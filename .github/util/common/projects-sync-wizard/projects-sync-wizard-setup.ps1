# ============================================
# GitHub Projects Sync Wizard - 원클릭 설치 스크립트 (Windows)
#
# ⚠️ 사전 요구사항:
#   - Node.js 18.0.0 이상 (node -v로 확인)
#   - npm (Node.js와 함께 설치됨)
#   - Cloudflare 계정
#
# 사용법 (마법사에서 생성된 명령어):
# irm 'https://raw.githubusercontent.com/.../projects-sync-wizard-setup.ps1' | iex
#
# 또는 인자와 함께:
# $env:WIZARD_TYPE='org'; $env:WIZARD_OWNER='ORG_NAME'; $env:WIZARD_PROJECT='1'; `
# $env:WIZARD_WORKER_NAME='my-worker'; $env:WIZARD_WEBHOOK_SECRET='abc123'; `
# $env:WIZARD_LABELS='작업 전,작업 중,완료'; $env:WIZARD_GITHUB_TOKEN='ghp_xxxx'; `
# irm '...' | iex
# ============================================

$ErrorActionPreference = "Stop"

# 환경변수에서 설정 읽기
$ProjectType = if ($env:WIZARD_TYPE) { $env:WIZARD_TYPE } else { "org" }
$OwnerName = $env:WIZARD_OWNER
$ProjectNumber = $env:WIZARD_PROJECT
$WorkerName = if ($env:WIZARD_WORKER_NAME) { $env:WIZARD_WORKER_NAME } else { "github-projects-sync-worker" }
$WebhookSecret = $env:WIZARD_WEBHOOK_SECRET
$StatusLabels = $env:WIZARD_LABELS
$RepoOwner = $env:WIZARD_REPO_OWNER
$RepoName = $env:WIZARD_REPO_NAME
$GithubToken = $env:WIZARD_GITHUB_TOKEN

# 필수 인자 확인
if (-not $OwnerName -or -not $ProjectNumber -or -not $WebhookSecret -or -not $GithubToken) {
    Write-Host "❌ 필수 환경변수가 설정되지 않았습니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "필수 환경변수:" -ForegroundColor Yellow
    Write-Host "  `$env:WIZARD_OWNER = 'ORG_NAME'"
    Write-Host "  `$env:WIZARD_PROJECT = '1'"
    Write-Host "  `$env:WIZARD_WEBHOOK_SECRET = 'your-secret'"
    Write-Host "  `$env:WIZARD_GITHUB_TOKEN = 'ghp_xxxx...'"
    Write-Host ""
    Write-Host "선택 환경변수:" -ForegroundColor Yellow
    Write-Host "  `$env:WIZARD_TYPE = 'org' 또는 'user'"
    Write-Host "  `$env:WIZARD_WORKER_NAME = 'my-worker'"
    Write-Host "  `$env:WIZARD_LABELS = '작업 전,작업 중,완료'"
    Write-Host "  `$env:WIZARD_REPO_OWNER = 'username' (User Projects용)"
    Write-Host "  `$env:WIZARD_REPO_NAME = 'repo-name' (User Projects용)"
    exit 1
}

# Worker 이름 Cloudflare 규칙 준수 (소문자, 숫자, 하이픈만)
$WorkerName = $WorkerName.ToLower() -replace '[^a-z0-9-]', '-' -replace '-+', '-' -replace '^-|-$', ''

# User 타입인데 저장소 정보가 없는 경우 경고
if ($ProjectType -eq "user" -and (-not $RepoOwner -or -not $RepoName)) {
    Write-Host "⚠️  User Projects는 저장소 정보가 필요합니다." -ForegroundColor Yellow
    Write-Host "   WIZARD_REPO_OWNER와 WIZARD_REPO_NAME 환경변수를 설정하세요."
}

# 작업 디렉토리 변수 (cleanup 함수에서 사용)
$script:WorkDir = $null

# 임시 디렉토리 정리 함수
function Cleanup-OnExit {
    if ($script:WorkDir -and (Test-Path $script:WorkDir)) {
        Write-Host ""
        Write-Host "🧹 임시 디렉토리 정리 중..." -ForegroundColor Yellow
        Set-Location $env:USERPROFILE 2>$null
        Remove-Item -Recurse -Force $script:WorkDir -ErrorAction SilentlyContinue
        Write-Host "✅ 임시 디렉토리 삭제 완료" -ForegroundColor Green
    }

    # 환경변수 정리
    Remove-Item Env:WIZARD_TYPE -ErrorAction SilentlyContinue
    Remove-Item Env:WIZARD_OWNER -ErrorAction SilentlyContinue
    Remove-Item Env:WIZARD_PROJECT -ErrorAction SilentlyContinue
    Remove-Item Env:WIZARD_WORKER_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:WIZARD_WEBHOOK_SECRET -ErrorAction SilentlyContinue
    Remove-Item Env:WIZARD_LABELS -ErrorAction SilentlyContinue
    Remove-Item Env:WIZARD_REPO_OWNER -ErrorAction SilentlyContinue
    Remove-Item Env:WIZARD_REPO_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:WIZARD_GITHUB_TOKEN -ErrorAction SilentlyContinue
}

