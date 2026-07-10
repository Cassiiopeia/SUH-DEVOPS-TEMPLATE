#!/bin/bash
# coderabbit provider — @coderabbitai summary 요청 후 폴링 (#455)
# 입력: PR_NUMBER, GITHUB_REPOSITORY, PAT_TOKEN, CODERABBIT_TIMEOUT(기본 600초)
# 출력: 성공 시 pr_body.md + exit 0 + PROVIDER=coderabbit. 무응답 시 exit 1 (다음 사다리로 폴백).
#
# CodeRabbit은 default 브랜치가 아니면 @coderabbitai summary에 응답하지 않는 제약이 있다.
# 그런 경우 timeout 후 exit 1 → 워크플로우가 github-ai 등 다음 provider로 폴백한다.
set -u
TIMEOUT="${CODERABBIT_TIMEOUT:-600}"
REPO="${GITHUB_REPOSITORY:-}"
PR="${PR_NUMBER:-}"
TOKEN="${PAT_TOKEN:-}"

if [ -z "$REPO" ] || [ -z "$PR" ] || [ -z "$TOKEN" ]; then
  echo "coderabbit: 필수 입력(PR_NUMBER/GITHUB_REPOSITORY/PAT_TOKEN) 누락 — 폴백" >&2
  exit 1
fi

API="https://api.github.com/repos/$REPO"
# Windows python3 스텁(실행 불가 alias) 회피 — 실행 검증 포함 탐지 (CLAUDE.md OS 호환 표준)
PYBIN=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)

# summary 요청
curl -s -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
  -X POST -d '{"body": "@coderabbitai summary"}' \
  "$API/issues/${PR}/comments" > /dev/null 2>&1 || true

INTERVAL=5
ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  RAW=$(curl -s -H "Authorization: token $TOKEN" "$API/pulls/${PR}" 2>/dev/null || true)
  if [ -n "$PYBIN" ]; then
    BODY=$(printf "%s" "$RAW" | "$PYBIN" -c "import sys,json;
try:
    print(json.load(sys.stdin).get('body') or '')
except Exception:
    print('')" 2>/dev/null || true)
  else
    BODY="$RAW"
  fi
  if printf "%s" "$BODY" | grep -q "Summary by CodeRabbit"; then
    printf "%s" "$BODY" > pr_body.md
    echo "PROVIDER=coderabbit"
    exit 0
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "coderabbit: ${TIMEOUT}초 내 Summary 없음 — 폴백" >&2
exit 1
