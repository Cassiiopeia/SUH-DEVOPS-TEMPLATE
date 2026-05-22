# Spring GitHub Packages Publish Workflow — Design Spec

- **Date**: 2026-05-22
- **Status**: Approved (brainstorming → writing-plans)
- **Author**: SUH SAECHAN

---

## 1. 목적

Java 라이브러리(Spring 모듈)를 **GitHub Packages**(Maven repo)에 자동 배포하는 CICD 워크플로우를 추가한다. 기존 사내 Nexus 서버 의존성 없이 GitHub만으로 모듈 호스팅이 가능하게 한다.

기존 `PROJECT-SPRING-NEXUS-PUBLISH`는 **그대로 유지**한다. 신규 워크플로우는 별도 파일로 추가되며, 두 워크플로우는 독립적으로 동작한다.

---

## 2. 범위

### In Scope

- 신규 워크플로우 파일 1개 추가 (`PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml`)
- `CLAUDE.md` Spring 워크플로우 표에 1행 추가

### Out of Scope

- 기존 Nexus 워크플로우 수정/제거
- `build.gradle` 수정 (각 프로젝트가 자체 관리)
- 이중 publish (Nexus + GitHub Packages 동시) — 사용자가 명시적으로 거부함
- `template_integrator.sh` 옵션 추가 — 기본 포함 워크플로우로 분류

---

## 3. 결정 사항 (사용자 승인 완료)

| 항목 | 결정 |
|------|------|
| 파일 위치 | `project-types/spring/` 루트 (synology 폴더 밖) |
| 워크플로우 분류 | 기본 포함 (`--synology` 옵션 불필요) |
| Secret 전략 | `GITHUB_TOKEN` 자동 (별도 secret 등록 불필요) |
| Publish task | `publishMavenPublicationToGitHubPackagesRepository` (단일 타겟) |
| 기존 Nexus 워크플로우 | 유지 |
| 워크플로우 주석 | Java 라이브러리 모듈 배포 전용 CICD 명시 |
| 주석 가이드라인 타입 | **Type A** (Secrets 없음, GITHUB_TOKEN만 사용 — 🔑 섹션 생략) |
| 주석 가이드라인 준수 | `docs/WORKFLOW-COMMENT-GUIDELINES.md` 전체 준수 (67자 구분선, GITHUB_TOKEN 미언급, 표준 아이콘만) |

---

## 4. 파일 구조

```
.github/workflows/project-types/spring/
├── PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml   ← NEW
└── synology/
    ├── PROJECT-SPRING-NEXUS-CI.yml              (변경 없음)
    ├── PROJECT-SPRING-NEXUS-PUBLISH.yml         (변경 없음)
    ├── PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml
    ├── PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml
    └── PROJECT-SPRING-SYNOLOGY-NONSTOP-TRAEFIK-CICD.yaml
```

---

## 5. 워크플로우 사양

### 5.1 파일 헤더 (주석)

> **준수 가이드라인**: `docs/WORKFLOW-COMMENT-GUIDELINES.md` Type A (Secrets 없음 — GITHUB_TOKEN만 사용).
>
> 핵심 규칙 준수:
> - 67자 구분선 사용
> - `GITHUB_TOKEN` 명시 금지 (자동 제공이라 문서화 불필요)
> - 🔑 필수 Secrets 섹션 **생략** (Type A는 Secrets 섹션 없음)
> - 표준 아이콘만 사용 (⚠️ 🛠️ 💡)

```yaml
# ===================================================================
# Spring GitHub Packages 라이브러리 배포 워크플로우
# ===================================================================
#
# Java 라이브러리 모듈을 GitHub Packages(Maven repo)에 자동 배포합니다.
# Nexus 없이 GitHub만으로 의존성 호스팅이 가능합니다.
#
# ⚠️ Java 라이브러리 모듈 배포 전용 CICD입니다.
#    Spring Boot 애플리케이션 배포가 아닙니다.
#
# ===================================================================
# 🛠️ build.gradle 요구사항
# ===================================================================
# publishing.repositories.maven 블록에 GitHub Packages 항목 추가:
#
#   maven {
#     name = "GitHubPackages"
#     url = uri("https://maven.pkg.github.com/${System.getenv('GITHUB_REPOSITORY')}")
#     credentials {
#       username = System.getenv("GITHUB_ACTOR")
#       password = System.getenv("GITHUB_TOKEN")
#     }
#   }
#
# 💡 Free 계정 제한 (Private repo 기준):
#   - 월 500MB 저장 + 1GB 전송 무료
#   - Public repo는 무제한 무료
# ===================================================================
```

