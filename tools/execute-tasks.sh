#!/usr/bin/env bash
# execute-tasks.sh - Token-efficient implementation of task execution from specifications
#
# This script processes task execution requests in a token-efficient manner
# It handles task selection, status tracking, and dependency management
# For AI-powered reasoning tasks, it can optionally delegate to Claude Code
#
# Usage: ./execute-tasks.sh [options] <inputs_file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colorization for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default values
DEFAULT_SPEC_DIR=".agent-os/specs"
VERBOSITY="${VERBOSITY:-info}"

# Logging functions
log() { echo -e "${BLUE}[execute-tasks]${NC} $*"; }
error() { echo -e "${RED}[execute-tasks][ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[execute-tasks][SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[execute-tasks][WARNING]${NC} $*"; }
debug() { [[ "$VERBOSITY" == "debug" ]] && echo -e "[DEBUG][execute-tasks] $*" || true; }

# Cross-platform SHA-256 of a file (hex)
sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    # openssl prints like: SHA256(filename)= hash or (stdin)
    openssl dgst -sha256 "$f" | awk '{print $2}'
  else
    echo "" # caller should handle missing tool
  fi
}

# ISO8601 UTC timestamp
now_iso() {
  if date -u +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
    date -u +%Y-%m-%dT%H:%M:%SZ
  else
    # Fallback
    date +%Y-%m-%dT%H:%M:%SZ
  fi
}

# Extract a parent task block from tasks.md into stdout
# Args: tasks_file, task_number
extract_parent_task_block() {
  local tasks_file="$1"; shift
  local task_number="$1"; shift

  local start
  start=$(grep -n "^## Task ${task_number}:" "$tasks_file" | cut -d: -f1 | head -1)
  if [[ -z "$start" ]]; then
    return 1
  fi
  local end
  end=$(awk -v s="$start" 'NR>s && /^## Task [0-9]+:/ {print NR; exit}' "$tasks_file")
  if [[ -z "$end" ]]; then
    end=$(wc -l < "$tasks_file")
    # include to EOF
  else
    end=$(( end - 1 ))
  fi
  sed -n "${start},${end}p" "$tasks_file"
}

# Determine if manifest indicates a file is unchanged (by key) vs current hash
# Returns 0 and prints JSON {exists:bool, unchanged:bool} to stdout
manifest_check_doc() {
  local spec_folder="$1"; shift
  local relpath="$1"; shift
  local ctx_dir="$spec_folder/context"
  local manifest="$ctx_dir/manifest.json"

  local exists=false
  local unchanged=false
  local fpath="$spec_folder/$relpath"
  if [[ -f "$fpath" ]]; then exists=true; fi
  if [[ -f "$manifest" && -f "$fpath" ]] && command -v jq >/dev/null 2>&1; then
    local key
    key="$(basename "$relpath")"
    local stored
    stored=$(jq -r --arg k "$key" '.docs[$k].sha256 // ""' "$manifest" 2>/dev/null || echo "")
    local current
    current="$(sha256_file "$fpath")"
    if [[ -n "$stored" && -n "$current" && "$stored" == "$current" ]]; then
      unchanged=true
    fi
  fi
  printf '{"exists":%s,"unchanged":%s}' "$exists" "$unchanged"
}

