# 타입 수정 메뉴 스마트 추천·path 자동 연결 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이미 init된 레포에서 타입 수정 메뉴에 들어가면 레포를 스캔해 타입을 추천하고, 타입 선택 직후 path 감지를 자동으로 이어 붙인다.

**Architecture:** `template_integrator.sh`(원본)와 `template_integrator.ps1`(포팅)에 동일 변경을 적용한다. 마커가 없을 때 확장자 빈도로 타입을 추천하는 순수 함수를 신규 추가하고, 타입 선택 메뉴 진입 시 추천 로그를 쌓는다. 타입 수정 케이스에서 `resolve_project_paths`를 즉시 호출해 흐름을 연결하고, path 루프에 진행표시를 더한다. 모든 출력은 append-only 로그 방식이다.

**Tech Stack:** Bash 3.2 호환 / PowerShell 5.1 호환. 테스트는 기존 `.github/scripts/test/*.sh` 패턴(`mktemp -d` + 함수 source + `chk`).

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `template_integrator.sh` | 통합 원본 스크립트 | source 가드 추가, `suggest_types_by_scan` 신규, 메뉴 추천 블록, 타입 수정 path 연결, 진행표시, 문구 정리 |
| `template_integrator.ps1` | PowerShell 포팅 | 위와 1:1 대칭 (`Get-SuggestedTypesByScan` 등) |
| `.github/scripts/test/test_integrator_suggest.sh` | `suggest_types_by_scan` 단위 테스트 | 신규 |

**참고**: spec은 `docs/superpowers/specs/2026-06-11-type-edit-smart-recommend-design.md`.

---

### Task 1: source 가드 추가 (테스트 가능하게)

`template_integrator.sh` 끝의 `main "$@"`가 무조건 실행되어 함수만 source할 수 없다. source 시 main이 돌지 않도록 가드를 추가한다.

**Files:**
- Modify: `template_integrator.sh:4072`

- [ ] **Step 1: 현재 마지막 줄 확인**

Run: `tail -3 template_integrator.sh`
Expected: 마지막이 `main "$@"`

- [ ] **Step 2: source 가드로 교체**

`template_integrator.sh`의 맨 끝 부분에서:

```bash
# 스크립트 실행
main "$@"
```

를 다음으로 교체:

```bash
# 스크립트 실행 (source될 때는 main을 돌리지 않음 — 함수 단위 테스트 가능)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
```

- [ ] **Step 3: 직접 실행은 여전히 동작하는지 구문 검사**

Run: `bash -n template_integrator.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 4: source 시 main이 안 도는지 확인**

Run: `bash -c 'source template_integrator.sh; echo SOURCED_OK; type suggest_types_by_scan 2>/dev/null || echo NO_FUNC_YET'`
Expected: `SOURCED_OK` 출력 후 `NO_FUNC_YET` (함수는 Task 2에서 추가). main 배너가 출력되지 않아야 함.

- [ ] **Step 5: Commit**

```bash
git add template_integrator.sh
git commit -m "template_integrator source 가드 추가 : refactor : source 시 main 미실행으로 함수 단위 테스트 가능하게 변경"
```

---

### Task 2: suggest_types_by_scan 함수 (sh) + 단위 테스트

마커가 없을 때 확장자 빈도로 타입을 추천하는 순수 함수. stdout에 csv(예: `python,node`)를 출력하고, 추천 없으면 빈 문자열.

**Files:**
- Modify: `template_integrator.sh` (`detect_project_types` 함수 바로 뒤, 956줄 이후에 삽입)
- Test: `.github/scripts/test/test_integrator_suggest.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

Create `.github/scripts/test/test_integrator_suggest.sh`:

