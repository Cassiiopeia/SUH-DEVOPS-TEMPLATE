# 서브폴더 마커 스캔 추천 + 멀티모듈 스프링 정합 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 타입 추천이 서브폴더 마커(`client/package.json` 등)를 우선 스캔하게 보강하고, 멀티모듈 스프링에서 후보가 루트 `.` 하나로만 잡히게 수정한다.

**Architecture:** `suggest_types_by_scan`을 "모든 마커 타입에 `find_type_path_candidates`를 돌려 후보가 있으면 추천 → package.json 계열은 내용으로 판별 → 마커 없으면 확장자 빈도 폴백" 구조로 바꾼다. `find_type_path_candidates`의 spring 분기는 루트 `settings.gradle` 존재 시 `.`만 반환한다. sh 구현 후 ps1에 1:1 대칭 포팅. `version_manager.sh`는 이미 멀티모듈을 지원하므로 건드리지 않는다.

**Tech Stack:** Bash 3.2 / PowerShell 5.1 호환. 테스트는 `.github/scripts/test/test_integrator_suggest.sh`(함수 source + mktemp + chk).

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `template_integrator.sh` | 통합 원본 | `classify_package_json` 신규, `find_type_path_candidates`(spring) 수정, `suggest_types_by_scan` 재작성 |
| `template_integrator.ps1` | PS 포팅 | `Get-PackageJsonType` 신규, `Find-TypePathCandidates`(spring) 수정, `Get-SuggestedTypesByScan` 재작성 |
| `.github/scripts/test/test_integrator_suggest.sh` | 단위 테스트 | 서브폴더 react/next·멀티모듈 spring·서브폴더 spring 케이스 추가 |

**참고**: spec = `docs/superpowers/specs/2026-06-11-submarker-scan-recommend-design.md`. 직전 작업으로 `suggest_types_by_scan`·`find_type_path_candidates`·`detect_project_types`·source 가드가 이미 존재한다.

---

### Task 1: classify_package_json 헬퍼 (sh) + 멀티모듈 spring 수정 + 단위 테스트

`detect_project_types`의 package.json 판별 로직을 재사용 가능한 헬퍼로 추출하고, spring 멀티모듈 오탐을 수정한다. 두 변경 모두 다음 Task의 `suggest_types_by_scan` 재작성이 의존하므로 먼저 한다.

**Files:**
- Modify: `template_integrator.sh` (`detect_project_types` 앞에 `classify_package_json` 삽입; `find_type_path_candidates` spring 분기 수정)
- Test: `.github/scripts/test/test_integrator_suggest.sh` (케이스 추가)

- [ ] **Step 1: 실패 테스트 추가**

`.github/scripts/test/test_integrator_suggest.sh`의 마지막 `echo ""` (결과 출력) **앞에** 아래 블록을 삽입:

```bash
echo "=== (7) classify_package_json: react 의존성 → react ==="
new_workdir
printf '{"dependencies":{"react":"^18.0.0"}}\n' > package.json
chk "react 판별" "$(classify_package_json package.json)" "react"

echo "=== (8) classify_package_json: next 의존성 → next ==="
new_workdir
printf '{"dependencies":{"next":"14.0.0","react":"^18"}}\n' > package.json
chk "next 판별(react보다 우선)" "$(classify_package_json package.json)" "next"

echo "=== (9) classify_package_json: react-native + expo → react-native-expo ==="
new_workdir
printf '{"dependencies":{"react-native":"0.73","expo":"~50"}}\n' > package.json
chk "expo 판별" "$(classify_package_json package.json)" "react-native-expo"

echo "=== (10) classify_package_json: 순수 → node ==="
new_workdir
printf '{"dependencies":{"express":"^4"}}\n' > package.json
chk "node 판별" "$(classify_package_json package.json)" "node"

echo "=== (11) 멀티모듈 spring: settings.gradle 있으면 . 하나 ==="
new_workdir
echo "rootProject.name='demo'" > settings.gradle
echo "version='0.0.1'" > build.gradle
mkdir -p api core
echo "version='0.0.1'" > api/build.gradle
echo "version='0.0.1'" > core/build.gradle
chk "멀티모듈 → 루트만" "$(find_type_path_candidates spring)" "."

echo "=== (12) 단일모듈 spring: 루트 build.gradle, settings 없음 → . ==="
new_workdir
echo "version='0.0.1'" > build.gradle
chk "단일모듈 → ." "$(find_type_path_candidates spring)" "."

echo "=== (13) 서브폴더 spring: server/build.gradle, settings 없음 → server ==="
new_workdir
mkdir -p server
echo "version='0.0.1'" > server/build.gradle
chk "서브폴더 spring → server" "$(find_type_path_candidates spring)" "server"
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: (7)~(10) FAIL (`classify_package_json: command not found`), (11) FAIL (현재는 `.\napi\ncore` 반환)

- [ ] **Step 3: classify_package_json 구현**

`template_integrator.sh`에서 `detect_project_types()` 함수 **시작 줄 바로 앞**에 삽입:

```bash
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
```

- [ ] **Step 4: find_type_path_candidates spring 분기 수정**

`template_integrator.sh`의 `find_type_path_candidates` 안, `case "$t" in` 후보 필터 루프에서 spring 분기를 찾는다(현재):

```bash
            spring)
                # Flutter/RN의 android/build.gradle 오탐 제외
                case "$d" in *android*) continue ;; esac
                ;;
```

그리고 이 함수의 **맨 앞**(`local t=$1` 다음)에 멀티모듈 단락 로직을 추가한다. `local t=$1` 줄 바로 뒤에 삽입:

```bash
    # 멀티모듈 스프링: 루트에 settings.gradle(.kts) 있으면 버전은 루트에서 관리 →
    # 후보를 "." 하나로 고정 (version_manager가 . 아래 모든 build.gradle을 일괄 갱신)
    if [ "$t" = "spring" ] && { [ -f "settings.gradle" ] || [ -f "settings.gradle.kts" ]; }; then
        echo "."
        return 0
    fi
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: 전 케이스 PASS, `PASS=13 FAIL=0`

- [ ] **Step 6: 구문 검사**

Run: `bash -n template_integrator.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 7: Commit**

```bash
git add template_integrator.sh .github/scripts/test/test_integrator_suggest.sh
git commit -m "template_integrator package.json 타입 판별 헬퍼·멀티모듈 스프링 오탐 수정 : feat : classify_package_json 추출하고 settings.gradle 있는 멀티모듈은 후보를 루트 하나로 고정 + 테스트 7케이스 추가"
```

---

### Task 2: suggest_types_by_scan 마커 우선 재작성 (sh)

확장자만 보던 추천을 "마커 우선 + 확장자 폴백"으로 재작성한다. Task 1의 `classify_package_json`·`find_type_path_candidates`에 의존한다.

**Files:**
- Modify: `template_integrator.sh` (`suggest_types_by_scan` 함수 전체 교체)
- Test: `.github/scripts/test/test_integrator_suggest.sh` (서브폴더 케이스 추가)

- [ ] **Step 1: 실패 테스트 추가**

`.github/scripts/test/test_integrator_suggest.sh`의 결과 출력 `echo ""` 앞에 삽입:

```bash
echo "=== (14) 서브폴더 react: client/package.json → react 포함 ==="
new_workdir
mkdir -p client
printf '{"dependencies":{"react":"^18"}}\n' > client/package.json
chk "서브폴더 react 추천" "$(suggest_types_by_scan)" "react"

echo "=== (15) 서브폴더 next: web/package.json → next 포함 ==="
new_workdir
mkdir -p web
printf '{"dependencies":{"next":"14","react":"^18"}}\n' > web/package.json
chk "서브폴더 next 추천" "$(suggest_types_by_scan)" "next"

echo "=== (16) 혼합 모노레포: app/pubspec + client/package(react) + ai/pyproject ==="
new_workdir
mkdir -p app/lib client ai
printf 'name: demo\n' > app/pubspec.yaml
printf '{"dependencies":{"react":"^18"}}\n' > client/package.json
printf '[project]\nname="x"\n' > ai/pyproject.toml
chk "혼합 모노레포 정렬 추천" "$(suggest_types_by_scan)" "flutter,react,python"

