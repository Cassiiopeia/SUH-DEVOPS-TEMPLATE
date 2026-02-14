# ===================================================================
# GitHub 템플릿 통합 스크립트 v1.0.0 (Windows PowerShell)
# ===================================================================
#
# 이 스크립트는 기존 프로젝트에 SUH-DEVOPS-TEMPLATE의 기능을
# 선택적으로 통합합니다. (Windows 환경 전용)
#
# 주요 기능:
# 1. 기존 README.md 보존 및 버전 정보 섹션 자동 추가
# 2. package.json, pubspec.yaml 등에서 버전과 타입 자동 감지
# 3. GitHub Actions 워크플로우 선택적 복사
# 4. 충돌 파일 자동 처리 및 백업
# 5. version.yml 생성 (기존 프로젝트 정보 유지)
#
# 사용법:
# 
# 방법 1: 로컬 다운로드 후 실행
# Invoke-WebRequest -Uri "https://raw.githubusercontent.com/.../template_integrator.ps1" -OutFile "template_integrator.ps1"
# powershell -ExecutionPolicy Bypass -File .\template_integrator.ps1
#
# 방법 2: 원격 실행 - 대화형 (추천)
# $wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/.../template_integrator.ps1")
#
# 방법 3: 원격 실행 - CLI 파라미터 전달
# $wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("URL"))) -Mode full -Force
#
# 옵션:
#   -Mode <MODE>             통합 모드 선택 (기본: interactive)
#                            • full        - 전체 통합 (버전관리+워크플로우+이슈템플릿)
#                            • version     - 버전 관리 시스템만
#                            • workflows   - GitHub Actions 워크플로우만
#                            • issues      - 이슈/PR 템플릿만
#                            • interactive - 대화형 선택 (기본값)
#   -Version <VERSION>       초기 버전 설정 (자동 감지, 수동 지정 가능)
#   -Type <TYPE>             프로젝트 타입 (자동 감지, 수동 지정 가능)
#                            지원: spring, flutter, react, react-native,
#                                  react-native-expo, node, python, basic
#   -NoBackup                백업 생성 안 함 (기본: 백업 생성)
#   -Force                   확인 없이 즉시 실행
#   -Help                    도움말 표시
#
# 예시:
#   # 대화형 모드 (추천)
#   .\template_integrator.ps1
#
#   # 버전 관리 시스템만 추가
#   .\template_integrator.ps1 -Mode version
#
#   # 전체 통합 (자동 감지)
#   .\template_integrator.ps1 -Mode full
#
#   # Node.js 프로젝트로 버전 1.0.0 설정
#   .\template_integrator.ps1 -Mode full -Version "1.0.0" -Type node
#
# ===================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Mode = "interactive",

    [Parameter(Mandatory=$false)]
    [string]$Version = "",

    [Parameter(Mandatory=$false)]
    [string]$Type = "",

    [Parameter(Mandatory=$false)]
    [switch]$NoBackup,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$Synology,

    [Parameter(Mandatory=$false)]
    [switch]$NoSynology,

    [Parameter(Mandatory=$false)]
    [string]$Target = "",

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# 에러 발생 시 스크립트 중단
$ErrorActionPreference = "Stop"

# UTF-8 인코딩 설정 (한글 지원)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ===================================================================
# SSL 인증서 관련 환경 변수 초기화
# 사용자 환경에서 잘못 설정된 CA 경로 문제 방지
# (예: curl: (77) error setting certificate verify locations: CAfile: /tmp/cacert.pem)
# ===================================================================
$env:CURL_CA_BUNDLE = $null
$env:SSL_CERT_FILE = $null
$env:SSL_CERT_DIR = $null
$env:REQUESTS_CA_BUNDLE = $null

# ===================================================================
# 상수 정의
# ===================================================================

$TEMPLATE_REPO = "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git"
$TEMPLATE_RAW_URL = "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main"
$TEMP_DIR = ".template_download_temp"
$VERSION_FILE = "version.yml"
$WORKFLOWS_DIR = ".github/workflows"
$SCRIPTS_DIR = ".github/scripts"
$PROJECT_TYPES_DIR = "project-types"
$DEFAULT_VERSION = "1.3.14"
$WORKFLOW_PREFIX = "PROJECT"
$WORKFLOW_COMMON_PREFIX = "PROJECT-COMMON"
$WORKFLOW_TEMPLATE_INIT = "PROJECT-TEMPLATE-INITIALIZER.yaml"

# 전역 변수
$script:ProjectType = $Type
$script:ProjectVersion = $Version
$script:DetectedBranch = ""
$script:IsInteractiveMode = $false
$script:WorkflowsCopied = 0
$script:UtilModulesCopied = 0
$script:ValidTypes = @("spring", "flutter", "next", "react", "react-native", "react-native-expo", "node", "python", "basic")
$script:IncludeSynology = $null  # Synology 워크플로우 포함 여부 ($null: 미설정, $true/$false: 명시적 설정)
$script:TemplateVersion = ""  # 다운로드한 템플릿의 실제 버전 (Download-Template에서 설정됨)

# ===================================================================
# 출력 함수 (색상 지원)
# ===================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Print-Header {
    param([string]$Title)
    Write-Host ""
    Write-ColorOutput "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-ColorOutput "║ $Title" -ForegroundColor Cyan
    Write-ColorOutput "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Print-Banner {
    param(
        [string]$Version,
        [string]$Mode
    )
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗"
    Write-Host "║ 🔮  ✦ S U H · D E V O P S · T E M P L A T E ✦                    ║"
    Write-Host "╚══════════════════════════════════════════════════════════════════╝"
    Write-Host "       🌙 Version : v$Version"
    Write-Host "       🐵 Author  : Cassiiopeia"
    Write-Host "       🪐 Mode    : $Mode"
    Write-Host "       📦 Repo    : github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    Write-Host ""
}

function Print-Step {
    param([string]$Message)
    Write-ColorOutput "🔅 $Message" -ForegroundColor Cyan
}

function Print-Info {
    param([string]$Message)
    Write-ColorOutput "  🔸 $Message" -ForegroundColor Blue
}

function Print-Success {
    param([string]$Message)
    Write-ColorOutput "✨ $Message" -ForegroundColor Green
}

function Print-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠️  $Message" -ForegroundColor Yellow
}

function Print-Error {
    param([string]$Message)
    Write-ColorOutput "💥 $Message" -ForegroundColor Red
}

function Print-Question {
    param([string]$Message)
    Write-ColorOutput "💫 $Message" -ForegroundColor Magenta
}

function Print-SeparatorLine {
    Write-Host "────────────────────────────────────────"
}

function Print-SectionHeader {
    param(
        [string]$Emoji,
        [string]$Title
    )
    
    Write-Host ""
    Write-Host "────────────────────────────────────────────────────────────────────────────────"
    Write-Host "$Emoji $Title"
    Write-Host "────────────────────────────────────────────────────────────────────────────────"
}

function Print-QuestionHeader {
    param(
        [string]$Emoji,
        [string]$Question
    )
    
    Write-Host ""
    Print-SeparatorLine
    Write-Host "$Emoji $Question"
    Print-SeparatorLine
    Write-Host ""
}

# ===================================================================
# 사용자 입력 함수
# ===================================================================

function Read-UserInput {
    param(
        [string]$Prompt,
        [string]$DefaultValue = ""
    )
    
    if ($DefaultValue) {
        $input = Read-Host "$Prompt (기본: $DefaultValue)"
        if ([string]::IsNullOrWhiteSpace($input)) {
            return $DefaultValue
        }
        return $input
    } else {
        return Read-Host $Prompt
    }
}

function Read-SingleKey {
    param([string]$Prompt)
    
    Write-Host $Prompt -NoNewline
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
    return $key.Character.ToString().ToUpper()
}

function Ask-YesNo {
    param(
        [string]$Prompt,
        [string]$DefaultValue = "N"
    )
    
    while ($true) {
        $response = Read-SingleKey "$Prompt (Y/N, 기본: $DefaultValue) "
        
        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = $DefaultValue
        }
        
        if ($response -eq "Y") {
            return $true
        } elseif ($response -eq "N") {
            return $false
        } else {
            Print-Error "잘못된 입력입니다. Y 또는 N을 입력해주세요."
            Write-Host ""
        }
    }
}

function Ask-YesNoEdit {
    while ($true) {
        $response = Read-SingleKey "선택 (Y/N/E) "
        
        $response = $response.ToUpper()
        
        if ($response -eq "" -or $response -eq "Y") {
            return "yes"
        } elseif ($response -eq "N") {
            return "no"
        } elseif ($response -eq "E") {
            return "edit"
        } else {
            Print-Error "잘못된 입력입니다. Y, E, 또는 N을 입력해주세요."
            Write-Host ""
        }
    }
}

# ===================================================================
# 도움말
# ===================================================================

function Show-Help {
    Write-Host @"

GitHub 템플릿 통합 스크립트 v1.0.0 (Windows PowerShell)

사용법:
  .\template_integrator.ps1 [옵션]

통합 모드:
  full        - 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)
  version     - 버전 관리 시스템만 (version.yml + scripts)
  workflows   - GitHub Actions 워크플로우만
  issues      - 이슈/PR 템플릿만
  commands    - Custom Command만 (Cursor/Claude 설정)
  interactive - 대화형 선택 (기본값, 추천)

옵션:
  -Mode <MODE>          통합 모드 선택
  -Version <VERSION>    초기 버전 (미지정 시 자동 감지)
  -Type <TYPE>          프로젝트 타입 (미지정 시 자동 감지)
  -NoBackup             백업 생성 안 함
  -Force                확인 없이 즉시 실행
  -Target <TARGET>      commands 모드 설치 대상 (cursor, claude, all)
  -Synology             Synology 워크플로우 포함 (기본: 제외)
  -NoSynology           Synology 워크플로우 제외
  -Help                 이 도움말 표시

지원 프로젝트 타입:
  • node / react / next / react-native - Node.js 기반 프로젝트
  • spring            - Spring Boot 백엔드
  • flutter           - Flutter 모바일 앱
  • python            - Python 프로젝트
  • basic             - 기타 프로젝트

자동 감지 기능:
  우선순위 1 (명확한 프레임워크 마커):
    • pubspec.yaml → Flutter
    • build.gradle/pom.xml → Spring Boot
    • pyproject.toml → Python
  우선순위 2 (Node.js 에코시스템 세부 분류):
    • package.json 내용 분석
      - @react-native → React Native
      - "next" → Next.js
      - "react" → React
      - 기타 → Node.js

