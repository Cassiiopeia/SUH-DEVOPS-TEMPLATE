# Synology Secret File Upload 워크플로우 템플릿 구현 계획

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GitHub Secrets를 Synology NAS에 자동 업로드하는 공통 워크플로우 템플릿 생성

**Architecture:** SSH(appleboy/ssh-action) 기반으로 `project-types/common/synology/`에 배치. 기본 Secret(ENV_FILE, APPLICATION_PROD_YML)은 있으면 업로드/없으면 스킵. 워크플로우 상단에 AI 에이전트 커스텀 프롬프트 포함. template_integrator에 common/synology/ 복사 로직 추가 필수.

**Tech Stack:** GitHub Actions, appleboy/ssh-action@v1.0.3, Bash

---

## 파일 구조

| 동작 | 파일 경로 | 용도 |
|------|----------|------|
| Create | `.github/workflows/project-types/common/synology/PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml` | 원본 (Source of Truth) |
| Modify | `template_integrator.sh` | common/synology/ 복사 로직 추가 |
| Modify | `template_integrator.ps1` | common/synology/ 복사 로직 추가 (PowerShell) |
| Modify | `CLAUDE.md` | 핵심 워크플로우 테이블, 트리거 키워드, Secrets 섹션 업데이트 |

> **루트 복사본 불필요**: synology 워크플로우는 `--synology` 옵션으로만 포함되는 조건부 기능이므로, 기존 패턴(spring/synology, flutter/synology)과 동일하게 루트에 복사본을 두지 않음.

---

## Chunk 1: 워크플로우 파일 생성

### Task 1: 원본 워크플로우 작성

**Files:**
- Create: `.github/workflows/project-types/common/synology/PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml`

- [ ] **Step 1: common/synology/ 디렉토리 생성**

```bash
mkdir -p .github/workflows/project-types/common/synology/
```

- [ ] **Step 2: 워크플로우 파일 작성**

전체 워크플로우 내용:

