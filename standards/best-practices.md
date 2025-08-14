# Development Best Practices

## Context

Global development guidelines for Spec Agent Kibo projects.

<conditional-block context-check="core-principles">
IF this Core Principles section already read in current context:
  SKIP: Re-reading this section
  NOTE: "Using Core Principles already in context"
ELSE:
  READ: The following principles

## Core Principles

### Keep It Simple
- Implement code in the fewest lines possible
- Avoid over-engineering solutions
- Choose straightforward approaches over clever ones
- Never create a file longer than 500 lines of code (per CLAUDE.md)
- Functions should be under 50 lines with single responsibility
- Classes should be under 100 lines representing single concept

### Optimize for Readability
- Prioritize code clarity over micro-optimizations
- Write self-documenting code with clear variable names
- Add comments for "why" not "what"
- Follow existing layered architecture patterns
- Maintain consistent indentation and formatting

### DRY (Don't Repeat Yourself)
- Extract repeated business logic to private methods
- Extract repeated DTOs to reusable contracts
- Create utility functions for common operations
- Use AutoMapper profiles for repeated mapping logic
- Leverage repository base classes for common data access

### SOLID Design Principles
- **Single Responsibility**: Each class has one reason to change
- **Open/Closed**: Open for extension, closed for modification
- **Liskov Substitution**: Derived classes must be substitutable for base classes
- **Interface Segregation**: Many client-specific interfaces are better than one general-purpose interface
- **Dependency Inversion**: Depend on abstractions, not concretions

### File Structure and Architecture
- Follow layered architecture: WebApi → Domain → Repository
- Keep files focused on a single responsibility
- Group related functionality together
- Use consistent naming conventions
- Maximum line length: 100 characters
- Organize code into clearly separated modules by feature
</conditional-block>

<conditional-block context-check="dependencies" task-condition="choosing-external-library">
IF current task involves choosing an external library:
  IF Dependencies section already read in current context:
    SKIP: Re-reading this section
    NOTE: "Using Dependencies guidelines already in context"
  ELSE:
    READ: The following guidelines
ELSE:
  SKIP: Dependencies section not relevant to current task

## Dependencies

### Choose Libraries Wisely
When adding third-party dependencies:
- Select the most popular and actively maintained option
- Check the library's GitHub repository for:
  - Recent commits (within last 6 months)
  - Active issue resolution
  - Number of stars/downloads
  - Clear documentation
- For .NET projects:
  - Prefer packages that support .NET 6.0+
  - Check NuGet package download statistics
  - Verify compatibility with existing Mozu Core framework
  - Consider licensing implications for commercial use
  - Avoid packages that conflict with existing dependencies
  - Use Mozu Core utilities when available (caching, configuration, messaging)
</conditional-block>
