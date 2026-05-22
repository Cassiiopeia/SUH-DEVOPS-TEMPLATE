# Spring GitHub Packages Publish Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spring 프로젝트 타입의 Java 라이브러리 모듈을 GitHub Packages(Maven repo)에 자동 배포하는 신규 워크플로우 1개를 추가하고, CLAUDE.md / WORKFLOW-COMMENT-GUIDELINES.md 문서 표를 갱신한다.

**Architecture:** 신규 워크플로우는 `.github/workflows/project-types/spring/` 루트(synology 폴더 밖)에 위치하며 기본 포함된다. 기존 `PROJECT-SPRING-NEXUS-PUBLISH`는 손대지 않는다. Secret은 `GITHUB_TOKEN` 자동 제공만 사용하고, `publishMavenPublicationToGitHubPackagesRepository` Gradle task만 호출해 Nexus 워크플로우와 부수효과 없이 공존한다. 주석은 `docs/WORKFLOW-COMMENT-GUIDELINES.md` Type A를 따른다.

**Tech Stack:** GitHub Actions YAML, `actions/checkout@v5`, `actions/setup-java@v4` (JDK 17 temurin), `gradle/actions/setup-gradle@v4`, `version_manager.sh`.

---

## 파일 변경 요약

**Create:**
- `.github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml`

**Modify:**
- `CLAUDE.md` — Spring 워크플로우 표에 1행 추가
- `docs/WORKFLOW-COMMENT-GUIDELINES.md` — §10 Spring 표에 1행 추가

**Test:** 자동화 테스트 없음. 워크플로우 동작 검증은 spec §8에 따라 별도 spring 프로젝트에서 수동 검증.

---

## Task 1: 워크플로우 파일 작성

**Files:**
- Create: `.github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml`

- [ ] **Step 1: 파일 작성**

다음 내용으로 신규 파일을 작성한다.

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

- [ ] **Step 2: YAML 문법 검증**

Run:
```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml'))"
```

Expected: 출력 없음 (parse 성공). Parse 에러 시 `yaml.YAMLError`로 종료.

Python 미설치 환경이면 PowerShell:
```powershell
Get-Content .github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml | Out-Null
```

- [ ] **Step 3: 주석 가이드라인 자체 검증**

다음 항목을 파일 헤더에서 직접 확인한다.

| 체크 | 검증 방법 | 기대 |
|------|---------|------|
| 67자 구분선 | `grep -c '^# ={67}$' [파일]` | 4 이상 |
| GITHUB_TOKEN 헤더 언급 없음 | 파일 헤더(`name:` 이전)에 `GITHUB_TOKEN` 문자열 부재 | 0 hit |
| 🔑 섹션 부재 | `grep '🔑' [파일]` | hit 없음 |
| 표준 아이콘만 | ⚠️ 🛠️ 💡 외 아이콘 없음 | OK |

Run:
```bash
grep -c '^# ={67}$' .github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml
```

Expected: `4`

Run:
```bash
sed -n '1,/^name:/p' .github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml | grep -c 'GITHUB_TOKEN'
```

Expected: `0` (헤더 주석에는 등장하지 않음)

Run:
```bash
grep -c '🔑' .github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml
```

Expected: `0`

- [ ] **Step 4: 커밋**

