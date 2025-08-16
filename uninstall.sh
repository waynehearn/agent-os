#!/bin/bash

# Spec Agent K Uninstall Script (local-only)
# Safely removes files installed under ~/.agent-os with optional dry-run and backups.
# No network calls.

set -euo pipefail

DRY_RUN=false
ENABLE_BACKUP=true
REMOVE_ALL=false
ONLY_INSTRUCTIONS=false
ONLY_STANDARDS=false
ONLY_DOCS=false
PURGE_BACKUPS=false

TIMESTAMP="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_ROOT="$HOME/.agent-os/.backup/$TIMESTAMP/pre-uninstall"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_backup_dir() {
  [[ "$ENABLE_BACKUP" == true ]] || return 0
  mkdir -p "$BACKUP_ROOT" >/dev/null 2>&1 || true
}

backup_path_for() {
  local dest="$1" base="$HOME/.agent-os" rel
  rel="${dest#$base/}"
  printf "%s" "$BACKUP_ROOT/$rel"
}

backup_file() {
  local dest="$1" out
  [[ "$ENABLE_BACKUP" == true ]] || return 0
  [[ -f "$dest" ]] || return 0
  ensure_backup_dir
  out="$(backup_path_for "$dest")"
  mkdir -p "$(dirname "$out")"
  cp -f "$dest" "$out" 2>/dev/null || true
}

remove_path() {
  local p="$1"
  if [[ -e "$p" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  ~ Would remove: ${p#$HOME/}"
    else
      if [[ -f "$p" ]]; then
        backup_file "$p"
        rm -f "$p"
      else
        # directory
        # Back up only tracked files within directory
        while IFS= read -r -d '' f; do
          backup_file "$f"
        done < <(find "$p" -type f -print0)
        rm -rf "$p"
      fi
      echo "  ✓ Removed: ${p#$HOME/}"
    fi
  fi
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Safely uninstall Spec Agent K files from ~/.agent-os.

Options:
  --dry-run           Show what would be removed without deleting
  --no-backup         Do not back up files before removal
  --all               Remove the entire ~/.agent-os directory
  --only-instructions Remove only instructions (~/.agent-os/instructions)
  --only-standards    Remove only standards (~/.agent-os/standards)
  --only-docs         Remove only docs (~/.agent-os/docs)
  --purge-backups     Additionally remove ~/.agent-os/.backup (use with --all)
  -h, --help          Show help

Notes:
  - By default, changed files are backed up to ~/.agent-os/.backup/<timestamp>/pre-uninstall/
  - Use --all to fully remove the installation.
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --no-backup) ENABLE_BACKUP=false; shift ;;
    --all) REMOVE_ALL=true; shift ;;
    --only-instructions) ONLY_INSTRUCTIONS=true; shift ;;
    --only-standards) ONLY_STANDARDS=true; shift ;;
    --only-docs) ONLY_DOCS=true; shift ;;
    --purge-backups) PURGE_BACKUPS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# Validate scope
if [[ "$REMOVE_ALL" == true ]]; then
  if [[ "$ONLY_INSTRUCTIONS" == true || "$ONLY_STANDARDS" == true || "$ONLY_DOCS" == true ]]; then
    echo "--all cannot be combined with --only-* flags" >&2
    exit 1
  fi
fi

echo "🧹 Spec Agent K Uninstall"
[[ "$DRY_RUN" == true ]] && echo "(dry run)"

target_root="$HOME/.agent-os"

if [[ "$REMOVE_ALL" == true ]]; then
  remove_path "$target_root"
  if [[ "$PURGE_BACKUPS" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  ~ Would remove: ${target_root#$HOME/}/.backup"
    else
      rm -rf "$target_root/.backup" 2>/dev/null || true
      echo "  ✓ Removed: ${target_root#$HOME/}/.backup"
    fi
  fi
  echo "Done."
  exit 0
fi

# Scoped removal
if [[ "$ONLY_INSTRUCTIONS" == true ]]; then
  remove_path "$target_root/instructions"
fi
if [[ "$ONLY_STANDARDS" == true ]]; then
  remove_path "$target_root/standards"
fi
if [[ "$ONLY_DOCS" == true ]]; then
  remove_path "$target_root/docs"
fi

if [[ "$ONLY_INSTRUCTIONS" == false && "$ONLY_STANDARDS" == false && "$ONLY_DOCS" == false ]]; then
  # Default: remove the managed subfolders
  remove_path "$target_root/instructions"
  remove_path "$target_root/standards"
  remove_path "$target_root/docs"
fi

echo
if [[ "$DRY_RUN" == true ]]; then
  echo "🧪 Dry run complete (no changes made)."
else
  if [[ "$ENABLE_BACKUP" == true ]]; then
    echo "✅ Uninstall complete. Backups (if any) at ${BACKUP_ROOT#$HOME/}"
  else
    echo "✅ Uninstall complete."
  fi
fi
