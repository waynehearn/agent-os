#!/usr/bin/env bash
# run-execute-task.sh - Per-parent task runner with selective-reading + debug tracing
#
# Responsibilities (script-mode, token-efficient):
# - Parse inputs: spec_folder_path, optional parent_task_number, optional debug flags
# - Ensure current parent task snippet exists at [spec]/context/current-task.md
# - Write/update [spec]/context/tasks-summary.json
# - Read [spec]/context/tasks-heuristics.json (if present) to gate API/DB reads
# - Selectively read relevant sections from sub-specs and write compact extracts:
#     - [spec]/context/selected-technical.md
#     - [spec]/context/selected-api.md (when gated true)
#     - [spec]/context/selected-db.md (when gated true)
# - Emit NDJSON debug trace when debug_subagents=true per instructions/core/execute-task.md
# - Refresh manifest for tasks.md so sha256 stays current
# - Print placeholder for TDD execution loop (actual code/test execution is out-of-scope here)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[execute-task]${NC} $*"; }
error() { echo -e "${RED}[execute-task][ERROR]${NC} $*" >&2; }
warning() { echo -e "${YELLOW}[execute-task][WARN]${NC} $*" >&2; }
success() { echo -e "${GREEN}[execute-task][OK]${NC} $*"; }

# --- Minimal JSON-safe helpers ---
json_escape() { sed 's/\\/\\\\/g; s/\"/\\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'; }
now_iso() {
  if date -u +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then date -u +%Y-%m-%dT%H:%M:%SZ; else date +%Y-%m-%dT%H:%M:%SZ; fi
}

show_help() {
  cat << EOF
Usage: $0 <inputs_file>

Inputs file should contain an [execution_context] with:
  spec_folder_path: @.agent-os/specs/DATE-name
  parent_task_number: N               # optional; if omitted, discover next
  debug_subagents: true|false         # optional; default false
  debug_trace_dir: @[spec_folder_path]/debug/exec-trace  # optional
EOF
}

# Helpers (duplicated lightweight versions from execute-tasks.sh)
extract_parent_task_block() {
  local tasks_file="$1"; shift
  local task_number="$1"; shift
  local start end
  start=$(grep -n "^## Task ${task_number}:" "$tasks_file" | cut -d: -f1 | head -1)
  [[ -z "$start" ]] && return 1
  end=$(awk -v s="$start" 'NR>s && /^## Task [0-9]+:/ {print NR; exit}' "$tasks_file")
  if [[ -z "$end" ]]; then end=$(wc -l < "$tasks_file"); else end=$(( end - 1 )); fi
  sed -n "${start},${end}p" "$tasks_file"
}

write_current_task_snippet() {
  local spec_folder="$1" tasks_file="$2" task_number="$3"
  local ctx_dir="$spec_folder/context"; mkdir -p "$ctx_dir"
  local out_file="$ctx_dir/current-task.md"
  if ! extract_parent_task_block "$tasks_file" "$task_number" > "$out_file"; then
    warning "Failed to extract parent task $task_number"
    return 1
  fi
  log "Snippet written: $out_file"
}

write_tasks_summary_json() {
  local spec_folder="$1" tasks_file="$2" task_number="$3"
  local ctx_dir="$spec_folder/context"; mkdir -p "$ctx_dir"
  local out_json="$ctx_dir/tasks-summary.json"
  local title_line task_title block nums sub_count=0 first_sub="" last_sub=""
  title_line=$(grep "^## Task ${task_number}:" "$tasks_file" | head -1)
  task_title=$(echo "$title_line" | sed 's/^## Task [0-9][0-9]*: *//')
  block=$(extract_parent_task_block "$tasks_file" "$task_number" || true)
  nums=$(echo "$block" | grep -E "^### Subtask ${task_number}\.([0-9]+):" | sed -E "s/^### Subtask ${task_number}\.([0-9]+):.*/\1/" || true)
  if [[ -n "${nums}" ]]; then
    sub_count=$(echo "$nums" | wc -l | awk '{print $1}')
    local min max; min=$(echo "$nums" | sort -n | head -1); max=$(echo "$nums" | sort -n | tail -1)
    first_sub="${task_number}.${min}"; last_sub="${task_number}.${max}"
  fi
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  cat > "$out_json" <<JSON
{
  "specFolderPath": "${spec_folder//\\/\/}",
  "updatedAt": "$ts",
  "parentTask": {"number": ${task_number}, "title": "$(echo "$task_title" | sed 's/"/\\"/g')"},
  "subtasks": {"count": ${sub_count}, "hasFirst": $( [[ -n "$first_sub" ]] && echo true || echo false ), "hasLast": $( [[ -n "$last_sub" ]] && echo true || echo false ), "first": "${first_sub}", "last": "${last_sub}"}
}
JSON
  log "Summary written: $out_json"
}

