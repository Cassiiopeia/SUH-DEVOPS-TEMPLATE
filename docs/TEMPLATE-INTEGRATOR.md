# Template Integrator 상세 가이드

> 기존 프로젝트에 SUH-DEVOPS-TEMPLATE을 통합하는 스크립트 사용법

---

## 목차

- [개요](#개요)
- [설치 방법](#설치-방법)
- [통합 모드](#통합-모드)
- [CLI 옵션](#cli-옵션)
- [멀티 프로젝트 타입](#멀티-프로젝트-타입)
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
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1")
```

---

## 통합 모드

| 모드 | 설명 | CLI 옵션 |
|------|------|----------|
| **전체 통합** | 버전관리 + 워크플로우 + 이슈템플릿 모두 설치 | `--mode full` |
| **버전 관리** | version.yml 및 버전 관리 시스템만 설치 | `--mode version` |
| **워크플로우** | GitHub Actions 워크플로우만 설치 | `--mode workflows` |
| **이슈 템플릿** | 이슈/PR 템플릿만 설치 | `--mode issues` |

---

## CLI 옵션

### Bash (macOS/Linux) 옵션

| 옵션 | 설명 | 예시 |
|------|------|------|
| `-m`, `--mode <mode>` | 통합 모드 선택 | `--mode full` |
| `-t`, `--type <type>` | 프로젝트 타입 지정 | `--type spring` |
| `-v`, `--version <ver>` | 초기 버전 지정 | `--version 1.0.0` |
| `--force` | 확인 없이 실행 | `--force` |
| `--no-backup` | 백업 생성 안 함 | `--no-backup` |
| `--synology` | Synology 워크플로우 포함 | `--synology` |
| `--no-synology` | Synology 워크플로우 제외 (기본값) | `--no-synology` |
| `-h`, `--help` | 도움말 표시 | `--help` |

### PowerShell (Windows) 옵션

| 옵션 | 설명 | 예시 |
|------|------|------|
| `-Mode <mode>` | 통합 모드 선택 | `-Mode full` |
| `-Type <type>` | 프로젝트 타입 지정 | `-Type spring` |
| `-Version <ver>` | 초기 버전 지정 | `-Version "1.0.0"` |
| `-Force` | 확인 없이 실행 | `-Force` |
| `-NoBackup` | 백업 생성 안 함 | `-NoBackup` |
| `-Synology` | Synology 워크플로우 포함 | `-Synology` |
| `-NoSynology` | Synology 워크플로우 제외 (기본값) | `-NoSynology` |
| `-Help` | 도움말 표시 | `-Help` |

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

> `--type`에 csv로 여러 타입을 동시에 지정할 수 있습니다. 자세한 내용은 [멀티 프로젝트 타입](#멀티-프로젝트-타입)을 참고하세요.

---

## 멀티 프로젝트 타입

하나의 레포에 여러 타입이 공존하는 경우(예: Spring 백엔드 + React 프론트 + Python AI 모듈) `--type`에 csv로 지정합니다.

```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") \
  --mode full --type spring,react,python --version 1.0.0 --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode full -Type 'spring,react,python' -Version '1.0.0' -Force
```

### 동작 방식

- **자동 감지 시 다중 선택**: `--type`을 생략하면 일치하는 모든 타입을 감지해 다중 선택 메뉴로 표시합니다. `Space`로 토글, `Enter`로 csv 확정합니다.
- **version.yml 저장 형식**: 선택한 타입은 `version.yml`의 `project_types` 배열에 저장됩니다.
  ```yaml
  project_types: ["spring", "react", "python"]
  project_type: "spring"   # project_types[0] 자동 미러 (직접 수정 금지)
  ```
- **하위 호환**: 단일 타입도 `project_types: ["react"]` 형태로 통일되며, 단수 `project_type` 키만 있는 기존 version.yml도 100% 그대로 동작합니다.

### CI 트리거 주의

멀티타입 레포에서는 여러 타입의 `*-CI.yaml`이 같은 main push에 **동시에 발화**합니다. 디렉토리별로 분리하려면 각 워크플로우의 `paths:` 필터를 수동으로 추가하세요.

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'backend/**'    # Spring CI 만 이 경로 변경 시 발화
```

배포 워크플로우(SYNOLOGY-CICD 등)도 타입별로 `PROJECT_NAME` / `CONTAINER_NAME` / `DEPLOY_PORT`를 서로 다른 값으로 설정해야 합니다. 자세한 내용은 [SYNOLOGY-DEPLOYMENT-GUIDE.md](SYNOLOGY-DEPLOYMENT-GUIDE.md)를 참고하세요.

---

## 사용 예시

> 아래 원격 URL은 가독성을 위해 줄여서 표기합니다.
> - **Bash**: `https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh`
> - **PS1**: `https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1`

### 대화형 모드 (권장)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh")

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1")
```

---

### 전체 통합 (`--mode full`)

#### 전체 통합 (자동 감지)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode full --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode full -Force
```

#### 전체 통합 + 타입/버전 지정
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") \
  --mode full --type spring --version 1.0.0 --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode full -Type spring -Version '1.0.0' -Force
```

#### 전체 통합 + Synology 포함
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode full --synology --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode full -Synology -Force
```

#### 전체 통합 + Synology 제외 (명시적)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode full --no-synology --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode full -NoSynology -Force
```

#### 전체 통합 + 백업 없이
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode full --no-backup --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode full -NoBackup -Force
```

#### 전체 통합 + 모든 옵션 조합
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") \
  --mode full --type flutter --version 1.0.0 --synology --no-backup --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode full -Type flutter -Version '1.0.0' -Synology -NoBackup -Force
```

---

### 버전 관리만 (`--mode version`)

```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode version --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode version -Force
```

---

### 워크플로우만 (`--mode workflows`)

#### 워크플로우만 설치
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode workflows --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode workflows -Force
```

#### 워크플로우 + Synology 포함
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode workflows --synology --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode workflows -Synology -Force
```

---

### 이슈 템플릿만 (`--mode issues`)

```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode issues --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode issues -Force
```

---

### CI/CD 환경 (stdin 모드)

TTY가 없는 환경에서는 `--mode`와 `--force`를 반드시 지정해야 합니다.

```bash
# macOS/Linux - curl | bash 방식
curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh" | bash -s -- --mode version --force

curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh" | bash -s -- --mode full --type spring --force
```

---

## IDE 도구 (Skills) 설치

> **v2.9.0부터** Skills는 template_integrator의 통합 모드에서 분리되었습니다.
> 통합 완료 후 IDE 도구 설치 여부를 별도로 안내합니다.

### 배포 방식

| IDE | 배포 방식 | 설명 |
|-----|----------|------|
| **Claude Code** | 플러그인 마켓플레이스 | `claude plugin` 명령어로 설치, 자동 업데이트 |
| **Cursor** | 폴더 복사 | 통합 시 `skills/` → `.cursor/skills/`로 복사 |

### Claude Code 플러그인 설치

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE

# 2. 플러그인 설치 (글로벌)
claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user
```

설치 후 `/cassiiopeia:suh-analyze`, `/cassiiopeia:suh-review` 등으로 사용합니다.

### Cursor IDE Skills 설치

template_integrator 실행 후 IDE 도구 설치 단계에서 Cursor를 선택하면 자동으로 `skills/` → `.cursor/skills/`로 복사됩니다.

### 통합 후 IDE 도구 설치 흐름

template_integrator는 통합 완료 후 다음 순서로 안내합니다:

1. Claude Code 설치 여부 확인 → CLI 명령어 자동 실행 (실패 시 수동 명령어 안내)
2. Cursor 설치 여부 확인 → `skills/` 폴더를 `.cursor/skills/`로 복사

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