```bash
git add .github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml
git commit -m "$(cat <<'EOF'
Spring GitHub Packages 라이브러리 배포 워크플로우 추가 : feat : Java 라이브러리 모듈을 GitHub Packages(Maven repo)에 자동 배포하는 신규 CICD 워크플로우 1개 추가

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: 커밋 성공 메시지.

---

## Task 2: CLAUDE.md Spring 표 업데이트

**Files:**
- Modify: `CLAUDE.md` (Spring 워크플로우 표 — `PROJECT-SPRING-NEXUS-PUBLISH` 행 아래)

- [ ] **Step 1: 현재 Spring 표 위치 확인**

Run:
```bash
grep -n 'PROJECT-SPRING-NEXUS-PUBLISH' CLAUDE.md
```

Expected: 1개 라인 매치 — Spring 표 안에 있는 행.

- [ ] **Step 2: Edit tool로 1행 추가**

`PROJECT-SPRING-NEXUS-PUBLISH` 행을 찾아 그 뒤에 신규 행을 추가한다.

old_string:
```
| `PROJECT-SPRING-NEXUS-PUBLISH` | Nexus 라이브러리 배포 | synology/ |
```

new_string:
```
| `PROJECT-SPRING-NEXUS-PUBLISH` | Nexus 라이브러리 배포 | synology/ |
| `PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH` | Java 라이브러리 GitHub Packages 배포 | 기본 |
```

- [ ] **Step 3: 검증**

Run:
```bash
grep -n 'PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH' CLAUDE.md
```

Expected: 1개 라인 매치, Spring 표 안.

Run:
```bash
grep -B1 'PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH' CLAUDE.md
```

Expected: 직전 행이 `PROJECT-SPRING-NEXUS-PUBLISH` 행이어야 함.

- [ ] **Step 4: 커밋**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
CLAUDE.md Spring 워크플로우 표에 GitHub Packages 배포 행 추가 : docs : 신규 워크플로우 PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH 문서화

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: 커밋 성공.

---

## Task 3: WORKFLOW-COMMENT-GUIDELINES.md Spring 표 업데이트

**Files:**
- Modify: `docs/WORKFLOW-COMMENT-GUIDELINES.md` §10 `project-types/spring/` 표

- [ ] **Step 1: 현재 Spring 표 라인 확인**

Run:
```bash
grep -n 'NEXUS-PUBLISH' docs/WORKFLOW-COMMENT-GUIDELINES.md
```

Expected: §10 안의 `| NEXUS-PUBLISH | B | ✅ |` 라인 매치.

- [ ] **Step 2: Edit tool로 1행 추가**

`NEXUS-PUBLISH` 행 아래에 GitHub Packages 행을 추가한다.

old_string:
```
| NEXUS-PUBLISH | B | ✅ |
```

new_string:
```
| NEXUS-PUBLISH | B | ✅ |
| GITHUB-PACKAGES-PUBLISH | A | ✅ |
```

> 타입은 **A** — Secrets 없음(GITHUB_TOKEN만 사용), 가이드라인 §3 Type A 분류 기준 충족.

- [ ] **Step 3: 검증**

Run:
```bash
grep -n 'GITHUB-PACKAGES-PUBLISH' docs/WORKFLOW-COMMENT-GUIDELINES.md
```

Expected: 1개 라인 매치, §10 Spring 표 안.

- [ ] **Step 4: 커밋**

```bash
git add docs/WORKFLOW-COMMENT-GUIDELINES.md
git commit -m "$(cat <<'EOF'
WORKFLOW-COMMENT-GUIDELINES Spring 표에 GitHub Packages 행 추가 : docs : 신규 워크플로우 Type A 분류 기록

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: 커밋 성공.

---

## Task 4: 최종 점검

- [ ] **Step 1: 변경된 파일 일람 확인**

Run:
```bash
git log --oneline -3
```

Expected: Task 1·2·3의 커밋 3개가 순서대로 나타남.

- [ ] **Step 2: 워크플로우 파일 존재 + 라인 수 확인**

Run:
```bash
wc -l .github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml
```

Expected: 약 60~70 라인 사이.

- [ ] **Step 3: spec 산출물 목록 대조**

spec §10 산출물 1·2·3번을 모두 처리했는지 확인:

| 산출물 | 처리 Task | 상태 |
|--------|---------|------|
| 워크플로우 파일 신규 생성 | Task 1 | 완료 확인 |
| CLAUDE.md Spring 표 1행 추가 | Task 2 | 완료 확인 |
| WORKFLOW-COMMENT-GUIDELINES Spring 표 1행 추가 | Task 3 | 완료 확인 |

산출물 4번(docs 사용 가이드)은 spec에서 (선택)으로 분류 — 이번 Plan에는 포함하지 않음. 필요 시 별도 작업으로 분리.

- [ ] **Step 4: push 안내**

워크플로우 동작 검증은 spec §8에 따라 별도 spring 프로젝트에서 수동 진행. push는 사용자가 명시 요청 시에만 실행한다 (Global Rules 준수).

---

## Self-Review 결과

**Spec coverage:**

| Spec 섹션 | 대응 Task |
|----------|---------|
| §1 목적 | Task 1 (워크플로우 작성) |
| §2 In Scope: 워크플로우 1개 추가 | Task 1 |
| §2 In Scope: CLAUDE.md 표 갱신 | Task 2 |
| §3 결정 사항 (위치/Type/Publish task) | Task 1 — YAML 본문에 반영 |
| §4 파일 구조 | Task 1 — 정확한 경로로 생성 |
| §5.1 헤더 주석 | Task 1 Step 1 + Step 3 검증 |
| §5.2~5.7 YAML 본문 | Task 1 Step 1 |
| §6 호환성 (workflow 측면) | Task 1 — `publishMavenPublicationToGitHubPackagesRepository` 명시 호출 |
| §7 CLAUDE.md 업데이트 | Task 2 |
| §8 테스트 계획 | Task 4 Step 4 — 수동 검증으로 안내 |
| §9 Breaking Changes 없음 | breaking-changes.json 수정 불필요 |
| §10 산출물 3번 (WORKFLOW-COMMENT-GUIDELINES) | Task 3 |
| §11 가이드라인 체크리스트 | Task 1 Step 3 |

빠진 항목 없음.

**Placeholder scan:** TBD/TODO/placeholder 없음. 모든 코드 블록 완전 기술. 모든 grep 명령 기대 출력 명시.

**Type consistency:** 워크플로우명 `PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH`는 spec §7 행 추가·§5.7 `name:` 필드·파일명 모두 일치. Gradle task 명 `publishMavenPublicationToGitHubPackagesRepository`도 Task 1 본문·spec §3·§5.5에서 동일.
