#!/usr/bin/env bash
# command-router.sh - Intelligent router for Agent OS commands
#
# This script routes command execution requests to either:
# 1. Script-based implementation (token-efficient)
# 2. Claude Code subagents (AI-powered)
#
# It makes decisions based on:
# - Command complexity
# - Available implementations
# - User preferences
# - Required capabilities
#
# Usage: ./command-router.sh [options] <command> [inputs_file]
#
# Options:
#   --script-first    Prefer script implementation when available
#   --ai-first        Prefer AI implementation even when script is available
#   --profile         Enable profiling (track token usage)
#   --no-cache        Bypass the operation cache
#   --no-extensions   Disable all extensions
#   --extension-path  Specify custom extension path
#   --extensions      Comma-separated list of enabled extensions

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

# Logging functions
log() { echo -e "${BLUE}[command-router]${NC} $*"; }
error() { echo -e "${RED}[command-router][ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[command-router][SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[command-router][WARNING]${NC} $*"; }

# Help message
show_help() {
  cat << EOF
Usage: $0 [options] <command> [inputs_file]

Commands:
  create-spec         - Create a detailed specification
  analyze-product     - Analyze product context and generate insights
  execute-task        - Execute a single task from a spec
  execute-tasks       - Execute multiple tasks from a spec
  plan-product        - Create a product plan

Options:
  -h, --help          - Show this help message and exit
  --script-first      - Prefer script implementation when available
  --ai-first          - Prefer AI implementation even when script is available
  --profile           - Enable profiling (track token usage)
  --no-cache          - Bypass the operation cache
  --no-extensions     - Disable all extensions
  --extension-path P  - Specify custom extension path
  --extensions LIST   - Comma-separated list of enabled extensions
  --version           - Show version information and exit

Parameters:
  inputs_file         - JSON or Markdown file with inputs for the command

Examples:
  $0 create-spec examples/sample-jira-spec-inputs.md
  $0 --script-first create-spec examples/sample-jira-spec-inputs.md
  $0 --ai-first --profile create-spec examples/sample-jira-spec-inputs.md
  $0 --no-extensions execute-tasks tasks-inputs.json
EOF
}

# Function to check if Claude Code is available
check_claude_code_available() {
  # Check for Claude Code installation markers
  if [[ -d "$HOME/.claude" && -d "$HOME/.claude/agents" ]]; then
    return 0  # Claude Code is available
  else
    return 1  # Claude Code is not available
  fi
}

# Load the context cache manager
if [[ -f "$SCRIPT_DIR/context-cache-manager.sh" ]]; then
  # shellcheck source=./context-cache-manager.sh
  source "$SCRIPT_DIR/context-cache-manager.sh"
fi

# Function to check if a script implementation exists
check_script_implementation() {
  local command="$1"
  
  case "$command" in
    create-spec)
      [[ -f "$SCRIPT_DIR/run-create-spec.sh" ]] && return 0 || return 1
      ;;
    analyze-product)
      [[ -f "$SCRIPT_DIR/run-analyze-product.sh" ]] && return 0 || return 1
      ;;
    execute-task)
      [[ -f "$SCRIPT_DIR/run-execute-task.sh" ]] && return 0 || return 1
      ;;
    execute-tasks)
      [[ -f "$SCRIPT_DIR/execute-tasks.sh" ]] && return 0 || return 1
      ;;
    plan-product)
      [[ -f "$SCRIPT_DIR/run-plan-product.sh" ]] && return 0 || return 1
      ;;
    *)
      return 1
      ;;
  esac
}

# Function to determine if an operation is deterministic
is_deterministic_operation() {
  local command="$1"
  local input_file="$2"
  
  # Check command and arguments against known patterns
  case "$command" in
    "create-spec")
      # Check for templated spec creation (deterministic)
      if [[ "$*" == *"--template"* ]]; then
        return 0
      fi

      # Check for optional Jira-sourced operation
      if grep -q '\[jira_inputs\]' "$input_file" 2>/dev/null; then
        # First check if Jira integration is enabled
        local use_jira_mcp
        use_jira_mcp=$(sed -n '/\[jira_inputs\]/,/\[\/jira_inputs\]/p' "$input_file" | grep 'use_jira_mcp:' | sed 's/use_jira_mcp: *//;s/"//g')
        if [[ "$use_jira_mcp" == "true" ]]; then
          # Only check Jira-specific logic if integration is enabled
          # Check if it's a simple field mapping (deterministic)
          if ! grep -q 'custom_reasoning' "$input_file"; then
            return 0
          fi
        else
          # If Jira inputs exist but integration disabled,
          # treat as regular input (still might be deterministic)
          if [[ "$*" == *"--simple"* ]] || ! grep -q 'requires_reasoning' "$input_file"; then
            return 0
          fi
        fi
      fi
      ;;
    "execute-tasks")
      # Check if this is just status reporting (deterministic)
      if [[ "$*" == *"--status-only"* ]] || [[ "$*" == *"--list"* ]]; then
        return 0
      fi
      ;;
    "analyze-product")
      # Check if this is just metrics reporting (deterministic)
      if [[ "$*" == *"--metrics-only"* ]]; then
        return 0
      fi
      ;;
  esac

  # Default: assume non-deterministic (requires reasoning)
  return 1
}

