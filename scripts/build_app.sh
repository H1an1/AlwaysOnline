#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/AlwaysOnline.app"
ZIP_PATH="$ROOT_DIR/dist/AlwaysOnline.zip"
DMG_RW_PATH="$ROOT_DIR/dist/AlwaysOnline.rw.dmg"
DMG_PATH="$ROOT_DIR/dist/AlwaysOnline.dmg"
VOLUME_NAME="AlwaysOnline"
DMG_BACKGROUND_PATH="$ROOT_DIR/Resources/DmgBackground.png"
DMG_BACKGROUND_NAME="DmgBackground.png"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_ICON_SOURCE_PATH="$ROOT_DIR/Resources/AppIcon.icon"
APP_ICON_NAME="AppIcon"

# Code signing + notarization configuration.
# Override any of these via environment variables when invoking the script, e.g.
#   NOTARIZE=0 ./scripts/build_app.sh   # fast local build: sign only, skip Apple notary
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"
NOTARIZE="${NOTARIZE:-1}"
NOTARIZE_ZIP_PATH="$ROOT_DIR/dist/AlwaysOnline.notarize.zip"

clear_bundle_finder_info() {
    local bundle_path="$1"

    xattr -cr "$bundle_path" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
        xattr -d com.apple.FinderInfo "$bundle_path" 2>/dev/null || true
        if ! xattr -p com.apple.FinderInfo "$bundle_path" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done

    echo "Could not remove com.apple.FinderInfo from $bundle_path" >&2
    xattr -lr "$bundle_path" >&2 || true
    return 1
}

sign_bundle() {
    local bundle_path="$1"

    for _ in 1 2 3 4 5; do
        clear_bundle_finder_info "$bundle_path"
        if codesign --force --options runtime --timestamp \
            --sign "$SIGN_IDENTITY" "$bundle_path"; then
            if verify_bundle_clean "$bundle_path"; then
                return 0
            fi
        fi
        sleep 0.2
    done

    echo "Could not sign $bundle_path cleanly" >&2
    return 1
}

verify_bundle_clean() {
    local bundle_path="$1"

    for _ in 1 2 3 4 5 6 7 8 9 10; do
        clear_bundle_finder_info "$bundle_path"
        if codesign --verify --deep --strict "$bundle_path"; then
            return 0
        fi
        sleep 0.2
    done

    echo "Could not verify $bundle_path cleanly" >&2
    codesign --verify --deep --strict --verbose=4 "$bundle_path" >&2 || true
    xattr -lr "$bundle_path" >&2 || true
    return 1
}

# Submit an artifact (.zip wrapping the .app, or a .dmg) to Apple's notary
# service, wait for the verdict, and fail loudly with the log if it is rejected.
notarize_artifact() {
    local artifact_path="$1"
    local submit_output submission_id status

    echo "Submitting $(basename "$artifact_path") to Apple notary service (this can take a few minutes)..."
    submit_output="$(xcrun notarytool submit "$artifact_path" \
        --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)" || true
    echo "$submit_output"

    submission_id="$(printf '%s\n' "$submit_output" | awk -F'[[:space:]]+' '/^[[:space:]]*id:/ {print $3; exit}')"
    status="$(printf '%s\n' "$submit_output" | awk -F'[[:space:]]+' '/^[[:space:]]*status:/ {print $3}' | tail -1)"

    if [[ "$status" != "Accepted" ]]; then
        echo "Notarization failed for $artifact_path (status: ${status:-unknown})" >&2
        if [[ -n "$submission_id" ]]; then
            echo "Fetching notary log for submission $submission_id:" >&2
            xcrun notarytool log "$submission_id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
        fi
        return 1
    fi
}

# Notarize the .app bundle, then staple the ticket so Gatekeeper accepts it
# offline. The staple writes a file inside the bundle, so it survives the later
# ZIP and DMG packaging steps.
notarize_and_staple_app() {
    local app_path="$1"

    rm -f "$NOTARIZE_ZIP_PATH"
    COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn -c -k --keepParent "$app_path" "$NOTARIZE_ZIP_PATH"
    notarize_artifact "$NOTARIZE_ZIP_PATH"
    rm -f "$NOTARIZE_ZIP_PATH"

    xcrun stapler staple "$app_path"
    spctl --assess --type execute --verbose=4 "$app_path"
}

cd "$ROOT_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/AlwaysOnline" "$MACOS_DIR/AlwaysOnline"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"
cp "$ROOT_DIR/Resources/MenuBarIconShake.png" "$RESOURCES_DIR/MenuBarIconShake.png"
# Compile the Tahoe-native Liquid Glass icon (.icon) into the bundle.
# Emits Resources/Assets.car (macOS 26 glass container, via CFBundleIconName)
# and Resources/AppIcon.icns (fallback for older macOS, via CFBundleIconFile).
ACTOOL_PARTIAL_PLIST="$(mktemp -t actool-partial)"
xcrun actool "$APP_ICON_SOURCE_PATH" \
    --compile "$RESOURCES_DIR" \
    --app-icon "$APP_ICON_NAME" \
    --output-partial-info-plist "$ACTOOL_PARTIAL_PLIST" \
    --minimum-deployment-target 26.0 \
    --platform macosx \
    --target-device mac \
    --development-region en \
    --enable-on-demand-resources NO \
    --output-format human-readable-text --notices --warnings --errors
