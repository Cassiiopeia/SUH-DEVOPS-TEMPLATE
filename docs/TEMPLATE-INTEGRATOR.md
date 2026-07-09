# Template Integrator 상세 가이드

> 기존 프로젝트에 SUH-DEVOPS-TEMPLATE을 통합하는 스크립트 사용법

---

## 목차

- [개요](#개요)
- [설치 방법](#설치-방법)
- [대화형 마법사 조작법 (화살표 메뉴)](#대화형-마법사-조작법-화살표-메뉴)
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
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh")
```

### Windows (PowerShell)
```powershell
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1")
```

---

## 대화형 마법사 조작법 (화살표 메뉴)

`template_integrator`는 옵션을 주지 않고 실행하면 **대화형 마법사**가 뜹니다. 이때 모든 선택은 **방향키 화살표(↑/↓)로 이동하고 Enter로 확정**하는 방식입니다. macOS/Linux(`.sh`)와 Windows(`.ps1`)가 **조작법·문구·동작이 완전히 동일**합니다.

> **숫자를 일일이 콤마로 입력할 필요가 없습니다.** 화살표로 움직이고 Enter만 누르면 됩니다. 화살표가 동작하지 않는 일부 환경(아래 "번호 입력 폴백" 참고)에서만 자동으로 번호 입력 방식으로 전환됩니다.

### 단일 선택 메뉴

모드 선택, "이 정보가 맞습니까?" 같은 **하나만 고르는** 메뉴입니다.

```
무엇을 설치할까요? (↑↓ 이동, 숫자 점프, Enter 확정, ESC 취소):

  [•]  1) 전체 설치 — 버전관리 + 자동화 워크플로우 + 이슈·PR 템플릿 (처음이라면 추천)
  [ ]  2) 버전 관리만 — 버전 자동 증가·동기화 시스템만 설치
  [ ]  3) 워크플로우만 — 빌드·배포 GitHub Actions만 설치
  [ ]  4) 이슈·PR 템플릿만 — GitHub 이슈/PR 양식만 설치
  [ ]  5) AI 스킬만 — Claude·Cursor·Gemini·Codex용 스킬만 설치
  [ ]  6) 취소
```

| 키 | 동작 |
|----|------|
| `↑` / `↓` | 항목 간 이동 (커서 `[•]`가 따라 움직임, 끝에서 반대편으로 순환) |
| `숫자 1~9` | 해당 번호 항목으로 커서 즉시 점프 |
| `Enter` | 현재 커서 항목 확정 |
| `ESC` | 취소 (메뉴에 따라 동작이 다름 — 아래 "ESC 동작" 참고) |

### 멀티 셀렉트 메뉴 (여러 개 선택)

프로젝트 타입 선택, 설치할 IDE 선택처럼 **여러 개를 동시에 고르는** 메뉴입니다.

```
프로젝트 타입을 선택하세요 (↑↓ 이동, Space 토글, a 전체토글, Enter 확정, ESC 뒤로):

  [✓]  1) Spring Boot 백엔드
  [ ]  2) Flutter 모바일 앱
  [ ]  3) Next.js 웹 앱
> [✓]  4) React 웹 앱
  [ ]  5) Node.js 프로젝트
  ...
```

| 키 | 동작 |
|----|------|
| `↑` / `↓` | 커서 이동 (`>`로 현재 위치 표시) |
| `Space` | 현재 항목 선택 토글 (`[ ]` ↔ `[✓]`) |
| `a` | 전체 토글 (모두 선택돼 있으면 전체 해제, 아니면 전체 선택) |
| `Enter` | 체크된(`[✓]`) 항목들을 모두 확정 |
| `ESC` | 취소/뒤로 |

- **미리 체크된 항목(preselect)**: 레포를 스캔해 자동 감지된 타입은 처음부터 `[✓]`로 체크되어 있습니다. 그대로 Enter만 누르면 감지된 타입이 그대로 적용됩니다.
- 아무것도 선택하지 않고 Enter를 누르면 취소로 처리됩니다.

### ESC 동작 — 화면마다 의미가 다릅니다

ESC는 "무조건 종료"가 아니라 **현재 화면의 맥락에 맞게** 동작합니다. 안내 문구의 `ESC <라벨>` 부분이 그 화면에서 ESC가 무엇을 하는지 알려줍니다.

| 화면 | ESC 안내 | ESC를 누르면 |
|------|---------|-------------|
| 프로젝트 타입 선택 | `ESC 뒤로` | 기존 값을 유지하고 이전 단계로 |
| 확인 화면 ("이 정보가 맞습니까?") | `ESC 머무르기` | **종료하지 않고** 그 화면에 머무름 (실수로 빠져나가지 않도록). 실제 취소는 '아니오, 취소'를 직접 골라야 함 |
| 수정 메뉴 ("어떤 항목을 수정?") | `ESC 뒤로` | 변경 없이 상위 확인 화면으로 복귀 |
| AI 스킬 설치 메뉴 | `ESC 건너뛰기` | 변경 없이 건너뜀 |
| 모드 선택 (최상위) | `ESC 취소` | 명시적 '취소' 항목 선택과 동일하게 종료 |

> **뒤로 가기는 두 가지 방법**: ESC 키를 누르거나, 메뉴에 있는 `뒤로 (변경 없이 확인 화면으로)` 항목을 화살표로 골라도 됩니다. ESC를 모르는 사용자도 메뉴 항목으로 따라갈 수 있습니다.

### 번호 입력 폴백 (화살표가 안 되는 환경)

다음 환경에서는 화살표 키 입력이 불가능하므로 **자동으로 번호 입력 방식**으로 전환됩니다. 동작·결과는 동일하며 입력 방법만 다릅니다.

- Windows PowerShell ISE
- 일부 비대화형 실행 환경 / CI 파이프라인 (`--force` 모드 등)

번호 입력 시:
- **단일 선택**: 원하는 번호 하나를 입력하고 Enter (예: `1`)
- **멀티 셀렉트**: 여러 번호를 콤마로 구분해 입력 (예: `1,3,5`), `a`는 전체, 그냥 Enter는 현재값 유지

### OS별 동작 비교

| 항목 | macOS/Linux (`.sh`) | Windows (`.ps1`) |
|------|---------------------|------------------|
| 화살표 이동 (↑/↓) | ✅ | ✅ |
| 숫자 점프 | ✅ | ✅ |
| 멀티 셀렉트 (Space/a) | ✅ | ✅ |
| preselect 자동 체크 | ✅ | ✅ |
| ESC 동작 (뒤로/머무르기/취소) | ✅ 동일 | ✅ 동일 |
| 안내 문구·선택지 라벨 | 동일 | 동일 |
| 키 입력 우회 (파이프 실행 시) | `/dev/tty` | `RawUI.ReadKey` |

### 실행 방식별 화살표 동작

| 실행 방식 | 화살표 메뉴 |
|-----------|------------|
| 파일로 받아 실행 (`./template_integrator.sh`, `.\template_integrator.ps1`) | ✅ 화살표 |
| 원격 실행 (`curl \| bash`, `iex $wc.DownloadString(...)`) | ✅ 화살표 |
| PowerShell ISE / 비대화형 CI | 번호 입력 폴백 |

> macOS/Linux는 `curl | bash` 파이프 실행에서도 `/dev/tty`로, Windows는 원격 `iex` 실행에서도 `RawUI.ReadKey`로 키 입력을 받아 화살표 메뉴가 정상 동작합니다.

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
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") \
  --mode full --type spring,react,python --version 1.0.0 --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode full -Type 'spring,react,python' -Version '1.0.0' -Force
```

