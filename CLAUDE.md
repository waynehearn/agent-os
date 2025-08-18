# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spec Agent K is a system for spec-driven agentic development that transforms AI coding agents into productive developers through structured workflows. It provides standards, tech stack definitions, and workflow instructions that help AI agents ship quality code consistently.

## Installation and Setup Commands (local)

Run these from the repository root in Bash (macOS/Linux or Git Bash/WSL on Windows):

### Install Spec Agent K Base System

```bash
bash ./setup.sh
```

### Install Claude Code Integration

```bash
bash ./setup-claude-code.sh
```

### Install Cursor Integration (run inside the target project repo)

```bash
bash ./setup-cursor.sh
```

## Core Architecture

### Directory Structure

- **`instructions/`** - Core workflow instructions for different development phases
  - `core/` - Main workflow files (plan-product.md, create-spec.md, execute-tasks.md, analyze-product.md)
  - `meta/` - Meta instructions like pre-flight checks
- **`standards/`** - Development standards and conventions
  - `tech-stack.md` - Global technology defaults
  - `best-practices.md` - Development guidelines
  - `code-style/` - Language-specific style guides
- **`commands/`** - Claude Code command definitions that reference instructions
- **`claude-code/agents/`** - Specialized subagent configurations for Claude Code

### Spec Agent K Workflow

Spec Agent K follows a structured workflow:

1. **Plan Product** (`/plan-product`) - For new projects, creates mission, tech stack, roadmap, and decisions documentation
2. **Analyze Product** (`/analyze-product`) - For existing projects, analyzes codebase and creates documentation
3. **Create Spec** (`/create-spec`) - Creates detailed specifications for features
4. **Execute Tasks** (`/execute-tasks`) - Implements features based on specifications

### Key File Relationships

- Commands in `commands/` reference instructions in `instructions/core/`
- Instructions use subagents defined in `claude-code/agents/`
- All workflows reference standards from `standards/`
- Product-specific overrides are stored in `.agent-os/product/` within target projects

## Default Tech Stack

When working with Spec Agent K projects, use these defaults unless overridden in project-specific `.agent-os/product/tech-stack.md`:

- **Backend**: Ruby on Rails 8.0+, Ruby 3.2+, PostgreSQL 17+
- **Frontend**: React (latest stable), Vite build tool, Node.js 22 LTS
- **Styling**: TailwindCSS 4.0+, Instrumental Components
- **Icons**: Lucide React components
- **Hosting**: Digital Ocean App Platform, S3 + CloudFront for assets
- **CI/CD**: GitHub Actions with main/staging branch deployment

## Development Principles

### Core Principles (from standards/best-practices.md)

- **Keep It Simple**: Implement in fewest lines, avoid over-engineering
- **Optimize for Readability**: Prioritize clarity, self-documenting code
- **DRY**: Extract repeated logic to methods/components
- **File Structure**: Single responsibility, consistent naming

### Workflow Integration

- Always check for existing Spec Agent K documentation in `.agent-os/product/` before starting work
- Use the date-checker subagent when creating time-sensitive documentation
- Use the context-fetcher subagent to gather information from existing standards
- Use the file-creator subagent for batch file creation with proper structure

## Common Commands

### Initialize Spec Agent K in Projects

- New project: `/plan-product`
- Existing project: `/analyze-product`

### Feature Development

- Create feature spec: `/create-spec`
- Implement feature: `/execute-tasks`

#### Execute Tasks flags inside Claude Code

- Provide `execution_context` with at least:
  - `spec_folder_path`
  - Optional: `specific_tasks`, `execution_notes`
- Debug options:
  - `debug_subagents: true` to emit NDJSON events under `debug/exec-trace/`
  - `debug_trace_redact_secrets`, `debug_trace_include_bodies`
- Script-mode TDD loop (run in terminal when desired):
  - `ENABLE_TDD_LOOP=1` to enable tests
  - `TEST_CMD` (e.g., `npm test -- -t "Greeting"`)
  - `TEST_PATTERN` (auto-inferred from parent title if omitted)
  - `TEST_RETRIES` (default 0/1)

### Direct Setup (compact)

```bash
# Install base system
bash ./setup.sh

# Install Claude Code integration
bash ./setup-claude-code.sh
```

## File Resolution Priority

When resolving configuration or standards:

1. Project-specific `.agent-os/product/` files
2. Global `~/.agent-os/standards/` files
3. Repository `standards/` files (this repo)
4. User Claude memories or Cursor rules

Decisions in `.agent-os/product/decisions.md` have override priority and supersede conflicting directives.
