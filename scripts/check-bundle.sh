#!/bin/bash
set -euo pipefail
app=${1:?app path required}
mode=${2:-signed}
helper="$app/Contents/Helpers/advice-fetcher"
widget="$app/Contents/PlugIns/FuckingAdviceWidgets.appex"
[[ -d "$app" ]] || { echo "error: app bundle missing: $app" >&2; exit 1; }
[[ -x "$helper" ]] || { echo "error: bundled helper missing or not executable" >&2; exit 1; }
[[ -d "$widget" ]] || { echo "error: WidgetKit extension missing" >&2; exit 1; }
file "$helper" | grep -q 'Mach-O' || { echo "error: helper is not Mach-O" >&2; exit 1; }
if [[ "$mode" == signed ]]; then
  codesign --verify --deep --strict --verbose=2 "$app"
  codesign -d --entitlements - "$app" 2>&1 | grep -q 'application-groups' || { echo "error: App Group entitlement missing" >&2; exit 1; }
  [[ -n "${DEVELOPMENT_TEAM:-}" && -n "${APP_GROUP_ID:-}" ]] || { echo "error: signing verification requires DEVELOPMENT_TEAM and APP_GROUP_ID" >&2; exit 1; }
  [[ "$APP_GROUP_ID" == "$DEVELOPMENT_TEAM.fucking-advice-macos" ]] || { echo "error: invalid unprovisioned macOS App Group identifier" >&2; exit 1; }
  for component in "$app" "$widget"; do
    signature=$(codesign -dv --verbose=4 "$component" 2>&1)
    entitlements=$(codesign -d --entitlements - "$component" 2>&1)
    [[ "$signature" == *"TeamIdentifier=$DEVELOPMENT_TEAM"* ]] || { echo "error: component is not signed by team $DEVELOPMENT_TEAM: $component" >&2; exit 1; }
    [[ "$entitlements" == *"$APP_GROUP_ID"* ]] || { echo "error: component lacks App Group $APP_GROUP_ID: $component" >&2; exit 1; }
  done
else
  echo "warning: unsigned diagnostic bundle built; App Group storage and WidgetKit installation are not operational" >&2
fi
echo "Verified bundle structure: $app"
