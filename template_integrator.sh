#!/bin/bash

# ===================================================================
# GitHub 템플릿 통합 스크립트 v1.0.0
# ===================================================================
#
# 이 스크립트는 기존 프로젝트에 SUH-DEVOPS-TEMPLATE의 기능을
# 선택적으로 통합합니다.
#
# 주요 기능:
# 1. 기존 README.md 보존 및 버전 정보 섹션 자동 추가
# 2. package.json, pubspec.yaml 등에서 버전과 타입 자동 감지
# 3. GitHub Actions 워크플로우 선택적 복사
# 4. 충돌 파일 자동 처리 및 백업
# 5. version.yml 생성 (기존 프로젝트 정보 유지)
#
# 사용법:
# 
# 방법 1: 로컬 다운로드 후 실행
# curl -o template_integrator.sh \
#   https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh
# chmod +x template_integrator.sh
# ./template_integrator.sh [옵션]
#
# 방법 2: 원격 실행 - 대화형 (추천)
# bash <(curl -fsSL https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh)
#
# 방법 3: 원격 실행 - 자동화 (CI/CD)
# bash <(curl -fsSL https://raw.../template_integrator.sh) --mode full --force
# curl -fsSL https://raw.../template_integrator.sh | bash -s -- --mode version --force
#
# 옵션:
#   -m, --mode MODE          통합 모드 선택 (기본: interactive)
#                            • full        - 전체 통합 (버전관리+워크플로우+이슈템플릿)
#                            • version     - 버전 관리 시스템만
#                            • workflows   - GitHub Actions 워크플로우만
#                            • issues      - 이슈/PR 템플릿만
#                            • skills      - Agent Skill 설치만 (Claude, Cursor, Gemini, Codex, PI)
#                            • interactive - 대화형 선택 (기본값)
#   -v, --version VERSION    초기 버전 설정 (자동 감지, 수동 지정 가능)
#   -t, --type TYPE          프로젝트 타입 (자동 감지, 수동 지정 가능)
#                            지원: spring, flutter, react, react-native,
#                                  react-native-expo, node, python, basic
#   --no-backup              백업 생성 안 함 (기본: 백업 생성)
#   --force                  확인 없이 즉시 실행
#   -h, --help               도움말 표시
#
# 예시:
#   # 대화형 모드 (추천)
#   ./template_integrator.sh
#
#   # 버전 관리 시스템만 추가
#   ./template_integrator.sh --mode version
#
#   # 전체 통합 (자동 감지)
#   ./template_integrator.sh --mode full
#
#   # Node.js 프로젝트로 버전 1.0.0 설정
#   ./template_integrator.sh --mode full --version 1.0.0 --type node
#
# ===================================================================

set -e  # 에러 발생 시 스크립트 중단

# ===================================================================
# SSL 인증서 관련 환경 변수 초기화
# 사용자 환경에서 잘못 설정된 CA 경로 문제 방지
# (예: curl: (77) error setting certificate verify locations: CAfile: /tmp/cacert.pem)
# ===================================================================
unset CURL_CA_BUNDLE
unset SSL_CERT_FILE
unset SSL_CERT_DIR
unset REQUESTS_CA_BUNDLE

# stdin 모드 및 TTY 가용성 감지
STDIN_MODE=false
TTY_AVAILABLE=true

# 터미널 상태 감지 함수
detect_terminal() {
    # stdin이 터미널인지 확인
    if [ -t 0 ]; then
        STDIN_MODE=false
        TTY_AVAILABLE=true
        return
    fi
    
    # stdin은 파이프지만 /dev/tty 접근 가능한지 확인
    STDIN_MODE=true
    if [ -c /dev/tty ] 2>/dev/null; then
        # /dev/tty 읽기 테스트 — 서브셸로 감싸서 에러 출력 완전 억제
        if ( exec 3< /dev/tty ) 2>/dev/null; then
            TTY_AVAILABLE=true
        else
            TTY_AVAILABLE=false
        fi
    else
        TTY_AVAILABLE=false
    fi
}

# 색상 정의 (비활성화 - 안정성 향상)
RED=''
GREEN=''
YELLOW=''
BLUE=''
CYAN=''
MAGENTA=''
NC=''

# 템플릿 저장소 URL
TEMPLATE_REPO="https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git"
TEMP_DIR=".template_download_temp"

# 임시 다운로드 폴더 정리 — 정상 종료뿐 아니라 중단(ESC/Ctrl+C)·set -e 에러로
# 종료될 때도 호출돼 .template_download_temp가 프로젝트에 잔존하지 않도록 보장한다.
# (정상 흐름에서는 본문에서 한 번 더 명시적으로 rm 하지만, trap이 안전망이 된다.)
cleanup_temp_dir() {
    [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup_temp_dir EXIT

# 상수 정의
readonly TEMPLATE_RAW_URL="https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main"
readonly VERSION_FILE="version.yml"
readonly WORKFLOWS_DIR=".github/workflows"
readonly SCRIPTS_DIR=".github/scripts"
readonly PROJECT_TYPES_DIR="project-types"
readonly DEFAULT_VERSION="1.3.14"

# 다운로드한 템플릿의 실제 버전 (download_template에서 설정됨)
TEMPLATE_VERSION=""

# 워크플로우 파일명 패턴
readonly WORKFLOW_PREFIX="PROJECT"
readonly WORKFLOW_COMMON_PREFIX="PROJECT-COMMON"
readonly WORKFLOW_TEMPLATE_INIT="PROJECT-TEMPLATE-INITIALIZER.yaml"

# 출력 함수 (/dev/tty 우선, 없으면 stderr로 폴백하여 명령어 치환 시 데이터 오염 방지)

# 출력 대상 선택 헬퍼 (중복 제거)
# TTY_AVAILABLE이 true(detect_terminal에서 실제 접근 검증 완료)일 때만 /dev/tty 사용
# -w 체크만으로는 false positive 발생 가능 (Claude Code 샌드박스 등 특수 환경)
get_output_target() {
    if [ "$TTY_AVAILABLE" = true ]; then
        echo "/dev/tty"
    elif [ -w /dev/tty ] 2>/dev/null; then
        # detect_terminal 호출 전(초기화 단계) 폴백: 실제 쓰기 가능한지 probe
        if ( echo "" >/dev/tty ) 2>/dev/null; then
            echo "/dev/tty"
        else
            echo "/dev/stderr"
        fi
    else
        echo "/dev/stderr"
    fi
}

# 안전한 출력 헬퍼
safe_echo() {
    local target=$(get_output_target)
    if [ "$target" = "/dev/tty" ]; then
        echo "$@" >/dev/tty
    else
        echo "$@" >&2
    fi
}

safe_echo_e() {
    local target=$(get_output_target)
    if [ "$target" = "/dev/tty" ]; then
        echo -e "$@" >/dev/tty
    else
        echo -e "$@" >&2
    fi
}

print_header() {
    safe_echo ""
    safe_echo_e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    safe_echo_e "${CYAN}║$1${NC}"
    safe_echo_e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    safe_echo ""
}

# 멋진 배너 출력 (템플릿 버전 표시)
print_banner() {
    local version=$1
    local mode=$2
    
    safe_echo ""
    safe_echo "╔══════════════════════════════════════════════════════════════════╗"
    safe_echo "║ 🔮  ✦ S U H · D E V O P S · T E M P L A T E ✦                    ║"
    safe_echo "╚══════════════════════════════════════════════════════════════════╝"
    safe_echo "       🌙 Version : v${version}"
    safe_echo "       🐵 Author  : Cassiiopeia"
    safe_echo "       🪐 Mode    : ${mode}"
    safe_echo "       📦 Repo    : github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    safe_echo ""
}

print_step() {
    safe_echo_e "${CYAN}🔅${NC} $1"
}

print_info() {
    safe_echo_e "  ${BLUE}🔸${NC} $1"
}

print_success() {
    safe_echo_e "${GREEN}✨${NC} $1"
}

print_warning() {
    safe_echo_e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    safe_echo_e "${RED}💥${NC} $1"
}

print_question() {
    safe_echo_e "${MAGENTA}💫${NC} $1"
}

# 안전한 read 함수 (/dev/tty 사용)
# 반환: 0=정상 입력, 1=TTY 없음(비대화형), 2=ESC로 취소
# ESC 처리: 자유텍스트 입력($options 빈값)에서만 동작. 첫 키를 raw 모드로 한 글자
#           읽어 ESC면 취소(2)로 반환한다. 일반 문자면 그 글자를 첫 글자로 삼고
#           나머지를 라인으로 읽어 합쳐 기존 줄 입력과 동일하게 동작시킨다.
#           (read -r 한 줄 입력은 ESC가 리터럴 '^['로 박혀 취소로 인식되지 못했던
#            버그를 해결 — 버전/브랜치 입력 중 ESC가 ^[^[로 찍히던 문제)
safe_read() {
    local prompt="$1"
    local varname="$2"
    local options="$3"

    if [ "$TTY_AVAILABLE" = true ]; then
        printf "%s" "$prompt" > /dev/tty

        if [ "$options" = "-n 1" ]; then
            IFS= read -r -n 1 "$varname" < /dev/tty
        elif [ -n "$options" ]; then
            IFS= read -r $options "$varname" < /dev/tty
        else
            # 첫 키를 raw 1바이트로 읽어 ESC 여부 판별
            local _first
            IFS= read -rsn1 _first < /dev/tty || { printf "%s" "" > /dev/tty; return 1; }

            if [ "$_first" = $'\e' ]; then
                # ESC 뒤 시퀀스(화살표 등)를 정수 타임아웃으로 흡수.
                # 추가 바이트가 있으면 화살표 등 → 취소 아님(빈값으로 처리), 없으면 진짜 ESC.
                local _b1
                if IFS= read -rsn1 -t 1 _b1 < /dev/tty 2>/dev/null && [ -n "$_b1" ]; then
                    IFS= read -rsn1 -t 1 _ < /dev/tty 2>/dev/null || true
                    printf "\n" > /dev/tty
                    printf -v "$varname" '%s' ""
                    return 0
                fi
                # 단독 ESC → 취소
                printf "\n" > /dev/tty
                printf -v "$varname" '%s' ""
                return 2
            fi

            if [ "$_first" = $'\n' ] || [ "$_first" = $'\r' ] || [ -z "$_first" ]; then
                # 즉시 Enter → 빈 입력
                printf "\n" > /dev/tty
                printf -v "$varname" '%s' ""
                return 0
            fi

            # 일반 문자 → 첫 글자 echo 후 나머지 라인 읽어 합침
            printf "%s" "$_first" > /dev/tty
            local _rest
            IFS= read -r _rest < /dev/tty || _rest=""
            printf -v "$varname" '%s' "${_first}${_rest}"
        fi
        return 0
    else
        return 1
    fi
}

# 안전한 출력 함수 (TTY 우선, stderr 폴백)
print_to_user() {
    safe_echo "$@"
}

# ─────────────────────────────────────────────────────────────
# 인터랙티브 메뉴 (TTY 전용) — 화살표/숫자/Enter/ESC
# 사용법: selected=$(interactive_menu "prompt" "value1|label1" "value2|label2" ...)
# stdout: 선택된 value
# exit:   0=확정, 1=취소(ESC)
# 옵션: --cancel-label=라벨 → 하단 안내의 ESC 동작 표기(기본 "취소").
#       하위 메뉴는 "뒤로", 최상위는 "취소"로 호출자가 지정한다.
# ─────────────────────────────────────────────────────────────
interactive_menu() {
    # 옵션 파싱 — --multi(다중 선택), --preselect=csv(초기 선택값), --cancel-label=라벨,
    #            --initial-index=N(단일 선택 커서 초기 위치 = 기본값. 항목 순서는 고정한 채 기본만 표현)
    local multi=false
    local preselect_csv=""
    local cancel_label="취소"
    local initial_index=0
    while [[ "$1" == --* ]]; do
        case "$1" in
            --multi) multi=true; shift ;;
            --preselect=*) preselect_csv="${1#--preselect=}"; shift ;;
            --cancel-label=*) cancel_label="${1#--cancel-label=}"; shift ;;
            --initial-index=*) initial_index="${1#--initial-index=}"; shift ;;
            *) break ;;
        esac
    done

    local prompt="$1"
    shift
    local options=("$@")
    local n=${#options[@]}

    if [ "$n" -eq 0 ]; then
        echo "interactive_menu: 옵션이 없습니다" >&2
        return 1
    fi

    local use_color=true
    if [ -n "${NO_COLOR:-}" ] || [ ! -t 2 ]; then
        use_color=false
    fi

    local C_RESET="" C_CYAN="" C_DIM="" C_GREEN=""
    if [ "$use_color" = true ]; then
        C_RESET=$'\033[0m'
        C_CYAN=$'\033[36m'
        C_DIM=$'\033[2m'
        C_GREEN=$'\033[32m'
    fi

    # multi 모드 선택 상태 — index → bool
    local selected=()
    local i
    for i in $(seq 0 $((n - 1))); do selected[$i]=false; done

    # preselect 적용 — value가 일치하는 항목을 초기 선택
    if [ -n "$preselect_csv" ] && [ "$multi" = true ]; then
        local p pre_value
        IFS=',' read -ra _pre <<< "$preselect_csv"
        for p in "${_pre[@]}"; do
            for i in $(seq 0 $((n - 1))); do
                IFS='|' read -r pre_value _ <<< "${options[$i]}"
                if [ "$pre_value" = "$p" ]; then
                    selected[$i]=true
                    break
                fi
            done
        done
    fi

    if [ "$multi" = true ]; then
        printf "\n%s (↑↓ 이동, Space 토글, a 전체토글, Enter 확정, ESC %s):\n\n" "$prompt" "$cancel_label" >&2
    else
        printf "\n%s (↑↓ 이동, 숫자 점프, Enter 확정, ESC %s):\n\n" "$prompt" "$cancel_label" >&2
    fi

    # 커서 초기 위치 = initial_index (단일 선택의 기본값 표현). 범위를 벗어나거나 숫자가 아니면 0.
    local cursor=0
    if [ "$multi" = false ] && [[ "$initial_index" =~ ^[0-9]+$ ]] && [ "$initial_index" -lt "$n" ]; then
        cursor="$initial_index"
    fi

    trap 'printf "\033[?25h" >&2; return 130' INT
    printf "\033[?25l" >&2

    # ── 스크롤 안전 커서 앵커 ──
    # 문제: 메뉴를 화면 하단에서 그리면 출력이 터미널을 스크롤시킨다. 그러면 ESC7로 저장한
    #       절대좌표가 위로 밀려 무효화되고, redraw마다 잔상이 누적돼 "점점 늘어나는" 버그가 됐다.
    # 해법: 메뉴가 차지할 만큼(wrap 여유 포함) 빈 줄을 먼저 출력해 스크롤을 '미리' 일으킨 뒤,
    #       그만큼 커서를 되올려(ESC[<rows>A) 그 지점을 앵커로 저장(ESC7)한다. 이 앵커는 이미
    #       화면 안쪽이라 이후 redraw는 스크롤을 유발하지 않아 좌표가 안정적이다.
    # 여유: 가장 긴 라벨이 wrap되는 경우까지 대비해 항목당 1줄 여유(=n*2) 확보.
    local _reserve=$(( n * 2 + 1 ))
    local _r
    for ((_r = 0; _r < _reserve; _r++)); do printf "\n" >&2; done
    printf "\033[%dA" "$_reserve" >&2
    printf "\0337" >&2

    _interactive_menu_render() {
        local i value label num indicator
        for i in $(seq 0 $((n - 1))); do
            IFS='|' read -r value label <<< "${options[$i]}"
            num=$((i + 1))
            # 표시자 — multi면 체크박스([✓]/[ ]), single이면 커서표시([•]/[ ])
            if [ "$multi" = true ]; then
                if [ "${selected[$i]}" = true ]; then
                    indicator="${C_GREEN}[✓]${C_RESET}"
                else
                    indicator="[ ]"
                fi
            else
                if [ "$i" -eq "$cursor" ]; then
                    indicator="[•]"
                else
                    indicator="[ ]"
                fi
            fi
            # label이 비어 있으면 value만 출력(예/아니오 같은 단순 선택지). 있으면 'value    label(dim)'.
            if [ "$i" -eq "$cursor" ]; then
                if [ -n "$label" ]; then
                    printf "%s> %s %d) %s    %s%s%s%s\n" \
                        "$C_CYAN" "$indicator" "$num" "$value" \
                        "$C_DIM" "$label" "$C_RESET" "$C_RESET" >&2
                else
                    printf "%s> %s %d) %s%s\n" \
                        "$C_CYAN" "$indicator" "$num" "$value" "$C_RESET" >&2
                fi
            else
                if [ -n "$label" ]; then
                    printf "  %s %d) %s    %s%s%s\n" \
                        "$indicator" "$num" "$value" \
                        "$C_DIM" "$label" "$C_RESET" >&2
                else
                    printf "  %s %d) %s\n" \
                        "$indicator" "$num" "$value" >&2
                fi
            fi
        done
    }

    _interactive_menu_clear() {
        # 저장한 시작 지점으로 복원(ESC 8) 후 거기서 화면 끝까지 삭제(ESC[J).
        # 기존 "n줄 위로(ESC[1A)" 방식은 wrap된 줄을 1줄로 오인해 잔상이 남았다 → 폐기.
        printf "\0338\033[J" >&2
    }

    _interactive_menu_render

    local key rest value
    while true; do
        IFS= read -rsn1 key < /dev/tty || { printf "\033[?25h" >&2; trap - INT; return 1; }

        if [ "$key" = $'\e' ]; then
            # ESC 다음 바이트를 1개씩 읽는다. bash 3.2는 `read -t 0.01`(소수점) 타임아웃을
            # 0초로 절삭해 화살표 시퀀스([ A/B)를 놓치고 ESC로 오인 → 메뉴가 멋대로 취소됐다.
            # 정수 타임아웃(-t 1)으로 바꾸고, 화살표(ESC [) + 애플리케이션 커서모드(ESC O)
            # 양쪽을 모두 처리한다. 타임아웃되면(rest 비어있음) 진짜 ESC 키로 간주.
            local b1 b2 rest=""
            if IFS= read -rsn1 -t 1 b1 < /dev/tty 2>/dev/null && [ -n "$b1" ]; then
                IFS= read -rsn1 -t 1 b2 < /dev/tty 2>/dev/null || b2=""
                rest="${b1}${b2}"
            fi
            case "$rest" in
                '[A'|'OA') key=UP ;;
                '[B'|'OB') key=DOWN ;;
                '')        key=ESC ;;
                *)         continue ;;
            esac
        fi

        case "$key" in
            UP|k)
                cursor=$(( cursor - 1 ))
                [ "$cursor" -lt 0 ] && cursor=$((n - 1))
                ;;
            DOWN|j)
                cursor=$(( cursor + 1 ))
                [ "$cursor" -ge "$n" ] && cursor=0
                ;;
            [1-9])
                local jump=$((key - 1))
                if [ "$jump" -ge 0 ] && [ "$jump" -lt "$n" ]; then
                    cursor=$jump
                fi
                ;;
            ' ')
                # Space — multi 모드에서 현재 행 선택 토글
                if [ "$multi" = true ]; then
                    if [ "${selected[$cursor]}" = true ]; then
                        selected[$cursor]=false
                    else
                        selected[$cursor]=true
                    fi
                fi
                ;;
            a|A)
                # a — multi 모드에서 전체 토글 (모두 선택돼 있으면 전체 해제, 아니면 전체 선택)
                if [ "$multi" = true ]; then
                    local all_on=true
                    for i in $(seq 0 $((n - 1))); do
                        [ "${selected[$i]}" = true ] || { all_on=false; break; }
                    done
                    for i in $(seq 0 $((n - 1))); do
                        if [ "$all_on" = true ]; then selected[$i]=false; else selected[$i]=true; fi
                    done
                fi
                ;;
            ""|$'\n'|$'\r')
                _interactive_menu_clear
                printf "\033[?25h" >&2
                trap - INT
                if [ "$multi" = true ]; then
                    # 선택된 항목들을 csv로 출력 (하나도 없으면 취소 처리)
                    local out="" first=true
                    for i in $(seq 0 $((n - 1))); do
                        if [ "${selected[$i]}" = true ]; then
                            IFS='|' read -r value _ <<< "${options[$i]}"
                            if [ "$first" = true ]; then
                                out="$value"; first=false
                            else
                                out="$out,$value"
                            fi
                        fi
                    done
                    [ -z "$out" ] && return 1
                    echo "$out"
                    return 0
                else
                    IFS='|' read -r value _ <<< "${options[$cursor]}"
                    echo "$value"
                    return 0
                fi
                ;;
            ESC|q)
                _interactive_menu_clear
                printf "\033[?25h" >&2
                trap - INT
                return 1
                ;;
            *)
                continue
                ;;
        esac

        _interactive_menu_clear
        _interactive_menu_render
    done
}

# ─────────────────────────────────────────────────────────────
# 비TTY fallback — 기존 숫자 입력 방식
# 사용법: selected=$(legacy_numeric_menu "prompt" "value1|label1" ...)
# ─────────────────────────────────────────────────────────────
legacy_numeric_menu() {
    # 옵션 파싱 — interactive_menu와 동일한 --multi/--preselect/--cancel-label 지원
    # (--cancel-label은 비TTY 텍스트 메뉴에선 표기 의미가 없어 파싱만 하고 무시)
    local multi=false
    local preselect_csv=""
    while [[ "$1" == --* ]]; do
        case "$1" in
            --multi) multi=true; shift ;;
            --preselect=*) preselect_csv="${1#--preselect=}"; shift ;;
            --cancel-label=*) shift ;;
            --initial-index=*) shift ;;   # 텍스트 메뉴엔 커서 개념이 없어 파싱만 하고 무시
            *) break ;;
        esac
    done

    local prompt="$1"
    shift
    local options=("$@")
    local n=${#options[@]}

    if [ "$n" -eq 0 ]; then
        echo "legacy_numeric_menu: 옵션이 없습니다" >&2
        return 1
    fi

    printf "\n%s\n\n" "$prompt" >&2
    local i value label
    for i in $(seq 0 $((n - 1))); do
        IFS='|' read -r value label <<< "${options[$i]}"
        printf "  %d) %-20s - %s\n" "$((i + 1))" "$value" "$label" >&2
    done
    printf "\n" >&2

    # 입력 프롬프트 — multi면 csv 안내
    local input_prompt
    if [ "$multi" = true ]; then
        input_prompt="여러 항목 선택 (csv, 예: 1,3,5 또는 spring,react)"
        [ -n "$preselect_csv" ] && input_prompt="$input_prompt [기본: $preselect_csv]"
        input_prompt="$input_prompt: "
    else
        input_prompt=$(printf "선택 (1-%d): " "$n")
    fi

    local choice read_ok=0
    while true; do
        choice=""
        read_ok=0
        if [ -t 0 ]; then
            printf "%s" "$input_prompt" >&2
            IFS= read -r choice && read_ok=1
        elif [ -c /dev/tty ] 2>/dev/null && [ -r /dev/tty ]; then
            printf "%s" "$input_prompt" >&2
            IFS= read -r choice < /dev/tty && read_ok=1
        fi

        if [ "$read_ok" -eq 0 ]; then
            # stdin/tty 모두 못 읽음 → multi+preselect면 그 값, 아니면 첫 옵션 자동 선택
            if [ "$multi" = true ] && [ -n "$preselect_csv" ]; then
                echo "$preselect_csv"
                return 0
            fi
            IFS='|' read -r value _ <<< "${options[0]}"
            echo "$value"
            return 0
        fi

        if [ "$multi" = true ]; then
            # 빈 입력 + preselect → preselect 사용
            if [ -z "$choice" ] && [ -n "$preselect_csv" ]; then
                echo "$preselect_csv"
                return 0
            fi
            # csv 파싱 — 숫자(1,3,5)/이름(spring,react) 혼용 허용
            local out="" first=true p resolved parts
            IFS=',' read -ra parts <<< "$choice"
            for p in "${parts[@]}"; do
                p=$(echo "$p" | tr -d ' ')
                [ -z "$p" ] && continue
                resolved=""
                if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le "$n" ]; then
                    IFS='|' read -r resolved _ <<< "${options[$((p - 1))]}"
                else
                    for i in $(seq 0 $((n - 1))); do
                        IFS='|' read -r value _ <<< "${options[$i]}"
                        if [ "$value" = "$p" ]; then resolved="$value"; break; fi
                    done
                fi
                if [ -n "$resolved" ]; then
                    if [ "$first" = true ]; then out="$resolved"; first=false; else out="$out,$resolved"; fi
                fi
            done
            if [ -z "$out" ]; then
                printf "유효한 선택이 없습니다. 다시 입력해주세요.\n" >&2
                continue
            fi
            echo "$out"
            return 0
        fi

        # single 모드
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ]; then
            IFS='|' read -r value _ <<< "${options[$((choice - 1))]}"
            echo "$value"
            return 0
        else
            printf "잘못된 입력입니다. 1-%d 사이의 숫자를 입력해주세요.\n" "$n" >&2
        fi
    done
}

# ─────────────────────────────────────────────────────────────
# 통합 entry point — TTY면 interactive_menu, 아니면 legacy_numeric_menu
# ─────────────────────────────────────────────────────────────
choose_menu() {
    if [ "$TTY_AVAILABLE" = true ] && [ -t 2 ]; then
        interactive_menu "$@"
    else
        legacy_numeric_menu "$@"
    fi
}

# Y/N 질문 함수 (기본값 지원)
# 반환: 0 (Yes), 1 (No)
ask_yes_no() {
    local prompt="$1"
    local default="${2:-N}"  # 기본값 N

    # 프롬프트 끝의 입력 안내 군더더기 제거 — choose_menu가 자체 안내(↑↓/Enter)를 붙이므로
    # "(Y/N, 기본: Y)", "(Y=예 / N=직접입력)", "선택:" 같은 Y/N식 꼬리표가 남으면 중복·모순돼 보인다.
    local _title
    _title=$(printf '%s' "$prompt" | sed -E \
        -e 's/[[:space:]]*\([^)]*[YyNn][^)]*\)[[:space:]]*//g' \
        -e 's/[[:space:]]*:[[:space:]]*$//' \
        -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//')
    # "선택"만 남는 무의미한 제목 방어
    case "$_title" in ""|"선택") _title="진행하시겠습니까?" ;; esac

    # TTY 대화형 → 화살표 메뉴(choose_menu).
    # 항목 순서는 항상 '1) 예  2) 아니오'로 고정한다 (기본값에 따라 순서가 바뀌면 일관성이 깨진다).
    # 기본값은 순서가 아니라 '커서 초기 위치'로만 표현한다: 기본 Y → 커서 예(0), 기본 N → 커서 아니오(1).
    # value를 '예'/'아니오'로 두고 label은 비워, 메뉴에 '1) 예 / 2) 아니오'만 깔끔히 표시.
    if [ "$TTY_AVAILABLE" = true ] && [ "$FORCE_MODE" = false ]; then
        local _ans _rc _init_idx
        if [[ "$default" =~ ^[Yy]$ ]]; then _init_idx=0; else _init_idx=1; fi
        _ans=$(choose_menu "--initial-index=$_init_idx" "$_title" "예|" "아니오|"); _rc=$?
        # choose_menu가 실패(ESC 취소 등) → 반환 1(=No/취소)
        [ "$_rc" -ne 0 ] && return 1
        [ "$_ans" = "예" ] && return 0
        return 1
    fi

    # 비TTY / FORCE — 기존 텍스트 입력 폴백 (한 글자 Y/N)
    local reply
    while true; do
        if safe_read "$prompt" reply "-n 1"; then
            print_to_user ""
            if [[ -z "$reply" ]]; then
                reply="$default"
            fi
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                return 0
            elif [[ "$reply" =~ ^[Nn]$ ]]; then
                return 1
            else
                print_error "잘못된 입력입니다. Y/y 또는 N/n을 입력해주세요. (Enter는 $default)"
                print_to_user ""
            fi
        else
            return 1
        fi
    done
}

# Y/N/E 질문 함수 (예/아니오/편집)
# 출력: "yes", "no", "edit" (set -e 모드 호환)
ask_yes_no_edit() {
    local reply
    local reply_normalized
    
    while true; do
        if safe_read "선택: " reply "-n 1"; then
            print_to_user ""
            
            # 입력값 정규화 (tr 에러 무시, 공백 제거, 소문자 변환)
            reply_normalized=$(printf '%s' "$reply" | tr -d '[:space:]' 2>/dev/null | tr '[:upper:]' '[:lower:]' 2>/dev/null)
            
            # 정규화 실패 시 원본 사용 (한국어 등)
            if [ -z "$reply_normalized" ] && [ -n "$reply" ]; then
                print_error "영문자만 입력해주세요. (Y/y, E/e, N/n)"
                print_to_user ""
                continue
            fi
            
            case "$reply_normalized" in
                ""|"y")
                    echo "yes"
                    return 0
                    ;;
                "n")
                    echo "no"
                    return 0
                    ;;
                "e")
                    echo "edit"
                    return 0
                    ;;
                *)
                    print_error "잘못된 입력입니다. Y/y, E/e, 또는 N/n을 입력해주세요."
                    print_to_user ""
                    ;;
            esac
        else
            print_error "입력을 읽을 수 없습니다"
            exit 1
        fi
    done
}

# 도움말 표시
show_help() {
    cat << EOF
${CYAN}GitHub 템플릿 통합 스크립트 v1.0.0${NC}

${BLUE}사용법:${NC}
  ./template_integrator.sh [옵션]

${BLUE}통합 모드:${NC}
  ${GREEN}full${NC}        - 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)
  ${GREEN}version${NC}     - 버전 관리 시스템만 (version.yml + scripts)
  ${GREEN}workflows${NC}   - GitHub Actions 워크플로우만
  ${GREEN}issues${NC}      - 이슈/PR 템플릿만
  ${GREEN}skills${NC}      - Agent Skill 설치만 (Claude, Cursor, Gemini, Codex, PI)
  ${GREEN}interactive${NC} - 대화형 선택 (기본값, 추천)

