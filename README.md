<div align="center">

# 🚀 SUH-DEVOPS-TEMPLATE

**GitHub Actions 자동화 + Claude Code AI Skills — 개발 사이클 전체를 자동화하는 DevOps 템플릿**

> 이슈 등록부터 커밋, 보고서, 배포까지. 개발자는 코드만 작성하세요.

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v3.0.25 (2026-04-24)

[전체 버전 기록 보기](CHANGELOG.md)

</div>

---

## 왜 이 템플릿인가?

이 프로젝트는 두 축으로 개발 워크플로우를 자동화합니다.

**① GitHub Actions** — main 푸시 한 번으로 버전 관리, 체인지로그, CI/CD 배포까지 자동 처리  
**② Claude Code Skills** — `/issue`, `/commit`, `/report` 등 AI가 이슈 작성부터 커밋 메시지, 구현 보고서까지 대신 생성

| 기존 방식 | SUH-DEVOPS-TEMPLATE |
|----------|---------------------|
| 버전 수동 관리, 태그 직접 생성 | main 푸시 시 patch 버전 자동 증가 + 태그 생성 |
| 체인지로그 직접 작성 (30분+) | CodeRabbit AI가 PR마다 자동 생성 |
| CI/CD 처음부터 설정 | 프로젝트 타입별 워크플로우 즉시 구성 |
| 이슈 매번 형식 맞춰 작성 (5분+) | `/cassiiopeia:issue` 한 번에 표준 템플릿 생성 |
| 커밋 메시지 이슈 URL 수동 복사 | `/cassiiopeia:commit` 이슈 컨텍스트 기반 자동 완성 |
| PR 설명/보고서 직접 작성 | `/cassiiopeia:report` git diff 분석 후 자동 생성 |
| 코드 리뷰·분석 매번 프롬프트 입력 | 25종 Skills로 일관된 결과, 매번 재입력 불필요 |

---

## AI 개발 사이클

Claude Code Skills가 개발 사이클 전체를 커버합니다.

```mermaid
flowchart LR
    A([작업 시작]) --> B["/cassiiopeia:issue\n이슈 등록 + GitHub 자동 생성"]
    B --> C["/cassiiopeia:init-worktree\nworktree + 민감파일 자동 복사"]
    C --> D{작업 유형}

    D -->|새 기능| E1["/cassiiopeia:plan\n전략 수립"]
    D -->|버그| E2["/cassiiopeia:troubleshoot\n원인 분석"]
    D -->|리팩토링| E3["/cassiiopeia:refactor-analyze\nSmell 탐지"]

    E1 & E2 & E3 --> F["/cassiiopeia:implement\n구현"]
    F --> G["/cassiiopeia:test\n테스트"]
    G --> H["/cassiiopeia:review\n셀프 리뷰"]
    H --> I["/cassiiopeia:commit\n이슈 연동 커밋 자동 완성"]
    I --> J["/cassiiopeia:report\n구현 보고서 + GitHub 댓글"]
    J --> K([PR 등록])
    K --> L["/cassiiopeia:changelog-deploy\nmain push → deploy PR + automerge"]
```

> Skills 전체 목록 및 상세 사용법: **[docs/SKILLS.md](docs/SKILLS.md)**

---

## GitHub Actions 자동화 파이프라인

```mermaid
flowchart LR
    A([main 푸시]) --> B[버전 자동 증가\npatch +1 + 태그]
    B --> C[deploy PR 자동 생성]
    C --> D[AI 체인지로그\nCodeRabbit 분석]
    D --> E[자동 머지]
    E --> F[CI/CD 배포\nFlutter / Spring / React 등]
    F --> G([완료])
```

---

## 빠른 시작

### 새 프로젝트

GitHub에서 **"Use this template"** 클릭 → 1분 내 자동 초기화 완료

### 기존 프로젝트에 통합

```bash
# macOS / Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh")
```

```powershell
# Windows PowerShell
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1")
```

### Claude Code Skills만 설치

```bash
claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE
claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user
```