```yaml
# ===================================================================
# PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml
# GitHub Secret 파일 Synology NAS 자동 업로드
# ===================================================================
#
# GitHub Secrets에 저장된 설정 파일들을 Synology NAS에
# 자동 업로드하여 변경 이력을 추적합니다.
# 타임스탬프 기반 백업으로 변경 히스토리를 보존합니다.
#
# ===================================================================
# 🤖 AI 에이전트 커스텀 가이드
# ===================================================================
# 이 워크플로우를 프로젝트에 맞게 수정하려면,
# 아래 프롬프트를 AI 에이전트에게 전달하세요:
#
# 📋 프롬프트:
# "PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml을
#  프로젝트에 맞게 수정해줘.
#  - 프로젝트명: {프로젝트명}
#  - 역할(ROLE): {backend/frontend 등}
#  - Synology 경로: {NAS 저장 경로}
#  - SSH 포트: {포트번호}
#  - 업로드할 GitHub Secrets:
#    SECRET_KEY → 저장할_파일명.확장자
#  기존 파일 목록 섹션에 추가하고,
#  없는 Secret은 스킵하도록 해줘."
#
# 💡 예시:
# "- APPLICATION_PROD_YML → application-prod.yml
#  - FIREBASE_KEY_JSON → firebase-admin-sdk.json
#  - VERTEX_SA_KEY → vertex-sa-key.json
#  - ENV_FILE → .env
#  - ADMIN_YML → admin.yml"
# ===================================================================
#
# ===================================================================
# 🔑 필수 GitHub Secrets
# ===================================================================
# SERVER_HOST: Synology NAS 주소
# SERVER_USER: SSH 사용자명
# SERVER_PASSWORD: SSH 비밀번호
# ===================================================================
#
# 🔧 환경변수 설정 (env 섹션에서 설정)
# ===================================================================
#
# 📦 프로젝트 설정:
# PROJECT_NAME: 프로젝트명 (NAS 경로에 사용)
# ROLE: 역할 구분 (backend, frontend 등)
# SYNOLOGY_BASE_PATH: NAS 기본 경로 (기본: /volume1/projects)
#
# 🔌 SSH 연결:
# SSH_PORT: SSH 포트 (기본: 2022)
# ===================================================================

name: PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD

on:
  push:
    branches:
      - main
  workflow_dispatch:

concurrency:
  group: synology-secret-file-upload-${{ github.ref }}
  cancel-in-progress: true

env:
  # 🔧 프로젝트 설정 - 프로젝트에 맞게 수정하세요
  PROJECT_NAME: "my-project"
  ROLE: "backend"
  SYNOLOGY_BASE_PATH: "/volume1/projects"
  SSH_PORT: "2022"

jobs:
  upload-secret-files:
    runs-on: ubuntu-latest
    if: "!contains(github.event.head_commit.message, '[skip ci]')"

    steps:
      - name: 코드 체크아웃
        uses: actions/checkout@v4

      - name: 타임스탬프 및 커밋 정보 생성
        run: |
          export TZ='Asia/Seoul'
          TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
          echo "TIMESTAMP=$TIMESTAMP" >> $GITHUB_ENV
          echo "BUILD_DATE=$(date '+%Y-%m-%d %H:%M')" >> $GITHUB_ENV
          echo "SHORT_COMMIT_HASH=$(echo ${{ github.sha }} | cut -c1-7)" >> $GITHUB_ENV
          echo "생성된 타임스탬프: $TIMESTAMP"

      - name: Secret 파일 업로드
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          password: ${{ secrets.SERVER_PASSWORD }}
          port: ${{ env.SSH_PORT }}
          envs: TIMESTAMP,SHORT_COMMIT_HASH,BUILD_DATE,PROJECT_NAME,ROLE,SYNOLOGY_BASE_PATH
          script: |
            set -e

            # 경로 설정
            BASE_DIR="${SYNOLOGY_BASE_PATH}/${PROJECT_NAME}/github_secret/${ROLE}"

            echo "=== Secret 파일 업로드 시작 ==="
            echo "프로젝트: ${PROJECT_NAME} (${ROLE})"
            echo "경로: ${BASE_DIR}"
            echo "타임스탬프: ${TIMESTAMP}"

            # 디렉토리 생성
            export PW=${{ secrets.SERVER_PASSWORD }}
            echo $PW | sudo -S mkdir -p "${BASE_DIR}/${TIMESTAMP}"

            # ============================================
            # 📦 파일 업로드 섹션
            # Secret이 비어있으면 자동 스킵됩니다.
            # AI 에이전트로 이 섹션에 파일을 추가하세요.
            # ============================================

            # --- ENV_FILE → .env ---
            SECRET_CONTENT='${{ secrets.ENV_FILE }}'
            if [ -n "$SECRET_CONTENT" ]; then
              echo "ENV_FILE → .env 업로드 중..."
              cat << 'FILEEOF' | sudo tee "${BASE_DIR}/.env" > /dev/null
            ${{ secrets.ENV_FILE }}
            FILEEOF
              cat << 'FILEEOF' | sudo tee "${BASE_DIR}/${TIMESTAMP}/.env" > /dev/null
            ${{ secrets.ENV_FILE }}
            FILEEOF
              echo ".env 업로드 완료"
            else
              echo "ENV_FILE 스킵 (Secret 미설정)"
            fi

            # --- APPLICATION_PROD_YML → application-prod.yml ---
            SECRET_CONTENT='${{ secrets.APPLICATION_PROD_YML }}'
            if [ -n "$SECRET_CONTENT" ]; then
              echo "APPLICATION_PROD_YML → application-prod.yml 업로드 중..."
              cat << 'FILEEOF' | sudo tee "${BASE_DIR}/application-prod.yml" > /dev/null
            ${{ secrets.APPLICATION_PROD_YML }}
            FILEEOF
              cat << 'FILEEOF' | sudo tee "${BASE_DIR}/${TIMESTAMP}/application-prod.yml" > /dev/null
            ${{ secrets.APPLICATION_PROD_YML }}
            FILEEOF
              echo "application-prod.yml 업로드 완료"
            else
              echo "APPLICATION_PROD_YML 스킵 (Secret 미설정)"
            fi

            # ============================================
            # 📋 메타데이터 JSON 생성
            # ============================================
            cat << EOF | sudo tee "${BASE_DIR}/${TIMESTAMP}/cicd-gitignore-file.json" > /dev/null
            {
              "build_info": {
                "timestamp": "$TIMESTAMP",
                "workflow": "Secret 파일 자동 업로드",
                "run_id": "${{ github.run_id }}",
                "run_number": "${{ github.run_number }}",
                "event": "${{ github.event_name }}",
                "repository": "${{ github.repository }}",
                "branch": "${{ github.ref_name }}",
                "commit_hash": "${{ github.sha }}",
                "short_hash": "$SHORT_COMMIT_HASH",
                "commit_url": "https://github.com/${{ github.repository }}/commit/${{ github.sha }}",
                "actor": "${{ github.actor }}",
                "build_date": "$BUILD_DATE"
              },
              "files": [
                {
                  "secret_name": "ENV_FILE",
                  "file_name": ".env",
                  "last_updated": "$BUILD_DATE"
                },
                {
                  "secret_name": "APPLICATION_PROD_YML",
                  "file_name": "application-prod.yml",
                  "last_updated": "$BUILD_DATE"
                }
              ]
            }
            EOF

            # 타임스탬프 인덱스 업데이트
            echo "{\"last_updated\": \"${TIMESTAMP}\", \"commit\": \"${SHORT_COMMIT_HASH}\", \"actor\": \"${{ github.actor }}\", \"status\": \"completed\"}" | sudo tee "${BASE_DIR}/timestamp_index.json" > /dev/null

            echo "=== 모든 파일 업로드 완료 ==="
```

