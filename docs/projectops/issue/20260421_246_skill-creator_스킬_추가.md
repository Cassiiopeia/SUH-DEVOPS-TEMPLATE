---
title: "⚙️[기능추가][Skills] skill-creator 스킬 추가 (CREATE/REVIEW/IMPROVE 3모드)"
issue_number: 246
label: 작업전
---

## 📝 현재 문제점

skill을 만들거나 리뷰/개선할 때 일관된 절차와 품질 기준이 없어 skill 품질이 들쭉날쭉해지는 문제.

## 🛠️ 해결 방안

Somansa skill-creator (CREATE / REVIEW / IMPROVE 3모드)를 cassiiopeia 플러그인에 추가.

**추가 파일 목록**:
- `skills/skill-creator/SKILL.md` — 메인 스킬 (모드 판정 + 8대 원칙)
- `skills/skill-creator/references/phase0_brainstorming.md` — 브레인스토밍 절차
- `skills/skill-creator/references/phase1_slots.md` — 6개 슬롯 정의·자동 추론 규칙
- `skills/skill-creator/references/phase2_question_format.md` — 한 번에 하나씩 질문 포맷
- `skills/skill-creator/references/phase4_checklist.md` — 8대 원칙 self-review 체크표
- `skills/skill-creator/references/phase6_report_format.md` — 사용자 보고 표준 포맷
- `skills/skill-creator/references/trigger_optimization.md` — description 최적화 가이드
- `skills/skill-creator/references/anti_patterns.md` — 실패 패턴 모음
- `skills/skill-creator/templates/config.json.example` — 표준 config 구조
- `skills/skill-creator/templates/python_cli_script.py` — stdlib 기반 CLI 뼈대

**3가지 모드**:
- CREATE: 브레인스토밍 → 슬롯 추출 → SKILL.md 작성 → 8대 원칙 검증 → 트리거 검증
- REVIEW: 기존 skill을 8대 원칙 + 공식 모범사례로 검토 → 우선순위별 이슈 리포트
- IMPROVE: 리뷰 결과 선택 반영 → 파일 수정 → 변경 요약 보고
