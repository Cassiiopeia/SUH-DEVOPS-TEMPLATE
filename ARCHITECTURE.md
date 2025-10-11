# 🏗️ 시스템 아키텍처

이 문서는 SUH-DEVOPS-TEMPLATE의 시스템 아키텍처, 설계 결정, 데이터 흐름을 설명합니다.

---

## 📋 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [시스템 아키텍처](#시스템-아키텍처)
3. [디렉토리 구조](#디렉토리-구조)
4. [핵심 컴포넌트](#핵심-컴포넌트)
5. [데이터 흐름](#데이터-흐름)
6. [워크플로우 트리거 체인](#워크플로우-트리거-체인)
7. [버전 관리 메커니즘](#버전-관리-메커니즘)
8. [브랜치 감지 시스템](#브랜치-감지-시스템)
9. [설계 결정](#설계-결정)
10. [확장성 및 유지보수](#확장성-및-유지보수)

---

## 프로젝트 개요

### 목적
GitHub Actions를 활용한 **완전 자동화된 DevOps 템플릿**으로, 다음을 제공합니다:
- 버전 관리 자동화
- AI 기반 체인지로그 생성
- 동적 브랜치 감지
- 멀티 플랫폼 프로젝트 지원

### 핵심 가치
1. **제로 설정**: 3개 파일 복사로 완전한 환경 구축
2. **완전 자동화**: 수동 작업 90% 이상 제거
3. **범용성**: 7가지 프로젝트 타입 지원
4. **AI 통합**: CodeRabbit을 활용한 지능적 문서화

---

## 시스템 아키텍처

### 전체 구조

```
┌──────────────────────────────────────────────────────────────┐
│                      GitHub Repository                        │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Repository Metadata                        │ │
│  │  - default_branch: "main"                               │ │
│  │  - owner: "username"                                    │ │
│  │  - name: "project-name"                                 │ │
│  └─────────────────────┬───────────────────────────────────┘ │
│                        │                                      │
└────────────────────────┼──────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                  Template Initialization                      │
│           (사용자가 수동으로 한 번만 실행)                    │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │         template_initializer.sh v2.0.0                  │ │
│  │                                                           │ │
│  │  1. 동적 브랜치 감지 (3단계 폴백)                        │ │
│  │     ├─ gh CLI                                            │ │
│  │     ├─ git symbolic-ref                                  │ │
│  │     ├─ git remote show                                   │ │
│  │     └─ fallback: "main"                                  │ │
│  │                                                           │ │
│  │  2. version.yml 생성                                     │ │
│  │     ├─ version: "1.0.0"                                  │ │
│  │     ├─ version_code: 1                                   │ │
│  │     ├─ project_type: "spring"                            │ │
│  │     └─ metadata.default_branch: "main"                   │ │
│  │                                                           │ │
│  │  3. 워크플로우 트리거 자동 수정                          │ │
│  │     └─ branches: ["main"] → ["detected_branch"]         │ │
│  │                                                           │ │
│  │  4. 템플릿 파일 정리                                     │ │
│  │     └─ CHANGELOG, LICENSE 등 삭제                        │ │
│  │                                                           │ │
│  │  5. README 초기화 + 이슈 템플릿 수정                    │ │
│  └─────────────────────────────────────────────────────────┘ │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                   Runtime Automation                          │
│                (GitHub Actions 자동 실행)                     │
│                                                                │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────┐│
│  │ Version Control  │  │  Changelog Gen   │  │ README Update││
│  │                  │  │                  │  │              ││
│  │ [main push]      │  │ [deploy PR]      │  │[deploy push]││
│  │      ▼           │  │      ▼           │  │      ▼      ││
│  │ version_manager  │  │ changelog_mgr    │  │ README sync ││
│  │      .sh         │  │      .py         │  │             ││
│  │      ▼           │  │      ▼           │  │      ▼      ││
│  │ increment        │  │ CodeRabbit parse │  │ version     ││
│  │ version          │  │ → CHANGELOG      │  │ update      ││
│  │      ▼           │  │   .json/.md      │  │             ││
│  │ Git tag          │  │                  │  │             ││
│  └──────────────────┘  └──────────────────┘  └─────────────┘│
└──────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                    Storage Layer                              │
│                                                                │
│  ┌─────────────┐  ┌───────────┐  ┌────────────┐             │
│  │ version.yml │  │ CHANGELOG │  │ README.md  │             │
│  │             │  │ .json/.md │  │            │             │
│  │ - version   │  │           │  │ - version  │             │
│  │ - type      │  │ - entries │  │   display  │             │
│  │ - metadata  │  │ - history │  │            │             │
│  └─────────────┘  └───────────┘  └────────────┘             │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐   │
│  │        Project-Specific Version Files                 │   │
│  │                                                         │   │
│  │  build.gradle  pubspec.yaml  package.json  etc.       │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

---

## 디렉토리 구조

```
suh-github-template/
│
├── 📄 version.yml                      # 🔥 중앙 버전 관리 파일
├── 📄 CHANGELOG.json                   # 구조화된 체인지로그 (자동 생성)
├── 📄 CHANGELOG.md                     # 가독성 높은 체인지로그 (자동 생성)
├── 📄 README.md                        # 프로젝트 개요
├── 📄 SETUP-GUIDE.md                   # 상세 설정 가이드
├── 📄 SCRIPTS_GUIDE.md                 # 스크립트 사용법
├── 📄 WORKFLOWS.md                     # 워크플로우 상세
├── 📄 ARCHITECTURE.md                  # 이 문서
├── 📄 TROUBLESHOOTING.md               # 트러블슈팅
├── 📄 CONTRIBUTING.md                  # 기여 가이드
├── 📄 LICENSE                          # MIT 라이선스
│
├── 📁 .github/
│   │
│   ├── 📁 workflows/                   # 🔥 GitHub Actions 워크플로우
│   │   ├── PROJECT-VERSION-CONTROL.yaml           # 버전 자동 관리
│   │   ├── PROJECT-AUTO-CHANGELOG-CONTROL.yaml    # 체인지로그 생성
│   │   ├── PROJECT-README-VERSION-UPDATE.yaml     # README 동기화
│   │   ├── PROJECT-TEMPLATE-INITIALIZER.yaml      # 템플릿 초기화 자동화
│   │   ├── PROJECT-ISSUE-COMMENT.yaml             # 이슈 자동화
│   │   ├── PROJECT-SYNC-ISSUE-LABELS.yaml         # 라벨 동기화
│   │   ├── PROJECT-SPRING-CICD.yaml               # Spring Boot CI/CD
│   │   ├── PROJECT-SAMPLE-CICD.yaml               # 범용 CI/CD 샘플
│   │   ├── PROJECT-SAMPLE-NEXUS-PUBLISH.yml       # Nexus 배포 샘플
│   │   └── PROJECT-SAMPLE-NEXUS-MODULE-CI-BUILD-CHECK.yml
│   │
│   ├── 📁 scripts/                     # 🔥 자동화 스크립트
│   │   ├── version_manager.sh         # 버전 관리 (Bash)
│   │   └── changelog_manager.py       # 체인지로그 관리 (Python)
│   │
│   ├── 📁 ISSUE_TEMPLATE/              # 이슈 템플릿
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   ├── design_request.md
│   │   ├── config.yml
│   │   └── issue-label.yml
│   │
│   ├── 📁 DISCUSSION_TEMPLATE/         # 토론 템플릿
│   │   ├── announcements.yaml
│   │   └── documents.yaml
│   │
│   ├── 📄 PULL_REQUEST_TEMPLATE.md     # PR 템플릿
│   └── 📄 OLD_ISSUE_TEMPLATE.md
│
├── 📁 agent-prompts/                   # AI 프롬프트 및 개발 보고서
│   ├── PPT_개발_보고서_가이드라인.md
│   ├── 기능_개발_보고서_가이드라인.md
│   ├── 버그_수정_보고서_가이드라인.md
│   └── result/
│       ├── @20250903_FEATURE_프롬프트가이드라인시스템_v1.0.4.md
│       ├── @20250928_FEATURE_버전관리오류해결_v1.1.11.md
│       ├── @20251011_FEATURE_동적_브랜치_관리_시스템_v1.2.7.md
│       └── @Cursor_Commands_가이드.md
│
└── 📄 template_initializer.sh          # 프로젝트 루트 초기화 스크립트
```

---

## 핵심 컴포넌트

### 1. version_manager.sh

**역할**: 중앙 집중식 버전 관리  
**언어**: Bash Shell Script  
**주요 기능**:
- version.yml과 프로젝트 파일 양방향 동기화
- 버전 증가 (patch, minor, major)
- version_code 관리
- 7가지 프로젝트 타입 지원

**입력**:
- `version.yml`: 중앙 버전 정보
- 프로젝트 파일: `build.gradle`, `pubspec.yaml`, `package.json` 등

**출력**:
- 동기화된 버전 정보
- 업데이트된 모든 버전 파일

**핵심 함수**:
```bash
get_version()               # 현재 버전 조회
sync_versions()             # 버전 동기화
increment_patch_version()   # 패치 버전 증가
update_all_versions()       # 모든 파일 업데이트
```

---

### 2. template_initializer.sh

**역할**: 템플릿 프로젝트 초기화  
**언어**: Bash Shell Script  
**버전**: v2.0.0  
**주요 기능**:
- 동적 브랜치 감지 (3단계 폴백)
- version.yml 생성
- 워크플로우 트리거 자동 수정
- 템플릿 파일 정리

**입력**:
- 명령줄 파라미터: `--version`, `--type`
- GitHub 리포지토리 메타데이터

**출력**:
- `version.yml`: 초기화된 버전 설정
- 수정된 워크플로우 파일
- 초기화된 README.md
- 업데이트된 이슈 템플릿

**핵심 함수**:
```bash
detect_default_branch()     # 브랜치 자동 감지
create_version_yml()        # version.yml 생성
update_workflow_triggers()  # 워크플로우 수정
cleanup_template_files()    # 템플릿 파일 삭제
```

---

### 3. changelog_manager.py

**역할**: AI 기반 체인지로그 생성  
**언어**: Python 3  
**주요 기능**:
- CodeRabbit AI 리뷰 파싱
- CHANGELOG.json 업데이트
- CHANGELOG.md 생성
- 릴리즈 노트 추출

**입력**:
- PR 코멘트 (CodeRabbit 리뷰)
- 환경 변수: `GITHUB_TOKEN`, `PR_NUMBER`

**출력**:
- `CHANGELOG.json`: 구조화된 변경 이력
- `CHANGELOG.md`: 가독성 높은 체인지로그

**핵심 함수**:
```python
parse_coderabbit_summary()  # AI 리뷰 파싱
update_changelog()          # CHANGELOG.json 업데이트
generate_markdown()         # CHANGELOG.md 생성
export_release_notes()      # 릴리즈 노트 추출
```

---

### 4. version.yml (데이터 모델)

**역할**: 단일 진실 공급원 (Single Source of Truth)  
**형식**: YAML  
**구조**:

```yaml
version: "1.3.0"            # 시맨틱 버전 (x.y.z)
version_code: 14            # 빌드 번호 (모바일 앱)
project_type: "basic"       # 프로젝트 타입
metadata:
  last_updated: "2025-10-11 09:12:11"
  last_updated_by: "Cassiiopeia"
  default_branch: "main"    # 자동 감지된 기본 브랜치
```

**필드 설명**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `version` | String | ✅ | 시맨틱 버전 (x.y.z) |
| `version_code` | Integer | ✅ | 모바일 앱 빌드 번호 |
| `project_type` | Enum | ✅ | spring, flutter, react, react-native, react-native-expo, node, python, basic |
| `metadata.last_updated` | DateTime | ❌ | 마지막 업데이트 시각 (UTC) |
| `metadata.last_updated_by` | String | ❌ | 마지막 업데이트 사용자 |
| `metadata.default_branch` | String | ❌ | 기본 브랜치명 |

---

## 데이터 흐름

### 1. 템플릿 초기화 플로우

```
┌─────────────┐
│   사용자    │
│   실행      │
└──────┬──────┘
       │ ./template_initializer.sh -v 1.0.0 -t spring
       ▼
┌──────────────────────────────────────┐
│   1. 파라미터 검증                  │
│   - 버전 형식 체크 (x.y.z)         │
│   - 프로젝트 타입 검증              │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│   2. 브랜치 감지 (3단계 폴백)       │
│   ┌────────────────────────────┐   │
│   │ try: gh CLI                │   │
│   └────┬───────────────────────┘   │
│        │ fail                       │
│   ┌────▼───────────────────────┐   │
│   │ try: git symbolic-ref      │   │
│   └────┬───────────────────────┘   │
│        │ fail                       │
│   ┌────▼───────────────────────┐   │
│   │ try: git remote show       │   │
│   └────┬───────────────────────┘   │
│        │ fail                       │
│   ┌────▼───────────────────────┐   │
│   │ fallback: "main"           │   │
│   └────────────────────────────┘   │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│   3. version.yml 생성               │
│   - version: "1.0.0"                │
│   - version_code: 1                 │
│   - project_type: "spring"          │
│   - metadata.default_branch         │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│   4. 워크플로우 수정                │
│   (브랜치가 "main"이 아닌 경우)     │
│   - branches: ["main"]              │
│     → branches: ["detected"]        │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│   5. 템플릿 파일 삭제               │
│   - CHANGELOG.md/.json              │
│   - LICENSE, CONTRIBUTING.md        │
│   - test/ 폴더                      │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│   6. README 초기화                  │
│   - 프로젝트명 + 버전 표시          │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│   7. 이슈 템플릿 assignee 변경      │
│   - Cassiiopeia → current_owner     │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│   ✅ 초기화 완료 요약 출력          │
└──────────────────────────────────────┘
```

---

### 2. 버전 자동 증가 플로우 (GitHub Actions)

```
┌─────────────────────────────────────────┐
│   Trigger: push to main branch          │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   PROJECT-VERSION-CONTROL.yaml          │
│   (GitHub Actions Workflow)             │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   1. 저장소 체크아웃                    │
│   - ref: ${{ default_branch || 'main' }}│
│   - fetch-depth: 0                      │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   2. 스크립트 실행 권한 부여            │
│   - chmod +x version_manager.sh         │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   3. 버전 동기화 및 증가                │
│   ./version_manager.sh increment        │
│                                          │
│   ┌───────────────────────────────────┐ │
│   │ sync_versions()                   │ │
│   │ ├─ version.yml: "1.0.0"           │ │
│   │ ├─ build.gradle: "1.0.0"          │ │
│   │ └─ ✅ 버전 일치                   │ │
│   └───────────────────────────────────┘ │
│                                          │
│   ┌───────────────────────────────────┐ │
│   │ increment_patch_version()         │ │
│   │ └─ 1.0.0 → 1.0.1                  │ │
│   └───────────────────────────────────┘ │
│                                          │
│   ┌───────────────────────────────────┐ │
│   │ increment_version_code()          │ │
│   │ └─ 1 → 2                          │ │
│   └───────────────────────────────────┘ │
│                                          │
│   ┌───────────────────────────────────┐ │
│   │ update_all_versions()             │ │
│   │ ├─ version.yml → "1.0.1"          │ │
│   │ └─ build.gradle → "1.0.1"         │ │
│   └───────────────────────────────────┘ │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   4. 변경사항 커밋                      │
│   - git add version.yml build.gradle    │
│   - git commit -m "chore: bump v1.0.1"  │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   5. Git 태그 생성 및 푸시              │
│   - git tag v1.0.1                      │
│   - git push origin v1.0.1              │
│   - git push origin HEAD:main           │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   ✅ 워크플로우 완료                    │
│   - 버전: 1.0.0 → 1.0.1                 │
│   - 태그: v1.0.1 생성                   │
└─────────────────────────────────────────┘
```

---

### 3. 체인지로그 생성 플로우

```
┌─────────────────────────────────────────┐
│   Trigger: PR to deploy branch          │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   1. CodeRabbit AI 자동 리뷰            │
│   - 코드 변경사항 분석                  │
│   - PR 코멘트로 리뷰 작성               │
│                                          │
│   ┌───────────────────────────────────┐ │
│   │ ## Summary by CodeRabbit          │ │
│   │                                   │ │
│   │ **Release Notes**                 │ │
│   │                                   │ │
│   │ **신규 기능**                     │ │
│   │ - 동적 브랜치 감지 추가           │ │
│   │                                   │ │
│   │ **버그 수정**                     │ │
│   │ - Flutter 버전 형식 오류 수정     │ │
│   └───────────────────────────────────┘ │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   2. PROJECT-AUTO-CHANGELOG-CONTROL     │
│   (GitHub Actions Workflow)             │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   3. changelog_manager.py 실행          │
│   python3 changelog_manager.py \        │
│     update-from-summary                 │
│                                          │
│   ┌───────────────────────────────────┐ │
│   │ parse_coderabbit_summary()        │ │
│   │ ├─ PR 코멘트 조회                │ │
│   │ ├─ CodeRabbit 리뷰 추출          │ │
│   │ └─ HTML 파싱 (이중 전략)         │ │
│   └───────────────────────────────────┘ │
│                                          │
│   ┌───────────────────────────────────┐ │
│   │ update_changelog()                │ │
│   │ └─ CHANGELOG.json 업데이트        │ │
│   │    {                              │ │
│   │      "version": "1.0.1",          │ │
│   │      "changes": {                 │ │
│   │        "features": [...],         │ │
│   │        "bugfixes": [...]          │ │
│   │      }                             │ │
│   │    }                              │ │
│   └───────────────────────────────────┘ │
│                                          │
│   ┌───────────────────────────────────┐ │
│   │ generate_markdown()               │ │
│   │ └─ CHANGELOG.md 생성              │ │
│   │    ## [1.0.1] - 2025-10-11        │ │
│   │                                   │ │
│   │    **신규 기능**                  │ │
│   │    - 동적 브랜치 감지 추가        │ │
│   └───────────────────────────────────┘ │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   4. 변경사항 커밋 및 푸시              │
│   - git add CHANGELOG.json/.md          │
│   - git commit -m "docs: update"        │
│   - git push origin deploy              │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   5. PR 자동 머지                       │
│   - 조건 충족 시 자동 머지              │
└────────────┬────────────────────────────┘
             ▼
┌─────────────────────────────────────────┐
│   ✅ 체인지로그 생성 완료               │
└─────────────────────────────────────────┘
```

---

## 워크플로우 트리거 체인

### 트리거 조건 및 실행 순서

```
┌────────────────────────────────────────────────────────────┐
│                       사용자 액션                          │
└───────────┬────────────────────────────────────────────────┘
            │
   ┌────────┴────────┐
   │                 │
   ▼                 ▼
[git push main]   [PR to deploy]
   │                 │
   │                 ▼
   │         ┌───────────────────────────────────┐
   │         │  CodeRabbit AI 리뷰 (자동)        │
   │         └────────────┬──────────────────────┘
   │                      │
   │                      ▼
   ▼         ┌───────────────────────────────────┐
┌─────────────────────────┐  PROJECT-AUTO-CHANGELOG-CONTROL  │
│ PROJECT-VERSION-CONTROL │            (deploy PR)            │
│      (main push)        │ └────────────┬──────────────────────┘
└────────────┬────────────┘              │
             │                           ▼
             │              ┌───────────────────────────────┐
             │              │  changelog_manager.py         │
             │              │  - CodeRabbit 파싱            │
             │              │  - CHANGELOG 생성             │
             │              └────────────┬──────────────────┘
             │                           │
             │                           ▼
             │              ┌───────────────────────────────┐
             │              │  PR 자동 머지                 │
             │              └────────────┬──────────────────┘
             │                           │
             │                           ▼
             │              ┌───────────────────────────────┐
             │              │  PROJECT-README-VERSION-UPDATE│
             │              │     (deploy push)             │
             │              └────────────┬──────────────────┘
             │                           │
             ▼                           ▼
┌────────────────────────────────────────────────────────────┐
│  version_manager.sh increment      README.md version update │
│  ├─ 버전 증가: 1.0.0 → 1.0.1       ├─ 최신 버전 표기       │
│  ├─ version_code 증가              └─ 날짜 업데이트        │
│  ├─ Git 태그 생성                                          │
│  └─ 커밋 및 푸시                                           │
└────────────────────────────────────────────────────────────┘
            │
            ▼
┌────────────────────────────────────────────────────────────┐
│               모든 자동화 완료                             │
│  ✅ 버전 업데이트                                          │
│  ✅ 체인지로그 생성                                        │
│  ✅ README 동기화                                          │
│  ✅ Git 태그 생성                                          │
└────────────────────────────────────────────────────────────┘
```

---

## 버전 관리 메커니즘

### 버전 동기화 알고리즘

```
┌──────────────────────────────────────────────────────┐
│  sync_versions()                                     │
└─────────────┬────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────────┐
│  1. version.yml 버전 읽기                            │
│     └─ get_version_from_yml() → "1.0.0"             │
└─────────────┬────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────────┐
│  2. 프로젝트 파일 버전 읽기                          │
│     └─ get_project_version() → "1.0.5"              │
│        (project_type에 따라 다른 파일 조회)          │
└─────────────┬────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────────┐
│  3. 버전 비교                                        │
│     compare_versions("1.0.0", "1.0.5")              │
└─────────────┬────────────────────────────────────────┘
              │
         ┌────┴────┐
         │         │
    [같음]    [다름]
         │         │
         ▼         ▼
  ┌──────────┐  ┌────────────────────────────────────┐
  │ 현재 버전│  │  4. 높은 버전 선택                 │
  │   반환   │  │     max("1.0.0", "1.0.5") = "1.0.5"│
  └──────────┘  └─────────────┬──────────────────────┘
                              │
                              ▼
                ┌────────────────────────────────────┐
                │  5. 양쪽 모두 업데이트             │
                │  ├─ update_version_yml("1.0.5")   │
                │  └─ update_project_file("1.0.5")  │
                └─────────────┬──────────────────────┘
                              │
                              ▼
                ┌────────────────────────────────────┐
                │  6. 동기화된 버전 반환             │
                │     return "1.0.5"                 │
                └────────────────────────────────────┘
```

### 프로젝트 타입별 버전 파일 매핑

```
project_type     →    Version File              →    Format
─────────────────────────────────────────────────────────────
spring           →    build.gradle             →    version = "x.y.z"
                      (모든 하위 build.gradle도 업데이트)

flutter          →    pubspec.yaml             →    version: x.y.z+buildNumber
                      (version + version_code 조합)

react/node       →    package.json             →    "version": "x.y.z"

react-native     →    ios/*/Info.plist         →    CFBundleShortVersionString
                 →    android/app/build.gradle →    versionName "x.y.z"
                      (iOS 우선, 없으면 Android)

react-native-    →    app.json                 →    "expo": {"version": "x.y.z"}
expo

python           →    pyproject.toml           →    version = "x.y.z"

basic            →    version.yml only         →    version: "x.y.z"
```

---

## 브랜치 감지 시스템

### 3단계 폴백 메커니즘

```
┌──────────────────────────────────────────────────────┐
│  detect_default_branch()                             │
└─────────────┬────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────────┐
│  🥇 방법 1: GitHub CLI (gh)                         │
│                                                       │
│  command -v gh >/dev/null 2>&1                       │
│  └─ [성공]                                           │
│      └─ gh repo view \                               │
│         --json defaultBranchRef \                    │
│         -q .defaultBranchRef.name                    │
│                                                       │
│  장점:                                               │
│  ✅ 가장 정확 (GitHub API 직접 조회)                │
│  ✅ 리포지토리 설정 그대로 반영                      │
│                                                       │
│  단점:                                               │
│  ❌ gh CLI 설치 필요                                 │
│  ❌ 인증 필요 (gh auth login)                        │
└─────────────┬────────────────────────────────────────┘
              │
         [실패] │ [성공] → return branch
              │
              ▼
┌──────────────────────────────────────────────────────┐
│  🥈 방법 2: git symbolic-ref                        │
│                                                       │
│  git symbolic-ref refs/remotes/origin/HEAD           │
│  └─ sed 's@^refs/remotes/origin/@@'                 │
│                                                       │
│  장점:                                               │
│  ✅ 로컬 Git 설정 기반                               │
│  ✅ 빠르고 가벼움                                    │
│                                                       │
│  단점:                                               │
│  ❌ origin/HEAD 설정 필요                            │
│  ❌ git remote set-head 실행 필요할 수 있음          │
└─────────────┬────────────────────────────────────────┘
              │
         [실패] │ [성공] → return branch
              │
              ▼
┌──────────────────────────────────────────────────────┐
│  🥉 방법 3: git remote show origin                  │
│                                                       │
│  git remote show origin | \                          │
│  grep 'HEAD branch' | \                              │
│  sed 's/.*: //'                                      │
│                                                       │
│  장점:                                               │
│  ✅ 원격 저장소 정보 직접 조회                       │
│  ✅ 대부분의 환경에서 동작                           │
│                                                       │
│  단점:                                               │
│  ❌ 네트워크 연결 필요                               │
│  ❌ 느림 (원격 조회)                                 │
└─────────────┬────────────────────────────────────────┘
              │
         [실패] │ [성공] → return branch
              │
              ▼
┌──────────────────────────────────────────────────────┐
│  🆘 최종 폴백: "main"                                │
│                                                       │
│  print_warning "자동 감지 실패, 기본값 사용: main"  │
│  return "main"                                       │
│                                                       │
│  이유:                                               │
│  - "main"이 현재 GitHub 표준 브랜치명                │
│  - 대부분의 최신 프로젝트가 "main" 사용             │
│  - 워크플로우 기본값도 "main"                        │
└──────────────────────────────────────────────────────┘
```

---

## 설계 결정

### 1. Bash Shell Script 선택 이유

**선택**: Bash Shell Script  
**대안**: Python, Node.js, Go

**근거**:
- ✅ GitHub Actions 기본 환경 (Ubuntu runner)에 설치됨
- ✅ Git 명령어와 자연스러운 통합
- ✅ 텍스트 처리에 강함 (sed, awk, grep)
- ✅ 추가 런타임 설치 불필요
- ✅ 파일 시스템 작업에 최적화

**트레이드오프**:
- ❌ 복잡한 로직 작성 어려움 → Python(changelog_manager.py)로 보완
- ❌ 타입 안정성 없음 → 철저한 검증 로직으로 보완
- ❌ 테스트 작성 어려움 → 통합 테스트 중심

---

### 2. version.yml 중앙 집중식 관리

**선택**: `version.yml` 단일 파일로 중앙 관리  
**대안**: 각 프로젝트 파일만 사용 (build.gradle, package.json 등)

**근거**:
- ✅ **단일 진실 공급원** (Single Source of Truth)
- ✅ 프로젝트 타입 변경 시에도 일관성 유지
- ✅ 워크플로우에서 쉽게 접근 가능
- ✅ metadata 추가 가능 (last_updated, default_branch)
- ✅ 7가지 프로젝트 타입 통일된 방식으로 관리

**트레이드오프**:
- ❌ 추가 파일 관리 필요 → 하지만 자동화로 부담 없음
- ❌ 동기화 로직 필요 → version_manager.sh가 자동 처리

---

### 3. 양방향 동기화 (Bidirectional Sync)

**선택**: version.yml ↔ 프로젝트 파일 양방향 동기화  
**대안**: 단방향 (version.yml → 프로젝트 파일만)

**근거**:
- ✅ 수동으로 프로젝트 파일 수정해도 자동 감지
- ✅ "높은 버전 우선" 정책으로 충돌 자동 해결
- ✅ 유연성 제공 (어느 쪽을 수정해도 OK)
- ✅ 팀 협업 시 버전 불일치 방지

**트레이드오프**:
- ❌ 로직 복잡도 증가 → compare_versions() 함수로 해결
- ❌ 의도치 않은 버전 상승 가능 → 경고 메시지 출력

---

### 4. CodeRabbit AI 통합

**선택**: CodeRabbit AI 리뷰 기반 체인지로그 생성  
**대안**: 커밋 메시지 기반, 수동 작성

**근거**:
- ✅ **높은 품질**의 체인지로그 자동 생성
- ✅ 코드 변경사항 정확한 요약
- ✅ 카테고리 자동 분류 (features, bugfixes 등)
- ✅ 개발자 부담 제거 (체인지로그 작성 불필요)

**트레이드오프**:
- ❌ CodeRabbit 의존성 → 하지만 대부분의 팀이 이미 사용
- ❌ PR 필요 → 이미 베스트 프랙티스

---

### 5. 동적 브랜치 감지

**선택**: 3단계 폴백 메커니즘으로 동적 감지  
**대안**: "main" 고정, 사용자가 수동 설정

**근거**:
- ✅ **범용성**: main, master, develop 등 모든 브랜치 지원
- ✅ **제로 설정**: 사용자 입력 불필요
- ✅ **안정성**: 3단계 폴백으로 실패율 최소화
- ✅ GitHub의 브랜치명 변화 대응 (master → main 추세)

**트레이드오프**:
- ❌ 복잡도 증가 → 하지만 한 번만 실행 (초기화 시)
- ❌ 실패 가능성 → 최종 폴백("main")으로 보장

---

## 확장성 및 유지보수

### 새 프로젝트 타입 추가 방법

1. **`version_manager.sh` 수정**

```bash
# VALID_TYPES 배열에 추가
VALID_TYPES=("spring" "flutter" "react" "react-native" 
             "react-native-expo" "node" "python" "basic" "new-type")  # ← 추가

# get_project_version_file() 함수에 case 추가
"new-type")
    VERSION_FILE="path/to/version/file"
    ;;

# get_project_version() 함수에 파싱 로직 추가
"new-type")
    version=$(grep 'version_pattern' "$VERSION_FILE" | awk '{print $2}')
    echo "$version"
    ;;

# save_to_project_file() 함수에 업데이트 로직 추가
"new-type")
    sed -i.bak "s/version_pattern.*/new_pattern/" "$VERSION_FILE"
    ;;
```

2. **테스트 작성**

```bash
# test/test_new_type.sh
test_new_type_version_sync() {
    # 테스트 파일 생성
    echo 'version = "1.0.0"' > test_version_file
    echo 'version: "1.0.0"' > version.yml
    echo 'project_type: "new-type"' >> version.yml
    
    # 동기화 테스트
    result=$(./version_manager.sh sync)
    assert_equals "1.0.0" "$result" "new-type 동기화"
    
    # 정리
    rm test_version_file version.yml
}
```

3. **문서 업데이트**
   - `SCRIPTS_GUIDE.md`에 새 타입 설명 추가
   - `README.md`의 지원 타입 목록 업데이트

---

### 코드 유지보수 가이드

#### 주석 규칙
```bash
# 함수 설명: 한 줄로 명확하게
# 파라미터: $1 - 설명
# 반환값: 설명
# 사용 예: 구체적 예시
function_name() {
    # 구현
}
```

#### 에러 처리 일관성
```bash
# ✅ 좋은 예
if [ condition ]; then
    print_error "명확한 에러 메시지"
    print_error "해결 방법 제시"
    exit 1
fi

# ❌ 나쁜 예
if [ condition ]; then
    echo "error"  # 불명확
    exit 1
fi
```

#### 버전 호환성 유지
- 하위 호환성 최우선
- Breaking change는 Major 버전에서만
- deprecation 경고 → 1 버전 후 제거

---

## 참고 자료

- [GitHub Actions 공식 문서](https://docs.github.com/en/actions)
- [Semantic Versioning](https://semver.org/lang/ko/)
- [Bash Shell Scripting Guide](https://www.gnu.org/software/bash/manual/)
- [CodeRabbit Documentation](https://docs.coderabbit.ai/)

---

**📌 이 문서는 SUH-DEVOPS-TEMPLATE v1.3.0 기준으로 작성되었습니다.**  
**📅 최종 업데이트: 2025년 10월 11일**  
**✍️ 작성자: SUH-DEVOPS-TEMPLATE 팀**

