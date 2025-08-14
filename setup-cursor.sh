#!/bin/bash

# Spec Agent Kibo Cursor Setup Script
# This script installs Spec Agent Kibo commands for Cursor in the current project

set -e  # Exit on error

echo "🚀 Spec Agent Kibo Cursor Setup"
echo "========================"
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

echo ""
echo "📁 Creating .cursor/rules directory..."
mkdir -p .cursor/rules

# Base URL for raw GitHub content
BASE_URL="https://raw.githubusercontent.com/buildermethods/agent-os/main"

echo ""
echo "📥 Downloading and setting up Cursor command files..."

# Function to process a command file
process_command_file() {
    local cmd="$1"
    local temp_file="/tmp/${cmd}.md"
    local target_file=".cursor/rules/${cmd}.mdc"

    # Download the file
    if curl -s -o "$temp_file" "${BASE_URL}/commands/${cmd}.md"; then
        # Create the front-matter and append original content
        cat > "$target_file" << EOF
---
alwaysApply: false
---

EOF

        # Append the original content
        cat "$temp_file" >> "$target_file"

        # Clean up temp file
        rm "$temp_file"

        echo "  ✓ .cursor/rules/${cmd}.mdc"
    else
        echo "  ❌ Failed to download ${cmd}.md"
        return 1
    fi
}

# Process each command file
for cmd in plan-product create-spec execute-tasks analyze-product; do
    process_command_file "$cmd"
done

echo ""
echo "✅ Spec Agent Kibo Cursor setup complete!"
echo ""
echo "📍 Files installed to:"
echo "   .cursor/rules/             - Cursor command rules"
echo ""
echo "Next steps:"
echo ""
echo "Use Spec Agent Kibo commands in Cursor with @ prefix:"
echo "  @plan-product    - Initiate Spec Agent Kibo in a new product's codebase"
echo "  @analyze-product - Initiate Spec Agent Kibo in an existing product's codebase"
echo "  @create-spec     - Initiate a new feature (or simply ask 'what's next?')"
echo "  @execute-tasks    - Build and ship code"
echo ""
echo "Learn more at https://buildermethods.com/agent-os"
echo ""