사용 예시:
  # 로컬 실행 - 대화형 모드 (추천)
  .\template_integrator.ps1

  # 원격 실행 - 대화형 모드
  $wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.../template_integrator.ps1")

  # 버전 관리만 추가
  .\template_integrator.ps1 -Mode version

  # 전체 통합 (자동 감지)
  .\template_integrator.ps1 -Mode full

  # 수동 설정
  .\template_integrator.ps1 -Mode full -Version "1.0.0" -Type node

  # Custom Command만 설치 (대화형 메뉴)
  .\template_integrator.ps1 -Mode commands

  # Custom Command 모두 설치 (확인 없이)
  .\template_integrator.ps1 -Mode commands -Target all -Force

통합 후 작업:
  1. README.md - 버전 정보 섹션 자동 추가됨 (기존 내용 보존)
  2. version.yml - 버전 관리 설정 파일 생성
  3. .github/workflows/ - 워크플로우 파일 추가

⚠️  주의사항:
  • 기존 README.md, LICENSE는 절대 덮어쓰지 않습니다
  • 충돌하는 워크플로우는 .bak 파일로 백업됩니다
  • Git 저장소가 아니면 경고만 표시하고 계속 진행합니다

"@
}

# ===================================================================
# 프로젝트 타입 자동 감지
# ===================================================================

function Detect-ProjectType {
    Print-Step "프로젝트 타입 자동 감지 중..."

    # ===================================================
    # 우선순위 1: 명확한 프레임워크 마커 파일 체크
    # Flutter, Spring, Python은 고유한 마커 파일을 가지므로 우선 체크
    # ===================================================

    # Flutter
    if (Test-Path "pubspec.yaml") {
        Print-Info "감지됨: Flutter"
        return "flutter"
    }

    # Spring Boot
    if ((Test-Path "build.gradle") -or (Test-Path "build.gradle.kts") -or (Test-Path "pom.xml")) {
        Print-Info "감지됨: Spring Boot"
        return "spring"
    }

    # Python
    if ((Test-Path "pyproject.toml") -or (Test-Path "setup.py") -or (Test-Path "requirements.txt")) {
        Print-Info "감지됨: Python"
        return "python"
    }

    # ===================================================
    # 우선순위 2: Node.js 에코시스템 세부 분류
    # package.json은 여러 프로젝트 타입에서 보조 도구로 사용될 수 있으므로 나중에 체크
    # ===================================================

    # Node.js / React / React Native / Next.js
    if (Test-Path "package.json") {
        $packageJson = Get-Content "package.json" -Raw

        # React Native 체크
        if ($packageJson -match "@react-native|react-native") {
            # Expo 체크
            if ($packageJson -match "expo") {
                Print-Info "감지됨: React Native (Expo)"
                return "react-native-expo"
            } else {
                Print-Info "감지됨: React Native"
                return "react-native"
            }
        }

        # Next.js 체크 (React보다 먼저 체크해야 함)
        if ($packageJson -match '"next"') {
            Print-Info "감지됨: Next.js"
            return "next"
        }

        # React 체크
        if ($packageJson -match '"react"') {
            Print-Info "감지됨: React"
            return "react"
        }

        # 기본 Node.js
        Print-Info "감지됨: Node.js"
        return "node"
    }

    # ===================================================
    # 감지 실패
    # ===================================================
    Print-Warning "프로젝트 타입을 감지하지 못했습니다. 기본(basic) 타입으로 설정합니다."
    return "basic"
}

# ===================================================================
# 버전 자동 감지
# ===================================================================

function Detect-Version {
    Print-Step "버전 정보 자동 감지 중..."
    
    $detectedVersion = ""
    
    # package.json
    if (Test-Path "package.json") {
        try {
            $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
            if ($packageJson.version) {
                $detectedVersion = $packageJson.version
                Print-Info "package.json에서 발견: v$detectedVersion"
                return $detectedVersion
            }
        } catch {
            # JSON 파싱 실패 시 무시
        }
    }
    
    # build.gradle (Spring Boot)
    if (Test-Path "build.gradle") {
        $content = Get-Content "build.gradle" -Raw
        if ($content -match 'version\s*=\s*[''"]?([0-9]+\.[0-9]+\.[0-9]+)') {
            $detectedVersion = $matches[1]
            Print-Info "build.gradle에서 발견: v$detectedVersion"
            return $detectedVersion
        }
    }
    
    # pubspec.yaml (Flutter)
    if (Test-Path "pubspec.yaml") {
        $content = Get-Content "pubspec.yaml" -Raw
        if ($content -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
            $detectedVersion = $matches[1]
            Print-Info "pubspec.yaml에서 발견: v$detectedVersion"
            return $detectedVersion
        }
    }
    
    # pyproject.toml (Python)
    if (Test-Path "pyproject.toml") {
        $content = Get-Content "pyproject.toml" -Raw
        if ($content -match 'version\s*=\s*[''"]?([0-9]+\.[0-9]+\.[0-9]+)') {
            $detectedVersion = $matches[1]
            Print-Info "pyproject.toml에서 발견: v$detectedVersion"
            return $detectedVersion
        }
    }
    
    # Git 태그
    try {
        $gitTag = git describe --tags --abbrev=0 2>$null
        if ($gitTag) {
            $detectedVersion = $gitTag -replace '^v', ''
            Print-Info "Git 태그에서 발견: v$detectedVersion"
            return $detectedVersion
        }
    } catch {
        # Git 명령 실패 시 무시
    }
    
    # 기본값
    Print-Warning "버전을 감지하지 못했습니다. 기본값 0.0.1로 설정합니다."
    return "0.0.1"
}

# ===================================================================
# Default Branch 감지
# ===================================================================

function Detect-DefaultBranch {
    $detected = ""
    
    # git symbolic-ref
    try {
        $detected = git symbolic-ref refs/remotes/origin/HEAD 2>$null
        if ($detected) {
            $detected = $detected -replace '^refs/remotes/origin/', ''
            return $detected
        }
    } catch {}
    
    # git remote show
    try {
        $output = git remote show origin 2>$null
        foreach ($line in $output) {
            if ($line -match 'HEAD branch:\s*(.+)') {
                return $matches[1].Trim()
            }
        }
    } catch {}
    
    # 기본값
    return "main"
}

# ===================================================================
# 프로젝트 타입 선택 메뉴
# ===================================================================

function Show-ProjectTypeMenu {
    Write-Host ""
    Write-Host "프로젝트 타입을 선택하세요:"
    Write-Host ""
    Write-Host "  1) spring            - Spring Boot 백엔드"
    Write-Host "  2) flutter           - Flutter 모바일 앱"
    Write-Host "  3) next              - Next.js 웹 앱"
    Write-Host "  4) react             - React 웹 앱"
    Write-Host "  5) react-native      - React Native 모바일 앱"
    Write-Host "  6) react-native-expo - React Native Expo 앱"
    Write-Host "  7) node              - Node.js 프로젝트"
    Write-Host "  8) python            - Python 프로젝트"
    Write-Host "  9) basic             - 기타 프로젝트"
    Write-Host ""

    while ($true) {
        $choice = Read-SingleKey "선택 (1-9) "

        if ($choice -match '^[1-9]$') {
            switch ($choice) {
                "1" { return "spring" }
                "2" { return "flutter" }
                "3" { return "next" }
                "4" { return "react" }
                "5" { return "react-native" }
                "6" { return "react-native-expo" }
                "7" { return "node" }
                "8" { return "python" }
                "9" { return "basic" }
            }
        } else {
            Print-Error "잘못된 입력입니다. 1-9 사이의 숫자를 입력해주세요."
            Write-Host ""
        }
    }
}

# ===================================================================
# 프로젝트 정보 수정 메뉴
# ===================================================================

function Edit-ProjectInfo {
    Print-QuestionHeader "💫" "어떤 항목을 수정하시겠습니까?"
    
    Write-Host "  1) Project Type"
    Write-Host "  2) Version"
    Write-Host "  3) Default Branch (기본 브랜치)"
    Write-Host "  4) 모두 맞음, 계속"
    Write-Host ""
    
    while ($true) {
        $choice = Read-SingleKey "선택 (1-4) "
        
        if ($choice -match '^[1-4]$') {
            switch ($choice) {
                "1" {
                    # Project Type 수정
                    $script:ProjectType = Show-ProjectTypeMenu
                    Print-Success "Project Type이 '$($script:ProjectType)'(으)로 변경되었습니다"
                    Write-Host ""
                    break
                }
                "2" {
                    # Version 수정
                    Write-Host ""
                    $newVersion = Read-UserInput "새 버전을 입력하세요 (예: 1.0.0)"
                    Write-Host ""
                    
                    if ($newVersion -match '^[0-9]+\.[0-9]+\.[0-9]+$') {
                        $script:ProjectVersion = $newVersion
                        Print-Success "Version이 '$($script:ProjectVersion)'(으)로 변경되었습니다"
                    } else {
                        Print-Error "잘못된 버전 형식입니다. 기존 값을 유지합니다. (올바른 형식: x.y.z)"
                    }
                    Write-Host ""
                    break
                }
                "3" {
                    # Default Branch 수정
                    Write-Host ""
                    Write-Host "💡 이 설정은 GitHub Actions 워크플로우에서 사용할 기본 브랜치입니다."
                    Write-Host ""
                    $newBranch = Read-UserInput "기본 브랜치 이름을 입력하세요 (예: main, develop)"
                    Write-Host ""
                    
                    if (![string]::IsNullOrWhiteSpace($newBranch)) {
                        $script:DetectedBranch = $newBranch
                        Print-Success "Default Branch가 '$($script:DetectedBranch)'(으)로 변경되었습니다"
                    } else {
                        Print-Error "브랜치 이름이 비어있습니다. 기존 값을 유지합니다."
                    }
                    Write-Host ""
                    break
                }
                "4" {
                    # 모두 맞음, 계속
                    Print-Success "프로젝트 정보 확인 완료"
                    Write-Host ""
                    return
                }
            }
        } else {
            Print-Error "잘못된 입력입니다. 1-4 사이의 숫자를 입력해주세요."
            Write-Host ""
        }
    }
}

# ===================================================================
# 프로젝트 감지 및 확인
# ===================================================================

function Detect-AndConfirmProject {
    # 자동 감지 (최초 1회만)
    if ([string]::IsNullOrWhiteSpace($script:ProjectType)) {
        $script:ProjectType = Detect-ProjectType
    }
    if ([string]::IsNullOrWhiteSpace($script:ProjectVersion)) {
        $script:ProjectVersion = Detect-Version
    }
    if ([string]::IsNullOrWhiteSpace($script:DetectedBranch)) {
        $script:DetectedBranch = Detect-DefaultBranch
    }
    
    $confirmed = $false
    
    # 확인 루프 - Edit 선택 시 다시 확인 질문으로 돌아옴
    while (-not $confirmed) {
        Print-SectionHeader "🛰️" "프로젝트 분석 결과"
        
        # 감지 결과 표시
        Write-Host ""
        Write-Host "       📂 Project Type     : $($script:ProjectType)"
        Write-Host "       🌙 Version          : $($script:ProjectVersion)"
        Write-Host "       🌿 Default Branch   : $($script:DetectedBranch)"
        Write-Host ""
        
        # 사용자 확인
        Write-Host "이 정보가 맞습니까?"
        Write-Host "  Y/y - 예, 계속 진행"
        Write-Host "  E/e - 수정하기"
        Write-Host "  N/n - 아니오, 취소"
        Write-Host ""
        
        # Y/N/E 입력 받기
        $userChoice = Ask-YesNoEdit
        
        switch ($userChoice) {
            "yes" {
                $confirmed = $true
                Print-Success "프로젝트 정보 확인 완료"
                Write-Host ""
            }
            "no" {
                Print-Info "취소되었습니다"
                exit 0
            }
            "edit" {
                Edit-ProjectInfo
                # 루프 계속 - 다시 확인 질문으로
            }
        }
    }
}