refresh_manifest_tasks() {
  local spec_folder="$1"
  if [[ -f "$SCRIPT_DIR/update-manifest.sh" ]]; then
    bash "$SCRIPT_DIR/update-manifest.sh" "$spec_folder" --files "tasks.md" || warning "manifest refresh failed"
  fi
}

discover_next_parent_task() {
  local tasks_file="$1"
  local line
  line=$(grep -n '^## Task [0-9]' "$tasks_file" | while IFS=: read -r ln _; do
  if ! grep -Fq -- '- [x]' <(sed -n "${ln},+20p" "$tasks_file"); then echo "$ln"; break; fi
  done)
  [[ -z "$line" ]] && return 1
  sed -n "${line}p" "$tasks_file" | grep -o '^## Task [0-9][0-9]*' | grep -o '[0-9][0-9]*'
}

# Read heuristics JSON if present -> sets REQUIRES_API, REQUIRES_DB, API_INDICATORS, DB_INDICATORS
load_heuristics() {
  local spec_folder="$1"
  REQUIRES_API=false; REQUIRES_DB=false
  API_INDICATORS=""; DB_INDICATORS=""
  local hfile="$spec_folder/context/tasks-heuristics.json"
  if [[ -f "$hfile" ]]; then
    if command -v jq >/dev/null 2>&1; then
      REQUIRES_API=$(jq -r '.requires_api_changes // false' "$hfile") || REQUIRES_API=false
      REQUIRES_DB=$(jq -r '.requires_db_changes // false' "$hfile") || REQUIRES_DB=false
      API_INDICATORS=$(jq -r '.indicators.api // [] | join(",")' "$hfile" 2>/dev/null || echo "")
      DB_INDICATORS=$(jq -r '.indicators.db // [] | join(",")' "$hfile" 2>/dev/null || echo "")
    else
      # Fallback: naive check for keywords in file
      grep -qi 'api' "$hfile" && REQUIRES_API=true || true
      grep -qi 'db\|database\|schema' "$hfile" && REQUIRES_DB=true || true
    fi
  fi
}

# Extract parent task title from snippet or tasks.md
parent_task_title() {
  local src_file="$1"
  sed -n '1,3p' "$src_file" | grep -E '^## Task [0-9]+' | sed 's/^## Task [0-9][0-9]*: *//'
}

# Build a regex from title words (letters/numbers, length>=3)
title_to_regex() {
  local title="$1"
  echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]/ /g' | awk '{
    out=""; for(i=1;i<=NF;i++){ if(length($i)>=3){ if(out!="") out=out"|"; out=out $i } }
    if(out=="") out=".*"; print out
  }'
}

# Extract sections from a markdown file whose heading line matches provided regex (case-insensitive)
# Writes to stdout a compact extract with matched sections only.
extract_sections_matching() {
  local file="$1"; shift
  local regex="$1"; shift
  [[ -f "$file" ]] || return 1
  awk -v IGNORECASE=1 -v rx="$regex" '
    BEGIN{ printing=0 }
    /^[#]+ /{
      if(tolower($0) ~ rx){ printing=1; print; next } else { printing=0 }
    }
    { if(printing==1) print }
  ' "$file"
}

# Decide if we should consider API/DB based on heuristics OR scanning the current task snippet
decide_gates_from_snippet() {
  local snippet="$1"
  local lower; lower=$(tr '[:upper:]' '[:lower:]' < "$snippet")
  local api=false db=false
  printf "%s" "$lower" | grep -Ei '(api|endpoint|controller|route|router|openapi|swagger|rest|graphql|(^|[^a-z])get([^a-z]|$)|(^|[^a-z])post([^a-z]|$)|(^|[^a-z])put([^a-z]|$)|(^|[^a-z])patch([^a-z]|$)|(^|[^a-z])delete([^a-z]|$))' >/dev/null && api=true || true
  printf "%s" "$lower" | grep -Ei '(db|database|schema|migration|migrate|table|column|index|constraint|foreign key|sql|ddl|prisma|liquibase|flyway)' >/dev/null && db=true || true
  # Merge with loaded heuristics
  if [[ "$REQUIRES_API" == true ]]; then api=true; fi
  if [[ "$REQUIRES_DB" == true ]]; then db=true; fi
  REQUIRES_API=$api; REQUIRES_DB=$db
}

