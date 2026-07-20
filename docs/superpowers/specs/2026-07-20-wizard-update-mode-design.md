# npx 마법사 "업데이트" 모드 설계

- 날짜: 2026-07-20
- 배경: 기존 통합 레포에서 `npx projectops@latest`를 실행하면 층5가 "업데이트로 진행합니다"라고
  표시하면서도 메뉴는 신규 설치용 5개 항목만 보여준다. 사용자는 "전체 설치(처음이라면 추천)"를
  업데이트 용도로 골라야 하고, 이후 env 계획 질문과 워크플로우 충돌 3지선다를 매번 통과해야 한다.
  충돌 3지선다의 기본값이 "건너뛰기"라서 엔터만 치면 갱신된 워크플로우가 실제로 반영되지 않는
  함정도 있다.

## 결정 사항

사용자 검토 대기 중 무응답으로 권장안을 채택했다 (변경 원하면 후속 이슈로 조정):

1. 접근: **업데이트 모드 신설** (A안). 라벨 변경(B)이나 완전 무질문 위임(C)이 아니라
   저장된 설정을 재사용하는 전용 경로를 만든다.
2. 충돌 처리: **확인 1회(기본 Y) 후 일괄 .bak 백업+교체**. 단 기존 설치본의 env 실값을
   추출해 새 파일에 이월(carryover)하므로 사용자가 채운 값이 보존된다.
3. AI 스킬: **설치된 IDE만 질문 없이 자동 업데이트**. 미설치 IDE는 건드리지 않는다.

## 동작 설계

### 메뉴 (src/ui/prompts.js selectMode)

- 시그니처를 `selectMode({ update = null } = {})`로 확장. `update = { from, to }`가 오면
  맨 위에 항목을 추가하고 기본 선택으로 둔다.
- 디자인 규칙: 괄호 안의 번잡한 보조 문구를 제거해 라벨 길이를 축약하고, 중간점(`·`) 기호는 혼란을 야기하므로 슬래시(`/`) 혹은 쉼표(`,`)로 대체하여 전면 제거한다.
- 확정된 최종 UI 메뉴 항목 명세 (대안 A 승인안):
  - **`update`**: `업데이트 (v{from} → v{to})`
  - **`full`**: `전체 설치 (버전관리 + 워크플로우 + 템플릿)`
  - **`version`**: `버전 관리 전용 (자동화 시스템)`
  - **`workflows`**: `워크플로우 전용 (GitHub Actions 빌드, 배포)`
  - **`issues`**: `이슈/PR 템플릿 전용`
  - **`skills`**: `AI 스킬 전용 (Claude, Cursor, Gemini, Codex, PI)`
- 기존 테스트 스텁(`selectMode: async () => q.mode`)은 인자를 무시하므로 무수정 호환.

### 통합 범위(mode) 기록 (src/core/version-yml.js)

- template 블록에 `mode: "full|version|workflows"` 한 줄 기록 (buildVersionYml templateOptions).
- parseExisting이 `templateMode`로 읽는다. 기록이 없는 구 version.yml은 null → 업데이트 모드가
  full로 간주 (하위호환).
- issues/skills 모드는 version.yml을 쓰지 않으므로 기록 대상 아님.

### 업데이트 경로 (src/commands/interactive.js)

`mode === "update"`이면 `effectiveMode = existing.templateMode || "full"`로 치환하고
`updateRun = true` 플래그로 아래만 다르게 동작한다:

| 단계 | 기존(전체 설치) | 업데이트 모드 |
|------|----------------|--------------|
| 타입 | detectTypes 재감지 | **저장 types 우선** (없으면 감지) |
| 옵션 축 질문 | 저장값 있으면 생략(현행) | 동일 (저장값 없는 새 축만 질문) |
| 분석 카드 | 표시 + "진행할까요?" 확인 루프 | **표시만 하고 진행** (확인 루프 생략) |
| 경로 | 저장 경로 재사용(현행) | 동일 |
| env 계획 질문 | 매번 질문 | **생략** (기본값 + 충돌 carryover 값) |
| 워크플로우 충돌 | 타입당 3지선다(기본 skip) | **일괄 확인 1회(기본 Y) → 전부 backup+교체**, 거절 시 전부 skip |
| 마이그레이션/고아 정리 | 확인 후 진행 | 동일 (안전 확인 유지) |
| AI 스킬 | "설치할까요?" (기본 N) | **설치된 IDE만 질문 없이 업데이트** |

### env 값 이월 (src/core/wizard-env.js)

- 신규 함수 `extractEnvValues(templateContent, installedContent)`:
  템플릿의 `@wizard ask` 키 각각에 대해 설치본에서 `^\s*KEY:\s*"([^"]*)"` 값을 추출해
  Map으로 반환한다. (치환 시 @wizard 주석은 제거되지만 KEY 라인은 남는다 — setEnvLine 참조.)
- 업데이트 모드에서 충돌 파일들에 대해 교체 전 추출 → envValues로 병합, envUseDefaults=false.
  키가 겹치면 나중 파일 값 (같은 KEY는 같은 의미라 실질 무해).
- auto 키는 resolver가 항상 재계산하므로 이월 대상 아님. 템플릿에서 사라진 키는 자연 소멸,
  새 키는 기본값.

### AI 스킬 (src/commands/skills.js)

- `runSkills(opts)`에 `installedOnly: true` 옵션 추가: 비대화형 apply를
  `status.installed`인 어댑터로 한정. 업데이트 경로가 이 옵션으로 호출한다.

## 하지 않는 것 (YAGNI)

- 비대화형 CLI `--update` 플래그: 비대화형은 이미 저장값 재사용 + force로 동작 — 불필요.
- 업데이트 모드에서 설정 변경 UI: 설정을 바꾸려면 기존 "전체 설치"(수정 메뉴 포함)를 쓰면 된다.
  업데이트 항목의 존재 이유가 "묻지 말고 반영"이므로 섞지 않는다.
- 충돌 파일별 개별 선택: 필요한 사용자는 기존 모드를 쓰면 된다.

## 테스트

1. selectMode: update 전달 시 항목 추가/기본 선택, 미전달 시 현행 5개 (prompts 단위)
2. version.yml: mode 기록 → parseExisting 라운드트립, 구 파일(mode 없음) null
3. interactive 업데이트 경로: 저장 mode 재실행, confirmProjectMenu 미호출, env 계획 미호출,
   충돌 일괄 backup 결정, 거절 시 skip
4. extractEnvValues: 실값 추출, 기본값 파일, 키 없는 파일, CRLF
5. carryover 통합: 실값 가진 설치본 교체 후 새 파일에 값 보존
6. runSkills installedOnly: 설치된 어댑터만 apply
7. 기존 302+ 테스트 무회귀
