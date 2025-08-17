#!/usr/bin/env bash
# Simple mock discover-product-context.sh script for testing
# Simplified implementation to work with analyze-product.sh

set -euo pipefail

# Color output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[discover-context]${NC} $*"; }
success() { echo -e "${GREEN}[discover-context][SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[discover-context][WARNING]${NC} $*"; }

# Parse arguments
PROJECT_ROOT="${1:-$(pwd)}"
WRITE=false
WRITE_IF_MISSING=false
INIT_PRODUCT=false

# If first arg doesn't start with --, it's the project root
if [[ "$PROJECT_ROOT" == --* ]]; then
  PROJECT_ROOT="$(pwd)"
  # Put the argument back to be processed
  set -- "$PROJECT_ROOT" "$@"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      echo "Usage: $0 [project_root] [--write | --write-if-missing] [--init-product]"
      exit 0
      ;;
    --write)
      WRITE=true
      shift
      ;;
    --write-if-missing)
      WRITE_IF_MISSING=true
      shift
      ;;
    --init-product)
      INIT_PRODUCT=true
      shift
      ;;
    *)
      if [[ "$1" != "$PROJECT_ROOT" ]]; then
        PROJECT_ROOT="$1"
      fi
      shift
      ;;
  esac
done

# Make sure target directory exists
CONTEXT_DIR="$PROJECT_ROOT/.agent-os/product/context"
CONTEXT_FILE="$CONTEXT_DIR/context.json"

# Create directory if needed
mkdir -p "$CONTEXT_DIR"

# Check if file exists and if we should write
if [[ -f "$CONTEXT_FILE" && "$WRITE" != "true" && "$WRITE_IF_MISSING" != "true" ]]; then
  log "Using existing context file: $CONTEXT_FILE"
  cat "$CONTEXT_FILE"
  exit 0
fi

if [[ -f "$CONTEXT_FILE" && "$WRITE_IF_MISSING" == "true" ]]; then
  log "Context file already exists, skipping write: $CONTEXT_FILE"
  cat "$CONTEXT_FILE"
  exit 0
fi

# Create a sample context file if it doesn't exist or --write was specified
if [[ ! -f "$CONTEXT_FILE" || "$WRITE" == "true" ]]; then
  log "Generating context file: $CONTEXT_FILE"
  
  # Create sample context
  cat > "$CONTEXT_FILE" << EOF
{
  "project": {
    "name": "Agent OS",
    "description": "A token-efficient hybrid approach for agent operations",
    "techStack": ["Bash", "Markdown", "JSON"],
    "features": [
      "Token-efficient operation routing",
      "Context management and caching",
      "Section-level content hashing",
      "Hybrid AI and script processing"
    ]
  },
  "repository": {
    "type": "git",
    "url": "github.com/waynehearn/agent-os",
    "mainBranch": "main",
    "currentBranch": "jira"
  },
  "discovery": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "sources": ["README.md", "docs/architecture.md", "package.json"],
    "sourcesFound": 3,
    "sourcesUsed": 3,
    "confidence": "high"
  }
}
EOF

  success "Context file generated successfully"
fi

# Output the context file
cat "$CONTEXT_FILE"

# Handle product initialization if requested
if [[ "$INIT_PRODUCT" == "true" ]]; then
  PRODUCT_DIR="$PROJECT_ROOT/.agent-os/product"
  
  log "Initializing minimal product docs in $PRODUCT_DIR"
  
  # Create minimal product docs
  mkdir -p "$PRODUCT_DIR"
  
  if [[ ! -f "$PRODUCT_DIR/mission.md" ]]; then
    cat > "$PRODUCT_DIR/mission.md" << EOF
# Mission Statement

*Auto-generated from code analysis. Please edit to refine.*

## Purpose

Based on code analysis, this project appears to be a software application that provides agent operations with token efficiency.

*TODO: Refine the mission statement with specific business goals and purpose.*
EOF
    success "Created $PRODUCT_DIR/mission.md"
  fi
  
  if [[ ! -f "$PRODUCT_DIR/tech-stack.md" ]]; then
    cat > "$PRODUCT_DIR/tech-stack.md" << EOF
# Technology Stack

## Primary Technologies

- Bash
- Markdown
- JSON

## Frameworks and Libraries

*TODO: Add framework and library details*
EOF
    success "Created $PRODUCT_DIR/tech-stack.md"
  fi
  
  success "Product initialization completed"
fi

exit 0
