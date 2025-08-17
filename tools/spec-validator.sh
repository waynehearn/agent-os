#!/usr/bin/env bash
set -euo pipefail
# spec-validator.sh
# Validates a specification file against the spec-input.schema.json

SPEC_FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../docs/schemas/spec-input.schema.json"

if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "Usage: $0 <spec_file.json>" >&2
  exit 1
fi
if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "Error: Schema file not found at $SCHEMA_FILE" >&2
  exit 1
fi

# Try to use ajv-cli if available for full JSON Schema validation
if command -v ajv >/dev/null 2>&1; then
  ajv validate -s "$SCHEMA_FILE" -d "$SPEC_FILE" --strict=false
  if [[ $? -eq 0 ]]; then
    echo "Validation passed for $SPEC_FILE"
    exit 0
  else
    echo "Validation failed for $SPEC_FILE" >&2
    exit 2
  fi
fi

# Fallback: basic required fields check with jq
missing=$(jq -r '
  [
    (if .main_idea? and (.main_idea | length >= 8) then empty else "main_idea" end),
    (if .initial_user_stories? and (.initial_user_stories | length >= 1) then empty else "initial_user_stories" end),
    (if .in_scope? and (.in_scope | length >= 1) then empty else "in_scope" end),
    (if .expected_deliverables? and (.expected_deliverables | length >= 1) then empty else "expected_deliverables" end)
  ] | select(length > 0) | join(", ")
' "$SPEC_FILE")
if [[ -z "$missing" ]]; then
  echo "Validation passed for $SPEC_FILE (basic checks only)"
  exit 0
else
  echo "Validation failed: missing or invalid fields: $missing" >&2
  exit 2
fi
