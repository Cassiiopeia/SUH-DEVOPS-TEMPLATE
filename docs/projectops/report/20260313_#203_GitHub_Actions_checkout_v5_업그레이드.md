### 📌 작업 개요
GitHub Actions Node.js 20 deprecated 대응으로 전체 워크플로우 파일에서 `actions/checkout` 버전을 `v5`로 일괄 업그레이드.
`actions/checkout@v5`는 Node.js 24를 공식 지원하는 버전으로, 2026년 6월 2일 Node.js 24 강제 전환에 대비.

### 🎯 구현 목표
- 전체 워크플로우에서 `actions/checkout@v4` → `@v5` 업그레이드
- `actions/checkout@v3`으로 남아있던 레거시 파일도 `@v5`로 통일
- `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` 환경변수는 추가하지 않음 (6월 2일에 GitHub가 자동 전환 예정)

### ✅ 구현 내용

#### 1. 루트 워크플로우 업그레이드 (7개 파일, 9개소)
- **파일**: `.github/workflows/` 루트
- **변경 내용**: `actions/checkout@v4` → `actions/checkout@v5`
- **대상 파일**:

| 파일 | 변경 개소 |
|------|----------|
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` | 3 |
| `PROJECT-COMMON-README-VERSION-UPDATE.yaml` | 1 |
| `PROJECT-COMMON-SYNC-ISSUE-LABELS.yaml` | 1 |
| `PROJECT-COMMON-VERSION-CONTROL.yaml` | 1 |
| `PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml` | 1 |
| `PROJECT-TEMPLATE-INITIALIZER.yaml` | 2 |

#### 2. project-types/common 워크플로우 업그레이드 (6개 파일, 8개소)
- **파일**: `.github/workflows/project-types/common/`
- **변경 내용**: `actions/checkout@v4` → `actions/checkout@v5` (5개 파일), `@v3` → `@v5` (1개 파일)
- **대상 파일**:

| 파일 | 변경 전 | 변경 개소 |
|------|--------|----------|
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` | v4 | 3 |
| `PROJECT-COMMON-README-VERSION-UPDATE.yaml` | v4 | 1 |
| `PROJECT-COMMON-SYNC-ISSUE-LABELS.yaml` | v4 | 1 |
| `PROJECT-COMMON-VERSION-CONTROL.yaml` | v4 | 1 |
| `PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml` | v4 | 1 |
| `PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml` | **v3** | 1 |

#### 3. project-types/flutter 워크플로우 업그레이드 (6개 파일, 16개소)
- **파일**: `.github/workflows/project-types/flutter/` 및 `flutter/synology/`
- **대상 파일**:

| 파일 | 변경 전 | 변경 개소 |
|------|--------|----------|
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | v4 | 3 |
| `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` | v4 | 2 |
| `PROJECT-FLUTTER-CI.yaml` | v4 | 3 |
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` | v4 | 3 |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | v4 | 3 |
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml` | **v3** | 2 |

#### 4. project-types/spring 워크플로우 업그레이드 (4개 파일, 6개소)
- **파일**: `.github/workflows/project-types/spring/synology/`
- **대상 파일**:

| 파일 | 변경 전 | 변경 개소 |
|------|--------|----------|
| `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml` | v4 | 1 |
| `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml` | v4 | 3 |
| `PROJECT-SPRING-NEXUS-CI.yml` | v4 | 1 |
| `PROJECT-SPRING-NEXUS-PUBLISH.yml` | **v3** | 1 |

#### 5. project-types/react 워크플로우 업그레이드 (2개 파일, 2개소)

| 파일 | 변경 개소 |
|------|----------|
| `PROJECT-REACT-CI.yaml` | 1 |
| `PROJECT-REACT-CICD.yaml` | 1 |

#### 6. project-types/next 워크플로우 업그레이드 (2개 파일, 2개소)

| 파일 | 변경 개소 |
|------|----------|
| `PROJECT-NEXT-CI.yaml` | 1 |
| `PROJECT-NEXT-CICD.yaml` | 1 |

#### 7. project-types/python 워크플로우 업그레이드 (3개 파일, 5개소)

| 파일 | 변경 개소 |
|------|----------|
| `PROJECT-PYTHON-CI.yaml` | 1 |
| `PROJECT-PYTHON-SYNOLOGY-CICD.yaml` | 1 |
| `PROJECT-PYTHON-SYNOLOGY-PR-PREVIEW.yaml` | 3 |

### 🔧 주요 변경사항 상세

#### checkout 버전 일괄 업그레이드
전체 29개 워크플로우 파일에서 총 48개소의 `actions/checkout` 버전을 `v5`로 변경.
대부분 `v4` → `v5` 변경이며, 3개 파일은 `v3`에서 바로 `v5`로 업그레이드.

| 변경 유형 | 파일 수 | 변경 개소 |
|----------|---------|----------|
| `@v4` → `@v5` | 26 | 45 |
| `@v3` → `@v5` | 3 | 3 |
| **합계** | **29** | **48** |

**v3에서 v5로 업그레이드된 파일**:
- `PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml` (common)
- `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml` (flutter/synology)
- `PROJECT-SPRING-NEXUS-PUBLISH.yml` (spring/synology)

#### FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 미적용 결정
`actions/cache@v4`, `actions/upload-artifact@v4` 등 아직 v5가 출시되지 않은 액션은 현재 상태 유지.
2026년 6월 2일 GitHub 러너 자동 전환 시점에 Node.js 24로 자동 적용되므로, 별도 환경변수 추가 불필요.

### 🧪 테스트 및 검증
- 변경 후 `actions/checkout@v3` 또는 `@v4` 잔존 여부 검색: **0건** (완전 제거 확인)
- 전체 `actions/checkout@v5` 적용 현황: **48개소, 29개 파일** 확인 완료

### 📌 참고사항
- `actions/checkout@v5`는 Node.js 24를 공식 지원하는 버전. 최소 러너 버전 v2.327.1 필요
- `actions/cache`, `actions/upload-artifact`, `actions/setup-java` 등은 v5 미출시 상태이므로 현재 v4 유지
- 2026년 6월 2일 이후 GitHub 러너가 Node.js 24를 기본값으로 전환하면 나머지 액션도 자동 대응됨
- Node.js 24 강제 전환 이전에 사전 테스트가 필요하면 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` 환경변수 추가 가능
