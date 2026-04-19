#!/bin/bash

# ===================================================================
# GitHub 템플릿 초기화 스크립트
# ===================================================================
#
# 이 스크립트는 GitHub 템플릿을 통해 새 프로젝트가 생성될 때
# 수동으로 실행하여 프로젝트를 초기 상태로 설정합니다.
#
# 주요 기능:
# 1. version.yml을 지정된 버전과 타입으로 초기화
# 2. default_branch 자동 감지 및 설정
# 3. 워크플로우 트리거 브랜치 자동 변경
# 4. CHANGELOG.md, CHANGELOG.json 파일 삭제
# 5. README.md를 기본 템플릿으로 초기화
# 6. 이슈 템플릿의 assignee를 현재 저장소 소유자로 변경
#
# 사용법:
# ./template_initializer.sh [옵션]
#
# 옵션:
#   -v, --version VERSION    초기 버전 설정 (기본: 0.0.0)
#   -t, --type TYPE          프로젝트 타입 (기본: basic)
#                            지원: spring, flutter, react, react-native,
#                                  react-native-expo, node, python, basic
#   -h, --help               도움말 표시
#
# 예시:
#   ./template_initializer.sh --version 1.0.0 --type spring
#   ./template_initializer.sh -v 1.0.0 -t python
#
# ===================================================================

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 출력 함수 (stderr로 출력하여 변수 캡처와 분리)
print_step() {
    echo -e "${CYAN}▶${NC} $1" >&2
}

print_info() {
    echo -e "  ${BLUE}→${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}✓${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# 도움말 표시
show_help() {
    cat << EOF
${CYAN}GitHub 템플릿 초기화 스크립트${NC}

${BLUE}사용법:${NC}
  ./template_initializer.sh [옵션]

${BLUE}옵션:${NC}
  -v, --version VERSION    초기 버전 설정 (기본: 0.0.0)
  -t, --type TYPE          프로젝트 타입 (기본: basic)
                           지원 타입:
                             • spring          - Spring Boot 백엔드
                             • flutter         - Flutter 모바일 앱
                             • next            - Next.js 웹 앱
                             • react           - React 웹 앱
                             • react-native    - React Native 모바일 앱
                             • react-native-expo - React Native Expo 앱
                             • node            - Node.js 프로젝트
                             • python          - Python 프로젝트
                             • basic           - 기본 (프레임워크 없음)
  -h, --help               이 도움말 표시

${BLUE}사용 예시:${NC}
  # 기본 초기화 (버전 0.0.0, 타입 basic)
  ./template_initializer.sh

  # Spring Boot 프로젝트로 버전 1.0.0으로 초기화
  ./template_initializer.sh --version 1.0.0 --type spring

  # Python 프로젝트로 초기화
  ./template_initializer.sh -v 1.0.0 -t python

  # 짧은 형식
  ./template_initializer.sh -v 2.0.0 -t react

${BLUE}초기화 작업:${NC}
  1. Default 브랜치 자동 감지 (main/master 등)
  2. version.yml 생성 (버전, 타입, default_branch 설정)
  3. 워크플로우 트리거 브랜치 자동 변경
  4. CHANGELOG 파일 삭제
  5. LICENSE, CONTRIBUTING.md 삭제
  6. 테스트 폴더 삭제
  7. README.md 초기화
  8. 이슈 템플릿 assignee 변경

EOF
}

# 기본값 설정
VERSION="0.0.0"
PROJECT_TYPE="basic"
GITHUB_USER="${GITHUB_ACTOR:-$(whoami)}"
REPO_OWNER="${GITHUB_REPOSITORY%/*}"

# 지원하는 프로젝트 타입
VALID_TYPES=("spring" "flutter" "next" "react" "react-native" "react-native-expo" "node" "python" "basic")

# 템플릿 버전 (version.yml에서 읽어옴)
get_template_version() {
    local version_file="version.yml"
    if [ -f "$version_file" ]; then
        grep '^version:' "$version_file" | sed 's/version:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d ' '
    else
        echo "unknown"
    fi
}

TEMPLATE_VERSION=$(get_template_version)

# 파라미터 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "알 수 없는 옵션: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# 버전 형식 검증
validate_version() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "잘못된 버전 형식: $1"
        print_error "올바른 형식: x.y.z (예: 1.0.0, 2.1.3)"
        exit 1
    fi
}

