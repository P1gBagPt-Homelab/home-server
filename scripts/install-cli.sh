#!/usr/bin/env bash
# ==============================================================================
# Installer for Project Janus Unified CLI
# Installs / updates /usr/local/bin/janus
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_CLI="${SCRIPT_DIR}/janus"
TARGET_CLI="/usr/local/bin/janus"

if [[ $EUID -ne 0 ]]; then
   echo "Error: This installer must be run as root (use sudo)."
   exit 1
fi

if [[ ! -f "$SOURCE_CLI" ]]; then
    echo "Error: Source CLI not found at ${SOURCE_CLI}"
    exit 1
fi

echo "Installing Project Janus CLI..."
cp -f "$SOURCE_CLI" "$TARGET_CLI"
chmod +x "$TARGET_CLI"

echo "✓ Successfully installed to ${TARGET_CLI}"
echo ""
echo "Try running:"
echo "  janus status"
echo "  janus help"
