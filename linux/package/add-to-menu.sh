#!/bin/sh
# Adds Enso Engine to your applications menu, pointing at this folder. Nothing is copied or installed.
HERE=$(cd "$(dirname "$0")" && pwd)
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS"
sed -e "s|^Exec=.*|Exec=\"$HERE/blender\" %f|" -e "s|^Icon=.*|Icon=$HERE/enso-engine.png|" "$HERE/enso-engine.desktop" > "$APPS/enso-engine.desktop"
chmod +x "$APPS/enso-engine.desktop"
update-desktop-database "$APPS" 2>/dev/null || true
echo "Enso Engine was added to your applications menu."
echo "If you move this folder, run this script again."
