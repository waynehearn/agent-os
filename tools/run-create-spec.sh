#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_DIR="$ROOT_DIR/.tmp"

# Import context estimator if available
if [[ -f "$SCRIPT_DIR/context-estimator.sh" ]]; then
  source "$SCRIPT_DIR/context-estimator.sh"
fi

# Default settings
PROFILE=${ENABLE_PROFILING:-0}

log() { echo "[create-spec][$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[create-spec][ERROR][$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
success() { echo "[create-spec][SUCCESS][$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Create temp directory if it doesn't exist
mkdir -p "$TEMP_DIR"

# Initialize profiling if enabled
if [[ $PROFILE -eq 1 ]]; then
  ce_start_profiling "create_spec_$(date +%Y%m%d_%H%M%S)"
  log "Profiling enabled for this run"
fi

#===============================================================
# SCRIPT-BASED FUNCTIONS (REPLACING DETERMINISTIC SUBAGENT TASKS)
#===============================================================

# Function: validate_date (replaces date-checker subagent)
validate_date() {
  local date_str="$1"
  local date_pattern="^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
  
  if [[ ! "$date_str" =~ $date_pattern ]]; then
    error "Invalid date format: $date_str. Expected YYYY-MM-DD"
    return 1
  fi
  
  # Additional validation could be added here
  return 0
}

# Function: extract_section (utility for parsing input file)
extract_section() {
  local file="$1"
  local start_pattern="$2"
  local end_pattern="$3"
  local exclude_patterns=("$4" "$5")
  
  sed -n "/$start_pattern/,/$end_pattern/p" "$file" | \
    grep -v "$start_pattern" | \
    grep -v "$end_pattern" | \
    grep -v "${exclude_patterns[0]}" | \
    grep -v "${exclude_patterns[1]}"
}

# Function: normalize_spec_name (replaces part of context-fetcher)
normalize_spec_name() {
  local input_name="$1"
  local override_name="$2"
  
  if [ -n "$override_name" ] && [ "$override_name" != '""' ]; then
    echo "$override_name"
  else
    echo "$input_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | head -c 40
  fi
}

# Function: validate_spec_inputs (validation utility)
validate_spec_inputs() {
  local file="$1"
  local required_fields=("main_idea:" "initial_user_stories:" "in_scope:" "expected_deliverables:")
  local missing_fields=()
  
  for field in "${required_fields[@]}"; do
    if ! grep -q "$field" "$file"; then
      missing_fields+=("$field")
    fi
  done
  
  if [ ${#missing_fields[@]} -gt 0 ]; then
    error "Missing required fields: ${missing_fields[*]}"
    return 1
  fi
  
  return 0
}

# Input validation
if [ "$#" -lt 1 ]; then
  error "Usage: $0 <spec_inputs_file>"
  exit 1
fi

SPEC_INPUTS_FILE="$1"
if [ ! -f "$SPEC_INPUTS_FILE" ]; then
  error "Spec inputs file not found: $SPEC_INPUTS_FILE"
  exit 1
fi

# Validate the input file has required sections
validate_spec_inputs "$SPEC_INPUTS_FILE"
if [ $? -ne 0 ]; then
  exit 1
fi

log "========== Starting create-spec workflow (hybrid mode) =========="

# Pre-compute spec folder variables so early steps (e.g., debug reports) have a stable location
# Note: These will be computed again in Step 1, but values should be identical.
MAIN_IDEA_PRE=$(grep -A 3 'main_idea:' "$SPEC_INPUTS_FILE" | tail -n 1 | sed 's/^[[:space:]]*//g' || true)
SPEC_NAME_OVERRIDE_PRE=$(grep 'spec_name_override:' "$SPEC_INPUTS_FILE" | cut -d'"' -f2 | sed 's/^[[:space:]]*//g' || true)
SPEC_NAME_PRE=$(normalize_spec_name "$MAIN_IDEA_PRE" "$SPEC_NAME_OVERRIDE_PRE")
CURRENT_DATE_PRE=$(date '+%Y-%m-%d')
SPEC_FOLDER_PATH="${ROOT_DIR}/.agent-os/specs/${CURRENT_DATE_PRE}-${SPEC_NAME_PRE}"
CONTEXT_PATH="${SPEC_FOLDER_PATH}/context"

#===============================================================
# STEP 0.9: EXTENSIONS DISCOVERY REPORT (DEBUG OPTIONAL)
#===============================================================
# Honor extension toggles/paths from environment
EXTENSIONS_ENABLED_ENV=${EXTENSIONS_ENABLED:-true}
EXTENSION_SCOPE_ENV=${EXTENSION_SCOPE:-all}
EXTENSION_EXTRA_ROOTS_ENV=${EXTENSION_EXTRA_ROOTS:-}

DEBUG_EXTENSIONS_ENV=${DEBUG_EXTENSIONS:-}
# Read from inputs if present (expects a line like: debug_extensions: true)
DEBUG_EXTENSIONS_INPUT=$(grep -i '^debug_extensions:' "$SPEC_INPUTS_FILE" 2>/dev/null | awk -F ':' '{gsub(/ /,"",$2); print tolower($2)}' || true)
DEBUG_EXTENSIONS=0
if [[ "$DEBUG_EXTENSIONS_ENV" == "1" || "$DEBUG_EXTENSIONS_ENV" == "true" ]]; then
  DEBUG_EXTENSIONS=1
elif [[ "$DEBUG_EXTENSIONS_INPUT" == "true" ]]; then
  DEBUG_EXTENSIONS=1
fi

if [[ $DEBUG_EXTENSIONS -eq 1 && ! "$EXTENSIONS_ENABLED_ENV" =~ ^(0|false|False|FALSE)$ ]]; then
  log "Step 0.9: Extensions Discovery Report (debug)"

  SCANNER="$SCRIPT_DIR/extensions/extension-scanner.sh"
  if [[ -f "$SCANNER" ]]; then
    # Capabilities can be provided via env var (comma-separated), e.g., RUNTIME_CAPABILITIES="mcp:atlassian"
    CAPS=${RUNTIME_CAPABILITIES:-}
    REPORT_DIR="$SPEC_FOLDER_PATH/debug"
    mkdir -p "$REPORT_DIR"
    REPORT_FILE="$REPORT_DIR/extensions-discovery.txt"

  # Run scanner with debug lines; capture human-readable lines from stderr
    # Build args
    SCOPE_ARG=(--scope "$EXTENSION_SCOPE_ENV")
    CAP_ARGS=()
    [[ -n "$CAPS" ]] && CAP_ARGS=(--capabilities "$CAPS")
    EXTRA_ARGS=()
    if [[ -n "$EXTENSION_EXTRA_ROOTS_ENV" ]]; then
      IFS=',' read -r -a roots <<< "$EXTENSION_EXTRA_ROOTS_ENV"
      for r in "${roots[@]}"; do
        [[ -n "$r" ]] && EXTRA_ARGS+=(--extra-root "$r")
      done
    fi

    # Single invocation: capture JSON (stdout) to temp file and human lines (stderr) into variable
    mkdir -p "$TEMP_DIR"
    SCAN_JSON_FILE="$TEMP_DIR/extension-scan-$(date +%s)-$$.json"
    scan_lines=$( { bash "$SCANNER" --flow create-spec "${SCOPE_ARG[@]}" "${CAP_ARGS[@]}" "${EXTRA_ARGS[@]}" --debug-lines 1>"$SCAN_JSON_FILE"; } 2>&1 )
    scan_json=""
    if [[ -f "$SCAN_JSON_FILE" ]]; then
      scan_json=$(cat "$SCAN_JSON_FILE" 2>/dev/null || echo "")
      rm -f "$SCAN_JSON_FILE" || true
    fi

    # Helper: resolve @-logical paths to real paths
    resolve_logical_path() {
      local lp="$1"
      case "$lp" in
        @~/*)
          echo "$HOME${lp#@~}"
          ;;
        @.*)
          echo "$ROOT_DIR${lp#@.}"
          ;;
        @instructions/*)
          echo "$ROOT_DIR/instructions${lp#@instructions}"
          ;;
        *)
          echo "$lp"
          ;;
      esac
    }

    # Extract loaded logical paths from JSON without jq
    loaded_paths=()
    in_loaded=0
    while IFS= read -r line; do
      # Detect start/end of loaded array
      if [[ $in_loaded -eq 0 && $line == *'"loaded": ['* ]]; then
        in_loaded=1
        continue
      fi
      if [[ $in_loaded -eq 1 && $line == *']'* ]]; then
        # This may catch the end of loaded or other arrays; stop at first closing when we already started
        in_loaded=2
      fi
      if [[ $in_loaded -eq 1 ]]; then
        if [[ $line == *'"path":'* ]]; then
          lp=$(echo "$line" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
          if [[ -n "$lp" ]]; then
            loaded_paths+=("$lp")
          fi
        fi
      fi
      [[ $in_loaded -eq 2 ]] && break
    done <<< "$scan_json"

    # Collect core steps from instructions/core/create-spec.md
    core_steps=()
    core_file="$ROOT_DIR/instructions/core/create-spec.md"
    if [[ -f "$core_file" ]]; then
      while IFS= read -r line; do
        if [[ $line == "<step number="* ]]; then
          num=$(echo "$line" | sed -n 's/^<step number="\([0-9.]*\)".*$/\1/p')
          name=$(echo "$line" | sed -n 's/^<step number="[0-9.]*"[^>]*name="\([^"]*\)".*/\1/p')
          if [[ -n "$num" ]]; then
            core_steps+=("$num|core|${name:-}")
          fi
        fi
      done < "$core_file"
    fi

    # Collect extension steps by reading loaded files
    ext_steps=()
    for lp in "${loaded_paths[@]}"; do
      realp=$(resolve_logical_path "$lp")
      [[ -f "$realp" ]] || continue
      while IFS= read -r line; do
        if [[ $line == "<step number="* ]]; then
          num=$(echo "$line" | sed -n 's/^<step number="\([0-9.]*\)".*$/\1/p')
          name=$(echo "$line" | sed -n 's/^<step number="[0-9.]*"[^>]*name="\([^"]*\)".*/\1/p')
          if [[ -n "$num" ]]; then
            ext_steps+=("$num|ext:${lp}|${name:-}")
          fi
        fi
      done < "$realp"
    done

    # Merge and sort by numeric step number
    merged=$( {
      for s in "${core_steps[@]}"; do echo "$s"; done
      for s in "${ext_steps[@]}"; do echo "$s"; done
    } | sort -t '|' -g -k1,1 )

    loaded_cnt=$(echo "$scan_lines" | grep -c '^LOADED  |' || true)
    skipped_cnt=$(echo "$scan_lines" | grep -c '^SKIPPED |' || true)

    {
      echo "Extensions Discovery Report"
      echo "Capabilities: ${CAPS:-[]}"
      echo "Scope: $EXTENSION_SCOPE_ENV"
      echo "Extra roots: ${EXTENSION_EXTRA_ROOTS_ENV:-<none>}"
      echo "---"
      echo "$scan_lines"
      echo "---"
      echo "Summary: loaded: $loaded_cnt, skipped: $skipped_cnt"
      echo ""
      echo "Merged step order (preview):"
      echo "number | name | source"
      while IFS='|' read -r num src nm; do
        [[ -z "$num" ]] && continue
        echo "$num | ${nm:-} | [$src]"
      done <<< "$merged"
    } | tee "$REPORT_FILE" >/dev/null

    log "Extensions discovery report saved to $REPORT_FILE"
  else
    log "[warn] Extension scanner not found; skipping discovery report"
  fi
fi

#===============================================================
# EXTENSIONS: DISCOVERY FOR EXECUTION (ALWAYS WHEN ENABLED)
#===============================================================
EXT_EXEC_ENABLED=1
if [[ "$EXTENSIONS_ENABLED_ENV" =~ ^(0|false|False|FALSE)$ ]]; then
  EXT_EXEC_ENABLED=0
fi

EXT_LOADED_STEPS=()   # entries: "num|ext:<logicalPath>|name"
EXT_EXEC_DONE=()

scan_extensions_for_execution() {
  [[ $EXT_EXEC_ENABLED -eq 1 ]] || return 0

  SCANNER="$SCRIPT_DIR/extensions/extension-scanner.sh"
  [[ -f "$SCANNER" ]] || return 0

  CAPS=${RUNTIME_CAPABILITIES:-}
  SCOPE_ARG=(--scope "${EXTENSION_SCOPE_ENV:-all}")
  CAP_ARGS=()
  [[ -n "$CAPS" ]] && CAP_ARGS=(--capabilities "$CAPS")
  EXTRA_ARGS=()
  if [[ -n "${EXTENSION_EXTRA_ROOTS_ENV:-}" ]]; then
    IFS=',' read -r -a roots <<< "${EXTENSION_EXTRA_ROOTS_ENV}"
    for r in "${roots[@]}"; do
      [[ -n "$r" ]] && EXTRA_ARGS+=(--extra-root "$r")
    done
  fi

  # Use cache-friendly JSON scan
  local json
  json=$(bash "$SCANNER" --flow create-spec "${SCOPE_ARG[@]}" "${CAP_ARGS[@]}" "${EXTRA_ARGS[@]}") || json=""
  [[ -z "$json" ]] && return 0

  # Extract loaded logical paths
  local loaded_paths=()
  local in_loaded=0
  while IFS= read -r line; do
    if [[ $in_loaded -eq 0 && $line == *'"loaded": ['* ]]; then in_loaded=1; continue; fi
    if [[ $in_loaded -eq 1 && $line == *']'* ]]; then in_loaded=2; fi
    if [[ $in_loaded -eq 1 && $line == *'"path"'* ]]; then
      lp=$(echo "$line" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
      [[ -n "$lp" ]] && loaded_paths+=("$lp")
    fi
    [[ $in_loaded -eq 2 ]] && break
  done <<< "$json"

  # Resolve logical path helper
  resolve_logical_path() {
    local lp="$1"
    case "$lp" in
      @~/*) echo "$HOME${lp#@~}" ;;
      @.*) echo "$ROOT_DIR${lp#@.}" ;;
      @instructions/*) echo "$ROOT_DIR/instructions${lp#@instructions}" ;;
      *) echo "$lp" ;;
    esac
  }

  # Parse steps from each extension file
  EXT_LOADED_STEPS=()
  for lp in "${loaded_paths[@]}"; do
    realp=$(resolve_logical_path "$lp")
    [[ -f "$realp" ]] || continue
    while IFS= read -r line; do
      if [[ $line == "<step number="* ]]; then
        num=$(echo "$line" | sed -n 's/^<step number="\([0-9.]*\)".*$/\1/p')
        name=$(echo "$line" | sed -n 's/^<step number="[0-9.]*"[^>]*name="\([^"]*\)".*/\1/p')
        [[ -n "$num" ]] && EXT_LOADED_STEPS+=("$num|ext:${lp}|${name:-}")
      fi
    done < "$realp"
  done
}

# Execute an extension step placeholder
execute_extension_step() {
  local num="$1"; local src="$2"; local nm="$3"
  log "[ext] Executing step $num '${nm:-}' from [$src] (placeholder)"
  # Future: dispatch subagent based on extension metadata
}

# Helper to run steps in a bucket (integer part) with optional range
run_extension_bucket() {
  local bucket_int="$1"; local before_next="$2" # 1 means run < bucket+1, else run == bucket+post
  local new_list=()
  for entry in "${EXT_LOADED_STEPS[@]}"; do
    IFS='|' read -r num src nm <<< "$entry"
    # integer part
    int_part=${num%%.*}
    # Handle numbers like '2' without decimal
    [[ -z "$int_part" ]] && int_part="$num"
    if [[ "$int_part" =~ ^[0-9]+$ ]]; then
      if [[ "$int_part" -eq "$bucket_int" ]]; then
        # Determine if to run now
        if [[ "$before_next" -eq 1 ]]; then
          # Run if num > bucket_int and < bucket_int+1 OR when bucket_int=0, also allow <1
          if awk "BEGIN{exit !($num>$bucket_int && $num<($bucket_int+1))}"; then
            execute_extension_step "$num" "$src" "$nm"
            continue
          fi
        fi
      fi
    fi
    new_list+=("$entry")
  done
  EXT_LOADED_STEPS=("${new_list[@]}")
}

# Run any remaining extension steps (post-run)
run_extension_remaining() {
  for entry in "${EXT_LOADED_STEPS[@]}"; do
    IFS='|' read -r num src nm <<< "$entry"
    execute_extension_step "$num" "$src" "$nm"
  done
  EXT_LOADED_STEPS=()
}

# Perform scan if enabled
scan_extensions_for_execution

#===============================================================
# STEP 1: EXTRACT INPUTS (SCRIPT-BASED)
#===============================================================
log "Step 1: Extracting and validating inputs"

# Start tracking this operation
op_id=$(ce_track_operation "extract_inputs" "script")

# Parse spec inputs and extract variables
MAIN_IDEA=$(grep -A 3 'main_idea:' "$SPEC_INPUTS_FILE" | tail -n 1 | sed 's/^[[:space:]]*//g')
log "Main idea extracted: ${MAIN_IDEA:0:40}..."

# Track the input file for profiling
ce_track_file "$SPEC_INPUTS_FILE" "input"

# Extract spec name override if provided
SPEC_NAME_OVERRIDE=$(grep 'spec_name_override:' "$SPEC_INPUTS_FILE" | cut -d'"' -f2 | sed 's/^[[:space:]]*//g')

# Use the normalized spec name function
SPEC_NAME=$(normalize_spec_name "$MAIN_IDEA" "$SPEC_NAME_OVERRIDE")
log "Using spec name: $SPEC_NAME"

# Current date in YYYY-MM-DD format
CURRENT_DATE=$(date '+%Y-%m-%d')
validate_date "$CURRENT_DATE" || exit 1
log "Using date: $CURRENT_DATE"

# Set up paths
SPEC_FOLDER=".agent-os/specs/$CURRENT_DATE-$SPEC_NAME"
SPEC_FOLDER_PATH="$ROOT_DIR/.agent-os/specs/$CURRENT_DATE-$SPEC_NAME"
CONTEXT_PATH="$SPEC_FOLDER_PATH/context"

# Extract mode (express|standard|investigate)
MODE=$(grep 'mode:' "$SPEC_INPUTS_FILE" | cut -d':' -f2 | sed 's/^[[:space:]]*//g')
if [ -z "$MODE" ]; then
  MODE="standard"
fi
log "Running in $MODE mode"

# Create spec folder and context directory
mkdir -p "$CONTEXT_PATH"
success "Created specification directory structure"

# Run extension steps numbered < 1 and 1.x (immediately after Step 1)
run_extension_bucket 0 1
run_extension_bucket 1 1

#===============================================================
# STEP 2: CONTEXT GATHERING (SCRIPT-BASED)
#===============================================================
log "Step 2: Context gathering and discovery"

# Run product context discovery (completely script-based)
log "Running product context discovery"
PRODUCT_CONTEXT=$("$SCRIPT_DIR/discover-product-context.sh")
if [ $? -ne 0 ]; then
  error "Error during product context discovery"
  exit 1
fi

# Save product context
echo "$PRODUCT_CONTEXT" > "$CONTEXT_PATH/product-context.json"
success "Product context saved to $CONTEXT_PATH/product-context.json"

# End operation tracking
ce_end_operation "$op_id"

#===============================================================
# STEP 2: CONTEXT GATHERING (SCRIPT-BASED)
#===============================================================
log "Step 2: Context gathering and discovery"

# Start tracking this operation
op_id=$(ce_track_operation "gather_context" "script")

# Use context-gatherer.sh if available, otherwise fall back to direct methods
if [[ -f "$SCRIPT_DIR/context-gatherer.sh" ]]; then
  log "Using context-gatherer.sh for efficient context gathering"
  
  # Product context
  "$SCRIPT_DIR/context-gatherer.sh" product "$CONTEXT_PATH/product-context.md"
  
  # Repository context
  "$SCRIPT_DIR/context-gatherer.sh" repo "$CONTEXT_PATH/repo-context.md"
else
  # Fallback: Capture repository information if git is available
  log "Falling back to direct context gathering methods"
  if command -v git >/dev/null 2>&1 && [ -d "$ROOT_DIR/.git" ]; then
    log "Capturing git repository context"
    {
      echo "# Git Repository Information"
      echo "Branch: $(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
      echo "Commit: $(git -C "$ROOT_DIR" rev-parse HEAD)"
      echo "Last commit date: $(git -C "$ROOT_DIR" log -1 --format=%cd)"
      echo ""
    } > "$CONTEXT_PATH/repo-context.md"
    success "Repository context saved"
    
    # Track the output file
    ce_track_file "$CONTEXT_PATH/repo-context.md" "context_output"
  fi
fi

# Run extension steps numbered 2.x
run_extension_bucket 2 1

#===============================================================
# STEP 3: EXTRACT SPECIFICATION COMPONENTS (SCRIPT-BASED)
#===============================================================
log "Step 3: Extracting specification components"

# Using our improved extract_section function
USER_STORIES=$(extract_section "$SPEC_INPUTS_FILE" "initial_user_stories:" "in_scope:" "dummy" "dummy")
IN_SCOPE=$(extract_section "$SPEC_INPUTS_FILE" "in_scope:" "out_of_scope:" "dummy" "dummy")
OUT_OF_SCOPE=$(extract_section "$SPEC_INPUTS_FILE" "out_of_scope:" "expected_deliverables:" "dummy" "dummy")
EXPECTED_DELIVERABLES=$(extract_section "$SPEC_INPUTS_FILE" "expected_deliverables:" "tech_constraints:" "dummy" "dummy")

# Extract tech constraints
TECH_CONSTRAINTS=$(grep -A 3 'tech_constraints:' "$SPEC_INPUTS_FILE" | tail -n 1 | sed 's/^[[:space:]]*//g')

# Extract DB and API change requirements
REQUIRES_DB_CHANGES=$(grep 'requires_db_changes:' "$SPEC_INPUTS_FILE" | cut -d':' -f2 | sed 's/^[[:space:]]*//g')
REQUIRES_API_CHANGES=$(grep 'requires_api_changes:' "$SPEC_INPUTS_FILE" | cut -d':' -f2 | sed 's/^[[:space:]]*//g')

# Save extracted components to context for potential AI enhancement
{
  echo "# Extracted User Stories"
  echo "$USER_STORIES"
  echo ""
  echo "# In Scope Items"
  echo "$IN_SCOPE"
  echo ""
  echo "# Out of Scope Items"
  echo "$OUT_OF_SCOPE"
  echo ""
  echo "# Expected Deliverables"
  echo "$EXPECTED_DELIVERABLES"
  echo ""
  echo "# Technical Constraints"
  echo "$TECH_CONSTRAINTS"
  echo ""
  echo "# Database Changes Required: $REQUIRES_DB_CHANGES"
  echo "# API Changes Required: $REQUIRES_API_CHANGES"
} > "$CONTEXT_PATH/extracted-components.md"

success "Specification components extracted and saved"

# Run extension steps numbered 3.x
run_extension_bucket 3 1

#===============================================================
# STEP 4: GENERATE SPECIFICATION FILE (HYBRID APPROACH)
#===============================================================
log "Step 4: Creating specification document"

# Load any templates if they exist
SPEC_TEMPLATE="$ROOT_DIR/templates/spec-template.md"
if [ -f "$SPEC_TEMPLATE" ]; then
  log "Using spec template from $SPEC_TEMPLATE"
  cat "$SPEC_TEMPLATE" > "$SPEC_FOLDER_PATH/spec.md"
  # Replace template variables (THIS WOULD BE MORE ROBUST IN PRODUCTION)
  sed -i "s/\[SPEC_NAME\]/$SPEC_NAME/g" "$SPEC_FOLDER_PATH/spec.md"
  sed -i "s/\[CURRENT_DATE\]/$CURRENT_DATE/g" "$SPEC_FOLDER_PATH/spec.md"
  sed -i "s/\[MAIN_IDEA\]/$MAIN_IDEA/g" "$SPEC_FOLDER_PATH/spec.md"
  # Etc for other variables
else
  # No template found, create from scratch (script-based)
  log "Creating spec.md from scratch"
  cat > "$SPEC_FOLDER_PATH/spec.md" << EOL
# ${SPEC_NAME} Specification

**Date:** ${CURRENT_DATE}

## Overview

${MAIN_IDEA}

## User Stories

${USER_STORIES}

## Spec Scope

${IN_SCOPE}

## Out of Scope

${OUT_OF_SCOPE}

## Expected Deliverable

${EXPECTED_DELIVERABLES}

## Technical Constraints

${TECH_CONSTRAINTS}

**Requires Database Changes:** ${REQUIRES_DB_CHANGES}
**Requires API Changes:** ${REQUIRES_API_CHANGES}
EOL
fi

success "spec.md created at $SPEC_FOLDER_PATH/spec.md"

# Run extension steps numbered 4.x
run_extension_bucket 4 1

#===============================================================
# STEP 5: GENERATE TASKS (AI-ASSISTED BUT SCRIPT-CREATED)
#===============================================================
log "Step 5: Creating tasks breakdown"

# For this version, we use a static task template
# In a real implementation, you would call an AI here to generate tasks based on spec content
# This demonstrates the hybrid approach - AI generates content, scripts handle file operations

# Extract task categories based on the spec (example of simple analysis)
TASK_CATEGORIES=("Implementation Tasks" "Review Tasks" "Deployment Tasks")
if [ "$REQUIRES_DB_CHANGES" = "true" ]; then
  TASK_CATEGORIES+=("Database Tasks")
fi
if [ "$REQUIRES_API_CHANGES" = "true" ]; then
  TASK_CATEGORIES+=("API Tasks")
fi

# Create tasks.md file with dynamic categories
cat > "$SPEC_FOLDER_PATH/tasks.md" << EOL
# Tasks for ${SPEC_NAME}

## Implementation Tasks

- [ ] Task 1: Initial setup and scaffolding
- [ ] Task 2: Implement core functionality
- [ ] Task 3: Add unit tests
- [ ] Task 4: Add integration tests
- [ ] Task 5: Update documentation

## Review Tasks

- [ ] Code review
- [ ] Test coverage review
- [ ] Documentation review

## Deployment Tasks

- [ ] Prepare deployment plan
- [ ] Deploy to staging
- [ ] Run QA tests
- [ ] Deploy to production
EOL

# Conditionally add database tasks
if [ "$REQUIRES_DB_CHANGES" = "true" ]; then
  cat >> "$SPEC_FOLDER_PATH/tasks.md" << EOL

## Database Tasks

- [ ] Create database schema changes
- [ ] Write migration scripts
- [ ] Test database migrations
- [ ] Create rollback plan
EOL
fi

# Conditionally add API tasks
if [ "$REQUIRES_API_CHANGES" = "true" ]; then
  cat >> "$SPEC_FOLDER_PATH/tasks.md" << EOL

## API Tasks

- [ ] Design API changes
- [ ] Update API documentation
- [ ] Implement API versioning if needed
- [ ] Add API tests
EOL
fi

success "tasks.md created at $SPEC_FOLDER_PATH/tasks.md"

# Run extension steps numbered 5.x
run_extension_bucket 5 1

#===============================================================
# STEP 6: HASH AND VALIDATE (SCRIPT-BASED)
#===============================================================
log "Step 6: Hashing golden example sections"
"$SCRIPT_DIR/section-hash.sh" "$SPEC_FOLDER_PATH" || {
  error "Section hashing failed"
  # Don't exit on this error, continue with validation
}

# Run extension steps numbered 6.x
run_extension_bucket 6 1

log "Step 7: Final validation"
"$SCRIPT_DIR/spec-validator.sh" "$SPEC_FOLDER_PATH/spec.md" || {
  error "Spec validation failed but continuing"
  # Don't exit on validation failure, mark as warning instead
}

# Run extension steps numbered 7.x
run_extension_bucket 7 1

#===============================================================
# STEP 8: CREATE AI ENHANCEMENT PLACEHOLDER (HYBRID APPROACH)
#===============================================================
log "Step 8: Adding AI enhancement placeholder"

# In a real implementation, this is where you would invoke an AI model
# to enhance the spec with additional insights, technical details, etc.
# For now, we'll create a placeholder file explaining how to use AI

cat > "$SPEC_FOLDER_PATH/ai-enhancements.md" << EOL
# AI Enhancement Opportunities

This file identifies opportunities where AI assistance would be beneficial
to enhance the specification. In a fully integrated system, these would be 
automatically processed by an AI model.

## Potential AI Enhancement Tasks

1. **Task Refinement** - AI could analyze the spec to generate more specific, 
   actionable tasks tailored to the project's tech stack and requirements.

2. **Technical Implementation Suggestions** - AI could propose implementation 
   approaches, patterns, or architectures suitable for the feature.

3. **Risk Analysis** - AI could identify potential risks or challenges based 
   on the specification details.

4. **Dependency Analysis** - AI could identify system components that might 
   be affected by this feature.

5. **Testing Strategy** - AI could suggest testing approaches specific to 
   this feature.

To apply AI enhancements:
1. Review the specification and tasks
2. Use a suitable AI assistant to address the specific enhancement areas
3. Incorporate the AI suggestions into the specification
EOL

success "AI enhancement placeholder created"

# Run extension steps numbered 8.x
run_extension_bucket 8 1

# End operation tracking for the last step
ce_end_operation "$op_id"

#===============================================================
# CONCLUSION
#===============================================================
if [ -f "$SPEC_FOLDER_PATH/spec.md" ] && [ -f "$SPEC_FOLDER_PATH/tasks.md" ]; then
  # Run any remaining extension steps (> last core step) before exiting
  run_extension_remaining
  success "========== create-spec workflow completed successfully =========="
  log "Specification created at: $SPEC_FOLDER_PATH/"
  log "Files created:"
  log "  - spec.md: Core specification document"
  log "  - tasks.md: Task breakdown"
  log "  - context/: Context information used for specification"
  log "  - ai-enhancements.md: Placeholder for AI enhancements"
  log ""
  log "Next steps:"
  log "  1. Review the generated specification"
  log "  2. Consider adding AI enhancements where indicated"
  log "  3. Finalize tasks and begin implementation"
  
  # End profiling if enabled
  if [[ $PROFILE -eq 1 ]]; then
    ce_end_profiling
    log "Profiling report generated. Use this to analyze token efficiency."
  fi
  
  exit 0
else
  error "========== create-spec workflow completed with errors =========="
  error "Some expected files were not created correctly"
  
  # End profiling even on error
  if [[ $PROFILE -eq 1 ]]; then
    ce_end_profiling
    log "Profiling report generated despite errors."
  fi
  
  # Run any remaining extension steps even on error
  run_extension_remaining
  exit 1
fi
