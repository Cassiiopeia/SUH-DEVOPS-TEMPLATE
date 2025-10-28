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
# iex (iwr -Uri "https://raw.githubusercontent.com/.../template_integrator.ps1" -UseBasicParsing).Content
#
# 방법 3: 원격 실행 - 자동화 (CI/CD)
# iex (iwr -Uri "URL" -UseBasicParsing).Content -mode full -force
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
    [switch]$Help
)

# 에러 발생 시 스크립트 중단
$ErrorActionPreference = "Stop"

# UTF-8 인코딩 설정 (한글 지원)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
$script:ValidTypes = @("spring", "flutter", "react", "react-native", "react-native-expo", "node", "python", "basic")

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
  interactive - 대화형 선택 (기본값, 추천)

옵션:
  -Mode <MODE>          통합 모드 선택
  -Version <VERSION>    초기 버전 (미지정 시 자동 감지)
  -Type <TYPE>          프로젝트 타입 (미지정 시 자동 감지)
  -NoBackup             백업 생성 안 함
  -Force                확인 없이 즉시 실행
  -Help                 이 도움말 표시

지원 프로젝트 타입:
  • node / react / react-native - Node.js 기반 프로젝트
  • spring            - Spring Boot 백엔드
  • flutter           - Flutter 모바일 앱
  • python            - Python 프로젝트
  • basic             - 기타 프로젝트

자동 감지 기능:
  • package.json 발견 → Node.js 프로젝트로 감지
  • @react-native 의존성 → React Native
  • build.gradle → Spring Boot
  • pubspec.yaml → Flutter
  • pyproject.toml → Python

