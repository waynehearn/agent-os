# Running Create-Spec Without Claude Code

This document explains how to run the create-spec workflow using VSCode Copilot without requiring Claude Code or subagents.

## Overview

The `run-create-spec.sh` script provides a hybrid implementation of the create-spec workflow that would normally require Claude Code and subagents. It uses a balanced approach that:

1. Uses script-based functions for deterministic operations (date validation, file operations, etc.)
2. Provides templates and placeholders where AI would normally generate content
3. Indicates opportunities for AI enhancement without requiring subagents

## Prerequisites

- Git Bash (for Windows) or Bash shell (for Unix/Linux/macOS)
- jq installed and available in your PATH
- VSCode with Copilot

## Usage

1. Create a spec inputs file following the format in `examples/sample-jira-spec-inputs.md`
2. Run the script:

```bash
bash tools/run-create-spec.sh examples/sample-jira-spec-inputs.md
```

3. The script will:
   - Parse your inputs
   - Generate a specification in `.agent-os/specs/[CURRENT_DATE]-[SPEC_NAME]/`
   - Create spec.md and tasks.md files
   - Validate the specification

## Spec Inputs Format

```markdown
[spec_inputs]
main_idea: >
  A clear description of the feature or enhancement.

initial_user_stories:

- title: User Story Title
  story: As a [USER], I want to [ACTION], so that [BENEFIT].
  details: More details about the user story.

in_scope:

- Item that is in scope for this specification
- Another in-scope item

out_of_scope:

- Item that is out of scope for this specification
- Another out-of-scope item

expected_deliverables:

- Expected deliverable 1
- Expected deliverable 2

tech_constraints: >
  Technical constraints that apply to this specification.

requires_db_changes: false
requires_api_changes: false

mode: standard  # express|standard|investigate
spec_name_override: "custom-name" # Optional
overwrite_existing: false
[/spec_inputs]
```

## Modes

- **standard**: Regular specification flow with full validation
- **express**: Simplified flow for smaller features
- **investigate**: For investigative work (bug analysis, research)

## Balanced Approach

The script uses a balanced approach to replace subagent functionality:

### Script-Based Functions (Replacing Deterministic Subagent Tasks)

- **Date validation** (replaces date-checker subagent)
- **File parsing** (replaces context-fetcher's parsing functionality)
- **File creation** (replaces file-creator's basic functionality)
- **Text normalization** (replaces context-fetcher's normalization functionality)

### Templates and Placeholders (For AI-Generated Content)

- **Specification templates** (in the templates/ folder)
- **Task templates** (with conditional sections based on requirements)
- **AI enhancement placeholders** (indicating where AI would add value)

### Hybrid Functionality

For some steps, the script uses a hybrid approach:

- Script-based operations to create file structures and handle basic logic
- Placeholders that indicate where AI would normally enhance content
- Conditional logic that mimics AI-based decision making

## Extending the Script

To add additional functionality:

1. Add more deterministic functions to the script-based sections
2. Create more sophisticated templates in the templates/ folder
3. Add more conditional logic to mimic AI-based decision making
4. Integrate with AI APIs if desired for specific enhancements

## Token Efficiency

This approach is token-efficient because:

1. Deterministic operations use zero tokens (pure bash/shell)
2. Templates reduce the need for repetitive content generation
3. AI involvement is clearly marked for targeted application
4. Context gathering is handled by optimized scripts
