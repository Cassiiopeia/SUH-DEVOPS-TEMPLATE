#!/bin/bash
# ============================================
# GitHub Projects Sync Wizard - 원클릭 설치 스크립트
#
# ⚠️ Organization Projects 전용
#    (User Projects는 GitHub API 제한으로 미지원)
#
# ⚠️ 사전 요구사항:
#   - Node.js 18.0.0 이상 (node -v로 확인)
#   - npm (Node.js와 함께 설치됨)
#   - Cloudflare 계정
#
# 사용법 (마법사에서 생성된 명령어):
# curl -fsSL https://raw.githubusercontent.com/.../projects-sync-wizard-setup.sh | bash -s -- \
#   --owner "ORG_NAME" \
#   --project "1" \
#   --worker-name "my-worker" \
#   --webhook-secret "abc123" \
#   --github-token "ghp_xxxx..." \
#   --labels "작업 전,작업 중,완료"
# ============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 기본값 (Organization Projects 전용)
OWNER_NAME=""
PROJECT_NUMBER=""
WORKER_NAME="github-projects-sync-worker"
WEBHOOK_SECRET=""
STATUS_LABELS=""
GITHUB_TOKEN=""
WORK_DIR=""

# 임시 디렉토리 자동 정리 함수
cleanup_on_exit() {
    local exit_code=$?
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        echo ""
        echo -e "${YELLOW}🧹 임시 디렉토리 정리 중...${NC}"
        cd ~ 2>/dev/null || cd /tmp
        rm -rf "$WORK_DIR" 2>/dev/null || true
        echo -e "${GREEN}✅ 임시 디렉토리 삭제 완료${NC}"
    fi
    exit $exit_code
}

# 스크립트 종료 시 자동 정리 (정상 종료, 에러, 인터럽트 모두 포함)
trap cleanup_on_exit EXIT ERR INT TERM

# 인자 파싱 (Organization Projects 전용)
while [[ $# -gt 0 ]]; do
    case $1 in
        --owner)
            OWNER_NAME="$2"
            shift 2
            ;;
        --project)
            PROJECT_NUMBER="$2"
            shift 2
            ;;
        --worker-name)
            WORKER_NAME="$2"
            shift 2
            ;;
        --webhook-secret)
            WEBHOOK_SECRET="$2"
            shift 2
            ;;
        --labels)
            STATUS_LABELS="$2"
            shift 2
            ;;
        --github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --type)
            # 하위 호환성: --type 옵션은 무시 (Organization 전용)
            shift 2
            ;;
        --repo-owner|--repo-name)
            # 하위 호환성: User 관련 옵션은 무시
            shift 2
            ;;
        *)
            echo -e "${RED}알 수 없는 옵션: $1${NC}"
            exit 1
            ;;
    esac
done

# 필수 인자 확인
if [ -z "$OWNER_NAME" ] || [ -z "$PROJECT_NUMBER" ] || [ -z "$WEBHOOK_SECRET" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}❌ 필수 인자가 누락되었습니다.${NC}"
    echo "필수: --owner, --project, --webhook-secret, --github-token"
    exit 1
fi

