#!/bin/bash

# ===================================================================
# Release Notes 길이 제한 스크립트 v1.0
# ===================================================================
#
# 스토어별 release notes(changelog) 길이 한도에 맞춰 텍스트를 안전하게
# 절단한다. 한도를 넘으면 줄 경계를 우선 존중하여 자르고 말줄임표(…)를
# 붙인다. 어떤 경우에도 비정상 종료하지 않아(exit 0) 배포 파이프라인을
# 깨지 않는다.
#
# 배경: Google Play(500 글자), TestFlight(4000 바이트), Firebase 등
# 플랫폼마다 한도와 계측 단위(글자/바이트)가 다르다. 생성 단계가 아닌
# 각 플랫폼 배포 직전에 그 플랫폼 기준으로 절단한다.
# 관련 이슈: SUH-DEVOPS-TEMPLATE#347
#
# 사용법:
# ./truncate_release_notes.sh <입력파일> <최대길이> <모드> [출력파일]
#
# 인자:
# - 입력파일: 절단 대상 텍스트 파일
# - 최대길이: 한도 (정수)
# - 모드: char(유니코드 글자 수) | byte(UTF-8 바이트 수)
# - 출력파일: (선택) 생략 시 입력파일을 in-place 수정
#
# 예시:
# ./truncate_release_notes.sh final_release_notes.txt 480 char
# ./truncate_release_notes.sh final_release_notes.txt 3800 byte out.txt
#
# ===================================================================

set -u

INPUT_FILE="${1:-}"
MAX_LEN="${2:-}"
MODE="${3:-char}"
OUTPUT_FILE="${4:-$INPUT_FILE}"

# --- 입력 검증 (실패해도 배포를 막지 않도록 exit 0) ---
if [ -z "$INPUT_FILE" ] || [ -z "$MAX_LEN" ]; then
  echo "⚠️ truncate_release_notes: 인자 부족 (사용법: <입력파일> <최대길이> <모드> [출력파일]). 건너뜀."
  exit 0
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "⚠️ truncate_release_notes: 입력 파일 없음 ($INPUT_FILE). 건너뜀."
  exit 0
fi

# --- PYTHON 검출 (크로스 플랫폼: Windows Store stub 회피) ---
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
if [ -z "$PYTHON" ]; then
  echo "⚠️ truncate_release_notes: Python을 찾을 수 없음. 절단 없이 원본 유지."
  exit 0
fi

# --- 절단 로직 (Python 표준 라이브러리만 사용 → 내부망/양 OS 동작) ---
# 인자는 환경변수로 전달 (heredoc 보간/임시파일/파이프 미사용)
TRN_INPUT="$INPUT_FILE" \
TRN_OUTPUT="$OUTPUT_FILE" \
TRN_MAX="$MAX_LEN" \
TRN_MODE="$MODE" \
PYTHONIOENCODING=utf-8 "$PYTHON" - <<'PYEOF'
import os
import sys

input_file = os.environ["TRN_INPUT"]
output_file = os.environ["TRN_OUTPUT"]
mode = os.environ.get("TRN_MODE", "char").strip().lower()

try:
    max_len = int(os.environ["TRN_MAX"])
except ValueError:
    print(f"⚠️ truncate_release_notes: 최대길이가 정수가 아님. 건너뜀.")
    sys.exit(0)

if mode not in ("char", "byte"):
    print(f"⚠️ truncate_release_notes: 알 수 없는 모드 '{mode}' → char 모드로 동작.")
    mode = "char"

with open(input_file, "r", encoding="utf-8") as f:
    text = f.read()

# 줄바꿈 정규화: CRLF/CR → LF. (Windows에서 생성된 입력의 \r가 길이 계산에서
# 누락되어 절단 후에도 한도를 넘는 문제를 방지한다.)
text = text.replace("\r\n", "\n").replace("\r", "\n")

ELLIPSIS = "…"


def measure(s):
    """모드별 길이 측정: char=글자 수, byte=UTF-8 바이트 수."""
    return len(s.encode("utf-8")) if mode == "byte" else len(s)


orig_len = measure(text)

if orig_len <= max_len:
    # 한도 이내 — 변경 없음
    if output_file != input_file:
        with open(output_file, "w", encoding="utf-8", newline="") as f:
            f.write(text)
    print(f"✅ truncate_release_notes: 한도 이내 ({orig_len}/{max_len} {mode}). 변경 없음.")
    sys.exit(0)

# 말줄임표 공간을 뺀 유효 한도
ellipsis_len = measure(ELLIPSIS)
effective = max_len - ellipsis_len
if effective < 0:
    effective = 0


def truncate_to(s, limit):
    """유효 한도 이내가 되도록 문자 단위로 자른다.
    byte 모드는 멀티바이트 문자 중간을 깨지 않도록 문자 경계를 보장한다."""
    if measure(s) <= limit:
        return s
    if mode == "char":
        return s[:limit]
    # byte 모드: 문자를 하나씩 줄여 바이트 한도 충족
    lo, hi = 0, len(s)
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if len(s[:mid].encode("utf-8")) <= limit:
            lo = mid
        else:
            hi = mid - 1
    return s[:lo]

# 1차: 유효 한도 이내로 자른 결과를 만든다
hard_cut = truncate_to(text, effective)

# 줄 경계 우선: hard_cut 범위 안의 마지막 줄바꿈에서 자른다
nl_idx = hard_cut.rfind("\n")
if nl_idx > 0:
    candidate = hard_cut[:nl_idx]
else:
    # 줄바꿈이 없으면 글자/바이트 경계 fallback
    candidate = hard_cut

# 트레일링 공백/줄바꿈 정리 후 말줄임표 부착
result = candidate.rstrip() + ELLIPSIS

# 안전 보정: 혹시 결과가 여전히 한도를 넘으면 한 번 더 강제 절단
while measure(result) > max_len and len(candidate) > 0:
    candidate = candidate[:-1]
    result = candidate.rstrip() + ELLIPSIS

with open(output_file, "w", encoding="utf-8", newline="") as f:
    f.write(result)

print(f"✂️ truncate_release_notes: {orig_len} → {measure(result)} {mode} (한도 {max_len}). 절단 완료.")
PYEOF

exit 0
