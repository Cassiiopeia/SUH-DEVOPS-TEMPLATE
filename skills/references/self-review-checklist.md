# Self-Review 체크리스트

3 스킬(`suh-plan` / `suh-analyze` / `suh-implement`)이 산출물 제출 전 자체 검토에 공유하는 체크리스트.
각 스킬의 Self-Review Phase는 방금 작성한 파일을 `Read` 도구로 다시 읽고 아래 체크리스트를 적용한다.

## suh-plan 체크리스트

- [ ] **HARD-GATE — HOW 침범 없는가?**
  - 파일 경로 + 함수명 + 라인 번호 조합 없음
  - "변경 계획" 표 또는 구현 순서 표 없음
  - Before/After 코드 예시 없음
  - HOW가 필요하면 "→ `/suh-analyze`에서 구체화" 한 줄로 대체됨
- [ ] **placeholder 없는가?** "TBD" / "TODO" / "추후 결정" / 빈 섹션 없음
- [ ] **Must/Should/Nice 균형 잡혔는가?** 전부 Must면 우선순위 없음 — 재분류 필요
- [ ] **가정 섹션에 추측한 내용 명시됐는가?** 사용자에게 물어보지 않은 가정은 모두 `## 7. 가정` (`[ASSUMPTIONS]`) 섹션에 기록
- [ ] **이슈 정보가 반영됐는가?** (Phase -1에서 fetch한 경우)
- [ ] **HARD-GATE — Devil's Advocate**: `## 10. [REVIEW_LOG]`에 Architect 시선의 리스크·놓친 시나리오·아키텍처 방향 대안이 **1개 이상** 기록됐는가? (단순 작업이면 "리스크 없음 — 단순 작업 (Fast-Track)" 한 줄 갈음 허용). 비어 있으면 제출 불가 (Stop-and-Think Gate).

문제 발견 시 인라인 수정 후 Phase 4로 진행.

## suh-analyze 체크리스트

- [ ] **HARD-GATE — No Placeholders**: "TBD" / "TODO" / "나중에" / "적절히" / "필요 시" / "유사하게" 어디에도 없음
- [ ] **모든 변경 항목에 파일 경로 + 함수명 + 라인 번호가 있는가?**
- [ ] **Before/After 코드가 실제 파일에서 읽은 내용인가?** (추측 코드 금지)
- [ ] **병렬 가능 태스크에 `[병렬]` 표시됐는가?**
- [ ] **검증 방법이 구체적인가?** (입력값 / 명령 / 기대 결과 모두 명시)
- [ ] **plan.md의 Must 항목이 모두 태스크에 반영됐는가?**
- [ ] **HARD-GATE — Devil's Advocate (Reviewer)**: `## 7. [REVIEW_LOG]`와 `## 8. [ALTERNATIVES_CONSIDERED]`가 **둘 다** 작성됐는가? `[REVIEW_LOG]`에 Red Team 시선의 결함·우회 시나리오·더 나은 대안 1개 이상, `[ALTERNATIVES_CONSIDERED]`에 기각한 HOW 대안 1개 이상 + 기각 이유. (단순 작업이면 각 "Fast-Track" 한 줄 갈음 허용). 비어 있으면 제출 불가 (Stop-and-Think Gate).

문제 발견 시 인라인 수정 후 Phase 4로 진행.

## suh-implement 체크리스트

- [ ] **편집한 모든 파일을 편집 전 1번 이상 Read 했는가?**
- [ ] **plan에 없는 변경을 사용자 합의 없이 끼워 넣지 않았는가?** (발견은 메모리 보관 → Phase 6 후 별건 보고)
- [ ] **검증 명령을 실제로 실행했는가?** 체크리스트만 채우지 않음 — 실제 출력 인용
- [ ] **실패한 검증 결과를 사용자에게 정직하게 보고했는가?** 성공한 척 금지
- [ ] **글로벌 룰 준수**: 사용자 명시 승인 없이 `git commit` / `git push` 자동 실행하지 않았는가?
- [ ] **내부망 룰 준수**: 외부 패키지 다운로드(`npm install` 등)를 자동 실행하지 않았는가?
- [ ] **서브에이전트를 썼다면**, 결과를 메인 컨텍스트에서 한 번 더 통합 검증했는가?
- [ ] **HARD-GATE — Devil's Advocate (SDET)**: "성공 증명"이 아니라 "실패의 반증" 관점에서, 이 변경을 깨뜨릴 invalid input·경계값·실패 모드를 **1개 이상 의도적으로 시도**하고 그 결과를 실제 출력으로 인용했는가? (단순 버그픽스면 핵심 경계 1개 시도로 갈음 허용). 시도 없이 happy path만 확인했으면 Phase 6 진입 불가.

문제 발견 시 인라인 수정 후 Phase 6 Finishing으로 진행.
