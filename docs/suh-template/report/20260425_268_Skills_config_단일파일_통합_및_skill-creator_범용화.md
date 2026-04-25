# 구현 완료 보고 — #268 Skills config 단일 파일 통합 및 skill-creator 범용화

## 개요

분산되어 있던 스킬별 config 파일을 `~/.suh-template/config/config.json` 단일 파일로 통합하고,
skill-creator 스킬에 남아있던 회사 명칭(Somansa)을 제거하여 범용 스킬로 개편했다.

## 변경 파일

- `CLAUDE.md` — config 단일 파일 구조 및 skill_id 네임스페이스 규칙 문서 추가
- `skills/references/config-rules.md` — 단일 파일 구조·네임스페이스·읽기/쓰기 표준 전면 재작성
- `skills/config.json.example` — 전체 config 구조 예시 파일 신규 생성
- `skills/commit/SKILL.md` — config 경로 단일 파일 참조로 수정
- `skills/skill-creator/SKILL.md` — 회사 명칭 제거, 범용화
- `skills/skill-creator/references/phase0_brainstorming.md` — Somansa 명칭 제거
- `skills/skill-creator/references/phase1_slots.md` — Somansa 명칭 제거
- `skills/skill-creator/references/phase4_checklist.md` — Somansa 명칭 제거
- `skills/skill-creator/references/trigger_optimization.md` — Somansa 명칭 제거
- `skills/ssh/SKILL.md` — config 읽기 방식 단일 파일 구조로 수정
- `skills/ssh/config.example.json` — 제거 (config.json.example로 통합)

## 구현 내용

**config 단일 파일 통합**

기존에는 스킬별로 별도 config 파일을 두던 방식에서, 모든 스킬의 config를 `~/.suh-template/config/config.json` 하나로 통합했다.

```json
{
  "global_pat": "...",
  "github": { "repos": [...] },
  "ssh": { "servers": [...] },
  "synology-expose": { ... }
}
```

각 스킬은 `skill_id`를 키로 하는 네임스페이스에 설정을 저장한다.

**config-rules.md 전면 재작성**

- §1: 단일 파일 경로 명시 (`~/.suh-template/config/config.json`)
- §2~3: Read tool로 직접 읽는 방법 표준화 (CLI 호출 금지)
- §4: 스킬별 네임스페이스 구조 정의
- §7: 각 스킬 config 섹션 스키마 문서화

**config.json.example 신규 생성**

전체 config 구조를 예시로 담은 `skills/config.json.example`을 추가해 새 스킬 개발 시 참조 기준으로 삼을 수 있도록 했다.

**skill-creator 범용화**

skill-creator 스킬 내 파일 전반에 남아있던 `Somansa` 명칭을 `cassiiopeia`로 교체하여 범용 스킬로 전환했다.

## 효과

- 스킬간 config 파일 중복 제거 및 일관된 접근 방식 확보
- config 파일 위치를 단일 표준으로 통일하여 유지보수 용이
- skill-creator가 특정 조직에 종속되지 않는 범용 도구로 전환

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/268
