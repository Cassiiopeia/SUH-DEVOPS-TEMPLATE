#!/bin/bash
# version-sync.sh - version.json의 버전을 HTML 파일에 동기화

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/version.json"
HTML_FILE="$SCRIPT_DIR/secrets-converter.html"

# version.json에서 버전 추출
VERSION=$(grep -o '"version": *"[^"]*"' "$VERSION_FILE" | cut -d'"' -f4)

if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from version.json"
    exit 1
fi

echo "Syncing version $VERSION to HTML file..."

# HTML 파일에서 버전 업데이트 (meta tag와 footer)
if [ -f "$HTML_FILE" ]; then
    # macOS와 Linux 호환 sed 명령
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/content=\"[0-9]*\.[0-9]*\.[0-9]*\"/content=\"$VERSION\"/g" "$HTML_FILE"
        sed -i '' "s/v[0-9]*\.[0-9]*\.[0-9]*/v$VERSION/g" "$HTML_FILE"
    else
        sed -i "s/content=\"[0-9]*\.[0-9]*\.[0-9]*\"/content=\"$VERSION\"/g" "$HTML_FILE"
        sed -i "s/v[0-9]*\.[0-9]*\.[0-9]*/v$VERSION/g" "$HTML_FILE"
    fi
    echo "Successfully updated $HTML_FILE to version $VERSION"
else
    echo "Warning: HTML file not found at $HTML_FILE"
fi