# Debug trace helpers
TRACE_ENABLED=false
TRACE_DIR=""
TRACE_FILE=""
trace_init() {
  local spec_folder="$1"; local parent_num="$2"; local desired_dir="$3"; local enabled="$4"
  if [[ "$enabled" == "true" ]]; then
    TRACE_ENABLED=true
    if [[ -z "$desired_dir" ]]; then
      TRACE_DIR="$spec_folder/debug/exec-trace"
    else
      # resolve @ and relative
      TRACE_DIR=$(echo "$desired_dir" | sed "s/@//")
      [[ "$TRACE_DIR" == .* ]] && TRACE_DIR="$(cd "$spec_folder" && pwd)/${TRACE_DIR#.}"
    fi
    mkdir -p "$TRACE_DIR"
    TRACE_FILE="$TRACE_DIR/task-${parent_num}.log"
    local ts; ts=$(now_iso)
    echo "{\"ts\":\"$ts\",\"action\":\"task-start\",\"parentTask\":$parent_num}" >> "$TRACE_FILE"
  fi
}
trace_event() {
  [[ "$TRACE_ENABLED" == true ]] || return 0
  local json_line="$1"
  echo "$json_line" >> "$TRACE_FILE"
}

# Write selected extracts to context files
write_selected_extract() {
  local content="$1"; shift
  local out_file="$1"; shift
  if [[ -n "$content" ]]; then
    printf "%s\n" "$content" > "$out_file"
    log "Wrote: $out_file"
  else
    : # nothing to write
  fi
}

