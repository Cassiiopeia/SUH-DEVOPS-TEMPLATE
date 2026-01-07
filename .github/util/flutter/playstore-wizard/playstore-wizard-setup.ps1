# ===================================================================
# Flutter Android Play Store 초기화 스크립트 (Windows PowerShell)
# ===================================================================
#
# 이 스크립트는 Flutter 프로젝트에 Android Play Store 배포를 위한
# 빌드 환경 설정을 자동으로 구성합니다.
#
# ★ 마법사 우선 아키텍처 ★
# - 모든 설정 파일은 이 마법사가 생성합니다
# - GitHub Actions 워크플로우는 생성된 파일을 그대로 사용합니다
# - 초기 설정 후 수정 불필요 (One-time setup)
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File playstore-wizard-setup.ps1 PROJECT_PATH APPLICATION_ID KEY_ALIAS STORE_PASSWORD KEY_PASSWORD VALIDITY_DAYS CERT_CN CERT_O CERT_L CERT_C
#
# 예시:
#   powershell -ExecutionPolicy Bypass -File playstore-wizard-setup.ps1 "C:\path\to\project" "com.example.app" "my-release-key" "MyPass123" "MyPass123" "99999" "My Name" "My Company" "Seoul" "KR"
#
# ===================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory=$true)]
    [string]$ApplicationId,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyAlias,
    
    [Parameter(Mandatory=$true)]
    [string]$StorePassword,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyPassword,
    
    [Parameter(Mandatory=$true)]
    [int]$ValidityDays,
    
    [Parameter(Mandatory=$true)]
    [string]$CertCN,
    
    [Parameter(Mandatory=$true)]
    [string]$CertO,
    
    [Parameter(Mandatory=$true)]
    [string]$CertL,
    
    [Parameter(Mandatory=$true)]
    [string]$CertC
)

# 에러 발생 시 스크립트 중단
$ErrorActionPreference = "Stop"

# 색상 출력 함수
function Write-Step {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "  → $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# 매개변수 검증
function Validate-Params {
    if (-not (Test-Path $ProjectPath)) {
        Write-Error "프로젝트 경로가 존재하지 않습니다: $ProjectPath"
        exit 1
    }

    if (-not (Test-Path (Join-Path $ProjectPath "pubspec.yaml"))) {
        Write-Error "Flutter 프로젝트가 아닙니다 (pubspec.yaml 없음)"
        exit 1
    }

    if (-not (Test-Path (Join-Path $ProjectPath "android"))) {
        Write-Error "Android 폴더가 없습니다. 'flutter create .' 명령을 먼저 실행하세요."
        exit 1
    }

    if ($ApplicationId -notmatch '\.') {
        Write-Error "Application ID 형식이 올바르지 않습니다: $ApplicationId"
        Write-Error "예시: com.example.app"
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($StorePassword) -or [string]::IsNullOrWhiteSpace($KeyPassword)) {
        Write-Error "Keystore 비밀번호와 Key 비밀번호는 필수입니다."
        exit 1
    }

    if ($CertC.Length -ne 2) {
        Write-Error "Country Code는 2자리여야 합니다: $CertC"
        exit 1
    }
}

# 템플릿 디렉토리 찾기
function Find-TemplateDir {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $templateDir = Join-Path $scriptDir "templates"
    
    if (-not (Test-Path $templateDir)) {
        Write-Error "템플릿 디렉토리를 찾을 수 없습니다: $templateDir"
        exit 1
    }
    
    Write-Info "템플릿 디렉토리: $templateDir"
    return $templateDir
}

# .gitignore 업데이트
function Update-Gitignore {
    Write-Step ".gitignore 업데이트 중..."

    # Git 저장소 확인
    $gitDir = Join-Path $ProjectPath ".git"
    if (-not (Test-Path $gitDir)) {
        Write-Info "Git 저장소가 아닙니다. .gitignore 업데이트를 건너뜁니다."
        return
    }

    $gitignorePath = Join-Path $ProjectPath ".gitignore"
    $androidGitignorePath = Join-Path $ProjectPath "android\.gitignore"
    $gitignoreUpdated = $false

    # 루트 .gitignore 처리 (파일이 존재할 때만)
    if (Test-Path $gitignorePath) {
        $gitignoreEntries = @(
            "android/key.properties",
            "android/app/keystore/",
            "*.jks",
            "*.keystore"
        )

        foreach ($entry in $gitignoreEntries) {
            $content = Get-Content $gitignorePath -Raw -ErrorAction SilentlyContinue
            if ($content -and $content -notmatch [regex]::Escape($entry)) {
                Add-Content $gitignorePath "`n# Play Store Keystore (자동 생성됨)"
                Add-Content $gitignorePath $entry
                Write-Info "루트 .gitignore에 추가: $entry"
                $gitignoreUpdated = $true
            }
        }
    }
    # 루트 .gitignore가 없으면 생성하지 않음 (Git 미사용 프로젝트 가능성)

    # android/.gitignore 처리
    if (Test-Path $androidGitignorePath) {
        $content = Get-Content $androidGitignorePath -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -notmatch "key.properties") {
            Add-Content $androidGitignorePath "`n# Play Store Keystore (자동 생성됨)"
            Add-Content $androidGitignorePath "key.properties"
            Add-Content $androidGitignorePath "keystore/"
            Write-Info "android/.gitignore에 추가됨"
            $gitignoreUpdated = $true
        }
    } else {
        # android/.gitignore가 없으면 생성
        $androidDir = Join-Path $ProjectPath "android"
        if (-not (Test-Path $androidDir)) {
            New-Item -ItemType Directory -Path $androidDir -Force | Out-Null
        }
        $content = @"
# Play Store Keystore (자동 생성됨)
key.properties
keystore/
*.jks
*.keystore
"@
        Set-Content $androidGitignorePath $content
        Write-Info "android/.gitignore 생성됨"
        $gitignoreUpdated = $true
    }

    if ($gitignoreUpdated) {
        Write-Success ".gitignore 업데이트 완료"
    } else {
        Write-Info ".gitignore에 이미 모든 항목이 포함되어 있습니다."
    }
}

