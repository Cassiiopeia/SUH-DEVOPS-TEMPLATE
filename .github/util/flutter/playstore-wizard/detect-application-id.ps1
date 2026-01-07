# ===================================================================
# Flutter Application ID 자동 감지 스크립트 (PowerShell)
# ===================================================================
# build.gradle.kts 또는 build.gradle에서 applicationId를 자동으로 읽어옵니다.
#
# 사용법:
#   .\detect-application-id.ps1 PROJECT_PATH
#
# 출력:
#   JSON 형식으로 applicationId를 출력합니다.
#   예: {"applicationId": "com.example.app"}
# ===================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

# 프로젝트 경로 확인
if (-not (Test-Path $ProjectPath)) {
    Write-Error "오류: 프로젝트 경로가 존재하지 않습니다: $ProjectPath"
    exit 1
}

# build.gradle.kts 우선 확인
$gradleFile = $null
if (Test-Path (Join-Path $ProjectPath "android\app\build.gradle.kts")) {
    $gradleFile = Join-Path $ProjectPath "android\app\build.gradle.kts"
} elseif (Test-Path (Join-Path $ProjectPath "android\app\build.gradle")) {
    $gradleFile = Join-Path $ProjectPath "android\app\build.gradle"
} else {
    Write-Error "오류: build.gradle.kts 또는 build.gradle 파일을 찾을 수 없습니다."
    exit 1
}

# 파일 내용 읽기
$content = Get-Content $gradleFile -Raw

# applicationId 추출
$applicationId = $null

# Kotlin DSL (build.gradle.kts) 형식: applicationId = "com.example.app"
if ($gradleFile -match "\.kts$") {
    # applicationId = "..." 형식 정확히 매칭
    if ($content -match 'applicationId\s*=\s*"([^"]+)"') {
        $applicationId = $matches[1].Trim()
    }
}

# Groovy (build.gradle) 형식: applicationId "com.example.app"
if (-not $applicationId) {
    # applicationId "..." 형식 정확히 매칭 (공백만, = 없음)
    if ($content -match 'applicationId\s+"([^"]+)"') {
        $applicationId = $matches[1].Trim()
    }
}

# namespace에서 추출 시도 (Kotlin DSL) - applicationId가 없을 때만
if (-not $applicationId) {
    if ($content -match 'namespace\s*=\s*"([^"]+)"') {
        $applicationId = $matches[1].Trim()
    }
}

# 결과 출력
if (-not $applicationId) {
    Write-Error "오류: applicationId를 찾을 수 없습니다."
    exit 1
}

# JSON 형식으로 출력
$json = @{
    applicationId = $applicationId
} | ConvertTo-Json -Compress

Write-Output $json
