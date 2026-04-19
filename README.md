<div align="center">

# 🚀 SUH-DEVOPS-TEMPLATE

**완전 자동화된 GitHub 프로젝트 관리 템플릿 + Claude Code Skill 플러그인**

> 개발자는 코드만 작성하세요. 버전 관리, 체인지로그, 배포는 자동으로 처리됩니다.
> GitHub Actions 자동화와 Claude Code용 DevOps Skill 20종을 한 레포에서 제공합니다.

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v2.9.14 (2026-04-19)

[전체 버전 기록 보기](CHANGELOG.md) 

</div>

---

<div align="center">


  ## https://lab.suhsaechan.kr/suh-devops-template

</div>

## 왜 이 템플릿인가?

| 기존 방식 | SUH-DEVOPS-TEMPLATE |
|----------|---------------------|
| 버전 수동 관리, 태그 직접 생성 | main 푸시 시 자동 증가 + 태그 생성 |
| 체인지로그 직접 작성 | CodeRabbit AI가 자동 생성 |
| CI/CD 처음부터 설정 | 프로젝트 타입별 워크플로우 자동 구성 |
| 이슈 템플릿 수동 설정 | 4종 템플릿 자동 설치 |
| PR Preview 환경 수동 구축 | 댓글 한 줄로 임시 서버 배포 |
| Claude Code 매번 같은 프롬프트 반복 | `/cassiiopeia:xxx` 20종 Skill로 일관된 작업 수행 |
| 코드 리뷰·이슈 작성·보고서 수동 작성 | Skill 한 번에 표준 포맷으로 생성 |

---

## 빠른 시작

### 새 프로젝트

GitHub에서 **"Use this template"** 클릭 → 1분 내 자동 초기화 완료

### 기존 프로젝트

##### macOS / Linux
```bash
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh")
```
##### Windows PowerShell
```bash
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1")
```

> 대화형 모드로 프로젝트 타입과 버전을 자동 감지합니다.

### Claude Code Skill만 설치

```bash
claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE
claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user
```

> `/cassiiopeia:` 입력 시 20종 Skill 자동완성. 자세한 내용은 [docs/SKILLS.md](docs/SKILLS.md)

---

## 주요 기능

| 기능 | 설명 | 문서 |
|------|------|------|
| **Claude Code Skills** | `/cassiiopeia:xxx` 20종 DevOps/개발 Skill 플러그인 (리뷰·이슈·리팩토링·테스트·보고서 등) | [상세](docs/SKILLS.md) |
| **버전 자동화** | main 푸시 시 patch 버전 자동 증가 + Git 태그 | [상세](docs/VERSION-CONTROL.md) |
| **AI 체인지로그** | CodeRabbit 리뷰 기반 CHANGELOG 자동 생성 | [상세](docs/CHANGELOG-AUTOMATION.md) |
| **PR Preview** | Issue/PR 댓글로 임시 서버 배포, 닫으면 자동 삭제 | [상세](docs/PR-PREVIEW.md) |
| **이슈 자동화** | 브랜치명/커밋 메시지 자동 제안, QA 이슈 생성 | [상세](docs/ISSUE-AUTOMATION.md) |
| **Flutter CI/CD** | iOS TestFlight + Android Play Store 자동 배포 | [상세](docs/FLUTTER-CICD-OVERVIEW.md) |
| **Synology 배포** | Docker 기반 NAS 무중단 배포 | [상세](docs/SYNOLOGY-DEPLOYMENT-GUIDE.md) |

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
| `react-native` | Info.plist + build.gradle | - |
| `react-native-expo` | app.json | - |
| `basic` | version.yml만 | - |

---

## 자동화 흐름

**GitHub Actions 파이프라인**

```mermaid
flowchart LR
    A([main 푸시]) --> B[버전 자동 증가]
    B --> C[deploy PR 생성]
    C --> D[AI 체인지로그]
    D --> E[자동 머지]
    E --> F[CI/CD 배포]
    F --> G([완료])
```

**Claude Code Skill 개발 흐름**

