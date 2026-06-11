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

echo "=== (7) classify_package_json: react 의존성 → react ==="
new_workdir
printf '{"dependencies":{"react":"^18.0.0"}}\n' > package.json
chk "react 판별" "$(classify_package_json package.json)" "react"

echo "=== (8) classify_package_json: next 의존성 → next ==="
new_workdir
printf '{"dependencies":{"next":"14.0.0","react":"^18"}}\n' > package.json
chk "next 판별(react보다 우선)" "$(classify_package_json package.json)" "next"

echo "=== (9) classify_package_json: react-native + expo → react-native-expo ==="
new_workdir
printf '{"dependencies":{"react-native":"0.73","expo":"~50"}}\n' > package.json
chk "expo 판별" "$(classify_package_json package.json)" "react-native-expo"

echo "=== (10) classify_package_json: 순수 → node ==="
new_workdir
printf '{"dependencies":{"express":"^4"}}\n' > package.json
chk "node 판별" "$(classify_package_json package.json)" "node"

echo "=== (11) 멀티모듈 spring: settings.gradle 있으면 . 하나 ==="
new_workdir
echo "rootProject.name='demo'" > settings.gradle
echo "version='0.0.1'" > build.gradle
mkdir -p api core
echo "version='0.0.1'" > api/build.gradle
echo "version='0.0.1'" > core/build.gradle
chk "멀티모듈 → 루트만" "$(find_type_path_candidates spring)" "."

echo "=== (12) 단일모듈 spring: 루트 build.gradle, settings 없음 → . ==="
new_workdir
echo "version='0.0.1'" > build.gradle
chk "단일모듈 → ." "$(find_type_path_candidates spring)" "."

echo "=== (13) 서브폴더 spring: server/build.gradle, settings 없음 → server ==="
new_workdir
mkdir -p server
echo "version='0.0.1'" > server/build.gradle
chk "서브폴더 spring → server" "$(find_type_path_candidates spring)" "server"

echo "=== (14) 서브폴더 react: client/package.json → react 포함 ==="
new_workdir
mkdir -p client
printf '{"dependencies":{"react":"^18"}}\n' > client/package.json
chk "서브폴더 react 추천" "$(suggest_types_by_scan)" "react"

echo "=== (15) 서브폴더 next: web/package.json → next 포함 ==="
new_workdir
mkdir -p web
printf '{"dependencies":{"next":"14","react":"^18"}}\n' > web/package.json
chk "서브폴더 next 추천" "$(suggest_types_by_scan)" "next"

echo "=== (16) 혼합 모노레포: app/pubspec + client/package(react) + ai/pyproject ==="
new_workdir
mkdir -p app/lib client ai
printf 'name: demo\n' > app/pubspec.yaml
printf '{"dependencies":{"react":"^18"}}\n' > client/package.json
printf '[project]\nname="x"\n' > ai/pyproject.toml
chk "혼합 모노레포 정렬 추천" "$(suggest_types_by_scan)" "flutter,react,python"

echo "=== (17) 마커 없는 .py 4개 → python (확장자 폴백 유지) ==="
new_workdir
for i in 1 2 3 4; do echo "print($i)" > "m$i.py"; done
chk "확장자 폴백 python" "$(suggest_types_by_scan)" "python"

echo ""
echo "=== 결과: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
