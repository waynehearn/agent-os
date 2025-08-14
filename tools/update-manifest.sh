#!/usr/bin/env bash
set -euo pipefail

# update-manifest.sh
# Cross-platform (Linux/macOS/Git Bash) utility to update [spec_folder]/context/manifest.json
# with sha256 and lastModified for known spec files or user-specified files.
#
# Requirements: jq
#
# Usage:
#   tools/update-manifest.sh /absolute/path/to/spec-folder [--files <file1> <file2> ...]
#
# Defaults (relative to spec folder):
#   spec.md
#   spec-lite.md
#   sub-specs/technical-spec.md
#   sub-specs/api-spec.md
#   sub-specs/database-schema.md
#   tasks.md
#   context/facts.md

die() { echo "[update-manifest] $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

# Cross-platform sha256
sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    # openssl prints like: SHA256(filename)= hash or (stdin)
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
    if date -u -d @${epoch} +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
      date -u -d @${epoch} +%Y-%m-%dT%H:%M:%SZ
      return 0
    fi
  fi
  if stat -f %m "$f" >/dev/null 2>&1; then
    epoch=$(stat -f %m "$f")
    if date -u -r ${epoch} +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
      date -u -r ${epoch} +%Y-%m-%dT%H:%M:%SZ
      return 0
    fi
  fi
  # Fallback: current time
  date -u +%Y-%m-%dT%H:%M:%SZ
}

need_cmd jq

SPEC_DIR="${1:-}"
shift || true
[[ -z "${SPEC_DIR}" ]] && die "Usage: tools/update-manifest.sh /absolute/path/to/spec-folder [--files <file1> ...]"

# Resolve to absolute path
if [[ "${SPEC_DIR}" != /* ]]; then
  SPEC_DIR="$(cd "${SPEC_DIR}" && pwd)"
fi

[[ -d "${SPEC_DIR}" ]] || die "Spec folder not found: ${SPEC_DIR}"

FILES=()
if [[ "${1:-}" == "--files" ]]; then
  shift
  while [[ $# -gt 0 ]]; do
    FILES+=("$1")
    shift
  done
else
  FILES+=(
    "spec.md"
    "spec-lite.md"
    "sub-specs/technical-spec.md"
    "sub-specs/api-spec.md"
    "sub-specs/database-schema.md"
    "tasks.md"
    "context/facts.md"
  )
fi

CTX_DIR="${SPEC_DIR}/context"
MANIFEST="${CTX_DIR}/manifest.json"
mkdir -p "${CTX_DIR}"

# Initialize manifest if missing
if [[ ! -f "${MANIFEST}" ]]; then
  printf '{"docs":{}}' > "${MANIFEST}"
fi

update_entry() {
  local key="$1" path="$2" hash="$3" mtime="$4"
  # Use jq to upsert docs[key]
  tmp=$(mktemp)
  jq --arg k "$key" \
     --arg p "$path" \
     --arg h "$hash" \
     --arg m "$mtime" \
     '.docs[$k] = {path: $p, sha256: $h, lastModified: $m}' "${MANIFEST}" > "$tmp" && mv "$tmp" "${MANIFEST}"
}

for rel in "${FILES[@]}"; do
  fpath="${SPEC_DIR}/${rel}"
  if [[ -f "${fpath}" ]]; then
    hash=$(sha256_file "${fpath}")
    iso=$(file_mtime_iso "${fpath}")
    key="$(basename "$rel")"
    update_entry "$key" "$fpath" "$hash" "$iso"
    echo "Updated manifest: $key"
  fi
done

echo "Manifest updated: ${MANIFEST}"
