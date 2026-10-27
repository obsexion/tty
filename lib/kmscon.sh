#!/usr/bin/env bash
# kmscon.sh — build kmscon from source and run it on ONE tty (tty2) only.
#
# kmscon is a userspace KMS/DRM console with TrueType fonts and more colors —
# it goes beyond the kernel console's 16-color bitmap limit. It is NOT packaged
# in current Debian, so we build it from the maintained Aetf/kmscon fork.
#
# SAFETY: we only take over tty2 and leave tty1 as the stock getty. If kmscon
# fails to start, you can always switch to tty1 (Ctrl+Alt+F1) and log in.

KMSCON_REPO="https://github.com/Aetf/kmscon.git"
KMSCON_TTY="tty2"
KMSCON_BUILD_DIR=""   # set in module

_kmscon_deps() {
  # Build toolchain + graphics/input/text stack kmscon needs.
  apt_install git meson ninja-build gcc pkg-config \
    libdrm-dev libxkbcommon-dev libgbm-dev libegl1-mesa-dev \
    libpango1.0-dev libudev-dev libsystemd-dev libtsm-dev || return 1
}

# libtsm may be missing from Debian; build it from source if so.
_kmscon_libtsm() {
  if pkg-config --exists libtsm 2>/dev/null; then
    ok "libtsm 已存在"
    return 0
  fi
  warn "libtsm 缺失,从源码编译…"
  local d="$KMSCON_BUILD_DIR/libtsm"
  run git clone --depth 1 https://github.com/Aetf/libtsm.git "$d" || return 1
  ( run cd "$d" && run meson setup build && run ninja -C build && run ninja -C build install ) || return 1
  run ldconfig
}

_kmscon_build() {
  local d="$KMSCON_BUILD_DIR/kmscon"
  info "clone kmscon ($KMSCON_REPO)"
  run git clone --depth 1 "$KMSCON_REPO" "$d" || return 1
  info "编译 kmscon(需要几分钟)…"
  ( run cd "$d" \
      && run meson setup build \
      && run ninja -C build \
      && run ninja -C build install ) || return 1
  run ldconfig
  have kmscon || [ "$DRY_RUN" = "1" ] || { err "kmscon 编译后仍找不到可执行文件。"; return 1; }
  ok "kmscon 编译安装完成"
}

_kmscon_install_config() {
  local src="$ASSETS_DIR/kmscon/kmscon.conf" dst=/etc/kmscon/kmscon.conf
  [ -f "$src" ] || return 0
  backup_file "$dst"
  run install -D -m 0644 "$src" "$dst"
  ok "配置写入 $dst"
}

# Hook kmscon onto tty2 only; keep getty@tty1 untouched. Returns non-zero on
# failure so the caller can roll back.
_kmscon_enable_tty2() {
  local who; who="$(target_user)"
  # kmscon needs access to DRM + input devices.
  run usermod -aG video,input "$who" 2>/dev/null || true

  # The Aetf fork installs kmsconvt@.service. Confirm it exists.
  if [ "$DRY_RUN" != "1" ] && ! systemctl cat kmsconvt@.service >/dev/null 2>&1; then
    err "没找到 kmsconvt@.service(安装可能不完整),不改动 getty。"
    return 1
  fi

  info "让 kmscon 接管 $KMSCON_TTY(tty1 保持原生 getty 不变)"
  run systemctl daemon-reload
  run systemctl disable --now "getty@${KMSCON_TTY}.service" 2>/dev/null || true
  run systemctl mask "getty@${KMSCON_TTY}.service"
  if ! run systemctl enable --now "kmsconvt@${KMSCON_TTY}.service"; then
    err "kmscon 启动失败,回滚 $KMSCON_TTY 的 getty。"
    run systemctl unmask "getty@${KMSCON_TTY}.service"
    run systemctl enable --now "getty@${KMSCON_TTY}.service" 2>/dev/null || true
    return 1
  fi
  return 0
}

module_kmscon() {
  section "kmscon(高级:源码编译 + 接管 tty2)"

  warn "${C_BOLD}这是高级选项${C_RESET}:需要从源码编译(拉一堆开发依赖、耗时几分钟),"
  warn "并会把 ${C_BOLD}$KMSCON_TTY${C_RESET} 换成 kmscon。tty1 保持原生 getty,出问题可切回 Ctrl+Alt+F1。"
  confirm "确认继续安装 kmscon 吗?" "n" || { info "已跳过 kmscon。"; return 0; }

  KMSCON_BUILD_DIR="$(mktemp -d /tmp/kmscon-build.XXXXXX)"
  info "构建目录:$KMSCON_BUILD_DIR"

  _kmscon_deps        || { err "依赖安装失败,放弃 kmscon。"; return 0; }
  _kmscon_libtsm      || { err "libtsm 处理失败,放弃 kmscon。"; return 0; }
  _kmscon_build       || { err "kmscon 编译失败,放弃 kmscon。"; return 0; }
  _kmscon_install_config
  if _kmscon_enable_tty2; then
    ok "kmscon 已接管 $KMSCON_TTY —— 按 ${C_BOLD}Ctrl+Alt+F2${C_RESET} 查看效果。"
    warn "首次需重新登录或重启让 video/input 组生效。"
  else
    warn "kmscon 未能启用;系统仍可正常用原生控制台。"
  fi

  # Clean build dir unless dry-run.
  [ "$DRY_RUN" = "1" ] || rm -rf "$KMSCON_BUILD_DIR"
}