rm -f "$ACTOOL_PARTIAL_PLIST"
chmod +x "$MACOS_DIR/AlwaysOnline"

sign_bundle "$APP_DIR"

if [[ "$NOTARIZE" == "1" ]]; then
    notarize_and_staple_app "$APP_DIR"
else
    echo "NOTARIZE=0 set: skipping Apple notarization (local build only, not for distribution)."
fi

rm -f "$ZIP_PATH"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

rm -f "$DMG_RW_PATH" "$DMG_PATH"
hdiutil create \
    -size 32m \
    -fs HFS+ \
    -volname "$VOLUME_NAME" \
    "$DMG_RW_PATH" >/dev/null

MOUNT_POINT=""
FINDER_DISK_NAME=""
cleanup_mount() {
    if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
        hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 ||
            hdiutil detach -force "$MOUNT_POINT" >/dev/null 2>&1 ||
            true
    fi
}
trap cleanup_mount EXIT

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW_PATH")"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F'\t' '$NF ~ /^\/Volumes\/AlwaysOnline/ {print $NF; exit}')"
if [[ -z "$MOUNT_POINT" ]]; then
    echo "Could not mount writable DMG" >&2
    exit 1
fi
FINDER_DISK_NAME="$(basename "$MOUNT_POINT")"

ditto --norsrc --noextattr --noqtn "$APP_DIR" "$MOUNT_POINT/AlwaysOnline.app"
ln -s /Applications "$MOUNT_POINT/Applications"
mkdir -p "$MOUNT_POINT/.background"
ditto --norsrc --noextattr --noqtn "$DMG_BACKGROUND_PATH" "$MOUNT_POINT/.background/$DMG_BACKGROUND_NAME"
SetFile -a V "$MOUNT_POINT/.background" 2>/dev/null || true

osascript <<APPLESCRIPT
set backgroundPicture to POSIX file "$MOUNT_POINT/.background/$DMG_BACKGROUND_NAME" as alias
tell application "Finder"
    tell disk "$FINDER_DISK_NAME"
        open
        delay 0.5
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {180, 120, 1100, 690}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 144
        set text size of viewOptions to 16
        set label position of viewOptions to bottom
        set background picture of viewOptions to backgroundPicture
        set position of item "AlwaysOnline.app" of container window to {260, 270}
        set position of item "Applications" of container window to {660, 270}
        try
            set position of item ".background" of container window to {-500, -500}
        end try
        try
            set position of item ".fseventsd" of container window to {-500, -500}
        end try
        update without registering applications
    end tell
    set selection to {}
    delay 1
    tell disk "$VOLUME_NAME"
        delay 1
        close
    end tell
end tell
APPLESCRIPT

for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [[ -s "$MOUNT_POINT/.DS_Store" ]]; then
        break
    fi
    sleep 0.2
done

if [[ ! -s "$MOUNT_POINT/.DS_Store" ]]; then
    echo "Finder layout was not written to $MOUNT_POINT/.DS_Store" >&2
    exit 1
fi

if ! strings "$MOUNT_POINT/.DS_Store" | grep -q "$DMG_BACKGROUND_NAME"; then
    echo "Finder layout does not reference $DMG_BACKGROUND_NAME" >&2
    exit 1
fi

sync

clear_bundle_finder_info "$MOUNT_POINT/AlwaysOnline.app"
verify_bundle_clean "$MOUNT_POINT/AlwaysOnline.app"
hdiutil detach "$MOUNT_POINT" >/dev/null ||
    hdiutil detach -force "$MOUNT_POINT" >/dev/null
MOUNT_POINT=""
FINDER_DISK_NAME=""

hdiutil convert "$DMG_RW_PATH" -format UDZO -o "$DMG_PATH" >/dev/null
rm -f "$DMG_RW_PATH"
verify_bundle_clean "$APP_DIR"

if [[ "$NOTARIZE" == "1" ]]; then
    notarize_artifact "$DMG_PATH"
    xcrun stapler staple "$DMG_PATH"
    # Verify via the stapled notarization ticket. A DMG is not codesigned, so
    # `spctl` would report "no usable signature" here even though Gatekeeper
    # accepts it on download — stapler validate is the correct offline check.
    xcrun stapler validate "$DMG_PATH"
    # Confirm what a downloader actually sees: assess the app the DMG carries.
    spctl --assess --type execute --verbose=4 "$APP_DIR"
fi

echo "Built $APP_DIR"
echo "Packaged $ZIP_PATH"
echo "Packaged $DMG_PATH"
