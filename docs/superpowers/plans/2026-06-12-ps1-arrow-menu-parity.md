# template_integrator ps1↔sh 화살표 메뉴·ESC 동작 완전 동일화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `template_integrator.ps1`(Windows)의 대화형 선택 UI를 `template_integrator.sh`(macOS/Linux)와 화살표 메뉴·문구·ESC 동작(stay/back/취소)까지 완전히 동일하게 통일한다. (이슈 #363)

**Architecture:** ps1에 sh `interactive_menu`와 1:1 대칭인 `Invoke-ArrowMenu`(단일+멀티)를 신규 추가하고, `Invoke-ChooseMenu` 디스패처를 "RawUI 동작 가능 → 화살표, 불가 → 번호 폴백"으로 교체한다. 취소(ESC)는 `$null` 반환으로 통일하고 호출처가 stay/back/유지로 분기한다. 키 입력은 `RawUI.ReadKey`, 렌더링은 ANSI 상대 이동(`ESC[nA`+`ESC[2K`)을 쓴다 — 둘 다 2026-06-12 Windows 실기 검증 완료. sh 쪽은 수정 메뉴에 '뒤로' 명시 항목을 추가해 양쪽을 "ESC + 뒤로 항목"으로 맞춘다.

**Tech Stack:** PowerShell 5.1+ (`$Host.UI.RawUI.ReadKey`, ANSI VT sequences), Bash 3.2+ (sh 대칭), Docker `mcr.microsoft.com/powershell:latest`(파서 검증), `expect`(sh TTY 검증).

---

## 설계 근거 (검증 완료 사실)

- **키 입력**: `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")` — stdin redirect(원격 iex) 상태에서도 화살표 VirtualKeyCode(38/40)를 정상 인식. `[Console]::ReadKey`는 redirect에서 예외 → 금지.
- **렌더링**: ANSI `ESC[nA`(n줄 위로) + `ESC[2K`(줄 지우기). `RawUI.CursorPosition` 절대 좌표는 Windows Terminal/VSCode에서 무시되어 줄이 쌓임 → 금지.
- **폴백 판정**: `[Console]::IsInputRedirected`가 아니라 **RawUI 커서 제어 동작 여부**.
- **VirtualKeyCode 맵**: ↑=38, ↓=40, Enter=13, Esc=27, Space=32, a=65, 숫자 1~9=49~57.

## sh 호출처별 ESC 동작 (이식 기준)

| 호출처 (ps1 함수) | cancel-label | ESC 동작 | 비고 |
|---|---|---|---|
| `Show-ProjectTypeMenu` (멀티) | "뒤로" | 기존 타입 유지 | 빈 결과 = 취소 |
| `Detect-AndConfirmProject` 확인화면 | (없음) | **stay** (머묾, 종료 안 함) | 종료는 '아니오, 취소' 명시 선택만 |
| `Edit-ProjectInfo` 수정메뉴 | "뒤로" | **back** (상위로) | ESC + '뒤로' 항목 둘 다 |
| 모드 선택 (`Start-InteractiveMode`) | (없음) | 명시 '취소' 항목으로만 종료 | |

## 취소 신호 규약 (불변 조건)

- `Invoke-ArrowMenu` / `Invoke-ChooseMenu`: 확정 시 선택 value(들), **ESC 취소 시 `$null`** 반환.
- 호출처는 `$null`을 받아 분기: 타입선택 = 기존값 유지, 확인화면 = stay, 수정메뉴 = back.
- `Ask-YesNo` 반환 `$true`/`$false`, `Ask-YesNoEdit` 반환 `"yes"`/`"no"`/`"edit"` 유지 → 호출처 무수정.

---

## File Structure

- **Modify** `template_integrator.ps1`:
  - `Invoke-ArrowMenu` 신규 추가 (Read-SingleKey 함수 뒤, 줄 ~297 다음)
  - `Invoke-ChooseMenu` 교체 (줄 ~439-456): `-CancelLabel` 추가, 화살표/번호 디스패치
  - `Ask-YesNo` 교체 (줄 ~458-486): 화살표 2지선
  - `Ask-YesNoEdit` 교체 (줄 ~488-503): 화살표 3지선
  - `Detect-AndConfirmProject` 확인화면 (줄 ~1383-1390): Y/N/E 안내 블록 제거, 화살표 3지선 + ESC=stay
  - `Edit-ProjectInfo` (줄 ~1255-1269): ESC(=`$null`)=back 분기 추가 ('뒤로' 항목 유지)
