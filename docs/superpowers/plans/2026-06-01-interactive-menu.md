# Interactive Menu UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `template_integrator.sh` + `template_integrator.ps1`의 단일 선택 메뉴 6곳을 화살표 키 + 숫자 점프 + Enter 확정 + ESC 취소 방식 인터랙티브 UI로 교체한다. 비TTY 환경에서는 기존 숫자 입력 fallback을 유지한다.

**Architecture:** 두 스크립트 안에 함수 1개씩 내장 (`interactive_menu` / `Invoke-InteractiveMenu`). 외부 의존 0. TTY 감지로 화살표 UI / 숫자 입력 자동 분기. 기존 숫자 입력 코드는 `legacy_numeric_menu` 함수로 분리해 fallback 경로 보존.

**Tech Stack:** Bash 3.2+, PowerShell 5.1+. ANSI escape sequences, `tput`, `[Console]::ReadKey`, `[Console]::SetCursorPosition`.

**Spec:** `docs/superpowers/specs/2026-06-01-interactive-menu-design.md`

---

## File Structure

| 파일 | 역할 | 추가 함수 |
|------|------|----------|
| `template_integrator.sh` | Bash 진입 스크립트 | `interactive_menu`, `legacy_numeric_menu`, `choose_menu` |
| `template_integrator.ps1` | PowerShell 진입 스크립트 | `Invoke-InteractiveMenu`, `Invoke-LegacyNumericMenu`, `Invoke-ChooseMenu` |

기존 메뉴 코드는 5곳(sh) / 6곳(ps1)에서 `choose_menu`/`Invoke-ChooseMenu` 호출로 교체. 기존 `show_project_type_menu`, `handle_project_edit_menu` 등 함수의 메뉴 본체만 교체.

---

## Task 1: Bash — `interactive_menu` 함수 추가 (TTY 모드)

**Files:**
- Modify: `template_integrator.sh` (helper 함수 영역 — `safe_read` 함수 직후 line 230 부근에 신규 함수 삽입)

- [ ] **Step 1: `interactive_menu` 함수 추가**

위치: `template_integrator.sh` line 230 직후 (`safe_read` 함수 끝 다음)

```bash
# 인터랙티브 메뉴 (TTY 전용) — 화살표/숫자/Enter/ESC
# 사용법: selected=$(interactive_menu "prompt" "value1|label1" "value2|label2" ...)
# stdout: 선택된 value
# exit:   0=확정, 1=취소
interactive_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local n=${#options[@]}

    if [ "$n" -eq 0 ]; then
        echo "interactive_menu: 옵션이 없습니다" >&2
        return 1
    fi

    # 색상 활성 여부
    local use_color=true
    if [ -n "${NO_COLOR:-}" ] || [ ! -t 2 ]; then
        use_color=false
    fi

    local C_RESET="" C_CYAN="" C_GREEN="" C_DIM="" C_BOLD=""
    if [ "$use_color" = true ]; then
        C_RESET=$'\033[0m'
        C_CYAN=$'\033[36m'
        C_GREEN=$'\033[32m'
        C_DIM=$'\033[2m'
        C_BOLD=$'\033[1m'
    fi

    # 프롬프트 + 안내 출력 (stderr — stdout은 결과값 전용)
    printf "\n%s (↑↓ 이동, 숫자 점프, Enter 확정, ESC 취소):\n\n" "$prompt" >&2

    local cursor=0

    # Ctrl+C 시 커서 복원
    trap 'printf "\033[?25h" >&2; return 130' INT

    # 커서 숨김
    printf "\033[?25l" >&2

    _interactive_menu_render() {
        local i value label num
        for i in $(seq 0 $((n - 1))); do
            IFS='|' read -r value label <<< "${options[$i]}"
            num=$((i + 1))
            if [ "$i" -eq "$cursor" ]; then
                printf "%s> [•] %d) %s%s    %s%s%s\n" \
                    "$C_CYAN" "$num" "$value" "$C_RESET" \
                    "$C_DIM" "$label" "$C_RESET" >&2
            else
                printf "  [ ] %d) %s    %s%s%s\n" \
                    "$num" "$value" \
                    "$C_DIM" "$label" "$C_RESET" >&2
            fi
        done
    }

    _interactive_menu_clear() {
        # n줄 위로 이동 후 각 줄 지우기
        local i
        for i in $(seq 1 "$n"); do
            printf "\033[1A\033[2K" >&2
        done
    }

    _interactive_menu_render

    local key rest
    while true; do
        IFS= read -rsn1 key < /dev/tty || { printf "\033[?25h" >&2; return 1; }

        if [ "$key" = $'\e' ]; then
            # 화살표 시퀀스 또는 ESC 단독
            IFS= read -rsn2 -t 0.01 rest < /dev/tty 2>/dev/null || rest=""
            case "$rest" in
                '[A') key=UP ;;
                '[B') key=DOWN ;;
                '')   key=ESC ;;
                *)    continue ;;
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
            ""|$'\n')
                # Enter — 확정
                _interactive_menu_clear
                printf "\033[?25h" >&2
                trap - INT
                IFS='|' read -r value _ <<< "${options[$cursor]}"
                echo "$value"
                return 0
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
```

