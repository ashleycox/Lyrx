#!/bin/sh
# Keep generated files outside synced folders, where Finder metadata can break signing.
set -eu
cd "$(dirname "$0")/.."
verification_root="${LYRX_BUILD_ROOT:-${TMPDIR:-/tmp}/lyrx-verification}"
python3 Scripts/check-repository.py
swift test --scratch-path "$verification_root/tests"
xcodebuild -project Lyrx.xcodeproj -scheme Lyrx -destination 'platform=macOS' \
    -derivedDataPath "$verification_root/mac" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Lyrx.xcodeproj -scheme Lyrx -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$verification_root/ios" CODE_SIGNING_ALLOWED=NO build
