# ⚙️[기능추가][Skills] Sub-project #6 GitHub Skill 통합 구현

**라벨**: `작업전`
**담당자**: 

---

📝현재 문제점
---

- `/issue` 스킬이 로컬 `.issue/*.md` 파일 생성만 수행하고, GitHub에 실제 이슈를 등록하지 못함
- 브랜치명 계산이 SUH-ISSUE-HELPER GitHub Actions에 의존하여 수 초 딜레이 발생
- `/report` 스킬이 로컬 파일 저장만 수행하고, 해당 이슈에 GitHub 댓글을 자동 포스팅하지 못함
- GitHub를 독립적으로 제어하는 스킬이 없어 이슈 조회·댓글·PR 생성을 수동으로 처리해야 함

🛠️해결 방안 / 제안 기능
---

- `scripts/suh_template/gh_branch.py` 신규 생성: SUH-ISSUE-HELPER TypeScript 로직을 Python으로 포팅, 브랜치명 즉시 로컬 계산
- `scripts/suh_template/gh_client.py` 신규 생성: urllib 표준 라이브러리만 사용하는 GitHub REST API 클라이언트 (외부 의존성 없음)
- `scripts/suh_template/cli.py` 확장: `create-issue`, `add-comment`, `get-issue`, `create-branch-name`, `create-pr` 커맨드 추가, PAT는 `GITHUB_PAT` 환경변수로 전달
- `skills/issue/SKILL.md` 수정: GitHub API로 이슈 실제 생성 → 브랜치명 즉시 계산 → worktree/브랜치 선택지 제공
- `skills/report/SKILL.md` 수정: 이슈 번호 자동 감지 후 GitHub 댓글 자동 포스팅
- `skills/github/SKILL.md` 신규 생성: 이슈 조회·댓글·PR 생성·PR 조회를 독립적으로 수행하는 스킬

⚙️작업 내용
---

- `gh_branch.py`: `normalize_title`, `create_branch_name`, `get_commit_template` 구현 (브랜치명 형식: `YYYYMMDD_#번호_정규화제목`)
- `gh_client.py`: `create_issue`, `add_comment`, `get_issue`, `list_issues`, `create_pull_request` 구현, `GitHubAPIError` 예외 처리
- CLI 커맨드 5개 추가 및 `SUPPORTED_SKILL_IDS`에 `github` 등록
- 테스트 파일 3개 (`test_gh_branch.py`, `test_gh_client.py`, `test_cli_github.py`) — 71 tests passed
- `.cursor/skills/` 동기화 (issue.mdc, report.mdc, github.mdc)

🙋‍♂️담당자
---

- 백엔드: 
- 프론트엔드: 
- 디자인: 
