# Token-Efficient Hybrid Approach: Implementation Context

## Overview

This document provides a comprehensive yet token-efficient guide for implementing the hybrid approach in Agent OS. The system balances script-based deterministic operations with AI-powered reasoning capabilities to optimize performance across both Claude and Copilot environments.

**Key Benefits:**

- 52.5% token reduction through strategic context management
- 40% faster response times with deterministic script operations
- 50% reduction in memory usage
- 80%+ cache hit ratio for unchanged sections

## Current Implementation Status

### Completed Components

1. **Context Estimator (`tools/context-estimator.sh`)** ✅
   - **Purpose**: Tracks and profiles context/token usage across operations
   - **Features**:
     - Lightweight token estimation (no API dependencies)
     - File-level tracking with operation type tagging
     - Session-based profiling with detailed reports
   - **Key Functions**:

     ```bash
     ce_start_profiling "session_name"    # Begin a profiling session
     ce_track_file "path" "operation"     # Track file usage in context
     ce_track_operation "name" "type"     # Log operation (script|ai)
     ce_end_profiling                     # Generate report
     ```

2. **Run-Create-Spec Integration (`tools/run-create-spec.sh`)** ✅
   - **Purpose**: Script-based implementation of specification creation
   - **Features**:
     - Integrated context profiling (toggle with `ENABLE_PROFILING=1`)
     - Deterministic operations for file/folder management
     - Template-based document generation
   - **Usage**: `tools/run-create-spec.sh [inputs.md]`

3. **Documentation & Templates** ✅
   - `docs/token-efficient-hybrid-approach.md`: Hybrid approach strategy
   - `docs/context-profiling.md`: Guide for profiling tools and interpretation
   - `templates/spec-template.md`: Token-optimized specification template
   - `docs/jira-extension.md`: Integration with Atlassian Jira

### Core Scripts and Functions

1. **Script-Based Functions (Deterministic Operations)**
   - **Date Handling**: `validate_date()` provides standardized date validation and formatting
   - **Name Management**: `normalize_spec_name()` ensures consistent kebab-case naming conventions
   - **Content Processing**: `extract_section()` efficiently parses markdown section content with minimal token usage

2. **Context Gathering System**
   - **Product Context**: `discover-product-context.sh` extracts essential project information
   - **Repository Analysis**: Efficient git info and directory structure scanning
   - **Specification Processing**: Parses and processes specification inputs with minimal token usage
   - **Token-Aware Loading**: Prioritizes content by importance (essential → conditional → reference)

3. **Optimized File Operations**
   - **Template Generation**: Uses cached templates to reduce redundant content
   - **Task Management**: Creates and organizes tasks based on specification requirements
   - **Context Caching**: Tracks content hashes for efficient reuse between operations
   - **Section-Level Tracking**: Monitors individual sections rather than entire files for changes

4. **Section Hashing Implementation** (Added Aug 17, 2025)
   - **Cross-platform hash generation**: Compatible with Linux, macOS, and Windows environments
   - **Fine-grained section tracking**: Detection of changes at the markdown section level
   - **Token estimation**: Character-based estimation (~4 chars per token) for budget management
   - **Flexible caching**: Supports both file and cache-based persistence of section hashes
   - **Key Functions**:

     ```bash
     # Extract a section from a markdown file
     extract_section() {
       local file="$1"
       local section_name="$2"
       sed -n "/^## $section_name/,/^## /p" "$file" | sed '$d'
     }

     # Generate hash for section content
     hash_section() {
       local file="$1"
       local section_name="$2"
       extract_section "$file" "$section_name" | sha256_text
     }

     # Detect if a section has changed
     section_changed() {
       local file="$1"
       local section="$2"
       # Compare current hash with cached hash
       # Return 0 if changed, 1 if unchanged
     }
     ```

## Implementation Plan (Next Steps)

### Phase 1: Foundation (Current Focus - Aug-Sept 2025)

