#!/usr/bin/env bash
# install.sh (Debian) — entry point. Thin wrapper: set paths, load core/pkg/modules, hand off to core_main.
# See --help for usage. Modules: resolution / font / colors / shell / tools / fbterm.
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
source "$REPO_ROOT/shared/modules/tools.sh"
source "$REPO_ROOT/shared/modules/fbterm.sh"
# distro-specific modules
source "$HERE/modules/font.sh"
source "$HERE/modules/shell.sh"
# shared entry logic
source "$REPO_ROOT/shared/install-core.sh"

core_main "$@"