# ===================================================================
# 템플릿 다운로드
# ===================================================================

function Download-Template {
    Print-Step "템플릿 다운로드 중..."
    
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }
    
    try {
        git clone --depth 1 --quiet $TEMPLATE_REPO $TEMP_DIR 2>&1 | Out-Null
    } catch {
        Print-Error "템플릿 다운로드 실패"
        exit 1
    }
    
    # 문서 파일 제거 (프로젝트 특화 문서는 복사하지 않음)
    Print-Info "템플릿 내부 문서 제외 중..."
    $docsToRemove = @(
        "CONTRIBUTING.md",
        "CLAUDE.md"
    )
    
    foreach ($doc in $docsToRemove) {
        $docPath = Join-Path $TEMP_DIR $doc
        if (Test-Path $docPath) {
            Remove-Item -Path $docPath -Force
        }
    }
    
    # 사용자 적용 가이드 문서는 포함
    Print-Info "사용자 적용 가이드 문서 다운로드 중..."
    $guidePath = Join-Path $TEMP_DIR "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    if (Test-Path $guidePath) {
        Print-Info "✓ SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    }

    # 다운로드한 템플릿에서 버전 읽기 (TemplateVersion 전역 변수에 저장)
    $templateVersionFile = Join-Path $TEMP_DIR "version.yml"
    if (Test-Path $templateVersionFile) {
        $versionContent = Get-Content $templateVersionFile -Raw -ErrorAction SilentlyContinue
        if ($versionContent -match 'version:\s*[''"]?([0-9.]+)') {
            $script:TemplateVersion = $matches[1]
        } else {
            $script:TemplateVersion = $DEFAULT_VERSION
        }
    } else {
        $script:TemplateVersion = $DEFAULT_VERSION
    }

    Print-Success "템플릿 다운로드 완료"
}

# ===================================================================
# README.md 버전 섹션 추가
# ===================================================================

function Add-VersionSectionToReadme {
    param([string]$Version)
    
    Print-Step "README.md에 버전 관리 섹션 추가 중..."
    
    if (-not (Test-Path "README.md")) {
        Print-Warning "README.md 파일이 없습니다. 건너뜁니다."
        return
    }
    
    # 이미 버전 섹션이 있는지 확인 (영어 마커만 체크 - 파싱 호환성)
    $readmeContent = Get-Content "README.md" -Raw

    if ($readmeContent -match "<!-- AUTO-VERSION-SECTION") {
        Print-Info "이미 버전 관리 섹션이 있습니다. (마커 감지)"
        return
    }

    # 버전 라인 체크 (버전 번호 패턴 감지)
    if ($readmeContent -match "(?i)##\s*(최신\s*버전|최신버전|Version|버전)\s*:\s*v\d+\.\d+\.\d+") {
        Print-Info "이미 버전 관리 섹션이 있습니다. (버전 라인 감지)"
        return
    }

    # README.md 끝에 버전 섹션 추가
    $versionSection = @"

---

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v$Version

[전체 버전 기록 보기](CHANGELOG.md)
"@
    
    Add-Content -Path "README.md" -Value $versionSection -Encoding UTF8
    
    Print-Success "README.md에 버전 관리 섹션 추가 완료"
    Print-Info "📝 위치: README.md 파일 하단"
    Print-Info "🔄 자동 업데이트: PROJECT-README-VERSION-UPDATE.yaml 워크플로우"
}

# ===================================================================
# version.yml 생성
# ===================================================================

function Create-VersionYml {
    param(
        [string]$Version,
        [string]$Type,
        [string]$Branch
    )
    
    $existingVersionCode = 1  # 기본값
    
    Print-Step "version.yml 생성 중..."
    
    if (Test-Path "version.yml") {
        # 기존 version.yml에서 version_code 추출
        # 주석이 아닌 실제 데이터 라인에서만 추출 (주석 내 'version_code: 1' 오탐지 방지)
        $lines = Get-Content "version.yml" -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            # 주석 라인 건너뛰기 (# 으로 시작하는 라인)
            if ($line -match '^\s*#') {
                continue
            }
            # version_code 값 추출 (라인 시작부터 매칭)
            if ($line -match '^version_code:\s*(\d+)') {
                $parsedValue = [int]$matches[1]
                if ($parsedValue -gt 0) {
                    $existingVersionCode = $parsedValue
                    Print-Info "기존 version_code 감지: $existingVersionCode"
                }
                break
            }
        }
        
        Print-Warning "version.yml이 이미 존재합니다"
        if (-not $Force) {
            Print-SeparatorLine
            Write-Host ""
            Write-Host "version.yml을 덮어쓰시겠습니까?"
            Write-Host "  Y/y - 예, 덮어쓰기"
            Write-Host "  N/n - 아니오, 건너뛰기 (기본)"
            Write-Host ""
            
            if (-not (Ask-YesNo "선택" "N")) {
                Print-Info "version.yml 생성 건너뜁니다"
                return
            }
        }
    }
    
    $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $integrationDate = Get-Date -Format "yyyy-MM-dd"
    
    $versionYmlContent = @"
# ===================================================================
# 프로젝트 버전 관리 파일
# ===================================================================
#
# 이 파일은 다양한 프로젝트 타입에서 버전 정보를 중앙 관리하기 위한 파일입니다.
# GitHub Actions 워크플로우가 이 파일을 읽어 자동으로 버전을 관리합니다.
#
# 사용법:
# 1. version: "1.0.0" - 사용자에게 표시되는 버전
# 2. version_code: 1 - Play Store/App Store 빌드 번호 (1부터 자동 증가)
# 3. project_type: 프로젝트 타입 지정
#
# 자동 버전 업데이트:
# - patch: 자동으로 세 번째 자리 증가 (x.x.x -> x.x.x+1)
# - version_code: 매 빌드마다 자동으로 1씩 증가
# - minor/major: 수동으로 직접 수정 필요
#
# 프로젝트 타입별 동기화 파일:
# - spring: build.gradle (version = "x.y.z")
# - flutter: pubspec.yaml (version: x.y.z+i, buildNumber 포함)
# - react/next/node: package.json ("version": "x.y.z")
# - react-native: iOS Info.plist 또는 Android build.gradle
# - react-native-expo: app.json (expo.version)
# - python: pyproject.toml (version = "x.y.z")
# - basic/기타: version.yml 파일만 사용
#
# 연관된 워크플로우:
# - .github/workflows/PROJECT-VERSION-CONTROL.yaml
# - .github/workflows/PROJECT-README-VERSION-UPDATE.yaml
# - .github/workflows/PROJECT-AUTO-CHANGELOG-CONTROL.yaml
#
# 주의사항:
# - project_type은 최초 설정 후 변경하지 마세요
# - 버전은 항상 높은 버전으로 자동 동기화됩니다
# ===================================================================

version: "$Version"
version_code: $existingVersionCode  # app build number
project_type: "$Type"  # spring, flutter, next, react, react-native, react-native-expo, node, python, basic
metadata:
  last_updated: "$currentDate"
  last_updated_by: "template_integrator"
  default_branch: "$Branch"
  integrated_from: "SUH-DEVOPS-TEMPLATE"
  integration_date: "$integrationDate"
"@
    
    Set-Content -Path "version.yml" -Value $versionYmlContent -Encoding UTF8

    Print-Success "version.yml 생성 완료"
}

# ===================================================================
# Synology 옵션 관리 함수
# ===================================================================

function Read-TemplateOptions {
    $versionFile = "version.yml"

    if (-not (Test-Path $versionFile)) {
        return
    }

    $content = Get-Content -Path $versionFile -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        return
    }

    # template.options.synology 값 찾기
    $inTemplate = $false
    $inOptions = $false

    foreach ($line in (Get-Content -Path $versionFile)) {
        # template: 섹션 시작 확인
        if ($line -match "^\s*template:") {
            $inTemplate = $true
            continue
        }

        # template 섹션 내부에서 options: 확인
        if ($inTemplate -and $line -match "^\s+options:") {
            $inOptions = $true
            continue
        }

        # options 섹션 내부에서 synology 값 확인
        if ($inTemplate -and $inOptions) {
            if ($line -match "^\s+synology:\s*(.+)") {
                $synologyVal = $matches[1].Trim().Trim('"').Trim("'")

                if ($synologyVal -eq "true" -or $synologyVal -eq "True") {
                    $script:IncludeSynology = $true
                    Print-Info "이전 설정에서 Synology 옵션 감지: 포함"
                }
                elseif ($synologyVal -eq "false" -or $synologyVal -eq "False") {
                    $script:IncludeSynology = $false
                    Print-Info "이전 설정에서 Synology 옵션 감지: 제외"
                }
                return
            }

            # 다른 최상위 키 만나면 options 섹션 종료
            if ($line -match "^\s{0,4}[a-z_]+:") {
                $inOptions = $false
                $inTemplate = $false
            }
        }

        # template 섹션 종료 확인
        if ($inTemplate -and $line -match "^[a-z_]+:") {
            $inTemplate = $false
            $inOptions = $false
        }
    }
}

