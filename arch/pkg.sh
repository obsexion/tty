#!/usr/bin/env bash
# pkg.sh (Arch) — pacman + AUR implementation of the package interface.
#
# Binary names: Arch ships bat/fd under their real names (unlike Debian).
export BAT_BIN="bat"
export FD_BIN="fd"

# CJK (Chinese) font for fbterm — noto-fonts-cjk is in the official repos.
# Package name + the family name to put in ~/.fbtermrc.
export CJK_FONT_PKG="noto-fonts-cjk"
export CJK_FONT_NAME="Noto Sans Mono CJK SC"

# --- optional tools map (used by shared/modules/tools.sh) --------------------
# Generic tool key -> pacman package name(s). The shared tools module only
# knows keys; distro package names live here. A key absent from this map is
# skipped with a warning. Arch ships almost everything in the official repos.
declare -gA TOOL_PKG=(
  [git]="git"
  [buildtools]="base-devel"
  [make]="make"
  [cmake]="cmake"
  [python]="python python-pip"
  [nodejs]="nodejs npm"
  [go]="go"
  [rust]="rustup"
  [gdb]="gdb"
  [jq]="jq"
  [shellcheck]="shellcheck"
  [curl]="curl"
  [wget]="wget"
  [openssh]="openssh"
  [nmap]="nmap"
  [net-tools]="net-tools"
  [iproute2]="iproute2"
  [dig]="bind"
  [mtr]="mtr"
  [traceroute]="traceroute"
  [tcpdump]="tcpdump"
  [rsync]="rsync"
  [whois]="whois"
  [socat]="socat"
  [netcat]="openbsd-netcat"
  [iftop]="iftop"
  [nload]="nload"
  [nano]="nano"
  [vim]="vim"
  [neovim]="neovim"
  [micro]="micro"
  [helix]="helix"
  [emacs]="emacs-nox"
  [tmux]="tmux"
  [gpm]="gpm"
  [htop]="htop"
  [btop]="btop"
  [ncdu]="ncdu"
  [tldr]="tealdeer"
  [tree]="tree"
  [duf]="duf"
  [dust]="dust"
  [procs]="procs"
  [delta]="git-delta"
)
# AUR-only tools (installed via aur_install). Empty by default; add keys here
# for anything not in the official repos.
declare -gA TOOL_AUR=()

pkg_detect() {
  if [ -f /etc/arch-release ] && have pacman; then
    return 0
  fi
  warn "这看起来不是 Arch/pacman 系统。arch/ 脚本是为 Arch 写的,继续可能出错。"
  confirm "仍要继续吗?" "n" || die "已取消。"
}

_PAC_SYNCED=0
pkg_update_once() {
  [ "$_PAC_SYNCED" = "1" ] && return 0
  info "pacman -Sy …"
  run pacman -Sy --noconfirm
  _PAC_SYNCED=1
}

# pkg_install <pkgs...> : install official-repo packages not already present.
pkg_install() {
  local pkgs=() p
  for p in "$@"; do
    if pacman -Qq "$p" >/dev/null 2>&1; then
      ok "$p 已安装"
    else
      pkgs+=("$p")
    fi
  done
  [ "${#pkgs[@]}" -eq 0 ] && return 0
  pkg_update_once
  info "安装:${pkgs[*]}"
  run pacman -S --needed --noconfirm "${pkgs[@]}"
}

# aur_install <pkgs...> : install from the AUR via paru/yay, run as the real
# user (AUR helpers refuse to run as root). Falls back to a manual hint.
aur_install() {
  local p
  for p in "$@"; do
    pacman -Qq "$p" >/dev/null 2>&1 && { ok "$p 已安装"; continue; }
    local helper=""
    have paru && helper=paru
    [ -z "$helper" ] && have yay && helper=yay
    if [ -z "$helper" ]; then
      warn "没找到 AUR 助手(paru/yay),无法自动装 $p。"
      warn "请先装一个 AUR 助手,或手动:git clone https://aur.archlinux.org/$p.git && cd $p && makepkg -si"
      return 1
    fi
    local who; who="$(target_user)"
    info "用 $helper(以用户 $who)安装 AUR 包:$p"
    run sudo -u "$who" "$helper" -S --needed --noconfirm "$p"
  done
}

# Regenerate boot artifacts after font/resolution changes (used by uninstall).
pkg_regen_boot() {
  have grub-mkconfig && [ -d /boot/grub ] && run grub-mkconfig -o /boot/grub/grub.cfg || true
  have mkinitcpio && run mkinitcpio -P || true
}
