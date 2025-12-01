# =============================================================================
# Flutter Play Store CI/CD - Project Analyzer (Windows PowerShell)
# =============================================================================
# This script analyzes a Flutter project and outputs JSON with project info.
# Usage: powershell -ExecutionPolicy Bypass -File init.ps1 [project_path]
# =============================================================================

param(
    [string]$ProjectPath = "."
)

# Change to project directory
try {
    Set-Location $ProjectPath -ErrorAction Stop
} catch {
    Write-Error "Cannot access directory: $ProjectPath"
    exit 1
}

# Initialize result hashtable
$result = @{}

# Check if this is a Flutter project
if (-not (Test-Path "pubspec.yaml")) {
    Write-Error "This is not a Flutter project (pubspec.yaml not found)"
    exit 1
}

# 1. Parse Application ID from build.gradle.kts or build.gradle
if (Test-Path "android/app/build.gradle.kts") {
    $result["gradleType"] = "kts"
    $gradleContent = Get-Content "android/app/build.gradle.kts" -Raw
    if ($gradleContent -match 'applicationId\s*=\s*"([^"]+)"') {
        $result["applicationId"] = $matches[1]
    }
} elseif (Test-Path "android/app/build.gradle") {
    $result["gradleType"] = "groovy"
    $gradleContent = Get-Content "android/app/build.gradle" -Raw
    if ($gradleContent -match 'applicationId\s+"([^"]+)"') {
        $result["applicationId"] = $matches[1]
    }
} else {
    $result["gradleType"] = "unknown"
    $result["applicationId"] = ""
}

# 2. Parse version from version.yml or pubspec.yaml
if (Test-Path "version.yml") {
    $versionContent = Get-Content "version.yml" -Raw

    if ($versionContent -match 'version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?') {
        $result["versionName"] = $matches[1]
    }

    if ($versionContent -match 'version_code:\s*(\d+)') {
        $result["versionCode"] = [int]$matches[1]
    } else {
        $result["versionCode"] = 1
    }
} else {
    # Parse from pubspec.yaml
    $pubspecContent = Get-Content "pubspec.yaml" -Raw

    if ($pubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+?(\d*)') {
        $result["versionName"] = $matches[1]
        if ($matches[2]) {
            $result["versionCode"] = [int]$matches[2]
        } else {
            $result["versionCode"] = 1
        }
    }
}

# 3. Check for Firebase (google-services.json)
$result["hasFirebase"] = Test-Path "android/app/google-services.json"

# 4. Check for existing keystore
$keystorePath = "android/app/keystore"
$result["hasKeystore"] = $false
if (Test-Path $keystorePath) {
    $keystoreFiles = Get-ChildItem -Path $keystorePath -Filter "*.jks" -ErrorAction SilentlyContinue
    if (-not $keystoreFiles) {
        $keystoreFiles = Get-ChildItem -Path $keystorePath -Filter "*.keystore" -ErrorAction SilentlyContinue
    }
    if ($keystoreFiles) {
        $result["hasKeystore"] = $true
        $result["keystorePath"] = $keystoreFiles[0].FullName
    }
}

# 5. Check for fastlane setup
$result["hasFastlane"] = (Test-Path "android/fastlane/Fastfile") -or (Test-Path "android/fastlane/Fastfile.playstore")

# 6. Check for .env file
$result["hasEnvFile"] = Test-Path ".env"

# 7. Check for key.properties
$result["hasKeyProperties"] = Test-Path "android/key.properties"

# 8. Check signing config in build.gradle
$result["hasSigningConfig"] = $false
if (Test-Path "android/app/build.gradle.kts") {
    $gradleContent = Get-Content "android/app/build.gradle.kts" -Raw
    if ($gradleContent -match "signingConfigs") {
        $result["hasSigningConfig"] = $true
    }
} elseif (Test-Path "android/app/build.gradle") {
    $gradleContent = Get-Content "android/app/build.gradle" -Raw
    if ($gradleContent -match "signingConfigs") {
        $result["hasSigningConfig"] = $true
    }
}

# 9. Get app name from pubspec.yaml
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match 'name:\s*(\S+)') {
    $result["appName"] = $matches[1]
}

# 10. Project path
$result["projectPath"] = (Get-Location).Path

# Convert to JSON and output
$jsonOutput = $result | ConvertTo-Json -Compress
Write-Output $jsonOutput
