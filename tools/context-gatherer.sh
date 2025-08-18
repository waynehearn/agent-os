#!/usr/bin/env bash
# context-gatherer.sh - A token-efficient script for intelligent context gathering
# 
# This script implements a hierarchical context loading strategy to optimize LLM token usage:
# - Priority-based context loading (essential → conditional → reference)
# - Section-level hash tracking for granular updates
# - Context selection optimization based on operation type
# - Integration with context-estimator.sh for token profiling
#
# Usage: ./context-gatherer.sh [options] [operation] [parameters...]
#
# Options:
#   --operation TYPE    Operation type (create-spec, analyze-product, etc.)
#   --tier TIER         Limit to specific tier (essential, conditional, reference)
#   --track-sections    Enable section-level hash tracking
#   --verbose           Show detailed context selection information
#   --max-tokens N      Set maximum token budget (default: 4000)
#
# Example:
#   ./context-gatherer.sh --operation create-spec --track-sections product context.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$ROOT_DIR/.agent-os/cache"
SECTION_MANIFEST="$CACHE_DIR/section-hashes.json"

# Shared operation cache (TTL + dedup)
USE_CACHE=${USE_CACHE:-1}
OPERATION_CACHE_TTL=${OPERATION_CACHE_TTL:-3600}
# Try to source the shared cache manager if available
if [[ -f "$SCRIPT_DIR/context-cache-manager.sh" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/context-cache-manager.sh"
fi

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Default configuration
OPERATION_TYPE="default"
CONTEXT_TIER="all"
TRACK_SECTIONS="false"
VERBOSE="false"
MAX_TOKENS=4000
ENABLE_PROFILING="${ENABLE_PROFILING:-0}"

# Colorization for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[context-gatherer]${NC} $*"; }
error() { echo -e "${RED}[context-gatherer][ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[context-gatherer][SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[context-gatherer][WARNING]${NC} $*"; }
detail() { if [[ "$VERBOSE" == "true" ]]; then echo -e "${GRAY}[context-gatherer][DETAIL]${NC} $*" >&2; fi; }
token_info() { echo -e "${CYAN}[context-gatherer][TOKENS]${NC} $*" >&2; }

# Help message
show_help() {
  cat << EOF
Usage: $0 [options] [operation] [parameters...]

Options:
  --operation TYPE      Operation type (create-spec, analyze-product, execute-tasks, plan-product)
  --tier TIER           Limit to specific tier (essential, conditional, reference, all)
  --track-sections      Enable section-level hash tracking
  --verbose             Show detailed context selection information
  --max-tokens N        Set maximum token budget (default: 4000)
  --no-cache            Disable shared operation cache
  --use-cache           Enable shared operation cache (default)
  --cache-ttl N         Override cache TTL seconds (default: 3600)
  --help, -h            Show this help message

Operations:
  gather-context [type] [output_file]     - Gather hierarchical context by type
  gather-product-context [output_file]     - Gather product context from available sources
  gather-project-structure [output_file]   - Generate project structure overview
  find-relevant-files [pattern] [output_file] - Find files matching the given pattern
  gather-tech-stack [output_file]          - Extract information about the tech stack
  gather-file-content [file_path] [output_file] - Extract content from a specific file
  hash-section [file_path] [section_name]   - Generate hash for a specific markdown section

Parameters:
  type                                   - Context type (product, spec, repo, tasks)
  output_file                            - Where to write the gathered context (default: stdout)
  pattern                                - File pattern to search for (e.g., "*.md", "*.js")
  file_path                              - Path to a specific file to extract
  section_name                           - Name of the markdown section (e.g., "Overview")

Examples:
  # Hierarchical context gathering
  $0 --operation create-spec gather-context product context.md
  $0 --tier essential gather-context spec spec-context.md
  $0 --track-sections gather-context repo repo-context.md
  
  # Traditional operations
  $0 gather-product-context product-context.json
  $0 gather-project-structure project-structure.md
  $0 find-relevant-files "*.md" markdown-files.txt
  
  # Section hash tracking
  $0 hash-section spec.md "Requirements"
EOF
}

# Section-level hash tracking

# Extract a section from a markdown file
extract_section() {
  local file="$1"
  local section_name="$2"

  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 1
  fi

  # Use sed to extract content between section headers (## Section)
  # This handles both "## Section" and "## Section Name with Spaces"
  # Normalize CRLF (remove carriage returns) to be robust on Windows checkouts
  sed -n "/^## $section_name/,/^## /p" "$file" | sed '$d' | sed -e 's/\r$//'
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
  # Normalize CRLF before hashing to ensure stable hashes across platforms
  extract_section "$file" "$section_name" |
    tr -d '\r' |
    tr -s '[:space:]' |
    sha256_text
}

# Get SHA-256 hash of text from stdin
sha256_text() {
  # reads stdin, prints hex sha256
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -binary | od -An -tx1 | tr -d ' \n'
  else
    die "No sha256 tool found (sha256sum/shasum/openssl)"
  fi
}

# Check if jq is available
check_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    error "jq is required for section hash tracking. Please install it."
    return 1
  fi
  return 0
}

# Initialize section manifest
init_section_manifest() {
  if [[ ! -f "$SECTION_MANIFEST" ]]; then
    if ! check_jq; then
      warning "Creating basic section manifest without jq"
      echo '{"sections":[]}' > "$SECTION_MANIFEST"
    else
      echo '{"sections":[]}' | jq . > "$SECTION_MANIFEST"
    fi
  fi
}

# Track section hash in manifest
track_section() {
  local file="$1"
  local section_name="$2"
  
  if ! check_jq; then
    warning "Skipping section tracking: jq not available"
    return 1
  fi
  
  # Ensure manifest exists
  init_section_manifest
  
  local rel_path="${file#$ROOT_DIR/}"
  local hash=$(hash_section "$file" "$section_name")
  local timestamp=$(date +%s)
  local section_content=$(extract_section "$file" "$section_name")
  local token_estimate=$(estimate_tokens "$section_content")
  
  detail "Tracking section: $rel_path » $section_name ($token_estimate tokens)"
  
  # Check if section exists in manifest
  local section_exists
  section_exists=$(jq --arg file "$rel_path" --arg section "$section_name" \
    '.sections | map(select(.file == $file and .section == $section)) | length' \
    "$SECTION_MANIFEST")
  
  if [[ "$section_exists" -gt 0 ]]; then
    # Update existing section
    jq --arg file "$rel_path" \
       --arg section "$section_name" \
       --arg hash "$hash" \
       --arg time "$timestamp" \
       --arg tokens "$token_estimate" \
       '.sections = (.sections | map(
          if .file == $file and .section == $section
          then . + {hash: $hash, last_updated: $time|tonumber, tokens: $tokens|tonumber}
          else .
          end
        ))' \
       "$SECTION_MANIFEST" > "$SECTION_MANIFEST.tmp"
  else
    # Add new section
    jq --arg file "$rel_path" \
       --arg section "$section_name" \
       --arg hash "$hash" \
       --arg time "$timestamp" \
       --arg tokens "$token_estimate" \
       '.sections += [{
          file: $file,
          section: $section,
          hash: $hash,
          last_updated: $time|tonumber,
          tokens: $tokens|tonumber
        }]' \
       "$SECTION_MANIFEST" > "$SECTION_MANIFEST.tmp"
  fi
  
  mv "$SECTION_MANIFEST.tmp" "$SECTION_MANIFEST"
}

