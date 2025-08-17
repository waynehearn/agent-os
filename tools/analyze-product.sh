#!/usr/bin/env bash
# analyze-product.sh - Token-efficient implementation of product analysis
#
# This script analyzes an existing product codebase and generates documentation
# using deterministic operations where possible to minimize token usage.
#
# Usage: ./analyze-product.sh [options] <inputs_file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import common utilities if available
if [[ -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
  source "$SCRIPT_DIR/context-estimator.sh"
else
  # Simple token estimation as fallback
  estimate_token_usage() {
    local file="$1"
    local _operation="$2"
    # Estimate 1 token per ~4 characters
    local char_count=$(wc -c < "$file")
    TOKEN_ESTIMATE=$((char_count / 4))
  }
  
  get_token_estimate() {
    echo "$TOKEN_ESTIMATE"
  }
  
  warning "context-estimator.sh not found, using simple token estimation"
fi

if [[ -f "$SCRIPT_DIR/context-cache-manager.sh" ]]; then
  source "$SCRIPT_DIR/context-cache-manager.sh"
else
  # Simple cache functions as fallback
  generate_cache_key() {
    local operation="$1"
    local input_file="$2"
    echo "${operation}_$(echo -n "$input_file" | md5sum | cut -d' ' -f1)"
  }
  
  is_cache_valid() {
    return 1  # Always return invalid when no proper cache manager
  }
  
  cache_operation() {
    # This is a no-op function when cache manager is not available
    debug "Cache operation requested but cache manager not available"
    return 0
  }
  
  load_cache_metadata() {
    return 0  # Do nothing when no proper cache manager
  }
  
  warning "context-cache-manager.sh not found, caching disabled"
fi

# Colorization for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default values
DEFAULT_DOCS_DIR="docs"
VERBOSITY="${VERBOSITY:-info}"
USE_CACHE=true
AUTO_INIT_PRODUCT=false
REPO_PATH="$(pwd)"
PRODUCT_CONTEXT_CACHE="${ROOT_DIR}/.agent-os/product/context/context.json"

# Logging functions
log() { echo -e "${BLUE}[analyze-product]${NC} $*"; }
error() { echo -e "${RED}[analyze-product][ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[analyze-product][SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[analyze-product][WARNING]${NC} $*"; }
debug() { [[ "$VERBOSITY" == "debug" ]] && echo -e "[DEBUG][analyze-product] $*" || true; }

# Show help message
show_help() {
  cat << EOF
Usage: $0 [options] <inputs_file>

Analyze an existing product codebase and generate documentation using token-efficient approaches.

Options:
  -h, --help           Show this help message and exit
  --profile            Enable token usage profiling
  --no-cache           Disable caching for this execution
  --repo-path DIR      Path to the repository to analyze (default: current directory)
  --init-product       Allow creation of minimal product docs when discovery is insufficient
  --output-dir DIR     Output documentation to DIR (default: ./docs)

Examples:
  $0 analyze-inputs.md
  $0 --profile --repo-path /path/to/repo analyze-inputs.md
EOF
}

# Parse inputs file to extract parameters
parse_inputs_file() {
  local inputs_file="$1"
  local field="$2"
  local default_value="${3:-}"
  
  # Ensure inputs file exists
  if [[ ! -f "$inputs_file" ]]; then
    error "Inputs file not found: $inputs_file"
    return 1
  fi
  
  debug "Parsing field '$field' from $inputs_file"
  
  # Extract content between [analyze_inputs] and [/analyze_inputs] markers
  local analyze_section
  analyze_section=$(sed -n '/\[analyze_inputs\]/,/\[\/analyze_inputs\]/p' "$inputs_file")
  
  # For scalar fields, handle both single-line and multi-line values
  local value

  # 1) Try to extract value on the same line: field: some value
  #    Avoid capturing YAML fold markers like '>' and the closing tag
  value=$(echo "$analyze_section" | sed -n "s/^$field:[[:space:]]*//p" | head -n 1)
  if [[ -n "${value:-}" && "$value" != ">" && "$value" != "[/analyze_inputs]" ]]; then
    echo "$value"
    return 0
  fi
  
  # Try to extract a multi-line field that ends with >
  if [[ "$field" == "context_notes" ]]; then
    value=$(echo "$analyze_section" | grep -A 2 "^context_notes: >" | tail -n 1 | sed 's/^\s*//')
    if [[ -n "$value" ]]; then
      echo "$value"
      return 0
    fi
  fi
  
  # Try to extract a value after the field
  value=$(echo "$analyze_section" | grep -A 1 "^$field:" | tail -n 1 | sed 's/^\s*//')
  
  # If we got a value and it's not the next field
  if [[ -n "$value" && "$value" != *":"* && "$value" != "[/analyze_inputs]" ]]; then
    echo "$value"
    return 0
  fi
  
  # Return default value if provided
  if [[ -n "$default_value" ]]; then
    debug "Using default value for '$field': $default_value"
    echo "$default_value"
    return 0
  fi
  
  debug "No value found for '$field'"
  return 1
}

# Validate inputs file
validate_inputs() {
  local inputs_file="$1"
  
  # Check that file exists
  if [[ ! -f "$inputs_file" ]]; then
    error "Inputs file not found: $inputs_file"
    return 1
  fi
  
  # Check for [analyze_inputs] section
  if ! grep -q "\[analyze_inputs\]" "$inputs_file"; then
    error "Missing [analyze_inputs] section in $inputs_file"
    return 1
  fi
  
  # Extract auto_init_product if present
  local auto_init
  auto_init=$(parse_inputs_file "$inputs_file" "auto_init_product" "false")
  
  if [[ "$auto_init" != "true" && "$auto_init" != "false" ]]; then
    warning "Invalid value for auto_init_product: $auto_init, using default (false)"
    AUTO_INIT_PRODUCT=false
  else
    AUTO_INIT_PRODUCT="$auto_init"
  fi
  
  return 0
}

# Run discovery to gather product context
run_discovery() {
  local repo_path="$1"
  local auto_init="${2:-false}"
  
  log "Running product context discovery on $repo_path"
  
  local discover_script="$SCRIPT_DIR/discover-product-context.sh"
  
  if [[ ! -f "$discover_script" ]]; then
    error "Discovery script not found: $discover_script"
    return 1
  fi
  
  local discovery_args=("--write-if-missing")
  
  if [[ "$auto_init" == "true" ]]; then
  discovery_args+=("--init-product")
  fi
  
  # Run discovery script
  log "Executing: $discover_script $repo_path ${discovery_args[*]}"
  if ! bash "$discover_script" "$repo_path" "${discovery_args[@]}"; then
    error "Discovery failed"
    return 1
  fi
  
  # Check if context file was created
  if [[ ! -f "$PRODUCT_CONTEXT_CACHE" ]]; then
    error "Product context file not created: $PRODUCT_CONTEXT_CACHE"
    return 1
  fi
  
  success "Discovery completed successfully"
  return 0
}

# Generate documentation based on discovery results
generate_docs() {
  local context_file="$1"
  local output_dir="$2"
  local context_notes="${3:-}"
  
  log "Generating documentation based on discovery results"
  
  # Ensure output directory exists
  mkdir -p "$output_dir"
  
  # Check if context file exists
  if [[ ! -f "$context_file" ]]; then
    error "Context file not found: $context_file"
    return 1
  fi
  
  # Try to use jq to extract data from context file
  if ! command -v jq &> /dev/null; then
    warning "jq not found, using simplified document generation"
    generate_minimal_docs "$output_dir" "$context_notes"
    return $?
  fi
  
  # Extract data from context file
  local project_name
  project_name=$(jq -r '.project.name // "Unknown Project"' "$context_file")
  
  local tech_stack
  tech_stack=$(jq -r '.project.techStack | join(", ") // "Unknown"' "$context_file")
  
  local features
  features=$(jq -r '.project.features | map("- " + .) | join("\n") // ""' "$context_file")
  if [[ -z "$features" ]]; then
    features="- No features detected"
  fi
  
  # Generate mission.md if it doesn't exist
  if [[ ! -f "$output_dir/mission.md" ]]; then
    log "Generating $output_dir/mission.md"
    cat > "$output_dir/mission.md" << EOF
# Mission Statement

## Project: $project_name

*Auto-generated from code analysis. Please edit to refine.*

$([ -n "$context_notes" ] && echo -e "$context_notes\n\n")
## Purpose

Based on code analysis, this project appears to be a software application that provides functionality related to ${project_name}.

*TODO: Refine the mission statement with specific business goals and purpose.*
EOF
    success "Created $output_dir/mission.md"
  else
    log "Skipping mission.md generation (file already exists)"
  fi
  
  # Generate tech-stack.md if it doesn't exist
  if [[ ! -f "$output_dir/tech-stack.md" ]]; then
    log "Generating $output_dir/tech-stack.md"
    cat > "$output_dir/tech-stack.md" << EOF
# Technology Stack

## Primary Technologies

$([ -n "$tech_stack" ] && echo "$tech_stack" || echo "*No technology stack detected*")

## Frameworks and Libraries

*TODO: Add framework and library details*

## Infrastructure

*TODO: Add deployment and infrastructure details*

## Development Tools

*TODO: Add development tooling details*
EOF
    success "Created $output_dir/tech-stack.md"
  else
    log "Skipping tech-stack.md generation (file already exists)"
  fi
  
  # Generate architecture.md if it doesn't exist
  if [[ ! -f "$output_dir/architecture.md" ]]; then
    log "Generating $output_dir/architecture.md"
    cat > "$output_dir/architecture.md" << EOF
# Architecture

*Auto-generated from code analysis. Please edit to refine.*

## System Overview

*TODO: Add system overview*

## Components

*TODO: Add component details*

## Data Flow

*TODO: Add data flow description*

## Integration Points

*TODO: Add integration details*
EOF
    success "Created $output_dir/architecture.md"
  else
    log "Skipping architecture.md generation (file already exists)"
  fi
  
  # Generate roadmap.md if it doesn't exist
  if [[ ! -f "$output_dir/roadmap.md" ]]; then
    log "Generating $output_dir/roadmap.md"
    cat > "$output_dir/roadmap.md" << EOF
# Product Roadmap

*Auto-generated from code analysis. Please edit to refine.*

## Current Features

$features

## Planned Features

*TODO: Add planned features*

## Milestones

*TODO: Add milestone details*
EOF
    success "Created $output_dir/roadmap.md"
  else
    log "Skipping roadmap.md generation (file already exists)"
  fi
  
  success "Documentation generation completed"
  return 0
}

# Generate minimal documentation when jq is not available
generate_minimal_docs() {
  local output_dir="$1"
  local context_notes="${2:-}"
  
  log "Generating minimal documentation in $output_dir"
  
  # Ensure output directory exists
  mkdir -p "$output_dir"
  
  # Generate mission.md
  if [[ ! -f "$output_dir/mission.md" ]]; then
    cat > "$output_dir/mission.md" << EOF
# Mission Statement

*Auto-generated from code analysis. Please edit to refine.*

$([ -n "$context_notes" ] && echo -e "$context_notes\n\n")
## Purpose

*TODO: Add mission statement*
EOF
    success "Created minimal $output_dir/mission.md"
  fi
  
  # Generate tech-stack.md
  if [[ ! -f "$output_dir/tech-stack.md" ]]; then
    cat > "$output_dir/tech-stack.md" << EOF
# Technology Stack

*Auto-generated from code analysis. Please edit to refine.*

## Primary Technologies

*TODO: Add primary technologies*

## Frameworks and Libraries

*TODO: Add framework and library details*
EOF
    success "Created minimal $output_dir/tech-stack.md"
  fi
  
  # Generate architecture.md
  if [[ ! -f "$output_dir/architecture.md" ]]; then
    cat > "$output_dir/architecture.md" << EOF
# Architecture

*Auto-generated from code analysis. Please edit to refine.*

## System Overview

*TODO: Add system overview*
EOF
    success "Created minimal $output_dir/architecture.md"
  fi
  
  # Generate roadmap.md
  if [[ ! -f "$output_dir/roadmap.md" ]]; then
    cat > "$output_dir/roadmap.md" << EOF
# Product Roadmap

*Auto-generated from code analysis. Please edit to refine.*

## Current Features

*TODO: List current features*

## Planned Features

*TODO: Add planned features*
EOF
    success "Created minimal $output_dir/roadmap.md"
  fi
  
  success "Minimal documentation generation completed"
  return 0
}

# Main function to coordinate the analysis process
analyze_product() {
  local inputs_file="$1"
  local repo_path="$2"
  local output_dir="${3:-$DEFAULT_DOCS_DIR}"
  
  log "Starting product analysis process for $repo_path"
  
  # Extract inputs from file
  local context_notes
  context_notes=$(parse_inputs_file "$inputs_file" "context_notes" "")
  
  local auto_init
  auto_init=$(parse_inputs_file "$inputs_file" "auto_init_product" "false")
  
  # Run discovery
  if ! run_discovery "$repo_path" "$auto_init"; then
    error "Discovery process failed"
    return 1
  fi
  
  # Generate documentation
  if ! generate_docs "$PRODUCT_CONTEXT_CACHE" "$output_dir" "$context_notes"; then
    error "Documentation generation failed"
    return 1
  fi
  
  # Generate cacheability report if profiling is enabled
  if [[ "$PROFILING" == "true" ]]; then
    # Check if token estimation functions are available
    if declare -f estimate_token_usage &>/dev/null; then
      estimate_token_usage "$inputs_file" "product_analysis"
      log "Estimated token usage: $(get_token_estimate) tokens"
    else
      warning "Token estimation functions not available, skipping token usage profile"
    fi
  fi
  
  success "Product analysis completed successfully"
  log "Documentation created in $output_dir"
  log "Next steps: Review and customize the generated documentation files"
  
  return 0
}

# Process command line arguments
PROFILING=false
OUTPUT_DIR="$DEFAULT_DOCS_DIR"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    --profile)
      PROFILING=true
      shift
      ;;
    --no-cache)
      USE_CACHE=false
      shift
      ;;
    --repo-path)
      REPO_PATH="$2"
      shift 2
      ;;
    --init-product)
      AUTO_INIT_PRODUCT=true
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      # Assume this is the inputs file
      INPUTS_FILE="$1"
      shift
      ;;
  esac