```mermaid
flowchart LR
    A([작업 시작]) --> B[/issue<br/>이슈 등록/]
    B --> C[/init-worktree<br/>worktree 생성/]
    C --> D[/plan<br/>계획 수립/]
    D --> E[/implement<br/>구현/]
    E --> F[/test<br/>테스트/]
    F --> G[/review<br/>리뷰/]
    G --> H[/report<br/>보고서/]
    H --> I([PR 등록])
```

> Skill별 상세 흐름(버그/리팩토링/설계 등): [docs/SKILLS.md](docs/SKILLS.md#어떤-skill을-언제-쓸까)

---

## Claude Code Skill 플러그인

이 레포는 **Claude Code용 Skill 플러그인 마켓플레이스**이기도 합니다. 20개 DevOps/개발 자동화 Skill을 `/cassiiopeia:xxx` 형식으로 바로 호출할 수 있습니다.

```bash
# 설치 (2줄)
claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE
claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user
```

### 분석형 (코드 수정 없이 분석/계획만)

| 스킬 | 용도 |
|------|------|
| `/cassiiopeia:analyze` | 구현 전 현재 코드 상태 분석 및 영향 범위 평가 |
| `/cassiiopeia:plan` | 요구사항 명확화 및 2가지 이상 접근 방식 비교로 전략 수립 |
| `/cassiiopeia:design-analyze` | 아키텍처/API/DB/UI 설계 방향 분석 (구현 X) |
| `/cassiiopeia:refactor-analyze` | Code Smell 탐지 및 Before/After 예시 기반 리팩토링 계획 |
| `/cassiiopeia:review` | 보안/성능/버그/품질 6관점 리뷰, Critical/Major/Minor 분류 |
| `/cassiiopeia:troubleshoot` | 가설-검증 방식 근본 원인 분석, Quick Fix/Root Fix 제시 |

### 구현형 (실제 코드 작성/수정)

| 스킬 | 용도 |
|------|------|
| `/cassiiopeia:implement` | 계획/분석 결과 기반 코드 구현 (프로젝트 스타일 100% 준수) |
| `/cassiiopeia:design` | 아키텍처/API/DB/UI 설계 + 실제 구현까지 |
| `/cassiiopeia:refactor` | Extract Method, DRY 등 리팩토링 기법 단계별 적용 |
| `/cassiiopeia:test` | AAA 패턴 단위/통합/E2E 테스트 코드 작성 |
| `/cassiiopeia:figma` | Figma CSS를 React/RN/Flutter 반응형 코드로 변환 |
| `/cassiiopeia:build` | 프로젝트 빌드 실행, 에러 처리, 최적화 제안 |
| `/cassiiopeia:init-worktree` | Git worktree 생성 + .gitignore 기반 민감 파일 자동 복사 |

### 문서/산출물 생성형

| 스킬 | 용도 |
|------|------|
| `/cassiiopeia:document` | 코드 주석/README/API 문서 작성 (기존 스타일 유지) |
| `/cassiiopeia:issue` | 사용자 설명 → GitHub 이슈 템플릿 형식 md 파일 생성 |
| `/cassiiopeia:report` | git diff + 이슈 기반 구현 보고서를 .report/에 저장 |
| `/cassiiopeia:testcase` | 이슈 분석 → 프로젝트 타입별 QA 체크리스트 md 생성 |
| `/cassiiopeia:ppt` | 트러블슈팅/구현 사례를 5섹션 발표자료 마크다운으로 정리 |
| `/cassiiopeia:suh-spring-test` | Spring Boot 테스트 샘플 코드 생성 (suh-logger 감지) |
| `/cassiiopeia:synology-expose` | 시놀로지 NAS 외부 도메인 노출 설정 가이드 |

> 각 Skill의 상세 사용법 및 예시: **[docs/SKILLS.md](docs/SKILLS.md)**

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

자동 체인지로그, PR 머지 등을 사용하려면:

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
| [Claude Code Skills 가이드](docs/SKILLS.md) | 20개 Skill 각각의 용도, 사용법, 활용 시나리오 |
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

- [Issues](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues) - 버그 리포트, 기능 요청
- [CONTRIBUTING.md](CONTRIBUTING.md) - 기여 가이드

---

<div align="center">

**MIT License**

</div>