# 메인 로직을 try/finally로 감싸서 오류 발생 시에도 정리 보장
try {

# Node.js 버전 확인
Write-Host ""
Write-Host "🔍 사전 요구사항 확인 중..." -ForegroundColor Cyan

try {
    $nodeVersion = node -v 2>$null
    if (-not $nodeVersion) { throw }
    $majorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
    if ($majorVersion -lt 18) {
        Write-Host "❌ Node.js 18 이상이 필요합니다. 현재 버전: $nodeVersion" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Node.js $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js가 설치되어 있지 않습니다." -ForegroundColor Red
    Write-Host "   https://nodejs.org 에서 Node.js 18 이상을 설치해주세요."
    exit 1
}

try {
    $npmVersion = npm -v 2>$null
    if (-not $npmVersion) { throw }
    Write-Host "✅ npm $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ npm이 설치되어 있지 않습니다." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "   🔄 GitHub Projects Sync Worker 원클릭 설치" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 설정 정보:" -ForegroundColor Blue
Write-Host "   타입: $ProjectType" -ForegroundColor Green
Write-Host "   Owner: $OwnerName" -ForegroundColor Green
Write-Host "   Project #: $ProjectNumber" -ForegroundColor Green
Write-Host "   Worker 이름: $WorkerName" -ForegroundColor Green
if ($ProjectType -eq "user" -and $RepoOwner) {
    Write-Host "   대상 저장소: $RepoOwner/$RepoName" -ForegroundColor Green
}
Write-Host ""

# 임시 디렉토리 생성
$script:WorkDir = Join-Path $env:TEMP "projects-sync-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
Set-Location $script:WorkDir
Write-Host "[1/5] 📁 작업 디렉토리: $script:WorkDir" -ForegroundColor Yellow

# Labels를 JSON 배열로 변환
$LabelArray = $StatusLabels -split ','
$LabelsJson = ($LabelArray | ForEach-Object { "`"$($_.Trim())`"" }) -join ','
$LabelsJson = "[$LabelsJson]"

# wrangler.toml 생성
Write-Host "[2/5] 📝 설정 파일 생성 중..." -ForegroundColor Yellow

@"
name = "$WorkerName"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[vars]
PROJECT_NUMBER = "$ProjectNumber"
STATUS_FIELD = "Status"
STATUS_LABELS = '$LabelsJson'
ORG_NAME = "$OwnerName"
"@ | Out-File -FilePath "wrangler.toml" -Encoding utf8

# package.json 생성
@"
{
  "name": "github-projects-sync-worker",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "deploy": "wrangler deploy",
    "dev": "wrangler dev",
    "tail": "wrangler tail"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20240117.0",
    "typescript": "^5.3.3",
    "wrangler": "^3.22.1"
  }
}
"@ | Out-File -FilePath "package.json" -Encoding utf8

# tsconfig.json 생성
@"
{
  "compilerOptions": {
    "target": "ES2021",
    "module": "ESNext",
    "moduleResolution": "node",
    "lib": ["ES2021"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"]
}
"@ | Out-File -FilePath "tsconfig.json" -Encoding utf8

# Worker 코드 생성
New-Item -ItemType Directory -Path "src" -Force | Out-Null

$workerCode = @'
/**
 * GitHub Projects Sync Worker
 * Projects Status → Issue Label 동기화
 */

export interface Env {
  GITHUB_TOKEN: string;
  WEBHOOK_SECRET: string;
  PROJECT_NUMBER: string;
  STATUS_FIELD: string;
  STATUS_LABELS: string;
  ORG_NAME: string;
}

interface GitHubWebhookPayload {
  action: string;
  projects_v2_item?: {
    id: number;
    node_id: string;
    content_node_id: string;
    content_type: string;
  };
  changes?: {
    field_value?: {
      field_node_id: string;
      field_type: string;
    };
  };
  organization?: {
    login: string;
  };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'GET') {
      return new Response(JSON.stringify({
        status: 'ok',
        message: 'GitHub Projects Sync Worker is running',
        org: env.ORG_NAME,
        project: env.PROJECT_NUMBER
      }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    try {
      const signature = request.headers.get('X-Hub-Signature-256');
      const body = await request.text();

      if (!await verifySignature(body, signature, env.WEBHOOK_SECRET)) {
        console.log('Invalid signature');
        return new Response('Unauthorized', { status: 401 });
      }

      const payload: GitHubWebhookPayload = JSON.parse(body);

      if (payload.action !== 'edited' || !payload.projects_v2_item) {
        return new Response('Ignored', { status: 200 });
      }

      if (payload.projects_v2_item.content_type !== 'Issue' &&
          payload.projects_v2_item.content_type !== 'PullRequest') {
        return new Response('Not an Issue or PR', { status: 200 });
      }

      const contentNodeId = payload.projects_v2_item.content_node_id;
      const statusLabels: string[] = JSON.parse(env.STATUS_LABELS);

      const status = await getCurrentStatus(
        contentNodeId,
        parseInt(env.PROJECT_NUMBER),
        env.STATUS_FIELD,
        env.GITHUB_TOKEN
      );

      if (!status) {
        console.log('Status not found');
        return new Response('Status not found', { status: 200 });
      }

      console.log(`Current status: ${status}`);

      if (!statusLabels.includes(status)) {
        console.log(`Status "${status}" not in label list`);
        return new Response('Status not in label list', { status: 200 });
      }

      await syncLabel(contentNodeId, status, statusLabels, env.GITHUB_TOKEN);

      return new Response('OK', { status: 200 });
    } catch (error) {
      console.error('Error:', error);
      return new Response(`Error: ${error}`, { status: 500 });
    }
  }
};

async function verifySignature(
  payload: string,
  signature: string | null,
  secret: string
): Promise<boolean> {
  if (!signature) return false;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signatureBuffer = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(payload)
  );

  const expectedSignature = 'sha256=' + Array.from(new Uint8Array(signatureBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  return signature === expectedSignature;
}

async function getCurrentStatus(
  contentNodeId: string,
  projectNumber: number,
  statusField: string,
  token: string
): Promise<string | null> {
  const query = `
    query($nodeId: ID!) {
      node(id: $nodeId) {
        ... on Issue {
          projectItems(first: 10) {
            nodes {
              project {
                number
              }
              fieldValueByName(name: "${statusField}") {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                }
              }
            }
          }
        }
        ... on PullRequest {
          projectItems(first: 10) {
            nodes {
              project {
                number
              }
              fieldValueByName(name: "${statusField}") {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                }
              }
            }
          }
        }
      }
    }
  `;

  $response = Invoke-RestMethod -Uri 'https://api.github.com/graphql' -Method Post -Headers @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
    'User-Agent' = 'GitHub-Projects-Sync-Worker'
  } -Body (ConvertTo-Json @{ query = $query; variables = @{ nodeId = $contentNodeId } })

  const response = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    },
    body: JSON.stringify({ query, variables: { nodeId: contentNodeId } })
  });

  const data = await response.json() as any;

  const items = data.data?.node?.projectItems?.nodes || [];
  const targetItem = items.find((item: any) => item.project?.number === projectNumber);

  return targetItem?.fieldValueByName?.name || null;
}

async function syncLabel(
  contentNodeId: string,
  newStatus: string,
  statusLabels: string[],
  token: string
): Promise<void> {
  const infoQuery = `
    query($nodeId: ID!) {
      node(id: $nodeId) {
        ... on Issue {
          number
          repository {
            owner { login }
            name
          }
          labels(first: 100) {
            nodes { name }
          }
        }
        ... on PullRequest {
          number
          repository {
            owner { login }
            name
          }
          labels(first: 100) {
            nodes { name }
          }
        }
      }
    }
  `;

  const infoResponse = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    },
    body: JSON.stringify({ query: infoQuery, variables: { nodeId: contentNodeId } })
  });

  const infoData = await infoResponse.json() as any;
  const node = infoData.data?.node;

  if (!node) {
    console.log('Node not found');
    return;
  }

  const owner = node.repository.owner.login;
  const repo = node.repository.name;
  const issueNumber = node.number;
  const currentLabels = node.labels.nodes.map((l: any) => l.name);

  console.log(`Issue: ${owner}/${repo}#${issueNumber}`);
  console.log(`Current labels: ${currentLabels.join(', ')}`);

  const currentStatusLabel = currentLabels.find((l: string) => statusLabels.includes(l));

  if (currentStatusLabel === newStatus) {
    console.log(`Label already set to "${newStatus}", skipping`);
    return;
  }

  if (currentStatusLabel) {
    await removeLabel(owner, repo, issueNumber, currentStatusLabel, token);
  }

  await addLabel(owner, repo, issueNumber, newStatus, token);

  console.log(`Label updated to "${newStatus}"`);
}

async function removeLabel(
  owner: string,
  repo: string,
  issueNumber: number,
  label: string,
  token: string
): Promise<void> {
  const url = `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/labels/${encodeURIComponent(label)}`;

  await fetch(url, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${token}`,
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    }
  });
}

async function addLabel(
  owner: string,
  repo: string,
  issueNumber: number,
  label: string,
  token: string
): Promise<void> {
  const url = `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/labels`;

  await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    },
    body: JSON.stringify({ labels: [label] })
  });
}
'@

$workerCode | Out-File -FilePath "src/index.ts" -Encoding utf8

Write-Host "✅ 설정 파일 생성 완료" -ForegroundColor Green

# npm 설치
Write-Host "[3/5] 📦 의존성 설치 중..." -ForegroundColor Yellow
npm install --silent
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ npm install 실패" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 의존성 설치 완료" -ForegroundColor Green

# Cloudflare 로그인
Write-Host "[4/5] 🔐 Cloudflare 로그인 중..." -ForegroundColor Yellow
npx wrangler login
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 로그인 실패" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Cloudflare 로그인 완료" -ForegroundColor Green

# Worker 배포
Write-Host "[5/5] 🚀 Worker 배포 중..." -ForegroundColor Yellow
$DeploySuccess = $false
$WorkerUrl = ""

while (-not $DeploySuccess) {
    $DeployOutput = npx wrangler deploy 2>&1 | Out-String

    if ($DeployOutput -match "(https://[^\s]+\.workers\.dev)") {
        $WorkerUrl = $Matches[1]
        $DeploySuccess = $true
        Write-Host "✅ Worker 배포 완료" -ForegroundColor Green
    } else {
        Write-Host "❌ Worker 배포 실패" -ForegroundColor Red
        $DeployOutput | Select-Object -Last 5
        Write-Host ""
        $NewName = Read-Host "새 Worker 이름을 입력하세요 (q로 종료)"
        if ($NewName -eq "q") { exit 1 }
        if ($NewName) {
            (Get-Content wrangler.toml) -replace '^name = ".*"', "name = `"$NewName`"" | Set-Content wrangler.toml
        }
    }
}

# Secrets 설정 (환경변수로 전달된 값 사용, pipe 방식)
Write-Host ""
Write-Host "🔑 Secrets 설정" -ForegroundColor Cyan
Write-Host "GITHUB_TOKEN 설정 중..." -ForegroundColor Yellow
$GithubToken | npx wrangler secret put GITHUB_TOKEN
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ GITHUB_TOKEN 설정 완료" -ForegroundColor Green
} else {
    Write-Host "❌ GITHUB_TOKEN 설정 실패" -ForegroundColor Red
    exit 1
}
Write-Host "WEBHOOK_SECRET 설정 중..." -ForegroundColor Yellow
$WebhookSecret | npx wrangler secret put WEBHOOK_SECRET
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ WEBHOOK_SECRET 설정 완료" -ForegroundColor Green
} else {
    Write-Host "❌ WEBHOOK_SECRET 설정 실패" -ForegroundColor Red
    exit 1
}

