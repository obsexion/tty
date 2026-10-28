#!/usr/bin/env bash
# font.sh (Arch) — crisp console font via terminus-font + /etc/vconsole.conf.
#
# Arch has no console-setup; the console font is set by FONT= in
# /etc/vconsole.conf (applied by systemd-vconsole-setup), with setfont for the
# current console and the mkinitcpio 'consolefont' hook for early boot.

# Ensure 'consolefont' is in the mkinitcpio HOOKS array so the font is set
# before/at boot (not just after login).
_arch_add_consolefont_hook() {
  local conf=/etc/mkinitcpio.conf
  [ -f "$conf" ] || { warn "没有 $conf,跳过 initramfs 字体 hook。"; return 0; }
  if grep -qE '^HOOKS=.*\bconsolefont\b' "$conf"; then
    ok "mkinitcpio 已含 consolefont hook"
    return 0
  fi
  backup_file "$conf"
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s[dry-run]%s add consolefont to HOOKS in %s\n' "$C_DIM" "$C_RESET" "$conf"
  else
    # Insert consolefont after 'keymap' if present, else before 'filesystems'.
    if grep -qE '^HOOKS=.*\bkeymap\b' "$conf"; then
      sed -i -E 's/^(HOOKS=\(.*\bkeymap\b)/\1 consolefont/' "$conf"
    else
      sed -i -E 's/^(HOOKS=\(.*)\bfilesystems\b/\1consolefont filesystems/' "$conf"
    fi
    ok "已向 mkinitcpio HOOKS 加入 consolefont"
  fi
  if have mkinitcpio; then run mkinitcpio -P; fi
}

module_font() {
  section "控制台字体(Terminus / vconsole)"

  pkg_install terminus-font || { warn "terminus-font 安装失败,跳过字体模块。"; return 0; }

  # terminus-font PSF names: ter-1NNn (normal) / ter-1NNb (bold), NN = pixel size.
  local font
  font="$(choose "选择字体(数字越大越大,高分屏选大的):" 1 \
    "ter-132n" "ter-128n" "ter-124n" "ter-120n" "ter-116n")"

  info "写入 /etc/vconsole.conf: FONT=$font"
  set_kv_in_file /etc/vconsole.conf FONT "$font"

  # Apply to the current console immediately.
  if have setfont; then
    run setfont "$font" 2>/dev/null || warn "setfont 立即应用失败(重启后仍会生效)。"
  fi

  # Make it stick from early boot.
  _arch_add_consolefont_hook

  ok "字体已设为 $font(立即生效;下次开机同样生效)。"
  warn "注意:Terminus 不含中文字形,纯内核控制台也显示不了 CJK —— 中文会变方框。"
  warn "需要在控制台看中文,请用 fbterm 模块(它能装中文 TTF 字体)。"
}
