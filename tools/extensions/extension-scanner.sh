#!/usr/bin/env bash
set -euo pipefail

# extension-scanner.sh
# Fast, front-matter-only scanner for extension files.
# - Reads only YAML front matter bounded by the first pair of '---' lines.
# - Filters by targets (flow) and optional requires (capabilities).
# - Integrates with shared cache if tools/context-cache-manager.sh is present.
# - Outputs a JSON report with loaded vs skipped and reasons.
#
# Usage:
#   bash tools/extensions/extension-scanner.sh --flow create-spec \
#     --capabilities "mcp:atlassian,foo" --scope all --cache-ttl 3600
#
# Exit codes:
#   0 on success
#   2 on invalid arguments

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

# Defaults
FLOW=""
SCOPE="all"           # home|project|repo|all
CAPABILITIES=""       # comma-separated
USE_CACHE=1
CACHE_TTL=3600
DEBUG_LINES=0

# Optional shared cache manager
CACHE_MANAGER="$REPO_ROOT/tools/context-cache-manager.sh"
if [[ -f "$CACHE_MANAGER" ]]; then
  # shellcheck source=/dev/null
  source "$CACHE_MANAGER" || true
fi

err() { echo "[extension-scanner] $*" 1>&2; }

print_help() {
  cat <<EOF
Front-matter-only extension scanner

Options:
  --flow NAME           Required. Flow name to match in targets, e.g. create-spec
  --scope SCOPE         home|project|repo|all (default: all)
  --capabilities LIST   Comma-separated capabilities, e.g. mcp:atlassian,foo
  --no-cache            Disable cache usage
  --cache-ttl SEC       TTL seconds for cache (default: 3600)
  --debug-lines         Also print human lines about decisions to stderr
  -h|--help             Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flow)
      FLOW=${2:-}
      shift 2
      ;;
    --scope)
      SCOPE=${2:-}
      shift 2
      ;;
    --capabilities)
      CAPABILITIES=${2:-}
      shift 2
      ;;
    --no-cache)
      USE_CACHE=0
      shift 1
      ;;
    --cache-ttl)
      CACHE_TTL=${2:-3600}
      shift 2
      ;;
    --debug-lines)
      DEBUG_LINES=1
      shift 1
      ;;
    -h|--help)
      print_help; exit 0
      ;;
    *)
      err "Unknown argument: $1"; print_help; exit 2
      ;;
  esac
done

if [[ -z "$FLOW" ]]; then
  err "--flow is required"; print_help; exit 2
fi

# Capability membership check
has_cap() {
  local cap="$1"
  [[ ",$CAPABILITIES," == *",$cap,"* ]]
}

# Extract front matter between the first pair of --- lines, excluding the markers
extract_front_matter() {
  local file="$1"
  # Use awk to find first pair of '---' lines and print inner content
  awk '
    BEGIN{dash=0}
    /^---[ \t]*$/ {dash++ ; if (dash==1) next; if (dash==2) exit}
    dash==1 {print}
  ' "$file"
}

# Parse a YAML array line like: key: ["a", "b"] or key: [a,b]
parse_yaml_array_line() {
  local line="$1"
  # Get stuff between first [ and last ]
  local inner
  inner=$(echo "$line" | sed -n 's/^[^\[]*\[\(.*\)\][^\]]*$/\1/p') || true
  if [[ -z "$inner" ]]; then
    echo ""
    return
  fi
  # Split by comma, trim spaces and quotes
  local out=""
  IFS=',' read -r -a parts <<< "$inner"
  for p in "${parts[@]}"; do
    p=$(echo "$p" | sed 's/^ *\"\?//; s/\"\? *$//')
    if [[ -n "$p" ]]; then
      if [[ -z "$out" ]]; then out="$p"; else out+="|$p"; fi
    fi
  done
  echo "$out"
}

