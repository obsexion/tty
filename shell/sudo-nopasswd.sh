#!/usr/bin/env bash
# sudo-nopasswd.sh — 让指定用户使用 sudo 时无需输入密码(带真实验证 + 自动回退)。
#
# 做法:优先用 /etc/sudoers.d/ drop-in;装完后**清缓存真测一次**,若被其它
# 规则覆盖(常见:/etc/sudoers 里有匹配规则排在 @includedir 之后),则**自动
# 回退到把规则追加到 /etc/sudoers 末尾**(保证最后匹配生效)。全程 visudo 校验。
#
# ⚠️ 免密 sudo 会降低安全性:任何能用你账号的人都能直接拿到 root。
#    只建议在自己的单人机器/虚拟机上用。
#
# 用法:
#   sudo ./sudo-nopasswd.sh              # 给当前用户开启免密
#   sudo ./sudo-nopasswd.sh -u alice     # 给指定用户开启
#   sudo ./sudo-nopasswd.sh --undo       # 关闭(清掉 drop-in 与主 sudoers 里的规则)
#   ./sudo-nopasswd.sh --dry-run         # 只打印将做的事,不改系统
#   ./sudo-nopasswd.sh -h

set -euo pipefail

DRY_RUN=0
UNDO=0
USER_ARG=""
ORIG_ARGS=("$@")

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# --- parse args --------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -u|--user)  USER_ARG="${2:-}"; shift 2 ;;
    --undo)     UNDO=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    -h|--help)  usage 0 ;;
    *) echo "未知参数:$1(-h 看用法)" >&2; exit 2 ;;
  esac
done

# --- resolve target user (the real human, not root) --------------------------
if [ -n "$USER_ARG" ]; then
  TARGET="$USER_ARG"
elif [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  TARGET="$SUDO_USER"
else
  TARGET="$(logname 2>/dev/null || true)"
fi
[ -n "$TARGET" ] || { echo "无法确定目标用户,请用 -u <用户名> 指定。" >&2; exit 1; }
id "$TARGET" >/dev/null 2>&1 || { echo "用户不存在:$TARGET" >&2; exit 1; }

SUDOERS="/etc/sudoers"
DROPIN="/etc/sudoers.d/99-${TARGET}-nopasswd"     # 99- 让它排到 drop-in 靠后
LEGACY_DROPIN="/etc/sudoers.d/90-${TARGET}-nopasswd"
MARKER="# tty-nopasswd: ${TARGET}"                # 主 sudoers 里的标记,便于 --undo
RULE="${TARGET} ALL=(ALL:ALL) NOPASSWD: ALL"
BACKUP_DIR="/var/backups/sudo-nopasswd"

# --- helpers -----------------------------------------------------------------
run() { if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*"; else "$@"; fi; }

need_root() {
  [ "$DRY_RUN" = "1" ] && return 0
  if [ "$(id -u)" -ne 0 ]; then
    echo "需要 root,正在用 sudo 重新运行…"
    exec sudo "$0" "${ORIG_ARGS[@]}"
  fi
}

# 真正验证:以目标用户身份、清掉缓存后测 sudo 是否免密。0=免密生效。
verify_nopasswd() {
  [ "$DRY_RUN" = "1" ] && return 0
  runuser -l "$TARGET" -c 'sudo -k; sudo -n true' >/dev/null 2>&1
}

backup_sudoers() {
  run mkdir -p "$BACKUP_DIR"
  run cp -a "$SUDOERS" "$BACKUP_DIR/sudoers.$(date +%Y%m%d-%H%M%S)"
}

# 写一个 sudoers 文件前先在临时文件上 visudo 校验,过了才原子落位。
install_validated() {  # <content-producer-cmd writes to $1> <dest> <mode>
  local dest="$2" mode="$3" tmp
  tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN
  "$1" "$tmp"
  chmod "$mode" "$tmp"
  if ! visudo -cf "$tmp" >/dev/null; then
    echo "visudo 校验失败,未改动 $dest。" >&2
    return 1
  fi
  install -m "$mode" -o root -g root "$tmp" "$dest"
}

# 内容生产者:drop-in(单行规则)
_gen_dropin() { printf '%s\n' "$RULE" > "$1"; }
# 内容生产者:主 sudoers 追加(先去掉旧标记块,再在末尾加)
_gen_main_append() {
  cp -a "$SUDOERS" "$1"
  sed -i "/^${MARKER}$/,+1d" "$1" 2>/dev/null || true
  printf '\n%s\n%s\n' "$MARKER" "$RULE" >> "$1"
}

append_to_main() {
  backup_sudoers
  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] 在 $SUDOERS 末尾追加(visudo 校验后):"
    echo "          $RULE"
    return 0
  fi
  install_validated _gen_main_append "$SUDOERS" 0440
}

# 返回 0 = 确实删了;返回 1 = 没有本工具的规则可删。
remove_from_main() {
  [ -f "$SUDOERS" ] || return 1
  grep -q "^${MARKER}$" "$SUDOERS" 2>/dev/null || return 1
  backup_sudoers
  if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] 从 $SUDOERS 删除本工具的规则块"; return 0; fi
  install_validated _gen_main_append_removed "$SUDOERS" 0440
}
_gen_main_append_removed() { cp -a "$SUDOERS" "$1"; sed -i "/^${MARKER}$/,+1d" "$1"; }