# Check if section has changed since last tracking
has_section_changed() {
  local file="$1"
  local section_name="$2"
  
  if ! check_jq || [[ ! -f "$SECTION_MANIFEST" ]]; then
    # If we can't check, assume changed
    return 0
  fi
  
  local rel_path="${file#$ROOT_DIR/}"
  local current_hash=$(hash_section "$file" "$section_name")
  
  # Get stored hash
  local stored_hash
  stored_hash=$(jq --arg file "$rel_path" --arg section "$section_name" \
    '.sections[] | select(.file == $file and .section == $section) | .hash' \
    "$SECTION_MANIFEST" | tr -d '"')
  
  if [[ -z "$stored_hash" ]]; then
    # No stored hash, assume changed
    return 0
  fi
  
  if [[ "$current_hash" != "$stored_hash" ]]; then
    detail "Section changed: $rel_path » $section_name"
    return 0
  else
    detail "Section unchanged: $rel_path » $section_name"
    return 1
  fi
}

# Get token estimate for a section from manifest
get_section_tokens() {
  local file="$1"
  local section_name="$2"
  
  if ! check_jq || [[ ! -f "$SECTION_MANIFEST" ]]; then
    # If we can't check, estimate from file
    local section_content=$(extract_section "$file" "$section_name")
    estimate_tokens "$section_content"
    return
  fi
  
  local rel_path="${file#$ROOT_DIR/}"
  
  # Get stored token count
  local tokens
  tokens=$(jq --arg file "$rel_path" --arg section "$section_name" \
    '.sections[] | select(.file == $file and .section == $section) | .tokens' \
    "$SECTION_MANIFEST")
  
  if [[ -z "$tokens" || "$tokens" == "null" ]]; then
    # No stored count, estimate from file
    local section_content=$(extract_section "$file" "$section_name")
    estimate_tokens "$section_content"
  else
    echo "$tokens"
  fi
}

