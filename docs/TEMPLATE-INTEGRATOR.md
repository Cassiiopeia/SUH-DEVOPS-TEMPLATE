# Template Integrator 상세 가이드

> 기존 프로젝트에 SUH-DEVOPS-TEMPLATE을 통합하는 스크립트 사용법

---

## 목차

- [개요](#개요)
- [설치 방법](#설치-방법)
- [통합 모드](#통합-모드)
- [CLI 옵션](#cli-옵션)
- [사용 예시](#사용-예시)

---

## 개요

`template_integrator`는 기존 프로젝트에 SUH-DEVOPS-TEMPLATE의 기능을 선택적으로 통합할 수 있는 스크립트입니다.

**지원 환경:**
- **macOS/Linux**: `template_integrator.sh` (Bash)
- **Windows**: `template_integrator.ps1` (PowerShell)

---

## 설치 방법

### macOS / Linux
```bash
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh")
```

### Windows (PowerShell)
```powershell
iex (iwr -Uri "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1" -UseBasicParsing).Content
```

---

## 통합 모드

| 모드 | 설명 | CLI 옵션 |
|------|------|----------|
| **전체 통합** | 버전관리 + 워크플로우 + 이슈템플릿 모두 설치 | `--mode full` |
| **버전 관리** | version.yml 및 버전 관리 시스템만 설치 | `--mode version` |
| **워크플로우** | GitHub Actions 워크플로우만 설치 | `--mode workflows` |
| **이슈 템플릿** | 이슈/PR 템플릿만 설치 | `--mode issues` |
| **Custom Command** | Cursor IDE / Claude Code 설정만 설치 | `--mode commands` |

---

## CLI 옵션

### 공통 옵션

| 옵션 | 설명 | 예시 |
|------|------|------|
| `--mode <mode>` | 통합 모드 선택 | `--mode full` |
| `--type <type>` | 프로젝트 타입 지정 | `--type spring` |
| `--version <ver>` | 초기 버전 지정 | `--version 1.0.0` |
| `--force` | 확인 없이 실행 | `--force` |
| `--help` | 도움말 표시 | `--help` |

### 프로젝트 타입

| 타입 | 설명 |
|------|------|
| `spring` | Spring Boot (Gradle/Maven) |
| `flutter` | Flutter 멀티 플랫폼 |
| `react` | React.js / Next.js |
| `react-native` | React Native CLI |
| `react-native-expo` | Expo 기반 RN |
| `node` | Node.js / Express |
| `python` | FastAPI / Django / Flask |
| `basic` | 범용 (버전 관리만) |

---

## 사용 예시

### 대화형 모드 (권장)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh")

# Windows
iex (iwr -Uri "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1" -UseBasicParsing).Content
```

### 전체 통합 (자동 감지)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode full --force

# Windows
iex "& { $(iwr -Uri 'https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1' -UseBasicParsing).Content } -Mode full -Force"
```

### 특정 타입/버전 지정
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") \
  --mode full --type spring --version 1.0.0 --force

# Windows
iex "& { $(iwr -Uri 'https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1' -UseBasicParsing).Content } -Mode full -Type spring -Version '1.0.0' -Force"
```

### 워크플로우만 설치
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode workflows --force

# Windows
iex "& { $(iwr -Uri 'https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1' -UseBasicParsing).Content } -Mode workflows -Force"
```

### Custom Command만 설치
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode commands --force

# Windows
iex "& { $(iwr -Uri 'https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1' -UseBasicParsing).Content } -Mode commands -Force"
```

---

## Custom Command 모드 상세

Custom Command 모드는 **Cursor IDE**와 **Claude Code**의 설정 파일을 설치합니다.

### 설치되는 폴더

| 폴더 | 설명 |
|------|------|
| `.cursor/` | Cursor IDE 커스텀 명령어 설정 |
| `.claude/` | Claude Code 커스텀 명령어 설정 |

### 대화형 모드 서브메뉴

대화형 모드에서 Custom Command를 선택하면 다음 옵션이 표시됩니다:

```
Custom Command 설치 대상 선택:
[1] Cursor IDE만 (.cursor 폴더)
[2] Claude Code만 (.claude 폴더)
[3] 둘 다 설치
[4] 취소
```

### 주의사항

- **기존 폴더 덮어쓰기**: 기존 `.cursor` 또는 `.claude` 폴더가 있으면 삭제 후 새로 설치됩니다
- **백업 없음**: 기존 설정은 백업되지 않으므로 필요시 미리 백업하세요
- **경고 표시**: 설치 전 경고 메시지가 표시됩니다

---

## 문제 해결

### 스크립트 실행 권한 오류 (macOS/Linux)
```bash
chmod +x template_integrator.sh
```

### PowerShell 실행 정책 오류 (Windows)
```powershell
powershell -ExecutionPolicy Bypass -Command "..."
```

### 다운로드 실패
- 인터넷 연결 확인
- GitHub 접근 가능 여부 확인
- 방화벽/프록시 설정 확인

---

## 관련 문서

- [README.md](../README.md) - 프로젝트 메인 문서
- [SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md](../SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md) - 초기 설정 가이드
- [CONTRIBUTING.md](../CONTRIBUTING.md) - 기여 가이드
