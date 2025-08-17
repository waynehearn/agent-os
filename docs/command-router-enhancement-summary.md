# Command Router Enhancement Implementation

Date: August 17, 2025

## Overview

This document summarizes the implementation of the Command Router Enhancement as part of the token-efficient hybrid approach for Agent OS. The implementation includes intelligent operation type detection, operation result caching, and optional Jira integration support.

## Components Implemented

1. **Context Cache Manager (`tools/context-cache-manager.sh`)**
   - Implements caching for operation results
   - Provides TTL-based cache invalidation
   - Handles content hashing for intelligent cache invalidation

2. **Command Router Enhancement (`tools/command-router.sh`)**
   - Added intelligent operation type detection
   - Implemented caching for repeated operations
   - Added support for various command line options
   - Integrated with the context-estimator for profiling

3. **Optional Jira Integration (`tools/extensions/jira-integration.sh`)**
   - Created as an optional extension
   - Implements graceful fallback when unavailable
   - Supports explicit opt-in security model
   - Provides field mapping and result posting

4. **Documentation**
   - Updated `optional-jira-integration-design.md` with comprehensive design
   - Added detailed comments to implementation files

## Key Features

### 1. Intelligent Operation Type Detection

```bash
is_deterministic_operation() {
  local command="$1"
  local input_file="$2"
  
  # Check command and arguments against known patterns
  case "$command" in
    "create-spec")
      # Check for templated spec creation (deterministic)
      if [[ "$*" == *"--template"* ]]; then
        return 0
      fi

      # Check for optional Jira-sourced operation
      if grep -q '\[jira_inputs\]' "$input_file" 2>/dev/null; then
        # First check if Jira integration is enabled
        local use_jira_mcp
        use_jira_mcp=$(sed -n '/\[jira_inputs\]/,/\[\/jira_inputs\]/p' "$input_file" | grep 'use_jira_mcp:' | sed 's/use_jira_mcp: *//;s/"//g')
        if [[ "$use_jira_mcp" == "true" ]]; then
          # Only check Jira-specific logic if integration is enabled
          # Check if it's a simple field mapping (deterministic)
          if ! grep -q 'custom_reasoning' "$input_file"; then
            return 0
          fi
        else
          # If Jira inputs exist but integration disabled,
          # treat as regular input (still might be deterministic)
          if [[ "$*" == *"--simple"* ]] || ! grep -q 'requires_reasoning' "$input_file"; then
            return 0
          fi
        fi
      fi
      ;;
    # Additional cases for other commands...
  esac

  # Default: assume non-deterministic (requires reasoning)
  return 1
}
```

### 2. Operation Caching System

```bash
# Cache management functions
generate_cache_key() {
  local command="$1"
  shift
  
  local key="$command"
  local args_hash=$(echo "$*" | md5sum | cut -d' ' -f1)
  key="${key}_${args_hash}"
  
  if [[ -f "$1" ]]; then
    local content_hash=$(md5sum "$1" | cut -d' ' -f1)
    key="${key}_${content_hash}"
  fi
  
  echo "$key"
}

# Execution with caching
if [[ "${USE_CACHE:-true}" == "true" ]]; then
  local cache_key=$(generate_cache_key "$command" "$input_file" "$mode")
  
  if is_cache_valid "$cache_key"; then
    log "Found valid cached result for $command operation"
    get_cached_result "$cache_key"
    return $?
  fi
fi
```

### 3. Optional Jira Integration

```bash
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
  
  # Check if Atlassian MCP is available
  if ! check_mcp_available "atlassian"; then
    log_warn "Atlassian MCP requested but not available. Continuing without Jira integration."
    return 1
  fi
  
  # All conditions met, Jira integration should be used
  return 0
}
```

## Command Line Interface

The command router now supports a rich command line interface:

```
Usage: tools/command-router.sh [options] <command> [inputs_file]

Options:
  --script-first      - Prefer script implementation when available
  --ai-first          - Prefer AI implementation even when script is available
  --profile           - Enable profiling (track token usage)
  --no-cache          - Bypass the operation cache
  --no-extensions     - Disable all extensions
  --extension-path P  - Specify custom extension path
  --extensions LIST   - Comma-separated list of enabled extensions
```

## Testing

Initial testing confirms basic functionality:

1. **Command Router**: Properly processes command line options and routes commands
2. **Caching System**: Successfully initializes cache directory
3. **Jira Integration**: Properly detects when MCP is unavailable and falls back gracefully

Additional testing needed:

1. Complete end-to-end flow with actual script implementations
2. Performance metrics for cached vs. non-cached operations
3. Jira integration with actual MCP when available

## Next Steps

1. **Expand Test Coverage**: Create comprehensive test suite for all components
2. **Implement Additional Extensions**: Add support for other optional extensions
3. **Update Documentation**: Complete the command-router-implementation.md document with final implementation details
4. **Performance Tuning**: Optimize cache management for larger operations

## Conclusion

The Command Router Enhancement implementation successfully delivers the core functionality outlined in the implementation plan. It provides intelligent operation type detection, caching for repeated operations, and optional Jira integration support with proper fallback mechanisms. The implementation is fully aligned with the token-efficient hybrid approach and supports the goal of optimizing both token usage and performance.
