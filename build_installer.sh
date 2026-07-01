#!/bin/bash
# Builds "GAM Admin Installer.pkg" — a polished macOS installer wizard.
# Share the resulting .pkg with colleagues. They double-click, click Install, done.
set -e
cd "$(dirname "$0")"

APP_NAME="GAM Admin"
INSTALLER_NAME="GAM Admin Installer"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"
VERSION="1.0"
IDENTIFIER="io.aircall.it-admin"
OUT_PKG="$HOME/Desktop/$INSTALLER_NAME.pkg"
ICON_SRC="$(pwd)/installer-icon.png"

echo "Building $INSTALLER_NAME..."

# ── Step 1: Build the .app bundle ─────────────────────────────────────────────
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

cp -r "$APP_BUNDLE" "$PKG_ROOT/Applications/"

# Use the custom icon as the installer background image
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$PKG_RES/background.png"
fi

# ── Step 3: Installer screens ─────────────────────────────────────────────────
echo "Step 3/4 — Writing installer screens..."

cat > "$PKG_RES/welcome.html" << 'WELCOME'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body  { font-family: -apple-system, sans-serif; padding: 24px 28px; color: #111; background: transparent; }
  h2   { font-size: 18px; font-weight: 700; margin: 0 0 14px; color: #002620; }
  p    { font-size: 13px; line-height: 1.65; color: #333; margin: 0 0 12px; }
  .prereq {
    border-left: 3px solid #00c278;
    border-radius: 0 6px 6px 0;
    padding: 12px 16px;
    margin-top: 16px;
    background: rgba(0,194,120,0.10);
  }
  .prereq-title {
    font-size: 11px; font-weight: 700; letter-spacing: 0.1em;
    text-transform: uppercase; color: #00874f; margin-bottom: 6px;
  }
  .prereq-body { font-size: 12.5px; line-height: 1.6; color: #333; }
  @media (prefers-color-scheme: dark) {
    body          { color: #ddd; }
    h2            { color: #00c278; }
    p             { color: #bbb; }
    .prereq-title { color: #00c278; }
    .prereq-body  { color: #bbb; }
  }
</style>
</head>
<body>
  <h2>Welcome to GAM Admin</h2>
  <p>This installer will add <strong>GAM Admin</strong> to your Applications folder &mdash;
  a tool built by the Aircall IT team to manage Google Workspace users and groups
  directly from your Mac.</p>
  <p>Everything runs locally on your machine. No data is sent to any external server.</p>
  <div class="prereq">
    <div class="prereq-title">Before you continue</div>
    <div class="prereq-body">GAM (Google Admin Manager) must be installed and set up on this Mac
    before GAM Admin will work. Your IT administrator will have taken care of this for you.
    If you are unsure, reach out to them before proceeding.</div>
  </div>
</body>
</html>
WELCOME

cat > "$PKG_RES/conclusion.html" << 'CONCLUSION'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body      { font-family: -apple-system, sans-serif; padding: 24px 28px; color: #111; background: transparent; }
  h2        { font-size: 18px; font-weight: 700; margin: 0 0 6px; color: #002620; }
  .subtitle { font-size: 13px; color: #555; margin: 0 0 20px; }
  .step     { display: flex; align-items: flex-start; gap: 12px; margin-bottom: 14px; }
  .num {
    background: #002620; color: white; border-radius: 50%;
    width: 22px; height: 22px; font-size: 11px; font-weight: 700;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0; margin-top: 1px;
  }
  .step-text        { font-size: 13px; line-height: 1.55; color: #333; }
  .step-text strong { color: #111; }
  .note {
    margin-top: 20px; font-size: 12px; color: #777;
    border-top: 1px solid #ddd; padding-top: 14px;
  }
  @media (prefers-color-scheme: dark) {
    body            { color: #ddd; }
    h2              { color: #00c278; }
    .subtitle       { color: #aaa; }
    .num            { background: #00c278; color: #002620; }
    .step-text      { color: #ccc; }
    .step-text strong { color: #eee; }
    .note           { color: #888; border-top-color: #444; }
  }
</style>
</head>
<body>
  <h2>You&#39;re all set!</h2>
  <p class="subtitle">GAM Admin has been installed in your Applications folder.</p>
  <div class="step">
    <div class="num">1</div>
    <div class="step-text">Open <strong>Finder &rarr; Applications</strong> and double-click <strong>GAM Admin</strong>.</div>
  </div>
  <div class="step">
    <div class="num">2</div>
    <div class="step-text">Confirm the <strong>Touch ID</strong> or password prompt &mdash; this keeps the app secure.</div>
  </div>
  <div class="step">
    <div class="num">3</div>
    <div class="step-text">You&#39;re in. Use the sidebar to look up users, manage groups, run offboarding, and more.</div>
  </div>
  <p class="note">If you see a <em>&ldquo;GAM not found&rdquo;</em> warning when the app opens, contact your IT administrator &mdash; a quick setup step is needed before you can get started.</p>
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

# Distribution XML
BACKGROUND_TAG=""
if [ -f "$PKG_RES/background.png" ]; then
  BACKGROUND_TAG='<background file="background.png" alignment="bottomleft" scaling="proportional" mime-type="image/png"/>'
fi

cat > "$WORK_DIR/distribution.xml" << DISTXML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>GAM Admin Installer</title>
    <welcome    file="welcome.html"    mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    ${BACKGROUND_TAG}
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="${IDENTIFIER}"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="${IDENTIFIER}" visible="false">
        <pkg-ref id="${IDENTIFIER}"/>
    </choice>
    <pkg-ref id="${IDENTIFIER}" version="${VERSION}" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
DISTXML

productbuild \
  --distribution "$WORK_DIR/distribution.xml" \
  --resources "$PKG_RES" \
  --package-path "$WORK_DIR" \
  "$OUT_PKG"

# ── Set custom icon on the .pkg file ──────────────────────────────────────────
if [ -f "$ICON_SRC" ]; then
  .venv/bin/python3 - "$ICON_SRC" "$OUT_PKG" << 'PYICON'
import sys
from AppKit import NSImage, NSWorkspace
img = NSImage.alloc().initWithContentsOfFile_(sys.argv[1])
if img:
    NSWorkspace.sharedWorkspace().setIcon_forFile_options_(img, sys.argv[2], 0)
PYICON
fi

echo ""
echo "✓ Installer ready: $OUT_PKG"
echo ""
echo "  Share this file with your colleague."
echo "  They double-click it, click Continue → Install, and GAM Admin"
echo "  appears in their Applications folder."
echo ""
echo "  Reminder: they still need GAM installed and authorised first."
