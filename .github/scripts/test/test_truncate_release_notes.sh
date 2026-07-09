#!/bin/bash
# truncate_release_notes.sh 테스트 스위트 (Linux/WSL 환경 검증용)
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/truncate_release_notes.sh"
WORK=$(mktemp -d)
cd "$WORK" || exit 1
PASS=0
FAIL=0

chk() {
  local d="$1" a="$2" op="$3" e="$4"
  if [ "$op" = "le" ]; then
    if [ "$a" -le "$e" ]; then echo "  PASS: $d ($a <= $e)"; PASS=$((PASS+1)); else echo "  FAIL: $d ($a NOT <= $e)"; FAIL=$((FAIL+1)); fi
  else
    if [ "$a" = "$e" ]; then echo "  PASS: $d ($a == $e)"; PASS=$((PASS+1)); else echo "  FAIL: $d ($a != $e)"; FAIL=$((FAIL+1)); fi
  fi
}
clen() { python3 -c "import sys; print(len(open(sys.argv[1], encoding='utf-8').read()))" "$1"; }
cr() { tr -cd '\r' < "$1" | wc -c | tr -d ' '; }  # BSD wc는 앞에 공백 붙임 → 제거
ends_ellipsis() { python3 -c "import sys; print('1' if open(sys.argv[1], encoding='utf-8').read().endswith(chr(8230)) else '0')" "$1"; }

echo "=== (a) char 한도 이내 통과 ==="
printf '짧은 노트' > a.txt
bash "$SCRIPT" a.txt 480 char
chk "내용 보존" "$(cat a.txt)" eq "짧은 노트"

echo "=== (b) char 600자 -> 480 ==="
python3 -c "open('b.txt','w',encoding='utf-8').write('가'*600)"
bash "$SCRIPT" b.txt 480 char
chk "글자수 <=480" "$(clen b.txt)" le 480
chk "말줄임표 끝" "$(ends_ellipsis b.txt)" eq 1

echo "=== (c) CRLF 줄경계 절단 -> 100자 ==="
: > c.txt
for i in $(seq 1 39); do printf '항목 %d번 내용입니다\r\n' "$i" >> c.txt; done
bash "$SCRIPT" c.txt 100 char
chk "글자수 <=100" "$(clen c.txt)" le 100
chk "CR 제거" "$(cr c.txt)" eq 0
chk "말줄임표 끝" "$(ends_ellipsis c.txt)" eq 1

echo "=== (d) byte 모드 한글 무손상 -> 100byte ==="
python3 -c "open('d.txt','w',encoding='utf-8').write('가나다라마'*20)"
bash "$SCRIPT" d.txt 100 byte
chk "바이트 <=100" "$(wc -c < d.txt)" le 100
if python3 -c "open('d.txt',encoding='utf-8').read()" 2>/dev/null; then chk "UTF-8 디코드" 1 eq 1; else chk "UTF-8 디코드" 0 eq 1; fi

echo "=== (e) 없는 파일 exit 0 ==="
rm -f none.txt
bash "$SCRIPT" none.txt 480 char
chk "exit 0" "$?" eq 0

echo "=== (f) 빈 파일 exit 0 ==="
: > empty.txt
bash "$SCRIPT" empty.txt 480 char
chk "exit 0" "$?" eq 0

echo "=== (g) 잘못된 모드 fallback exit 0 ==="
printf '테스트' > g.txt
bash "$SCRIPT" g.txt 480 bogus
chk "exit 0" "$?" eq 0

echo "=== (h) 출력파일 분리 (입력 보존) ==="
python3 -c "open('hi.txt','w',encoding='utf-8').write('나'*600)"
bash "$SCRIPT" hi.txt 480 char ho.txt
chk "입력 보존 600" "$(clen hi.txt)" eq 600
chk "출력 <=480" "$(clen ho.txt)" le 480

echo ""
echo "===================================="
echo "RESULT: PASS=$PASS  FAIL=$FAIL"
echo "===================================="
rm -rf "$WORK"
[ "$FAIL" -eq 0 ]
