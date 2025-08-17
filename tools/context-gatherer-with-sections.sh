#!/usr/bin/env bash
# context-gatherer-with-sections.sh - Simple version with section hashing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
OPERATION_TYPE="default"
CONTEXT_TIER="all"
MAX_TOKENS=4000
TRACK_SECTIONS=false
CONTEXT_CACHE_DIR="$ROOT_DIR/.context-cache"

# Colorization for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[gatherer]${NC} $*"; }
error() { echo -e "${RED}[gatherer][ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[gatherer][SUCCESS]${NC} $*"; }
token_info() { echo -e "${CYAN}[gatherer][TOKENS]${NC} $*"; }
warn() { echo -e "${YELLOW}[gatherer][WARN]${NC} $*"; }

# Cross-platform sha256
sha256_text() {
  # reads stdin, prints hex sha256
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -binary | od -An -tx1 | tr -d ' \n'
  else
    error "No sha256 tool found (sha256sum/shasum/openssl)"
    exit 1
  fi
}

# Extract a section from a markdown file
extract_section() {
  local file="$1"
  local section_name="$2"

  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 1
  fi

  # Use sed to extract content between section headers (## Section)
  # Normalize CRLF for cross-platform robustness
  sed -n "/^## $section_name/,/^## /p" "$file" | sed '$d' | sed -e 's/\r$//'
}

# Hash a section
hash_section() {
  local file="$1"
  local section_name="$2"
  
  # Normalize CRLF before hashing to ensure stability across platforms
  extract_section "$file" "$section_name" | tr -d '\r' | sha256_text
}

# Initialize cache
init_cache() {
  mkdir -p "$CONTEXT_CACHE_DIR"
  if [[ ! -f "$CONTEXT_CACHE_DIR/sections.json" ]]; then
    echo '{"sections":{}}' > "$CONTEXT_CACHE_DIR/sections.json"
  fi
}

