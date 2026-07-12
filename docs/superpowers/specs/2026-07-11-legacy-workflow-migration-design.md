# 레거시 템플릿 마이그레이션 시스템 (마법사 통합) — 설계

> 관련 조사: e:\github 전수 스캔 (2026-07-11) — 템플릿 통합 레포 14개 전부 레거시 잔재 보유 (template 1.x~4.0.4 혼재, 절반은 template 메타 자체가 없음)

## 문제

- 템플릿이 2년간 워크플로우를 여러 번 리네임/폐기했지만(1세대 `PROJECT-*` → 2세대 `PROJECT-COMMON-*` → SYNOLOGY 폐기 → `AUTO-CHANGELOG-CONTROL`→`RELEASE-CHANGELOG`), 마법사 복사 엔진은 **새 파일만 추가하고 구 파일을 치우지 않는다.**
- 결과: 실측으로 `PROJECT-VERSION-CONTROL.yaml`(구) + `PROJECT-COMMON-VERSION-CONTROL.yaml`(신)이 **공존 → 버전 이중 증가**, QA 봇 중복 생성, 릴리스 PR 이중 처리 등 실사고 각.
- 절반의 레포는 version.yml에 `metadata.template.version`이 아예 없어 **버전 번호 기반 마이그레이션은 불가능** — 신호(파일 존재) 기반이어야 한다.

## 결정 사항