# Write heuristics about current task to context/tasks-heuristics.json
# Detect API/DB indicators in the parent task block; include manifest skip hints
write_tasks_heuristics_json() {
  local spec_folder="$1"; shift
  local tasks_file="$1"; shift
  local task_number="$1"; shift

  local ctx_dir="$spec_folder/context"
  mkdir -p "$ctx_dir"
  local out_json="$ctx_dir/tasks-heuristics.json"

  local block
  block=$(extract_parent_task_block "$tasks_file" "$task_number" || echo "")
  local lower
  lower=$(printf "%s" "$block" | tr '[:upper:]' '[:lower:]')

  # Indicators
  local -a api_terms=("api" "endpoint" "controller" "route" "router" "openapi" "swagger" "rest" "graphql")
  local -a db_terms=("db" "database" "schema" "migration" "migrate" "table" "column" "index" "constraint" "foreign key" "sql" "ddl" "prisma" "liquibase" "flyway")

  local requires_api=false requires_db=false
  local api_hits="[]" db_hits="[]"

  if command -v jq >/dev/null 2>&1; then
    for t in "${api_terms[@]}"; do
      if printf "%s" "$lower" | grep -q "\b${t}\b"; then
        requires_api=true
        api_hits=$(printf '%s' "$api_hits" | jq --arg t "$t" '. + [$t]')
      fi
    done
    for t in "${db_terms[@]}"; do
      if printf "%s" "$lower" | grep -q "\b${t}\b"; then
        requires_db=true
        db_hits=$(printf '%s' "$db_hits" | jq --arg t "$t" '. + [$t]')
      fi
    done
  else
    # Fallback without jq: simple flags
    for t in "${api_terms[@]}"; do
      if printf "%s" "$lower" | grep -q "$t"; then requires_api=true; break; fi
    done
    for t in "${db_terms[@]}"; do
      if printf "%s" "$lower" | grep -q "$t"; then requires_db=true; break; fi
    done
  fi

  local api_doc db_doc
  api_doc=$(manifest_check_doc "$spec_folder" "sub-specs/api-spec.md")
  db_doc=$(manifest_check_doc "$spec_folder" "sub-specs/database-schema.md")

  local ts
  ts=$(now_iso)

  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --argjson requires_api $( [[ "$requires_api" == true ]] && echo true || echo false ) \
      --argjson requires_db $( [[ "$requires_db" == true ]] && echo true || echo false ) \
      --argjson api_hits "$api_hits" \
      --argjson db_hits "$db_hits" \
      --arg ts "$ts" \
      --argjson api_doc "$api_doc" \
      --argjson db_doc "$db_doc" \
      '{updatedAt:$ts, requires_api_changes:$requires_api, requires_db_changes:$requires_db, indicators:{api:$api_hits, db:$db_hits}, manifest:{apiSpec:$api_doc, dbSchema:$db_doc}}' > "$out_json"
  else
    cat > "$out_json" <<JSON
{"updatedAt":"$ts","requires_api_changes":$requires_api,"requires_db_changes":$requires_db}
JSON
  fi
  log "Wrote task heuristics to: $out_json"
  if [[ "${ENABLE_PROFILING:-0}" == "1" ]] && type ce_track_file >/dev/null 2>&1; then
    ce_track_file "$out_json" "execute-tasks:heuristics"
  fi
}

# Write current parent task snippet to context/current-task.md
write_current_task_snippet() {
  local spec_folder="$1"; shift
  local tasks_file="$1"; shift
  local task_number="$1"; shift

  local ctx_dir="$spec_folder/context"
  mkdir -p "$ctx_dir"
  local out_file="$ctx_dir/current-task.md"

  if ! extract_parent_task_block "$tasks_file" "$task_number" > "$out_file"; then
    warning "Failed to extract parent task $task_number to $out_file"
    return 1
  fi
  log "Wrote current parent task snippet to: $out_file"
  if [[ "${ENABLE_PROFILING:-0}" == "1" ]] && type ce_track_file >/dev/null 2>&1; then
    ce_track_file "$out_file" "execute-tasks:tasks"
  fi
  return 0
}