# .gitignore 변경사항 커밋 (Keystore 생성 전에 실행!)
function Commit-Gitignore {
    Write-Step ".gitignore 변경사항 커밋 중..."

    # Git 저장소 확인
    $gitDir = Join-Path $ProjectPath ".git"
    if (-not (Test-Path $gitDir)) {
        Write-Info "Git 저장소가 아닙니다. 커밋을 건너뜁니다."
        return
    }

    # Git 명령어 사용 가능 여부 확인
    try {
        $null = Get-Command git -ErrorAction Stop
    } catch {
        Write-Warning "Git이 설치되어 있지 않습니다. 커밋을 건너뜁니다."
        return
    }

    $gitignorePath = Join-Path $ProjectPath ".gitignore"
    $androidGitignorePath = Join-Path $ProjectPath "android\.gitignore"
    $hasChanges = $false

    # .gitignore 변경사항 확인
    if (Test-Path $gitignorePath) {
        Push-Location $ProjectPath
        try {
            $diff = git diff --quiet $gitignorePath 2>&1
            if ($LASTEXITCODE -ne 0) {
                $hasChanges = $true
            }
        } finally {
            Pop-Location
        }
    }

    if (Test-Path $androidGitignorePath) {
        Push-Location $ProjectPath
        try {
            $diff = git diff --quiet $androidGitignorePath 2>&1
            if ($LASTEXITCODE -ne 0) {
                $hasChanges = $true
            }
        } finally {
            Pop-Location
        }
    }

    if ($hasChanges) {
        # 이미 추적 중인 파일 제거 (있는 경우)
        Push-Location $ProjectPath
        try {
            $keyPropertiesPath = "android/key.properties"
            $keystorePath = "android/app/keystore/key.jks"

            $trackedFiles = git ls-files 2>&1
            if ($trackedFiles -match "android[/\\]key\.properties") {
                Write-Warning "이미 추적 중인 key.properties를 Git에서 제거합니다..."
                git rm --cached $keyPropertiesPath 2>&1 | Out-Null
            }

            if ($trackedFiles -match "android[/\\]app[/\\]keystore[/\\]key\.jks") {
                Write-Warning "이미 추적 중인 keystore 파일을 Git에서 제거합니다..."
                git rm --cached $keystorePath 2>&1 | Out-Null
            }

            # .gitignore 커밋
            if (Test-Path $gitignorePath) {
                git add $gitignorePath 2>&1 | Out-Null
            }
            if (Test-Path $androidGitignorePath) {
                git add $androidGitignorePath 2>&1 | Out-Null
            }

            $stagedDiff = git diff --cached --quiet 2>&1
            if ($LASTEXITCODE -ne 0) {
                $commitResult = git commit -m "chore: Add keystore files to .gitignore" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success ".gitignore 변경사항 커밋 완료"
                } else {
                    Write-Warning "커밋 실패 (이미 커밋되었거나 변경사항 없음)"
                }
            } else {
                Write-Info ".gitignore에 변경사항이 없습니다 (이미 커밋됨)."
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Info ".gitignore에 변경사항이 없습니다."
    }
}

# Keystore 생성
function Create-Keystore {
    Write-Step "Keystore 생성 중..."

    $keystoreDir = Join-Path $ProjectPath "android\app\keystore"
    $keystorePath = Join-Path $keystoreDir "key.jks"

    # 디렉토리 생성
    if (-not (Test-Path $keystoreDir)) {
        New-Item -ItemType Directory -Path $keystoreDir -Force | Out-Null
    }

    # 기존 keystore 확인
    if (Test-Path $keystorePath) {
        Write-Warning "기존 keystore가 존재합니다: $keystorePath"
        $response = Read-Host "덮어쓰시겠습니까? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            Write-Info "Keystore 생성 스킵"
            return
        }
        Copy-Item $keystorePath "$keystorePath.bak"
        Write-Info "기존 keystore 백업: $keystorePath.bak"
    }

    $dname = "CN=$CertCN, O=$CertO, L=$CertL, C=$CertC"
    
    Write-Info "Keystore 정보:"
    Write-Info "  • 경로: $keystorePath"
    Write-Info "  • Alias: $KeyAlias"
    Write-Info "  • 유효기간: $ValidityDays일"
    Write-Info "  • 인증서: $dname"

    # keytool 실행
    $keytoolArgs = @(
        "-genkey",
        "-v",
        "-keystore", $keystorePath,
        "-alias", $KeyAlias,
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", $ValidityDays.ToString(),
        "-storepass", $StorePassword,
        "-keypass", $KeyPassword,
        "-dname", $dname
    )

    try {
        & keytool $keytoolArgs 2>&1 | Where-Object { $_ -notmatch "Warning:" } | Out-Null
        if (Test-Path $keystorePath) {
            Write-Success "Keystore 생성 완료: $keystorePath"
        } else {
            Write-Error "Keystore 생성 실패!"
            exit 1
        }
    } catch {
        Write-Error "Keystore 생성 중 오류 발생: $_"
        exit 1
    }
}