# Worker 이름 Cloudflare 규칙 준수 (소문자, 숫자, 하이픈만)
WORKER_NAME=$(echo "$WORKER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g')

# Node.js 버전 확인
echo ""
echo -e "${CYAN}🔍 사전 요구사항 확인 중...${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js가 설치되어 있지 않습니다.${NC}"
    echo -e "   https://nodejs.org 에서 Node.js 18 이상을 설치해주세요."
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo -e "${RED}❌ Node.js 18 이상이 필요합니다. 현재 버전: $(node -v)${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Node.js $(node -v)${NC}"

if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm이 설치되어 있지 않습니다.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ npm $(npm -v)${NC}"

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq가 설치되어 있지 않습니다. 설치 중...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq 2>/dev/null || {
            echo -e "${RED}❌ jq 설치 실패. brew install jq 로 수동 설치해주세요.${NC}"
            exit 1
        }
    else
        sudo apt-get install -y jq 2>/dev/null || sudo yum install -y jq 2>/dev/null || {
            echo -e "${RED}❌ jq 설치 실패. 수동으로 설치해주세요.${NC}"
            exit 1
        }
    fi
fi
echo -e "${GREEN}✅ jq $(jq --version)${NC}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🔄 GitHub Projects Sync Worker 원클릭 설치${NC}"
echo -e "${CYAN}   (Organization Projects 전용)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}📋 설정 정보:${NC}"
echo -e "   Organization: ${GREEN}$OWNER_NAME${NC}"
echo -e "   Project #: ${GREEN}$PROJECT_NUMBER${NC}"
echo -e "   Worker 이름: ${GREEN}$WORKER_NAME${NC}"
echo ""

# 임시 디렉토리 생성
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"
echo -e "${YELLOW}[1/5]${NC} 📁 작업 디렉토리: $WORK_DIR"

# Labels를 JSON 배열로 변환 (compact - 한 줄 출력)
IFS=',' read -ra LABEL_ARRAY <<< "$STATUS_LABELS"
LABELS_JSON=$(printf '%s\n' "${LABEL_ARRAY[@]}" | jq -R . | jq -sc .)

# wrangler.toml 생성
echo -e "${YELLOW}[2/5]${NC} 📝 설정 파일 생성 중..."
cat > wrangler.toml << EOF
name = "$WORKER_NAME"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[vars]
PROJECT_NUMBER = "$PROJECT_NUMBER"
STATUS_FIELD = "Status"
STATUS_LABELS = '$LABELS_JSON'
ORG_NAME = "$OWNER_NAME"
EOF

# package.json 생성
cat > package.json << 'PACKAGE_EOF'
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
PACKAGE_EOF

# tsconfig.json 생성
cat > tsconfig.json << 'TSCONFIG_EOF'
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
TSCONFIG_EOF

# Worker 코드 생성
mkdir -p src
cat > src/index.ts << 'WORKER_EOF'
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
WORKER_EOF

echo -e "${GREEN}✅ 설정 파일 생성 완료${NC}"

# npm 설치
echo -e "${YELLOW}[3/5]${NC} 📦 의존성 설치 중..."
npm config set strict-ssl false 2>/dev/null || true
npm install --silent && echo -e "${GREEN}✅ 의존성 설치 완료${NC}" || {
    echo -e "${RED}❌ npm install 실패${NC}"
    exit 1
}
npm config set strict-ssl true 2>/dev/null || true

# Cloudflare 로그인
echo -e "${YELLOW}[4/5]${NC} 🔐 Cloudflare 로그인 중..."
export NODE_TLS_REJECT_UNAUTHORIZED=0
npx wrangler login && echo -e "${GREEN}✅ Cloudflare 로그인 완료${NC}" || {
    echo -e "${RED}❌ 로그인 실패${NC}"
    exit 1
}

# Worker 배포
echo -e "${YELLOW}[5/5]${NC} 🚀 Worker 배포 중..."
DEPLOY_SUCCESS=false
WORKER_URL=""

while [ "$DEPLOY_SUCCESS" = false ]; do
    DEPLOY_OUTPUT=$(npx wrangler deploy 2>&1) || true

    if echo "$DEPLOY_OUTPUT" | grep -q "https://.*workers.dev"; then
        WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -o 'https://[^[:space:]]*workers.dev' | head -1)
        DEPLOY_SUCCESS=true
        echo -e "${GREEN}✅ Worker 배포 완료${NC}"
    else
        echo -e "${RED}❌ Worker 배포 실패${NC}"
        echo "$DEPLOY_OUTPUT" | tail -5
        echo ""
        echo -e "새 Worker 이름을 입력하세요 (q로 종료):"
        read -r NEW_NAME
        [ "$NEW_NAME" = "q" ] && exit 1
        if [ -n "$NEW_NAME" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/^name = \".*\"/name = \"$NEW_NAME\"/" wrangler.toml
            else
                sed -i "s/^name = \".*\"/name = \"$NEW_NAME\"/" wrangler.toml
            fi
        fi
    fi
done

# Secrets 설정 (인자로 전달된 값 사용, pipe 방식)
echo ""
echo -e "${CYAN}🔑 Secrets 설정${NC}"
echo -e "${YELLOW}GITHUB_TOKEN 설정 중...${NC}"
echo "$GITHUB_TOKEN" | npx wrangler secret put GITHUB_TOKEN 2>/dev/null && echo -e "${GREEN}✅ GITHUB_TOKEN 설정 완료${NC}" || {
    echo -e "${RED}❌ GITHUB_TOKEN 설정 실패${NC}"
    exit 1
}
echo -e "${YELLOW}WEBHOOK_SECRET 설정 중...${NC}"
echo "$WEBHOOK_SECRET" | npx wrangler secret put WEBHOOK_SECRET 2>/dev/null && echo -e "${GREEN}✅ WEBHOOK_SECRET 설정 완료${NC}" || {
    echo -e "${RED}❌ WEBHOOK_SECRET 설정 실패${NC}"
    exit 1
}

# Webhook URL (Organization Webhook 전용) - /new 추가로 바로 생성 페이지로 이동
WEBHOOK_SETTINGS_URL="https://github.com/organizations/$OWNER_NAME/settings/hooks/new"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 설치 완료!${NC}"
echo ""
echo -e "📌 ${BLUE}Worker URL:${NC} ${CYAN}$WORKER_URL${NC}"
echo ""
echo -e "${BLUE}📋 다음 단계: GitHub Webhook 설정${NC}"
echo -e "   1. Webhook 생성 페이지 열기:"
echo -e "      ${CYAN}$WEBHOOK_SETTINGS_URL${NC}"
echo -e "   2. 설정 입력:"
echo -e "      - Payload URL: ${CYAN}$WORKER_URL${NC}"
echo -e "      - Content type: application/json"
echo -e "      - Secret: ${CYAN}$WEBHOOK_SECRET${NC}"
echo -e "   3. Events: 'Let me select individual events' → ${GREEN}'Project v2 items'${NC} 선택"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 작업 디렉토리는 trap으로 자동 정리됨
