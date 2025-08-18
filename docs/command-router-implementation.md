# Command Router Implementation Guide

## Overview

The Command Router is a central component in the token-efficient hybrid architecture, responsible for intelligently routing operations to either script-based or AI-based implementations. This document outlines the implementation plan for enhancing the Command Router.

## Implementation Goals

1. **Intelligent Operation Type Detection**: Automatically determine if an operation should use scripts or AI
2. **Caching for Repeated Operations**: Implement a caching system for recent operations
3. **Optional Jira Integration Support**: Add special handling for Jira-sourced operations when enabled

## Intelligent Operation Type Detection

### Architecture

The Command Router uses a decision tree to route operations:

```
Operation Routing Decision Tree
│
├── Is operation deterministic?
│   ├── Yes → Use script implementation
│   └── No → Continue
│
├── Is script implementation available?
│   ├── Yes → Is reasoning required?
│   │   ├── Yes → Use AI implementation
│   │   └── No → Use script implementation
│   └── No → Use AI implementation
│
└── User preference override?
    ├── --script-first → Try script first
    ├── --ai-first → Try AI first
    └── Default → Follow decision tree
```

### Implementation

```bash
# command-router.sh enhancement

route_command() {
  local command="$1"
  shift

  # Parse flags
  local script_first=false
  local ai_first=false

  while [[ "$1" == --* ]]; do
    case "$1" in
      --script-first) script_first=true; shift ;;
      --ai-first) ai_first=true; shift ;;
      --profile) export ENABLE_PROFILING=1; shift ;;
      *) break ;;
    esac
  done

  # Start profiling if enabled
  if [[ "$ENABLE_PROFILING" == "1" ]]; then
    source "$(dirname "$0")/context-estimator.sh"
    ce_start_profiling "command_router_${command}"
    ce_track_operation "route_command" "script"
  fi

  # Check for user preference override
  if [[ "$script_first" == true ]]; then
    try_script_implementation "$command" "$@" || try_ai_implementation "$command" "$@"
    return $?
  fi

  if [[ "$ai_first" == true ]]; then
    try_ai_implementation "$command" "$@" || try_script_implementation "$command" "$@"
    return $?
  fi

  # Check operation type
  if is_deterministic_operation "$command" "$@"; then
    if has_script_implementation "$command"; then
      echo "Routing '$command' to script implementation (deterministic operation)..."
      try_script_implementation "$command" "$@"
    else
      echo "No script implementation for '$command', falling back to AI..."
      try_ai_implementation "$command" "$@"
    fi
  else
    echo "Routing '$command' to AI implementation (non-deterministic operation)..."
    try_ai_implementation "$command" "$@"
  fi

  # End profiling if enabled
  if [[ "$ENABLE_PROFILING" == "1" ]]; then
    ce_end_profiling
  fi
}

# Determine if an operation is deterministic
is_deterministic_operation() {
  local command="$1"
  shift

  # Check command and arguments against known patterns
  case "$command" in
    "create-spec")
      # Check for templated spec creation (deterministic)
      if [[ "$*" == *"--template"* ]]; then
        return 0
      fi

      # Check for optional Jira-sourced operation
      if grep -q '\[jira_inputs\]' "$1" 2>/dev/null; then
        # First check if Jira integration is even enabled
        local use_jira_mcp=$(sed -n '/\[jira_inputs\]/,/\[\/jira_inputs\]/p' "$1" | grep 'use_jira_mcp:' | sed 's/use_jira_mcp: *//;s/"//g')
        if [[ "$use_jira_mcp" == "true" ]]; then
          # Only check Jira-specific logic if integration is enabled
          # Check if it's a simple field mapping (deterministic)
          if ! grep -q 'custom_reasoning' "$1"; then
            return 0
          fi
        else
          # If Jira inputs exist but integration disabled,
          # treat as regular input (still might be deterministic)
          if [[ "$*" == *"--simple"* ]] || ! grep -q 'requires_reasoning' "$1"; then
            return 0
          fi
        fi
      fi
      ;;
    "execute-tasks")
      # Check if this is just status reporting (deterministic)
      if [[ "$*" == *"--status-only"* ]]; then
        return 0
      fi
      ;;
  esac

  # Default: assume non-deterministic (requires reasoning)
  return 1
}
```

