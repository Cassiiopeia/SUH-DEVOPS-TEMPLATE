#!/bin/bash
# ============================================
# version.json → firebase-wizard.html 동기화 스크립트
# 사용법: ./version-sync.sh
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/version.json"
INDEX_FILE="$SCRIPT_DIR/firebase-wizard.html"

if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ version.json 파일을 찾을 수 없습니다: $VERSION_FILE"
    exit 1
fi

if [ ! -f "$INDEX_FILE" ]; then
    echo "❌ firebase-wizard.html 파일을 찾을 수 없습니다: $INDEX_FILE"
    exit 1
fi

CURRENT_VERSION=$(grep '"version"' "$VERSION_FILE" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
echo "📦 동기화할 버전: v$CURRENT_VERSION"

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then
    echo "❌ Python을 찾을 수 없습니다."
    exit 1
fi

$PYTHON - "$VERSION_FILE" "$INDEX_FILE" << 'EOF'
import sys
import re

version_file = sys.argv[1]
index_file = sys.argv[2]

with open(version_file, 'r', encoding='utf-8') as f:
    version_content = f.read()

with open(index_file, 'r', encoding='utf-8') as f:
    index_content = f.read()

pattern = r'(<script type="application/json" id="versionJson">)[\s\S]*?(</script>)'
replacement = r'\1\n' + version_content + r'\n    \2'

new_content = re.sub(pattern, replacement, index_content, count=1)

with open(index_file, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("✅ 버전 정보 동기화 완료!")
print("   - version.json → firebase-wizard.html")
EOF