# Webhook URL 결정
if ($ProjectType -eq "org") {
    $WebhookSettingsUrl = "https://github.com/organizations/$OwnerName/settings/hooks"
} elseif ($ProjectType -eq "user" -and $RepoOwner -and $RepoName) {
    $WebhookSettingsUrl = "https://github.com/$RepoOwner/$RepoName/settings/hooks"
} else {
    $WebhookSettingsUrl = "(저장소 설정에서 Webhook 추가)"
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🎉 설치 완료!" -ForegroundColor Green
Write-Host ""
Write-Host "📌 Worker URL: $WorkerUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 다음 단계: GitHub Webhook 설정" -ForegroundColor Blue
Write-Host "   1. Webhook 설정 페이지:"
Write-Host "      $WebhookSettingsUrl" -ForegroundColor Cyan
Write-Host "   2. 'Add webhook' 클릭"
Write-Host "   3. 설정 입력:"
Write-Host "      - Payload URL: $WorkerUrl" -ForegroundColor Cyan
Write-Host "      - Content type: application/json"
Write-Host "      - Secret: (마법사에서 생성된 값)"
Write-Host "   4. Events: 'Let me select individual events' → 'Project v2 items' 선택" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# 작업 디렉토리는 finally 블록에서 자동 정리됨

} finally {
    # 스크립트 종료 시 자동 정리 (정상 종료, 에러, Ctrl+C 모두 포함)
    Cleanup-OnExit
}
