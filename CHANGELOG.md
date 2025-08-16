# Changelog

All notable changes to Spec Agent K will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Jira extension variables simplified: removed support for legacy `ext_*` keys in `instructions/extensions/create-spec/atlassian-jira.md`.
  - Use short-form keys instead: `jira_issue_key`, `use_jira_mcp`, `post_spec_to_jira`, `jira_comment_mode`.
  - Migration: replace any `ext_jira_issue_key`, `ext_use_jira_mcp`, `ext_post_spec_to_jira`, `ext_jira_comment_mode` with the short-form equivalents in your `[jira_inputs]` blocks.
  - Docs updated to reflect short-form only (jira-extension, configuration, usage, troubleshooting, extensions README).

### Added

- Architecture & Customization Guide: `docs/architecture.md` (explains context budgets, section-level manifests, template externalization, and extension registry cache).
- Manifest spec: `docs/manifest-spec.md` and JSON Schemas under `docs/schemas/` (`manifest.schema.json`, `spec-input.schema.json`).
- Section hashing utilities:
  - `tools/section-hash.sh` (POSIX) and `tools/section-hash.ps1` (PowerShell) to compute section-level hashes and update per-spec `context/manifest.json` per the schema.

### Performance

- Implemented hierarchical context loading, section-level manifest tracking, template externalization, and extension registry caching.
  - Result: ~52.5% token reduction per create-spec execution while maintaining functionality.
  - Details: see `llm-context-optimization-implementation.md`.

## [1.4.0] - 2025-08-14

### Added [1.4.0]

- Renamed to Spec Agent K
  - Cause Kibo and Specs...😉
- Documentation folder with local, offline-first docs:
  - `docs/index.md`, `docs/installation.md`, `docs/quickstart.md`, `docs/configuration.md`
  - `docs/create-spec-usage.md`, `docs/smoke-tests.md`, `docs/troubleshooting.md`, `docs/glossary.md`
- New instruction utilities to enforce determinism and structure:
  - `instructions/core/spec-validator.md`
  - `instructions/core/tasks-validator.md`
  - `instructions/core/spec-name-normalizer.md`
- Development tooling/config:
  - `.claude/settings.local.json`
  - `.serena/project.yml`

### Changed [1.4.0]

- README reworked as installer-first entry point with links into local docs and canonical site; macOS/Linux/Windows (Git Bash) guidance added; project header updated.
- Commands expanded with usage and examples:
  - `commands/create-spec.md` now documents required/optional inputs plus Jira-driven and manual example blocks
  - `commands/execute-tasks.md` now describes the task loop with examples for next, specific parents, and targeted subtasks
  - `commands/plan-product.md` now lists input template and example
  - `commands/analyze-product.md` now supports optional `context_notes`
- Core instructions refined for clarity, determinism, and validation:
  - `instructions/core/create-spec.md` adds variables, strict section/count rules, Atlassian MCP mapping, conditional sub-spec creation, and post-write validation steps
  - `instructions/core/execute-tasks.md` adds variables, clearer context-gathering using path aliases, optional spec/tasks validation, and cross‑platform completion notification
  - `instructions/core/execute-task.md` adds variables, explicit targets, and fixes best‑practices/code‑style path aliases
  - `instructions/core/analyze-product.md` clarifies overview, improves wording, and fixes bare URLs
  - `instructions/core/plan-product.md` typo fixes and lint guards
- Standards updated toward a .NET-first stack and conventions:
  - `standards/tech-stack.md` switched to ASP.NET Core/.NET 6+, MongoDB, Docker/Kubernetes, Jenkins, SonarQube
  - `standards/code-style.md` updated to C# naming/formatting guidance
  - `standards/best-practices.md` expanded (SOLID, DRY, layered architecture, .NET tips)
  - Added `standards/code-style/csharp-style.md` with detailed architecture and patterns

### Improved [1.4.0]

- Deterministic spec and tasks generation with validators; clearer path aliases (`@...`) across OS/shells.
- Cross‑platform guidance and notifications (POSIX shells and Windows Git Bash).
- Markdown consistency (lint rules, links) across instructions and docs.