- [ ] **Step 3: 파일 저장 확인**

```bash
head -5 .github/workflows/project-types/common/synology/PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml
```

Expected: 주석 헤더가 정상 출력

---

## Chunk 2: template_integrator 수정

### Task 2: template_integrator.sh에 common/synology/ 복사 로직 추가

**Files:**
- Modify: `template_integrator.sh`

현재 문제:
- 공통 워크플로우 복사 (1418행): `common/*.{yaml,yml}`만 복사, subdirectory 무시
- synology 복사 (1542행): `$PROJECT_TYPE/synology/`만 복사, `common/synology/` 무시
- ask_synology_option (1334행): `$type_dir/synology`만 체크, `common/synology/` 무시

- [ ] **Step 1: ask_synology_option 함수 수정**

`ask_synology_option` 함수(1334행)에서 `common/synology/` 폴더도 체크하도록 수정.
타입별 synology 폴더가 없어도 common/synology/가 있으면 질문이 표시되어야 함.

수정 위치: `template_integrator.sh:1334-1341`

기존:
```bash
ask_synology_option() {
    local type_dir="$1"
    local synology_dir="$type_dir/synology"

    # synology 폴더가 없으면 건너뛰기
    if [ ! -d "$synology_dir" ]; then
        return
    fi
```

변경:
```bash
ask_synology_option() {
    local type_dir="$1"
    local synology_dir="$type_dir/synology"
    local common_synology_dir="$(dirname "$type_dir")/common/synology"

    # 타입별/공통 synology 폴더 모두 없으면 건너뛰기
    if [ ! -d "$synology_dir" ] && [ ! -d "$common_synology_dir" ]; then
        return
    fi
```

또한 파일 개수 세는 부분(1362-1370행)에서 common/synology/ 파일도 합산:

기존:
```bash
    local synology_files=0
    for f in "$synology_dir"/*.{yaml,yml}; do
        [ -e "$f" ] && synology_files=$((synology_files + 1))
    done
```

변경:
```bash
    local synology_files=0
    if [ -d "$synology_dir" ]; then
        for f in "$synology_dir"/*.{yaml,yml}; do
            [ -e "$f" ] && synology_files=$((synology_files + 1))
        done
    fi
    if [ -d "$common_synology_dir" ]; then
        for f in "$common_synology_dir"/*.{yaml,yml}; do
            [ -e "$f" ] && synology_files=$((synology_files + 1))
        done
    fi
```

파일 목록 출력 부분(1377-1382행)도 common/synology/ 포함:

기존 목록 출력 후 추가:
```bash
    if [ -d "$common_synology_dir" ]; then
        for f in "$common_synology_dir"/*.{yaml,yml}; do
            [ -e "$f" ] || continue
            local fname=$(basename "$f")
            print_to_user "     • $fname (공통)"
        done
    fi
```

- [ ] **Step 2: synology 복사 로직에 common/synology/ 추가**