# 프로젝트 타입 검증
validate_project_type() {
    local type=$1
    local valid=false
    
    for valid_type in "${VALID_TYPES[@]}"; do
        if [ "$type" = "$valid_type" ]; then
            valid=true
            break
        fi
    done
    
    if [ "$valid" = false ]; then
        print_error "지원하지 않는 프로젝트 타입: $type"
        print_error "지원 타입: ${VALID_TYPES[*]}"
        exit 1
    fi
}

# Default branch 자동 감지
detect_default_branch() {
    local detected=""
    
    print_step "Default branch 자동 감지 중..."
    
    # 방법 1: GitHub CLI
    if command -v gh >/dev/null 2>&1; then
        detected=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")
        if [ -n "$detected" ]; then
            print_info "gh CLI로 감지: $detected"
            echo "$detected"
            return
        fi
    fi
    
    # 방법 2: git symbolic-ref
    detected=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
    if [ -n "$detected" ]; then
        print_info "git symbolic-ref로 감지: $detected"
        echo "$detected"
        return
    fi
    
    # 방법 3: git remote show
    detected=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | sed 's/.*: //' || echo "")
    if [ -n "$detected" ]; then
        print_info "git remote show로 감지: $detected"
        echo "$detected"
        return
    fi
    
    # 최종 폴백
    print_warning "자동 감지 실패, 기본값 사용: main"
    echo "main"
}

# version.yml 생성
create_version_yml() {
    local version=$1
    local type=$2
    local branch=$3
    local user=$4
    
    print_step "version.yml 파일 생성 중..."
    print_info "버전: $version"
    print_info "타입: $type"
    print_info "브랜치: $branch"
    print_info "사용자: $user"
    
    cat > version.yml << EOF
# ===================================================================
# 프로젝트 버전 관리 파일
# ===================================================================
#
# 이 파일은 다양한 프로젝트 타입에서 버전 정보를 중앙 관리하기 위한 파일
# GitHub Actions 워크플로우가 이 파일을 읽어 자동으로 버전을 관리
#
# 사용법:
# 1. version: "1.0.0" - 사용자에게 표시되는 버전
# 2. version_code: 1 - Play Store/App Store 빌드 번호 (1부터 자동 증가)
# 3. project_type: 프로젝트 타입 지정
#
# 자동 버전 업데이트:
# - patch: 자동으로 세 번째 자리 증가 (x.x.x -> x.x.x+1)
# - version_code: 매 빌드마다 자동으로 1씩 증가
# - minor/major: 수동으로 직접 수정 필요
#
# 프로젝트 타입별 동기화 파일:
# - spring: build.gradle (version = "x.y.z")
# - flutter: pubspec.yaml (version: x.y.z+i, buildNumber 포함)
# - react/next/node: package.json ("version": "x.y.z")
# - react-native: iOS Info.plist 또는 Android build.gradle
# - react-native-expo: app.json (expo.version)
# - python: pyproject.toml (version = "x.y.z")
# - basic/기타: version.yml 파일만 사용
#
# 주의사항:
# - project_type은 최초 설정 후 변경하지 마세요
# - 버전은 항상 높은 버전으로 자동 동기화됩니다
# ===================================================================

version: "$version"
version_code: 1  # app build number
project_type: "$type" # spring, flutter, next, react, react-native, react-native-expo, node, python, basic
metadata:
  last_updated: "$(date -u +"%Y-%m-%d %H:%M:%S")"
  last_updated_by: "$user"
  default_branch: "$branch"
  template:
    source: "SUH-DEVOPS-TEMPLATE"
    version: "$TEMPLATE_VERSION"
    initialized_date: "$(date -u +"%Y-%m-%d")"
EOF

    print_success "version.yml 파일이 생성되었습니다."
}