function Save-TemplateOptions {
    param([string]$TemplateVersion = "unknown")

    $versionFile = "version.yml"
    $today = (Get-Date).ToString("yyyy-MM-dd")

    if (-not (Test-Path $versionFile)) {
        return
    }

    $content = Get-Content -Path $versionFile -Raw

    # 기존에 template 섹션이 있는지 확인
    if ($content -match "template:") {
        # synology 값 업데이트 또는 추가
        if ($content -match "synology:") {
            $content = $content -replace "synology:.*$", "synology: $($script:IncludeSynology.ToString().ToLower())"
        }
        elseif ($content -match "options:") {
            # options 다음 줄에 synology 추가
            $content = $content -replace "(options:)", "`$1`n      synology: $($script:IncludeSynology.ToString().ToLower())"
        }

        # last_update_date 업데이트
        if ($content -match "last_update_date:") {
            $content = $content -replace 'last_update_date:.*$', "last_update_date: `"$today`""
        }

        Set-Content -Path $versionFile -Value $content -Encoding UTF8
    }
    else {
        # template 섹션 새로 추가
        $templateSection = @"
  template:
    source: "SUH-DEVOPS-TEMPLATE"
    version: "$TemplateVersion"
    integrated_date: "$today"
    last_update_date: "$today"
    options:
      synology: $($script:IncludeSynology.ToString().ToLower())
"@
        Add-Content -Path $versionFile -Value $templateSection -Encoding UTF8
        Print-Info "version.yml에 템플릿 설정 저장됨"
    }
}

# 버전 비교 함수 (v1 > v2 이면 1, v1 < v2 이면 -1, 같으면 0)
function Compare-SemVer {
    param(
        [string]$Version1,
        [string]$Version2
    )

    # v 접두사 제거
    $v1 = $Version1 -replace "^v", ""
    $v2 = $Version2 -replace "^v", ""

    $parts1 = $v1.Split(".")
    $parts2 = $v2.Split(".")

    for ($i = 0; $i -lt 3; $i++) {
        $p1 = if ($i -lt $parts1.Length) { [int]$parts1[$i] } else { 0 }
        $p2 = if ($i -lt $parts2.Length) { [int]$parts2[$i] } else { 0 }

        if ($p1 -gt $p2) { return 1 }
        if ($p1 -lt $p2) { return -1 }
    }

    return 0
}

# Breaking Changes 확인 및 알림
function Test-BreakingChanges {
    param(
        [string]$CurrentVersion,
        [string]$NewVersion
    )

    # 버전 정보가 없으면 (레거시 프로젝트) 스킵
    if ([string]::IsNullOrEmpty($CurrentVersion) -or $CurrentVersion -eq "unknown") {
        return $true
    }

    # -Force 모드면 스킵
    if ($Force) {
        return $true
    }

    # breaking-changes.json 다운로드
    $bcUrl = "$script:TemplateRawUrl/.github/config/breaking-changes.json"
    try {
        $bcJson = Invoke-RestMethod -Uri $bcUrl -UseBasicParsing -ErrorAction Stop
    }
    catch {
        return $true
    }

    # breaking changes 버전 목록 추출 (객체 속성 중 _ 로 시작하지 않는 것)
    $versions = $bcJson.PSObject.Properties | Where-Object { $_.Name -notlike "_*" } | Select-Object -ExpandProperty Name

    # 해당 버전 범위의 breaking changes 수집
    $criticalChanges = @()
    $warningChanges = @()

    foreach ($ver in $versions) {
        # CurrentVersion < ver <= NewVersion 인 경우만 해당
        $cmpCurrent = Compare-SemVer -Version1 $ver -Version2 $CurrentVersion
        $cmpNew = Compare-SemVer -Version1 $ver -Version2 $NewVersion

        if ($cmpCurrent -eq 1 -and $cmpNew -ne 1) {
            $change = $bcJson.$ver
            $severity = if ($change.severity) { $change.severity } else { "warning" }
            $title = if ($change.title) { $change.title } else { "" }
            $message = if ($change.message) { $change.message } else { "" }

            $changeInfo = @{
                Version = "v$ver"
                Title = $title
                Message = $message
            }

            if ($severity -eq "critical") {
                $criticalChanges += $changeInfo
            }
            else {
                $warningChanges += $changeInfo
            }
        }
    }

    # breaking change가 없으면 리턴
    $totalChanges = $criticalChanges.Count + $warningChanges.Count
    if ($totalChanges -eq 0) {
        return $true
    }

    # 알림 표시
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗"
    Write-Host "║  ⚠️  BREAKING CHANGES (v$CurrentVersion → v$NewVersion)"
    Write-Host "╠══════════════════════════════════════════════════════════════════╣"

    # Critical changes 표시
    foreach ($change in $criticalChanges) {
        Write-Host "║"
        Write-Host "║  " -NoNewline
        Write-Host "[CRITICAL]" -ForegroundColor Red -NoNewline
        Write-Host " $($change.Version) - $($change.Title)"
        Write-Host "║  → $($change.Message)"
    }

    # Warning changes 표시
    foreach ($change in $warningChanges) {
        Write-Host "║"
        Write-Host "║  " -NoNewline
        Write-Host "[WARNING]" -ForegroundColor Yellow -NoNewline
        Write-Host " $($change.Version) - $($change.Title)"
        Write-Host "║  → $($change.Message)"
    }

    Write-Host "║"
    Write-Host "╚══════════════════════════════════════════════════════════════════╝"
    Write-Host ""

    # Critical이 있으면 Y/N 확인
    if ($criticalChanges.Count -gt 0) {
        Print-Warning "CRITICAL 변경사항이 있습니다."
        Write-Host ""
        Write-Host "계속 진행하시겠습니까?"
        Write-Host "  Y/y - 예, 계속 진행"
        Write-Host "  N/n - 아니오, 취소"
        Write-Host ""

        if (-not (Ask-YesNo -Prompt "선택: " -Default "N")) {
            Print-Info "취소되었습니다"
            exit 0
        }
    }

    return $true
}

# 현재 프로젝트의 템플릿 버전 읽기
function Get-CurrentTemplateVersion {
    $versionFile = "version.yml"

    if (-not (Test-Path $versionFile)) {
        return "unknown"
    }

    $content = Get-Content -Path $versionFile -Raw

    # metadata.template.version 읽기 (template 섹션 내 version만 정확히 매칭)
    if ($content -match "template:\s*\r?\n\s+source:[^\r\n]+\r?\n\s+version:\s*[`"']?([0-9.]+)[`"']?") {
        return $matches[1]
    }

    return "unknown"
}

function Ask-SynologyOption {
    param([string]$TypeDir)

    $synologyDir = Join-Path $TypeDir "synology"

    # synology 폴더가 없으면 건너뛰기
    if (-not (Test-Path $synologyDir)) {
        return
    }

    # CLI 파라미터로 이미 지정된 경우
    if ($Synology) {
        $script:IncludeSynology = $true
        return
    }
    if ($NoSynology) {
        $script:IncludeSynology = $false
        return
    }

    # 이미 설정되어 있으면 건너뛰기
    if ($null -ne $script:IncludeSynology) {
        return
    }

    # 기존 version.yml에서 설정 읽기 시도
    Read-TemplateOptions

    # 이전 설정이 있으면 건너뛰기
    if ($null -ne $script:IncludeSynology) {
        return
    }

    # synology 폴더 내 파일 개수 확인
    $synologyFiles = @()
    $yamlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yaml" -ErrorAction SilentlyContinue
    $ymlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yml" -ErrorAction SilentlyContinue
    if ($yamlFiles) { $synologyFiles += $yamlFiles }
    if ($ymlFiles) { $synologyFiles += $ymlFiles }

    if ($synologyFiles.Count -eq 0) {
        return
    }

    Print-SeparatorLine
    Write-Host ""
    Write-Host "🗄️ Synology 워크플로우가 발견되었습니다. ($($synologyFiles.Count)개 파일)"
    Write-Host "   Synology NAS에 배포하는 워크플로우를 포함하시겠습니까?"
    Write-Host ""
    Write-Host "   포함되는 워크플로우:"
    foreach ($f in $synologyFiles) {
        Write-Host "     • $($f.Name)"
    }
    Write-Host ""
    Write-Host "  Y/y - 예, 포함"
    Write-Host "  N/n - 아니오, 제외 (기본)"
    Write-Host ""

    if (Ask-YesNo "선택" "N") {
        $script:IncludeSynology = $true
        Print-Info "Synology 워크플로우를 포함합니다"
    }
    else {
        $script:IncludeSynology = $false
        Print-Info "Synology 워크플로우를 제외합니다"
    }
}

# ===================================================================
# 워크플로우 다운로드
# ===================================================================

function Copy-Workflows {
    Print-Step "프로젝트 타입별 워크플로우 다운로드 중..."
    Print-Info "프로젝트 타입: $($script:ProjectType)"

    if (-not (Test-Path $WORKFLOWS_DIR)) {
        New-Item -Path $WORKFLOWS_DIR -ItemType Directory -Force | Out-Null
    }

    $copied = 0
    $skipped = 0
    $templateAdded = 0
    $projectTypesDir = Join-Path $TEMP_DIR "$WORKFLOWS_DIR\$PROJECT_TYPES_DIR"

    # project-types 폴더 존재 확인
    if (-not (Test-Path $projectTypesDir)) {
        Print-Error "템플릿 저장소의 폴더 구조가 올바르지 않습니다."
        Print-Error "project-types 폴더를 찾을 수 없습니다."
        exit 1
    }

    # 1. Common 워크플로우 다운로드 (항상 최신으로 업데이트)
    Print-Info "공통 워크플로우 다운로드 중..."
    $commonDir = Join-Path $projectTypesDir "common"
    if (Test-Path $commonDir) {
        # PowerShell 5.1 호환성: 배열 초기화 후 추가 (null += 방지)
        $workflows = @()
        $yamlFiles = Get-ChildItem -Path $commonDir -Filter "*.yaml" -ErrorAction SilentlyContinue
        $ymlFiles = Get-ChildItem -Path $commonDir -Filter "*.yml" -ErrorAction SilentlyContinue
        if ($yamlFiles) { $workflows += $yamlFiles }
        if ($ymlFiles) { $workflows += $ymlFiles }

        foreach ($workflow in $workflows) {
            $filename = $workflow.Name
            $destPath = Join-Path $WORKFLOWS_DIR $filename

            # COMMON은 항상 덮어쓰기 (핵심 기능)
            if (Test-Path $destPath) {
                Print-Info "$filename 업데이트"
            }

            Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
            Write-Host "  ✓ $filename"
            $copied++
        }
    } else {
        Print-Warning "common 폴더를 찾을 수 없습니다. 건너뜁니다."
    }

    # 2. 타입별 워크플로우 처리 (선택적 업데이트)
    $typeDir = Join-Path $projectTypesDir $script:ProjectType
    if (Test-Path $typeDir) {
        # 먼저 이미 존재하는 파일 목록 수집
        $existingFiles = @()
        $newFiles = @()

        # PowerShell 5.1 호환성: 배열 초기화 후 추가
        $workflows = @()
        $yamlFiles = Get-ChildItem -Path $typeDir -Filter "*.yaml" -ErrorAction SilentlyContinue
        $ymlFiles = Get-ChildItem -Path $typeDir -Filter "*.yml" -ErrorAction SilentlyContinue
        if ($yamlFiles) { $workflows += $yamlFiles }
        if ($ymlFiles) { $workflows += $ymlFiles }

        foreach ($workflow in $workflows) {
            $filename = $workflow.Name
            $destPath = Join-Path $WORKFLOWS_DIR $filename

            if (Test-Path $destPath) {
                $existingFiles += $workflow
            } else {
                $newFiles += $workflow
            }
        }

        # 신규 파일은 바로 복사
        if ($newFiles.Count -gt 0) {
            Print-Info "$($script:ProjectType) 신규 워크플로우 다운로드 중..."
            foreach ($workflow in $newFiles) {
                Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                Write-Host "  ✓ $($workflow.Name) (신규)"
                $copied++
            }
        }

        # 이미 존재하는 파일 처리
        if ($existingFiles.Count -gt 0) {
            Write-Host ""
            Print-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            Print-Warning "⚠️  이미 존재하는 타입별 워크플로우: $($existingFiles.Count)개"
            Print-Warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            foreach ($workflow in $existingFiles) {
                Write-Host "   • $($workflow.Name)"
            }
            Write-Host ""
            Print-Info "처리 방법을 선택하세요:"
            Write-Host ""
            Write-Host "  (T) .template.yaml로 추가"
            Write-Host "      → 기존 파일 유지 + 새 버전을 참고용으로 추가"
            Write-Host "      → 예: PROJECT-FLUTTER-*.yaml.template.yaml"
            Write-Host ""
            Write-Host "  (S) 건너뛰기"
            Write-Host "      → 기존 파일만 유지, 아무것도 추가 안 함"
            Write-Host ""
            Write-Host "  (O) 덮어쓰기 (기존 방식)"
            Write-Host "      → 기존 파일을 .bak으로 백업 후 덮어쓰기"
            Write-Host ""

            $choice = Read-SingleKey "선택 [T/S/O]: "
            Write-Host ""

            switch ($choice.ToUpper()) {
                "T" {
                    # .template.yaml로 추가
                    Print-Info "새 버전을 .template.yaml로 추가합니다..."
                    foreach ($workflow in $existingFiles) {
                        $filename = $workflow.Name
                        $templateName = $filename -replace '\.yaml$', '.template.yaml'
                        $templatePath = Join-Path $WORKFLOWS_DIR $templateName
                        # 기존 .template.yaml이 있으면 삭제
                        if (Test-Path $templatePath) {
                            Remove-Item -Path $templatePath -Force
                        }
                        Copy-Item -Path $workflow.FullName -Destination $templatePath -Force
                        Write-Host "  ✓ $templateName (참고용 추가)"
                        $templateAdded++
                    }
                    Print-Info "💡 .template.yaml 파일은 GitHub Actions에서 실행되지 않습니다."
                    Print-Info "   필요한 변경사항을 참고하여 기존 파일에 수동으로 반영하세요."
                }
                "S" {
                    # 건너뛰기
                    Print-Info "기존 파일을 유지합니다..."
                    foreach ($workflow in $existingFiles) {
                        Write-Host "  ⏭ $($workflow.Name) (건너뜀)"
                        $skipped++
                    }
                }
                "O" {
                    # 기존 방식 (덮어쓰기)
                    Print-Info "기존 파일을 백업 후 덮어씁니다..."
                    foreach ($workflow in $existingFiles) {
                        $filename = $workflow.Name
                        $destPath = Join-Path $WORKFLOWS_DIR $filename
                        $backupPath = [string]$destPath + ".bak"
                        Move-Item -Path $destPath -Destination $backupPath -Force
                        Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                        Write-Host "  ✓ $filename (백업: ${filename}.bak)"
                        $copied++
                    }
                }
                default {
                    # 기본값: 건너뛰기
                    Print-Warning "잘못된 선택. 기존 파일을 유지합니다."
                    foreach ($workflow in $existingFiles) {
                        Write-Host "  ⏭ $($workflow.Name) (건너뜀)"
                        $skipped++
                    }
                }
            }
        } else {
            Print-Info "$($script:ProjectType) 타입의 기존 워크플로우가 없습니다."
        }
    } else {
        Print-Info "$($script:ProjectType) 타입의 전용 워크플로우가 없습니다. (공통 워크플로우만 사용)"
    }

    # 3. Synology 하위폴더 처리 (선택적)
    $synologyCopied = 0
    $synologyDir = Join-Path $projectTypesDir "$($script:ProjectType)\synology"

    if (Test-Path $synologyDir) {
        if ($script:IncludeSynology -eq $true) {
            Print-Info "Synology 워크플로우 다운로드 중..."

            $synologyWorkflows = @()
            $yamlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yaml" -ErrorAction SilentlyContinue
            $ymlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yml" -ErrorAction SilentlyContinue
            if ($yamlFiles) { $synologyWorkflows += $yamlFiles }
            if ($ymlFiles) { $synologyWorkflows += $ymlFiles }

            foreach ($workflow in $synologyWorkflows) {
                $filename = $workflow.Name
                $destPath = Join-Path $WORKFLOWS_DIR $filename

                # 이미 존재하는 경우 처리
                if (Test-Path $destPath) {
                    # 기존 파일 백업 후 덮어쓰기
                    $backupPath = [string]$destPath + ".bak"
                    Move-Item -Path $destPath -Destination $backupPath -Force
                    Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                    Write-Host "  ✓ $filename (Synology, 백업: ${filename}.bak)"
                } else {
                    Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                    Write-Host "  ✓ $filename (Synology)"
                }
                $synologyCopied++
                $copied++
            }
        } else {
            # Synology 제외됨 - 사용자에게 알림
            $synologyFiles = @()
            $yamlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yaml" -ErrorAction SilentlyContinue
            $ymlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yml" -ErrorAction SilentlyContinue
            if ($yamlFiles) { $synologyFiles += $yamlFiles }
            if ($ymlFiles) { $synologyFiles += $ymlFiles }

            if ($synologyFiles.Count -gt 0) {
                Print-Info "Synology 워크플로우 $($synologyFiles.Count)개 제외됨 (-Synology 옵션으로 포함 가능)"
            }
        }
    }

    # 결과 요약
    Write-Host ""
    Print-Success "워크플로우 처리 완료 (타입: $($script:ProjectType))"
    Write-Host "   📥 복사됨: $copied 개"
    if ($synologyCopied -gt 0) {
        Write-Host "   🗄️ Synology: $synologyCopied 개"
    }
    if ($templateAdded -gt 0) {
        Write-Host "   📄 참고용 추가 (.template.yaml): $templateAdded 개"
    }
    if ($skipped -gt 0) {
        Write-Host "   ⏭ 건너뜀: $skipped 개"
    }

    # 복사된 워크플로우 수를 전역 변수로 저장
    $script:WorkflowsCopied = $copied

    # CI/CD 워크플로우 안내
    if ($script:ProjectType -eq "spring") {
        Write-Host ""
        Print-Info "🔐 Spring CI/CD 워크플로우 사용 시 GitHub Secrets 설정:"
        Write-Host "     Repository > Settings > Secrets > Actions"
        Write-Host "     필수 Secrets:"
        Write-Host "       - APPLICATION_PROD_YML (Spring 운영 설정)"
        Write-Host "       - DOCKERHUB_USERNAME, DOCKERHUB_TOKEN"
        Write-Host "       - SERVER_HOST, SERVER_USER, SERVER_PASSWORD"
        Write-Host "       - GRADLE_PROPERTIES (Nexus 사용 시)"
    }
}

# ===================================================================
# 스크립트 다운로드
# ===================================================================

function Copy-Scripts {
    Print-Step "버전 관리 스크립트 다운로드 중..."
    
    if (-not (Test-Path $SCRIPTS_DIR)) {
        New-Item -Path $SCRIPTS_DIR -ItemType Directory -Force | Out-Null
    }
    
    $scripts = @(
        "version_manager.sh",
        "changelog_manager.py"
    )
    
    $copied = 0
    foreach ($script in $scripts) {
        $src = Join-Path $TEMP_DIR "$SCRIPTS_DIR\$script"
        $dst = Join-Path $SCRIPTS_DIR $script
        
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $dst -Force
            Write-Host "  ✓ $script"
            $copied++
        }
    }
    
    Print-Success "$copied 개 스크립트 다운로드 완료"
}