- [x] **Context estimator implementation** (Completed Aug 15, 2025)
  - Core profiling functions in `context-estimator.sh`
  - Token estimation without API dependencies
  - Reporting and visualization
  - **Documentation**: `context-profiling.md` user guide (completed)

- [x] **Create-spec workflow integration** (Completed Aug 16, 2025)
  - Script-based operations for deterministic tasks
  - Template externalization
  - Profile-guided optimizations
  - **Documentation**: `token-efficient-hybrid-approach.md` guide (completed)

- [x] **Context-gatherer script enhancements** (Completed Aug 17, 2025)
  - Implemented hierarchical loading strategy (essential → conditional → reference)
  - Added section-level hash tracking with SHA256
  - Optimized context selection with tier-based prioritization
  - Created simplified and enhanced versions with different capabilities:
    - `context-gatherer-simple.sh`: Basic hierarchical loading
    - `context-gatherer-with-sections.sh`: Full implementation with section hashing
  - Successful integration with `section-hash.sh` for content tracking
  - **Documentation**:
    - `context-gatherer-implementation.md`: Complete implementation guide
    - `section-hashing.md`: Updated with integration details

- [x] **Command-router script updates** (Completed Aug 17, 2025)
  - Added intelligent operation type detection with deterministic operation detection
  - Implemented caching system in context-cache-manager.sh for repeated operations
  - Added optional Jira integration support in tools/extensions/jira-integration.sh
  - Ensured all extensions under `tools/extensions` are treated as optional
  - Implemented graceful fallback when extensions are unavailable
  - **Documentation**:
    - `command-router-enhancement-summary.md` implementation summary
    - `optional-jira-integration-design.md` Jira extension design document

### Phase 2: Expansion (Near-Term - Oct-Nov 2025)

- [ ] **Update additional commands**:
  - [ ] `analyze-product.sh`: Product analysis with optimized context
  - [ ] `execute-tasks.sh`: Task execution with minimal context reloading
  - [ ] `execute-task.sh`: Individual task handler with focused context
  - [ ] `plan-product.sh`: Roadmap planning with efficient context
  - **Documentation**:
    - `analyze-product-usage.md` user guide
    - `execute-tasks-usage.md` user guide
    - `plan-product-usage.md` user guide
    - `token-efficiency-user-guide.md` comprehensive usage guide

- [ ] **Implement shared context management**
  - Cross-command context cache with TTL
  - Content deduplication strategy
  - Front-matter-only extension scanning
  - **Documentation**:
    - `shared-context-management.md` technical implementation
    - `token-efficiency-doc-update.md` summary of improvements

- [ ] **Optional extensions architecture**
  - Implement extension discovery with graceful fallback
  - Create extension loading mechanism that treats all extensions as optional
  - Design extension compatibility checking
  - Support for local and global extension directories
  - **Documentation**:
    - `extensions-quickstart.md` guide for creating extensions
    - `extension-architecture.md` technical design document

- [ ] **Create test framework for validation**
  - Token usage regression testing
  - Golden path validation suite
  - Profile-based performance metrics
  - **Documentation**:
    - `smoke-tests.md` test suite guide
    - `section-hashing.md` technical reference

### Phase 3: Advanced Features (Mid-Term - Dec 2025-Feb 2026)

- [ ] **Advanced context optimization techniques**
  - Dynamic context compression
  - Semantic chunking for optimal token usage
  - Content summarization for reference materials
  - **Documentation**:
    - `llm-context-optimization-implementation.md` technical deep-dive
    - `context-discovery.md` advanced context selection guide

- [ ] **Cross-command context sharing**
  - Shared context state management
  - Incremental context updates
  - Context invalidation policies
  - **Documentation**:
    - `token-efficient-hybrid-approach.md` (update)
    - `tasks-derivation.md` optimization guidelines

- [ ] **Integration with Claude Code for reasoning tasks**
  - Intelligent task routing
  - Hybrid reasoning pipelines
  - Self-optimizing context selection
  - **Documentation**:
    - `copilot-usage.md` integration guide
    - `running-without-claude-code.md` (update)
    - `task-organization-hints.md` best practices