${BLUE}옵션:${NC}
  -m, --mode MODE          통합 모드 선택
  -v, --version VERSION    초기 버전 (미지정 시 자동 감지)
  -t, --type TYPE          프로젝트 타입 (미지정 시 자동 감지)
  --no-backup              백업 생성 안 함
  --force                  확인 없이 즉시 실행
  --nexus                  Nexus 라이브러리 publish 워크플로우 포함 (기본: 제외)
  --no-nexus               Nexus publish 워크플로우 제외
  --secret-backup          GitHub Secret 서버 백업 워크플로우 포함 (기본: 제외)
  --no-secret-backup       Secret 백업 워크플로우 제외
  --paths "T=P,..."        타입별 프로젝트 경로 (모노레포용, 예: --paths "flutter=app,react=client")
  -h, --help               이 도움말 표시

${BLUE}지원 프로젝트 타입:${NC}
  • ${GREEN}node${NC} / ${GREEN}react${NC} / ${GREEN}react-native${NC} - Node.js 기반 프로젝트
  • ${GREEN}spring${NC}            - Spring Boot 백엔드
  • ${GREEN}flutter${NC}           - Flutter 모바일 앱
  • ${GREEN}python${NC}            - Python 프로젝트
  • ${GREEN}basic${NC}             - 기타 프로젝트

${BLUE}자동 감지 기능:${NC}
  우선순위 1 (명확한 프레임워크 마커):
    • pubspec.yaml → Flutter
    • build.gradle/pom.xml → Spring Boot
    • pyproject.toml → Python
  우선순위 2 (Node.js 에코시스템 세부 분류):
    • package.json 내용 분석
      - @react-native → React Native
      - "next" → Next.js
      - "react" → React
      - 기타 → Node.js

${BLUE}사용 예시:${NC}
  # 로컬 실행 - 대화형 모드 (추천)
  ${GREEN}./template_integrator.sh${NC}

  # 원격 실행 - 대화형 모드 (curl 사용)
  ${GREEN}bash <(curl -fsSL https://raw.../template_integrator.sh)${NC}

  # 버전 관리만 추가
  ${GREEN}./template_integrator.sh --mode version${NC}

  # 전체 통합 (자동 감지)
  ${GREEN}./template_integrator.sh --mode full${NC}

  # 원격 실행 + 파라미터 (CI/CD, 자동화)
  ${GREEN}bash <(curl -fsSL https://raw.../template_integrator.sh) --mode full --force${NC}

  # 수동 설정
  ${GREEN}./template_integrator.sh --mode full --version 1.0.0 --type node${NC}

${BLUE}통합 후 작업:${NC}
  1. ${CYAN}README.md${NC} - 버전 정보 섹션 자동 추가됨 (기존 내용 보존)
  2. ${CYAN}version.yml${NC} - 버전 관리 설정 파일 생성
  3. ${CYAN}.github/workflows/${NC} - 워크플로우 파일 추가
  4. ${CYAN}.template_integration/${NC} - 백업 및 롤백 스크립트

${BLUE}stdin 모드 (curl | bash):${NC}
  ${GREEN}bash <(curl)${NC} 또는 ${GREEN}curl | bash${NC} 방식으로 실행 시:
  • /dev/tty를 통해 대화형 입력 가능 (Homebrew 방식)
  • CI/CD 환경(TTY 없음)에서는 --mode, --force 옵션 필수
  
  ${GREEN}# CI/CD 환경 예시${NC}
  ${GREEN}curl -fsSL URL | bash -s -- --mode version --force${NC}

${YELLOW}⚠️  주의사항:${NC}
  • 기존 README.md, LICENSE는 절대 덮어쓰지 않습니다
  • 충돌하는 워크플로우는 .bak 파일로 백업됩니다
  • Git 저장소가 아니면 경고만 표시하고 계속 진행합니다
  • 문서 파일(*.md)은 자동 제외됩니다

${BLUE}롤백:${NC}
  ${GREEN}./.template_integration/rollback.sh${NC}

EOF
}

# 기본값 설정
MODE="interactive"
VERSION=""
PROJECT_TYPE=""
PROJECT_TYPES=()   # 멀티타입 배열 — PROJECT_TYPE은 PROJECT_TYPES[0] 미러
FORCE_MODE=false
IS_INTERACTIVE_MODE=false  # interactive_mode()에서 왔는지 추적
# 선택적(opt-in) 워크플로우 포함 여부 (빈 값: 미설정, true/false: 명시적 설정)
INCLUDE_NEXUS=""          # Nexus 라이브러리 publish 워크플로우 (spring/nexus/)
INCLUDE_SECRET_BACKUP=""  # GitHub Secret 파일 서버 백업 워크플로우 (common/secret-backup/)
PROJECT_PATHS_CSV=""  # 타입별 경로 "flutter=app,react=client" — 빈 값이면 미확정 (bash 3.2 호환: 연관배열 금지)

# 지원하는 프로젝트 타입 (next 포함 — sh/ps1 일관성)
VALID_TYPES=("spring" "flutter" "next" "react" "react-native" "react-native-expo" "node" "python" "basic")

# 파라미터 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--type)
            # csv 분해 → PROJECT_TYPES 배열 (멀티타입). dedup + 검증 후 첫 항목을 PROJECT_TYPE에 미러
            _arg_types="$2"
            IFS=',' read -ra _arg_arr <<< "$_arg_types"
            PROJECT_TYPES=()
            _seen=""
            for _t in "${_arg_arr[@]}"; do
                _t=$(echo "$_t" | tr -d ' ')
                [ -z "$_t" ] && continue
                # dedup
                [[ ",$_seen," == *",$_t,"* ]] && continue
                # 검증
                _valid=false
                for _v in "${VALID_TYPES[@]}"; do
                    [ "$_v" = "$_t" ] && _valid=true && break
                done
                if [ "$_valid" = false ]; then
                    print_error "지원하지 않는 타입: '$_t'"
                    print_error "지원 타입: ${VALID_TYPES[*]}"
                    exit 1
                fi
                PROJECT_TYPES+=("$_t")
                _seen="$_seen,$_t"
            done
            if [ ${#PROJECT_TYPES[@]} -eq 0 ]; then
                print_error "--type 인자가 비어 있습니다"
                exit 1
            fi
            PROJECT_TYPE="${PROJECT_TYPES[0]}"
            shift 2
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        --nexus)
            INCLUDE_NEXUS=true
            shift
            ;;
        --no-nexus)
            INCLUDE_NEXUS=false
            shift
            ;;
        --secret-backup)
            INCLUDE_SECRET_BACKUP=true
            shift
            ;;
        --no-secret-backup)
            INCLUDE_SECRET_BACKUP=false
            shift
            ;;
        --paths)
            # "flutter=app,react=client" 형식 — 비대화형 경로 지정
            PROJECT_PATHS_CSV="$2"
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

# 프로젝트 타입 자동 감지
detect_project_type() {
    print_step "프로젝트 타입 자동 감지 중..."

    # ===================================================
    # 우선순위 1: 명확한 프레임워크 마커 파일 체크
    # Flutter, Spring, Python은 고유한 마커 파일을 가지므로 우선 체크
    # ===================================================

    # Flutter
    if [ -f "pubspec.yaml" ]; then
        print_info "✓ Flutter 감지됨"
        echo "flutter"
        return
    fi

    # Spring Boot
    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] || [ -f "pom.xml" ]; then
        print_info "✓ Spring Boot 감지됨"
        echo "spring"
        return
    fi

    # Python
    if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
        print_info "✓ Python 감지됨"
        echo "python"
        return
    fi

    # ===================================================
    # 우선순위 2: Node.js 에코시스템 세부 분류
    # package.json은 여러 프로젝트 타입에서 보조 도구로 사용될 수 있으므로 나중에 체크
    # ===================================================

    # Node.js / React / React Native / Next.js
    if [ -f "package.json" ]; then
        # React Native 체크
        if grep -q "@react-native" package.json || grep -q "react-native" package.json; then
            # Expo 체크
            if grep -q "expo" package.json; then
                print_info "✓ React Native (Expo) 감지됨"
                echo "react-native-expo"
                return
            else
                print_info "✓ React Native 감지됨"
                echo "react-native"
                return
            fi
        fi

        # Next.js 체크 (React보다 먼저 체크해야 함)
        if grep -q "\"next\"" package.json; then
            print_info "✓ Next.js 감지됨"
            echo "next"
            return
        fi

        # React 체크
        if grep -q "\"react\"" package.json; then
            print_info "✓ React 감지됨"
            echo "react"
            return
        fi

        # 기본 Node.js
        print_info "✓ Node.js 감지됨"
        echo "node"
        return
    fi

    # ===================================================
    # 감지 실패
    # ===================================================
    print_warning "프로젝트 타입을 감지하지 못했습니다. 기본(basic) 타입으로 설정합니다."
    echo "basic"
}

# 프로젝트 타입 자동 감지 (멀티 — 모든 일치 타입을 csv로 반환)
# detect_project_type(단수)은 첫 일치 하나만 반환하지만, 모노레포는 여러 타입이
# 공존할 수 있으므로 전부 감지해 사용자가 다중 선택 메뉴로 확정하게 한다.
# package.json 경로를 받아 react/next/node/react-native(-expo) 중 하나로 판별
# detect_project_types의 인라인 판별 로직을 추출 — 서브폴더 package.json에도 재사용
classify_package_json() {
    local pj=$1
    [ -f "$pj" ] || { echo ""; return; }
    if grep -q "@react-native" "$pj" || grep -q "react-native" "$pj"; then
        if grep -q "expo" "$pj"; then
            echo "react-native-expo"
        else
            echo "react-native"
        fi
    elif grep -q "\"next\"" "$pj"; then
        echo "next"
    elif grep -q "\"react\"" "$pj"; then
        echo "react"
    else
        echo "node"
    fi
}

# 모드 키 → 확인 화면용 한국어 라벨
_mode_display_label() {
    case "$1" in
        full)      echo "전체 설치 (버전관리 + 워크플로우 + 이슈·PR 템플릿)" ;;
        version)   echo "버전 관리만" ;;
        workflows) echo "워크플로우만" ;;
        issues)    echo "이슈·PR 템플릿만" ;;
        skills)    echo "AI 스킬만" ;;
        *)         echo "$1" ;;
    esac
}

detect_project_types() {
    print_step "프로젝트 타입 자동 감지 중..."

    # ── 0) 기존 version.yml의 project_types 최우선 ──
    # 이미 통합된 프로젝트(멀티타입 포함)는 version.yml에 타입이 저장돼 있다.
    # 루트에 마커가 없어도(모노레포: 타입이 server/·app/ 하위) 기존 설정을 그대로 이어받아야
    # basic으로 잘못 재감지되지 않는다. (version 보존과 동일 철학 — version.yml이 source of truth)
    if [ -f "version.yml" ]; then
        local _existing_types=""
        if command -v yq >/dev/null 2>&1; then
            _existing_types=$(yq -r '.project_types // [] | join(",")' version.yml 2>/dev/null)
            [ "$_existing_types" = "null" ] && _existing_types=""
            if [ -z "$_existing_types" ]; then
                _existing_types=$(yq -r '.project_type // ""' version.yml 2>/dev/null)
                [ "$_existing_types" = "null" ] && _existing_types=""
            fi
        else
            # yq 없음: project_types 라인에서 ["a","b"] 안의 토큰 추출
            local _line
            _line=$(grep -E '^project_types:' version.yml 2>/dev/null | head -1)
            if [ -n "$_line" ]; then
                _existing_types=$(echo "$_line" | grep -oE '"[a-z-]+"' | tr -d '"' | paste -sd, -)
            fi
            if [ -z "$_existing_types" ]; then
                _existing_types=$(grep -E '^project_type:' version.yml 2>/dev/null | head -1 | sed 's/.*"\([a-z-]*\)".*/\1/')
            fi
        fi
        # version.yml에 타입이 명시돼 있으면(basic 포함) 그것이 source of truth → 그대로 사용.
        # 값이 아예 없을 때만 아래 파일 스캔으로 새로 감지한다.
        if [ -n "$_existing_types" ]; then
            print_info "✓ 기존 설정 적용: $_existing_types (version.yml에서 불러옴)"
            echo "$_existing_types"
            return
        fi
    fi

    local detected=()

    # 고유 마커 파일 — 독립적으로 모두 감지
    [ -f "pubspec.yaml" ] && detected+=("flutter")

    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] || [ -f "pom.xml" ]; then
        detected+=("spring")
    fi

    if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
        detected+=("python")
    fi

    # package.json 기반 — next / react-native / react-native-expo / react / node 구분
    # (단, spring/flutter에서 build 도구로 쓰는 package.json과 구분하기 위해 내용 검사)
    if [ -f "package.json" ]; then
        if grep -q "@react-native" package.json || grep -q "react-native" package.json; then
            if grep -q "expo" package.json; then
                detected+=("react-native-expo")
            else
                detected+=("react-native")
            fi
        elif grep -q "\"next\"" package.json; then
            detected+=("next")
        elif grep -q "\"react\"" package.json; then
            detected+=("react")
        else
            # spring/flutter가 이미 감지된 경우 순수 node 보조 도구일 수 있어 중복 추가 방지
            if [ ${#detected[@]} -eq 0 ]; then
                detected+=("node")
            fi
        fi
    fi

    [ ${#detected[@]} -eq 0 ] && detected=("basic")

    print_info "✓ 감지된 타입: ${detected[*]}"

    # csv로 stdout 출력
    local IFS=','
    echo "${detected[*]}"
}

# 마커 파일이 없을 때(=detect_project_types가 basic) 타입을 추천 (스캔 추천)
# stdout: 추천 타입 csv (메뉴 정의 순서 정렬), 추천 없으면 빈 문자열. 안내용(강제 아님).
suggest_types_by_scan() {
    local _found=""   # 공백 구분 누적, 마지막에 정렬

    # ── 1) 마커 우선 스캔 — 모든 마커 타입에 find_type_path_candidates ──
    # package.json 계열은 같은 마커라 내용으로 판별한다.
    local _mt _cand _d _ptype
    for _mt in flutter spring python react-native-expo; do
        _cand=$(find_type_path_candidates "$_mt")
        [ -n "$_cand" ] && _found="$_found $_mt"
    done

    # package.json 계열 — react/next/node/react-native를 디렉터리별 내용으로 판별
    _cand=$(find_type_path_candidates react)   # react 토큰 = package.json 검색
    if [ -n "$_cand" ]; then
        while IFS= read -r _d; do
            [ -z "$_d" ] && continue
            local _pj
            if [ "$_d" = "." ]; then _pj="package.json"; else _pj="$_d/package.json"; fi
            _ptype=$(classify_package_json "$_pj")
            [ -n "$_ptype" ] && _found="$_found $_ptype"
        done <<< "$_cand"
    fi

    # ── 2) 마커가 전혀 없으면 확장자 빈도 폴백 ──
    if [ -z "$_found" ]; then
        local _files
        _files=$(find . -maxdepth 3 \
            \( -name node_modules -o -name .git -o -name build -o -name dist \
               -o -name .dart_tool -o -name android -o -name ios -o -name .gradle \
               -o -name venv -o -name .venv -o -name __pycache__ \) -prune \
            -o -type f -print 2>/dev/null)
        local _dart _java _kt _gradle _tsx _jsx _py _ts _js
        _dart=$(printf '%s\n' "$_files"   | grep -c '\.dart$' || true)
        _java=$(printf '%s\n' "$_files"   | grep -c '\.java$' || true)
        _kt=$(printf '%s\n' "$_files"     | grep -c '\.kt$' || true)
        _gradle=$(printf '%s\n' "$_files" | grep -c '\.gradle$' || true)
        _tsx=$(printf '%s\n' "$_files"    | grep -c '\.tsx$' || true)
        _jsx=$(printf '%s\n' "$_files"    | grep -c '\.jsx$' || true)
        _py=$(printf '%s\n' "$_files"     | grep -c '\.py$' || true)
        _ts=$(printf '%s\n' "$_files"     | grep -c '\.ts$' || true)
        _js=$(printf '%s\n' "$_files"     | grep -c '\.js$' || true)
        [ "$_dart" -ge 1 ] && _found="$_found flutter"
        [ $((_java + _kt + _gradle)) -ge 3 ] && _found="$_found spring"
        [ $((_tsx + _jsx)) -ge 3 ] && _found="$_found react"
        [ "$_py" -ge 3 ] && _found="$_found python"
        if [ -z "$_found" ] && [ $((_ts + _js)) -ge 3 ]; then
            _found="node"
        fi
    fi

    # ── 3) 메뉴 정의 순서로 정렬 + 중복 제거 → csv ──
    local _order="spring flutter next react react-native react-native-expo node python basic"
    local _o _out=""
    for _o in $_order; do
        case " $_found " in
            *" $_o "*) _out="${_out:+$_out,}$_o" ;;
        esac
    done
    echo "$_out"
}

# ===================================================================
# 타입별 프로젝트 경로 (project_paths) 감지·확정
# ===================================================================

# PROJECT_PATHS_CSV에서 타입의 경로 조회 (없으면 빈 문자열)
get_path_for_type() {
    local t=$1
    local pair
    local _ifs_bak="${IFS-$' \t\n'}"  # IFS가 unset이면 기본값으로 복원 (빈 문자열 오염 방지)
    IFS=','
    for pair in $PROJECT_PATHS_CSV; do
        IFS="$_ifs_bak"
        case "$pair" in
            "$t="*) echo "${pair#*=}"; return ;;
        esac
        IFS=','
    done
    IFS="$_ifs_bak"
    echo ""
}

# PROJECT_PATHS_CSV에 타입=경로 저장 (이미 있으면 교체)
set_path_for_type() {
    local t=$1
    local p=$2
    local out=""
    local pair
    local _ifs_bak="${IFS-$' \t\n'}"  # IFS가 unset이면 기본값으로 복원 (빈 문자열 오염 방지)
    IFS=','
    for pair in $PROJECT_PATHS_CSV; do
        IFS="$_ifs_bak"
        [ -z "$pair" ] && { IFS=','; continue; }
        case "$pair" in
            "$t="*) IFS=','; continue ;;
        esac
        out="${out:+$out,}$pair"
        IFS=','
    done
    IFS="$_ifs_bak"
    PROJECT_PATHS_CSV="${out:+$out,}$t=$p"
}

# 타입의 대표 마커 파일명 (감지·version.yml 주석용)
marker_for_type() {
    case "$1" in
        flutter) echo "pubspec.yaml" ;;
        react|next|node|react-native) echo "package.json" ;;
        react-native-expo) echo "app.json" ;;
        python) echo "pyproject.toml" ;;
        spring) echo "build.gradle" ;;
        *) echo "" ;;
    esac
}

# 디렉토리에 실재하는 마커 파일명 반환 (보조 마커 포함) — 없으면 대표 마커 반환 (표시용)
existing_marker_in_dir() {
    local t=$1
    local d=$2
    local names n
    case "$t" in
        spring) names="build.gradle build.gradle.kts pom.xml" ;;
        python) names="pyproject.toml setup.py requirements.txt" ;;
        *) names=$(marker_for_type "$t") ;;
    esac
    for n in $names; do
        if [ -f "$d/$n" ]; then echo "$n"; return; fi
    done
    marker_for_type "$t"
}

# 타입별 마커 파일 후보 검색 — 후보 디렉토리 상대경로를 줄단위 출력 (루트는 ".")
# maxdepth 3 + 잡음 폴더 제외 + 타입별 오탐 필터 (스펙 §4.2~4.3)
find_type_path_candidates() {
    local t=$1
    # 멀티모듈 스프링: settings.gradle(.kts)이 있는 폴더 = 멀티모듈 루트로 축약.
    # 루트뿐 아니라 server/ 같은 하위 폴더도 maxdepth 3까지 탐색해 그 폴더를 후보로 잡는다.
    # version_manager가 해당 폴더 아래 모든 build.gradle을 일괄 갱신하므로 하위 모듈을 후보로 펼치지 않는다.
    # android/ 폴더의 settings.gradle(Flutter/RN)은 spring 모듈이 아니므로 prune으로 제외.
    if [ "$t" = "spring" ]; then
        local _mm
        _mm=$(find . -maxdepth 3 \
            \( -name node_modules -o -name .git -o -name build -o -name dist \
               -o -name .gradle -o -name android -o -name ios \) -prune \
            -o -type f \( -name settings.gradle -o -name settings.gradle.kts \) -print 2>/dev/null \
            | sed 's#/settings\.gradle\(\.kts\)\{0,1\}$##; s#^\./##; s#^$#.#' | sort -u)
        # settings.gradle 발견 시: 그 폴더(들)만 후보로 반환. 단일이면 자동확정, 복수면 메뉴 선택.
        if [ -n "$_mm" ]; then
            echo "$_mm"
            return 0
        fi
        # settings.gradle 전혀 없음 → 단일 모듈. 아래 build.gradle 탐색 폴백으로 진행.
    fi
    local names=""
    case "$t" in
        flutter)            names="pubspec.yaml" ;;
        react|next|node)    names="package.json" ;;
        react-native)       names="package.json" ;;
        react-native-expo)  names="app.json" ;;
        python)             names="pyproject.toml setup.py requirements.txt" ;;
        spring)             names="build.gradle build.gradle.kts pom.xml" ;;
        *) return 0 ;;
    esac

    local n found=""
    for n in $names; do
        found=$(find . -maxdepth 3 \
            \( -name node_modules -o -name .git -o -name build -o -name dist \
               -o -name .dart_tool -o -name android -o -name ios -o -name .gradle \
               -o -name venv -o -name .venv -o -name __pycache__ \) -prune \
            -o -type f -name "$n" -print 2>/dev/null)
        [ -n "$found" ] && break  # 우선순위 높은 마커에서 발견되면 그것만 사용
    done
    [ -z "$found" ] && return 0

    local f d _libdir
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        d=$(dirname "$f")
        d="${d#./}"
        if [ "$d" = "." ] || [ -z "$d" ]; then d="."; fi
        case "$t" in
            flutter)
                # example/ 제외 + lib/ 동반 확인 (오탐 방지)
                case "$d" in *example*) continue ;; esac
                if [ "$d" = "." ]; then _libdir="lib"; else _libdir="$d/lib"; fi
                [ -d "$_libdir" ] || continue
                ;;
            spring)
                # Flutter/RN의 android/build.gradle 오탐 제외
                case "$d" in *android*) continue ;; esac
                ;;
        esac
        echo "$d"
    done <<< "$found" | sort -u
}

# 기존 version.yml의 project_paths 값을 PROJECT_PATHS_CSV에 로드만 한다 (질문 없음).
# 이미 init된 프로젝트는 확인 화면에 저장된 경로를 그대로 보여주기 위해 사용한다.
# 반환: 대상 타입(basic 제외) 전부가 이미 채워졌으면 0 (= 경로 질문 불필요), 아니면 1.
load_saved_project_paths() {
    [ ! -f "version.yml" ] && return 1

    local _all_types=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
    local _targets=() _t
    for _t in "${_all_types[@]}"; do
        [ "$_t" = "basic" ] && continue
        _targets+=("$_t")
    done
    [ ${#_targets[@]} -eq 0 ] && return 0  # basic만이면 경로 불필요

    # 대상 타입을 version.yml의 project_paths 저장값으로 채운다 (이미 있으면 건드리지 않음)
    local _in_paths=false _line _key _val _existing
    for _t in "${_targets[@]}"; do
        # 이미 채워져 있으면(예: --paths) 건너뜀
        _existing=$(get_path_for_type "$_t")
        [ -n "$_existing" ] && continue
        # version.yml의 project_paths 블록에서 해당 타입 줄 찾기
        _in_paths=false
        while IFS= read -r _line; do
            case "$_line" in
                project_paths:*) _in_paths=true; continue ;;
            esac
            if [ "$_in_paths" = true ]; then
                # '  flutter: "app"' 형태
                if printf '%s' "$_line" | grep -qE "^  ${_t}:[[:space:]]*\""; then
                    _val=$(printf '%s' "$_line" | sed -E "s/^  ${_t}:[[:space:]]*\"([^\"]*)\".*/\1/")
                    [ -n "$_val" ] && set_path_for_type "$_t" "$_val"
                    break
                fi
                # 다른 최상위 키(들여쓰기 없음) → 섹션 종료
                case "$_line" in
                    [!\ ]*) break ;;
                esac
            fi
        done < version.yml
    done

    # 대상 전부가 채워졌는지 확인
    for _t in "${_targets[@]}"; do
        [ -z "$(get_path_for_type "$_t")" ] && return 1
    done
    return 0
}

