#!/usr/bin/env bash
# shell.sh (Arch) — modern shell + starship + modern CLI tools.
#
# On Arch everything is in the official repos (starship, eza, bat, fd, …) and
# ships under its real binary name, so this is simpler than the Debian module.
# Note: in the bare kernel console colors degrade to 16; full effect needs a
# real terminal emulator / fbterm.

_SHELL_BLOCK_BEGIN="# >>> tty-beautify (managed block) >>>"
_SHELL_BLOCK_END="# <<< tty-beautify (managed block) <<<"
_shell_write_block() { write_managed_block "$1" "$2" "$3" "$_SHELL_BLOCK_BEGIN" "$_SHELL_BLOCK_END"; }

module_shell() {
  section "Shell + 提示符 + 现代工具"

  local who; who="$(target_user)"
  local home; home="$(target_home)"
  info "目标用户:$who ($home)"

  local sh
  sh="$(choose "选择要用的 shell:" 1 "zsh" "fish" "跳过(只装工具)")"

  local shbin=""
  case "$sh" in
    zsh)  pkg_install zsh  && shbin="$(command -v zsh)";;
    fish) pkg_install fish && shbin="$(command -v fish)";;
  esac

  # Modern CLI tools + starship — all from official repos; best-effort.
  pkg_install starship ripgrep fd bat fzf zoxide eza || \
    warn "部分工具安装失败,不影响其余功能。"

  # starship preset.
  if [ -f "$ASSETS_DIR/starship/starship.toml" ]; then
    backup_file "$home/.config/starship.toml"
    run install -D -m 0644 -o "$who" -g "$who" \
      "$ASSETS_DIR/starship/starship.toml" "$home/.config/starship.toml"
    run chown "$who:$who" "$home/.config" 2>/dev/null || true
  fi

  # Aliases (Arch binary names: bat/fd).
  local aliases=""
  have eza && aliases+=$'alias ls=\'eza --group-directories-first\'\nalias ll=\'eza -lah --group-directories-first\'\n'
  have bat && aliases+=$'alias cat=\'bat --paging=never\'\n'

  case "$sh" in
    zsh)
      local block="$aliases"
      block+=$'command -v starship >/dev/null && eval "$(starship init zsh)"\n'
      block+=$'command -v zoxide >/dev/null && eval "$(zoxide init zsh)"\n'
      block+=$'[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh\n'
      block+=$'[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh'
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

  if [ -n "$shbin" ] && [ "$sh" != "跳过(只装工具)" ]; then
    if confirm "把 $who 的登录 shell 改为 $sh 吗?" "y"; then
      run chsh -s "$shbin" "$who" && ok "登录 shell 已改为 $shbin(重新登录生效)。"
    fi
  fi

  ok "Shell 模块完成。"
  warn "提示:starship / 现代工具在纯内核控制台只有 16 色;完整效果建议用 fbterm 或从别处 SSH 进来用现代终端。"
}