# key.properties 생성
function Create-KeyProperties {
    Write-Step "key.properties 생성 중..."

    $keyPropertiesPath = Join-Path $ProjectPath "android\key.properties"

    # 기존 파일 백업
    if (Test-Path $keyPropertiesPath) {
        Write-Warning "기존 key.properties 백업: $keyPropertiesPath.bak"
        Copy-Item $keyPropertiesPath "$keyPropertiesPath.bak"
    }

    $content = @"
# Release Keystore Configuration
# WARNING: Do not commit this file to version control!
# This file is automatically generated by Play Store Wizard

storeFile=keystore/key.jks
storePassword=$StorePassword
keyAlias=$KeyAlias
keyPassword=$KeyPassword
"@

    Set-Content $keyPropertiesPath $content
    Write-Success "key.properties 생성 완료: $keyPropertiesPath"
    Write-Info "  • Store Password: $StorePassword"
    Write-Info "  • Key Alias: $KeyAlias"
    Write-Info "  • Key Password: $KeyPassword"
}

# build.gradle.kts에 서명 설정 추가
function Patch-BuildGradle {
    Write-Step "build.gradle.kts에 서명 설정 추가 중..."

    $gradleFile = Join-Path $ProjectPath "android\app\build.gradle.kts"

    if (-not (Test-Path $gradleFile)) {
        Write-Error "build.gradle.kts 파일을 찾을 수 없습니다: $gradleFile"
        exit 1
    }

    # 백업 생성
    Copy-Item $gradleFile "$gradleFile.bak"
    Write-Info "백업 생성: $gradleFile.bak"

    $content = Get-Content $gradleFile -Raw

    # key.properties 로드 코드 추가
    if ($content -notmatch "key.properties") {
        $importBlock = @"

// Load key.properties file
import java.util.Properties
import java.io.FileInputStream
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
"@
        # plugins 블록 다음에 추가
        $content = $content -replace "(plugins \{[\s\S]*?\n\})", "`$1$importBlock"
        Write-Info "key.properties 로드 코드 추가됨"
    }

    # signingConfigs 블록 추가
    if ($content -notmatch "signingConfigs") {
        $signingBlock = @"

    // Signing Configurations
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }
"@
        # android { 다음에 추가
        $content = $content -replace "(android \{)", "`$1$signingBlock"
        Write-Info "signingConfigs 블록 추가됨"
    }

    # release buildType에 signingConfig 추가
    if ($content -match "buildTypes \{") {
        if ($content -notmatch "signingConfig = signingConfigs.getByName\(`"release`"\)") {
            $content = $content -replace "(release \{)", "`$1`n            signingConfig = signingConfigs.getByName(`"release`")"
            Write-Info "release buildType에 signingConfig 추가됨"
        }
    }

    Set-Content $gradleFile $content -NoNewline
    Write-Success "build.gradle.kts 패치 완료"
    Write-Warning "변경사항을 확인하고 필요시 수동으로 조정하세요."
}

