#!/usr/bin/env bash
# colors.sh — recolor the 16-color console palette to Gruvbox and persist it.
#
# The kernel console has exactly 16 colors, but their RGB values are
# programmable via setvtrgb. We ship a Gruvbox palette and load it at boot
# through a small systemd oneshot service (more reliable than implicit paths).

module_colors() {
  section "配色(Gruvbox 16 色)"

  if ! have setvtrgb; then
    pkg_install kbd || true
  fi
  if ! have setvtrgb; then
    warn "没有 setvtrgb(kbd 包),跳过配色模块。"
    return 0
  fi

  local src="$ASSETS_DIR/vtrgb/gruvbox"
  local dst=/etc/vt/vtrgb-gruvbox
  [ -f "$src" ] || { err "缺少调色板文件 $src"; return 0; }

  info "安装调色板到 $dst"
  backup_file "$dst"
  run install -D -m 0644 "$src" "$dst"

  # Apply immediately to the current VTs.
  info "立即应用配色"
  run setvtrgb "$dst"

  # Persist across reboots via a oneshot service.
  local unit=/etc/systemd/system/tty-colors.service
  info "安装开机持久化服务 tty-colors.service"
  backup_file "$unit"
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s[dry-run]%s write %s\n' "$C_DIM" "$C_RESET" "$unit"
  else
    cat > "$unit" <<EOF
[Unit]
Description=Apply Gruvbox palette to the Linux console (tty)
After=systemd-vconsole-setup.service
Wants=systemd-vconsole-setup.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/setvtrgb $dst

[Install]
WantedBy=multi-user.target
EOF
  fi
  run systemctl daemon-reload
  run systemctl enable tty-colors.service

  ok "Gruvbox 配色已应用,并会在每次开机自动加载。"
}