# 선택된 모든 타입의 경로를 감지·확인하여 PROJECT_PATHS_CSV 확정 (스펙 §4)
resolve_project_paths() {
    # --paths 사전 검증·정규화: 타입 유효성 + 경로 정규화 (백슬래시→슬래시, 끝 슬래시·앞 ./ 제거)
    if [ -n "$PROJECT_PATHS_CSV" ]; then
        local _vpair _vt _vp _vnorm=""
        local _ifs_bak="${IFS-$' \t\n'}"
        IFS=','
        for _vpair in $PROJECT_PATHS_CSV; do
            IFS="$_ifs_bak"
            [ -z "$_vpair" ] && { IFS=','; continue; }
            _vt="${_vpair%%=*}"
            _vp="${_vpair#*=}"
            # 타입 토큰 앞뒤 공백 트림 — "flutter=app, react=client" 같은 콤마 뒤 공백 허용
            _vt=$(printf '%s' "$_vt" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            local _valid=false _v
            for _v in "${VALID_TYPES[@]}"; do
                [ "$_v" = "$_vt" ] && _valid=true && break
            done
            if [ "$_valid" = false ]; then
                print_error "--paths에 지원하지 않는 타입: '$_vt'"
                print_error "지원 타입: ${VALID_TYPES[*]}"
                exit 1
            fi
            _vp=$(echo "$_vp" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s#\\#/#g; s#/$##; s#^\./##')
            [ -z "$_vp" ] && _vp="."
            if [ ! -f "$_vp/$(existing_marker_in_dir "$_vt" "$_vp")" ]; then
                print_warning "--paths: $_vt=$_vp 경로에서 마커 파일을 찾지 못했지만 입력값을 그대로 기록합니다"
            fi
            _vnorm="${_vnorm:+$_vnorm,}$_vt=$_vp"
            IFS=','
        done
        IFS="$_ifs_bak"
        PROJECT_PATHS_CSV="$_vnorm"
    fi

    local _all_types=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
    local _targets=()
    local _t
    for _t in "${_all_types[@]}"; do
        [ "$_t" = "basic" ] && continue
        _targets+=("$_t")
    done
    [ ${#_targets[@]} -eq 0 ] && return 0  # basic만이면 경로 불필요

    local _total=${#_targets[@]}

    print_step "타입별 프로젝트 경로 확인 중..."
    print_to_user ""
    # ── 도입부: 무엇이 감지됐고 이제 무엇을 할지 먼저 설명 (에이전트형 안내 톤) ──
    if [ "$_total" -gt 1 ]; then
        print_to_user "🔍 멀티타입 프로젝트가 감지되었습니다 — 총 ${_total}개 타입"
    else
        print_to_user "🔍 ${_targets[0]} 프로젝트가 감지되었습니다 — 총 1개 타입"
    fi
    local _ml _mt
    for _ml in "${_targets[@]}"; do
        # 타입명을 8칸으로 패딩해 마커 파일명을 세로로 정렬 (safe_echo와 동일 출력 라우팅)
        _mt=$(existing_marker_in_dir "$_ml" ".")
        print_to_user "$(printf '   • %-8s → %s' "$_ml" "$_mt")"
    done
    print_to_user ""
    print_to_user "각 타입의 프로젝트가 레포 어느 폴더에 있는지 확인이 필요합니다."
    if [ "$_total" -gt 1 ]; then
        print_to_user "이제 하나씩 차례대로 각 프로젝트의 루트 디렉터리를 설정하겠습니다."
    else
        print_to_user "이제 이 프로젝트의 루트 디렉터리를 설정하겠습니다."
    fi
    print_to_user ""
    print_to_user "💡 '프로젝트 루트' = 그 타입의 버전 파일이 있는 폴더 (레포 루트 기준 상대경로)"
    print_to_user "   예) 레포루트/app/pubspec.yaml 이면 → \"app\""
    print_to_user "       레포루트/packages/web/package.json 이면 → \"packages/web\""
    print_to_user "       레포 루트에 바로 있으면 → \".\""
    print_separator_line
    print_to_user ""

    local _idx=0
    for _t in "${_targets[@]}"; do
        _idx=$((_idx + 1))
        local _prog="[$_idx/$_total]"
        # 1) --paths로 이미 지정됨 → 최우선
        local _preset
        _preset=$(get_path_for_type "$_t")
        if [ -n "$_preset" ]; then
            print_info "  $_t → $_preset (--paths 지정)"
            continue
        fi

        # 2) 루트에 마커 존재 → "." 자동 확정 (질문 없이 안내만, 보조 마커 포함)
        local _root_marker
        _root_marker=$(existing_marker_in_dir "$_t" ".")
        if [ -f "$_root_marker" ]; then
            set_path_for_type "$_t" "."
            print_info "  $_t → . (루트의 $_root_marker)"
            continue
        fi

        # 3) 기존 version.yml의 project_paths 값 → 기본 제안값
        local _existing=""
        if [ -f "version.yml" ]; then
            if command -v yq >/dev/null 2>&1; then
                _existing=$(yq -r ".project_paths.\"$_t\" // \"\"" version.yml 2>/dev/null || echo "")
                [ "$_existing" = "null" ] && _existing=""
            else
                _existing=$(sed -n '/^project_paths:/,/^[^ ]/p' version.yml | sed -n "s/^  $_t:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)
            fi
        fi

        # 4) 후보 검색
        local _candidates _count=0
        _candidates=$(find_type_path_candidates "$_t")
        [ -n "$_candidates" ] && _count=$(echo "$_candidates" | grep -c .)

        local _chosen=""

        # ── 비대화형 (--force 또는 TTY 없음): 스펙 §4.5 ──
        if [ "$FORCE_MODE" = true ] || [ "$TTY_AVAILABLE" != true ]; then
            if [ -n "$_existing" ]; then
                _chosen="$_existing"
                print_info "  $_t → $_chosen (기존 project_paths 유지)"
            elif [ "$_count" -eq 1 ]; then
                _chosen="$_candidates"
                print_info "  $_t → $_chosen (자동 감지)"
            else
                _chosen="."
                print_warning "  $_t → 후보 ${_count}개로 자동 확정 불가, 루트(.)로 기록 (--paths \"$_t=경로\"로 지정 가능)"
            fi
            set_path_for_type "$_t" "$_chosen"
            continue
        fi

        # ── 대화형: 후보 개수별 분기 (스펙 §4.4) ──
        if [ "$_count" -eq 1 ]; then
            print_to_user ""
            local _cand_marker _cand_full
            _cand_marker=$(existing_marker_in_dir "$_t" "$_candidates")
            # 루트면 마커만, 하위 폴더면 폴더/마커 — "어디 기준 경로"인지 전체 경로로 노출
            if [ "$_candidates" = "." ]; then _cand_full="$_cand_marker"; else _cand_full="$_candidates/$_cand_marker"; fi
            print_to_user "  $_prog 🔍 $_t — $_cand_marker 발견"
            print_to_user "      위치: <레포루트>/$_cand_full"
            print_to_user ""
            # '아니오' 선택 시 _chosen 미설정 → 아래 직접입력 루프로 진행
            if ask_yes_no "  $_t 프로젝트 루트를 '$_candidates'(으)로 설정할까요? ($_cand_full 기준 — 아니오 선택 시 직접 입력)" "Y"; then
                _chosen="$_candidates"
            fi
        elif [ "$_count" -gt 1 ]; then
            print_to_user ""
            print_to_user "  $_prog 🔍 $_t: 경로 후보 ${_count}개 발견"
            # 후보들 + '직접 입력'을 화살표 메뉴로 (다른 메뉴와 통일). value=후보경로, 마지막은 직접입력 센티넬.
            local _opts=() _c
            while IFS= read -r _c; do
                [ -z "$_c" ] && continue
                _opts+=("$_c|$(existing_marker_in_dir "$_t" "$_c")")   # value=경로, label=마커파일명
            done <<< "$_candidates"
            _opts+=("직접 입력|")   # value 자체를 한국어로 — 센티넬 노출 방지
            local _sel
            _sel=$(choose_menu "  $_t 프로젝트 루트를 선택하세요" "${_opts[@]}") || _sel="직접 입력"
            if [ "$_sel" = "직접 입력" ] || [ -z "$_sel" ]; then
                : # _chosen 미설정 → 아래 직접입력 루프로
            else
                _chosen="$_sel"
            fi
        else
            print_to_user ""
            print_warning "  $_prog $_t: 프로젝트를 찾지 못했습니다 (maxdepth 3)."
        fi

        # ── 직접 입력 (위에서 미확정 시) ──
        while [ -z "$_chosen" ]; do
            local _input="" _prompt _hint_marker
            # 루트(.) 기준 마커명으로 힌트 — 어떤 파일이 있는 폴더인지 사용자에게 명시
            _hint_marker=$(existing_marker_in_dir "$_t" ".")
            _prompt="  $_t 프로젝트 루트 경로 입력 ($_hint_marker 이 있는 폴더, 예: server, app — 루트면 그냥 Enter"
            if [ -n "$_existing" ]; then
                _prompt="$_prompt, 현재값: $_existing"
            fi
            _prompt="$_prompt): "
            # set -e 가드: ESC(return 2)로 함수가 죽지 않게 || true. 빈값이면 아래서 기존값/루트로 폴백.
            safe_read "$_prompt" _input "" || true
            # 정규화: 공백 제거, 백슬래시→슬래시, 끝 슬래시·앞 ./ 제거
            _input=$(echo "$_input" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s#\\#/#g; s#/$##; s#^\./##')
            if [ -z "$_input" ]; then
                if [ -n "$_existing" ]; then _input="$_existing"; else _input="."; fi
            fi
            # 검증: 입력 경로에 마커 존재 확인 (보조 마커 포함)
            if [ -f "$_input/$(existing_marker_in_dir "$_t" "$_input")" ]; then
                _chosen="$_input"
            else
                print_warning "  $_input/$(existing_marker_in_dir "$_t" "$_input") 파일이 없습니다."
                if ask_yes_no "  그래도 이 경로를 사용할까요? (Y/N): " "N"; then
                    _chosen="$_input"
                fi
            fi
        done

        set_path_for_type "$_t" "$_chosen"
        print_success "  $_t → $_chosen"
    done

    # ── 요약 출력 + 동일 파일 중복 안내 (스펙 §4.4) ──
    print_to_user ""
    print_to_user "📂 타입별 버전 파일 경로 확정:"
    local _pair _pt _pp _m _file _lines=""
    local _ifs_bak="${IFS-$' \t\n'}"  # IFS가 unset이면 기본값으로 복원 (빈 문자열 오염 방지)
    IFS=','
    for _pair in $PROJECT_PATHS_CSV; do
        IFS="$_ifs_bak"
        _pt="${_pair%%=*}"
        _pp="${_pair#*=}"
        _m=$(existing_marker_in_dir "$_pt" "${_pp:-.}")
        if [ "$_pp" = "." ]; then _file="$_m"; else _file="$_pp/$_m"; fi
        print_to_user "   $_pt → $_file"
        _lines="${_lines}${_file}|${_pt}"$'\n'
        IFS=','
    done
    IFS="$_ifs_bak"

    # 같은 파일을 둘 이상의 타입이 바라보면 경고 (멱등 동작이라 막지는 않음)
    local _dups
    _dups=$(printf '%s' "$_lines" | awk -F'|' '{cnt[$1]++; t[$1]=t[$1]" "$2} END{for (f in cnt) if (cnt[f]>1) print f":"t[f]}')
    if [ -n "$_dups" ]; then
        local _dl
        while IFS= read -r _dl; do
            [ -z "$_dl" ] && continue
            print_warning "  ⚠️ 같은 파일(${_dl%%:*})을 여러 타입(${_dl#*:} )이 바라봅니다."
            print_warning "     → 이렇게 하면 sync 때 모두 같은 버전이 기록됩니다. 동작에는 문제없지만 의도한 구성인지 확인하세요."
        done <<< "$_dups"
    fi
    print_to_user ""
}

# 버전 자동 감지
detect_version() {
    print_step "버전 정보 자동 감지 중..."
    
    local detected_version=""
    
    # package.json
    if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
        detected_version=$(jq -r '.version // empty' package.json 2>/dev/null)
        if [ -n "$detected_version" ]; then
            print_info "✓ package.json에서 버전 감지: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi
    
    # build.gradle (Spring Boot)
    # macOS 호환: grep -oP(\K)는 GNU 전용 → BSD grep에서 'invalid option -- P'.
    # grep -E로 라인만 찾고 sed -E로 첫 버전 토큰을 추출 (BSD/GNU 모두 동작).
    if [ -f "build.gradle" ]; then
        detected_version=$(grep -E "version[[:space:]]*=" build.gradle 2>/dev/null \
            | sed -E "s/.*version[[:space:]]*=[[:space:]]*['\"]?([0-9]+\.[0-9]+\.[0-9]+).*/\1/" \
            | grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" | head -1)
        if [ -n "$detected_version" ]; then
            print_info "✓ build.gradle에서 버전 감지: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi

    # pubspec.yaml (Flutter)
    if [ -f "pubspec.yaml" ]; then
        detected_version=$(grep -E "^version:" pubspec.yaml 2>/dev/null \
            | sed -E "s/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/" \
            | grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" | head -1)
        if [ -n "$detected_version" ]; then
            print_info "✓ pubspec.yaml에서 버전 감지: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi

    # pyproject.toml (Python)
    if [ -f "pyproject.toml" ]; then
        detected_version=$(grep -E "version[[:space:]]*=" pyproject.toml 2>/dev/null \
            | sed -E "s/.*version[[:space:]]*=[[:space:]]*['\"]?([0-9]+\.[0-9]+\.[0-9]+).*/\1/" \
            | grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" | head -1)
        if [ -n "$detected_version" ]; then
            print_info "✓ pyproject.toml에서 버전 감지: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi
    
    # Git 태그
    if git rev-parse --git-dir > /dev/null 2>&1; then
        detected_version=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
        if [ -n "$detected_version" ]; then
            print_info "✓ Git 태그에서 버전 감지: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi
    
    # 기본값
    print_warning "버전을 감지하지 못했습니다. 기본값 0.0.1로 설정합니다."
    echo "0.0.1"
}

# Default branch 감지
detect_default_branch() {
    local detected=""
    
    # GitHub CLI
    if command -v gh >/dev/null 2>&1; then
        detected=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")
        if [ -n "$detected" ]; then
            echo "$detected"
            return
        fi
    fi
    
    # git symbolic-ref
    detected=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
    if [ -n "$detected" ]; then
        echo "$detected"
        return
    fi
    
    # git remote show
    detected=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | sed 's/.*: //' || echo "")
    if [ -n "$detected" ]; then
        echo "$detected"
        return
    fi
    
    # 기본값
    echo "main"
}

# 구분선 출력 (40자)
print_separator_line() {
    local line="────────────────────────────────────────"
    safe_echo "$line"
}

# 섹션 헤더 출력 (80자 구분선)
print_section_header() {
    local emoji="$1"
    local title="$2"
    local line="────────────────────────────────────────────────────────────────────────────────"
    
    safe_echo ""
    safe_echo "$line"
    safe_echo "$emoji $title"
    safe_echo "$line"
}

# 질문 헤더 출력 (40자 구분선)
print_question_header() {
    local emoji="$1"
    local question="$2"
    
    safe_echo ""
    print_separator_line
    safe_echo "$emoji $question"
    print_separator_line
    safe_echo ""
}

# 프로젝트 타입 선택 메뉴
show_project_type_menu() {
    # ── 레포 스캔 → 추천 로그 (append-only) ──
    # 1) 마커 기반 감지 (basic이면 마커 없음)
    local _detected_csv
    _detected_csv=$(detect_project_types 2>/dev/null)

    print_to_user "" >&2
    print_to_user "🔍 이 레포를 살펴봤습니다:" >&2

    local _marker_csv=""
    if [ -n "$_detected_csv" ] && [ "$_detected_csv" != "basic" ]; then
        _marker_csv="$_detected_csv"
        local _mt
        local IFS=','
        for _mt in $_detected_csv; do
            unset IFS
            print_to_user "   • $(marker_for_type "$_mt") 발견 → $_mt 추천 (자동 선택됨)" >&2
            IFS=','
        done
        unset IFS
    else
        # 2) 마커 없음 → 확장자 스캔 추천 (안내만)
        local _scan_csv
        _scan_csv=$(suggest_types_by_scan)
        if [ -n "$_scan_csv" ]; then
            local _st
            local IFS=','
            for _st in $_scan_csv; do
                unset IFS
                print_to_user "   • $_st 관련 파일 발견 → $_st 가능성 (직접 골라주세요)" >&2
                IFS=','
            done
            unset IFS
        else
            print_to_user "   • 마커 파일을 찾지 못했습니다 — 직접 선택하세요" >&2
        fi
    fi

    # 현재 version.yml 값 안내
    local _cur
    local IFS=','
    _cur="${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
    unset IFS
    print_to_user "   • 현재 값: ${_cur:-basic}" >&2
    print_to_user "" >&2

    # ── preselect: 마커 추천이 있으면 그것, 없으면 현재값 ──
    local _preselect
    if [ -n "$_marker_csv" ]; then
        _preselect="$_marker_csv"
    else
        local IFS=','
        _preselect="${PROJECT_TYPES[*]:-}"
        unset IFS
    fi

    # 하위 메뉴이므로 ESC는 '뒤로'. set -e 환경에서 ESC(비-0)가 함수를 죽이지 않도록 || true 가드.
    local selected=""
    selected=$(choose_menu --multi --cancel-label="뒤로" --preselect="$_preselect" "프로젝트 타입을 선택하세요" \
        "spring|Spring Boot 백엔드" \
        "flutter|Flutter 모바일 앱" \
        "next|Next.js 웹 앱" \
        "react|React 웹 앱" \
        "react-native|React Native 모바일 앱" \
        "react-native-expo|React Native Expo 앱" \
        "node|Node.js 프로젝트" \
        "python|Python 프로젝트" \
        "basic|기타 프로젝트") || true

    if [ -z "$selected" ]; then
        print_info "타입 선택을 취소했습니다 — 기존 설정을 그대로 유지합니다."
        local IFS=','
        echo "${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
        unset IFS
        return 1
    fi

    echo "$selected"
}

# 프로젝트 감지 및 확인
# 프로젝트 분석 결과 개요 출력 (감지된 타입·버전·브랜치·모드·옵션 워크플로우·경로)
# detect_and_confirm_project(확인 화면)와 handle_project_edit_menu(수정 직후)에서
# 동일하게 호출해, 항목을 고칠 때마다 현재 상태를 한눈에 다시 보여준다.
print_project_analysis() {
    print_section_header "🛰️" "프로젝트 분석 결과"

    # 감지 결과 표시 — 멀티면 csv로, 단일이면 기존 형식
    local _types_display
    local IFS=','
    _types_display="${PROJECT_TYPES[*]}"
    unset IFS

    print_to_user ""
    if [ ${#PROJECT_TYPES[@]} -gt 1 ]; then
        print_to_user "       📂 Project Types    : $_types_display (멀티)"
    else
        print_to_user "       📂 Project Type     : $PROJECT_TYPE"
    fi
    print_to_user "       🌙 Version          : $VERSION"
    print_to_user "       🌿 Default Branch   : $DETECTED_BRANCH"
    # 모드  : 무엇을 설치하는지 (확인 화면에서 한눈에)
    [ -n "$MODE" ] && print_to_user "       💫 통합 모드        : $(_mode_display_label "$MODE")"
    # 선택 워크플로우 : full/workflows에서 수집된 경우만 표시 (값이 있을 때만)
    if [ "$INCLUDE_NEXUS" = true ]; then
        print_to_user "       📦 Nexus publish    : 포함"
    elif [ "$INCLUDE_NEXUS" = false ]; then
        print_to_user "       📦 Nexus publish    : 제외"
    fi
    if [ "$INCLUDE_SECRET_BACKUP" = true ]; then
        print_to_user "       🔐 Secret 백업      : 포함"
    elif [ "$INCLUDE_SECRET_BACKUP" = false ]; then
        print_to_user "       🔐 Secret 백업      : 제외"
    fi
    # 프로젝트 경로 : full/version에서 확정된 경우만 표시 (멀티경로 한눈에)
    if [ -n "$PROJECT_PATHS_CSV" ]; then
        print_to_user "       📁 프로젝트 경로    : $(echo "$PROJECT_PATHS_CSV" | sed 's/=/→/g; s/,/, /g')"
    fi
    print_to_user ""
}

detect_and_confirm_project() {
    # 자동 감지 (최초 1회만) — --type으로 PROJECT_TYPES가 이미 채워졌으면 건너뜀
    if [ ${#PROJECT_TYPES[@]} -eq 0 ]; then
        local _detected_csv
        _detected_csv=$(detect_project_types)
        IFS=',' read -ra PROJECT_TYPES <<< "$_detected_csv"
        PROJECT_TYPE="${PROJECT_TYPES[0]}"
    fi
    if [ -z "$VERSION" ]; then
        VERSION=$(detect_version)
    fi
    if [ -z "$DETECTED_BRANCH" ]; then
        DETECTED_BRANCH=$(detect_default_branch)
    fi

    local confirmed=false

    # 확인 루프 - Edit 선택 시 다시 확인 질문으로 돌아옴
    while [ "$confirmed" = false ]; do
        print_project_analysis

        # 사용자 확인 — 화살표 3지선 메뉴 (TTY 대화형). 비TTY/FORCE는 기존 키 입력 폴백.
        local user_choice
        if [ "$TTY_AVAILABLE" = true ] && [ "$FORCE_MODE" = false ]; then
            # 영어 키 노출 방지: 한국어 라벨을 value로 두고 반환값을 매핑
            local _confirm_label _confirm_rc=0
            # set -e 환경: choose_menu가 ESC로 비-0 반환 시 함수가 즉시 중단되지 않도록
            # || 로 종료코드를 받아 stay(머무름) 분기로 안전하게 흘려보낸다.
            # 최상위 확인 화면 — ESC는 종료가 아니라 stay(머무름)이므로 안내도 "머무르기"로.
            # (ps1 Ask-YesNoEdit와 문구·동작 동일)
            _confirm_label=$(choose_menu --cancel-label="머무르기" "위 분석 결과가 맞습니까?" \
                "예, 계속 진행|" \
                "수정하기|" \
                "아니오, 취소|") || _confirm_rc=$?
            if [ "$_confirm_rc" -ne 0 ]; then
                # ESC — 여기는 최상위 확인 화면이라 더 뒤로 갈 단계가 없다.
                # 의도치 않은 종료를 막기 위해 그 자리에 머문다(루프 재출력).
                # 실제 종료는 '아니오, 취소'를 명시적으로 골라야만 한다.
                user_choice="stay"
            else
                case "$_confirm_label" in
                    예*)  user_choice="yes" ;;
                    수정*) user_choice="edit" ;;
                    아니오*) user_choice="no" ;;   # 명시적 취소만 종료
                    *)    user_choice="stay" ;;
                esac
            fi
        else
            user_choice=$(ask_yes_no_edit)
        fi

        case "$user_choice" in
            "yes")
                confirmed=true
                print_success "프로젝트 정보 검증 완료 — 이 설정으로 통합을 진행합니다"
                print_to_user ""
                ;;
            "no")
                print_info "통합을 취소했습니다. (다시 실행하면 처음부터 설정할 수 있습니다)"
                exit 0
                ;;
            "edit")
                # handle_project_edit_menu는 '뒤로'(ESC) 시 return 1을 준다.
                # set -e 환경에서 그 비-0 반환이 이 함수를 죽이지 않도록 || true로 흡수.
                # 어느 경우든 확인 루프를 계속 돌아 다시 확인 화면을 보여준다.
                handle_project_edit_menu || true
                ;;
            "stay")
                # ESC 등으로 인한 중립 상태 — 종료하지 않고 확인 화면을 다시 보여준다
                ;;
            *)
                print_error "예상치 못한 오류가 발생했습니다"
                exit 1
                ;;
        esac
    done
}

# 프로젝트 정보 수정 메뉴
# 루프 구조: 항목을 고쳐도 메뉴로 되돌아와 다른 항목을 이어서 수정할 수 있다.
# '모두 맞음, 계속' 또는 ESC(뒤로) → 상위 확인 화면으로 복귀.
# set -e 환경: 메뉴/입력이 ESC로 비-0 반환해도 함수가 죽지 않도록 모두 || 로 코드를 받는다.
handle_project_edit_menu() {
    while true; do
        # 항목을 고칠 때마다 현재 확정된 전체 설정 개요를 먼저 다시 보여준다.
        # (수정 → 개요 확인 → 다음 선택 흐름 — 변경이 어떻게 반영됐는지 한눈에 파악)
        print_project_analysis
        print_question_header "💫" "어떤 항목을 수정할까요?"

        # 영어 키 노출 방지: 한국어 라벨을 value로 두고 반환값을 매핑
        # 하위 메뉴이므로 ESC는 '뒤로'(상위 확인 화면으로) 표기.
        # 선택 워크플로우(Nexus/Secret 백업) 항목은 워크플로우를 설치하는 모드(full/workflows)에서만 노출한다.
        # (version 모드는 워크플로우를 안 깔아 무관.)
        local _edit_opts=("프로젝트 타입|" "버전|" "기본 브랜치|")
        if [ "$MODE" = "full" ] || [ "$MODE" = "workflows" ]; then
            local _nx_state="제외"; [ "$INCLUDE_NEXUS" = "true" ] && _nx_state="포함"
            local _sb_state="제외"; [ "$INCLUDE_SECRET_BACKUP" = "true" ] && _sb_state="포함"
            _edit_opts+=("Nexus publish 포함 여부 (현재: ${_nx_state})|")
            _edit_opts+=("Secret 백업 포함 여부 (현재: ${_sb_state})|")
        fi
        _edit_opts+=("모두 맞음, 계속|" "뒤로 (변경 없이 확인 화면으로)|")

        local _edit_label _menu_rc=0
        _edit_label=$(choose_menu --cancel-label="뒤로" "어떤 항목을 수정하시겠습니까?" \
            "${_edit_opts[@]}") || _menu_rc=$?

        local edit_choice=""
        if [ "$_menu_rc" -ne 0 ]; then
            # ESC → 상위 확인 화면으로 뒤로
            edit_choice="back"
        else
            case "$_edit_label" in
                프로젝트\ 타입*) edit_choice="type" ;;
                버전*)           edit_choice="version" ;;
                기본\ 브랜치*)   edit_choice="branch" ;;
                Nexus*)          edit_choice="optional" ;;
                Secret*)         edit_choice="optional" ;;
                모두\ 맞음*)     edit_choice="done" ;;
                뒤로*)           edit_choice="back" ;;
                *)               edit_choice="back" ;;
            esac
        fi

        case "$edit_choice" in
            type)
                local _old_csv
                local IFS=','
                _old_csv="${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
                unset IFS

                local _new_csv
                _new_csv=$(show_project_type_menu) || _new_csv=""
                if [ -n "$_new_csv" ]; then
                    IFS=',' read -ra PROJECT_TYPES <<< "$_new_csv"
                    PROJECT_TYPE="${PROJECT_TYPES[0]}"
                    if [ ${#PROJECT_TYPES[@]} -gt 1 ]; then
                        print_success "프로젝트 타입을 '${PROJECT_TYPES[*]}'(으)로 변경했습니다"
                    else
                        print_success "프로젝트 타입을 '$PROJECT_TYPE'(으)로 변경했습니다"
                    fi

                    # ★ 타입이 실제로 바뀌었으면 그 자리에서 path 감지를 바로 이어 붙임
                    # (선택 순서가 달라도 같은 집합이면 변경 아님 — 정렬 후 비교)
                    local _old_sorted _new_sorted
                    _old_sorted=$(printf '%s\n' "$_old_csv" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,*$//')
                    _new_sorted=$(printf '%s\n' "$_new_csv" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,*$//')
                    if [ "$_new_sorted" != "$_old_sorted" ]; then
                        PROJECT_PATHS_CSV=""   # 새 타입 기준으로 다시 잡도록 초기화
                        resolve_project_paths
                    fi
                fi
                print_to_user ""
                ;;
            version)
                local new_version _rc=0
                print_to_user ""
                safe_read "새 버전을 입력하세요 (예: 1.0.0, ESC=뒤로): " new_version "" || _rc=$?
                if [ "$_rc" -eq 2 ]; then
                    # ESC → 이전 메뉴로 돌아감(기존 값 유지)
                    print_info "이전 메뉴로 돌아갑니다 — 기존 설정을 유지합니다."
                    print_to_user ""
                elif [ "$_rc" -eq 0 ]; then
                    print_to_user ""
                    if [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        VERSION="$new_version"
                        print_success "버전을 '$VERSION'(으)로 변경했습니다"
                    else
                        print_error "버전 형식이 올바르지 않습니다 (x.y.z 형태로 입력) — 기존 값을 유지합니다."
                    fi
                    print_to_user ""
                else
                    print_warning "입력을 읽지 못했습니다 — 기존 값을 그대로 유지합니다."
                    print_to_user ""
                fi
                ;;
            branch)
                local new_branch _rc=0
                print_to_user ""
                print_to_user "💡 이 설정은 GitHub Actions 워크플로우에서 사용할 기본 브랜치입니다."
                print_to_user ""
                safe_read "기본 브랜치 이름을 입력하세요 (예: main, develop, ESC=뒤로): " new_branch "" || _rc=$?
                if [ "$_rc" -eq 2 ]; then
                    # ESC → 이전 메뉴로 돌아감(기존 값 유지)
                    print_info "이전 메뉴로 돌아갑니다 — 기존 설정을 유지합니다."
                    print_to_user ""
                elif [ "$_rc" -eq 0 ]; then
                    print_to_user ""
                    if [ -n "$new_branch" ]; then
                        DETECTED_BRANCH="$new_branch"
                        print_success "기본 브랜치를 '$DETECTED_BRANCH'(으)로 변경했습니다"
                    else
                        print_error "브랜치 이름이 비어 있어 변경하지 않고 기존 값을 유지합니다."
                    fi
                    print_to_user ""
                else
                    print_warning "입력을 읽지 못했습니다 — 기존 값을 그대로 유지합니다."
                    print_to_user ""
                fi
                ;;
            optional)
                # 선택 워크플로우(Nexus/Secret 백업) 포함 여부를 다시 묻는다. --force-ask로 이미 설정된 값이 있어도 무조건 재질문.
                # ask_all_optional_workflows이 nexus·secret-backup 폴더를 스캔해 발견 시 안내+질문하고 INCLUDE_NEXUS·INCLUDE_SECRET_BACKUP를 갱신한다.
                local _opt_dirs=() _st
                for _st in "${PROJECT_TYPES[@]:-$PROJECT_TYPE}"; do
                    _opt_dirs+=("$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR/$_st")
                done
                ask_all_optional_workflows --force-ask "${_opt_dirs[@]}"
                print_to_user ""
                ;;
            done)
                print_success "수정을 마쳤습니다 — 확인 화면으로 돌아갑니다"
                print_to_user ""
                return 0
                ;;
            back)
                # ESC/취소 → 상위 확인 화면으로 복귀(변경 없이)
                return 1
                ;;
        esac
    done
}

