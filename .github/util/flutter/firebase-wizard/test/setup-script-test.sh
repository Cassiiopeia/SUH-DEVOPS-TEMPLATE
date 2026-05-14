#!/bin/bash
# Firebase wizard setup script - bash 시나리오 테스트
# 사용법: ./setup-script-test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIZARD_DIR="$(dirname "$SCRIPT_DIR")"
SETUP="$WIZARD_DIR/firebase-wizard-setup.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
FAIL_LOG=()

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local label="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        PASS=$((PASS + 1))
        echo "  ✅ $label"
    else
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$label — 기대 문자열 '$needle' 누락")
        echo "  ❌ $label"
    fi
}

assert_file_unchanged() {
    local original="$1"
    local actual="$2"
    local label="$3"
    if diff -q "$original" "$actual" > /dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo "  ✅ $label"
    else
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$label — 파일이 변경됨")
        echo "  ❌ $label"
    fi
}

setup_workspace() {
    local ws=$(mktemp -d)
    mkdir -p "$ws/.github/workflows"
    cp "$FIXTURES"/*.yaml "$ws/.github/workflows/"
    echo "$ws"
}

cleanup_workspace() {
    rm -rf "$1"
}

NEW_APP_ID="1:905325245238:android:86db75164e0df29a1f3997"
NEW_TESTER="romrom"

echo "=== 시나리오 1: placeholder → 새 값 치환 ==="
WS=$(setup_workspace)
OUT=$("$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup 2>&1)
assert_contains "$NEW_APP_ID" "$(cat $WS/.github/workflows/workflow-with-placeholders.yaml)" "placeholder fixture에 새 APP_ID 적용"
assert_contains "$NEW_TESTER" "$(cat $WS/.github/workflows/workflow-with-placeholders.yaml)" "placeholder fixture에 새 TESTER 적용"
cleanup_workspace "$WS"

echo "=== 시나리오 2: 키 없는 파일은 변경되지 않음 ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup > /dev/null 2>&1
assert_file_unchanged "$FIXTURES/workflow-without-keys.yaml" "$WS/.github/workflows/workflow-without-keys.yaml" "키 없는 fixture 변경 없음"
cleanup_workspace "$WS"

echo "=== 시나리오 3: 이미 같은 값은 SKIP ==="
WS=$(setup_workspace)
OUT=$("$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup 2>&1)
assert_contains "이미" "$OUT" "같은 값 SKIP 메시지 출력"
assert_contains "$NEW_APP_ID" "$(cat $WS/.github/workflows/workflow-mixed.yaml)" "mixed fixture APP_ID는 치환됨"
cleanup_workspace "$WS"

echo "=== 시나리오 4: 다른 값 + non-interactive → SKIP ==="
WS=$(setup_workspace)
OUT=$("$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup 2>&1)
ORIGINAL_APP_ID="1:111111111111:android:aaaaaaaaaaaaaaaaaaaaaa"
assert_contains "$ORIGINAL_APP_ID" "$(cat $WS/.github/workflows/workflow-with-real-values.yaml)" "real-values fixture APP_ID는 SKIP되어 보존"
assert_contains "old-group" "$(cat $WS/.github/workflows/workflow-with-real-values.yaml)" "real-values fixture TESTER_GROUP는 SKIP되어 보존"
cleanup_workspace "$WS"

echo "=== 시나리오 5: --dry-run 시 파일 변경 없음 ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup --dry-run > /dev/null 2>&1
assert_file_unchanged "$FIXTURES/workflow-with-placeholders.yaml" "$WS/.github/workflows/workflow-with-placeholders.yaml" "dry-run 시 placeholder fixture 변경 없음"
cleanup_workspace "$WS"

echo "=== 시나리오 6: 백업 파일 생성 ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive > /dev/null 2>&1
BAK_COUNT=$(ls "$WS/.github/workflows/"*.bak.* 2>/dev/null | wc -l)
if [ "$BAK_COUNT" -ge 2 ]; then
    PASS=$((PASS + 1))
    echo "  ✅ 백업 파일 자동 생성됨 ($BAK_COUNT개)"
else
    FAIL=$((FAIL + 1))
    FAIL_LOG+=("백업 파일이 충분히 생성되지 않음 ($BAK_COUNT개)")
    echo "  ❌ 백업 파일 자동 생성"
fi
cleanup_workspace "$WS"

echo "=== 시나리오 7: --no-backup 시 백업 파일 미생성 ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup > /dev/null 2>&1
BAK_COUNT=$(ls "$WS/.github/workflows/"*.bak.* 2>/dev/null | wc -l)
if [ "$BAK_COUNT" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  ✅ --no-backup 시 백업 미생성"
else
    FAIL=$((FAIL + 1))
    FAIL_LOG+=("--no-backup인데 백업 파일이 생성됨 ($BAK_COUNT개)")
    echo "  ❌ --no-backup"
fi
cleanup_workspace "$WS"

echo "=== 시나리오 8: .github/workflows 폴더 없을 때 abort ==="
WS=$(mktemp -d)
OUT=$("$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup 2>&1) || true
assert_contains "workflows" "$OUT" "workflows 폴더 없음 에러 메시지"
cleanup_workspace "$WS"

echo "=== 시나리오 9: 들여쓰기 보존 (라인 단위 처리 검증) ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup > /dev/null 2>&1
LINE=$(grep "FIREBASE_APP_ID" "$WS/.github/workflows/workflow-with-placeholders.yaml")
assert_contains "  FIREBASE_APP_ID" "$LINE" "들여쓰기 2칸 보존"
cleanup_workspace "$WS"

echo "=== 시나리오 10: 단어 경계 (FIREBASE_APP_ID_DEV 같은 비슷한 키 보호) ==="
WS=$(mktemp -d)
mkdir -p "$WS/.github/workflows"
cat > "$WS/.github/workflows/edge.yaml" <<'EOF'
env:
  FIREBASE_APP_ID: "{FIREBASE_APP_ID}"
  FIREBASE_APP_ID_DEV: "{FIREBASE_APP_ID}"
EOF
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup > /dev/null 2>&1
ID_DEV_LINE=$(grep "FIREBASE_APP_ID_DEV" "$WS/.github/workflows/edge.yaml")
assert_contains "{FIREBASE_APP_ID}" "$ID_DEV_LINE" "FIREBASE_APP_ID_DEV는 단어 경계 매칭으로 변경되지 않음"
cleanup_workspace "$WS"

echo
echo "===================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo
    echo "실패 항목:"
    for msg in "${FAIL_LOG[@]}"; do
        echo "  - $msg"
    done
    exit 1
fi
exit 0
