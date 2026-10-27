#!/usr/bin/env bash
# uninstall.sh (Arch) — 还原本工具做过的改动(薄封装)。
# 用法:
#   sudo ./uninstall.sh            还原最近一次备份
#   sudo ./uninstall.sh <备份目录>  还原指定 backups/<时间戳>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

source "$REPO_ROOT/shared/common.sh"
source "$REPO_ROOT/arch/pkg.sh"
source "$REPO_ROOT/shared/uninstall-core.sh"

uninstall_main "$@"
