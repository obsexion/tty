#!/usr/bin/env bash
# common.sh — shared helpers for the Debian console beautifier.
# Sourced by install.sh / uninstall.sh and every lib/*.sh module.
#
# Guards against being sourced twice.
[ -n "${_TTY_COMMON_SOURCED:-}" ] && return 0
_TTY_COMMON_SOURCED=1

# --- paths -------------------------------------------------------------------
# REPO_ROOT is resolved by the caller (install.sh/uninstall.sh) and exported.
# Fall back to the directory two levels up from this file if unset.
if [ -z "${REPO_ROOT:-}" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export REPO_ROOT
ASSETS_DIR="$REPO_ROOT/assets"
BACKUP_ROOT="$REPO_ROOT/backups"

# --- runtime flags -----------------------------------------------------------
# DRY_RUN=1  -> print write actions instead of running them (safe host trial).
# ASSUME_YES=1 -> skip interactive confirmations, take defaults.
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

# --- colors (16-color safe, degrades gracefully) -----------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m'; C_CYA=$'\033[36m'
else
  C_RESET=; C_DIM=; C_BOLD=; C_RED=; C_GRN=; C_YEL=; C_BLU=; C_CYA=
fi

log()  { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$C_BLU$C_BOLD" "$C_RESET" "$*"; }
ok()   { printf '%s ok %s %s\n' "$C_GRN$C_BOLD" "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YEL$C_BOLD" "$C_RESET" "$*" >&2; }
err()  { printf '%serr %s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

# A visually distinct section header for each module.
section() {
  printf '\n%s%s──%s %s\n' "$C_CYA" "$C_BOLD" "$C_RESET" "$C_BOLD$*$C_RESET"
}

# --- privilege ---------------------------------------------------------------
require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      info "需要 root 权限,正在用 sudo 重新运行…"
      exec sudo -E bash "$0" "$@"
    fi
    die "请用 root 运行(没找到 sudo)。"
  fi
}

# --- target user (the real user behind sudo) ---------------------------------
# chsh / writing ~/.config must target the human, not root.
target_user() {
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    printf '%s' "$SUDO_USER"
  else
    # No SUDO_USER (ran as root directly); fall back to the first real login.
    local u
    u="$(logname 2>/dev/null || true)"
    [ -z "$u" ] && u="$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd)"
    printf '%s' "${u:-root}"
  fi
}

target_home() {
  local u; u="$(target_user)"
  getent passwd "$u" | cut -d: -f6
}

# --- environment detection ---------------------------------------------------
detect_debian() {
  if [ -f /etc/debian_version ] && command -v apt-get >/dev/null 2>&1; then
    return 0
  fi
  warn "这看起来不是 Debian/apt 系统。脚本是为 Debian 写的,继续可能出错。"
  confirm "仍要继续吗?" "n" || die "已取消。"
}

# --- confirm / prompt helpers ------------------------------------------------
# confirm <question> [default y|n] -> returns 0 for yes
confirm() {
  local q="$1" def="${2:-y}" ans hint
  if [ "$ASSUME_YES" = "1" ]; then return 0; fi
  if [ "$def" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  read -r -p "$q $hint " ans
  ans="${ans:-$def}"
  case "$ans" in [Yy]*) return 0;; *) return 1;; esac
}

# choose <prompt> <default-index> <opt1> <opt2> ...
# echoes the chosen option string; honors ASSUME_YES -> default.
choose() {
  local prompt="$1" def="$2"; shift 2
  local opts=("$@") i ans
  if [ "$ASSUME_YES" = "1" ]; then printf '%s' "${opts[$((def-1))]}"; return 0; fi
  {
    printf '%s\n' "$prompt"
    for i in "${!opts[@]}"; do printf '  %d) %s\n' "$((i+1))" "${opts[$i]}"; done
  } >&2
  read -r -p "选择 [${def}]: " ans >&2
  ans="${ans:-$def}"
  if ! [[ "$ans" =~ ^[0-9]+$ ]] || [ "$ans" -lt 1 ] || [ "$ans" -gt "${#opts[@]}" ]; then
    ans="$def"
  fi
  printf '%s' "${opts[$((ans-1))]}"
}

# --- dry-run aware command runner --------------------------------------------
# run <cmd...> : execute, or just print under DRY_RUN.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  "$@"
}

# --- backup with manifest ----------------------------------------------------
# A single backup dir per run, created lazily; manifest maps orig -> backup.
# Note: _ensure_backup_dir must run in the current shell (NOT via $(...)),
# otherwise the _BACKUP_DIR assignment is lost in the subshell.
_BACKUP_DIR=""
_ensure_backup_dir() {
  [ -n "$_BACKUP_DIR" ] && return 0
  _BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$_BACKUP_DIR"
    : > "$_BACKUP_DIR/manifest.tsv"
  fi
}

# backup_file <path> : copy an existing file into the run's backup dir and
# record it in the manifest. No-op if the file does not exist.
backup_file() {
  local src="$1"
  [ -e "$src" ] || return 0
  _ensure_backup_dir
  local dir="$_BACKUP_DIR"
  # Flatten path into a safe backup filename.
  local flat; flat="$(printf '%s' "$src" | sed 's#/#__#g')"
  local dst="$dir/$flat"
  # Keep only the FIRST (pristine) copy per path per run: a file edited twice
  # (e.g. grub via two set_kv_in_file calls) must not re-back-up its modified
  # form over the original.
  if [ -e "$dst" ]; then
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s[dry-run]%s backup %s -> %s\n' "$C_DIM" "$C_RESET" "$src" "$dst"
    return 0
  fi
  cp -a "$src" "$dst"
  printf '%s\t%s\n' "$src" "$dst" >> "$dir/manifest.tsv"
  info "已备份 $src"
}

# backup_dir_path : echo current run backup dir (for end-of-run summary).
backup_dir_path() { printf '%s' "${_BACKUP_DIR:-（本次无文件改动）}"; }

# --- apt helpers -------------------------------------------------------------
_APT_UPDATED=0
apt_update_once() {
  [ "$_APT_UPDATED" = "1" ] && return 0
  info "apt-get update …"
  run apt-get update -qq
  _APT_UPDATED=1
}

# apt_install <pkgs...> : install packages that aren't already present.
apt_install() {
  local pkgs=() p
  for p in "$@"; do
    if dpkg -s "$p" >/dev/null 2>&1; then
      ok "$p 已安装"
    else
      pkgs+=("$p")
    fi
  done
  [ "${#pkgs[@]}" -eq 0 ] && return 0
  apt_update_once
  info "安装:${pkgs[*]}"
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

# have <cmd> : true if command exists.
have() { command -v "$1" >/dev/null 2>&1; }

# set_kv_in_file <file> <KEY> <VALUE> :
# idempotently set KEY=VALUE in a shell-style config file (replace or append).
# Backs up the file first.
set_kv_in_file() {
  local file="$1" key="$2" val="$3"
  backup_file "$file"
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s[dry-run]%s set %s=%s in %s\n' "$C_DIM" "$C_RESET" "$key" "$val" "$file"
    return 0
  fi
  [ -e "$file" ] || touch "$file"
  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}=" "$file"; then
    # Replace the (possibly commented) existing assignment.
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}=.*|${key}=${val}|" "$file"
  else
    printf '%s=%s\n' "$key" "$val" >> "$file"
  fi
}
