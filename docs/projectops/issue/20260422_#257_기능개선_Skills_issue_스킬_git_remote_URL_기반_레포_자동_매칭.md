---
제목: 🚀[기능개선][Skills] issue 스킬 git remote URL 기반 레포 자동 매칭
라벨: 작업전
---

# 🚀[기능개선][Skills] issue 스킬 git remote URL 기반 레포 자동 매칭

📝 현재 문제점
---

- `issue` 스킬 실행 시 config의 `repos` 배열에서 `default: true`인 레포를 무조건 사용함
- 여러 레포를 사용하는 환경에서 `/issue`를 실행하면 현재 작업 중인 레포가 아닌 default 레포(SUH-DEVOPS-TEMPLATE)로 이슈가 등록됨
- 예: `passQL` 디렉토리에서 `/issue` 실행 시 `passQL-Lab/passQL`이 아닌 `Cassiiopeia/SUH-DEVOPS-TEMPLATE`으로 이슈가 등록되는 문제 발생
- 결국 사용자가 PAT를 직접 알려주고 repo 정보를 수동으로 입력하거나 후처리로 수정해야 하는 불편함 존재
- `skills/issue/SKILL.md`의 Config 확인 절차에 git remote URL 매칭 로직이 누락되어 있음

🛠️ 해결 방안 / 제안 기능
---

- `git remote get-url origin`으로 현재 작업 디렉토리의 레포 정보 추출
- 추출한 `owner/repo`를 config의 `repos` 배열과 대조하여 일치하는 항목을 자동 선택
- 매칭 우선순위: git remote URL 매칭 → `default: true` fallback → 번호 선택
- git remote URL이 없거나 config에 해당 레포가 없을 경우에만 기존 방식(default 또는 선택)으로 동작

⚙️ 작업 내용
---

- [ ] `skills/issue/SKILL.md` Config 확인 절차에 git remote URL 자동 매칭 로직 추가
- [ ] `commit`, `github`, `changelog-deploy`, `report` 등 동일 config를 사용하는 스킬에도 동일 로직 반영 검토
- [ ] `skills/references/config-rules.md`에 레포 자동 매칭 원칙 문서화

🙋‍♂️ 담당자
---

- 백엔드: suhsaechan