- [ ] **Step 2: 수동 테스트 — 옵션 표시 + 화살표 이동**

Run:
```bash
bash -c 'source ./template_integrator.sh 2>/dev/null; interactive_menu "테스트" "a|첫번째" "b|두번째" "c|세번째"'
```
> Note: source 시 자동 실행 방지를 위해 main 진입 전에 `return 0 2>/dev/null` 가드가 필요할 수 있다. 없으면 별도 테스트 스크립트로 함수만 추출해 실행.

Expected:
- 3개 옵션 표시, 첫 행에 `> [•]`
- ↓ 누르면 두번째로 이동, ↑ 누르면 첫번째로
- `2` 누르면 두번째로 점프
- Enter 누르면 `b` 출력 후 종료
- ESC 누르면 빈 출력, exit 1

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.sh
git commit -m "interactive_menu 함수 추가 (Bash) : feat : 화살표 키 메뉴 컴포넌트"
```

---

## Task 2: Bash — `legacy_numeric_menu` + `choose_menu` 분기 함수 추가

**Files:**
- Modify: `template_integrator.sh` (Task 1에서 추가한 `interactive_menu` 직후)

- [ ] **Step 1: `legacy_numeric_menu` 함수 추가**

`interactive_menu` 함수 종료 직후 추가:

```bash
# 비TTY fallback — 기존 숫자 입력 방식
# 사용법: selected=$(legacy_numeric_menu "prompt" "value1|label1" "value2|label2" ...)
legacy_numeric_menu() {
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

    local choice
    while true; do
        if [ -t 0 ]; then
            printf "선택 (1-%d): " "$n" >&2
            IFS= read -r choice
        elif [ -c /dev/tty ]; then
            printf "선택 (1-%d): " "$n" >&2
            IFS= read -r choice < /dev/tty
        else
            # 완전 비TTY — 첫 옵션 자동 선택
            IFS='|' read -r value _ <<< "${options[0]}"
            echo "$value"
            return 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ]; then
            IFS='|' read -r value _ <<< "${options[$((choice - 1))]}"
            echo "$value"
            return 0
        else
            printf "잘못된 입력입니다. 1-%d 사이의 숫자를 입력해주세요.\n" "$n" >&2
        fi
    done
}
```

- [ ] **Step 2: `choose_menu` 분기 함수 추가**

`legacy_numeric_menu` 직후 추가:

```bash
# 통합 entry point — TTY면 interactive_menu, 아니면 legacy_numeric_menu
choose_menu() {
    if [ "$TTY_AVAILABLE" = true ] && [ -t 2 ]; then
        interactive_menu "$@"
    else
        legacy_numeric_menu "$@"
    fi
}
```

- [ ] **Step 3: 수동 테스트 — 비TTY fallback**

Run:
```bash
echo "2" | bash -c 'source ./template_integrator.sh ...; legacy_numeric_menu "테스트" "a|첫째" "b|둘째"'
```

Expected: `b` 출력

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.sh
git commit -m "legacy_numeric_menu + choose_menu 분기 함수 추가 : feat : 비TTY fallback 분리"
```

---

## Task 3: Bash — 프로젝트 타입 선택 메뉴 교체

**Files:**
- Modify: `template_integrator.sh:653-698` (`show_project_type_menu` 함수 본체)

