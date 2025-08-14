# Code Style Guide

## Context

Global code style rules for Spec Agent Kibo projects.

<conditional-block context-check="general-formatting">
IF this General Formatting section already read in current context:
  SKIP: Re-reading this section
  NOTE: "Using General Formatting rules already in context"
ELSE:
  READ: The following formatting rules

## General Formatting

### Indentation
- Use 4 spaces for indentation (never tabs) - C# standard
- Maintain consistent indentation throughout files
- Align nested structures for readability
- Use braces on new lines (Allman style)

### Naming Conventions
- **Methods and Properties**: Use PascalCase (e.g., `GetUserProfile`, `CalculateTotal`)
- **Variables and Parameters**: Use camelCase (e.g., `userProfile`, `totalAmount`)
- **Classes, Interfaces, and Namespaces**: Use PascalCase (e.g., `UserProfile`, `IPaymentProcessor`)
- **Private Fields**: Use camelCase with underscore prefix (e.g., `_userRepository`)
- **Constants**: Use PascalCase (e.g., `MaxRetryCount`)
- **Interfaces**: Prefix with "I" (e.g., `ILocationRepository`)

### String Formatting
- Use double quotes for strings: `"Hello World"`
- Use string interpolation for dynamic content: `$"Hello {name}"`
- Use verbatim strings for file paths: `@"C:\Path\To\File"`
- Use raw string literals for multi-line strings in C# 11+

### Code Comments
- Add brief comments above non-obvious business logic
- Document complex algorithms or calculations
- Explain the "why" behind implementation choices
- Never remove existing comments unless removing the associated code
- Update comments when modifying code to maintain accuracy
- Keep comments concise and relevant
</conditional-block>

<conditional-block task-condition="html-css-tailwind" context-check="html-css-style">
IF current task involves writing or updating HTML, CSS, or TailwindCSS:
  IF html-style.md AND css-style.md already in context:
    SKIP: Re-reading these files
    NOTE: "Using HTML/CSS style guides already in context"
  ELSE:
    <context_fetcher_strategy>
      IF current agent is Claude Code AND context-fetcher agent exists:
        USE: @agent:context-fetcher
        REQUEST: "Get HTML formatting rules from code-style/html-style.md"
        REQUEST: "Get CSS and TailwindCSS rules from code-style/css-style.md"
        PROCESS: Returned style rules
      ELSE:
        READ the following style guides (only if not already in context):
        - @~/.agent-os/standards/code-style/html-style.md (if not in context)
        - @~/.agent-os/standards/code-style/css-style.md (if not in context)
    </context_fetcher_strategy>
ELSE:
  SKIP: HTML/CSS style guides not relevant to current task
</conditional-block>

<conditional-block task-condition="javascript" context-check="javascript-style">
IF current task involves writing or updating JavaScript:
  IF javascript-style.md already in context:
    SKIP: Re-reading this file
    NOTE: "Using JavaScript style guide already in context"
  ELSE:
    <context_fetcher_strategy>
      IF current agent is Claude Code AND context-fetcher agent exists:
        USE: @agent:context-fetcher
        REQUEST: "Get JavaScript style rules from code-style/javascript-style.md"
        PROCESS: Returned style rules
      ELSE:
        READ: @~/.agent-os/standards/code-style/javascript-style.md
    </context_fetcher_strategy>
ELSE:
  SKIP: JavaScript style guide not relevant to current task
</conditional-block>