# Fastfile.playstore 생성
function Create-Fastfile {
    Write-Step "Fastfile.playstore 생성 중..."

    $fastlaneDir = Join-Path $ProjectPath "android\fastlane"
    $fastfilePath = Join-Path $fastlaneDir "Fastfile.playstore"
    $templateFastfile = Join-Path $TemplateDir "Fastfile.playstore.template"

    # fastlane 디렉토리 생성
    if (-not (Test-Path $fastlaneDir)) {
        New-Item -ItemType Directory -Path $fastlaneDir -Force | Out-Null
    }

    # 기존 파일 백업
    if (Test-Path $fastfilePath) {
        Write-Warning "기존 Fastfile.playstore 백업: $fastfilePath.bak"
        Copy-Item $fastfilePath "$fastfilePath.bak"
    }

    # 템플릿 파일 존재 확인
    if (Test-Path $templateFastfile) {
        $templateContent = Get-Content $templateFastfile -Raw
        $templateContent = $templateContent -replace '\{\{APPLICATION_ID\}\}', $ApplicationId
        Set-Content $fastfilePath $templateContent
        Write-Info "템플릿에서 생성됨"
    } else {
        # 템플릿이 없으면 직접 생성
        $content = @"
# Fastfile for Play Store Internal Testing Deployment
# Path: android/fastlane/Fastfile.playstore
# Generated by Flutter Play Store CI/CD Helper

default_platform(:android)

platform :android do
  desc "Deploy to Play Store Internal Testing"
  lane :deploy_internal do
    # Environment variables
    aab_path = ENV["AAB_PATH"] || "../build/app/outputs/bundle/release/app-release.aab"
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"

    puts "========================================="
    puts "Deploying to Play Store Internal Testing"
    puts "========================================="
    puts "AAB Path: #{aab_path}"
    puts "Service Account: #{json_key}"
    puts ""

    # Verify AAB exists
    unless File.exist?(aab_path)
      UI.user_error!("AAB file not found: #{aab_path}")
    end

    # Verify Service Account exists
    unless File.exist?(json_key)
      UI.user_error!("Service Account JSON not found: #{json_key}")
    end

    # Upload to Play Store
    upload_to_play_store(
      package_name: "$ApplicationId",
      track: "internal",
      aab: aab_path,
      json_key: json_key,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      release_status: "completed"
    )

    puts ""
    puts "========================================="
    puts "Successfully deployed to Internal Testing!"
    puts "========================================="
  end
end
"@
        Set-Content $fastfilePath $content
    }

    Write-Success "Fastfile.playstore 생성 완료: $fastfilePath"
    Write-Info "  → GitHub Actions 워크플로우에서 이 파일을 직접 사용합니다"
}

