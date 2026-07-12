# suh-project-utility 마법사 통합 QA 로그 (2026-07-12)

> npx projectops@latest(4.2.8)를 suh-project-utility(spring, v2.5.81)에 적용하며 단계별로 수집한 피드백/버그.
> flow 종료 후 이슈화 여부·수정 방침을 항목별로 확정한다.

## 환경

- 실행: `npx projectops@latest` → **projectops@4.2.8** (npm 최신)
- 대상: `Cassiiopeia/suh-project-utility` — spring, version.yml 구식 단수 키(`project_type: "spring"`)
- ⚠️ **전제**: npm 4.2.8에는 #470 레거시 마이그레이션 코드가 없음 (develop 미배포).
  → 이 세션은 UX/일반 통합 검증용. 마이그레이션 검증은 로컬 develop 코드로 별도 수행 예정.

## 대상 레포 베이스라인 (마이그레이션 기대값 — develop 코드로 재검증 시 사용)

| 파일 | 레지스트리 | tier | 기대 동작 |
|---|---|---|---|
| PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml | wf-auto-changelog-v2 | safe | 확인 1회 후 .bak 무해화 → RELEASE-CHANGELOG 대체 |
| PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml | wf-syn-secret-upload | confirm | 자동 조치 없음, 안내만 |
| PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml | wf-syn-spring-preview | confirm | 자동 조치 없음, 안내만 |
| PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml.bak (기존재) | — | — | 기존 .bak 덮어쓰기 금지 확인 포인트 |
| SUH-PROJECT-UTILITY-CICD(-BLUEGREEN).yaml | 커스텀 | — | 불가침 |
| version.yml `project_type` 단수 키 | — | — | `project_types: ["spring"]` 배열로 자동 변환 확인 |

---

## 피드백 / 버그 목록

### FB-01. breaking-changes 안내 출력 가독성 저하 (UX)

- **단계**: 스킬 상태 확인 직후 breaking-changes 배너 출력
- **증상**:
  - 구버전→4.2.8 사이 CRITICAL/WARNING 전문이 통째로 덤프되어 벽글이 됨 (2.9.0 / 3.0.186 / 3.0.137 / 4.1.0 / 4.2.0 등 전부)
  - 긴 본문이 터미널 폭에서 어색하게 래핑되고 `║` 박스 경계가 붕괴, 한글이 중간에 깨져 보이는 지점 존재 (`미설�→` 등)
  - 제목+요약 한 줄 수준이 아니라 message 전문을 그대로 출력 → 사용자가 읽기를 포기하게 됨
- **개선 방향(안)**: 버전·제목·1줄 요약만 리스트로 출력하고, 전문은 "자세히 보기" 선택 또는 링크(docs/breaking-changes)로 위임. 박스 폭 고정 대신 터미널 폭 기반 래핑.
- **분류**: 버그라기보다 UX 개선 → flow 끝까지 진행 후 이슈화 예정

### FB-02. 🐛 workflows 모드가 구식 version.yml을 변환하지 않으면서 신 스키마 요구 스크립트를 복사함 (버그)

- **재현**: v2.7.7 통합 레포(단수 `project_type: "spring"`)에 `--mode workflows --force` 실행 (로컬 develop 코드)
- **증상**:
  - 새 `version_manager.py`(.sh 포함)가 복사됨 — 이 스크립트는 단수 키만 있으면 **명시적 실패**(4.1.0 설계)
  - 그런데 workflows 모드는 version.yml에 deploy 블록만 append하고 `project_type` → `project_types` 변환은 안 함
  - 결과: push 시 VERSION-CONTROL / RELEASE-CHANGELOG 등 version_manager를 호출하는 워크플로우 **전부 실패**하는 깨진 중간 상태
  - `metadata.template.version: "2.7.7"`도 안 갱신 → 매 실행마다 breaking-changes 배너 전체 반복 출력
  - `options.synology: true` 구 키도 신 축(deploy/publish/secret_backup) 미변환