### Fixed [1.4.0]

- Typos and wording in multiple instruction files; replaced bare URLs with Markdown links; corrected alias paths.

## [1.3.1] - 2025-08-02

### Added [1.3.1]

- **Date-Checker Subagent** - New specialized Claude Code subagent for accurate date determination using file system timestamps
  - Uses temporary file creation to extract current date in YYYY-MM-DD format
  - Includes context checking to avoid duplication
  - Provides clear validation and error handling

### Changed [1.3.1]

- **Create-Spec Instructions** - Updated `instructions/core/create-spec.md` to use the new date-checker subagent
  - Replaced complex inline date determination logic with simple subagent delegation
  - Simplified step 4 (date_determination) by removing 45 lines of validation and fallback code
  - Cleaner instruction flow with specialized agent handling date logic

### Improved [1.3.1]

- **Code Maintainability** - Date determination logic centralized in reusable subagent
- **Instruction Clarity** - Simplified create-spec workflow with cleaner delegation pattern
- **Error Handling** - More robust date determination with dedicated validation rules

## [1.3.0] - 2025-08-01

### Added [1.3.0]

- **Pre-flight Check System** - New `meta/pre-flight.md` instruction for centralized agent detection and initialization
- **Proactive Agent Usage** - Updated agent descriptions to encourage proactive use when appropriate
- **Structured Instruction Organization** - New folder structure with `core/` and `meta/` subdirectories

### Changed [1.3.0]

- **Instruction File Structure** - Reorganized all instruction files into subdirectories:
  - Core instructions moved to `instructions/core/` (plan-product, create-spec, execute-tasks, execute-task, analyze-product)
  - Meta instructions in `instructions/meta/` (pre-flight, more to come)
- **Simplified XML Metadata** - Removed verbose `<ai_meta>` and `<step_metadata>` blocks for cleaner, more readable instructions
- **Subagent Integration** - Replaced manual agent detection with centralized pre-flight check across all instruction files to enforce delegation and preserve main agent's context.
- **Step Definitions** - Added `subagent` attribute to steps for clearer delegation of work to help enforce delegation and preserve main agent's context.
- **Setup Script** - Updated to create subdirectories and download files to new locations

### Improved [1.3.0]

- **Code Clarity** - Removed redundant XML instructions in favor of descriptive step purposes
- **Agent Efficiency** - Centralized agent detection reduces repeated checks throughout workflows
- **Maintainability** - Cleaner instruction format with less XML boilerplate
- **User Experience** - Clearer indication of when specialized agents will be used proactively

### Removed [1.3.0]

- **CLAUDE.md** - Removed deprecated Claude Code configuration file (functionality moved to pre-flight system, preventing over-reading instructions into context)
- **Redundant Instructions** - Eliminated verbose ACTION/MODIFY/VERIFY instruction blocks

## [1.2.0] - 2025-07-29

### Added [1.2.0]

- **Claude Code Specialized Subagents** - New agents to offload specific tasks for improved efficiency:
  - `test-runner.md` - Handles test execution and failure analysis with minimal toolset
  - `context-fetcher.md` - Retrieves information from files while checking context to avoid duplication
  - `git-workflow.md` - Manages git operations, branches, commits, and PR creation
  - `file-creator.md` - Creates files, directories, and applies consistent templates
- **Agent Detection Pattern** - Single check at process start with boolean flags for efficiency
- **Subagent Integration** across all instruction files with automatic fallback for non-Claude Code users

### Changed [1.2.0]

- **Instruction Files** - All updated to support conditional agent usage:
  - `execute-tasks.md` - Uses git-workflow (branch management, PR creation), test-runner (full suite), and context-fetcher (loading lite files)
  - `execute-task.md` - Uses context-fetcher (best practices, code style) and test-runner (task-specific tests)
  - `plan-product.md` - Uses file-creator (directory creation) and context-fetcher (tech stack defaults)
  - `create-spec.md` - Uses file-creator (spec folder) and context-fetcher (mission/roadmap checks)
