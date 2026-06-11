#!/bin/bash
# version_manager.sh project_paths(모노레포 경로) 테스트 스위트
# 실행: bash .github/scripts/test/test_version_manager_paths.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/version_manager.sh"
PASS=0
FAIL=0

# yq/jq 없는 환경(일부 로컬)은 스킵 — ubuntu-latest에는 기본 설치
command -v yq >/dev/null 2>&1 || { echo "SKIP: yq 필요"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq 필요"; exit 0; }

chk() {
  local d="$1" a="$2" e="$3"
  if [ "$a" = "$e" ]; then
    echo "  PASS: $d"; PASS=$((PASS+1))
  else
    echo "  FAIL: $d (got: '$a', want: '$e')"; FAIL=$((FAIL+1))
  fi
}

new_workdir() {
  WORK=$(mktemp -d)
  cd "$WORK" || exit 1
}

echo "=== (1) legacy 회귀: project_paths 없음 + 루트 flutter ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.2"
version_code: 5
project_type: "flutter"
EOF
printf 'name: demo\nversion: 0.0.1+1\n' > pubspec.yaml
bash "$SCRIPT" sync >/dev/null 2>&1
chk "루트 pubspec 동기화" "$(yq -r '.version' pubspec.yaml)" "0.0.2+5"

echo "=== (2) 모노레포: project_paths 있는 멀티타입 sync ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["flutter", "react", "python"]
project_type: "flutter"
project_paths:
  flutter: "app"
  react: "client"
  python: "ai"
EOF
mkdir -p app client ai
printf 'name: demo\nversion: 0.0.1+1\n' > app/pubspec.yaml
printf '{"name":"demo","version":"0.0.1"}\n' > client/package.json
printf '[project]\nname = "demo"\nversion = "0.0.1"\n' > ai/pyproject.toml
bash "$SCRIPT" sync >/dev/null 2>&1
chk "app/pubspec.yaml" "$(yq -r '.version' app/pubspec.yaml)" "0.0.9+5"
chk "client/package.json" "$(jq -r '.version' client/package.json)" "0.0.9"
chk "ai/pyproject.toml" "$(grep -E '^version' ai/pyproject.toml | sed 's/.*"\(.*\)".*/\1/')" "0.0.9"

echo "=== (3) paths 없는 멀티타입: 서브폴더 미동기화(기존 no-op) + exit 0 ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["flutter", "react"]
project_type: "flutter"
EOF
mkdir -p app client
printf 'name: demo\nversion: 0.0.1+1\n' > app/pubspec.yaml
printf '{"name":"demo","version":"0.0.1"}\n' > client/package.json
bash "$SCRIPT" sync >/dev/null 2>&1
chk "exit 0" "$?" "0"
chk "app/pubspec 그대로" "$(yq -r '.version' app/pubspec.yaml)" "0.0.1+1"
chk "client/package.json 그대로" "$(jq -r '.version' client/package.json)" "0.0.1"

echo "=== (4) 경로에 마커 없음: 경고 + skip + exit 0 ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["flutter"]
project_type: "flutter"
project_paths:
  flutter: "nope"
EOF
OUT=$(bash "$SCRIPT" sync 2>&1)
chk "exit 0" "$?" "0"
echo "$OUT" | grep -q "없음" && chk "경고 출력" "1" "1" || chk "경고 출력" "0" "1"

echo "=== (5) increment: 경로 따라 patch 증가 ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["flutter", "react"]
project_type: "flutter"
project_paths:
  flutter: "app"
  react: "client"
EOF
mkdir -p app client
printf 'name: demo\nversion: 0.0.9+5\n' > app/pubspec.yaml
printf '{"name":"demo","version":"0.0.9"}\n' > client/package.json
bash "$SCRIPT" increment >/dev/null 2>&1
chk "version.yml 증가" "$(yq -r '.version' version.yml)" "0.0.10"
chk "app/pubspec 증가" "$(yq -r '.version' app/pubspec.yaml | cut -d'+' -f1)" "0.0.10"
chk "client/package.json 증가" "$(jq -r '.version' client/package.json)" "0.0.10"

echo "=== (6) spring 잘못된 경로 + increment: 경고 + exit 0 ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["spring"]
project_type: "spring"
project_paths:
  spring: "nope"
EOF
OUT=$(bash "$SCRIPT" increment 2>&1)
RC=$?
chk "exit 0" "$RC" "0"
echo "$OUT" | grep -q "없음" && chk "경고 출력" "1" "1" || chk "경고 출력" "0" "1"
chk "version.yml 증가" "$(yq -r '.version' version.yml)" "0.0.10"

echo ""
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
