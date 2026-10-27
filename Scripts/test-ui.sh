#!/bin/sh
# Run one focused check by default; reuse verification builds and avoid simulator clones.
set -eu
cd "$(dirname "$0")/.."

usage() {
    echo "Usage: Scripts/test-ui.sh [macOS|iOS] [smoke|focus|settings|large-text|all]"
    echo "Defaults: macOS smoke. focus is Mac-only; settings and large-text are iOS-only."
}
if [ "${1:-}" = "--help" ]; then usage; exit 0; fi
if [ "$#" -gt 2 ]; then usage >&2; exit 2; fi
ui_platform="${1:-macOS}"
ui_scope="${2:-smoke}"
case "$ui_platform" in
    macOS) ui_build_subdir=mac ;;
    iOS) ui_build_subdir=ios ;;
    *) usage >&2; exit 2 ;;
esac
case "$ui_scope" in
    smoke) ui_test=testSearchAndLineNavigation ;;
    focus) ui_test=testBrowsingTableKeepsKeyboardFocus ;;
    settings) ui_test=testProviderProtectionAndPlatformCopy ;;
    large-text) ui_test=testLargestTextKeepsReadingControlsReachable ;;
    all) ui_test= ;;
    *) usage >&2; exit 2 ;;
esac
case "$ui_platform:$ui_scope" in
    iOS:focus|macOS:settings|macOS:large-text) usage >&2; exit 2 ;;
esac

ui_destination="${LYRX_UI_DESTINATION:-}"
if [ -n "$ui_destination" ]; then
    case "$ui_platform:$ui_destination" in
        macOS:platform=macOS|macOS:platform=macOS,*|iOS:platform=iOS\ Simulator,*) ;;
        *) echo "LYRX_UI_DESTINATION must match the requested platform." >&2; exit 2 ;;
    esac
fi
if [ -z "$ui_destination" ] && [ "$ui_platform" = macOS ]; then
    ui_destination=platform=macOS
fi
if [ -z "$ui_destination" ]; then
    ui_device_id="$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
runtimes = json.load(sys.stdin)["devices"]
candidates = []
for runtime, devices in runtimes.items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(map(int, re.findall(r"\d+", runtime)))
    if version < (26,):
        continue
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append((device["state"] == "Booted", version, device["udid"]))
if not candidates:
    sys.exit("Install a compatible iPhone simulator runtime in Xcode before running UI tests.")
print(max(candidates)[2])
')"
    ui_destination="platform=iOS Simulator,id=$ui_device_id"
fi
verification_root="${LYRX_BUILD_ROOT:-${TMPDIR:-/tmp}/lyrx-verification}"
ui_build_root="${LYRX_UI_BUILD_ROOT:-$verification_root/$ui_build_subdir}"
set -- -project Lyrx.xcodeproj -scheme Lyrx -destination "$ui_destination" \
    -derivedDataPath "$ui_build_root" -destination-timeout 20 \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 60 \
    -maximum-test-execution-time-allowance 60 -collect-test-diagnostics on-failure
if [ -n "$ui_test" ]; then
    set -- "$@" "-only-testing:LyrxUITests/LyrxUITests/$ui_test"
fi
echo "UI check: $ui_platform / $ui_scope (build directory: $ui_build_root)"
exec xcodebuild "$@" CODE_SIGNING_ALLOWED=NO test