- **Standards Files** - Updated for conditional agent usage:
  - `code-style.md` - Uses context-fetcher for loading language-specific style guides
- **Setup Scripts** - Enhanced to install Claude Code agents:
  - `setup-claude-code.sh` - Downloads all agents to `~/.claude/agents/` directory

### Improved [1.2.0]

- **Context Efficiency** - Specialized agents use minimal context for their specific tasks
- **Code Organization** - Complex operations delegated to focused agents with clear responsibilities
- **Error Handling** - Agents provide targeted error analysis and recovery strategies
- **Maintainability** - Cleaner main agent code with operations abstracted to subagents
- **Performance** - Reduced context checks through one-time agent detection pattern

### Technical Details

- Each agent uses only necessary tools (e.g., test-runner uses only Bash, Read, Grep, Glob)
- Automatic fallback ensures compatibility for users without Claude Code
- Consistent `IF has_[agent_name]:` pattern reduces code complexity
- All agents follow Spec Agent K conventions (branch naming, commit messages, file templates)

## [1.1.0] - 2025-07-29

### Added [1.1.0]

- New `mission-lite.md` file generation in product initialization for efficient AI context usage
- New `spec-lite.md` file generation in spec creation for condensed spec summaries
- New `execute-task.md` instruction file for individual task execution with TDD workflow
- Task execution loop in `execute-tasks.md` that calls `execute-task.md` for each parent task
- Language-specific code style guides:
  - `standards/code-style/css-style.md` for CSS and TailwindCSS
  - `standards/code-style/html-style.md` for HTML markup
  - `standards/code-style/javascript-style.md` for JavaScript
- Conditional loading blocks in `best-practices.md` and `code-style.md` to prevent duplicate context loading
- Context-aware file loading throughout all instruction files

### Changed [1.1.0]

- Optimized `plan-product.md` to generate condensed versions of documents
- Enhanced `create-spec.md` with conditional context loading for mission-lite and tech-stack files
- Simplified technical specification structure by removing multiple approach options
- Made external dependencies section conditional in technical specifications
- Updated `execute-tasks.md` to use minimal context loading strategy
- Improved `execute-task.md` with selective reading of relevant documentation sections
- Modified roadmap progress check to be conditional and context-aware
- Updated decision documentation to avoid loading decisions.md and use conditional checks
- Restructured task execution to follow typical TDD pattern (tests first, implementation, verification)

### Improved [1.1.0]

- Context efficiency by 60-80% through conditional loading and lite file versions
- Reduced duplication when files are referenced multiple times in a workflow
- Clearer separation between task-specific and full test suite execution
- More intelligent file loading that checks current context before reading
- Better organization of code style rules with language-specific files

### Fixed [1.1.0]

- Duplicate content loading when instruction files are called in loops
- Unnecessary loading of full documentation files when condensed versions suffice
- Redundant test suite runs between individual task execution and overall workflow

## [1.0.0] - 2025-07-21

### Added

- Initial release of Spec Agent K framework
- Core instruction files:
  - `plan-product.md` for product initialization
  - `create-spec.md` for feature specification
  - `execute-tasks.md` for task execution
  - `analyze-product.md` for existing codebase analysis
- Standard files:
  - `tech-stack.md` for technology choices
  - `code-style.md` for formatting rules
  - `best-practices.md` for development guidelines
- Product documentation structure:
  - `mission.md` for product vision
  - `roadmap.md` for development phases
  - `decisions.md` for decision logging
  - `tech-stack.md` for technical architecture
- Setup scripts for easy installation
- Integration with AI coding assistants (Claude Code, Cursor)
- Task management with TDD workflow
- Spec creation and organization system

[1.3.1]: https://github.com/buildermethods/agent-os/compare/v1.3.0...v1.3.1
[1.4.0]: https://github.com/buildermethods/agent-os/compare/v1.3.1...v1.4.0
[1.3.0]: https://github.com/buildermethods/agent-os/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/buildermethods/agent-os/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/buildermethods/agent-os/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/buildermethods/agent-os/releases/tag/v1.0.0
