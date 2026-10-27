#!/usr/bin/env bash
# resolution.sh — raise the framebuffer console resolution via GRUB.
# The #1 reason the console looks "big and blurry" is a low video mode.

module_resolution() {
  section "分辨率(GRUB framebuffer)"

  local grub=/etc/default/grub
  if [ ! -f "$grub" ]; then
    warn "$grub 不存在,跳过(可能不是 GRUB 引导)。"
    return 0
  fi

  local mode
  mode="$(choose "选择控制台分辨率:" 1 \
    "1920x1080" "1600x900" "1366x768" "1280x720" "1024x768" "自定义")"
  if [ "$mode" = "自定义" ]; then
    if [ "$ASSUME_YES" = "1" ]; then
      mode="1920x1080"
    else
      read -r -p "输入分辨率 (如 2560x1440): " mode
      [[ "$mode" =~ ^[0-9]+x[0-9]+$ ]] || { warn "格式不对,用 1920x1080"; mode="1920x1080"; }
    fi
  fi

  info "设置 GRUB_GFXMODE=$mode, GRUB_GFXPAYLOAD_LINUX=keep"
  set_kv_in_file "$grub" GRUB_GFXMODE "$mode"
  set_kv_in_file "$grub" GRUB_GFXPAYLOAD_LINUX keep

  if have update-grub; then
    run update-grub
  elif have grub-mkconfig; then
    run grub-mkconfig -o /boot/grub/grub.cfg
  else
    warn "未找到 update-grub/grub-mkconfig,配置已写入但未重新生成 grub.cfg。"
  fi

  ok "分辨率已设为 $mode —— ${C_BOLD}重启后生效${C_RESET}。"
  warn "虚拟机虚拟显卡对分辨率支持有限;若重启后黑屏/无显示,进 GRUB 菜单降到 1280x720 或 1024x768。"
  NEED_REBOOT=1
}
