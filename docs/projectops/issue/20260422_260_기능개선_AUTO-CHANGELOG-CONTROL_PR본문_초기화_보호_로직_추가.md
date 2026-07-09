---
name: 🚀[기능개선][ChangeLog] AUTO-CHANGELOG-CONTROL PR 본문 초기화 보호 로직 추가
description: changelog-deploy가 PR 본문에 Summary를 먼저 작성한 경우 워크플로우가 덮어쓰지 않도록 보호
type: project
---

# 🚀[기능개선][ChangeLog] AUTO-CHANGELOG-CONTROL PR 본문 초기화 보호 로직 추가

- 라벨: 작업전
- 담당자: Cassiiopeia

---

📝 현재 문제점
---

- `changelog-deploy` 스킬이 deploy PR 생성 시 PR 본문에 "Summary by CodeRabbit" 형식으로 릴리스 노트를 작성함
- `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` 워크플로우가 트리거되면 첫 번째 스텝에서 PR 본문을 무조건 초기화함
- `changelog-deploy`가 PR 생성 직후 빠르게 본문을 작성한 경우, 워크플로우가 해당 내용을 덮어써 버림
- 결과적으로 이미 작성된 릴리스 노트가 사라지고 CodeRabbit 폴링 10분을 다시 대기해야 하는 낭비 발생

🛠️ 해결 방안 / 제안 기능
---

- PR 본문 초기화 스텝에서 초기화 전에 현재 본문을 먼저 확인
- 이미 "Summary by CodeRabbit" 문자열이 포함되어 있으면 초기화를 건너뜀
- 해당 경우 `pr_body.md`를 현재 본문 내용으로 즉시 저장하고 `already_found=true` 플래그 설정
- CodeRabbit Summary 요청 스텝: `already_found=true`이면 건너뜀 (불필요한 API 호출 방지)
- CodeRabbit Summary 폴링 스텝: `already_found=true`이면 즉시 `summary_found=true`로 종료 (10분 대기 생략)

⚙️ 작업 내용
---

- `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` 수정
  - `PR 본문 초기화` 스텝: 초기화 전 PR 본문 확인 → Summary 존재 시 건너뜀
  - `CodeRabbit Summary 요청` 스텝: `already_found=true` 조건부 스킵
  - `CodeRabbit Summary 감지(폴링)` 스텝: `already_found=true` 시 즉시 성공 처리

🙋‍♂️ 담당자
---

- 백엔드: -
- 프론트엔드: -
- 디자인: -
