#!/usr/bin/env bash
# Builds the textbook: docs/book/*.typ -> docs/ReflectAndMore.pdf (needs typst, https://typst.app)
#
# The version line on the title page comes from git: the nearest tag (e.g. 2026W), the commit,
# and "modified" if the working tree has uncommitted changes. Without a tag only the commit is shown.
set -euo pipefail
cd "$(dirname "$0")"

tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
dirty=$(git status --porcelain --untracked-files=no -- .. 2>/dev/null | grep -v 'ReflectAndMore.pdf' | grep -q . && echo ", modified" || true)
if [[ -n "$tag" ]]; then
  version="Version $tag (commit $commit$dirty)"
else
  version="Commit $commit$dirty"
fi
built=$(date +%Y-%m-%d)

typst compile --root .. --input version="$version" --input built="$built" book.typ ../ReflectAndMore.pdf
echo "wrote docs/ReflectAndMore.pdf  [$version, built $built]"