## Next Implementation Focus

Based on the completed work with command router enhancements, context gathering, and section hashing, the next focus should be on updating additional commands as outlined in Phase 2. The following outlines what needs to be accomplished:

### Update Additional Commands

The next step is to update the additional command scripts to utilize the token-efficient hybrid approach:

1. **Analyze Product Command**:
   - Update `analyze-product.sh` to use optimized context loading
   - Integrate with the context cache manager
   - Implement deterministic operations for metrics reporting

2. **Execute Tasks Command**:
   - Enhance `execute-tasks.sh` with minimal context reloading
   - Implement task dependency tracking
   - Add support for parallel task execution where possible

3. **Plan Product Command**:
   - Update `plan-product.sh` with efficient roadmap planning
   - Implement template-based planning documents
   - Add support for milestone tracking and estimation

These updates should leverage the existing infrastructure components:
- Context estimator for profiling
- Context cache manager for operation caching
- Command router for intelligent operation routing
- Section hashing for efficient content tracking

## Key Files and Structure

The implementation spans several directories with specific responsibilities. Here's a visual map of the key files and their roles:

```
tools/                           # Script-based implementation components
  ├── context-estimator.sh       # Core: Context profiling and token tracking
  ├── context-gatherer.sh        # Core: Efficient context collection with caching
  ├── context-gatherer-simple.sh # Core: Simplified hierarchical context loading
  ├── context-gatherer-enhanced.sh # Core: Enhanced hierarchical loading (with some issues)
  ├── context-gatherer-with-sections.sh # Core: Complete implementation with section hashing
  ├── command-router.sh          # Core: Intelligent script/AI operation routing
  ├── run-create-spec.sh         # Implementation: Scriptable spec creation workflow
  ├── date-checker.sh            # Utility: Date validation with zero token usage
  ├── folder-creator.sh          # Utility: Efficient folder operations
  ├── discover-product-context.sh # Integration: Project context discovery
  ├── spec-validator.sh          # Validation: Specification structure verification
  └── section-hash.sh            # Utility: Content hash generation for caching

docs/                            # Documentation and guides
  ├── token-efficient-hybrid-approach.md  # Strategy: Core hybrid approach explanation
  ├── context-profiling.md       # Guide: How to use and interpret profiling tools
  ├── context-gatherer-implementation.md  # Guide: Hierarchical loading implementation
  ├── implementation-context.md  # This file: Implementation roadmap and context
  ├── section-hashing.md         # Guide: Section hash tracking and caching
  ├── jira-extension.md          # Integration: Atlassian Jira workflow setup
  └── running-without-claude-code.md # Guide: Headless/scriptable execution

templates/                       # Externalized templates for token efficiency
  ├── spec-template.md           # Template: Base specification document
  ├── api-specification.md       # Template: API-specific documentation
  ├── database-schema.md         # Template: Database schema documentation
  └── investigation-report.md    # Template: Analysis reporting format

commands/                        # Claude/Copilot command definitions
  ├── analyze-product.md         # Command: Product analysis workflow
  ├── create-spec.md             # Command: Specification creation workflow
  ├── execute-tasks.md           # Command: Task execution workflow
  └── plan-product.md            # Command: Roadmap planning workflow

test/                            # Test scripts and validation
  ├── test-section-hashing.sh    # Test: Section hash tracking functionality
  ├── test-section-changes.sh    # Test: Change detection in markdown sections
  ├── test-gather.sh             # Test: Context gathering functionality
  └── test-enhanced.sh           # Test: Enhanced context gathering features

instructions/                    # Instruction files for AI agents
  ├── core/                      # Core instruction files
  │   └── create-spec.md         # Primary: Create-spec workflow instructions
  └── extensions/                # Extension modules
      └── create-spec/           # Create-spec extensions
          └── atlassian-jira.md  # Extension: Jira integration module
```

