#!/usr/bin/env python3
# ===================================================================
# truncate_release_notes.py — Release Notes 길이 제한 (.sh의 Python 이전, #448)
# ===================================================================
#
# 스토어별 release notes(changelog) 길이 한도에 맞춰 텍스트를 안전하게
# 절단한다. 한도를 넘으면 줄 경계를 우선 존중하여 자르고 말줄임표(…)를
# 붙인다. 어떤 경우에도 비정상 종료하지 않아(exit 0) 배포 파이프라인을
# 깨지 않는다.
#
# 배경: Google Play(500 글자), TestFlight(4000 바이트), Firebase 등
# 플랫폼마다 한도와 계측 단위(글자/바이트)가 다르다. 관련 이슈: #347
#
# 사용법:
#   python truncate_release_notes.py <입력파일> <최대길이> <모드> [출력파일]
#   - 모드: char(유니코드 글자 수) | byte(UTF-8 바이트 수)
#   - 출력파일 생략 시 입력파일을 in-place 수정
# ===================================================================

import sys

ELLIPSIS = "…"


def main(argv):
    input_file = argv[1] if len(argv) > 1 else ""
    max_raw = argv[2] if len(argv) > 2 else ""
    mode = (argv[3] if len(argv) > 3 else "char").strip().lower()
    output_file = argv[4] if len(argv) > 4 else input_file

    # --- 입력 검증 (실패해도 배포를 막지 않도록 exit 0) ---
    if not input_file or not max_raw:
        print("⚠️ truncate_release_notes: 인자 부족 (사용법: <입력파일> <최대길이> <모드> [출력파일]). 건너뜀.")
        return 0

    try:
        max_len = int(max_raw)
    except ValueError:
        print("⚠️ truncate_release_notes: 최대길이가 정수가 아님. 건너뜀.")
        return 0

    if mode not in ("char", "byte"):
        print(f"⚠️ truncate_release_notes: 알 수 없는 모드 '{mode}' → char 모드로 동작.")
        mode = "char"

    try:
        with open(input_file, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError:
        print(f"⚠️ truncate_release_notes: 입력 파일 없음 ({input_file}). 건너뜀.")
        return 0

    # 줄바꿈 정규화: CRLF/CR → LF. (Windows에서 생성된 입력의 \r가 길이 계산에서
    # 누락되어 절단 후에도 한도를 넘는 문제를 방지한다.)
    text = text.replace("\r\n", "\n").replace("\r", "\n")

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
        return 0

    # 말줄임표 공간을 뺀 유효 한도
    effective = max(max_len - measure(ELLIPSIS), 0)

    def truncate_to(s, limit):
        """유효 한도 이내가 되도록 문자 단위로 자른다.
        byte 모드는 멀티바이트 문자 중간을 깨지 않도록 문자 경계를 보장한다."""
        if measure(s) <= limit:
            return s
        if mode == "char":
            return s[:limit]
        # byte 모드: 이분 탐색으로 바이트 한도 충족 문자 경계 탐색
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
    candidate = hard_cut[:nl_idx] if nl_idx > 0 else hard_cut

    # 트레일링 공백/줄바꿈 정리 후 말줄임표 부착
    result = candidate.rstrip() + ELLIPSIS

    # 안전 보정: 혹시 결과가 여전히 한도를 넘으면 한 번 더 강제 절단
    while measure(result) > max_len and len(candidate) > 0:
        candidate = candidate[:-1]
        result = candidate.rstrip() + ELLIPSIS

    with open(output_file, "w", encoding="utf-8", newline="") as f:
        f.write(result)

    print(f"✂️ truncate_release_notes: {orig_len} → {measure(result)} {mode} (한도 {max_len}). 절단 완료.")
    return 0


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except AttributeError:
        pass
    sys.exit(main(sys.argv))
