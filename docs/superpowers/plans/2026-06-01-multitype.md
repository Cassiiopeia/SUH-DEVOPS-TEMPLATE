# Multi Project Type Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `template_integrator.{sh,ps1}`, `version.yml`, `.github/scripts/version_manager.sh`, `.github/scripts/changelog_manager.py`, 공통 워크플로우에 멀티 프로젝트 타입 지원을 도입한다. 기존 단수 `project_type` 키만 있는 레포는 100% 하위 호환을 보장한다.

**Architecture:** `version.yml`에 `project_types: ["spring","react"]` 배열 키를 신규 추가하고, 단수 `project_type` 키는 항상 배열 첫 항목으로 자동 미러링한다. integrator는 자동 감지 시 모든 일치 타입을 반환하고, 다중 선택 메뉴(`--multi` 플래그)로 사용자가 확정한다. `version_manager.sh`는 배열을 우선 읽고 `sync_for_type()` 함수로 각 타입을 순회 sync한다. 워크플로우(`PROJECT-COMMON-VERSION-CONTROL`, `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL`)는 `project_types` step output을 추가해 changelog에도 배열을 기록한다.

**Tech Stack:** Bash 4+, PowerShell 5.1+, Python 3.8+, yq, jq, GitHub Actions YAML, sed/grep.

**Spec:** `docs/superpowers/specs/2026-06-01-multitype-design.md`

---

## File Structure

| 파일 | 역할 | 변경 종류 |
|---|---|---|
| `template_integrator.sh` | Bash 진입 스크립트 | 수정 — `PROJECT_TYPES` 배열, `detect_project_types()`, `--multi` 메뉴, 멀티 복사 |
| `template_integrator.ps1` | PowerShell 진입 스크립트 | 수정 — sh와 동일 로직 포팅 |
| `version.yml` | 버전 메타 | 수정 — `project_types: ["basic"]` 추가 |
| `.github/scripts/version_manager.sh` | 버전 동기화 | 수정 — `parse_version_yml()` 정합화, `sync_for_type()` 함수, 배열 순회 |
| `.github/scripts/changelog_manager.py` | CHANGELOG 갱신 | 수정 — `PROJECT_TYPES` env 받아 배열 기록 |
| `.github/scripts/template_initializer.sh` | 신규 레포 초기화 | 수정 — version.yml 초기 생성 시 두 키 같이 작성 |
| `.github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml` | 버전 컨트롤 워크플로우 | 수정 — `project_types` step output |
| `.github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml` | 원본 | 수정 — 동일 |
| `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` | 자동 changelog | 수정 — `project_types` step output + env 전달 |
| `.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` | 원본 | 수정 — 동일 |
| `docs/TEMPLATE-INTEGRATOR.md` | 사용 가이드 | 수정 — 멀티 예시 |
| `docs/VERSION-CONTROL.md` | 버전 관리 가이드 | 수정 — `project_types` 키 설명 |
| `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` | 배포 가이드 | 수정 — 멀티 시 포트/이름 안내 |
| `CONTRIBUTING.md` | 기여 가이드 | 수정 — 멀티타입 노트 |
| `CLAUDE.md` | 프로젝트 instruction | 수정 — 멀티타입 짧은 설명 |

---

## Implementation Order

1. **Task 1-3**: Bash `interactive_menu` `--multi` 확장 (PowerShell도 같이)
2. **Task 4-6**: `version.yml` 스키마 + `template_initializer.sh` + `version.yml` 실제 파일
3. **Task 7-10**: `template_integrator.sh` 멀티 로직 (`PROJECT_TYPES`, `detect_project_types`, 메뉴 호출, 복사 루프)
4. **Task 11-14**: `template_integrator.ps1` 동일 포팅
5. **Task 15-17**: `version_manager.sh` 정합화 + `sync_for_type()` + 배열 순회
6. **Task 18-19**: `changelog_manager.py` + 워크플로우 step output
7. **Task 20-21**: 문서 + 통합 수동 테스트

---

## Task 1: Bash — `choose_menu`에 `--multi` 플래그 추가

**Files:**
- Modify: `template_integrator.sh` — `interactive_menu` 함수 본체

- [ ] **Step 1: `interactive_menu` 시그니처 변경**

기존 시그니처: `interactive_menu "prompt" "value1|label1" ...`

신규: 첫 인자에 `--multi` 또는 `--preselect=csv` 옵션 허용. 기존 사용처 영향 0 (옵션 없으면 single).

`template_integrator.sh`에서 `interactive_menu` 함수 본체 위에 옵션 파싱 + multi mode 분기 추가:

```bash
interactive_menu() {
    local multi=false
    local preselect_csv=""

    # 옵션 파싱
    while [[ "$1" == --* ]]; do
        case "$1" in
            --multi) multi=true; shift ;;
            --preselect=*) preselect_csv="${1#--preselect=}"; shift ;;
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

    # 색상 활성 여부 (기존과 동일)
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

    # multi mode 선택 상태 — index → bool
    local selected=()
    local i
    for i in $(seq 0 $((n - 1))); do selected[$i]=false; done

    # preselect 적용
    if [ -n "$preselect_csv" ] && [ "$multi" = true ]; then
        IFS=',' read -ra pre <<< "$preselect_csv"
        for p in "${pre[@]}"; do
            for i in $(seq 0 $((n - 1))); do
                local value=""
                IFS='|' read -r value _ <<< "${options[$i]}"
                if [ "$value" = "$p" ]; then
                    selected[$i]=true
                    break
                fi
            done
        done
    fi

    # 프롬프트 안내
    if [ "$multi" = true ]; then
        printf "\n%s (↑↓ 이동, Space 토글, a 전체토글, Enter 확정, ESC 취소):\n\n" "$prompt" >&2
    else
        printf "\n%s (↑↓ 이동, 숫자 점프, Enter 확정, ESC 취소):\n\n" "$prompt" >&2
    fi

    local cursor=0

    trap 'printf "\033[?25h" >&2; return 130' INT
    printf "\033[?25l" >&2

    _interactive_menu_render() {
        local i value label num indicator
        for i in $(seq 0 $((n - 1))); do
            IFS='|' read -r value label <<< "${options[$i]}"
            num=$((i + 1))
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
            if [ "$i" -eq "$cursor" ]; then
                printf "%s> %s %d) %s    %s%s%s%s\n" \
                    "$C_CYAN" "$indicator" "$num" "$value" \
                    "$C_DIM" "$label" "$C_RESET" "$C_RESET" >&2
            else
                printf "  %s %d) %s    %s%s%s\n" \
                    "$indicator" "$num" "$value" \
                    "$C_DIM" "$label" "$C_RESET" >&2
            fi
        done
    }

    _interactive_menu_clear() {
        local i
        for i in $(seq 1 "$n"); do
            printf "\033[1A\033[2K" >&2
        done
    }

    _interactive_menu_render

    local key rest value
    while true; do
        IFS= read -rsn1 key < /dev/tty || { printf "\033[?25h" >&2; trap - INT; return 1; }

        if [ "$key" = $'\e' ]; then
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
            ' ')
                if [ "$multi" = true ]; then
                    if [ "${selected[$cursor]}" = true ]; then
                        selected[$cursor]=false
                    else
                        selected[$cursor]=true
                    fi
                fi
                ;;
            a|A)
                if [ "$multi" = true ]; then
                    # 전체가 선택돼 있으면 다 해제, 아니면 다 선택
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
                    # csv 출력
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
                    if [ -z "$out" ]; then
                        return 1
                    fi
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
```

> 기존 `interactive_menu` 함수 본체 전체를 위 코드로 교체. 변경점: 옵션 파싱(`--multi`, `--preselect=csv`), multi mode 분기 (선택 상태 배열·Space 토글·전체 토글·csv 출력).

- [ ] **Step 2: `legacy_numeric_menu` `--multi` 지원 추가**

기존 `legacy_numeric_menu` 함수 본체 전체를 다음으로 교체:

```bash
legacy_numeric_menu() {
    local multi=false
    local preselect_csv=""

    while [[ "$1" == --* ]]; do
        case "$1" in
            --multi) multi=true; shift ;;
            --preselect=*) preselect_csv="${1#--preselect=}"; shift ;;
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

    if [ "$multi" = true ]; then
        printf "여러 항목 선택 (csv, 예: 1,3,5 또는 spring,react)" >&2
        [ -n "$preselect_csv" ] && printf " [기본: %s]" "$preselect_csv" >&2
        printf ": " >&2
    else
        printf "선택 (1-%d): " "$n" >&2
    fi

    local choice read_ok=0
    if [ -t 0 ]; then
        IFS= read -r choice && read_ok=1
    elif [ -c /dev/tty ] 2>/dev/null && [ -r /dev/tty ]; then
        IFS= read -r choice < /dev/tty && read_ok=1
    fi

    if [ "$read_ok" -eq 0 ]; then
        if [ "$multi" = true ] && [ -n "$preselect_csv" ]; then
            echo "$preselect_csv"
            return 0
        fi
        IFS='|' read -r value _ <<< "${options[0]}"
        echo "$value"
        return 0
    fi

    # 빈 입력 + multi + preselect → preselect 사용
    if [ "$multi" = true ] && [ -z "$choice" ] && [ -n "$preselect_csv" ]; then
        echo "$preselect_csv"
        return 0
    fi

    if [ "$multi" = true ]; then
        # csv 파싱 — 숫자/이름 혼용 허용
        local out="" first=true
        IFS=',' read -ra parts <<< "$choice"
        for p in "${parts[@]}"; do
            p=$(echo "$p" | tr -d ' ')
            [ -z "$p" ] && continue
            local resolved=""
            if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le "$n" ]; then
                IFS='|' read -r resolved _ <<< "${options[$((p - 1))]}"
            else
                # 이름으로 매칭
                for i in $(seq 0 $((n - 1))); do
                    IFS='|' read -r value _ <<< "${options[$i]}"
                    if [ "$value" = "$p" ]; then
                        resolved="$value"
                        break
                    fi
                done
            fi
            if [ -n "$resolved" ]; then
                if [ "$first" = true ]; then
                    out="$resolved"; first=false
                else
                    out="$out,$resolved"
                fi
            fi
        done
        if [ -z "$out" ]; then
            printf "유효한 선택이 없습니다.\n" >&2
            return 1
        fi
        echo "$out"
        return 0
    fi

    # single mode
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ]; then
        IFS='|' read -r value _ <<< "${options[$((choice - 1))]}"
        echo "$value"
        return 0
    else
        printf "잘못된 입력입니다.\n" >&2
        return 1
    fi
}
```