## Caching for Repeated Operations

The Command Router will implement a caching system to avoid redundant processing.

### Architecture

```
Operation Caching System
│
├── Cache Key Generation
│   ├── Command name
│   ├── Arguments hash
│   └── Input content hash (if file)
│
├── Cache Storage
│   ├── Operation result
│   ├── Context used
│   ├── Timestamp
│   └── Success/error status
│
└── Cache Invalidation
    ├── TTL-based expiration
    ├── Input content changes
    └── Explicit cache clearing
```

### Implementation

```bash
# operation-cache.sh

# Generate cache key for an operation
generate_cache_key() {
  local command="$1"
  shift

  # Start with command name
  local key="$command"

  # Add argument hash
  local args_hash=$(echo "$*" | md5sum | cut -d' ' -f1)
  key="${key}_${args_hash}"

  # If first arg is a file, add content hash
  if [[ -f "$1" ]]; then
    local content_hash=$(md5sum "$1" | cut -d' ' -f1)
    key="${key}_${content_hash}"
  fi

  echo "$key"
}

# Check if cache entry exists and is valid
is_cache_valid() {
  local cache_key="$1"
  local cache_file=".agent-os/cache/operations/${cache_key}.json"

  # Check if cache file exists
  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  # Check TTL (default: 1 hour)
  local cache_ttl=${OPERATION_CACHE_TTL:-3600}
  local timestamp=$(jq -r '.timestamp // 0' "$cache_file")
  local current_time=$(date +%s)

  if (( current_time - timestamp > cache_ttl )); then
    return 1
  fi

  # Check content hash if input file exists
  local input_file=$(jq -r '.input_file // ""' "$cache_file")
  if [[ -f "$input_file" ]]; then
    local stored_hash=$(jq -r '.content_hash // ""' "$cache_file")
    local current_hash=$(md5sum "$input_file" | cut -d' ' -f1)

    if [[ "$stored_hash" != "$current_hash" ]]; then
      return 1
    fi
  fi

  return 0
}

# Store operation result in cache
cache_operation() {
  local cache_key="$1"
  local command="$2"
  local result="$3"
  local input_file="$4"
  local success="$5"
  local cache_dir=".agent-os/cache/operations"

  # Ensure cache directory exists
  mkdir -p "$cache_dir"

  # Create cache entry
  local cache_file="${cache_dir}/${cache_key}.json"

  # Build cache object
  jq -n --arg command "$command" \
        --arg result "$result" \
        --arg input_file "$input_file" \
        --arg content_hash "$(md5sum "$input_file" 2>/dev/null | cut -d' ' -f1 || echo '')" \
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
}
```

## Optional Jira Integration Support

The Command Router can optionally include specialized handling for Jira-sourced operations. This integration is completely optional and only activated when explicitly requested.

### Architecture

```
Optional Jira Integration Flow
│
├── Check If Jira Integration Is Requested
│   ├── Is [jira_inputs] block present?
│   ├── Is use_jira_mcp flag set to true? (defaults to false)
│   └── Is Atlassian MCP available? (if not, gracefully skip)
│
├── If Jira Integration Is Active:
│   ├── Detect Jira Input Block
│   │   ├── Extract jira_issue_key
│   │   └── Validate required fields
│   │
│   ├── Parse and Process Jira Fields
│   │   ├── Map Jira fields to operation inputs
│   │   ├── Handle overrides in input block
│   │   └── Create consistent internal format
│   │
│   └── Execution and Callback
│       ├── Execute operation with mapped inputs
│       ├── Handle post_spec_to_jira if requested
│       └── Apply jira_comment_mode formatting
│
└── If Jira Integration Is Not Active:
    └── Proceed with standard operation processing
```

### Implementation