```bash
#!/bin/bash
# suggest_types_by_scan 단위 테스트
# 실행: bash .github/scripts/test/test_integrator_suggest.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/../../.." && pwd)/template_integrator.sh"
PASS=0
FAIL=0

# 함수만 source (Task 1 source 가드 덕분에 main 안 돎)
source "$SCRIPT" >/dev/null 2>&1

chk() {
  local d="$1" a="$2" e="$3"
  if [ "$a" = "$e" ]; then
    echo "  PASS: $d"; PASS=$((PASS+1))
  else
    echo "  FAIL: $d (got: '$a', want: '$e')"; FAIL=$((FAIL+1))
  fi
}

new_workdir() { WORK=$(mktemp -d); cd "$WORK" || exit 1; }

echo "=== (1) .py 4개 → python 추천 ==="
new_workdir
for i in 1 2 3 4; do echo "print($i)" > "mod$i.py"; done
chk "python 추천" "$(suggest_types_by_scan)" "python"

echo "=== (2) .py 2개(임계 미만) → 추천 없음 ==="
new_workdir
echo "x" > a.py; echo "y" > b.py
chk "임계 미만 빈 추천" "$(suggest_types_by_scan)" ""

echo "=== (3) .dart 1개 → flutter 추천 ==="
new_workdir
echo "void main(){}" > main.dart
chk "flutter 추천(.dart 임계 1)" "$(suggest_types_by_scan)" "flutter"

echo "=== (4) .tsx 3개 → react 추천 ==="
new_workdir
for i in 1 2 3; do echo "export default ()=>null" > "c$i.tsx"; done
chk "react 추천" "$(suggest_types_by_scan)" "react"

echo "=== (5) .js 3개(react/flutter/python/spring 없음) → node 추천 ==="
new_workdir
for i in 1 2 3; do echo "console.log($i)" > "s$i.js"; done
chk "node 추천(fallback)" "$(suggest_types_by_scan)" "node"

echo "=== (6) node_modules 안의 .py는 제외 ==="
new_workdir
mkdir -p node_modules/pkg
for i in 1 2 3 4; do echo "x" > "node_modules/pkg/m$i.py"; done
chk "제외 폴더 무시 → 빈 추천" "$(suggest_types_by_scan)" ""

echo ""
echo "=== 결과: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: FAIL — `suggest_types_by_scan: command not found` 또는 전 케이스 FAIL (함수 미존재)

- [ ] **Step 3: suggest_types_by_scan 구현**

`template_integrator.sh`의 `detect_project_types` 함수가 끝나는 `}` 바로 다음(956줄 부근, "타입별 프로젝트 경로" 주석 블록 직전)에 삽입:

```bash
# 마커 파일이 없을 때 확장자·특징 파일 빈도로 타입을 추천 (스캔 추천)
# stdout: 추천 타입 csv (예: "python,node"), 추천 없으면 빈 문자열
# detect_project_types가 basic만 반환했을 때 보조로만 쓴다 — 강제 아님(안내용).
suggest_types_by_scan() {
    # 잡음 폴더 제외하고 maxdepth 3로 파일을 모아 확장자 카운트
    local _files
    _files=$(find . -maxdepth 3 \
        \( -name node_modules -o -name .git -o -name build -o -name dist \
           -o -name .dart_tool -o -name android -o -name ios -o -name .gradle \
           -o -name venv -o -name .venv -o -name __pycache__ \) -prune \
        -o -type f -print 2>/dev/null)

    local _dart _java _kt _gradle _tsx _jsx _py _ts _js
    _dart=$(printf '%s\n' "$_files"   | grep -c '\.dart$')
    _java=$(printf '%s\n' "$_files"   | grep -c '\.java$')
    _kt=$(printf '%s\n' "$_files"     | grep -c '\.kt$')
    _gradle=$(printf '%s\n' "$_files" | grep -c '\.gradle$')
    _tsx=$(printf '%s\n' "$_files"    | grep -c '\.tsx$')
    _jsx=$(printf '%s\n' "$_files"    | grep -c '\.jsx$')
    _py=$(printf '%s\n' "$_files"     | grep -c '\.py$')
    _ts=$(printf '%s\n' "$_files"     | grep -c '\.ts$')
    _js=$(printf '%s\n' "$_files"     | grep -c '\.js$')

    local _out=""
    # flutter: .dart 임계 1 (고유 확장자라 오탐 적음)
    [ "$_dart" -ge 1 ] && _out="${_out:+$_out,}flutter"
    # spring: .java/.kt/.gradle 합산 임계 3
    [ $((_java + _kt + _gradle)) -ge 3 ] && _out="${_out:+$_out,}spring"
    # react: .tsx/.jsx 합산 임계 3
    [ $((_tsx + _jsx)) -ge 3 ] && _out="${_out:+$_out,}react"
    # python: .py 임계 3
    [ "$_py" -ge 3 ] && _out="${_out:+$_out,}python"
    # node: 위 어떤 추천도 없을 때만, .ts/.js 합산 임계 3
    if [ -z "$_out" ] && [ $((_ts + _js)) -ge 3 ]; then
        _out="node"
    fi

    echo "$_out"
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: 전 케이스 PASS, 마지막 `PASS=6 FAIL=0`

- [ ] **Step 5: 구문 검사**

Run: `bash -n template_integrator.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 6: Commit**

```bash
git add template_integrator.sh .github/scripts/test/test_integrator_suggest.sh
git commit -m "template_integrator 확장자 스캔 타입 추천 함수 추가 : feat : 마커 없는 레포에서 .dart·.py·.tsx 등 빈도로 타입 추천하는 suggest_types_by_scan + 단위 테스트 6케이스"
```

---

### Task 3: 타입 선택 메뉴 추천 블록 (sh)

`show_project_type_menu` 진입 시 레포 스캔 결과를 로그로 쌓는다. 마커 발견 타입은 preselect, 스캔 추천은 안내만.

**Files:**
- Modify: `template_integrator.sh:1396-1426` (`show_project_type_menu`)

- [ ] **Step 1: 현재 함수 확인**

Run: `sed -n '1396,1426p' template_integrator.sh`
Expected: 기존 `show_project_type_menu` 본문 표시

- [ ] **Step 2: 추천 블록 + preselect 연동으로 교체**

`show_project_type_menu` 함수 전체를 다음으로 교체:

```bash
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

    local selected
    selected=$(choose_menu --multi --preselect="$_preselect" "프로젝트 타입을 선택하세요" \
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
        local IFS=','
        echo "${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
        unset IFS
        return 1
    fi

    echo "$selected"
}
```

- [ ] **Step 3: 구문 검사**

Run: `bash -n template_integrator.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 4: 추천 로그가 stderr로 나가고 selected만 stdout인지 확인**

`show_project_type_menu`는 stdout으로 선택 csv만 반환해야 한다(호출측이 `$(...)`로 받음). 추천 로그는 전부 `>&2`. 시각 확인:

Run: `grep -n 'print_to_user.*>&2' template_integrator.sh | grep -c '추천\|살펴봤\|현재 값\|찾지 못'`
Expected: `4` 이상 (추천 로그 라인들이 모두 `>&2`로 리다이렉트됨)

- [ ] **Step 5: Commit**

```bash
git add template_integrator.sh
git commit -m "template_integrator 타입 선택 메뉴 추천 블록 추가 : feat : 마커 발견 시 자동 preselect·확장자 스캔 추천 안내·현재값 표시를 append-only 로그로 출력, Space 토글 문구 제거"
```

---

### Task 4: 타입 수정 직후 path 자동 연결 (sh)

`handle_project_edit_menu`의 `type` 케이스에서 타입이 바뀌면 즉시 `resolve_project_paths`를 호출한다.

**Files:**
- Modify: `template_integrator.sh:1516-1529` (`type)` 케이스)

- [ ] **Step 1: 현재 type 케이스 확인**

Run: `sed -n '1515,1530p' template_integrator.sh`
Expected: 기존 `type)` 케이스 (타입만 바꾸고 path 호출 없음)

- [ ] **Step 2: path 자동 연결 추가**

`type)` 케이스 블록을 다음으로 교체:

```bash
        type)
            local _old_csv
            local IFS=','
            _old_csv="${PROJECT_TYPES[*]:-$PROJECT_TYPE}"
            unset IFS

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

                # ★ 타입이 실제로 바뀌었으면 그 자리에서 path 감지를 바로 이어 붙임
                if [ "$_new_csv" != "$_old_csv" ]; then
                    PROJECT_PATHS_CSV=""   # 새 타입 기준으로 다시 잡도록 초기화
                    resolve_project_paths
                fi
            fi
            print_to_user ""
            ;;
```

- [ ] **Step 3: 구문 검사**

Run: `bash -n template_integrator.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 4: basic 유지 시 path 미호출 로직 확인**

`resolve_project_paths`는 basic을 `_targets`에서 제외하고 `[ ${#_targets[@]} -eq 0 ] && return 0` 한다. 즉 basic→basic이면 `_new_csv == _old_csv`라 호출 자체를 안 하고, 설령 호출돼도 즉시 return. 코드 확인:

Run: `grep -n 'targets\[@\]} -eq 0 ] && return 0' template_integrator.sh`
Expected: 해당 가드 라인이 존재

- [ ] **Step 5: Commit**

```bash
git add template_integrator.sh
git commit -m "template_integrator 타입 수정 직후 path 자동 감지 연결 : feat : 수정 메뉴에서 타입이 바뀌면 resolve_project_paths를 즉시 호출해 타입→경로를 한 흐름으로, basic 유지 시 미호출"
```

---

### Task 5: 멀티 path 진행표시 + 문구 정리 (sh)

`resolve_project_paths` 타입별 루프에 `[n/N]` 카운터를 붙이고, `detect_project_types`의 "(멀티 지원)" 문구를 정리한다.

**Files:**
- Modify: `template_integrator.sh:913` (`detect_project_types` print_step)
- Modify: `template_integrator.sh:1128` (path 루프 시작)

- [ ] **Step 1: "(멀티 지원)" 문구 제거**

`template_integrator.sh`에서:

```bash
    print_step "프로젝트 타입 자동 감지 중... (멀티 지원)"
```

를:

```bash
    print_step "프로젝트 타입 자동 감지 중..."
```

- [ ] **Step 2: path 루프에 진행표시 추가**

`resolve_project_paths`의 타입 루프를 찾는다:

Run: `grep -n 'for _t in "${_targets\[@\]}"; do' template_integrator.sh`
Expected: 1128줄 부근 (path 확정 루프)

해당 루프(`print_step "타입별 프로젝트 경로 확인 중..."` 다음에 오는 두 번째 `for _t in "${_targets[@]}"; do`)의 시작 직후에 카운터를 추가한다. 루프 헤더를 다음으로 교체:

```bash
    local _total=${#_targets[@]}
    local _idx=0
    for _t in "${_targets[@]}"; do
        _idx=$((_idx + 1))
        local _prog="[$_idx/$_total]"
```

그리고 같은 루프 안의 후보 안내 출력 3곳에 `$_prog`를 접두로 붙인다:

- `print_to_user "  🔍 $_t: ${_candidates}/...` → `print_to_user "  $_prog 🔍 $_t: ${_candidates}/...`
- `print_to_user "  🔍 $_t: 후보 ${_count}개 발견"` → `print_to_user "  $_prog 🔍 $_t: 후보 ${_count}개 발견"`
- `print_warning "  $_t: 프로젝트를 찾지 못했습니다 (maxdepth 3)."` → `print_warning "  $_prog $_t: 프로젝트를 찾지 못했습니다 (maxdepth 3)."`

> 주의: `_prog`/`_idx`/`_total`은 루프 안에서 `local`로 선언하되 `_total`·`_idx`는 루프 진입 전에 선언한다(위 교체 블록이 루프 헤더를 포함). 루프 내부에서 `local _prog=...`는 매 반복 재선언이라 bash에서 안전하다.

- [ ] **Step 3: 구문 검사**

Run: `bash -n template_integrator.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 4: 진행표시 문자열이 들어갔는지 확인**

Run: `grep -c '_prog' template_integrator.sh`
Expected: `5` 이상 (선언 1 + 헤더 1 + 사용 3)

- [ ] **Step 5: 기존 path 테스트 회귀 확인**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: `PASS=6 FAIL=0` (Task 2 테스트 영향 없음)

- [ ] **Step 6: Commit**

```bash
git add template_integrator.sh
git commit -m "template_integrator 멀티 path 진행표시·문구 정리 : feat : 타입별 경로 질문에 [n/N] 카운터 추가하고 감지 단계 (멀티 지원) 잉여 문구 제거"
```

---

### Task 6: PowerShell 대칭 적용 (ps1)

Task 2~5의 변경을 `template_integrator.ps1`에 1:1 대칭으로 포팅한다. ps1은 source 가드가 불필요(함수 단위 테스트 안 함, sh 테스트로 로직 검증됨)하므로 Task 1 대응은 생략.

**Files:**
- Modify: `template_integrator.ps1` (`Detect-ProjectTypes`, `Show-ProjectTypeMenu`, `Edit-ProjectInfo` type 케이스, `Resolve-ProjectPaths`)

- [ ] **Step 1: Get-SuggestedTypesByScan 신규 함수 추가**

`Detect-ProjectTypes` 함수가 끝나는 `}` 다음(696줄 부근, "타입별 프로젝트 경로" 주석 직전)에 삽입:

```powershell
# 마커 파일이 없을 때 확장자·특징 파일 빈도로 타입을 추천 (스캔 추천)
# 반환: 추천 타입 csv (예: "python,node"), 추천 없으면 빈 문자열
function Get-SuggestedTypesByScan {
    $files = @(Get-ChildItem -Path . -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $script:PathExcludeRegex })

    $dart   = @($files | Where-Object { $_.Extension -eq '.dart' }).Count
    $java   = @($files | Where-Object { $_.Extension -eq '.java' }).Count
    $kt     = @($files | Where-Object { $_.Extension -eq '.kt' }).Count
    $gradle = @($files | Where-Object { $_.Extension -eq '.gradle' }).Count
    $tsx    = @($files | Where-Object { $_.Extension -eq '.tsx' }).Count
    $jsx    = @($files | Where-Object { $_.Extension -eq '.jsx' }).Count
    $py     = @($files | Where-Object { $_.Extension -eq '.py' }).Count
    $ts     = @($files | Where-Object { $_.Extension -eq '.ts' }).Count
    $js     = @($files | Where-Object { $_.Extension -eq '.js' }).Count

    $out = @()
    if ($dart -ge 1) { $out += 'flutter' }
    if (($java + $kt + $gradle) -ge 3) { $out += 'spring' }
    if (($tsx + $jsx) -ge 3) { $out += 'react' }
    if ($py -ge 3) { $out += 'python' }
    if ($out.Count -eq 0 -and ($ts + $js) -ge 3) { $out += 'node' }

    return ($out -join ',')
}
```

- [ ] **Step 2: Show-ProjectTypeMenu 추천 블록 추가**

`Show-ProjectTypeMenu`(1056줄 부근)의 `$preselect = ...` 줄 **앞에** 추천 블록을 삽입하고 preselect 로직을 교체:

```powershell
function Show-ProjectTypeMenu {
    # ── 레포 스캔 → 추천 로그 (append-only) ──
    $detectedCsv = Detect-ProjectTypes
    Write-Host ""
    Write-Host "🔍 이 레포를 살펴봤습니다:"

    $markerCsv = ""
    if ($detectedCsv -and $detectedCsv -ne "basic") {
        $markerCsv = $detectedCsv
        foreach ($mt in ($detectedCsv -split ',')) {
            Write-Host ("   • {0} 발견 → {1} 추천 (자동 선택됨)" -f (Get-MarkerForType $mt), $mt)
        }
    } else {
        $scanCsv = Get-SuggestedTypesByScan
        if ($scanCsv) {
            foreach ($st in ($scanCsv -split ',')) {
                Write-Host ("   • {0} 관련 파일 발견 → {0} 가능성 (직접 골라주세요)" -f $st)
            }
        } else {
            Write-Host "   • 마커 파일을 찾지 못했습니다 — 직접 선택하세요"
        }
    }
    $curVal = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes -join ',' } else { $script:ProjectType }
    Write-Host ("   • 현재 값: {0}" -f $(if ($curVal) { $curVal } else { "basic" }))
    Write-Host ""

    # ── preselect: 마커 추천이 있으면 그것, 없으면 현재값 ──
    if ($markerCsv) { $preselect = $markerCsv }
    else { $preselect = ($script:ProjectTypes -join ',') }

    $selected = Invoke-ChooseMenu -Multi -Preselect $preselect -Prompt "프로젝트 타입을 선택하세요" -Options @(
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
        Print-Error "프로젝트 타입 선택이 취소되었습니다. 기존 값을 유지합니다."
        if ($script:ProjectTypes.Count -gt 0) { return ($script:ProjectTypes -join ',') }
        return $script:ProjectType
    }

    return $selected
}
```

- [ ] **Step 3: Edit-ProjectInfo type 케이스에 path 연결**

`Edit-ProjectInfo`의 type 처리부를 찾는다:

Run: `grep -n "Show-ProjectTypeMenu" template_integrator.ps1`
Expected: `Edit-ProjectInfo` 내부 호출 위치

해당 type 분기를 다음 형태로 교체(기존 타입 갱신 직후 path 연결 추가):

```powershell
        'type' {
            $oldCsv = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes -join ',' } else { $script:ProjectType }
            $newCsv = Show-ProjectTypeMenu
            if ($newCsv) {
                $script:ProjectTypes = @($newCsv -split ',')
                $script:ProjectType = $script:ProjectTypes[0]
                if ($script:ProjectTypes.Count -gt 1) {
                    Print-Success "Project Types가 '$($script:ProjectTypes -join ', ')'(으)로 변경되었습니다"
                } else {
                    Print-Success "Project Type이 '$($script:ProjectType)'(으)로 변경되었습니다"
                }
                # ★ 타입이 실제로 바뀌었으면 그 자리에서 path 감지를 바로 이어 붙임
                if ($newCsv -ne $oldCsv) {
                    $script:ProjectPaths = [ordered]@{}
                    Resolve-ProjectPaths
                }
            }
            Write-Host ""
        }
