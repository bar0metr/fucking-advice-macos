#!/bin/bash
set -euo pipefail

target=${1:?app bundle or binary required}
shift
expected=("$@")
[[ ${#expected[@]} -gt 0 ]] || { echo "error: expected architectures are required" >&2; exit 2; }

if [[ -d "$target" ]]; then
  binaries=(
    "$target/Contents/MacOS/FuckingAdvice"
    "$target/Contents/Helpers/advice-fetcher"
    "$target/Contents/PlugIns/FuckingAdviceWidgets.appex/Contents/MacOS/FuckingAdviceWidgets"
  )
else
  binaries=("$target")
fi

for binary in "${binaries[@]}"; do
  [[ -f "$binary" ]] || { echo "error: binary missing: $binary" >&2; exit 1; }
  read -r -a actual <<<"$(lipo -archs "$binary")"
  [[ ${#actual[@]} -eq ${#expected[@]} ]] || { echo "error: unexpected architectures for $binary: ${actual[*]}" >&2; exit 1; }
  for architecture in "${expected[@]}"; do
    [[ " ${actual[*]} " == *" $architecture "* ]] || { echo "error: $binary lacks $architecture" >&2; exit 1; }
  done
done

echo "Verified architectures (${expected[*]}): $target"