- [ ] **Step 1: `show_project_type_menu` 본체 교체**

기존 코드 (L653-698):
```bash
show_project_type_menu() {
    print_to_user ""
    print_to_user "프로젝트 타입을 선택하세요:"
    print_to_user ""
    print_to_user "  1) spring            - Spring Boot 백엔드"
    # ... (기존 8개 옵션 + 입력 루프)
}
```

전체 교체:
```bash
show_project_type_menu() {
    local selected
    selected=$(choose_menu "프로젝트 타입을 선택하세요" \
        "spring|Spring Boot 백엔드" \
        "flutter|Flutter 모바일 앱" \
        "react|React 웹 앱" \
        "react-native|React Native 모바일 앱" \
        "react-native-expo|React Native Expo 앱" \
        "node|Node.js 프로젝트" \
        "python|Python 프로젝트" \
        "basic|기타 프로젝트")

    if [ -z "$selected" ]; then
        # 취소 — 기존 값 유지
        print_error "프로젝트 타입 선택이 취소되었습니다. 기존 값을 유지합니다."
        echo "$PROJECT_TYPE"
        return 1
    fi

    echo "$selected"
}
```

- [ ] **Step 2: 수동 테스트**

Run: `bash template_integrator.sh` (대화형 실행)

Expected:
- "프로젝트 자동 감지 실패 시" 또는 "Edit → Project Type" 진입 시 화살표 UI 표시
- 8개 옵션 표시, 화살표 / 숫자 / Enter 동작 확인
- ESC 시 기존 값 유지 메시지

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.sh
git commit -m "프로젝트 타입 메뉴 인터랙티브 UI 적용 : feat : show_project_type_menu 교체"
```

---

## Task 4: Bash — 통합 모드 선택 메뉴 교체

**Files:**
- Modify: `template_integrator.sh:2139-2185` (메인 함수의 모드 선택 블록)

- [ ] **Step 1: 모드 선택 블록 교체**

기존 코드 (L2139-2185, `print_question_header "🚀" ...` 이후):
```bash
print_to_user "  1) 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)"
print_to_user "  2) 버전 관리 시스템만"
# ... (입력 루프)
```

전체 교체:
```bash
local _mode_selected
_mode_selected=$(choose_menu "어떤 기능을 통합하시겠습니까?" \
    "full|전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)" \
    "version|버전 관리 시스템만" \
    "workflows|GitHub Actions 워크플로우만" \
    "issues|이슈/PR 템플릿만" \
    "skills|Agent Skill 설치 (Claude, Cursor, Gemini, Codex)" \
    "cancel|취소")

if [ -z "$_mode_selected" ] || [ "$_mode_selected" = "cancel" ]; then
    print_info "취소되었습니다"
    exit 0
fi

MODE="$_mode_selected"
```

- [ ] **Step 2: 수동 테스트**

Run: `bash template_integrator.sh`

Expected: 모드 선택 화면이 화살표 UI로 표시, 각 옵션 정상 매핑

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.sh
git commit -m "통합 모드 메뉴 인터랙티브 UI 적용 : feat : 메인 모드 선택 교체"
```

---

## Task 5: Bash — 버전 정보 편집 메뉴 교체

**Files:**
- Modify: `template_integrator.sh:760-846` (`handle_project_edit_menu` 함수의 메뉴 부분)

- [ ] **Step 1: 메뉴 선택 부분 교체**

기존 코드 (L760-840 범위, `print_to_user "  1) Project Type"` ~ `case $edit_choice in ... esac`):