# 워크플로우 트리거 브랜치 변경
# 
# 동작 방식:
# - Default branch가 "main"인 경우: 모든 워크플로우가 기본적으로 main을 사용하므로 변경 불필요
# - Default branch가 "main"이 아닌 경우: main 브랜치를 트리거로 사용하는 워크플로우만 변경
#
# 화이트리스트 방식:
# - main 브랜치를 트리거로 사용하는 워크플로우를 명시적으로 지정
# - deploy 브랜치 전용 워크플로우는 변경하지 않음
# - 새로운 main 트리거 워크플로우 추가 시 MAIN_BRANCH_WORKFLOWS 배열에 추가 필요
#
# 참고: 
# - 이 함수는 템플릿 초기화 시에만 실행됩니다.
# - 임시 파일 방식으로 macOS (BSD sed) / Linux (GNU sed) 모두 호환됩니다.
update_workflow_triggers() {
    local branch=$1
    
    # main 브랜치면 변경 불필요 (워크플로우 기본값이 main이므로)
    if [ "$branch" = "main" ]; then
        print_info "브랜치가 main이므로 워크플로우 변경 불필요"
        print_info "모든 워크플로우는 기본적으로 main 브랜치를 트리거로 사용합니다"
        return
    fi
    
    print_step "워크플로우 트리거 브랜치 변경 중: main → $branch"
    
    # main 브랜치를 트리거로 사용하는 워크플로우만 명시적으로 지정
    # (deploy 브랜치 전용 워크플로우는 포함하지 않음)
    local MAIN_BRANCH_WORKFLOWS=(
        "PROJECT-VERSION-CONTROL.yaml"
    )
    
    local updated=0
    
    for workflow in "${MAIN_BRANCH_WORKFLOWS[@]}"; do
        local file=".github/workflows/$workflow"
        
        if [ -f "$file" ]; then
            # main 브랜치 트리거를 감지된 브랜치로 변경 (임시 파일 사용, macOS/Linux 호환)
            if grep -q 'branches: \["main"\]' "$file"; then
                sed "s/branches: \\[\"main\"\\]/branches: [\"$branch\"]/" "$file" > "$file.tmp"
                mv "$file.tmp" "$file"
                echo "  ✓ $workflow"
                updated=$((updated + 1))
            elif grep -q "branches: \\['main'\\]" "$file"; then
                sed "s/branches: \\['main'\\]/branches: ['$branch']/" "$file" > "$file.tmp"
                mv "$file.tmp" "$file"
                echo "  ✓ $workflow"
                updated=$((updated + 1))
            else
                print_warning "$workflow 파일에서 main 브랜치 트리거를 찾을 수 없습니다"
            fi
        else
            print_warning "$workflow 파일이 존재하지 않습니다"
        fi
    done
    
    if [ $updated -gt 0 ]; then
        print_success "$updated 개 워크플로우 파일 업데이트 완료"
    else
        print_warning "업데이트할 워크플로우 파일이 없습니다"
    fi
}

# 템플릿 관련 파일 삭제
cleanup_template_files() {
    print_step "템플릿 관련 파일 삭제 중..."
    
    # 주의: SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md는 삭제하지 않습니다
    # (사용자가 템플릿 사용법을 참고할 수 있도록 보존)
    
    # CHANGELOG 파일들 삭제
    if [ -f "CHANGELOG.md" ]; then
        rm -f CHANGELOG.md
        echo "  ✓ CHANGELOG.md 삭제"
    fi
    
    if [ -f "CHANGELOG.json" ]; then
        rm -f CHANGELOG.json
        echo "  ✓ CHANGELOG.json 삭제"
    fi
    
    # template_integrator.sh 삭제 (원격 실행 전용 스크립트)
    if [ -f "template_integrator.sh" ]; then
        rm -f template_integrator.sh
        echo "  ✓ template_integrator.sh 삭제 (원격 실행 전용)"
    fi

    # template_integrator.ps1 삭제 (원격 실행 전용 스크립트 - Windows)
    if [ -f "template_integrator.ps1" ]; then
        rm -f template_integrator.ps1
        echo "  ✓ template_integrator.ps1 삭제 (원격 실행 전용)"
    fi

    # LICENSE 파일 삭제
    if [ -f "LICENSE" ]; then
        rm -f LICENSE
        echo "  ✓ LICENSE 삭제"
    fi
    
    # CONTRIBUTING.md 파일 삭제
    if [ -f "CONTRIBUTING.md" ]; then
        rm -f CONTRIBUTING.md
        echo "  ✓ CONTRIBUTING.md 삭제"
    fi

    # CLAUDE.md 파일 삭제 (템플릿 전용 문서)
    if [ -f "CLAUDE.md" ]; then
        rm -f CLAUDE.md
        echo "  ✓ CLAUDE.md 삭제"
    fi

    # 테스트 폴더들 삭제
    if [ -d ".github/scripts/test" ]; then
        rm -rf .github/scripts/test
        echo "  ✓ .github/scripts/test 폴더 삭제"
    fi
    
    if [ -d ".github/workflows/test" ]; then
        rm -rf .github/workflows/test
        echo "  ✓ .github/workflows/test 폴더 삭제"
    fi

    # docs 폴더 삭제 (템플릿 전용 문서)
    if [ -d "docs" ]; then
        rm -rf docs
        echo "  ✓ docs 폴더 삭제"
    fi

    # 플러그인 전용 파일/폴더 삭제 (마켓플레이스 전용, 일반 프로젝트에서 불필요)
    if [ -d ".claude-plugin" ]; then
        rm -rf .claude-plugin
        echo "  ✓ .claude-plugin 폴더 삭제 (플러그인 매니페스트)"
    fi

    if [ -d "skills" ]; then
        rm -rf skills
        echo "  ✓ skills 폴더 삭제 (마켓플레이스 전용 스킬)"
    fi

    if [ -d "scripts" ]; then
        rm -rf scripts
        echo "  ✓ scripts 폴더 삭제 (마켓플레이스 전용 스크립트)"
    fi

    # .suh-template.example 폴더 삭제 (템플릿 전용 config 스키마)
    if [ -d ".suh-template.example" ]; then
        rm -rf .suh-template.example
        echo "  ✓ .suh-template.example 폴더 삭제 (템플릿 전용)"
    fi

    print_success "템플릿 관련 파일 삭제 완료"
}

