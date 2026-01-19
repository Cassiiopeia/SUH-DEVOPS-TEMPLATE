# SUH-DEVOPS-TEMPLATE

완전 자동화된 GitHub 프로젝트 관리 템플릿

> 개발자는 코드만 작성하세요. 버전 관리, 체인지로그, 배포는 자동으로 처리됩니다.

---

## 프로젝트 개요

### 지원 프로젝트 타입
| 타입 | 설명 | 버전 동기화 파일 |
|------|------|-----------------|
| `spring` | Spring Boot | `build.gradle` |
| `flutter` | Flutter | `pubspec.yaml` |
| `react` | React.js | `package.json` |
| `next` | Next.js | `package.json` |
| `node` | Node.js | `package.json` |
| `python` | FastAPI/Django | `pyproject.toml` |
| `react-native` | React Native CLI | `Info.plist` + `build.gradle` |
| `react-native-expo` | Expo | `app.json` |
| `basic` | 범용 | `version.yml`만 |

---

## 폴더 구조

```
suh-github-template/
├── .github/
│   ├── workflows/                          # GitHub Actions
│   │   ├── PROJECT-TEMPLATE-INITIALIZER.yaml
│   │   ├── PROJECT-COMMON-*.yaml           # 공통 워크플로우
│   │   └── project-types/
│   │       ├── common/                     # 공통 (복사본)
│   │       ├── flutter/                    # Flutter 전용
│   │       │   └── synology/               # Synology 배포 (선택적)
│   │       ├── spring/                     # Spring 전용
│   │       │   └── synology/               # Synology/Nexus 배포 (선택적)
│   │       ├── react/                      # React 전용
│   │       └── next/                       # Next.js 전용
│   │
│   ├── scripts/
│   │   ├── version_manager.sh              # 버전 관리 (v3.0)
│   │   ├── changelog_manager.py            # AI 체인지로그
│   │   └── template_initializer.sh         # 템플릿 초기화
│   │
│   ├── util/flutter/
│   │   ├── playstore-wizard/               # Android 배포 설정
│   │   └── testflight-wizard/              # iOS 배포 설정
│   │
│   ├── ISSUE_TEMPLATE/                     # 이슈 템플릿 (4종)
│   ├── DISCUSSION_TEMPLATE/                # 토론 템플릿
│   └── PULL_REQUEST_TEMPLATE.md
│
├── .claude/commands/                       # Claude IDE 명령어 (17개)
├── .cursor/commands/                       # Cursor IDE 명령어 (17개)
├── docs/                                   # 문서
│
├── version.yml                             # 중앙 버전 관리
├── CHANGELOG.md / CHANGELOG.json           # 변경 이력 (자동생성)
├── template_integrator.sh                  # Linux/macOS 통합
└── template_integrator.ps1                 # Windows 통합
```

---

## 네이밍 컨벤션

### 워크플로우 파일
```
PROJECT-[TYPE]-[FEATURE]-[DETAIL].yaml

TYPE 분류:
├── TEMPLATE    # 초기화 전용 (일회성)
├── COMMON      # 모든 프로젝트 공통
├── FLUTTER     # Flutter 전용
├── SPRING      # Spring Boot 전용
├── REACT       # React 전용
└── NEXT        # Next.js 전용

예시:
├── PROJECT-TEMPLATE-INITIALIZER.yaml
├── PROJECT-COMMON-VERSION-CONTROL.yaml
├── PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml
└── PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml
```

### 스크립트 파일
```
snake_case.sh / snake_case.py

예시:
├── version_manager.sh
├── changelog_manager.py
└── template_initializer.sh
```

### Util 마법사
```
.github/util/[platform]/[name]-wizard/

예시:
├── .github/util/flutter/playstore-wizard/
└── .github/util/flutter/testflight-wizard/

필수 포함 파일:
├── version.json          # 버전 정보
├── version-sync.sh       # HTML 버전 동기화
├── [name]-wizard.html    # UI
└── [name]-wizard.js      # 로직
```

---

## 핵심 워크플로우

### 공통 워크플로우 (루트)

