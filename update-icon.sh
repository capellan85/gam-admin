#!/bin/bash
SOURCE="$HOME/gam-ui/icon.png"
ICONSET="/tmp/AppIcon.iconset"
DEST="$HOME/Applications/GAM Admin.app/Contents/Resources/AppIcon.icns"
SQUARE="/tmp/icon_square.png"

if [ ! -f "$SOURCE" ]; then
  echo "Error: Save your icon as ~/gam-ui/icon.png first."
  exit 1
fi

# Get dimensions
W=$(sips -g pixelWidth  "$SOURCE" | awk '/pixelWidth/  {print $2}')
H=$(sips -g pixelHeight "$SOURCE" | awk '/pixelHeight/ {print $2}')

# Center-crop to the shortest side to make it square
SIDE=$H
if [ "$W" -lt "$H" ]; then SIDE=$W; fi

cp "$SOURCE" "$SQUARE"
sips -c $SIDE $SIDE "$SQUARE" > /dev/null 2>&1

# Generate all required icon sizes from the square
mkdir -p "$ICONSET"
for size in 16 32 64 128 256 512 1024; do
  sips -z $size $size "$SQUARE" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null 2>&1
done

# @2x variants
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$DEST"
rm -rf "$ICONSET" "$SQUARE"

touch "$HOME/Applications/GAM Admin.app"
killall Finder 2>/dev/null

echo "Done. Icon size: $(ls -lh "$DEST" | awk '{print $5}')"
echo "Remove the app from your Dock and re-add it to refresh the icon."
