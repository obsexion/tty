#!/usr/bin/env bash
# install-core.sh — shared entry logic for both distros.
#
# A distro install.sh sets REPO_ROOT + DISTRO_NAME, sources shared/common.sh,
# its own pkg.sh, the shared + distro modules, then sources this file. All the
# flag parsing, the menu, module dispatch and the summary live here so the two
# install.sh wrappers stay thin.
#
# Modules expected to be defined before sourcing:
#   module_resolution module_font module_colors module_shell module_tools module_fbterm
# and the package interface from pkg.sh: pkg_detect / pkg_install / aur_install.

NEED_REBOOT=0
RUN_ALL=0

_core_usage() {
  cat <<EOF
用法:
  sudo ./install.sh            交互菜单(推荐)
  sudo ./install.sh --all      跑全部模块(fbterm 的自启仍会询问)
  sudo ./install.sh --yes      非交互,全取默认值
  ./install.sh --dry-run       只打印将执行的动作,不改系统(可非 root)
  ./install.sh --help

模块:分辨率 / 字体 / 配色 / Shell / 工具 / fbterm
EOF
  exit 0
}

core_main() {
  # --- parse flags ----------------------------------------------------------
  local arg
  for arg in "$@"; do
    case "$arg" in
      --all)     RUN_ALL=1 ;;
      --yes|-y)  ASSUME_YES=1; RUN_ALL=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --help|-h) _core_usage ;;
      *) die "未知参数:$arg(--help 看用法)" ;;
    esac
  done
  export DRY_RUN ASSUME_YES

  # dry-run doesn't need root; everything else does.
  [ "$DRY_RUN" = "1" ] || require_root "$@"
  pkg_detect

  printf '%s%s %s 控制台美化工具箱 %s\n' "$C_BOLD" "$C_CYA" "${DISTRO_NAME:-Linux}" "$C_RESET"
  [ "$DRY_RUN" = "1" ] && warn "DRY-RUN 模式:只打印,不改动系统。"

  # --- pick modules ---------------------------------------------------------
  local SELECTED=""
  if [ "$RUN_ALL" = "1" ]; then
    SELECTED="resolution font colors shell tools fbterm"
  else
    cat <<'MENU'

选择要执行的模块(多选,用空格/逗号分隔序号,或输入 all):
  1) 分辨率   提高 framebuffer 分辨率(GRUB)
  2) 字体     Terminus 清晰点阵字体
  3) 配色     Gruvbox 16 色调色板
  4) Shell    zsh/fish + starship + 现代 CLI 工具
  5) 工具     选装开发/网络/编辑器/TTY增强工具 + 命令速查
  6) fbterm   framebuffer 终端:TTF 字体,自启于 tty2-6
MENU
    local ans n
    read -r -p "你的选择 [1 2 3]: " ans
    ans="${ans:-1 2 3}"
    if [ "$ans" = "all" ]; then
      SELECTED="resolution font colors shell tools fbterm"
    else
      for n in ${ans//,/ }; do
        case "$n" in
          1) SELECTED+=" resolution" ;;
          2) SELECTED+=" font" ;;
          3) SELECTED+=" colors" ;;
          4) SELECTED+=" shell" ;;
          5) SELECTED+=" tools" ;;
          6) SELECTED+=" fbterm" ;;
          *) warn "忽略无效选项:$n" ;;
        esac
      done
    fi
  fi
  [ -n "${SELECTED// /}" ] || die "没有选择任何模块,退出。"

  # --- run in a sensible order ----------------------------------------------
  run_if() { case " $SELECTED " in *" $1 "*) "$2" ;; esac; }
  run_if resolution module_resolution
  run_if font       module_font
  run_if colors     module_colors
  run_if shell      module_shell
  run_if tools      module_tools
  run_if fbterm     module_fbterm

  # --- summary --------------------------------------------------------------
  section "完成"
  ok "已执行模块:$SELECTED"
  info "备份目录:$(backup_dir_path)"
  info "还原命令:sudo ./uninstall.sh"
  if [ "$NEED_REBOOT" = "1" ]; then
    warn "分辨率改动需要 ${C_BOLD}重启${C_RESET} 后生效:sudo reboot"
  fi
}
