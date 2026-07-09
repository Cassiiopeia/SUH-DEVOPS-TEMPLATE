#!/bin/bash
# commit.sh가 커밋 로그로 pr_body.md를 만드는지 오프라인 검증 (#455)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../changelog_providers/commit.sh"
TMP=$(mktemp -d)
cd "$TMP" || exit 1
git init -q && git config user.email t@t && git config user.name t
git commit -q --allow-empty -m "feat: 사용자 로그인 기능 추가"
git commit -q --allow-empty -m "fix: 결제 오류 수정 #123"
git branch -M main
git checkout -q -b develop
git commit -q --allow-empty -m "docs: README 갱신"

FAIL=0
COMMIT_RANGE="main..HEAD" bash "$SCRIPT" > /dev/null || { echo "FAIL: exit non-zero"; FAIL=1; }
grep -q "Summary by CodeRabbit" pr_body.md || { echo "FAIL: no summary header"; FAIL=1; }
grep -q "문서" pr_body.md || { echo "FAIL: no docs section"; FAIL=1; }

# main..HEAD가 아닌 전체 분석도 되는지 (fallback)
COMMIT_RANGE="origin/nonexistent..HEAD" bash "$SCRIPT" > /dev/null || { echo "FAIL: fallback exit"; FAIL=1; }
grep -q "새 기능" pr_body.md || { echo "FAIL: no feat section (fallback)"; FAIL=1; }
grep -q "버그 수정" pr_body.md || { echo "FAIL: no fix section (fallback)"; FAIL=1; }

# 정제: 이슈번호·prefix 제거 확인
grep -q "#123" pr_body.md && { echo "FAIL: 이슈번호 미제거"; FAIL=1; }
grep -qE "^\s*\* fix:" pr_body.md && { echo "FAIL: prefix 미제거"; FAIL=1; }

cd / && rm -rf "$TMP"
[ "$FAIL" -eq 0 ] && echo "PASS" || { echo "FAILED"; exit 1; }
