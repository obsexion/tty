#!/usr/bin/env bash
# uninstall.sh — 还原本工具做过的改动。
#
# 用法:
#   sudo ./uninstall.sh            还原最近一次运行的备份
#   sudo ./uninstall.sh <备份目录>  还原指定 backups/<时间戳>
#
# 做的事:按 manifest 还原被改文件、禁用/删除 tty-colors.service、
#        把 tty2 的 getty 恢复回来、重新生成 grub.cfg 与 initramfs。
# 不会自动卸载 apt 包(避免误删),只提示包名。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
source "$REPO_ROOT/lib/common.sh"

require_root "$@"

BACKUP_ROOT="$REPO_ROOT/backups"
target="${1:-}"

if [ -z "$target" ]; then
  [ -d "$BACKUP_ROOT" ] || die "没有找到任何备份目录($BACKUP_ROOT)。"
  target="$(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort | tail -n1)"
  [ -n "$target" ] || die "备份目录为空。"
fi
target="${target%/}"
[ -d "$target" ] || die "备份目录不存在:$target"

info "使用备份:$target"

# --- restore files from manifest --------------------------------------------
manifest="$target/manifest.tsv"
if [ -f "$manifest" ]; then
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

# --- colors service ----------------------------------------------------------
if systemctl list-unit-files 2>/dev/null | grep -q '^tty-colors.service'; then
  info "停用并删除 tty-colors.service"
  systemctl disable --now tty-colors.service 2>/dev/null || true
  rm -f /etc/systemd/system/tty-colors.service
fi

# --- kmscon: give tty2 back to getty -----------------------------------------
if systemctl list-unit-files 2>/dev/null | grep -q '^kmsconvt@'; then
  info "恢复 tty2 的 getty(禁用 kmscon)"
  systemctl disable --now kmsconvt@tty2.service 2>/dev/null || true
  systemctl unmask getty@tty2.service 2>/dev/null || true
  systemctl enable --now getty@tty2.service 2>/dev/null || true
fi

systemctl daemon-reload 2>/dev/null || true

# --- regenerate boot artifacts if we touched grub/console-setup --------------
if have update-grub; then update-grub || true; fi
if have update-initramfs; then update-initramfs -u || true; fi
if have setupcon; then setupcon --force 2>/dev/null || true; fi

ok "还原完成。"
warn "本工具不会自动卸载安装过的 apt 包(console-setup/fonts-terminus/zsh/fish 等)。"
warn "如需卸载请自行:sudo apt remove <包名>;kmscon 为源码安装,如装了在 /usr/local 下。"