# Function to execute command using scripts
execute_script_mode() {
  local command="$1"
  local inputs_file="$2"
  
  log "Executing $command in script mode with inputs: $inputs_file"
  
  case "$command" in
    create-spec)
      if [[ -f "$SCRIPT_DIR/run-create-spec.sh" ]]; then
        bash "$SCRIPT_DIR/run-create-spec.sh" "$inputs_file"
      else
        error "Script implementation not found for $command"
        return 1
      fi
      ;;
    analyze-product)
      if [[ -f "$SCRIPT_DIR/run-analyze-product.sh" ]]; then
        bash "$SCRIPT_DIR/run-analyze-product.sh" "$inputs_file"
      else
        error "Script implementation not found for $command"
        return 1
      fi
      ;;
    execute-task)
      if [[ -f "$SCRIPT_DIR/run-execute-task.sh" ]]; then
        bash "$SCRIPT_DIR/run-execute-task.sh" "$inputs_file"
      else
        error "Script implementation not found for $command"
        return 1
      fi
      ;;
    execute-tasks)
      if [[ -f "$SCRIPT_DIR/execute-tasks.sh" ]]; then
        bash "$SCRIPT_DIR/execute-tasks.sh" "$inputs_file"
      else
        error "Script implementation not found for $command"
        return 1
      fi
      ;;
    plan-product)
      if [[ -f "$SCRIPT_DIR/run-plan-product.sh" ]]; then
        bash "$SCRIPT_DIR/run-plan-product.sh" "$inputs_file"
      else
        error "Script implementation not found for $command"
        return 1
      fi
      ;;
    *)
      error "Unknown command: $command"
      return 1
      ;;
  esac
}

# Function to execute command using Claude Code subagents
execute_subagent_mode() {
  local command="$1"
  local inputs_file="$2"
  
  if ! check_claude_code_available; then
    error "Claude Code is not available. Cannot execute in subagent mode."
    error "Try installing Claude Code or using script mode instead."
    return 1
  fi
  
  log "Executing $command in subagent mode with inputs: $inputs_file"
  
  # For now, this is a placeholder. In a real implementation, this would
  # invoke Claude Code with the appropriate command and inputs.
  warning "Subagent mode execution is not yet implemented."
  warning "This would invoke Claude Code with @~/.agent-os/commands/$command.md"
  
  return 0
}

# Function to execute command using hybrid approach
execute_hybrid_mode() {
  local command="$1"
  local inputs_file="$2"
  
  log "Executing $command in hybrid mode with inputs: $inputs_file"
  
  # Hybrid mode would use scripts for deterministic operations and subagents for reasoning.
  # For now, we'll just use script mode if available, otherwise fall back to subagent mode.
  if check_script_implementation "$command"; then
    warning "Hybrid mode implementation is not yet complete."
    warning "Falling back to script mode for now."
    execute_script_mode "$command" "$inputs_file"
  else
    warning "Hybrid mode implementation is not yet complete."
    warning "Falling back to subagent mode for now."
    execute_subagent_mode "$command" "$inputs_file"
  fi
}

# Function to automatically determine the best execution mode
determine_auto_mode() {
  local command="$1"
  
  # If Claude Code is not available, use script mode
  if ! check_claude_code_available; then
    echo "script"
    return
  fi
  
  # If script implementation is not available, use subagent mode
  if ! check_script_implementation "$command"; then
    echo "subagent"
    return
  fi
  
  # Otherwise, use hybrid mode
  echo "hybrid"
}