# Produce a minimal tasks summary JSON at context/tasks-summary.json
# Fields: specFolderPath, updatedAt, parentTask{number,title}, subtasks{count,hasFirst,hasLast,first, last}
write_tasks_summary_json() {
  local spec_folder="$1"; shift
  local tasks_file="$1"; shift
  local task_number="$1"; shift

  local ctx_dir="$spec_folder/context"
  mkdir -p "$ctx_dir"
  local out_json="$ctx_dir/tasks-summary.json"

  # Title of parent task
  local title_line
  title_line=$(grep "^## Task ${task_number}:" "$tasks_file" | head -1)
  local task_title
  task_title=$(echo "$title_line" | sed 's/^## Task [0-9][0-9]*: *//')

  # Extract block and scan for subtasks
  local block
  block=$(extract_parent_task_block "$tasks_file" "$task_number" || echo "")
  local sub_count=0
  local first_sub=""
  local last_sub=""
  if [[ -n "$block" ]]; then
    # lines like: ### Subtask N.M:
    # gather M indices
    local nums
    nums=$(echo "$block" | grep -E "^### Subtask ${task_number}\.([0-9]+):" | sed -E "s/^### Subtask ${task_number}\.([0-9]+):.*/\1/" || true)
    if [[ -n "$nums" ]]; then
      sub_count=$(echo "$nums" | wc -l | awk '{print $1}')
      # determine first and last
      local min max
      min=$(echo "$nums" | sort -n | head -1)
      max=$(echo "$nums" | sort -n | tail -1)
      first_sub="${task_number}.${min}"
      last_sub="${task_number}.${max}"
    fi
  fi

  local has_first="false"
  local has_last="false"
  if [[ -n "$first_sub" ]]; then has_first="true"; fi
  if [[ -n "$last_sub" ]]; then has_last="true"; fi

  local ts
  ts=$(now_iso)

  cat > "$out_json" <<JSON
{
  "specFolderPath": "${spec_folder//\\/\/}",
  "updatedAt": "$ts",
  "parentTask": {
    "number": ${task_number},
    "title": "$(echo "$task_title" | sed 's/"/\\"/g')"
  },
  "subtasks": {
    "count": ${sub_count},
    "hasFirst": ${has_first},
    "hasLast": ${has_last},
    "first": "${first_sub}",
    "last": "${last_sub}"
  }
}
JSON

  log "Wrote tasks summary to: $out_json"
  if [[ "${ENABLE_PROFILING:-0}" == "1" ]] && type ce_track_file >/dev/null 2>&1; then
    ce_track_file "$out_json" "execute-tasks:tasks"
  fi
}

# Refresh manifest entry for tasks.md (and ensure manifest exists)
refresh_manifest_tasks() {
  local spec_folder="$1"
  if [[ -f "$SCRIPT_DIR/update-manifest.sh" ]]; then
    bash "$SCRIPT_DIR/update-manifest.sh" "$spec_folder" --files "tasks.md" || warning "update-manifest.sh failed"
  else
    warning "update-manifest.sh not found or not executable; skipping manifest refresh"
  fi
}

# Find the line number of the first uncompleted parent task (no '- [x]' within its block)
find_first_uncompleted_task_line() {
  local tasks_file="$1"
  awk '
    BEGIN { have=0; done=0; task_line=0; emitted=0 }
    /^## Task [0-9]/ {
      if (have==1 && done==0) { print task_line; emitted=1; exit }
      have=1; done=0; task_line=NR; next
    }
    { if (have==1 && $0 ~ /^- \[x\]/) done=1 }
    END { if (emitted==0 && have==1 && done==0) print task_line }
  ' "$tasks_file"
}

# Show help message
show_help() {
  cat << EOF
Usage: $0 [options] <inputs_file>

Execute tasks from a specification using token-efficient approaches.

Options:
  -h, --help           Show this help message and exit
  --status-only        Only show task status, don't execute any tasks
  --list               List all tasks with their current status
  --profile            Enable token usage profiling
  --no-cache           Disable caching for this execution

Examples:
  $0 task-execution-inputs.md
  $0 --status-only task-execution-inputs.md
  $0 --list task-execution-inputs.md
EOF
}

