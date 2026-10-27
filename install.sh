#!/usr/bin/env bash
# install.sh — Debian 控制台美化工具箱入口。
#
# 用法:
#   sudo ./install.sh            交互菜单(推荐)
#   sudo ./install.sh --all      跑全部模块(kmscon 仍会二次确认)
#   sudo ./install.sh --yes      非交互,全取默认值
#   ./install.sh --dry-run       只打印将执行的动作,不改系统(可非 root)
#   ./install.sh --help
#
# 模块:分辨率 / 字体 / 配色 / Shell / kmscon(高级)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT

# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/resolution.sh"
source "$REPO_ROOT/lib/font.sh"
source "$REPO_ROOT/lib/colors.sh"
source "$REPO_ROOT/lib/shell.sh"
source "$REPO_ROOT/lib/kmscon.sh"

NEED_REBOOT=0
RUN_ALL=0

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# --- parse flags -------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --all)     RUN_ALL=1 ;;
    --yes|-y)  ASSUME_YES=1; RUN_ALL=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --help|-h) usage ;;
    *) die "未知参数:$arg(--help 看用法)" ;;
  esac
done
export DRY_RUN ASSUME_YES

# dry-run doesn't need root; everything else does.
[ "$DRY_RUN" = "1" ] || require_root "$@"
detect_debian

printf '%s%s Debian 控制台美化工具箱 %s\n' "$C_BOLD" "$C_CYA" "$C_RESET"
[ "$DRY_RUN" = "1" ] && warn "DRY-RUN 模式:只打印,不改动系统。"

# --- pick modules ------------------------------------------------------------
# selections stored as space-separated keys
SELECTED=""

select_modules() {
  if [ "$RUN_ALL" = "1" ]; then
    SELECTED="resolution font colors shell kmscon"
    return
  fi
  cat <<'MENU'

选择要执行的模块(多选,用空格/逗号分隔序号,或输入 all):
  1) 分辨率   提高 framebuffer 分辨率(GRUB)
  2) 字体     Terminus 清晰字体
  3) 配色     Gruvbox 16 色调色板
  4) Shell    zsh/fish + starship + 现代 CLI 工具
  5) kmscon   高级:TTF 字体控制台,接管 tty2(需编译)
MENU
  local ans
  read -r -p "你的选择 [1 2 3]: " ans
  ans="${ans:-1 2 3}"
  if [ "$ans" = "all" ]; then
    SELECTED="resolution font colors shell kmscon"
    return
  fi
  local n
  for n in ${ans//,/ }; do
    case "$n" in
      1) SELECTED+=" resolution" ;;
      2) SELECTED+=" font" ;;
      3) SELECTED+=" colors" ;;
      4) SELECTED+=" shell" ;;
      5) SELECTED+=" kmscon" ;;
      *) warn "忽略无效选项:$n" ;;
    esac
  done
}

select_modules
[ -n "${SELECTED// /}" ] || die "没有选择任何模块,退出。"

# --- run in a sensible order -------------------------------------------------
run_if() { case " $SELECTED " in *" $1 "*) "$2" ;; esac; }

run_if resolution module_resolution
run_if font        module_font
run_if colors       module_colors
run_if shell        module_shell
run_if kmscon       module_kmscon

# --- summary -----------------------------------------------------------------
section "完成"
ok "已执行模块:$SELECTED"
info "备份目录:$(backup_dir_path)"
info "还原命令:sudo ./uninstall.sh"
if [ "$NEED_REBOOT" = "1" ]; then
  warn "分辨率改动需要 ${C_BOLD}重启${C_RESET} 后生效:sudo reboot"
fi
