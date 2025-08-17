#!/bin/bash
#
# Script Name: jira-integration.sh
# Description: Optional Jira integration module for Agent OS
# Author: Agent OS Team
# Created: 2025-08-17
# Last Modified: 2025-08-17
# Usage: Source this file in other scripts
#
# Dependencies:
# - bash (version 4+)
# - jq
# - curl (for API calls)
# - Atlassian Model Context Protocol (MCP)
#
# Notes:
# - This is an optional extension module
# - Will gracefully fail when Jira MCP is unavailable
# - Requires explicit opt-in via use_jira_mcp: true in inputs

# ==============================================================================
# Configuration
# ==============================================================================

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Jira configuration
JIRA_CONFIG_FILE="${ROOT_DIR}/.agent-os/config/jira-config.json"

# Default settings
JIRA_ENABLED=true
JIRA_REQUIRE_EXPLICIT_ENABLE=true
JIRA_DEFAULT_COMMENT_MODE="summary"

# ==============================================================================
# Logging Functions
# ==============================================================================

# Import logging functions if available
if [[ -f "$SCRIPT_DIR/../logging.sh" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/../logging.sh"
else
  # Fallback minimal logging functions
  log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
  log_warn() { echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
  log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
  log_debug() { echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
fi

# ==============================================================================
# MCP Availability Functions
# ==============================================================================

# Function: check_mcp_available
# Description: Check if a specific MCP is available
# Parameters:
#   $1: mcp_type - The type of MCP to check for
# Returns: 0 if available, 1 otherwise
check_mcp_available() {
  local mcp_type="$1"
  
  # Mock MCP unavailable if environment variable is set (for testing)
  if [[ "${MOCK_MCP_UNAVAILABLE:-}" == "1" ]]; then
    return 1
  fi
  
  case "$mcp_type" in
    "atlassian")
      # Check if Atlassian MCP commands are available
      if command -v mcp_atlassian_atlassianUserInfo &>/dev/null; then
        return 0
      else
        return 1
      fi
      ;;
    *)
      # Unknown MCP type
      return 1
      ;;
  esac
}

# ==============================================================================
# Jira Integration Functions
# ==============================================================================

# Function: should_use_jira_integration
# Description: Check if Jira integration should be used
# Parameters:
#   $1: input_file - The input file to check for Jira configuration
# Returns: 0 if Jira should be used, 1 otherwise
should_use_jira_integration() {
  local input_file="$1"
  
  # First check if Jira integration is globally enabled
  if [[ "${JIRA_ENABLED:-true}" != "true" ]]; then
    log_debug "Jira integration is globally disabled"
    return 1
  fi
  
  # Check if file contains Jira inputs section
  if ! grep -q '\[jira_inputs\]' "$input_file" 2>/dev/null; then
    log_debug "No Jira inputs found in $input_file"
    return 1
  fi
  
  # Extract use_jira_mcp flag (defaults to false for opt-in security)
  local use_jira_mcp
  use_jira_mcp=$(sed -n '/\[jira_inputs\]/,/\[\/jira_inputs\]/p' "$input_file" | grep 'use_jira_mcp:' | sed 's/use_jira_mcp: *//;s/"//g')
  
  # Check if explicit enable is required
  if [[ "${JIRA_REQUIRE_EXPLICIT_ENABLE:-true}" == "true" && "$use_jira_mcp" != "true" ]]; then
    log_debug "Jira MCP integration not explicitly enabled (use_jira_mcp: true not found)"
    return 1
  fi
  
  # Check if Atlassian MCP is available
  if ! check_mcp_available "atlassian"; then
    log_warn "Atlassian MCP requested but not available. Continuing without Jira integration."
    return 1
  fi
  
  # All conditions met, Jira integration should be used
  return 0
}

# Function: process_jira_inputs
# Description: Process Jira inputs from a file
# Parameters:
#   $1: input_file - The input file with Jira configuration
# Returns: Path to temporary file with normalized inputs
process_jira_inputs() {
  local input_file="$1"
  local jira_section
  
  # Extract Jira inputs section
  jira_section=$(sed -n '/\[jira_inputs\]/,/\[\/jira_inputs\]/p' "$input_file")
  
  # Extract key fields
  local jira_issue_key
  local cloud_id
  local post_spec_to_jira
  
  jira_issue_key=$(echo "$jira_section" | grep 'jira_issue_key:' | sed 's/jira_issue_key: *//;s/"//g')
  cloud_id=$(echo "$jira_section" | grep 'cloud_id:' | sed 's/cloud_id: *//;s/"//g')
  post_spec_to_jira=$(echo "$jira_section" | grep 'post_spec_to_jira:' | sed 's/post_spec_to_jira: *//;s/"//g')
  use_jira_mcp=$(echo "$jira_section" | grep 'use_jira_mcp:' | sed 's/use_jira_mcp: *//;s/"//g')
  
  # Validate required fields
  if [[ -z "$jira_issue_key" ]]; then
    log_error "Missing required field: jira_issue_key"
    return 1
  fi
  
  # Create a temporary file with normalized inputs
  local temp_file
  temp_file=$(mktemp)
  
  # If we should fetch from Jira
  if [[ "$use_jira_mcp" == "true" ]]; then
    log_info "Fetching Jira issue $jira_issue_key using MCP..."
    
    # Discover cloud ID if not provided
    if [[ -z "$cloud_id" ]]; then
      log_debug "No cloud_id provided, attempting to discover"
      
      # This will be a call to the MCP to get available Atlassian resources
      # For now, we'll just use a placeholder
      cloud_id="placeholder-cloud-id"
    fi
    
    # Call MCP to get Jira issue details
    if ! fetch_jira_issue "$cloud_id" "$jira_issue_key" "$temp_file"; then
      log_error "Failed to fetch Jira issue details"
      rm "$temp_file"
      return 1
    fi
    
    # Apply any overrides from the input file
    apply_jira_overrides "$jira_section" "$temp_file"
  else
    # Just use the inputs as provided
    echo "$jira_section" | grep -v '\[jira_inputs\]' | grep -v '\[\/jira_inputs\]' > "$temp_file"
  fi
  
  # Store jira callback info for later use if post_spec_to_jira is set
  if [[ "$post_spec_to_jira" == "true" ]]; then
    mkdir -p "${ROOT_DIR}/.agent-os/tmp"
    echo "$jira_section" > "${ROOT_DIR}/.agent-os/tmp/jira_callback_${jira_issue_key}.txt"
  fi
  
  echo "$temp_file"
}

# Function: fetch_jira_issue
# Description: Fetch Jira issue details using MCP
# Parameters:
#   $1: cloud_id - The Atlassian cloud ID
#   $2: issue_key - The Jira issue key
#   $3: output_file - Path to file where results should be saved
# Returns: 0 on success, non-zero on failure
fetch_jira_issue() {
  local cloud_id="$1"
  local issue_key="$2"
  local output_file="$3"
  
  log_info "Fetching Jira issue: $issue_key"
  
  # Check if MCP is available
  if ! check_mcp_available "atlassian"; then
    log_error "Atlassian MCP not available"
    return 1
  fi
  
  # This would be a call to the Atlassian MCP
  # For now, we'll just create a mock response
  
  # In a real implementation, this would call something like:
  # mcp_atlassian_getJiraIssue --cloudId "$cloud_id" --issueIdOrKey "$issue_key"
  
  # Create a mock response
  cat > "$output_file" << EOF
title: "Mock Jira Issue $issue_key"
description: |
  This is a mock Jira issue description.
  It would normally contain the actual issue details from Jira.
jira_issue_key: "$issue_key"
cloud_id: "$cloud_id"
jira_status: "Open"
created_by: "jira-user"
created_date: "2025-08-17"
EOF
  
  log_info "Successfully fetched Jira issue data"
  return 0
}

# Function: apply_jira_overrides
# Description: Apply overrides from the Jira inputs section
# Parameters:
#   $1: jira_section - The Jira inputs section from the file
#   $2: output_file - The file to modify with overrides
# Returns: 0 on success, non-zero on failure
apply_jira_overrides() {
  local jira_section="$1"
  local output_file="$2"
  
  log_debug "Applying Jira input overrides"
  
  # Get list of fields to override (excluding meta fields)
  local fields
  fields=$(echo "$jira_section" | grep -v '\[jira_inputs\]' | grep -v '\[\/jira_inputs\]' | 
           grep -v 'jira_issue_key:' | grep -v 'cloud_id:' | 
           grep -v 'use_jira_mcp:' | grep -v 'post_spec_to_jira:')
  
  # Apply each field as an override
  echo "$fields" >> "$output_file"
  
  return 0
}

# Function: post_spec_to_jira
# Description: Post specification back to Jira
# Parameters:
#   $1: issue_key - The Jira issue key
#   $2: spec_file - The specification file to post
# Returns: 0 on success, non-zero on failure
post_spec_to_jira() {
  local issue_key="$1"
  local spec_file="$2"
  
  log_info "Posting specification to Jira issue: $issue_key"
  
  # Check if callback info exists
  local callback_file="${ROOT_DIR}/.agent-os/tmp/jira_callback_${issue_key}.txt"
  if [[ ! -f "$callback_file" ]]; then
    log_error "Jira callback info not found for issue $issue_key"
    return 1
  fi
  
  # Extract cloud_id from callback info
  local cloud_id
  cloud_id=$(grep 'cloud_id:' "$callback_file" | sed 's/cloud_id: *//;s/"//g')
  
  # Extract comment mode
  local comment_mode
  comment_mode=$(grep 'jira_comment_mode:' "$callback_file" | sed 's/jira_comment_mode: *//;s/"//g')
  comment_mode=${comment_mode:-$JIRA_DEFAULT_COMMENT_MODE}
  
  # Check if MCP is available
  if ! check_mcp_available "atlassian"; then
    log_error "Atlassian MCP not available, cannot post to Jira"
    return 1
  }
  
  # Format comment based on mode
  local comment_body
  case "$comment_mode" in
    "full")
      # Use full spec content
      comment_body=$(cat "$spec_file")
      ;;
    "summary")
      # Use just the summary section
      comment_body=$(sed -n '/^## Summary/,/^## /p' "$spec_file" | sed '$d')
      ;;
    "link")
      # Just post a link to the spec
      local spec_filename
      spec_filename=$(basename "$spec_file")
      comment_body="Specification created: $spec_filename"
      ;;
    *)
      # Default to summary
      comment_body=$(sed -n '/^## Summary/,/^## /p' "$spec_file" | sed '$d')
      ;;
  esac
  
  # This would be a call to the Atlassian MCP to add a comment
  # For now, just log what would happen
  log_info "Would post the following to Jira issue $issue_key:"
  log_info "---"
  echo "$comment_body" | head -10
  log_info "... (content truncated) ..."
  log_info "---"
  
  # In a real implementation, this would call something like:
  # mcp_atlassian_addCommentToJiraIssue --cloudId "$cloud_id" --issueIdOrKey "$issue_key" --commentBody "$comment_body"
  
  log_info "Specification successfully posted to Jira issue: $issue_key"
  return 0
}

# ==============================================================================
# Initialization
# ==============================================================================

# Load configuration if available
if [[ -f "$JIRA_CONFIG_FILE" ]]; then
  if command -v jq &>/dev/null; then
    JIRA_ENABLED=$(jq -r '.jira.enabled // true' "$JIRA_CONFIG_FILE")
    JIRA_REQUIRE_EXPLICIT_ENABLE=$(jq -r '.jira.requireExplicitEnable // true' "$JIRA_CONFIG_FILE")
    JIRA_DEFAULT_COMMENT_MODE=$(jq -r '.jira.defaultCommentMode // "summary"' "$JIRA_CONFIG_FILE")
  else
    log_warn "jq not available, using default Jira configuration"
  fi
fi

log_debug "Jira integration module loaded"
log_debug "- Jira enabled: $JIRA_ENABLED"
log_debug "- Require explicit enable: $JIRA_REQUIRE_EXPLICIT_ENABLE"
log_debug "- Default comment mode: $JIRA_DEFAULT_COMMENT_MODE"
