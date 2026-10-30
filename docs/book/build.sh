#!/usr/bin/env bash
# Builds the textbook: docs/book/*.typ -> docs/ReflectAndMore.pdf (needs typst, https://typst.app)
set -euo pipefail
cd "$(dirname "$0")"
typst compile --root .. book.typ ../ReflectAndMore.pdf
echo "wrote docs/ReflectAndMore.pdf"
