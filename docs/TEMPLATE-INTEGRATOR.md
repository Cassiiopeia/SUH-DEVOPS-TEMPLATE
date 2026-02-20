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
| **Custom Command** | Cursor IDE / Claude Code 설정만 설치 | `--mode commands` |

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
| `--target <target>` | commands 모드 설치 대상 (`cursor`, `claude`, `all`) | `--target all` |
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
| `-Target <target>` | commands 모드 설치 대상 (`cursor`, `claude`, `all`) | `-Target all` |
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

### Custom Command (`--mode commands`)

#### 대화형 메뉴 (1~4번 선택)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode commands

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode commands
```

#### Cursor만 설치
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode commands --target cursor --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode commands -Target cursor -Force
```

#### Claude만 설치
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode commands --target claude --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode commands -Target claude -Force
```

#### 모두 설치 (Cursor + Claude)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") --mode commands --target all --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Mode commands -Target all -Force
```

---

### CI/CD 환경 (stdin 모드)

TTY가 없는 환경에서는 `--mode`와 `--force`를 반드시 지정해야 합니다.

```bash
# macOS/Linux - curl | bash 방식
curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh" | bash -s -- --mode version --force

curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh" | bash -s -- --mode full --type spring --force

curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh" | bash -s -- --mode commands --target all --force
```

---

## Custom Command 모드 상세

Custom Command 모드는 **Cursor IDE**와 **Claude Code**의 설정 파일을 설치합니다.

### 설치되는 폴더

| 폴더 | 설명 |
|------|------|
| `.cursor/` | Cursor IDE 커스텀 명령어 설정 |
| `.claude/` | Claude Code 커스텀 명령어 설정 |

### `--target` 옵션

`--target` 옵션으로 대화형 메뉴 없이 설치 대상을 직접 지정할 수 있습니다.

| `--target` 값 | 설명 |
|---------------|------|
| `cursor` | Cursor IDE 설정만 설치 (`.cursor` 폴더) |
| `claude` | Claude Code 설정만 설치 (`.claude` 폴더) |
| `all` | Cursor + Claude 모두 설치 |

### `--target`과 `--force` 조합

| 조합 | 대화형 메뉴 | 덮어쓰기 확인(Y/N) |
|------|:-----------:|:------------------:|
| `--mode commands` | 표시 | 표시 |
| `--mode commands --target claude` | 스킵 | 표시 |
| `--mode commands --force` | 표시 | 스킵 |
| `--mode commands --target all --force` | 스킵 | 스킵 |

### 대화형 모드 서브메뉴

`--target`을 지정하지 않으면 다음 대화형 메뉴가 표시됩니다:

```
Custom Command 설치 대상 선택:
[1] Cursor IDE만 (.cursor 폴더)
[2] Claude Code만 (.claude 폴더)
[3] 둘 다 설치
[4] 취소
```

### 주의사항

- **기존 폴더 덮어쓰기**: 기존 `.cursor` 또는 `.claude` 폴더가 있으면 기존에 추가한 파일은 보존되고 템플릿 파일만 덮어쓰기됩니다
- **경고 표시**: `--force` 없이 실행하면 설치 전 확인 메시지가 표시됩니다

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
