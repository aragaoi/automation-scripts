#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/bin"

echo "Setting up automation scripts..."
echo ""

if [ ! -d "$TARGET_DIR" ]; then
  echo "Creating $TARGET_DIR directory..."
  mkdir -p "$TARGET_DIR"
fi

echo "Copying scripts to $TARGET_DIR..."

if [ -f "$SCRIPT_DIR/bin/create-pr.sh" ]; then
  cp "$SCRIPT_DIR/bin/create-pr.sh" "$TARGET_DIR/"
  chmod +x "$TARGET_DIR/create-pr.sh"
  echo "✓ Copied create-pr.sh"
else
  echo "✗ Error: create-pr.sh not found in $SCRIPT_DIR/bin/"
  exit 1
fi

if [ -f "$SCRIPT_DIR/bin/git-setup.sh" ]; then
  cp "$SCRIPT_DIR/bin/git-setup.sh" "$TARGET_DIR/"
  chmod +x "$TARGET_DIR/git-setup.sh"
  echo "✓ Copied git-setup.sh"
else
  echo "✗ Error: git-setup.sh not found in $SCRIPT_DIR/bin/"
  exit 1
fi

echo ""
echo "Running git-setup.sh to configure git alias..."
echo ""

"$TARGET_DIR/git-setup.sh"

echo ""
echo "Setup complete!"
echo ""
echo "You can now use: git pr [base-branch]"

