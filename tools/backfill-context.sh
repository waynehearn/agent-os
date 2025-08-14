#!/usr/bin/env bash
set -euo pipefail

# backfill-context.sh
# Populate context artifacts (meta.json, context/facts.md, context/manifest.json)
# for existing specs under .agent-os/specs/.
#
# Requirements: jq, awk, sed, grep
#
# Usage:
#   tools/backfill-context.sh [root_dir]
#   Default root_dir: current working directory
#
# Notes:
# - Best-effort: does not modify spec.md content; derives counts via simple parsing.
# - Skips files that do not exist.

ROOT_DIR="${1:-$(pwd)}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need_cmd jq
need_cmd awk
need_cmd sed
need_cmd grep

spec_counts() {
  # Args: spec_path
  local spec="$1"
  local user_stories=0 scope=0 deliverables=0
  if [[ -f "$spec" ]]; then
    # Count h3 under User Stories and numbered items for scope/deliverables
    user_stories=$(awk '/^## +User Stories/{flag=1;next} /^## /{flag=0} flag && /^### /{c++} END{print c+0}' "$spec")
    scope=$(awk '/^## +Spec Scope/{flag=1;next} /^## /{flag=0} flag && /^\s*\d+\./{c++} END{print c+0}' "$spec")
    deliverables=$(awk '/^## +Expected Deliverable/{flag=1;next} /^## /{flag=0} flag && /^\s*\d+\./{c++} END{print c+0}' "$spec")
  fi
  echo "$user_stories $scope $deliverables"
}

ensure_file() {
  local path="$1"; shift
  local content="$*"
  if [[ ! -f "$path" ]]; then
    mkdir -p "$(dirname "$path")"
    printf "%s\n" "$content" > "$path"
  fi
}

FACTS_TMPL() {
  local spec_name="$1" spec_date="$2" mission_line="$3"; shift 3
  cat <<EOF
# Context Facts

- Mission (lite): ${mission_line:-N/A}
- Spec: ${spec_name} (${spec_date})
- Primary deliverables (1–3):
  - [fill from Expected Deliverable]
- Constraints/assumptions:
  - [fill]
- Notes:
  - This file is the canonical lite context for execution flows.
EOF
}

MISSION_LITE_LINE() {
  local mission_lite="$1"
  if [[ -f "$mission_lite" ]]; then
    # First non-empty, non-heading line
    awk 'NF && $0 !~ /^#/ {print; exit}' "$mission_lite"
  fi
}

update_meta() {
  local meta="$1" spec_key="$2" spec_name="$3" spec_date="$4" db_flag="$5" api_flag="$6" us="$7" sc="$8" dlv="$9"
  local tmp
  tmp=$(mktemp)
  jq -n --arg key "$spec_key" --arg name "$spec_name" --arg date "$spec_date" \
        --argjson rdb ${db_flag} --argjson rap ${api_flag} \
        --arg us "$us" --arg sc "$sc" --arg dlv "$dlv" \
        '{spec_key:$key,spec_name:$name,spec_date:$date,requires_db_changes:$rdb,requires_api_changes:$rap,section_counts:{user_stories:($us|tonumber),spec_scope:($sc|tonumber),expected_deliverables:($dlv|tonumber)}}' > "$tmp"
  mv "$tmp" "$meta"
}

ROOT_SPEC_DIR="$ROOT_DIR/.agent-os/specs"
if [[ ! -d "$ROOT_SPEC_DIR" ]]; then
  echo "No specs directory at $ROOT_SPEC_DIR; nothing to backfill." >&2
  exit 0
fi

for specdir in "$ROOT_SPEC_DIR"/*; do
  [[ -d "$specdir" ]] || continue
  spec_md="$specdir/spec.md"
  spec_lite="$specdir/spec-lite.md"
  tech_spec="$specdir/sub-specs/technical-spec.md"
  tasks_md="$specdir/tasks.md"
  ctx_dir="$specdir/context"
  manifest="$ctx_dir/manifest.json"
  meta="$specdir/meta.json"
  facts="$ctx_dir/facts.md"

  # Derive spec key and name from folder
  base="$(basename "$specdir")" # e.g., 2025-08-14-feature-name
  spec_key="$base"
  spec_date="${base%%-*}"
  spec_name="${base#*-}"
  # Flags default false; cannot infer safely
  requires_db=false
  requires_api=false

  read us sc dlv < <(spec_counts "$spec_md")

  # facts.md
  mission_line="$(MISSION_LITE_LINE "$ROOT_DIR/.agent-os/product/mission-lite.md")"
  ensure_file "$facts" "$(FACTS_TMPL "$spec_name" "$spec_date" "${mission_line:-}")"

  # meta.json
  update_meta "$meta" "$spec_key" "$spec_name" "$spec_date" "$requires_db" "$requires_api" "$us" "$sc" "$dlv"

  # manifest.json via update-manifest.sh
  "$(dirname "$0")/update-manifest.sh" "$specdir" >/dev/null || true
  echo "Backfilled: $specdir"

done

echo "Backfill complete."
