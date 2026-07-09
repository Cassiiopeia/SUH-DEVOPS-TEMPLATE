#!/bin/bash
# commit provider — 커밋 분석으로 pr_body.md 생성 (안전망, AI 무의존) (#455)
# 입력: COMMIT_RANGE (기본 origin/main..HEAD)
# 출력: pr_body.md (Summary by CodeRabbit 고정 구조), stdout에 PROVIDER=commit
#
# macOS bash 3.2 + BSD 도구 호환: declare -A / grep -P 미사용, set -e 미사용(끝 exit 0 명시).
set -u
RANGE="${COMMIT_RANGE:-origin/main..HEAD}"

# 지정 range로 커밋 수집. 비면 최근 30개로 폴백. grep 0매치가 스크립트를 죽이지 않도록 || true.
COMMITS=$(git log "$RANGE" --pretty=format:"%s" 2>/dev/null | grep -v "\[skip ci\]" || true)
COMMITS=$(printf "%s" "$COMMITS" | head -60)
if [ -z "$COMMITS" ]; then
  COMMITS=$(git log --pretty=format:"%s" -30 2>/dev/null | grep -v "\[skip ci\]" || true)
fi

FEAT=""; FIX=""; IMP=""; DOC=""; ETC=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  # prefix 추출 (BSD grep 호환 — -oE 사용, -P 금지)
  PREFIX=$(printf "%s" "$line" | grep -oE '^(feat|fix|refactor|docs|chore|style|test|perf|ci|build|revert)(\([^)]*\))?:' | head -1 || true)
  # 정제: prefix·이슈번호(#123)·URL 제거, 공백 정리
  MSG=$(printf "%s" "$line" \
    | sed -E 's/^[a-z]+(\([^)]*\))?: *//' \
    | sed -E 's/#[0-9]+//g' \
    | sed -E 's#https?://[^ ]+##g' \
    | sed -E 's/  */ /g' | sed -E 's/^ *//; s/ *$//')
  [ -z "$MSG" ] && MSG="$line"
  case "$PREFIX" in
    feat*) FEAT="$FEAT
  * $MSG" ;;
    fix*) FIX="$FIX
  * $MSG" ;;
    refactor*|style*|perf*) IMP="$IMP
  * $MSG" ;;
    docs*) DOC="$DOC
  * $MSG" ;;
    *) ETC="$ETC
  * $MSG" ;;
  esac
done <<EOF
$COMMITS
EOF

{
  echo "<!-- This is an auto-generated comment: release notes by coderabbit.ai -->"
  echo ""
  echo "## Summary by CodeRabbit"
  echo ""
  echo "## 릴리스 노트"
  echo ""
  [ -n "$FEAT" ] && { echo "* **새 기능**"; printf "%s\n" "$FEAT" | sed '/^$/d'; echo ""; }
  [ -n "$FIX" ]  && { echo "* **버그 수정**"; printf "%s\n" "$FIX" | sed '/^$/d'; echo ""; }
  [ -n "$IMP" ]  && { echo "* **개선**"; printf "%s\n" "$IMP" | sed '/^$/d'; echo ""; }
  [ -n "$DOC" ]  && { echo "* **문서**"; printf "%s\n" "$DOC" | sed '/^$/d'; echo ""; }
  [ -n "$ETC" ]  && { echo "* **기타**"; printf "%s\n" "$ETC" | sed '/^$/d'; echo ""; }
  echo "<!-- end of auto-generated comment: release notes by coderabbit.ai -->"
} > pr_body.md

echo "PROVIDER=commit"
exit 0
