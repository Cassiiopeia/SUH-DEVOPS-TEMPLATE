<div align="center">

# 🚀 SUH-DEVOPS-TEMPLATE

**완전 자동화된 GitHub 프로젝트 관리 템플릿**

> 개발자는 코드만 작성하세요. 버전 관리, 체인지로그, 배포는 자동으로 처리됩니다.

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v2.7.20 (2026-02-04)

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
iex (iwr -Uri "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1" -UseBasicParsing).Content
```

> 대화형 모드로 프로젝트 타입과 버전을 자동 감지합니다.

---

## 주요 기능

| 기능 | 설명 | 문서 |
|------|------|------|
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

```
main 푸시 → 버전 증가 → deploy PR 생성 → AI 체인지로그 → 자동 머지 → CI/CD 배포
```

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
