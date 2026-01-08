# ===================================================================
# Flutter 환경 검사 + Application ID 자동 감지 스크립트 (PowerShell)
# ===================================================================
# 1. Android SDK 환경 검사 (없으면 자동 설정)
# 2. keytool 명령어 확인
# 3. build.gradle.kts에서 applicationId 추출
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File detect-application-id.ps1 PROJECT_PATH
#
# 출력:
#   JSON 형식으로 결과 출력
#   예: {"applicationId": "com.example.app", "env": "ok", "keytool": "ok"}
# ===================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

$envStatus = "ok"
$keytoolStatus = "ok"
$envMessage = ""
$gradleType = ""

# 프로젝트 경로 확인
if (-not (Test-Path $ProjectPath)) {
    $json = @{ error = "프로젝트 경로가 존재하지 않습니다"; env = "error" } | ConvertTo-Json -Compress
    Write-Output $json
    exit 1
}

# ===================================================================
# 1. Android SDK 환경 검사 및 자동 설정
# ===================================================================

$androidHome = $env:ANDROID_HOME

if (-not $androidHome -or -not (Test-Path $androidHome)) {
    # 기본 경로에서 Android SDK 찾기
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Android\Sdk",
        "$env:USERPROFILE\AppData\Local\Android\Sdk",
        "C:\Android\Sdk"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $androidHome = $path
            break
        }
    }
}

if ($androidHome -and (Test-Path $androidHome)) {
    # 환경 변수 설정 (현재 세션)
    $env:ANDROID_HOME = $androidHome

    # 시스템 환경 변수에 추가 (영구적) - 없는 경우만
    $currentAndroidHome = [Environment]::GetEnvironmentVariable("ANDROID_HOME", "User")
    if (-not $currentAndroidHome) {
        [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "User")
        $envMessage = "ANDROID_HOME을 사용자 환경 변수에 추가했습니다. 터미널을 다시 열어주세요."
    }
} else {
    $envStatus = "warning"
    $envMessage = "Android SDK를 찾을 수 없습니다. Android Studio에서 SDK Manager를 열어 설치하세요."
}

# ===================================================================
# 2. keytool 명령어 확인
# ===================================================================

try {
    $keytoolTest = Get-Command keytool -ErrorAction Stop
} catch {
    # Java 확인
    try {
        $javaTest = Get-Command java -ErrorAction Stop
        $keytoolStatus = "warning"
    } catch {
        $keytoolStatus = "error"
        $envStatus = "error"
        $envMessage = "Java가 설치되어 있지 않습니다. JDK를 설치하세요."
    }
}

# ===================================================================
# 3. Application ID 추출
# ===================================================================

$gradleFile = $null
if (Test-Path (Join-Path $ProjectPath "android\app\build.gradle.kts")) {
    $gradleFile = Join-Path $ProjectPath "android\app\build.gradle.kts"
    $gradleType = "kts"
} elseif (Test-Path (Join-Path $ProjectPath "android\app\build.gradle")) {
    $gradleFile = Join-Path $ProjectPath "android\app\build.gradle"
    $gradleType = "groovy"
} else {
    $json = @{ error = "build.gradle 파일을 찾을 수 없습니다"; env = "error" } | ConvertTo-Json -Compress
    Write-Output $json
    exit 1
}

$content = Get-Content $gradleFile -Raw
$applicationId = $null

# Kotlin DSL
if ($gradleType -eq "kts") {
    if ($content -match 'applicationId\s*=\s*"([^"]+)"') {
        $applicationId = $matches[1].Trim()
    }
}

# Groovy
if (-not $applicationId) {
    if ($content -match 'applicationId\s+"([^"]+)"') {
        $applicationId = $matches[1].Trim()
    } elseif ($content -match "applicationId\s+'([^']+)'") {
        $applicationId = $matches[1].Trim()
    }
}

# namespace에서 추출
if (-not $applicationId) {
    if ($content -match 'namespace\s*=\s*"([^"]+)"') {
        $applicationId = $matches[1].Trim()
    }
}

if (-not $applicationId) {
    $json = @{ error = "applicationId를 찾을 수 없습니다"; env = "error" } | ConvertTo-Json -Compress
    Write-Output $json
    exit 1
}

# ===================================================================
# 4. 결과 출력 (JSON)
# ===================================================================

$result = @{
    applicationId = $applicationId
    env = $envStatus
    keytool = $keytoolStatus
    gradleType = $gradleType
}

if ($envMessage) {
    $result.message = $envMessage
}

$json = $result | ConvertTo-Json -Compress
Write-Output $json
