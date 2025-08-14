#!/bin/bash

# Spec Agent Kibo Cursor Setup Script (local-only)
# Generates .cursor/rules/*.mdc from local command files. No network calls.

set -euo pipefail

echo "🚀 Spec Agent Kibo Cursor Setup (local)"
echo "====================================="
echo

# Check if Spec Agent Kibo base installation is present
if [ ! -d "$HOME/.agent-os/instructions" ] || [ ! -d "$HOME/.agent-os/standards" ]; then
    echo "⚠️  Spec Agent Kibo base installation not found!"
    echo "   Run: bash ./setup.sh (from the repo root)"
    exit 1
fi

echo
echo "📁 Creating .cursor/rules directory..."
mkdir -p .cursor/rules

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo "📥 Setting up Cursor command files..."

process_command_file() {
    local cmd="$1"
    local src="$script_dir/commands/${cmd}.md"
    local target_file=".cursor/rules/${cmd}.mdc"

    if [[ -f "$src" ]]; then
        cat > "$target_file" << EOF
---
alwaysApply: false
---

EOF
        cat "$src" >> "$target_file"
        echo "  ✓ .cursor/rules/${cmd}.mdc"
    else
        echo "  ⚠️  Missing local file: $src (skipped)"
    fi
}

for cmd in plan-product create-spec execute-tasks analyze-product; do
    process_command_file "$cmd"
done

echo
echo "✅ Spec Agent Kibo Cursor setup complete!"
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