### 동작 방식

- **자동 감지 시 다중 선택**: `--type`을 생략하면 일치하는 모든 타입을 감지해 다중 선택 메뉴로 표시합니다. `Space`로 토글, `Enter`로 csv 확정합니다.
- **version.yml 저장 형식**: 선택한 타입은 `version.yml`의 `project_types` 배열에 저장됩니다.
  ```yaml
  project_types: ["spring", "react", "python"]   # 첫 항목이 primary
  ```
- **단수 키 제거(v4.1.0)**: 단일 타입도 `project_types: ["react"]` 형태로 통일됩니다. 단수 `project_type` 키는 더 이상 쓰지도 읽지도 않으며, 단수 키만 있는 기존 version.yml은 통합(업데이트) 실행 시 마커 재감지를 거쳐 배열 형식으로 재작성됩니다.

### CI 트리거 주의

멀티타입 레포에서는 여러 타입의 `*-CI.yaml`이 같은 main push에 **동시에 발화**합니다. 디렉토리별로 분리하려면 각 워크플로우의 `paths:` 필터를 수동으로 추가하세요.

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'backend/**'    # Spring CI 만 이 경로 변경 시 발화
```

배포 워크플로우(SIMPLE-CICD 등)도 타입별로 `PROJECT_NAME` / `CONTAINER_NAME` / `DEPLOY_PORT`를 서로 다른 값으로 설정해야 합니다. 자세한 내용은 [SSH-DOCKER-DEPLOYMENT-GUIDE.md](SSH-DOCKER-DEPLOYMENT-GUIDE.md)를 참고하세요.

---

## 사용 예시

> 아래 원격 URL은 가독성을 위해 줄여서 표기합니다.
> - **Bash**: `https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh`
> - **PS1**: `https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1`

### 대화형 모드 (권장)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh")

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1")
```

---

### 전체 통합 (`--mode full`)

#### 전체 통합 (자동 감지)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") --mode full --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode full -Force
```

#### 전체 통합 + 타입/버전 지정
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") \
  --mode full --type spring --version 1.0.0 --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode full -Type spring -Version '1.0.0' -Force
```

#### 전체 통합 + Synology 포함
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") --mode full --synology --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode full -Synology -Force
```

#### 전체 통합 + Synology 제외 (명시적)
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") --mode full --no-synology --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode full -NoSynology -Force
```

#### 전체 통합 + 백업 없이
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") --mode full --no-backup --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode full -NoBackup -Force
```

#### 전체 통합 + 모든 옵션 조합
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") \
  --mode full --type flutter --version 1.0.0 --synology --no-backup --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode full -Type flutter -Version '1.0.0' -Synology -NoBackup -Force
```

---

### 버전 관리만 (`--mode version`)

```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") --mode version --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode version -Force
```

---

### 워크플로우만 (`--mode workflows`)

#### 워크플로우만 설치
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") --mode workflows --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode workflows -Force
```

#### 워크플로우 + Synology 포함
```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") --mode workflows --synology --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode workflows -Synology -Force
```

---

### 이슈 템플릿만 (`--mode issues`)

```bash
# macOS/Linux
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh") --mode issues --force

# Windows
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1"))) -Mode issues -Force
```

---

### CI/CD 환경 (stdin 모드)

TTY가 없는 환경에서는 `--mode`와 `--force`를 반드시 지정해야 합니다.

```bash
# macOS/Linux - curl | bash 방식
curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh" | bash -s -- --mode version --force

curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh" | bash -s -- --mode full --type spring --force
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
claude plugin marketplace add Cassiiopeia/projectops

# 2. 플러그인 설치 (글로벌)
claude plugin install projectops@projectops-marketplace --scope user
```

설치 후 `/projectops:analyze`, `/projectops:review` 등으로 사용합니다.

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