| 파일명 | 트리거 | 기능 |
|--------|--------|------|
| `PROJECT-TEMPLATE-INITIALIZER` | 저장소 생성 | 템플릿 초기화 (일회성) |
| `PROJECT-COMMON-VERSION-CONTROL` | main 푸시 | patch 버전 자동 증가 |
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` | deploy PR | AI 체인지로그 생성 |
| `PROJECT-COMMON-README-VERSION-UPDATE` | deploy 푸시 | README 버전 동기화 |
| `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE` | 이슈 생성 | 브랜치명/커밋 제안 |
| `PROJECT-COMMON-QA-ISSUE-CREATION-BOT` | @suh-lab 멘션 | QA 이슈 자동 생성 |
| `PROJECT-COMMON-SYNC-ISSUE-LABELS` | 라벨 파일 변경 | GitHub 라벨 동기화 |
| `PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC` | version.json 변경 | Util HTML 버전 동기화 |

### 타입별 워크플로우

#### Flutter
| 파일명 | 용도 | 위치 |
|--------|------|------|
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD` | Play Store 내부 테스트 배포 | 기본 |
| `PROJECT-FLUTTER-ANDROID-TEST-APK` | 테스트 APK 빌드 | 기본 |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT` | TestFlight 배포 | 기본 |
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT` | 테스트 빌드 | 기본 |
| `PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER` | 댓글 트리거 빌드 | 기본 |
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD` | Synology NAS APK 배포 | synology/ |

#### Spring
| 파일명 | 용도 | 위치 |
|--------|------|------|
| `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD` | Synology Docker 배포 | synology/ |
| `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW` | PR 프리뷰 배포 | synology/ |
| `PROJECT-SPRING-NEXUS-CI` | Nexus CI (빌드/테스트) | synology/ |
| `PROJECT-SPRING-NEXUS-PUBLISH` | Nexus 라이브러리 배포 | synology/ |

> **참고**: `synology/` 위치의 워크플로우는 `--synology` 옵션으로만 포함됩니다.

#### React / Next (각 2개)
| 파일명 | 용도 |
|--------|------|
| `PROJECT-REACT-CI` / `PROJECT-NEXT-CI` | 빌드 검증 |
| `PROJECT-REACT-CICD` / `PROJECT-NEXT-CICD` | Docker 빌드 및 배포 |

---

## 핵심 스크립트

### version_manager.sh (v3.0)

```bash
# 현재 버전 확인 (모든 파일 상태)
.github/scripts/version_manager.sh get

# patch 버전 자동 증가 (1.0.0 → 1.0.1)
.github/scripts/version_manager.sh increment

# 특정 버전으로 설정
.github/scripts/version_manager.sh set 2.0.0

# 버전 동기화 (충돌 시 높은 버전 우선)
.github/scripts/version_manager.sh sync

# 버전 형식 검증
.github/scripts/version_manager.sh validate 1.2.3

# version_code 확인/증가
.github/scripts/version_manager.sh get-code
.github/scripts/version_manager.sh increment-code
```

### changelog_manager.py

```bash
# CodeRabbit Summary → CHANGELOG.json 업데이트
python3 .github/scripts/changelog_manager.py update-from-summary

# CHANGELOG.json → CHANGELOG.md 재생성
python3 .github/scripts/changelog_manager.py generate-md

# 특정 버전 릴리즈 노트 추출
python3 .github/scripts/changelog_manager.py export --version 1.2.3 --output release_notes.txt
```

### template_initializer.sh

```bash
# 새 프로젝트 초기화
./template_initializer.sh --version 1.0.0 --type spring
./template_initializer.sh -v 0.0.0 -t flutter
```

**GitHub 템플릿으로 새 저장소 생성 시** `PROJECT-TEMPLATE-INITIALIZER` 워크플로우가 자동 실행됩니다.

**초기화 시 삭제되는 템플릿 전용 파일**:
```
CHANGELOG.md
CHANGELOG.json
template_integrator.sh
template_integrator.ps1
LICENSE
CONTRIBUTING.md
CLAUDE.md
docs/
.github/scripts/test/
.github/workflows/test/
```

### template_integrator.sh / template_integrator.ps1

기존 프로젝트에 SUH-DEVOPS-TEMPLATE 기능을 추가하는 원격 실행 스크립트

```bash
# Linux/macOS (원격 실행)
bash <(curl -fsSL https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh)

