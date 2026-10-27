#!/usr/bin/env bash
# shell.sh — modern shell + starship prompt + modern CLI tools.
#
# Note: starship and truecolor tools degrade to 16 colors on the bare kernel
# console. They still look better there, but full effect needs a real terminal
# emulator (e.g. SSH in from the host). README spells this out.

# Markers for our idempotent/removable rc block (see write_managed_block).
_SHELL_BLOCK_BEGIN="# >>> tty-beautify (managed block) >>>"
_SHELL_BLOCK_END="# <<< tty-beautify (managed block) <<<"
_shell_write_block() { write_managed_block "$1" "$2" "$3" "$_SHELL_BLOCK_BEGIN" "$_SHELL_BLOCK_END"; }

# Install modern CLI tools best-effort; collect the ones that are missing.
# Debian package names: fd is 'fd-find' (binary fdfind), bat is 'bat' (binary
# batcat) — see BAT_BIN/FD_BIN exported by debian/pkg.sh.
_install_cli_tools() {
  local missing=()
  local pkgs=(ripgrep fd-find bat fzf zoxide eza)
  local p
  for p in "${pkgs[@]}"; do
    pkg_install "$p" 2>/dev/null || missing+=("$p")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    warn "这些工具在当前仓库装不上(Debian stable 可能没有,如 eza):${missing[*]}"
    warn "可开启 backports 或手动安装;不影响其余功能。"
  fi
}

module_shell() {
  section "Shell + 提示符 + 现代工具"

  local who; who="$(target_user)"
  local home; home="$(target_home)"
  info "目标用户:$who ($home)"

  local sh
  sh="$(choose "选择要用的 shell:" 1 "zsh" "fish" "跳过(只装工具)")"

  # --- install chosen shell -------------------------------------------------
  local shbin=""
  case "$sh" in
    zsh)  pkg_install zsh  && shbin="$(command -v zsh)";;
    fish) pkg_install fish && shbin="$(command -v fish)";;
  esac

  # --- modern CLI tools -----------------------------------------------------
  _install_cli_tools

  # --- starship -------------------------------------------------------------
  if ! have starship; then
    info "安装 starship 到 /usr/local/bin"
    if [ "$DRY_RUN" = "1" ]; then
      printf '%s[dry-run]%s curl -sS https://starship.rs/install.sh | sh -s -- -y\n' "$C_DIM" "$C_RESET"
    elif have curl; then
      curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null \
        && ok "starship 安装完成" || warn "starship 安装失败(可稍后手动装)。"
    else
      pkg_install curl
      curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null \
        && ok "starship 安装完成" || warn "starship 安装失败。"
    fi
  else
    ok "starship 已安装"
  fi

  # Drop the starship preset into the user's config.
  if [ -f "$ASSETS_DIR/starship/starship.toml" ]; then
    local cfgdir="$home/.config"
    backup_file "$cfgdir/starship.toml"
    run install -D -m 0644 -o "$who" -g "$who" \
      "$ASSETS_DIR/starship/starship.toml" "$cfgdir/starship.toml"
    run chown "$who:$who" "$cfgdir" 2>/dev/null || true
  fi

  # --- shell rc config block ------------------------------------------------
  # Common aliases; only wire a tool if its binary is present. Binary names
  # differ per distro, hence BAT_BIN/FD_BIN from pkg.sh.
  local aliases=""
  have eza           && aliases+=$'alias ls=\'eza --group-directories-first\'\nalias ll=\'eza -lah --group-directories-first\'\n'
  have "$BAT_BIN"    && aliases+="alias cat='$BAT_BIN --paging=never'"$'\n'
  [ "$FD_BIN" != "fd" ] && have "$FD_BIN" && aliases+="alias fd='$FD_BIN'"$'\n'

  case "$sh" in
    zsh)
      local block="$aliases"
      block+=$'command -v starship >/dev/null && eval "$(starship init zsh)"\n'
      block+=$'command -v zoxide >/dev/null && eval "$(zoxide init zsh)"\n'
      block+=$'[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh\n'
      block+=$'[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh'
      _shell_write_block "$home/.zshrc" "$block" "$who"
      ;;
    fish)
      local fcfg="$home/.config/fish/config.fish"
      run install -d -o "$who" -g "$who" "$home/.config/fish"
      local block="$aliases"
      block+=$'command -v starship >/dev/null && starship init fish | source\n'
      block+=$'command -v zoxide >/dev/null && zoxide init fish | source'
      _shell_write_block "$fcfg" "$block" "$who"
      ;;
  esac

  # --- set login shell ------------------------------------------------------
  if [ -n "$shbin" ] && [ "$sh" != "跳过(只装工具)" ]; then
    if confirm "把 $who 的登录 shell 改为 $sh 吗?" "y"; then
      run chsh -s "$shbin" "$who" && ok "登录 shell 已改为 $shbin(重新登录生效)。"
    fi
  fi

  ok "Shell 模块完成。"
  warn "提示:starship / 现代工具在纯内核控制台只有 16 色;完整效果建议从宿主机 SSH 进来用现代终端。"
}
