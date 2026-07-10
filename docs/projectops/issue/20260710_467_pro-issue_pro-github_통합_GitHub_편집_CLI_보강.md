📝 현재 문제점
---

- 이슈 관련 GitHub 작업을 할 때 `pro-github`를 호출해야 할지 `pro-issue`를 호출해야 할지 헷갈린다. 두 스킬의 경계가 모호하다(둘 다 이슈 조회/수정/검색을 함).
- `github_cli.py`의 이슈/PR 편집 기능이 불완전하다:
  - 댓글은 추가만 되고 수정/삭제 불가
  - 라벨은 전체 교체만 가능 (기존 라벨 유지하며 하나만 추가/제거 불가)
  - 담당자도 전체 교체만 가능 (기존 담당자가 날아감)
  - PR은 생성/목록/본문수정만 되고 머지/닫기/댓글 불가
- 공유 로직(`scripts/common/gh_client.py`)엔 이미 `add_issue_labels`, `get_pull_detail` 등 CLI에 노출 안 된 함수가 있어 활용되지 못했다.

🛠️ 해결 방안 / 제안 기능
---

- **GitHub 작업은 `pro-github` 하나로 통일한다.** `pro-issue`를 완전히 흡수·삭제하고, `/issue` 대신 `/github`(또는 "이슈 만들어줘")로 호출한다.
- **`github_cli.py`가 GitHub 이슈/PR 편집 작업을 전부 커버하도록 서브커맨드를 전면 보강한다.**

⚙️ 작업 내용
---

- `gh_client.py` 신규 함수: `update_comment`, `delete_comment`, `remove_issue_label`, `set_issue_labels`, `add_assignees`, `remove_assignees`, `merge_pull_request` (GitHub REST API 스펙 준수, urllib 주의사항 반영 — 204 파싱금지·한글 라벨 quote·DELETE+body)
- `github_cli.py` 서브커맨드 32종으로 확장:
  - 이슈: create-issue(생성 흡수), list-issues, close-issue, reopen-issue
  - 댓글: list-comments, edit-comment, delete-comment
  - 라벨: list-labels, add-labels(유지+추가), remove-label(하나만·멱등), set-labels(전체교체)
  - 담당자: add-assignees(유지+추가), remove-assignees(일부만)
  - PR: get-pr(verdict 판정), add-pr-comment, close-pr, reopen-pr, merge-pr(405/409/422 구분)
  - 헬퍼: normalize-title, create-branch-name, get-commit-template (issue_cli에서 흡수)
- 이슈 생성 워크플로우(템플릿·중복검사·auto_approve·담당자 첫설정·브랜치명)를 `references/issue-creation.md`로 분리하고 `pro-github`가 라우팅
- `pro-issue` 폴더 삭제 + 전 참조 정리 (CLAUDE.md, README, SKILLS.md, GEMINI.md, AGENTS.md, common-rules, config-rules, pro-changelog-deploy, pro-plan). 스킬 카운트 25종 → 24종
- config 키(`issue.auto_approve`, `default_assignee`)는 하위 호환을 위해 이름 유지
- 테스트: gh_client 신규 함수 + github_cli 신규 서브커맨드 단위 테스트 추가, doc-sync 경로 갱신 (전체 65개 통과)

🙋‍♂️ 담당자
---

- 백엔드: SUH SAECHAN