사용 예시:
  # 로컬 실행 - 대화형 모드 (추천)
  .\template_integrator.ps1

  # 원격 실행 - 대화형 모드
  iex (iwr -Uri "https://raw.../template_integrator.ps1" -UseBasicParsing).Content

  # 버전 관리만 추가
  .\template_integrator.ps1 -Mode version

  # 전체 통합 (자동 감지)
  .\template_integrator.ps1 -Mode full

  # 수동 설정
  .\template_integrator.ps1 -Mode full -Version "1.0.0" -Type node

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
    
    # Node.js / React / React Native
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
        
        # React 체크
        if ($packageJson -match '"react"') {
            Print-Info "감지됨: React"
            return "react"
        }
        
        # 기본 Node.js
        Print-Info "감지됨: Node.js"
        return "node"
    }
    
    # Spring Boot
    if ((Test-Path "build.gradle") -or (Test-Path "build.gradle.kts") -or (Test-Path "pom.xml")) {
        Print-Info "감지됨: Spring Boot"
        return "spring"
    }
    
    # Flutter
    if (Test-Path "pubspec.yaml") {
        Print-Info "감지됨: Flutter"
        return "flutter"
    }
    
    # Python
    if ((Test-Path "pyproject.toml") -or (Test-Path "setup.py") -or (Test-Path "requirements.txt")) {
        Print-Info "감지됨: Python"
        return "python"
    }
    
    # 감지 실패
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
    Write-Host "  3) react             - React 웹 앱"
    Write-Host "  4) react-native      - React Native 모바일 앱"
    Write-Host "  5) react-native-expo - React Native Expo 앱"
    Write-Host "  6) node              - Node.js 프로젝트"
    Write-Host "  7) python            - Python 프로젝트"
    Write-Host "  8) basic             - 기타 프로젝트"
    Write-Host ""
    
    while ($true) {
        $choice = Read-SingleKey "선택 (1-8) "
        
        if ($choice -match '^[1-8]$') {
            switch ($choice) {
                "1" { return "spring" }
                "2" { return "flutter" }
                "3" { return "react" }
                "4" { return "react-native" }
                "5" { return "react-native-expo" }
                "6" { return "node" }
                "7" { return "python" }
                "8" { return "basic" }
            }
        } else {
            Print-Error "잘못된 입력입니다. 1-8 사이의 숫자를 입력해주세요."
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
        "ARCHITECTURE.md",
        "CONTRIBUTING.md"
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
    
    # 이미 버전 섹션이 있는지 확인
    $readmeContent = Get-Content "README.md" -Raw
    if ($readmeContent -match "<!-- AUTO-VERSION-SECTION") {
        Print-Info "이미 버전 관리 섹션이 있습니다. 건너뜁니다."
        return
    }
    
    # README.md 끝에 버전 섹션 추가
    $versionSection = @"

---

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
<!-- 이 섹션은 .github/workflows/PROJECT-README-VERSION-UPDATE.yaml에 의해 자동으로 업데이트됩니다 -->
## 최신 버전 : v$Version

[전체 버전 기록 보기](CHANGELOG.md)
<!-- END-AUTO-VERSION-SECTION -->
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
    
    Print-Step "version.yml 생성 중..."
    
    if (Test-Path "version.yml") {
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
# - react/node: package.json ("version": "x.y.z")
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
version_code: 1  # app build number
project_type: "$Type"  # spring, flutter, react, react-native, react-native-expo, node, python, basic
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
# 워크플로우 다운로드
# ===================================================================

function Copy-Workflows {
    Print-Step "프로젝트 타입별 워크플로우 다운로드 중..."
    Print-Info "프로젝트 타입: $($script:ProjectType)"
    
    if (-not (Test-Path $WORKFLOWS_DIR)) {
        New-Item -Path $WORKFLOWS_DIR -ItemType Directory -Force | Out-Null
    }
    
    $copied = 0
    $projectTypesDir = Join-Path $TEMP_DIR "$WORKFLOWS_DIR\$PROJECT_TYPES_DIR"
    
    # project-types 폴더 존재 확인
    if (-not (Test-Path $projectTypesDir)) {
        Print-Error "템플릿 저장소의 폴더 구조가 올바르지 않습니다."
        Print-Error "project-types 폴더를 찾을 수 없습니다."
        exit 1
    }
    
    # 1. Common 워크플로우 다운로드 (필수)
    Print-Info "공통 워크플로우 다운로드 중..."
    $commonDir = Join-Path $projectTypesDir "common"
    if (Test-Path $commonDir) {
        $workflows = Get-ChildItem -Path $commonDir -Filter "*.yaml" -ErrorAction SilentlyContinue
        $workflows += Get-ChildItem -Path $commonDir -Filter "*.yml" -ErrorAction SilentlyContinue
        
        foreach ($workflow in $workflows) {
            $filename = $workflow.Name
            $destPath = Join-Path $WORKFLOWS_DIR $filename
            
            if (Test-Path $destPath) {
                Print-Warning "$filename 이미 존재 → ${filename}.bak으로 백업"
                Move-Item -Path $destPath -Destination "$destPath.bak" -Force
            }
            
            Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
            Write-Host "  ✓ $filename"
            $copied++
        }
    } else {
        Print-Warning "common 폴더를 찾을 수 없습니다. 건너뜁니다."
    }
    
    # 2. 타입별 워크플로우 다운로드
    $typeDir = Join-Path $projectTypesDir $script:ProjectType
    if (Test-Path $typeDir) {
        Print-Info "$($script:ProjectType) 전용 워크플로우 다운로드 중..."
        
        $workflows = Get-ChildItem -Path $typeDir -Filter "*.yaml" -ErrorAction SilentlyContinue
        $workflows += Get-ChildItem -Path $typeDir -Filter "*.yml" -ErrorAction SilentlyContinue
        
        foreach ($workflow in $workflows) {
            $filename = $workflow.Name
            $destPath = Join-Path $WORKFLOWS_DIR $filename
            
            if (Test-Path $destPath) {
                Print-Warning "$filename 이미 존재 → ${filename}.bak으로 백업"
                Move-Item -Path $destPath -Destination "$destPath.bak" -Force
            }
            
            Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
            Write-Host "  ✓ $filename"
            $copied++
        }
    } else {
        Print-Info "$($script:ProjectType) 타입의 전용 워크플로우가 없습니다. (공통 워크플로우만 사용)"
    }
    
    Print-Success "$copied 개 워크플로우 다운로드 완료 (타입: $($script:ProjectType))"
    
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
            
            # 백업
            Copy-Item -Path ".coderabbit.yaml" -Destination ".coderabbit.yaml.bak" -Force
            Print-Info "기존 파일을 .coderabbit.yaml.bak으로 백업했습니다"
        } elseif ($Force) {
            # Force 모드에서는 백업하고 덮어쓰기
            Copy-Item -Path ".coderabbit.yaml" -Destination ".coderabbit.yaml.bak" -Force -ErrorAction SilentlyContinue
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

function Ensure-GitIgnore {
    Print-Step ".gitignore 파일 확인 및 업데이트 중..."
    
    $requiredEntries = @(
        "/.idea",
        "/.claude/settings.local.json"
    )
    
    # .gitignore가 없으면 생성
    if (-not (Test-Path ".gitignore")) {
        Print-Info ".gitignore 파일이 없습니다. 생성합니다."
        
        $gitignoreContent = @"
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json
"@
        
        Set-Content -Path ".gitignore" -Value $gitignoreContent -Encoding UTF8
        
        Print-Success ".gitignore 파일 생성 완료"
        return
    }
    
    # 기존 파일이 있으면 누락된 항목만 추가
    Print-Info "기존 .gitignore 파일 발견. 필수 항목 확인 중..."
    
    $gitignoreContent = Get-Content ".gitignore" -Raw -ErrorAction SilentlyContinue
    $added = 0
    $entriesToAdd = @()
    
    foreach ($entry in $requiredEntries) {
        # 정확한 매칭 확인
        if ($gitignoreContent -notmatch [regex]::Escape($entry)) {
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
# agent-prompts 폴더 다운로드
# ===================================================================

function Copy-AgentPrompts {
    Print-Step "agent-prompts 폴더 다운로드 여부 확인 중..."
    
    $srcAgentDir = Join-Path $TEMP_DIR "agent-prompts"
    if (-not (Test-Path $srcAgentDir)) {
        Print-Info "agent-prompts 폴더가 템플릿에 없습니다. 건너뜁니다."
        return
    }
    
    # 사용자 동의 확인
    if (-not $Force) {
        Print-SeparatorLine
        Write-Host ""
        Write-Host "agent-prompts 폴더를 다운로드하시겠습니까? (AI 개발 가이드라인)"
        Write-Host "  Y/y - 예, 다운로드하기"
        Write-Host "  N/n - 아니오, 건너뛰기 (기본)"
        Write-Host ""
        
        if (-not (Ask-YesNo "선택" "N")) {
            Print-Info "agent-prompts 폴더 다운로드 건너뜁니다"
            return
        }
    }
    
    # 다운로드 실행
    if (-not (Test-Path "agent-prompts")) {
        New-Item -Path "agent-prompts" -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path "$srcAgentDir\*" -Destination "agent-prompts\" -Recurse -Force -ErrorAction SilentlyContinue
    Print-Success "agent-prompts 폴더 다운로드 완료"
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
    
    Print-QuestionHeader "🚀" "어떤 기능을 통합하시겠습니까?"
    
    Write-Host "  1) 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)"
    Write-Host "  2) 버전 관리 시스템만"
    Write-Host "  3) GitHub Actions 워크플로우만"
    Write-Host "  4) 이슈/PR 템플릿만"
    Write-Host "  5) 취소"
    Write-Host ""
    
    # 입력 검증 루프
    while ($true) {
        $choice = Read-SingleKey "선택 (1-5) "
        
        if ($choice -match '^[1-5]$') {
            switch ($choice) {
                "1" { $script:Mode = "full"; break }
                "2" { $script:Mode = "version"; break }
                "3" { $script:Mode = "workflows"; break }
                "4" { $script:Mode = "issues"; break }
                "5" { 
                    Print-Info "취소되었습니다"
                    exit 0
                }
            }
            break
        } else {
            Print-Error "잘못된 입력입니다. 1-5 사이의 숫자를 입력해주세요."
            Write-Host ""
        }
    }
}

# ===================================================================
# 통합 실행
# ===================================================================

function Start-Integration {
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
    
    # 1. 템플릿 다운로드
    Download-Template
    
    # 2. 모드별 통합
    switch ($Mode) {
        "full" {
            Create-VersionYml $script:ProjectVersion $script:ProjectType $script:DetectedBranch
            Add-VersionSectionToReadme $script:ProjectVersion
            Copy-Workflows
            Copy-Scripts
            Copy-IssueTemplates
            Copy-DiscussionTemplates
            Copy-CodeRabbitConfig
            Ensure-GitIgnore
            Copy-CursorFolder
            Copy-AgentPrompts
            Copy-SetupGuide
        }
        "version" {
            Create-VersionYml $script:ProjectVersion $script:ProjectType $script:DetectedBranch
            Add-VersionSectionToReadme $script:ProjectVersion
            Copy-Scripts
            Ensure-GitIgnore
            Copy-SetupGuide
        }
        "workflows" {
            Copy-Workflows
            Copy-Scripts
            Copy-SetupGuide
        }
        "issues" {
            Copy-IssueTemplates
            Copy-DiscussionTemplates
        }
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
    $validModes = @("interactive", "full", "version", "workflows", "issues")
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