- [ ] **Step 3: `choose_menu` 옵션 pass-through 확인**

`choose_menu` 함수는 그대로 `"$@"` 전달 → `--multi`/`--preselect=`도 자동 통과. 본문 그대로:

```bash
choose_menu() {
    if [ "$TTY_AVAILABLE" = true ] && [ -t 2 ]; then
        interactive_menu "$@"
    else
        legacy_numeric_menu "$@"
    fi
}
```

- [ ] **Step 4: 수동 테스트 — multi 모드**

Run:
```bash
bash -c '
source <(sed -n "/^interactive_menu()/,/^choose_menu()/p" template_integrator.sh; echo "}")
echo "test"
'
```
(실제로는 별도 작은 테스트 스크립트에 함수만 복사해 실행이 더 안정적)

Expected: Space 토글, Enter csv 출력, ESC 취소.

- [ ] **Step 5: 구문 검증**

```bash
bash -n template_integrator.sh && echo SYNTAX_OK
```
Expected: `SYNTAX_OK`

- [ ] **Step 6: 커밋**

```bash
git add template_integrator.sh
git commit -m "choose_menu 다중 선택(--multi) 모드 추가 : feat : Space 토글/전체토글/csv 출력"
```

---

## Task 2: PowerShell — `Invoke-ChooseMenu`에 `-Multi` 파라미터 추가

**Files:**
- Modify: `template_integrator.ps1` — `Invoke-InteractiveMenu`, `Invoke-LegacyNumericMenu`, `Invoke-ChooseMenu`

- [ ] **Step 1: `Invoke-InteractiveMenu` 본체 교체**

기존 `Invoke-InteractiveMenu` 함수 본체 전체를 다음으로 교체:

```powershell
function Invoke-InteractiveMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [int]$DefaultIndex = 0,
        [switch]$Multi,
        [string]$Preselect = ""
    )

    $n = $Options.Count
    if ($n -eq 0) {
        [Console]::Error.WriteLine("Invoke-InteractiveMenu: 옵션이 없습니다")
        return $null
    }

    $useColor = -not $env:NO_COLOR

    $cursor = $DefaultIndex
    if ($cursor -lt 0 -or $cursor -ge $n) { $cursor = 0 }

    # multi 선택 상태
    $selected = New-Object 'bool[]' $n
    if ($Multi -and $Preselect) {
        $pre = $Preselect.Split(',') | ForEach-Object { $_.Trim() }
        for ($i = 0; $i -lt $n; $i++) {
            if ($pre -contains $Options[$i].Value) { $selected[$i] = $true }
        }
    }

    Write-Host ""
    if ($Multi) {
        Write-Host ("{0} (↑↓ 이동, Space 토글, a 전체토글, Enter 확정, ESC 취소):" -f $Prompt)
    } else {
        Write-Host ("{0} (↑↓ 이동, 숫자 점프, Enter 확정, ESC 취소):" -f $Prompt)
    }
    Write-Host ""

    $startTop = [Console]::CursorTop
    $width = [Console]::WindowWidth
    if ($width -lt 20) { $width = 80 }

    $renderMenu = {
        [Console]::SetCursorPosition(0, $startTop)
        for ($i = 0; $i -lt $n; $i++) {
            $opt = $Options[$i]
            $num = $i + 1
            $indicator = ""
            if ($Multi) {
                if ($selected[$i]) { $indicator = "[✓]" } else { $indicator = "[ ]" }
            } else {
                if ($i -eq $cursor) { $indicator = "[•]" } else { $indicator = "[ ]" }
            }
            if ($i -eq $cursor) {
                $line = "> {0} {1}) {2}    {3}" -f $indicator, $num, $opt.Value, $opt.Label
            } else {
                $line = "  {0} {1}) {2}    {3}" -f $indicator, $num, $opt.Value, $opt.Label
            }
            if ($line.Length -lt ($width - 1)) {
                $line = $line.PadRight($width - 1)
            } else {
                $line = $line.Substring(0, $width - 1)
            }
            if ($i -eq $cursor -and $useColor) {
                Write-Host $line -ForegroundColor Cyan
            } elseif ($Multi -and $selected[$i] -and $useColor) {
                Write-Host $line -ForegroundColor Green
            } else {
                Write-Host $line
            }
        }
    }

    [Console]::CursorVisible = $false

    try {
        & $renderMenu
        while ($true) {
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow'   { $cursor--; if ($cursor -lt 0) { $cursor = $n - 1 } }
                'DownArrow' { $cursor++; if ($cursor -ge $n) { $cursor = 0 } }
                'K'         { $cursor--; if ($cursor -lt 0) { $cursor = $n - 1 } }
                'J'         { $cursor++; if ($cursor -ge $n) { $cursor = 0 } }
                'Spacebar'  {
                    if ($Multi) { $selected[$cursor] = -not $selected[$cursor] }
                }
                'A'         {
                    if ($Multi) {
                        $allOn = $true
                        for ($i = 0; $i -lt $n; $i++) { if (-not $selected[$i]) { $allOn = $false; break } }
                        for ($i = 0; $i -lt $n; $i++) { $selected[$i] = -not $allOn }
                    }
                }
                'Enter' {
                    [Console]::SetCursorPosition(0, $startTop + $n)
                    if ($Multi) {
                        $picked = @()
                        for ($i = 0; $i -lt $n; $i++) { if ($selected[$i]) { $picked += $Options[$i].Value } }
                        if ($picked.Count -eq 0) { return $null }
                        return ($picked -join ',')
                    }
                    return $Options[$cursor].Value
                }
                'Escape' { [Console]::SetCursorPosition(0, $startTop + $n); return $null }
                'Q'      { [Console]::SetCursorPosition(0, $startTop + $n); return $null }
                default  {
                    $ch = $key.KeyChar
                    if ($ch -ge '1' -and $ch -le '9') {
                        $jump = [int]([string]$ch) - 1
                        if ($jump -lt $n) { $cursor = $jump }
                    }
                }
            }
            & $renderMenu
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}
```

- [ ] **Step 2: `Invoke-LegacyNumericMenu` 본체 교체**

```powershell
function Invoke-LegacyNumericMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [switch]$Multi,
        [string]$Preselect = ""
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

    $promptMsg = if ($Multi) {
        if ($Preselect) { "여러 항목 선택 (csv, 예: 1,3,5 또는 spring,react) [기본: $Preselect]" }
        else { "여러 항목 선택 (csv, 예: 1,3,5 또는 spring,react)" }
    } else { "선택 (1-$n)" }

    try {
        $choice = Read-Host $promptMsg
    } catch {
        if ($Multi -and $Preselect) { return $Preselect }
        return $Options[0].Value
    }

    if ($Multi) {
        if (-not $choice -and $Preselect) { return $Preselect }
        $resolved = @()
        foreach ($p in $choice.Split(',')) {
            $p = $p.Trim()
            if (-not $p) { continue }
            if ($p -match '^\d+$' -and [int]$p -ge 1 -and [int]$p -le $n) {
                $resolved += $Options[[int]$p - 1].Value
            } else {
                for ($i = 0; $i -lt $n; $i++) {
                    if ($Options[$i].Value -eq $p) { $resolved += $p; break }
                }
            }
        }
        if ($resolved.Count -eq 0) {
            Write-Host "유효한 선택이 없습니다."
            return $null
        }
        return ($resolved -join ',')
    }

    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $n) {
        return $Options[[int]$choice - 1].Value
    }
    Write-Host "잘못된 입력입니다."
    return $null
}
```

- [ ] **Step 3: `Invoke-ChooseMenu` 본체 교체**

```powershell
function Invoke-ChooseMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [int]$DefaultIndex = 0,
        [switch]$Multi,
        [string]$Preselect = ""
    )

    $isTty = (-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected)
    if ($isTty) {
        if ($Multi) {
            return Invoke-InteractiveMenu -Prompt $Prompt -Options $Options -DefaultIndex $DefaultIndex -Multi -Preselect $Preselect
        }
        return Invoke-InteractiveMenu -Prompt $Prompt -Options $Options -DefaultIndex $DefaultIndex
    } else {
        if ($Multi) {
            return Invoke-LegacyNumericMenu -Prompt $Prompt -Options $Options -Multi -Preselect $Preselect
        }
        return Invoke-LegacyNumericMenu -Prompt $Prompt -Options $Options
    }
}
```

- [ ] **Step 4: 구문 검증**

Run:
```powershell
[System.Management.Automation.Language.Parser]::ParseFile('D:\0-suh\project\suh-github-template\template_integrator.ps1', [ref]$null, [ref]$null) | Out-Null; 'OK'
```
Expected: `OK`

- [ ] **Step 5: 커밋**

```bash
git add template_integrator.ps1
git commit -m "Invoke-ChooseMenu 다중 선택(-Multi) 모드 추가 : feat : Space 토글/csv 출력"
```