> `/cassiiopeia:` 입력 시 25종 Skills 자동완성 — [설치 가이드](docs/SKILLS.md)

---

## 주요 기능

| 기능 | 설명 | 문서 |
|------|------|------|
| **Claude Code Skills** | 이슈·커밋·리뷰·리팩토링·보고서 등 25종 AI DevOps Skills | [상세](docs/SKILLS.md) |
| **버전 자동화** | main 푸시 시 patch 버전 자동 증가 + Git 태그 | [상세](docs/VERSION-CONTROL.md) |
| **AI 체인지로그** | CodeRabbit 리뷰 기반 CHANGELOG 자동 생성 | [상세](docs/CHANGELOG-AUTOMATION.md) |
| **PR Preview** | 댓글 한 줄로 임시 서버 배포, 닫으면 자동 삭제 | [상세](docs/PR-PREVIEW.md) |
| **이슈 자동화** | 브랜치명/커밋 메시지 자동 제안, QA 이슈 생성 | [상세](docs/ISSUE-AUTOMATION.md) |
| **Flutter CI/CD** | iOS TestFlight + Android Play Store 자동 배포 | [상세](docs/FLUTTER-CICD-OVERVIEW.md) |
| **Synology 배포** | Docker 기반 NAS 무중단 배포 | [상세](docs/SYNOLOGY-DEPLOYMENT-GUIDE.md) |

---

## Claude Code Skills (25종)

### 🔄 개발 사이클 자동화

| 스킬 | 용도 |
|------|------|
| `/cassiiopeia:issue` | 설명 한 줄 → GitHub 이슈 템플릿 자동 작성 + 등록 |
| `/cassiiopeia:init-worktree` | Git worktree 생성 + 민감 파일 자동 복사 |
| `/cassiiopeia:commit` | 이슈 컨텍스트 기반 커밋 메시지 자동 완성 (superpowers 준수) |
| `/cassiiopeia:report` | git diff 분석 → 구현 보고서 생성 + GitHub 댓글 자동 포스팅 |
| `/cassiiopeia:changelog-deploy` | main push → deploy PR 생성 + 릴리스 노트 작성 + automerge |
| `/cassiiopeia:github` | GitHub 이슈/PR/댓글 독립 조회 및 관리 |

### 📊 분석형 (코드 수정 없음)

| 스킬 | 용도 |
|------|------|
| `/cassiiopeia:analyze` | 구현 전 현재 코드 상태 분석 및 영향 범위 평가 |
| `/cassiiopeia:plan` | 요구사항 명확화 + 2가지 이상 접근 방식 비교로 전략 수립 |
| `/cassiiopeia:design-analyze` | 아키텍처/API/DB/UI 설계 분석 (구현 X) |
| `/cassiiopeia:refactor-analyze` | Code Smell 탐지 + Before/After 기반 리팩토링 계획 |
| `/cassiiopeia:review` | 보안/성능/버그/품질 6관점 리뷰, Critical/Major/Minor 분류 |
| `/cassiiopeia:troubleshoot` | 가설-검증 방식 근본 원인 분석, Quick Fix/Root Fix 제시 |

### 🔧 구현형 (실제 코드 작성)

| 스킬 | 용도 |
|------|------|
| `/cassiiopeia:implement` | 계획/분석 결과 기반 코드 구현 (기존 스타일 100% 준수) |
| `/cassiiopeia:design` | 아키텍처/API/DB/UI 설계 + 구현까지 |
| `/cassiiopeia:refactor` | Extract Method, DRY 등 리팩토링 기법 단계별 적용 |
| `/cassiiopeia:test` | AAA 패턴 단위/통합/E2E 테스트 코드 작성 |
| `/cassiiopeia:figma` | Figma CSS → React/RN/Flutter 반응형 코드 변환 |
| `/cassiiopeia:build` | 프로젝트 빌드 실행, 에러 분석, 최적화 제안 |

### 📝 문서/산출물 생성형

