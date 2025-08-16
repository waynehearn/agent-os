#!/usr/bin/env bash
set -euo pipefail

# section-hash.sh
# Compute section-level hashes for spec files and update [spec_folder]/context/manifest.json
# according to docs/manifest-spec.md and docs/schemas/manifest.schema.json.
#
# Requirements: jq, POSIX tools (grep, sed, awk), and one of sha256sum/shasum/openssl
# Cross-platform: Linux, macOS, Windows (Git Bash/WSL)
#
# Usage:
#   tools/section-hash.sh /absolute/path/to/spec-folder [--files <rel1> <rel2> ...] [--dry-run]
#
# Defaults (relative to spec folder):
#   spec.md
#   sub-specs/api-spec.md
#   sub-specs/database-schema.md

die() { echo "[section-hash] $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

# Cross-platform sha256
sha256_text() {
  # reads stdin, prints hex sha256
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -binary | od -An -tx1 | tr -d ' \n'
  else
    die "No sha256 tool found (sha256sum/shasum/openssl)"
  fi
}

sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$f" | awk '{print $2}'
  else
    die "No sha256 tool found (sha256sum/shasum/openssl)"
  fi
}

# Cross-platform file mtime -> ISO8601 UTC
file_mtime_iso() {
  local f="$1"
  local epoch=""
  if stat -c %Y "$f" >/dev/null 2>&1; then
    epoch=$(stat -c %Y "$f")
    date -u -d @${epoch} +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  fi
  if stat -f %m "$f" >/dev/null 2>&1; then
    epoch=$(stat -f %m "$f")
    date -u -r ${epoch} +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  fi
  date -u +%Y-%m-%dT%H:%M:%SZ
}

need_cmd jq
need_cmd grep
need_cmd sed
need_cmd awk

SPEC_DIR="${1:-}"; shift || true
[[ -z "${SPEC_DIR}" ]] && die "Usage: tools/section-hash.sh /absolute/path/to/spec-folder [--files <rel1> ...] [--dry-run]"

# Resolve to absolute path
if [[ "${SPEC_DIR}" != /* ]]; then
  SPEC_DIR="$(cd "${SPEC_DIR}" && pwd)"
fi
[[ -d "${SPEC_DIR}" ]] || die "Spec folder not found: ${SPEC_DIR}"

DRY_RUN=false
FILES=()
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --files)
      shift
      while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do FILES+=("$1"); shift; done
      ;;
    --dry-run)
      DRY_RUN=true; shift ;;
    *) die "Unknown arg: $1" ;;
  esac
 done

if [[ ${#FILES[@]} -eq 0 ]]; then
  FILES+=(
    "spec.md"
    "sub-specs/api-spec.md"
    "sub-specs/database-schema.md"
  )
fi

CTX_DIR="${SPEC_DIR}/context"
MANIFEST="${CTX_DIR}/manifest.json"
mkdir -p "${CTX_DIR}"

# Initialize manifest if missing, using new shape
if [[ ! -f "${MANIFEST}" ]]; then
  printf '{"files":{},"sections":{}}' > "${MANIFEST}"
fi

# Migrate old shape (docs -> files)
if jq -e '.docs' "${MANIFEST}" >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq '{files: (.docs // {} | with_entries({key: .value.path | sub("^.*/"; ""), value: {sha256: .value.sha256, lastModified: .value.lastModified}})), sections: (.sections // {})}' "${MANIFEST}" > "$tmp" && mv "$tmp" "${MANIFEST}"
  echo "[section-hash] Migrated manifest to section-aware base shape"
fi

# Normalize heading text to a section key (best-effort)
normalize_key() {
  local h="$1"
  h=$(echo "$h" | sed 's/^##\s\+//; s/^#\s\+//; s/\r$//')
  # map common names
  sh=$(echo "$h" | tr '[:upper:]' '[:lower:]')
  case "$sh" in
    overview*) echo "overview" ;;
    user\ stories*) echo "user_stories" ;;
    scope*|spec\ scope*) echo "scope" ;;
    deliverables*|expected\ deliverable*) echo "deliverables" ;;
    technical\ details*) echo "technical_details" ;;
    api\ specification*|api\ spec*) echo "api_spec" ;;
    database\ changes*|database\ schema*) echo "database_changes" ;;
    endpoints*) echo "endpoints" ;;
    models*) echo "models" ;;
    validation*) echo "validation" ;;
    errors*) echo "errors" ;;
    tables*) echo "tables" ;;
    migrations*) echo "migrations" ;;
    constraints*) echo "constraints" ;;
    *) echo "$sh" | tr ' ' '_' | tr -cd '[:alnum:]_-' ;;
  esac
}