---

## Task 3: version.yml — `project_types` 배열 키 추가

**Files:**
- Modify: `version.yml` — 새 키 추가

- [ ] **Step 1: `version.yml` 편집**

기존:
```yaml
version: "3.0.78"
version_code: 270
project_type: "basic" # spring, flutter, next, react, react-native, react-native-expo, node, python, basic
metadata:
  last_updated: "2026-06-01 02:30:07"
  last_updated_by: "Cassiiopeia"
```

신규 (line 28~29 사이에 `project_types` 추가):
```yaml
version: "3.0.78"
version_code: 270
project_types: ["basic"]                          # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능
project_type: "basic"                             # project_types[0] 자동 미러 — 직접 수정 금지
metadata:
  last_updated: "2026-06-01 02:30:07"
  last_updated_by: "Cassiiopeia"
```

> `project_types`를 `project_type` 위에 두고 주석으로 역할 구분 명시.

- [ ] **Step 2: yq 파싱 검증**

```bash
cd D:/0-suh/project/suh-github-template
yq -r '.project_types[]' version.yml
```
Expected: `basic` (한 줄)

- [ ] **Step 3: 커밋**

```bash
git add version.yml
git commit -m "version.yml project_types 배열 키 신규 추가 : feat : 멀티타입 지원 스키마"
```

---

## Task 4: `template_initializer.sh` — 초기 version.yml에 `project_types` 작성

**Files:**
- Modify: `.github/scripts/template_initializer.sh:269-271`

- [ ] **Step 1: 신규 version.yml 생성 부분 수정**

기존 (L267-272):
```bash
version: "$version"
version_code: 1  # app build number
project_type: "$type" # spring, flutter, next, react, react-native, react-native-expo, node, python, basic
metadata:
  last_updated: "$(date -u +"%Y-%m-%d %H:%M:%S")"
```

→ 수정:
```bash
version: "$version"
version_code: 1  # app build number
project_types: ["$type"]                          # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능
project_type: "$type"                             # project_types[0] 자동 미러 — 직접 수정 금지
metadata:
  last_updated: "$(date -u +"%Y-%m-%d %H:%M:%S")"
```

- [ ] **Step 2: 구문 검증**

```bash
bash -n .github/scripts/template_initializer.sh && echo SYNTAX_OK
```
Expected: `SYNTAX_OK`

- [ ] **Step 3: 커밋**

```bash
git add .github/scripts/template_initializer.sh
git commit -m "template_initializer.sh 초기 version.yml에 project_types 작성 : feat"
```

---

## Task 5: `version_manager.sh` — `parse_version_yml()` 정합화 + `sync_for_type()` 함수

**Files:**
- Modify: `.github/scripts/version_manager.sh:97-145` (`read_version_config()`), `:113-139` (case 분기), 전체 sync 흐름

- [ ] **Step 1: `parse_project_types()` 헬퍼 + `sync_project_type_field()` 정합화 함수 추가**

`read_version_config()` 함수 바로 위에 다음 헬퍼 두 개를 추가:

```bash
# version.yml의 project_types 배열을 csv로 반환 (빈 문자열이면 키 없음)
parse_project_types() {
    if [ ! -f "version.yml" ]; then
        echo ""
        return
    fi
    yq -r '.project_types // [] | join(",")' version.yml 2>/dev/null || echo ""
}

# project_type 단수 키를 project_types[0]으로 강제 동기화
sync_project_type_field() {
    local types_csv=$1
    [ -z "$types_csv" ] && return 0

    local first
    first=$(echo "$types_csv" | cut -d',' -f1)

    local current_single
    current_single=$(yq -r '.project_type // ""' version.yml)

    if [ "$current_single" != "$first" ]; then
        log_info "project_type 정합화: '$current_single' → '$first' (project_types[0])"
        yq -i ".project_type = \"$first\"" version.yml
    fi
}
```

- [ ] **Step 2: `read_version_config()` 본체 수정**

기존:
```bash
read_version_config() {
    if [ ! -f "version.yml" ]; then
        log_error "version.yml 파일을 찾을 수 없습니다!"
        exit 1
    fi

    log_debug "version.yml 파싱 시작 (yq 사용)"

    PROJECT_TYPE=$(yq -r '.project_type // "basic"' version.yml)
    CURRENT_VERSION=$(yq -r '.version // "0.0.0"' version.yml)

    check_required_tools "$PROJECT_TYPE"

    case "$PROJECT_TYPE" in
        "spring") VERSION_FILE="build.gradle" ;;
        ...
    esac

    log_info "프로젝트 설정"
    log_info "  타입: $PROJECT_TYPE"
    log_info "  버전 파일: $VERSION_FILE"
    log_info "  현재 버전: $CURRENT_VERSION"
}
```

→ 수정:
```bash
read_version_config() {
    if [ ! -f "version.yml" ]; then
        log_error "version.yml 파일을 찾을 수 없습니다!"
        exit 1
    fi

    log_debug "version.yml 파싱 시작 (yq 사용)"

    # 1. project_types 배열 파싱
    PROJECT_TYPES_CSV=$(parse_project_types)

    # 2. 정합화 — 배열 있으면 project_type 단수 키를 첫 항목으로 강제
    if [ -n "$PROJECT_TYPES_CSV" ]; then
        sync_project_type_field "$PROJECT_TYPES_CSV"
    fi

    # 3. 단수 키 + 현재 버전 읽기 (정합화 이후)
    PROJECT_TYPE=$(yq -r '.project_type // "basic"' version.yml)
    CURRENT_VERSION=$(yq -r '.version // "0.0.0"' version.yml)

    # 4. 필수 도구 확인 — 배열이면 모든 타입 검사, 아니면 단수
    if [ -n "$PROJECT_TYPES_CSV" ]; then
        IFS=',' read -ra _types <<< "$PROJECT_TYPES_CSV"
        for t in "${_types[@]}"; do check_required_tools "$t"; done
    else
        check_required_tools "$PROJECT_TYPE"
    fi

    # 5. VERSION_FILE — primary 타입(단수 키) 기준 — 기존 동작 유지
    case "$PROJECT_TYPE" in
        "spring")
            VERSION_FILE="build.gradle"
            ;;
        "flutter")
            VERSION_FILE="pubspec.yaml"
            ;;
        "react"|"next"|"node")
            VERSION_FILE="package.json"
            ;;
        "react-native")
            local ios_plist
            ios_plist=$(find ios -name "Info.plist" -type f 2>/dev/null | head -1 || true)
            if [ -n "$ios_plist" ]; then
                VERSION_FILE="$ios_plist"
            else
                VERSION_FILE="android/app/build.gradle"
            fi
            ;;
        "react-native-expo")
            VERSION_FILE="app.json"
            ;;
        "basic"|*)
            VERSION_FILE="version.yml"
            ;;
    esac

    log_info "프로젝트 설정"
    if [ -n "$PROJECT_TYPES_CSV" ]; then
        log_info "  타입(배열): $PROJECT_TYPES_CSV"
    fi
    log_info "  타입(primary): $PROJECT_TYPE"
    log_info "  버전 파일(primary): $VERSION_FILE"
    log_info "  현재 버전: $CURRENT_VERSION"
}
```

- [ ] **Step 3: `sync_for_type()` 함수 신설 + 기존 update 로직 활용**

`update_project_file_version()` 함수의 case 분기를 함수로 추출하지 않고 그대로 둔다 — 단일 타입에서만 호출되는 함수. 멀티 sync는 별도 신규 함수로 처리.

`update_project_file_version()` 직후에 다음 함수 추가:

```bash
# 특정 타입에 대해 프로젝트 파일 sync (멀티 타입 지원)
sync_for_type() {
    local t=$1
    local new_version=$2

    log_info "타입별 sync: $t → $new_version"

    case "$t" in
        "spring")
            find . -maxdepth 2 -name "build.gradle" -type f 2>/dev/null | while read -r gradle_file; do
                sed -i.bak "s/version = '[^']*'/version = '$new_version'/g; s/version = \"[^\"]*\"/version = \"$new_version\"/g" "$gradle_file"
                rm -f "${gradle_file}.bak"
                log_success "업데이트: $gradle_file"
            done
            ;;
        "flutter")
            if [ -f "pubspec.yaml" ]; then
                local code
                code=$(get_version_code)
                yq -i ".version = \"$new_version+$code\"" pubspec.yaml
                log_success "업데이트: pubspec.yaml"
            fi
            ;;
        "react"|"next"|"node")
            if [ -f "package.json" ]; then
                jq ".version = \"$new_version\"" package.json > tmp.json && mv tmp.json package.json
                log_success "업데이트: package.json"
            fi
            ;;
        "react-native")
            find ios -name "Info.plist" -type f 2>/dev/null | while read -r plist_file; do
                if grep -q "CFBundleShortVersionString" "$plist_file"; then
                    sed -i.bak '/CFBundleShortVersionString/{n;s/<string>[^<]*<\/string>/<string>'"$new_version"'<\/string>/;}' "$plist_file"
                    rm -f "${plist_file}.bak"
                    log_success "업데이트: $plist_file"
                fi
            done
            if [ -f "android/app/build.gradle" ]; then
                sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$new_version\"/" "android/app/build.gradle"
                rm -f "android/app/build.gradle.bak"
                log_success "업데이트: android/app/build.gradle"
            fi
            ;;
        "react-native-expo")
            if [ -f "app.json" ]; then
                jq ".expo.version = \"$new_version\"" app.json > tmp.json && mv tmp.json app.json
                log_success "업데이트: app.json"
            fi
            ;;
        "basic")
            : ;;
        *)
            log_warning "알 수 없는 타입: $t — 건너뜀"
            ;;
    esac
}

# 모든 타입 sync (멀티 또는 단일)
sync_all_project_files() {
    local new_version=$1

    if [ -n "${PROJECT_TYPES_CSV:-}" ]; then
        log_info "멀티타입 sync 시작: $PROJECT_TYPES_CSV"
        IFS=',' read -ra _types <<< "$PROJECT_TYPES_CSV"
        for t in "${_types[@]}"; do
            sync_for_type "$t" "$new_version"
        done
    else
        # Legacy 단일 — 기존 update_project_file_version 호출
        update_project_file_version "$new_version"
    fi
}
```