# 템플릿 다운로드
download_template() {
    # 이미 다운로드되었으면 건너뛰기 (중복 호출 방지)
    if [ -d "$TEMP_DIR" ] && [ -d "$TEMP_DIR/.github" ]; then
        print_info "템플릿이 이미 다운로드되어 있습니다. 건너뜁니다."
        return
    fi

    print_step "템플릿을 GitHub 저장소에서 내려받고 있습니다..."

    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    git clone --depth 1 --quiet "$TEMPLATE_REPO" "$TEMP_DIR" 2>/dev/null || {
        print_error "템플릿 다운로드 실패"
        exit 1
    }
    
    # 문서 파일 제거 (프로젝트 특화 문서는 복사하지 않음)
    print_info "프로젝트에는 불필요한 템플릿 내부 문서를 정리하고 있습니다..."
    local docs_to_remove=(
        "CONTRIBUTING.md"
        "CLAUDE.md"
        "AGENTS.md"
        "GEMINI.md"
        "gemini-extension.json"
    )
    
    for doc in "${docs_to_remove[@]}"; do
        if [ -f "$TEMP_DIR/$doc" ]; then
            rm -f "$TEMP_DIR/$doc"
        fi
    done

    # 플러그인 전용 파일/폴더 제거 (마켓플레이스 전용, template_integrator로 배포하지 않음)
    print_info "마켓플레이스 전용 파일(플러그인 메타데이터 등)을 정리하고 있습니다..."
    local plugin_items_to_remove=(
        ".claude-plugin"    # Claude Code 플러그인 매니페스트
        ".codex-plugin"     # Codex 플러그인 메타데이터
        ".agents"           # Codex 마켓플레이스 메타데이터
        ".cursor"           # Cursor 스킬 복사본
        "scripts"           # 플러그인 스크립트 (마켓플레이스 전용)
        "package.json"      # pi 패키지 매니페스트 (마켓플레이스 전용)
        "harness"           # pi Persona Harness (loader/PERSONA/WORKFLOW, 마켓플레이스 전용)
        ".github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml"  # 플러그인 매니페스트 버전 동기화 (위 매니페스트가 제거되므로 동기화 대상 없음)
    )
    # 주의: skills/ 폴더는 Cursor IDE 복사용으로 보존 (offer_ide_tools_install에서 사용 후 정리)

    for item in "${plugin_items_to_remove[@]}"; do
        if [ -d "$TEMP_DIR/$item" ]; then
            rm -rf "$TEMP_DIR/$item"
        elif [ -f "$TEMP_DIR/$item" ]; then
            rm -f "$TEMP_DIR/$item"
        fi
    done

    # 사용자 적용 가이드 문서는 포함 (SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md)
    print_info "사용자용 적용 가이드 문서를 내려받고 있습니다..."
    if [ -f "$TEMP_DIR/SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" ]; then
        print_info "✓ SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    fi

    # 다운로드한 템플릿에서 버전 읽기 (TEMPLATE_VERSION 전역 변수에 저장)
    if [ -f "$TEMP_DIR/version.yml" ]; then
        # version.yml에서 version 값 추출 (예: version: "2.7.5" → 2.7.5)
        TEMPLATE_VERSION=$(grep -E '^version:\s*' "$TEMP_DIR/version.yml" 2>/dev/null | sed 's/version:[[:space:]]*["'\'']*\([^"'\'']*\)["'\'']*$/\1/' | head -1)
        if [ -z "$TEMPLATE_VERSION" ]; then
            TEMPLATE_VERSION="$DEFAULT_VERSION"
        fi
    else
        TEMPLATE_VERSION="$DEFAULT_VERSION"
    fi

    print_success "템플릿 다운로드 완료 — 이제 프로젝트에 맞게 구성합니다"
}


# README.md 버전 섹션 추가
add_version_section_to_readme() {
    local version=$1
    
    print_step "README.md에 버전 관리 섹션 추가 중..."
    
    if [ ! -f "README.md" ]; then
        print_warning "README.md를 찾지 못해 이 단계를 건너뜁니다."
        return
    fi
    
    # 이미 버전 섹션이 있는지 확인 (영어 마커만 체크 - 파싱 호환성)
    if grep -q "<!-- AUTO-VERSION-SECTION" README.md; then
        print_info "이미 버전 관리 섹션이 있습니다. (마커 감지)"
        return
    fi

    # 버전 라인 체크 (버전 번호 패턴 감지)
    if grep -qiE "##[[:space:]]*(최신[[:space:]]*버전|최신버전|Version|버전)[[:space:]]*:[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+" README.md; then
        print_info "이미 버전 관리 섹션이 있습니다. (버전 라인 감지)"
        return
    fi

    # README.md 끝에 버전 섹션 추가
    cat >> README.md << EOF

---

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v${version}

[전체 버전 기록 보기](CHANGELOG.md)
EOF
    
    print_success "README.md에 버전 관리 섹션을 추가했습니다"
    print_info "📝 위치: README.md 파일 하단"
    print_info "🔄 자동 업데이트: PROJECT-README-VERSION-UPDATE.yaml 워크플로우"
}

# version.yml 생성
create_version_yml() {
    local version=$1
    local type=$2
    local branch=$3
    local existing_version_code=1  # 기본값

    # 멀티타입 — PROJECT_TYPES 배열을 ["a","b"] json 형태로, primary는 첫 항목
    # (배열이 비었으면 $type 단수로 fallback — 하위 호환)
    local _types_json _primary_type
    if [ ${#PROJECT_TYPES[@]} -gt 0 ]; then
        local _t _parts=()
        for _t in "${PROJECT_TYPES[@]}"; do _parts+=("\"$_t\""); done
        local IFS=','
        _types_json="[${_parts[*]}]"
        unset IFS
        _primary_type="${PROJECT_TYPES[0]}"
    else
        _types_json="[\"$type\"]"
        _primary_type="$type"
    fi

    print_step "version.yml 생성 중..."
    
    if [ -f "version.yml" ]; then
        # 기존 version.yml에서 version_code 추출
        # 주석이 아닌 실제 데이터 라인에서만 추출 (주석 내 'version_code: 1' 오탐지 방지)
        if command -v yq >/dev/null 2>&1; then
            existing_version_code=$(yq -r '.version_code // 1' version.yml 2>/dev/null || echo "1")
        else
            # grep: 주석(#)으로 시작하지 않는 라인에서만 version_code 추출
            # macOS 호환: grep -P 대신 sed 사용 (BSD grep은 -P 미지원)
            existing_version_code=$(grep -E '^version_code:\s*[0-9]+' version.yml 2>/dev/null | sed 's/[^0-9]//g' | head -1 || echo "1")
        fi
        
        # 숫자 검증 (0보다 큰 정수만 허용)
        if ! [[ "$existing_version_code" =~ ^[0-9]+$ ]] || [ "$existing_version_code" -le 0 ]; then
            existing_version_code=1
        fi

        print_info "기존 version_code 감지: $existing_version_code"

        # version 보존: version.yml이 버전 관리의 single source of truth.
        # 기존 version.yml의 version을 최우선으로 읽어 유지하고, 없을 때만 감지값($version) 폴백.
        local _existing_version=""
        if command -v yq >/dev/null 2>&1; then
            _existing_version=$(yq -r '.version // ""' version.yml 2>/dev/null || echo "")
            [ "$_existing_version" = "null" ] && _existing_version=""
        else
            # 주석(#)이 아닌 실제 version 라인에서만 추출 (x.y.z 형식)
            _existing_version=$(grep -E '^version:[[:space:]]*' version.yml 2>/dev/null \
                | sed 's/version:[[:space:]]*["'\'']*\([0-9][0-9.]*\)["'\'']*.*/\1/' | head -1)
        fi
        if [ -n "$_existing_version" ]; then
            version="$_existing_version"
            print_info "기존 version 보존: $version"
        fi

        # 덮어쓰기 확인 — version.yml 갱신은 통합에 필수.
        # Y=업데이트하고 계속(기본) / N=통합 전체 취소 (반쪽 상태 방지)
        if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
            print_to_user ""
            print_separator_line
            print_to_user " 🔄 version.yml 업데이트 — 안전합니다, 필수입니다"
            print_separator_line
            print_to_user ""
            print_to_user "  기존 version.yml을 최신 템플릿 구조로 갱신합니다."
            print_to_user "  이 단계는 통합에 반드시 필요합니다."
            print_to_user ""
            print_to_user "  ✅ 유지되는 값 (그대로 보존)"
            # printf로 컬럼 정렬한 문자열을 만들어 safe_echo(print_to_user)로 출력 — 출력 대상 일관성 유지
            local _row
            printf -v _row "       %-14s %-11s %s" "version" "$version" "롤백 없음"
            print_to_user "$_row"
            printf -v _row "       %-14s %-11s %s" "version_code" "$existing_version_code" "스토어 빌드번호 안전"
            print_to_user "$_row"
            print_to_user ""
            print_to_user "  📝 갱신되는 것"
            print_to_user "       구조, 주석, project_paths, metadata"
            print_to_user ""
            print_to_user "  ⚠️  업데이트하지 않으면 구버전 구조가 남아"
            print_to_user "       최신 워크플로우의 버전 자동증가, 체인지로그, 배포"
            print_to_user "       동기화가 깨집니다. 그래서 건너뛸 수 없습니다."
            print_to_user ""

            # 기본값 Y — Enter만 쳐도 업데이트. N이면 통합 전체 중단.
            # 선택지(예/아니오)는 아래 ask_yes_no가 화살표 메뉴로 직접 보여주므로 여기서 중복 안내하지 않는다.
            if ! ask_yes_no "  선택 (Y/N, 기본: Y): " "Y"; then
                print_error "통합이 취소되었습니다. version.yml은 변경되지 않았습니다."
                exit 0
            fi
        fi
    fi

    # project_paths 블록 생성 (resolve_project_paths가 확정한 값 — 빈 값이면 블록 생략)
    local _paths_block=""
    if [ -n "$PROJECT_PATHS_CSV" ]; then
        _paths_block="project_paths:                # 타입별 프로젝트 폴더 (레포 루트 기준 상대경로)"$'\n'
        local _pair _pt _pp _pm _pf
        local _ifs_bak="${IFS-$' \t\n'}"  # IFS가 unset이면 기본값으로 복원 (빈 문자열 오염 방지)
        IFS=','
        for _pair in $PROJECT_PATHS_CSV; do
            IFS="$_ifs_bak"
            _pt="${_pair%%=*}"
            _pp="${_pair#*=}"
            _pm=$(existing_marker_in_dir "$_pt" "${_pp:-.}")
            if [ "$_pp" = "." ]; then _pf="$_pm"; else _pf="$_pp/$_pm"; fi
            _paths_block="${_paths_block}  ${_pt}: \"${_pp}\"   # ${_pf}"$'\n'
            IFS=','
        done
        IFS="$_ifs_bak"
    fi

    cat > version.yml << EOF
# ===================================================================
# 프로젝트 버전 관리 파일
# ===================================================================
#
# 이 파일은 다양한 프로젝트 타입에서 버전 정보를 중앙 관리하기 위한 파일입니다.
# GitHub Actions 워크플로우가 이 파일을 읽어 자동으로 버전을 관리합니다.
#
# 사용법:
# 1. version: "1.0.0" - 사용자에게 표시되는 버전
# 2. version_code: 1 - Play Store/App Store 빌드 번호 (1부터 자동 증가)
# 3. project_type: 프로젝트 타입 지정
# 4. project_paths: 타입별 프로젝트 폴더 (레포 루트 기준 상대경로, 모노레포용)
#
# 자동 버전 업데이트:
# - patch: 자동으로 세 번째 자리 증가 (x.x.x -> x.x.x+1)
# - version_code: 매 빌드마다 자동으로 1씩 증가
# - minor/major: 수동으로 직접 수정 필요
#
# 프로젝트 타입별 동기화 파일:
# - spring: build.gradle (version = "x.y.z")
# - flutter: pubspec.yaml (version: x.y.z+i, buildNumber 포함)
# - react/node: package.json ("version": "x.y.z")
# - react-native: iOS Info.plist 또는 Android build.gradle
# - react-native-expo: app.json (expo.version)
# - python: pyproject.toml (version = "x.y.z")
# - basic/기타: version.yml 파일만 사용
#
# 연관된 워크플로우:
# - .github/workflows/PROJECT-VERSION-CONTROL.yaml
# - .github/workflows/PROJECT-README-VERSION-UPDATE.yaml
# - .github/workflows/PROJECT-AUTO-CHANGELOG-CONTROL.yaml
#
# 주의사항:
# - project_type은 최초 설정 후 변경하지 마세요
# - 버전은 항상 높은 버전으로 자동 동기화됩니다
# ===================================================================

version: "$version"
version_code: $existing_version_code  # app build number
project_types: $_types_json   # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능
project_type: "$_primary_type"  # project_types[0] 자동 미러 — 직접 수정 금지 (spring, flutter, next, react, react-native, react-native-expo, node, python, basic)
EOF

    if [ -n "$_paths_block" ]; then
        printf '%s' "$_paths_block" >> version.yml
    fi

    cat >> version.yml << EOF
metadata:
  last_updated: "$(date -u +"%Y-%m-%d %H:%M:%S")"
  last_updated_by: "template_integrator"
  default_branch: "$branch"
  integrated_from: "SUH-DEVOPS-TEMPLATE"
  integration_date: "$(date -u +"%Y-%m-%d")"
EOF

    print_success "version.yml 생성 완료 — 이 파일이 버전 관리의 기준이 됩니다"
}

# ===================================================================
# 선택 워크플로우(Nexus/Secret 백업) 옵션 관리 함수
# ===================================================================

# version.yml에서 템플릿 옵션 읽기
read_template_options() {
    local version_file="version.yml"

    if [ ! -f "$version_file" ]; then
        return
    fi

    # 선택적 워크플로우 옵션 읽기 (metadata.template.options.nexus / .secret_backup)
    # YAML 파싱: template 섹션 내의 options 값들을 찾는다 (하위호환 매핑 없음 — 새 키만)
    local in_template=false
    local in_options=false

    while IFS= read -r line; do
        # template: 섹션 시작 확인
        if [[ "$line" =~ ^[[:space:]]*template: ]]; then
            in_template=true
            continue
        fi

        # template 섹션 내부에서 options: 확인
        if [ "$in_template" = true ] && [[ "$line" =~ ^[[:space:]]+options: ]]; then
            in_options=true
            continue
        fi

        # options 섹션 내부에서 nexus / secret_backup 값 확인
        # (한 키만 읽고 끝내면 안 되므로 continue로 둘 다 스캔. 구 synology 키는 어느 분기에도
        #  안 걸려 자연히 무시된다.)
        if [ "$in_template" = true ] && [ "$in_options" = true ]; then
            if [[ "$line" =~ ^[[:space:]]+nexus:[[:space:]]*(.+) ]]; then
                local _v=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | tr -d "'" | xargs)
                [ "$_v" = "true" ] && INCLUDE_NEXUS=true
                [ "$_v" = "false" ] && INCLUDE_NEXUS=false
                continue
            fi
            if [[ "$line" =~ ^[[:space:]]+secret_backup:[[:space:]]*(.+) ]]; then
                local _v=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | tr -d "'" | xargs)
                [ "$_v" = "true" ] && INCLUDE_SECRET_BACKUP=true
                [ "$_v" = "false" ] && INCLUDE_SECRET_BACKUP=false
                continue
            fi

            # 다른 최상위 키 만나면 options 섹션 종료
            if [[ "$line" =~ ^[[:space:]]{0,4}[a-z_]+: ]]; then
                in_options=false
                in_template=false
            fi
        fi

        # template 섹션 종료 확인 (들여쓰기가 줄어들면)
        if [ "$in_template" = true ] && [[ "$line" =~ ^[a-z_]+: ]]; then
            in_template=false
            in_options=false
        fi
    done < "$version_file"
}

# version.yml에 템플릿 옵션 저장
save_template_options() {
    local version_file="version.yml"
    local template_version="${1:-unknown}"
    local today=$(date -u +"%Y-%m-%d")

    # 미설정(빈 값)이면 false로 보정 — 항상 명시적 true/false를 기록한다.
    : "${INCLUDE_NEXUS:=false}"
    : "${INCLUDE_SECRET_BACKUP:=false}"

    if [ ! -f "$version_file" ]; then
        return
    fi

    # 기존에 template 섹션이 있는지 확인
    if grep -q "^[[:space:]]*template:" "$version_file"; then
        # 기존 template 섹션 업데이트
        # macOS/Linux 호환을 위해 임시 파일 방식 사용

        # options.nexus 값 업데이트 또는 추가
        if grep -q "nexus:" "$version_file"; then
            sed "s/nexus:.*$/nexus: $INCLUDE_NEXUS/" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        elif grep -q "options:" "$version_file"; then
            sed "/options:/a\\
      nexus: $INCLUDE_NEXUS" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        fi

        # options.secret_backup 값 업데이트 또는 추가
        if grep -q "secret_backup:" "$version_file"; then
            sed "s/secret_backup:.*$/secret_backup: $INCLUDE_SECRET_BACKUP/" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        elif grep -q "options:" "$version_file"; then
            sed "/options:/a\\
      secret_backup: $INCLUDE_SECRET_BACKUP" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        fi

        # last_update_date 업데이트
        if grep -q "last_update_date:" "$version_file"; then
            sed "s/last_update_date:.*$/last_update_date: \"$today\"/" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        fi
    else
        # template 섹션 새로 추가 (metadata 섹션 끝에)
        # 파일 끝에 추가
        cat >> "$version_file" << EOF
  template:
    source: "SUH-DEVOPS-TEMPLATE"
    version: "$template_version"
    integrated_date: "$today"
    last_update_date: "$today"
    options:
      nexus: $INCLUDE_NEXUS
      secret_backup: $INCLUDE_SECRET_BACKUP
EOF
        print_info "version.yml에 템플릿 설정 저장됨"
    fi
}

# 버전 비교 함수 (v1 > v2 이면 1, v1 < v2 이면 -1, 같으면 0)
compare_versions() {
    local v1="$1"
    local v2="$2"

    # 버전에서 v 접두사 제거
    v1="${v1#v}"
    v2="${v2#v}"

    # 버전을 . 기준으로 분리 (IFS 격리)
    local V1_PARTS
    local V2_PARTS
    V1_PARTS=($(echo "$v1" | tr '.' ' '))
    V2_PARTS=($(echo "$v2" | tr '.' ' '))

    for i in 0 1 2; do
        local p1="${V1_PARTS[$i]:-0}"
        local p2="${V2_PARTS[$i]:-0}"

        if [ "$p1" -gt "$p2" ] 2>/dev/null; then
            echo 1
            return
        elif [ "$p1" -lt "$p2" ] 2>/dev/null; then
            echo -1
            return
        fi
    done

    echo 0
}

# Breaking Changes 확인 및 알림
check_breaking_changes() {
    local current_version="$1"  # 프로젝트의 현재 템플릿 버전
    local new_version="$2"      # 업데이트될 템플릿 버전

    # 버전 정보가 없으면 (레거시 프로젝트) 스킵
    if [ -z "$current_version" ] || [ "$current_version" = "unknown" ]; then
        return 0
    fi

    # --force 모드면 스킵
    if [ "$FORCE_MODE" = true ]; then
        return 0
    fi

    # TTY 없으면 스킵
    if [ "$TTY_AVAILABLE" = false ]; then
        return 0
    fi

    # breaking-changes.json 다운로드
    local bc_url="${TEMPLATE_RAW_URL}/.github/config/breaking-changes.json"
    local bc_json
    bc_json=$(curl -fsSL "$bc_url" 2>/dev/null) || return 0

    # JSON 파싱 실패 시 스킵
    if [ -z "$bc_json" ]; then
        return 0
    fi

    # jq 없으면 스킵 (JSON 파싱 불가)
    if ! command -v jq &> /dev/null; then
        print_warning "jq가 없어 호환성 변경(breaking change) 확인을 건너뜁니다 — jq 설치를 권장합니다."
        return 0
    fi

    # breaking changes 버전 목록 추출 (버전 키만)
    local versions
    versions=$(echo "$bc_json" | jq -r 'keys[] | select(startswith("_") | not)' 2>/dev/null) || return 0

    # 해당 버전 범위의 breaking changes 수집
    local critical_changes=()
    local warning_changes=()

    for ver in $versions; do
        # current_version < ver <= new_version 인 경우만 해당
        local cmp_current
        local cmp_new
        cmp_current=$(compare_versions "$ver" "$current_version")
        cmp_new=$(compare_versions "$ver" "$new_version")

        if [ "$cmp_current" = "1" ] && [ "$cmp_new" != "1" ]; then
            local severity
            local title
            local message
            severity=$(echo "$bc_json" | jq -r ".[\"$ver\"].severity // \"warning\"" 2>/dev/null)
            title=$(echo "$bc_json" | jq -r ".[\"$ver\"].title // \"\"" 2>/dev/null)
            message=$(echo "$bc_json" | jq -r ".[\"$ver\"].message // \"\"" 2>/dev/null)

            if [ "$severity" = "critical" ]; then
                critical_changes+=("v$ver|$title|$message")
            else
                warning_changes+=("v$ver|$title|$message")
            fi
        fi
    done

    # breaking change가 없으면 리턴
    local total_changes=$((${#critical_changes[@]} + ${#warning_changes[@]}))
    if [ "$total_changes" -eq 0 ]; then
        return 0
    fi

    # 알림 표시
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════════╗" >&2
    echo "║  ⚠️  BREAKING CHANGES (v$current_version → v$new_version)" >&2
    echo "╠══════════════════════════════════════════════════════════════════╣" >&2

    # Critical changes 표시
    for change in "${critical_changes[@]}"; do
        IFS='|' read -r ver title msg <<< "$change"
        echo "║" >&2
        echo "║  ${RED}[CRITICAL]${NC} $ver - $title" >&2
        echo "║  → $msg" >&2
    done

    # Warning changes 표시
    for change in "${warning_changes[@]}"; do
        IFS='|' read -r ver title msg <<< "$change"
        echo "║" >&2
        echo "║  ${YELLOW}[WARNING]${NC} $ver - $title" >&2
        echo "║  → $msg" >&2
    done

    echo "║" >&2
    echo "╚══════════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2

    # Critical이 있으면 Y/N 확인
    if [ ${#critical_changes[@]} -gt 0 ]; then
        print_warning "주의가 필요한 호환성 변경(CRITICAL)이 있습니다. 아래 내용을 꼭 확인하세요."
        print_to_user ""

        if ! ask_yes_no "위 호환성 변경을 확인했고 계속 진행할까요?" "N"; then
            print_info "통합을 안전하게 취소했습니다."
            exit 0
        fi
    fi

    return 0
}

# 현재 프로젝트의 템플릿 버전 읽기
get_current_template_version() {
    local version_file="version.yml"

    if [ ! -f "$version_file" ]; then
        echo "unknown"
        return
    fi

    # metadata.template.version 읽기
    local in_template=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*template: ]]; then
            in_template=true
        elif [ "$in_template" = true ]; then
            if [[ "$line" =~ ^[[:space:]]*version:[[:space:]]*[\"\']?([0-9.]+)[\"\']? ]]; then
                echo "${BASH_REMATCH[1]}"
                return
            elif [[ "$line" =~ ^[[:space:]]*[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]{4,} ]]; then
                # 다른 최상위 키를 만나면 종료
                break
            fi
        fi
    done < "$version_file"

    echo "unknown"
}

# 선택적(opt-in) 워크플로우 1종의 포함 여부를 묻는다.
# 인자: [--force-ask] $1=폴더경로 $2=아이콘 $3=짧은이름 $4=한줄설명 $5=include변수명
# 폴더가 없거나 파일이 0개면 조용히 return.
# 이미 값이 설정돼 있으면(--force-ask 아니면) 건너뛴다. (CLI/version.yml 우선)
ask_optional_workflow() {
    local _force_ask=false
    if [ "$1" = "--force-ask" ]; then _force_ask=true; shift; fi
    local _dir="$1" _icon="$2" _short="$3" _desc="$4" _varname="$5"

    # 현재 변수값 읽기 (bash 3.2 — nameref 없이 eval)
    local _cur; eval "_cur=\"\${$_varname}\""

    [ -d "$_dir" ] || return

    # 폴더 내 파일 개수
    local _count=0 f
    for f in "$_dir"/*.{yaml,yml}; do [ -e "$f" ] && _count=$((_count + 1)); done
    [ "$_count" -eq 0 ] && return

    # 이미 설정된 값이 있고 force-ask 아니면 건너뜀 (CLI 또는 version.yml에서 온 값)
    if [ "$_force_ask" = false ] && { [ "$_cur" = true ] || [ "$_cur" = false ]; }; then
        return
    fi

    # TTY 없으면 기본 제외
    if [ "$TTY_AVAILABLE" = false ]; then
        eval "$_varname=false"; return
    fi

    print_separator_line
    print_to_user ""
    print_to_user "$_icon $_short 워크플로우를 발견했습니다. ($_count개 파일)"
    print_to_user "   $_desc"
    print_to_user ""
    print_to_user "   포함되는 워크플로우:"
    for f in "$_dir"/*.{yaml,yml}; do
        [ -e "$f" ] || continue
        print_to_user "     • $(basename "$f")"
    done
    print_to_user ""

    if ask_yes_no "$_short 워크플로우를 포함할까요?" "N"; then
        eval "$_varname=true"
        print_info "$_short 워크플로우를 포함합니다 — GitHub Actions에 추가됩니다"
    else
        eval "$_varname=false"
        print_info "$_short 워크플로우를 제외합니다 (나중에 옵션으로 추가 가능)"
    fi
}

# 모든 opt-in 워크플로우를 순서대로 묻는다.
# 인자: [--force-ask] type_dirs... (project_types_dir 하위 타입 폴더 목록)
# - Nexus: 각 타입의 nexus/ 폴더 (현재 spring만 존재)
# - Secret 백업: 공통 secret-backup/ 폴더
ask_all_optional_workflows() {
    local _fa=""
    if [ "$1" = "--force-ask" ]; then _fa="--force-ask"; shift; fi
    local type_dirs=("$@")
    [ ${#type_dirs[@]} -eq 0 ] && return
    local _common_root; _common_root="$(dirname "${type_dirs[0]}")/common"

    # --force-ask가 아니면 version.yml 저장값을 먼저 읽어 재질문을 건너뛴다.
    # (ask_optional_workflow가 변수값으로 판단하므로 여기서 한 번만 읽는다.)
    [ "$_fa" = "" ] && read_template_options

    # Nexus: 각 타입의 nexus/ 폴더
    local _td
    for _td in "${type_dirs[@]}"; do
        ask_optional_workflow $_fa "$_td/nexus" "📦" "Nexus 라이브러리 publish" \
            "라이브러리/모듈을 Maven 저장소(Nexus)에 배포하는 워크플로우입니다. 일반 서버 배포가 아니라 라이브러리 프로젝트에만 필요합니다." \
            INCLUDE_NEXUS
    done
    # Secret 백업: 공통 폴더
    ask_optional_workflow $_fa "$_common_root/secret-backup" "🔐" "Secret 서버 백업" \
        "GitHub Secret에 저장한 설정 파일을 SSH로 서버에 업로드·이력관리하는 워크플로우입니다." \
        INCLUDE_SECRET_BACKUP
}

# ===================================================================
# 워크플로우 env 동적 설정 (토큰 + @wizard 마커 엔진)
# ===================================================================
# 워크플로우 env의 "__TOKEN__" 값을 프로젝트에 맞게 자동 치환한다.
# 마법사는 키 목록을 외우지 않고 파일의 '# @wizard' 마커를 스캔해 동작한다.
#   @wizard ask        → 기본값 우선순위로 질문(엔터=기본값) 후 치환 + version.yml 저장
#   @wizard auto       → 자동값(레포명 등)으로 치환
#   @wizard auto-find  → find로 후보 탐색 후 치환
#   # @wizard paths-anchor → 모노레포면 paths 필터 주입
# 자세한 설계: docs/superpowers/specs/2026-06-13-dynamic-cicd-env-init-design.md

# deploy 설정 기억용 CSV (재실행 시 기본값 제안 + version.yml deploy 블록 생성)
# 형식: "type|KEY=값;type|KEY=값" (bash 3.2 호환 — 연관배열 금지)
WF_DEPLOY_CSV="${WF_DEPLOY_CSV:-}"
# "전부 기본값 일괄" 모드 플래그 (configure 첫 호출 시 1회 질문해 세팅)
WF_USE_DEFAULTS=""

# 레포명 자동 도출 — PROJECT_NAME 토큰의 auto 값
detect_repo_name() {
    local _url _name
    _url=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -n "$_url" ]; then
        _name=$(echo "$_url" | sed -E 's#.*[/:]([^/]+)/([^/.]+)(\.git)?/?$#\2#')
        [ -n "$_name" ] && { echo "$_name"; return 0; }
    fi
    # 폴백: 현재 디렉토리명
    basename "$(pwd)"
}

# ── resolver 레지스트리 ──────────────────────────────────────────────
# 동적 기본값(@name)·auto:name 둘 다 사용. $1=type. 반환은 stdout.
resolve_repo() { detect_repo_name; }

resolve_spring_app_yml_dir() {
    local _t="$1" _base
    _base=$(get_path_for_type "$_t"); [ -z "$_base" ] && _base="."
    local _f
    _f=$(find "$_base" -path "*/src/main/resources/application*.yml" 2>/dev/null | head -1)
    [ -z "$_f" ] && { echo ""; return; }
    dirname "$_f" | sed 's#^\./##'
}

resolve_spring_app_yml_path() {
    local _t="$1" _base
    _base=$(get_path_for_type "$_t"); [ -z "$_base" ] && _base="."
    find "$_base" -path "*/src/main/resources/application*.yml" 2>/dev/null | head -1 | sed 's#^\./##'
}

# auto:flutter-root — Flutter 루트 경로(레포 루트 기준). 단일레포면 ".", 모노레포면 "app" 등.
# project_paths.flutter(통합 시점 resolve_project_paths가 채운 값)를 그대로 워크플로우 env에 박는다.
resolve_flutter_root() {
    local _p
    _p=$(get_path_for_type "flutter")
    [ -z "$_p" ] && echo "." || echo "$_p"
}

# resolver 디스패처. $1=type $2=resolver명 → 값(없으면 빈문자열)
resolve_token() {
    local _t="$1" _name="$2"
    case "$_name" in
        repo)                 resolve_repo ;;
        spring-app-yml-dir)   resolve_spring_app_yml_dir "$_t" ;;
        spring-app-yml-path)  resolve_spring_app_yml_path "$_t" ;;
        flutter-root)         resolve_flutter_root ;;
        *) echo "" ;;
    esac
}

# wizard-prompts.yml에서 질문 문구 조회 (없으면 키명). $1=KEY
LABELS_FILE="${LABELS_FILE:-.github/config/wizard-prompts.yml}"
# 실제로 읽을 wizard-prompts.yml 경로를 고른다.
#   1) 작업 디렉토리 dst(LABELS_FILE) — 재통합/이미 복사된 경우
#   2) 다운로드 원본 $TEMP_DIR/.github/config/wizard-prompts.yml — 신규 통합에서 copy_config_folder가
#      configure_workflow_env 보다 늦게 실행되어 dst에 아직 파일이 없을 때 폴백.
# 이 폴백이 없으면 신규 통합 시 label/help/example이 모두 빈값이 되어 KEY명만 출력된다.
_wf_labels_path() {
    if [ -f "$LABELS_FILE" ]; then echo "$LABELS_FILE"; return; fi
    local _src="$TEMP_DIR/.github/config/wizard-prompts.yml"
    [ -f "$_src" ] && { echo "$_src"; return; }
    echo ""
}
# 워크플로우 파일명 → 사람이 읽는 짧은 이름.
# wizard-prompts.yml의 _workflow_names: 블록에서 "키가 파일명에 포함되면" 그 값 사용(긴 키 우선).
# 매핑 없으면 파일명에서 .yaml/.yml 확장자만 제거해 그대로 반환.
# _workflow_names 매핑을 전역 캐시(WF_WFNAME_KEYS/WF_WFNAME_VAL)에 1회만 로드.
# 호출마다 wizard-prompts.yml을 풀스캔하면 Windows Git Bash에서 fork 비용으로 극단적으로 느려진다(실측 수십 초).
# 매핑은 통합 1회 동안 불변이므로 캐싱이 안전하다.
declare -ga WF_WFNAME_KEYS 2>/dev/null || true
declare -gA WF_WFNAME_VAL 2>/dev/null || true
WF_WFNAME_LOADED=""
_wf_load_workflow_names() {
    [ -n "$WF_WFNAME_LOADED" ] && return 0
    WF_WFNAME_LOADED=1
    WF_WFNAME_KEYS=(); WF_WFNAME_VAL=()
    local _lf _line _k _v _rest _inblk=false
    _lf=$(_wf_labels_path); [ -n "$_lf" ] || return 0
    while IFS= read -r _line; do
        case "$_line" in
            _workflow_names:*) _inblk=true; continue ;;
        esac
        [ "$_inblk" = true ] || continue
        case "$_line" in [!\ ]*) _inblk=false; continue ;; esac
        # "  KEY: "값"" → bash 내장 파싱(sed fork 회피)
        _k="${_line#"${_line%%[![:space:]]*}"}"   # leading ws strip
        case "$_k" in
            *:\ \"*\") _v="${_k#*: \"}"; _v="${_v%\"}"; _k="${_k%%:*}" ;;
            *) continue ;;
        esac
        [ -z "$_k" ] && continue
        WF_WFNAME_KEYS+=("$_k"); WF_WFNAME_VAL[$_k]="$_v"
    done < "$_lf"
}
wf_workflow_name() {
    local _file="$1" _base _k _best="" _bestlen=0
    _base="${_file##*/}"                 # 경로 제거
    _wf_load_workflow_names
    for _k in "${WF_WFNAME_KEYS[@]}"; do
        case "$_base" in
            *"$_k"*)
                if [ "${#_k}" -gt "$_bestlen" ]; then _best="${WF_WFNAME_VAL[$_k]}"; _bestlen="${#_k}"; fi
                ;;
        esac
    done
    if [ -n "$_best" ]; then echo "$_best"; return; fi
    # 폴백: 확장자만 제거
    echo "${_base%.y*ml}"
}
# wizard-prompts.yml에서 단일 필드 1개를 읽는다. $1=조회키(KEY 또는 "type.KEY") $2=필드(label|help|example)
# 블록 형식(KEY: 다음 2칸 들여쓰기 label/help/example)과 구형 1줄 형식(KEY: "라벨") 모두 지원.
_wf_read_field() {
    local _key="$1" _field="$2" _v="" _lf
    _lf=$(_wf_labels_path)
    [ -n "$_lf" ] || { echo ""; return; }
    # 1) 구형 1줄: KEY: "..."  (값이 같은 줄에 있는 경우) — label만 의미 있음
    if [ "$_field" = "label" ]; then
        _v=$(sed -nE "s~^${_key}:[[:space:]]+\"([^\"]*)\"[[:space:]]*\$~\1~p" "$_lf" | head -1)
        [ -n "$_v" ] && { echo "$_v"; return; }
    fi
    # 2) 블록 형식: "KEY:" 줄을 찾고, 그 아래 들여쓰기 블록에서 "  field: ..." 추출.
    #    awk로 KEY 블록(다음 비들여쓰기 키 전까지)을 격리해 해당 field 한 줄을 읽는다.
    _v=$(awk -v key="$_key" -v fld="$_field" '
        $0 ~ "^"key":[[:space:]]*$" { inblk=1; next }
        inblk && /^[^[:space:]]/   { inblk=0 }
        inblk {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ "^"fld":") {
                sub("^"fld":[[:space:]]*", "", line)
                sub(/^"/, "", line); sub(/"[[:space:]]*$/, "", line)
                print line; exit
            }
        }
    ' "$_lf")
    echo "$_v"
}

