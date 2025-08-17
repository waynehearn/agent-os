#!/usr/bin/env bash
set -euo pipefail
# spec-validator.sh
# Validates a specification file against the spec-input.schema.json

log() { echo "[spec-validator][$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[spec-validator][ERROR][$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

log "========== Starting spec validation =========="

SPEC_FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../docs/schemas/spec-input.schema.json"

if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
  error "Usage: $0 <spec_file.json>"
  exit 1
fi
if [[ ! -f "$SCHEMA_FILE" ]]; then
  error "Schema file not found at $SCHEMA_FILE"
  exit 1
fi

log "Step 1: Attempting full schema validation with ajv-cli..."
if command -v ajv >/dev/null 2>&1; then
  ajv validate -s "$SCHEMA_FILE" -d "$SPEC_FILE" --strict=false
  if [[ $? -eq 0 ]]; then
    log "Validation passed for $SPEC_FILE"
    log "========== spec validation finished successfully =========="
    exit 0
  else
    error "Validation failed for $SPEC_FILE"
    exit 2
  fi
fi

log "Step 2: Falling back to basic required fields check with jq..."
missing=$(jq -r '
  [
    (if .main_idea? and (.main_idea | length >= 8) then empty else "main_idea" end),
    (if .initial_user_stories? and (.initial_user_stories | length >= 1) then empty else "initial_user_stories" end),
    (if .in_scope? and (.in_scope | length >= 1) then empty else "in_scope" end),
    (if .expected_deliverables? and (.expected_deliverables | length >= 1) then empty else "expected_deliverables" end)
  ] | select(length > 0) | join(", ")
' "$SPEC_FILE")
if [[ -z "$missing" ]]; then
  log "Validation passed for $SPEC_FILE (basic checks only)"
  log "========== spec validation finished successfully =========="
  exit 0
else
  error "Validation failed: missing or invalid fields: $missing"
  exit 2
fi
