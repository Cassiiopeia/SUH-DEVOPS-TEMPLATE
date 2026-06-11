#!/bin/bash
# suggest_types_by_scan 단위 테스트
# 실행: bash .github/scripts/test/test_integrator_suggest.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/../../.." && pwd)/template_integrator.sh"
PASS=0
FAIL=0

# 함수만 source (source 가드 덕분에 main 안 돎)
source "$SCRIPT" >/dev/null 2>&1

chk() {
  local d="$1" a="$2" e="$3"
  if [ "$a" = "$e" ]; then
    echo "  PASS: $d"; PASS=$((PASS+1))
  else
    echo "  FAIL: $d (got: '$a', want: '$e')"; FAIL=$((FAIL+1))
  fi
}

new_workdir() { WORK=$(mktemp -d); cd "$WORK" || exit 1; }

echo "=== (1) .py 4개 → python 추천 ==="
new_workdir
for i in 1 2 3 4; do echo "print($i)" > "mod$i.py"; done
chk "python 추천" "$(suggest_types_by_scan)" "python"

echo "=== (2) .py 2개(임계 미만) → 추천 없음 ==="
new_workdir
echo "x" > a.py; echo "y" > b.py
chk "임계 미만 빈 추천" "$(suggest_types_by_scan)" ""

echo "=== (3) .dart 1개 → flutter 추천 ==="
new_workdir
echo "void main(){}" > main.dart
chk "flutter 추천(.dart 임계 1)" "$(suggest_types_by_scan)" "flutter"

echo "=== (4) .tsx 3개 → react 추천 ==="
new_workdir
for i in 1 2 3; do echo "export default ()=>null" > "c$i.tsx"; done
chk "react 추천" "$(suggest_types_by_scan)" "react"

echo "=== (5) .js 3개(react/flutter/python/spring 없음) → node 추천 ==="
new_workdir
for i in 1 2 3; do echo "console.log($i)" > "s$i.js"; done
chk "node 추천(fallback)" "$(suggest_types_by_scan)" "node"

echo "=== (6) node_modules 안의 .py는 제외 ==="
new_workdir
mkdir -p node_modules/pkg
for i in 1 2 3 4; do echo "x" > "node_modules/pkg/m$i.py"; done
chk "제외 폴더 무시 → 빈 추천" "$(suggest_types_by_scan)" ""

echo ""
echo "=== 결과: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
