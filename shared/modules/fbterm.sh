#!/usr/bin/env bash
# fbterm.sh — a framebuffer terminal with TrueType fonts (replaces kmscon).
#
# fbterm renders scalable, anti-aliased TTF fonts on the framebuffer — the
# crisp console the kernel console can't give you. It is launched from the
# shell (not by replacing getty), so there is little lock-out risk; we still
# only auto-start it on tty2-6 and keep tty1 as a plain fallback.
#
# Distro-agnostic: installs via aur_install (Debian's pkg.sh aliases that to
# pkg_install since fbterm is in the Debian repos; Arch uses a real AUR helper).

_FBTERM_BLOCK_BEGIN="# >>> tty-beautify fbterm autostart >>>"
_FBTERM_BLOCK_END="# <<< tty-beautify fbterm autostart <<<"

# Pick the login-profile file for a user's login shell.
_fbterm_profile_for() {
  local home="$1" shell="$2"
  case "$shell" in
    *zsh)  printf '%s/.zprofile' "$home" ;;
    *fish) printf '%s/.config/fish/config.fish' "$home" ;;
    *)     printf '%s/.bash_profile' "$home" ;;
  esac
}

module_fbterm() {
  section "fbterm(framebuffer + TTF 字体)"

  info "安装 fbterm"
  aur_install fbterm || { warn "fbterm 安装失败,跳过。"; return 0; }

  local who; who="$(target_user)"
  local home; home="$(target_home)"
  local ushell; ushell="$(getent passwd "$who" | cut -d: -f7)"

  # fbterm needs framebuffer (video group) access.
  run usermod -aG video "$who" 2>/dev/null || true

  # Install the fbtermrc (TTF font + size) for the user.
  if [ -f "$ASSETS_DIR/fbterm/fbtermrc" ]; then
    backup_file "$home/.fbtermrc"
    run install -D -m 0644 -o "$who" -g "$who" \
      "$ASSETS_DIR/fbterm/fbtermrc" "$home/.fbtermrc"
    ok "已写入 $home/.fbtermrc(字体改这里的 font-names)"
  fi

  # Optional guarded autostart.
  if confirm "登录 tty2-6 时自动进入 fbterm 吗?(tty1 保持纯控制台做兜底)" "y"; then
    local profile; profile="$(_fbterm_profile_for "$home" "$ushell")"
    local snippet
    snippet=$'if command -v fbterm >/dev/null 2>&1 && [ -z "$FBTERM" ] && [ -z "$DISPLAY" ]; then\n'
    snippet+=$'  case "$(tty)" in\n'
    snippet+=$'    /dev/tty[2-6]) exec fbterm ;;\n'
    snippet+=$'  esac\n'
    snippet+=$'fi'
    # fish uses different syntax; write a fish-native guard instead.
    if [[ "$ushell" == *fish ]]; then
      snippet=$'if type -q fbterm; and not set -q FBTERM; and not set -q DISPLAY\n'
      snippet+=$'  switch (tty)\n'
      snippet+=$'    case /dev/tty2 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6\n'
      snippet+=$'      exec fbterm\n'
      snippet+=$'  end\n'
      snippet+=$'end'
      run install -d -o "$who" -g "$who" "$home/.config/fish"
    fi
    write_managed_block "$profile" "$snippet" "$who" "$_FBTERM_BLOCK_BEGIN" "$_FBTERM_BLOCK_END"
    ok "已在 $profile 加入 fbterm 自启(仅 tty2-6)。"
  fi

  ok "fbterm 模块完成。"
  warn "首次需重新登录让 video 组生效。切到 ${C_BOLD}Ctrl+Alt+F2${C_RESET} 体验;tty1 保持原样。"
  warn "fbterm 用标准 ANSI 调色板,主打 TTF 字体;想要 Gruvbox 配色靠 colors 模块与 app 级主题。"
}