- **Modify** `template_integrator.sh`:
  - `handle_project_edit_menu` (줄 ~1831): 메뉴에 '뒤로' 명시 항목 추가 + 매핑

---

### Task 1: ps1 `Invoke-ArrowMenu` 신규 추가 (단일+멀티 화살표)

**Files:**
- Modify: `template_integrator.ps1` (Read-SingleKey 함수 직후, 약 297행 다음에 삽입)

- [ ] **Step 1: `Invoke-ArrowMenu` 함수를 Read-SingleKey 뒤에 삽입**

`template_integrator.ps1`에서 `Read-SingleKey` 함수의 닫는 `}` (약 297행) 바로 다음 줄에 아래 함수를 추가한다. 기존 `# ───── 메뉴 — 숫자 입력` 주석 블록 **앞에** 삽입한다.

```powershell
# ─────────────────────────────────────────────────────────────
# 인터랙티브 메뉴 (화살표/숫자/Enter/ESC) — sh interactive_menu와 1:1 대칭
# 반환: 확정 시 선택 value(멀티는 csv), ESC 취소 시 $null
# sh와 동일 동작: ↑↓ 이동, (멀티) Space 토글·a 전체토글, 숫자 점프, Enter 확정, ESC 취소
# 키 입력 = RawUI.ReadKey(redirect에서도 동작), 렌더 = ANSI 상대이동(ESC[nA + ESC[2K)
# ─────────────────────────────────────────────────────────────
function Test-ArrowMenuSupported {
    # RawUI 커서 제어가 실제 가능한지 타진 (IsInputRedirected로 판정하지 않는다 — redirect여도 RawUI는 동작)
    if ($Host.Name -eq 'Windows PowerShell ISE Host') { return $false }
    try {
        $p = $Host.UI.RawUI.CursorPosition
        $null = $p.Y
        return $true
    } catch {
        return $false
    }
}

function Invoke-ArrowMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [switch]$Multi,
        [string]$Preselect = "",
        [string]$CancelLabel = "취소"
    )

    $n = $Options.Count
    if ($n -eq 0) { return $null }
    $esc = [char]27

    # VT(ANSI) 처리 활성화 시도 — Windows 콘솔은 기본 꺼져 있을 수 있다.
    try {
        $sig = '[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h);' +
               '[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out int m);' +
               '[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, int m);'
        $k = Add-Type -MemberDefinition $sig -Name 'VtConsole' -Namespace 'Win32Vt' -PassThru -ErrorAction Stop
        $h = $k::GetStdHandle(-11)
        $m = 0
        if ($k::GetConsoleMode($h, [ref]$m)) { $null = $k::SetConsoleMode($h, $m -bor 0x0004) }
    } catch {}

    $useColor = -not $env:NO_COLOR

    # 멀티 선택 상태 + preselect 적용
    $selected = New-Object 'bool[]' $n
    if ($Multi -and $Preselect) {
        foreach ($p in ($Preselect.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            for ($i = 0; $i -lt $n; $i++) {
                if ($Options[$i].Value -eq $p) { $selected[$i] = $true; break }
            }
        }
    }

    # 안내 문구 — sh와 동일
    Write-Host ""
    if ($Multi) {
        Write-Host ("{0} (↑↓ 이동, Space 토글, a 전체토글, Enter 확정, ESC {1}):" -f $Prompt, $CancelLabel)
    } else {
        Write-Host ("{0} (↑↓ 이동, 숫자 점프, Enter 확정, ESC {1}):" -f $Prompt, $CancelLabel)
    }
    Write-Host ""

    $cursor = 0

    function Render {
        param($first)
        if (-not $first) { [Console]::Write("$esc[${n}A") }
        for ($i = 0; $i -lt $n; $i++) {
            [Console]::Write("$esc[2K`r")
            $opt = $Options[$i]
            $disp = if ([string]::IsNullOrWhiteSpace($opt.Label)) { $opt.Value } else { $opt.Label }
            # 표시자 — 멀티는 체크박스, 단일은 커서표시
            if ($Multi) {
                $ind = if ($selected[$i]) { "[✓]" } else { "[ ]" }
            } else {
                $ind = if ($i -eq $cursor) { "[•]" } else { "[ ]" }
            }
            $line = "  {0} {1,2}) {2}" -f $ind, ($i + 1), $disp
            if ($i -eq $cursor) {
                Write-Host ("> " + $line.Substring(2)) -ForegroundColor Cyan
            } elseif ($Multi -and $selected[$i] -and $useColor) {
                Write-Host $line -ForegroundColor Green
            } else {
                Write-Host $line
            }
        }
    }

    Render $true
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $vk = $key.VirtualKeyCode
        switch ($vk) {
            38 { $cursor = ($cursor - 1 + $n) % $n }                  # ↑
            40 { $cursor = ($cursor + 1) % $n }                       # ↓
            { $_ -ge 49 -and $_ -le 57 } {                            # 숫자 점프 1~9
                $jump = $vk - 49
                if ($jump -lt $n) { $cursor = $jump }
            }
            32 { if ($Multi) { $selected[$cursor] = -not $selected[$cursor] } }   # Space
            65 {                                                      # a 전체토글
                if ($Multi) {
                    $allOn = $true
                    for ($i = 0; $i -lt $n; $i++) { if (-not $selected[$i]) { $allOn = $false; break } }
                    for ($i = 0; $i -lt $n; $i++) { $selected[$i] = -not $allOn }
                }
            }
            13 {                                                      # Enter 확정
                if ($Multi) {
                    $picked = @()
                    for ($i = 0; $i -lt $n; $i++) { if ($selected[$i]) { $picked += $Options[$i].Value } }
                    if ($picked.Count -eq 0) { return $null }
                    return ($picked -join ',')
                }
                return $Options[$cursor].Value
            }
            27 { return $null }                                       # ESC 취소
        }
        Render $false
    }
}
```

- [ ] **Step 2: ps1 파서로 문법 검증**

Run (Docker, ARM Mac은 `--platform linux/amd64`):
```bash
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}' > /tmp/ps1parse.txt 2>&1
cat /tmp/ps1parse.txt
```
Expected: `PS1_PARSE_OK`

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 화살표 메뉴 함수 추가 : feat : sh interactive_menu와 대칭인 Invoke-ArrowMenu(단일+멀티, RawUI.ReadKey+ANSI 상대이동) 신규"
```