**신호 기반·멱등·단일 레지스트리 마이그레이션.** 버전 번호를 믿지 않고 "구 산출물이 존재하는가"로 감지한다. (#464 IDE 레거시 정리, #439 version.yml 키 변환과 동일 철학.)

### 아키텍처 (확장성 — 마이그레이션은 여기 한 곳에 모은다)

```
src/core/migrations/
├── index.js       # runMigrations(ctx) 단일 진입점: detect 전체 → 계획 카드 → 확인 → apply
├── registry.js    # MIGRATIONS 배열 — 유일한 관리 지점. 앞으로 리네임/폐기 시 여기 한 줄 추가
└── rules/
    └── obsolete-workflows.js   # 카테고리 구현 (v1). 후속: claude-commands, root-files 등 추가
```

레지스트리 항목 스키마:

```js
{
  id: "wf-auto-changelog-control",
  category: "workflow",              // 카테고리별 rules/ 구현이 detect/apply 담당
  tier: "safe" | "confirm",          // 아래 2-티어 정책
  file: "PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml",  // 정확한 파일명 (글롭 금지)
  replacedBy: "PROJECT-COMMON-RELEASE-CHANGELOG.yaml", // 대체 신형 (없으면 null)
  since: "4.3.0",
  reason: "릴리스 워크플로우 리네임 — 공존 시 릴리스 PR 이중 처리",
}
```

### 2-티어 안전 정책 (실측 근거)

| tier | 대상 | 동작 |
|------|------|------|
| **safe** | 순수 리네임/대체 관계 — 신형이 같은 기능을 대신함. 공존 시 이중 트리거 실해 (VERSION-CONTROL·README-VERSION-UPDATE·SYNC-ISSUE-LABELS·ISSUE-COMMENT/ISSUE-HELPER-API·AUTO-CHANGELOG-CONTROL·COMQA/QA봇·TEMPLATE-UTIL-VERSION-SYNC·SUH-LAB-APP-BUILD-TRIGGER·NEXT-* 등) | 계획 카드 표시 → 확인 1회 → `.bak` 무해화. `--force`는 자동 적용+로그 |
| **confirm** | 배포 파이프라인일 수 있는 CICD류 (SYNOLOGY-* 계열, 1세대 PROJECT-SPRING-CICD·PROJECT-PYTHON-CICD·PROJECT-ANDROID-CICD·IOS-TESTFLIGHT-CICD·AUTO-FILE-UPLOAD·NEXUS-PUBLISH 등) — **그 레포의 유일한 현역 배포일 수 있음** | 자동으로 건드리지 않는다. 계획 카드에 "구세대 배포 워크플로우 — 신형 전환 후 수동 정리 권장"으로 안내만. `--force`에서도 불변 |

### 적용 방식

- 삭제가 아니라 **`<이름>.bak` 리네임** — GitHub Actions는 `.bak`을 실행하지 않으므로 즉시 무해화 + 복원 가능 (기존 copy-workflows `.bak` 컨벤션 동일). 기존 `.bak` 충돌 시 구 `.bak` 제거 후 리네임 (Windows rename 실패 방지).
- **정확한 파일명 매칭만** — 글롭/폴더 삭제 금지. 사용자가 리네임·커스텀한 파일(예: MapSy-BE의 `PROJECT-SPRING-SYNOLOGY-MAPSEE-CICD.yaml`, RomRom의 `ROMROM-*`)은 목록에 없으므로 자동 보호.
- **멱등**: 재실행 시 `.yaml`이 이미 없으면 감지 0건 → 조용히 통과.

### 마법사 배선

- 위치: 업데이트 플로우에서 breaking-check 확인 게이트 **직후**, 워크플로우 복사 **직전** (full/workflows 모드 공통 — 신규 통합은 감지 0건이라 자연 no-op).
- 계획 카드: 파일별 `reason`·`since`·`replacedBy` 표시. safe 티어는 일괄 확인, confirm 티어는 안내 목록만.
- 요약 카드에 "레거시 정리: N개 무해화(.bak), M개 수동 확인 권장" 한 줄.

### 초기 레지스트리 데이터 (e:\github 14개 레포 실측 전수)

**safe 티어:**
`PROJECT-VERSION-CONTROL.yaml`, `PROJECT-README-VERSION-UPDATE.yaml`, `PROJECT-SYNC-ISSUE-LABELS.yaml`, `PROJECT-ISSUE-COMMENT.yaml`, `PROJECT-AUTO-CHANGELOG-CONTROL.yaml`, `PROJECT-COMMON-ISSUE-COMMENT.yaml`, `PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml`, `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`, `COMQA-ISSUE-CREATION-BOT.yaml`, `TEMPLATE-UTIL-VERSION-SYNC.yml`, `sync-issue-labels.yaml`, `PROJECT-COMMON-PROJECT-BACKLOG-MANAGER.yaml`, `PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml`, `PROJECT-NEXT-CI.yaml`, `PROJECT-NEXT-CICD.yaml`, `PROJECT-FLUTTER-ANDROID-PR-CI.yaml`(→CI 흡수), `PROJECT-FLUTTER-CI.yml`(구 확장자 — 현행 `.yaml`)

**confirm 티어 (안내만):**
SYNOLOGY 계열(`PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml`, `PROJECT-SPRING-SYNOLOGY-NONSTOP-CICD.yaml`, `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml`, `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml`, `PROJECT-PYTHON-SYNOLOGY-CICD.yaml`, `PROJECT-PYTHON-SYNOLOGY-PR-PREVIEW.yaml`, `PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml`), 1세대 배포류(`PROJECT-SPRING-CI.yaml`, `PROJECT-SPRING-CICD.yaml`, `PROJECT-PYTHON-CICD.yaml`, `PROJECT-ANDROID-CICD.yaml`, `PROJECT-IOS-TESTFLIGHT-CICD.yml`, `PROJECT-FLUTTER-IOS-CICD.yaml`, `PROJECT-SPRING-AUTO-FILE-UPLOAD.yaml`, `PROJECT-FLUTTER-AUTO-FILE-UPLOAD.yaml`, `PROJECT-PYTHON-AUTO-FILE-UPLOAD.yaml`, `PROJECT-NEXUS-PUBLISH.yml`, `PROJECT-NEXUS-MODULE-CI-BUILD-CHECK.yml`, `PROJECT-CI-BUILD-CHECK.yml`, `PROJECT-PUBLISH.yml`, `PROJECT-DEPLOY-TRIGGER.yaml`, `PROJECT-FILE-AUTO-UPLOAD.yaml`)

> 구현 시 이 목록을 (히스토리 전수 삭제/리네임 기록) ∪ (14개 레포 실측) − (현행 배포 세트)로 재검증해 확정한다.

## 테스트 전략

1. 단위: detect(있음/없음/`.bak`만 있음), apply(.bak 리네임·기존 .bak 충돌·멱등), tier 분리(confirm은 불변), 사용자 커스텀 파일 불가침
2. **실물 검증**: RomRom-FE fresh clone(scratchpad)에 로컬 마법사(`node bin/projectops.js --mode workflows --force`) 실행 → safe 티어 구파일이 `.bak`으로 바뀌고 confirm 티어·`ROMROM-*`·`chuseok22-*`는 불변임을 diff로 확인. suh-logger(1세대)·EarLocAlert(4.0.4)로 세대별 교차 검증
3. 회귀: 기존 copy-workflows·wizard 테스트 전체 green

## 범위 밖 (후속 카테고리 — 레지스트리 구조가 이미 수용)

- `.claude/commands/` 1.x 커맨드 잔재 정리 (현행 clone에선 비어 있어 시급성 낮음)
- 루트 구 파일 (`SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md` 등)
- version.yml `metadata.template.source` 구 표기(`SUH-DEVOPS-TEMPLATE`) 갱신 — 마법사 업데이트가 이미 재작성하는지 확인 후 필요 시 추가
