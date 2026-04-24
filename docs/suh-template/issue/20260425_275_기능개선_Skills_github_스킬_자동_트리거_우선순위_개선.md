---
title: "🚀[기능개선][Skills] github 스킬 자동 트리거 우선순위 개선"
labels: [작업전]
assignees: [Cassiiopeia]
---

📝 현재 문제점
---

- 사용자가 "PR 올려줘", "댓글 달아줘", "이슈 확인해줘" 등 GitHub 작업을 요청해도 `cassiiopeia:github` 스킬이 자동으로 트리거되지 않음
- `superpowers:brainstorming` 등 description이 넓은 범용 스킬이 먼저 매칭되어 github 스킬이 후순위로 밀림
- 결과적으로 AI가 잘못된 컨텍스트(현재 레포)로 작업을 시도하다 실패함

🛠️ 해결 방안 / 제안 기능
---

- `skills/github/SKILL.md` description의 트리거 키워드를 더 구체적이고 강력하게 명시
- "PR 생성", "이슈 댓글", "GitHub API" 등 명확한 GitHub 작업 키워드를 description에 추가
- CLAUDE.md Skill routing 테이블에 GitHub 작업 패턴을 우선 트리거로 명시적 등록

🙋‍♂️ 담당자
---

- 백엔드: 이름
- 프론트엔드: 이름
- 디자인: 이름