---

### Task 2: ps1 `Invoke-ChooseMenu` 디스패처 교체 (+`-CancelLabel`)

**Files:**
- Modify: `template_integrator.ps1` (현재 약 439-456행 `Invoke-ChooseMenu`)

- [ ] **Step 1: `Invoke-ChooseMenu` 본문을 교체**

기존 함수(아래 주석 포함 본문)를 통째로 다음으로 교체한다.

기존:
```powershell
function Invoke-ChooseMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [int]$DefaultIndex = 0,
        [switch]$Multi,
        [string]$Preselect = ""
    )

    # 메뉴는 항상 숫자 입력 방식(Invoke-LegacyNumericMenu)으로 통일한다.
    # 화살표+커서 좌표 제어 메뉴는 원격 iex 실행 환경에서 SetCursorPosition이
    # 먹히지 않아 줄이 쌓이는 문제가 있어 제거했다. 숫자/토글 입력 방식은
    # 화면 재배치가 없어 iex·파일실행·CI 어디서나 안정적으로 동작한다.
    if ($Multi) {
        return Invoke-LegacyNumericMenu -Prompt $Prompt -Options $Options -Multi -Preselect $Preselect
    }
    return Invoke-LegacyNumericMenu -Prompt $Prompt -Options $Options
}
```

교체 후:
```powershell
function Invoke-ChooseMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [int]$DefaultIndex = 0,
        [switch]$Multi,
        [string]$Preselect = "",
        [string]$CancelLabel = "취소"
    )

    # sh choose_menu와 대칭: RawUI 커서 제어 가능 + 비FORCE → 화살표 메뉴.
    # 불가(ISE 등) → 기존 숫자/토글 입력 메뉴로 폴백.
    # 판정은 IsInputRedirected가 아니라 RawUI 동작 여부 (redirect여도 RawUI.ReadKey는 동작).
    # $Force는 스크립트 최상위 param() switch(73행) — 함수 내부에서 $script:Force로 접근.
    $forceMode = $false
    try { if ($script:Force -eq $true) { $forceMode = $true } } catch {}

    if ((Test-ArrowMenuSupported) -and -not $forceMode) {
        if ($Multi) {
            return Invoke-ArrowMenu -Multi -Prompt $Prompt -Options $Options -Preselect $Preselect -CancelLabel $CancelLabel
        }
        return Invoke-ArrowMenu -Prompt $Prompt -Options $Options -CancelLabel $CancelLabel
    }

    if ($Multi) {
        return Invoke-LegacyNumericMenu -Prompt $Prompt -Options $Options -Multi -Preselect $Preselect
    }
    return Invoke-LegacyNumericMenu -Prompt $Prompt -Options $Options
}
```

