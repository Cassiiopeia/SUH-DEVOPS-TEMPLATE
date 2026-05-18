#!/bin/bash
# ===================================================================
# Firebase App Distribution Wizard - Setup Script (bash)
# ===================================================================
# 워크플로우 파일들의 FIREBASE_APP_ID, FIREBASE_TESTER_GROUP 키를
# 라인 단위로 안전하게 치환합니다.
#
# 사용법:
#   ./firebase-wizard-setup.sh \
#     --project-path /path/to/project \
#     --app-id "1:905325245238:android:86db..." \
#     --tester-group "romrom" \
#     [--dry-run] [--non-interactive] [--no-backup]
# ===================================================================
set -u

# ---- Color ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---- Flags & args ----
PROJECT_PATH=""
APP_ID=""
TESTER_GROUP=""
DRY_RUN=0
NON_INTERACTIVE=0
NO_BACKUP=0

print_usage() {
    cat <<EOF
사용법: $0 --project-path <path> --app-id <id> --tester-group <group> [옵션]

옵션:
  --dry-run             실제 파일 수정 없이 변경 미리보기
  --non-interactive     충돌 시 자동 SKIP (프롬프트 안 띄움)
  --no-backup           백업 파일 자동 생성 비활성화
  -h, --help            이 도움말 출력
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --project-path) PROJECT_PATH="$2"; shift 2 ;;
        --app-id) APP_ID="$2"; shift 2 ;;
        --tester-group) TESTER_GROUP="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --non-interactive) NON_INTERACTIVE=1; shift ;;
        --no-backup) NO_BACKUP=1; shift ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo -e "${RED}❌ 알 수 없는 인자: $1${NC}"; print_usage; exit 2 ;;
    esac
done

# ---- 인자 검증 ----
if [ -z "$PROJECT_PATH" ] || [ -z "$APP_ID" ] || [ -z "$TESTER_GROUP" ]; then
    echo -e "${RED}❌ --project-path, --app-id, --tester-group 모두 필요합니다${NC}"
    print_usage
    exit 2
fi

if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ project-path 디렉터리가 존재하지 않음: $PROJECT_PATH${NC}"
    exit 2
fi

WORKFLOWS_DIR="$PROJECT_PATH/.github/workflows"
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo -e "${RED}❌ .github/workflows 폴더가 없음. 템플릿이 적용되지 않은 프로젝트입니다.${NC}"
    echo -e "${YELLOW}   확인 경로: $WORKFLOWS_DIR${NC}"
    exit 3
fi

# ---- 대상 파일 탐지 ----
mapfile -t YAML_FILES < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)

