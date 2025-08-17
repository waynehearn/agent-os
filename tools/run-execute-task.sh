#!/usr/bin/env bash
# run-execute-task.sh - Minimal per-task runner (script mode)
#
# Parses inputs for spec_folder_path and parent_task_number (or discovers next),
# extracts the parent task block from tasks.md, writes a snippet and summary,
# refreshes manifest for tasks.md, and prints a placeholder execution message.

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

show_help() {
  cat << EOF
Usage: $0 <inputs_file>

Inputs file should contain an [execution_context] with:
  spec_folder_path: @.agent-os/specs/DATE-name
  parent_task_number: N               # optional; if omitted, discover next
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
    if ! grep -q '- \[x\]' <(sed -n "${ln},+20p" "$tasks_file"); then echo "$ln"; break; fi
  done)
  [[ -z "$line" ]] && return 1
  sed -n "${line}p" "$tasks_file" | grep -o '^## Task [0-9][0-9]*' | grep -o '[0-9][0-9]*'
}

main() {
  local input_file="${1:-}"; [[ -z "$input_file" ]] && { show_help; exit 1; }
  [[ -f "$input_file" ]] || { error "Inputs file not found: $input_file"; exit 1; }

  local ctx; ctx=$(sed -n '/\[execution_context\]/,/\[\/execution_context\]/p' "$input_file")
  local spec_folder_path parent_task_number
  spec_folder_path=$(echo "$ctx" | grep 'spec_folder_path:' | sed 's/spec_folder_path: *//;s/"//g' | sed 's/@/./')
  parent_task_number=$(echo "$ctx" | grep 'parent_task_number:' | sed 's/parent_task_number: *//;s/"//g' || true)
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
  write_current_task_snippet "$spec_folder_path" "$tasks_file" "$parent_task_number" || true
  write_tasks_summary_json "$spec_folder_path" "$tasks_file" "$parent_task_number" || true
  refresh_manifest_tasks "$spec_folder_path" || true

  echo "Executing parent task ${parent_task_number} (placeholder)."
  success "Done"
}

main "$@"