- [ ] **Step 2: ps1 파서 검증**

Run:
```bash
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}' > /tmp/ps1parse.txt 2>&1
cat /tmp/ps1parse.txt
```
Expected: `PS1_PARSE_OK`

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 Invoke-ChooseMenu 화살표 우선 디스패치 : feat : RawUI 동작 시 Invoke-ArrowMenu, 불가 시 숫자 폴백 + CancelLabel 파라미터 추가"
```

---

### Task 3: ps1 `Ask-YesNo` / `Ask-YesNoEdit` 화살표 전환

**Files:**
- Modify: `template_integrator.ps1` (현재 약 458-503행)

- [ ] **Step 1: `Ask-YesNo` 본문을 화살표 2지선으로 교체**

기존 `Ask-YesNo` 함수(458-486행) 전체를 다음으로 교체한다. 반환 `$true`/`$false` 계약 유지.

```powershell
function Ask-YesNo {
    param(
        [string]$Prompt,
        [string]$DefaultValue = "N"
    )

    # 프롬프트 끝의 Y/N식 꼬리표 제거 (sh ask_yes_no와 동일 정책)
    $_title = $Prompt -replace '\s*\([^)]*[YyNn][^)]*\)\s*', '' -replace '\s*:\s*$', ''
    $_title = $_title.Trim()
    if ([string]::IsNullOrWhiteSpace($_title) -or $_title -eq '선택') { $_title = '진행하시겠습니까?' }

    $forceMode = $false
    try { if ($script:Force -eq $true) { $forceMode = $true } } catch {}

    # TTY 대화형(화살표 가능) → 화살표 2지선. default가 첫 항목 = 커서 초기 위치.
    if ((Test-ArrowMenuSupported) -and -not $forceMode) {
        if ($DefaultValue -match '^[Yy]$') {
            $opts = @(@{Value='예'; Label=''}, @{Value='아니오'; Label=''})
        } else {
            $opts = @(@{Value='아니오'; Label=''}, @{Value='예'; Label=''})
        }
        $ans = Invoke-ArrowMenu -Prompt $_title -Options $opts -CancelLabel "취소"
        if ($null -eq $ans) { return $false }   # ESC 취소 = No
        return ($ans -eq '예')
    }

    # 폴백 — Y/N 키 입력
    while ($true) {
        $response = Read-SingleKey "$_title (Y/N, 기본: $DefaultValue) "
        if ([string]::IsNullOrWhiteSpace($response)) { $response = $DefaultValue }
        if ($response -eq "Y") { return $true }
        elseif ($response -eq "N") { return $false }
        else { Print-Error "잘못된 입력입니다. Y 또는 N을 입력해주세요."; Write-Host "" }
    }
}
```

- [ ] **Step 2: `Ask-YesNoEdit` 본문을 화살표 3지선으로 교체**

기존 `Ask-YesNoEdit` 함수(488-503행) 전체를 다음으로 교체한다. 반환 `"yes"`/`"no"`/`"edit"` 계약 유지. 단, 확인화면에서 ESC=stay 분기를 위해 ESC 시 `"stay"`를 반환한다 (Task 5에서 사용).

```powershell
function Ask-YesNoEdit {
    $forceMode = $false
    try { if ($script:Force -eq $true) { $forceMode = $true } } catch {}

    # TTY 대화형 → 화살표 3지선. ESC = stay(머묾) 신호.
    if ((Test-ArrowMenuSupported) -and -not $forceMode) {
        $ans = Invoke-ArrowMenu -Prompt "이 정보가 맞습니까?" -Options @(
            @{Value='예, 계속 진행'; Label=''},
            @{Value='수정하기';      Label=''},
            @{Value='아니오, 취소';  Label=''}
        ) -CancelLabel "머무르기"
        if ($null -eq $ans) { return "stay" }
        switch -Wildcard ($ans) {
            '예*'    { return "yes" }
            '수정*'  { return "edit" }
            '아니오*' { return "no" }
            default  { return "stay" }
        }
    }

    # 폴백 — Y/N/E 키 입력
    while ($true) {
        $response = (Read-SingleKey "선택 (Y/N/E) ").ToUpper()
        if ($response -eq "" -or $response -eq "Y") { return "yes" }
        elseif ($response -eq "N") { return "no" }
        elseif ($response -eq "E") { return "edit" }
        else { Print-Error "잘못된 입력입니다. Y, E, 또는 N을 입력해주세요."; Write-Host "" }
    }
}
```

- [ ] **Step 3: ps1 파서 검증**

Run:
```bash
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}' > /tmp/ps1parse.txt 2>&1
cat /tmp/ps1parse.txt
```
Expected: `PS1_PARSE_OK`

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 예아니오 화살표 전환 : feat : Ask-YesNo 2지선·Ask-YesNoEdit 3지선(ESC=stay) 화살표화, 반환계약 유지 + 폴백 보존"
```

