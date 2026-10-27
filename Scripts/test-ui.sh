#!/bin/sh
# Use an installed iOS simulator without committing a developer's device identifiers.
set -eu
cd "$(dirname "$0")/.."
ui_destination="${LYRX_UI_DESTINATION:-}"
if [ -z "$ui_destination" ]; then
    ui_device_id="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
for runtime, devices in sorted(runtimes.items(), reverse=True):
    if ".iOS-" not in runtime:
        continue
    device = next((d for d in devices if d.get("isAvailable") and d["name"].startswith("iPhone")), None)
    if device:
        print(device["udid"])
        break
else:
    sys.exit("Install an iPhone simulator runtime in Xcode before running UI tests.")
')"
    ui_destination="platform=iOS Simulator,id=$ui_device_id"
fi
ui_build_root="${LYRX_UI_BUILD_ROOT:-${TMPDIR:-/tmp}/lyrx-ui-verification}"
xcodebuild -project Lyrx.xcodeproj -scheme Lyrx -destination "$ui_destination" \
    -derivedDataPath "$ui_build_root" CODE_SIGNING_ALLOWED=NO test