# Windows PowerShell (원격 실행)
irm https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1 | iex
```

**통합 시 복사되지 않는 템플릿 전용 문서**:
```
CONTRIBUTING.md
CLAUDE.md
```

**통합 모드 옵션**:
| 모드 | 설명 |
|------|------|
| 신규 통합 | 기존 프로젝트에 템플릿 추가 |
| 업데이트 | 최신 템플릿 버전으로 업그레이드 |
| 되돌리기 | 이전 백업으로 복원 |

**Synology 옵션**:
| 옵션 | 설명 |
|------|------|
| `--synology` / `-Synology` | Synology 워크플로우 포함 |
| `--no-synology` / `-NoSynology` | Synology 워크플로우 제외 (기본값) |

Synology 워크플로우는 `project-types/{type}/synology/` 폴더에 위치하며, 기본적으로 제외됩니다.
대화형 모드에서는 해당 폴더가 있을 때만 Y/N 질문이 표시됩니다.
선택한 옵션은 `version.yml`의 `metadata.template.options.synology`에 저장되어 재통합 시 기억됩니다.

---

## Flutter 마법사 도구

### playstore-wizard (Android)

**위치**: `.github/util/flutter/playstore-wizard/`

**6단계 설정 프로세스**:
1. 프로젝트 경로 + Application ID 입력
2. Keystore 생성 (alias, password, 인증서 정보)
3. Service Account JSON 업로드
4. Play Console 앱 생성 + AAB 빌드
5. 설정 적용 명령어 실행
6. GitHub Secrets JSON/TXT 다운로드

**생성되는 Secrets**:
```
RELEASE_KEYSTORE_BASE64
RELEASE_KEYSTORE_PASSWORD
RELEASE_KEY_ALIAS
RELEASE_KEY_PASSWORD
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64
```

### testflight-wizard (iOS)

**위치**: `.github/util/flutter/testflight-wizard/`

**9단계 설정 프로세스**:
1. 프로젝트 경로 입력
2. Distribution 인증서 (.p12) 업로드
3. Bundle ID 입력
4. Provisioning Profile 설정
5. App Store Connect 앱 등록
6. 앱 정보 확인 (Team ID 등)
7. API Key (.p8) 업로드
8. Fastlane 초기화
9. GitHub Secrets 다운로드

**생성되는 Secrets**:
```
APPLE_CERTIFICATE_BASE64
APPLE_CERTIFICATE_PASSWORD
APPLE_PROVISIONING_PROFILE_BASE64
IOS_PROVISIONING_PROFILE_NAME
APP_STORE_CONNECT_API_KEY_BASE64
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APPLE_TEAM_ID
IOS_BUNDLE_ID
```

---

## 자동화 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                      main 브랜치 푸시                        │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
               ┌────────────────────────┐
               │  VERSION-CONTROL       │
               │  - patch 버전 +1       │
               │  - 프로젝트 파일 동기화 │
               │  - Git 태그 생성       │
               └───────────┬────────────┘
                           │
                           ▼
               ┌────────────────────────┐
               │  deploy 브랜치 PR 생성  │
               └───────────┬────────────┘
                           │
                           ▼
               ┌────────────────────────┐
               │  CHANGELOG-CONTROL     │
               │  - CodeRabbit Summary  │
               │  - CHANGELOG 자동 생성 │
               │  - PR 자동 머지        │
               └───────────┬────────────┘
                           │
                           ▼
               ┌────────────────────────┐
               │  deploy 브랜치 푸시     │
               └───────────┬────────────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
      README 업데이트  타입별 CICD   아티팩트 생성
```

---

## 버전 관리 규칙

### version.yml 구조

```yaml
version: "2.4.3"              # 자동 관리 (patch만)
version_code: 94              # 빌드 번호 (자동 증가)
project_type: "basic"         # 프로젝트 타입

metadata:
  last_updated: "2026-01-06 08:23:20"
  last_updated_by: "username"
```

