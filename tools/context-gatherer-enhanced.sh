#!/usr/bin/env bash
# context-gatherer-enhanced.sh - Simplified version of the hierarchical context gathering implementation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$ROOT_DIR/.agent-os/cache"
mkdir -p "$CACHE_DIR"

# Default configuration
OPERATION_TYPE="default"
CONTEXT_TIER="all"
TRACK_SECTIONS="false"
VERBOSE="false"
MAX_TOKENS=4000

# Colorization for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[context-gatherer]${NC} $*"; }
error() { echo -e "${RED}[context-gatherer][ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[context-gatherer][SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[context-gatherer][WARNING]${NC} $*"; }
token_info() { echo -e "${CYAN}[context-gatherer][TOKENS]${NC} $*"; }

# Extract a section from a markdown file
extract_section() {
  local file="$1"
  local section_name="$2"

  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 1
  fi

  # Use sed to extract content between section headers (## Section)
  sed -n "/^## $section_name/,/^## /p" "$file" | sed '$d'
}

# Calculate token count estimate for a text
estimate_tokens() {
  local text="$1"
  # Rough estimation: ~4 chars per token for English text
  local char_count=${#text}
  echo $(( char_count / 4 ))
}

# Generate hash for a specific section
hash_section() {
  local file="$1"
  local section_name="$2"

  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 1
  fi

  # Extract section, normalize whitespace, and hash
  local content=$(extract_section "$file" "$section_name")
  echo "$content" | sha256sum | awk '{print $1}'
}

# Gather essential context for a context type
gather_essential_context() {
  local context_type="$1"
  local output_file="$2"
  local tokens_used=0
  
  log "Gathering essential context for $context_type..."
  
  # Initialize context file with header
  echo "# Essential $context_type Context" > "$output_file"
  
  case "$context_type" in
    "product")
      # Product mission is always essential
      if [[ -f "$ROOT_DIR/README.md" ]]; then
        echo -e "\n## Overview\n" >> "$output_file"
        if extract_section "$ROOT_DIR/README.md" "Overview" > /dev/null 2>&1; then
          extract_section "$ROOT_DIR/README.md" "Overview" >> "$output_file"
        else
          head -10 "$ROOT_DIR/README.md" >> "$output_file"
        fi
        tokens_used=$((tokens_used + 50))
      fi
      ;;
    
    "spec")
      # Core requirements are essential for specs
      if [[ -f "$ROOT_DIR/spec.md" ]]; then
        echo -e "\n## Requirements\n" >> "$output_file"
        if extract_section "$ROOT_DIR/spec.md" "Requirements" > /dev/null 2>&1; then
          extract_section "$ROOT_DIR/spec.md" "Requirements" >> "$output_file"
        else
          echo "No requirements section found in spec.md" >> "$output_file"
        fi
        tokens_used=$((tokens_used + 75))
      fi
      ;;
      
    "repo")
      # Core structure is essential for repo context
      echo -e "\n## Project Structure\n" >> "$output_file"
      echo -e "```" >> "$output_file"
      find "$ROOT_DIR" -maxdepth 2 -type d -not -path "*/\.*" -not -path "*/node_modules/*" | 
        sort | 
        sed "s|$ROOT_DIR/||" | 
        grep -v "^$" | 
        sed 's/^/  /' >> "$output_file"
      echo -e "```\n" >> "$output_file"
      tokens_used=100
      ;;
  esac
  
  token_info "Essential context: $tokens_used tokens"
  echo "$tokens_used"
}

# Gather conditional context for a context type
gather_conditional_context() {
  local context_type="$1"
  local output_file="$2"
  local tokens_added=0
  
  log "Gathering conditional context for $context_type..."
  
  echo -e "\n# Conditional $context_type Context" >> "$output_file"
  
  case "$context_type" in
    "product")
      # Tech stack is conditional for product
      if [[ -f "$ROOT_DIR/standards/tech-stack.md" ]]; then
        echo -e "\n## Tech Stack\n" >> "$output_file"
        head -20 "$ROOT_DIR/standards/tech-stack.md" >> "$output_file"
        tokens_added=150
      fi
      ;;
      
    "spec")
      # Implementation details are conditional for specs
      if [[ -f "$ROOT_DIR/spec.md" ]]; then
        echo -e "\n## Implementation\n" >> "$output_file"
        if extract_section "$ROOT_DIR/spec.md" "Implementation" > /dev/null 2>&1; then
          extract_section "$ROOT_DIR/spec.md" "Implementation" >> "$output_file"
        else
          echo "No implementation section found in spec.md" >> "$output_file"
        fi
        tokens_added=200
      fi
      ;;
  esac
  
  token_info "Conditional context: $tokens_added tokens"
  echo "$tokens_added"
}

