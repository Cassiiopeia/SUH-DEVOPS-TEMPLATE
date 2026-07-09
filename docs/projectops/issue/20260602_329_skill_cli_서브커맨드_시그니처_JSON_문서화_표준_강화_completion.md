## 완료 요약 (이슈 #329)

### 적용 사항
- `scripts/common/cli_parser.py` 신규 — `JSONArgumentParser` + `run_cli` 헬퍼.
- 7개 `_cli.py` (issue/commit/report/review/troubleshoot/github/changelog) 전부 `JSONArgumentParser` 적용.
- `issue_cli.py`의 `get-next-seq` 서브커맨드 제거 (사용처 0건 + SKILL.md `TMP1` 절차와 충돌).
- `paths.get_next_seq`에 `strict` 모드 추가.
- `mcp-subcommand-rules.md`에 §7 "SKILL.md 호출예 필수" + §8 "JSONArgumentParser 표준" 추가.
- 회귀 테스트 — argparse 실패 JSON 강제, SKILL.md ↔ CLI 매칭, `get-next-seq` 부재.

### 재현 케이스 검증
원래 실패: `issue_cli.py get-next-seq <root> <date>` → argparse stderr text + Exit 2
수정 후: 동일 호출 → stdout JSON `{"ok": false, "code": "bad_args", "available_subcommands": [...]}`
agent가 응답을 보고 즉시 self-correct 가능.

실제 검증 출력 (2026-06-02):
```json
{"ok": false, "code": "bad_args", "error": "argument command: invalid choice: 'get-next-seq' (choose from create-issue, search-issues, update-issue, normalize-title, create-branch-name, get-commit-template)", "hint": "issue_cli <subcommand> — available: create-branch-name, create-issue, get-commit-template, normalize-title, search-issues, update-issue. 사용법은 `issue_cli <subcommand> --help`로 확인.", "available_subcommands": ["create-branch-name", "create-issue", "get-commit-template", "normalize-title", "search-issues", "update-issue"], "summary": null, "next": null}
```

### 후속 작업 (별도 이슈 권장)
- SKILL.md ↔ CLI 매칭 화이트리스트(`EXPECTED_MISSING`)에 남은 항목 보강.
  특히 `issue`의 `normalize-title`, `create-branch-name`, `get-commit-template` 호출예 추가.
