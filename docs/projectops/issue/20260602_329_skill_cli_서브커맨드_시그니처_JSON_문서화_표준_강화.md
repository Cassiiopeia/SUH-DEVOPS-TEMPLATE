# 🚀[기능개선][Skills] _cli.py 서브커맨드 시그니처·JSON·문서화 표준 강화

라벨: 작업전
담당자: Cassiiopeia

📝 현재 문제점
---

- `skills/issue/scripts/issue_cli.py`의 `get-next-seq` 서브커맨드 호출 시 agent가 `<skill_id>` 1개 인자 대신 `<PROJECT_ROOT> <YYYYMMDD>` 2개 인자를 넘겨 `Error: Exit code 2 / unrecognized arguments` 발생. 실제 발생 케이스 — 2026-06-02 changelog-deploy 승인 게이트 이슈 작성 도중 재현.
- 함수 시그니처(`paths.get_next_seq(skill_dir, today)`)는 인자 2개, CLI 시그니처(`get-next-seq <skill_id>`)는 인자 1개로 불일치. agent가 함수 시그니처를 기준으로 추론하면 그대로 깨진다.
- 실패 출력이 argparse stderr plain text(`usage: ...`)로 나가 모든 다른 서브커맨드가 따르는 JSON contract(`ok/code/summary/next`)와 다르다. agent가 실패 사실은 알지만 무엇을 잘못 넘겼는지·어떻게 고쳐야 하는지 self-correct 단서를 얻지 못한다.
- `get-next-seq`는 `issue` SKILL.md 어디에서도 호출 예시가 명시돼 있지 않다. SKILL.md 4단계는 "임시 번호 `TMP1`, `TMP2` 사용 후 GitHub 등록 후 rename"으로 충돌되는 절차가 적혀 있다. 그럼에도 서브커맨드가 CLI에 노출돼 있어 agent가 "있으니 써야 한다"고 잘못 추론한다.
- 같은 함정이 다른 서브커맨드에도 잠재해 있다. `issue_cli.py`의 `normalize-title`, `create-branch-name`, `get-commit-template`는 `issue/SKILL.md`에 호출 예시가 0건. agent가 시그니처를 추측해 깨질 가능성이 동일하게 남아 있다.
- `paths.get_next_seq`는 잘못된 `skill_id`를 넘겨도 빈 디렉터리로 가정하고 `001`을 반환한다(침묵 실패). 검증 단계가 없어 결과가 틀려도 agent가 알아챌 수 없다.

🛠️ 해결 방안 / 제안 기능
---

세 갈래 — (1) `get-next-seq` 정리, (2) JSON contract 강제, (3) SKILL.md 호출예 표준화.

1. `get-next-seq` 사용 정책 결정 후 정리한다.
   - 현재 사용처 0건이고 SKILL.md 절차(`TMP1` 직접 사용)와 충돌. 가장 안전한 해결은 CLI 서브커맨드 제거이고, `common/paths.get_next_seq` 함수는 그대로 유지해 향후 내부 호출이 필요하면 다시 노출한다.
   - 살리는 쪽으로 결정하면 시그니처를 `get-next-seq <skill_id> [--date YYYYMMDD]`로 정리하고 SKILL.md 사용처에 정확한 호출 예시를 추가한다.

2. 모든 `_cli.py` 서브커맨드의 실패 출력을 JSON contract로 통일한다.
   - argparse 오류(`unrecognized arguments`, `invalid choice`, 인자 개수 mismatch)를 가로채 `emit({"ok": False, "code": "bad_args", "error": "...", "hint": "..."})` 형태로 stdout JSON으로 출력한다.
   - `hint`에는 예시 호출 한 줄을 포함해 agent가 즉시 self-correct 가능하게 한다.
   - 적용 범위: `issue_cli`, `commit_cli`, `report_cli`, `review_cli`, `troubleshoot_cli`, `github_cli`, `changelog_cli` 등 모든 skill CLI.
   - 공통 처리는 `scripts/common/emit.py` 또는 `scripts/common/bootstrap.py`에 `safe_parse(parser)` 헬퍼로 추가한다.

3. SKILL.md ↔ CLI 서브커맨드 노출 규칙을 표준화한다.
   - 원칙: **SKILL.md에 호출 예시가 없는 서브커맨드는 CLI에서 제거하거나 internal-only로 표시한다.**
   - `skills/references/mcp-subcommand-rules.md`에 "SKILL.md 호출 예시 필수" 절을 추가한다.
   - 각 skill SKILL.md 점검 — 자기 `_cli.py`에 정의된 모든 서브커맨드에 대해 `bash` 코드블록 + 입력 인자 + 기대 JSON 출력 예시(`{"ok": true, ...}`) 명시.
   - 점검 대상 우선순위: `issue`(`normalize-title`, `create-branch-name`, `get-commit-template` 호출예 없음), 이후 다른 skill 전수.

4. `paths.get_next_seq` 검증 강화.
   - `skill_dir.exists()` 거짓일 때 침묵 `001` 대신 `{"ok": false, "code": "skill_dir_missing"}` 반환하도록 CLI 레이어에서 처리한다.
   - 함수 자체는 순수 계산 유지, CLI 레이어에서 존재 검증.

⚙️ 작업 내용
---

- `skills/issue/scripts/issue_cli.py`
  - `get-next-seq` 서브커맨드 제거(권장) 또는 시그니처 정정(`<skill_id> [--date]`)
  - argparse `error` override로 JSON 실패 출력 전환
- `scripts/common/emit.py` (또는 `bootstrap.py`)
  - `safe_parse(parser)` 헬퍼 추가 — argparse 에러를 JSON으로 변환
- `scripts/common/paths.py`
  - `get_next_seq` 디렉터리 미존재 시 호출자가 구분할 수 있게 sentinel 반환 또는 예외
- 다른 모든 `*_cli.py` (`commit_cli`, `report_cli`, `review_cli`, `troubleshoot_cli`, `github_cli`, `changelog_cli`)
  - `safe_parse` 적용
- `skills/issue/SKILL.md`
  - 4단계에 "TMP1 직접 사용, `get-next-seq` 호출 금지" 명시
  - 자기 CLI의 모든 사용 가능 서브커맨드에 호출 예시 + 기대 JSON 추가
- 다른 skill SKILL.md 동일 점검 — `normalize-title`, `get-commit-template`, `get-output-path` 등 누락된 호출예 채우기
- `skills/references/mcp-subcommand-rules.md`
  - "SKILL.md 호출 예시 필수" 절 추가, 호출예 없는 서브커맨드는 internal-only / 제거 권고

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
- 프론트엔드: -
- 디자인: -
