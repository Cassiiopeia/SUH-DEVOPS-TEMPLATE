#!/bin/bash
# openai_compatible.sh 정규화 검증 (mock 응답 주입) (#455)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../changelog_providers/openai_compatible.sh"
TMP=$(mktemp -d)
cd "$TMP" || exit 1
git init -q && git config user.email t@t && git config user.name t
git commit -q --allow-empty -m "feat: 로그인"

FAIL=0
# mock: CHANGELOG_TEST_RESPONSE가 있으면 실제 curl 대신 그걸 응답으로 사용
CHANGELOG_TEST_RESPONSE='* **새 기능**
  * 로그인 기능이 추가되었습니다' \
  PROVIDER_NAME=openai MODEL_API_KEY=dummy COMMIT_RANGE="HEAD~1..HEAD" \
  bash "$SCRIPT" > /dev/null || { echo "FAIL: exit"; FAIL=1; }
grep -q "Summary by CodeRabbit" pr_body.md || { echo "FAIL: header"; FAIL=1; }
grep -q "로그인 기능이 추가" pr_body.md || { echo "FAIL: body"; FAIL=1; }

# ollama인데 base_url 없으면 exit 1 (폴백)
CHANGELOG_TEST_RESPONSE="" PROVIDER_NAME=ollama CHANGELOG_BASE_URL="" MODEL_API_KEY=dummy \
  bash "$SCRIPT" > /dev/null 2>&1 && { echo "FAIL: ollama base_url 없는데 성공함"; FAIL=1; }

# 알 수 없는 provider면 exit 1
CHANGELOG_TEST_RESPONSE="x" PROVIDER_NAME=unknown \
  bash "$SCRIPT" > /dev/null 2>&1 && { echo "FAIL: unknown provider 성공함"; FAIL=1; }

cd / && rm -rf "$TMP"
[ "$FAIL" -eq 0 ] && echo "PASS" || { echo "FAILED"; exit 1; }