echo "=== (17) 마커 없는 .py 4개 → python (확장자 폴백 유지) ==="
new_workdir
for i in 1 2 3 4; do echo "print($i)" > "m$i.py"; done
chk "확장자 폴백 python" "$(suggest_types_by_scan)" "python"
```

> 케이스 16의 기대값 `flutter,react,python`은 메뉴 정의 순서(spring,flutter,next,react,react-native,react-native-expo,node,python,basic)대로 정렬한 결과다. flutter→react→python 순.

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: (14)(15)(16) FAIL (현재 확장자 스캔은 서브폴더 package.json을 react/next로 못 잡음 — maxdepth 3 .tsx도 없음), (17) PASS

- [ ] **Step 3: suggest_types_by_scan 재작성**

`template_integrator.sh`의 `suggest_types_by_scan` 함수 전체를 교체:

```bash
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
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: 전 케이스 PASS, `PASS=17 FAIL=0`

- [ ] **Step 5: 구문 검사**

Run: `bash -n template_integrator.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 6: Commit**

```bash
git add template_integrator.sh .github/scripts/test/test_integrator_suggest.sh
git commit -m "template_integrator 마커 우선 스캔 추천으로 재작성 : feat : 서브폴더 마커(client/package.json 등)를 find_type_path_candidates로 우선 탐지하고 package.json은 내용 판별, 마커 없으면 확장자 폴백 + 서브폴더 react/next 테스트"
```

---

### Task 3: PowerShell 대칭 적용 (ps1)

Task 1~2의 sh 변경을 `template_integrator.ps1`에 1:1 대칭 포팅한다.

**Files:**
- Modify: `template_integrator.ps1` (`Get-PackageJsonType` 신규, `Find-TypePathCandidates` spring 수정, `Get-SuggestedTypesByScan` 재작성)

- [ ] **Step 1: Get-PackageJsonType 신규**

`Detect-ProjectTypes` 함수 앞(또는 `Get-MarkerForType` 부근, 다른 함수 정의 사이)에 삽입:

```powershell
# package.json 경로 → react/next/node/react-native(-expo) 판별 (sh classify_package_json 대응)
function Get-PackageJsonType {
    param([string]$PjPath)
    if (-not (Test-Path $PjPath -PathType Leaf)) { return "" }
    $content = Get-Content $PjPath -Raw
    if ($content -match "@react-native|react-native") {
        if ($content -match "expo") { return "react-native-expo" }
        return "react-native"
    } elseif ($content -match '"next"') {
        return "next"
    } elseif ($content -match '"react"') {
        return "react"
    } else {
        return "node"
    }
}
```

- [ ] **Step 2: Find-TypePathCandidates spring 멀티모듈 단락**

`Find-TypePathCandidates` 함수의 `param([string]$ProjType)` 다음, switch 앞에 삽입:

```powershell
    # 멀티모듈 스프링: 루트 settings.gradle(.kts) 있으면 후보를 "." 하나로 고정
    if ($ProjType -eq "spring" -and ((Test-Path "settings.gradle" -PathType Leaf) -or (Test-Path "settings.gradle.kts" -PathType Leaf))) {
        return @(".")
    }
