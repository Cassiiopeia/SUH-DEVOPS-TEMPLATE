#!/bin/bash
# ============================================
# version.json → playstore-wizard.html 동기화 스크립트
# 사용법: ./version-sync.sh
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/version.json"
INDEX_FILE="$SCRIPT_DIR/playstore-wizard.html"

# 파일 존재 확인
if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ version.json 파일을 찾을 수 없습니다: $VERSION_FILE"
    exit 1
fi

if [ ! -f "$INDEX_FILE" ]; then
    echo "❌ playstore-wizard.html 파일을 찾을 수 없습니다: $INDEX_FILE"
    exit 1
fi

# 현재 버전 출력
CURRENT_VERSION=$(grep '"version"' "$VERSION_FILE" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
echo "📦 동기화할 버전: v$CURRENT_VERSION"

# Python을 사용해 안전하게 교체
python3 - "$VERSION_FILE" "$INDEX_FILE" << 'EOF'
import sys
import re

version_file = sys.argv[1]
index_file = sys.argv[2]

# version.json 읽기
with open(version_file, 'r', encoding='utf-8') as f:
    version_content = f.read()

# playstore-wizard.html 읽기
with open(index_file, 'r', encoding='utf-8') as f:
    index_content = f.read()

# 정규식으로 versionJson 스크립트 영역 교체
pattern = r'(<script type="application/json" id="versionJson">)[\s\S]*?(</script>)'
replacement = r'\1\n' + version_content + r'\n    \2'

new_content = re.sub(pattern, replacement, index_content, count=1)

# 저장
with open(index_file, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("✅ 버전 정보 동기화 완료!")
print("   - version.json → playstore-wizard.html")
EOF
