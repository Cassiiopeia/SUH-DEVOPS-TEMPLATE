---
title: 📄[문서][README] README, SKILLS.md Skills 목록 24종으로 전면 개편
labels: [작업전]
assignees: [Cassiiopeia]
---

📝 현재 문제점
---

- README.md와 docs/SKILLS.md에 Skills 개수가 `20종` / `21종`으로 혼재되어 실제 구현된 24개와 불일치
- `changelog-deploy`, `github`, `skill-creator` 3개 스킬이 문서에서 완전히 누락됨
- 개발 사이클 flowchart에 `changelog-deploy`(배포 자동화) 단계가 반영되지 않아 실제 워크플로우와 괴리
- 시나리오별 추천 흐름 표에도 배포 단계가 빠져 있어 사용자가 전체 사이클을 파악하기 어려움

🛠️ 해결 방안 / 제안 기능
---

- README.md, docs/SKILLS.md 전체에서 Skills 개수를 `24종`으로 통일
- 누락된 3개 스킬 섹션 추가
  - `changelog-deploy`: main push → deploy PR 생성 + 릴리스 노트 작성 + automerge
  - `github`: GitHub 이슈/PR/댓글 독립 조회 및 관리
  - `skill-creator`: Skill 생성/리뷰/개선 3모드
- flowchart에 `changelog-deploy` 노드 추가 (PR 등록 → deploy PR + automerge)
- 시나리오별 추천 흐름 표 끝에 `changelog-deploy` 단계 추가
- 단건 작업 표에 3개 신규 스킬 항목 추가

⚙️ 작업 내용
---

- `README.md`: 개수 표기 일괄 수정, 개발 사이클 자동화 표에 `changelog-deploy`/`github` 추가, 문서/산출물 생성형 표에 `skill-creator` 추가, flowchart 수정
- `docs/SKILLS.md`: 개수 표기 수정, 개발 사이클 자동화 섹션에 3개 스킬 상세 설명 추가, flowchart 및 시나리오 표 수정

🙋‍♂️ 담당자
---

- 문서: Cassiiopeia