---

### Task 4: ps1 확인 화면 Y/N/E 안내 블록 제거 (sh와 동일화)

**Files:**
- Modify: `template_integrator.ps1` `Detect-AndConfirmProject` (현재 약 1383-1390행)

- [ ] **Step 1: Y/N/E 안내 3줄을 제거**

`Detect-AndConfirmProject` 안에서 아래 블록을 찾아 삭제한다. (`Ask-YesNoEdit` 호출은 그대로 둔다 — 이제 화살표가 자체 안내를 출력한다.)

삭제할 코드:
```powershell
        # 사용자 확인
        Write-Host "이 정보가 맞습니까?"
        Write-Host "  Y/y - 예, 계속 진행"
        Write-Host "  E/e - 수정하기"
        Write-Host "  N/n - 아니오, 취소"
        Write-Host ""
        
        # Y/N/E 입력 받기
        $userChoice = Ask-YesNoEdit
```

교체 후 (안내 블록 제거, 호출만 유지):
```powershell
        # 사용자 확인 — 화살표 3지선(Ask-YesNoEdit가 자체 안내 출력). ESC=stay.
        $userChoice = Ask-YesNoEdit
```

- [ ] **Step 2: `stay` 분기가 처리되는지 확인**

`Detect-AndConfirmProject`의 `switch ($userChoice)` 블록을 확인한다. 현재 `"yes"`/`"no"`/`"edit"` 케이스만 있고 `"stay"`가 없으면, 아래처럼 `"stay"` 케이스를 추가한다 (sh와 동일 — 종료하지 않고 루프 재출력). switch에 default가 있으면 stay도 그쪽으로 흘러가 무한 안전하지만, 명시적으로 추가한다.

확인할 위치: `Detect-AndConfirmProject`의 `switch ($userChoice) { "yes" {...} ... }`. `"edit"` 케이스 다음에 추가:
```powershell
            "stay" {
                # ESC 등 중립 상태 — 종료하지 않고 확인 화면을 다시 보여준다
            }
```

> 주의: 기존 switch에 `"no"`(취소→exit), `"edit"`(수정 메뉴) 케이스가 있는지 Read로 먼저 확인하고, 없는 케이스만 보존하며 stay만 추가한다. yes/no/edit 동작은 변경하지 않는다.

- [ ] **Step 3: ps1 파서 검증**

Run:
```bash
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}' > /tmp/ps1parse.txt 2>&1
cat /tmp/ps1parse.txt
```
Expected: `PS1_PARSE_OK`

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 확인화면 Y/N/E 안내 제거 : feat : 화살표 3지선이 자체 안내 출력하도록 정리하고 ESC=stay 분기 추가 (sh와 동일)"
```

---

### Task 5: ps1 수정 메뉴 ESC=back 분기 추가 ('뒤로' 항목 유지)

**Files:**
- Modify: `template_integrator.ps1` `Edit-ProjectInfo` (현재 약 1255-1269행)

- [ ] **Step 1: `Invoke-ChooseMenu` 호출에 `-CancelLabel "뒤로"` 추가 + `$null`(ESC)=back 처리**

`Edit-ProjectInfo`의 메뉴 호출부를 확인한다. 현재:
```powershell
        $editChoice = Invoke-ChooseMenu -Prompt "어떤 항목을 수정하시겠습니까?" -Options @(
            @{Value='type';    Label='프로젝트 타입'},
            @{Value='version'; Label='버전'},
            @{Value='branch';  Label='기본 브랜치'},
            @{Value='done';    Label='모두 맞음, 계속'},
            @{Value='back';    Label='뒤로 (변경 없이 확인 화면으로)'}
        )

        if (-not $editChoice) {
            # 입력 불가 등 → 안전하게 뒤로
            return
        }
