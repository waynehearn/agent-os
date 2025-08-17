# Optional Jira Integration Design

## Overview

This document details the design and implementation of the optional Jira integration for Agent OS. The integration is designed to be completely optional, requiring explicit opt-in, and gracefully handling scenarios where Jira access is unavailable.

## Core Design Principles

1. **Strict Opt-in Model**: Jira integration is disabled by default and requires explicit opt-in
2. **Graceful Fallbacks**: System continues to function when Jira integration is unavailable
3. **Multiple Control Layers**: Integration is controlled at system, input, and environment levels
4. **No Silent Authentication**: No authentication attempts without explicit user consent
5. **Privacy-focused**: No credentials or Jira data are used without explicit consent
6. **MCP Integration**: Leverages the Atlassian Model Context Protocol when available

## Implementation Requirements

### Activation Logic

The Jira integration will only be activated when ALL of these conditions are met:

1. The system-wide configuration allows Jira integration (`jira.enabled: true`)
2. The input explicitly requests Jira integration (`use_jira_mcp: true`)
3. The Atlassian MCP is available in the environment

If any of these conditions are not met, the system will continue operating without Jira integration.

### Fallback Behavior

When Jira integration is requested but cannot be fulfilled, the system should:

1. Log a clear warning message explaining why integration is skipped
2. Continue processing with available local inputs
3. Not attempt to post results back to Jira
4. Complete the operation successfully when possible

### Configuration Options

Users can control Jira integration at multiple levels:

1. **System configuration** (`.agent-os/config/jira-config.json`):

   ```json
   {
     "jira": {
       "enabled": true,             // Master switch for Jira capability
       "requireExplicitEnable": true,  // Require explicit use_jira_mcp: true in input
       "defaultCommentMode": "summary",
       "fieldMapping": {
         "summary": "main_idea",
         "description": "initial_user_stories"
       }
     }
   }
   ```

2. **Per-operation control** (in input files):

   ```
   [jira_inputs]
   jira_issue_key: ABC-123
   use_jira_mcp: true    // Must be explicitly set to true to enable Jira integration
   post_spec_to_jira: true
   jira_comment_mode: "summary" // How to format Jira comments (full|summary|link)
   [/jira_inputs]
   ```

3. **Environment variables**:

   ```bash
   JIRA_ENABLED=false tools/command-router.sh create-spec inputs.md
   ```

## Integration Architecture

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

## Implementation Details

### 1. Jira Integration Module

The Jira integration is implemented as an optional extension module in `tools/extensions/jira-integration.sh`.

Key functions:

- `check_mcp_available()`: Checks if a specific MCP is available
- `should_use_jira_integration()`: Determines if Jira integration should be used
- `process_jira_inputs()`: Extracts and processes Jira inputs from a file
- `fetch_jira_issue()`: Retrieves Jira issue details using MCP
- `post_spec_to_jira()`: Posts results back to Jira

### 2. Command Router Integration

The command router integrates with the Jira extension through intelligent operation type detection:

```bash
# Check for optional Jira-sourced operation
if grep -q '\[jira_inputs\]' "$input_file" 2>/dev/null; then
  # First check if Jira integration is enabled
  local use_jira_mcp
  use_jira_mcp=$(sed -n '/\[jira_inputs\]/,/\[\/jira_inputs\]/p' "$input_file" | grep 'use_jira_mcp:' | sed 's/use_jira_mcp: *//;s/"//g')
  if [[ "$use_jira_mcp" == "true" ]]; then
    # Only check Jira-specific logic if integration is enabled
    # Check if it's a simple field mapping (deterministic)
    if ! grep -q 'custom_reasoning' "$input_file"; then
      return 0  # This is a deterministic operation
    fi
  else
    # If Jira inputs exist but integration disabled,
    # treat as regular input (still might be deterministic)
    if [[ "$*" == *"--simple"* ]] || ! grep -q 'requires_reasoning' "$input_file"; then
      return 0  # This is a deterministic operation
    fi
  fi
fi
```