- [ ] **Step 4: `update_all_versions()` 본체 수정**

기존:
```bash
update_all_versions() {
    local new_version=$1
    log_info "모든 버전 파일 업데이트: $new_version"
    update_version_yml "$new_version"
    update_project_file_version "$new_version"
    log_success "모든 버전 파일 업데이트 완료: $new_version"
}
```

→ 수정:
```bash
update_all_versions() {
    local new_version=$1
    log_info "모든 버전 파일 업데이트: $new_version"
    update_version_yml "$new_version"
    sync_all_project_files "$new_version"
    log_success "모든 버전 파일 업데이트 완료: $new_version"
}
```

- [ ] **Step 5: 전역 변수 선언 추가**

L33-36 (`PROJECT_TYPE=""` 등) 위치에 `PROJECT_TYPES_CSV=""` 추가:

기존:
```bash
PROJECT_TYPE=""
VERSION_FILE=""
CURRENT_VERSION=""
```

→ 수정:
```bash
PROJECT_TYPE=""
PROJECT_TYPES_CSV=""
VERSION_FILE=""
CURRENT_VERSION=""
```

- [ ] **Step 6: 구문 검증**

```bash
bash -n .github/scripts/version_manager.sh && echo SYNTAX_OK
```
Expected: `SYNTAX_OK`

- [ ] **Step 7: 기능 검증 — 멀티 sync**

테스트 절차:
1. `version.yml` 에 `project_types: ["spring", "react"]` 와 dummy `build.gradle` + `package.json` 준비
2. `bash .github/scripts/version_manager.sh set 9.9.9` 실행
3. `build.gradle`과 `package.json` 둘 다 9.9.9로 업데이트됐는지 확인

> 실제 레포의 version.yml은 `basic` 타입이라 sync 영향 없음. 별도 임시 디렉토리에서 검증.

- [ ] **Step 8: 커밋**

```bash
git add .github/scripts/version_manager.sh
git commit -m "version_manager.sh 멀티타입 sync 지원 : feat : project_types 배열 순회 + 정합화"
```

---

## Task 6: `template_integrator.sh` — `PROJECT_TYPES` 배열 변수 + `detect_project_types()`

**Files:**
- Modify: `template_integrator.sh:583` (`PROJECT_TYPE=""` 직후), `:632-705` (`detect_project_type()`)

- [ ] **Step 1: `PROJECT_TYPES` 배열 변수 선언**

L583 (`PROJECT_TYPE=""`) 직후에 추가:
```bash
PROJECT_TYPE=""
PROJECT_TYPES=()
```

- [ ] **Step 2: `detect_project_types()` 신규 함수 추가**

기존 `detect_project_type()` 함수 직후에 추가:

```bash
# 모든 일치 타입을 배열로 반환 (자동 감지 — 멀티 지원)
detect_project_types() {
    local detected=()

    [ -f "pubspec.yaml" ] && detected+=("flutter")

    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] || [ -f "pom.xml" ]; then
        detected+=("spring")
    fi

    if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
        detected+=("python")
    fi

    # package.json 기반 — next / react-native / react-native-expo / node / react 구분
    if [ -f "package.json" ]; then
        if [ -f "next.config.js" ] || [ -f "next.config.ts" ] || [ -f "next.config.mjs" ]; then
            detected+=("next")
        elif [ -d "ios" ] && [ -d "android" ]; then
            # Expo? — app.json에 expo 키 확인
            if [ -f "app.json" ] && grep -q '"expo"' app.json 2>/dev/null; then
                detected+=("react-native-expo")
            else
                detected+=("react-native")
            fi
        elif command -v jq >/dev/null 2>&1 && jq -e '.dependencies.react // empty' package.json >/dev/null 2>&1; then
            detected+=("react")
        else
            detected+=("node")
        fi
    fi

    [ ${#detected[@]} -eq 0 ] && detected=("basic")

    # 출력 — 한 줄 csv
    local IFS=','
    echo "${detected[*]}"
}
```

- [ ] **Step 3: 구문 검증**

```bash
bash -n template_integrator.sh && echo SYNTAX_OK
```

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.sh
git commit -m "detect_project_types() 신규 함수 + PROJECT_TYPES 배열 변수 : feat"
```

---

## Task 7: `template_integrator.sh` — `--type` csv 파싱 + 검증

**Files:**
- Modify: `template_integrator.sh:589` (`VALID_TYPES`), `:597-615` (인자 파싱)

- [ ] **Step 1: `VALID_TYPES`에 `next` 추가 (sh-ps1 일관성)**

기존 (L589):
```bash
VALID_TYPES=("spring" "flutter" "react" "react-native" "react-native-expo" "node" "python" "basic")
```

→ 수정:
```bash
VALID_TYPES=("spring" "flutter" "next" "react" "react-native" "react-native-expo" "node" "python" "basic")
```

- [ ] **Step 2: `--type` 옵션 csv 파싱 처리**

기존 (L603 부근, `--type` 파싱):
```bash
            PROJECT_TYPE="$2"
```

→ 수정 (csv 분해, 검증, 배열 저장):
```bash
            # csv 분해 → PROJECT_TYPES 배열에 저장 + 첫 항목을 PROJECT_TYPE에
            local _arg_types="$2"
            IFS=',' read -ra _arg_arr <<< "$_arg_types"
            PROJECT_TYPES=()
            local _seen=""
            for _t in "${_arg_arr[@]}"; do
                _t=$(echo "$_t" | tr -d ' ')
                [ -z "$_t" ] && continue
                # dedup
                [[ ",$_seen," == *",$_t,"* ]] && continue
                # 검증
                local _valid=false
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
```

- [ ] **Step 3: 구문 검증**

```bash
bash -n template_integrator.sh && echo SYNTAX_OK
```

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.sh
git commit -m "--type 인자 csv 파싱 + 검증 + dedup : feat : 멀티타입 CLI 지원"
```

---

## Task 8: `template_integrator.sh` — 자동 감지 흐름 → 사용자 확인 + 다중 선택 메뉴

**Files:**
- Modify: `template_integrator.sh:854-905` (`detect_and_confirm_project()` 본체)

- [ ] **Step 1: 자동 감지 → 멀티 결과 + 사용자 확인 흐름 수정**

기존 (L854-871):
```bash
detect_and_confirm_project() {
    if [ -z "$PROJECT_TYPE" ]; then
        PROJECT_TYPE=$(detect_project_type)
    fi
    ...
```

→ 수정:
```bash
detect_and_confirm_project() {
    # 자동 감지 (최초 1회만) — 멀티 결과 우선
    if [ ${#PROJECT_TYPES[@]} -eq 0 ]; then
        local _detected_csv
        _detected_csv=$(detect_project_types)
        IFS=',' read -ra PROJECT_TYPES <<< "$_detected_csv"
        PROJECT_TYPE="${PROJECT_TYPES[0]}"
        print_info "감지된 프로젝트 타입: ${PROJECT_TYPES[*]}"
    fi

    if [ -z "$VERSION" ]; then
        VERSION=$(detect_version)
    fi
    if [ -z "$DETECTED_BRANCH" ]; then
        DETECTED_BRANCH=$(detect_default_branch)
    fi

    local confirmed=false
    while [ "$confirmed" = false ]; do
        print_section_header "🛰️" "프로젝트 분석 결과"

        local _types_csv
        local IFS=','
        _types_csv="${PROJECT_TYPES[*]}"
        unset IFS

        print_to_user ""
        if [ ${#PROJECT_TYPES[@]} -gt 1 ]; then
            print_to_user "       📂 Project Types    : $_types_csv (멀티)"
        else
            print_to_user "       📂 Project Type     : $PROJECT_TYPE"
        fi
        print_to_user "       🌙 Version          : $VERSION"
        print_to_user "       🌿 Default Branch   : $DETECTED_BRANCH"
        print_to_user ""

        print_to_user "이 정보가 맞습니까?"
        print_to_user "  Y/y - 예, 계속 진행"
        print_to_user "  E/e - 수정하기"
        print_to_user "  N/n - 아니오, 취소"
        print_to_user ""

        local user_choice
        user_choice=$(ask_yes_no_edit)

        case "$user_choice" in
            "yes")
                confirmed=true
                print_success "프로젝트 정보 확인 완료"
                print_to_user ""
                ;;
            "no")
                print_info "취소되었습니다"
                exit 0
                ;;
            "edit")
                handle_project_edit_menu
                ;;
            *)
                print_error "예상치 못한 오류가 발생했습니다"
                exit 1
                ;;
        esac
    done
}
```

- [ ] **Step 2: 구문 검증**