# Gather reference context for a context type
gather_reference_context() {
  local context_type="$1"
  local output_file="$2"
  local tokens_added=0
  
  log "Gathering reference context for $context_type..."
  
  echo -e "\n# Reference $context_type Context" >> "$output_file"
  
  case "$context_type" in
    "product")
      # Examples are reference for product
      if [[ -d "$ROOT_DIR/examples" ]]; then
        echo -e "\n## Examples\n" >> "$output_file"
        find "$ROOT_DIR/examples" -maxdepth 1 -type f -name "*.md" | 
          head -1 | 
          xargs cat | 
          head -20 >> "$output_file"
        tokens_added=200
      fi
      ;;
      
    "spec")
      # Example specs are reference
      if [[ -d "$ROOT_DIR/examples/golden" ]]; then
        echo -e "\n## Example Specs\n" >> "$output_file"
        find "$ROOT_DIR/examples/golden" -name "*.md" | 
          head -1 | 
          xargs cat | 
          head -20 >> "$output_file"
        tokens_added=200
      fi
      ;;
  esac
  
  token_info "Reference context: $tokens_added tokens"
  echo "$tokens_added"
}

# Main function to gather hierarchical context
gather_hierarchical_context() {
  local context_type="$1"
  local output_file="$2"
  local total_tokens=0
  
  log "Gathering hierarchical context for $context_type (operation: $OPERATION_TYPE)..."
  
  # Always include essential context (Tier 1)
  if [[ "$CONTEXT_TIER" == "essential" || "$CONTEXT_TIER" == "all" ]]; then
    local essential_tokens
    essential_tokens=$(gather_essential_context "$context_type" "$output_file")
    total_tokens=$((total_tokens + essential_tokens))
  fi
  
  # Include conditional context (Tier 2)
  if [[ "$CONTEXT_TIER" == "conditional" || "$CONTEXT_TIER" == "all" ]]; then
    local conditional_tokens
    conditional_tokens=$(gather_conditional_context "$context_type" "$output_file")
    total_tokens=$((total_tokens + conditional_tokens))
  fi
  
  # Include reference context (Tier 3)
  if [[ "$CONTEXT_TIER" == "reference" || "$CONTEXT_TIER" == "all" ]]; then
    local reference_tokens
    reference_tokens=$(gather_reference_context "$context_type" "$output_file")
    total_tokens=$((total_tokens + reference_tokens))
  fi
  
  # Add summary of token usage
  echo -e "\n## Context Summary\n" >> "$output_file"
  echo -e "- Context type: $context_type" >> "$output_file"
  echo -e "- Operation: $OPERATION_TYPE" >> "$output_file"
  echo -e "- Total tokens: $total_tokens" >> "$output_file"
  echo -e "- Generated: $(date -u "+%Y-%m-%d %H:%M:%S UTC")" >> "$output_file"
  
  token_info "Total context gathered: $total_tokens tokens (budget: $MAX_TOKENS)"
  success "Hierarchical context written to $output_file ($total_tokens tokens)"
}

# Show help message
show_help() {
  cat << EOF
Usage: $0 [options] <context-type> <output-file>

Options:
  --operation TYPE    Operation type (create-spec, analyze-product, etc.)
  --tier TIER         Limit to specific tier (essential, conditional, reference, all)
  --track-sections    Enable section-level hash tracking
  --verbose           Show detailed context selection information
  --max-tokens N      Set maximum token budget (default: 4000)

Context Types:
  product             Product context (mission, requirements)
  spec                Specification context (requirements, implementation)
  repo                Repository context (structure, files)
  tasks               Tasks context (current tasks, dependencies)

Examples:
  $0 --tier essential product context.md
  $0 --operation create-spec spec spec-context.md
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --operation)
      OPERATION_TYPE="$2"
      shift 2
      ;;
    --tier)
      CONTEXT_TIER="$2"
      shift 2
      ;;
    --track-sections)
      TRACK_SECTIONS="true"
      shift
      ;;
    --verbose)
      VERBOSE="true"
      shift
      ;;
    --max-tokens)
      MAX_TOKENS="$2"
      shift 2
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    -*)
      error "Unknown option: $1"
      show_help
      exit 1
      ;;
    *)
      # Non-option arguments: context_type and output_file
      if [[ -z "${context_type:-}" ]]; then
        context_type="$1"
      elif [[ -z "${output_file:-}" ]]; then
        output_file="$1"
      else
        error "Too many arguments"
        show_help
        exit 1
      fi
      shift
      ;;
  esac
done

# Check required arguments
if [[ -z "${context_type:-}" ]]; then
  error "Context type is required"
  show_help
  exit 1
fi

if [[ -z "${output_file:-}" ]]; then
  error "Output file is required"
  show_help
  exit 1
fi

# Validate context type
case "$context_type" in
  product|spec|repo|tasks)
    # Valid context type
    ;;
  *)
    error "Invalid context type: $context_type"
    show_help
    exit 1
    ;;
esac

# Execute the main function
gather_hierarchical_context "$context_type" "$output_file"