main() {
  local input_file="${1:-}"; [[ -z "$input_file" ]] && { show_help; exit 1; }
  [[ -f "$input_file" ]] || { error "Inputs file not found: $input_file"; exit 1; }

  local ctx
  ctx=$(awk 'BEGIN{on=0} /\[execution_context\]/{on=1; next} /\[\/execution_context\]/{on=0; exit} { if(on) print }' "$input_file")
  local spec_folder_path parent_task_number
  spec_folder_path=$(echo "$ctx" | grep 'spec_folder_path:' | sed 's/spec_folder_path: *//;s/"//g' | sed 's/@/./')
  parent_task_number=$(echo "$ctx" | grep 'parent_task_number:' | sed 's/parent_task_number: *//;s/"//g' || true)
  local debug_subagents debug_trace_dir
  debug_subagents=$(echo "$ctx" | grep 'debug_subagents:' | sed 's/debug_subagents: *//;s/\r//;s/\"//g' || true)
  debug_trace_dir=$(echo "$ctx" | grep 'debug_trace_dir:' | sed 's/debug_trace_dir: *//;s/\"//g' | sed 's/@//' || true)
  # Seed a basic pattern from execution_notes single-line if present (very lightweight)
  local exec_notes_pattern
  exec_notes_pattern=$(echo "$ctx" | grep -A 2 '^execution_notes:' | tail -n +2 | head -1 | sed 's/^ *//;s/ *$//' || true)
  if [[ -z "$spec_folder_path" ]]; then error "Missing spec_folder_path in inputs"; exit 1; fi

  # Resolve path
  if [[ "$spec_folder_path" == .* ]]; then spec_folder_path="$(cd "$(dirname "$input_file")" && pwd)/${spec_folder_path#.}"; fi
  [[ -d "$spec_folder_path" ]] || { error "Spec folder not found: $spec_folder_path"; exit 1; }

  local tasks_file="$spec_folder_path/tasks.md"
  [[ -f "$tasks_file" ]] || { error "tasks.md not found: $tasks_file"; exit 1; }

  if [[ -z "$parent_task_number" ]]; then
    parent_task_number=$(discover_next_parent_task "$tasks_file" || true)
  fi
  [[ -n "$parent_task_number" ]] || { warning "No unfinished tasks found"; exit 0; }

  log "Parent task: $parent_task_number"

  # Step 0.9: init debug trace if requested
  trace_init "$spec_folder_path" "$parent_task_number" "$debug_trace_dir" "${debug_subagents:-false}"

  # Ensure snippet + summary + manifest
  write_current_task_snippet "$spec_folder_path" "$tasks_file" "$parent_task_number" || true
  write_tasks_summary_json "$spec_folder_path" "$tasks_file" "$parent_task_number" || true
  refresh_manifest_tasks "$spec_folder_path" || true

  # Load heuristics and decide gates based on snippet
  local snippet="$spec_folder_path/context/current-task.md"
  load_heuristics "$spec_folder_path"
  decide_gates_from_snippet "$snippet"

  # Step 1: understanding (already have snippet); nothing else to do here in script-mode

  # Prepare regex from title for selective reading
  local title regex
  title=$(parent_task_title "$snippet")
  regex=$(title_to_regex "$title")
  [[ -z "$regex" ]] && regex=".*"

  # Step 2: Technical spec selective reading
  local tech_file="$spec_folder_path/sub-specs/technical-spec.md"
  local selected_tech=""
  if [[ -f "$tech_file" ]]; then
    selected_tech=$(extract_sections_matching "$tech_file" "$regex" || true)
    write_selected_extract "$selected_tech" "$spec_folder_path/context/selected-technical.md"
  else
    warning "technical-spec.md not found; skipping"
  fi

  # Trace for Step 2.1 API check/read
  if [[ "$TRACE_ENABLED" == true ]]; then
    local api_gate; api_gate=$( [[ "$REQUIRES_API" == true ]] && echo "true" || echo "false" )
    trace_event "{\"ts\":\"$(now_iso)\",\"step\":2.1,\"action\":\"api-spec-check\",\"gates\":{\"flag\":$api_gate,\"indicators\":\"$({ echo "$API_INDICATORS" | json_escape; })\"}}"
  fi
  local api_file="$spec_folder_path/sub-specs/api-spec.md"
  if [[ "$REQUIRES_API" == true && -f "$api_file" ]]; then
    local selected_api
    selected_api=$(extract_sections_matching "$api_file" "$regex" || true)
    write_selected_extract "$selected_api" "$spec_folder_path/context/selected-api.md"
    [[ "$TRACE_ENABLED" == true ]] && trace_event "{\"ts\":\"$(now_iso)\",\"step\":2.1,\"action\":\"api-spec-read\",\"status\":\"done\"}"
  fi

  # Trace for Step 2.2 DB check/read
  if [[ "$TRACE_ENABLED" == true ]]; then
    local db_gate; db_gate=$( [[ "$REQUIRES_DB" == true ]] && echo "true" || echo "false" )
    trace_event "{\"ts\":\"$(now_iso)\",\"step\":2.2,\"action\":\"db-spec-check\",\"gates\":{\"flag\":$db_gate,\"indicators\":\"$({ echo "$DB_INDICATORS" | json_escape; })\"}}"
  fi
  local db_file="$spec_folder_path/sub-specs/database-schema.md"
  if [[ "$REQUIRES_DB" == true && -f "$db_file" ]]; then
    local selected_db
    selected_db=$(extract_sections_matching "$db_file" "$regex" || true)
    write_selected_extract "$selected_db" "$spec_folder_path/context/selected-db.md"
    [[ "$TRACE_ENABLED" == true ]] && trace_event "{\"ts\":\"$(now_iso)\",\"step\":2.2,\"action\":\"db-spec-read\",\"status\":\"done\"}"
  fi

  # Steps 3-4 (best-practices, code-style) involve subagents; omit in script-mode

  # Step 5-6: Optional TDD loop (behind flag) or placeholders
  if [[ "${ENABLE_TDD_LOOP:-0}" == "1" ]]; then
    [[ "$TRACE_ENABLED" == true ]] && trace_event "{\"ts\":\"$(now_iso)\",\"step\":5,\"action\":\"tdd-loop\",\"status\":\"start\"}"
    local runner_rc=0
    if [[ -x "$SCRIPT_DIR/test-runner.sh" ]]; then
      local tr_args=( --spec-folder "$spec_folder_path" --parent "$parent_task_number" )
      [[ -n "${TEST_PATTERN:-}" ]] && tr_args+=( --pattern "$TEST_PATTERN" ) || true
      [[ -n "$exec_notes_pattern" ]] && tr_args+=( --pattern "$exec_notes_pattern" ) || true
      [[ -n "${TEST_RETRIES:-}" ]] && tr_args+=( --retries "$TEST_RETRIES" ) || true
      # shellcheck disable=SC2068
      bash "$SCRIPT_DIR/test-runner.sh" ${tr_args[@]} || runner_rc=$?
    else
      warning "test-runner.sh not found; skipping TDD loop"
    fi
    local status; status=$([[ $runner_rc -eq 0 ]] && echo success || echo fail)
    [[ "$TRACE_ENABLED" == true ]] && trace_event "{\"ts\":\"$(now_iso)\",\"step\":6,\"action\":\"task-tests\",\"result\":\"$status\"}"
  else
    [[ "$TRACE_ENABLED" == true ]] && trace_event "{\"ts\":\"$(now_iso)\",\"step\":5,\"action\":\"tdd-loop\",\"status\":\"placeholder\"}"
    [[ "$TRACE_ENABLED" == true ]] && trace_event "{\"ts\":\"$(now_iso)\",\"step\":6,\"action\":\"task-tests\",\"status\":\"placeholder\"}"
  fi

  echo "Executing parent task ${parent_task_number} (script-mode ${ENABLE_TDD_LOOP:-0} TDD flag)."
  success "Selective reading complete"
}

main "$@"