```

교체 후 ('뒤로' 항목 유지 + `-CancelLabel "뒤로"` 추가, ESC($null)도 back과 동일하게 return):
```powershell
        # 하위 메뉴이므로 ESC는 '뒤로'(상위 확인 화면으로). ESC + '뒤로' 항목 둘 다 제공.
        $editChoice = Invoke-ChooseMenu -CancelLabel "뒤로" -Prompt "어떤 항목을 수정하시겠습니까?" -Options @(
            @{Value='type';    Label='프로젝트 타입'},
            @{Value='version'; Label='버전'},
            @{Value='branch';  Label='기본 브랜치'},
            @{Value='done';    Label='모두 맞음, 계속'},
            @{Value='back';    Label='뒤로 (변경 없이 확인 화면으로)'}
        )

        # ESC($null) 또는 '뒤로' → 상위 확인 화면으로 복귀 (sh handle_project_edit_menu와 대칭)
        if ((-not $editChoice) -or ($editChoice -eq 'back')) {
            return
        }
```

> 주의: 기존 `switch ($editChoice)` 안의 `'back' { return }` 케이스는 남겨둬도 무방하지만, 위에서 이미 처리하므로 도달하지 않는다. 중복 제거는 선택적 — 기능에 영향 없으니 그대로 둔다.

- [ ] **Step 2: ps1 파서 검증**

Run:
```bash
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}' > /tmp/ps1parse.txt 2>&1
cat /tmp/ps1parse.txt
```
Expected: `PS1_PARSE_OK`

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 수정메뉴 ESC=뒤로 분기 : feat : Invoke-ChooseMenu에 CancelLabel 뒤로 지정하고 ESC를 back과 동일 처리, 뒤로 항목 유지 (ESC+항목 둘 다)"
```

---

### Task 6: sh 수정 메뉴에 '뒤로' 명시 항목 추가 (ps1과 동일화)

**Files:**
- Modify: `template_integrator.sh` `handle_project_edit_menu` (현재 약 1831-1848행)

- [ ] **Step 1: 메뉴에 '뒤로' 항목 추가 + 매핑**

sh `handle_project_edit_menu`의 메뉴 호출과 매핑을 확인한다. 현재:
```bash
        _edit_label=$(choose_menu --cancel-label="뒤로" "어떤 항목을 수정하시겠습니까?" \
            "프로젝트 타입|" \
            "버전|" \
            "기본 브랜치|" \
            "모두 맞음, 계속|") || _menu_rc=$?

        local edit_choice=""
        if [ "$_menu_rc" -ne 0 ]; then
            # ESC → 상위 확인 화면으로 뒤로
            edit_choice="back"
        else
            case "$_edit_label" in
                프로젝트\ 타입*) edit_choice="type" ;;
                버전*)           edit_choice="version" ;;
                기본\ 브랜치*)   edit_choice="branch" ;;
                모두\ 맞음*)     edit_choice="done" ;;
                *)               edit_choice="back" ;;
            esac
        fi
```

교체 후 ('뒤로' 항목 추가 — ps1과 동일하게 ESC + 명시 항목 둘 다):
```bash
        _edit_label=$(choose_menu --cancel-label="뒤로" "어떤 항목을 수정하시겠습니까?" \
            "프로젝트 타입|" \
            "버전|" \
            "기본 브랜치|" \
            "모두 맞음, 계속|" \
            "뒤로 (변경 없이 확인 화면으로)|") || _menu_rc=$?

        local edit_choice=""
        if [ "$_menu_rc" -ne 0 ]; then
            # ESC → 상위 확인 화면으로 뒤로
            edit_choice="back"
        else
            case "$_edit_label" in
                프로젝트\ 타입*) edit_choice="type" ;;
                버전*)           edit_choice="version" ;;
                기본\ 브랜치*)   edit_choice="branch" ;;
                모두\ 맞음*)     edit_choice="done" ;;
                뒤로*)           edit_choice="back" ;;
                *)               edit_choice="back" ;;
            esac
        fi
```

- [ ] **Step 2: sh 문법 검증**

Run:
```bash
bash -n template_integrator.sh && echo "BASH_SYNTAX_OK"
```
Expected: `BASH_SYNTAX_OK`

- [ ] **Step 3: 커밋**

```bash
git add template_integrator.sh
git commit -m "template_integrator.sh 수정메뉴 뒤로 항목 추가 : feat : ps1과 동일하게 뒤로 명시 항목 추가(ESC+항목 둘 다), 뒤로 라벨 매핑"
```

---

### Task 7: sh 회귀 테스트 + ps1 함수 동작 검증

