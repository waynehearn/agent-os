#!/usr/bin/env bash
set -euo pipefail

# discover-product-context.sh
# Unified, Bash-only product context discovery for Spec Agent Kibo flows.
#
# Goals:
# - Prefer existing sources (do not create anything unless asked)
# - Aggregate minimal context needed by analyze-product/create-spec
# - Be fast and dependency-light (jq required)
# - Work on Linux/macOS and Windows (Git Bash/WSL)
#
# Priority order (first found wins for each field):
#  1) .agent-os/product/context/context.json (authoritative cache if valid)
#  2) .agent-os/product/* (mission.md, tech-stack.md, roadmap.md, decisions.md, context/facts.md)
#  3) CLAUDE.md (Project Overview section)
#  4) docs/architecture.md, docs/index.md
#  5) README.md
#  6) Heuristics from build files (package.json, pyproject.toml, Gemfile, pom.xml, build.gradle, go.mod, Cargo.toml, composer.json, *.csproj)
#
# If insufficient and --init-product is supplied, create a minimal .agent-os/product/ skeleton
# using detected signals. Otherwise, only emit JSON to stdout or to the cache if --write-if-missing.
#
# Usage:
#   tools/discover-product-context.sh [project_root] [--write | --write-if-missing] [--init-product]
#   tools/discover-product-context.sh --help
#
# Output:
#   JSON document matching docs/schemas/product-context.schema.json (best-effort)
#

die() { echo "[discover-context] $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || return 1; }

# Find jq (supports WSL with Windows jq.exe)
JQ_BIN=""
if need_cmd jq; then
  JQ_BIN="$(command -v jq)"
elif need_cmd jq.exe; then
  JQ_BIN="$(command -v jq.exe)"
else
  # Attempt common Windows locations when running under WSL
  if grep -qi microsoft /proc/version 2>/dev/null; then
    for p in \
      "/mnt/c/Users/$USER/.local/bin/jq.exe" \
      "/mnt/c/Program Files/jq/jq.exe" \
      "/mnt/c/Program Files (x86)/jq/jq.exe" \
      "/mnt/c/Program Files/Git/usr/bin/jq.exe"; do
      if [[ -x "$p" ]]; then JQ_BIN="$p"; break; fi
    done
  fi
fi

[[ -n "$JQ_BIN" ]] || die "Missing dependency: jq (or jq.exe under WSL). See docs/installation.md."

# Wrap jq calls so the script can transparently use jq.exe if needed
jq() { "$JQ_BIN" "$@"; }

usage() {
  cat <<'USAGE'
discover-product-context.sh
Unified, Bash-only product context discovery for Spec Agent Kibo.

Usage:
  tools/discover-product-context.sh [project_root] [--write | --write-if-missing] [--init-product]

Options:
  --write              Write aggregated JSON to .agent-os/product/context/context.json (create dirs as needed)
  --write-if-missing   Only write cache file if it doesn't already exist
  --init-product       If aggregated context is insufficient, create minimal .agent-os/product/ skeleton
  --help               Show this help

Environment:
  None required. Uses jq (or jq.exe under WSL) and standard POSIX tools.

Exit codes:
  0 success
  1 generic error
  2 insufficient context (when not using --init-product); JSON still printed to stdout
USAGE
}

PROJECT_ROOT="${1:-.}"
if [[ "$PROJECT_ROOT" == "--help" || "${2:-}" == "--help" || "${3:-}" == "--help" ]]; then
  usage; exit 0
fi

# If first arg is a flag, assume CWD as root
case "$PROJECT_ROOT" in
  --write|--write-if-missing|--init-product)
    PROJECT_ROOT="."
    ;;
  *) ;;
esac

WRITE_MODE="none"    # none|write|write-if-missing
INIT_PRODUCT=false

# Parse flags (start at $2 if root provided)
shift || true
for arg in "$@"; do
  case "$arg" in
    --write) WRITE_MODE="write" ;;
    --write-if-missing) WRITE_MODE="write-if-missing" ;;
    --init-product) INIT_PRODUCT=true ;;
    --help) usage; exit 0 ;;
    *) ;;
  esac
done

# Normalize Windows path to WSL path when applicable (e.g., C:\path or C:/path)
is_wsl=false
if grep -qi microsoft /proc/version 2>/dev/null; then is_wsl=true; fi