| 스킬 | 용도 |
|------|------|
| `/cassiiopeia:document` | 코드 주석/README/API 문서 작성 |
| `/cassiiopeia:testcase` | 이슈 분석 → QA 체크리스트 생성 |
| `/cassiiopeia:ppt` | 트러블슈팅/구현 사례 → 5섹션 발표자료 |
| `/cassiiopeia:suh-spring-test` | Spring Boot 테스트 샘플 코드 생성 |
| `/cassiiopeia:synology-expose` | Synology NAS 외부 도메인 노출 설정 가이드 |
| `/cassiiopeia:ssh` | 원격 서버 SSH 접속·명령 실행 (AWS EC2, 시놀로지 NAS, Linux 등 범용) |
| `/cassiiopeia:skill-creator` | Skill 생성/리뷰/개선 (CREATE·REVIEW·IMPROVE 3모드) |

---

## 지원 프로젝트 타입

| 타입 | 버전 파일 | CI/CD |
|------|----------|-------|
| `spring` | build.gradle | Synology Docker, Nexus |
| `flutter` | pubspec.yaml | TestFlight, Play Store |
| `react` | package.json | Docker |
| `next` | package.json | Docker |
| `node` | package.json | Docker |
| `python` | pyproject.toml | Synology Docker |
| `react-native` | Info.plist + build.gradle | — |
| `react-native-expo` | app.json | — |
| `basic` | version.yml만 | — |

---

## 댓글 명령어

Issue나 PR에 댓글로 자동화를 실행합니다.

| 명령어 | 기능 | 대상 |
|--------|------|------|
| `@suh-lab server build` | 임시 서버 배포 | Spring, Python |
| `@suh-lab server destroy` | 서버 삭제 | Spring, Python |
| `@suh-lab server status` | 서버 상태 확인 | Spring, Python |
| `@suh-lab build app` | iOS + Android 빌드 | Flutter |
| `@suh-lab apk build` | Android만 빌드 | Flutter |
| `@suh-lab ios build` | iOS만 빌드 | Flutter |
| `@suh-lab create qa` | QA 이슈 자동 생성 | 모든 프로젝트 |

> 상세: [PR Preview](docs/PR-PREVIEW.md) | [Flutter 빌드](docs/FLUTTER-TEST-BUILD-TRIGGER.md) | [이슈 자동화](docs/ISSUE-AUTOMATION.md)

---

## 설정

### 필수 Secret

```
Repository Settings → Secrets → Actions → New repository secret
Name: _GITHUB_PAT_TOKEN
Value: [Personal Access Token - repo, workflow 권한]
```

### Organization 설정

```
Settings → Actions → General
├─ ✅ Allow GitHub Actions to create and approve pull requests
└─ ✅ Read and write permissions
```

---

## 문서

| 문서 | 설명 |
|------|------|
| [Claude Code Skills 가이드](docs/SKILLS.md) | 25종 Skills 용도, 사용법, 전체 개발 사이클 흐름 |
| [통합 스크립트 가이드](docs/TEMPLATE-INTEGRATOR.md) | 기존 프로젝트에 템플릿 통합 |
| [버전 관리](docs/VERSION-CONTROL.md) | version.yml, 자동 버전 증가 |
| [체인지로그 자동화](docs/CHANGELOG-AUTOMATION.md) | CodeRabbit 연동, AI 문서화 |
| [PR Preview](docs/PR-PREVIEW.md) | 임시 서버 배포 시스템 |
| [Flutter CI/CD](docs/FLUTTER-CICD-OVERVIEW.md) | iOS/Android 자동 배포 |
| [Synology 배포](docs/SYNOLOGY-DEPLOYMENT-GUIDE.md) | Docker 기반 NAS 배포 |
| [이슈 자동화](docs/ISSUE-AUTOMATION.md) | Issue Helper, QA 봇 |
| [트러블슈팅](docs/TROUBLESHOOTING.md) | 자주 발생하는 문제 해결 |

---

## 지원

- [Issues](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues) — 버그 리포트, 기능 요청
- [CONTRIBUTING.md](CONTRIBUTING.md) — 기여 가이드

---

<div align="center">

**MIT License**

</div>
