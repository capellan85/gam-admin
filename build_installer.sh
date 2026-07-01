#!/bin/bash
# Builds "IT Admin Installer.pkg" — a standard macOS installer wizard.
# Share the resulting .pkg with colleagues. They double-click, click Install, done.
set -e
cd "$(dirname "$0")"

APP_NAME="IT Admin"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"
VERSION="1.0"
IDENTIFIER="io.aircall.it-admin"
OUT_PKG="$HOME/Desktop/IT Admin Installer.pkg"

echo "Building $APP_NAME installer..."

# ── Step 1: Build the .app bundle first ───────────────────────────────────────
echo ""
echo "Step 1/4 — Building app bundle..."
bash build_app.sh

if [ ! -d "$APP_BUNDLE" ]; then
  echo "ERROR: App bundle not found at $APP_BUNDLE"
  exit 1
fi

# ── Step 2: Create staging area ───────────────────────────────────────────────
echo ""
echo "Step 2/4 — Staging files..."
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

PKG_ROOT="$WORK_DIR/root"
PKG_RES="$WORK_DIR/resources"
mkdir -p "$PKG_ROOT/Applications"
mkdir -p "$PKG_RES"

# Copy the .app into the staging root
cp -r "$APP_BUNDLE" "$PKG_ROOT/Applications/"

# ── Step 3: Installer resources (welcome, conclusion screens) ─────────────────
echo "Step 3/4 — Writing installer screens..."

cat > "$PKG_RES/welcome.html" << 'WELCOME'
<!DOCTYPE html>
<html>
<head>
<style>
  body { font-family: -apple-system, sans-serif; padding: 20px 28px; color: #111; }
  h2 { font-size: 17px; font-weight: 700; margin: 0 0 12px; color: #002620; }
  p  { font-size: 13px; line-height: 1.6; color: #333; margin: 0 0 10px; }
  .note { background: #FFFBEB; border: 1px solid #FDE68A; border-radius: 6px;
          padding: 10px 14px; font-size: 12px; color: #7A5100; margin-top: 14px; }
  .note strong { font-weight: 700; }
</style>
</head>
<body>
<h2>Welcome to IT Admin</h2>
<p>This installer will place <strong>IT Admin.app</strong> in your Applications folder.</p>
<p>IT Admin is an Aircall IT tool for managing Google Workspace — user lookups,
group management, offboarding, Drive and Calendar transfers, and more.</p>
<p>The app runs entirely on your Mac. No data is sent to any server.</p>
<div class="note">
  <strong>Before you begin:</strong> Make sure GAMADV-XTD3 (GAM) is installed and
  authorised on this Mac. If you are unsure, contact your IT administrator.
</div>
</body>
</html>
WELCOME

cat > "$PKG_RES/conclusion.html" << 'CONCLUSION'
<!DOCTYPE html>
<html>
<head>
<style>
  body { font-family: -apple-system, sans-serif; padding: 20px 28px; color: #111; }
  h2 { font-size: 17px; font-weight: 700; margin: 0 0 12px; color: #002620; }
  p  { font-size: 13px; line-height: 1.6; color: #333; margin: 0 0 10px; }
  .step { display: flex; align-items: flex-start; gap: 10px; margin-bottom: 8px; }
  .num { background: #002620; color: white; border-radius: 50%; width: 20px; height: 20px;
         font-size: 11px; font-weight: 700; display: flex; align-items: center;
         justify-content: center; flex-shrink: 0; margin-top: 1px; }
  .step p { margin: 0; }
</style>
</head>
<body>
<h2>Installation complete!</h2>
<p>IT Admin has been installed in your Applications folder. Here's how to get started:</p>
<div class="step"><div class="num">1</div><p>Open <strong>Finder → Applications</strong> and double-click <strong>IT Admin</strong>.</p></div>
<div class="step"><div class="num">2</div><p>Approve the <strong>Touch ID</strong> or password prompt — this keeps the app secure.</p></div>
<div class="step"><div class="num">3</div><p>If you see a <em>"GAM not found"</em> warning, contact your IT administrator to complete the GAM setup.</p></div>
</body>
</html>
CONCLUSION

# ── Step 4: Build the .pkg ─────────────────────────────────────────────────────
echo "Step 4/4 — Packaging..."

COMPONENT_PKG="$WORK_DIR/component.pkg"

pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location "/" \
  "$COMPONENT_PKG"

# Distribution XML — controls the wizard layout
cat > "$WORK_DIR/distribution.xml" << DISTXML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>IT Admin</title>
    <welcome    file="welcome.html"    mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="$IDENTIFIER"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$IDENTIFIER" visible="false">
        <pkg-ref id="$IDENTIFIER"/>
    </choice>
    <pkg-ref id="$IDENTIFIER" version="$VERSION" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
DISTXML

productbuild \
  --distribution "$WORK_DIR/distribution.xml" \
  --resources "$PKG_RES" \
  --package-path "$WORK_DIR" \
  "$OUT_PKG"

echo ""
echo "✓ Installer ready: $OUT_PKG"
echo ""
echo "  Share this file with your colleague."
echo "  They double-click it, click Install, and IT Admin appears in their Applications."
echo ""
echo "  Reminder: they still need GAM installed and authorised."
echo "  GAM guide: https://github.com/GAM-team/GAM/wiki/How-to-Install-Advanced-GAM"