전체를 다음으로 교체 (함수 본체):
```bash
handle_project_edit_menu() {
    local edit_choice
    edit_choice=$(choose_menu "어떤 항목을 수정하시겠습니까?" \
        "type|Project Type" \
        "version|Version" \
        "branch|Default Branch (기본 브랜치)" \
        "done|모두 맞음, 계속")

    if [ -z "$edit_choice" ]; then
        # 취소 시 main 루프로 돌아감
        return 1
    fi

    case "$edit_choice" in
        type)
            PROJECT_TYPE=$(show_project_type_menu)
            print_success "Project Type이 '$PROJECT_TYPE'(으)로 변경되었습니다"
            print_to_user ""
            ;;
        version)
            local new_version
            print_to_user ""
            if safe_read "새 버전을 입력하세요 (예: 1.0.0): " new_version ""; then
                print_to_user ""
                if [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    VERSION="$new_version"
                    print_success "Version이 '$VERSION'(으)로 변경되었습니다"
                else
                    print_error "잘못된 버전 형식입니다. 기존 값을 유지합니다. (올바른 형식: x.y.z)"
                fi
                print_to_user ""
            else
                print_warning "입력을 읽을 수 없습니다. 기존 값을 유지합니다."
                print_to_user ""
            fi
            ;;
        branch)
            local new_branch
            print_to_user ""
            print_to_user "💡 이 설정은 GitHub Actions 워크플로우에서 사용할 기본 브랜치입니다."
            print_to_user ""
            if safe_read "기본 브랜치 이름을 입력하세요 (예: main, develop): " new_branch ""; then
                print_to_user ""
                if [ -n "$new_branch" ]; then
                    DETECTED_BRANCH="$new_branch"
                    print_success "Default Branch가 '$DETECTED_BRANCH'(으)로 변경되었습니다"
                else
                    print_error "브랜치 이름이 비어있습니다. 기존 값을 유지합니다."
                fi
                print_to_user ""
            else
                print_warning "입력을 읽을 수 없습니다. 기존 값을 유지합니다."
                print_to_user ""
            fi
            ;;
        done)
            print_success "프로젝트 정보 확인 완료"
            print_to_user ""
            return 0
            ;;
    esac
}
```

- [ ] **Step 2: 수동 테스트**

Run: `bash template_integrator.sh` → 프로젝트 확인 화면에서 `e` 입력

Expected: 화살표 UI로 4개 항목 표시. 각 항목 선택 시 기존 동작 유지.

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.sh
git commit -m "프로젝트 편집 메뉴 인터랙티브 UI 적용 : feat : handle_project_edit_menu 교체"
```

---

## Task 6: Bash — 플러그인 cassiiopeia 관리 메뉴 교체

**Files:**
- Modify: `template_integrator.sh:2426-2488` (cassiiopeia 설치된 경우 분기)

- [ ] **Step 1: 메뉴 입력 블록 교체**

기존 코드 (L2426-2441, `print_to_user "  1 - ${update_label}"` ~ `case "$choice" in`):

다음으로 교체:
```bash
if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
    local choice
    choice=$(choose_menu "Claude Code 플러그인 (cassiiopeia)" \
        "update|${update_label}" \
        "reinstall|재설치 (scope 변경)" \
        "delete|삭제 (cassiiopeia@cassiiopeia-marketplace, scope: ${installed_scope})" \
        "skip|건너뛰기")

    case "$choice" in
        update)
            # (기존 1) 블록 본체 그대로)
            ...
            ;;
        reinstall)
            # (기존 2) 블록 본체 그대로)
            ...
            ;;
        delete)
            # (기존 3) 블록 본체 그대로)
            ...
            ;;
        *)
            print_info "Claude Code 플러그인 변경 없이 건너뜁니다"
            ;;
    esac
```

> 본 step에서는 case 분기명만 `1` → `update` 등으로 변경. 각 블록의 명령(claude plugin update/uninstall 등)은 기존 코드 그대로 유지한다. 변경 범위는 L2426-2488 안에서만.

- [ ] **Step 2: 수동 테스트**

Run: cassiiopeia 플러그인이 설치된 상태에서 `bash template_integrator.sh`

Expected: 화살표 UI로 4개 옵션 표시, 각 옵션 동작 확인

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.sh
git commit -m "cassiiopeia 플러그인 메뉴 인터랙티브 UI 적용 : feat : 플러그인 관리 UX 개선"
```

---

## Task 7: Bash — 플러그인 cursor 관리 메뉴 교체

**Files:**
- Modify: `template_integrator.sh:2575-2620` (cursor 설치된 경우 분기)

- [ ] **Step 1: 메뉴 입력 블록 교체**

기존 코드 (L2575-2590):
```bash
if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
    print_to_user "어떻게 하시겠습니까?"
    print_to_user "  1 - 업데이트 (기존 scope 유지)"
    print_to_user "  2 - 신규 설치 (다른 scope에 추가)"
    print_to_user "  3 - 삭제"
    print_to_user "  4 - 건너뛰기"
    # ... read cursor_choice
    case "$cursor_choice" in
        1) ... ;;
```

