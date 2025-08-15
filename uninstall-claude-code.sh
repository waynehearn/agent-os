#!/bin/bash

# Spec Agent Kibo Claude Code Uninstall Script (local-only)
# Safely removes files installed under ~/.claude (commands and agents).

set -euo pipefail

DRY_RUN=false
ENABLE_BACKUP=true
REMOVE_ALL=false
ONLY_COMMANDS=false
ONLY_AGENTS=false

TIMESTAMP="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_ROOT="$HOME/.claude/.backup/$TIMESTAMP/pre-uninstall"

ensure_backup_dir() {
  [[ "$ENABLE_BACKUP" == true ]] || return 0
  mkdir -p "$BACKUP_ROOT" >/dev/null 2>&1 || true
}

backup_file() {
  local dest="$1"
  [[ "$ENABLE_BACKUP" == true ]] || return 0
  [[ -f "$dest" ]] || return 0
  ensure_backup_dir
  local rel="${dest#$HOME/.claude/}"
  local out="$BACKUP_ROOT/$rel"
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
        backup_file "$p"; rm -f "$p"
      else
        while IFS= read -r -d '' f; do backup_file "$f"; done < <(find "$p" -type f -print0)
        rm -rf "$p"
      fi
      echo "  ✓ Removed: ${p#$HOME/}"
    fi
  fi
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Safely uninstall Claude Code files from ~/.claude.

Options:
  --dry-run        Show what would be removed without deleting
  --no-backup      Do not back up files before removal
  --all            Remove ~/.claude/commands and ~/.claude/agents
  --only-commands  Remove only ~/.claude/commands
  --only-agents    Remove only ~/.claude/agents
  -h, --help       Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --no-backup) ENABLE_BACKUP=false; shift ;;
    --all) REMOVE_ALL=true; shift ;;
    --only-commands) ONLY_COMMANDS=true; shift ;;
    --only-agents) ONLY_AGENTS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

echo "🧹 Spec Agent Kibo Claude Code Uninstall"
[[ "$DRY_RUN" == true ]] && echo "(dry run)"

if [[ "$REMOVE_ALL" == true ]]; then
  remove_path "$HOME/.claude/commands"
  remove_path "$HOME/.claude/agents"
  exit 0
fi

if [[ "$ONLY_COMMANDS" == true ]]; then
  remove_path "$HOME/.claude/commands"
fi
if [[ "$ONLY_AGENTS" == true ]]; then
  remove_path "$HOME/.claude/agents"
fi

if [[ "$ONLY_COMMANDS" == false && "$ONLY_AGENTS" == false && "$REMOVE_ALL" == false ]]; then
  # Default: remove both managed folders
  remove_path "$HOME/.claude/commands"
  remove_path "$HOME/.claude/agents"
fi

echo
if [[ "$DRY_RUN" == true ]]; then
  echo "🧪 Dry run complete (no changes made)."
else
  if [[ "$ENABLE_BACKUP" == true ]] && [[ -d "$BACKUP_ROOT" ]]; then
    echo "✅ Uninstall complete. Backups (if any) at ${BACKUP_ROOT#$HOME/}"
  else
    echo "✅ Uninstall complete."
  fi
fi