# 조회 우선순위로 필드를 얻는다. $1=type $2=KEY $3=field. 폴백: field=label이면 KEY명, 아니면 빈값.
wf_field() {
    local _type="$1" _key="$2" _field="$3" _v=""
    _v=$(_wf_read_field "${_type}.${_key}" "$_field")
    [ -n "$_v" ] && { echo "$_v"; return; }
    _v=$(_wf_read_field "$_key" "$_field")
    [ -n "$_v" ] && { echo "$_v"; return; }
    [ "$_field" = "label" ] && echo "$_key" || echo ""
}

# WF_DEPLOY_CSV에서 type+KEY 조회 (우선순위 1 — 재실행 시 기존값)
wf_deploy_get() {
    local _t="$1" _k="$2" _pair _ifs_bak="${IFS-$' \t\n'}"
    IFS=';'
    for _pair in $WF_DEPLOY_CSV; do
        IFS="$_ifs_bak"
        case "$_pair" in
            "$_t|$_k="*) echo "${_pair#*=}"; return 0 ;;
        esac
        IFS=';'
    done
    IFS="$_ifs_bak"
    echo ""
}

# WF_DEPLOY_CSV에 type+KEY=값 저장 (이미 있으면 교체)
wf_deploy_set() {
    local _t="$1" _k="$2" _v="$3" _pair _out="" _ifs_bak="${IFS-$' \t\n'}"
    IFS=';'
    for _pair in $WF_DEPLOY_CSV; do
        IFS="$_ifs_bak"
        [ -z "$_pair" ] && { IFS=';'; continue; }
        case "$_pair" in
            "$_t|$_k="*) ;; # 기존 항목 스킵(교체)
            *) _out="${_out:+$_out;}$_pair" ;;
        esac
        IFS=';'
    done
    IFS="$_ifs_bak"
    WF_DEPLOY_CSV="${_out:+$_out;}$_t|$_k=$_v"
}

# env 키 값 치환 + 그 줄의 # @wizard 주석 삭제. $1=파일 $2=KEY $3=값
_wf_set_env() {
    local _file="$1" _key="$2" _val="$3" _esc
    _esc=$(printf '%s' "$_val" | sed 's/[&~\\]/\\&/g')
    # 값 치환: KEY: "..." 따옴표 안
    sed -i.wftmp -E "s~^([[:space:]]*${_key}:[[:space:]]*\")[^\"]*(\")~\1${_esc}\2~" "$_file" 2>/dev/null
    # 그 줄 끝의 # @wizard ... 주석 제거(공백째)
    sed -i.wftmp -E "s~(^[[:space:]]*${_key}:.*[^[:space:]])[[:space:]]*#[[:space:]]*@wizard[[:space:]].*\$~\1~" "$_file" 2>/dev/null
    rm -f "$_file.wftmp"
}

# WF_DEPLOY_CSV(ask로 모은 비민감 배포 설정)를 version.yml의 deploy 블록으로 기록
# copy_workflows 완료 후 호출 (그때 CSV가 다 채워져 있음). 재실행 시 기본값 제안용 기억.
update_version_yml_deploy() {
    [ -z "$WF_DEPLOY_CSV" ] && return 0
    [ -f "version.yml" ] || return 0

    # 기존 deploy: 블록 제거 (멱등성 — 매 실행 새로 기록)
    if grep -q "^deploy:" version.yml; then
        sed -i.wftmp '/^deploy:/,/^[^[:space:]]/{/^deploy:/d; /^  /d;}' version.yml
        rm -f version.yml.wftmp
    fi

    # CSV → "type별 그룹" 으로 deploy 블록 생성
    local _block="deploy:                          # 마법사가 기억하는 배포 설정 (비민감 / 직접 수정 가능)"
    local _types _t _pair _ifs_bak="${IFS-$' \t\n'}"
    # 등장한 타입 목록 수집
    _types=$(printf '%s' "$WF_DEPLOY_CSV" | tr ';' '\n' | sed -E 's/\|.*//' | sort -u)
    local _t_nl
    for _t_nl in $_types; do
        [ -z "$_t_nl" ] && continue
        _block="$_block"$'\n'"  ${_t_nl}:"
        IFS=';'
        for _pair in $WF_DEPLOY_CSV; do
            IFS="$_ifs_bak"
            case "$_pair" in
                "$_t_nl|"*)
                    local _kv="${_pair#*|}"
                    local _k="${_kv%%=*}" _v="${_kv#*=}"
                    _block="$_block"$'\n'"    ${_k}: \"${_v}\""
                    ;;
            esac
            IFS=';'
        done
        IFS="$_ifs_bak"
    done

    # version.yml 끝에 deploy 블록 추가
    printf '\n%s\n' "$_block" >> version.yml
    print_info "version.yml에 deploy 설정을 기록했습니다 (재통합 시 기본값으로 제안)"
}

# "type|name" 줄들의 사용처 문자열 조립.
# 단일 타입: "{타입} {name1·name2·...}" (name 중복 제거).
# 여러 타입: "type1·type2·..." (타입만, 중복 제거).
# 입력은 wf_collect_asks가 누적한 리터럴 \n 마커 포함 문자열(printf '%b'로 개행 복원).
wf_scope_string() {
    local _pairs="$1" _line _t _n
    local _types="" _names=""
    while IFS= read -r _line; do
        [ -z "$_line" ] && continue
        _t="${_line%%|*}"; _n="${_line#*|}"
        case "·$_types·" in *"·$_t·"*) ;; *) _types="${_types:+$_types·}$_t" ;; esac
        case "·$_names·" in *"·$_n·"*) ;; *) _names="${_names:+$_names·}$_n" ;; esac
    done <<< "$(printf '%b' "$_pairs")"
    # 타입이 여러 개면(·포함) 타입만, 하나면 "타입 name들"
    case "$_types" in
        *·*) echo "$_types" ;;
        *)   echo "${_types} ${_names}" ;;
    esac
}

# ask KEY를 전 워크플로우에서 수집. 결과는 전역 배열에 채운다.
# WF_ASK_KEYS: KEY 등장 순서(중복 제거). WF_ASK_DEFAULT/WF_ASK_SCOPE: KEY별 기본값/사용처.
declare -gA WF_ASK_DEFAULT 2>/dev/null || true
declare -gA WF_ASK_SCOPE 2>/dev/null || true
declare -gA WF_ASK_TYPE_DEFAULT 2>/dev/null || true
WF_ASK_KEYS=()
# KEY -> 등장 파일들의 "type|name" 누적 (사용처 조립용)
declare -gA WF_ASK_FILES 2>/dev/null || true

# $1=project_types_dir 베이스(=_copy_workflows_for_type에 넘기는 것과 동일: 보통 "$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR"),
# $2.. = 설치 대상 type 목록. 실제 설치되는 워크플로우와 같은 소스를 스캔해야 사용처/기본값이 정확하다.
wf_collect_asks() {
    WF_ASK_KEYS=(); WF_ASK_DEFAULT=(); WF_ASK_SCOPE=(); WF_ASK_FILES=(); WF_ASK_TYPE_DEFAULT=()
    local _base_dir="$1"; shift
    local _type _dir _f _base _line _key _arg _default _saved _hn _grepout
    for _type in "$@"; do
        _dir="$_base_dir/$_type"
        [ -d "$_dir" ] || continue
        for _f in "$_dir"/*.yaml "$_dir"/*.yml; do
            [ -f "$_f" ] || continue
            grep -q "@wizard" "$_f" 2>/dev/null || continue
            _base="${_f##*/}"
            _hn=$(wf_workflow_name "$_base")   # 파일당 1회 (라인마다 호출하면 fork 폭증)
            # 프로세스 치환(< <(grep)) 대신 변수+here-string: Windows Git Bash에서 프로세스 치환 FD가
            # 루프 내 중첩 서브셸로 상속돼 극단적으로 느려지는 것을 피한다.
            _grepout=$(grep -E '^[[:space:]]*[A-Z_]+:.*@wizard[[:space:]]+ask:' "$_f")
            while IFS= read -r _line; do
                [ -z "$_line" ] && continue
                # _key: 앞 공백 제거 후 ':' 앞부분 (bash 내장 — sed fork 회피)
                _key="${_line#"${_line%%[![:space:]]*}"}"
                _key="${_key%%:*}"
                case "$_key" in *[!A-Z_]*|"") continue ;; esac
                # _arg: '@wizard ask:' 뒤, 끝 공백 제거 (bash 내장)
                case "$_line" in *"@wizard ask:"*) _arg="${_line##*@wizard ask:}" ;; *) continue ;; esac
                _arg="${_arg%"${_arg##*[![:space:]]}"}"
                
                # 타입별 고유 기본값은 무조건 수집 및 저장
                local _type_default
                case "$_arg" in
                    @*) _type_default=$(resolve_token "$_type" "${_arg#@}") ;;
                    *)  _type_default="$_arg" ;;
                esac
                _saved=$(wf_deploy_get "$_type" "$_key"); [ -n "$_saved" ] && _type_default="$_saved"
                WF_ASK_TYPE_DEFAULT["${_type}|${_key}"]="$_type_default"

                # KEY 처음 보면 등록
                if [ -z "${WF_ASK_DEFAULT[$_key]+x}" ]; then
                    WF_ASK_KEYS+=("$_key")
                    WF_ASK_DEFAULT[$_key]="$_type_default"
                fi
                # 사용처 파일 누적 (type|humanname)
                WF_ASK_FILES[$_key]="${WF_ASK_FILES[$_key]:+${WF_ASK_FILES[$_key]}\n}${_type}|${_hn}"
            done <<< "$_grepout"
        done
    done
    # 사용처 문자열 조립 (Task 4의 wf_scope_string 사용)
    local _k
    for _k in "${WF_ASK_KEYS[@]}"; do
        WF_ASK_SCOPE[$_k]=$(wf_scope_string "${WF_ASK_FILES[$_k]}")
    done
}

# KEY가 처음 등장한 type 반환 (label 조회용 — 타입오버라이드 우선순위 때문)
_wf_first_type_for() {
    local _k="$1"
    printf '%b' "${WF_ASK_FILES[$_k]}" | head -1 | sed 's/|.*//'
}

# 모든 KEY를 기본값으로, 각 KEY가 등장한 모든 type에 prefill (wf_deploy_set 캐시)
# KEY 1개를 'label·사용처·설명·예시·기본값' 카드로 출력. $1=KEY $2=현재번호(옵션) $3=전체(옵션)
_wf_print_field_card() {
    local _k="$1" _idx="${2:-}" _tot="${3:-}" _t _label _help _ex _head
    _t=$(_wf_first_type_for "$_k")
    _label=$(wf_field "$_t" "$_k" "label")
    _help=$(wf_field "$_t" "$_k" "help")
    _ex=$(wf_field "$_t" "$_k" "example")
    if [ -n "$_idx" ] && [ -n "$_tot" ]; then
        _head="   ▸ (${_idx}/${_tot}) ${_label}  [${WF_ASK_SCOPE[$_k]}]"
    else
        _head="   ▸ ${_label}  [${WF_ASK_SCOPE[$_k]}]"
    fi
    print_to_user "$_head"
    [ -n "$_help" ] && print_to_user "       ${_help}"
    [ -n "$_ex" ] && print_to_user "       예) ${_ex}"
    print_to_user "       기본값: ${WF_ASK_DEFAULT[$_k]}"
    print_to_user ""
}

_wf_prefill_all() {
    local _k _t _line _def
    for _k in "${WF_ASK_KEYS[@]}"; do
        while IFS= read -r _line; do
            [ -z "$_line" ] && continue
            _t="${_line%%|*}"
            _def="${WF_ASK_TYPE_DEFAULT["${_t}|${_k}"]:-${WF_ASK_DEFAULT[$_k]}}"
            wf_deploy_set "$_t" "$_k" "$_def"
        done <<< "$(printf '%b' "${WF_ASK_FILES[$_k]}")"
    done
}

# 지정한 KEY들만 사용자에게 입력받아, 각 KEY가 등장한 모든 type에 prefill.
# 인자: 처리할 KEY 목록(WF_ASK_KEYS 멤버만 KEY로 인정 — type 이름이 섞여 와도 무시).
_wf_prefill_interactive() {
    local _arg _k _t _line _in _val
    # 처리할 KEY만 추려 전체 개수를 먼저 센다(진행 표시 N/총).
    local _todo=()
    for _arg in "$@"; do
        case " ${WF_ASK_KEYS[*]} " in *" $_arg "*) _todo+=("$_arg") ;; esac
    done
    local _tot=${#_todo[@]} _i=0
    [ "$_tot" -eq 0 ] && return 0
    print_to_user ""
    print_to_user "   값을 입력하세요. 그대로 두려면 아무것도 입력하지 말고 Enter를 누르면 기본값이 적용됩니다."
    print_to_user ""
    for _k in "${_todo[@]}"; do
        _i=$((_i + 1))
        _t=$(_wf_first_type_for "$_k")
        # 카드(번호/총 포함)로 무엇을 입력하는지 충분히 안내
        _wf_print_field_card "$_k" "$_i" "$_tot"
        _in=""
        safe_read "       ↳ 값 입력 (Enter=기본값 «${WF_ASK_DEFAULT[$_k]}» 유지): " _in "" || _in=""
        [ -z "$_in" ] && _val="${WF_ASK_DEFAULT[$_k]}" || _val="$_in"
        print_to_user "         → $(wf_field "$_t" "$_k" "label") = ${_val}"
        print_to_user ""
        while IFS= read -r _line; do
            [ -z "$_line" ] && continue
            _t="${_line%%|*}"
            wf_deploy_set "$_t" "$_k" "$_val"
        done <<< "$(printf '%b' "${WF_ASK_FILES[$_k]}")"
    done
}

# 배포 env 설정 계획: 표 미리보기 + 메뉴(전부기본/하나씩/골라서) + 값 확정(prefill).
# $1=project_types_dir 베이스, $2.. = 설치 대상 type 목록. 호출 후 WF_USE_DEFAULTS=true 고정.
wf_prompt_env_plan() {
    [ -n "${WF_USE_DEFAULTS:-}" ] && return 0     # 이미 정해졌으면 재실행 안 함
    local _base_dir="$1"; shift
    # 비대화형/FORCE → 표·메뉴 없이 전부 기본값
    if [ "$FORCE_MODE" = true ] || [ "$TTY_AVAILABLE" != true ]; then
        wf_collect_asks "$_base_dir" "$@"
        _wf_prefill_all
        WF_USE_DEFAULTS=true
        return 0
    fi
    wf_collect_asks "$_base_dir" "$@"
    [ ${#WF_ASK_KEYS[@]} -eq 0 ] && { WF_USE_DEFAULTS=true; return 0; }

    print_to_user ""
    print_step "배포 워크플로우 환경설정을 채웁니다"
    print_to_user ""
    print_to_user "   설치되는 배포 워크플로우가 사용할 값입니다. 항목마다 '무엇에 쓰이는지·설명·예시'와"
    print_to_user "   기본값을 함께 보여드립니다. 그대로 둬도 되고, 원하는 것만 바꿀 수 있습니다."
    print_to_user ""
    # 기본값 미리보기 — 항목마다 label·사용처·설명·예시·기본값을 모두 보여주는 카드.
    # (표 대신 카드로 통일: 폭과 무관하게 설명/예시까지 안 잘리고 가독성 일정)
    local _k _i=0 _n=${#WF_ASK_KEYS[@]}
    for _k in "${WF_ASK_KEYS[@]}"; do
        _i=$((_i + 1))
        _wf_print_field_card "$_k" "$_i" "$_n"
    done

    print_to_user "   ─────────────────────────────────────────────"
    print_to_user "   ① 전부 기본값으로 바로 설치   ② 하나씩 직접 입력"
    print_to_user "   ③ 몇 개만 골라서 바꾸기 (고른 것만 입력, 나머지는 기본값)"
    print_to_user ""

    local _choice _rc=0
    _choice=$(interactive_menu "어떻게 채울까요?" \
        "all|① 위 기본값 그대로 전부 설치 (입력 없이 바로 진행)" \
        "each|② 하나씩 직접 입력 (모든 항목을 순서대로)" \
        "some|③ 몇 개만 골라서 바꾸기 (고른 것만 입력 · 나머지는 기본값)") || _rc=$?
    if [ "$_rc" -ne 0 ]; then WF_USE_DEFAULTS=true; _wf_prefill_all; return 0; fi   # ESC=전부기본

    case "$_choice" in
        all)  _wf_prefill_all ;;
        each) _wf_prefill_interactive "${WF_ASK_KEYS[@]}" ;;
        some)
            local _opts=() _sel _rc2=0 _label
            for _k in "${WF_ASK_KEYS[@]}"; do
                _label=$(wf_field "$(_wf_first_type_for "$_k")" "$_k" "label")
                _opts+=("$_k|${_label}  (기본: ${WF_ASK_DEFAULT[$_k]})")
            done
            _sel=$(interactive_menu --multi "바꿀 항목을 고르세요 (Space로 선택 · Enter로 확정)" "${_opts[@]}") || _rc2=$?
            _wf_prefill_all                       # 일단 전부 기본값
            if [ "$_rc2" -eq 0 ] && [ -n "$_sel" ]; then
                local _csv_k; IFS=',' read -ra _csv_k <<< "$_sel"
                _wf_prefill_interactive "${_csv_k[@]}"   # 고른 것만 덮어쓰기 입력
            fi
            ;;
    esac
    WF_USE_DEFAULTS=true
    return 0
}

# 워크플로우 1개의 env 토큰을 프로젝트에 맞게 치환 (토큰+마커 엔진의 핵심)
# $1=type $2=워크플로우 파일 절대경로
configure_workflow_env() {
    local _type="$1" _file="$2"
    [ -f "$_file" ] || return 0
    grep -q "@wizard" "$_file" 2>/dev/null || return 0

    # 일괄 기본값 모드 1회 질문 (기존 로직 유지)
    if [ -z "${WF_USE_DEFAULTS:-}" ]; then
        if [ "$FORCE_MODE" = true ] || [ "$TTY_AVAILABLE" != true ]; then
            WF_USE_DEFAULTS=true
        else
            print_to_user ""
            print_step "배포 워크플로우 환경설정을 채웁니다"
            local _ans=""
            safe_read "  전부 기본값으로 빠르게 채울까요? (Y=전부기본 / n=하나씩) [Y]: " _ans "-n 1" || _ans=""
            print_to_user ""
            case "$_ans" in n|N) WF_USE_DEFAULTS=false ;; *) WF_USE_DEFAULTS=true ;; esac
        fi
    fi

    local _line _key _action _arg _val
    while IFS= read -r _line; do
        _key=$(printf '%s' "$_line" | sed -nE 's|^[[:space:]]*([A-Z_]+):.*#[[:space:]]*@wizard[[:space:]].*|\1|p')
        [ -z "$_key" ] && continue
        _val=""
        _action=$(printf '%s' "$_line" | sed -nE 's~.*#[[:space:]]*@wizard[[:space:]]+(ask|auto):.*~\1~p')
        _arg=$(printf '%s' "$_line" | sed -nE 's~.*#[[:space:]]*@wizard[[:space:]]+(ask|auto):(.*)$~\2~p' | sed 's/[[:space:]]*$//')
        [ -z "$_action" ] && continue

        case "$_action" in
            auto)
                _val=$(resolve_token "$_type" "$_arg")
                ;;
            ask)
                # 기본값: @name이면 resolver, 아니면 리터럴. 재실행 기존값 우선.
                local _default
                case "$_arg" in
                    @*) _default=$(resolve_token "$_type" "${_arg#@}") ;;
                    *)  _default="$_arg" ;;
                esac
                local _saved; _saved=$(wf_deploy_get "$_type" "$_key")
                [ -n "$_saved" ] && _default="$_saved"
                if [ "$WF_USE_DEFAULTS" = true ]; then
                    _val="$_default"
                else
                    local _label _help _example _in="" _scope
                    _label=$(wf_field "$_type" "$_key" "label")
                    _help=$(wf_field "$_type" "$_key" "help")
                    _example=$(wf_field "$_type" "$_key" "example")
                    _scope="${WF_ASK_SCOPE[$_key]:-}"
                    if [ -n "$_scope" ]; then
                        print_to_user "  ▸ ${_label}  [${_scope}]"
                    else
                        print_to_user "  ▸ ${_label}"
                    fi
                    [ -n "$_help" ] && print_to_user "    ${_help}"
                    [ -n "$_example" ] && print_to_user "    예) ${_example}"
                    safe_read "  값 입력 [기본: ${_default}]: " _in "" || _in=""
                    [ -z "$_in" ] && _val="$_default" || _val="$_in"
                fi
                wf_deploy_set "$_type" "$_key" "$_val"
                ;;
        esac
        [ -n "$_val" ] && _wf_set_env "$_file" "$_key" "$_val"
    done < <(grep -nE "#[[:space:]]*@wizard[[:space:]]+(ask|auto):" "$_file" | sed 's/^[0-9]*://')

    # 재귀 토큰 치환: 남은 __PROJECT_NAME__ / __APP_ARTIFACT_NAME__ (VOLUME 경로·flutter 산출물명 등)
    if grep -qE "__PROJECT_NAME__|__APP_ARTIFACT_NAME__" "$_file" 2>/dev/null; then
        local _esc_repo; _esc_repo=$(printf '%s' "$(detect_repo_name)" | sed 's/[&|\\]/\\&/g')
        sed -i.wftmp -e "s|__PROJECT_NAME__|$_esc_repo|g" -e "s|__APP_ARTIFACT_NAME__|$_esc_repo|g" "$_file"; rm -f "$_file.wftmp"
    fi

    # paths-anchor (불변 — 기존 로직 그대로 유지)
    if grep -q "#[[:space:]]*@wizard paths-anchor" "$_file" 2>/dev/null; then
        local _ppath; _ppath=$(get_path_for_type "$_type")
        if [ -n "$_ppath" ] && [ "$_ppath" != "." ]; then
            local _indent; _indent=$(grep "@wizard paths-anchor" "$_file" | sed -E 's/([[:space:]]*).*/\1/' | head -1)
            sed -i.wftmp "s~^[[:space:]]*#[[:space:]]*@wizard paths-anchor.*~${_indent}paths: ['${_ppath}/**']~" "$_file"; rm -f "$_file.wftmp"
        fi
    fi

    if grep -qE "__[A-Z_]+__" "$_file" 2>/dev/null; then
        local _leftover; _leftover=$(grep -oE "__[A-Z_]+__" "$_file" | sort -u | tr '\n' ' ')
        print_warning "  $(basename "$_file"): 미치환 토큰 남음($_leftover) — 직접 채워주세요"
    fi
}

# 기존 설치본이 "이 템플릿을 지금 설정대로 깔면 나올 결과"와 내용상 동일한가?
# 단순 cmp가 안 되는 이유: 원본엔 __TOKEN__/# @wizard 마커가 남아있고 설치본엔
# 값이 치환돼 있어 항상 다르게 나온다. 그래서 원본을 임시 사본으로 떠서 실제 치환
# 로직(configure_workflow_env)을 가상 적용한 "설치 예상 최종형"을 만들어 비교한다.
#   반환 0 = 동일(unchanged) / 1 = 다름 또는 비교 실패(changed로 취급, 업데이트 놓침 방지)
# 가상 치환은 서브셸 안에서 WF_USE_DEFAULTS=true로 돌려 (1)사용자에게 다시 묻지 않고
# (2)WF_DEPLOY_CSV 등 부수효과가 실제 설치 흐름으로 새지 않게 격리한다.
# $1=type  $2=원본 워크플로우 경로  $3=기존(설치된) 파일 경로
_wf_is_unchanged() {
    local _type="$1" _src="$2" _existing="$3"
    [ -f "$_src" ] && [ -f "$_existing" ] || return 1
    local _tmp
    _tmp=$(mktemp 2>/dev/null) || return 1          # 임시파일 실패 → changed
    if ! cp "$_src" "$_tmp" 2>/dev/null; then
        rm -f "$_tmp"; return 1
    fi
    # 서브셸 격리: 여기서 바뀐 WF_USE_DEFAULTS/WF_DEPLOY_CSV는 부모로 전파되지 않는다.
    (
        WF_USE_DEFAULTS=true
        configure_workflow_env "$_type" "$_tmp" >/dev/null 2>&1
    )
    if cmp -s "$_tmp" "$_existing"; then
        rm -f "$_tmp"; return 0                       # unchanged
    fi
    rm -f "$_tmp"; return 1                            # changed
}

