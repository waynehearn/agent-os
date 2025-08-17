#!/usr/bin/env bash
set -euo pipefail
# execute-tasks.sh
# Orchestrates the execute-tasks process by invoking sub-scripts and validating input.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { echo "[execute-tasks][$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[execute-tasks][ERROR][$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

log "========== Starting execute-tasks =========="

# Set the initial tasks input file path from the first argument
TASKS_INPUT_FILE="$1"
if [ -z "$TASKS_INPUT_FILE" ]; then
  error "Usage: $0 <path_to_tasks_input_file>"
  exit 1
fi

# Ensure the tasks input file exists
if [ ! -f "$TASKS_INPUT_FILE" ]; then
  error "Tasks input file not found at '$TASKS_INPUT_FILE'"
  exit 1
fi

if [ -f "$SCRIPT_DIR/tasks-validator.sh" ]; then
  log "Step 1: Validating tasks input..."
  "$SCRIPT_DIR/tasks-validator.sh" "$TASKS_INPUT_FILE"
  if [ $? -ne 0 ]; then
    error "Tasks validation failed. See errors above."
    exit 1
  fi
  log "Validation complete."
else
  log "Warning: tasks-validator.sh not found. Skipping validation."
fi

log "Step 2: Executing tasks..."
cat "$TASKS_INPUT_FILE"
log "========== execute-tasks process finished successfully =========="
