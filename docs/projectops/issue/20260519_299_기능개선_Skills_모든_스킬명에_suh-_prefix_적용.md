# 🚀[기능개선][Skills] 모든 스킬명에 suh- prefix 적용

- 라벨: 작업전
- 담당자: Cassiiopeia

---

📝 현재 문제점
---

- `cassiiopeia` 플러그인의 스킬명이 `report`, `commit`, `review`, `test`, `build`, `plan`, `analyze`, `issue` 등 범용(generic) 이름을 사용하고 있음
- 다른 레포(예: `somansa-tools`)의 동일 이름 스킬과 충돌 발생 → 예: `report` 스킬이 다른 플러그인의 `report`와 겹쳐 오작동
- 플러그인 네임스페이스(`cassiiopeia:report`)로 구분되지만, 슬래시 커맨드 입력 시 모호성 존재

🛠️ 해결 방안 / 제안 기능
---

- 모든 스킬명에 `suh-` prefix를 추가하여 네이밍 충돌 원천 차단
- 대상: `skills/` 하위 전체 스킬 폴더명 + `SKILL.md` description + `CLAUDE.md` 스킬 라우팅 표
- `suh-spring-test`는 이미 `suh-` prefix가 있으므로 유지

⚙️ 작업 내용
---

- `skills/` 하위 24개 폴더명 rename (예: `report` → `suh-report`, `commit` → `suh-commit`)
- 각 `SKILL.md`의 name/description 필드 업데이트
- `CLAUDE.md` 스킬 라우팅 표 및 Skills 목록 전면 업데이트
- `.claude-plugin/` 매니페스트 스킬명 업데이트
- `README` 및 관련 문서 업데이트

🙋‍♂️ 담당자
---

- Cassiiopeia
