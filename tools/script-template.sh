#!/bin/bash
#
# Script Name: script-template.sh
# Description: Template for shell scripts following project standards
# Author: Agent OS Team
# Created: 2025-08-17
# Last Modified: 2025-08-17
# Usage: ./script-template.sh [options]
#
# Dependencies:
# - bash (version 4+)
# - jq
# - standard Unix utilities (grep, sed, awk)
#
# Notes:
# - Use this template as a starting point for all new scripts
# - Ensure logging is enabled for all production scripts
# - Always check for dependencies before execution

# ==============================================================================
# Configuration
# ==============================================================================

# Script version
readonly VERSION="1.0.0"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_DEPENDENCY_MISSING=3

# Default values
DEFAULT_OUTPUT_DIR=".agent-os/output"
DEFAULT_VERBOSITY="info"

# ==============================================================================
# Logging Functions
# ==============================================================================

# Log levels
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

# Current log level (can be overridden via environment variable)
LOG_LEVEL_NAME=${VERBOSITY:-$DEFAULT_VERBOSITY}
case "$LOG_LEVEL_NAME" in
  error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
  warn)  LOG_LEVEL=$LOG_LEVEL_WARN ;;
  info)  LOG_LEVEL=$LOG_LEVEL_INFO ;;
  debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
  *)     LOG_LEVEL=$LOG_LEVEL_INFO ;;
esac

# Logging functions
log_error() { [[ $LOG_LEVEL -ge $LOG_LEVEL_ERROR ]] && echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
log_warn() { [[ $LOG_LEVEL -ge $LOG_LEVEL_WARN ]] && echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
log_info() { [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_debug() { [[ $LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }

# ==============================================================================
# Utility Functions
# ==============================================================================

# Function: show_help
# Description: Display help information for this script
# Parameters: None
# Returns: None
show_help() {
  cat <<EOF
Usage: $(basename "$0") [options] <argument>

Template script that demonstrates proper script structure and logging.

Options:
  -h, --help           Show this help message and exit
  -v, --verbose        Increase verbosity level
  -q, --quiet          Decrease verbosity level
  -o, --output DIR     Set output directory (default: $DEFAULT_OUTPUT_DIR)
  --version            Show version information and exit

Examples:
  $(basename "$0") --verbose example-input.md
  $(basename "$0") --output ./custom-output input.md

EOF
}

# Function: show_version
# Description: Display version information
# Parameters: None
# Returns: None
show_version() {
  echo "$(basename "$0") version $VERSION"
}

# Function: check_dependencies
# Description: Check if required tools are available
# Parameters: None
# Returns: 0 if all dependencies are met, 1 otherwise
check_dependencies() {
  log_debug "Checking dependencies..."
  
  # Check for jq
  if ! command -v jq >/dev/null 2>&1; then
    log_error "Required dependency 'jq' is not installed"
    log_error "Please install jq: https://stedolan.github.io/jq/download/"
    return 1
  fi
  
  # Check for other dependencies as needed
  
  log_debug "All dependencies satisfied"
  return 0
}

# Function: process_file
# Description: Example function that processes an input file
# Parameters:
#   $1: input_file - Path to the input file to process
#   $2: output_dir - Directory where output should be saved
# Returns: 0 on success, non-zero on failure
process_file() {
  local input_file="$1"
  local output_dir="$2"
  
  # Validate input
  if [[ ! -f "$input_file" ]]; then
    log_error "Input file not found: $input_file"
    return 1
  fi
  
  if [[ ! -d "$output_dir" ]]; then
    log_info "Creating output directory: $output_dir"
    mkdir -p "$output_dir" || return 1
  fi
  
  log_info "Processing file: $input_file"
  log_debug "Output directory: $output_dir"
  
  # Example processing
  local basename
  basename=$(basename "$input_file" | cut -d. -f1)
  local output_file="$output_dir/${basename}-processed.txt"
  
  log_debug "Writing output to: $output_file"
  cat "$input_file" > "$output_file"
  
  log_info "Processing complete: $output_file"
  return 0
}

# ==============================================================================
# Main Function
# ==============================================================================

main() {
  local output_dir="$DEFAULT_OUTPUT_DIR"
  local input_file=""
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit $EXIT_SUCCESS
        ;;
      --version)
        show_version
        exit $EXIT_SUCCESS
        ;;
      -v|--verbose)
        if [[ $LOG_LEVEL -lt $LOG_LEVEL_DEBUG ]]; then
          ((LOG_LEVEL++))
        fi
        ;;
      -q|--quiet)
        if [[ $LOG_LEVEL -gt $LOG_LEVEL_ERROR ]]; then
          ((LOG_LEVEL--))
        fi
        ;;
      -o|--output)
        shift
        output_dir="$1"
        ;;
      -*)
        log_error "Unknown option: $1"
        show_help
        exit $EXIT_INVALID_ARGS
        ;;
      *)
        # First non-option argument is the input file
        if [[ -z "$input_file" ]]; then
          input_file="$1"
        else
          log_error "Too many input files. Only one input file is allowed."
          show_help
          exit $EXIT_INVALID_ARGS
        fi
        ;;
    esac
    shift
  done
  
  log_info "Starting $(basename "$0") version $VERSION"
  
  # Check dependencies
  if ! check_dependencies; then
    log_error "Missing dependencies. Please install required tools."
    exit $EXIT_DEPENDENCY_MISSING
  fi
  
  # Validate required arguments
  if [[ -z "$input_file" ]]; then
    log_error "No input file specified"
    show_help
    exit $EXIT_INVALID_ARGS
  fi
  
  # Process the file
  if process_file "$input_file" "$output_dir"; then
    log_info "Script execution successful"
    exit $EXIT_SUCCESS
  else
    log_error "Script execution failed"
    exit $EXIT_FAILURE
  fi
}

# Execute main function if script is being run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  main "$@"
fi
