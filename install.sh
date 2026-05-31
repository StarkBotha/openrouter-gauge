#!/bin/bash
set -e

INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/com.stark.openrouter-gauge"
SRC_DIR="$(cd "$(dirname "$0")/package" && pwd)"

echo "Source:      $SRC_DIR"
echo "Destination: $INSTALL_DIR"
echo ""

# Remove old installation if exists
rm -rf "$INSTALL_DIR"

# Create target directory
mkdir -p "$INSTALL_DIR"

# Copy all files
cp -r "$SRC_DIR"/* "$INSTALL_DIR/"

echo "Installation complete!"
echo ""
echo "Installed files:"
find "$INSTALL_DIR" -type f | sort
echo ""
echo "To use: Right-click your KDE panel > Add Widgets > search 'OpenRouter'"
echo "Then configure your API key in widget settings (right-click widget > Configure)"
