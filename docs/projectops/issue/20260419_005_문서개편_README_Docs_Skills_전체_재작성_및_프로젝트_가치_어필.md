# 📄[문서][README/Docs] SUH-DEVOPS-TEMPLATE 전체 문서 개편 및 프로젝트 가치 재정의

**라벨**: `작업전`
**담당자**: Cassiiopeia

---

📝현재 문제점
---

- README.md가 단순 기능 나열 수준에 머물러 있어 이 프로젝트가 **왜 중요한지** 전달이 안 됨
- Claude Code Skills 자동화 플로우 (`/issue` → `/commit` → `/report` → `/init-worktree` 등)가 문서 어디에도 제대로 설명되지 않음
- `docs/suh-template/`이 공개 전환되었는데 이 폴더가 무엇인지, 어떤 산출물이 쌓이는지 설명 없음
- 신규 기여자가 "이 템플릿을 쓰면 뭐가 달라지는지" 5분 안에 파악 불가능
- Skills 20개가 있지만 각 스킬의 입출력·연계 플로우가 문서화되어 있지 않음
- 프로젝트의 핵심 가치 — **AI가 개발자의 GitHub 워크플로우 전체를 대신 처리** — 가 README에 전혀 드러나지 않음

🛠️해결 방안 / 제안 기능
---

### 1. README.md 전면 재작성

- 헤더에 "개발자는 코드만 작성하세요" 철학을 강하게 어필
- 기존 툴 대비 차별점 비교 테이블 (GitHub Actions 단독 사용 vs SUH-DEVOPS-TEMPLATE)
- 핵심 자동화 흐름을 ASCII 다이어그램으로 시각화
- 스킬 플로우 한눈에 보기: `/issue` → git worktree → `/commit` → `/report` → PR

### 2. `docs/SKILLS-OVERVIEW.md` 신규 작성

- 전체 20개 스킬 카탈로그 (입력/출력/연계 스킬 명시)
- Claude Code 플러그인 설치부터 첫 커밋까지 5분 퀵스타트
- 스킬 체인 플로우 다이어그램
- `docs/suh-template/` 폴더 구조 및 산출물 설명

### 3. `docs/AUTOMATION-PHILOSOPHY.md` 신규 작성

- 이 프로젝트의 존재 이유: GitHub 워크플로우 완전 자동화
- AI 시대의 개발 생산성 — 이슈 생성부터 배포까지 Claude가 처리
- superpowers 원칙 (사용자 확인 우선, 자동 커밋 금지) 설명
- 실제 사용 시나리오 예시 (before/after)

⚙️작업 내용
---

- [ ] README.md 150줄 이내 재작성 (현재 구조 유지, 내용 강화)
- [ ] `docs/SKILLS-OVERVIEW.md` 신규 작성
- [ ] `docs/AUTOMATION-PHILOSOPHY.md` 신규 작성
- [ ] `docs/` 문서 링크 테이블 README에 반영
- [ ] CLAUDE.md 문서 섹션 업데이트

🙋‍♂️담당자
---

- 문서: Cassiiopeia