다음으로 교체:
```bash
if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
    local cursor_choice
    cursor_choice=$(choose_menu "Cursor Skills 관리" \
        "update|업데이트 (기존 scope 유지)" \
        "install|신규 설치 (다른 scope에 추가)" \
        "delete|삭제" \
        "skip|건너뛰기")

    case "$cursor_choice" in
        update)
            # (기존 1) 블록 본체 그대로)
            ...
            ;;
        install)
            # (기존 2) 블록 본체 그대로)
            ...
            ;;
        delete)
            # (기존 3) 블록 본체 그대로)
            ...
            ;;
        *)
            print_info "Cursor Skills 변경 없이 건너뜁니다"
            ;;
    esac
```

- [ ] **Step 2: 수동 테스트**

Expected: 화살표 UI 4개 옵션 표시, 각 옵션 동작 확인

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.sh
git commit -m "cursor skills 메뉴 인터랙티브 UI 적용 : feat : Cursor 관리 UX 개선"
```

---

## Task 8: PowerShell — `Invoke-InteractiveMenu` 함수 추가

**Files:**
- Modify: `template_integrator.ps1` (helper 영역 — `Read-Host` 사용 함수 정의 인근 L240 부근)

- [ ] **Step 1: `Invoke-InteractiveMenu` 함수 추가**

위치: `template_integrator.ps1` L245 부근 (`Read-Host` 헬퍼 정의 직후 또는 그 인근 빈 줄)

```powershell
function Invoke-InteractiveMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [int]$DefaultIndex = 0
    )

    $n = $Options.Count
    if ($n -eq 0) {
        [Console]::Error.WriteLine("Invoke-InteractiveMenu: 옵션이 없습니다")
        return $null
    }

    $useColor = -not $env:NO_COLOR

    $cursor = $DefaultIndex
    if ($cursor -lt 0 -or $cursor -ge $n) { $cursor = 0 }

    Write-Host ""
    Write-Host ("{0} (↑↓ 이동, 숫자 점프, Enter 확정, ESC 취소):" -f $Prompt)
    Write-Host ""

    $startTop = [Console]::CursorTop

    function _Render {
        [Console]::SetCursorPosition(0, $startTop)
        for ($i = 0; $i -lt $n; $i++) {
            $opt = $Options[$i]
            $num = $i + 1
            $line = ""
            if ($i -eq $cursor) {
                $line = "> [•] {0}) {1}    {2}" -f $num, $opt.Value, $opt.Label
                if ($useColor) {
                    Write-Host $line -ForegroundColor Cyan
                } else {
                    Write-Host $line
                }
            } else {
                $line = "  [ ] {0}) {1}    {2}" -f $num, $opt.Value, $opt.Label
                Write-Host $line
            }
            # 줄 끝까지 지우기 위해 추가 공백
            # (Write-Host가 자동 줄바꿈하므로 별도 padding 불필요)
        }
    }

    # 커서 숨김
    [Console]::CursorVisible = $false

    try {
        _Render
        while ($true) {
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow' {
                    $cursor--
                    if ($cursor -lt 0) { $cursor = $n - 1 }
                }
                'DownArrow' {
                    $cursor++
                    if ($cursor -ge $n) { $cursor = 0 }
                }
                'K' {
                    $cursor--
                    if ($cursor -lt 0) { $cursor = $n - 1 }
                }
                'J' {
                    $cursor++
                    if ($cursor -ge $n) { $cursor = 0 }
                }
                'Enter' {
                    [Console]::CursorVisible = $true
                    [Console]::SetCursorPosition(0, $startTop + $n)
                    return $Options[$cursor].Value
                }
                'Escape' {
                    [Console]::CursorVisible = $true
                    [Console]::SetCursorPosition(0, $startTop + $n)
                    return $null
                }
                'Q' {
                    [Console]::CursorVisible = $true
                    [Console]::SetCursorPosition(0, $startTop + $n)
                    return $null
                }
                default {
                    # 숫자 점프
                    $ch = $key.KeyChar
                    if ($ch -ge '1' -and $ch -le '9') {
                        $jump = [int]([string]$ch) - 1
                        if ($jump -lt $n) { $cursor = $jump }
                    }
                }
            }
            _Render
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}
```

- [ ] **Step 2: 수동 테스트**

Run (PowerShell 5.1 + 7 양쪽):
```powershell
. .\template_integrator.ps1  # source 시 main 실행 가드 필요 — 없으면 별도 .ps1 파일에 함수만 복사해 테스트
$result = Invoke-InteractiveMenu -Prompt "테스트" -Options @(
    @{Value='a'; Label='첫째'},
    @{Value='b'; Label='둘째'},
    @{Value='c'; Label='셋째'}
)
$result
```

Expected:
- 3개 옵션 표시, 첫 행에 `>` + cyan
- ↑↓ 이동, 숫자 점프 동작
- Enter 시 선택된 Value 반환
- ESC 시 `$null` 반환

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.ps1
git commit -m "Invoke-InteractiveMenu 함수 추가 (PowerShell) : feat : 화살표 키 메뉴 컴포넌트"
```