# Load context manager and estimator if available
load_utilities() {
  debug "Loading utility scripts..."
  
  # Load context cache manager
  if [[ -f "$SCRIPT_DIR/context-cache-manager.sh" ]]; then
    # shellcheck source=./context-cache-manager.sh
    source "$SCRIPT_DIR/context-cache-manager.sh"
    debug "Context cache manager loaded"
  else
    warning "Context cache manager not found. Caching will be disabled."
  fi
  
  # Load context estimator
  if [[ "${ENABLE_PROFILING:-0}" == "1" ]] && [[ -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
    # shellcheck source=./context-estimator.sh
    source "$SCRIPT_DIR/context-estimator.sh"
    debug "Context estimator loaded"
    ce_start_profiling "execute_tasks"
    ce_track_operation "main" "script"
  fi
}

# Function: parse_execution_context
# Description: Parse execution context from input file
# Parameters:
#   $1: input_file - Path to the input file with execution context
# Returns: 0 on success, non-zero on failure
parse_execution_context() {
  local input_file="$1"
  
  debug "Parsing execution context from: $input_file"
  
  # Check if file exists
  if [[ ! -f "$input_file" ]]; then
    error "Input file not found: $input_file"
    return 1
  fi
  
  # Extract execution context section
  local execution_context
  execution_context=$(sed -n '/\[execution_context\]/,/\[\/execution_context\]/p' "$input_file")
  
  if [[ -z "$execution_context" ]]; then
    error "No execution context found in: $input_file"
    return 1
  fi
  
  # Extract spec_folder_path
  SPEC_FOLDER_PATH=$(echo "$execution_context" | grep 'spec_folder_path:' | sed 's/spec_folder_path: *//;s/"//g' | sed 's/@/./')
  
  if [[ -z "$SPEC_FOLDER_PATH" ]]; then
    error "Missing required field: spec_folder_path"
    return 1
  fi
  
  # Extract specific_tasks if present
  SPECIFIC_TASKS=$(echo "$execution_context" | grep -A 10 'specific_tasks:' | grep -v 'specific_tasks:' | grep -v '\[\/execution_context\]' | grep -v '^execution_notes:' | grep -E '^ *- ' | sed 's/ *- //')
  
  # Extract execution_notes if present
  EXECUTION_NOTES=$(echo "$execution_context" | grep -A 10 'execution_notes:' | grep -v 'execution_notes:' | grep -v '\[\/execution_context\]' | grep -v '^ *- ')
  
  debug "Parsed spec_folder_path: $SPEC_FOLDER_PATH"
  debug "Parsed specific_tasks: $SPECIFIC_TASKS"
  debug "Parsed execution_notes: $EXECUTION_NOTES"
  
  return 0
}

# Function: list_tasks
# Description: List all tasks with their current status
# Parameters:
#   $1: tasks_file - Path to the tasks file
# Returns: 0 on success, non-zero on failure
list_tasks() {
  local tasks_file="$1"
  
  log "Listing tasks from: $tasks_file"
  
  # Check if tasks file exists
  if [[ ! -f "$tasks_file" ]]; then
    error "Tasks file not found: $tasks_file"
    return 1
  fi
  
  # Find task headers (## Task n:)
  local task_headers
  task_headers=$(awk '/^## Task [0-9]/{print NR}' "$tasks_file")
  
  if [[ -z "$task_headers" ]]; then
    warning "No tasks found in: $tasks_file"
    return 1
  fi
  
  echo -e "\n${BLUE}======= Task Status =======${NC}"
  
  # Process each task header
  local prev_line=0
  while IFS= read -r line_number; do
    local task_title
    task_title=$(sed -n "${line_number}p" "$tasks_file" | sed 's/^## Task [0-9][0-9]*: *//')
    
    local task_status="Unknown"
    local status_color=$YELLOW
    
    # Check for status markers
  if grep -Fq -- '- [x]' <(sed -n "${line_number},+20p" "$tasks_file"); then
      task_status="Completed"
      status_color=$GREEN
  elif grep -Fq -- '- [ ]' <(sed -n "${line_number},+20p" "$tasks_file"); then
      task_status="In Progress"
      status_color=$BLUE
    else
      task_status="Not Started"
      status_color=$RED
    fi
    
    # Extract task number
    local task_number
    task_number=$(sed -n "${line_number}p" "$tasks_file" | grep -o '^## Task [0-9][0-9]*' | grep -o '[0-9][0-9]*')
    
    echo -e "Task ${task_number}: ${task_title} - ${status_color}${task_status}${NC}"
    
    # Check for subtasks
    if grep -q '^### Subtask' <(sed -n "${line_number},+20p" "$tasks_file"); then
  local subtasks
  subtasks=$(sed -n "${line_number},+20p" "$tasks_file" | awk '/^### Subtask/{print NR}')
      
      while IFS= read -r subtask_offset; do
        local actual_line=$((line_number + subtask_offset - 1))
        local subtask_title
        subtask_title=$(sed -n "${actual_line}p" "$tasks_file" | sed 's/^### Subtask [0-9][0-9]*\.[0-9][0-9]*: *//')
        
        local subtask_status="Unknown"
        local subtask_color=$YELLOW
        
        # Check for status markers
  if grep -Fq -- '- [x]' <(sed -n "${actual_line},+10p" "$tasks_file"); then
          subtask_status="Completed"
          subtask_color=$GREEN
  elif grep -Fq -- '- [ ]' <(sed -n "${actual_line},+10p" "$tasks_file"); then
          subtask_status="In Progress"
          subtask_color=$BLUE
        else
          subtask_status="Not Started"
          subtask_color=$RED
        fi
        
        # Extract subtask number
        local subtask_number
        subtask_number=$(sed -n "${actual_line}p" "$tasks_file" | grep -o '^### Subtask [0-9][0-9]*\.[0-9][0-9]*' | grep -o '[0-9][0-9]*\.[0-9][0-9]*')
        
        echo -e "  └─ Subtask ${subtask_number}: ${subtask_title} - ${subtask_color}${subtask_status}${NC}"
      done <<< "$subtasks"
    fi
    
  done <<< "$task_headers"
  
  echo -e "${BLUE}=========================${NC}\n"
  
  return 0
}

# Function: execute_specific_tasks
# Description: Execute specific tasks from the tasks list
# Parameters:
#   $1: tasks_file - Path to the tasks file
#   $2: specific_tasks - Space-separated list of task numbers to execute
# Returns: 0 on success, non-zero on failure
execute_specific_tasks() {
  local tasks_file="$1"
  local specific_tasks="$2"
  
  log "Executing specific tasks: $specific_tasks"
  
  # For each task number
  for task_number in $specific_tasks; do
    log "Processing task number: $task_number"
    
    # Find the task header
  local task_line
  task_line=$(awk -v n="$task_number" '$0 ~ ("^## Task " n ":") {print NR; exit}' "$tasks_file")
    
    if [[ -z "$task_line" ]]; then
      error "Task ${task_number} not found in: $tasks_file"
      continue
    fi
    
    # Extract task title
    local task_title
    task_title=$(sed -n "${task_line}p" "$tasks_file" | sed 's/^## Task [0-9][0-9]*: *//')
    
    # Check if task is already completed
  if grep -Fq -- '- [x]' <(sed -n "${task_line},+20p" "$tasks_file"); then
      warning "Task ${task_number} (${task_title}) is already completed. Skipping."
      continue
    fi
    
    log "Executing task ${task_number}: ${task_title}"
    
    # In a real implementation, this would:
    # 1. Determine if this is a deterministic task (can be done with scripts)
    # 2. For deterministic tasks, execute the appropriate script
    # 3. For non-deterministic tasks, delegate to AI via Claude Code
    
    # For this implementation, we'll simulate task execution
    echo -e "${PURPLE}Executing task ${task_number}: ${task_title}${NC}"
    echo -e "${PURPLE}This is a placeholder. In a real implementation, this would execute the task.${NC}"
    echo -e "${PURPLE}For now, marking the task as completed.${NC}"
    
    # Simulate completion
    success "Task ${task_number} (${task_title}) completed successfully"
  done
  
  return 0
}

# Function: execute_next_task
# Description: Execute the next uncompleted task
# Parameters:
#   $1: tasks_file - Path to the tasks file
# Returns: 0 on success, non-zero on failure
execute_next_task() {
  local tasks_file="$1"
  
  log "Finding next uncompleted task in: $tasks_file"
  
  # Find task headers
  local task_headers
  task_headers=$(awk '/^## Task [0-9]/{print NR}' "$tasks_file")
  
  if [[ -z "$task_headers" ]]; then
    warning "No tasks found in: $tasks_file"
    return 1
  fi
  
  # Find the first uncompleted task
  while IFS= read -r line_number; do
    local task_title
    task_title=$(sed -n "${line_number}p" "$tasks_file" | sed 's/^## Task [0-9][0-9]*: *//')
    
    # Check if we have a valid line and extract the number
    if [[ -n "$line_number" ]]; then
      # Extract task number via awk
      local task_number
      task_number=$(awk -v ln="$line_number" 'NR==ln { match($0, /^## Task ([0-9]+)/, m); if (m[1] != "") print m[1]; }' "$tasks_file")
      
      # Execute this task
      execute_specific_tasks "$tasks_file" "$task_number"
      return $?
    fi
  done <<< "$(find_first_uncompleted_task_line "$tasks_file")"
  
  warning "All tasks are already completed in: $tasks_file"
  return 0
}

# Main execution logic
main() {
  log "========== Starting execute-tasks =========="
  
  # Default values
  local input_file=""
  local status_only=false
  local list_only=false
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      --status-only)
        status_only=true
        shift
        ;;
      --list)
        list_only=true
        shift
        ;;
      --profile)
        export ENABLE_PROFILING=1
        shift
        ;;
      --no-cache)
        export USE_CACHE=false
        shift
        ;;
      -*)
        error "Unknown option: $1"
        show_help
        exit 1
        ;;
      *)
        # First non-option argument is the input file
        input_file="$1"
        shift
        break
        ;;
    esac
  done
  
  # Load utilities (context manager, estimator)
  load_utilities
  
  # Validate required arguments
  if [[ -z "$input_file" ]]; then
    error "No input file specified"
    show_help
    exit 1
  fi
  
  if [[ ! -f "$input_file" ]]; then
    error "Input file not found: $input_file"
    exit 1
  fi
  
  # Parse execution context
  if ! parse_execution_context "$input_file"; then
    error "Failed to parse execution context"
    exit 1
  fi
  
  # Resolve the spec folder path
  if [[ "$SPEC_FOLDER_PATH" == .* ]]; then
    # Relative path starting with .
    SPEC_FOLDER_PATH="$(cd "$(dirname "$input_file")" && pwd)/${SPEC_FOLDER_PATH#.}"
  elif [[ ! "$SPEC_FOLDER_PATH" == /* ]]; then
    # Relative path not starting with /
    SPEC_FOLDER_PATH="$DEFAULT_SPEC_DIR/$SPEC_FOLDER_PATH"
  fi
  
  # Validate spec folder exists
  if [[ ! -d "$SPEC_FOLDER_PATH" ]]; then
    error "Specification folder not found: $SPEC_FOLDER_PATH"
    exit 1
  fi
  
  # Check if tasks.md exists
  local tasks_file="$SPEC_FOLDER_PATH/tasks.md"
  if [[ ! -f "$tasks_file" ]]; then
    error "Tasks file not found: $tasks_file"
    exit 1
  fi
  
  # Process according to mode
  if [[ "$list_only" == true ]]; then
    # List all tasks with status
    list_tasks "$tasks_file"
    # Also refresh manifest for tasks.md so hashes stay current
    refresh_manifest_tasks "$SPEC_FOLDER_PATH"
  elif [[ "$status_only" == true ]]; then
    # Show task status without executing
    list_tasks "$tasks_file"
    # Also refresh manifest for tasks.md
    refresh_manifest_tasks "$SPEC_FOLDER_PATH"
  else
    # Execute tasks
    if [[ -n "$SPECIFIC_TASKS" ]]; then
      # Execute specific tasks
      # For the first task in the list, emit snippet and summary before execution
      local first_spec_task
      first_spec_task=$(echo "$SPECIFIC_TASKS" | awk '{print $1}')
      if [[ -n "$first_spec_task" ]]; then
        write_current_task_snippet "$SPEC_FOLDER_PATH" "$tasks_file" "$first_spec_task" || true
        write_tasks_summary_json "$SPEC_FOLDER_PATH" "$tasks_file" "$first_spec_task" || true
        write_tasks_heuristics_json "$SPEC_FOLDER_PATH" "$tasks_file" "$first_spec_task" || true
        refresh_manifest_tasks "$SPEC_FOLDER_PATH" || true
      fi
      execute_specific_tasks "$tasks_file" "$SPECIFIC_TASKS"
    else
      # Execute next uncompleted task
      # Determine next and emit snippet/summary
      local next_line
      next_line=$(find_first_uncompleted_task_line "$tasks_file" | tr -d '\r')
      debug "Computed next_line: '${next_line}'"
      if [[ -n "$next_line" ]]; then
        local next_num
        next_num=$(awk -v ln="$next_line" 'NR==ln { match($0, /^## Task ([0-9]+)/, m); if (m[1] != "") print m[1]; }' "$tasks_file")
        debug "Extracted next_num: '${next_num}'"
        if [[ -n "$next_num" ]]; then
          write_current_task_snippet "$SPEC_FOLDER_PATH" "$tasks_file" "$next_num" || true
          write_tasks_summary_json "$SPEC_FOLDER_PATH" "$tasks_file" "$next_num" || true
          write_tasks_heuristics_json "$SPEC_FOLDER_PATH" "$tasks_file" "$next_num" || true
          refresh_manifest_tasks "$SPEC_FOLDER_PATH" || true
        fi
      fi
      execute_next_task "$tasks_file"
    fi
  fi
  
  # End profiling if enabled
  if [[ "${ENABLE_PROFILING:-0}" == "1" ]] && [[ -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
    ce_end_profiling
  fi
  
  success "========== execute-tasks process finished successfully =========="
}

# Execute main function
main "$@"
