#!/bin/bash

# Spec Agent K – Verify local installation
# Checks that key files exist under ~/.agent-os and optional editor setups.

set -uo pipefail

CHECK_CLAUDE=false
CHECK_CURSOR=false

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [--check-claude] [--check-cursor]

Verifies Spec Agent K installation by checking for expected files.

Options:
  --check-claude    Also verify ~/.claude commands and agents
  --check-cursor    Also verify ./.cursor/rules (run inside a project repo)
  -h, --help        Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-claude) CHECK_CLAUDE=true; shift ;;
    --check-cursor) CHECK_CURSOR=true; shift ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
  esac
done

fail_count=0

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "  ✓ $path"
  else
    echo "  ✗ $path (missing)"
    fail_count=$((fail_count+1))
  fi
}

check_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    echo "  ✓ $path/"
  else
    echo "  ✗ $path/ (missing)"
    fail_count=$((fail_count+1))
  fi
}

echo "🔎 Verifying Spec Agent K installation"
echo "========================================"

echo "\nHome directories"
check_dir "$HOME/.agent-os"
check_dir "$HOME/.agent-os/standards"
check_dir "$HOME/.agent-os/standards/code-style"
check_dir "$HOME/.agent-os/instructions"
check_dir "$HOME/.agent-os/instructions/core"
check_dir "$HOME/.agent-os/instructions/meta"

echo "\nStandards files"
check_file "$HOME/.agent-os/standards/tech-stack.md"
check_file "$HOME/.agent-os/standards/code-style.md"
check_file "$HOME/.agent-os/standards/best-practices.md"
check_file "$HOME/.agent-os/standards/code-style/css-style.md"
check_file "$HOME/.agent-os/standards/code-style/html-style.md"
check_file "$HOME/.agent-os/standards/code-style/javascript-style.md"

echo "\nInstruction files (core)"
check_file "$HOME/.agent-os/instructions/core/plan-product.md"
check_file "$HOME/.agent-os/instructions/core/create-spec.md"
check_file "$HOME/.agent-os/instructions/core/execute-tasks.md"
check_file "$HOME/.agent-os/instructions/core/execute-task.md"
check_file "$HOME/.agent-os/instructions/core/analyze-product.md"

echo "\nInstruction files (meta)"
check_file "$HOME/.agent-os/instructions/meta/pre-flight.md"

# Tools directory and PATH
echo "\nTools"
check_dir "$HOME/.agent-os/tools"
if command -v section-hash.sh >/dev/null 2>&1; then
  echo "  ✓ section-hash.sh found on PATH"
else
  echo "  ✗ section-hash.sh not found on PATH (ensure ~/.agent-os/tools is in PATH)"
fi

if [[ "$CHECK_CLAUDE" == true ]]; then
  echo "\nClaude Code (optional)"
  check_dir "$HOME/.claude/commands"
  check_dir "$HOME/.claude/agents"
  for cmd in plan-product create-spec execute-tasks analyze-product; do
    check_file "$HOME/.claude/commands/${cmd}.md"
  done
  for agent in test-runner context-fetcher git-workflow file-creator date-checker; do
    check_file "$HOME/.claude/agents/${agent}.md"
  done
fi

if [[ "$CHECK_CURSOR" == true ]]; then
  echo "\nCursor (optional; current directory)"
  check_dir ".cursor"
  check_dir ".cursor/rules"
  for cmd in plan-product create-spec execute-tasks analyze-product; do
    check_file ".cursor/rules/${cmd}.mdc"
  done
fi

echo
if [[ $fail_count -eq 0 ]]; then
  echo "✅ Installation verification passed"
  exit 0
else
  echo "❌ Verification failed: $fail_count missing item(s)"
  exit 1
fi
