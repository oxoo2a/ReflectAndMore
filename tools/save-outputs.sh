#!/usr/bin/env bash
# Run every stage and store its Markdown output as <stage>/output.md.
#   tools/save-outputs.sh            write the files
#   tools/save-outputs.sh --check    compare with the committed files instead (ignores the Java
#                                    version line and benchmark numbers); exit 1 on differences
set -euo pipefail
cd "$(dirname "$0")/.."
check=false
[[ "${1:-}" == "--check" ]] && check=true
status=0
for dir in stage*/; do
  stage="${dir%/}"
  tmp=$(mktemp)
  ./run.sh "$stage" > "$tmp"
  if $check; then
    filter() { grep -v -e '^_Java ' -e 'unnamed module @' -e 'Lambda/0x' -e 'ns per call' -e '^| direct call' -e '^| Method.invoke' -e '^| MethodHandle' "$1" || true; }
    if ! diff -u <(filter "$stage/output.md") <(filter "$tmp") > /dev/null; then
      echo "DIFFERENT: $stage/output.md"
      diff -u <(filter "$stage/output.md") <(filter "$tmp") || true
      status=1
    else
      echo "unchanged: $stage"
    fi
  else
    mv "$tmp" "$stage/output.md"
    echo "wrote $stage/output.md"
  fi
  rm -f "$tmp"
done
exit $status