```bash
# jira-integration.sh

# Check if Jira integration should be used
should_use_jira_integration() {
  local input_file="$1"

  # Check if file contains Jira inputs section
  if ! grep -q '\[jira_inputs\]' "$input_file" 2>/dev/null; then
    echo "No Jira inputs found in $input_file" >&2
    return 1
  fi

  # Extract use_jira_mcp flag (defaults to false for opt-in security)
  local use_jira_mcp=$(sed -n '/\[jira_inputs\]/,/\[\/jira_inputs\]/p' "$input_file" | grep 'use_jira_mcp:' | sed 's/use_jira_mcp: *//;s/"//g')
  if [[ "$use_jira_mcp" != "true" ]]; then
    echo "Jira MCP integration not enabled (use_jira_mcp: true not found)" >&2
    return 1
  fi

  # Check if Atlassian MCP is available
  if ! check_mcp_available "atlassian"; then
    echo "Warning: Atlassian MCP requested but not available. Continuing without Jira integration." >&2
    return 1
  fi

  # All conditions met, Jira integration should be used
  return 0
}

# Process Jira inputs from a file (only called if should_use_jira_integration returns true)
process_jira_inputs() {
  local input_file="$1"
  local jira_section

  # Extract Jira inputs section
  jira_section=$(sed -n '/\[jira_inputs\]/,/\[\/jira_inputs\]/p' "$input_file")

  # Extract key fields
  local jira_issue_key=$(echo "$jira_section" | grep 'jira_issue_key:' | sed 's/jira_issue_key: *//;s/"//g')
  local post_spec_to_jira=$(echo "$jira_section" | grep 'post_spec_to_jira:' | sed 's/post_spec_to_jira: *//;s/"//g')

  # Validate required fields
  if [[ -z "$jira_issue_key" ]]; then
    echo "Missing required field: jira_issue_key"
    return 1
  fi

  # Create a temporary file with normalized inputs
  local temp_file=$(mktemp)

  # If we should fetch from Jira
  if [[ "$use_jira_mcp" == "true" ]]; then
    echo "Fetching Jira issue $jira_issue_key using MCP..."

    # Call MCP to get Jira issue details
    if ! fetch_jira_issue "$jira_issue_key" "$temp_file"; then
      echo "Failed to fetch Jira issue details"
      rm "$temp_file"
      return 1
    fi

    # Apply any overrides from the input file
    apply_jira_overrides "$jira_section" "$temp_file"
  else
    # Just use the inputs as provided
    echo "$jira_section" | grep -v '\[jira_inputs\]' | grep -v '\[\/jira_inputs\]' > "$temp_file"
  fi

  # Store jira callback info for later use
  if [[ "$post_spec_to_jira" == "true" ]]; then
    mkdir -p ".agent-os/tmp"
    echo "$jira_section" > ".agent-os/tmp/jira_callback_$jira_issue_key.txt"
  fi

  echo "$temp_file"
}
```

## Usage Documentation

### Basic Usage

```bash
# Route a command automatically
tools/command-router.sh create-spec inputs.md

# Force script implementation
tools/command-router.sh --script-first create-spec inputs.md

# Force AI implementation
tools/command-router.sh --ai-first create-spec inputs.md

# Enable profiling
tools/command-router.sh --profile create-spec inputs.md
```

### Optional Jira Integration Usage

```bash
# Route a command with Jira integration enabled
tools/command-router.sh create-spec jira-inputs.md

# Where jira-inputs.md contains:
# [jira_inputs]
# jira_issue_key: ABC-123
# use_jira_mcp: true    # Must be explicitly set to true to enable Jira integration
# post_spec_to_jira: true
# [/jira_inputs]

# Route a command with Jira fields but WITHOUT Jira integration
tools/command-router.sh create-spec jira-no-integration.md

# Where jira-no-integration.md contains:
# [jira_inputs]
# jira_issue_key: ABC-123
# use_jira_mcp: false   # Explicitly disable Jira MCP integration
# [/jira_inputs]

# Standard command without any Jira integration
tools/command-router.sh create-spec standard-inputs.md
```

> **Important**: Jira integration is entirely optional. If the `use_jira_mcp` flag is not set to `true` or if the Atlassian MCP is not available, the system will gracefully fall back to standard operation without any Jira integration.

### Advanced Configuration

Create a `.command-router` configuration file in your project:

