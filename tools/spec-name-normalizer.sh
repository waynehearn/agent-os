#!/bin/bash
# Normalizes a spec name from stdin.
# For now, it just converts to lowercase and replaces spaces with hyphens.

read input_name
echo "$input_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
