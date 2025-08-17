#!/usr/bin/env bash
# context-gatherer-simple.sh - Very simplified version of hierarchical context gathering

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
OPERATION_TYPE="default"
CONTEXT_TIER="all"
MAX_TOKENS=4000

# Colorization for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[gatherer]${NC} $*"; }
error() { echo -e "${RED}[gatherer][ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[gatherer][SUCCESS]${NC} $*"; }
token_info() { echo -e "${CYAN}[gatherer][TOKENS]${NC} $*"; }

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

# Gather essential context
gather_essential() {
  local context_type="$1"
  local output_file="$2"
  
  log "Gathering essential $context_type context..."
  
  # Initialize context file with header
  echo "# Essential $context_type Context" > "$output_file"
  local tokens=0
  
  case "$context_type" in
    "product")
      # README.md is essential for product
      if [[ -f "$ROOT_DIR/README.md" ]]; then
        echo -e "\n## Overview\n" >> "$output_file"
        head -10 "$ROOT_DIR/README.md" >> "$output_file"
        tokens=50
      fi
      ;;
      
    "spec")
      # spec.md is essential for specs
      if [[ -f "$ROOT_DIR/spec.md" ]]; then
        echo -e "\n## Requirements\n" >> "$output_file"
        head -20 "$ROOT_DIR/spec.md" >> "$output_file"
        tokens=75
      fi
      ;;
      
    "repo")
      # Structure is essential for repo
      echo -e "\n## Project Structure\n" >> "$output_file"
      echo -e "```" >> "$output_file"
      find "$ROOT_DIR" -maxdepth 2 -type d | head -10 | sed "s|$ROOT_DIR/||" >> "$output_file"
      echo -e "```\n" >> "$output_file"
      tokens=50
      ;;
  esac
  
  token_info "Essential context: $tokens tokens"
  return $tokens
}

# Gather conditional context
gather_conditional() {
  local context_type="$1"
  local output_file="$2"
  
  log "Gathering conditional $context_type context..."
  
  echo -e "\n# Conditional $context_type Context" >> "$output_file"
  local tokens=0
  
  case "$context_type" in
    "product")
      # Tech stack for product
      if [[ -f "$ROOT_DIR/standards/tech-stack.md" ]]; then
        echo -e "\n## Tech Stack\n" >> "$output_file"
        head -20 "$ROOT_DIR/standards/tech-stack.md" >> "$output_file"
        tokens=150
      fi
      ;;
      
    "spec")
      # Implementation details
      if [[ -d "$ROOT_DIR/docs" ]]; then
        echo -e "\n## Implementation Details\n" >> "$output_file"
        find "$ROOT_DIR/docs" -name "*.md" | head -1 | xargs head -10 >> "$output_file" 2>/dev/null || true
        tokens=125
      fi
      ;;
  esac
  
  token_info "Conditional context: $tokens tokens"
  return $tokens
}

# Gather reference context
gather_reference() {
  local context_type="$1"
  local output_file="$2"
  
  log "Gathering reference $context_type context..."
  
  echo -e "\n# Reference $context_type Context" >> "$output_file"
  local tokens=0
  
  case "$context_type" in
    "product")
      # Examples for product
      if [[ -d "$ROOT_DIR/examples" ]]; then
        echo -e "\n## Examples\n" >> "$output_file"
        find "$ROOT_DIR/examples" -name "*.md" | head -1 | xargs head -10 >> "$output_file" 2>/dev/null || true
        tokens=100
      fi
      ;;
      
    "spec")
      # Golden examples
      if [[ -d "$ROOT_DIR/examples/golden" ]]; then
        echo -e "\n## Golden Examples\n" >> "$output_file"
        find "$ROOT_DIR/examples/golden" -name "*.md" | head -1 | xargs head -10 >> "$output_file" 2>/dev/null || true
        tokens=100
      fi
      ;;
  esac
  
  token_info "Reference context: $tokens tokens"
  return $tokens
}

# Main function
gather_context() {
  local context_type="$1"
  local output_file="$2"
  
  log "Gathering context for $context_type (operation: $OPERATION_TYPE, tier: $CONTEXT_TIER)..."
  local total_tokens=0
  local tier_tokens=0
  
  # Gather context based on tier
  if [[ "$CONTEXT_TIER" == "essential" || "$CONTEXT_TIER" == "all" ]]; then
    gather_essential "$context_type" "$output_file"
    tier_tokens=$?
    total_tokens=$((total_tokens + tier_tokens))
  fi
  
  if [[ "$CONTEXT_TIER" == "conditional" || "$CONTEXT_TIER" == "all" ]]; then
    gather_conditional "$context_type" "$output_file"
    tier_tokens=$?
    total_tokens=$((total_tokens + tier_tokens))
  fi
  
  if [[ "$CONTEXT_TIER" == "reference" || "$CONTEXT_TIER" == "all" ]]; then
    gather_reference "$context_type" "$output_file"
    tier_tokens=$?
    total_tokens=$((total_tokens + tier_tokens))
  fi
  
  # Add summary
  echo -e "\n## Context Summary\n" >> "$output_file"
  echo -e "- Context type: $context_type" >> "$output_file"
  echo -e "- Operation: $OPERATION_TYPE" >> "$output_file"
  echo -e "- Tier: $CONTEXT_TIER" >> "$output_file"
  echo -e "- Total tokens: $total_tokens" >> "$output_file"
  echo -e "- Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
  
  token_info "Total context: $total_tokens tokens"
  success "Context written to $output_file"
}

# Show help
show_help() {
  cat << EOF
Usage: $0 [options] <context-type> <output-file>

Options:
  --operation TYPE    Operation type (create-spec, analyze-product, etc.)
  --tier TIER         Context tier (essential, conditional, reference, all)
  --help              Show this help message

Context Types:
  product, spec, repo, tasks

Examples:
  $0 --tier essential product context.md
  $0 --operation create-spec --tier all spec spec-context.md
EOF
}

# Parse arguments
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
      # Positional arguments
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
  error "Missing context type"
  show_help
  exit 1
fi

if [[ -z "${output_file:-}" ]]; then
  error "Missing output file"
  show_help
  exit 1
fi

# Run main function
gather_context "$context_type" "$output_file"
