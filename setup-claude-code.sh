 #!/bin/bash

# Spec Agent Kibo Claude Code Setup Script
# This script installs Spec Agent Kibo commands for Claude Code

set -e  # Exit on error

echo "🚀 Spec Agent Kibo Claude Code Setup"
echo "============================="
echo ""

# Check if Spec Agent Kibo base installation is present
if [ ! -d "$HOME/.agent-os/instructions" ] || [ ! -d "$HOME/.agent-os/standards" ]; then
    echo "⚠️  Spec Agent Kibo base installation not found!"
    echo ""
    echo "Please install the Spec Agent Kibo base installation first:"
    echo ""
    echo "Option 1 - Automatic installation:"
    echo "  curl -sSL https://raw.githubusercontent.com/buildermethods/agent-os/main/setup.sh | bash"
    echo ""
    echo "Option 2 - Manual installation:"
    echo "  Follow instructions at https://buildermethods.com/agent-os"
    echo ""
    exit 1
fi

# Base URL for raw GitHub content
BASE_URL="https://raw.githubusercontent.com/buildermethods/agent-os/main"

# Create directories
echo "📁 Creating directories..."
mkdir -p "$HOME/.claude/commands"
mkdir -p "$HOME/.claude/agents"

# Download command files for Claude Code
echo ""
echo "📥 Downloading Claude Code command files to ~/.claude/commands/"

# Commands
for cmd in plan-product create-spec execute-tasks analyze-product; do
    if [ -f "$HOME/.claude/commands/${cmd}.md" ]; then
        echo "  ⚠️  ~/.claude/commands/${cmd}.md already exists - skipping"
    else
        curl -s -o "$HOME/.claude/commands/${cmd}.md" "${BASE_URL}/commands/${cmd}.md"
        echo "  ✓ ~/.claude/commands/${cmd}.md"
    fi
done

# Download Claude Code agents
echo ""
echo "📥 Downloading Claude Code subagents to ~/.claude/agents/"

# List of agent files to download
agents=("test-runner" "context-fetcher" "git-workflow" "file-creator" "date-checker")

for agent in "${agents[@]}"; do
    if [ -f "$HOME/.claude/agents/${agent}.md" ]; then
        echo "  ⚠️  ~/.claude/agents/${agent}.md already exists - skipping"
    else
        curl -s -o "$HOME/.claude/agents/${agent}.md" "${BASE_URL}/claude-code/agents/${agent}.md"
        echo "  ✓ ~/.claude/agents/${agent}.md"
    fi
done

echo ""
echo "✅ Spec Agent Kibo Claude Code installation complete!"
echo ""
echo "📍 Files installed to:"
echo "   ~/.claude/commands/        - Claude Code commands"
echo "   ~/.claude/agents/          - Claude Code specialized subagents"
echo ""
echo "Next steps:"
echo ""
echo "Initiate Spec Agent Kibo in a new product's codebase with:"
echo "  /plan-product"
echo ""
echo "Initiate Spec Agent Kibo in an existing product's codebase with:"
echo "  /analyze-product"
echo ""
echo "Initiate a new feature with:"
echo "  /create-spec (or simply ask 'what's next?')"
echo ""
echo "Build and ship code with:"
echo "  /execute-task"
echo ""
echo "Learn more at https://buildermethods.com/agent-os"
echo ""
