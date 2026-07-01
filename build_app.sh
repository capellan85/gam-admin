#!/bin/bash
# Builds a self-contained GAM Admin.app bundle that can be shared with colleagues.
# Each recipient needs their own GAM install + OAuth credentials.
set -e
cd "$(dirname "$0")"
SRC="$(pwd)"
APP_NAME="GAM Admin"
APP_DIR="$HOME/Applications/$APP_NAME.app"
BUNDLE_ID="io.aircall.it-admin"

echo "Building $APP_NAME.app..."

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [ ! -d ".venv" ]; then
  echo "  No .venv found — running install.sh first..."
  bash install.sh
fi

# ── Clean previous build ──────────────────────────────────────────────────────
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# ── Copy source files (no venv — will be created on first launch) ─────────────
echo "  Copying app files..."
APP_RES="$APP_DIR/Contents/Resources/app"
mkdir -p "$APP_RES"
cp app.py auth.py main.py "$APP_RES/"
cp -r static "$APP_RES/static"

# ── Bundle a fresh portable venv (--copies avoids broken symlinks) ────────────
echo "  Creating bundled Python environment..."
python3 -m venv --copies "$APP_RES/.venv"
"$APP_RES/.venv/bin/pip" install --quiet --upgrade pip
"$APP_RES/.venv/bin/pip" install --quiet \
  fastapi uvicorn httpx \
  pywebview pyobjc-framework-Cocoa pyobjc-framework-LocalAuthentication

# ── Launcher script ───────────────────────────────────────────────────────────
LAUNCHER="$APP_DIR/Contents/MacOS/$APP_NAME"
cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$DIR/Resources/app"
PYTHON="$APP_DIR/.venv/bin/python3"

# Recreate venv if Python binary is broken (happens when .app is moved across machines)
if ! "$PYTHON" --version &>/dev/null 2>&1; then
  osascript -e 'display notification "Setting up GAM Admin for the first time…" with title "GAM Admin"'
  python3 -m venv --copies "$APP_DIR/.venv" 2>/dev/null
  "$APP_DIR/.venv/bin/pip" install --quiet --upgrade pip
  "$APP_DIR/.venv/bin/pip" install --quiet \
    fastapi uvicorn httpx pywebview pyobjc-framework-Cocoa pyobjc-framework-LocalAuthentication
fi

exec "$PYTHON" "$APP_DIR/app.py"
LAUNCHER_EOF
chmod +x "$LAUNCHER"

# ── Info.plist ────────────────────────────────────────────────────────────────
cat > "$APP_DIR/Contents/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>GAM Admin</string>
    <key>CFBundleDisplayName</key>
    <string>GAM Admin</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>GAM Admin</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Aircall IT</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
</dict>
</plist>
PLIST_EOF

# ── Icon ──────────────────────────────────────────────────────────────────────
echo "  Generating icon..."
ICON_PNG="$SRC/icon.png"
ICNS="$APP_DIR/Contents/Resources/AppIcon.icns"

if [ -f "$ICON_PNG" ]; then
  ICONSET=$(mktemp -d)/AppIcon.iconset
  mkdir -p "$ICONSET"

  # Square-crop if needed
  W=$(sips -g pixelWidth  "$ICON_PNG" | awk '/pixelWidth/  {print $2}')
  H=$(sips -g pixelHeight "$ICON_PNG" | awk '/pixelHeight/ {print $2}')
  SIDE=$H; [ "$W" -lt "$H" ] && SIDE=$W
  SQUARE=$(mktemp).png
  cp "$ICON_PNG" "$SQUARE"
  sips -c $SIDE $SIDE "$SQUARE" > /dev/null 2>&1

  for size in 16 32 64 128 256 512 1024; do
    sips -z $size $size "$SQUARE" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null 2>&1
  done
  cp "$ICONSET/icon_32x32.png"    "$ICONSET/icon_16x16@2x.png"
  cp "$ICONSET/icon_64x64.png"    "$ICONSET/icon_32x32@2x.png"
  cp "$ICONSET/icon_256x256.png"  "$ICONSET/icon_128x128@2x.png"
  cp "$ICONSET/icon_512x512.png"  "$ICONSET/icon_256x256@2x.png"
  cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

  iconutil -c icns "$ICONSET" -o "$ICNS"
  rm -rf "$(dirname $ICONSET)" "$SQUARE"
  echo "  Icon generated from icon.png"
else
  echo "  Warning: icon.png not found, skipping icon."
fi

# ── Codesign (ad-hoc, removes Gatekeeper quarantine warning for local sharing) ─
echo "  Signing..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo ""
echo "✓ Built: $APP_DIR"
echo ""
echo "  To share with a colleague:"
echo "  1. Zip it:    ditto -c -k --sequesterRsrc '$APP_DIR' ~/Desktop/IT\\ Admin.zip"
echo "  2. Send the zip via Slack / Drive"
echo "  3. They drag GAM Admin.app → /Applications and double-click"
echo "     (First launch may take ~30 seconds to set up Python if venv needs rebuilding)"
echo ""
echo "  Note: each person needs their own GAM install + OAuth credentials."
echo "  GAM install guide: https://github.com/GAM-team/GAM/wiki/How-to-Install-Advanced-GAM"