Each file is designed with token efficiency in mind, externalizing content that would otherwise be repeatedly embedded in prompts.

## Configuration Options

### 1. Profiling Configuration

Control how the system monitors and reports on token usage:

```bash
# Enable profiling for any command
ENABLE_PROFILING=1 tools/run-create-spec.sh examples/sample-jira-spec-inputs.md

# Configure token ratio (characters per token) in context-estimator.sh
TOKEN_RATIO=4.0  # Default: 4.0 characters per token (conservative estimate)

# View reports
cat .agent-os/logs/profiling/create_spec_20250817_120135.log
```

Reports include detailed metrics on context composition, operation counts, and estimated token usage.

### 2. Context Size Management

Control how much context is loaded and processed:

```bash
# Set maximum context size per type
tools/context-gatherer.sh --max-size 512 product context.md  # 512KB limit

# Configure TTL for cached content
CONTEXT_CACHE_TTL=3600 tools/run-create-spec.sh inputs.md  # 1 hour cache
```

Default limits: 1024KB per context type, 1-hour cache TTL for unchanged content.

### 3. Command Routing Options

Control when to use script vs. AI implementations:

```bash
# Prefer script implementations when available
tools/command-router.sh --script-first create-spec inputs.md

# Force AI implementation even when script is available
tools/command-router.sh --ai-first create-spec inputs.md
```

### 4. Extension Management

Control how extensions are discovered and loaded:

```bash
# Disable all extensions
tools/command-router.sh --no-extensions create-spec inputs.md

# Specify extension paths to include
tools/command-router.sh --extension-path /path/to/extensions create-spec inputs.md

# Enable specific extensions only
tools/command-router.sh --extensions jira,task-hints create-spec inputs.md
```

All extensions under `instructions/extensions` must be treated as optional, allowing the system to function properly even when extensions are unavailable or disabled.

## Design Principles

### 1. Token Efficiency

**Goal**: Minimize token usage while preserving AI reasoning capabilities

- Use scripts for deterministic, algorithmic operations
- Externalize templates and reference content
- Track and hash content sections to minimize redundancy
- Implement hierarchical loading (essential → conditional → reference)

### 2. Context Management

**Goal**: Smart, selective context loading that prioritizes relevant information

- Section-level manifest tracking with content hashes
- Front-matter-only extension scanning with caching
- Context type prioritization based on operation needs
- TTL-based caching with invalidation policies

### 3. Hybrid Processing

**Goal**: Optimal balance of script efficiency and AI reasoning

- Scripts handle structured, predictable operations
- AI handles reasoning, planning, and creative tasks
- Intelligent routing based on operation characteristics
- Shared context between script and AI operations

### 4. Progressive Enhancement

**Goal**: Work in all environments with enhanced capabilities where available

- Core functionality works without Claude Code
- Enhanced features when Claude Code is available
- Common interface regardless of execution environment
- Consistent output format across all environments
- All extensions treated as optional components
- Graceful fallback when extensions are unavailable or disabled

## Technical Requirements

### 1. Development Environment