# Function to gather product context (similar to discover-product-context.sh)
gather_product_context() {
  local output_file="${1:-}"
  
  log "Gathering product context..."
  
  # Use the existing discover-product-context.sh if available
  if [[ -f "$SCRIPT_DIR/discover-product-context.sh" ]]; then
    log "Using existing discover-product-context.sh script"
    CONTEXT=$("$SCRIPT_DIR/discover-product-context.sh")
    
    if [[ -n "$output_file" ]]; then
      echo "$CONTEXT" > "$output_file"
      success "Product context written to $output_file"
    else
      echo "$CONTEXT"
    fi
    return
  fi
  
  # If discover-product-context.sh is not available, implement basic functionality
  local context_json='{'
  
  # Try to extract product name from various sources
  if [[ -f "$ROOT_DIR/package.json" ]]; then
    local product_name=$(grep '"name":' "$ROOT_DIR/package.json" | head -1 | cut -d'"' -f4)
    context_json+="\"product_name\": \"$product_name\","
  elif [[ -f "$ROOT_DIR/README.md" ]]; then
    local product_name=$(grep -m 1 '^# ' "$ROOT_DIR/README.md" | sed 's/^# //')
    context_json+="\"product_name\": \"$product_name\","
  else
    context_json+="\"product_name\": \"Unknown\","
  fi
  
  # Extract mission if available
  if [[ -f "$ROOT_DIR/.agent-os/product/mission.md" ]]; then
    local mission=$(cat "$ROOT_DIR/.agent-os/product/mission.md" | tr '\n' ' ' | sed 's/"/\\"/g')
    context_json+="\"mission\": \"$mission\","
  elif [[ -f "$ROOT_DIR/README.md" ]]; then
    local mission=$(grep -A 3 -i -m 1 'mission\|purpose\|about' "$ROOT_DIR/README.md" | tr '\n' ' ' | sed 's/"/\\"/g')
    context_json+="\"mission\": \"$mission\","
  fi
  
  # Extract tech stack information
  if [[ -f "$ROOT_DIR/.agent-os/product/tech-stack.md" ]]; then
    local tech_stack=$(cat "$ROOT_DIR/.agent-os/product/tech-stack.md" | tr '\n' ' ' | sed 's/"/\\"/g')
    context_json+="\"tech_stack\": \"$tech_stack\","
  elif [[ -f "$ROOT_DIR/standards/tech-stack.md" ]]; then
    local tech_stack=$(cat "$ROOT_DIR/standards/tech-stack.md" | tr '\n' ' ' | sed 's/"/\\"/g')
    context_json+="\"tech_stack\": \"$tech_stack\","
  fi
  
  # Remove trailing comma and close JSON
  context_json=$(echo "$context_json" | sed 's/,$//')
  context_json+='}'
  
  if [[ -n "$output_file" ]]; then
    echo "$context_json" > "$output_file"
    success "Basic product context written to $output_file"
  else
    echo "$context_json"
  fi
}

# Hierarchical context loading functions

# Determine if conditional context is needed for an operation+context type
needs_conditional_context() {
  local operation="$1"
  local context_type="$2"
  
  # Default mapping of which operations need which context types
  case "$operation:$context_type" in
    "create-spec:product") return 0 ;; # Yes, needed
    "create-spec:spec") return 0 ;;
    "create-spec:repo") return 0 ;;
    "create-spec:tasks") return 1 ;; # No, not needed
    
    "analyze-product:product") return 0 ;;
    "analyze-product:spec") return 0 ;;
    "analyze-product:repo") return 1 ;;
    "analyze-product:tasks") return 1 ;;
    
    "execute-tasks:product") return 1 ;;
    "execute-tasks:spec") return 0 ;;
    "execute-tasks:repo") return 0 ;;
    "execute-tasks:tasks") return 0 ;;
    
    "plan-product:product") return 0 ;;
    "plan-product:spec") return 0 ;;
    "plan-product:repo") return 1 ;;
    "plan-product:tasks") return 0 ;;
    
    *) 
      # For unknown combinations, check config if available
      # Otherwise default to including conditional context
      return 0 
      ;;
  esac
}

# Determine if reference context is needed for an operation+context type
needs_reference_context() {
  # By default, reference context is only included when explicitly requested
  if [[ "$CONTEXT_TIER" == "reference" || "$CONTEXT_TIER" == "all" ]]; then
    return 0
  else
    return 1
  fi
}

