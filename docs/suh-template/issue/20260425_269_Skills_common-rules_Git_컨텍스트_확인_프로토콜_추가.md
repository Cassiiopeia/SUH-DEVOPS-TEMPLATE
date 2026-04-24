# 🚀[기능개선][Skills] common-rules Git 컨텍스트 확인 프로토콜 추가

라벨: 작업전
담당자: Cassiiopeia

---

📝 현재 문제점
---

- `skills/references/common-rules.md`의 작업 시작 프로토콜에 Git 컨텍스트를 확인하는 단계가 없어, 코드 수정이 필요한 작업 시 main(default) 브랜치에서 바로 작업을 시작하는 상황이 발생한다.
- 이슈 번호가 없는 브랜치에서 작업이 시작되어도 아무런 경고 없이 진행된다.
- 사용자가 worktree를 사용할지 여부를 선택할 기회가 주어지지 않는다.

🛠️ 해결 방안 / 제안 기능
---

- `common-rules.md` 작업 시작 프로토콜에 **Git 컨텍스트 확인** 단계를 추가한다.
- 코드 수정이 수반되는 작업 시작 전, 아래 흐름을 강제한다:
  1. 현재 브랜치가 main/master이면 즉시 멈추고 사용자에게 이슈 연결 여부를 묻는다.
  2. feature 브랜치이지만 이슈 번호(`YYYYMMDD_#번호_제목` 형식)가 없으면 사용자에게 확인한다.
  3. 이슈가 없으면 새로 생성(`/issue` 스킬)을 권유하되, 사용자가 직접 선택하도록 자유를 준다.
  4. 이슈 번호가 확정되어 새 브랜치가 필요한 경우 worktree 생성 여부를 선택하게 한다.
- 분석·계획 전용 스킬(`/plan`, `/analyze`, `/design-analyze`, `/refactor-analyze`)은 이 프로토콜에서 제외한다.

⚙️ 작업 내용
---

- `skills/references/common-rules.md` — 작업 시작 프로토콜 4단계에 Git 컨텍스트 확인 항목 추가 및 `## Git 컨텍스트 확인 프로토콜` 섹션 신규 추가

🙋‍♂️ 담당자
---

- Skills: Cassiiopeia