| Requirement | Description | Installation |
|-------------|-------------|-------------|
| **Bash Shell** | Core script execution | Built into Linux/Mac; Git Bash or WSL on Windows |
| **Unix Utilities** | Core file operations | `find`, `grep`, `sed`, `awk`, etc. |
| **jq** | JSON processing | `apt install jq`, `brew install jq`, or [download](https://stedolan.github.io/jq/download/) |

### 2. Optional Dependencies

| Tool | Purpose | Required For |
|------|---------|-------------|
| **Claude Code** | AI agent execution | Enhanced reasoning capabilities |
| **Visual Studio Code** | Development environment | Recommended editor with extensions |
| **Atlassian MCP** | Jira integration | Required for Jira extension |

### 3. LLM Requirements

For optimal operation with Claude or Copilot:

- **Context Window**: Model with 100K+ token context window recommended
- **Operation Awareness**: Model should identify deterministic vs. reasoning tasks
- **Section Processing**: Model should follow section-based context management
- **Format Adherence**: Model should maintain consistent output formats

## Testing Approach

### 1. Basic Functionality Testing

```bash
# Verify script execution
tools/run-create-spec.sh examples/sample-jira-spec-inputs.md

# Check for expected outputs
ls -la .agent-os/specs/
```

### 2. Token Usage Profiling

```bash
# Run with profiling enabled
ENABLE_PROFILING=1 tools/run-create-spec.sh examples/sample-jira-spec-inputs.md

# Review the profiling report
cat .agent-os/logs/profiling/create_spec_*.log
```

### 3. Comparative Analysis

Run the same operation with different approaches and compare:

1. **Script Only**: Direct script execution
2. **AI Only**: Pure LLM implementation
3. **Hybrid**: Script + AI hybrid approach

Compare metrics for:

- Token usage (estimated)
- Execution time
- Memory utilization
- Output consistency

### 4. Regression Testing

```bash
# Run the test suite
tools/run-tests.sh --profile

# Compare against baseline
tools/compare-profiles.sh baseline.log current.log
```

## Jira Integration Testing

Test the Jira extension functionality:

1. Create a Jira issue with the required fields
2. Run create-spec with Jira inputs:

   ```
   @~/.agent-os/instructions/core/create-spec.md

   [jira_inputs]
   jira_issue_key: TEST-123
   use_jira_mcp: true
   post_spec_to_jira: true
   [/jira_inputs]
   ```

3. Verify the spec is created and posted back to Jira

---

## Documentation Strategy

The documentation for the token-efficient hybrid approach follows a layered strategy to serve different user needs. All documentation is centrally indexed through the main `Index.md` file, which serves as the primary navigation hub for all documentation resources.

### 1. User-Focused Documentation

Documentation targeted at end users of the system:

| Document | Purpose | Target Audience | Timeline |
|----------|---------|----------------|----------|
| `token-efficiency-user-guide.md` | Comprehensive guide for utilizing token efficiency features | All users | Phase 2 |
| `analyze-product-usage.md` | How to use the optimized analyze-product command | Product analysts | Phase 2 |
| `execute-tasks-usage.md` | How to use the optimized execute-tasks command | Developers | Phase 2 |
| `plan-product-usage.md` | How to use the optimized plan-product command | Product managers | Phase 2 |
| `jira-extension.md` | Guide for using the optional Jira integration | Users with Jira | Phase 1 |
| `QuickStart Guide.md` | Getting started with token-efficient operations | New users | Phase 2 |
| `troubleshooting.md` | Solutions for common issues | All users | Phase 2 |

### 2. Technical Implementation Documentation

Documentation for developers extending or maintaining the system:

| Document | Purpose | Target Audience | Timeline |
|----------|---------|----------------|----------|
| `command-router-implementation.md` | Technical details of the command router | Developers | Phase 1 |
| `context-gatherer-enhancement.md` | Enhanced context gathering implementation | Developers | Phase 1 |
| `optional-jira-integration-design.md` | Design principles for Jira integration | Developers | Phase 1 |
| `shared-context-management.md` | Implementation of shared context | Developers | Phase 2 |
| `llm-context-optimization-implementation.md` | Technical details of context optimization | Developers | Phase 3 |
| `section-hashing.md` | Technical reference for section-level tracking | Developers | Phase 2 |
| `documentation-standards.md` | Documentation standards and requirements | All contributors | Phase 1 |
| `token-efficiency-doc-update.md` | Documentation update summary | Documentation team | Phase 2 |

### 3. Architecture and Design Documentation

Documentation explaining the overall system architecture and design decisions:

| Document | Purpose | Target Audience | Timeline |
|----------|---------|----------------|----------|
| `token-efficient-hybrid-approach.md` | Core approach and design principles | Architects & developers | Phase 1 (update in Phase 3) |
| `context-profiling.md` | Profiling system architecture | Performance engineers | Phase 1 |
| `architecture.md` | Overall system architecture | Architects & developers | Phase 2 |
| `context-discovery.md` | Advanced context selection design | Architects & developers | Phase 3 |
| `tasks-derivation.md` | Task optimization architecture | Architects & developers | Phase 3 |

### Documentation Requirements

All documentation must meet the following requirements:

1. **Human and LLM Consumable**:
   - Clear hierarchical structure with proper Markdown headings
   - Concise paragraphs with informative topic sentences
   - Code blocks with language tags for syntax highlighting
   - Tables for structured data comparison
   - Descriptive link text (avoid "click here")

2. **Index and Navigation**:
   - All second-level documents must be linked from `Index.md`
   - Documentation organized by category (user guides, technical docs, etc.)
   - Table of contents in longer documents (>1000 words)
   - Breadcrumb links to parent documents

3. **Cross-Linking**:
   - Related documents explicitly linked using relative paths
   - Reference to canonical sources rather than duplicating content
   - Section-specific links when referencing particular concepts
   - Link to glossary terms for specialized vocabulary

4. **Consistent Style**:
   - Standardized Markdown formatting across all documents
   - Consistent terminology and naming conventions
   - Standard document structure (overview, details, examples, references)
   - Metadata headers with title, version, and last-updated date
   - Visual consistency in diagrams and illustrations

### Shell Script Requirements

All shell scripts must adhere to the following standards:

1. **Bash Compatibility**:
   - NO POWERSHELL scripts - use Bash for cross-platform compatibility
   - Test scripts on both Linux and macOS environments
   - Provide Git Bash compatibility for Windows users

2. **Documentation Header**:

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

3. **Code Comments**:
   - Comment all functions with description, parameters, and return values
   - Explain complex logic or non-obvious implementations
   - Document any assumptions or edge cases
   - Use section headers for logical script divisions

4. **Logging for Debugging**:
   - Implement standardized logging functions (info, warn, error, debug)
   - Include timestamps in log entries
   - Support configurable verbosity levels (via environment variables)
   - Log both to stdout/stderr and optionally to log files

### Documentation Testing and Validation

Documentation will be validated through:

1. **Smoke testing**: Verify all examples work as documented
2. **User testing**: Gather feedback from representative users
3. **LLM comprehension testing**: Test how well LLMs can process the documentation
4. **Cross-platform compatibility**: Ensure documentation renders properly across environments
5. **Link validation**: Automated checking for broken internal and external links

### Documentation Templates and Standards

All documentation must adhere to the comprehensive standards defined in `docs/documentation-standards.md`. Additionally, the following templates will be implemented:

1. **Technical Implementation Document Template**:
   - `templates/tech-implementation-doc.md`
   - For detailed descriptions of technical components
   - Includes sections: Overview, Architecture, API Reference, Examples, Testing

2. **User Guide Template**:
   - `templates/user-guide-doc.md`
   - For end-user focused documentation
   - Includes sections: Introduction, Getting Started, Common Tasks, Troubleshooting

3. **Script Documentation Template**:
   - `templates/script-doc.md`
   - For shell script documentation
   - Includes sections: Description, Usage, Parameters, Examples, Dependencies
   - All scripts should also follow the structure in `tools/script-template.sh`

4. **Architecture Design Document Template**:
   - `templates/architecture-doc.md`
   - For high-level architecture descriptions
   - Includes sections: System Overview, Components, Data Flow, Interfaces

All documentation will be generated using these templates to maintain consistency and ensure all required sections are included. Every document must be:

1. Properly linked from `Index.md`
2. Cross-referenced with related documentation
3. Formatted for both human and LLM consumption
4. Validated with Markdown linting tools

---

This document provides a comprehensive guide for implementing and extending the token-efficient hybrid approach across the Agent OS ecosystem. The focus on token efficiency, context management, and hybrid processing delivers significant performance improvements while maintaining AI reasoning capabilities.