# 워크플로우 다운로드 (폴더 기반, 선택적 업데이트)
# 단일 타입의 타입별 워크플로우 + 타입별 nexus(opt-in) 복사 (멀티타입 순회용 헬퍼)
# 카운터는 호출측 전역 변수(_wf_copied/_wf_template_added/_wf_skipped/_wf_optional_copied) 공유
_copy_workflows_for_type() {
    local type="$1"
    local project_types_dir="$2"

    local type_dir="$project_types_dir/$type"
    if [ -d "$type_dir" ]; then
        local existing_files=()    # 기존에 있고 내용이 '바뀐' 파일 (메뉴 대상)
        local unchanged_files=()   # 기존에 있고 내용이 '동일한' 파일 (조용히 건너뜀)
        local new_files=()

        for workflow in "$type_dir"/*.{yaml,yml}; do
            [ -e "$workflow" ] || continue
            local filename=$(basename "$workflow")
            if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                # 설치 예상 최종형과 동일하면 unchanged — 메뉴에 올리지 않는다.
                if _wf_is_unchanged "$type" "$workflow" "$WORKFLOWS_DIR/$filename"; then
                    unchanged_files+=("$filename")
                else
                    existing_files+=("$filename")
                fi
            else
                new_files+=("$filename")
            fi
        done

        # 내용 동일 파일: 조용히 건너뜀 (메뉴 없음 — 변경점 0인데 .bak 덮어쓰던 혼란 제거)
        if [ ${#unchanged_files[@]} -gt 0 ]; then
            for filename in "${unchanged_files[@]}"; do
                echo "  ⏭ $filename (변경 없음, $type)"
                _wf_skipped=$((_wf_skipped + 1))
            done
        fi

        # 신규 파일은 바로 복사
        if [ ${#new_files[@]} -gt 0 ]; then
            print_info "$type 타입의 신규 워크플로우를 내려받고 있습니다..."
            for filename in "${new_files[@]}"; do
                cp "$type_dir/$filename" "$WORKFLOWS_DIR/"
                echo "  ✓ $filename (신규, $type)"
                _wf_copied=$((_wf_copied + 1))
            done
        fi

        # 이미 존재하는 파일 처리 — 화살표 3지선 메뉴 (다른 메뉴와 통일)
        if [ ${#existing_files[@]} -gt 0 ]; then
            echo "" >&2
            print_warning "이미 존재하는 타입별 워크플로우($type): ${#existing_files[@]}개"
            for f in "${existing_files[@]}"; do
                print_to_user "   • $f"
            done

            # choose_menu 화살표 메뉴 (TTY) / FORCE·비TTY는 기본 'skip'
            local choice="skip"
            if [ "$TTY_AVAILABLE" = true ] && [ "$FORCE_MODE" = false ]; then
                local _wf_label
                _wf_label=$(choose_menu "기존 워크플로우를 어떻게 할까요?" \
                    "기존 유지 + 새 버전을 참고용(.template.yaml)으로 추가|" \
                    "건너뛰기 — 기존 파일만 유지|" \
                    "덮어쓰기 — 기존 파일을 .bak 백업 후 교체|")
                case "$_wf_label" in
                    기존\ 유지*) choice="T" ;;
                    건너뛰기*)   choice="S" ;;
                    덮어쓰기*)   choice="O" ;;
                    *)           choice="S" ;;   # ESC/취소 → 안전하게 건너뜀
                esac
            fi

            case "$choice" in
                T)
                    print_info "기존 파일은 두고 새 버전을 .template.yaml로 추가합니다 (수동 반영용 참고)..."
                    for filename in "${existing_files[@]}"; do
                        local template_name="${filename%.yaml}.template.yaml"
                        rm -f "$WORKFLOWS_DIR/$template_name"
                        cp "$type_dir/$filename" "$WORKFLOWS_DIR/$template_name"
                        echo "  ✓ $template_name (참고용 추가)"
                        _wf_template_added=$((_wf_template_added + 1))
                    done
                    print_info "💡 .template.yaml 파일은 GitHub Actions에서 실행되지 않습니다."
                    print_info "   필요한 변경사항을 참고하여 기존 파일에 수동으로 반영하세요."
                    ;;
                S)
                    print_info "기존 워크플로우를 그대로 유지합니다..."
                    for filename in "${existing_files[@]}"; do
                        echo "  ⏭ $filename (건너뜀)"
                        _wf_skipped=$((_wf_skipped + 1))
                    done
                    ;;
                O)
                    print_info "기존 파일을 .bak으로 백업한 뒤 새 버전으로 교체합니다..."
                    for filename in "${existing_files[@]}"; do
                        mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
                        cp "$type_dir/$filename" "$WORKFLOWS_DIR/"
                        echo "  ✓ $filename (백업: ${filename}.bak)"
                        _wf_copied=$((_wf_copied + 1))
                    done
                    ;;
                *)
                    print_warning "선택을 인식하지 못해 기존 파일을 유지합니다."
                    for filename in "${existing_files[@]}"; do
                        echo "  ⏭ $filename (건너뜀)"
                        _wf_skipped=$((_wf_skipped + 1))
                    done
                    ;;
            esac
        elif [ ${#unchanged_files[@]} -gt 0 ]; then
            print_info "$type 타입의 기존 워크플로우 ${#unchanged_files[@]}개가 현재 설정과 동일해 건너뜁니다."
        else
            print_info "$type 타입의 기존 워크플로우가 없습니다."
        fi
    else
        print_info "$type 타입의 전용 워크플로우가 없습니다. (공통 워크플로우만 사용)"
    fi

    # 타입별 Nexus 하위폴더 처리 (opt-in)
    # 배포 워크플로우는 타입 루트로 올라와 기본 포함됨. nexus/ 만 선택적으로 남는다.
    local nexus_dir="$project_types_dir/$type/nexus"
    if [ -d "$nexus_dir" ]; then
        if [ "$INCLUDE_NEXUS" = true ]; then
            print_info "$type Nexus 워크플로우 다운로드 중..."
            for workflow in "$nexus_dir"/*.{yaml,yml}; do
                [ -e "$workflow" ] || continue
                local filename=$(basename "$workflow")
                if [ -f "$WORKFLOWS_DIR/$filename" ] && _wf_is_unchanged "$type" "$workflow" "$WORKFLOWS_DIR/$filename"; then
                    echo "  ⏭ $filename (Nexus $type, 변경 없음)"
                    _wf_skipped=$((_wf_skipped + 1))
                    continue
                fi
                if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                    mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
                    cp "$workflow" "$WORKFLOWS_DIR/"
                    echo "  ✓ $filename (Nexus $type, 백업: ${filename}.bak)"
                else
                    cp "$workflow" "$WORKFLOWS_DIR/"
                    echo "  ✓ $filename (Nexus $type)"
                fi
                _wf_optional_copied=$((_wf_optional_copied + 1))
                _wf_copied=$((_wf_copied + 1))
            done
        else
            local nexus_count=0
            for f in "$nexus_dir"/*.{yaml,yml}; do
                [ -e "$f" ] && nexus_count=$((nexus_count + 1))
            done
            if [ $nexus_count -gt 0 ]; then
                print_info "$type Nexus 워크플로우 $nexus_count개 제외됨 (--nexus 옵션으로 포함 가능)"
            fi
        fi
    fi

    # ── 복사된 워크플로우 env 동적 설정 (토큰+@wizard 마커 치환) ──
    # 이 타입의 원본 디렉토리(+nexus)에 있던 파일 중, WORKFLOWS_DIR에 실제 복사돼
    # @wizard 마커를 가진 것만 configure. (.template.yaml/.bak은 대상 아님)
    local _src_dir _wf _bn _target
    for _src_dir in "$type_dir" "$nexus_dir"; do
        [ -d "$_src_dir" ] || continue
        for _wf in "$_src_dir"/*.{yaml,yml}; do
            [ -e "$_wf" ] || continue
            _bn=$(basename "$_wf")
            _target="$WORKFLOWS_DIR/$_bn"
            [ -f "$_target" ] || continue          # 건너뛴(S) 파일은 원본 미반영이라 제외
            # 내용 동일(unchanged)로 분류된 파일은 이미 설치 최종형과 같으므로 재설정 불필요
            local _skip_cfg=false _uf
            for _uf in "${unchanged_files[@]:-}"; do
                [ "$_uf" = "$_bn" ] && { _skip_cfg=true; break; }
            done
            [ "$_skip_cfg" = true ] && continue
            configure_workflow_env "$type" "$_target"
        done
    done
}

# 멀티타입 안내·체크 헬퍼 — PROJECT_TYPES 배열에 특정 타입 포함 여부
_contains_type() {
    local needle=$1
    local arr=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
    local x
    for x in "${arr[@]}"; do [ "$x" = "$needle" ] && return 0; done
    return 1
}

copy_workflows() {
    print_step "프로젝트 타입별 워크플로우 다운로드 중..."
    local IFS=','
    print_info "프로젝트 타입: ${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
    unset IFS

    mkdir -p "$WORKFLOWS_DIR"

    # 멀티타입 순회에서 _copy_workflows_for_type이 공유하는 카운터 (전역)
    _wf_copied=0
    _wf_skipped=0
    _wf_template_added=0
    _wf_optional_copied=0   # opt-in(nexus/secret-backup) 워크플로우 복사 수
    local project_types_dir="$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR"

    # project-types 폴더 존재 확인
    if [ ! -d "$project_types_dir" ]; then
        print_error "템플릿 저장소의 폴더 구조가 올바르지 않습니다."
        print_error "템플릿 저장소 구조 오류 — project-types 폴더를 찾지 못했습니다."
        exit 1
    fi

    # 1. Common 워크플로우 다운로드 (항상 최신으로 업데이트)
    # *.{yaml,yml} 글로브는 common/ 직접 하위 파일만 매칭 (common/secret-backup/ 등 하위 디렉토리 제외)
    print_info "모든 타입에 공통으로 들어가는 기본 워크플로우를 내려받고 있습니다..."
    if [ -d "$project_types_dir/common" ]; then
        for workflow in "$project_types_dir/common"/*.{yaml,yml}; do
            [ -e "$workflow" ] || continue
            local filename=$(basename "$workflow")

            # 내용이 이미 동일하면 cp 생략 (변경점 0인 파일 덮어쓰기 방지)
            if [ -f "$WORKFLOWS_DIR/$filename" ] && _wf_is_unchanged "common" "$workflow" "$WORKFLOWS_DIR/$filename"; then
                echo "  ✓ $filename (변경 없음)"
                _wf_skipped=$((_wf_skipped + 1))
                continue
            fi

            # COMMON은 항상 덮어쓰기 (핵심 기능)
            if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                print_info "$filename 업데이트"
            fi

            cp "$workflow" "$WORKFLOWS_DIR/"
            echo "  ✓ $filename"
            _wf_copied=$((_wf_copied + 1))
        done
    else
        print_warning "공통 워크플로우 폴더(common)를 찾지 못해 건너뜁니다."
    fi

    # 2~3. 타입별 워크플로우 + 타입별 Nexus(opt-in) 처리 — PROJECT_TYPES 배열 순회
    #       타입별 파일명은 PROJECT-{TYPE}- prefix로 완전 분리되어 충돌 0.
    local _types_to_copy=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
    local _t
    # (타입 순회 전) 배포 env 계획 1회 수립 — 기본값 표·메뉴·prefill. 이후 configure_workflow_env는
    # WF_USE_DEFAULTS=true + 캐시값(wf_deploy_*)만 사용하므로 가상 비교 경로도 무손상.
    wf_prompt_env_plan "$project_types_dir" "${_types_to_copy[@]}"
    for _t in "${_types_to_copy[@]}"; do
        _copy_workflows_for_type "$_t" "$project_types_dir"
    done

    # 4. Common Secret 백업 워크플로우 처리 (opt-in)
    local common_secret_dir="$project_types_dir/common/secret-backup"
    if [ -d "$common_secret_dir" ]; then
        if [ "$INCLUDE_SECRET_BACKUP" = true ]; then
            print_info "공통 Secret 백업 워크플로우 다운로드 중..."
            for workflow in "$common_secret_dir"/*.{yaml,yml}; do
                [ -e "$workflow" ] || continue
                local filename=$(basename "$workflow")

                # 이미 복사된 파일이면 스킵
                if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                    print_warning "$filename: 이미 존재하여 건너뜁니다."
                    continue
                fi

                cp "$workflow" "$WORKFLOWS_DIR/"
                echo "  ✓ $filename (Secret 백업)"
                _wf_optional_copied=$((_wf_optional_copied + 1))
                _wf_copied=$((_wf_copied + 1))
            done
        else
            local common_sb_count=0
            for f in "$common_secret_dir"/*.{yaml,yml}; do
                [ -e "$f" ] && common_sb_count=$((common_sb_count + 1))
            done
            if [ $common_sb_count -gt 0 ]; then
                print_info "공통 Secret 백업 워크플로우 $common_sb_count개 제외됨 (--secret-backup 옵션으로 포함 가능)"
            fi
        fi
    fi

    # 결과 요약
    echo ""
    local _types_summary
    local IFS=','
    _types_summary="${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
    unset IFS
    print_success "워크플로우 처리 완료 (타입: $_types_summary)"
    echo "   📥 복사됨: $_wf_copied 개"
    if [ $_wf_optional_copied -gt 0 ]; then
        echo "   🧩 선택 워크플로우: $_wf_optional_copied 개"
    fi
    if [ $_wf_template_added -gt 0 ]; then
        echo "   📄 참고용 추가 (.template.yaml): $_wf_template_added 개"
    fi
    if [ $_wf_skipped -gt 0 ]; then
        echo "   ⏭ 건너뜀: $_wf_skipped 개"
    fi

    # 복사된 워크플로우 수를 전역 변수로 저장 (최종 요약에서 사용)
    WORKFLOWS_COPIED=$_wf_copied

    # 멀티타입 CI 트리거 충돌 경고 — 여러 *-CI.yaml이 같은 push에 동시 발화
    if [ ${#PROJECT_TYPES[@]} -gt 1 ]; then
        echo ""
        print_warning "⚠️  멀티타입 주의: 여러 타입의 CI/CD 워크플로우가 같은 push에 동시 실행됩니다."
        print_warning "   각 워크플로우의 paths: 필터를 디렉토리별로 수동 추가해 분리하길 권장합니다."
        print_warning "   배포 워크플로우는 PROJECT_NAME/CONTAINER_NAME/DEPLOY_PORT를 타입별로 다르게 설정하세요."
    fi

    # CI/CD 워크플로우 안내 — PROJECT_TYPES 배열에 spring 포함 시
    if _contains_type "spring"; then
        echo ""
        print_info "🔐 Spring CI/CD 워크플로우 사용 시 GitHub Secrets 설정:"
        echo "     Repository > Settings > Secrets and variables > Actions"
        echo "     필수 Secrets:"
        echo "       - APPLICATION_PROD_YML (Spring 운영 설정)"
        echo "       - DOCKERHUB_USERNAME, DOCKERHUB_TOKEN"
        echo "       - SERVER_HOST, SERVER_USER, SERVER_PASSWORD"
        echo "       - GRADLE_PROPERTIES (Nexus 사용 시)"
    fi
}

# 스크립트 다운로드
copy_scripts() {
    print_step "버전 관리 스크립트 다운로드 중..."
    
    mkdir -p "$SCRIPTS_DIR"
    
    local scripts=(
        "version_manager.sh"
        "changelog_manager.py"
    )
    
    local copied=0
    for script in "${scripts[@]}"; do
        local src="$TEMP_DIR/$SCRIPTS_DIR/$script"
        local dst="$SCRIPTS_DIR/$script"
        
        if [ -f "$src" ]; then
            cp "$src" "$dst"
            chmod +x "$dst"
            echo "  ✓ $script"
            copied=$((copied + 1))
        fi
    done
    
    print_success "$copied개 스크립트 다운로드 완료"
}

# .github/config 폴더 복사
copy_config_folder() {
    print_step ".github/config 폴더 복사 중..."

    local src_config_dir="$TEMP_DIR/.github/config"
    local dst_config_dir=".github/config"

    if [ ! -d "$src_config_dir" ]; then
        print_info ".github/config 폴더가 템플릿에 없어 건너뜁니다."
        return
    fi

    # 기존 config 파일이 있으면 알림
    if [ -d "$dst_config_dir" ] && [ "$(ls -A "$dst_config_dir" 2>/dev/null)" ]; then
        print_info "기존 config 파일을 최신 버전으로 덮어씁니다."
    fi

    mkdir -p "$dst_config_dir"

    # 항상 최신으로 덮어쓰기
    cp -r "$src_config_dir/"* "$dst_config_dir/" 2>/dev/null || true

    # 복사된 파일 개수 계산
    local copied=$(ls -1 "$dst_config_dir" 2>/dev/null | wc -l | tr -d ' ')
    print_success ".github/config 폴더 복사 완료 ($copied개 파일)"
}

# 이슈 템플릿 다운로드
copy_issue_templates() {
    print_step "이슈/PR 템플릿 다운로드 중..."
    
    mkdir -p .github/ISSUE_TEMPLATE
    
    # 기존 템플릿 백업 (백업 디렉토리 없어도 실패하지 않음)
    if [ -d ".github/ISSUE_TEMPLATE" ] && [ "$(ls -A .github/ISSUE_TEMPLATE 2>/dev/null)" ]; then
        print_info "기존 이슈 템플릿을 최신 버전으로 덮어씁니다."
    fi
    
    # 템플릿 다운로드
    if [ -d "$TEMP_DIR/.github/ISSUE_TEMPLATE" ]; then
        cp -r "$TEMP_DIR/.github/ISSUE_TEMPLATE/"* .github/ISSUE_TEMPLATE/ 2>/dev/null || true
    fi
    
    # PR 템플릿
    if [ -f "$TEMP_DIR/.github/PULL_REQUEST_TEMPLATE.md" ]; then
        cp "$TEMP_DIR/.github/PULL_REQUEST_TEMPLATE.md" .github/
        print_success "이슈/PR 템플릿을 적용했습니다"
    fi
}

# Discussion 템플릿 다운로드
copy_discussion_templates() {
    print_step "GitHub Discussions 템플릿 다운로드 중..."
    
    # 템플릿에 DISCUSSION_TEMPLATE이 없으면 건너뛰기
    if [ ! -d "$TEMP_DIR/.github/DISCUSSION_TEMPLATE" ]; then
        print_info "Discussions 템플릿이 템플릿에 없어 건너뜁니다."
        return
    fi
    
    mkdir -p .github/DISCUSSION_TEMPLATE
    
    # 기존 템플릿이 있으면 알림
    if [ -d ".github/DISCUSSION_TEMPLATE" ] && [ "$(ls -A .github/DISCUSSION_TEMPLATE 2>/dev/null)" ]; then
        print_info "기존 Discussion 템플릿을 최신 버전으로 덮어씁니다."
    fi
    
    # 템플릿 다운로드
    cp -r "$TEMP_DIR/.github/DISCUSSION_TEMPLATE/"* .github/DISCUSSION_TEMPLATE/ 2>/dev/null || true
    print_success "GitHub Discussions 템플릿을 적용했습니다"
}

# .coderabbit.yaml 다운로드
# CodeRabbit이 무엇이고, 이 파일이 어떤 설정으로 동작하는지 안내한다.
# (설정을 안 하고 "왜 리뷰가 안 달리지?" 하는 사용자가 많아 명시적으로 설명한다.)
show_coderabbit_intro() {
    print_to_user ""
    print_to_user "  🐰 CodeRabbit이란?"
    print_to_user "     PR을 올리면 AI가 코드 변경을 자동으로 읽고 리뷰 코멘트를 달아주는 서비스입니다."
    print_to_user "     (버그·보안·개선점 지적, 변경 요약, PR 내 채팅 질문 응답)"
    print_to_user ""
    print_to_user "  📋 이 .coderabbit.yaml에 들어가는 설정:"
    print_to_user "     • 리뷰 언어        : 한국어(ko-KR)"
    print_to_user "     • 자동 리뷰        : 켜짐 — main 대상 PR에 자동 리뷰 (draft PR 제외)"
    print_to_user "     • 리뷰 성향        : chill (과하지 않게), 변경요약 표시, 변경요청 강제 안 함"
    print_to_user "     • PR 채팅 자동응답  : 켜짐"
    print_to_user ""
    print_to_user "  ⚠️  파일만으로는 끝이 아닙니다 — 한 번만 활성화하면 됩니다:"
    print_to_user "     1) https://coderabbit.ai 접속 → GitHub으로 로그인"
    print_to_user "     2) 이 저장소를 CodeRabbit에 연결(Authorize/Enable)"
    print_to_user "     이 단계를 안 하면 .coderabbit.yaml이 있어도 리뷰가 달리지 않습니다."
    print_to_user ""
}

copy_coderabbit_config() {
    print_step "CodeRabbit AI 리뷰 설정을 확인하고 있습니다..."

    if [ ! -f "$TEMP_DIR/.coderabbit.yaml" ]; then
        print_info ".coderabbit.yaml이 템플릿에 없어 건너뜁니다."
        return
    fi

    # CodeRabbit 소개 + 설정 안내 (덮어쓰기/신규 적용 공통으로 먼저 보여준다)
    show_coderabbit_intro

    # 기존 파일이 있으면 사용자 확인
    if [ -f ".coderabbit.yaml" ]; then
        print_warning ".coderabbit.yaml이 이미 있습니다 — 덮어쓸지 확인합니다"
        
        if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
            print_separator_line
            print_to_user ""

            # 워크플로우 충돌 메뉴와 동일하게 '덮어쓰기 / 건너뛰기' 선택지를 명시한다.
            # (단순 예/아니오는 "건너뛰기"가 직관적이지 않아 사용자가 헷갈린다.)
            # set -e 안전: ESC(비-0)에 함수가 통째로 종료되지 않도록 || true로 종료코드 흡수.
            local _cr_label
            _cr_label=$(choose_menu "기존 .coderabbit.yaml을 어떻게 할까요?" \
                "덮어쓰기 — 기존 파일을 .bak 백업 후 교체 (권장)|" \
                "건너뛰기 — 기존 파일만 유지|") || true
            case "$_cr_label" in
                덮어쓰기*) : ;;   # 계속 진행 (아래에서 백업 후 교체)
                *)
                    # 건너뛰기 또는 ESC/취소 → 기존 유지
                    print_info ".coderabbit.yaml 업데이트를 건너뜁니다 — 기존 설정을 유지합니다"
                    return
                    ;;
            esac

            # 백업
            cp .coderabbit.yaml .coderabbit.yaml.bak
            print_info "기존 파일을 .coderabbit.yaml.bak으로 백업했습니다"
        elif [ "$FORCE_MODE" = true ]; then
            # Force 모드에서는 백업하고 덮어쓰기
            cp .coderabbit.yaml .coderabbit.yaml.bak 2>/dev/null || true
            print_info "강제 모드 — 기존 파일을 새 버전으로 교체합니다"
        else
            # TTY 없고 Force도 아니면 건너뛰기
            print_info "대화형 입력이 불가능한 환경이라 기존 파일을 유지합니다."
            return
        fi
    fi
    
    # 다운로드 실행
    cp "$TEMP_DIR/.coderabbit.yaml" .coderabbit.yaml
    print_success ".coderabbit.yaml 설정을 적용했습니다 (CodeRabbit AI 리뷰 활성화)"
    print_info "💡 CodeRabbit AI 리뷰가 활성화됩니다 (language: ko-KR)"
}

# gitignore 항목 정규화 함수 (중복 체크용)
# 예: "/.idea" -> ".idea", ".idea" -> ".idea", "./idea" -> ".idea"
# 예: "/.claude/settings.local.json" -> ".claude/settings.local.json"
normalize_gitignore_entry() {
    local entry="$1"
    # 주석 제거
    entry="${entry%%#*}"
    # 앞뒤 공백 제거
    entry=$(echo "$entry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # 앞의 슬래시 제거 (루트 경로 표시 제거)
    entry="${entry#/}"
    # "./" 제거 (현재 디렉토리 표시 제거, 하지만 ".idea" 같은 숨김 폴더는 보존)
    entry="${entry#./}"
    # 뒤의 슬래시 제거 (디렉토리 표시 제거)
    entry="${entry%/}"
    # 빈 문자열이면 원본 반환
    if [ -z "$entry" ]; then
        echo "$1"
    else
        echo "$entry"
    fi
}

# gitignore 파일에서 항목 존재 여부 확인 (정규화된 비교)
check_gitignore_entry_exists() {
    local target_entry="$1"
    local gitignore_file="$2"
    
    # 정규화된 타겟 항목
    local normalized_target=$(normalize_gitignore_entry "$target_entry")
    
    # gitignore 파일의 각 라인 확인
    while IFS= read -r line || [ -n "$line" ]; do
        # 주석 라인 건너뛰기
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # 빈 라인 건너뛰기
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        
        # 정규화된 라인과 비교
        local normalized_line=$(normalize_gitignore_entry "$line")
        
        if [ "$normalized_line" = "$normalized_target" ]; then
            return 0  # 존재함
        fi
    done < "$gitignore_file"
    
    return 1  # 존재하지 않음
}

# .gitignore 생성 또는 업데이트
ensure_gitignore() {
    print_step ".gitignore 파일 확인 및 업데이트 중..."
    
    local required_entries=(
        "/.idea"
        "/.claude/settings.local.json"
    )
    
    # .gitignore가 없으면 생성
    if [ ! -f ".gitignore" ]; then
        print_info ".gitignore가 없어 필수 항목과 함께 새로 만듭니다."
        
        cat > .gitignore << 'EOF'
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json
EOF
        
        print_success ".gitignore를 새로 만들었습니다"
        return
    fi
    
    # 기존 파일이 있으면 누락된 항목만 추가
    print_info "기존 .gitignore를 발견했습니다 — 필수 항목이 있는지 확인합니다..."
    
    local added=0
    local entries_to_add=()
    
    for entry in "${required_entries[@]}"; do
        # 정규화된 비교로 중복 체크
        if ! check_gitignore_entry_exists "$entry" ".gitignore"; then
            entries_to_add+=("$entry")
            added=$((added + 1))
        fi
    done
    
    if [ $added -eq 0 ]; then
        print_info "필수 항목이 이미 모두 있어 업데이트를 건너뜁니다."
        return
    fi
    
    # 항목 추가 (마지막에 섹션으로 추가)
    print_info "$added개 항목 추가 중..."
    
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
    
    print_success ".gitignore 업데이트 완료 ($added개 항목 추가)"
}

# SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 다운로드
copy_setup_guide() {
    print_step "템플릿 설정 가이드 다운로드 중..."
    
    if [ ! -f "$TEMP_DIR/SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" ]; then
        print_info "설정 가이드(SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md)가 템플릿에 없어 건너뜁니다."
        return
    fi
    
    # 항상 최신 버전으로 다운로드 (기존 파일 덮어쓰기)
    cp "$TEMP_DIR/SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" .
    print_success "템플릿 설정 가이드를 적용했습니다 (최신 버전)"
    print_info "📖 템플릿 사용법을 SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md에서 확인하세요"
}

# ===================================================================
# 프로젝트 타입별 유틸리티 모듈 다운로드
# ===================================================================
# 프로젝트 타입에 따라 추가 유틸리티 모듈(마법사 등)을 다운로드합니다.
# 현재 지원: flutter (ios-testflight-setup-wizard, android-playstore-setup-wizard)
# 확장 가능: 다른 프로젝트 타입에도 util 모듈 추가 시 자동 지원
# ===================================================================

# util 모듈 설명 표시
show_util_module_description() {
    local project_type=$1

    case $project_type in
        flutter)
            print_separator_line
            print_to_user ""
            print_to_user "📦 Flutter 추가 유틸리티 모듈:"
            print_to_user ""
            print_to_user "  🧙 ios-testflight-setup-wizard"
            print_to_user "     iOS TestFlight 배포에 필요한 설정 파일들을"
            print_to_user "     웹 브라우저에서 쉽게 생성할 수 있는 마법사입니다."
            print_to_user "     → ExportOptions.plist, Fastfile 등 자동 생성"
            print_to_user ""
            print_to_user "  🧙 android-playstore-setup-wizard"
            print_to_user "     Android Play Store 배포에 필요한 설정 파일들을"
            print_to_user "     웹 브라우저에서 쉽게 생성할 수 있는 마법사입니다."
            print_to_user "     → Fastfile, build.gradle 서명 설정 등 자동 생성"
            print_to_user ""
            ;;
        # 다른 프로젝트 타입 추가 시 여기에 case 추가
        # spring)
        #     print_to_user "📦 Spring 추가 유틸리티 모듈:"
        #     ...
        #     ;;
        *)
            # 알 수 없는 타입은 일반 메시지
            print_separator_line
            print_to_user ""
            print_to_user "📦 $project_type 추가 유틸리티 모듈이 있습니다."
            print_to_user ""
            ;;
    esac
}

# util 모듈 사용 가이드 표시
show_util_usage_guide() {
    local project_type=$1

    case $project_type in
        flutter)
            print_to_user ""
            print_info "📖 Flutter 마법사 사용법:"
            print_to_user "   iOS TestFlight:"
            print_to_user "     1. 브라우저에서 열기:"
            print_to_user "        .github/util/flutter/ios-testflight-setup-wizard/index.html"
            print_to_user "     2. 필요한 정보 입력 후 파일 생성"
            print_to_user "     3. 생성된 파일을 ios/ 폴더에 복사"
            print_to_user ""
            print_to_user "   Android Play Store:"
            print_to_user "     1. 브라우저에서 열기:"
            print_to_user "        .github/util/flutter/android-playstore-setup-wizard/index.html"
            print_to_user "     2. 필요한 정보 입력 후 파일 생성"
            print_to_user "     3. 생성된 파일을 android/ 폴더에 복사"
            print_to_user ""
            ;;
        *)
            print_to_user ""
            print_info "📖 util 모듈 사용법:"
            print_to_user "   .github/util/$project_type/ 폴더 내 README.md를 참고하세요."
            print_to_user ""
            ;;
    esac
}

# 프로젝트 타입별 util 모듈 다운로드
copy_util_modules() {
    local project_type=$1
    local util_src="$TEMP_DIR/.github/util/$project_type"
    local util_dst=".github/util/$project_type"

    # util 모듈 존재 확인
    if [ ! -d "$util_src" ]; then
        # util 모듈이 없으면 조용히 건너뜀 (모든 타입에 모듈이 있는 건 아님)
        return
    fi

    print_step "$project_type 추가 유틸리티 모듈 확인 중..."

    # 모듈 설명 표시
    show_util_module_description "$project_type"

    # 사용자 확인 (force 모드가 아니고 TTY 가용 시)
    if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
        if ! ask_yes_no "이 유틸리티 모듈을 다운로드할까요?" "Y"; then
            print_info "유틸리티 모듈 다운로드를 건너뜁니다"
            return
        fi
    elif [ "$FORCE_MODE" = true ]; then
        # Force 모드에서는 자동으로 다운로드
        print_info "강제 모드 — 유틸리티 모듈을 자동으로 내려받습니다"
    else
        # TTY 없고 Force도 아니면 건너뛰기
        print_info "대화형 입력이 불가능한 환경이라 유틸리티 모듈을 건너뜁니다."
        print_info "util 모듈을 다운로드하려면 --force 옵션을 사용하세요."
        return
    fi

    # 다운로드 실행
    mkdir -p "$util_dst"
    cp -r "$util_src/"* "$util_dst/" 2>/dev/null || true

    # 복사된 모듈 개수 계산
    local module_count=0
    for dir in "$util_dst"/*/; do
        [ -d "$dir" ] && module_count=$((module_count + 1))
    done

    print_success "유틸리티 모듈을 적용했습니다 ($module_count개 모듈)"

    # 복사된 모듈 목록 표시
    for dir in "$util_dst"/*/; do
        [ -d "$dir" ] || continue
        local module_name=$(basename "$dir")
        echo "  ✓ $module_name"
    done

    # 사용 가이드 표시
    show_util_usage_guide "$project_type"

    # 복사된 모듈 수를 전역 변수로 저장 (최종 요약에서 사용)
    UTIL_MODULES_COPIED=$module_count
}


# 대화형 모드
interactive_mode() {
    # Interactive 모드 플래그 설정
    IS_INTERACTIVE_MODE=true
    
    # 템플릿 버전 가져오기 (원격 version.yml)
    local template_version=""
    
    # GitHub 원격 저장소의 version.yml에서 버전 가져오기
    if command -v curl >/dev/null 2>&1; then
        template_version=$(curl -fsSL --max-time 3 \
            "${TEMPLATE_RAW_URL}/${VERSION_FILE}" \
            2>/dev/null | grep "^version:" | sed 's/version:[[:space:]]*[\"'\'']*\([^\"'\'']*\)[\"'\'']*$/\1/' | head -1)
    fi
    
    # 폴백: 버전을 가져오지 못한 경우 기본값 사용
    if [ -z "$template_version" ]; then
        template_version="$DEFAULT_VERSION"
    fi
    
    print_banner "$template_version" "Interactive (대화형 모드)"
    
    # stdin 모드 정보 표시
    if [ "$STDIN_MODE" = true ] && [ "$TTY_AVAILABLE" = true ]; then
        print_info "원격 실행 모드 감지: /dev/tty를 통해 대화형 입력 사용"
        if [ -w /dev/tty ] 2>/dev/null; then echo "" >/dev/tty; else echo "" >&2; fi
    fi
    
    # 터미널 상태 확인
    if [ "$TTY_AVAILABLE" = false ]; then
        print_error "대화형 입력이 불가능한 환경입니다 (CI/CD, non-interactive shell)"
        print_error "다음 중 하나를 사용하세요:"
        if [ -w /dev/tty ] 2>/dev/null; then
            echo "" >/dev/tty
            echo "  ${GREEN}bash <(curl -fsSL URL) --mode full --force${NC}" >/dev/tty
            echo "  ${GREEN}bash <(curl -fsSL URL) --mode version${NC}" >/dev/tty
            echo "  ${GREEN}curl -fsSL URL | bash -s -- --mode version --force${NC}" >/dev/tty
            echo "" >/dev/tty
        else
            echo "" >&2
            echo "  ${GREEN}bash <(curl -fsSL URL) --mode full --force${NC}" >&2
            echo "  ${GREEN}bash <(curl -fsSL URL) --mode version${NC}" >&2
            echo "  ${GREEN}curl -fsSL URL | bash -s -- --mode version --force${NC}" >&2
            echo "" >&2
        fi
        exit 1
    fi
    
    # ── 1) 모드 선택 먼저 (사용자 의도부터 파악) ──
    # 사용자가 무엇을 하려는지 먼저 묻고, 모드에 따라 필요한 정보만 수집한다.
    # (예: skills/issues 모드는 프로젝트 타입·버전·선택 워크플로우·경로가 전혀 필요 없음)
    print_question_header "🚀" "어떤 기능을 통합하시겠습니까?"

    # 라벨에 영어 키(full/version…)가 보이지 않도록, 사용자에게는 한국어 설명만 노출한다.
    # choose_menu는 value를 표시하므로 value 자리에 한국어 라벨을 두고 반환값을 케이스로 매핑.
    # 최상위 첫 화면이라 ESC는 '취소'(종료). set -e 환경에서 ESC(비-0)가 함수를
    # 죽여 안내 없이 끝나지 않도록 || 로 코드를 받아 cancel로 매핑한다.
    local _mode_label _mode_rc=0
    _mode_label=$(choose_menu "무엇을 설치할까요?" \
        "전체 설치 — 버전관리 + 자동화 워크플로우 + 이슈·PR 템플릿 (처음이라면 추천)|" \
        "버전 관리만 — 버전 자동 증가·동기화 시스템만 설치|" \
        "워크플로우만 — 빌드·배포 GitHub Actions만 설치|" \
        "이슈·PR 템플릿만 — GitHub 이슈/PR 양식만 설치|" \
        "AI 스킬만 — Claude·Cursor·Gemini·Codex·PI용 스킬만 설치|" \
        "취소|") || _mode_rc=$?

    # 한국어 라벨 → 내부 모드 키 매핑 (ESC=비-0 → cancel)
    local _mode_selected=""
    if [ "$_mode_rc" -ne 0 ]; then
        _mode_selected="cancel"
    else
        case "$_mode_label" in
            전체\ 설치*)        _mode_selected="full" ;;
            버전\ 관리만*)      _mode_selected="version" ;;
            워크플로우만*)      _mode_selected="workflows" ;;
            이슈*PR\ 템플릿만*) _mode_selected="issues" ;;
            AI\ 스킬만*)        _mode_selected="skills" ;;
            *)                  _mode_selected="cancel" ;;
        esac
    fi

    if [ -z "$_mode_selected" ] || [ "$_mode_selected" = "cancel" ]; then
        print_info "설치를 취소했습니다. 스크립트를 종료합니다."
        exit 0
    fi

    MODE="$_mode_selected"

    # 템플릿 다운로드 (모드별 수집·복사에서 사용)
    download_template

    # ── 2) 모드별 필요 정보만 수집 ──
    # 수집 매트릭스: full=타입/버전/선택WF/경로, version=타입/버전/경로,
    #               workflows=타입/선택WF, issues=없음, skills=없음
    case "$MODE" in
        skills|issues)
            # 프로젝트 정보 불필요 → 수집·확인 전부 건너뜀. 바로 실행 단계로.
            ;;
        *)
            # full/version/workflows → 타입·버전·브랜치 감지 → 선택 워크플로우·경로 수집 → 최종 확인
            # 순서가 핵심: 선택 워크플로우·경로를 확인 화면 '전에' 모아야 확인 화면에 함께 표시된다.

            # 1) 타입/버전/브랜치 먼저 감지 (확인은 아직 안 함)
            if [ ${#PROJECT_TYPES[@]} -eq 0 ]; then
                local _detected_csv
                _detected_csv=$(detect_project_types)
                IFS=',' read -ra PROJECT_TYPES <<< "$_detected_csv"
                PROJECT_TYPE="${PROJECT_TYPES[0]}"
            fi
            [ -z "$VERSION" ] && VERSION=$(detect_version)
            [ -z "$DETECTED_BRANCH" ] && DETECTED_BRANCH=$(detect_default_branch)

            # 2) 선택 워크플로우(Nexus/Secret 백업): 포함 모드(full/workflows)에서만, 멀티타입은 폴더 합쳐 한 번만
            if [ "$MODE" = "full" ] || [ "$MODE" = "workflows" ]; then
                local _opt_dirs=()
                local _st
                for _st in "${PROJECT_TYPES[@]:-$PROJECT_TYPE}"; do
                    _opt_dirs+=("$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR/$_st")
                done
                ask_all_optional_workflows "${_opt_dirs[@]}"
            fi

            # 3) 경로: full/version 모드에서만 필요
            #    이미 init된 프로젝트(version.yml에 project_paths 있음)는 저장값을 '로드만' 해
            #    확인 화면에 보여주고 질문은 생략한다. 저장값이 없거나 일부만 있으면(신규 init)
            #    확인 화면을 거친 뒤(아래 5번) 비어있는 타입만 resolve_project_paths로 묻는다.
            if [ "$MODE" = "full" ] || [ "$MODE" = "version" ]; then
                load_saved_project_paths || true
            fi

            # 4) 모든 수집 결과를 확인 화면에 모아 최종 확인 (수정/취소 가능)
            detect_and_confirm_project

            # 5) 확인 후에도 경로가 비어있는 대상 타입이 있으면(신규 init) 그때 질문한다.
            #    (사용자가 '수정 → 타입 변경'을 했다면 그 안에서 이미 경로를 다시 물었으므로 보통 채워져 있다.)
            if [ "$MODE" = "full" ] || [ "$MODE" = "version" ]; then
                local _need_paths=false _pt
                for _pt in "${PROJECT_TYPES[@]:-$PROJECT_TYPE}"; do
                    [ "$_pt" = "basic" ] && continue
                    if [ -z "$(get_path_for_type "$_pt")" ]; then _need_paths=true; break; fi
                done
                [ "$_need_paths" = true ] && resolve_project_paths
            fi
            ;;
    esac
}

# 통합 실행
execute_integration() {
    # Breaking Changes 확인 (업데이트 시)
    local current_template_version
    current_template_version=$(get_current_template_version)
    if [ "$current_template_version" != "unknown" ]; then
        check_breaking_changes "$current_template_version" "$DEFAULT_VERSION"
    fi

    # CLI 모드에서만 자동 감지 및 확인 (interactive 모드에서는 이미 감지 완료, skills 모드는 프로젝트 정보 불필요)
    if [ "$IS_INTERACTIVE_MODE" = false ] && [ "$MODE" != "skills" ]; then
        # --type으로 PROJECT_TYPES가 안 채워졌으면 멀티 자동 감지
        if [ ${#PROJECT_TYPES[@]} -eq 0 ]; then
            local _detected_csv
            _detected_csv=$(detect_project_types)
            IFS=',' read -ra PROJECT_TYPES <<< "$_detected_csv"
            PROJECT_TYPE="${PROJECT_TYPES[0]}"
        fi

        if [ -z "$VERSION" ]; then
            VERSION=$(detect_version)
        fi

        if [ -z "$DETECTED_BRANCH" ]; then
            DETECTED_BRANCH=$(detect_default_branch)
        fi

        # CLI 모드에서만 통합 정보 표시
        print_question_header "🪐" "통합 설정 확인"

        local _cli_types
        local IFS=','
        _cli_types="${PROJECT_TYPES[*]}"
        unset IFS
        if [ ${#PROJECT_TYPES[@]} -gt 1 ]; then
            print_to_user "🔭 프로젝트 타입  : $_cli_types (멀티)"
        else
            print_to_user "🔭 프로젝트 타입  : $PROJECT_TYPE"
        fi
        print_to_user "🌙 초기 버전     : v$VERSION"
        print_to_user "🌿 Default 브랜치 : $DETECTED_BRANCH"
        print_to_user "💫 통합 모드     : $MODE"
        print_separator_line
        print_to_user ""

        # CLI 모드에서만 확인 질문 (force 모드가 아닐 때만)
        if [ "$FORCE_MODE" = false ]; then
            if [ "$TTY_AVAILABLE" = true ]; then
                if ! ask_yes_no "이 설정으로 통합을 진행할까요?" "Y"; then
                    print_info "통합을 취소했습니다. (설정을 다시 검토한 뒤 재실행하세요)"
                    exit 0
                fi
            else
                # TTY 없음 - --force 필수
                print_error "--force 옵션이 필요합니다 (non-interactive 환경)"
                echo "" >&2
                echo "  bash <(curl -fsSL URL) --mode $MODE --force" >&2
                echo "" >&2
                exit 1
            fi
        fi
    fi
    
    echo "" >&2

    # 1. 템플릿 다운로드 (CLI 모드에서만, interactive 모드는 이미 다운로드됨)
    if [ "$IS_INTERACTIVE_MODE" = false ]; then
        download_template

        # CLI 모드에서도 선택 워크플로우 질문 (워크플로우 모드에서만)
        # 멀티타입이면 모든 타입의 nexus 폴더 + 공통 secret-backup을 합쳐 한 번만 질문
        if [ "$MODE" = "full" ] || [ "$MODE" = "workflows" ]; then
            local _opt_dirs=()
            local _st
            for _st in "${PROJECT_TYPES[@]:-$PROJECT_TYPE}"; do
                _opt_dirs+=("$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR/$_st")
            done
            ask_all_optional_workflows "${_opt_dirs[@]}"
        fi
    fi

    # 타입별 경로 확정 — version.yml에 project_paths 기록 (full/version 모드만)
    # interactive 모드는 확인 화면 전에 이미 수집했으므로 중복 호출 방지.
    if { [ "$MODE" = "full" ] || [ "$MODE" = "version" ]; } && [ "$IS_INTERACTIVE_MODE" = false ]; then
        resolve_project_paths
    fi

    # 2. 모드별 통합
    case $MODE in
        full)
            create_version_yml "$VERSION" "$PROJECT_TYPE" "$DETECTED_BRANCH"
            add_version_section_to_readme "$VERSION"
            copy_workflows
            update_version_yml_deploy   # 워크플로우 env 설정값을 version.yml deploy 블록에 기록
            copy_scripts
            copy_config_folder
            for _ut in "${PROJECT_TYPES[@]:-$PROJECT_TYPE}"; do copy_util_modules "$_ut"; done
            copy_issue_templates
            copy_discussion_templates
            copy_coderabbit_config
            ensure_gitignore
            copy_setup_guide
            ;;
        version)
            create_version_yml "$VERSION" "$PROJECT_TYPE" "$DETECTED_BRANCH"
            add_version_section_to_readme "$VERSION"
            copy_scripts
            copy_config_folder
            ensure_gitignore
            copy_setup_guide
            ;;
        workflows)
            copy_workflows
            update_version_yml_deploy   # 워크플로우 env 설정값을 version.yml deploy 블록에 기록
            copy_scripts
            copy_config_folder
            for _ut in "${PROJECT_TYPES[@]:-$PROJECT_TYPE}"; do copy_util_modules "$_ut"; done
            copy_setup_guide
            ;;
        issues)
            copy_issue_templates
            copy_discussion_templates
            ;;
        skills)
            # skills 모드: 템플릿 통합 없이 IDE 도구 설치만 진행
            offer_ide_tools_install

            # 임시 파일 정리 후 간결한 완료 메시지 출력하고 종료
            rm -rf "$TEMP_DIR"
            print_summary
            return 0
            ;;
    esac

    # 2.1 템플릿 옵션 저장 (Nexus / Secret 백업 등 선택 워크플로우 설정)
    if [ "$MODE" = "full" ] || [ "$MODE" = "workflows" ]; then
        # 설정되지 않은 경우 기본값 false 사용
        # (해당 opt-in 폴더가 없는 타입을 위한 처리)
        [ -z "$INCLUDE_NEXUS" ] && INCLUDE_NEXUS=false
        [ -z "$INCLUDE_SECRET_BACKUP" ] && INCLUDE_SECRET_BACKUP=false
        # 다운로드한 템플릿의 실제 버전 전달 (TEMPLATE_VERSION 사용)
        save_template_options "$TEMPLATE_VERSION"
    fi

    # 3. IDE 도구(Skills) 설치 제안
    offer_ide_tools_install

    # 4. 임시 파일 정리
    rm -rf "$TEMP_DIR"

    # 완료 메시지
    print_summary
}

# ===================================================================
# IDE 도구(Skills) 설치 제안
# Claude Code: 플러그인 마켓플레이스 자동 설치
# Cursor: skills/ → .cursor/skills/ 복사
# Gemini CLI: extension install/update
# Codex CLI: plugin marketplace registration, fallback to ~/.agents/skills native discovery symlink
# ===================================================================

offer_ide_tools_install() {
    local claude_available=false

    # Claude Code CLI 존재 여부 감지
    if command -v claude &> /dev/null; then
        claude_available=true
    fi

    # ─── 현재 설치 상태 수집 ───
    local installed_scope=""
    local installed_version=""
    if [ "$claude_available" = true ]; then
        local plugin_json
        plugin_json=$(claude plugin list --json 2>/dev/null || echo "[]")
        local plugin_entry
        plugin_entry=$(echo "$plugin_json" | grep -A5 '"cassiiopeia@' | head -10)
        if [ -n "$plugin_entry" ]; then
            installed_scope=$(echo "$plugin_entry" | grep '"scope"' | sed 's/.*"scope": *"\([^"]*\)".*/\1/')
            installed_version=$(echo "$plugin_entry" | grep '"version"' | sed 's/.*"version": *"\([^"]*\)".*/\1/')
        fi
    fi

    # ─── 통합 상태 표시 ───
    echo "" >&2
    print_separator_line
    print_step "IDE Skills 현재 상태"
    echo "" >&2

    # 상태 표기 통일: scope(user/project) 구분 없이 "skill 설치됨/미설치"로만 안내.
    # 모든 IDE는 global(user) 한 곳에만 설치·관리한다.

    # Claude Code
    if [ "$claude_available" = true ]; then
        if [ -n "$installed_scope" ]; then
            local cv_tag=""
            [ -n "$TEMPLATE_VERSION" ] && [ "$installed_version" = "$TEMPLATE_VERSION" ] && cv_tag=" ✓ 최신"
            [ -n "$TEMPLATE_VERSION" ] && [ "$installed_version" != "$TEMPLATE_VERSION" ] && cv_tag=" → 업데이트 가능: v${TEMPLATE_VERSION}"
            print_info "Claude Code : skill 설치됨 (v${installed_version})${cv_tag}"
        else
            print_info "Claude Code : skill 미설치"
        fi
    else
        print_info "Claude Code : skill 미설치 (CLI 없음)"
    fi

    # Cursor — global(user) 한 곳만 확인
    local _cur_u_ver=""
    local _cur_u_meta="${HOME}/.cursor/skills/cursor-skills-meta.json"
    [ -f "$_cur_u_meta" ] && _cur_u_ver=$(grep '"version"' "$_cur_u_meta" | sed 's/.*"version": *"\([^"]*\)".*/\1/' | head -1)
    if [ -z "$_cur_u_ver" ]; then
        print_info "Cursor      : skill 미설치"
    else
        local utag=""
        [ -n "$TEMPLATE_VERSION" ] && [ "$_cur_u_ver" = "$TEMPLATE_VERSION" ] && utag=" ✓ 최신"
        [ -n "$TEMPLATE_VERSION" ] && [ "$_cur_u_ver" != "$TEMPLATE_VERSION" ] && utag=" → 업데이트 가능: v${TEMPLATE_VERSION}"
        print_info "Cursor      : skill 설치됨 (v${_cur_u_ver})${utag}"
    fi

    # Gemini
    if command -v gemini &> /dev/null; then
        print_info "Gemini CLI  : 설치 가능 (CLI 감지됨)"
    else
        print_info "Gemini CLI  : skill 미설치 (CLI 없음)"
    fi

    # Codex
    local codex_target="${HOME}/.agents/skills/cassiiopeia"
    if [ -L "$codex_target" ] || [ -d "$codex_target" ]; then
        print_info "Codex CLI   : skill 설치됨"
    elif command -v codex &> /dev/null; then
        print_info "Codex CLI   : 설치 가능 (CLI 감지됨)"
    else
        print_info "Codex CLI   : skill 미설치 (CLI 없음)"
    fi

    # PI — git package. 'pi list'에 우리 패키지가 잡히면 설치됨으로 본다.
    if command -v pi &> /dev/null; then
        if _pi_is_installed; then
            print_info "PI          : skill 설치됨"
        else
            print_info "PI          : 설치 가능 (CLI 감지됨)"
        fi
        # Persona Harness 상태 — skill과 독립
        if _pi_harness_enabled; then
            print_info "PI Harness   : 활성화됨 (Persona/Workflow 주입)"
        else
            print_info "PI Harness   : 비활성화"
        fi
    else
        print_info "PI          : skill 미설치 (CLI 없음)"
    fi
    echo "" >&2

    # ── 2단계 통합 라우터 ──
    # 1단계: 현재 상태(위에서 출력 완료) + 동작 선택(설치·업데이트 / 제거 / 건너뛰기)
    # 2단계: 그 동작을 적용할 IDE 멀티셀렉트 → 선택된 IDE만 기존 관리 로직 호출
    # 기존 IDE별 실행 로직은 _manage_*_section 함수로 보존(검증된 동작 유지), 라우터가 호출만 한다.
    if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
        # 감지된(=관리 가능한) IDE만 후보로 구성
        # IDE 후보 — value는 매핑 키(고유명사라 그대로), label은 비워 'Claude Code'만 깔끔히 표시.
        local _ide_opts=()
        _ide_opts+=("Claude Code|")
        _ide_opts+=("Cursor|")
        if command -v gemini &> /dev/null; then _ide_opts+=("Gemini CLI|"); else _ide_opts+=("Gemini CLI (미감지)|"); fi
        if command -v codex &> /dev/null || [ -e "${HOME}/.agents/skills/cassiiopeia" ]; then _ide_opts+=("Codex CLI|"); else _ide_opts+=("Codex CLI (미감지)|"); fi
        if command -v pi &> /dev/null; then _ide_opts+=("PI|"); else _ide_opts+=("PI (미감지)|"); fi
        # PI Persona Harness — skill과 독립. skill은 두고 harness만 켜고/끌 수 있는 별도 항목.
        # PI 패키지가 설치돼 harness loader가 있을 때만 후보로 노출.
        if command -v pi &> /dev/null && [ -f "$(_pi_harness_loader_path)" ]; then _ide_opts+=("PI Persona Harness|"); fi

        # ESC는 '그대로 두기'와 동일(건너뛰기). set -e 가드 || 로 비-0 흡수.
        local _action_label _action_rc=0
        _action_label=$(choose_menu --cancel-label="건너뛰기" "AI 스킬을 어떻게 할까요?" \
            "설치 / 업데이트 — 최신 상태로 맞추기|" \
            "제거 — 설치된 스킬 삭제하기|" \
            "그대로 두기|") || _action_rc=$?
        local _action=""
        if [ "$_action_rc" -ne 0 ]; then
            _action="skip"
        else
            case "$_action_label" in
                설치*)   _action="apply" ;;
                제거*)   _action="remove" ;;
                *)       _action="skip" ;;
            esac
        fi

        case "$_action" in
            apply)
                # 감지된 IDE 전체를 기본 체크 (미감지 항목은 preselect에서 제외)
                # value가 'Claude Code' 등 표시명이므로 매핑도 표시명 기준.
                local _pre="Claude Code,Cursor"
                command -v gemini &> /dev/null && _pre="$_pre,Gemini CLI"
                { command -v codex &> /dev/null || [ -e "${HOME}/.agents/skills/cassiiopeia" ]; } && _pre="$_pre,Codex CLI"
                command -v pi &> /dev/null && _pre="$_pre,PI"
                # ESC/무선택 → 건너뛰기. set -e 가드 || true.
                local _targets=""
                _targets=$(choose_menu --multi --cancel-label="뒤로" --preselect="$_pre" "설치 / 업데이트할 IDE를 고르세요" "${_ide_opts[@]}") || true
                [ -z "$_targets" ] && { print_info "선택한 IDE가 없어 설치/업데이트를 건너뜁니다 (원할 때 다시 실행하세요)."; return; }
                case ",$_targets," in *,Claude\ Code,*) _manage_claude_section "$claude_available" "$installed_scope" "$installed_version" ;; esac
                case ",$_targets," in *,Cursor,*)       _manage_cursor_section ;; esac
                case ",$_targets," in *,Gemini\ CLI,*)  _manage_gemini_extension ;; esac
                case ",$_targets," in *,Codex\ CLI,*)   _manage_codex_skills ;; esac
                case ",$_targets," in *,PI,*)           _manage_pi_section ;; esac
                case ",$_targets," in *,PI\ Persona\ Harness,*) _pi_harness_toggle ;; esac
                ;;
            remove)
                # 제거: 전체 후보 제시 후 미설치는 각 섹션이 no-op 처리
                # ESC/무선택 → 건너뛰기. set -e 가드 || true.
                local _targets=""
                _targets=$(choose_menu --multi --cancel-label="뒤로" "제거할 IDE를 고르세요" "${_ide_opts[@]}") || true
                [ -z "$_targets" ] && { print_info "선택한 IDE가 없어 설치/업데이트를 건너뜁니다 (원할 때 다시 실행하세요)."; return; }
                case ",$_targets," in *,Claude\ Code,*) _remove_claude_section "$claude_available" "$installed_scope" ;; esac
                case ",$_targets," in *,Cursor,*)       _remove_cursor_section ;; esac
                case ",$_targets," in *,Gemini\ CLI,*)  _remove_gemini_section ;; esac
                case ",$_targets," in *,Codex\ CLI,*)   _remove_codex_section ;; esac
                case ",$_targets," in *,PI,*)           _remove_pi_section ;; esac
                # PI skill은 두고 harness만 해제 (PI 항목과 별개로 단독 선택 가능)
                case ",$_targets," in *,PI\ Persona\ Harness,*) _pi_harness_remove_only ;; esac
                ;;
            *)
                print_info "IDE Skills는 변경하지 않고 넘어갑니다 — 통합은 계속됩니다."
                ;;
        esac
        return
    fi

    # ── FORCE / 비TTY — 기존 순차 흐름 유지 (자동 설치/업데이트) ──
    _manage_claude_section "$claude_available" "$installed_scope" "$installed_version"
    _manage_cursor_section
    _manage_gemini_extension
    _manage_codex_skills
    _manage_pi_section
}