```

> 주의: 기존 코드의 type 분기 구조(`switch`인지 `if`인지)를 먼저 확인하고 그 형식에 맞춘다. `Edit-ProjectInfo` 본문을 `sed -n`으로 읽어 기존 분기 키워드를 그대로 따른다.

- [ ] **Step 4: Resolve-ProjectPaths 진행표시 + Detect 문구 정리**

`Detect-ProjectTypes`의 `Print-Step "프로젝트 타입 자동 감지 중... (멀티 지원)"`(655줄)에서 ` (멀티 지원)` 제거.

`Resolve-ProjectPaths`의 타입 루프(`foreach ($t in $targets)` 부근)에 진행 카운터 추가. 루프 직전에 `$idx = 0; $total = $targets.Count` 선언하고, 루프 안 맨 위에 `$idx++; $prog = "[$idx/$total]"` 추가. 후보 안내 `Write-Host`들에 `$prog`를 접두로 붙인다(sh Task 5와 동일 위치: 후보 1개/여러개/없음 안내 3곳).

Run: `grep -n 'foreach ($t in $targets)' template_integrator.ps1`
Expected: 루프 위치 확인 후 위 변경 적용

- [ ] **Step 5: PowerShell 파싱 검사**

Run (PowerShell):
```powershell
$null = [ScriptBlock]::Create((Get-Content -Raw template_integrator.ps1)); "PARSE_OK"
```
Expected: `PARSE_OK` (파싱 에러 없음)

- [ ] **Step 6: Commit**

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 스마트 추천·path 자동 연결 대칭 적용 : feat : Get-SuggestedTypesByScan·메뉴 추천 블록·타입 수정 직후 Resolve-ProjectPaths 호출·진행표시·문구 정리를 sh와 1:1 대칭 포팅"
```