### 5.2 트리거

```yaml
on:
  push:
    branches: ["deploy"]
    tags:
      - 'v*.*.*'
  workflow_dispatch:
```

### 5.3 Concurrency

```yaml
concurrency:
  group: github-packages-publish-${{ github.ref }}
  cancel-in-progress: false
```

### 5.4 Permissions

```yaml
permissions:
  contents: read
  packages: write
```

### 5.5 Job 스텝 (publish)

| # | 스텝 | 동작 |
|---|------|------|
| 1 | `actions/checkout@v5` | 소스 체크아웃 |
| 2 | `actions/setup-java@v4` | JDK 17, temurin |
| 3 | `gradle/actions/setup-gradle@v4` | Gradle 캐시 + wrapper 검증 |
| 4 | Get version | tag면 tag에서, 아니면 `version_manager.sh get` |
| 5 | Publish to GitHub Packages | `./gradlew publishMavenPublicationToGitHubPackagesRepository -Pversion=$VERSION` |

### 5.6 환경변수 인터페이스 (build.gradle이 읽는 키)

| 키 | 출처 | 용도 |
|----|------|------|
| `GITHUB_ACTOR` | `github.actor` | publish username |
| `GITHUB_TOKEN` | `secrets.GITHUB_TOKEN` | publish password |
| `GITHUB_REPOSITORY` | `github.repository` | repo URL 조합 |

### 5.7 전체 YAML (최종 안)

```yaml
# ===================================================================
# Spring GitHub Packages 라이브러리 배포 워크플로우
# ===================================================================
#
# Java 라이브러리 모듈을 GitHub Packages(Maven repo)에 자동 배포합니다.
# Nexus 없이 GitHub만으로 의존성 호스팅이 가능합니다.
#
# ⚠️ Java 라이브러리 모듈 배포 전용 CICD입니다.
#    Spring Boot 애플리케이션 배포가 아닙니다.
#
# ===================================================================
# 🛠️ build.gradle 요구사항
# ===================================================================
# publishing.repositories.maven 블록에 GitHub Packages 항목 추가:
#
#   maven {
#     name = "GitHubPackages"
#     url = uri("https://maven.pkg.github.com/${System.getenv('GITHUB_REPOSITORY')}")
#     credentials {
#       username = System.getenv("GITHUB_ACTOR")
#       password = System.getenv("GITHUB_TOKEN")
#     }
#   }
#
# 💡 Free 계정 제한 (Private repo 기준):
#   - 월 500MB 저장 + 1GB 전송 무료
#   - Public repo는 무제한 무료
# ===================================================================

name: PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH

on:
  push:
    branches: ["deploy"]
    tags:
      - 'v*.*.*'
  workflow_dispatch:

concurrency:
  group: github-packages-publish-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      - name: Get version
        id: get_version
        run: |
          if [[ "${{ github.ref }}" == refs/tags/* ]]; then
            TAG_NAME=${GITHUB_REF#refs/tags/}
            VERSION=${TAG_NAME#v}
            echo "🏷️ 태그에서 버전 추출: $VERSION"
          else
            chmod +x .github/scripts/version_manager.sh
            VERSION=$(./.github/scripts/version_manager.sh get | tail -n 1)
            echo "📄 version.yml에서 버전 추출: $VERSION"
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "Publishing version $VERSION"

      - name: Publish to GitHub Packages
        env:
          GITHUB_ACTOR: ${{ github.actor }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITHUB_REPOSITORY: ${{ github.repository }}
        run: |
          VERSION="${{ steps.get_version.outputs.version }}"
          echo "🚀 Publishing version $VERSION to GitHub Packages"
          ./gradlew publishMavenPublicationToGitHubPackagesRepository -Pversion=$VERSION
```