# Process a section and decide whether to include it
process_section() {
  local file="$1"
  local section="$2"
  local tier="$3"
  local output_file="$4"
  local current_tokens="$5"
  
  # Check if we still have token budget
  if [[ $current_tokens -ge $MAX_TOKENS ]]; then
    detail "Token budget exceeded ($current_tokens/$MAX_TOKENS). Skipping section: $section"
    return 1
  fi
  
  # If tracking sections is enabled, check if changed and update tracking
  if [[ "$TRACK_SECTIONS" == "true" ]]; then
    # Skip unchanged sections except for essential tier
    if [[ "$tier" != "essential" ]] && ! has_section_changed "$file" "$section"; then
      detail "Skipping unchanged section: $section (tier: $tier)"
      return 1
    fi
    
    # Track this section
    track_section "$file" "$section"
  fi
  
  # Get section content and append to output
  local section_content
  section_content=$(extract_section "$file" "$section" 2>/dev/null || echo "")
  
  # Check if we got any content
  if [[ -z "$section_content" ]]; then
    detail "No content found for section: $section in $file"
    printf "0"
    return 1
  fi
  
  local token_count
  token_count=$(estimate_tokens "$section_content")
  
  # Check if adding this would exceed budget
  if [[ $(( current_tokens + token_count )) -gt $MAX_TOKENS ]]; then
    detail "Adding section would exceed token budget. Skipping: $section ($token_count tokens)"
    printf "0"
    return 1
  fi
  
  # Add the section to output
  echo -e "\n## $section\n" >> "$output_file"
  echo -e "$section_content" >> "$output_file"
  
  token_info "Added section: $section ($token_count tokens, tier: $tier)"
  
  # Return the token count that was added
  printf "%d" "$token_count"
  return 0
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
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/README.md" "Overview" "essential" "$output_file" "$tokens_used")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_used=$((tokens_used + added_tokens))
      fi
      
      if [[ -f "$ROOT_DIR/.agent-os/product/mission.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/.agent-os/product/mission.md" "Mission" "essential" "$output_file" "$tokens_used")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_used=$((tokens_used + added_tokens))
      fi
      ;;
      
    "spec")
      # Core requirements are essential for specs
      if [[ -f "$ROOT_DIR/spec.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/spec.md" "Requirements" "essential" "$output_file" "$tokens_used")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_used=$((tokens_used + added_tokens))
        
        added_tokens=$(process_section "$ROOT_DIR/spec.md" "Constraints" "essential" "$output_file" "$tokens_used")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_used=$((tokens_used + added_tokens))
      fi
      ;;
      
    "repo")
      # Core structure is essential for repo context
      # Use a simplified project structure
      echo -e "\n## Project Structure\n" >> "$output_file"
      echo -e "```" >> "$output_file"
      find "$ROOT_DIR" -maxdepth 2 -type d -not -path "*/\.*" -not -path "*/node_modules/*" | 
        sort | 
        sed "s|$ROOT_DIR/||" | 
        grep -v "^$" | 
        sed 's/^/  /' >> "$output_file"
      echo -e "```\n" >> "$output_file"
      
      # Estimate tokens for structure (rough estimate)
      local structure_lines
      structure_lines=$(find "$ROOT_DIR" -maxdepth 2 -type d -not -path "*/\.*" -not -path "*/node_modules/*" | wc -l)
      structure_lines=${structure_lines:-0} # Default to 0 if empty
      tokens_used=$((tokens_used + structure_lines * 2))
      ;;
      
    "tasks")
      # Task definitions are essential
      if [[ -f "$ROOT_DIR/.agent-os/tasks/current-tasks.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/.agent-os/tasks/current-tasks.md" "Tasks" "essential" "$output_file" "$tokens_used")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_used=$((tokens_used + added_tokens))
      fi
      ;;
  esac
  
  detail "Essential context tokens: $tokens_used"
  printf "%d" "$tokens_used"
}