synology 복사 블록(1540-1574행) 이후에 common/synology/ 복사 로직 추가.

`template_integrator.sh:1574` 이후에 삽입:

```bash
    # 4. Common Synology 워크플로우 처리 (선택적)
    local common_synology_dir="$project_types_dir/common/synology"
    if [ -d "$common_synology_dir" ]; then
        if [ "$INCLUDE_SYNOLOGY" = true ]; then
            print_info "공통 Synology 워크플로우 다운로드 중..."
            for workflow in "$common_synology_dir"/*.{yaml,yml}; do
                [ -e "$workflow" ] || continue
                local filename=$(basename "$workflow")

                if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                    mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
                    cp "$workflow" "$WORKFLOWS_DIR/"
                    echo "  ✓ $filename (공통 Synology, 백업: ${filename}.bak)"
                else
                    cp "$workflow" "$WORKFLOWS_DIR/"
                    echo "  ✓ $filename (공통 Synology)"
                fi
                synology_copied=$((synology_copied + 1))
                copied=$((copied + 1))
            done
        else
            local common_syn_count=0
            for f in "$common_synology_dir"/*.{yaml,yml}; do
                [ -e "$f" ] && common_syn_count=$((common_syn_count + 1))
            done
            if [ $common_syn_count -gt 0 ]; then
                print_info "공통 Synology 워크플로우 $common_syn_count개 제외됨 (--synology 옵션으로 포함 가능)"
            fi
        fi
    fi
```

- [ ] **Step 3: 변경 확인**

```bash
grep -n "common.*synology\|common/synology" template_integrator.sh
```

Expected: 새로 추가한 로직이 검색됨

---

### Task 3: template_integrator.ps1에 동일 로직 추가

**Files:**
- Modify: `template_integrator.ps1`

PowerShell 버전에도 동일한 수정 적용:

- [ ] **Step 1: Ask-SynologyOption 함수에 common/synology 체크 추가**

기존 함수에서 `$TypeDir/synology`만 체크하는 부분을 `common/synology`도 체크하도록 수정.

- [ ] **Step 2: Download-Workflows 함수에 common/synology 복사 로직 추가**

타입별 synology 복사 로직 이후에 common/synology/ 파일도 조건부 복사.

- [ ] **Step 3: 변경 확인**

```powershell
Select-String -Path template_integrator.ps1 -Pattern "common.*synology"
```

---

## Chunk 3: 문서 업데이트

### Task 4: CLAUDE.md 업데이트

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 핵심 워크플로우 > 공통 워크플로우 테이블에 행 추가**

`PROJECT-COMMON-PROJECTS-SYNC-MANAGER` 행 아래에 추가:

```markdown
| `PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD` | main 푸시 | GitHub Secret 파일 Synology 업로드 |
```

- [ ] **Step 2: 필수 GitHub Secrets에 Synology 섹션 추가**

공통 Secrets 섹션 아래에 새 섹션 추가:

```markdown
### Synology Secret 파일 업로드
```
SERVER_HOST      # Synology NAS 주소
SERVER_USER      # SSH 사용자명
SERVER_PASSWORD  # SSH 비밀번호
```
```

- [ ] **Step 3: 브랜치 기반 트리거 테이블 업데이트**

`main` push 행 업데이트:

```markdown
| `main` | push | VERSION-CONTROL, FLUTTER-CI, SECRET-FILE-UPLOAD |
```

---

### Task 5: WORKFLOW-COMMENT-GUIDELINES.md 상태 테이블 업데이트

**Files:**
- Modify: `docs/WORKFLOW-COMMENT-GUIDELINES.md`

- [ ] **Step 1: project-types/common/ 테이블에 행 추가**

Section 10의 `project-types/common/` 테이블에:

```markdown
| SYNOLOGY-SECRET-FILE-UPLOAD | D | ✅ |
```

---

## 실행 순서 요약

```
Task 1: 원본 워크플로우 작성 (common/synology/)
  ↓
Task 2: template_integrator.sh 수정 (common/synology/ 복사 로직)
  ↓
Task 3: template_integrator.ps1 수정 (동일 로직)
  ↓
Task 4: CLAUDE.md 문서 업데이트
  ↓
Task 5: WORKFLOW-COMMENT-GUIDELINES.md 상태 테이블 업데이트
```
