#!/usr/bin/env bash
# font.sh — crisp console font via console-setup + Terminus.

module_font() {
  section "控制台字体(Terminus)"

  apt_install console-setup fonts-terminus || {
    warn "字体包安装失败,跳过字体模块。"; return 0; }

  local size
  size="$(choose "选择字号(高分屏选大的):" 1 \
    "16x32" "14x28" "12x24" "10x20" "8x16")"

  local cfg=/etc/default/console-setup
  info "写入 $cfg: Terminus / $size / UTF-8"
  set_kv_in_file "$cfg" ACTIVE_CONSOLES '"/dev/tty[1-6]"'
  set_kv_in_file "$cfg" CHARMAP '"UTF-8"'
  set_kv_in_file "$cfg" CODESET '"guess"'
  set_kv_in_file "$cfg" FONTFACE '"Terminus"'
  set_kv_in_file "$cfg" FONTSIZE "\"$size\""

  # Apply now and bake into initramfs so it's right from early boot.
  if have setupcon; then
    run setupcon --force --save
  fi
  if have update-initramfs; then
    run update-initramfs -u
  fi

  ok "字体已设为 Terminus $size(立即生效;下次开机同样生效)。"
}
