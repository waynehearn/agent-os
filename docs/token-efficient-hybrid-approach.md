# Token-Efficient Hybrid Approach: Scripts + Subagents

This document describes the hybrid approach for the create-spec workflow that combines script-based deterministic operations with AI-powered subagents for reasoning tasks.

## Overview

The hybrid approach replaces certain deterministic subagent calls with direct script calls to:

1. Reduce token usage
2. Improve execution speed
3. Maintain reliability for deterministic operations
4. Focus AI power on tasks where it adds genuine value

## Implemented Optimizations

The following subagent operations have been replaced with script calls:

| Original Subagent | Function | Replacement Script |
|-------------------|----------|-------------------|
| date-checker      | Date determination | `tools/date-checker.sh` |
| file-creator (partial) | Folder creation | `tools/folder-creator.sh` |

## How It Works

1. The instruction files (`instructions/core/create-spec.md`) have been modified to call scripts directly instead of subagents for deterministic operations
2. Claude Code still orchestrates the overall process and uses subagents for reasoning tasks
3. The scripts are called with specific parameters and produce outputs that the main flow can use

## Benefits of the Hybrid Approach

- **Token Efficiency**: Scripts use zero tokens for deterministic operations
- **Speed**: Scripts execute faster than LLM-based subagents for straightforward tasks
- **Reliability**: Deterministic operations have more predictable results
- **Cost Savings**: Reduced token usage translates to lower operational costs
- **Focused AI Usage**: Reserves AI power for tasks where it adds real value

## Future Optimizations

Additional deterministic subagent operations that could be converted to scripts:

- Context gathering (basic file operations)
- Git workflow operations
- Validation operations

## Maintaining Both Options

This repository maintains two approaches:

1. **Hybrid Claude Code**: Using scripts for deterministic operations, subagents for reasoning
2. **Pure Script**: The `run-create-spec.sh` script that runs without Claude Code or subagents

Users can choose the approach that best fits their needs and environment.