# Gather conditional context for a context type
gather_conditional_context() {
  local context_type="$1"
  local output_file="$2"
  local current_tokens="$3"
  local tokens_added=0
  
  log "Gathering conditional context for $context_type..."
  
  echo -e "\n# Conditional $context_type Context" >> "$output_file"
  
  case "$context_type" in
    "product")
      # Technical details are conditional for product
      if [[ -f "$ROOT_DIR/standards/tech-stack.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/standards/tech-stack.md" "Tech Stack" "conditional" "$output_file" "$current_tokens")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_added=$((tokens_added + added_tokens))
        current_tokens=$((current_tokens + added_tokens))
      fi
      
      if [[ -f "$ROOT_DIR/docs/architecture.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/docs/architecture.md" "Architecture" "conditional" "$output_file" "$current_tokens")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_added=$((tokens_added + added_tokens))
        current_tokens=$((current_tokens + added_tokens))
      fi
      ;;
      
    "spec")
      # Implementation details are conditional for specs
      if [[ -f "$ROOT_DIR/spec.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/spec.md" "Implementation" "conditional" "$output_file" "$current_tokens")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_added=$((tokens_added + added_tokens))
        current_tokens=$((current_tokens + added_tokens))
        
        added_tokens=$(process_section "$ROOT_DIR/spec.md" "Architecture" "conditional" "$output_file" "$current_tokens")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_added=$((tokens_added + added_tokens))
        current_tokens=$((current_tokens + added_tokens))
      fi
      ;;
      
    "repo")
      # Key files are conditional for repo context
      echo -e "\n## Key Files\n" >> "$output_file"
      echo -e "```" >> "$output_file"
      for ext in md json js ts py sh; do
        find "$ROOT_DIR" -maxdepth 3 -name "*.$ext" -not -path "*/\.*" -not -path "*/node_modules/*" | 
          sort | 
          head -10 | 
          sed "s|$ROOT_DIR/||" | 
          grep -v "^$" | 
          sed 's/^/  /' >> "$output_file" || true
      done
      echo -e "```\n" >> "$output_file"
      
      # Estimate tokens for key files (rough estimate)
      local files_count
      files_count=$(find "$ROOT_DIR" -maxdepth 3 -name "*.md" -o -name "*.json" -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.sh" | wc -l || echo 0)
      files_count=${files_count:-0} # Default to 0 if empty
      tokens_added=$((tokens_added + files_count))
      ;;
      
    "tasks")
      # Task dependencies are conditional
      if [[ -f "$ROOT_DIR/.agent-os/tasks/task-dependencies.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/.agent-os/tasks/task-dependencies.md" "Dependencies" "conditional" "$output_file" "$current_tokens")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_added=$((tokens_added + added_tokens))
        current_tokens=$((current_tokens + added_tokens))
      fi
      ;;
  esac
  
  detail "Conditional context tokens: $tokens_added"
  printf "%d" "$tokens_added"
}

# Gather reference context for a context type
gather_reference_context() {
  local context_type="$1"
  local output_file="$2"
  local current_tokens="$3"
  local tokens_added=0
  
  log "Gathering reference context for $context_type..."
  
  echo -e "\n# Reference $context_type Context" >> "$output_file"
  
  case "$context_type" in
    "product")
      # Examples and documentation are reference for product
      if [[ -f "$ROOT_DIR/examples/quickstart/README.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/examples/quickstart/README.md" "Examples" "reference" "$output_file" "$current_tokens")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_added=$((tokens_added + added_tokens))
        current_tokens=$((current_tokens + added_tokens))
      fi
      
      if [[ -f "$ROOT_DIR/docs/Index.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/docs/Index.md" "Documentation" "reference" "$output_file" "$current_tokens")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_added=$((tokens_added + added_tokens))
        current_tokens=$((current_tokens + added_tokens))
      fi
      ;;
      
    "spec")
      # Historical context and examples are reference for specs
      if [[ -d "$ROOT_DIR/examples/golden" ]]; then
        # Get one example spec if available
        local example_spec
        example_spec=$(find "$ROOT_DIR/examples/golden" -name "spec.md" -print -quit || echo "")
        if [[ -n "$example_spec" ]]; then
          local added_tokens
          added_tokens=$(process_section "$example_spec" "Example" "reference" "$output_file" "$current_tokens")
          added_tokens=${added_tokens:-0} # Default to 0 if empty
          tokens_added=$((tokens_added + added_tokens))
          current_tokens=$((current_tokens + added_tokens))
        fi
      fi
      ;;
      
    "repo")
      # Detailed code examples are reference for repo context
      # Add sample code snippets if budget allows
      local snippet_file
      snippet_file=$(find "$ROOT_DIR" -name "*.sh" -not -path "*/\.*" | head -1 || echo "")
      if [[ -n "$snippet_file" ]]; then
        echo -e "\n## Code Sample\n" >> "$output_file"
        echo -e "```bash" >> "$output_file"
        head -25 "$snippet_file" >> "$output_file"
        echo -e "```\n" >> "$output_file"
        
        # Estimate tokens for code sample
        tokens_added=$((tokens_added + 150))
      fi
      ;;
      
    "tasks")
      # Historical tasks are reference
      if [[ -f "$ROOT_DIR/.agent-os/tasks/completed-tasks.md" ]]; then
        local added_tokens
        added_tokens=$(process_section "$ROOT_DIR/.agent-os/tasks/completed-tasks.md" "Completed Tasks" "reference" "$output_file" "$current_tokens")
        added_tokens=${added_tokens:-0} # Default to 0 if empty
        tokens_added=$((tokens_added + added_tokens))
        current_tokens=$((current_tokens + added_tokens))
      fi
      ;;
  esac
  
  detail "Reference context tokens: $tokens_added"
  printf "%d" "$tokens_added"
}