**Files:**
- Test: `.github/workflows/test/test_integrator_suggest.sh` (또는 실제 경로)

- [ ] **Step 1: 회귀 테스트 경로 확인**

Run:
```bash
find . -name "test_integrator_suggest.sh" -not -path "*/node_modules/*"
```
Expected: 테스트 스크립트 경로 출력 (예: `./.github/workflows/test/test_integrator_suggest.sh`)

- [ ] **Step 2: sh 회귀 테스트 실행 (22 케이스)**

Run (Step 1에서 찾은 경로 사용):
```bash
bash <위에서 찾은 경로> 2>&1 | tail -20
```
Expected: 22/22 통과 (PASS 표시 또는 실패 0건). 화살표 메뉴 변경은 추천 로직(suggest)과 무관하므로 모두 통과해야 한다.

- [ ] **Step 3: ps1 동작 검증 — Invoke-ArrowMenu 폴백 경로 (Docker)**

stdin redirect 환경(Docker `-Command -`)에서 `Invoke-ArrowMenu`가 단일 선택을 ↓+Enter로 처리하는지 최소 하네스로 검증한다. `Invoke-ArrowMenu`와 `Test-ArrowMenuSupported` 본문을 `sed`로 잘라 붙이고, 키 입력을 RawUI 스텁으로 주입한다.

Run:
```bash
# Invoke-ArrowMenu 함수 영역 라인 확인
grep -n "^function Invoke-ArrowMenu\|^function Test-ArrowMenuSupported\|^function Invoke-ChooseMenu" template_integrator.ps1
```
Expected: 세 함수의 시작 라인 번호 출력. (다음 스텝에서 sed 범위로 사용)

- [ ] **Step 4: ps1 최소 하네스로 멀티 셀렉트 csv 반환 검증**

`Invoke-ArrowMenu`(Test-ArrowMenuSupported 시작 ~ Invoke-ChooseMenu 직전)를 추출해 RawUI.ReadKey를 시퀀스 스텁으로 덮고, 멀티 모드에서 Space×2 + Enter가 csv를 반환하는지 본다.

Run (라인 범위 START,END는 Step 3 결과로 치환):
```bash
{
  echo '$ErrorActionPreference="Stop"'
  echo 'function Test-ArrowMenuSupported { return $true }'
  # ReadKey 스텁: ↓(40), Space(32), ↓(40), Space(32), Enter(13) 시퀀스 주입
  cat <<'PS'
$script:__keys = @(40,32,40,32,13)
$script:__ki = 0
$stub = {
  param($opt)
  $vk = $script:__keys[$script:__ki]; $script:__ki++
  return [pscustomobject]@{ VirtualKeyCode = $vk; Character = [char]0 }
}
# RawUI.ReadKey를 가짜로: Host UI 접근을 가로채기 어려우므로, 함수 내 호출을 스텁 함수로 대체할 수 없다.
# 대신 Invoke-ArrowMenu의 ReadKey 호출을 직접 패치한 사본을 만들기 어렵다 → 이 스텝은 수동/실기 검증으로 대체 가능.
PS
} > /tmp/ps1_harness_note.txt
cat /tmp/ps1_harness_note.txt
```

> 참고: `$Host.UI.RawUI.ReadKey`는 함수 스텁으로 덮기 어렵다(메서드 호출). 따라서 멀티/ESC의 완전한 자동 검증은 **사용자 실기**(Task 8)로 수행하고, 여기서는 파서 통과 + 폴백 경로(`Invoke-LegacyNumericMenu`) 정상만 자동 확인한다. 폴백은 기존에 검증된 코드라 회귀 위험이 낮다.

- [ ] **Step 5: 커밋 (검증 로그 없으면 생략)**

검증만 한 경우 커밋할 변경이 없으면 생략. 테스트 스크립트를 보강했다면:
```bash
git add <변경 파일>
git commit -m "template_integrator 화살표 메뉴 검증 보강 : test : sh 회귀 22케이스 + ps1 파서 통과 확인"
```

---

### Task 8: 문구 대조 + 사용자 실기 검증

**Files:**
- 검증만 (코드 변경 없음)

- [ ] **Step 1: sh ↔ ps1 메뉴 문구 대조표 추출**

두 파일에서 메뉴 prompt·옵션 라벨·안내 꼬리표를 추출해 육안 대조한다.

