#!/usr/bin/env bash
# sudo-nopasswd.sh — 让指定用户使用 sudo 时无需输入密码。
#
# 原理:在 /etc/sudoers.d/ 放一个 drop-in 文件 `<user> ALL=(ALL) NOPASSWD: ALL`。
# 安全保险:
#   - 只对指定用户生效(默认当前 sudo 背后的真实用户)。
#   - 安装前先用 `visudo -c` 校验语法(sudoers 写错会把你锁在 sudo 之外)。
#   - 先写临时文件校验通过,再原子落位,权限 0440。
#   - 原文件若存在会备份;支持 --undo 还原/删除。
#
# ⚠️ 免密 sudo 会降低安全性:任何能用你账号的人都能直接拿到 root。
#    只建议在自己的单人机器/虚拟机上用。
#
# 用法:
#   sudo ./sudo-nopasswd.sh              # 给当前用户开启免密
#   sudo ./sudo-nopasswd.sh -u alice     # 给指定用户开启
#   sudo ./sudo-nopasswd.sh --undo       # 关闭(删除 drop-in)
#   ./sudo-nopasswd.sh --dry-run         # 只打印将做的事,不改系统
#   ./sudo-nopasswd.sh -h

set -euo pipefail

DRY_RUN=0
UNDO=0
USER_ARG=""

usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# Keep the original args so a root re-exec replays them exactly.
ORIG_ARGS=("$@")

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

# 目标用户必须真实存在。
if ! id "$TARGET" >/dev/null 2>&1; then
  echo "用户不存在:$TARGET" >&2; exit 1
fi

DROPIN="/etc/sudoers.d/90-${TARGET}-nopasswd"

# --- helpers -----------------------------------------------------------------
run() {
  if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*"; else "$@"; fi
}

need_root() {
  [ "$DRY_RUN" = "1" ] && return 0
  if [ "$(id -u)" -ne 0 ]; then
    echo "需要 root,正在用 sudo 重新运行…"
    exec sudo "$0" "${ORIG_ARGS[@]}"
  fi
}

# --- undo --------------------------------------------------------------------
if [ "$UNDO" = "1" ]; then
  need_root
  if [ -f "$DROPIN" ]; then
    run rm -f "$DROPIN"
    echo "已删除 $DROPIN —— $TARGET 的 sudo 恢复需要密码。"
  else
    echo "没有找到 $DROPIN,无需处理。"
  fi
  exit 0
fi

# --- enable ------------------------------------------------------------------
need_root

echo "将为用户 '$TARGET' 开启免密 sudo(写入 $DROPIN)。"
echo "⚠️  这意味着该用户执行 sudo 不再需要密码,请确认是你自己的机器。"
if [ "$DRY_RUN" != "1" ]; then
  read -r -p "继续吗? [y/N] " ans
  case "${ans:-n}" in [Yy]*) ;; *) echo "已取消。"; exit 0 ;; esac
fi

LINE="$TARGET ALL=(ALL) NOPASSWD: ALL"

if [ "$DRY_RUN" = "1" ]; then
  echo "[dry-run] 写入 $DROPIN:"
  echo "          $LINE"
  echo "[dry-run] visudo -c 校验后以 0440 落位"
  exit 0
fi

# 备份已存在的同名 drop-in。
if [ -f "$DROPIN" ]; then
  bak="${DROPIN}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$DROPIN" "$bak"
  echo "已备份原文件到 $bak"
fi

# 先写到临时文件并校验,校验通过再原子落位 —— 避免写坏 sudoers 把自己锁死。
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$LINE" > "$tmp"
chmod 0440 "$tmp"

if ! visudo -cf "$tmp" >/dev/null; then
  echo "sudoers 语法校验失败,未做任何改动。" >&2
  exit 1
fi

# 原子落位(同一文件系统上 mv 为原子操作)。
install -m 0440 -o root -g root "$tmp" "$DROPIN"

# 最终再校验一次整体 sudoers 配置。
if ! visudo -c >/dev/null; then
  echo "落位后整体校验失败,正在回滚…" >&2
  rm -f "$DROPIN"
  exit 1
fi

echo "完成:'$TARGET' 现在使用 sudo 无需密码。"
echo "关闭:sudo $0 -u $TARGET --undo"
