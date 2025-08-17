#!/bin/bash
#
# Script Name: context-cache-manager.sh
# Description: Manages caching of operation results for token efficiency
# Author: Agent OS Team
# Created: 2025-08-17
# Last Modified: 2025-08-17
# Usage: Source this file in other scripts
#
# Dependencies:
# - bash (version 4+)
# - jq
# - standard Unix utilities (grep, sed, awk)
#
# Notes:
# - Provides functions for caching operation results
# - Implements TTL-based cache invalidation
# - Handles content hashing for intelligent cache invalidation

# ==============================================================================
# Configuration
# ==============================================================================

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cache settings
CACHE_DIR="${ROOT_DIR}/.agent-os/cache/operations"
CACHE_TTL=${OPERATION_CACHE_TTL:-3600}  # Default: 1 hour

# ==============================================================================
# Logging Functions
# ==============================================================================

# Import logging functions if available
if [[ -f "$SCRIPT_DIR/logging.sh" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/logging.sh"
else
  # Fallback minimal logging functions
  log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
  log_warn() { echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
  log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
  log_debug() { echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
fi

# ==============================================================================
# Cache Management Functions
# ==============================================================================

# Function: generate_cache_key
# Description: Generate a cache key for an operation based on command and inputs
# Parameters:
#   $1: command - The command name
#   $@: The command arguments (starting from $2)
# Returns: The generated cache key as a string
generate_cache_key() {
  local command="$1"
  shift
  
  # Start with command name
  local key="$command"
  
  # Add argument hash
  local args_hash
  args_hash=$(echo "$*" | md5sum | cut -d' ' -f1)
  key="${key}_${args_hash}"
  
  # If first arg is a file, add content hash
  if [[ -f "$1" ]]; then
    local content_hash
    content_hash=$(md5sum "$1" | cut -d' ' -f1)
    key="${key}_${content_hash}"
  fi
  
  echo "$key"
}

# Function: is_cache_valid
# Description: Check if a cache entry exists and is valid
# Parameters:
#   $1: cache_key - The cache key to check
# Returns: 0 if cache is valid, 1 otherwise
is_cache_valid() {
  local cache_key="$1"
  local cache_file="$CACHE_DIR/${cache_key}.json"
  
  # Check if cache file exists
  if [[ ! -f "$cache_file" ]]; then
    log_debug "Cache miss: No cache file for key $cache_key"
    return 1
  fi
  
  # Check TTL
  if ! command -v jq &>/dev/null; then
    log_warn "jq not available, cannot validate cache TTL"
    return 1
  fi
  
  local timestamp
  timestamp=$(jq -r '.timestamp // 0' "$cache_file")
  local current_time
  current_time=$(date +%s)
  
  if (( current_time - timestamp > CACHE_TTL )); then
    log_debug "Cache expired: TTL exceeded for key $cache_key"
    return 1
  fi
  
  # Check content hash if input file exists
  local input_file
  input_file=$(jq -r '.input_file // ""' "$cache_file")
  if [[ -f "$input_file" ]]; then
    local stored_hash
    local current_hash
    
    stored_hash=$(jq -r '.content_hash // ""' "$cache_file")
    current_hash=$(md5sum "$input_file" | cut -d' ' -f1)
    
    if [[ "$stored_hash" != "$current_hash" ]]; then
      log_debug "Cache invalid: Input content changed for $input_file"
      return 1
    fi
  fi
  
  log_debug "Cache hit: Valid cache for key $cache_key"
  return 0
}

# Function: get_cached_result
# Description: Get the result of a previously cached operation
# Parameters:
#   $1: cache_key - The cache key to retrieve
# Returns: The cached result or empty if not found
get_cached_result() {
  local cache_key="$1"
  local cache_file="$CACHE_DIR/${cache_key}.json"
  
  if ! is_cache_valid "$cache_key"; then
    return 1
  fi
  
  if ! command -v jq &>/dev/null; then
    log_warn "jq not available, cannot retrieve cached result"
    return 1
  fi
  
  # Extract the result from the cache file
  jq -r '.result // ""' "$cache_file"
  return 0
}

# Function: cache_operation
# Description: Store operation result in the cache
# Parameters:
#   $1: cache_key - The cache key
#   $2: command - The command that was executed
#   $3: result - The result of the operation
#   $4: input_file - Path to the input file (optional)
#   $5: success - Whether the operation was successful (true/false)
# Returns: 0 on success, non-zero on failure
cache_operation() {
  local cache_key="$1"
  local command="$2"
  local result="$3"
  local input_file="${4:-}"
  local success="${5:-true}"
  
  # Create cache directory if it doesn't exist
  mkdir -p "$CACHE_DIR"
  
  # Create cache entry
  local cache_file="$CACHE_DIR/${cache_key}.json"
  
  if ! command -v jq &>/dev/null; then
    log_warn "jq not available, cannot cache operation"
    return 1
  fi
  
  # Calculate content hash if input file exists
  local content_hash=""
  if [[ -f "$input_file" ]]; then
    content_hash=$(md5sum "$input_file" | cut -d' ' -f1)
  fi
  
  # Build and write cache object
  jq -n \
    --arg command "$command" \
    --arg result "$result" \
    --arg input_file "$input_file" \
    --arg content_hash "$content_hash" \
    --argjson success "$success" \
    --argjson timestamp "$(date +%s)" \
    '{
      command: $command,
      result: $result,
      input_file: $input_file,
      content_hash: $content_hash,
      success: $success,
      timestamp: $timestamp
    }' > "$cache_file"
  
  log_debug "Cached result for key $cache_key"
  return 0
}

# Function: clear_cache
# Description: Clear cache entries matching optional pattern
# Parameters:
#   $1: pattern - Optional pattern to match cache keys
# Returns: 0 on success, non-zero on failure
clear_cache() {
  local pattern="$1"
  
  if [[ -z "$pattern" ]]; then
    log_info "Clearing all operation cache entries"
    rm -f "${CACHE_DIR}"/*.json
  else
    log_info "Clearing operation cache entries matching: $pattern"
    find "${CACHE_DIR}" -name "*${pattern}*.json" -delete
  fi
  
  return 0
}

# Function: list_cache_entries
# Description: List all cache entries or those matching a pattern
# Parameters:
#   $1: pattern - Optional pattern to match cache keys
# Returns: 0 on success, non-zero on failure
list_cache_entries() {
  local pattern="$1"
  
  if [[ ! -d "$CACHE_DIR" ]]; then
    log_info "No cache directory exists yet"
    return 0
  fi
  
  if [[ -z "$pattern" ]]; then
    log_info "Listing all operation cache entries:"
    for f in "${CACHE_DIR}"/*.json; do
      [[ -f "$f" ]] || continue
      basename "$f" | sed 's/\.json$//'
    done
  else
    log_info "Listing operation cache entries matching: $pattern"
    find "${CACHE_DIR}" -name "*${pattern}*.json" | while read -r f; do
      basename "$f" | sed 's/\.json$//'
    done
  fi
  
  return 0
}

# Function: cache_statistics
# Description: Show cache statistics
# Parameters: None
# Returns: 0 on success, non-zero on failure
cache_statistics() {
  if [[ ! -d "$CACHE_DIR" ]]; then
    log_info "No cache directory exists yet"
    return 0
  fi
  
  local total_entries=0
  local valid_entries=0
  local expired_entries=0
  local invalid_entries=0
  
  for f in "${CACHE_DIR}"/*.json; do
    [[ -f "$f" ]] || continue
    
    ((total_entries++))
    local cache_key
    cache_key=$(basename "$f" | sed 's/\.json$//')
    
    if is_cache_valid "$cache_key" >/dev/null 2>&1; then
      ((valid_entries++))
    else
      # Determine why it's invalid
      local timestamp
      timestamp=$(jq -r '.timestamp // 0' "$f")
      local current_time
      current_time=$(date +%s)
      
      if (( current_time - timestamp > CACHE_TTL )); then
        ((expired_entries++))
      else
        ((invalid_entries++))
      fi
    fi
  done
  
  log_info "Cache Statistics:"
  log_info "  Total entries: $total_entries"
  log_info "  Valid entries: $valid_entries"
  log_info "  Expired entries: $expired_entries"
  log_info "  Content-invalid entries: $invalid_entries"
  log_info "  Cache hit rate: $(( valid_entries * 100 / (total_entries > 0 ? total_entries : 1) ))%"
  
  return 0
}

# Initialize cache directory
mkdir -p "$CACHE_DIR"
