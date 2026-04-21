# 🚀[기능개선][Config] config 시스템 글로벌 단일 파일 구조로 개편

**라벨**: 작업전  
**담당자**: Cassiiopeia

---

📝 현재 문제점
---

- 프로젝트별 로컬 config(`.suh-template/config/issue.config.json`)가 프로젝트 루트에 생성되어 레포 오염 위험이 있음
- `.gitignore` 실수 시 GitHub PAT 등 민감 정보가 커밋에 포함될 수 있음
- `github_pat`과 `github_repos`가 하나의 필드에 혼재되어 레포 추가 시 PAT가 담긴 파일을 직접 수정해야 함
- 레포별 PAT 분리가 불가능한 구조

🛠️ 해결 방안 / 제안 기능
---

- config를 글로벌 단일 파일(`~/.suh-template/config/config.json`)로 일원화
- 프로젝트별 로컬 config 폐지 — 레포와 config 완전 분리
- `global_pat` + `repos[].pat` 구조 도입: 레포별 PAT가 있으면 개별 사용, 없으면 `global_pat` fallback
- 관련 스킬(`issue`, `commit`, `github`, `report`, `changelog-deploy`) 및 `config-rules.md` 전면 업데이트

⚙️ 작업 내용
---

- `skills/references/config-rules.md` — 경로·스키마·읽기 규칙 전면 재작성
- `skills/issue/SKILL.md` — config 읽기/쓰기 로직 새 구조 반영
- `skills/commit/SKILL.md` — PAT 읽기 로직 수정
- `skills/github/SKILL.md` — PAT + repos 읽기 로직 수정
- `skills/report/SKILL.md` — PAT + repos 읽기 로직 수정
- `skills/changelog-deploy/SKILL.md` — 하드코딩된 config 경로 및 PAT 추출 로직 수정

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