# ── Claude Code 플러그인 관리 (기존 섹션 로직 보존) ──
_manage_claude_section() {
    local claude_available="$1"
    local installed_scope="$2"
    local installed_version="$3"

    print_step "[ Claude Code 플러그인 관리 ]"
    echo "" >&2

    if [ "$claude_available" = true ]; then
        if [ -n "$installed_scope" ]; then
            # 설치돼 있음 → 업데이트(최신화). 라우터에서 이미 동작을 정했으므로 추가 메뉴 없이 바로 실행.
            if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
                local choice=update
                case "$choice" in
                    update)
                        print_step "플러그인 업데이트 중..."
                        # 업데이트 전 현재 캐시 경로 저장 (마이그레이션용)
                        local old_cache_path
                        old_cache_path=$(find "$HOME/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia" -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)
                        if claude plugin update cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null; then
                            print_success "업데이트 완료 (scope: ${installed_scope})"
                            # 업데이트 후 새 캐시에 config.json 마이그레이션
                            local new_cache_path
                            new_cache_path=$(find "$HOME/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia" -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)
                            if [ -n "$old_cache_path" ] && [ -n "$new_cache_path" ] && [ "$old_cache_path" != "$new_cache_path" ]; then
                                if [ -d "$old_cache_path/config" ]; then
                                    mkdir -p "$new_cache_path/config"
                                    cp "$old_cache_path/config/"*.json "$new_cache_path/config/" 2>/dev/null && \
                                        print_success "config.json 마이그레이션 완료 (이전 버전 설정 유지)"
                                fi
                            fi
                        else
                            print_warning "업데이트 실패. 수동으로 실행해주세요:"
                            echo "    claude plugin update cassiiopeia@cassiiopeia-marketplace --scope ${installed_scope}" >&2
                        fi
                        ;;
                    reinstall)
                        print_step "기존 플러그인 삭제 중 (scope: ${installed_scope})..."
                        claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null || true
                        _remove_claude_plugin_data
                        local new_scope
                        new_scope="user"
                        _do_claude_plugin_install "$new_scope"
                        ;;
                    delete)
                        print_step "플러그인 삭제 중..."
                        print_info "  제거할 대상: cassiiopeia@cassiiopeia-marketplace (scope: ${installed_scope})"
                        print_info "             ~/.claude/plugins/data/cassiiopeia@cassiiopeia-marketplace/"
                        if claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null; then
                            print_success "플러그인 uninstall 완료"
                            _remove_claude_plugin_data
                        else
                            print_warning "삭제 실패. 수동으로 실행해주세요:"
                            echo "    claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope ${installed_scope}" >&2
                        fi
                        ;;
                    *)
                        print_info "Claude Code 플러그인은 변경하지 않고 넘어갑니다."
                        ;;
                esac
            else
                # FORCE 모드: 업데이트
                print_step "플러그인 업데이트 중 (FORCE)..."
                local old_cache_path_f
                old_cache_path_f=$(find "$HOME/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia" -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)
                claude plugin update cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null || true
                print_success "업데이트 완료 (scope: ${installed_scope})"
                local new_cache_path_f
                new_cache_path_f=$(find "$HOME/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia" -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)
                if [ -n "$old_cache_path_f" ] && [ -n "$new_cache_path_f" ] && [ "$old_cache_path_f" != "$new_cache_path_f" ]; then
                    if [ -d "$old_cache_path_f/config" ]; then
                        mkdir -p "$new_cache_path_f/config"
                        cp "$old_cache_path_f/config/"*.json "$new_cache_path_f/config/" 2>/dev/null && \
                            print_success "config.json 마이그레이션 완료 (이전 버전 설정 유지)"
                    fi
                fi
            fi
        else
            # 미설치 → 신규 설치. 라우터에서 이미 설치 의사 확인됨 → scope만 묻고 바로 설치.
            if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
                print_info "Claude Code 플러그인(DevOps Skills) 설치 — 설치 후 /cassiiopeia:suh-* 19+ 스킬 사용 가능"
                local scope
                scope="user"
                _do_claude_plugin_install "$scope"
            else
                _do_claude_plugin_install "user"
            fi
        fi
    else
        echo "  💡 Claude Code 사용자: claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE" >&2
        echo "                         claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user" >&2
    fi
}

# ── Cursor Skills 관리 (global=user 한 곳만, 마켓플레이스 미지원이라 파일 복사) ──
# Cursor는 마켓플레이스가 없어 ~/.cursor/skills/에 직접 복사하고,
# cursor-skills-meta.json(버전 manifest)을 함께 써서 다음 실행 때 버전을 추적한다.
_manage_cursor_section() {
    local cursor_meta="${HOME}/.cursor/skills/cursor-skills-meta.json"
    local cursor_ver=""
    [ -f "$cursor_meta" ] && cursor_ver=$(grep '"version"' "$cursor_meta" | sed 's/.*"version": *"\([^"]*\)".*/\1/' | head -1)

    # 스킬 파일 소스 후보 (원격 우선, 없으면 로컬)
    local src="${TEMP_DIR}/skills"
    [ -d "$src" ] || src="skills"
    [ -d "$src" ] || src=""

    echo "" >&2
    print_step "[ Cursor Skills 관리 ]"
    echo "" >&2

    if [ -n "$cursor_ver" ]; then
        local utag=""
        [ -n "$TEMPLATE_VERSION" ] && [ "$cursor_ver" = "$TEMPLATE_VERSION" ] && utag=" ✓ 최신"
        [ -n "$TEMPLATE_VERSION" ] && [ "$cursor_ver" != "$TEMPLATE_VERSION" ] && utag=" → v${TEMPLATE_VERSION}로 업데이트"
        print_info "  현재: skill 설치됨 (v${cursor_ver})${utag}"
    else
        print_info "  Cursor skill 설치 — /analyze, /review 등 (파일 복사 + 버전 manifest 자동 기록)"
    fi

    if [ -z "$src" ]; then
        print_warning "설치할 스킬 소스를 찾지 못했습니다 (다운로드된 템플릿 또는 로컬 skills/ 폴더가 필요합니다)."
        return
    fi
    # 라우터에서 '설치/업데이트' 선택됨 → 추가 질문 없이 global(user)로 바로 복사·최신화.
    _do_cursor_skills_copy "user" "$src"
}

# ── 제거 섹션 (2단계 라우터의 'remove' 동작에서 호출) ──
# 미설치 IDE면 안내만 하고 no-op. 설치돼 있으면 삭제 실행.
_remove_claude_section() {
    local claude_available="$1"
    local installed_scope="$2"
    echo "" >&2
    print_step "[ Claude Code 플러그인 제거 ]"
    if [ "$claude_available" != true ] || [ -z "$installed_scope" ]; then
        print_info "  설치된 Claude Code 플러그인이 없어 건너뜁니다"
        return
    fi
    print_info "  제거할 대상: cassiiopeia@cassiiopeia-marketplace (scope: ${installed_scope})"
    if claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null; then
        print_success "플러그인 uninstall 완료"
        _remove_claude_plugin_data
    else
        print_warning "삭제 실패. 수동으로 실행해주세요:"
        echo "    claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope ${installed_scope}" >&2
    fi
}

_remove_cursor_section() {
    echo "" >&2
    print_step "[ Cursor Skills 제거 ]"
    # global(user) 한 곳만 관리하므로 ~/.cursor/skills/만 확인·삭제한다.
    local cursor_dir="${HOME}/.cursor/skills"
    if [ ! -f "$cursor_dir/cursor-skills-meta.json" ]; then
        print_info "  설치된 Cursor Skills가 없어 건너뜁니다"
        return
    fi
    if rm -rf "$cursor_dir" 2>/dev/null; then
        print_success "Cursor Skills 제거 완료 (${cursor_dir}/)"
    else
        print_warning "Cursor Skills 제거 실패 — 수동 삭제: rm -rf ${cursor_dir}"
    fi
}

