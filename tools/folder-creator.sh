#!/usr/bin/env bash
# folder-creator.sh - A script alternative to the file-creator subagent for creating directories
# Usage: ./folder-creator.sh <date> <spec_name>

DATE="$1"
SPEC_NAME="$2"

if [ -z "$DATE" ] || [ -z "$SPEC_NAME" ]; then
    echo "Usage: $0 <date> <spec_name>"
    echo "Example: $0 2025-08-17 jira-integration"
    exit 1
fi

# Create the folder structure
FOLDER_PATH=".agent-os/specs/$DATE-$SPEC_NAME"
mkdir -p "$FOLDER_PATH"
mkdir -p "$FOLDER_PATH/context"

echo "Created spec folder: $FOLDER_PATH"
echo "Folder path: $FOLDER_PATH"