# Estimate tokens from char count (~4 chars per token)
estimate_tokens() {
  local text="$1"
  local chars
  chars=$(printf "%s" "$text" | wc -m | awk '{print $1}')
  if [[ -z "$chars" ]]; then echo 0; return; fi
  awk -v c="$chars" 'BEGIN { printf("%d\n", (c+3)/4) }'
}

update_file_entry() {
  local rel="$1" abspath="$2"
  local fhash mtime tmp
  fhash=$(sha256_file "$abspath")
  mtime=$(file_mtime_iso "$abspath")
  tmp=$(mktemp)
  jq --arg rel "$rel" --arg h "$fhash" --arg m "$mtime" \
     '.files[$rel] = {sha256: $h, lastModified: $m}' "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
}

update_sections_entry() {
  local rel="$1" sections_json="$2" tmp
  tmp=$(mktemp)
  # Merge: preserve existing sections, upsert new
  jq --arg rel "$rel" --argjson sec "$sections_json" '
    .sections[$rel].sections = (.sections[$rel].sections // {}) + $sec
  ' "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
}

process_file() {
  local rel="$1" fpath="${SPEC_DIR}/${rel}"
  [[ -f "$fpath" ]] || { echo "[section-hash] skip (missing): $rel"; return 0; }

  # Gather headings (## only) with line numbers
  # Accept both Unix and Windows line endings
  mapfile -t heads < <(grep -n "^##[[:space:]]\+" "$fpath" || true)
  if [[ ${#heads[@]} -eq 0 ]]; then
    echo "[section-hash] no headings found: $rel (skipping sections, will still update files entry)"
    update_file_entry "$rel" "$fpath"
    return 0
  fi

  # Build ranges
  local -a starts titles
  for h in "${heads[@]}"; do
    starts+=("${h%%:*}")
    titles+=("${h#*:}")
  done

  # Determine file length
  local total_lines
  total_lines=$(wc -l < "$fpath" | awk '{print $1}')
  local count=${#starts[@]}
  local i=0
  local sections_json="{}"

  while [[ $i -lt $count ]]; do
    local s=${starts[$i]}
    local e
    if [[ $((i+1)) -lt $count ]]; then
      e=$(( ${starts[$((i+1))]} - 1 ))
    else
      e=$total_lines
    fi
    local title="${titles[$i]}"
    local key
    key=$(normalize_key "$title")
    # Extract section text
    local text
    text=$(sed -n "${s},${e}p" "$fpath")
    local shash
    shash=$(printf "%s" "$text" | sha256_text)
    local toks
    toks=$(estimate_tokens "$text")
    # Merge into sections_json
    sections_json=$(jq --arg k "$key" --arg h "$shash" --arg l "${s}-${e}" --argjson t "$toks" \
      '. + {($k): {hash: $h, tokens: $t, lines: $l}}' <<<"$sections_json")
    i=$((i+1))
  done

  # Update manifest entries
  update_file_entry "$rel" "$fpath"
  update_sections_entry "$rel" "$sections_json"
  echo "[section-hash] updated sections: $rel"
}

for rel in "${FILES[@]}"; do
  process_file "$rel"
 done

if [[ "$DRY_RUN" == true ]]; then
  echo "[section-hash] DRY RUN complete. No changes persisted beyond current updates."
fi

echo "[section-hash] Manifest updated: ${MANIFEST}"
