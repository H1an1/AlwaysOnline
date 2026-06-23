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
    local bundle_id

    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle_path/Contents/Info.plist")"

    for _ in 1 2 3 4 5; do
        clear_bundle_finder_info "$bundle_path"
        if codesign --force --deep --sign - --requirements "=designated => identifier \"$bundle_id\"" "$bundle_path"; then
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

cd "$ROOT_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/AlwaysOnline" "$MACOS_DIR/AlwaysOnline"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"
cp "$ROOT_DIR/Resources/MenuBarIconShake.png" "$RESOURCES_DIR/MenuBarIconShake.png"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/AlwaysOnline"

sign_bundle "$APP_DIR"

rm -f "$ZIP_PATH"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noqtn -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

rm -f "$DMG_RW_PATH" "$DMG_PATH"
hdiutil create \
    -size 32m \
    -fs HFS+ \
    -volname "$VOLUME_NAME" \
    "$DMG_RW_PATH" >/dev/null

MOUNT_POINT=""
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

ditto --norsrc --noextattr --noqtn "$APP_DIR" "$MOUNT_POINT/AlwaysOnline.app"
ln -s /Applications "$MOUNT_POINT/Applications"
mkdir -p "$MOUNT_POINT/.background"
ditto --norsrc --noextattr --noqtn "$DMG_BACKGROUND_PATH" "$MOUNT_POINT/.background/$DMG_BACKGROUND_NAME"
SetFile -a V "$MOUNT_POINT/.background" 2>/dev/null || true

osascript <<APPLESCRIPT
set backgroundPicture to POSIX file "$MOUNT_POINT/.background/$DMG_BACKGROUND_NAME" as alias
tell application "Finder"
    tell disk "$VOLUME_NAME"
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

clear_bundle_finder_info "$MOUNT_POINT/AlwaysOnline.app"
verify_bundle_clean "$MOUNT_POINT/AlwaysOnline.app"
hdiutil detach "$MOUNT_POINT" >/dev/null ||
    hdiutil detach -force "$MOUNT_POINT" >/dev/null
MOUNT_POINT=""

hdiutil convert "$DMG_RW_PATH" -format UDZO -o "$DMG_PATH" >/dev/null
rm -f "$DMG_RW_PATH"
verify_bundle_clean "$APP_DIR"

echo "Built $APP_DIR"
echo "Packaged $ZIP_PATH"
echo "Packaged $DMG_PATH"