```bash
bash -n template_integrator.sh && echo SYNTAX_OK
```

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.sh
git commit -m "detect_and_confirm_project 멀티타입 감지·확인 흐름 : feat"
```

---

## Task 9: `template_integrator.sh` — Edit 메뉴 "Project Type" → 다중 선택

**Files:**
- Modify: `template_integrator.sh:907-973` (`handle_project_edit_menu`)

- [ ] **Step 1: `show_project_type_menu` → multi 모드**

기존 `show_project_type_menu()` 함수 본체 전체를 다음으로 교체:

```bash
show_project_type_menu() {
    # 현재 PROJECT_TYPES를 preselect csv로
    local _preselect=""
    local IFS=','
    _preselect="${PROJECT_TYPES[*]:-}"
    unset IFS

    local selected
    selected=$(choose_menu --multi --preselect="$_preselect" "프로젝트 타입을 선택하세요 (멀티 가능)" \
        "spring|Spring Boot 백엔드" \
        "flutter|Flutter 모바일 앱" \
        "next|Next.js 웹 앱" \
        "react|React 웹 앱" \
        "react-native|React Native 모바일 앱" \
        "react-native-expo|React Native Expo 앱" \
        "node|Node.js 프로젝트" \
        "python|Python 프로젝트" \
        "basic|기타 프로젝트")

    if [ -z "$selected" ]; then
        print_error "프로젝트 타입 선택이 취소되었습니다. 기존 값을 유지합니다."
        # 출력 — 기존 PROJECT_TYPES csv (호출측이 사용)
        local IFS=','
        echo "${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
        unset IFS
        return 1
    fi

    echo "$selected"
}
```

- [ ] **Step 2: `handle_project_edit_menu` "type" case 본체 수정**

기존 (L928-933):
```bash
    case "$edit_choice" in
        type)
            PROJECT_TYPE=$(show_project_type_menu)
            print_success "Project Type이 '$PROJECT_TYPE'(으)로 변경되었습니다"
            print_to_user ""
            ;;
