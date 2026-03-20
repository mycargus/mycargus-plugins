#!/usr/bin/env bash
# Auto-allow Read calls targeting files within this plugin's directory.
# Prevents permission prompts when skills/agents read their own reference files.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Resolve paths to absolute for reliable comparison
RESOLVED_FILE=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
RESOLVED_ROOT=$(realpath "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || echo "$CLAUDE_PLUGIN_ROOT")

if [[ -n "$RESOLVED_FILE" && -n "$RESOLVED_ROOT" && "$RESOLVED_FILE" == "$RESOLVED_ROOT"* ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Plugin reading its own reference file"}}'
fi
