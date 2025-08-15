#!/bin/bash

# Spec Agent Kibo Setup Script (local-only)
# Copies files from this repository into your home folder. No network calls.

set -euo pipefail

# Initialize flags
OVERWRITE_INSTRUCTIONS=false
OVERWRITE_STANDARDS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
        case $1 in
                --overwrite-instructions)
                        OVERWRITE_INSTRUCTIONS=true
                        shift
                        ;;
                --overwrite-standards)
                        OVERWRITE_STANDARDS=true
                        shift
                        ;;
                -h|--help)
                        cat <<EOF
Usage: $0 [OPTIONS]

Options:
    --overwrite-instructions    Overwrite existing instruction files
    --overwrite-standards       Overwrite existing standards files
    -h, --help                  Show this help message

This script installs Spec Agent Kibo locally by copying files from this repo
to ~/.agent-os. Intended to run via Git Bash, WSL, or any POSIX shell.
EOF
                        exit 0
                        ;;
                *)
                        echo "Unknown option: $1" >&2
                        echo "Use --help for usage information" >&2
                        exit 1
                        ;;
        esac
done

echo "🚀 Spec Agent Kibo Setup (local)"
echo "==============================="
echo

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create directories
echo "📁 Creating directories..."
mkdir -p "$HOME/.agent-os/standards"
mkdir -p "$HOME/.agent-os/standards/code-style"
mkdir -p "$HOME/.agent-os/instructions/core"
mkdir -p "$HOME/.agent-os/instructions/meta"

# Copy standards
echo
echo "📥 Installing standards to ~/.agent-os/standards/"
if [[ -d "$script_dir/standards" ]]; then
    if [[ "$OVERWRITE_STANDARDS" == true ]]; then
        cp -Rf "$script_dir/standards/." "$HOME/.agent-os/standards/"
        echo "  ✓ Standards copied (overwritten)"
    else
        cp -Rn "$script_dir/standards/." "$HOME/.agent-os/standards/" || true
        echo "  ✓ Standards copied (existing files preserved)"
    fi
else
    echo "  ⚠️  No local 'standards/' folder found in repo; skipping"
fi

# Copy instructions
echo
echo "📥 Installing instructions to ~/.agent-os/instructions/"
if [[ -d "$script_dir/instructions" ]]; then
    if [[ "$OVERWRITE_INSTRUCTIONS" == true ]]; then
        cp -Rf "$script_dir/instructions/core/." "$HOME/.agent-os/instructions/core/" 2>/dev/null || true
        cp -Rf "$script_dir/instructions/meta/." "$HOME/.agent-os/instructions/meta/" 2>/dev/null || true
        echo "  ✓ Instructions copied (overwritten)"
    else
        cp -Rn "$script_dir/instructions/core/." "$HOME/.agent-os/instructions/core/" 2>/dev/null || true
        cp -Rn "$script_dir/instructions/meta/." "$HOME/.agent-os/instructions/meta/" 2>/dev/null || true
        echo "  ✓ Instructions copied (existing files preserved)"
    fi
else
    echo "  ⚠️  No local 'instructions/' folder found in repo; skipping"
fi

echo
echo "✅ Spec Agent Kibo base installation complete!"
echo
echo "📁 Files installed to:"
echo "   ~/.agent-os/standards/     - Your development standards"
echo "   ~/.agent-os/instructions/  - Spec Agent Kibo instructions"
echo
if [[ "$OVERWRITE_INSTRUCTIONS" == false && "$OVERWRITE_STANDARDS" == false ]]; then
    echo "💡 Existing files were preserved. Use --overwrite-instructions or --overwrite-standards to replace."
fi
echo
echo "Next steps:"
echo
echo "1. Customize your coding standards in ~/.agent-os/standards/"
echo
echo "2. Optional editor integrations (run from this repo root):"
echo "   - Claude Code: bash ./setup-claude-code.sh"
echo "   - Cursor:      bash ./setup-cursor.sh (run inside a project repo)"
echo

