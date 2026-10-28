#!/usr/bin/env bash
# pkg.sh (Debian) — apt implementation of the package interface that shared
# core and modules rely on: pkg_detect / pkg_update_once / pkg_install.
#
# Also exports distro-specific binary names used by the shell module, because
# Debian ships bat/fd under different command names.
export BAT_BIN="batcat"
export FD_BIN="fdfind"

# CJK (Chinese) font for fbterm — the kernel console can't show CJK, but fbterm
# renders TTF so it can. Package name + the family name to put in ~/.fbtermrc.
export CJK_FONT_PKG="fonts-wqy-microhei"
export CJK_FONT_NAME="WenQuanYi Micro Hei Mono"

# --- optional tools map (used by shared/modules/tools.sh) --------------------
# Generic tool key -> apt package name(s). The shared tools module only knows
# keys; the distro-specific package names live here. A key absent from this
# map is skipped with a warning (e.g. helix/dust/procs are not in Debian stable).
declare -gA TOOL_PKG=(
  [git]="git"
  [buildtools]="build-essential"
  [make]="make"
  [cmake]="cmake"
  [python]="python3 python3-pip python3-venv"
  [nodejs]="nodejs npm"
  [go]="golang"
  [rust]="rustc cargo"
  [gdb]="gdb"
  [jq]="jq"
  [shellcheck]="shellcheck"
  [curl]="curl"
  [wget]="wget"
  [openssh]="openssh-client openssh-server"
  [nmap]="nmap"
  [net-tools]="net-tools"
  [iproute2]="iproute2"
  [dig]="dnsutils"
  [mtr]="mtr-tiny"
  [traceroute]="traceroute"
  [tcpdump]="tcpdump"
  [rsync]="rsync"
  [whois]="whois"
  [socat]="socat"
  [netcat]="netcat-openbsd"
  [iftop]="iftop"
  [nload]="nload"
  [nano]="nano"
  [vim]="vim"
  [neovim]="neovim"
  [micro]="micro"
  [emacs]="emacs-nox"
  [tmux]="tmux"
  [gpm]="gpm"
  [htop]="htop"
  [btop]="btop"
  [ncdu]="ncdu"
  [tldr]="tldr"
  [tree]="tree"
  [duf]="duf"
  [delta]="git-delta"
)
# Debian has no AUR; declared empty so tools.sh can reference it uniformly.
declare -gA TOOL_AUR=()

pkg_detect() {
  if [ -f /etc/debian_version ] && have apt-get; then
    return 0
  fi
  warn "这看起来不是 Debian/apt 系统。debian/ 脚本是为 Debian 写的,继续可能出错。"
  confirm "仍要继续吗?" "n" || die "已取消。"
}

_APT_UPDATED=0
pkg_update_once() {
  [ "$_APT_UPDATED" = "1" ] && return 0
  info "apt-get update …"
  run apt-get update -qq
  _APT_UPDATED=1
}

# pkg_install <pkgs...> : install packages that aren't already present.
pkg_install() {
  local pkgs=() p
  for p in "$@"; do
    if dpkg -s "$p" >/dev/null 2>&1; then
      ok "$p 已安装"
    else
      pkgs+=("$p")
    fi
  done
  [ "${#pkgs[@]}" -eq 0 ] && return 0
  pkg_update_once
  info "安装:${pkgs[*]}"
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

# Debian has fbterm in the repos, so aur_install just falls back to pkg_install.
aur_install() { pkg_install "$@"; }

# Regenerate boot artifacts after font/resolution changes (used by uninstall).
pkg_regen_boot() {
  have update-grub && run update-grub || true
  have update-initramfs && run update-initramfs -u || true
  have setupcon && run setupcon --force 2>/dev/null || true
}