Run:
```bash
echo "=== sh 메뉴 라벨/프롬프트 ===" 
grep -nE 'choose_menu|이 정보가 맞습니까|어떤 항목을 수정|어떤 기능을 통합|프로젝트 타입을 선택' template_integrator.sh | head -40
echo "=== ps1 메뉴 라벨/프롬프트 ==="
grep -nE 'Invoke-ChooseMenu|이 정보가 맞습니까|어떤 항목을 수정|어떤 기능을 통합|프로젝트 타입을 선택' template_integrator.ps1 | head -40
```
Expected: 양쪽의 prompt·옵션 라벨 텍스트가 동일. 다른 부분이 있으면 ps1을 sh에 맞춰 수정 후 재커밋.

- [ ] **Step 2: 안내 꼬리표 동일성 확인**

Run:
```bash
echo "=== sh 안내 ==="; grep -nE '↑↓ 이동|Enter 확정|ESC' template_integrator.sh | head
echo "=== ps1 안내 ==="; grep -nE '↑↓ 이동|Enter 확정|ESC' template_integrator.ps1 | head
```
Expected: `(↑↓ 이동, …, Enter 확정, ESC <라벨>)` 형식이 양쪽 동일. (ps1은 `Invoke-ArrowMenu`가 동적 생성하므로 형식 문자열이 일치하면 OK)

- [ ] **Step 3: 사용자 실기 검증 안내**

사용자에게 Windows PowerShell에서 다음을 직접 확인하도록 요청한다:

```
1. 파일 실행:   .\template_integrator.ps1
2. 원격 재현:   Get-Content .\template_integrator.ps1 -Raw | powershell -NoProfile -Command -

각 항목 확인:
- [ ] 모드 선택: ↑/↓ 이동, Enter 선택, 줄 안 쌓임
- [ ] 프로젝트 타입(멀티): Space 토글 [✓], a 전체토글, preselect 체크됨, Enter 확정
- [ ] 확인 화면: 화살표 3지선, ESC 눌러도 종료 안 됨(stay, 다시 확인 화면)
- [ ] 수정 메뉴: ESC 누르면 확인 화면으로 back, '뒤로' 항목도 동작
- [ ] 예/아니오 질문: 화살표 2지선, 기본값에 커서 위치
```

- [ ] **Step 4: 최종 커밋 (실기 검증 통과 후, 문구 수정 있었으면)**

```bash
git add template_integrator.ps1 template_integrator.sh
git commit -m "template_integrator sh/ps1 문구 대조 정합 : refactor : 메뉴 prompt·라벨·ESC 안내 꼬리표를 sh 기준으로 1:1 일치"
```

---

## Self-Review 결과

**Spec coverage:**
- 화살표 메뉴 이식(단일+멀티) → Task 1 ✅
- 디스패처 통일(-CancelLabel, RawUI 판정) → Task 2 ✅
- ESC 분기(타입=유지, 확인=stay, 수정=back, 모드=명시취소) → Task 3(stay)·4(확인화면)·5(수정 back) ✅. 타입선택 ESC=유지는 기존 `Show-ProjectTypeMenu`의 `if (-not $selected)` 로직이 그대로 처리(Invoke-ArrowMenu가 ESC 시 $null 반환 → 기존 유지 분기) ✅. 모드선택 명시취소는 기존 '취소' 항목 유지로 변경 불필요 ✅
- ESC+뒤로 항목 양쪽 → Task 5(ps1 유지)·6(sh 추가) ✅
- 문구 동일화 → Task 8 ✅
- 반환 계약 보존 → Task 3에서 $true/$false·yes/no/edit 유지(+stay 신규) ✅
- 검증(sh 회귀·파서·실기) → Task 7·8 ✅

**Placeholder scan:** Task 7 Step 4는 RawUI 메서드 스텁 한계를 명시하고 실기로 위임 — 가짜 코드 아님, 한계를 정직히 기록. 그 외 모든 코드 블록은 완전한 구현 포함.

**Type consistency:** `Test-ArrowMenuSupported`(Task1 정의 → Task2·3 사용), `Invoke-ArrowMenu`(Task1 → Task2·3), `-CancelLabel`(Task2 정의 → Task5 사용), 취소 신호 `$null`(전 Task 일관), `"stay"`(Task3 생성 → Task4 소비) — 모두 일치 ✅

**확인 완료 (실행자 참고):** FORCE 모드 변수는 스크립트 최상위 `param()`의 `[switch]$Force`(73행)다. 함수 내부에서는 `$script:Force`로 접근한다(이미 계획 코드에 반영됨). `$script:ForceMode` 같은 변수는 없으니 그대로 진행하면 된다.
