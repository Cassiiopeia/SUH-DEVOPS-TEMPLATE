# ============================================
# GitHub Projects Sync Worker 설치 스크립트 (Windows PowerShell)
#
# 사용법: .\projects-sync-worker-setup.ps1
#
# 이 스크립트는 다음을 자동으로 수행합니다:
# 1. npm 의존성 설치 (SSL 오류 대응)
# 2. Cloudflare 로그인 (브라우저 자동 오픈)
# 3. Worker 배포 (이름 충돌 시 재입력 가능)
# 4. Secrets 설정 (GITHUB_TOKEN, WEBHOOK_SECRET)
# ============================================

$ErrorActionPreference = "Stop"

# 색상 함수
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# 로고 출력
Write-Host ""
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Cyan"
Write-ColorOutput "   🔄 GitHub Projects Sync Worker 설치 스크립트" "Cyan"
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Cyan"
Write-Host ""

# config.json 확인
if (-not (Test-Path "config.json")) {
    Write-ColorOutput "❌ config.json 파일을 찾을 수 없습니다." "Red"
    Write-Host "   마법사에서 다운로드한 ZIP 파일을 먼저 압축 해제하세요."
    exit 1
}

# config.json 읽기
$config = Get-Content "config.json" -Raw | ConvertFrom-Json
$ORG_NAME = $config.orgName
$WORKER_NAME = $config.workerName
$WEBHOOK_SECRET = $config.webhookSecret

Write-ColorOutput "📋 설정 정보:" "Blue"
Write-Host "   Organization: " -NoNewline
Write-ColorOutput $ORG_NAME "Green"
Write-Host "   Worker 이름: " -NoNewline
Write-ColorOutput $WORKER_NAME "Green"
Write-Host ""

# ============================================
# Step 1: npm 의존성 설치
# ============================================
Write-Host "[1/4] " -NoNewline -ForegroundColor Yellow
Write-Host "📦 의존성 설치 중..."

# SSL 오류 대응
try {
    npm config set strict-ssl false 2>$null
} catch {}

try {
    npm install
    Write-ColorOutput "✅ 의존성 설치 완료" "Green"
} catch {
    Write-ColorOutput "❌ npm install 실패" "Red"
    Write-Host "   다음 명령어를 수동으로 실행해보세요:"
    Write-ColorOutput "   npm config set strict-ssl false; npm install" "Cyan"
    exit 1
}

# SSL 설정 복원
try {
    npm config set strict-ssl true 2>$null
} catch {}

Write-Host ""

# ============================================
# Step 2: Cloudflare 로그인
# ============================================
Write-Host "[2/4] " -NoNewline -ForegroundColor Yellow
Write-Host "🔐 Cloudflare 로그인 중..."
Write-ColorOutput "   브라우저가 열리면 로그인하세요." "Cyan"

# SSL 오류 대응 (환경 변수)
$env:NODE_TLS_REJECT_UNAUTHORIZED = "0"

try {
    npx wrangler login
    Write-ColorOutput "✅ Cloudflare 로그인 완료" "Green"
} catch {
    Write-ColorOutput "❌ Cloudflare 로그인 실패" "Red"
    Write-Host "   다음 명령어를 수동으로 실행해보세요:"
    Write-ColorOutput '   $env:NODE_TLS_REJECT_UNAUTHORIZED="0"; npx wrangler login' "Cyan"
    exit 1
}

Write-Host ""

# ============================================
# Step 3: Worker 배포 (이름 충돌 시 재시도)
# ============================================
Write-Host "[3/4] " -NoNewline -ForegroundColor Yellow
Write-Host "🚀 Worker 배포 중..."

$DEPLOY_SUCCESS = $false
$WORKER_URL = ""

