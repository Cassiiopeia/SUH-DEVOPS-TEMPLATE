# GitHub Projects Sync Wizard 구현 완료 보고서

> **Issue**: #163 - Github Projects 에 대한 템플릿 개발 필요 및 관련 Sync 워크플로우 개발 필요
> **작성일**: 2026-01-22
> **최종 버전**: v2.4.0

---

## 📋 개요

GitHub Organization Projects의 Status 컬럼과 Repository Issue의 Label 간 **양방향 자동 동기화**를 구현하는 Cloudflare Worker 기반 시스템입니다.

### 핵심 기능
- **Projects → Labels**: Project 카드 Status 변경 시 해당 Issue Label 자동 업데이트
- **Labels → Projects**: Issue Label 변경 시 해당 Project 카드 Status 자동 업데이트
- **Webhook 보안**: HMAC-SHA256 서명 검증으로 안전한 통신

---

## ⚠️ 중요 제한사항 (v2.4.0)

### User Projects 미지원

GitHub API 제한으로 인해 **Organization Projects만 지원**합니다.

| 구분 | Organization Projects | User Projects |
|------|----------------------|---------------|
| Webhook 위치 | Organization Webhook | Repository Webhook |
| `Projects v2 items` 이벤트 | ✅ 지원 | ❌ **미지원** |
| 지원 여부 | ✅ **지원** | ❌ 미지원 |

**기술적 원인**: Repository Webhook에는 `Projects v2 items` 이벤트가 없으므로 User Projects의 Status 변경을 감지할 수 없습니다.

---

## 🏗️ 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Organization                           │
│  ┌──────────────────┐         ┌──────────────────────────────┐  │
│  │  Organization    │         │      Repository              │  │
│  │  Projects (v2)   │         │  ┌────────────────────────┐  │  │
│  │                  │         │  │  Issues                │  │  │
│  │  ┌────────────┐  │         │  │  ┌──────────────────┐  │  │  │
│  │  │ Status 컬럼 │  │←───────→│  │  │ Labels (status) │  │  │  │
│  │  │ (작업 전,   │  │  동기화  │  │  │ 작업 전, 작업 중 │  │  │  │
│  │  │  작업 중..) │  │         │  │  │ 확인 대기, ...  │  │  │  │
│  │  └────────────┘  │         │  │  └──────────────────┘  │  │  │
│  └────────┬─────────┘         │  └───────────┬────────────┘  │  │
│           │                   └──────────────┼───────────────┘  │
│           │                                  │                  │
│  ┌────────┴──────────────────────────────────┴───────────┐      │
│  │              Organization Webhook                      │      │
│  │  Events: projects_v2_item, issues (labeled/unlabeled) │      │
│  └────────────────────────┬──────────────────────────────┘      │
└───────────────────────────┼─────────────────────────────────────┘
                            │ HTTPS POST
                            │ (HMAC-SHA256 서명)
                            ▼
              ┌─────────────────────────────┐
              │    Cloudflare Worker        │
              │    (projects-sync-worker)   │
              │                             │
              │  ┌───────────────────────┐  │
              │  │ 서명 검증 (SHA256)    │  │
              │  │ 이벤트 타입 분기      │  │
              │  │ GraphQL API (Status)  │  │
              │  │ REST API (Labels)     │  │
              │  └───────────────────────┘  │
              │                             │
              │  환경변수:                  │
              │  - GITHUB_TOKEN            │
              │  - WEBHOOK_SECRET          │
              │  - ORG_NAME                │
              │  - PROJECT_NUMBER          │
              │  - STATUS_LABELS           │
              └─────────────────────────────┘
```

---

## 📁 파일 구조

```
.github/util/common/projects-sync-wizard/
├── projects-sync-wizard.html      # 마법사 UI (웹 인터페이스)
├── projects-sync-wizard.js        # 마법사 로직 (상태 관리, URL 파싱)
├── projects-sync-wizard-setup.sh  # Bash 설치 스크립트 (Mac/Linux)
├── projects-sync-wizard-setup.ps1 # PowerShell 설치 스크립트 (Windows)
├── version.json                   # 버전 정보 및 변경 이력
├── version-sync.sh                # HTML 버전 동기화 스크립트
├── README.md                      # 문서
└── templates/                     # Worker 템플릿 파일
    ├── package.json.template
    ├── tsconfig.json.template
    ├── wrangler.toml.template
    └── src/
        └── index.ts.template      # Worker 메인 코드
```

---

## 🚀 설정 프로세스 (4단계)

### Step 1: 프로젝트 정보 입력

마법사 UI에서 입력하는 정보:

| 항목 | 설명 | 예시 |
|------|------|------|
| Projects URL | Organization Projects URL | `github.com/orgs/TEAM-ROMROM/projects/6` |
| GitHub Token | PAT (repo, read:project 권한) | `ghp_xxxx...` |
| Worker 이름 | Cloudflare Worker 이름 | `github-projects-romrom-sync-worker` |
| Status Labels | 동기화할 Label 목록 | 작업 전, 작업 중, 확인 대기, ... |
| Webhook Secret | 보안 서명용 시크릿 | 자동 생성 (32자 랜덤) |

### Step 2: Worker 배포

생성된 curl 명령어를 터미널에서 실행:

**Mac/Linux:**
```bash
curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/.github/util/common/projects-sync-wizard/projects-sync-wizard-setup.sh" | bash -s -- \
  --owner "TEAM-ROMROM" \
  --project "6" \
  --worker-name "github-projects-romrom-sync-worker" \
  --webhook-secret "abc123..." \
  --labels "작업 전,작업 중,확인 대기,피드백,작업 완료,취소" \
  --github-token "ghp_xxxx..."
