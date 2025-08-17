#!/usr/bin/env bash
# plan-product.sh - Token-efficient implementation of product planning
#
# This script processes product planning requests in a token-efficient manner
# It handles roadmap creation, documentation generation, and milestone tracking
# using deterministic operations where possible to minimize token usage
#
# Usage: ./plan-product.sh [options] <inputs_file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import common utilities
source "$SCRIPT_DIR/context-estimator.sh"
source "$SCRIPT_DIR/context-cache-manager.sh"

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

# Logging functions
log() { echo -e "${BLUE}[plan-product]${NC} $*"; }
error() { echo -e "${RED}[plan-product][ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[plan-product][SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[plan-product][WARNING]${NC} $*"; }
debug() { [[ "$VERBOSITY" == "debug" ]] && echo -e "[DEBUG][plan-product] $*" || true; }

# Show help message
show_help() {
  cat << EOF
Usage: $0 [options] <inputs_file>

Plan a new product and generate essential documentation using token-efficient approaches.

Options:
  -h, --help           Show this help message and exit
  --profile            Enable token usage profiling
  --no-cache           Disable caching for this execution
  --template-dir DIR   Use custom templates from directory DIR
  --output-dir DIR     Output documentation to DIR (default: ./docs)

Examples:
  $0 product-planning-inputs.md
  $0 --profile product-planning-inputs.md
EOF
}

