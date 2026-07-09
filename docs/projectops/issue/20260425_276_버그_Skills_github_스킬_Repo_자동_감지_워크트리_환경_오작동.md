---
title: "❗[버그][Skills] github 스킬 Repo 자동 감지 워크트리 환경 오작동"
labels: [작업전]
assignees: [Cassiiopeia]
---

🗒️ 설명
---

- `cassiiopeia:github` 스킬이 `git remote get-url origin`으로 현재 레포를 자동 감지할 때, Claude Code의 primary working directory가 SUH-DEVOPS-TEMPLATE인 경우 `Cassiiopeia/SUH-DEVOPS-TEMPLATE`를 origin으로 잡음
- 사용자가 다른 레포(예: `TEAM-ROMROM/RomRom-BE`) 작업을 요청해도 스킬이 현재 레포를 대상으로 작동함

🔄 재현 방법
---

1. SUH-DEVOPS-TEMPLATE 레포에서 Claude Code 세션 시작
2. `/cassiiopeia:github` 호출 후 다른 레포(RomRom-BE 등)의 PR 생성 요청
3. 스킬이 `git remote get-url origin`으로 SUH-DEVOPS-TEMPLATE을 감지하여 잘못된 레포에 API 호출

📸 참고 자료
---

- 워크트리 환경에서 primary working directory ≠ 작업 대상 레포인 경우 발생
- config의 `repos` 목록에 여러 레포가 등록된 사용자에게 주로 발생

✅ 예상 동작
---

- 스킬 호출 시 대상 레포를 arguments로 명시하거나(`TEAM-ROMROM/RomRom-BE`), config `repos` 목록에서 선택하는 흐름으로 처리
- `git remote get-url origin` 감지 실패 시 자동으로 config repos 목록 선택 UI 제공

⚙️ 환경 정보
---

- **OS**: Windows 11
- **환경**: Claude Code CLI, 멀티 레포 워크트리 환경

🙋‍♂️ 담당자
---

- 백엔드: 이름
- 프론트엔드: 이름
- 디자인: 이름
