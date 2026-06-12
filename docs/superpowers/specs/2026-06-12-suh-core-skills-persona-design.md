# SUH 3종 코어 스킬 페르소나 강화 — 설계 (Design Spec)

작성일: 2026-06-12
관련 자산: `harness/PERSONA.md`, `harness/WORKFLOW.md`, `skills/suh-plan`, `skills/suh-analyze`, `skills/suh-implement`, `skills/references/`

---

## 1. 한 줄 요약

PI 에이전트에만 주입되고 Claude Code 스킬에선 죽어있는 harness의 5개 전문가 페르소나와 6대 마인드셋·품질 강제 메커니즘(Devil's Advocate, Stop-and-Think Gate, Anti-Confirmation Bias)을, `suh-plan / suh-analyze / suh-implement` 3종 스킬에 HARD-GATE로 강제 주입해 에이전트가 항상 일관적이고 요구사항에 정확히 맞는 결과를 내도록 구현력을 끌어올린다.

## 2. 배경 / 문제 정의

- `harness/PERSONA.md`·`WORKFLOW.md`에는 Architect/Developer/Reviewer/SDET/Frontend 5개 전문가 페르소나와, Outcome-Focused Autonomy·Anti-Confirmation Bias·Devil's Advocate·Stop-and-Think Gate 같은 강력한 품질 강제 장치가 있다.
- 그러나 이 자산은 **PI(pi-coding-agent) 전용으로만** 시스템 프롬프트에 주입되고, Claude Code에서 3종 스킬을 실행할 때는 전혀 활용되지 않는다.
- 현재 3종 스킬은 superpowers(writing-plans·executing-plans·finishing·verification) 패턴은 이미 흡수했으나, 페르소나 기반의 "의심 → 대안 → 적대적 자기검증" 루프가 없어 품질이 매 실행마다 들쭉날쭉하다.

## 3. Definition of Done

1. **페르소나가 실제로 작동한다** — 3종 스킬 실행 시 자기 페르소나 카드 + 6대 마인드셋이 명시적으로 로드되어 행동에 반영된다.
2. **일관성이 강제된다** — HARD-GATE(리뷰 로그 저장 전 다음 단계 진입 금지) + Devil's Advocate(결함 1개 이상 의무 지적)로 같은 수준의 검증을 거친 결과만 통과한다.
3. **요구사항 적합성이 올라간다** — Anti-Confirmation Bias, 대안 비교, 코드 인용 기반 분석, Pre-mortem/파괴적 검증으로 "그럴듯하지만 빗나간" 결과를 걸러낸다.
4. **single source가 보존된다** — PI harness 원본은 미변경. 강화 로직은 `skills/references/` 공유 자산 + 3종 SKILL.md에만 반영해 중복 없이 유지보수된다.

## 4. 범위 경계

- **In scope**: `suh-plan` / `suh-analyze` / `suh-implement` 3종 SKILL.md + 공유 references (`personas.md` 신설, `self-review-checklist.md`·`common-rules.md` 강화)
- **Out of scope**: PI harness 원본(`harness/PERSONA.md`·`WORKFLOW.md`) 수정, 나머지 스킬(review/test 등), 산출물 디렉토리 구조 변경(기존 `docs/suh-template/plan`·`analyze/` 유지)

---

## 5. 결정 사항 (사용자 승인 완료)

| 결정 | 선택 |
|------|------|
| 페르소나 통합 방식 | **스킬별 단일 페르소나 바인딩** (plan=Architect, analyze=Architect+Reviewer, implement=Developer+SDET) |
| 산출물 체계 | **기존 plan/analyze 구조 유지 + 품질 섹션 강화** (`[REVIEW_LOG]`·`[ALTERNATIVES_CONSIDERED]`·`[ASSUMPTIONS]` 블록 추가) |
| 작업 범위 | **3종 스킬 + 공유 references만** (PI harness는 single source 보존) |
| 품질 강제 강도 | **HARD-GATE로 강제** + 단순 작업 Fast-Track 예외(harness Rule 8) |

---

## 6. 아키텍처

```
skills/
├── references/
│   ├── personas.md              [신설] harness/PERSONA.md → 한국어 Claude Code용 재작성, single source
│   ├── self-review-checklist.md [강화] 3종 모두 Devil's Advocate 게이트 항목 추가
│   └── common-rules.md          [소폭] 작업 시작 프로토콜에 페르소나 로드 한 줄
├── suh-plan/SKILL.md            [강화] System Architect 바인딩
├── suh-analyze/SKILL.md         [강화] System Architect + Reviewer 바인딩
└── suh-implement/SKILL.md       [강화] Software Developer + SDET 바인딩
```

### 스킬 ↔ 페르소나 매핑

| 스킬 | 주(主) 페르소나 | 부(副) 페르소나 | 핵심 강제 행동 |
|------|----------------|----------------|---------------|
| suh-plan | System Architect | — | Intentional Doubt, 아키텍처 방향 대안 비교, `[REVIEW_LOG]` |
| suh-analyze | System Architect | Reviewer | 코드 인용 + Red Team 적대 검증, `[REVIEW_LOG]` + `[ALTERNATIVES_CONSIDERED]` |
| suh-implement | Software Developer | SDET | Pre-mortem, Surgical Precision, Destructive Testing |

---

## 7. 컴포넌트별 상세 설계

### 7.1 `references/personas.md` (신설)

harness/PERSONA.md(영문 PI 전용)를 한국어 + Claude Code 스킬 문맥으로 옮긴 single source.

담을 내용:
- **공통 마인드셋 6종** (harness Core Philosophy 흡수): Outcome-Focused Autonomy, Proactive Excellence, Anti-Confirmation Bias(자기 가설 의심), Value-Driven Evaluation, Zero Flattery(군더더기 금지), Intellectual Humility
- **5개 페르소나 카드**: Architect / Developer / Reviewer / SDET / Frontend — 각 Objective + Core Responsibilities
- **스킬↔페르소나 매핑 표** (위 §6)
- 각 스킬이 "시작 전"에서 이 파일의 자기 페르소나 카드를 로드하도록 안내

### 7.2 `suh-plan/SKILL.md` (강화 — System Architect)

1. **"시작 전"에 페르소나 로드** — `references/personas.md`의 System Architect 카드 + 공통 마인드셋.
2. **Phase 1 질문에 Intentional Doubt 강제** — 사용자 지시를 액면 그대로 받지 말고 숨은 의도·누락 제약·모호함 1개 이상 파고든다. (기존 §8 미해결 질문과 연결)
3. **plan 템플릿 품질 블록**:
   - `## 7. 가정` → `[ASSUMPTIONS]` 형식 명시
   - 신설 `## 10. [REVIEW_LOG] — Architect 자기검증` (HARD-GATE): 최소 1개 리스크·놓친 시나리오·대안 방향 기록. 단 plan은 WHAT 단계 → 대안은 **아키텍처 방향 수준**까지만(파일/함수 단위 금지).
4. **Phase 3 Self-Review에 Stop-and-Think Gate** — `[REVIEW_LOG]` 물리적 작성 확인, 없으면 제출 불가.
5. **Fast-Track 예외** — 단순 작업이면 `[REVIEW_LOG]`를 "리스크 없음 — 단순 작업" 한 줄로 갈음.
6. **불변**: HOW 침범 HARD-GATE, WHAT 경계, 산출 경로.

### 7.3 `suh-analyze/SKILL.md` (강화 — Architect + Reviewer)

1. **"시작 전" 이중 페르소나 로드** — Architect(HOW 설계) + Reviewer(자기 계획 공격).
2. **Phase 1 정찰에 Pre-mortem 강제** — "이 계획이 미래에 깨진다면 원인은?" 호출자 영향·동시성·하위호환 능동 탐색.
3. **산출물 템플릿 품질 블록**:
   - `## 4. 위험 & 완화` → `[RISK]` 형식 강화, Red Team edge case 명시
   - 신설 `## 7. [REVIEW_LOG] — Reviewer 적대적 검증` (HARD-GATE): 최소 1개 결함·우회 시나리오·더 나은 대안을 적대적으로 지적
   - 신설 `## 8. [ALTERNATIVES_CONSIDERED]` (HARD-GATE): 채택한 HOW 외 기각 대안 1개 이상 + 기각 이유 (analyze는 HOW 단계라 구현 수준 대안 비교 허용)
4. **Phase 3 Self-Review에 Stop-and-Think Gate** — `[REVIEW_LOG]` + `[ALTERNATIVES_CONSIDERED]` 둘 다 없으면 제출 불가.
5. **불변**: No Placeholders HARD-GATE, 파일+함수+라인 인용, Before/After 코드.

### 7.4 `suh-implement/SKILL.md` (강화 — Developer + SDET)

1. **"시작 전" 이중 페르소나 로드** — Developer(Phase 2 구현) + SDET(Phase 3 검증).
2. **Phase 2에 Surgical Precision 강제** — 필요/관련 부분만 외과적 수정, 무관 블록 일괄 변경 금지.
3. **Phase 3 검증을 SDET Destructive Testing으로 격상** — "성공 증명"이 아니라 "실패의 반증". invalid input·경계값·실패 모드 1개 이상 의도적 시도. 내부망 제약은 사용자 위임 유지.
4. **Phase 5 Self-Review에 Devil's Advocate** — "SDET로서 이 변경을 깨뜨릴 입력/경계 1개 이상 시도했는가?" implement는 산출 md 없으므로 `[REVIEW_LOG]`는 메모리 보관 → Phase 6 사용자 보고.
5. **Fast-Track 일관성** — 단순 버그픽스는 파괴적 검증 1개로 갈음.
6. **불변**: 편집 전 Read, plan 범위 준수, 커밋 금지, 내부망 룰, Phase 6 Finishing.

### 7.5 `references/self-review-checklist.md` (강화)

3종 체크리스트 각각에 Devil's Advocate 항목 1줄씩:
- plan: `[REVIEW_LOG]에 리스크/놓친 시나리오 1개 이상 기록됐는가?`
- analyze: `[REVIEW_LOG] + [ALTERNATIVES_CONSIDERED] 둘 다 작성됐는가?`
- implement: `SDET로서 파괴적 검증 1개 이상 시도 + 결과 인용했는가?`

### 7.6 `references/common-rules.md` (소폭)

"작업 시작 프로토콜"에 한 줄: "코드 스킬은 `references/personas.md`에서 자기 페르소나 카드를 로드한다."

---

## 8. 변경 요약

| 파일 | 변경 | 효과 |
|------|------|------|
| `references/personas.md` | 신설 | 5 페르소나 + 6 마인드셋 single source (한국어) |
| `references/self-review-checklist.md` | 강화 | 3종 모두 Devil's Advocate 게이트 |
| `references/common-rules.md` | 소폭 | 페르소나 로드 프로토콜 |
| `suh-plan/SKILL.md` | 강화 | Architect 의심·`[REVIEW_LOG]`·`[ASSUMPTIONS]` |
| `suh-analyze/SKILL.md` | 강화 | Reviewer 적대검증·`[REVIEW_LOG]`·`[ALTERNATIVES_CONSIDERED]` |
| `suh-implement/SKILL.md` | 강화 | SDET 파괴적 검증·Surgical Precision |

## 9. 위험 & 완화

- **위험**: 페르소나 주입이 단순 작업까지 무겁게 만들어 실용성 저하 → **완화**: 모든 HARD-GATE에 Fast-Track 예외(harness Rule 8) 명시.
- **위험**: harness와 personas.md 내용이 갈라져 single source 깨짐 → **완화**: personas.md 상단에 "harness/PERSONA.md 기반, PI 동기화 시 함께 검토" 주석. (양방향 강제는 out of scope)
- **위험**: 기존 HARD-GATE(HOW 침범, No Placeholders)와 신규 게이트 충돌 → **완화**: 신규는 기존 위에 얹는 추가 레이어, 기존 규칙 문구는 보존.

## 10. 검증 방법

- [ ] personas.md에 5 페르소나 + 6 마인드셋 + 매핑표 존재
- [ ] 3종 SKILL.md 각각 "시작 전"에 페르소나 로드 지시 존재
- [ ] suh-plan 템플릿에 `[REVIEW_LOG]`·`[ASSUMPTIONS]`, Self-Review에 게이트 존재
- [ ] suh-analyze 템플릿에 `[REVIEW_LOG]`·`[ALTERNATIVES_CONSIDERED]`, Self-Review에 게이트 존재
- [ ] suh-implement Phase 3 SDET 파괴적 검증, Phase 5 Devil's Advocate 존재
- [ ] self-review-checklist 3종 모두 Devil's Advocate 항목 존재
- [ ] 각 게이트에 Fast-Track 예외 명시
- [ ] PI harness 원본 미변경 (git diff로 확인)

## 11. 다음 단계

이 spec 승인 후 → 구현 (references 신설/강화 → 3종 SKILL.md 강화 순). 각 스킬은 분석 전용/구현 스킬이므로 코드 빌드 검증은 불필요, 문서 일관성 검증만 수행.