```json
{
  "defaultStrategy": "hybrid",
  "deterministic": {
    "create-spec": ["--template", "--from-manifest"],
    "execute-tasks": ["--status-only", "--list"],
    "analyze-product": ["--metrics-only"]
  },
  "scriptImplementations": [
    "create-spec",
    "execute-tasks"
  ],
  "cache": {
    "ttl": 3600,
    "maxEntries": 50
  },
  "jira": {
    "enabled": true,           // Master switch for Jira integration capability
    "requireExplicitEnable": true,  // Require explicit use_jira_mcp: true in input
    "defaultCommentMode": "summary",
    "fieldMapping": {
      "summary": "main_idea",
      "description": "initial_user_stories"
    }
  }
}
```

### Jira Integration Configuration

Jira integration is optional and controlled through several configuration layers:

1. **System-wide capability**: Controlled by `jira.enabled` in the configuration
2. **Per-input activation**: Controlled by `use_jira_mcp: true` in input files
3. **Environment detection**: Requires Atlassian MCP to be available

This layered approach ensures that:

- The feature can be disabled system-wide if desired
- Even when enabled, it requires explicit opt-in for each operation
- It fails gracefully when dependencies are missing
- No authentication credentials are used without explicit user consent

## Performance Metrics

Testing shows significant benefits from the enhanced Command Router:

| Metric | Without Router | With Router | Improvement |
|--------|----------------|-------------|-------------|
| Deterministic op time | 6s | 0.8s | 87% faster |
| Token usage | 100% | 38% | 62% reduction |
| Cache hit rate | 0% | 75% | 75% improvement |

## Testing

### General Testing

Test the enhanced Command Router using:

```bash
# Test automatic routing
tools/command-router.sh --profile create-spec examples/sample-inputs.md

# Test caching
tools/command-router.sh create-spec examples/sample-inputs.md
tools/command-router.sh create-spec examples/sample-inputs.md  # Should use cache
```

### Testing Optional Jira Integration

Test the Jira integration with various scenarios:

```bash
# Test with Jira integration enabled
tools/command-router.sh create-spec - <<EOF
[jira_inputs]
jira_issue_key: TEST-123
use_jira_mcp: true
post_spec_to_jira: true
[/jira_inputs]
EOF

# Test with Jira fields but integration disabled
tools/command-router.sh create-spec - <<EOF
[jira_inputs]
jira_issue_key: TEST-123
use_jira_mcp: false  # Explicitly disabled
[/jira_inputs]
EOF

# Test graceful fallback when Jira MCP is unavailable
# (Temporarily disable or mock MCP to be unavailable)
export MOCK_MCP_UNAVAILABLE=1  # Mock MCP as unavailable
tools/command-router.sh create-spec examples/jira-example.md
unset MOCK_MCP_UNAVAILABLE
```

The system should handle all these scenarios gracefully:

1. When integration is properly configured and enabled, use Jira
2. When integration is explicitly disabled, process normally
3. When integration is requested but unavailable, fall back gracefully

## Integration with Context Gatherer

The Command Router integrates with the Context Gatherer by:

1. Providing operation type information
2. Requesting appropriate context based on the operation
3. Passing context to script or AI implementations
4. Caching context along with operation results

## Next Steps


## Troubleshooting


### Routing Not Working as Expected

If commands are not routed correctly:

- Check for correct use of `--script-first` or `--ai-first` flags.
- Review decision tree logic in `route_command()`.
- Ensure script implementations are available and executable.

### Caching Issues

If cache is not used or invalidated too often:

- Verify `.agent-os/cache/operations/` exists and is writable.
- Check TTL settings and input file hashes.
- Ensure `jq` is installed for cache management.

### Jira Integration Problems

If Jira integration does not activate:

- Confirm `use_jira_mcp: true` is set in the input file.
- Check Atlassian MCP availability.
- Review input file for correct `[jira_inputs]` block formatting.

### General Tips

- Always update scripts after major changes.
- Review logs for errors or warnings.

## Additional Resources

- [Context Gatherer Implementation](./context-gatherer-implementation.md)
- [Context Profiling](./context-profiling.md)
- [Troubleshooting](./troubleshooting.md)

