#!/usr/bin/env bash
# Builds the EPUB: docs/book/*.typ -> HTML (typst, experimental export) -> docs/ReflectAndMore.epub
# Needs typst, python3 with lxml and Pillow. The version line is derived from git as in build.sh.
set -euo pipefail
cd "$(dirname "$0")"

tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
dirty=$(git status --porcelain --untracked-files=no -- .. 2>/dev/null | grep -v 'ReflectAndMore\.\(pdf\|epub\)' | grep -q . && echo ", modified" || true)
if [[ -n "$tag" ]]; then version="Version $tag (commit $commit$dirty)"; else version="Commit $commit$dirty"; fi
built=$(date +%Y-%m-%d)
out="${1:-../ReflectAndMore.epub}"

work=$(mktemp -d)
typst compile --root .. --format svg figure.typ assets/figure-candidate.svg
typst compile --root .. --features html --format html --input version="$version" --input built="$built" \
    epub.typ "$work/book.html" 2> "$work/warnings.txt" || { cat "$work/warnings.txt"; exit 1; }
python3 -I make_epub.py "$work/book.html" "$out" --version "$version" --built "$built"
rm -rf "$work"
