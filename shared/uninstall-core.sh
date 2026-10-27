#!/usr/bin/env bash
# uninstall-core.sh — shared restore logic for both distros.
#
# A distro uninstall.sh sets REPO_ROOT, sources shared/common.sh + its pkg.sh,
# then calls uninstall_main "$@". Boot-artifact regeneration is delegated to
# pkg_regen_boot (provided by each distro's pkg.sh): apt/initramfs vs mkinitcpio.

uninstall_main() {
  require_root "$@"

  local backup_root="$REPO_ROOT/backups"
  local target="${1:-}"
  if [ -z "$target" ]; then
    [ -d "$backup_root" ] || die "没有找到任何备份目录($backup_root)。"
    target="$(ls -1d "$backup_root"/*/ 2>/dev/null | sort | tail -n1)"
    [ -n "$target" ] || die "备份目录为空。"
  fi
  target="${target%/}"
  [ -d "$target" ] || die "备份目录不存在:$target"
  info "使用备份:$target"

  # --- restore files from manifest ------------------------------------------
  local manifest="$target/manifest.tsv"
  if [ -f "$manifest" ]; then
    local orig bak
    while IFS=$'\t' read -r orig bak; do
      [ -n "$orig" ] || continue
      if [ -e "$bak" ]; then
        info "还原 $orig"
        install -D -m "$(stat -c %a "$bak")" "$bak" "$orig"
      fi
    done < "$manifest"
    ok "文件已按 manifest 还原。"
  else
    warn "没有 manifest.tsv,跳过文件还原。"
  fi

  # --- colors service --------------------------------------------------------
  if systemctl list-unit-files 2>/dev/null | grep -q '^tty-colors.service'; then
    info "停用并删除 tty-colors.service"
    systemctl disable --now tty-colors.service 2>/dev/null || true
    rm -f /etc/systemd/system/tty-colors.service
    systemctl daemon-reload 2>/dev/null || true
  fi

  # --- regenerate boot artifacts (distro-specific) ---------------------------
  pkg_regen_boot

  ok "还原完成。"
  warn "本工具不会自动卸载装过的包(字体/zsh/fish/fbterm 等),如需卸载请自行处理。"
  warn "fbterm 的自启片段已随 manifest 还原到对应 profile;如仍想手动清理见对应 ~/.*profile。"
}