done

# Check if inputs file was provided
if [[ -z ${INPUTS_FILE:-} ]]; then
  error "No inputs file provided"
  show_help
  exit 1
fi

# Check if inputs file exists
if [[ ! -f "$INPUTS_FILE" ]]; then
  error "Inputs file not found: $INPUTS_FILE"
  exit 1
fi

# Validate inputs
if ! validate_inputs "$INPUTS_FILE"; then
  error "Input validation failed"
  exit 1
fi

# Generate cache key for operation if cache is enabled
if [[ "$USE_CACHE" == "true" ]]; then
  CACHE_KEY=$(generate_cache_key "analyze_product" "$INPUTS_FILE")
  
  # Check if we have a valid cache for this operation
  if is_cache_valid "$CACHE_KEY"; then
    log "Using cached result for this analysis operation"
    # Load cached metadata and display
    load_cache_metadata "$CACHE_KEY"
    exit 0
  fi
fi

# Execute the main analysis function
analyze_product "$INPUTS_FILE" "$REPO_PATH" "$OUTPUT_DIR"

# Cache the operation result if cache is enabled
if [[ "$USE_CACHE" == "true" && $? -eq 0 ]]; then
  # Check if proper cache_operation function is available
  if declare -f -F cache_operation | grep -q "cache_operation is a function"; then
    # Cache successful operation with relevant metadata
    cache_operation "$CACHE_KEY" \
      "analyze_product" \
      "$INPUTS_FILE" \
      "Analyze product with documentation in $OUTPUT_DIR" \
      "$OUTPUT_DIR/mission.md $OUTPUT_DIR/tech-stack.md $OUTPUT_DIR/roadmap.md $OUTPUT_DIR/architecture.md"
  else
    debug "Skipping cache operation - function not properly defined"
  fi
fi