while (-not $DEPLOY_SUCCESS) {
    try {
        $DEPLOY_OUTPUT = npx wrangler deploy 2>&1 | Out-String

        # URL 추출
        if ($DEPLOY_OUTPUT -match "https://[^\s]*workers\.dev") {
            $WORKER_URL = $Matches[0]
            $DEPLOY_SUCCESS = $true
            Write-ColorOutput "✅ Worker 배포 완료" "Green"
            Write-Host "   URL: " -NoNewline
            Write-ColorOutput $WORKER_URL "Cyan"
        } else {
            throw "URL not found in output"
        }
    } catch {
        Write-ColorOutput "❌ Worker 배포 실패" "Red"
        Write-Host ""
        Write-ColorOutput "에러 내용:" "Yellow"
        Write-Host $DEPLOY_OUTPUT
        Write-Host ""

        # 서브도메인 충돌 확인
        if ($DEPLOY_OUTPUT -match "subdomain|unavailable|already|conflict") {
            Write-ColorOutput "💡 서브도메인이 이미 사용 중일 수 있습니다." "Yellow"
        }

        Write-Host ""
        $NEW_WORKER_NAME = Read-Host "새 Worker 이름을 입력하세요 (또는 Enter로 다시 시도, 'q'로 종료)"

        if ($NEW_WORKER_NAME -eq "q" -or $NEW_WORKER_NAME -eq "Q") {
            Write-ColorOutput "설치를 종료합니다." "Yellow"
            exit 1
        }

        if ($NEW_WORKER_NAME) {
            # wrangler.toml 수정
            if (Test-Path "wrangler.toml") {
                $content = Get-Content "wrangler.toml" -Raw
                $content = $content -replace 'name = "[^"]*"', "name = `"$NEW_WORKER_NAME`""
                Set-Content "wrangler.toml" $content
                Write-ColorOutput "✅ Worker 이름을 '$NEW_WORKER_NAME'으로 변경했습니다." "Green"

                # config.json도 업데이트
                if (Test-Path "config.json") {
                    $configContent = Get-Content "config.json" -Raw
                    $configContent = $configContent -replace '"workerName"\s*:\s*"[^"]*"', "`"workerName`": `"$NEW_WORKER_NAME`""
                    Set-Content "config.json" $configContent
                }
            }
        }

        Write-ColorOutput "다시 배포를 시도합니다..." "Blue"
        Write-Host ""
    }
}

Write-Host ""

# ============================================
# Step 4: Secrets 설정
# ============================================
Write-Host "[4/4] " -NoNewline -ForegroundColor Yellow
Write-Host "🔑 Secrets 설정 중..."

# GITHUB_TOKEN 설정
Write-Host ""
Write-ColorOutput "GitHub Personal Access Token을 입력하세요." "Cyan"
Write-Host "필요한 권한: " -NoNewline
Write-ColorOutput "repo" "Green" -NoNewline
Write-Host ", " -NoNewline
Write-ColorOutput "project" "Green" -NoNewline
Write-Host " (read:project, write:project)"
Write-ColorOutput "토큰 생성: https://github.com/settings/tokens/new" "White"
Write-Host ""

try {
    npx wrangler secret put GITHUB_TOKEN
    Write-ColorOutput "✅ GITHUB_TOKEN 설정 완료" "Green"
} catch {
    Write-ColorOutput "❌ GITHUB_TOKEN 설정 실패" "Red"
    Write-ColorOutput "   나중에 수동으로 설정하세요: npx wrangler secret put GITHUB_TOKEN" "Cyan"
}

Write-Host ""

# WEBHOOK_SECRET 설정
Write-ColorOutput "Webhook Secret 설정 중..." "Cyan"
$secretPreview = $WEBHOOK_SECRET.Substring(0, [Math]::Min(8, $WEBHOOK_SECRET.Length))
Write-Host "config.json에 저장된 값을 사용합니다: " -NoNewline
Write-ColorOutput "$secretPreview..." "Green"
Write-Host ""

try {
    $WEBHOOK_SECRET | npx wrangler secret put WEBHOOK_SECRET
    Write-ColorOutput "✅ WEBHOOK_SECRET 설정 완료" "Green"
} catch {
    Write-ColorOutput "⚠️ 자동 설정 실패. 수동으로 입력해주세요." "Yellow"
    npx wrangler secret put WEBHOOK_SECRET
}

Write-Host ""

# ============================================
# 완료
# ============================================
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Cyan"
Write-ColorOutput "🎉 설치 완료!" "Green"
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Cyan"
Write-Host ""
Write-Host "📌 " -NoNewline
Write-ColorOutput "Worker URL: " "Yellow" -NoNewline
Write-ColorOutput $WORKER_URL "Cyan"
Write-Host ""
Write-ColorOutput "📋 다음 단계: GitHub Webhook 설정" "Blue"
Write-Host ""
Write-Host "   1. Organization Settings → Webhooks 이동"
Write-ColorOutput "      https://github.com/organizations/$ORG_NAME/settings/hooks" "Cyan"
Write-Host ""
Write-Host "   2. 'Add webhook' 클릭"
Write-Host ""
Write-Host "   3. 다음 정보 입력:"
Write-Host "      • Payload URL: " -NoNewline
Write-ColorOutput $WORKER_URL "Green"
Write-Host "      • Content type: application/json"
Write-Host "      • Secret: " -NoNewline
Write-ColorOutput "$secretPreview... (config.json 참조)" "Green"
Write-Host ""
Write-Host "   4. Events 선택:"
Write-Host "      • 'Let me select individual events' 클릭"
Write-Host "      • " -NoNewline
Write-ColorOutput "'Project v2 items'" "Green" -NoNewline
Write-Host " 체크"
Write-Host ""
Write-Host "   5. 'Add webhook' 클릭"
Write-Host ""
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Cyan"
Write-Host "💡 " -NoNewline
Write-ColorOutput "Webhook Secret 전체값:" "Yellow"
Write-ColorOutput "   $WEBHOOK_SECRET" "Green"
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Cyan"
Write-Host ""