---

## Task 9: PowerShell — `Invoke-LegacyNumericMenu` + `Invoke-ChooseMenu` 분기 함수 추가

**Files:**
- Modify: `template_integrator.ps1` (Task 8 함수 직후)

- [ ] **Step 1: `Invoke-LegacyNumericMenu` 추가**

```powershell
function Invoke-LegacyNumericMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options
    )

    $n = $Options.Count
    if ($n -eq 0) { return $null }

    Write-Host ""
    Write-Host $Prompt
    Write-Host ""
    for ($i = 0; $i -lt $n; $i++) {
        $opt = $Options[$i]
        Write-Host ("  {0}) {1,-20} - {2}" -f ($i + 1), $opt.Value, $opt.Label)
    }
    Write-Host ""

    while ($true) {
        $choice = Read-Host ("선택 (1-{0})" -f $n)
        if ($choice -match '^\d+$') {
            $c = [int]$choice
            if ($c -ge 1 -and $c -le $n) {
                return $Options[$c - 1].Value
            }
        }
        Write-Host ("잘못된 입력입니다. 1-{0} 사이의 숫자를 입력해주세요." -f $n)
    }
}
```

- [ ] **Step 2: `Invoke-ChooseMenu` 분기 함수 추가**

```powershell
function Invoke-ChooseMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [int]$DefaultIndex = 0
    )

    $isTty = (-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected)
    if ($isTty) {
        return Invoke-InteractiveMenu -Prompt $Prompt -Options $Options -DefaultIndex $DefaultIndex
    } else {
        return Invoke-LegacyNumericMenu -Prompt $Prompt -Options $Options
    }
}
```

- [ ] **Step 3: 수동 테스트 — 비TTY fallback**

Run:
```powershell
"2" | powershell -Command {
    . .\template_integrator.ps1
    Invoke-LegacyNumericMenu -Prompt "테스트" -Options @(
        @{Value='a'; Label='첫째'},
        @{Value='b'; Label='둘째'}
    )
}
```

Expected: `b` 반환

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.ps1
git commit -m "Invoke-LegacyNumericMenu + ChooseMenu 분기 함수 추가 : feat : PowerShell 비TTY fallback"
```

---

## Task 10: PowerShell — 프로젝트 타입 선택 메뉴 교체

**Files:**
- Modify: `template_integrator.ps1` (프로젝트 타입 선택 블록 — `switch $choice` L574 부근)

- [ ] **Step 1: 기존 블록 위치 확인**

Run: `Grep "프로젝트 타입" template_integrator.ps1`

기존 블록은 L555-L600 부근 `do { Read-Host "선택 (1-8)" ... } while` 형태.

- [ ] **Step 2: 블록 교체**

기존 코드를 다음으로 교체:
```powershell
$selected = Invoke-ChooseMenu -Prompt "프로젝트 타입을 선택하세요" -Options @(
    @{Value='spring';            Label='Spring Boot 백엔드'},
    @{Value='flutter';           Label='Flutter 모바일 앱'},
    @{Value='react';             Label='React 웹 앱'},
    @{Value='react-native';      Label='React Native 모바일 앱'},
    @{Value='react-native-expo'; Label='React Native Expo 앱'},
    @{Value='node';              Label='Node.js 프로젝트'},
    @{Value='python';            Label='Python 프로젝트'},
    @{Value='basic';             Label='기타 프로젝트'}
)

