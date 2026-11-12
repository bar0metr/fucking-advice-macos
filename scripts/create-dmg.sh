#!/bin/bash
set -euo pipefail

app=${1:?app path required}
output=${2:?output path required}
version=${3:?version required}
flavor=${4:?arm64 or universal required}
mode=${5:-signed}
root=$(cd "$(dirname "$output")" && pwd)
[[ "$flavor" == arm64 || "$flavor" == universal ]] || { echo "error: invalid DMG flavor: $flavor" >&2; exit 2; }
staging="$root/dmg-staging-$flavor"

[[ -d "$app" ]] || { echo "error: app bundle missing: $app" >&2; exit 1; }
expected="$root/Fucking_Advice_${version}_${flavor}.dmg"
[[ "$mode" == --unsigned ]] && expected="$root/Fucking_Advice_${version}_${flavor}_UNSIGNED.dmg"
[[ "$output" == "$expected" ]] || { echo "error: unexpected DMG output path" >&2; exit 1; }

rm -rf "$staging"
mkdir -p "$staging"
ditto "$app" "$staging/Fucking Advice.app"
ln -s /Applications "$staging/Applications"
rm -f "$output"
volume_name="Fucking Advice $version $flavor"
[[ "$mode" == --unsigned ]] && volume_name="$volume_name UNSIGNED"
hdiutil create -volname "$volume_name" -srcfolder "$staging" -ov -format UDZO "$output" >/dev/null
rm -rf "$staging"
hdiutil verify "$output" >/dev/null
echo "Created $output"
