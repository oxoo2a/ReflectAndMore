#!/usr/bin/env bash
# Show what a stage adds compared with its predecessor:
#   tools/diff-stages.sh 01        diff stage00-* -> stage01-*
#   tools/diff-stages.sh 01 03     diff stage01-* -> stage03-*
# Build output and READMEs are excluded; only source files are compared.
set -euo pipefail
cd "$(dirname "$0")/.."
to="$1"
from="${2:-}"
num() { printf '%02d' "$((10#$1))"; }
if [[ -z "$from" ]]; then from=$(( 10#$to - 1 )); fi
a=$(ls -d stage"$(num "$from")"-*/ | head -1); b=$(ls -d stage"$(num "$to")"-*/ | head -1)
git diff --no-index --stat "${a}src" "${b}src" || true
echo
git diff --no-index "${a}src" "${b}src" || true
