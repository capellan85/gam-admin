#!/bin/bash
# Sets up the GAM Admin app for local development / running from source.
set -e
cd "$(dirname "$0")"

echo "Setting up GAM Admin..."

# ── Python check ──────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found. Install Python 3.11+ from https://python.org"
  exit 1
fi

PY_VER=$(python3 -c 'import sys; print(sys.version_info.minor)')
if [ "$PY_VER" -lt 11 ]; then
  echo "ERROR: Python 3.11+ required (found 3.$PY_VER)"
  exit 1
fi

# ── GAM check ─────────────────────────────────────────────────────────────────
GAM_PATH=""
for candidate in "$HOME/bin/gam7/gam" "$HOME/bin/gam/gam" \
                  "/usr/local/bin/gam" "/opt/homebrew/bin/gam"; do
  if [ -x "$candidate" ]; then
    GAM_PATH="$candidate"
    break
  fi
done
if [ -z "$GAM_PATH" ]; then
  GAM_PATH=$(command -v gam 2>/dev/null || true)
fi

if [ -z "$GAM_PATH" ]; then
  echo ""
  echo "  ⚠  GAM not found."
  echo "     Install GAMADV-XTD3: https://github.com/GAM-team/GAM/wiki/How-to-Install-Advanced-GAM"
  echo "     The app will still launch but won't be functional until GAM is installed."
  echo ""
else
  GAM_VER=$("$GAM_PATH" version 2>&1 | head -1)
  echo "  ✓  GAM found: $GAM_PATH ($GAM_VER)"
fi

# ── Virtual environment ───────────────────────────────────────────────────────
echo "  Creating Python virtual environment..."
python3 -m venv .venv

echo "  Installing dependencies..."
.venv/bin/pip install --quiet --upgrade pip
.venv/bin/pip install --quiet \
  fastapi uvicorn httpx \
  pywebview pyobjc-framework-Cocoa

echo ""
echo "✓ Done! To launch the app:"
echo "  .venv/bin/python app.py"
echo ""
echo "  Or build a shareable .app bundle:"
echo "  ./build_app.sh"