if (-not $selected) {
    Write-Host "프로젝트 타입 선택이 취소되었습니다. 기존 값을 유지합니다."
    return $script:ProjectType
}

return $selected
```

> 기존 함수가 값을 반환하는 형태이면 `return`, 변수에 할당하는 형태이면 `$ProjectType = $selected` 식으로 호출 컨텍스트에 맞춰 조정.

- [ ] **Step 3: 수동 테스트**

Run: `powershell -File .\template_integrator.ps1` (대화형 실행)

Expected: 프로젝트 타입 선택 화면에서 화살표 UI 동작

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.ps1
git commit -m "프로젝트 타입 메뉴 인터랙티브 UI 적용 (PowerShell) : feat : 타입 선택 교체"
```

---

## Task 11: PowerShell — 통합 모드 선택 메뉴 교체

**Files:**
- Modify: `template_integrator.ps1` (L2095 부근 `switch $choice`)

- [ ] **Step 1: 기존 블록 위치 확인**

Run: `Grep "전체 통합" template_integrator.ps1`

- [ ] **Step 2: 블록 교체**

기존 `do { ... Read-Host "선택 (1-6)" ... } while (...) switch ($choice) { 1 {$Mode="full"} ... }` 블록을 다음으로 교체:

```powershell
$_modeSelected = Invoke-ChooseMenu -Prompt "어떤 기능을 통합하시겠습니까?" -Options @(
    @{Value='full';      Label='전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)'},
    @{Value='version';   Label='버전 관리 시스템만'},
    @{Value='workflows'; Label='GitHub Actions 워크플로우만'},
    @{Value='issues';    Label='이슈/PR 템플릿만'},
    @{Value='skills';    Label='Agent Skill 설치 (Claude, Cursor, Gemini, Codex)'},
    @{Value='cancel';    Label='취소'}
)

if (-not $_modeSelected -or $_modeSelected -eq 'cancel') {
    Write-Host "취소되었습니다"
    exit 0
}

$Mode = $_modeSelected
```

- [ ] **Step 3: 수동 테스트**

Expected: 모드 선택 화살표 UI 동작, 각 값 정상 매핑

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.ps1
git commit -m "통합 모드 메뉴 인터랙티브 UI 적용 (PowerShell) : feat : 모드 선택 교체"
```

---

## Task 12: PowerShell — 버전 정보 편집 메뉴 교체

**Files:**
- Modify: `template_integrator.ps1` (L702 부근 `switch $userChoice`)

- [ ] **Step 1: 기존 블록 위치 확인**

Run: `Grep "어떤 항목을 수정" template_integrator.ps1`

- [ ] **Step 2: 블록 교체**

기존 `do { Read-Host "선택 (1-4)" ... switch ($edit_choice) { ... } }` 블록을:

```powershell
$editChoice = Invoke-ChooseMenu -Prompt "어떤 항목을 수정하시겠습니까?" -Options @(
    @{Value='type';    Label='Project Type'},
    @{Value='version'; Label='Version'},
    @{Value='branch';  Label='Default Branch (기본 브랜치)'},
    @{Value='done';    Label='모두 맞음, 계속'}
)

if (-not $editChoice) { return }

