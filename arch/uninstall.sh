#!/usr/bin/env bash
# uninstall.sh (Arch) — restore the changes this tool made (thin wrapper).
# Usage:
#   sudo ./uninstall.sh            restore the most recent backup
#   sudo ./uninstall.sh <backup-dir>  restore a specific backups/<timestamp>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

source "$REPO_ROOT/shared/common.sh"
source "$REPO_ROOT/arch/pkg.sh"
source "$REPO_ROOT/shared/uninstall-core.sh"

uninstall_main "$@"