```

- [ ] **Step 3: Get-SuggestedTypesByScan 재작성**

`Get-SuggestedTypesByScan` 함수 전체를 교체:

```powershell
# 마커 파일이 없을 때 타입 추천 (스캔 추천) — 반환: csv (메뉴 순서 정렬), 없으면 ""
function Get-SuggestedTypesByScan {
    $found = @()

    # ── 1) 마커 우선 스캔 ──
    foreach ($mt in @('flutter','spring','python','react-native-expo')) {
        $cand = @(Find-TypePathCandidates $mt)
        if ($cand.Count -gt 0) { $found += $mt }
    }
    # package.json 계열 — 디렉터리별 내용 판별
    $pjCand = @(Find-TypePathCandidates 'react')
    foreach ($d in $pjCand) {
        if ([string]::IsNullOrEmpty($d)) { continue }
        if ($d -eq ".") { $pj = "package.json" } else { $pj = "$d/package.json" }
        $ptype = Get-PackageJsonType $pj
        if ($ptype) { $found += $ptype }
    }

    # ── 2) 마커 없으면 확장자 폴백 ──
    if ($found.Count -eq 0) {
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
        if ($dart -ge 1) { $found += 'flutter' }
        if (($java + $kt + $gradle) -ge 3) { $found += 'spring' }
        if (($tsx + $jsx) -ge 3) { $found += 'react' }
        if ($py -ge 3) { $found += 'python' }
        if ($found.Count -eq 0 -and ($ts + $js) -ge 3) { $found += 'node' }
    }

    # ── 3) 메뉴 순서 정렬 + 중복 제거 ──
    $order = @('spring','flutter','next','react','react-native','react-native-expo','node','python','basic')
    $out = @()
    foreach ($o in $order) {
        if ($found -contains $o -and $out -notcontains $o) { $out += $o }
    }
    return ($out -join ',')
}
```

- [ ] **Step 4: PowerShell 파싱 검사**

Run (PowerShell): `$null = [ScriptBlock]::Create((Get-Content -Raw template_integrator.ps1)); "PARSE_OK"`
Expected: `PARSE_OK`

- [ ] **Step 5: sh 테스트 회귀 확인 (로직 동등성)**

Run: `bash .github/scripts/test/test_integrator_suggest.sh`
Expected: `PASS=17 FAIL=0` (sh 변경 영향 없음)

- [ ] **Step 6: Commit**

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 마커 우선 스캔 추천 대칭 적용 : feat : Get-PackageJsonType·멀티모듈 스프링 단락·Get-SuggestedTypesByScan 마커 우선 재작성을 sh와 1:1 대칭 포팅"
```

---

### Task 4: 통합 검증 + passQL 시나리오

**Files:** 없음 (검증만)

- [ ] **Step 1: sh/ps1 구문·파싱 + 전체 테스트**

Run:
```bash
bash -n template_integrator.sh && echo SH_OK
bash .github/scripts/test/test_integrator_suggest.sh
```
Expected: `SH_OK`, `PASS=17 FAIL=0`

Run (PowerShell): `$null = [ScriptBlock]::Create((Get-Content -Raw template_integrator.ps1)); "PS_OK"`
Expected: `PS_OK`

- [ ] **Step 2: passQL 시나리오 재현 (접근 가능 시)**

passQL이 `D:/0-suh/project/passQL`에 있으면:
```bash
PROJ="D:/0-suh/project/suh-github-template/template_integrator.sh"
cd "D:/0-suh/project/passQL" 2>/dev/null && bash -c "source '$PROJ'; suggest_types_by_scan"
```
Expected: react를 포함한 csv (예: `flutter,react,python` 또는 spring 포함). 핵심은 **react가 포함**될 것.
passQL 접근 불가 시: Step 1의 케이스 14·16(서브폴더 react)으로 대체 검증 완료로 간주.

- [ ] **Step 3: 커밋 로그 확인**

Run: `git log --oneline -5`
Expected: Task 1~3 커밋 3개 + 직전 작업 커밋

---

## Self-Review 결과

- **Spec 커버리지**: A(Task 2)·B(Task 1 Step 4)·C(Task 2 폴백)·classify_package_json(Task 1)·ps1 대칭(Task 3)·검증(Task 4). version_manager 비범위 준수. ✓
- **Placeholder**: 모든 step에 실제 코드·명령·기대출력. ✓
- **타입 일관성**: `classify_package_json`(sh)/`Get-PackageJsonType`(ps1), `suggest_types_by_scan`/`Get-SuggestedTypesByScan`, `find_type_path_candidates`/`Find-TypePathCandidates` 네이밍 일관. 정렬 순서(메뉴 정의 순서) sh·ps1 동일. ✓
- **의존 순서**: Task 1(헬퍼+spring수정) → Task 2(재작성, 헬퍼 의존) → Task 3(ps1) 명시. ✓
- **테스트 번호**: 기존 1~6 + Task1의 7~13 + Task2의 14~17 = 17케이스, `PASS=17` 일관. ✓
