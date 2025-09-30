#!/bin/bash

# ===================================================================
# GitHub 템플릿 초기화 스크립트 v1.0.0
# ===================================================================
#
# 이 스크립트는 GitHub 템플릿을 통해 새 프로젝트가 생성될 때
# 자동으로 실행되어 프로젝트를 초기 상태로 설정합니다.
#
# 주요 기능:
# 1. version.yml을 기본 상태(0.0.0, basic)로 초기화
# 2. CHANGELOG.md, CHANGELOG.json 파일 삭제
# 3. README.md를 기본 템플릿으로 초기화
# 4. 이슈 템플릿의 assignee를 현재 저장소 소유자로 변경
# 5. 초기화 완료 마커 파일 생성
#
# 사용법:
# ./template_initializer.sh [프로젝트명] [GitHub사용자명]
#
# ===================================================================

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 파라미터 확인
PROJECT_NAME="${1:-새로운 프로젝트}"
GITHUB_USER="${2:-사용자}"
REPO_OWNER="${GITHUB_REPOSITORY%/*}"

log_info "템플릿 초기화 시작..."
log_info "프로젝트명: $PROJECT_NAME"
log_info "GitHub 사용자: $GITHUB_USER"
log_info "저장소 소유자: $REPO_OWNER"

# 1. version.yml 초기화
log_info "version.yml 파일 초기화 중..."
cat > version.yml << EOF
# ===================================================================
# 프로젝트 버전 관리 파일
# ===================================================================
#
# 이 파일은 다양한 프로젝트 타입에서 버전 정보를 중앙 관리하기 위한 파일
# GitHub Actions 워크플로우가 이 파일을 읽어 자동으로 버전을 관리
#
# 사용법:
# 1. version: "0.0.0"
# 2. project_type: 프로젝트 타입 지정
#
# 자동 버전 업데이트:
# - patch: 자동으로 세 번째 자리 증가 (x.x.x -> x.x.x+1)
# - minor/major: 수동으로 직접 수정 필요
#
# 프로젝트 타입별 동기화 파일:
# - spring: build.gradle (version = "x.y.z")
# - flutter: pubspec.yaml (version: "0.0.0"
# - react/node: package.json ("version": "x.y.z")
# - react-native: iOS Info.plist 또는 Android build.gradle
# - react-native-expo: app.json (expo.version)
# - basic/기타: version.yml 파일만 사용
#
# 주의사항:
# - project_type은 최초 설정 후 변경하지 마세요
# - 버전은 항상 높은 버전으로 자동 동기화됩니다
# ===================================================================

version: "0.0.0"
project_type: "basic" # spring, flutter, react, react-native, react-native-expo, node, basic
metadata:
  last_updated: "$(date -u +"%Y-%m-%d %H:%M:%S")"
  last_updated_by: "$GITHUB_USER"
EOF

log_success "version.yml 파일이 초기화되었습니다."

# 2. CHANGELOG 파일들 삭제
log_info "기존 CHANGELOG 파일들 삭제 중..."
if [ -f "CHANGELOG.md" ]; then
    rm -f CHANGELOG.md
    log_success "CHANGELOG.md 파일이 삭제되었습니다."
fi

if [ -f "CHANGELOG.json" ]; then
    rm -f CHANGELOG.json
    log_success "CHANGELOG.json 파일이 삭제되었습니다."
fi

# 3. README.md 초기화
log_info "README.md 파일 초기화 중..."
cat > README.md << EOF
# $PROJECT_NAME
<br>
<!-- 수정하지마세요 자동으로 동기화 됩니다 -->
## 최신 버전 : v0.0.0
<br>
[전체 버전 기록 보기](CHANGELOG.md)
<br>

## 📋 프로젝트 소개

이 프로젝트에 대한 설명을 작성해주세요.

## 🚀 시작하기

### 필수 조건

- 필요한 소프트웨어나 도구들을 나열해주세요

### 설치

\`\`\`bash
# 설치 명령어를 작성해주세요
\`\`\`

### 사용법

\`\`\`bash
# 사용 예시를 작성해주세요
\`\`\`

## 🤝 기여하기

기여 방법에 대한 설명을 작성해주세요.

## 📄 라이선스

이 프로젝트의 라이선스 정보를 작성해주세요.

## 📞 연락처

- 작성자: $GITHUB_USER
- 이메일: your.email@example.com
- 프로젝트 링크: [https://github.com/$REPO_OWNER/$PROJECT_NAME](https://github.com/$REPO_OWNER/$PROJECT_NAME)
EOF

log_success "README.md 파일이 초기화되었습니다."

# 4. 이슈 템플릿 assignee 업데이트
log_info "이슈 템플릿 assignee 업데이트 중..."

# bug_report.md 업데이트
if [ -f ".github/ISSUE_TEMPLATE/bug_report.md" ]; then
    sed -i "s/assignees: \[Cassiiopeia\]/assignees: [$REPO_OWNER]/" .github/ISSUE_TEMPLATE/bug_report.md
    log_success "bug_report.md의 assignee가 업데이트되었습니다."
fi

# design_request.md 업데이트
if [ -f ".github/ISSUE_TEMPLATE/design_request.md" ]; then
    sed -i "s/assignees: \[Cassiiopeia\]/assignees: [$REPO_OWNER]/" .github/ISSUE_TEMPLATE/design_request.md
    log_success "design_request.md의 assignee가 업데이트되었습니다."
fi

# feature_request.md 업데이트
if [ -f ".github/ISSUE_TEMPLATE/feature_request.md" ]; then
    sed -i "s/assignees: \[Cassiiopeia\]/assignees: [$REPO_OWNER]/" .github/ISSUE_TEMPLATE/feature_request.md
    log_success "feature_request.md의 assignee가 업데이트되었습니다."
fi

# 5. 초기화 완료 기록 (README.md에 주석으로 추가)
log_info "초기화 완료 기록 추가 중..."
echo "" >> README.md
echo "<!-- 템플릿 초기화 완료: $(date -u +"%Y-%m-%d %H:%M:%S UTC") -->" >> README.md

log_success "초기화 완료 기록이 README.md에 추가되었습니다."

# 6. 초기화 완료 요약
echo ""
log_success "🎉 템플릿 초기화가 완료되었습니다!"
echo ""
log_info "초기화된 항목:"
echo "  ✅ version.yml → 0.0.0, basic 타입으로 초기화"
echo "  ✅ CHANGELOG.md, CHANGELOG.json → 삭제됨"
echo "  ✅ README.md → 기본 템플릿으로 초기화"
echo "  ✅ 이슈 템플릿 assignee → $REPO_OWNER로 변경"
echo "  ✅ 초기화 완료 기록 추가"
echo ""
log_info "다음 단계:"
echo "  1. 프로젝트 타입에 맞게 version.yml의 project_type을 변경하세요"
echo "  2. README.md를 프로젝트에 맞게 수정하세요"
echo "  3. 첫 번째 커밋을 푸시하여 자동화 시스템을 테스트하세요"
echo ""
log_warning "주의: 템플릿 초기화 워크플로우는 일회성으로 실행 후 자동 삭제됩니다."
