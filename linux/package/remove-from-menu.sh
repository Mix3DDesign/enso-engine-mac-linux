#!/bin/sh
# Removes the Enso Engine entry from your applications menu. Your settings and files are not touched.
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
rm -f "$APPS/enso-engine.desktop"
update-desktop-database "$APPS" 2>/dev/null || true
echo "Enso Engine was removed from your applications menu."
