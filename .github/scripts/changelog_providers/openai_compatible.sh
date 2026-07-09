#!/bin/bash
# openai-compatible provider — base_url preset swap (#455)
# 입력: PROVIDER_NAME(openai|gemini|claude|ollama), CHANGELOG_BASE_URL(ollama용),
#       MODEL_API_KEY, COMMIT_RANGE, CHANGELOG_MODEL(선택), CHANGELOG_TEST_RESPONSE(테스트용)
# 출력: 성공 시 pr_body.md + exit 0 + PROVIDER=openai:<name>. 실패 시 exit 1 (폴백).
#
# openai/gemini/claude/ollama 모두 OpenAI 호환(/v1/chat/completions). base_url·기본 모델만 다르다.
set -u
NAME="${PROVIDER_NAME:-openai}"

case "$NAME" in
  openai) BASE="https://api.openai.com/v1"; MODEL="${CHANGELOG_MODEL:-gpt-4o-mini}" ;;
  gemini) BASE="https://generativelanguage.googleapis.com/v1beta/openai"; MODEL="${CHANGELOG_MODEL:-gemini-1.5-flash}" ;;
  claude) BASE="https://api.anthropic.com/v1"; MODEL="${CHANGELOG_MODEL:-claude-3-5-haiku-latest}" ;;
  ollama) BASE="${CHANGELOG_BASE_URL:-}"; MODEL="${CHANGELOG_MODEL:-qwen2.5}" ;;
  *) echo "openai-compatible: 알 수 없는 provider '$NAME' — 폴백" >&2; exit 1 ;;
esac

RANGE="${COMMIT_RANGE:-origin/main..HEAD}"
PYBIN=$(command -v python3 || command -v python || true)

# 커밋 수집 (chore/ci/build/test prefix는 입력에서 제외 → 토큰 절약)
COMMITS=$(git log "$RANGE" --pretty=format:"%s" 2>/dev/null | grep -vE "\[skip ci\]|^(chore|ci|build|test):" || true)
COMMITS=$(printf "%s" "$COMMITS" | head -40)
[ -z "$COMMITS" ] && COMMITS=$(git log --pretty=format:"%s" -20 2>/dev/null || true)

if [ -n "${CHANGELOG_TEST_RESPONSE:-}" ]; then
  CONTENT="$CHANGELOG_TEST_RESPONSE"
else
  if [ -z "$BASE" ]; then
    echo "openai-compatible: base_url 없음 (ollama는 CHANGELOG_BASE_URL 필요) — 폴백" >&2
    exit 1
  fi
  if [ -z "$PYBIN" ]; then
    echo "openai-compatible: python 없음 — 폴백" >&2
    exit 1
  fi
  PROMPT="다음 커밋들을 사용자용 릴리스 노트로 만들어라. 파일명·prefix·이슈번호·URL 금지. '새 기능'/'버그 수정'/'개선'으로 분류:
$COMMITS"
  REQ=$("$PYBIN" -c "import json,sys; print(json.dumps({'model':sys.argv[1],'messages':[{'role':'user','content':sys.argv[2]}]}))" "$MODEL" "$PROMPT" 2>/dev/null || true)
  [ -z "$REQ" ] && { echo "openai-compatible: 요청 JSON 생성 실패 — 폴백" >&2; exit 1; }
  RESP=$(curl -s --max-time 60 -H "Authorization: Bearer ${MODEL_API_KEY:-}" -H "Content-Type: application/json" \
         -X POST -d "$REQ" "$BASE/chat/completions" 2>/dev/null || true)
  CONTENT=$(printf "%s" "$RESP" | "$PYBIN" -c "import sys,json;
try:
    print(json.load(sys.stdin)['choices'][0]['message']['content'])
except Exception:
    print('')" 2>/dev/null || true)
  if [ -z "$CONTENT" ]; then
    echo "openai-compatible: API 응답 파싱 실패 — 폴백" >&2
    exit 1
  fi
fi

{
  echo "<!-- This is an auto-generated comment: release notes by coderabbit.ai -->"
  echo ""
  echo "## Summary by CodeRabbit"
  echo ""
  echo "## 릴리스 노트"
  echo ""
  printf "%s\n" "$CONTENT"
  echo ""
  echo "<!-- end of auto-generated comment: release notes by coderabbit.ai -->"
} > pr_body.md

echo "PROVIDER=openai:$NAME"
exit 0
