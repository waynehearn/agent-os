#!/bin/bash

# Spec Agent K Claude Code Setup Script (local-only)
# Copies commands and agents from this repo into ~/.claude. No network calls.

set -euo pipefail

DRY_RUN=false
ENABLE_BACKUP=true
DO_UPGRADE=false
TIMESTAMP="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_ROOT="$HOME/.claude/.backup/$TIMESTAMP"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_backup_dir() {
    [[ "$ENABLE_BACKUP" == true ]] || return 0
    mkdir -p "$BACKUP_ROOT" >/dev/null 2>&1 || true
}

backup_file() {
    local dest="$1" base="$HOME/.claude" rel backup_path
    [[ "$ENABLE_BACKUP" == true ]] || return 0
    ensure_backup_dir
    if [[ -n "$dest" && -f "$dest" ]]; then
        if [[ "$dest" == $base/* ]]; then
            rel="${dest#$base/}"
            backup_path="$BACKUP_ROOT/$rel"
        else
            rel="${dest#/}"
            backup_path="$BACKUP_ROOT/$rel"
        fi
        mkdir -p "$(dirname "$backup_path")"
        cp -f "$dest" "$backup_path" 2>/dev/null || true
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
        echo "nohash"
    fi
}

copy_if_changed() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [[ -f "$dest" ]]; then
        local h1 h2
        h1="$(sha256_file "$src")"; h2="$(sha256_file "$dest")"
        if [[ "$h1" == "$h2" ]]; then
            echo "  • Unchanged: ${dest#$HOME/}"
            return 0
        fi
        if [[ "$DRY_RUN" == true ]]; then
            echo "  ~ Would update: ${dest#$HOME/}"
            return 0
        fi
        backup_file "$dest"
        cp -f "$src" "$dest"
        echo "  ✓ Updated: ${dest#$HOME/}"
    else
        if [[ "$DRY_RUN" == true ]]; then
            echo "  + Would install: ${dest#$HOME/}"
            return 0
        fi
        cp -f "$src" "$dest"
        echo "  ✓ Installed: ${dest#$HOME/}"
    fi
}

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --upgrade) DO_UPGRADE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --no-backup) ENABLE_BACKUP=false; shift ;;
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
    --upgrade    Upgrade commands and agents (change-only, with backups)
    --dry-run    Show what would change without writing
    --no-backup  Do not backup changed files
    -h          Help
EOF
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

echo "🚀 Spec Agent K Claude Code Setup (local)"
echo "========================================="
echo

# Check if Spec Agent K base installation is present (optional)
if [ ! -d "$HOME/.agent-os/instructions" ] || [ ! -d "$HOME/.agent-os/standards" ]; then
        echo "⚠️  Spec Agent K base installation not found!"
        echo "   Run: bash ./setup.sh (from the repo root)"
fi

# Create directories
echo "📁 Creating directories..."
mkdir -p "$HOME/.claude/commands"
mkdir -p "$HOME/.claude/agents"

# Copy command files for Claude Code
echo
echo "📥 Installing Claude Code command files to ~/.claude/commands/"
for cmd in plan-product create-spec execute-tasks analyze-product; do
    src="$script_dir/commands/${cmd}.md"
    dest="$HOME/.claude/commands/${cmd}.md"
    if [[ -f "$src" ]]; then
        copy_if_changed "$src" "$dest"
    else
        echo "  ⚠️  Missing local file: $src (skipped)"
    fi
done

# Copy Claude Code agents
echo
echo "📥 Installing Claude Code subagents to ~/.claude/agents/"
agents=("test-runner" "context-fetcher" "git-workflow" "file-creator" "date-checker")
for agent in "${agents[@]}"; do
    src="$script_dir/claude-code/agents/${agent}.md"
    dest="$HOME/.claude/agents/${agent}.md"
    if [[ -f "$src" ]]; then
        copy_if_changed "$src" "$dest"
    else
        echo "  ⚠️  Missing local file: $src (skipped)"
    fi
done

echo
if [[ "$DRY_RUN" == true ]]; then
    echo "🧪 Dry run complete (no changes written)"
else
    echo "✅ Spec Agent K Claude Code installation complete!"
    if [[ "$DO_UPGRADE" == true ]]; then
        echo "🔄 Upgrade mode used. Backups (if any) in ~/.claude/.backup/$TIMESTAMP"
    fi
fi
echo
echo "📍 Files managed:"
echo "   ~/.claude/commands/        - Claude Code commands"
echo "   ~/.claude/agents/          - Claude Code specialized subagents"
echo
echo "Next steps:"
echo "  /plan-product       (new product)"
echo "  /analyze-product    (existing codebase)"
echo "  /create-spec        (start a new feature)"
echo "  /execute-task       (implement a single task)"
echo