### 버전 증가 규칙
- **patch (자동)**: main 푸시 시 자동 증가 (1.0.0 → 1.0.1)
- **minor/major (수동)**: version.yml 직접 수정

### 동기화 정책
- 여러 파일 간 버전 불일치 시 **높은 버전 우선**
- version.yml ↔ 프로젝트 파일 양방향 동기화

---

## 기여 가이드라인

### 새 워크플로우 추가

1. **네이밍 규칙 준수**
   ```
   PROJECT-[TYPE]-[FEATURE]-[DETAIL].yaml
   ```

2. **배치 위치**
   - **공통 기능 (필수 2곳 - 반드시 동일하게 유지)**:
     1. `project-types/common/` - **원본 (Source of Truth)**
     2. `.github/workflows/` 루트 - **템플릿 저장소용 복사본**
   - 타입별 기능: `project-types/[type]/`만 (루트 복사 불필요)

3. **필수 요소**
   - `workflow_dispatch` 수동 트리거 포함
   - `concurrency` 설정으로 중복 실행 방지
   - `[skip ci]` 커밋 메시지로 무한 루프 방지

4. **공통 워크플로우 동기화 규칙**

   공통(COMMON) 워크플로우는 두 위치에 **동일하게** 유지해야 합니다:

   | 위치 | 용도 | 필수 |
   |------|------|------|
   | `project-types/common/` | `template_integrator`가 복사하는 원본 | ✅ |
   | `.github/workflows/` (루트) | 템플릿 저장소에서 직접 실행 | ✅ |

   **워크플로우 추가/수정 순서**:
   1. `project-types/common/`에 먼저 작성 (원본)
   2. 동일한 파일을 루트 `.github/workflows/`에 복사
   3. 두 파일의 버전/내용이 동일한지 확인

   > **참고**: 타입별 워크플로우 (flutter, spring 등)는 `project-types/[type]/`에만 존재하면 됨. `template_initializer`와 `template_integrator`가 프로젝트 타입에 따라 해당 폴더에서 복사함.

5. **GitHub 댓글에서 마크다운 표 작성 규칙**

   `actions/github-script`에서 이슈/PR에 댓글을 작성할 때 **마크다운 표(table)**가 포함되면 반드시 `array.join('\n')` 패턴을 사용해야 합니다.

   **✅ 올바른 방법 (array.join 패턴)**:
   ```javascript
   const body = [
     '## 🤖 빌드 완료!',
     '',
     '| 항목 | 값 |',
     '|------|-----|',
     `| **버전** | \`${version}\` |`,
     `| **브랜치** | \`${branchName}\` |`,
     '',
     '📦 **다운로드 가능합니다.**'
   ].join('\n');
   ```

   **❌ 잘못된 방법 (template literal + 들여쓰기)**:
   ```javascript
   // 들여쓰기가 마크다운에 포함되어 표가 깨질 수 있음
   const body = `## 🤖 빌드 완료!

               | 항목 | 값 |
               |------|-----|
               | **버전** | \`${version}\` |`;
   ```

   **이유**:
   - Template literal 내부의 들여쓰기(공백)가 그대로 마크다운에 포함됨
   - GitHub 마크다운 렌더러가 표를 올바르게 인식하지 못할 수 있음
   - `array.join('\n')`은 각 줄을 깔끔하게 연결하여 들여쓰기 문제 방지

### 새 스크립트 추가

1. **위치**: `.github/scripts/`
2. **명명**: `snake_case.sh` 또는 `snake_case.py`
3. **권한**: `chmod +x` 실행 권한 설정
4. **문서화**: README 또는 스크립트 내 주석

### 새 Util 마법사 추가

1. **디렉토리 구조**
   ```
   .github/util/[platform]/[name]-wizard/
   ├── version.json          # 필수
   ├── version-sync.sh       # 필수
   ├── [name]-wizard.html    # 필수
   ├── [name]-wizard.js      # 필수
   └── templates/            # 선택
   ```

2. **version.json 형식**
   ```json
   {
     "name": "마법사 이름",
     "version": "1.0.0",
     "description": "설명",
     "lastUpdated": "YYYY-MM-DD"
   }
   ```

3. **version-sync.sh**
   - version.json → HTML 버전 정보 동기화
   - TEMPLATE-UTIL-VERSION-SYNC 워크플로우가 자동 실행

---

## 이슈/PR 템플릿

### 이슈 템플릿 (4종)

| 템플릿 | 파일 | 용도 |
|--------|------|------|
| 버그 리포트 | `bug_report.md` | 버그 신고 |
| 기능 요청 | `feature_request.md` | 기능 추가/개선 |
| 디자인 요청 | `design_request.md` | UI/UX 디자인 |
| QA 요청 | `qa_request.md` | 테스트 요청 |

### 이슈 라벨 (`issue-label.yml`)
```yaml
긴급, 문서, 작업 전, 작업 중, 코드리뷰 대기중, PR 완료,
검토 완료, Merge 완료, Done, 보류
```

### PR 템플릿
```markdown
## 변경 사항
<!-- 핵심 변경사항 -->

