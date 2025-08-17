# Documentation Standards Guide

*Version: 1.0 | Last Updated: 2025-08-17*

This document outlines the standards and best practices for creating and maintaining documentation in the Agent OS project. Following these guidelines ensures that documentation is both human-friendly and LLM-consumable.

## Core Documentation Principles

### 1. Human and LLM Consumable

All documentation must be designed for efficient consumption by both humans and large language models:

- **Clear hierarchical structure** using proper Markdown headings (H1 → H6)
- **Concise paragraphs** with informative topic sentences at the beginning
- **Formatted code blocks** with appropriate language tags:

  ```bash
  # Bash code example
  echo "Hello World"
  ```

- **Tables for structured data** rather than complex nested lists
- **Descriptive link text** instead of generic phrases like "click here"
- **Front-matter metadata** with title, version, and last updated date

### 2. Central Documentation Index

The `Index.md` file serves as the central hub for all documentation:

- All second-level documents **must** be linked from `Index.md`
- Organization should follow a logical categorization:
  - User Guides
  - Technical Implementation
  - Architecture & Design
  - Reference Material
  - Troubleshooting
- New documentation sections must be added to the appropriate category in `Index.md`

### 3. Cross-Linking

Documentation should be extensively cross-linked for easy navigation:

- Use relative paths when linking to other documents
- Reference canonical sources rather than duplicating content
- Link to specific sections when referencing particular concepts
- Use the format `[Descriptive Link Text](./relative/path/to/file.md#section-anchor)`
- Add a "Related Documents" section at the end of each document

### 4. Consistent Documentation Style

Maintain consistency across all documentation files:

- Use standardized Markdown formatting
- Follow the project glossary for terminology
- Maintain a consistent voice (instructional, neutral)
- Use the templates provided in the `templates/` directory
- Include appropriate metadata headers

## Document Structure Templates

### Technical Document Structure

```markdown
---
title: Component Name
version: 1.0
lastUpdated: YYYY-MM-DD
---

# Component Name

Brief overview of the component (1-2 paragraphs).

## Overview

Detailed explanation of the component's purpose and role in the system.

## Architecture

Explanation of the component's internal design.

## API Reference

Detailed interface documentation.

## Implementation Details

Technical implementation notes.

## Examples

Usage examples.

## Testing

Testing approach and verification.

## Related Documents

- [Related Document 1](./path/to/doc1.md)
- [Related Document 2](./path/to/doc2.md)
```

### User Guide Structure

```markdown
---
title: Feature Name - User Guide
version: 1.0
lastUpdated: YYYY-MM-DD
---

# Feature Name - User Guide

Brief overview of what the feature does and why it's useful.

## Getting Started

Quick start instructions.

## Common Tasks

Step-by-step instructions for common operations.

## Configuration

Configuration options and customization.

## Troubleshooting

Solutions to common issues.

## Related Documents

- [Related Document 1](./path/to/doc1.md)
- [Related Document 2](./path/to/doc2.md)
```

## Shell Script Documentation

All shell scripts must include proper documentation:

### Script Header Template

```bash
#!/bin/bash
#
# Script Name: example-script.sh
# Description: Brief description of what this script does
# Author: [Author Name]
# Created: YYYY-MM-DD
# Last Modified: YYYY-MM-DD
# Usage: ./example-script.sh [options]
#
# Dependencies:
# - jq
# - grep, sed, awk
#
# Notes:
# - Additional implementation notes
# - Configuration requirements
```

### Script Function Documentation

```bash
# Function: function_name
# Description: What this function does
# Parameters:
#   $1: first_param - Description of first parameter
#   $2: second_param - Description of second parameter
# Returns:
#   Description of what the function returns or outputs
# Example:
#   function_name "input" "option"
function_name() {
    local first_param="$1"
    local second_param="$2"

    # Implementation
}
```

### Logging Implementation

All scripts should implement consistent logging:

```bash
# Log levels
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

# Current log level (can be overridden via environment variable)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Logging functions
log_error() { [[ $LOG_LEVEL -ge $LOG_LEVEL_ERROR ]] && echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
log_warn() { [[ $LOG_LEVEL -ge $LOG_LEVEL_WARN ]] && echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
log_info() { [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_debug() { [[ $LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
```

## Documentation Validation

All documentation should be validated before submission:

1. Run Markdown linting to ensure proper formatting
2. Verify all links resolve correctly
3. Test all code examples to ensure they work as documented
4. Review for consistency with other documentation
5. Ensure the document is linked from `Index.md` or another appropriate parent document

## Maintaining Documentation

Documentation should be updated whenever related code changes:

1. Update the `lastUpdated` field in the metadata
2. Add new sections as needed for new features
3. Mark deprecated features appropriately
4. Update examples to reflect current implementation
5. Review cross-links to ensure they remain valid

By following these standards, we ensure our documentation remains accessible, accurate, and useful for both human users and AI assistants.
