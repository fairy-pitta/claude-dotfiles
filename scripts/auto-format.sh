#!/bin/bash
# Auto-format script for PostToolUse hook
# This script formats files after they are edited by Claude

# Read the tool result from stdin (JSON format)
INPUT=$(cat)

# Extract the file path from the JSON
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

# If no file path found, exit
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Format based on file type
case "$EXT" in
  js|jsx|ts|tsx|json|css|scss|md|html|yaml|yml)
    # Try to use prettier if available
    if command -v npx &> /dev/null; then
      npx prettier --write "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  py)
    # Try to use black for Python if available
    if command -v black &> /dev/null; then
      black "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

exit 0