# Function to execute an operation with optional caching
execute_operation() {
  local command="$1"
  local input_file="$2"
  local mode="${3:-auto}"
  
  # Generate cache key if caching is enabled
  if [[ "${USE_CACHE:-true}" == "true" ]]; then
    local cache_key
    cache_key=$(generate_cache_key "$command" "$input_file" "$mode")
    
    # Check if we have a valid cached result
    if is_cache_valid "$cache_key"; then
      log "Found valid cached result for $command operation"
      get_cached_result "$cache_key"
      return $?
    fi
  fi
  
  log "Executing $command in $mode mode with inputs: $input_file"
  
  local result=""
  local success=false
  
  # Execute the command in the selected mode
  case "$mode" in
    script)
      if execute_script_mode "$command" "$input_file"; then
        success=true
      fi
      ;;
    subagent)
      if execute_subagent_mode "$command" "$input_file"; then
        success=true
      fi
      ;;
    hybrid)
      if execute_hybrid_mode "$command" "$input_file"; then
        success=true
      fi
      ;;
    *)
      error "Unknown mode: $mode"
      return 1
      ;;
  esac
  
  # Cache the result if caching is enabled and operation was successful
  if [[ "${USE_CACHE:-true}" == "true" && "$success" == "true" ]]; then
    if [[ -n "$result" ]]; then
      cache_operation "$cache_key" "$command" "$result" "$input_file" true
    fi
  fi
  
  return $success
}

# Function to route the command based on intelligent detection
route_command() {
  local command="$1"
  local input_file="$2"
  
  log "Routing command: $command"
  
  # Start profiling if enabled
  if [[ "${ENABLE_PROFILING:-0}" == "1" ]]; then
    if [[ -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
      # shellcheck source=./context-estimator.sh
      source "$SCRIPT_DIR/context-estimator.sh"
      ce_start_profiling "command_router_${command}"
      ce_track_operation "route_command" "script"
    else
      warning "Profiling requested but context-estimator.sh not found"
    fi
  fi
  
  # Check for user preference override
  if [[ "${SCRIPT_FIRST:-false}" == "true" ]]; then
    log "User preference: script implementation preferred"
    execute_operation "$command" "$input_file" "script" || execute_operation "$command" "$input_file" "subagent"
    return $?
  fi
  
  if [[ "${AI_FIRST:-false}" == "true" ]]; then
    log "User preference: AI implementation preferred"
    execute_operation "$command" "$input_file" "subagent" || execute_operation "$command" "$input_file" "script"
    return $?
  fi
  
  # Check if operation is deterministic
  if is_deterministic_operation "$command" "$input_file"; then
    log "Operation determined to be deterministic"
    
    if check_script_implementation "$command"; then
      log "Routing '$command' to script implementation (deterministic operation)"
      execute_operation "$command" "$input_file" "script"
    else
      log "No script implementation for '$command', falling back to AI"
      execute_operation "$command" "$input_file" "subagent"
    fi
  else
    log "Operation determined to require reasoning (non-deterministic)"
    execute_operation "$command" "$input_file" "hybrid"
  fi
  
  # End profiling if enabled
  if [[ "${ENABLE_PROFILING:-0}" == "1" && -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
    ce_end_profiling
  fi
  
  return $?
}

# Main execution logic
main() {
  # Default values
  SCRIPT_FIRST=false
  AI_FIRST=false
  ENABLE_PROFILING=0
  USE_CACHE=true
  EXTENSIONS_ENABLED=true
  EXTENSION_PATH=""
  ENABLED_EXTENSIONS=""
  
  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      --version)
        echo "command-router.sh version 1.0.0"
        exit 0
        ;;
      --script-first)
        SCRIPT_FIRST=true
        shift
        ;;
      --ai-first)
        AI_FIRST=true
        shift
        ;;
      --profile)
        ENABLE_PROFILING=1
        export ENABLE_PROFILING=1
        shift
        ;;
      --no-cache)
        USE_CACHE=false
        shift
        ;;
      --no-extensions)
        EXTENSIONS_ENABLED=false
        shift
        ;;
      --extension-path)
        EXTENSION_PATH="$2"
        shift 2
        ;;
      --extensions)
        ENABLED_EXTENSIONS="$2"
        shift 2
        ;;
      -*)
        error "Unknown option: $1"
        show_help
        exit 1
        ;;
      *)
        # First non-option argument is the command
        command="$1"
        shift
        break
        ;;
    esac
  done
  
  # Validate required arguments
  if [[ -z "${command:-}" ]]; then
    error "No command specified"
    show_help
    exit 1
  fi
  
  # Next argument is the input file
  inputs_file="${1:-}"
  
  if [[ -z "$inputs_file" ]]; then
    error "Inputs file is required"
    show_help
    exit 1
  fi
  
  if [[ ! -f "$inputs_file" ]]; then
    error "Inputs file not found: $inputs_file"
    exit 1
  fi
  
  # Export configuration for child processes
  export SCRIPT_FIRST
  export AI_FIRST
  export ENABLE_PROFILING
  export USE_CACHE
  export EXTENSIONS_ENABLED
  export EXTENSION_PATH
  export ENABLED_EXTENSIONS
  
  # Route and execute the command
  route_command "$command" "$inputs_file"
}

# Execute main function
main "$@"