---

### Task 7: 통합 검증 + 시나리오 재현

spec §5의 시나리오를 수동 재현해 흐름을 확인한다.

**Files:** 없음 (검증만)

- [ ] **Step 1: sh/ps1 구문·파싱 최종 확인**

Run:
```bash
bash -n template_integrator.sh && echo SH_OK
```
Expected: `SH_OK`

Run (PowerShell):
```powershell
$null = [ScriptBlock]::Create((Get-Content -Raw template_integrator.ps1)); "PS_OK"
```
Expected: `PS_OK`

- [ ] **Step 2: 스캔 추천 단위 테스트 재실행**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: `PASS=6 FAIL=0`

- [ ] **Step 3: passQL 시나리오 재현 (마커 없는 .py 레포)**

Run:
```bash
T=$(mktemp -d); cd "$T"
for i in 1 2 3 4; do echo "x" > "m$i.py"; done
bash -c 'source '"$OLDPWD"'/template_integrator.sh; suggest_types_by_scan'
```
Expected: `python` 출력 (마커 없는 .py 레포에서 python 추천)

- [ ] **Step 4: 변경 요약 확인**

Run: `git -C "$OLDPWD" log --oneline -8`
Expected: Task 1~6 커밋 6개가 보임

- [ ] **Step 5: 최종 상태 정리 커밋(필요 시)**

검증만 했으므로 변경 없으면 커밋 생략. `_release_notes.md` 같은 미추적 임시파일은 add 하지 않는다.

---

## Self-Review 결과

- **Spec 커버리지**: A(Task 3)·B(Task 2)·C(Task 4)·D(Task 5)·E(Task 3·5) 모두 태스크 존재. ps1 대칭은 Task 6. 검증은 Task 7. ✓
- **Placeholder**: 모든 step에 실제 코드/명령/기대 출력 명시. ✓
- **타입 일관성**: `suggest_types_by_scan`(sh)/`Get-SuggestedTypesByScan`(ps1), `PROJECT_PATHS_CSV`/`$script:ProjectPaths`, `resolve_project_paths`/`Resolve-ProjectPaths` 네이밍 일관. ✓
- **선행 의존**: Task 1(source 가드) → Task 2(테스트가 source) 순서 의존 명시. ✓