---

## 6. 기존 Nexus 워크플로우와의 호환성

| 항목 | Nexus | GitHub Packages |
|------|-------|----------------|
| Secret | `GRADLE_PROPERTIES` (수동 등록) | `GITHUB_TOKEN` (자동) |
| `gradle.properties` 생성 스텝 | 있음 | 없음 |
| `permissions.packages` | 불필요 | `write` 필요 |
| Publish task | `./gradlew publish` | `publishMavenPublicationToGitHubPackagesRepository` |
| 인증 정보 위치 | gradle.properties 내부 | GITHUB_* 환경변수 |
| `concurrency` | 없음 (legacy) | 있음 |
| 파일 위치 | `spring/synology/` | `spring/` |
| 옵션 의존성 | `--synology` 필요 | 기본 포함 |

### 충돌 가능성

`build.gradle`의 `publishing.repositories.maven` 블록에 양쪽 repo가 동시에 존재해도 충돌 없음. `./gradlew publish`는 모든 repo로 push 시도하지만, 신규 워크플로우는 GitHub Packages task만 명시 호출하므로 Nexus는 트리거되지 않는다.

기존 Nexus 워크플로우(`./gradlew publish`)는 양쪽으로 push 시도할 수 있다. Nexus 워크플로우 동작에 GitHub Packages credential이 없으면 실패한다 → **이 경우 build.gradle에서 GitHub Packages 블록을 환경변수 가드로 감싼다**:

```gradle
repositories {
    if (System.getenv("GITHUB_TOKEN") != null) {
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/${System.getenv('GITHUB_REPOSITORY')}")
            credentials {
                username = System.getenv("GITHUB_ACTOR")
                password = System.getenv("GITHUB_TOKEN")
            }
        }
    }
    // 기존 Nexus maven { ... }
}
```

> build.gradle 수정 가이드는 spec 본문이 아닌 **워크플로우 헤더 주석**에 포함된다.

---

## 7. CLAUDE.md 업데이트

Spring 표 마지막에 1행 추가:

```markdown
| `PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH` | Java 라이브러리 GitHub Packages 배포 | 기본 |
```

위치: `PROJECT-SPRING-NEXUS-PUBLISH` 행 **아래**.

---

## 8. 테스트 계획

워크플로우 자체 동작 검증:

1. 빈 spring 프로젝트에 워크플로우 파일 복사
2. `build.gradle`에 publishing block 추가 (5.1 주석 참조)
3. `deploy` 브랜치 push → 워크플로우 트리거 확인
4. GitHub Packages에 패키지 등록 확인
5. `v1.0.0` 태그 push → 태그 버전으로 publish 확인
6. `workflow_dispatch` 수동 트리거 동작 확인

---

## 9. Breaking Changes

없음. 신규 워크플로우 추가일 뿐 기존 동작 변경 없음. `version.yml` 스키마 변경 없음. `breaking-changes.json` 등록 불필요.

---

## 10. 산출물 목록 (writing-plans에서 다룰 항목)

1. `.github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml` 신규 생성
2. `CLAUDE.md` Spring 표 업데이트 (1행 추가)
3. `docs/WORKFLOW-COMMENT-GUIDELINES.md` §10 파일별 적용 현황 표에 신규 워크플로우 1행 추가 (Type A, 상태 ✅)
4. (선택) `docs/` 하위에 사용 가이드 추가 — writing-plans 단계에서 판단

---

## 11. 주석 가이드라인 자체 검증 결과

`docs/WORKFLOW-COMMENT-GUIDELINES.md` §11 체크리스트 대조:

- [x] 67자 구분선 사용
- [x] GITHUB_TOKEN 언급 없음
- [x] Secrets는 1줄 형식 — Type A이므로 Secrets 섹션 자체 없음
- [x] 선택 항목에만 `(선택)` 표시 — 선택 항목 없음
- [x] 아이콘 용도에 맞게 사용 (⚠️ 🛠️ 💡 모두 표준)
- [x] 환경변수는 1줄 형식 — env 섹션 없음
- [x] Type 분류 명시 (Type A)
