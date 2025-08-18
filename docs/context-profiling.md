# Context Efficiency Profiling

This document explains how to use the context profiling tools to optimize token usage and context management across both Claude and Copilot environments.

## Overview

The context profiling system provides insights into:

1. Character and estimated token usage
2. Script vs. AI operation counts
3. File sizes and context composition
4. Execution timings

These metrics help identify optimization opportunities without relying on system-specific token counting APIs.

## Available Tools

### Context Estimator

The `context-estimator.sh` script provides functions for tracking context metrics:

```bash
source tools/context-estimator.sh
ce_start_profiling [session_name]
ce_track_file "file_path" "operation_type"
ce_track_operation "operation_name" "type" (script|ai)
ce_end_operation "operation_id"
ce_end_profiling
```

### Context Gatherer

The `context-gatherer.sh` script efficiently gathers context with built-in profiling:

```bash
tools/context-gatherer.sh [--profile] [--max-size SIZE_KB] <context_type> <output_file>
```

Supported context types:

- `product`: Product context (mission, tech stack, roadmap)
- `spec`: Specification context (existing specs, templates)
- `repo`: Repository context (directory structure, key files)
- `tasks`: Task-related context (existing tasks, status)

### Command Router

The `command-router.sh` script intelligently routes commands to script or AI implementations:

```bash
tools/command-router.sh [--profile] [--ai-first|--script-first] <command> [args...]
```

## Enabling Profiling

You can enable profiling in two ways:

1. **Environment variable**:

   ```bash
   ENABLE_PROFILING=1 tools/run-create-spec.sh inputs.md
   ```

2. **Command flag** (for tools that support it):

   ```bash
   tools/context-gatherer.sh --profile product context.md
   ```

## Interpreting Results

Profiling reports are saved to `.agent-os/logs/profiling/` with metrics including:

- **Context Size**: Character counts and estimated tokens
- **Operation Counts**: Script vs. AI operations
- **File Tracking**: Individual file sizes and estimated tokens
- **Timing Data**: Execution time for operations

Example report:

```
=== Profiling Summary ===
Session: create_spec_20250817_120135
Duration: 27 seconds

Context Metrics:
  - Total characters processed: 24680
  - Estimated tokens: 6170

Operation Metrics:
  - Script operations: 12 (92%)
  - AI operations: 1 (8%)

Files Tracked:
  - examples/sample-jira-spec-inputs.md (input): 1.2KB, ~308 tokens
  - .agent-os/specs/2025-08-17-jira-integration/spec.md (output): 3.5KB, ~886 tokens
```

## Optimization Strategies

1. **Replace AI Operations**: Look for AI operations with high token usage that could be converted to scripts
2. **Reduce Context Size**: Minimize the context needed for operations
3. **Template Usage**: Use templates to reduce generative content
4. **Context Caching**: Cache frequently used context between operations

## Command-Specific Recommendations

- **create-spec**: Move template rendering and file operations to scripts
- **analyze-product**: Use scripts for data gathering and analytics
- **execute-tasks**: Use scripts for task state management and reporting
- **plan-product**: Use scripts for roadmap formatting and timeline calculations

## Cross-Command Optimization

- **Shared Context**: Maintain a context cache across commands
- **Progressive Loading**: Load context only when needed
- **Context Compression**: Remove duplicate or unnecessary information


## Troubleshooting


### Profiling Data Not Generated

If profiling reports are missing:

- Ensure profiling is enabled via environment variable or command flag.
- Check script permissions and paths.
- Verify `.agent-os/logs/profiling/` exists and is writable.

### Unexpected Token Counts

If token estimates seem inaccurate:

- Confirm you are using the latest version of the profiling scripts.
- Review context composition for duplicate or irrelevant data.

### Performance Issues

If profiling slows down operations:

- Limit context size with `--max-size`.
- Profile only critical operations.

### General Tips

- Always update scripts after major changes.
- Review logs for errors or warnings.

## Additional Resources

- [Context Discovery](./context-discovery.md)
- [Token Efficiency User Guide](./token-efficiency-user-guide.md)
- [Troubleshooting](./troubleshooting.md)

By applying these strategies based on profiling data, you can significantly reduce token usage while maintaining powerful AI capabilities for reasoning tasks.