if [ "${#YAML_FILES[@]}" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ workflows 폴더에 yaml/yml 파일이 없음${NC}"
    exit 0
fi

TIMESTAMP=$(date +%s)
TOTAL_REPLACED=0
TOTAL_SKIPPED=0
TOTAL_CONFLICTS=0
SUMMARY=()

# ---- regex 매칭용 키 목록 ----
KEYS_PATTERN='FIREBASE_APP_ID|FIREBASE_TESTER_GROUP'

# ---- 파일별 처리 ----
process_file() {
    local file="$1"
    local rel="${file#$PROJECT_PATH/}"
    local file_replaced=0
    local file_skipped=0
    local file_conflicts=0

    # 키 존재 여부 사전 확인 (단어 경계 보장: 키 직후에 공백 또는 콜론)
    if ! grep -E "^[[:space:]]*(FIREBASE_APP_ID|FIREBASE_TESTER_GROUP)[[:space:]]*:" "$file" > /dev/null 2>&1; then
        SUMMARY+=("⏭  $rel — 대상 키 없음, SKIP")
        return 0
    fi

    # 백업
    if [ "$NO_BACKUP" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
        cp "$file" "$file.bak.$TIMESTAMP"
    fi

    local tmp
    tmp=$(mktemp)
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^([[:space:]]*)(FIREBASE_APP_ID|FIREBASE_TESTER_GROUP)([[:space:]]*:[[:space:]]*)(.*)$ ]]; then
            local indent="${BASH_REMATCH[1]}"
            local key="${BASH_REMATCH[2]}"
            local sep="${BASH_REMATCH[3]}"
            local raw_value="${BASH_REMATCH[4]}"
            # CRLF 안전: trailing \r 먼저 제거
            raw_value="${raw_value%$'\r'}"
            # 따옴표·공백 제거
            local stripped="$raw_value"
            stripped="${stripped#\"}"; stripped="${stripped%\"}"
            stripped="${stripped#\'}"; stripped="${stripped%\'}"
            stripped="$(echo "$stripped" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

            local new_value=""
            local placeholder=""
            if [ "$key" = "FIREBASE_APP_ID" ]; then
                new_value="$APP_ID"
                placeholder="{FIREBASE_APP_ID}"
            else
                new_value="$TESTER_GROUP"
                placeholder="{TESTER_GROUP}"
            fi

            if [ "$stripped" = "$placeholder" ]; then
                echo "${indent}${key}${sep}\"${new_value}\"" >> "$tmp"
                file_replaced=$((file_replaced + 1))
                echo -e "  ${GREEN}✓${NC} $rel — $key: placeholder → $new_value"
            elif [ "$stripped" = "$new_value" ]; then
                echo "$line" >> "$tmp"
                file_skipped=$((file_skipped + 1))
                echo -e "  ${BLUE}ℹ${NC} $rel — $key: 이미 같은 값, SKIP"
            else
                if [ "$NON_INTERACTIVE" -eq 1 ]; then
                    echo "$line" >> "$tmp"
                    file_skipped=$((file_skipped + 1))
                    file_conflicts=$((file_conflicts + 1))
                    echo -e "  ${YELLOW}⚠${NC} $rel — $key: 다른 값 ('$stripped'), 비대화형 SKIP"
                else
                    echo
                    echo -e "${YELLOW}⚠ 충돌 감지: $rel${NC}"
                    echo "  키: $key"
                    echo "  현재값: $stripped"
                    echo "  새 값:  $new_value"
                    read -r -p "  덮어쓸까? (y/n/abort): " choice
                    case "$choice" in
                        y|Y)
                            echo "${indent}${key}${sep}\"${new_value}\"" >> "$tmp"
                            file_replaced=$((file_replaced + 1))
                            echo -e "  ${GREEN}✓${NC} 덮어씀"
                            ;;
                        n|N)
                            echo "$line" >> "$tmp"
                            file_skipped=$((file_skipped + 1))
                            echo -e "  ${BLUE}ℹ${NC} SKIP"
                            ;;
                        abort|A|a*)
                            echo -e "${RED}❌ 사용자 abort 요청${NC}"
                            rm -f "$tmp"
                            if [ "$NO_BACKUP" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
                                mv "$file.bak.$TIMESTAMP" "$file"
                            fi
                            return 99
                            ;;
                        *)
                            echo "$line" >> "$tmp"
                            file_skipped=$((file_skipped + 1))
                            echo -e "  ${BLUE}ℹ${NC} 알 수 없는 입력 → SKIP"
                            ;;
                    esac
                fi
            fi
        else
            echo "$line" >> "$tmp"
        fi
    done < "$file"

    if [ "$DRY_RUN" -eq 0 ]; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
    fi

    TOTAL_REPLACED=$((TOTAL_REPLACED + file_replaced))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + file_skipped))
    TOTAL_CONFLICTS=$((TOTAL_CONFLICTS + file_conflicts))
    SUMMARY+=("📝 $rel — 치환 $file_replaced, SKIP $file_skipped, 충돌 $file_conflicts")
}

echo -e "${CYAN}▶ Firebase Wizard Setup${NC}"
echo "  project-path: $PROJECT_PATH"
echo "  app-id:       $APP_ID"
echo "  tester-group: $TESTER_GROUP"
echo "  dry-run:      $DRY_RUN | non-interactive: $NON_INTERACTIVE | no-backup: $NO_BACKUP"
echo

ABORTED=0
for f in "${YAML_FILES[@]}"; do
    process_file "$f"
    rc=$?
    if [ "$rc" -eq 99 ]; then
        ABORTED=1
        break
    fi
done

echo
echo -e "${CYAN}===== Summary =====${NC}"
for line in "${SUMMARY[@]}"; do
    echo "  $line"
done
echo
echo "총 치환: $TOTAL_REPLACED | SKIP: $TOTAL_SKIPPED | 충돌(SKIP): $TOTAL_CONFLICTS"

if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${YELLOW}※ --dry-run: 실제 파일은 수정되지 않았습니다${NC}"
fi

if [ "$ABORTED" -eq 1 ]; then
    echo -e "${RED}❌ 사용자 abort로 중단됨${NC}"
    exit 4
fi
exit 0