## 테스트
- [ ] 수동 테스트 완료
- [ ] 테스트 코드 완료
```

---

## IDE 명령어

`.claude/commands/` 및 `.cursor/commands/`에 동일하게 존재 (17개):

| 명령어 | 용도 |
|--------|------|
| `/analyze` | 코드 분석 (구현 X) |
| `/build` | 빌드 관리 |
| `/design`, `/design-analyze` | 설계/디자인 |
| `/document` | 문서화 |
| `/figma` | Figma 연동 |
| `/implement` | 구현 |
| `/plan` | 계획 수립 |
| `/ppt` | 프레젠테이션 생성 |
| `/refactor`, `/refactor-analyze` | 리팩토링 |
| `/report` | 보고서 생성 |
| `/review` | 코드 리뷰 |
| `/test`, `/testcase` | 테스트 |
| `/troubleshoot` | 트러블슈팅 |
| `/suh-spring-test` | Spring 테스트 생성 |

---

## 트리거 키워드

### 댓글 기반 트리거

| 키워드 | 워크플로우 | 기능 |
|--------|-----------|------|
| `@suh-lab create qa` | QA-ISSUE-CREATION-BOT | QA 이슈 자동 생성 |
| `@suh-lab build app` | SUH-LAB-APP-BUILD-TRIGGER | Android + iOS 빌드 |
| `@suh-lab apk build` | SUH-LAB-APP-BUILD-TRIGGER | Android만 빌드 |
| `@suh-lab ios build` | SUH-LAB-APP-BUILD-TRIGGER | iOS만 빌드 |

### 브랜치 기반 트리거

| 브랜치 | 트리거 | 워크플로우 |
|--------|--------|-----------|
| `main` | push | VERSION-CONTROL |
| `deploy` | PR | CHANGELOG-CONTROL |
| `deploy` | push | README-UPDATE, CICD |
| `test` | push | 테스트 환경 배포 |

---

## 필수 GitHub Secrets

### 공통
```
_GITHUB_PAT_TOKEN    # PR 자동 머지용 (repo, workflow 권한)
```

### Flutter Android
```
RELEASE_KEYSTORE_BASE64
RELEASE_KEYSTORE_PASSWORD
RELEASE_KEY_ALIAS
RELEASE_KEY_PASSWORD
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64
```

### Flutter iOS
```
APPLE_CERTIFICATE_BASE64
APPLE_CERTIFICATE_PASSWORD
APPLE_PROVISIONING_PROFILE_BASE64
APP_STORE_CONNECT_API_KEY_BASE64
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APPLE_TEAM_ID
IOS_BUNDLE_ID
```

### Spring/Docker
```
DOCKER_REGISTRY_URL
DOCKER_USERNAME
DOCKER_PASSWORD
SYNOLOGY_HOST
SYNOLOGY_USERNAME
SYNOLOGY_PASSWORD
```

---

## 문서 가이드

| 문서 | 위치 | 설명 |
|------|------|------|
| README.md | 루트 | 메인 문서 (간결하게 유지, ~150줄) |
| CONTRIBUTING.md | 루트 | 기여 가이드 |
| CHANGELOG.md | 루트 | 변경 이력 (자동생성) |
| VERSION-CONTROL.md | docs/ | 버전 관리 시스템 |
| CHANGELOG-AUTOMATION.md | docs/ | 체인지로그 자동화 |
| PR-PREVIEW.md | docs/ | PR Preview 시스템 |
| ISSUE-AUTOMATION.md | docs/ | 이슈 자동화 (Issue Helper, QA 봇) |
| TEMPLATE-INTEGRATOR.md | docs/ | 통합 스크립트 가이드 |
| FLUTTER-CICD-OVERVIEW.md | docs/ | Flutter CI/CD 전체 가이드 |
| FLUTTER-TESTFLIGHT-WIZARD.md | docs/ | iOS 배포 설정 |
| FLUTTER-PLAYSTORE-WIZARD.md | docs/ | Android 배포 설정 |
| FLUTTER-TEST-BUILD-TRIGGER.md | docs/ | 테스트 빌드 트리거 |
| SYNOLOGY-DEPLOYMENT-GUIDE.md | docs/ | Synology NAS 배포 가이드 |
| TROUBLESHOOTING.md | docs/ | 문제 해결 가이드 |

---

## 문서 관리 규칙

### README.md 유지 원칙

README.md는 **150줄 이하**로 간결하게 유지합니다.

```
README.md 구조:
├── 헤더 (중앙 정렬, 배지)
├── "왜 이 템플릿인가?" (비교 테이블)
├── 빠른 시작 (간략)
├── 주요 기능 (테이블 + docs 링크)
├── 지원 프로젝트 타입
├── 댓글 명령어 (@suh-lab)
├── 설정 (간략)
├── 문서 링크
└── 지원/라이선스
```

**상세 내용은 모두 `docs/` 폴더로 분리**합니다.

### @suh-lab 명령어 문서화 규칙

`@suh-lab` 댓글 명령어는 두 곳에 기록합니다:

| 위치 | 내용 |
|------|------|
| `README.md` | 명령어 요약 테이블 (한눈에 보기) |
| `docs/[기능].md` | 상세 사용법 및 트러블슈팅 |

**명령어 추가 시 업데이트 순서**:
1. 해당 기능의 `docs/[기능].md`에 상세 내용 추가
2. `README.md`의 "댓글 명령어" 테이블에 요약 추가
3. `CLAUDE.md`의 "트리거 키워드" 섹션 업데이트

### 워크플로우 변경 시 문서 업데이트

워크플로우 파일을 수정하면 다음을 확인합니다:

| 변경 유형 | 업데이트 필요 문서 |
|----------|-------------------|
| 새 워크플로우 추가 | CLAUDE.md (핵심 워크플로우), 해당 docs/ |
| 트리거 조건 변경 | 해당 docs/, CLAUDE.md (트리거 키워드) |
| 환경변수 추가 | 해당 docs/ |
| 새 댓글 명령어 | README.md, CLAUDE.md, 해당 docs/ |

### 신규 기능 문서화 체크리스트

```markdown
새 기능 추가 시:
- [ ] 해당 기능의 docs/ 문서 생성/업데이트
- [ ] README.md "주요 기능" 테이블 업데이트 (필요시)
- [ ] README.md "댓글 명령어" 테이블 업데이트 (필요시)
- [ ] README.md "문서" 테이블에 링크 추가
- [ ] CLAUDE.md 관련 섹션 업데이트
- [ ] 모든 링크 유효성 확인
```

### docs/ 폴더 네이밍 규칙

```
docs/
├── [기능명].md              # 단일 기능 문서
├── [타입]-[기능].md         # 타입별 기능 (예: FLUTTER-CICD-OVERVIEW.md)
└── [타입]-[상세]-[기능].md  # 세부 기능 (예: FLUTTER-TESTFLIGHT-WIZARD.md)
```

**파일명 규칙**:
- 대문자 + 하이픈 (UPPER-KEBAB-CASE)
- 예: `PR-PREVIEW.md`, `VERSION-CONTROL.md`