# Gather context hierarchically
gather_context() {
  local context_type="$1"
  local output_file="${2:-}"
  local total_tokens=0
  
  # Use stdout if no output file provided
  if [[ -z "$output_file" ]]; then
    output_file=$(mktemp)
    local use_stdout=1
  else
    local use_stdout=0
  fi
  
  log "Gathering hierarchical context for $context_type (operation: $OPERATION_TYPE)..."
  
  # Attempt cache hit when enabled
  local cache_key="" input_file_hint=""
  if [[ "$USE_CACHE" -eq 1 && $(type -t generate_cache_key || true) == "function" ]]; then
    cache_key=$(generate_cache_key "gather-context" "$OPERATION_TYPE" "$context_type" "$CONTEXT_TIER" "$TRACK_SECTIONS" "$MAX_TOKENS")
    case "$context_type" in
      product)
        [[ -f "$ROOT_DIR/README.md" ]] && input_file_hint="$ROOT_DIR/README.md" || input_file_hint="" ;;
      spec)
        [[ -f "$ROOT_DIR/spec.md" ]] && input_file_hint="$ROOT_DIR/spec.md" || input_file_hint="" ;;
      repo)
        input_file_hint="" ;;
      tasks)
        [[ -f "$ROOT_DIR/.agent-os/tasks/current-tasks.md" ]] && input_file_hint="$ROOT_DIR/.agent-os/tasks/current-tasks.md" || input_file_hint="" ;;
    esac
    if [[ "$TRACK_SECTIONS" == "true" && -f "$SECTION_MANIFEST" ]]; then
      input_file_hint="$SECTION_MANIFEST"
    fi
    export OPERATION_CACHE_TTL
    if is_cache_valid "$cache_key" && content=$(get_cached_result "$cache_key"); then
      log "Using cached context (key: $cache_key)"
      if [[ $use_stdout -eq 1 ]]; then
        echo "$content"
      else
        echo "$content" > "$output_file"
        success "Hierarchical context written to $output_file (cache-hit)"
      fi
      return 0
    fi
  fi
  
  # Start profiling if enabled
  if [[ "$ENABLE_PROFILING" == "1" && -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
    source "$SCRIPT_DIR/context-estimator.sh"
    ce_start_profiling "context-gatherer-$context_type"
  fi
  
  # Always include essential context (Tier 1)
  if [[ "$CONTEXT_TIER" == "essential" || "$CONTEXT_TIER" == "all" ]]; then
    log "Including essential context..."
    local essential_tokens=0
    essential_tokens=$(gather_essential_context "$context_type" "$output_file")
    essential_tokens=${essential_tokens:-0} # Default to 0 if empty
    
    total_tokens=$((total_tokens + essential_tokens))
    token_info "Essential context: $essential_tokens tokens"
    
    # Track in profiler if enabled
    if [[ "$ENABLE_PROFILING" == "1" && -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
      ce_track_operation "essential-$context_type" "$essential_tokens"
    fi
  fi
  
  # Include conditional context based on operation (Tier 2)
  if { [[ "$CONTEXT_TIER" == "conditional" || "$CONTEXT_TIER" == "all" ]] && needs_conditional_context "$OPERATION_TYPE" "$context_type"; } || [[ "$CONTEXT_TIER" == "conditional" ]]; then
    log "Including conditional context..."
    local conditional_tokens=0
    conditional_tokens=$(gather_conditional_context "$context_type" "$output_file" "$total_tokens")
    conditional_tokens=${conditional_tokens:-0} # Default to 0 if empty
    
    total_tokens=$((total_tokens + conditional_tokens))
    token_info "Conditional context: $conditional_tokens tokens"
    
    # Track in profiler if enabled
    if [[ "$ENABLE_PROFILING" == "1" && -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
      ce_track_operation "conditional-$context_type" "$conditional_tokens"
    fi
  fi
  
  # Include reference context only when explicitly requested (Tier 3)
  if { [[ "$CONTEXT_TIER" == "reference" || "$CONTEXT_TIER" == "all" ]] && needs_reference_context "$OPERATION_TYPE" "$context_type"; } || [[ "$CONTEXT_TIER" == "reference" ]]; then
    log "Including reference context..."
    local reference_tokens=0
    reference_tokens=$(gather_reference_context "$context_type" "$output_file" "$total_tokens")
    reference_tokens=${reference_tokens:-0} # Default to 0 if empty
    
    total_tokens=$((total_tokens + reference_tokens))
    token_info "Reference context: $reference_tokens tokens"
    
    # Track in profiler if enabled
    if [[ "$ENABLE_PROFILING" == "1" && -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
      ce_track_operation "reference-$context_type" "$reference_tokens"
    fi
  fi
  
  # Add summary of token usage
  echo -e "\n## Context Summary\n" >> "$output_file"
  echo -e "- Context type: $context_type" >> "$output_file"
  echo -e "- Operation: $OPERATION_TYPE" >> "$output_file"
  echo -e "- Total tokens: $total_tokens" >> "$output_file"
  echo -e "- Generated: $(date -u "+%Y-%m-%d %H:%M:%S UTC")" >> "$output_file"
  
  token_info "Total context gathered: $total_tokens tokens (budget: $MAX_TOKENS)"
  
  # End profiling if enabled
  if [[ "$ENABLE_PROFILING" == "1" && -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
    ce_end_profiling
  fi
  
  if [[ $use_stdout -eq 1 ]]; then
    # Emit to stdout and cache
    local __content
    __content=$(cat "$output_file")
    echo "$__content"
    if [[ "$USE_CACHE" -eq 1 && -n "$cache_key" && $(type -t cache_operation || true) == "function" ]]; then
      cache_operation "$cache_key" "gather-context" "$__content" "${input_file_hint:-}" true || true
    fi
    rm "$output_file"
  else
    # Cache file content
    if [[ "$USE_CACHE" -eq 1 && -n "$cache_key" && $(type -t cache_operation || true) == "function" ]]; then
      local __content
      __content=$(cat "$output_file")
      cache_operation "$cache_key" "gather-context" "$__content" "${input_file_hint:-}" true || true
    fi
    success "Hierarchical context written to $output_file ($total_tokens tokens)"
  fi
}

# Function to gather project structure
gather_project_structure() {
  local output_file="${1:-}"
  
  log "Gathering project structure..."
  
  local structure="# Project Structure\n\n\`\`\`\n"
  
  # Use find to list directories first, then files, with proper indentation
  structure+=$(find "$ROOT_DIR" -type d -not -path "*/\.*" -not -path "*/node_modules/*" | sort | sed "s|$ROOT_DIR/||" | sed 's/^/  /')
  structure+="\n\n# Key Files\n\n"
  
  # Find important files
  for ext in md json js ts py sh; do
    structure+=$(find "$ROOT_DIR" -name "*.$ext" -not -path "*/\.*" -not -path "*/node_modules/*" | sort | head -20 | sed "s|$ROOT_DIR/||" | sed 's/^/  /')
    structure+="\n"
  done
  
  structure+="\`\`\`\n"
  
  if [[ -n "$output_file" ]]; then
    echo -e "$structure" > "$output_file"
    success "Project structure written to $output_file"
  else
    echo -e "$structure"
  fi
}

# Function to find relevant files based on a pattern
find_relevant_files() {
  local pattern="$1"
  local output_file="${2:-}"
  
  log "Finding files matching pattern: $pattern"
  
  local files=$(find "$ROOT_DIR" -name "$pattern" -not -path "*/\.*" -not -path "*/node_modules/*" | sort)
  
  if [[ -n "$output_file" ]]; then
    echo "$files" > "$output_file"
    success "File list written to $output_file"
  else
    echo "$files"
  fi
}

# Function to gather tech stack information
gather_tech_stack() {
  local output_file="${1:-}"
  
  log "Gathering tech stack information..."
  
  local tech_info="# Tech Stack Information\n\n"
  
  # Check for package.json for Node.js projects
  if [[ -f "$ROOT_DIR/package.json" ]]; then
    tech_info+="## Node.js Dependencies\n\n"
    tech_info+=$(grep -A 20 '"dependencies"' "$ROOT_DIR/package.json" | sed 's/^/    /')
    tech_info+="\n\n"
  fi
  
  # Check for requirements.txt for Python projects
  if [[ -f "$ROOT_DIR/requirements.txt" ]]; then
    tech_info+="## Python Dependencies\n\n"
    tech_info+=$(cat "$ROOT_DIR/requirements.txt" | sed 's/^/    /')
    tech_info+="\n\n"
  fi
  
  # Look for tech stack documentation
  if [[ -f "$ROOT_DIR/standards/tech-stack.md" ]]; then
    tech_info+="## Tech Stack Documentation\n\n"
    tech_info+=$(cat "$ROOT_DIR/standards/tech-stack.md")
    tech_info+="\n\n"
  fi
  
  if [[ -n "$output_file" ]]; then
    echo -e "$tech_info" > "$output_file"
    success "Tech stack information written to $output_file"
  else
    echo -e "$tech_info"
  fi
}

# Function to extract content from a specific file
gather_file_content() {
  local file_path="$1"
  local output_file="${2:-}"
  
  if [[ ! -f "$file_path" ]]; then
    error "File not found: $file_path"
    return 1
  fi
  
  log "Extracting content from: $file_path"
  
  if [[ -n "$output_file" ]]; then
    cp "$file_path" "$output_file"
    success "File content copied to $output_file"
  else
    cat "$file_path"
  fi
}

# Parse command line arguments
parse_args() {
  local found_operation=""
  
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      --operation)
        if [[ -z "$2" || "$2" == --* ]]; then
          error "Missing value for --operation"
          show_help
          exit 1
        fi
        OPERATION_TYPE="$2"
        shift 2
        ;;
      --tier)
        if [[ -z "$2" || "$2" == --* ]]; then
          error "Missing value for --tier"
          show_help
          exit 1
        fi
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
        if [[ -z "$2" || "$2" == --* ]]; then
          error "Missing value for --max-tokens"
          show_help
          exit 1
        fi
        MAX_TOKENS="$2"
        shift 2
        ;;
      --no-cache)
        USE_CACHE=0
        shift
        ;;
      --use-cache)
        USE_CACHE=1
        shift
        ;;
      --cache-ttl)
        if [[ -z "$2" || "$2" == --* ]]; then
          error "Missing value for --cache-ttl"
          show_help
          exit 1
        fi
        OPERATION_CACHE_TTL="$2"
        shift 2
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      -*)
        error "Unknown option: $key"
        show_help
        exit 1
        ;;
      *)
        # First non-option argument is the operation
        if [[ -z "$found_operation" ]]; then
          found_operation="$key"
          echo "$key"
        fi
        shift
        ;;
    esac
  done
  
  # If no operation found, show help
  if [[ -z "$found_operation" ]]; then
    show_help
    exit 1
  fi
}

# Main execution logic
if [[ $# -lt 1 ]]; then
  show_help
  exit 1
fi

# Parse options first
operation=$(parse_args "$@")

# Extract operation parameters (non-option arguments after the operation)
args=()
capturing=0
for arg in "$@"; do
  # Skip all option arguments and their values
  if [[ "$arg" == "--operation" || "$arg" == "--tier" || "$arg" == "--max-tokens" ]]; then
    shift
    continue
  elif [[ "$arg" == "--track-sections" || "$arg" == "--verbose" || "$arg" == "--help" || "$arg" == "-h" ]]; then
    continue
  elif [[ "$arg" == "$operation" ]]; then
    capturing=1
    continue
  elif [[ $capturing -eq 1 && "$arg" != --* && "$arg" != -* ]]; then
    args+=("$arg")
  fi
done

case "$operation" in
  gather-context)
    if [[ ${#args[@]} -lt 1 ]]; then
      error "Missing context type argument"
      show_help
      exit 1
    fi
    context_type="${args[0]}"
    output_file="${args[1]:-}"
    gather_context "$context_type" "$output_file"
    ;;
    
  gather-product-context)
    gather_product_context "${args[@]}"
    ;;
    
  gather-project-structure)
    gather_project_structure "${args[@]}"
    ;;
    
  find-relevant-files)
    find_relevant_files "${args[@]}"
    ;;
    
  gather-tech-stack)
    gather_tech_stack "${args[@]}"
    ;;
    
  gather-file-content)
    gather_file_content "${args[@]}"
    ;;
    
  hash-section)
    if [[ ${#args[@]} -lt 2 ]]; then
      error "Missing file_path or section_name argument"
      show_help
      exit 1
    fi
    file_path="${args[0]}"
    section_name="${args[1]}"
    hash_section "$file_path" "$section_name"
    ;;
    
  help|--help|-h)
    show_help
    ;;
    
  *)
    error "Unknown operation: $operation"
    show_help
    exit 1
    ;;
esac
