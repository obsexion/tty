#!/usr/bin/env bash
# install.sh (Debian) — 入口。薄封装:设定路径、载入 core/pkg/模块,交给 core_main。
# 用法见 --help。模块:分辨率 / 字体 / 配色 / Shell / fbterm。
set -euo pipefail

# REPO_ROOT = repo root (this file is at <root>/debian/install.sh).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
DISTRO_NAME="Debian"
HERE="$REPO_ROOT/debian"

source "$REPO_ROOT/shared/common.sh"
source "$HERE/pkg.sh"
# shared modules
source "$REPO_ROOT/shared/modules/resolution.sh"
source "$REPO_ROOT/shared/modules/colors.sh"
source "$REPO_ROOT/shared/modules/fbterm.sh"
# distro-specific modules
source "$HERE/modules/font.sh"
source "$HERE/modules/shell.sh"
# shared entry logic
source "$REPO_ROOT/shared/install-core.sh"

core_main "$@"
