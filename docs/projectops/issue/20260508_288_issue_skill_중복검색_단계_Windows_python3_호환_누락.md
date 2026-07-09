🗒️ 설명
---

issue skill v3.0.36 기준, **5단계(GitHub POST)는 cross-platform 패턴(`PYTHON=$(...)` + `urllib.request`)이 적용됐으나 2-1단계·4-1단계(중복 이슈 검색)는 누락됨**. 두 단계는 여전히 `python3 -c` 하드코딩 + `curl -o /tmp/issue_search.json` 방식이라 Windows 환경에서 다음 오류 연쇄 발생:

- `python3` → Windows Store stub 잡힘 → `Exit code 49`
- `curl ... -o /tmp/issue_search.json` → Git Bash POSIX path 매핑 후 native python이 다시 읽으려 하면 경로 인식 실패 (`FileNotFoundError`)
- 결과적으로 중복 검색이 매번 실패하거나 우회 명령으로 다중 retry 발생 → 토큰 낭비, skill 신뢰도 저하

5단계와 동일한 패턴으로 통일하면 root cause 제거됨.

🔄 재현 방법
---

1. Windows 환경에서 `/issue` 호출 (Git Bash 셸)
2. 2-1단계에서 `python3 -c "import urllib.parse; print(...)"` 실행
3. `Exit code 49` 또는 빈 출력 발생
4. fallback으로 `curl ... -o /tmp/issue_search.json` 시도
5. agent가 `Read` 또는 `python -c "open('/tmp/issue_search.json')"`로 결과 파싱 시도 → `FileNotFoundError`
6. agent가 임시 파일 복사·여러 python 변형 시도하며 5~10회 retry

📸 참고 자료
---

대상 파일: `skills/issue/SKILL.md`

- L120 (2-1단계 중복 검색): `python3 -c` 하드코딩 + `curl -o /tmp/issue_search.json`
- L212 (4-1단계 최종 중복 확인): 동일 패턴 반복
- L249~271 (5단계 POST): 이미 cross-platform 패턴 적용됨 — 참조 모범 사례

추가 발견: `skills/ssh/SKILL.md` L104 — `cat ~/.claude/plugins/installed.json | python3 -c "..."` 동일 문제 가능성 있음. 함께 점검 필요.

✅ 예상 동작
---

2-1단계·4-1단계도 5단계와 동일하게:

- `PYTHON=$(for _py in python3 python; do ... done)` 패턴으로 실행 가능 python 검출
- `urllib.request` + `urllib.parse.quote` 한 번에 처리 (curl + 임시 파일 제거)
- 검색 결과를 stdout JSON으로 출력하여 agent가 직접 파싱 (디스크 경유 X)

`skills/ssh/SKILL.md` L104도 동일 cross-platform 패턴 적용.

⚙️ 환경 정보
---

- **OS**: Windows 11 Pro 10.0.22631 (mac/linux 병행 사용 환경)
- **셸**: Git Bash
- **Python**: `python3` → Windows Store stub, `python` → Python 3.13.6
- **Plugin**: cassiiopeia v3.0.36

🙋‍♂️ 담당자
---

- **백엔드**: -
- **프론트엔드**: -
- **디자인**: -