### 3. Input Format

The Jira integration uses a standardized input format with a `[jira_inputs]` section:

```
[jira_inputs]
jira_issue_key: ABC-123       # Required: The Jira issue key
use_jira_mcp: true           # Required: Must be true to enable Jira integration
cloud_id: "cloud-id-value"   # Optional: Atlassian Cloud ID
post_spec_to_jira: true      # Optional: Whether to post results back to Jira
jira_comment_mode: "summary" # Optional: How to format Jira comments (full|summary|link)

# Custom field mappings and overrides
title: "Override title from Jira"
description: "Override description from Jira"
[/jira_inputs]
```

### 4. Field Mapping

The integration supports mapping Jira fields to internal operation fields:

1. **Default Mappings**: System-defined mappings in the configuration
2. **Custom Mappings**: User-defined mappings in the input file
3. **Priority Order**: Input file overrides > Jira field values > Default values

## Testing Scenarios

Test plan verifies all combinations of:

1. System configuration (enabled/disabled)
2. Input file settings (integration requested/not requested)
3. Environment conditions (MCP available/unavailable)
4. Processing outcomes (with/without Jira)

Specific test cases include:

### Test Case 1: Integration Enabled

```bash
# Test with Jira integration enabled
tools/command-router.sh create-spec - <<EOF
[jira_inputs]
jira_issue_key: TEST-123
use_jira_mcp: true
post_spec_to_jira: true
[/jira_inputs]
EOF
```

Expected: Integration activated, Jira issue fetched, results posted back

### Test Case 2: Integration Disabled

```bash
# Test with Jira fields but integration disabled
tools/command-router.sh create-spec - <<EOF
[jira_inputs]
jira_issue_key: TEST-123
use_jira_mcp: false  # Explicitly disabled
[/jira_inputs]
EOF
```

Expected: Integration bypassed, input processed normally

### Test Case 3: MCP Unavailable

```bash
# Test graceful fallback when Jira MCP is unavailable
export MOCK_MCP_UNAVAILABLE=1  # Mock MCP as unavailable
tools/command-router.sh create-spec examples/jira-example.md
unset MOCK_MCP_UNAVAILABLE
```

Expected: Graceful fallback to standard operation, warning logged

## Security Considerations

1. **No Default Access**: Jira integration is disabled by default
2. **Explicit Opt-In**: Requires `use_jira_mcp: true` for activation
3. **MCP Dependency**: Uses the security model of the Atlassian MCP
4. **No Credential Storage**: No credentials are stored by the integration
5. **Minimal Data Transfer**: Only transfers data explicitly requested
6. **No Jira authentication** without explicit user consent
7. **No automatic posting** to Jira unless specifically requested
8. **Clear logging** of all Jira-related operations
9. **Secure handling** of any temporary files with Jira data

## Documentation Requirements

All documentation clearly indicates that Jira integration is:

1. Optional and disabled by default
2. Requires explicit activation
3. Has fallback mechanisms when unavailable
4. Does not impact core functionality

## Troubleshooting

### Common Issues

1. **Integration Not Working**: Check if `use_jira_mcp: true` is set
2. **MCP Not Available**: Ensure Atlassian MCP is installed and configured
3. **Field Mapping Issues**: Verify field names in configuration and input file

### Debugging

Enable debug logging to see detailed integration information:

```bash
VERBOSITY=debug tools/command-router.sh create-spec jira-example.md
```

## Implementation Roadmap

1. **Phase 1 (Current)**: Basic integration with Jira issue fetching and comment posting
2. **Phase 2**: Enhanced field mapping with bidirectional synchronization
3. **Phase 3**: Integration with other Atlassian products (Confluence, etc.)

---

By following these design principles, the command router provides optional Jira integration that is secure, reliable, and non-intrusive for users who don't need or want it. The integration enhances Agent OS functionality while maintaining full compatibility with environments where Jira is unavailable.