# ===================================================================
# .github/config 폴더 복사
# ===================================================================

function Copy-ConfigFolder {
    Print-Step ".github/config 폴더 복사 중..."

    $srcConfigDir = Join-Path $TEMP_DIR ".github\config"
    $dstConfigDir = ".github\config"

    if (-not (Test-Path $srcConfigDir)) {
        Print-Info ".github/config 폴더가 템플릿에 없습니다. 건너뜁니다."
        return
    }

    # 기존 config 파일이 있으면 알림
    if ((Test-Path $dstConfigDir) -and (Get-ChildItem $dstConfigDir -ErrorAction SilentlyContinue)) {
        Print-Info "기존 config 파일이 있습니다. 덮어씁니다."
    }

    if (-not (Test-Path $dstConfigDir)) {
        New-Item -Path $dstConfigDir -ItemType Directory -Force | Out-Null
    }

    # 항상 최신으로 덮어쓰기
    Copy-Item -Path "$srcConfigDir\*" -Destination $dstConfigDir -Recurse -Force -ErrorAction SilentlyContinue

    # 복사된 파일 개수 계산
    $copied = (Get-ChildItem $dstConfigDir -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Print-Success ".github/config 폴더 복사 완료 ($copied 개 파일)"
}

# ===================================================================
# 이슈 템플릿 다운로드
# ===================================================================

function Copy-IssueTemplates {
    Print-Step "이슈/PR 템플릿 다운로드 중..."
    
    $issueTemplateDir = ".github\ISSUE_TEMPLATE"
    if (-not (Test-Path $issueTemplateDir)) {
        New-Item -Path $issueTemplateDir -ItemType Directory -Force | Out-Null
    }
    
    # 기존 템플릿이 있으면 알림
    if ((Test-Path $issueTemplateDir) -and (Get-ChildItem $issueTemplateDir -ErrorAction SilentlyContinue)) {
        Print-Info "기존 이슈 템플릿이 있습니다. 덮어씁니다."
    }
    
    # 템플릿 다운로드
    $srcIssueDir = Join-Path $TEMP_DIR ".github\ISSUE_TEMPLATE"
    if (Test-Path $srcIssueDir) {
        Copy-Item -Path "$srcIssueDir\*" -Destination $issueTemplateDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # PR 템플릿
    $srcPrTemplate = Join-Path $TEMP_DIR ".github\PULL_REQUEST_TEMPLATE.md"
    if (Test-Path $srcPrTemplate) {
        Copy-Item -Path $srcPrTemplate -Destination ".github\" -Force
        Print-Success "이슈/PR 템플릿 다운로드 완료"
    }
}

# ===================================================================
# Discussion 템플릿 다운로드
# ===================================================================

function Copy-DiscussionTemplates {
    Print-Step "GitHub Discussions 템플릿 다운로드 중..."
    
    $srcDiscussionDir = Join-Path $TEMP_DIR ".github\DISCUSSION_TEMPLATE"
    if (-not (Test-Path $srcDiscussionDir)) {
        Print-Info "DISCUSSION_TEMPLATE이 템플릿에 없습니다. 건너뜁니다."
        return
    }
    
    $discussionTemplateDir = ".github\DISCUSSION_TEMPLATE"
    if (-not (Test-Path $discussionTemplateDir)) {
        New-Item -Path $discussionTemplateDir -ItemType Directory -Force | Out-Null
    }
    
    # 기존 템플릿이 있으면 알림
    if ((Test-Path $discussionTemplateDir) -and (Get-ChildItem $discussionTemplateDir -ErrorAction SilentlyContinue)) {
        Print-Info "기존 Discussion 템플릿이 있습니다. 덮어씁니다."
    }
    
    # 템플릿 다운로드
    Copy-Item -Path "$srcDiscussionDir\*" -Destination $discussionTemplateDir -Recurse -Force -ErrorAction SilentlyContinue
    Print-Success "GitHub Discussions 템플릿 다운로드 완료"
}

# ===================================================================
# .coderabbit.yaml 다운로드
# ===================================================================

function Copy-CodeRabbitConfig {
    Print-Step "CodeRabbit 설정 파일 다운로드 여부 확인 중..."
    
    $srcCodeRabbit = Join-Path $TEMP_DIR ".coderabbit.yaml"
    if (-not (Test-Path $srcCodeRabbit)) {
        Print-Info ".coderabbit.yaml 파일이 템플릿에 없습니다. 건너뜁니다."
        return
    }
    
    # 기존 파일이 있으면 사용자 확인
    if (Test-Path ".coderabbit.yaml") {
        Print-Warning ".coderabbit.yaml이 이미 존재합니다"
        
        if (-not $Force) {
            Print-SeparatorLine
            Write-Host ""
            Write-Host ".coderabbit.yaml을 덮어쓰시겠습니까?"
            Write-Host "  Y/y - 예, 덮어쓰기"
            Write-Host "  N/n - 아니오, 건너뛰기 (기본)"
            Write-Host ""
            
            if (-not (Ask-YesNo "선택" "N")) {
                Print-Info ".coderabbit.yaml 다운로드 건너뜁니다"
                return
            }

            # PowerShell 5.1 호환성: 백업 경로를 변수로 분리
            $backupPath = ".coderabbit.yaml.bak"
            Copy-Item -Path ".coderabbit.yaml" -Destination $backupPath -Force
            Print-Info "기존 파일을 .coderabbit.yaml.bak으로 백업했습니다"
        } elseif ($Force) {
            # Force 모드에서는 백업하고 덮어쓰기
            # PowerShell 5.1 호환성: 백업 경로를 변수로 분리
            $backupPath = ".coderabbit.yaml.bak"
            Copy-Item -Path ".coderabbit.yaml" -Destination $backupPath -Force -ErrorAction SilentlyContinue
            Print-Info "강제 모드: 기존 파일 덮어씁니다"
        }
    }
    
    # 다운로드 실행
    Copy-Item -Path $srcCodeRabbit -Destination ".coderabbit.yaml" -Force
    Print-Success ".coderabbit.yaml 다운로드 완료"
    Print-Info "💡 CodeRabbit AI 리뷰가 활성화됩니다 (language: ko-KR)"
}

# ===================================================================
# .gitignore 생성 또는 업데이트
# ===================================================================

# gitignore 항목 정규화 함수 (중복 체크용)
# 예: "/.idea" -> ".idea", ".idea" -> ".idea", "./idea" -> ".idea"
# 예: "/.claude/settings.local.json" -> ".claude/settings.local.json"
function Normalize-GitIgnoreEntry {
    param(
        [string]$Entry
    )
    
    # 주석 제거
    $normalized = $Entry -replace '#.*$', ''
    # 앞뒤 공백 제거
    $normalized = $normalized.Trim()
    # 앞의 슬래시 제거 (루트 경로 표시 제거)
    $normalized = $normalized -replace '^/+', ''
    # "./" 제거 (현재 디렉토리 표시 제거, 하지만 ".idea" 같은 숨김 폴더는 보존)
    $normalized = $normalized -replace '^\./', ''
    # 뒤의 슬래시 제거 (디렉토리 표시 제거)
    $normalized = $normalized -replace '/+$', ''
    
    # 빈 문자열이면 원본 반환
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $Entry
    }
    
    return $normalized
}

# gitignore 파일에서 항목 존재 여부 확인 (정규화된 비교)
function Test-GitIgnoreEntryExists {
    param(
        [string]$TargetEntry,
        [string]$GitIgnoreFile
    )
    
    # 정규화된 타겟 항목
    $normalizedTarget = Normalize-GitIgnoreEntry -Entry $TargetEntry
    
    # gitignore 파일의 각 라인 확인
    $lines = Get-Content -Path $GitIgnoreFile -ErrorAction SilentlyContinue
    if ($null -eq $lines) {
        return $false
    }
    
    foreach ($line in $lines) {
        # 주석 라인 건너뛰기
        if ($line -match '^\s*#') {
            continue
        }
        
        # 빈 라인 건너뛰기
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        
        # 정규화된 라인과 비교
        $normalizedLine = Normalize-GitIgnoreEntry -Entry $line
        
        if ($normalizedLine -eq $normalizedTarget) {
            return $true  # 존재함
        }
    }
    
    return $false  # 존재하지 않음
}

function Ensure-GitIgnore {
    Print-Step ".gitignore 파일 확인 및 업데이트 중..."
    
    $requiredEntries = @(
        "/.idea",
        "/.claude/settings.local.json",
        "/.report",
        "/.issue"
    )
    
    # .gitignore가 없으면 생성
    if (-not (Test-Path ".gitignore")) {
        Print-Info ".gitignore 파일이 없습니다. 생성합니다."
        
        $gitignoreContent = @"
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json

# Implementation Reports (자동 생성)
/.report

# Issue Drafts (자동 생성)
/.issue
"@
        
        Set-Content -Path ".gitignore" -Value $gitignoreContent -Encoding UTF8
        
        Print-Success ".gitignore 파일 생성 완료"
        return
    }
    
    # 기존 파일이 있으면 누락된 항목만 추가
    Print-Info "기존 .gitignore 파일 발견. 필수 항목 확인 중..."
    
    $added = 0
    $entriesToAdd = @()
    
    foreach ($entry in $requiredEntries) {
        # 정규화된 비교로 중복 체크
        if (-not (Test-GitIgnoreEntryExists -TargetEntry $entry -GitIgnoreFile ".gitignore")) {
            $entriesToAdd += $entry
            $added++
        }
    }
    
    if ($added -eq 0) {
        Print-Info "필수 항목이 이미 모두 존재합니다. 건너뜁니다."
        return
    }
    
    # 항목 추가
    Print-Info "$added 개 항목 추가 중..."
    
    $appendContent = @"

# ====================================================================
# SUH-DEVOPS-TEMPLATE: Auto-added entries
# ====================================================================
"@
    
    foreach ($entry in $entriesToAdd) {
        $appendContent += "`n$entry"
        Print-Info "  ✓ $entry"
    }
    
    Add-Content -Path ".gitignore" -Value $appendContent -Encoding UTF8
    
    # .report 폴더가 이미 Git에 추적 중인 경우 제거
    if ($entriesToAdd -contains "/.report") {
        try {
            git ls-files --error-unmatch .report 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Print-Info ".report 폴더가 Git에 추적 중입니다. 추적 해제 중..."
                git rm -r --cached .report 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Print-Success ".report 폴더의 Git 추적이 해제되었습니다"
                }
            }
        } catch {
            # Git 명령 실패 시 무시 (Git 저장소가 아닐 수 있음)
        }
    }

    # .issue 폴더가 이미 Git에 추적 중인 경우 제거
    if ($entriesToAdd -contains "/.issue") {
        try {
            git ls-files --error-unmatch .issue 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Print-Info ".issue 폴더가 Git에 추적 중입니다. 추적 해제 중..."
                git rm -r --cached .issue 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Print-Success ".issue 폴더의 Git 추적이 해제되었습니다"
                }
            }
        } catch {
            # Git 명령 실패 시 무시 (Git 저장소가 아닐 수 있음)
        }
    }

    Print-Success ".gitignore 업데이트 완료 ($added 개 항목 추가)"
}

