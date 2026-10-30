#!/usr/bin/env bash
# Compile and run one stage with nothing but the JDK (no Maven needed).
#
#   ./run.sh 01            run stage01-*
#   ./run.sh stage01-rtti  same, by folder name
#   ./run.sh 01 --foo      extra arguments are passed to the program
#   ./run.sh 05 -Dkey=v    arguments starting with -D, -X or --add-opens go to the JVM
#
# Output goes to <stage>/out/classes. Maven users: mvn -q package && java -jar <stage>/target/*.jar
set -euo pipefail
cd "$(dirname "$0")"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <stage number or folder> [program arguments]" >&2
  echo "stages:" >&2
  ls -d stage*/ | sed 's#/##; s#^#  #' >&2
  exit 1
fi

sel="$1"; shift
if [[ -d "$sel" ]]; then
  stage="${sel%/}"
else
  stage=$(ls -d stage"$(printf '%02d' "$((10#$sel))")"-*/ 2>/dev/null | head -1 | sed 's#/##')
  [[ -n "$stage" ]] || { echo "no stage '$sel'" >&2; exit 1; }
fi

out="$stage/out/classes"
mkdir -p "$out"
# -parameters keeps parameter names for reflection (relevant from stage 02 on)
javac --release 25 -parameters -d "$out" $(find "$stage/src/main/java" -name '*.java')
if [[ -d "$stage/src/main/resources" ]]; then
  cp -R "$stage/src/main/resources/." "$out"/
fi
jvm=(); prog=()
for a in "$@"; do
  case "$a" in -D*|-X*|--add-opens*|--enable-*) jvm+=("$a");; *) prog+=("$a");; esac
done
exec java ${jvm[@]+"${jvm[@]}"} -cp "$out" sa4e.reflect.Main ${prog[@]+"${prog[@]}"}
