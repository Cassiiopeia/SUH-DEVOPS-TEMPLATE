#!/bin/bash
# ============================================
# GitHub Projects Sync Worker 설치 스크립트
#
# 사용법: ./projects-sync-worker-setup.sh
#
# 이 스크립트는 다음을 자동으로 수행합니다:
# 1. npm 의존성 설치 (SSL 오류 대응)
# 2. Cloudflare 로그인 (브라우저 자동 오픈)
# 3. Worker 배포 (이름 충돌 시 재입력 가능)
# 4. Secrets 설정 (GITHUB_TOKEN, WEBHOOK_SECRET)
# ============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로고 출력
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🔄 GitHub Projects Sync Worker 설치 스크립트${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# config.json 확인
if [ ! -f "config.json" ]; then
    echo -e "${RED}❌ config.json 파일을 찾을 수 없습니다.${NC}"
    echo -e "   마법사에서 다운로드한 ZIP 파일을 먼저 압축 해제하세요."
    exit 1
fi

# config.json 읽기
ORG_NAME=$(cat config.json | grep -o '"orgName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
WORKER_NAME=$(cat config.json | grep -o '"workerName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
WEBHOOK_SECRET=$(cat config.json | grep -o '"webhookSecret"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)

echo -e "${BLUE}📋 설정 정보:${NC}"
echo -e "   Organization: ${GREEN}$ORG_NAME${NC}"
echo -e "   Worker 이름: ${GREEN}$WORKER_NAME${NC}"
echo ""

# ============================================
# Step 1: npm 의존성 설치
# ============================================
echo -e "${YELLOW}[1/4]${NC} 📦 의존성 설치 중..."

# SSL 오류 대응
npm config set strict-ssl false 2>/dev/null || true

if npm install; then
    echo -e "${GREEN}✅ 의존성 설치 완료${NC}"
else
    echo -e "${RED}❌ npm install 실패${NC}"
    echo -e "   다음 명령어를 수동으로 실행해보세요:"
    echo -e "   ${CYAN}npm config set strict-ssl false && npm install${NC}"
    exit 1
fi

# SSL 설정 복원
npm config set strict-ssl true 2>/dev/null || true

echo ""

# ============================================
# Step 2: Cloudflare 로그인
# ============================================
echo -e "${YELLOW}[2/4]${NC} 🔐 Cloudflare 로그인 중..."
echo -e "   ${CYAN}브라우저가 열리면 로그인하세요.${NC}"

# SSL 오류 대응 (환경 변수)
export NODE_TLS_REJECT_UNAUTHORIZED=0

if npx wrangler login; then
    echo -e "${GREEN}✅ Cloudflare 로그인 완료${NC}"
else
    echo -e "${RED}❌ Cloudflare 로그인 실패${NC}"
    echo -e "   다음 명령어를 수동으로 실행해보세요:"
    echo -e "   ${CYAN}export NODE_TLS_REJECT_UNAUTHORIZED=0 && npx wrangler login${NC}"
    exit 1
fi

echo ""

# ============================================
# Step 3: Worker 배포 (이름 충돌 시 재시도)
# ============================================
echo -e "${YELLOW}[3/4]${NC} 🚀 Worker 배포 중..."

DEPLOY_SUCCESS=false
WORKER_URL=""

while [ "$DEPLOY_SUCCESS" = false ]; do
    # 배포 시도
    DEPLOY_OUTPUT=$(npx wrangler deploy 2>&1) || true

    # 성공 여부 확인
    if echo "$DEPLOY_OUTPUT" | grep -q "https://.*workers.dev"; then
        WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -o 'https://[^[:space:]]*workers.dev' | head -1)
        DEPLOY_SUCCESS=true
        echo -e "${GREEN}✅ Worker 배포 완료${NC}"
        echo -e "   URL: ${CYAN}$WORKER_URL${NC}"
    else
        # 실패 원인 출력
        echo -e "${RED}❌ Worker 배포 실패${NC}"
        echo ""
        echo -e "${YELLOW}에러 내용:${NC}"
        echo "$DEPLOY_OUTPUT" | tail -10
        echo ""

        # 서브도메인 충돌 확인
        if echo "$DEPLOY_OUTPUT" | grep -qi "subdomain\|unavailable\|already\|conflict"; then
            echo -e "${YELLOW}💡 서브도메인이 이미 사용 중일 수 있습니다.${NC}"
        fi

        echo ""
        echo -e "새 Worker 이름을 입력하세요 (또는 Enter로 다시 시도, 'q'로 종료):"
        read -r NEW_WORKER_NAME

        if [ "$NEW_WORKER_NAME" = "q" ] || [ "$NEW_WORKER_NAME" = "Q" ]; then
            echo -e "${YELLOW}설치를 종료합니다.${NC}"
            exit 1
        fi

        if [ -n "$NEW_WORKER_NAME" ]; then
            # wrangler.toml 수정
            if [ -f "wrangler.toml" ]; then
                sed -i.bak "s/^name = \".*\"/name = \"$NEW_WORKER_NAME\"/" wrangler.toml
                rm -f wrangler.toml.bak
                echo -e "${GREEN}✅ Worker 이름을 '$NEW_WORKER_NAME'으로 변경했습니다.${NC}"

                # config.json도 업데이트
                if [ -f "config.json" ]; then
                    sed -i.bak "s/\"workerName\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"workerName\": \"$NEW_WORKER_NAME\"/" config.json
                    rm -f config.json.bak
                fi
            fi
        fi

        echo -e "${BLUE}다시 배포를 시도합니다...${NC}"
        echo ""
    fi
done

echo ""

# ============================================
# Step 4: Secrets 설정
# ============================================
echo -e "${YELLOW}[4/4]${NC} 🔑 Secrets 설정 중..."

# GITHUB_TOKEN 설정
echo ""
echo -e "${CYAN}GitHub Personal Access Token을 입력하세요.${NC}"
echo -e "필요한 권한: ${GREEN}repo${NC}, ${GREEN}project${NC} (read:project, write:project)"
echo -e "토큰 생성: https://github.com/settings/tokens/new"
echo ""

if npx wrangler secret put GITHUB_TOKEN; then
    echo -e "${GREEN}✅ GITHUB_TOKEN 설정 완료${NC}"
else
    echo -e "${RED}❌ GITHUB_TOKEN 설정 실패${NC}"
    echo -e "   나중에 수동으로 설정하세요: ${CYAN}npx wrangler secret put GITHUB_TOKEN${NC}"
fi

echo ""

# WEBHOOK_SECRET 설정
echo -e "${CYAN}Webhook Secret 설정 중...${NC}"
echo -e "config.json에 저장된 값을 사용합니다: ${GREEN}${WEBHOOK_SECRET:0:8}...${NC}"
echo ""

# 자동으로 WEBHOOK_SECRET 설정
echo "$WEBHOOK_SECRET" | npx wrangler secret put WEBHOOK_SECRET 2>/dev/null && \
    echo -e "${GREEN}✅ WEBHOOK_SECRET 설정 완료${NC}" || \
    {
        echo -e "${YELLOW}⚠️ 자동 설정 실패. 수동으로 입력해주세요.${NC}"
        npx wrangler secret put WEBHOOK_SECRET
    }

echo ""

# ============================================
# 완료
# ============================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 설치 완료!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📌 ${YELLOW}Worker URL:${NC} ${CYAN}$WORKER_URL${NC}"
echo ""
echo -e "${BLUE}📋 다음 단계: GitHub Webhook 설정${NC}"
echo ""
echo "   1. Organization Settings → Webhooks 이동"
echo -e "      ${CYAN}https://github.com/organizations/$ORG_NAME/settings/hooks${NC}"
echo ""
echo "   2. 'Add webhook' 클릭"
echo ""
echo "   3. 다음 정보 입력:"
echo -e "      • Payload URL: ${GREEN}$WORKER_URL${NC}"
echo "      • Content type: application/json"
echo -e "      • Secret: ${GREEN}${WEBHOOK_SECRET:0:8}...${NC} (config.json 참조)"
echo ""
echo "   4. Events 선택:"
echo "      • 'Let me select individual events' 클릭"
echo -e "      • ${GREEN}'Project v2 items'${NC} 체크"
echo ""
echo "   5. 'Add webhook' 클릭"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "💡 ${YELLOW}Webhook Secret 전체값:${NC}"
echo -e "   ${GREEN}$WEBHOOK_SECRET${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