```

→ 수정:
```bash
    case "$edit_choice" in
        type)
            local _new_csv
            _new_csv=$(show_project_type_menu)
            if [ -n "$_new_csv" ]; then
                IFS=',' read -ra PROJECT_TYPES <<< "$_new_csv"
                PROJECT_TYPE="${PROJECT_TYPES[0]}"
                if [ ${#PROJECT_TYPES[@]} -gt 1 ]; then
                    print_success "Project Types가 '${PROJECT_TYPES[*]}'(으)로 변경되었습니다"
                else
                    print_success "Project Type이 '$PROJECT_TYPE'(으)로 변경되었습니다"
                fi
            fi
            print_to_user ""
            ;;
```

- [ ] **Step 3: 구문 검증 + 커밋**

```bash
bash -n template_integrator.sh && echo SYNTAX_OK
git add template_integrator.sh
git commit -m "Edit 메뉴 프로젝트 타입을 다중 선택으로 변경 : feat : --multi 활용"
```

---

## Task 10: `template_integrator.sh` — 워크플로우/util 복사 배열 순회

**Files:**
- Modify: `template_integrator.sh:1554-1792` (`copy_workflows`), `:2080~` (`show_util_module_description`/`show_util_usage_guide` 호출), `:3220~3293` (최종 요약 prefix 매칭, Spring/Flutter 안내)

- [ ] **Step 1: `copy_workflows()` — 타입별 처리 부분을 배열 순회로**

기존 (L1593-1697 부근, "2. 타입별 워크플로우 처리" 블록):

기존 코드는 `local type_dir="$project_types_dir/$PROJECT_TYPE"` 단일 처리. → 배열 순회 + 타입별 처리 헬퍼로 추출.

먼저 `copy_workflows()` 함수 직전에 헬퍼 함수 추가:

```bash
# 단일 타입의 워크플로우 복사 (기존 로직을 함수로 추출)
_copy_workflows_for_type() {
    local type=$1
    local project_types_dir=$2

    local type_dir="$project_types_dir/$type"
    if [ ! -d "$type_dir" ]; then
        print_info "$type 타입의 전용 워크플로우가 없습니다."
        return 0
    fi

    local existing_files=()
    local new_files=()

    for workflow in "$type_dir"/*.{yaml,yml}; do
        [ -e "$workflow" ] || continue
        local filename=$(basename "$workflow")
        if [ -f "$WORKFLOWS_DIR/$filename" ]; then
            existing_files+=("$filename")
        else
            new_files+=("$filename")
        fi
    done

    # 신규 파일은 바로 복사
    if [ ${#new_files[@]} -gt 0 ]; then
        print_info "$type 신규 워크플로우 다운로드 중..."
        for filename in "${new_files[@]}"; do
            cp "$type_dir/$filename" "$WORKFLOWS_DIR/"
            echo "  ✓ $filename (신규)"
            _copy_count=$((_copy_count + 1))
        done
    fi

    # 기존 파일 — T/S/O 선택 (기존 로직 그대로)
    if [ ${#existing_files[@]} -gt 0 ]; then
        echo ""
        print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_warning "⚠️  이미 존재하는 타입별 워크플로우($type): ${#existing_files[@]}개"
        print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for f in "${existing_files[@]}"; do
            echo "   • $f"
        done
        echo ""
        print_info "처리 방법을 선택하세요:"
        echo ""
        echo "  (T) .template.yaml로 추가"
        echo "      → 기존 파일 유지 + 새 버전을 참고용으로 추가"
        echo "  (S) 건너뛰기"
        echo "      → 기존 파일만 유지, 아무것도 추가 안 함"
        echo "  (O) 덮어쓰기 (기존 방식)"
        echo "      → 기존 파일을 .bak으로 백업 후 덮어쓰기"
        echo ""

        local choice
        safe_read "선택 [T/S/O]: " choice "-n 1"
        echo ""

        case "${choice^^}" in
            T)
                print_info "새 버전을 .template.yaml로 추가합니다..."
                for filename in "${existing_files[@]}"; do
                    local template_name="${filename%.yaml}.template.yaml"
                    rm -f "$WORKFLOWS_DIR/$template_name"
                    cp "$type_dir/$filename" "$WORKFLOWS_DIR/$template_name"
                    echo "  ✓ $template_name (참고용 추가)"
                    _template_added_count=$((_template_added_count + 1))
                done
                ;;
            S)
                print_info "기존 파일을 유지합니다..."
                for filename in "${existing_files[@]}"; do
                    echo "  ⏭ $filename (건너뜀)"
                    _skipped_count=$((_skipped_count + 1))
                done
                ;;
            O)
                print_info "기존 파일을 백업 후 덮어씁니다..."
                for filename in "${existing_files[@]}"; do
                    mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
                    cp "$type_dir/$filename" "$WORKFLOWS_DIR/"
                    echo "  ✓ $filename (백업: ${filename}.bak)"
                    _copy_count=$((_copy_count + 1))
                done
                ;;
            *)
                print_warning "잘못된 선택. 기존 파일을 유지합니다."
                for filename in "${existing_files[@]}"; do
                    _skipped_count=$((_skipped_count + 1))
                done
                ;;
        esac
    fi

    # synology 처리 (기존 로직)
    local synology_dir="$project_types_dir/$type/synology"
    if [ -d "$synology_dir" ] && [ "$INCLUDE_SYNOLOGY" = true ]; then
        for sf in "$synology_dir"/*.{yaml,yml}; do
            [ -e "$sf" ] || continue
            local sfn=$(basename "$sf")
            if [ ! -f "$WORKFLOWS_DIR/$sfn" ]; then
                cp "$sf" "$WORKFLOWS_DIR/"
                echo "  ✓ $sfn (synology, $type)"
                _copy_count=$((_copy_count + 1))
            fi
        done
    fi
}
```

> 기존 단일 타입 처리 블록(L1593~L1697)을 통째로 이 헬퍼로 추출. 카운터는 함수 외부 `_copy_count`, `_template_added_count`, `_skipped_count` 변수 공유. synology 로직도 기존 코드의 해당 블록을 그대로 옮겨 통합. 정확한 기존 코드 라인은 L1593-L1762 사이 — Synology 처리(L1699~)도 함수에 포함.

- [ ] **Step 2: `copy_workflows()` 본체 — 배열 순회로 변경**

`copy_workflows()` 함수 본체 안에서, 기존 "2. 타입별 워크플로우 처리" 시작부터 synology 블록 끝까지의 코드를 다음으로 교체:

```bash
    # 2. 타입별 워크플로우 처리 — PROJECT_TYPES 배열 순회
    local _copy_count=$copied
    local _template_added_count=$template_added
    local _skipped_count=$skipped

    local types_to_copy=("${PROJECT_TYPES[@]}")
    if [ ${#types_to_copy[@]} -eq 0 ]; then
        types_to_copy=("$PROJECT_TYPE")
    fi

    for _t in "${types_to_copy[@]}"; do
        _copy_workflows_for_type "$_t" "$project_types_dir"
    done

    copied=$_copy_count
    template_added=$_template_added_count
    skipped=$_skipped_count
```

> 정확한 위치 식별: `# 2. 타입별 워크플로우 처리 (선택적 업데이트)` 주석부터 `# CI/CD 워크플로우 안내` 직전까지가 교체 대상.

- [ ] **Step 3: `# CI/CD 워크플로우 안내` 블록(L1782)을 배열 contains 체크로**

기존:
```bash
    if [ "$PROJECT_TYPE" = "spring" ]; then
        echo ""
        print_info "🔐 Spring CI/CD 워크플로우 사용 시 GitHub Secrets 설정:"
        ...
    fi
```

→ 수정:
```bash
    _contains_type() {
        local needle=$1
        local arr=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
        for x in "${arr[@]}"; do [ "$x" = "$needle" ] && return 0; done
        return 1
    }

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
```

- [ ] **Step 4: 최종 요약 prefix 매칭 (L3220 부근)을 배열 순회로**

기존 (L3220-3231 부근):
```bash
            elif [[ "$filename" =~ ^${WORKFLOW_PREFIX}-$(echo "$PROJECT_TYPE" | tr '[:lower:]' '[:upper:]')- ]]; then
                type_workflows+=("$filename")
            fi
```

→ 수정:
```bash
            else
                # PROJECT_TYPES 배열 순회 — 어떤 타입 prefix와 매칭되는지 검사
                local _matched=false
                local _check_types=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
                for _t in "${_check_types[@]}"; do
                    local _prefix="^${WORKFLOW_PREFIX}-$(echo "$_t" | tr '[:lower:]' '[:upper:]')-"
                    if [[ "$filename" =~ $_prefix ]]; then
                        type_workflows+=("$filename")
                        _matched=true
                        break
                    fi
                done
                [ "$_matched" = false ] || true
            fi
```

- [ ] **Step 5: util 모듈 안내·복사 부분 (L3265, L3286)도 배열 순회**

`copy_util_modules()` 함수가 단일 타입을 받는 형태로 호출됨 (L2369, L2388, L3267~). 호출부에서 배열 순회로 호출하도록 수정.

기존 (L3265-3275 부근):
```bash
    if [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
        echo "  🧙 유틸리티 모듈:" >&2
        if [ -d ".github/util/$PROJECT_TYPE" ]; then
            for dir in ".github/util/$PROJECT_TYPE"/*/; do
                [ -d "$dir" ] || continue
                local module_name=$(basename "$dir")
                echo "     ├─ $module_name" >&2
            done
        fi
        echo "" >&2
    fi
```

→ 수정:
```bash
    if [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
        echo "  🧙 유틸리티 모듈:" >&2
        local _types_for_util=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
        for _t in "${_types_for_util[@]}"; do
            if [ -d ".github/util/$_t" ]; then
                for dir in ".github/util/$_t"/*/; do
                    [ -d "$dir" ] || continue
                    local module_name=$(basename "$dir")
                    echo "     ├─ $module_name ($_t)" >&2
                done
            fi
        done
        echo "" >&2
    fi
```

기존 Flutter 안내(L3286):
```bash
    if [ "$PROJECT_TYPE" = "flutter" ] && [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
```

→ 수정:
```bash
    if _contains_type "flutter" && [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
```

기존 Spring 안내(L3278):
```bash
    if [ "$PROJECT_TYPE" = "spring" ]; then
```

→ 수정:
```bash
    if _contains_type "spring"; then
```

> `_contains_type` 헬퍼는 본 step에서 이미 정의된 것 재사용.

- [ ] **Step 6: `copy_util_modules` 호출부도 배열 순회**

L2369, L2388 부근에서 `copy_util_modules "$PROJECT_TYPE"` 호출 → 배열 순회로 변경:

```bash
# 기존
copy_util_modules "$PROJECT_TYPE"

# 수정
_util_types=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
for _ut in "${_util_types[@]}"; do
    copy_util_modules "$_ut"
done
```

- [ ] **Step 7: 구문 검증**

```bash
bash -n template_integrator.sh && echo SYNTAX_OK
```

- [ ] **Step 8: 커밋**

```bash
git add template_integrator.sh
git commit -m "워크플로우/util 복사 + 안내 메시지 PROJECT_TYPES 배열 순회 : feat"
```

---

## Task 11: `template_integrator.sh` — `create_version_yml()` / `update_version_yml()` 두 키 작성

**Files:**
- Modify: `template_integrator.sh` — `create_version_yml`/`update_version_yml` 정의

- [ ] **Step 1: 함수 위치 식별**

```bash
grep -n "^create_version_yml\|^update_version_yml" template_integrator.sh
```

각 함수가 `project_type:` 단수 키만 쓰는 부분을 찾아 `project_types: ["$first"]`도 같이 작성.

- [ ] **Step 2: 두 함수 본체 수정 — 두 키 같이 작성**

`create_version_yml()` 안에서 version.yml에 작성하는 부분:

기존 패턴 (heredoc 또는 echo로 yaml 작성):
```bash
project_type: "$PROJECT_TYPE"
```

→ 수정:
```bash
project_types: [$(printf '"%s"' "${PROJECT_TYPES[@]:-$PROJECT_TYPE}" | sed 's/""/", "/g')]
project_type: "${PROJECT_TYPES[0]:-$PROJECT_TYPE}"
```

또는 더 단순하게 — `yq -i` 사용 가능하면:
```bash
# version.yml 초기 작성 후
local _csv=""
local IFS=','
_csv="${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
unset IFS
local _first="${PROJECT_TYPES[0]:-$PROJECT_TYPE}"

# yq 사용
local _types_json="[\"$(echo "$_csv" | sed 's/,/","/g')\"]"
yq -i ".project_types = $_types_json" version.yml
yq -i ".project_type = \"$_first\"" version.yml
```

> 정확한 함수 본체는 grep 결과에 따라 보강. 두 함수 모두 동일 패턴.

- [ ] **Step 3: 구문 검증 + 커밋**

```bash
bash -n template_integrator.sh && echo SYNTAX_OK
git add template_integrator.sh
git commit -m "create_version_yml/update_version_yml 두 키(project_types + project_type) 작성 : feat"
```

---

## Task 12: `template_integrator.ps1` — PowerShell 멀티타입 포팅

**Files:**
- Modify: `template_integrator.ps1`

- [ ] **Step 1: `$script:ProjectTypes` 배열 변수 신설**

`$script:ProjectType = ""` 선언 직후 추가:
```powershell
$script:ProjectType = ""
$script:ProjectTypes = @()
```

- [ ] **Step 2: `Detect-ProjectTypes` 신규 함수**

기존 `Detect-ProjectType` 직후에 추가:
```powershell
function Detect-ProjectTypes {
    $detected = @()
    if (Test-Path 'pubspec.yaml') { $detected += 'flutter' }
    if ((Test-Path 'build.gradle') -or (Test-Path 'build.gradle.kts') -or (Test-Path 'pom.xml')) { $detected += 'spring' }
    if ((Test-Path 'pyproject.toml') -or (Test-Path 'setup.py') -or (Test-Path 'requirements.txt')) { $detected += 'python' }
    if (Test-Path 'package.json') {
        if ((Test-Path 'next.config.js') -or (Test-Path 'next.config.ts') -or (Test-Path 'next.config.mjs')) {
            $detected += 'next'
        } elseif ((Test-Path 'ios') -and (Test-Path 'android')) {
            if ((Test-Path 'app.json') -and ((Get-Content 'app.json' -Raw) -match '"expo"')) {
                $detected += 'react-native-expo'
            } else {
                $detected += 'react-native'
            }
        } else {
            $pkg = Get-Content 'package.json' -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($pkg -and $pkg.dependencies.react) { $detected += 'react' } else { $detected += 'node' }
        }
    }
    if ($detected.Count -eq 0) { $detected = @('basic') }
    return ($detected -join ',')
}
```

- [ ] **Step 3: `Show-ProjectTypeMenu` multi 모드**

기존 함수 본체 전체를 다음으로 교체:
```powershell
function Show-ProjectTypeMenu {
    $preselect = ($script:ProjectTypes -join ',')
    $selected = Invoke-ChooseMenu -Multi -Preselect $preselect -Prompt "프로젝트 타입을 선택하세요 (멀티 가능)" -Options @(
        @{Value='spring';            Label='Spring Boot 백엔드'},
        @{Value='flutter';           Label='Flutter 모바일 앱'},
        @{Value='next';              Label='Next.js 웹 앱'},
        @{Value='react';             Label='React 웹 앱'},
        @{Value='react-native';      Label='React Native 모바일 앱'},
        @{Value='react-native-expo'; Label='React Native Expo 앱'},
        @{Value='node';              Label='Node.js 프로젝트'},
        @{Value='python';            Label='Python 프로젝트'},
        @{Value='basic';             Label='기타 프로젝트'}
    )
    if (-not $selected) {
        Print-Error "프로젝트 타입 선택이 취소되었습니다."
        return ($script:ProjectTypes -join ',')
    }
    return $selected
}
```

- [ ] **Step 4: `-Type` 인자 csv 파싱**

기존 `[string]$Type = ""` 파라미터를 `[string]$Type = ""`로 유지하되, 처리 시점에 csv 분해:

```powershell
if ($Type) {
    $arr = $Type.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $script:ProjectTypes = @($arr | Select-Object -Unique)
    foreach ($t in $script:ProjectTypes) {
        if ($script:ValidTypes -notcontains $t) {
            Print-Error "지원하지 않는 타입: '$t'"
            exit 1
        }
    }
    if ($script:ProjectTypes.Count -gt 0) {
        $script:ProjectType = $script:ProjectTypes[0]
    }
}
```

- [ ] **Step 5: Edit 메뉴 type case 수정**

기존:
```powershell
'type' {
    $script:ProjectType = Show-ProjectTypeMenu
    Print-Success "Project Type이 '$($script:ProjectType)'(으)로 변경되었습니다"
    Write-Host ""
}
```

→ 수정:
```powershell
'type' {
    $newCsv = Show-ProjectTypeMenu
    if ($newCsv) {
        $script:ProjectTypes = @($newCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $script:ProjectType = $script:ProjectTypes[0]
        if ($script:ProjectTypes.Count -gt 1) {
            Print-Success "Project Types가 '$($script:ProjectTypes -join ', ')'(으)로 변경되었습니다"
        } else {
            Print-Success "Project Type이 '$($script:ProjectType)'(으)로 변경되었습니다"
        }
    }
    Write-Host ""
}
```

- [ ] **Step 6: 워크플로우/util 복사 배열 순회 (PS)**

sh의 Task 10 변경을 PS에 대응. `Copy-Workflows`, `Copy-UtilModules` 등 호출부에서 `$script:ProjectTypes` 배열 순회:

```powershell
$typesToCopy = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
foreach ($t in $typesToCopy) {
    Copy-Workflows-ForType $t   # 기존 단일 처리를 함수로 추출
}
```

> sh와 동일한 헬퍼 함수 패턴 (`_copy_workflows_for_type` ↔ `Copy-Workflows-ForType`).

- [ ] **Step 7: `Create-VersionYml` / `Update-VersionYml` 두 키 작성**

기존 yaml 작성 부분에 `project_types: ["..."]` 라인 추가. yq가 PowerShell에 없으므로 yaml 직접 텍스트 빌드:

```powershell
$typesJson = '[' + (($script:ProjectTypes | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']'
$firstType = $script:ProjectTypes[0]

$yaml = @"
version: "$Version"
version_code: $VersionCode
project_types: $typesJson
project_type: "$firstType"
metadata:
  last_updated: "$timestamp"
  last_updated_by: "$user"
"@
```

- [ ] **Step 8: 구문 검증 + 커밋**

```powershell
[System.Management.Automation.Language.Parser]::ParseFile('D:\0-suh\project\suh-github-template\template_integrator.ps1', [ref]$null, [ref]$null) | Out-Null; 'OK'
```

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 멀티타입 포팅 : feat : sh와 동일 로직"
```

---

## Task 13: `changelog_manager.py` — `PROJECT_TYPES` env 받아 배열 기록

**Files:**
- Modify: `.github/scripts/changelog_manager.py:229~312`

- [ ] **Step 1: env 읽기 + release/metadata 작성 수정**

기존:
```python
project_type = os.environ.get('PROJECT_TYPE')
...
new_release = {
    "version": version,
    "project_type": project_type,
    "date": today,
    "pr_number": pr_number,
    ...
}
...
"projectType": project_type,
...
changelog_data["metadata"]["projectType"] = project_type
```

→ 수정:
```python
project_type = os.environ.get('PROJECT_TYPE', 'basic')
project_types_csv = os.environ.get('PROJECT_TYPES', '')
project_types = [t.strip() for t in project_types_csv.split(',') if t.strip()]
if not project_types:
    project_types = [project_type]

# release 항목
new_release = {
    "version": version,
    "project_type": project_type,            # 기존 단수 — 유지
    "project_types": project_types,          # 신규 배열
    "date": today,
    "pr_number": pr_number,
    ...
}

# metadata
"projectType": project_type,
"projectTypes": project_types,               # 신규
...
changelog_data["metadata"]["projectType"] = project_type
changelog_data["metadata"]["projectTypes"] = project_types
```

> 정확한 dict 위치는 함수 본체에 맞춰 변수 정의 부분 + dict 두 곳에 같이 반영.

- [ ] **Step 2: 구문 검증**

```bash
python -m py_compile .github/scripts/changelog_manager.py && echo SYNTAX_OK
```
Expected: `SYNTAX_OK`

- [ ] **Step 3: 커밋**

```bash
git add .github/scripts/changelog_manager.py
git commit -m "changelog_manager.py 멀티타입 기록 : feat : PROJECT_TYPES env + 배열 기록"
```

---

## Task 14: `PROJECT-COMMON-VERSION-CONTROL.yaml` — `project_types` step output

**Files:**
- Modify: `.github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml:90-98`
- Modify: `.github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml` (동일 변경)

- [ ] **Step 1: step output 추가**

기존:
```yaml
        run: |
          if [ -f "version.yml" ]; then
            PROJECT_TYPE=$(grep "^project_type:" version.yml | sed 's/project_type: *"\([^"]*\)".*/\1/')
            echo "project_type=$PROJECT_TYPE" >> $GITHUB_OUTPUT
            echo "프로젝트 타입: $PROJECT_TYPE"
          else
            echo "project_type=unknown" >> $GITHUB_OUTPUT
            echo "⚠️ version.yml 파일을 찾을 수 없습니다."
          fi
```

→ 수정:
```yaml
        run: |
          if [ -f "version.yml" ]; then
            PROJECT_TYPE=$(grep "^project_type:" version.yml | sed 's/project_type: *"\([^"]*\)".*/\1/')
            PROJECT_TYPES=$(grep "^project_types:" version.yml 2>/dev/null | sed -E 's/.*\[([^]]*)\].*/\1/' | tr -d '" ' || echo "")
            [ -z "$PROJECT_TYPES" ] && PROJECT_TYPES="$PROJECT_TYPE"
            echo "project_type=$PROJECT_TYPE" >> $GITHUB_OUTPUT
            echo "project_types=$PROJECT_TYPES" >> $GITHUB_OUTPUT
            echo "프로젝트 타입: $PROJECT_TYPE (배열: $PROJECT_TYPES)"
          else
            echo "project_type=unknown" >> $GITHUB_OUTPUT
            echo "project_types=unknown" >> $GITHUB_OUTPUT
            echo "⚠️ version.yml 파일을 찾을 수 없습니다."
          fi
```

- [ ] **Step 2: 동일 변경을 `project-types/common/` 원본에도 적용**

`.github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml`에 Step 1과 동일 패치.

- [ ] **Step 3: YAML 문법 검증**

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml',encoding='utf-8'))" && echo YAML_OK
python -c "import yaml; yaml.safe_load(open('.github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml',encoding='utf-8'))" && echo YAML_OK
```

- [ ] **Step 4: 커밋**

```bash
git add .github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml .github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml
git commit -m "VERSION-CONTROL 워크플로우 project_types step output 추가 : feat"
```

---

## Task 15: `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` — `project_types` step output + env 전달

**Files:**
- Modify: `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml:47, 116-120, 362-365`
- Modify: `.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` (동일)

- [ ] **Step 1: `outputs` 섹션에 `project_types` 추가 (L47 부근)**

기존:
```yaml
    outputs:
      summary_found: ${{ steps.detect_summary.outputs.summary_found }}
      version: ${{ steps.get_version.outputs.version }}
      project_type: ${{ steps.get_version.outputs.project_type }}
```

→ 수정:
```yaml
    outputs:
      summary_found: ${{ steps.detect_summary.outputs.summary_found }}
      version: ${{ steps.get_version.outputs.version }}
      project_type: ${{ steps.get_version.outputs.project_type }}
      project_types: ${{ steps.get_version.outputs.project_types }}
```

- [ ] **Step 2: `get_version` step (L114-120 부근)에 `project_types` 파싱 추가**

기존:
```yaml
          # version.yml에서 프로젝트 타입 확인
          if [ -f "version.yml" ] && [ "$PROJECT_TYPE" = "unknown" ]; then
            PROJECT_TYPE=$(grep "^project_type:" version.yml | sed 's/project_type: *"\([^"]*\)".*/\1/' || echo "unknown")
          fi

          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "project_type=$PROJECT_TYPE" >> $GITHUB_OUTPUT
          echo "✅ 버전: $VERSION, 프로젝트 타입: $PROJECT_TYPE"
```

→ 수정:
```yaml
          # version.yml에서 프로젝트 타입 확인
          if [ -f "version.yml" ] && [ "$PROJECT_TYPE" = "unknown" ]; then
            PROJECT_TYPE=$(grep "^project_type:" version.yml | sed 's/project_type: *"\([^"]*\)".*/\1/' || echo "unknown")
          fi
          PROJECT_TYPES=$(grep "^project_types:" version.yml 2>/dev/null | sed -E 's/.*\[([^]]*)\].*/\1/' | tr -d '" ' || echo "")
          [ -z "$PROJECT_TYPES" ] && PROJECT_TYPES="$PROJECT_TYPE"

          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "project_type=$PROJECT_TYPE" >> $GITHUB_OUTPUT
          echo "project_types=$PROJECT_TYPES" >> $GITHUB_OUTPUT
          echo "✅ 버전: $VERSION, 프로젝트 타입: $PROJECT_TYPE (배열: $PROJECT_TYPES)"
```

- [ ] **Step 3: `changelog_manager.py` 호출 step (L362-365 부근)에 env 추가**

기존:
```yaml
          PROJECT_TYPE="${{ needs.detect-and-parse.outputs.project_type }}"
          TODAY=$(date '+%Y-%m-%d')
```

→ 수정:
```yaml
          PROJECT_TYPE="${{ needs.detect-and-parse.outputs.project_type }}"
          PROJECT_TYPES="${{ needs.detect-and-parse.outputs.project_types }}"
          TODAY=$(date '+%Y-%m-%d')
```

같은 step의 `env:` (있다면) 또는 inline 호출 시 `PROJECT_TYPES`도 export하도록:
```yaml
          export PROJECT_TYPES
          # 기존 changelog_manager.py 호출
```

> 정확한 step 본체에 따라 export 위치 조정. 기존 코드가 `PROJECT_TYPE=... python ...` 형태면 `PROJECT_TYPE=... PROJECT_TYPES=... python ...` 로 그대로 한 줄에 인라인 가능.

- [ ] **Step 4: 동일 변경을 원본 폴더에도 적용**

`.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`에 Step 1~3 동일 패치.

- [ ] **Step 5: YAML 문법 검증**

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml',encoding='utf-8'))" && echo YAML_OK
python -c "import yaml; yaml.safe_load(open('.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml',encoding='utf-8'))" && echo YAML_OK
```

- [ ] **Step 6: 커밋**

```bash
git add .github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml .github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml
git commit -m "AUTO-CHANGELOG-CONTROL project_types output + env 전달 : feat"
```

---

## Task 16: 문서 — `TEMPLATE-INTEGRATOR.md`, `VERSION-CONTROL.md`, `SYNOLOGY-DEPLOYMENT-GUIDE.md`, `CONTRIBUTING.md`, `CLAUDE.md`

**Files:**
- Modify: `docs/TEMPLATE-INTEGRATOR.md`
- Modify: `docs/VERSION-CONTROL.md`
- Modify: `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md`
- Modify: `CONTRIBUTING.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: `docs/TEMPLATE-INTEGRATOR.md` 멀티 사용 예시 추가**

`--type` 옵션 설명 섹션을 찾아 csv 예시 추가:

```markdown
## 멀티 프로젝트 타입

하나의 레포에 여러 타입이 공존하는 경우 csv로 지정:

\`\`\`bash
./template_integrator.sh --mode full --type spring,react,python --version 1.0.0
\`\`\`

- 자동 감지 시 모든 일치 타입을 반환 → 사용자가 다중 선택 메뉴로 확정
- `version.yml`에 `project_types: ["spring", "react", "python"]` 배열로 저장
- `project_type` 단수 키는 배열 첫 항목 자동 미러 (직접 수정 금지)

### CI 트리거 주의

여러 타입의 `*-CI.yaml`이 동시에 main push에 발화한다. 멀티 레포에서는 각 워크플로우의 `paths:` 필터를 수동 추가하여 디렉토리별 분리를 권장한다:

\`\`\`yaml
on:
  push:
    branches: [main]
    paths:
      - 'backend/**'    # Spring
\`\`\`
```

- [ ] **Step 2: `docs/VERSION-CONTROL.md` `project_types` 키 설명**

`project_type` 설명 섹션 직후에 추가:

```markdown
### `project_types` (배열, 신규)

멀티 프로젝트 타입을 지원하기 위한 배열 키:

\`\`\`yaml
project_types: ["spring", "react", "python"]
project_type: "spring"   # project_types[0] 자동 미러
\`\`\`

- 단일 타입도 배열 형태로 통일 (`project_types: ["basic"]`)
- 기존 단수 키만 있는 version.yml도 100% 하위 호환
- `version_manager.sh`가 배열 순회로 모든 타입의 sync 파일 동기화
```

- [ ] **Step 3: `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` 멀티 안내**

배포 시 포트·이름 분리 주의사항 섹션 추가:

```markdown
## 멀티 프로젝트 타입 배포 시

여러 타입의 SYNOLOGY-CICD 워크플로우가 동시에 깔리면:
- 각 워크플로우의 `PROJECT_NAME`, `CONTAINER_NAME`, `DEPLOY_PORT`를 **서로 다른 값**으로 설정 필요
- 동일 NAS에 같은 포트로 두 컨테이너 배포 불가
- Spring 백엔드 8096, Python AI 8092 등 포트 분리 후 사용
```

- [ ] **Step 4: `CONTRIBUTING.md` 멀티타입 노트**

`Skill routing` 섹션 또는 `워크플로우 추가 시` 섹션에 추가:

```markdown
### 멀티타입 지원

`version.yml`에 `project_types` 배열 키가 있을 경우:
- 단수 `project_type` 키는 항상 첫 항목 자동 미러
- 새 워크플로우/스크립트가 타입에 분기할 때 `project_types` 배열 우선 읽기
- 기존 단수 키만 읽는 코드는 그대로 동작 (하위 호환)
```

- [ ] **Step 5: `CLAUDE.md` 짧은 설명 추가**

`지원 프로젝트 타입` 표 직후에 한 줄 추가:

```markdown
> **멀티타입**: 단일 레포에 여러 타입 공존 시 `--type spring,react,python` csv 지정. `version.yml`의 `project_types` 배열로 저장.
```

- [ ] **Step 6: 커밋**

```bash
git add docs/TEMPLATE-INTEGRATOR.md docs/VERSION-CONTROL.md docs/SYNOLOGY-DEPLOYMENT-GUIDE.md CONTRIBUTING.md CLAUDE.md
git commit -m "멀티타입 문서 추가 : docs : 사용법·주의사항 안내"
```

---

## Task 17: 통합 수동 테스트

**Files:** 없음 (실행 검증)

- [ ] **Step 1: 단일 타입 회귀 (기존 동작)**

임시 디렉토리에서:
```bash
mkdir -p /tmp/test-single && cd /tmp/test-single
echo '{"version":"1.0.0","name":"test"}' > package.json
git init -q
bash D:/0-suh/project/suh-github-template/template_integrator.sh --mode version --type react --version 2.0.0 --force
```
Expected: 정상 종료, `version.yml`에 `project_types: ["react"]` + `project_type: "react"` 둘 다 작성됨. `package.json` 2.0.0.

- [ ] **Step 2: 멀티 타입 CLI**

```bash
mkdir -p /tmp/test-multi && cd /tmp/test-multi
echo '{"version":"1.0.0","name":"test"}' > package.json
mkdir -p src && echo "version = '1.0.0'" > build.gradle
git init -q
bash D:/0-suh/project/suh-github-template/template_integrator.sh --mode version --type spring,react --version 3.0.0 --force
```
Expected: `version.yml`에 `project_types: ["spring", "react"]` + `project_type: "spring"`. `build.gradle`과 `package.json` 둘 다 3.0.0 (version_manager.sh 실행 시 — 본 task는 integrator만 검증, manager는 다음 step).

- [ ] **Step 3: `version_manager.sh` 멀티 sync**

위 Step 2 디렉토리에서:
```bash
bash D:/0-suh/project/suh-github-template/.github/scripts/version_manager.sh set 4.0.0
```
Expected: `version.yml` 4.0.0, `build.gradle` 4.0.0, `package.json` 4.0.0 모두 sync.

- [ ] **Step 4: 정합화 검증**

`version.yml`의 `project_type`을 임의로 잘못된 값(`project_type: "zzz"`)으로 수정 후:
```bash
bash D:/0-suh/project/suh-github-template/.github/scripts/version_manager.sh get
```
Expected: `project_type`이 `project_types[0]`인 `spring`으로 자동 복구.

- [ ] **Step 5: 자동 감지 multi**

```bash
mkdir -p /tmp/test-detect && cd /tmp/test-detect
echo "version = '1.0.0'" > build.gradle
echo '{"version":"1.0.0","name":"test"}' > package.json
git init -q
bash D:/0-suh/project/suh-github-template/template_integrator.sh
# 인터랙티브 → 화면 출력 확인 (spring + node 또는 react 동시 감지)
# ESC로 빠져나옴
```

- [ ] **Step 6: 다중 선택 메뉴 동작 (TTY)**

위 디렉토리에서 인터랙티브 실행 → Edit → Project Type → 다중 선택 메뉴 확인. Space 토글, Enter csv 확정, ESC 취소.

- [ ] **Step 7: PowerShell 동일 검증**

```powershell
. D:\0-suh\project\suh-github-template\template_integrator.ps1 -Mode version -Type 'spring,react' -Version '5.0.0' -Force
```
Expected: 위와 동일 동작.

- [ ] **Step 8: 비TTY fallback**

```bash
echo "1,3" | bash D:/0-suh/project/suh-github-template/template_integrator.sh --mode version --version 6.0.0
```
> 자동 감지 → fallback 메뉴에서 csv 입력 → 멀티 적용 확인.

- [ ] **Step 9: legacy version.yml 하위 호환**

```bash
mkdir -p /tmp/test-legacy && cd /tmp/test-legacy
cat > version.yml <<'EOF'
version: "1.0.0"
version_code: 1
project_type: "spring"
metadata:
  last_updated: "2026-01-01 00:00:00"
EOF
echo "version = '1.0.0'" > build.gradle
git init -q
bash D:/0-suh/project/suh-github-template/.github/scripts/version_manager.sh get
```
Expected: 정상 동작, `project_type: "spring"`만 읽어 단일 sync.

- [ ] **Step 10: 최종 정리 커밋 (필요 시)**

테스트 중 사소한 수정 있으면:
```bash
git add -A
git status
git commit -m "멀티타입 통합 회귀 테스트 통과 보강 : test"
```

---

## Self-Review Notes

- **Spec coverage:**
  - `version.yml` 스키마 변경 → Task 3, 4, 11, 12
  - 자동 동기화 정합화 → Task 5 (`sync_project_type_field`)
  - 자동 감지 → Task 6, 12
  - 사용자 확인 흐름 → Task 8, 12
  - 다중 선택 메뉴 → Task 1, 2
  - CLI csv 옵션 → Task 7, 12
  - 워크플로우 복사 배열 순회 → Task 10, 12
  - util 모듈 배열 순회 → Task 10, 12
  - 안내 메시지 배열 순회 → Task 10, 12
  - 최종 요약 prefix 매칭 → Task 10
  - `version_manager.sh` 멀티 sync → Task 5
  - `changelog_manager.py` 배열 기록 → Task 13
  - 워크플로우 step output → Task 14, 15
  - `template_initializer.sh` 두 키 작성 → Task 4
  - 문서 → Task 16
  - 통합 테스트 → Task 17

- **Placeholder scan:** 모든 step에 구체 코드/명령 명시. Task 10 Step 1의 헬퍼 함수 본체는 기존 코드(L1593~L1762)를 그대로 옮기는 거라 "기존 로직 그대로"라고 표기 — placeholder가 아니라 "옮기는 위치" 명시.

- **Type consistency:**
  - sh `PROJECT_TYPES` (배열) ↔ ps1 `$script:ProjectTypes` (배열)
  - sh `PROJECT_TYPES_CSV` (csv string, version_manager.sh) ↔ ps1 (-Multi로 csv string 반환)
  - 출력 csv 포맷 일관 (양 언어 모두 `value1,value2,value3`)

- **Scope:** 단일 plan 적정 (17 tasks). 더 작게 쪼개도 됐지만 task 사이 의존성(menu 컴포넌트 ← 메뉴 호출 ← 자동 감지) 명확.