# Gemfile 생성
function Create-Gemfile {
    Write-Step "Gemfile 생성 중..."

    $gemfilePath = Join-Path $ProjectPath "android\Gemfile"

    # 기존 파일 백업
    if (Test-Path $gemfilePath) {
        Write-Warning "기존 Gemfile 백업: $gemfilePath.bak"
        Copy-Item $gemfilePath "$gemfilePath.bak"
    }

    $content = @"
# frozen_string_literal: true

source "https://rubygems.org"

# Fastlane - Android 빌드 자동화
gem "fastlane", "~> 2.225"
"@

    Set-Content $gemfilePath $content
    Write-Success "Gemfile 생성 완료: $gemfilePath"
}

# 완료 메시지
function Write-Completion {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          🎉 Android Play Store 배포 설정 완료! 🎉             ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "★ 마법사 우선 아키텍처 ★" -ForegroundColor Yellow
    Write-Host "  모든 설정이 완료되었습니다. 워크플로우는 이 파일들을 그대로 사용합니다."
    Write-Host ""
    Write-Host "생성/수정된 파일:" -ForegroundColor Cyan
    Write-Host "  ✅ android/.gitignore                    (.gitignore 업데이트)"
    Write-Host "  ✅ android/app/keystore/key.jks         (Keystore 생성) ★"
    Write-Host "  ✅ android/key.properties               (서명 정보) ★"
    Write-Host "  ✅ android/app/build.gradle.kts         (서명 설정 패치) ★"
    Write-Host "  ✅ android/fastlane/Fastfile.playstore  (Play Store 업로드) ★"
    Write-Host "  ✅ android/Gemfile                      (Fastlane 의존성)"
    Write-Host ""
    Write-Host "설정된 정보:" -ForegroundColor Cyan
    Write-Host "  • Application ID: $ApplicationId"
    Write-Host "  • Key Alias: $KeyAlias"
    Write-Host "  • Keystore 유효기간: $ValidityDays일"
    Write-Host ""
    Write-Host "빌드 파이프라인:" -ForegroundColor Cyan
    Write-Host "  1. flutter build appbundle (AAB 생성)"
    Write-Host "  2. fastlane deploy_internal (Fastfile.playstore 사용)"
    Write-Host ""
    Write-Host "다음 단계:" -ForegroundColor Yellow
    Write-Host "  1. GitHub Secrets 설정:"
    Write-Host "     • RELEASE_KEYSTORE_BASE64 (keystore 파일을 base64 인코딩)"
    Write-Host "     • RELEASE_KEYSTORE_PASSWORD"
    Write-Host "     • RELEASE_KEY_ALIAS"
    Write-Host "     • RELEASE_KEY_PASSWORD"
    Write-Host "     • GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64"
    Write-Host ""
    Write-Host "  2. 추가 변경사항 커밋 (필요시):"
    Write-Host "     git add android/"
    Write-Host "     git commit -m `"chore: Android Play Store 배포 설정`""
    Write-Host "     (참고: .gitignore는 이미 자동으로 커밋되었습니다)"
    Write-Host ""
    Write-Host "  3. deploy 브랜치로 푸시하여 빌드 테스트"
    Write-Host ""
}

# ===================================================================
# 메인 실행
# ===================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       Flutter Android Play Store 초기화 스크립트               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Validate-Params

Write-Host "프로젝트 경로: $ProjectPath" -ForegroundColor Blue
Write-Host "Application ID: $ApplicationId" -ForegroundColor Blue
Write-Host "Key Alias: $KeyAlias" -ForegroundColor Blue
Write-Host "유효기간: $ValidityDays일" -ForegroundColor Blue
Write-Host ""

$TemplateDir = Find-TemplateDir

# 파일 생성 (순서 중요!)
Update-Gitignore      # 1. 먼저 .gitignore 업데이트
Commit-Gitignore      # 2. .gitignore 커밋 (Keystore 생성 전!)
Create-Keystore       # 3. 이제 Keystore 생성 (안전)
Create-KeyProperties
Patch-BuildGradle
Create-Fastfile
Create-Gemfile

# 완료
Write-Completion