switch ($editChoice) {
    'type'    { <#기존 Project Type 수정 본체#> }
    'version' { <#기존 Version 수정 본체#> }
    'branch'  { <#기존 Default Branch 수정 본체#> }
    'done'    { <#기존 4) 블록 본체#> }
}
```

> 각 case 본체는 기존 1)/2)/3)/4) 블록의 명령을 그대로 옮긴다.

- [ ] **Step 3: 수동 테스트**

Run: `powershell -File .\template_integrator.ps1` → Edit 선택

Expected: 4개 항목 화살표 UI, 각 항목 동작 유지

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.ps1
git commit -m "프로젝트 편집 메뉴 인터랙티브 UI 적용 (PowerShell) : feat : Edit 메뉴 교체"
```

---

## Task 13: PowerShell — 플러그인/scope 선택 메뉴 교체

**Files:**
- Modify: `template_integrator.ps1` (L2375, L2460, L2526, L2658, L2687, L2724 — `Read-Host "선택"` 사용 블록)

- [ ] **Step 1: 위치별 옵션 식별**

각 `Read-Host "선택"` 위치 위의 `Write-Host "  1 - ..."` 블록을 읽어 옵션 라벨 추출. 6곳 모두 동일 패턴 (`1`/`2`/`3`/`4` 입력).

- [ ] **Step 2: 각 블록 교체**

L2375 (cassiiopeia 관리):
```powershell
$choice = Invoke-ChooseMenu -Prompt "Claude Code 플러그인 (cassiiopeia)" -Options @(
    @{Value='update';    Label=$updateLabel},
    @{Value='reinstall'; Label='재설치 (scope 변경)'},
    @{Value='delete';    Label="삭제 (cassiiopeia@cassiiopeia-marketplace, scope: $installedScope)"},
    @{Value='skip';      Label='건너뛰기'}
)
switch ($choice) {
    'update'    { <#기존 1) 본체#> }
    'reinstall' { <#기존 2) 본체#> }
    'delete'    { <#기존 3) 본체#> }
    default     { Write-Host "Claude Code 플러그인 변경 없이 건너뜁니다" }
}
```

L2460 (cursor 관리) — 동일 패턴, 4개 옵션 `update`/`install`/`delete`/`skip`.

L2526, L2658, L2687, L2724 — 각 `Read-Host "선택"`이 묻는 scope/src/del 항목에 맞춰 옵션 정의. 옵션 라벨은 그 위의 `Write-Host` 텍스트 그대로 사용.

> 본 step은 각 위치를 개별 commit으로 나눠도 되고 한 commit에 묶어도 됨. 단순 치환이라 한 commit 권장.

- [ ] **Step 3: 수동 테스트**

각 메뉴 진입해 화살표 UI 정상 동작 확인.

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.ps1
git commit -m "플러그인/scope 메뉴 인터랙티브 UI 적용 (PowerShell) : feat : 6개 Read-Host 교체"
```

---

## Task 14: 전체 통합 수동 테스트

**Files:** 없음 (실행 검증)

- [ ] **Step 1: Git Bash (Windows) 전체 흐름 테스트**

Run: `bash template_integrator.sh`

체크:
- 프로젝트 자동 감지 → 수동 변경 (Edit → Project Type) → 화살표 UI 동작
- 통합 모드 선택 화살표 UI 동작
- 플러그인 관리 화살표 UI 동작
- ESC 키 → 취소 흐름 정상
- Ctrl+C → 커서 복원 후 종료

- [ ] **Step 2: PowerShell 전체 흐름 테스트**

Run: `powershell -ExecutionPolicy Bypass -File .\template_integrator.ps1`

체크: Step 1과 동일 항목

- [ ] **Step 3: 비TTY fallback 테스트**

Run:
```bash
echo "" | bash template_integrator.sh --help  # TTY 아니어도 깨지지 않음
```

체크: legacy 숫자 메뉴 또는 명령행 인자 처리 정상

- [ ] **Step 4: `NO_COLOR=1` 테스트**

Run: `NO_COLOR=1 bash template_integrator.sh`

체크: 색상 escape 제거, ASCII만 출력, UI 식별 가능

- [ ] **Step 5: 통합 commit (필요 시)**

이전 task에서 commit이 누락된 부분이 있으면 정리:
```bash
git status
git add template_integrator.sh template_integrator.ps1
git commit -m "interactive_menu 전체 통합 검증 : test : 수동 회귀 통과"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1-7 (sh) + Task 8-13 (ps1) + Task 14 (테스트). spec의 6개 적용 지점 모두 매핑됨.
- **Placeholder scan:** Task 6/7/12/13에서 "<#기존 N) 본체#>" 주석은 placeholder가 아니라 "기존 코드 그대로 이전"을 명시한 것. 각 task의 Step 1에서 기존 코드 줄 범위를 명시했으므로 실행자가 정확한 본체를 가져올 수 있다.
- **Type consistency:** sh `choose_menu` ↔ ps1 `Invoke-ChooseMenu`, sh option 형식 `value|label` ↔ ps1 `@{Value=..;Label=..}` — 양 언어 일관성 유지.
- **Scope:** 단일 plan 적정 (sh 함수 + ps1 함수 + 13개 메뉴 지점 + 검증).