# Convert a pipe-delimited list to JSON array string
to_json_array() {
  local pipe_list="$1"
  if [[ -z "$pipe_list" ]]; then
    echo '[]'
    return
  fi
  local json="["
  IFS='|' read -r -a items <<< "$pipe_list"
  for i in "${!items[@]}"; do
    local val="${items[$i]}"
    # Escape quotes
    val=${val//\"/\\\"}
    if [[ $i -gt 0 ]]; then json+=","; fi
    json+="\"$val\""
  done
  json+="]"
  echo "$json"
}

# Normalize a path for logical display with @ prefixes where applicable
logical_path() {
  local p="$1"
  local home="$HOME/.agent-os"
  if [[ "$p" == "$home"* ]]; then
    echo "@~${p#$HOME}"
    return
  fi
  if [[ "$p" == "$REPO_ROOT/.agent-os"* ]]; then
    echo "@.${p#$REPO_ROOT}"
    return
  fi
  if [[ "$p" == "$REPO_ROOT/instructions"* ]]; then
    echo "@instructions${p#$REPO_ROOT/instructions}"
    return
  fi
  echo "$p"
}

# Build list of base directories based on scope
collect_search_paths() {
  local flow="$1"
  local -a paths=()
  case "$SCOPE" in
    home)
      paths+=("$HOME/.agent-os/instructions/extensions/$flow")
      ;;
    project)
      paths+=("$REPO_ROOT/.agent-os/instructions/extensions/$flow")
      ;;
    repo)
      paths+=("$REPO_ROOT/instructions/extensions/$flow")
      ;;
    all|both|*)
      paths+=(
        "$HOME/.agent-os/instructions/extensions/$flow"
        "$REPO_ROOT/.agent-os/instructions/extensions/$flow"
        "$REPO_ROOT/instructions/extensions/$flow"
      )
      ;;
  esac
  printf '%s\n' "${paths[@]}"
}

# Discover files
discover_files() {
  local base="$1"
  if [[ ! -d "$base" ]]; then return; fi
  find "$base" -type f -name '*.md' -print 2>/dev/null || true
}