- **실측 증거**: 통합 직후 `python3 .github/scripts/version_manager.py get` → "❌ version.yml이 v4.1.0 이전 형식입니다" 오류
- **노출 경로**: 대화형 마법사 메뉴 "워크플로우만" 선택 시 실사용자도 동일하게 밟음 (interactive.js → runWorkflows)
- **기원**: #470과 무관 — 4.1.0 SSOT 전환 때부터 존재한 workflows 모드 설계 갭 (.sh 시절부터 동일)
- **수정 방향(안)**: workflows 모드에서 기존 version.yml이 구식 스키마면 (a) 최소 변환(단수→배열)만 수행, 또는 (b) "full 모드로 실행하세요" 경고 후 중단. 결정 필요.
- **상태**: 이슈 등록 예정

---

## 1차 검증 — workflows 모드 (로컬 develop 코드, 비대화형)

마이그레이션 자체는 **전부 기대대로 동작**:

- ✅ safe: `AUTO-CHANGELOG-CONTROL.yaml` 감지 → `.bak` 무해화 + 사유·버전 안내 출력
- ✅ `RELEASE-CHANGELOG.yaml` 신형 복사됨
- ✅ confirm: SYNOLOGY 2건 자동 조치 없이 안내만 (파일 무변경)
- ✅ 기존 `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml.bak` 불가침
- ✅ 커스텀 `SUH-PROJECT-UTILITY-CICD(-BLUEGREEN).yaml` 불가침
- ℹ️ `.bak`은 대상 레포 자체 `.gitignore`(`*.bak`)에 걸려 git 미추적 — 의도상 무해(원본은 git 히스토리에 있음)
- 🐛 version.yml 스키마 미변환 → FB-02

## 2차 검증 — full 모드 (1차 상태 위에 재실행 = 멱등성 동시 검증)

- ✅ **마이그레이션 멱등**: safe 티어 재감지 0건 (.bak 재처리 없음), confirm 2건만 반복 안내
- ✅ version.yml 완전 재생성: `project_types: ["spring"]` + `project_paths` + 신 옵션 축(deploy/publish/secret_backup/changelog) + template.version 4.2.8
- ✅ 기존 버전값 보존: version 2.5.81 / version_code 148
- ✅ `version_manager.py get` 정상 완주 — build.gradle(멀티모듈 2곳) 동기화 확인
- ✅ SYNOLOGY 2건·커스텀 CICD 2건 여전히 무변경 (git diff 없음)

### FB-03. 완료 요약 "새로 설치됨" 목록이 실제 설치와 무관 (UX/정확성)

- **증상**: `새로 설치됨 (0개):` 라면서 파일 9개 나열. 심지어 레거시 `PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml`도 "새로 설치됨"으로 표기
- **원인**: `src/ui/summary.js` — 카운터는 실제 복사 수(`workflowsCopied`)인데 목록은 대상 레포 workflows 디렉토리 스캔(존재하는 PROJECT-* 전부). .sh L5505 이식 시절부터의 동작
- **개선 방향**: 복사 엔진이 반환하는 실제 복사 파일 목록을 그대로 출력 (스캔 제거)

### FB-04. 구 `options.synology: true` → 신 축 미승계 (관찰)

- **증상**: 구 키 `synology: true`인 레포를 full 통합해도 `secret_backup: false`로 확정됨 (nexus/npm_publish만 자동 변환 대상)
- **판단 필요**: synology:true를 secret_backup=true로 승계할지, 아니면 대화형 질문에 맡길지. 비대화형(--force) 업데이트에서만 체감되는 갭

## 대상 레포 후속 조치 필요 (suh-project-utility 자체)

- 레포가 main 단일 브랜치 운영(구 브랜치 전략)이면 3.0.186 develop/main 전환 절차 선행 필요 — RELEASE-CHANGELOG은 develop→main PR 트리거
- confirm 티어 SYNOLOGY 2건: 신형(PR-PREVIEW·SECRET-FILE-UPLOAD) 전환 확인 후 수동 삭제
- 통합 결과 커밋은 사용자 리뷰 후 진행