win_to_wsl_path() {
  local p="$1"
  # Handle drive-letter paths like C:\Users\... or C:/Users/...
  if [[ "$p" =~ ^([A-Za-z]):[\\/](.*)$ ]]; then
    local drive rest
    drive="${BASH_REMATCH[1]}"; rest="${BASH_REMATCH[2]}"
    drive="${drive,,}"
    rest="${rest//\\/\/}"
    printf '/mnt/%s/%s' "$drive" "$rest"
  else
    printf '%s' "$p"
  fi
}

if [[ "$is_wsl" == true ]]; then
  PROJECT_ROOT="$(win_to_wsl_path "$PROJECT_ROOT")"
fi

# Normalize root to absolute path for consistency
if [[ "$PROJECT_ROOT" != /* ]]; then
  PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
fi
[[ -d "$PROJECT_ROOT" ]] || die "Project root not found: $PROJECT_ROOT"

# Helpers
read_text_if_exists() { # path -> sets REPLY to file content (raw); empty if missing
  local p="$1"
  if [[ -f "$p" ]]; then
    REPLY="$(cat "$p" 2>/dev/null || true)"
  else
    REPLY=""
  fi
}

append_unique() { # varname value -> add value to JSON array stored in varname
  local var="$1" val="$2"
  local cur=${!var:-"[]"}
  # shellcheck disable=SC2034
  printf -v "$var" '%s' "$(jq --arg v "$val" 'if index($v) then . else . + [$v] end' <<<"$cur")"
}

ensure_dir() { mkdir -p "$1"; }

# Target cache path
PRODUCT_DIR="$PROJECT_ROOT/.agent-os/product"
CTX_DIR="$PRODUCT_DIR/context"
CACHE_JSON="$CTX_DIR/context.json"

# Start aggregate JSON
AGG='{
  "sources_used": [],
  "overview": null,
  "target_users": [],
  "tech_stack": [],
  "implemented_features": [],
  "planned_features": [],
  "decisions": [],
  "roadmap": [],
  "sufficient_for_analyze": false,
  "sufficiency_reasons": []
}'

add_source() { AGG="$(jq --arg s "$1" '.sources_used += [$s]' <<<"$AGG")"; }
set_overview_if_empty() {
  local text="$1"
  if jq -e '.overview == null or .overview == ""' >/dev/null <<<"$AGG"; then
    AGG="$(jq --arg o "$text" '.overview = $o' <<<"$AGG")"
  fi
}
merge_array_unique() { # field jsonArray
  local field="$1" arrJson="$2"
  AGG="$(jq --argjson arr "$arrJson" --arg field "$field" '.[$field] = (.[$field] + $arr | unique)' <<<"$AGG")"
}

# 1) Cached JSON (if valid)
if [[ -f "$CACHE_JSON" ]]; then
  if jq empty "$CACHE_JSON" >/dev/null 2>&1; then
    add_source ".agent-os/product/context/context.json"
    # Trust cached fields where present
    for f in overview target_users tech_stack implemented_features planned_features decisions roadmap; do
      val=$(jq -c --arg f "$f" '.[ $f ] // empty' "$CACHE_JSON" || true)
      if [[ -n "$val" && "$val" != "null" ]]; then
        case "$f" in
          overview)
            AGG="$(jq --arg o "$(jq -r '.overview' "$CACHE_JSON")" '.overview = $o' <<<"$AGG")"
            ;;
          *)
            merge_array_unique "$f" "$val"
            ;;
        esac
      fi
    done
  fi
fi

# 2) Product docs
MISSION="$PRODUCT_DIR/mission.md"
TECH="$PRODUCT_DIR/tech-stack.md"
ROADMAP="$PRODUCT_DIR/roadmap.md"
DECISIONS="$PRODUCT_DIR/decisions.md"
FACTS="$PRODUCT_DIR/context/facts.md"

if [[ -f "$MISSION" || -f "$TECH" || -f "$ROADMAP" || -f "$DECISIONS" || -f "$FACTS" ]]; then
  add_source ".agent-os/product/*"
fi

if [[ -f "$MISSION" ]]; then
  read_text_if_exists "$MISSION"; set_overview_if_empty "$REPLY"
fi

if [[ -f "$TECH" ]]; then
  # Extract simple bullet list items as stack entries
  mapfile -t items < <(grep -E '^[\-*]\s+' "$TECH" | sed 's/^[\-*]\s\+//' || true)
  if [[ ${#items[@]} -gt 0 ]]; then
    js="$(printf '%s
' "${items[@]}" | jq -Rs 'split("\n") | map(select(length>0))')"
    merge_array_unique tech_stack "$js"
  fi
fi

if [[ -f "$ROADMAP" ]]; then
  # Parse checkboxes: - [x] implemented, - [ ] planned
  mapfile -t impl < <(grep -E '^\s*-\s*\[x\]\s+' "$ROADMAP" | sed -E 's/^\s*-\s*\[x\]\s+//' || true)
  mapfile -t plan < <(grep -E '^\s*-\s*\[ \]\s+' "$ROADMAP" | sed -E 's/^\s*-\s*\[ \]\s+//' || true)
  if [[ ${#impl[@]} -gt 0 ]]; then
    js="$(printf '%s
' "${impl[@]}" | jq -Rs 'split("\n") | map(select(length>0))')"
    merge_array_unique implemented_features "$js"
  fi
  if [[ ${#plan[@]} -gt 0 ]]; then
    js="$(printf '%s
' "${plan[@]}" | jq -Rs 'split("\n") | map(select(length>0))')"
    merge_array_unique planned_features "$js"
  fi
fi

if [[ -f "$DECISIONS" ]]; then
  # Take headings and bullets as decision summaries
  mapfile -t decs < <(grep -E '^(#|\s*[-*])\s+' "$DECISIONS" | sed -E 's/^#*\s*//; s/^[-*]\s+//' || true)
  if [[ ${#decs[@]} -gt 0 ]]; then
    js="$(printf '%s
' "${decs[@]}" | jq -Rs 'split("\n") | map(select(length>0))')"
    merge_array_unique decisions "$js"
  fi
fi

# 3) CLAUDE.md (Project Overview section)
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]]; then
  # Extract between '## Project Overview' and next '##'
  section=$(awk '/^##\s+Project Overview/{flag=1; next} /^##\s+/{flag=0} flag{print}' "$CLAUDE_MD" || true)
  if [[ -n "${section//[[:space:]]/}" ]]; then
    add_source "CLAUDE.md"
    set_overview_if_empty "$section"
  fi
fi

# 4) docs/architecture.md, docs/index.md
if [[ -f "$PROJECT_ROOT/docs/architecture.md" ]]; then
  add_source "docs/architecture.md"
  read_text_if_exists "$PROJECT_ROOT/docs/architecture.md"; set_overview_if_empty "$REPLY"
fi
if [[ -f "$PROJECT_ROOT/docs/index.md" ]]; then
  add_source "docs/index.md"
  read_text_if_exists "$PROJECT_ROOT/docs/index.md"; set_overview_if_empty "$REPLY"
fi

# 5) README.md (top paragraphs)
if [[ -f "$PROJECT_ROOT/README.md" ]]; then
  add_source "README.md"
  head_text=$(head -n 80 "$PROJECT_ROOT/README.md" || true)
  set_overview_if_empty "$head_text"
fi

# 6) Heuristic tech stack detection
add_stack_if() { # label predicate
  local label="$1" pred="$2"
  if eval "$pred"; then
    AGG="$(jq --arg s "$label" '.tech_stack += [$s] | .tech_stack |= unique' <<<"$AGG")"
  fi
}

# Language/platform signals
add_stack_if "Node.js" "[[ -f '$PROJECT_ROOT/package.json' ]]"
add_stack_if "Python" "[[ -f '$PROJECT_ROOT/pyproject.toml' || -f '$PROJECT_ROOT/requirements.txt' ]]"
add_stack_if "Ruby" "[[ -f '$PROJECT_ROOT/Gemfile' ]]"
add_stack_if "Java" "[[ -f '$PROJECT_ROOT/pom.xml' || -f '$PROJECT_ROOT/build.gradle' || -f '$PROJECT_ROOT/build.gradle.kts' ]]"
# .NET detection via find to avoid globstar issues
add_stack_if ".NET" "find '$PROJECT_ROOT' -maxdepth 2 -name '*.csproj' -print -quit | grep -q ."
add_stack_if "Go" "[[ -f '$PROJECT_ROOT/go.mod' ]]"
add_stack_if "Rust" "[[ -f '$PROJECT_ROOT/Cargo.toml' ]]"
add_stack_if "PHP" "[[ -f '$PROJECT_ROOT/composer.json' ]]"
add_stack_if "Docker" "[[ -f '$PROJECT_ROOT/Dockerfile' ]]"

# Framework/library extraction (best-effort)
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
  add_source "package.json"
  # combine deps and devDeps, search for common frameworks
  deps=$(jq -r '[.dependencies, .devDependencies] | map(select(.!=null)) | add // {} | keys[]' "$PROJECT_ROOT/package.json" 2>/dev/null || true)
  while IFS= read -r dep; do
    case "$dep" in
      react) add_stack_if "React" 'true' ;;
      next|nextjs|next.js) add_stack_if "Next.js" 'true' ;;
      vite) add_stack_if "Vite" 'true' ;;
      vue) add_stack_if "Vue" 'true' ;;
      @angular*|angular) add_stack_if "Angular" 'true' ;;
      svelte) add_stack_if "Svelte" 'true' ;;
      express) add_stack_if "Express" 'true' ;;
      nest|@nestjs*) add_stack_if "NestJS" 'true' ;;
      typescript) add_stack_if "TypeScript" 'true' ;;
      tailwindcss) add_stack_if "TailwindCSS" 'true' ;;
    esac
  done <<< "$deps"
