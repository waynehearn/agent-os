#!/bin/bash

# Spec Agent K Setup Script (local-only)
# Copies files from this repository into your home folder. No network calls.

set -euo pipefail

# Initialize flags
OVERWRITE_INSTRUCTIONS=false
OVERWRITE_STANDARDS=false
DRY_RUN=false
ENABLE_BACKUP=true
DO_UPGRADE=false

TIMESTAMP="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_ROOT="$HOME/.agent-os/.backup/$TIMESTAMP"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Cross-platform sha256
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

ensure_backup_dir() {
    [[ "$ENABLE_BACKUP" == true ]] || return 0
    mkdir -p "$BACKUP_ROOT" >/dev/null 2>&1 || true
}

backup_file() {
    local dest="$1" base="$HOME/.agent-os" rel backup_path
    [[ "$ENABLE_BACKUP" == true ]] || return 0
    ensure_backup_dir
    if [[ -n "$dest" && -f "$dest" ]]; then
        if [[ "$dest" == $base/* ]]; then
            rel="${dest#$base/}"
            backup_path="$BACKUP_ROOT/$rel"
        else
            # Fallback: mirror absolute path under backup dir
            rel="${dest#/}"
            backup_path="$BACKUP_ROOT/$rel"
        fi
        mkdir -p "$(dirname "$backup_path")"
        cp -f "$dest" "$backup_path" 2>/dev/null || true
    fi
}

copy_if_changed() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [[ -f "$dest" ]]; then
        local h1 h2
        h1="$(sha256_file "$src" 2>/dev/null || echo x)"
        h2="$(sha256_file "$dest" 2>/dev/null || echo y)"
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

sync_dir_changed_only() {
    local src_dir="$1" dest_dir="$2"
    local found=false
    if [[ ! -d "$src_dir" ]]; then
        return 0
    fi
    # Iterate files
    while IFS= read -r -d '' f; do
        found=true
        local rel="${f#$src_dir/}"
        copy_if_changed "$f" "$dest_dir/$rel"
    done < <(find "$src_dir" -type f -print0)
    if [[ "$found" == false ]]; then
        echo "  (no files)"
    fi
}

write_manifest_json() {
    local root="$1"
    local manifest="$root/manifest.json"
    if need_cmd jq; then
        mkdir -p "$root"
        echo '{"files":{},"generatedAt":"'"$TIMESTAMP"'"}' > "$manifest"
        while IFS= read -r -d '' f; do
            rel="${f#$root/}"
            [[ "$rel" == "manifest.json" ]] && continue
            h="$(sha256_file "$f")"
            tmp=$(mktemp)
            jq --arg k "$rel" --arg h "$h" '.files[$k] = { sha256: $h }' "$manifest" > "$tmp" && mv "$tmp" "$manifest"
        done < <(find "$root" -type f -print0)
        echo "  ✓ Manifest updated: ${manifest#$HOME/}"
    else
        echo "  • jq not found; manifest skipped"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --overwrite-instructions)
            OVERWRITE_INSTRUCTIONS=true; shift ;;
        --overwrite-standards)
            OVERWRITE_STANDARDS=true; shift ;;
        --upgrade)
            DO_UPGRADE=true
            OVERWRITE_INSTRUCTIONS=true
            OVERWRITE_STANDARDS=true
            shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        --no-backup)
            ENABLE_BACKUP=false; shift ;;
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
        --upgrade                 Upgrade all installed files (change-only), backup changed files
        --dry-run                 Show what would change without writing files
        --no-backup               Do not write backups when overwriting
        --overwrite-instructions  Force overwrite instructions (legacy behavior)
        --overwrite-standards     Force overwrite standards (legacy behavior)
        -h, --help                Show this help message

This script installs or upgrades Spec Agent K locally by copying files from
this repo to ~/.agent-os. Intended to run via Git Bash, WSL, or any POSIX shell.
EOF
            exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1 ;;
    esac
done

echo "🚀 Spec Agent K Setup (local)"
echo "==============================="
echo

# Create directories
echo "📁 Creating directories..."
mkdir -p "$HOME/.agent-os/standards"
mkdir -p "$HOME/.agent-os/standards/code-style"
mkdir -p "$HOME/.agent-os/instructions/core"
mkdir -p "$HOME/.agent-os/instructions/meta"
mkdir -p "$HOME/.agent-os/docs"

# Copy standards
echo
echo "📥 Installing standards to ~/.agent-os/standards/"
if [[ -d "$script_dir/standards" ]]; then
    if [[ "$DO_UPGRADE" == true ]]; then
        sync_dir_changed_only "$script_dir/standards" "$HOME/.agent-os/standards"
    else
        if [[ "$OVERWRITE_STANDARDS" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo "  ~ Would overwrite all files under standards/"
            else
                cp -Rf "$script_dir/standards/." "$HOME/.agent-os/standards/"
                echo "  ✓ Standards copied (overwritten)"
            fi
        else
            if [[ "$DRY_RUN" == true ]]; then
                echo "  • Would preserve existing files (no overwrite)"
            else
                cp -Rn "$script_dir/standards/." "$HOME/.agent-os/standards/" || true
                echo "  ✓ Standards copied (existing files preserved)"
            fi
        fi
    fi
else
    echo "  ⚠️  No local 'standards/' folder found in repo; skipping"
fi

# Copy instructions
echo
echo "📥 Installing instructions to ~/.agent-os/instructions/"
if [[ -d "$script_dir/instructions" ]]; then
    if [[ "$DO_UPGRADE" == true ]]; then
        sync_dir_changed_only "$script_dir/instructions/core" "$HOME/.agent-os/instructions/core"
        sync_dir_changed_only "$script_dir/instructions/meta" "$HOME/.agent-os/instructions/meta"
    else
        if [[ "$OVERWRITE_INSTRUCTIONS" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                echo "  ~ Would overwrite all instruction files"
            else
                cp -Rf "$script_dir/instructions/core/." "$HOME/.agent-os/instructions/core/" 2>/dev/null || true
                cp -Rf "$script_dir/instructions/meta/." "$HOME/.agent-os/instructions/meta/" 2>/dev/null || true
                echo "  ✓ Instructions copied (overwritten)"
            fi
        else
            if [[ "$DRY_RUN" == true ]]; then
                echo "  • Would preserve existing instruction files (no overwrite)"
            else
                cp -Rn "$script_dir/instructions/core/." "$HOME/.agent-os/instructions/core/" 2>/dev/null || true
                cp -Rn "$script_dir/instructions/meta/." "$HOME/.agent-os/instructions/meta/" 2>/dev/null || true
                echo "  ✓ Instructions copied (existing files preserved)"
            fi
        fi
    fi
else
    echo "  ⚠️  No local 'instructions/' folder found in repo; skipping"
fi

# Copy docs
echo
echo "📥 Installing docs to ~/.agent-os/docs/"
if [[ -d "$script_dir/docs" ]]; then
    if [[ "$DO_UPGRADE" == true ]]; then
        sync_dir_changed_only "$script_dir/docs" "$HOME/.agent-os/docs"
    else
        if [[ "$DRY_RUN" == true ]]; then
            echo "  • Would copy docs (preserve existing)"
        else
            cp -Rn "$script_dir/docs/." "$HOME/.agent-os/docs/" || true
            echo "  ✓ Docs copied (existing files preserved)"
        fi
    fi
else
    echo "  ⚠️  No local 'docs/' folder found in repo; skipping"
fi

# Write manifest when upgrading
if [[ "$DRY_RUN" == false ]]; then
    echo
    echo "🧾 Manifest"
    write_manifest_json "$HOME/.agent-os"
fi

echo
echo "✅ Spec Agent K base installation complete!"
echo
echo "📁 Files installed to:"
echo "   ~/.agent-os/standards/     - Your development standards"
echo "   ~/.agent-os/instructions/  - Spec Agent K instructions"
echo "   ~/.agent-os/docs/          - Spec Agent K documentation"
echo
if [[ "$DO_UPGRADE" == true ]]; then
    echo "🔄 Upgrade mode was used. Changed files were backed up to ~/.agent-os/.backup/$TIMESTAMP"
elif [[ "$OVERWRITE_INSTRUCTIONS" == false && "$OVERWRITE_STANDARDS" == false ]]; then
    echo "💡 Existing files were preserved. Use --upgrade or overwrite flags to replace."
fi
echo
echo "Next steps:"
echo
echo "1. Customize your coding standards in ~/.agent-os/standards/"
echo
echo "2. Optional editor integrations (run from this repo root):"
echo "   - Claude Code: bash ./setup-claude-code.sh --upgrade"
echo "   - Cursor:      bash ./setup-cursor.sh --upgrade (run inside a project repo)"
echo

