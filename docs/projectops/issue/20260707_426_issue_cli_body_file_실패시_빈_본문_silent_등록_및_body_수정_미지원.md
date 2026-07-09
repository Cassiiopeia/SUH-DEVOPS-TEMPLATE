🗒️ 설명
---

- issue의 `issue_cli.py` create-issue가 body_file 경로를 열지 못하면 에러 대신 **빈 본문("")으로 이슈를 등록**합니다 (silent fallback). 실측: 이슈 #425가 빈 본문으로 등록됐습니다.
- 원인 경로: Windows Git Bash에서 한글 포함 파일 경로가 네이티브 Python argv로 전달되며 깨져 `Path.exists()`가 false가 됨 → "" 등록. CLI는 성공 JSON을 반환하므로 agent가 실패를 감지할 수 없습니다.
- 복구 수단도 없습니다: `issue_cli.py` update-issue와 `github_cli.py` update-issue 모두 body 수정을 지원하지 않습니다 (title/state/labels/assignees만).

🔄 재현 방법
---

1. Windows Git Bash에서 한글이 포함된 본문 파일 경로로 `issue_cli.py create-issue ... "{한글경로}.md" ...` 실행
2. 성공 JSON(`{"number", "url"}`)이 반환되지만 GitHub 이슈 본문은 비어 있음
3. `update-issue`로 본문을 복구하려 해도 body 인자가 없어 불가

📸 참고 자료
---

- `skills/issue/scripts/issue_cli.py:33` — `body = Path(args.body_file).read_text(...) if Path(args.body_file).exists() else ""`
- 실측 사례: #425 빈 본문 등록 → PowerShell Invoke-RestMethod PATCH로 수동 복구
- 함께 발견: 레포명 변경(projectops) 후 구 이름으로 Search API 호출 시 422 반환 (REST와 달리 검색의 repo 한정자는 리다이렉트가 해결되지 않음) — config의 레포명 갱신 필요

✅ 예상 동작
---

- body_file이 존재하지 않으면 빈 본문 등록 대신 즉시 실패해야 함 (예: `{"ok": false, "code": "body_file_not_found"}` — `github_cli.py`의 add-comment는 이미 이렇게 동작)
- create-issue 성공 응답에 body 길이 등 검증 가능한 필드가 포함되어야 함
- update-issue에 body_file 옵션을 추가해 본문 수정/복구가 가능해야 함

⚙️ 환경 정보
---

- **OS**: Windows 11 (Git Bash) — silent fallback 자체는 OS 무관
- **버전**: cassiiopeia 플러그인 3.0.182

🙋‍♂️ 담당자
---

- 템플릿: Cassiiopeia
