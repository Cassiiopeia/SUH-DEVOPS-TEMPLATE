# ===================================================================
# Flutter OAuth Key Extractor (Windows PowerShell)
# ===================================================================
#
# 이 스크립트는 Android keystore에서 OAuth 인증에 필요한 키를 추출합니다.
#
# 지원하는 OAuth 제공자:
#   - Google / Firebase (SHA-1, SHA-256)
#   - Kakao (Key Hash)
#   - Facebook (Key Hash)
#   - Naver (안내만 제공)
#
# 사용법:
#   .\extract-keys.ps1                    # 대화형 모드
#   .\extract-keys.ps1 -Debug             # 디버그 키스토어 자동 사용
#   .\extract-keys.ps1 -Keystore "C:\path\to\keystore" -Alias "alias" -Password "pass"
#
# ===================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Keystore = "",

    [Parameter(Mandatory=$false)]
    [string]$Alias = "",

    [Parameter(Mandatory=$false)]
    [string]$Password = "",

    [Parameter(Mandatory=$false)]
    [switch]$Debug,

    [Parameter(Mandatory=$false)]
    [string]$Output = "oauth-keys.json",

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# UTF-8 인코딩 설정
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ===================================================================
# 출력 함수
# ===================================================================

function Write-Banner {
    Write-Host ""
    Write-Host "+" -NoNewline -ForegroundColor Cyan
    Write-Host ("=" * 68) -NoNewline -ForegroundColor Cyan
    Write-Host "+" -ForegroundColor Cyan
    Write-Host "|" -NoNewline -ForegroundColor Cyan
    Write-Host " " -NoNewline
    Write-Host "Flutter OAuth Key Extractor" -NoNewline -ForegroundColor White
    Write-Host (" " * 39) -NoNewline
    Write-Host "|" -ForegroundColor Cyan
    Write-Host "+" -NoNewline -ForegroundColor Cyan
    Write-Host ("=" * 68) -NoNewline -ForegroundColor Cyan
    Write-Host "+" -ForegroundColor Cyan
    Write-Host "|" -NoNewline -ForegroundColor Cyan
    Write-Host "  Extract SHA-1, SHA-256, Key Hash from Android Keystore" -NoNewline
    Write-Host (" " * 9) -NoNewline
    Write-Host "|" -ForegroundColor Cyan
    Write-Host "|" -NoNewline -ForegroundColor Cyan
    Write-Host "  For Google, Firebase, Kakao, Facebook, Naver OAuth" -NoNewline
    Write-Host (" " * 14) -NoNewline
    Write-Host "|" -ForegroundColor Cyan
    Write-Host "+" -NoNewline -ForegroundColor Cyan
    Write-Host ("=" * 68) -NoNewline -ForegroundColor Cyan
    Write-Host "+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host ">" -NoNewline -ForegroundColor Cyan
    Write-Host " $Message"
}

function Write-Info {
    param([string]$Message)
    Write-Host "  i" -NoNewline -ForegroundColor Blue
    Write-Host " $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK]" -NoNewline -ForegroundColor Green
    Write-Host " $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  [!]" -NoNewline -ForegroundColor Yellow
    Write-Host " $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "  [X]" -NoNewline -ForegroundColor Red
    Write-Host " $Message"
}

# ===================================================================
# 도움말
# ===================================================================

function Show-Help {
    Write-Host @"

Flutter OAuth Key Extractor (Windows)

사용법:
  .\extract-keys.ps1 [옵션]

옵션:
  -Keystore PATH    키스토어 파일 경로
  -Alias NAME       키 별칭 (기본: androiddebugkey)
  -Password PASS    키스토어 비밀번호 (기본: android)
  -Debug            디버그 키스토어 자동 사용
  -Output FILE      출력 파일명 (기본: oauth-keys.json)
  -Help             도움말

예시:
  # 대화형 모드
  .\extract-keys.ps1

  # 디버그 키스토어 (자동)
  .\extract-keys.ps1 -Debug

  # 릴리즈 키스토어
  .\extract-keys.ps1 -Keystore "C:\keys\release.jks" -Alias "my-alias" -Password "mypass"

출력:
  oauth-keys.json 파일이 생성됩니다.
  index.html을 열어서 결과를 확인하세요.

"@
}

# ===================================================================
# keytool 확인
# ===================================================================

