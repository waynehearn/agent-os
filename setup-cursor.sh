#!/bin/bash

# Spec Agent Kibo Cursor Setup Script (local-only)
# Generates .cursor/rules/*.mdc from local command files. No network calls.

set -euo pipefail

DRY_RUN=false
ENABLE_BACKUP=true
TIMESTAMP="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_ROOT=".cursor/.backup/$TIMESTAMP"

echo "🚀 Spec Agent Kibo Cursor Setup (local)"
echo "====================================="
echo

# Check if Spec Agent Kibo base installation is present
if [ ! -d "$HOME/.agent-os/instructions" ] || [ ! -d "$HOME/.agent-os/standards" ]; then
        echo "⚠️  Spec Agent Kibo base installation not found!"
        echo "   Run: bash ./setup.sh (from the repo root)"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --no-backup) ENABLE_BACKUP=false; shift ;;
        -h|--help)
            cat <<EOF
Usage: $0 [--dry-run] [--no-backup]

Regenerates .cursor/rules/*.mdc from commands/*.md
EOF
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

echo
echo "📁 Creating .cursor/rules directory..."
mkdir -p .cursor/rules

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sha256_str() { printf "%s" "$1" | {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}';
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}';
    elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 -r | awk '{print $1}';
    else echo nohash; fi; }
}

backup_file() {
    local dest="$1" rel backup_path
    [[ "$ENABLE_BACKUP" == true ]] || return 0
    if [[ -f "$dest" ]]; then
        rel="${dest#.cursor/}"
        backup_path="$BACKUP_ROOT/$rel"
        mkdir -p "$(dirname "$backup_path")"
        cp -f "$dest" "$backup_path" 2>/dev/null || true
    fi
}

echo
echo "📥 Setting up Cursor command files..."

process_command_file() {
    local cmd="$1"
    local src="$script_dir/commands/${cmd}.md"
    local target_file=".cursor/rules/${cmd}.mdc"
    if [[ -f "$src" ]]; then
        local header_content="---
alwaysApply: false
---

"
        local new_content
        new_content="${header_content}$(cat "$src")"
        local new_hash existing_hash
        new_hash="$(sha256_str "$new_content")"
        if [[ -f "$target_file" ]]; then
            existing_hash="$(sha256_str "$(cat "$target_file")")"
            if [[ "$new_hash" == "$existing_hash" ]]; then
                echo "  • Unchanged: $target_file"
                return 0
            fi
            if [[ "$DRY_RUN" == true ]]; then
                echo "  ~ Would update: $target_file"
                return 0
            fi
            backup_file "$target_file"
        else
            if [[ "$DRY_RUN" == true ]]; then
                echo "  + Would create: $target_file"
                return 0
            fi
        fi
        printf "%s" "$new_content" > "$target_file"
        echo "  ✓ ${target_file}"
    else
        echo "  ⚠️  Missing local file: $src (skipped)"
    fi
}

for cmd in plan-product create-spec execute-tasks analyze-product; do
    process_command_file "$cmd"
done

echo
if [[ "$DRY_RUN" == true ]]; then
    echo "🧪 Dry run complete (no changes written)"
else
    echo "✅ Spec Agent Kibo Cursor setup complete!"
fi
echo
echo "📍 Files installed to:"
echo "   .cursor/rules/             - Cursor command rules"
echo
echo "Next steps:"
echo "Use Spec Agent Kibo commands in Cursor with @ prefix:"
echo "  @plan-product     - Initiate Spec Agent Kibo in a new product's codebase"
echo "  @analyze-product  - Initiate Spec Agent Kibo in an existing product's codebase"
echo "  @create-spec      - Initiate a new feature (or simply ask 'what's next?')"
echo "  @execute-tasks     - Build and ship code"
echo