# Parse inputs file to extract key parameters
parse_inputs_file() {
  local inputs_file="$1"
  local field="$2"
  local default_value="${3:-}"
  
  # Ensure inputs file exists
  if [[ ! -f "$inputs_file" ]]; then
    error "Inputs file not found: $inputs_file"
    return 1
  fi
  
  # Extract content between [plan_inputs] and [/plan_inputs] markers
  local plan_section
  plan_section=$(sed -n '/\[plan_inputs\]/,/\[\/plan_inputs\]/p' "$inputs_file")
  
  # For key_features and target_users which are arrays
  if [[ "$field" == "key_features" || "$field" == "target_users" ]]; then
    grep -A 20 "^$field:" <<< "$plan_section" | grep -v "^$field:" | grep "^\s*-" | sed 's/^\s*-\s*//' | sed '/^\s*$/d' | sed '/^\[/,$d'
    return $?
  fi
  
  # For scalar fields
  local value
  value=$(grep -A 1 "^$field:" <<< "$plan_section" | tail -n 1 | sed 's/^\s*//')
  
  if [[ -n "$value" && "$value" != \[* ]]; then
    echo "$value"
    return 0
  fi
  
  if [[ -n "$default_value" ]]; then
    echo "$default_value"
    return 0
  fi
  
  return 1
}

# Validate required inputs
validate_inputs() {
  local inputs_file="$1"
  local errors=()
  
  # Check for required fields
  main_idea=$(parse_inputs_file "$inputs_file" "main_idea" || echo "")
  if [[ -z "$main_idea" ]]; then
    errors+=("Missing required field: main_idea")
  fi
  
  key_features=$(parse_inputs_file "$inputs_file" "key_features" || echo "")
  feature_count=$(echo "$key_features" | grep -v "^\s*$" | wc -l)
  if [[ $feature_count -lt 3 ]]; then
    errors+=("Not enough key_features: minimum 3 required, found $feature_count")
  fi
  
  target_users=$(parse_inputs_file "$inputs_file" "target_users" || echo "")
  user_count=$(echo "$target_users" | grep -v "^\s*$" | wc -l)
  if [[ $user_count -lt 1 ]]; then
    errors+=("Missing required field: target_users (minimum 1)")
  fi
  
  project_initialized=$(parse_inputs_file "$inputs_file" "project_initialized" "no")
  if [[ "$project_initialized" != "yes" && "$project_initialized" != "no" ]]; then
    errors+=("Invalid value for project_initialized: must be 'yes' or 'no'")
  fi
  
  # Return validation results
  if [[ ${#errors[@]} -gt 0 ]]; then
    for err in "${errors[@]}"; do
      error "$err"
    done
    return 1
  fi
  
  return 0
}

# Generate documentation structure based on templates
generate_docs_structure() {
  local output_dir="$1"
  local template_dir="${2:-$SCRIPT_DIR/../templates}"
  
  log "Generating documentation structure in $output_dir"
  
  # Ensure output directory exists
  mkdir -p "$output_dir"
  
  # Create standard documentation files based on templates
  if [[ -d "$template_dir" ]]; then
    # Create mission.md if template exists
    if [[ -f "$template_dir/mission.md" ]]; then
      cp "$template_dir/mission.md" "$output_dir/mission.md"
      success "Created $output_dir/mission.md"
    fi
    
    # Create tech-stack.md if template exists
    if [[ -f "$template_dir/tech-stack.md" ]]; then
      cp "$template_dir/tech-stack.md" "$output_dir/tech-stack.md"
      success "Created $output_dir/tech-stack.md"
    fi
    
    # Create roadmap.md if template exists
    if [[ -f "$template_dir/roadmap.md" ]]; then
      cp "$template_dir/roadmap.md" "$output_dir/roadmap.md"
      success "Created $output_dir/roadmap.md"
    fi
    
    # Create architecture.md if template exists
    if [[ -f "$template_dir/architecture.md" ]]; then
      cp "$template_dir/architecture.md" "$output_dir/architecture.md"
      success "Created $output_dir/architecture.md"
    fi
  else
    warning "Template directory not found: $template_dir"
    warning "Creating minimal documentation structure"
    
    # Create minimal documentation files
    echo "# Mission Statement\n\n*TODO: Add mission statement here*" > "$output_dir/mission.md"
    success "Created $output_dir/mission.md"
    
    echo "# Technology Stack\n\n*TODO: Define technology stack here*" > "$output_dir/tech-stack.md"
    success "Created $output_dir/tech-stack.md"
    
    echo "# Product Roadmap\n\n*TODO: Define product roadmap here*" > "$output_dir/roadmap.md"
    success "Created $output_dir/roadmap.md"
    
    echo "# Architecture\n\n*TODO: Define system architecture here*" > "$output_dir/architecture.md"
    success "Created $output_dir/architecture.md"
  fi
}

# Update documentation with content from inputs
update_docs_with_inputs() {
  local inputs_file="$1"
  local output_dir="$2"
  
  log "Updating documentation with inputs from $inputs_file"
  
  # Extract inputs
  local main_idea
  main_idea=$(parse_inputs_file "$inputs_file" "main_idea")
  
  local tech_stack
  tech_stack=$(parse_inputs_file "$inputs_file" "tech_stack_preferences" "Not specified")
  
  # Update mission.md with main idea
  if [[ -f "$output_dir/mission.md" ]]; then
    # Create temporary file with updated content
    local temp_file
    temp_file=$(mktemp)
    
    # Replace placeholder with actual content
    sed "s|*TODO: Add mission statement here*|$main_idea|g" "$output_dir/mission.md" > "$temp_file"
    
    # Move temporary file to original location
    mv "$temp_file" "$output_dir/mission.md"
    success "Updated mission.md with main idea"
  fi
  
  # Update tech-stack.md with preferences
  if [[ -f "$output_dir/tech-stack.md" ]]; then
    # Create temporary file with updated content
    local temp_file
    temp_file=$(mktemp)
    
    # Replace placeholder with actual content
    sed "s|*TODO: Define technology stack here*|$tech_stack|g" "$output_dir/tech-stack.md" > "$temp_file"
    
    # Move temporary file to original location
    mv "$temp_file" "$output_dir/tech-stack.md"
    success "Updated tech-stack.md with preferences"
  fi
  
  # Update roadmap.md with features as initial milestones
  if [[ -f "$output_dir/roadmap.md" ]]; then
    # Extract features
    local key_features
    key_features=$(parse_inputs_file "$inputs_file" "key_features")
    
    # Create temporary file with updated content
    local temp_file
    temp_file=$(mktemp)
    
    # Create roadmap content with features as milestones
    {
      echo "# Product Roadmap"
      echo ""
      echo "## Milestones"
      echo ""
      
      # Add each feature as a milestone
      while IFS= read -r feature; do
        echo "### Milestone: $feature"
        echo ""
        echo "- [ ] *TODO: Break down tasks for this milestone*"
        echo ""
      done <<< "$key_features"
      
    } > "$temp_file"
    
    # Move temporary file to original location
    mv "$temp_file" "$output_dir/roadmap.md"
    success "Updated roadmap.md with features as milestones"
  fi
}

# Initialize project structure if needed
initialize_project() {
  local project_initialized="$1"
  
  if [[ "$project_initialized" == "no" ]]; then
    log "Initializing project structure"
    
    # Create standard directories
    mkdir -p docs
    mkdir -p src
    mkdir -p test
    
    # Create .gitignore if it doesn't exist
    if [[ ! -f .gitignore ]]; then
      cat > .gitignore << EOF
# Dependencies
node_modules/
vendor/
.env

# Build artifacts
dist/
build/
*.log

# IDE and editor files
.vscode/
.idea/
*.swp
*~

# OS specific
.DS_Store
Thumbs.db
EOF
      success "Created .gitignore file"
    fi
    
    # Create README.md if it doesn't exist
    if [[ ! -f README.md ]]; then
      cat > README.md << EOF
# Project

*TODO: Add project description*

## Getting Started

*TODO: Add setup instructions*

## Features

*TODO: List key features*

## Documentation

See the [docs](./docs) directory for detailed documentation.
EOF
      success "Created README.md file"
    fi
    
    success "Project structure initialized"
  else
    log "Project already initialized, skipping initialization"
  fi
}

# Main function to orchestrate the planning process
plan_product() {
  local inputs_file="$1"
  local output_dir="${2:-$DEFAULT_DOCS_DIR}"
  local template_dir="${3:-$SCRIPT_DIR/../templates}"
  
  log "Starting product planning process"
  
  # Validate inputs
  if ! validate_inputs "$inputs_file"; then
    error "Input validation failed"
    return 1
  fi
  success "Input validation successful"
  
  # Check if we should initialize the project
  local project_initialized
  project_initialized=$(parse_inputs_file "$inputs_file" "project_initialized" "no")
  initialize_project "$project_initialized"
  
  # Generate documentation structure
  generate_docs_structure "$output_dir" "$template_dir"
  
  # Update documentation with inputs
  update_docs_with_inputs "$inputs_file" "$output_dir"
  
  # Generate cacheability report if profiling is enabled
  if [[ "$PROFILING" == "true" ]]; then
    estimate_token_usage "$inputs_file" "product_planning"
    log "Estimated token usage: $(get_token_estimate) tokens"
  fi
  
  success "Product planning completed successfully"
  log "Documentation created in $output_dir"
  log "Next steps: Review and customize the generated documentation files"
}

# Process command line arguments
PROFILING=false
TEMPLATE_DIR="$SCRIPT_DIR/../templates"
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
    --template-dir)
      TEMPLATE_DIR="$2"
      shift 2
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

# Generate cache key for operation if cache is enabled
if [[ "$USE_CACHE" == "true" ]]; then
  CACHE_KEY=$(generate_cache_key "plan_product" "$INPUTS_FILE")
  
  # Check if we have a valid cache for this operation
  if is_cache_valid "$CACHE_KEY"; then
    log "Using cached result for this planning operation"
    # Load cached metadata and display
    load_cache_metadata "$CACHE_KEY"
    exit 0
  fi
fi

# Execute the main planning function
plan_product "$INPUTS_FILE" "$OUTPUT_DIR" "$TEMPLATE_DIR"

# Cache the operation result if cache is enabled
if [[ "$USE_CACHE" == "true" && $? -eq 0 ]]; then
  # Cache successful operation with relevant metadata
  cache_operation "$CACHE_KEY" \
    "plan_product" \
    "$INPUTS_FILE" \
    "Plan product with documentation in $OUTPUT_DIR" \
    "$OUTPUT_DIR/mission.md $OUTPUT_DIR/tech-stack.md $OUTPUT_DIR/roadmap.md $OUTPUT_DIR/architecture.md"
fi