# .gitignore 생성 또는 업데이트
ensure_gitignore() {
    print_step ".gitignore 파일 확인 및 업데이트 중..."
    
    local required_entries=(
        "/.idea"
        "/.claude/settings.local.json"
        "/docs/suh-template/"
    )
    
    # .gitignore가 없으면 생성
    if [ ! -f ".gitignore" ]; then
        print_info ".gitignore 파일이 없습니다. 생성합니다."
        
        cat > .gitignore << 'EOF'
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json

# AI 산출물 (자동 생성, 로컬 전용)
/docs/suh-template/
EOF
        
        print_success ".gitignore 파일 생성 완료"
        return
    fi
    
    # 기존 파일이 있으면 누락된 항목만 추가
    print_info "기존 .gitignore 파일 발견. 필수 항목 확인 중..."
    
    local added=0
    local entries_to_add=()
    
    for entry in "${required_entries[@]}"; do
        # 간단한 존재 여부 확인 (정규화 없이)
        if ! grep -q "^${entry}$" .gitignore && ! grep -q "^${entry#/}$" .gitignore; then
            entries_to_add+=("$entry")
            added=$((added + 1))
        fi
    done
    
    if [ $added -eq 0 ]; then
        print_info "필수 항목이 이미 모두 존재합니다. 건너뜁니다."
        return
    fi
    
    # 항목 추가
    print_info "$added 개 항목 추가 중..."
    
    # 파일 끝에 빈 줄이 없으면 추가
    if [ -n "$(tail -c 1 .gitignore 2>/dev/null)" ]; then
        echo "" >> .gitignore
    fi
    
    # 섹션 헤더 추가
    echo "" >> .gitignore
    echo "# ====================================================================" >> .gitignore
    echo "# SUH-DEVOPS-TEMPLATE: Auto-added entries" >> .gitignore
    echo "# ====================================================================" >> .gitignore
    
    for entry in "${entries_to_add[@]}"; do
        echo "$entry" >> .gitignore
        print_info "  ✓ $entry"
    done
    
    # docs/suh-template/ 폴더가 이미 Git에 추적 중인 경우 제거
    if printf '%s\n' "${entries_to_add[@]}" | grep -q "^/docs/suh-template/$"; then
        if git ls-files --error-unmatch docs/suh-template >/dev/null 2>&1; then
            print_info "docs/suh-template/ 폴더가 Git에 추적 중입니다. 추적 해제 중..."
            if git rm -r --cached docs/suh-template >/dev/null 2>&1; then
                print_success "docs/suh-template/ 폴더의 Git 추적이 해제되었습니다"
            fi
        fi
    fi

    print_success ".gitignore 업데이트 완료 ($added 개 항목 추가)"
}

# README.md 초기화
initialize_readme() {
    local project_name=$1
    local version=$2
    
    print_step "README.md 파일 초기화 중..."
    
    cat > README.md << EOF
# $project_name

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v$version

[전체 버전 기록 보기](CHANGELOG.md)

</br>

<!-- Template initialized: $(TZ=Asia/Seoul date +"%Y-%m-%d %H:%M:%S KST") -->
EOF
    
    print_success "README.md 파일이 초기화되었습니다."
}

