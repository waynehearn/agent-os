#!/bin/bash

# Spec Agent Kibo Claude Code Setup Script (local-only)
# Copies commands and agents from this repo into ~/.claude. No network calls.

set -euo pipefail

echo "🚀 Spec Agent Kibo Claude Code Setup (local)"
echo "========================================="
echo

# Check if Spec Agent Kibo base installation is present
if [ ! -d "$HOME/.agent-os/instructions" ] || [ ! -d "$HOME/.agent-os/standards" ]; then
    echo "⚠️  Spec Agent Kibo base installation not found!"
    echo "   Run: bash ./setup.sh (from the repo root)"
    exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        cp -f "$src" "$dest"
        echo "  ✓ ${cmd}.md"
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
        cp -f "$src" "$dest"
        echo "  ✓ ${agent}.md"
    else
        echo "  ⚠️  Missing local file: $src (skipped)"
    fi
done

echo
echo "✅ Spec Agent Kibo Claude Code installation complete!"
echo
echo "📍 Files installed to:"
echo "   ~/.claude/commands/        - Claude Code commands"
echo "   ~/.claude/agents/          - Claude Code specialized subagents"
echo
echo "Next steps:"
echo "  /plan-product       (new product)"
echo "  /analyze-product    (existing codebase)"
echo "  /create-spec        (start a new feature)"
echo "  /execute-task       (implement a single task)"
echo
