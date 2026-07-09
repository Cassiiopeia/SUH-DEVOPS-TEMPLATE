# ⚙️[기능추가][Skills] deploy, changelogfix 스킬 신규 추가

**라벨**: `작업전`
**담당자**: Cassiiopeia

---

📝현재 문제점
---

- deploy PR을 올리면 `AUTO-CHANGELOG-CONTROL` 워크플로우가 CodeRabbit Summary를 최대 10분 대기함
- CodeRabbit rate limit 소진 시 폴백이 동작하지만 커밋 메시지를 그대로 써서 changelog 품질 저하
- automerge 실패 시 수동으로 PR을 다시 만들어야 하는 번거로움 존재
- deploy 관련 작업을 수행하는 전용 스킬 없음

🛠️해결 방안 / 제안 기능
---

### 1. `deploy` 스킬

- `main push → deploy PR 생성 → git diff 분석 → 릴리스 노트 즉시 작성 → PR 본문 업데이트`
- 워크플로우가 `Summary by CodeRabbit` 감지 후 automerge 자동 진행
- CodeRabbit 10분 대기 없이 즉시 처리

### 2. `changelogfix` 스킬 (복구용)

- automerge 실패 시 기존 deploy PR을 닫고 새 PR을 열어 워크플로우 재트리거
- PR 생성 후 즉시 릴리스 노트 작성으로 10분 대기 없이 처리

⚙️작업 내용
---

- [ ] `skills/deploy/SKILL.md` 신규 작성
- [ ] `skills/changelogfix/SKILL.md` 신규 작성
- [ ] `.cursor/skills/` 동기화
- [ ] `CLAUDE.md` Skills 섹션 업데이트
- [ ] `plugin.json`, `marketplace.json` 스킬 수 업데이트

🙋‍♂️담당자
---

- Cassiiopeia
