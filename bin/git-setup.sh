#!/bin/bash

set -e

SCRIPT_PATH="$HOME/bin/create-pr.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "Error: $SCRIPT_PATH not found"
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is not installed"
  exit 1
fi

echo "Setting up git alias for create-pr.sh..."

git config --global alias.pr "!f() { $SCRIPT_PATH \"\$@\"; }; f"

if git config --global --get alias.pr > /dev/null; then
  echo "✓ Git alias 'pr' configured successfully"
  echo ""
  echo "Usage: git pr [base-branch]"
  echo "Example: git pr develop"
else
  echo "Error: Failed to configure git alias"
  exit 1
fi

