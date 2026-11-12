#!/bin/bash
set -euo pipefail

action=${1:?record or check required}
app=${2:?app path required}
root=$(cd "$(dirname "$0")/.." && pwd)
stamp=${3:-"$root/build/runtime-validation.sha256"}

fingerprint() {
  for component in \
    "$app/Contents/MacOS/FuckingAdvice" \
    "$app/Contents/Helpers/advice-fetcher" \
    "$app/Contents/PlugIns/FuckingAdviceWidgets.appex/Contents/MacOS/FuckingAdviceWidgets"; do
    codesign -dv --verbose=4 "$component" 2>&1 | awk -F= '/^CDHash=/{print $2}'
  done | shasum -a 256 | awk '{print $1}'
}

case "$action" in
  record)
    fingerprint > "$stamp"
    echo "Recorded runtime validation for $(cat "$stamp")"
    ;;
  check)
    [[ -f "$stamp" ]] || { echo "error: runtime validation stamp is missing" >&2; exit 1; }
    [[ "$(cat "$stamp")" == "$(fingerprint)" ]] || { echo "error: runtime validation stamp does not match this binary" >&2; exit 1; }
    ;;
  *) echo "error: expected record or check" >&2; exit 2 ;;
esac
