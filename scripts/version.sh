#!/bin/bash
# scripts/version.sh
set -euo pipefail

TAG_NAME=${GITHUB_REF#refs/tags/}
VERSION_NAME=${TAG_NAME#v}
VERSION_CODE=$(git rev-list --count HEAD)

echo "Version Name: $VERSION_NAME"
echo "Version Code: $VERSION_CODE"

echo "VERSION_NAME=$VERSION_NAME" >> "$GITHUB_ENV"
echo "VERSION_CODE=$VERSION_CODE" >> "$GITHUB_ENV"