# Check if section has changed
section_changed() {
  local file="$1"
  local section="$2"
  
  if [[ "$TRACK_SECTIONS" != "true" ]]; then
    return 0  # Always treat as changed if not tracking
  fi
  
  init_cache
  
  local hash
  hash=$(hash_section "$file" "$section" 2>/dev/null || echo "none")
  
  local section_key="${file}:${section}"
  section_key=${section_key//\//_}
  
  # Simple text-based cache for sections
  local cache_file="$CONTEXT_CACHE_DIR/sections.txt"
  touch "$cache_file"
  
  if grep -q "^${section_key}=" "$cache_file" 2>/dev/null; then
    local cached_hash
    cached_hash=$(grep "^${section_key}=" "$cache_file" | cut -d= -f2)
    if [[ "$hash" == "$cached_hash" ]]; then
      log "Section '$section' unchanged"
      return 1  # Not changed (false)
    fi
  fi
  
  # Update cache
  grep -v "^${section_key}=" "$cache_file" > "${cache_file}.tmp" 2>/dev/null || true
  echo "${section_key}=${hash}" >> "${cache_file}.tmp"
  mv "${cache_file}.tmp" "$cache_file"
  
  log "Section '$section' changed or new"
  return 0  # Changed (true)
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
        
        if section_changed "$ROOT_DIR/README.md" "Overview"; then
          if extract_section "$ROOT_DIR/README.md" "Overview" > /dev/null 2>&1; then
            extract_section "$ROOT_DIR/README.md" "Overview" >> "$output_file"
          else
            head -10 "$ROOT_DIR/README.md" >> "$output_file"
          fi
        else
          head -10 "$ROOT_DIR/README.md" >> "$output_file"
        fi
        tokens=50
      fi
      ;;
      
    "spec")
      # spec.md is essential for specs
      if [[ -f "$ROOT_DIR/spec.md" ]]; then
        echo -e "\n## Requirements\n" >> "$output_file"
        
        if section_changed "$ROOT_DIR/spec.md" "Requirements"; then
          if extract_section "$ROOT_DIR/spec.md" "Requirements" > /dev/null 2>&1; then
            extract_section "$ROOT_DIR/spec.md" "Requirements" >> "$output_file"
          else
            head -20 "$ROOT_DIR/spec.md" >> "$output_file"
          fi
        else
          head -20 "$ROOT_DIR/spec.md" >> "$output_file"
        fi
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
        
        if section_changed "$ROOT_DIR/standards/tech-stack.md" "Tech Stack"; then
          if extract_section "$ROOT_DIR/standards/tech-stack.md" "Tech Stack" > /dev/null 2>&1; then
            extract_section "$ROOT_DIR/standards/tech-stack.md" "Tech Stack" >> "$output_file"
          else
            head -20 "$ROOT_DIR/standards/tech-stack.md" >> "$output_file"
          fi
        else
          head -20 "$ROOT_DIR/standards/tech-stack.md" >> "$output_file"
        fi
        tokens=150
      fi
      ;;
      
    "spec")
      # Implementation details
      if [[ -d "$ROOT_DIR/docs" ]]; then
        echo -e "\n## Implementation Details\n" >> "$output_file"
        
        # Find first implementation doc
        local impl_doc
        impl_doc=$(find "$ROOT_DIR/docs" -name "*implementation*.md" -type f -print -quit)
        
        if [[ -n "$impl_doc" ]]; then
          if section_changed "$impl_doc" "Implementation"; then
            if extract_section "$impl_doc" "Implementation" > /dev/null 2>&1; then
              extract_section "$impl_doc" "Implementation" >> "$output_file"
            else
              head -10 "$impl_doc" >> "$output_file"
            fi
          else
            head -10 "$impl_doc" >> "$output_file"
          fi
        fi
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
        
        local example_file
        example_file=$(find "$ROOT_DIR/examples" -name "*.md" -type f -print -quit)
        
        if [[ -n "$example_file" ]]; then
          if section_changed "$example_file" "Examples"; then
            if extract_section "$example_file" "Examples" > /dev/null 2>&1; then
              extract_section "$example_file" "Examples" >> "$output_file"
            else
              head -10 "$example_file" >> "$output_file"
            fi
          else
            head -10 "$example_file" >> "$output_file"
          fi
        fi
        
        tokens=100
      fi
      ;;
      
    "spec")
      # Golden examples
      if [[ -d "$ROOT_DIR/examples/golden" ]]; then
        echo -e "\n## Golden Examples\n" >> "$output_file"
        
        local golden_file
        golden_file=$(find "$ROOT_DIR/examples/golden" -name "*.md" -type f -print -quit)
        
        if [[ -n "$golden_file" ]]; then
          if section_changed "$golden_file" "Examples"; then
            if extract_section "$golden_file" "Examples" > /dev/null 2>&1; then
              extract_section "$golden_file" "Examples" >> "$output_file"
            else
              head -10 "$golden_file" >> "$output_file"
            fi
          else
            head -10 "$golden_file" >> "$output_file"
          fi
        fi
        
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
  echo -e "- Section tracking: $TRACK_SECTIONS" >> "$output_file"
  echo -e "- Total tokens: $total_tokens" >> "$output_file"
  echo -e "- Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
  
  token_info "Total context: $total_tokens tokens"
  success "Context written to $output_file"
  
  # Return total tokens as exit code (for scripting)
  return $total_tokens
}

# Show help
show_help() {
  cat << EOF
Usage: $0 [options] <context-type> <output-file>

Options:
  --operation TYPE    Operation type (create-spec, analyze-product, etc.)
  --tier TIER         Context tier (essential, conditional, reference, all)
  --track-sections    Track section hashes for change detection
  --help              Show this help message

Context Types:
  product, spec, repo, tasks

Examples:
  $0 --tier essential product context.md
  $0 --operation create-spec --tier all spec spec-context.md
  $0 --operation analyze-product --track-sections --tier all product context.md
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
    --track-sections)
      TRACK_SECTIONS=true
      shift
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
exit $?