# 이슈 템플릿 assignee 업데이트
update_issue_templates() {
    print_step "이슈 템플릿 assignee 업데이트 중..."

    # 처리 대상 이슈 템플릿 리스트 (새 템플릿 추가 시 여기에만 추가)
    local templates=(
        "bug_report.md"
        "design_request.md"
        "feature_request.md"
        "qa_request.md"
    )

    local updated=0

    # 각 템플릿의 assignee를 REPO_OWNER로 변경
    for template in "${templates[@]}"; do
        local file_path=".github/ISSUE_TEMPLATE/$template"

        if [ -f "$file_path" ]; then
            # 임시 파일 사용 (macOS/Linux 호환)
            sed "s/assignees: \\[Cassiiopeia\\]/assignees: [$REPO_OWNER]/" \
                "$file_path" > "${file_path}.tmp"
            mv "${file_path}.tmp" "$file_path"
            echo "  ✓ $template"
            updated=$((updated + 1))
        fi
    done

    if [ $updated -eq 0 ]; then
        print_warning "업데이트할 이슈 템플릿이 없습니다."
    else
        print_success "이슈 템플릿 $updated 개 업데이트 완료"
    fi
}

# 초기화 완료 요약 출력
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                🎉 템플릿 초기화 완료! 🎉                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}초기화된 설정:${NC}"
    echo -e "  ${BLUE}버전:${NC} $VERSION"
    echo -e "  ${BLUE}프로젝트 타입:${NC} $PROJECT_TYPE"
    echo -e "  ${BLUE}Default 브랜치:${NC} $DETECTED_BRANCH"
    echo -e "  ${BLUE}사용자:${NC} $GITHUB_USER"
    echo ""
    echo -e "${CYAN}완료된 작업:${NC}"
    echo "  ✅ version.yml 생성"
    echo "  ✅ Default branch 자동 감지 및 설정"
    if [ "$DETECTED_BRANCH" != "main" ]; then
        echo "  ✅ 워크플로우 트리거 브랜치 변경 (main → $DETECTED_BRANCH)"
    fi
    echo "  ✅ CHANGELOG 파일 삭제"
    echo "  ✅ LICENSE, CONTRIBUTING.md 삭제"
    echo "  ✅ 테스트 폴더 삭제"
    echo "  ✅ .gitignore 생성/업데이트"
    echo "  ✅ README.md 초기화"
    echo "  ✅ 이슈 템플릿 assignee 변경"
    echo ""
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "  1. 프로젝트에 맞게 README.md를 수정하세요"
    echo "  2. 필요한 경우 version.yml의 project_type을 확인하세요"
    echo "  3. 첫 번째 커밋을 푸시하여 자동화 시스템을 테스트하세요"
    echo ""
    echo -e "${CYAN}유용한 명령어:${NC}"
    echo "  git add ."
    echo "  git commit -m \"chore: 템플릿 초기화 완료 v$VERSION\""
    echo "  git push origin $DETECTED_BRANCH"
    echo ""
}

# 메인 실행 함수
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          GitHub 템플릿 초기화 스크립트                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 파라미터 검증
    validate_version "$VERSION"
    validate_project_type "$PROJECT_TYPE"
    
    # 프로젝트 이름 추출 (저장소명)
    if [ -n "$GITHUB_REPOSITORY" ]; then
        PROJECT_NAME="${GITHUB_REPOSITORY#*/}"
    else
        PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
    fi
    
    echo -e "${BLUE}프로젝트명:${NC} $PROJECT_NAME"
    echo -e "${BLUE}설정된 버전:${NC} $VERSION"
    echo -e "${BLUE}설정된 타입:${NC} $PROJECT_TYPE"
    echo ""
    
    # Default branch 감지
    DETECTED_BRANCH=$(detect_default_branch)
    echo ""
    
    # 1. version.yml 생성
    create_version_yml "$VERSION" "$PROJECT_TYPE" "$DETECTED_BRANCH" "$GITHUB_USER"
    echo ""
    
    # 2. 워크플로우 트리거 변경
    update_workflow_triggers "$DETECTED_BRANCH"
    echo ""
    
    # 3. 템플릿 파일 삭제
    cleanup_template_files
    echo ""
    
    # 3-1. .gitignore 생성 또는 업데이트
    ensure_gitignore
    echo ""

    # 4. README 초기화
    initialize_readme "$PROJECT_NAME" "$VERSION"
    echo ""
    
    # 5. 이슈 템플릿 업데이트
    update_issue_templates
    echo ""
    
    # 6. 완료 요약
    print_summary
}

# 스크립트 실행
main "$@"

