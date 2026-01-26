#!/bin/bash
# Deny-check script for PreToolUse hook
# Based on wasabeef's blog: https://wasabeef.jp/blog/claude-code-secure-bash

# Read the tool input from stdin
INPUT=$(cat)

# Extract the command from the JSON
COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)

# If no command found, allow
if [ -z "$COMMAND" ]; then
  exit 0
fi

# List of dangerous patterns
DANGEROUS_PATTERNS=(
  "rm -rf /"
  "rm -rf /*"
  "chmod 777"
  ":(){ :|:& };:"  # Fork bomb
  "> /dev/sda"
  "mkfs."
  "dd if="
  "curl.*| bash"
  "wget.*| bash"
  "git push.*--force.*main"
  "git push.*--force.*master"
)

# Check each pattern
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: Dangerous command detected: $pattern" >&2
    exit 2  # Exit code 2 blocks the tool execution
  fi
done

exit 0