function Test-Keytool {
    try {
        $null = & keytool -help 2>&1
        Write-Success "keytool 확인됨"
        return $true
    } catch {
        Write-Error "keytool을 찾을 수 없습니다."
        Write-Info "JDK를 설치해주세요: https://adoptium.net/"
        Write-Info "또는 JAVA_HOME이 PATH에 설정되어 있는지 확인해주세요."
        return $false
    }
}

# ===================================================================
# 디버그 키스토어 찾기
# ===================================================================

function Find-DebugKeystore {
    $debugPath = "$env:USERPROFILE\.android\debug.keystore"

    if (Test-Path $debugPath) {
        return $debugPath
    }

    return $null
}

# ===================================================================
# 대화형 모드
# ===================================================================

function Start-InteractiveMode {
    Write-Step "키스토어 설정"
    Write-Host ""
    Write-Host "  1) 디버그 키스토어 (자동 감지)"
    Write-Host "  2) 릴리즈 키스토어 (경로 입력)"
    Write-Host ""

    $choice = Read-Host "  선택 (1/2)"

    switch ($choice) {
        "1" {
            $script:Keystore = Find-DebugKeystore
            if (-not $script:Keystore) {
                Write-Error "디버그 키스토어를 찾을 수 없습니다."
                Write-Info "경로: $env:USERPROFILE\.android\debug.keystore"
                exit 1
            }
            $script:Alias = "androiddebugkey"
            $script:Password = "android"
            Write-Info "디버그 키스토어: $script:Keystore"
        }
        "2" {
            $script:Keystore = Read-Host "  키스토어 경로"
            if (-not (Test-Path $script:Keystore)) {
                Write-Error "파일을 찾을 수 없습니다: $script:Keystore"
                exit 1
            }
            $script:Alias = Read-Host "  별칭 (alias)"
            $securePassword = Read-Host "  비밀번호" -AsSecureString
            $script:Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
        }
        default {
            Write-Error "잘못된 선택입니다."
            exit 1
        }
    }
}

# ===================================================================
# SHA-1 추출
# ===================================================================

function Get-SHA1 {
    param(
        [string]$KeystorePath,
        [string]$KeyAlias,
        [string]$KeyPassword
    )

    try {
        $output = & keytool -list -v -keystore $KeystorePath -alias $KeyAlias -storepass $KeyPassword 2>&1
        $sha1Line = $output | Select-String "SHA1:"
        if ($sha1Line) {
            $sha1 = ($sha1Line -split "SHA1:")[1].Trim()
            return $sha1
        }
    } catch {
        return $null
    }
    return $null
}

# ===================================================================
# SHA-256 추출
# ===================================================================

function Get-SHA256 {
    param(
        [string]$KeystorePath,
        [string]$KeyAlias,
        [string]$KeyPassword
    )

    try {
        $output = & keytool -list -v -keystore $KeystorePath -alias $KeyAlias -storepass $KeyPassword 2>&1
        $sha256Line = $output | Select-String "SHA256:"
        if ($sha256Line) {
            $sha256 = ($sha256Line -split "SHA256:")[1].Trim()
            return $sha256
        }
    } catch {
        return $null
    }
    return $null
}

# ===================================================================
# Key Hash 추출 (Kakao, Facebook용)
# ===================================================================

function Get-KeyHash {
    param(
        [string]$KeystorePath,
        [string]$KeyAlias,
        [string]$KeyPassword
    )

    try {
        # keytool로 인증서 바이트 추출
        $certBytes = & keytool -exportcert -keystore $KeystorePath -alias $KeyAlias -storepass $KeyPassword 2>$null

        if ($certBytes) {
            # SHA-1 해시 계산
            $sha1 = [System.Security.Cryptography.SHA1]::Create()
            $hashBytes = $sha1.ComputeHash($certBytes)

            # Base64 인코딩
            $keyHash = [Convert]::ToBase64String($hashBytes)
            return $keyHash
        }
    } catch {
        return $null
    }
    return $null
}

# ===================================================================
# JSON 생성
# ===================================================================