# ===================================================================
# .cursor 폴더 다운로드
# ===================================================================

function Copy-CursorFolder {
    Print-Step ".cursor 폴더 다운로드 여부 확인 중..."
    
    $srcCursorDir = Join-Path $TEMP_DIR ".cursor"
    if (-not (Test-Path $srcCursorDir)) {
        Print-Info ".cursor 폴더가 템플릿에 없습니다. 건너뜁니다."
        return
    }
    
    # 사용자 동의 확인
    if (-not $Force) {
        Print-SeparatorLine
        Write-Host ""
        Write-Host ".cursor 폴더를 다운로드하시겠습니까? (Cursor IDE 설정)"
        Write-Host "  Y/y - 예, 다운로드하기"
        Write-Host "  N/n - 아니오, 건너뛰기 (기본)"
        Write-Host ""
        
        if (-not (Ask-YesNo "선택" "N")) {
            Print-Info ".cursor 폴더 다운로드 건너뜁니다"
            return
        }
    }
    
    # 다운로드 실행
    if (-not (Test-Path ".cursor")) {
        New-Item -Path ".cursor" -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path "$srcCursorDir\*" -Destination ".cursor\" -Recurse -Force -ErrorAction SilentlyContinue
    Print-Success ".cursor 폴더 다운로드 완료"
}

# ===================================================================
# .claude 폴더 다운로드
# ===================================================================

function Copy-ClaudeFolder {
    Print-Step ".claude 폴더 다운로드 여부 확인 중..."

    $srcClaudeDir = Join-Path $TEMP_DIR ".claude"
    if (-not (Test-Path $srcClaudeDir)) {
        Print-Info ".claude 폴더가 템플릿에 없습니다. 건너뜁니다."
        return
    }

    # 사용자 동의 확인
    if (-not $Force) {
        Print-SeparatorLine
        Write-Host ""
        Write-Host ".claude 폴더를 다운로드하시겠습니까? (Claude Code 설정)"
        Write-Host "  Y/y - 예, 다운로드하기"
        Write-Host "  N/n - 아니오, 건너뛰기 (기본)"
        Write-Host ""

        if (-not (Ask-YesNo "선택" "N")) {
            Print-Info ".claude 폴더 다운로드 건너뜁니다"
            return
        }
    }

    # 다운로드 실행
    if (-not (Test-Path ".claude")) {
        New-Item -Path ".claude" -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path "$srcClaudeDir\*" -Destination ".claude\" -Recurse -Force -ErrorAction SilentlyContinue
    Print-Success ".claude 폴더 다운로드 완료"
}

# ===================================================================
# Custom Command 설치 (백업 없이 덮어쓰기)
# ===================================================================

function Install-CustomCommand {
    param(
        [string]$FolderName,
        [string]$DisplayName
    )

    $src = Join-Path $TEMP_DIR $FolderName
    if (-not (Test-Path $src)) {
        Print-Warning "$DisplayName 폴더가 템플릿에 없습니다"
        return $false
    }

    Print-Step "$DisplayName 설정 설치 중..."

    # 기존 폴더가 있으면 덮어쓰기 알림
    if (Test-Path $FolderName) {
        Print-Info "기존 $FolderName 폴더에 덮어쓰기"
    } else {
        New-Item -Path $FolderName -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path "$src\*" -Destination "$FolderName\" -Recurse -Force -ErrorAction SilentlyContinue
    Print-Success "$DisplayName 설정 설치 완료"
    return $true
}

function Copy-CustomCommands {
    param(
        [string]$Target  # "cursor", "claude", "all"
    )

    # 경고 메시지
    Print-Warning "⚠️  기존 설정 파일이 덮어쓰기됩니다! (기존에 추가한 파일은 보존됨)"
    Write-Host ""

    if (-not $Force) {
        Write-Host "계속 진행하시겠습니까?"
        Write-Host "  Y/y - 예, 계속 진행"
        Write-Host "  N/n - 아니오, 취소 (기본)"
        Write-Host ""

        if (-not (Ask-YesNo "선택" "N")) {
            Print-Info "취소되었습니다"
            return
        }
    }

    # 템플릿 다운로드 (필요시)
    if (-not (Test-Path $TEMP_DIR)) {
        Download-Template
    }

    $installed = 0

    switch ($Target) {
        "cursor" {
            if (Install-CustomCommand ".cursor" "Cursor IDE") { $installed++ }
        }
        "claude" {
            if (Install-CustomCommand ".claude" "Claude Code") { $installed++ }
        }
        "all" {
            if (Install-CustomCommand ".cursor" "Cursor IDE") { $installed++ }
            if (Install-CustomCommand ".claude" "Claude Code") { $installed++ }
        }
    }

    # 임시 폴더 정리
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }

    if ($installed -gt 0) {
        Write-Host ""
        Print-Success "Custom Command 설치 완료 ($installed 개 폴더)"
    }
}

function Show-CustomCommandMenu {
    Print-QuestionHeader "📦" "어떤 Custom Command를 설치하시겠습니까?"

    Write-Host "  1) Cursor IDE 설정 (.cursor 폴더)"
    Write-Host "  2) Claude Code 설정 (.claude 폴더)"
    Write-Host "  3) 모두 설치"
    Write-Host "  4) 취소"
    Write-Host ""

    while ($true) {
        $choice = Read-SingleKey "선택 (1-4) "

        if ($choice -match '^[1-4]$') {
            switch ($choice) {
                "1" { Copy-CustomCommands -Target "cursor"; return }
                "2" { Copy-CustomCommands -Target "claude"; return }
                "3" { Copy-CustomCommands -Target "all"; return }
                "4" { Print-Info "취소되었습니다"; return }
            }
        } else {
            Print-Error "잘못된 입력입니다. 1-4 사이의 숫자를 입력해주세요."
            Write-Host ""
        }
    }
}

# ===================================================================
# SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 다운로드
# ===================================================================

function Copy-SetupGuide {
    Print-Step "템플릿 설정 가이드 다운로드 중..."
    
    $srcGuide = Join-Path $TEMP_DIR "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    if (-not (Test-Path $srcGuide)) {
        Print-Info "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 파일이 템플릿에 없습니다. 건너뜁니다."
        return
    }
    
    # 항상 최신 버전으로 다운로드
    Copy-Item -Path $srcGuide -Destination "." -Force
    Print-Success "템플릿 설정 가이드 다운로드 완료 (최신 버전)"
    Print-Info "📖 템플릿 사용법을 SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md에서 확인하세요"
}

# ===================================================================
# 프로젝트 타입별 유틸리티 모듈 다운로드
# ===================================================================
# 프로젝트 타입에 따라 추가 유틸리티 모듈(마법사 등)을 다운로드합니다.
# 현재 지원: flutter (ios-testflight-setup-wizard, android-playstore-setup-wizard)
# 확장 가능: 다른 프로젝트 타입에도 util 모듈 추가 시 자동 지원
# ===================================================================

function Show-UtilModuleDescription {
    param([string]$ProjectType)

    switch ($ProjectType) {
        "flutter" {
            Print-SeparatorLine
            Write-Host ""
            Write-Host "📦 Flutter 추가 유틸리티 모듈:"
            Write-Host ""
            Write-Host "  🧙 ios-testflight-setup-wizard"
            Write-Host "     iOS TestFlight 배포에 필요한 설정 파일들을"
            Write-Host "     웹 브라우저에서 쉽게 생성할 수 있는 마법사입니다."
            Write-Host "     → ExportOptions.plist, Fastfile 등 자동 생성"
            Write-Host ""
            Write-Host "  🧙 android-playstore-setup-wizard"
            Write-Host "     Android Play Store 배포에 필요한 설정 파일들을"
            Write-Host "     웹 브라우저에서 쉽게 생성할 수 있는 마법사입니다."
            Write-Host "     → Fastfile, build.gradle 서명 설정 등 자동 생성"
            Write-Host ""
        }
        # 다른 프로젝트 타입 추가 시 여기에 case 추가
        default {
            # 알 수 없는 타입은 일반 메시지
            Print-SeparatorLine
            Write-Host ""
            Write-Host "📦 $ProjectType 추가 유틸리티 모듈이 있습니다."
            Write-Host ""
        }
    }
}

function Show-UtilUsageGuide {
    param([string]$ProjectType)

    switch ($ProjectType) {
        "flutter" {
            Write-Host ""
            Print-Info "📖 Flutter 마법사 사용법:"
            Write-Host "   iOS TestFlight:"
            Write-Host "     1. 브라우저에서 열기:"
            Write-Host "        .github\util\flutter\ios-testflight-setup-wizard\index.html"
            Write-Host "     2. 필요한 정보 입력 후 파일 생성"
            Write-Host "     3. 생성된 파일을 ios\ 폴더에 복사"
            Write-Host ""
            Write-Host "   Android Play Store:"
            Write-Host "     1. 브라우저에서 열기:"
            Write-Host "        .github\util\flutter\android-playstore-setup-wizard\index.html"
            Write-Host "     2. 필요한 정보 입력 후 파일 생성"
            Write-Host "     3. 생성된 파일을 android\ 폴더에 복사"
            Write-Host ""
        }
        default {
            Write-Host ""
            Print-Info "📖 util 모듈 사용법:"
            Write-Host "   .github\util\$ProjectType\ 폴더 내 README.md를 참고하세요."
            Write-Host ""
        }
    }
}

function Copy-UtilModules {
    param([string]$ProjectType)

    $utilSrc = Join-Path $TEMP_DIR ".github\util\$ProjectType"
    $utilDst = ".github\util\$ProjectType"

    # util 모듈 존재 확인
    if (-not (Test-Path $utilSrc)) {
        # util 모듈이 없으면 조용히 건너뜀 (모든 타입에 모듈이 있는 건 아님)
        return
    }

    Print-Step "$ProjectType 추가 유틸리티 모듈 확인 중..."

    # 모듈 설명 표시
    Show-UtilModuleDescription $ProjectType

    # 사용자 확인 (force 모드가 아닐 때만)
    if (-not $Force) {
        Write-Host "이 유틸리티 모듈을 다운로드하시겠습니까?"
        Write-Host "  Y/y - 예, 다운로드하기"
        Write-Host "  N/n - 아니오, 건너뛰기 (기본)"
        Write-Host ""

        if (-not (Ask-YesNo "선택" "N")) {
            Print-Info "util 모듈 다운로드 건너뜁니다"
            return
        }
    } else {
        # Force 모드에서는 자동으로 다운로드
        Print-Info "강제 모드: util 모듈 자동 다운로드"
    }

    # 다운로드 실행
    if (-not (Test-Path $utilDst)) {
        New-Item -Path $utilDst -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path "$utilSrc\*" -Destination $utilDst -Recurse -Force -ErrorAction SilentlyContinue

    # 복사된 모듈 개수 계산
    $moduleCount = 0
    $moduleDirs = Get-ChildItem -Path $utilDst -Directory -ErrorAction SilentlyContinue
    if ($moduleDirs) {
        $moduleCount = $moduleDirs.Count
    }

    Print-Success "util 모듈 다운로드 완료 ($moduleCount 개 모듈)"

    # 복사된 모듈 목록 표시
    foreach ($dir in $moduleDirs) {
        Write-Host "  ✓ $($dir.Name)"
    }

    # 사용 가이드 표시
    Show-UtilUsageGuide $ProjectType

    # 복사된 모듈 수를 전역 변수로 저장 (최종 요약에서 사용)
    $script:UtilModulesCopied = $moduleCount
}

# ===================================================================
# 대화형 모드
# ===================================================================

function Start-InteractiveMode {
    # Interactive 모드 플래그 설정
    $script:IsInteractiveMode = $true
    
    # 템플릿 버전 가져오기
    $templateVersion = $DEFAULT_VERSION
    try {
        $versionUrl = "$TEMPLATE_RAW_URL/$VERSION_FILE"
        $versionContent = (Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -TimeoutSec 3).Content
        if ($versionContent -match 'version:\s*[''"]?([^''"]+)') {
            $templateVersion = $matches[1]
        }
    } catch {
        # 버전 가져오기 실패 시 기본값 사용
    }
    
    Print-Banner $templateVersion "Interactive (대화형 모드)"
    
    # 프로젝트 감지 및 확인
    Detect-AndConfirmProject

    # 템플릿 다운로드 (Synology 폴더 확인을 위해 미리 다운로드)
    Download-Template

    # Synology 옵션 질문 (해당 타입에 synology 폴더 있을 때만)
    $typeDir = Join-Path $TEMP_DIR "$WORKFLOWS_DIR\$PROJECT_TYPES_DIR\$($script:ProjectType)"
    Ask-SynologyOption $typeDir

    Print-QuestionHeader "🚀" "어떤 기능을 통합하시겠습니까?"

    Write-Host "  1) 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)"
    Write-Host "  2) 버전 관리 시스템만"
    Write-Host "  3) GitHub Actions 워크플로우만"
    Write-Host "  4) 이슈/PR 템플릿만"
    Write-Host "  5) Custom Command만 (Cursor/Claude 설정)"
    Write-Host "  6) 취소"
    Write-Host ""

    # 입력 검증 루프
    while ($true) {
        $choice = Read-SingleKey "선택 (1-6) "

        if ($choice -match '^[1-6]$') {
            switch ($choice) {
                "1" { $script:Mode = "full"; break }
                "2" { $script:Mode = "version"; break }
                "3" { $script:Mode = "workflows"; break }
                "4" { $script:Mode = "issues"; break }
                "5" { $script:Mode = "commands"; break }
                "6" {
                    Print-Info "취소되었습니다"
                    exit 0
                }
            }
            break
        } else {
            Print-Error "잘못된 입력입니다. 1-6 사이의 숫자를 입력해주세요."
            Write-Host ""
        }
    }
}

# ===================================================================
# 통합 실행
# ===================================================================

function Start-Integration {
    # Breaking Changes 확인 (업데이트 시)
    $currentTemplateVersion = Get-CurrentTemplateVersion
    if ($currentTemplateVersion -ne "unknown") {
        Test-BreakingChanges -CurrentVersion $currentTemplateVersion -NewVersion $script:DefaultVersion | Out-Null
    }

    # CLI 모드에서만 자동 감지 및 확인
    if (-not $script:IsInteractiveMode) {
        if ([string]::IsNullOrWhiteSpace($script:ProjectType)) {
            $script:ProjectType = Detect-ProjectType
        }
        
        if ([string]::IsNullOrWhiteSpace($script:ProjectVersion)) {
            $script:ProjectVersion = Detect-Version
        }
        
        if ([string]::IsNullOrWhiteSpace($script:DetectedBranch)) {
            $script:DetectedBranch = Detect-DefaultBranch
        }
        
        # CLI 모드에서만 통합 정보 표시
        Print-QuestionHeader "🪐" "통합 정보"
        
        Write-Host "🔭 프로젝트 타입  : $($script:ProjectType)"
        Write-Host "🌙 초기 버전     : v$($script:ProjectVersion)"
        Write-Host "🌿 Default 브랜치 : $($script:DetectedBranch)"
        Write-Host "💫 통합 모드     : $Mode"
        Print-SeparatorLine
        Write-Host ""
        
        # CLI 모드에서만 확인 질문 (force 모드가 아닐 때만)
        if (-not $Force) {
            Write-Host "이 정보로 통합을 진행하시겠습니까?"
            Write-Host "  Y/y - 예, 계속 진행"
            Write-Host "  N/n - 아니오, 취소"
            Write-Host ""
            
            if (-not (Ask-YesNo "선택" "Y")) {
                Print-Info "취소되었습니다"
                exit 0
            }
        }
    }
    
    Write-Host ""

    # 1. 템플릿 다운로드 (CLI 모드에서만, interactive 모드는 이미 다운로드됨)
    if (-not $script:IsInteractiveMode) {
        Download-Template

        # CLI 모드에서도 Synology 질문 (워크플로우 모드에서만)
        if ($Mode -eq "full" -or $Mode -eq "workflows") {
            $typeDir = Join-Path $TEMP_DIR "$WORKFLOWS_DIR\$PROJECT_TYPES_DIR\$($script:ProjectType)"
            Ask-SynologyOption $typeDir
        }
    }

    # 2. 모드별 통합
    switch ($Mode) {
        "full" {
            Create-VersionYml $script:ProjectVersion $script:ProjectType $script:DetectedBranch
            Add-VersionSectionToReadme $script:ProjectVersion
            Copy-Workflows
            Copy-Scripts
            Copy-ConfigFolder
            Copy-IssueTemplates
            Copy-DiscussionTemplates
            Copy-CodeRabbitConfig
            Ensure-GitIgnore
            Copy-CursorFolder
            Copy-ClaudeFolder
            Copy-SetupGuide
            Copy-UtilModules $script:ProjectType
        }
        "version" {
            Create-VersionYml $script:ProjectVersion $script:ProjectType $script:DetectedBranch
            Add-VersionSectionToReadme $script:ProjectVersion
            Copy-Scripts
            Copy-ConfigFolder
            Ensure-GitIgnore
            Copy-SetupGuide
        }
        "workflows" {
            Copy-Workflows
            Copy-Scripts
            Copy-ConfigFolder
            Copy-SetupGuide
            Copy-UtilModules $script:ProjectType
        }
        "issues" {
            Copy-IssueTemplates
            Copy-DiscussionTemplates
        }
        "commands" {
            if ($Target -ne "") {
                Copy-CustomCommands -Target $Target
            } else {
                Show-CustomCommandMenu
            }
            return  # commands 모드는 자체적으로 정리하고 종료
        }
    }

    # 2.1 템플릿 옵션 저장 (Synology 설정 등)
    if ($Mode -eq "full" -or $Mode -eq "workflows") {
        # IncludeSynology가 설정되지 않은 경우 기본값 false 사용
        # (basic 타입 등 Synology 폴더가 없는 경우를 위한 처리)
        if ($null -eq $script:IncludeSynology) {
            $script:IncludeSynology = $false
        }
        # 다운로드한 템플릿의 실제 버전 전달 (TemplateVersion 사용)
        Save-TemplateOptions $script:TemplateVersion
    }

    # 3. 임시 파일 정리
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }

    # 완료 메시지
    Show-Summary
}

# ===================================================================
# 완료 요약
# ===================================================================

function Show-Summary {
    Write-Host ""
    Print-SeparatorLine
    Write-Host ""
    Write-Host "✨ SUH-DEVOPS-TEMPLATE Setup Complete!"
    Write-Host ""
    Print-SeparatorLine
    Write-Host ""
    Write-Host "통합된 기능:"
    
    switch ($Mode) {
        "full" {
            Write-Host "  ✅ 버전 관리 시스템 (version.yml)"
            Write-Host "  ✅ README.md 자동 버전 업데이트"
            Write-Host "  ✅ GitHub Actions 워크플로우"
            Write-Host "  ✅ 이슈/PR/Discussion 템플릿"
            Write-Host "  ✅ CodeRabbit AI 리뷰 설정"
            Write-Host "  ✅ .gitignore 필수 항목"
            Write-Host "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)"
        }
        "version" {
            Write-Host "  ✅ 버전 관리 시스템 (version.yml)"
            Write-Host "  ✅ README.md 자동 버전 업데이트"
            Write-Host "  ✅ .gitignore 필수 항목"
            Write-Host "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)"
        }
        "workflows" {
            Write-Host "  ✅ GitHub Actions 워크플로우"
            Write-Host "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)"
        }
        "issues" {
            Write-Host "  ✅ 이슈/PR/Discussion 템플릿"
        }
    }
    
    Write-Host ""
    Write-Host "추가된 파일:"
    Write-Host "  📄 version.yml (버전: $($script:ProjectVersion), 타입: $($script:ProjectType))"
    Write-Host "  📝 README.md (버전 섹션 추가)"
    Write-Host ""
    Write-Host "추가된 워크플로우:"
    Write-Host "  📦 새로 설치됨 ($($script:WorkflowsCopied)개)"
    Write-Host ""
    Write-Host "  🔧 .github/scripts/"
    Write-Host "     ├─ version_manager.sh"
    Write-Host "     └─ changelog_manager.py"
    Write-Host ""

    # util 모듈 정보 표시
    if ($script:UtilModulesCopied -gt 0) {
        Write-Host "  📦 유틸리티 모듈:"
        Write-Host "     ✅ $($script:UtilModulesCopied)개 모듈 복사됨 (.github/util/$($script:ProjectType)/)"
        Write-Host ""

        # Flutter인 경우 상세 안내
        if ($script:ProjectType -eq "flutter") {
            Write-Host "  💡 Flutter 유틸리티 모듈 사용법:"
            Write-Host "     • iOS TestFlight 마법사: .github/util/flutter/ios-testflight-setup-wizard/"
            Write-Host "       → index.html을 브라우저에서 열어 설정 파일 생성"
            Write-Host "     • Android Play Store 마법사: .github/util/flutter/android-playstore-setup-wizard/"
            Write-Host "       → init.ps1 또는 init.sh 실행하여 설정 시작"
            Write-Host ""
        }
    }

    # 프로젝트 타입별 안내
    if ($script:ProjectType -eq "spring") {
        Write-Host "  💡 Spring 프로젝트 추가 설정:"
        Write-Host "     • build.gradle의 버전 정보가 자동 동기화됩니다"
        Write-Host "     • CI/CD 워크플로우에서 GitHub Secrets 설정이 필요합니다"
        Write-Host "     • 자세한 설정 방법: .github/workflows/project-types/spring/README.md"
        Write-Host ""
    }
    
    Write-Host "  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    Write-Host "  📚 워크플로우 가이드: .github/workflows/project-types/README.md"
    Write-Host ""
    
    # 필수 3가지 작업 안내
    Print-SeparatorLine
    Write-Host ""
    Write-ColorOutput "⚠️  다음 3가지 작업을 완료해주세요:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1️⃣  GitHub Personal Access Token 설정"
    Write-Host "     → Repository Settings > Secrets > Actions"
    Write-Host "     → Secret Name: _GITHUB_PAT_TOKEN"
    Write-Host "     → Scopes: repo, workflow"
    Write-Host ""
    Write-Host "  2️⃣  deploy 브랜치 생성"
    Write-Host "     → git checkout -b deploy && git push -u origin deploy"
    Write-Host ""
    Write-Host "  3️⃣  CodeRabbit 활성화"
    Write-Host "     → https://coderabbit.ai 방문하여 저장소 활성화"
    Write-Host ""
    Print-SeparatorLine
    Write-Host ""
    Write-ColorOutput "📖 자세한 설정 방법은 다음 파일을 참고하세요:" -ForegroundColor Cyan
    Write-Host "   → SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    Write-Host ""
}

# ===================================================================
# 메인 실행
# ===================================================================

function Main {
    # 도움말 표시
    if ($Help) {
        Show-Help
        exit 0
    }
    
    # 파라미터 검증
    $validModes = @("interactive", "full", "version", "workflows", "issues", "commands")
    if ($Mode -ne "" -and $Mode -notin $validModes) {
        Print-Error "잘못된 모드: $Mode"
        Write-Host "지원되는 모드: $($validModes -join ', ')"
        Write-Host ""
        Write-Host "도움말: .\template_integrator.ps1 -Help"
        exit 1
    }
    
    if ($Type -ne "" -and $Type -notin $script:ValidTypes) {
        Print-Error "잘못된 프로젝트 타입: $Type"
        Write-Host "지원되는 타입: $($script:ValidTypes -join ', ')"
        Write-Host ""
        Write-Host "도움말: .\template_integrator.ps1 -Help"
        exit 1
    }
    
    # Git 저장소 확인 (경고만 표시)
    try {
        git rev-parse --git-dir 2>&1 | Out-Null
    } catch {
        Print-Warning "Git 저장소가 아닙니다. 일부 기능이 제한될 수 있습니다."
        Write-Host ""
    }
    
    # 대화형 모드
    if ($Mode -eq "interactive") {
        Start-InteractiveMode
    }
    
    # 통합 실행
    Start-Integration
}

# 스크립트 실행
Main