_remove_gemini_section() {
    echo "" >&2
    print_step "[ Gemini CLI Extension 제거 ]"
    if ! command -v gemini &> /dev/null; then
        print_info "  gemini CLI 미감지 — 건너뜁니다"
        return
    fi
    if gemini extensions uninstall cassiiopeia 2>/dev/null; then
        print_success "Gemini CLI extension 제거 완료"
    else
        print_info "  제거할 Gemini extension이 없거나 실패 — 수동: gemini extensions uninstall cassiiopeia"
    fi
}

_remove_codex_section() {
    echo "" >&2
    print_step "[ Codex CLI Plugin 제거 ]"
    local codex_target="${HOME}/.agents/skills/cassiiopeia"
    # native fallback 심링크/디렉토리 제거
    if [ -L "$codex_target" ] || [ -d "$codex_target" ]; then
        rm -rf "$codex_target" && print_success "Codex native skills 제거 완료 (${codex_target})"
    else
        print_info "  제거할 Codex skills가 없어 건너뜁니다"
    fi
    command -v codex &> /dev/null && \
        print_info "  marketplace 등록 해제는 수동: codex plugin marketplace remove cassiiopeia"
}

_remove_pi_section() {
    echo "" >&2
    print_step "[ PI 패키지 제거 ]"
    if ! command -v pi &> /dev/null; then
        print_info "  pi CLI 미감지 — 건너뜁니다"
        return
    fi
    if ! _pi_is_installed; then
        print_info "  설치된 PI 패키지가 없어 건너뜁니다"
        return
    fi
    print_info "  pi remove ${PI_PACKAGE_URL}"
    pi remove "$PI_PACKAGE_URL" 2>/dev/null || true
    if _pi_is_installed; then
        print_warning "  제거 후에도 패키지가 남아있습니다 — 'pi list'로 확인하세요."
    else
        print_success "PI 패키지 제거 완료"
    fi
    # package 클론이 사라지면 등록된 harness loader 경로가 허공을 가리킨다 — 같이 해제
    if _pi_harness_enabled; then
        print_info "  Persona Harness 등록도 함께 해제됩니다."
        _pi_harness_remove
    fi
}

# ─── Claude Code 헬퍼 ───────────────────────────────────────────


# 마켓플레이스 등록 + 플러그인 설치
_do_claude_plugin_install() {
    local scope="$1"
    print_step "Claude Code 마켓플레이스 등록 중..."
    if claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE 2>/dev/null; then
        print_success "마켓플레이스 등록 완료"
    else
        print_info "마켓플레이스 이미 등록되어 있거나 등록 생략"
    fi

    print_step "Claude Code 플러그인 설치 중 (scope: ${scope})..."
    if claude plugin install cassiiopeia@cassiiopeia-marketplace --scope "$scope" 2>/dev/null; then
        print_success "Claude Code 플러그인 설치 완료 (cassiiopeia, scope: ${scope})"
    else
        print_warning "플러그인 설치 실패. 수동으로 설치해주세요:"
        echo "    claude plugin install cassiiopeia@cassiiopeia-marketplace --scope ${scope}" >&2
        echo "" >&2
    fi
}

# plugin data(config) 디렉토리 삭제
# Claude Code는 ~/.claude/plugins/data/{id}/ 에 plugin 설정을 저장한다.
_remove_claude_plugin_data() {
    # Claude Code plugin data 경로: ~/.claude/plugins/data/{plugin-id}/
    # plugin id는 "cassiiopeia@cassiiopeia-marketplace" 형태 그대로 사용된다.
    local data_dir="${HOME}/.claude/plugins/data/cassiiopeia@cassiiopeia-marketplace"

    if [ -d "$data_dir" ]; then
        rm -rf "$data_dir" 2>/dev/null
        print_success "플러그인 데이터(config) 삭제 완료"
    fi
    # data 디렉토리가 없는 경우는 정상 — 별도 메시지 불필요
}

# ─── Cursor 헬퍼 ────────────────────────────────────────────────

# cursor-skills-meta.json 생성/갱신
# 인자: $1=scope(user|project, 생략 시 project), $2=설치경로(생략 시 .cursor/skills)
_write_cursor_skills_meta() {
    local scope="${1:-user}"
    local dest_dir="${2:-${HOME}/.cursor/skills}"
    local version="${TEMPLATE_VERSION:-unknown}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
    local meta_file="${dest_dir}/cursor-skills-meta.json"

    # 업데이트 시 installedAt 기존 값 보존
    local installed_at="$timestamp"
    if [ -f "$meta_file" ]; then
        local existing
        existing=$(grep '"installedAt"' "$meta_file" | sed 's/.*"installedAt": *"\([^"]*\)".*/\1/')
        [ -n "$existing" ] && installed_at="$existing"
    fi

    mkdir -p "$dest_dir"
    cat > "$meta_file" <<EOF
{
  "name": "cassiiopeia",
  "version": "${version}",
  "scope": "${scope}",
  "source": "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE",
  "installPath": "${dest_dir}",
  "installedAt": "${installed_at}",
  "lastUpdated": "${timestamp}"
}
EOF
}


# Cursor Skills 실제 복사 실행
# 인자: $1=scope(user|project), $2=소스경로, $3=force(선택)
_do_cursor_skills_copy() {
    # global(user) 한 곳에만 설치. 첫 인자는 하위호환용으로 받되 항상 user 경로를 쓴다.
    local src="$2"
    local dest="${HOME}/.cursor/skills"

    print_step "Cursor Skills 복사 중..."
    mkdir -p "$dest"
    if cp -r "$src/"* "$dest/" 2>/dev/null; then
        # 버전 manifest 자동 기록 → 다음 실행 때 설치 버전 추적 가능
        _write_cursor_skills_meta "user" "$dest"
        print_success "Cursor Skills 설치 완료 (${dest}/, v${TEMPLATE_VERSION:-unknown})"
    else
        print_warning "Cursor Skills 복사에 실패했습니다 — 원본 skills/ 폴더를 확인하거나 다시 시도하세요."
    fi
}


# ─── Gemini CLI 헬퍼 ────────────────────────────────────────────

_manage_gemini_extension() {
    echo "" >&2
    print_step "[ Gemini CLI Extension 관리 ]"
    echo "" >&2

    if ! command -v gemini &> /dev/null; then
        print_warning "gemini CLI가 감지되지 않았습니다. 수동 설치 명령:"
        echo "    gemini extensions install https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE" >&2
        return
    fi

    # 라우터에서 '설치/업데이트' 선택됨 → 추가 확인 없이 바로 실행.
    print_step "Gemini CLI extension 업데이트 중..."
    if gemini extensions update cassiiopeia 2>/dev/null; then
        print_success "Gemini CLI extension 업데이트 완료"
        return
    fi

    print_step "Gemini CLI extension 설치 중..."
    if gemini extensions install https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE 2>/dev/null; then
        print_success "Gemini CLI extension 설치 완료"
    else
        print_warning "Gemini CLI extension 관리 중 오류가 발생하여 수동 설치가 필요합니다."
        print_info "도구 환경을 점검하신 후, 아래 명령어를 입력하여 수동으로 확장을 설치해주세요:"
        echo -e "    ${CYAN}gemini extensions install https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE${NC}" >&2
    fi
}

# ─── Codex CLI 헬퍼 ─────────────────────────────────────────────

_manage_codex_skills() {
    echo "" >&2
    print_step "[ Codex CLI Plugin 관리 ]"
    echo "" >&2

    if command -v codex &> /dev/null; then
        # 라우터에서 '설치/업데이트' 선택됨 → 추가 확인 없이 바로 등록/업데이트.
        _do_codex_marketplace_register
        return
    else
        print_warning "codex CLI가 감지되지 않았습니다."
        print_info "설치 후 수동으로 실행하세요: codex plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    fi
}

_do_codex_marketplace_register() {
    print_step "Codex plugin marketplace 등록 중..."
    if codex plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE 2>/dev/null; then
        print_success "Codex marketplace 등록 완료"
    else
        print_info "Codex marketplace가 이미 등록되어 있거나 등록 생략"
    fi

    print_step "Codex plugin marketplace 업데이트 중..."
    if codex plugin marketplace upgrade cassiiopeia 2>/dev/null; then
        print_success "Codex marketplace 등록 완료 (/plugins에서 확인 가능)"
    else
        print_warning "Codex plugin marketplace 관리 중 오류가 발생하여 수동 등록이 필요합니다."
        print_info "아래 명령어를 입력하여 수동으로 플러그인을 등록해주세요:"
        echo -e "    ${CYAN}codex plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE${NC}" >&2
    fi
}

_do_codex_native_skills_fallback() {
    local mode="${1:-interactive}"
    print_step "[ Codex CLI Native Skills fallback 관리 ]"
    echo "" >&2

    local install_dir="${HOME}/.codex/cassiiopeia"
    local skills_dir="${install_dir}/skills"
    local target_dir="${HOME}/.agents/skills"
    local target="${target_dir}/cassiiopeia"

    if [ "$mode" != "auto" ] && [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
        print_info "  설치 경로: ${target}"
        if ! ask_yes_no "Codex native skills fallback을 설치/업데이트할까요?" "Y"; then
            print_info "Codex native skills fallback을 건너뜁니다 (marketplace 등록 방식만 사용)."
            return
        fi
    fi

    if ! command -v git &> /dev/null; then
        print_warning "git이 없어 Codex native skills를 자동 설치할 수 없습니다."
        echo "    git clone https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git ${install_dir}" >&2
        echo "    mkdir -p ${target_dir}" >&2
        echo "    ln -s ${skills_dir} ${target}" >&2
        return
    fi

    if [ -d "${install_dir}/.git" ]; then
        print_step "Codex skills 저장소 업데이트 중..."
        git -C "$install_dir" pull --ff-only 2>/dev/null || print_warning "기존 저장소 업데이트 실패. 수동 확인 필요: ${install_dir}"
    elif [ -e "$install_dir" ]; then
        print_warning "설치 경로가 이미 존재하지만 git 저장소가 아닙니다: ${install_dir}"
        return
    else
        print_step "Codex skills 저장소 clone 중..."
        git clone https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git "$install_dir" 2>/dev/null || {
            print_warning "Codex skills 저장소 clone에 실패했습니다 — 네트워크를 확인하거나 수동으로 git clone 하세요."
            return
        }
    fi

    if [ ! -d "$skills_dir" ]; then
        print_warning "skills 디렉토리를 찾을 수 없습니다: ${skills_dir}"
        return
    fi

    mkdir -p "$target_dir"
    if [ -L "$target" ]; then
        rm -f "$target"
    elif [ -e "$target" ]; then
        print_warning "대상 경로가 이미 존재하고 symlink가 아닙니다: ${target}"
        print_warning "기존 경로를 보존하기 위해 자동 덮어쓰기를 중단합니다."
        return
    fi

    ln -s "$skills_dir" "$target"
    print_success "Codex native skills 설치 완료 (${target} -> ${skills_dir})"
}

# ─── PI 헬퍼 ────────────────────────────────────────────────────
# pi는 native `pi install <git-url>` 사용. raw 다운로드 X.
# 패키지의 skill은 복사되지 않고, settings의 packages에 등록된 패키지 경로를
# pi가 startup마다 직접 스캔한다. 따라서 설치 검증은 폴더 존재가 아니라 'pi list' 출력으로 한다.
PI_PACKAGE_URL="https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"

# 실제로 동작하는 python 경로를 찾는다. Windows의 'python3'는 Microsoft Store
# stub일 수 있어(command -v는 성공하지만 실행 시 Exit 49) 실제 실행으로 걸러낸다.
# 못 찾으면 빈 문자열 출력 + 비-0 반환.
_pi_python() {
    local c pth
    for c in python3 python py; do
        pth=$(command -v "$c" 2>/dev/null) || continue
        if "$pth" -c "import sys; sys.exit(0)" 2>/dev/null; then
            echo "$pth"
            return 0
        fi
    done
    return 1
}

# pi 패키지가 설치돼 있는지: 'pi list' 출력에 우리 레포가 잡히면 true.
# pi.ps1/pi는 일부 출력을 stderr로 보내므로 2>&1로 합쳐서 본다.
_pi_is_installed() {
    command -v pi &> /dev/null || return 1
    local out
    out=$(pi list 2>&1 || true)
    case "$out" in
        *SUH-DEVOPS-TEMPLATE*|*cassiiopeia*) return 0 ;;
        *) return 1 ;;
    esac
}

# pi 클론 경로(harness loader가 사는 곳). pi 표준 클론 위치: ~/.pi/agent/git/<host>/<owner>/<repo>
_pi_clone_dir() {
    echo "${HOME}/.pi/agent/git/github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
}
_pi_harness_loader_path() {
    echo "$(_pi_clone_dir)/harness/harness-loader.ts"
}
_pi_settings_path() {
    echo "${HOME}/.pi/agent/settings.json"
}

# settings.json의 extensions 배열에 harness loader가 등록돼 있는가
_pi_harness_enabled() {
    local settings loader py
    settings="$(_pi_settings_path)"
    loader="$(_pi_harness_loader_path)"
    [ -f "$settings" ] || return 1
    py=$(_pi_python) || return 1
    PI_SETTINGS="$settings" PI_LOADER="$loader" "$py" - <<'PYEOF'
import json, os, sys
try:
    with open(os.environ["PI_SETTINGS"], encoding="utf-8") as f:
        s = json.load(f)
    exts = s.get("extensions") or []
    sys.exit(0 if os.environ["PI_LOADER"] in exts else 1)
except Exception:
    sys.exit(1)
PYEOF
}

# extensions 배열에 harness loader 추가 (중복 방지). 성공 0.
_pi_harness_add() {
    local settings loader py
    settings="$(_pi_settings_path)"
    loader="$(_pi_harness_loader_path)"
    if [ ! -f "$settings" ]; then
        print_warning "  PI settings.json이 없습니다 — PI를 한 번 실행한 뒤 다시 시도하세요."
        return 1
    fi
    if [ ! -f "$loader" ]; then
        print_warning "  harness loader가 없습니다: ${loader}"
        print_warning "  먼저 PI 패키지를 설치/업데이트하세요."
        return 1
    fi
    py=$(_pi_python) || {
        print_warning "  python을 찾을 수 없어 harness 등록을 건너뜁니다."
        return 1
    }
    PI_SETTINGS="$settings" PI_LOADER="$loader" "$py" - <<'PYEOF'
import json, os, sys
p = os.environ["PI_SETTINGS"]; loader = os.environ["PI_LOADER"]
try:
    with open(p, encoding="utf-8") as f:
        s = json.load(f)
except Exception:
    s = {}
exts = [e for e in (s.get("extensions") or []) if e]
if loader not in exts:
    exts.append(loader)
s["extensions"] = exts
with open(p, "w", encoding="utf-8") as f:
    json.dump(s, f, ensure_ascii=False, indent=2)
sys.exit(0)
PYEOF
}

# extensions 배열에서 harness loader 제거. 성공 0.
_pi_harness_remove() {
    local settings loader py
    settings="$(_pi_settings_path)"
    loader="$(_pi_harness_loader_path)"
    [ -f "$settings" ] || return 0
    py=$(_pi_python) || return 1
    PI_SETTINGS="$settings" PI_LOADER="$loader" "$py" - <<'PYEOF'
import json, os, sys
p = os.environ["PI_SETTINGS"]; loader = os.environ["PI_LOADER"]
try:
    with open(p, encoding="utf-8") as f:
        s = json.load(f)
except Exception:
    sys.exit(0)
if "extensions" in s:
    s["extensions"] = [e for e in (s.get("extensions") or []) if e and e != loader]
    with open(p, "w", encoding="utf-8") as f:
        json.dump(s, f, ensure_ascii=False, indent=2)
sys.exit(0)
PYEOF
    print_success "  Persona Harness 해제 완료 — PI 재시작 후 적용됩니다."
}

# Persona Harness 설치 제안 (PI 설치/업데이트 직후 호출).
# 이미 활성화돼 있으면 그대로 두고, 꺼져 있을 때만 켤지 묻는다.
# (해제는 PI 제거 흐름 _remove_pi_section에서 함께 처리하므로 여기선 켜기만 다룬다.)
# 비TTY/FORCE면 자동 스킵.
_pi_harness_offer() {
    # 이미 활성화돼 있으면 설치 흐름에서 더 묻지 않는다.
    if _pi_harness_enabled; then
        print_info "  Persona Harness: 이미 활성화됨 (유지)"
        return
    fi
    if [ ! -f "$(_pi_harness_loader_path)" ]; then
        print_info "  harness loader가 아직 없어 건너뜁니다 (PI 패키지 설치 후 재시도)."
        return
    fi
    # 비대화형이면 묻지 않고 skill만 사용 (보수적 기본값).
    if [ "$FORCE_MODE" = true ] || [ "$TTY_AVAILABLE" != true ]; then
        print_info "  Persona Harness: 비활성화 (비대화형 — skill만 사용)"
        return
    fi

    print_step "(PI 전용) Persona Harness 활성화"
    _pi_harness_print_desc
    print_info "  나중에 켜고/끄려면 [설치/업데이트] 또는 [제거] 메뉴의 'PI Persona Harness' 항목을 쓰세요."

    if ask_yes_no "Persona Harness를 활성화할까요?" "N"; then
        if _pi_harness_add; then
            print_success "  Persona Harness 활성화 완료 — PI 재시작 후 적용됩니다."
        fi
    else
        print_info "  → 건너뜁니다 (skill만 사용, harness는 비활성)"
    fi
}

# harness 개념 설명 출력 (토글/단독 메뉴에서 재사용)
_pi_harness_print_desc() {
    print_info "  Persona Harness는 PI가 대화를 시작할 때마다 '전문가 페르소나'와 'SDLC 워크플로우'를"
    print_info "  시스템 프롬프트에 자동 주입하는 기능입니다."
    print_info "  • 페르소나(PERSONA): 아키텍트·개발자·리뷰어 등 전문가 역할을 AI에 부여해 답변 품질을 끌어올림"
    print_info "  • 워크플로우(WORKFLOW): 요구분석→설계→구현→검증 단계를 따르도록 행동 지침을 부여"
    print_info "  skill과는 독립적으로 동작합니다 (skill은 그대로 두고 harness만 켜고/끌 수 있습니다)."
}

# [설치/업데이트] 메뉴에서 'PI Persona Harness' 단독 선택 시 — 현재 상태 토글.
# skill은 건드리지 않고 harness 등록만 켜거나 끈다.
_pi_harness_toggle() {
    echo "" >&2
    print_step "[ PI Persona Harness 관리 ]"
    if ! command -v pi &> /dev/null; then
        print_warning "  pi CLI 미감지 — 건너뜁니다"
        return
    fi
    if [ ! -f "$(_pi_harness_loader_path)" ]; then
        print_warning "  harness loader가 없습니다 — 먼저 [설치/업데이트]에서 PI를 설치하세요."
        return
    fi
    _pi_harness_print_desc
    if _pi_harness_enabled; then
        print_info "  현재 상태: 활성화"
        if ask_yes_no "Persona Harness를 비활성화할까요? (PI skill은 유지됩니다)" "N"; then
            _pi_harness_remove
        else
            print_info "  → 활성화 상태 유지"
        fi
    else
        print_info "  현재 상태: 비활성화"
        if ask_yes_no "Persona Harness를 활성화할까요?" "N"; then
            if _pi_harness_add; then
                print_success "  Persona Harness 활성화 완료 — PI 재시작 후 적용됩니다."
            fi
        else
            print_info "  → 비활성화 상태를 유지합니다 (skill만 사용)"
        fi
    fi
}

# [제거] 메뉴에서 'PI Persona Harness' 단독 선택 시 — harness만 해제, PI skill은 보존.
_pi_harness_remove_only() {
    echo "" >&2
    print_step "[ PI Persona Harness 해제 ]"
    if ! _pi_harness_enabled; then
        print_info "  Persona Harness가 활성화돼 있지 않아 건너뜁니다"
        return
    fi
    print_info "  PI skill은 그대로 두고 harness 등록만 해제합니다."
    _pi_harness_remove
}

_manage_pi_section() {
    echo "" >&2
    print_step "[ PI 패키지 관리 ]"
    echo "" >&2

    if ! command -v pi &> /dev/null; then
        print_warning "pi CLI가 감지되지 않았습니다. 설치 후 수동으로 실행하세요:"
        echo "    pi install ${PI_PACKAGE_URL}" >&2
        return
    fi

    # 라우터에서 '설치/업데이트' 선택됨 → 추가 확인 없이 바로 실행.
    if _pi_is_installed; then
        print_step "PI 패키지 업데이트 중..."
        pi update "$PI_PACKAGE_URL" 2>/dev/null || pi install "$PI_PACKAGE_URL" 2>/dev/null || true
    else
        print_step "PI 패키지 설치 중..."
        pi install "$PI_PACKAGE_URL" 2>/dev/null || true
    fi

    if _pi_is_installed; then
        print_success "PI 패키지 설치 / 업데이트 완료"
        print_info "  → 'pi' 재실행 후 'pi list' 로 확인"
        print_info "  → 채팅창에서 /suh-analyze, /suh-review 등으로 호출하세요."
        # skill 설치와 별개로, harness는 opt-in으로만 켠다.
        _pi_harness_offer
    else
        print_warning "PI 설치/업데이트 실패 — 수동으로 실행해주세요:"
        echo "    pi install ${PI_PACKAGE_URL}" >&2
    fi
}

# 완료 요약
print_summary() {
    echo "" >&2
    print_separator_line
    echo "" >&2
    echo "✨ SUH-DEVOPS-TEMPLATE Setup Complete!" >&2
    echo "" >&2
    print_separator_line
    echo "" >&2
    echo "통합된 기능:" >&2
    
    case $MODE in
        full)
            echo "  ✅ 버전 관리 시스템 (version.yml)" >&2
            echo "  ✅ README.md 자동 버전 업데이트" >&2
            echo "  ✅ GitHub Actions 워크플로우" >&2
            if [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
                echo "  ✅ 유틸리티 모듈 ($UTIL_MODULES_COPIED 개)" >&2
            fi
            echo "  ✅ 이슈/PR/Discussion 템플릿" >&2
            echo "  ✅ CodeRabbit AI 리뷰 설정" >&2
            echo "  ✅ .gitignore 필수 항목" >&2
            echo "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)" >&2
            ;;
        version)
            echo "  ✅ 버전 관리 시스템 (version.yml)" >&2
            echo "  ✅ README.md 자동 버전 업데이트" >&2
            echo "  ✅ .gitignore 필수 항목" >&2
            echo "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)" >&2
            ;;
        workflows)
            echo "  ✅ GitHub Actions 워크플로우" >&2
            if [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
                echo "  ✅ 유틸리티 모듈 ($UTIL_MODULES_COPIED 개)" >&2
            fi
            echo "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)" >&2
            ;;
        issues)
            echo "  ✅ 이슈/PR/Discussion 템플릿" >&2
            ;;
        skills)
            echo "  ✅ Agent Skill 설치 (Claude, Cursor, Gemini, Codex, PI)" >&2
            ;;
    esac

    # skills 모드: 파일/워크플로우 추가 없으므로 간결하게 종료
    if [ "$MODE" = "skills" ]; then
        echo "" >&2
        echo "  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE" >&2
        echo "" >&2
        print_separator_line
        echo "" >&2
        return
    fi

    local _summary_types
    local IFS=','
    _summary_types="${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
    unset IFS

    echo "" >&2
    echo "추가된 파일:" >&2
    echo "  📄 version.yml (버전: $VERSION, 타입: $_summary_types)" >&2
    echo "  📝 README.md (버전 섹션 추가)" >&2
    echo "" >&2
    echo "추가된 워크플로우:" >&2
    
    # 워크플로우 분류 저장용 배열
    local common_workflows=()
    local type_workflows=()
    local existing_workflows=()
    
    # 실제 복사된 워크플로우와 기존 파일 구분
    if [ -d "$WORKFLOWS_DIR" ]; then
        for wf in "$WORKFLOWS_DIR/$WORKFLOW_PREFIX"-*.{yaml,yml}; do
            [ -e "$wf" ] || continue
            local filename=$(basename "$wf")
            
            # TEMPLATE-INITIALIZER는 기존 파일로 분류
            if [[ "$filename" == "$WORKFLOW_TEMPLATE_INIT" ]]; then
                existing_workflows+=("$filename")
            elif [[ "$filename" =~ ^${WORKFLOW_COMMON_PREFIX}- ]]; then
                common_workflows+=("$filename")
            else
                # PROJECT_TYPES 배열 순회 — 어떤 타입 prefix와 매칭되는지 검사
                local _check_types=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
                local _ct
                for _ct in "${_check_types[@]}"; do
                    local _prefix="^${WORKFLOW_PREFIX}-$(echo "$_ct" | tr '[:lower:]' '[:upper:]')-"
                    if [[ "$filename" =~ $_prefix ]]; then
                        type_workflows+=("$filename")
                        break
                    fi
                done
            fi
        done
    fi
    
    # 새로 설치된 워크플로우 출력
    if [ ${#common_workflows[@]} -gt 0 ] || [ ${#type_workflows[@]} -gt 0 ]; then
        echo "  📦 새로 설치됨 (${WORKFLOWS_COPIED:-0}개):" >&2
        
        # 공통 워크플로우
        for wf in "${common_workflows[@]}"; do
            echo "     📌 $wf" >&2
        done
        
        # 타입별 워크플로우
        for wf in "${type_workflows[@]}"; do
            echo "     🎯 $wf" >&2
        done
    fi
    
    # 기존 파일 유지됨 표시
    if [ ${#existing_workflows[@]} -gt 0 ]; then
        echo "" >&2
        echo "  🔧 기존 파일 유지됨:" >&2
        for wf in "${existing_workflows[@]}"; do
            echo "     📌 $wf (템플릿 전용)" >&2
        done
    fi
    
    echo "" >&2
    echo "  🔧 .github/scripts/" >&2
    echo "     ├─ version_manager.sh" >&2
    echo "     └─ changelog_manager.py" >&2
    echo "" >&2
    
    # util 모듈 정보 표시 — PROJECT_TYPES 배열 순회
    if [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
        echo "  🧙 유틸리티 모듈:" >&2
        local _ut_types=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
        local _ut
        for _ut in "${_ut_types[@]}"; do
            if [ -d ".github/util/$_ut" ]; then
                for dir in ".github/util/$_ut"/*/; do
                    [ -d "$dir" ] || continue
                    local module_name=$(basename "$dir")
                    echo "     ├─ $module_name ($_ut)" >&2
                done
            fi
        done
        echo "" >&2
    fi

    # 프로젝트 타입별 안내 — 배열에 spring 포함 시
    if _contains_type "spring"; then
        echo "  💡 Spring 프로젝트 추가 설정:" >&2
        echo "     • build.gradle의 버전 정보가 자동 동기화됩니다" >&2
        echo "     • CI/CD 워크플로우에서 GitHub Secrets 설정이 필요합니다" >&2
        echo "     • 자세한 설정 방법: .github/workflows/project-types/spring/README.md" >&2
        echo "" >&2
    fi

    # Flutter util 모듈 안내 — 배열에 flutter 포함 시
    if _contains_type "flutter" && [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
        echo "  💡 Flutter 배포 마법사 사용법:" >&2
        echo "     • iOS TestFlight: .github/util/flutter/ios-testflight-setup-wizard/index.html" >&2
        echo "     • Android Play Store: .github/util/flutter/android-playstore-setup-wizard/index.html" >&2
        echo "     • 브라우저에서 열어 필요한 정보 입력 후 파일 생성" >&2
        echo "" >&2
    fi
    
    echo "  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE" >&2
    echo "  📚 워크플로우 가이드: .github/workflows/project-types/README.md" >&2
    echo "" >&2
    
    # 필수 3가지 작업 안내
    print_separator_line
    echo "" >&2
    echo -e "${YELLOW}⚠️  다음 3가지 작업을 완료해주세요:${NC}" >&2
    echo "" >&2
    echo "  1️⃣  GitHub Personal Access Token 설정" >&2
    echo "     → Repository Settings > Secrets > Actions" >&2
    echo "     → Secret Name: _GITHUB_PAT_TOKEN" >&2
    echo "     → Scopes: repo, workflow" >&2
    echo "" >&2
    echo "  2️⃣  deploy 브랜치 생성" >&2
    echo "     → git checkout -b deploy && git push -u origin deploy" >&2
    echo "" >&2
    echo "  3️⃣  CodeRabbit 활성화" >&2
    echo "     → https://coderabbit.ai 방문하여 저장소 활성화" >&2
    echo "" >&2
    print_separator_line
    echo "" >&2
    echo -e "${CYAN}📖 자세한 설정 방법은 다음 파일을 참고하세요:${NC}" >&2
    echo "   → SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" >&2
    echo "" >&2
}

# 메인 실행
main() {
    # 터미널 상태 감지 (최우선)
    detect_terminal
    
    # stdin 모드 디버그 정보 (개발 시 유용)
    if [ "$STDIN_MODE" = true ]; then
        if [ "$TTY_AVAILABLE" = true ]; then
            print_info "실행 모드: 원격 (stdin), TTY 가용"
        else
            print_info "실행 모드: 원격 (stdin), TTY 불가 (자동화 환경)"
        fi
        echo "" >&2
    fi
    
    # Git 저장소 확인 (경고만 표시)
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_warning "Git 저장소가 아닙니다. 일부 기능이 제한될 수 있습니다."
        echo "" >&2
    fi
    
    # 대화형 모드
    if [ "$MODE" = "interactive" ]; then
        interactive_mode
    fi
    
    # 통합 실행
    execute_integration
}

# 스크립트 실행 (source될 때는 main을 돌리지 않음 — 함수 단위 테스트 가능)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
