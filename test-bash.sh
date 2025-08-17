#!/usr/bin/env bash
echo "Running in bash version: $BASH_VERSION"
echo "Current shell: $SHELL"
echo "Testing context gatherer:"
./tools/context-gatherer.sh --help