function New-OAuthKeysJson {
    param(
        [string]$SHA1,
        [string]$SHA256,
        [string]$KeyHash,
        [string]$KeystorePath,
        [string]$KeyAlias,
        [string]$OutputPath
    )

    $sha1NoColon = $SHA1 -replace ":", ""
    $sha256NoColon = $SHA256 -replace ":", ""
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $keystoreType = if ($KeystorePath -match "debug") { "debug" } else { "release" }

    $jsonContent = @{
        generated_at = $timestamp
        keystore = @{
            path = $KeystorePath
            alias = $KeyAlias
            type = $keystoreType
        }
        keys = @{
            sha1 = $SHA1
            sha1_no_colon = $sha1NoColon
            sha256 = $SHA256
            sha256_no_colon = $sha256NoColon
            key_hash_base64 = $KeyHash
        }
        platforms = @{
            google_firebase = @{
                sha1 = $sha1NoColon
                sha256 = $sha256NoColon
                console_url = "https://console.firebase.google.com"
            }
            kakao = @{
                key_hash = $KeyHash
                console_url = "https://developers.kakao.com"
            }
            facebook = @{
                key_hash = $KeyHash
                console_url = "https://developers.facebook.com"
            }
            naver = @{
                note = "Package Name 기반 설정"
                console_url = "https://developers.naver.com"
            }
        }
    }

    $jsonContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
}

# ===================================================================
# 결과 출력
# ===================================================================

function Write-Results {
    param(
        [string]$SHA1,
        [string]$SHA256,
        [string]$KeyHash
    )

    $sha1NoColon = $SHA1 -replace ":", ""

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host " 추출된 OAuth 키" -ForegroundColor White
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""

    # Google / Firebase
    Write-Host " Google / Firebase" -ForegroundColor Red
    Write-Host ("-" * 68)
    Write-Host "  SHA-1:           " -NoNewline
    Write-Host $SHA1 -ForegroundColor Green
    Write-Host "  SHA-1 (콜론없음): " -NoNewline
    Write-Host $sha1NoColon -ForegroundColor Green
    Write-Host "  SHA-256:         " -NoNewline
    Write-Host $SHA256 -ForegroundColor Green
    Write-Host ""

    # Kakao
    Write-Host " Kakao" -ForegroundColor Yellow
    Write-Host ("-" * 68)
    Write-Host "  Key Hash:        " -NoNewline
    Write-Host $KeyHash -ForegroundColor Green
    Write-Host ""

    # Facebook
    Write-Host " Facebook" -ForegroundColor Blue
    Write-Host ("-" * 68)
    Write-Host "  Key Hash:        " -NoNewline
    Write-Host $KeyHash -ForegroundColor Green
    Write-Host ""

    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
}

# ===================================================================
# 메인 실행
# ===================================================================

function Main {
    if ($Help) {
        Show-Help
        exit 0
    }

    Write-Banner

    # 의존성 확인
    Write-Step "의존성 확인 중..."
    if (-not (Test-Keytool)) {
        exit 1
    }
    Write-Host ""

    # 디버그 모드 또는 대화형 모드
    if ($Debug) {
        $script:Keystore = Find-DebugKeystore
        if (-not $script:Keystore) {
            Write-Error "디버그 키스토어를 찾을 수 없습니다."
            exit 1
        }
        $script:Alias = "androiddebugkey"
        $script:Password = "android"
        Write-Info "디버그 키스토어: $script:Keystore"
    } elseif ([string]::IsNullOrEmpty($Keystore)) {
        Start-InteractiveMode
    }

    # 키스토어 확인
    if (-not (Test-Path $Keystore)) {
        Write-Error "키스토어 파일을 찾을 수 없습니다: $Keystore"
        exit 1
    }

    Write-Host ""
    Write-Step "키 추출 중..."

    # 키 추출
    $sha1 = Get-SHA1 -KeystorePath $Keystore -KeyAlias $Alias -KeyPassword $Password
    if (-not $sha1) {
        Write-Error "SHA-1 추출 실패. 비밀번호 또는 별칭을 확인해주세요."
        exit 1
    }

    $sha256 = Get-SHA256 -KeystorePath $Keystore -KeyAlias $Alias -KeyPassword $Password
    $keyHash = Get-KeyHash -KeystorePath $Keystore -KeyAlias $Alias -KeyPassword $Password

    Write-Success "키 추출 완료"

    # 결과 출력
    Write-Results -SHA1 $sha1 -SHA256 $sha256 -KeyHash $keyHash

    # JSON 생성
    New-OAuthKeysJson -SHA1 $sha1 -SHA256 $sha256 -KeyHash $keyHash -KeystorePath $Keystore -KeyAlias $Alias -OutputPath $Output
    Write-Success "결과 저장됨: $Output"
    Write-Host ""
    Write-Info "index.html을 열어서 결과를 확인하고 복사하세요!"
    Write-Host ""
}

# 스크립트 실행
Main