fi

if [[ -f "$PROJECT_ROOT/Gemfile" ]]; then
  add_source "Gemfile"
  if grep -qi 'rails' "$PROJECT_ROOT/Gemfile"; then add_stack_if "Rails" 'true'; fi
  if grep -qi 'sinatra' "$PROJECT_ROOT/Gemfile"; then add_stack_if "Sinatra" 'true'; fi
fi

if [[ -f "$PROJECT_ROOT/pyproject.toml" ]]; then
  add_source "pyproject.toml"
  if grep -qi 'fastapi' "$PROJECT_ROOT/pyproject.toml"; then add_stack_if "FastAPI" 'true'; fi
  if grep -qi 'django' "$PROJECT_ROOT/pyproject.toml"; then add_stack_if "Django" 'true'; fi
  if grep -qi 'flask' "$PROJECT_ROOT/pyproject.toml"; then add_stack_if "Flask" 'true'; fi
fi
if [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
  add_source "requirements.txt"
  if grep -qi '^fastapi' "$PROJECT_ROOT/requirements.txt"; then add_stack_if "FastAPI" 'true'; fi
  if grep -qi '^django' "$PROJECT_ROOT/requirements.txt"; then add_stack_if "Django" 'true'; fi
  if grep -qi '^flask' "$PROJECT_ROOT/requirements.txt"; then add_stack_if "Flask" 'true'; fi
fi

if [[ -f "$PROJECT_ROOT/pom.xml" ]]; then
  add_source "pom.xml"
  if grep -qi 'spring-boot' "$PROJECT_ROOT/pom.xml"; then add_stack_if "Spring Boot" 'true'; fi
fi
if ls "$PROJECT_ROOT"/build.gradle* >/dev/null 2>&1; then
  add_source "build.gradle*"
  if grep -qi 'spring-boot' "$PROJECT_ROOT"/build.gradle* 2>/dev/null; then add_stack_if "Spring Boot" 'true'; fi
fi

if find "$PROJECT_ROOT" -name '*.csproj' -print -quit | grep -q .; then
  add_source "*.csproj"
  if grep -Rqi "Microsoft.AspNetCore" "$PROJECT_ROOT" 2>/dev/null; then add_stack_if "ASP.NET" 'true'; fi
fi

if [[ -f "$PROJECT_ROOT/go.mod" ]]; then
  add_source "go.mod"
fi
if [[ -f "$PROJECT_ROOT/Cargo.toml" ]]; then
  add_source "Cargo.toml"
fi
if [[ -f "$PROJECT_ROOT/composer.json" ]]; then
  add_source "composer.json"
  if jq -e '.require["laravel/framework"]' "$PROJECT_ROOT/composer.json" >/dev/null 2>&1; then add_stack_if "Laravel" 'true'; fi
  if jq -e '.require["symfony/symfony"]' "$PROJECT_ROOT/composer.json" >/dev/null 2>&1; then add_stack_if "Symfony" 'true'; fi
fi

# Sufficiency check
has_overview=$(jq -r '(.overview // "") | length > 20' <<<"$AGG")
has_stack=$(jq -r '(.tech_stack // []) | length > 0' <<<"$AGG")
sufficient=false
reasons=()
[[ "$has_overview" == "true" ]] || reasons+=("missing_overview")
[[ "$has_stack" == "true" ]] || reasons+=("missing_tech_stack")

if [[ ${#reasons[@]} -eq 0 ]]; then
  sufficient=true
fi

AGG="$(jq --argjson ok "$sufficient" '.sufficient_for_analyze = $ok' <<<"$AGG")"
if [[ ${#reasons[@]} -gt 0 ]]; then
  js_reasons="$(printf '%s\n' "${reasons[@]}" | jq -Rs 'split("\n") | map(select(length>0))')"
  AGG="$(jq --argjson r "$js_reasons" '.sufficiency_reasons = $r' <<<"$AGG")"
fi

# Write cache if requested
maybe_write=false
case "$WRITE_MODE" in
  write)
    maybe_write=true ;;
  write-if-missing)
    [[ -f "$CACHE_JSON" ]] || maybe_write=true ;;
  *) ;;
esac

if [[ "$maybe_write" == true ]]; then
  ensure_dir "$CTX_DIR"
  printf '%s' "$AGG" > "$CACHE_JSON"
fi

# If insufficient and --init-product, create minimal skeleton
created_files=()
if [[ "$sufficient" != true && "$INIT_PRODUCT" == true ]]; then
  ensure_dir "$PRODUCT_DIR"
  ensure_dir "$CTX_DIR"

  if [[ ! -f "$MISSION" ]]; then
    printf '# Mission\n\n' > "$MISSION"
    # Use overview if we have any, else placeholder
    if jq -e '.overview != null and .overview != ""' >/dev/null <<<"$AGG"; then
      jq -r '.overview' <<<"$AGG" >> "$MISSION"
    else
      printf 'TBD: Add a 1–2 paragraph mission/overview here.\n' >> "$MISSION"
    fi
    created_files+=("$MISSION")
  fi

  if [[ ! -f "$TECH" ]]; then
    printf '# Tech Stack\n\n' > "$TECH"
    if jq -e '(.tech_stack // []) | length > 0' >/dev/null <<<"$AGG"; then
      jq -r '.tech_stack[] | "- " + .' <<<"$AGG" >> "$TECH"
    else
      printf '- TBD (add languages, frameworks, DB, hosting)\n' >> "$TECH"
    fi
    created_files+=("$TECH")
  fi

  if [[ ! -f "$ROADMAP" ]]; then
    cat > "$ROADMAP" <<'RM'
# Roadmap

## Phase 0: Already Completed

- [ ] (Add implemented items)

## Phase 1: Current Development

- [ ] (Add in-progress items)

## Phase 2+: Planned

- [ ] (Add planned items)
RM
    created_files+=("$ROADMAP")
  fi

  if [[ ! -f "$DECISIONS" ]]; then
    cat > "$DECISIONS" <<'DM'
# Decisions

- (Add important technical/product decisions with rationale and date)
DM
    created_files+=("$DECISIONS")
  fi

  # Generate facts.md from AGG (lite summary)
  if [[ ! -f "$FACTS" ]]; then
    ensure_dir "$(dirname "$FACTS")"
    {
      printf '## Facts (lite)\n\n'
      printf '### Overview\n\n'
      if jq -e '.overview != null and .overview != ""' >/dev/null <<<"$AGG"; then
        jq -r '.overview' <<<"$AGG"
      else
        printf 'N/A\n'
      fi
      printf '\n### Tech Stack\n\n'
      if jq -e '(.tech_stack // []) | length > 0' >/dev/null <<<"$AGG"; then
        jq -r '.tech_stack[] | "- " + .' <<<"$AGG"
      else
        printf '- N/A\n'
      fi
      printf '\n### Implemented Features\n\n'
      if jq -e '(.implemented_features // []) | length > 0' >/dev/null <<<"$AGG"; then
        jq -r '.implemented_features[] | "- " + .' <<<"$AGG"
      else
        printf '- N/A\n'
      fi
      printf '\n### Planned Features\n\n'
      if jq -e '(.planned_features // []) | length > 0' >/dev/null <<<"$AGG"; then
        jq -r '.planned_features[] | "- " + .' <<<"$AGG"
      else
        printf '- N/A\n'
      fi
    } > "$FACTS"
    created_files+=("$FACTS")
  fi

  # Always refresh cache after init
  printf '%s' "$AGG" > "$CACHE_JSON"
fi

# Print JSON to stdout
printf '%s\n' "$AGG"

# Exit code: 0 if sufficient or created, 2 if insufficient without init
if [[ "$sufficient" == true || ( "$sufficient" != true && "$INIT_PRODUCT" == true ) ]]; then
  exit 0
else
  exit 2
fi