```

**Windows PowerShell:**
```powershell
$env:WIZARD_OWNER="TEAM-ROMROM"; $env:WIZARD_PROJECT="6"; ...
irm "https://raw.githubusercontent.com/.../projects-sync-wizard-setup.ps1" | iex
```

### Step 3: GitHub Webhook 설정

1. **Webhook 생성 페이지 열기**: `https://github.com/organizations/{ORG}/settings/hooks/new`
2. **설정 입력**:
   - Payload URL: Worker URL (`https://xxx.workers.dev`)
   - Content type: `application/json`
   - Secret: 마법사에서 생성된 Webhook Secret
3. **Events 선택**: `Let me select individual events` → **`Projects v2 items`** 체크

### Step 4: 완료

테스트 방법:
1. Projects에서 카드 Status 변경 → Issue Label 자동 업데이트 확인
2. Issue에서 Label 변경 → Projects Status 자동 업데이트 확인

---

## 📊 버전 이력

### v2.4.0 (2026-01-22) - 최신

- ⚠️ **User Projects 지원 중단**: GitHub API 제한으로 Organization Projects 전용
- User Projects URL 입력 시 경고 메시지 표시
- User 타입 관련 코드 전면 제거 (repositoryUrl, parseRepositoryUrl 등)
- 스크립트 인자 간소화: `--type`, `--repo-owner`, `--repo-name` 제거
- 환경변수 간소화: `WIZARD_TYPE`, `WIZARD_REPO_OWNER`, `WIZARD_REPO_NAME` 제거
- UI 간소화: User Projects용 저장소 URL 입력란 제거
- Webhook 설정 URL 개선: `/hooks` → `/hooks/new`로 바로 생성 페이지 이동
- 스크립트 완료 시 Webhook Secret 값 직접 표시 (복사 편의성 향상)

### v2.3.3 (2026-01-22)

- 오류 발생 시에도 임시 폴더 자동 삭제 (bash trap, PowerShell try/finally)

### v2.3.2 (2026-01-22)

- GitHub Token (PAT) 입력란 추가
- 원클릭 토큰 생성 링크 (권한 미리 선택)
- Secret 설정: 대화형 입력 → pipe 방식 변경

### v2.3.1 (2026-01-22)

- Worker 이름 Cloudflare 규칙 준수 (자동 소문자 변환)
- Worker 이름 기본값: `github-projects-{레포이름}-sync-worker`

### v2.3.0 (2026-01-22)

- wrangler.toml STATUS_LABELS 멀티라인 JSON 에러 수정 (`jq -sc`)
- 스크립트 파일명 변경: `projects-sync-wizard-setup.sh/ps1`
- Node.js 18+ 사전 요구사항 가이드 추가
- Mac/Linux + Windows 명령어 동시 표시

### v2.2.0 (2026-01-22)

- ZIP 다운로드 제거 → curl 원클릭 설치 명령어 방식

### v2.1.0 (2026-01-21)

- Organization + User Projects 모두 지원 (이후 v2.4.0에서 User 제거)
- URL의 `/views/N` 경로 자동 무시
- Step 1 UI 대폭 개선

### v2.0.0 (2026-01-21)

- 4단계 간소화 (기존 7단계에서 변경)
- 원클릭 설치 스크립트 추가

### v1.0.0 (2026-01-21)

- 초기 릴리즈

---

## 🔧 기술 스택

| 구성요소 | 기술 |
|----------|------|
| Worker 런타임 | Cloudflare Workers |
| Worker 언어 | TypeScript |
| 배포 도구 | Wrangler CLI |
| GitHub API | GraphQL (Projects), REST (Labels) |
| 보안 | HMAC-SHA256 Webhook 서명 검증 |
| 마법사 UI | HTML + Tailwind CSS + Vanilla JS |

---

## ✅ 구현 완료 항목

- [x] Cloudflare Worker 템플릿 (TypeScript)
- [x] 양방향 동기화 로직 (Projects ↔ Labels)
- [x] HMAC-SHA256 Webhook 서명 검증
- [x] 웹 기반 설정 마법사 (HTML/JS)
- [x] curl 원클릭 설치 스크립트 (Bash)
- [x] PowerShell 설치 스크립트 (Windows)
- [x] GitHub Token 입력 및 권한 가이드
- [x] Worker 이름 자동 소문자 변환
- [x] 임시 폴더 자동 정리 (trap/finally)
- [x] User Projects 미지원 안내 메시지
- [x] Organization 전용으로 코드 간소화

---

## 📝 사용 방법

1. **마법사 열기**: `.github/util/common/projects-sync-wizard/projects-sync-wizard.html`을 브라우저에서 열기

2. **정보 입력**: Organization Projects URL, GitHub Token, Worker 이름 입력

3. **명령어 복사**: 생성된 curl 명령어를 터미널에 붙여넣기

4. **Worker 배포**: Cloudflare 로그인 후 자동 배포

5. **Webhook 설정**: 안내에 따라 Organization Webhook 생성

6. **테스트**: Projects Status 또는 Issue Label 변경하여 동기화 확인

---

## 🔗 관련 링크

- [Worker 코드 템플릿](templates/src/index.ts.template)
- [마법사 UI](projects-sync-wizard.html)
- [Bash 설치 스크립트](projects-sync-wizard-setup.sh)
- [PowerShell 설치 스크립트](projects-sync-wizard-setup.ps1)

---

**작성자**: Claude Code
**검토일**: 2026-01-22
