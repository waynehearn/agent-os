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
# Usage: ./command-router.sh <command> [mode] [inputs_file]

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
Usage: $0 <command> [mode] [inputs_file]

Commands:
  create-spec         - Create a detailed specification
  analyze-product     - Analyze product context and generate insights
  execute-task        - Execute a single task from a spec
  execute-tasks       - Execute multiple tasks from a spec
  plan-product        - Create a product plan

Modes:
  script              - Use script-based implementation (token-efficient)
  subagent            - Use Claude Code subagents (AI-powered)
  hybrid              - Use hybrid approach (default)
  auto                - Automatically determine the best approach

Parameters:
  inputs_file         - JSON or Markdown file with inputs for the command

Examples:
  $0 create-spec script examples/sample-jira-spec-inputs.md
  $0 analyze-product hybrid product-analysis-inputs.md
  $0 execute-tasks auto tasks-inputs.json
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

# Main execution logic
if [[ $# -lt 1 ]]; then
  show_help
  exit 1
fi

command="$1"
mode="${2:-auto}"
inputs_file="${3:-}"

if [[ -z "$inputs_file" ]]; then
  error "Inputs file is required"
  show_help
  exit 1
fi

if [[ ! -f "$inputs_file" ]]; then
  error "Inputs file not found: $inputs_file"
  exit 1
fi

# If mode is auto, determine the best mode
if [[ "$mode" == "auto" ]]; then
  mode=$(determine_auto_mode "$command")
  log "Auto mode selected: $mode"
fi

# Execute the command in the selected mode
case "$mode" in
  script)
    execute_script_mode "$command" "$inputs_file"
    ;;
  subagent)
    execute_subagent_mode "$command" "$inputs_file"
    ;;
  hybrid)
    execute_hybrid_mode "$command" "$inputs_file"
    ;;
  *)
    error "Unknown mode: $mode"
    show_help
    exit 1
    ;;
esac