# --- undo --------------------------------------------------------------------
if [ "$UNDO" = "1" ]; then
  need_root
  removed=0
  for f in "$DROPIN" "$LEGACY_DROPIN" "$LEGACY_DROPIN".bak.* "$DROPIN".bak.*; do
    [ -e "$f" ] || continue
    run rm -f "$f"; removed=1
  done
  if remove_from_main; then removed=1; fi
  if [ "$removed" = "1" ]; then
    echo "已移除 $TARGET 的免密规则 —— 以后 sudo 需要密码。"
  else
    echo "没有找到本工具为 $TARGET 设置的免密规则,无需处理。"
  fi
  exit 0
fi

# --- enable ------------------------------------------------------------------
need_root

echo "将为用户 '$TARGET' 开启免密 sudo。"
echo "⚠️  该用户执行 sudo 将不再需要密码,请确认是你自己的机器。"
if [ "$DRY_RUN" != "1" ]; then
  read -r -p "继续吗? [y/N] " ans
  case "${ans:-n}" in [Yy]*) ;; *) echo "已取消。"; exit 0 ;; esac
fi

# 1) 优先 drop-in
echo "[1/2] 写入 drop-in:$DROPIN"
if [ "$DRY_RUN" = "1" ]; then
  echo "[dry-run] 写入 $DROPIN(visudo 校验后,0440):$RULE"
  echo "[dry-run] 然后清缓存真测;若被覆盖则回退追加 $SUDOERS 末尾"
  exit 0
fi
install_validated _gen_dropin "$DROPIN" 0440

if verify_nopasswd; then
  echo "完成:'$TARGET' 现在使用 sudo 无需密码(drop-in 生效)。"
  echo "关闭:sudo $0 -u $TARGET --undo"
  exit 0
fi

# 2) drop-in 被覆盖 → 回退到主 sudoers 末尾(保证最后匹配生效)
echo "[2/2] drop-in 未生效(被其它规则覆盖),回退:追加到 $SUDOERS 末尾…"
append_to_main
# 主 sudoers 已是权威规则,删掉 drop-in 避免重复来源
run rm -f "$DROPIN"

if verify_nopasswd; then
  echo "完成:'$TARGET' 现在使用 sudo 无需密码(写入 $SUDOERS 末尾)。"
  echo "备份目录:$BACKUP_DIR   关闭:sudo $0 -u $TARGET --undo"
else
  echo "仍未生效。请检查 /etc/sudoers 是否有更靠后的规则,或把下面这行手动放到最末尾:" >&2
  echo "  $RULE" >&2
  exit 1
fi