# Scan and produce JSON
scan() {
  local now_iso
  now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local -a all_files=()
  while IFS= read -r p; do all_files+=("$p"); done < <(collect_search_paths "$FLOW")

  local -a files=()
  for d in "${all_files[@]}"; do
    while IFS= read -r f; do files+=("$f"); done < <(discover_files "$d")
  done

  local loaded_json="[]"
  local skipped_json="[]"
  local loaded_cnt=0
  local skipped_cnt=0

  for f in "${files[@]}"; do
    local fm
    fm=$(extract_front_matter "$f" || true)
    if [[ -z "$fm" ]]; then
      # No front matter; skip silently
      continue
    fi

    # Extract fields (best-effort, line-based)
    local targets_line requires_line vendor_line description_line
    targets_line=$(echo "$fm" | grep -E '^targets:') || true
    requires_line=$(echo "$fm" | grep -E '^requires:') || true
    vendor_line=$(echo "$fm" | grep -E '^vendor:') || true
    description_line=$(echo "$fm" | grep -E '^description:') || true

    local targets requires vendor description
    targets=$(parse_yaml_array_line "$targets_line")
    requires=$(parse_yaml_array_line "$requires_line")
    vendor=$(echo "$vendor_line" | sed -n 's/^vendor:[ \t]*\(.*\)$/\1/p')
    description=$(echo "$description_line" | sed -n 's/^description:[ \t]*\(.*\)$/\1/p')

    # Must have targets containing FLOW
    local status reason
    status="SKIPPED"
    reason="no matching target"
    IFS='|' read -r -a tarr <<< "$targets"
    for t in "${tarr[@]}"; do
      if [[ "$t" == "$FLOW" ]]; then status="CANDIDATE"; reason=""; break; fi
    done

    # Capability requires gating
    if [[ "$status" == "CANDIDATE" && -n "$requires" ]]; then
      IFS='|' read -r -a rarr <<< "$requires"
      for r in "${rarr[@]}"; do
        if [[ -n "$r" && ! $(has_cap "$r" && echo yes) == yes ]]; then
          status="SKIPPED"; reason="requires $r not available"; break
        fi
      done
    fi

    local t_json r_json lpath
    t_json=$(to_json_array "$targets")
    r_json=$(to_json_array "$requires")
    lpath=$(logical_path "$f")

    if [[ "$status" == "CANDIDATE" ]]; then
      status="LOADED"
      ((loaded_cnt++))
      [[ $DEBUG_LINES -eq 1 ]] && err "LOADED  | $lpath | vendor=${vendor:-}"
      # Append to loaded_json
      local item
      item=$(cat <<EOJ
{"path":"$lpath","targets":$t_json,"requires":$r_json,"vendor":"${vendor:-}","description":"${description:-}"}
EOJ
)
      if [[ "$loaded_json" == "[]" ]]; then
        loaded_json="[$item]"
      else
        loaded_json="${loaded_json%]} , $item]"
      fi
    else
      ((skipped_cnt++))
      [[ $DEBUG_LINES -eq 1 ]] && err "SKIPPED | $lpath | reason=$reason"
      local item
      item=$(cat <<EOJ
{"path":"$lpath","targets":$t_json,"requires":$r_json,"vendor":"${vendor:-}","description":"${description:-}","reason":"$reason"}
EOJ
)
      if [[ "$skipped_json" == "[]" ]]; then
        skipped_json="[$item]"
      else
        skipped_json="${skipped_json%]} , $item]"
      fi
    fi
  done

  local caps_json
  if [[ -n "$CAPABILITIES" ]]; then
    # Convert comma list to JSON array
    local pipe=${CAPABILITIES//,/|}
    caps_json=$(to_json_array "$pipe")
  else
    caps_json='[]'
  fi

  # Scanned roots for report
  local roots_json="["
  local first=1
  while IFS= read -r root; do
    [[ -z "$root" ]] && continue
    local lp=$(logical_path "$root")
    if [[ $first -eq 0 ]]; then roots_json+=","; fi
    roots_json+="\"$lp\""
    first=0
  done < <(collect_search_paths "$FLOW")
  roots_json+="]"

  cat <<JSON
{
  "flow": "$FLOW",
  "generatedAt": "$now_iso",
  "capabilities": $caps_json,
  "scannedRoots": $roots_json,
  "ttlSeconds": $CACHE_TTL,
  "counts": {"loaded": $loaded_cnt, "skipped": $skipped_cnt, "total": $((loaded_cnt+skipped_cnt))},
  "loaded": $loaded_json,
  "skipped": $skipped_json
}
JSON
}

# Cache wrapper: try shared cache manager first
run_with_cache() {
  local key
  if declare -f generate_cache_key >/dev/null 2>&1; then
    key=$(generate_cache_key "extension-scan" "$FLOW" "$SCOPE" "$CAPABILITIES")
    # Validate/get
    if [[ $USE_CACHE -eq 1 ]] && declare -f is_cache_valid >/dev/null 2>&1 && \
       is_cache_valid "$key" "$CACHE_TTL" && declare -f get_cached_result >/dev/null 2>&1; then
      get_cached_result "$key"
      return 0
    fi

    local result
    result=$(scan)
    if [[ $USE_CACHE -eq 1 ]] && declare -f cache_operation >/dev/null 2>&1; then
      cache_operation "$key" "$CACHE_TTL" "$result" >/dev/null 2>&1 || true
    fi
    echo "$result"
    return 0
  fi

  # Fallback simple cache under project .agent-os/cache
  local cache_dir="$REPO_ROOT/.agent-os/cache"
  mkdir -p "$cache_dir"
  local safe_caps
  safe_caps=${CAPABILITIES//[^A-Za-z0-9_:\-]/_}
  local cache_file="$cache_dir/extensions_${FLOW}_${SCOPE}_${safe_caps}.json"

  if [[ $USE_CACHE -eq 1 && -f "$cache_file" ]]; then
    # Check TTL
    local now ts
    now=$(date +%s)
    # stat -c not available on mac; use perl fallback if needed
    if ts=$(date +%s -r "$cache_file" 2>/dev/null); then
      :
    else
      ts=$(perl -e 'print((stat(shift))[9])' "$cache_file" 2>/dev/null || echo 0)
    fi
    if (( now - ts < CACHE_TTL )); then
      cat "$cache_file"
      return 0
    fi
  fi

  local result
  result=$(scan)
  if [[ $USE_CACHE -eq 1 ]]; then
    echo "$result" > "$cache_file" || true
  fi
  echo "$result"
}

run_with_cache
