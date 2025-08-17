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
  }
  
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
  task_headers=$(grep -n '^## Task [0-9]' "$tasks_file" | sed 's/:.*$//')
  
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
    if grep -q '- \[x\]' <(sed -n "${line_number},+20p" "$tasks_file"); then
      task_status="Completed"
      status_color=$GREEN
    elif grep -q '- \[ \]' <(sed -n "${line_number},+20p" "$tasks_file"); then
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
      subtasks=$(grep -n '^### Subtask' <(sed -n "${line_number},+20p" "$tasks_file") | sed 's/:.*$//')
      
      while IFS= read -r subtask_offset; do
        local actual_line=$((line_number + subtask_offset - 1))
        local subtask_title
        subtask_title=$(sed -n "${actual_line}p" "$tasks_file" | sed 's/^### Subtask [0-9][0-9]*\.[0-9][0-9]*: *//')
        
        local subtask_status="Unknown"
        local subtask_color=$YELLOW
        
        # Check for status markers
        if grep -q '- \[x\]' <(sed -n "${actual_line},+10p" "$tasks_file"); then
          subtask_status="Completed"
          subtask_color=$GREEN
        elif grep -q '- \[ \]' <(sed -n "${actual_line},+10p" "$tasks_file"); then
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
    task_line=$(grep -n "^## Task ${task_number}:" "$tasks_file" | cut -d: -f1)
    
    if [[ -z "$task_line" ]]; then
      error "Task ${task_number} not found in: $tasks_file"
      continue
    fi
    
    # Extract task title
    local task_title
    task_title=$(sed -n "${task_line}p" "$tasks_file" | sed 's/^## Task [0-9][0-9]*: *//')
    
    # Check if task is already completed
    if grep -q '- \[x\]' <(sed -n "${task_line},+20p" "$tasks_file"); then
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
  task_headers=$(grep -n '^## Task [0-9]' "$tasks_file" | sed 's/:.*$//')
  
  if [[ -z "$task_headers" ]]; then
    warning "No tasks found in: $tasks_file"
    return 1
  fi
  
  # Find the first uncompleted task
  while IFS= read -r line_number; do
    local task_title
    task_title=$(sed -n "${line_number}p" "$tasks_file" | sed 's/^## Task [0-9][0-9]*: *//')
    
    # Check if task is already completed
    if ! grep -q '- \[x\]' <(sed -n "${line_number},+20p" "$tasks_file"); then
      # Extract task number
      local task_number
      task_number=$(sed -n "${line_number}p" "$tasks_file" | grep -o '^## Task [0-9][0-9]*' | grep -o '[0-9][0-9]*')
      
      # Execute this task
      execute_specific_tasks "$tasks_file" "$task_number"
      return $?
    fi
  done <<< "$task_headers"
  
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
  elif [[ "$status_only" == true ]]; then
    # Show task status without executing
    list_tasks "$tasks_file"
  else
    # Execute tasks
    if [[ -n "$SPECIFIC_TASKS" ]]; then
      # Execute specific tasks
      execute_specific_tasks "$tasks_file" "$SPECIFIC_TASKS"
    else
      # Execute next uncompleted task
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
