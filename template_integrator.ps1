# ===================================================================
# GitHub 템플릿 통합 스크립트 v1.0.0 (Windows PowerShell)
# ===================================================================
#
# 이 스크립트는 기존 프로젝트에 SUH-DEVOPS-TEMPLATE의 기능을
# 선택적으로 통합합니다. (Windows 환경 전용)
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
# Invoke-WebRequest -Uri "https://raw.githubusercontent.com/.../template_integrator.ps1" -OutFile "template_integrator.ps1"
# powershell -ExecutionPolicy Bypass -File .\template_integrator.ps1
#
# 방법 2: 원격 실행 - 대화형 (추천)
# $wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/.../template_integrator.ps1")
#
# 방법 3: 원격 실행 - CLI 파라미터 전달
# $wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("URL"))) -Mode full -Force
#
# 옵션:
#   -Mode <MODE>             통합 모드 선택 (기본: interactive)
#                            • full        - 전체 통합 (버전관리+워크플로우+이슈템플릿)
#                            • version     - 버전 관리 시스템만
#                            • workflows   - GitHub Actions 워크플로우만
#                            • issues      - 이슈/PR 템플릿만
#                            • skills      - Agent Skill 설치만 (Claude, Cursor, Gemini, Codex, PI)
#                            • interactive - 대화형 선택 (기본값)
#   -Version <VERSION>       초기 버전 설정 (자동 감지, 수동 지정 가능)
#   -Type <TYPE>             프로젝트 타입 (자동 감지, 수동 지정 가능)
#                            지원: spring, flutter, react, react-native,
#                                  react-native-expo, node, python, basic
#   -NoBackup                백업 생성 안 함 (기본: 백업 생성)
#   -Force                   확인 없이 즉시 실행
#   -Help                    도움말 표시
#
# 예시:
#   # 대화형 모드 (추천)
#   .\template_integrator.ps1
#
#   # 버전 관리 시스템만 추가
#   .\template_integrator.ps1 -Mode version
#
#   # 전체 통합 (자동 감지)
#   .\template_integrator.ps1 -Mode full
#
#   # Node.js 프로젝트로 버전 1.0.0 설정
#   .\template_integrator.ps1 -Mode full -Version "1.0.0" -Type node
#
# ===================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Mode = "interactive",

    [Parameter(Mandatory=$false)]
    [string]$Version = "",

    [Parameter(Mandatory=$false)]
    [string]$Type = "",

    [Parameter(Mandatory=$false)]
    [switch]$NoBackup,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$Synology,

    [Parameter(Mandatory=$false)]
    [switch]$NoSynology,

    [Parameter(Mandatory=$false)]
    [string]$Paths = "",

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# 에러 발생 시 스크립트 중단
$ErrorActionPreference = "Stop"

# UTF-8 인코딩 설정 (한글 지원)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ===================================================================
# SSL 인증서 관련 환경 변수 초기화
# 사용자 환경에서 잘못 설정된 CA 경로 문제 방지
# (예: curl: (77) error setting certificate verify locations: CAfile: /tmp/cacert.pem)
# ===================================================================
$env:CURL_CA_BUNDLE = $null
$env:SSL_CERT_FILE = $null
$env:SSL_CERT_DIR = $null
$env:REQUESTS_CA_BUNDLE = $null

# ===================================================================
# 상수 정의
# ===================================================================

$TEMPLATE_REPO = "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git"
$TEMPLATE_RAW_URL = "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main"
$TEMP_DIR = ".template_download_temp"
$VERSION_FILE = "version.yml"
$WORKFLOWS_DIR = ".github/workflows"
$SCRIPTS_DIR = ".github/scripts"
$PROJECT_TYPES_DIR = "project-types"
$DEFAULT_VERSION = "1.3.14"
$WORKFLOW_PREFIX = "PROJECT"
$WORKFLOW_COMMON_PREFIX = "PROJECT-COMMON"
$WORKFLOW_TEMPLATE_INIT = "PROJECT-TEMPLATE-INITIALIZER.yaml"

# 전역 변수
$script:ProjectType = ""
$script:ProjectTypes = @()   # 멀티타입 배열 — ProjectType은 ProjectTypes[0] 미러
$script:ProjectVersion = $Version
$script:DetectedBranch = ""
$script:IsInteractiveMode = $false
$script:WorkflowsCopied = 0
$script:UtilModulesCopied = 0
$script:ValidTypes = @("spring", "flutter", "next", "react", "react-native", "react-native-expo", "node", "python", "basic")
$script:IncludeSynology = $null  # Synology 워크플로우 포함 여부 ($null: 미설정, $true/$false: 명시적 설정)
$script:TemplateVersion = ""  # 다운로드한 템플릿의 실제 버전 (Download-Template에서 설정됨)
$script:PiPackageUrl = "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"  # pi install/update/remove 대상

# 타입별 프로젝트 경로 (project_paths) — resolve 또는 -Paths로 채워짐
$script:ProjectPaths = [ordered]@{}
if (-not [string]::IsNullOrWhiteSpace($Paths)) {
    foreach ($pair in $Paths.Split(',')) {
        $kv = $pair.Trim().Split('=', 2)
        if ($kv.Count -eq 2 -and $kv[0].Trim() -and $kv[1].Trim()) {
            $script:ProjectPaths[$kv[0].Trim()] = $kv[1].Trim().Replace('\','/').TrimEnd('/') -replace '^\./', ''
        }
    }
}

# ===================================================================
# 출력 함수 (색상 지원)
# ===================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Print-Header {
    param([string]$Title)
    Write-Host ""
    Write-ColorOutput "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-ColorOutput "║ $Title" -ForegroundColor Cyan
    Write-ColorOutput "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Print-Banner {
    param(
        [string]$Version,
        [string]$Mode
    )
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗"
    Write-Host "║ 🔮  ✦ S U H · D E V O P S · T E M P L A T E ✦                    ║"
    Write-Host "╚══════════════════════════════════════════════════════════════════╝"
    Write-Host "       🌙 Version : v$Version"
    Write-Host "       🐵 Author  : Cassiiopeia"
    Write-Host "       🪐 Mode    : $Mode"
    Write-Host "       📦 Repo    : github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    Write-Host ""
}

function Print-Step {
    param([string]$Message)
    Write-ColorOutput "🔅 $Message" -ForegroundColor Cyan
}

function Print-Info {
    param([string]$Message)
    Write-ColorOutput "  🔸 $Message" -ForegroundColor Blue
}

function Print-Success {
    param([string]$Message)
    Write-ColorOutput "✨ $Message" -ForegroundColor Green
}

function Print-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠️  $Message" -ForegroundColor Yellow
}

function Print-Error {
    param([string]$Message)
    Write-ColorOutput "💥 $Message" -ForegroundColor Red
}

function Print-Question {
    param([string]$Message)
    Write-ColorOutput "💫 $Message" -ForegroundColor Magenta
}

function Print-SeparatorLine {
    Write-Host "────────────────────────────────────────"
}

function Print-SectionHeader {
    param(
        [string]$Emoji,
        [string]$Title
    )
    
    Write-Host ""
    Write-Host "────────────────────────────────────────────────────────────────────────────────"
    Write-Host "$Emoji $Title"
    Write-Host "────────────────────────────────────────────────────────────────────────────────"
}

function Print-QuestionHeader {
    param(
        [string]$Emoji,
        [string]$Question
    )
    
    Write-Host ""
    Print-SeparatorLine
    Write-Host "$Emoji $Question"
    Print-SeparatorLine
    Write-Host ""
}

# ===================================================================
# 사용자 입력 함수
# ===================================================================

function Read-UserInput {
    param(
        [string]$Prompt,
        [string]$DefaultValue = ""
    )
    
    if ($DefaultValue) {
        $input = Read-Host "$Prompt (기본: $DefaultValue)"
        if ([string]::IsNullOrWhiteSpace($input)) {
            return $DefaultValue
        }
        return $input
    } else {
        return Read-Host $Prompt
    }
}

function Read-SingleKey {
    param([string]$Prompt)

    Write-Host $Prompt -NoNewline

    # stdin이 redirect된 비대화형 환경(원격 iex 실행 등)에서는 RawUI.ReadKey가
    # 예외를 던져 ErrorActionPreference=Stop으로 스크립트 전체가 죽는다.
    # IsInputRedirected면 즉시 줄 입력(Read-Host)으로 폴백하고, 그래도 실패하면
    # 빈 문자열을 반환해 호출측(Ask-YesNo/Ask-YesNoEdit)이 기본값을 쓰게 한다.
    if ([Console]::IsInputRedirected) {
        try {
            $line = Read-Host
            if ([string]::IsNullOrWhiteSpace($line)) { return "" }
            return $line.Trim().Substring(0, 1).ToUpper()
        } catch {
            Write-Host ""
            return ""
        }
    }

    try {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-Host ""
        if ($null -eq $key.Character) { return "" }
        return $key.Character.ToString().ToUpper()
    } catch {
        # RawUI.ReadKey 미지원 호스트 → 줄 입력 폴백
        try {
            $line = Read-Host
            if ([string]::IsNullOrWhiteSpace($line)) { return "" }
            return $line.Trim().Substring(0, 1).ToUpper()
        } catch {
            Write-Host ""
            return ""
        }
    }
}

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
        [string]$CancelLabel = "취소",
        [int]$InitialIndex = 0   # 단일 선택 시 커서 초기 위치(=기본값). 항목 순서는 고정한 채 기본만 표현.
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

    # 커서 초기 위치 = InitialIndex (단일 선택의 기본값 표현). 범위를 벗어나면 0으로.
    $cursor = if ($InitialIndex -ge 0 -and $InitialIndex -lt $n) { $InitialIndex } else { 0 }

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

# ─────────────────────────────────────────────────────────────
# 메뉴 — 숫자 입력 / 번호 토글 방식 (iex·파일실행·CI 어디서나 안전)
# ─────────────────────────────────────────────────────────────
function Invoke-LegacyNumericMenu {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][hashtable[]]$Options,
        [switch]$Multi,
        [string]$Preselect = ""
    )

    $n = $Options.Count
    if ($n -eq 0) { return $null }

    $useColor = -not $env:NO_COLOR

    # ── 단일 선택 ── 유효한 번호가 들어올 때까지 재시도
    if (-not $Multi) {
        Write-Host ""
        Write-Host $Prompt
        Write-Host ""
        # 화면엔 Label(사용자 친화 한국어)만 표시 — Value(full 등 영어 키)는 노출하지 않는다.
        # Label이 비어 있으면 Value를 대신 표시(예/아니오 같은 단순 선택지).
        for ($i = 0; $i -lt $n; $i++) {
            $opt = $Options[$i]
            $disp = if ([string]::IsNullOrWhiteSpace($opt.Label)) { $opt.Value } else { $opt.Label }
            Write-Host ("  {0}) {1}" -f ($i + 1), $disp)
        }
        Write-Host ""
        while ($true) {
            try {
                $choice = Read-Host "선택 (1-$n)"
            } catch {
                return $Options[0].Value   # stdin redirect → 첫 옵션
            }
            $choice = "$choice".Trim()
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $n) {
                return $Options[[int]$choice - 1].Value
            }
            # 이름으로도 허용
            for ($i = 0; $i -lt $n; $i++) {
                if ($Options[$i].Value -eq $choice) { return $Options[$i].Value }
            }
            Write-Host "잘못된 입력입니다. 1~$n 중 하나를 입력하세요." -ForegroundColor Red
        }
    }

    # ── 다중 선택 ── 입력한 번호 = 최종 선택 (덮어쓰기 방식, 토글 아님)
    #  "1,2,8"을 입력하면 정확히 1,2,8만 선택된다. 기존 선택은 입력으로 대체된다.
    $preValues = @()
    if ($Preselect) {
        foreach ($p in $Preselect.Split(',')) {
            $p = $p.Trim()
            if ($p) { $preValues += $p }
        }
    }

    # 목록 출력 (preselect는 현재값으로 [✓] 표시해 무엇이 기본인지 보여줌)
    Write-Host ""
    Write-Host $Prompt
    Write-Host ""
    for ($i = 0; $i -lt $n; $i++) {
        $opt = $Options[$i]
        $mark = if ($preValues -contains $opt.Value) { "[✓]" } else { "[ ]" }
        # 화면엔 Label만 표시(영어 키 비노출). Label 비면 Value.
        $disp = if ([string]::IsNullOrWhiteSpace($opt.Label)) { $opt.Value } else { $opt.Label }
        $line = "  {0} {1,2}) {2}" -f $mark, ($i + 1), $disp
        if (($preValues -contains $opt.Value) -and $useColor) {
            Write-Host $line -ForegroundColor Green
        } else {
            Write-Host $line
        }
    }
    Write-Host ""
    if ($preValues.Count -gt 0) {
        Write-Host ("  번호를 입력하세요 (여러 개는 1,3,5 · a=전체 · 그냥 Enter=현재값 [{0}] 유지)" -f ($preValues -join ',')) -ForegroundColor DarkGray
    } else {
        Write-Host "  번호를 입력하세요 (여러 개는 1,3,5 · a=전체)" -ForegroundColor DarkGray
    }

    while ($true) {
        try {
            $input = Read-Host "선택"
        } catch {
            # stdin redirect → preselect 있으면 그걸로, 없으면 첫 옵션
            if ($preValues.Count -gt 0) { return ($preValues -join ',') }
            return $Options[0].Value
        }
        $input = "$input".Trim()

        # 빈 입력(Enter) — preselect 있으면 그걸 그대로 확정
        if (-not $input) {
            if ($preValues.Count -gt 0) { return ($preValues -join ',') }
            Write-Host "  최소 1개는 선택해야 합니다. 번호를 입력하세요." -ForegroundColor Red
            continue
        }

        # a = 전체 선택
        if ($input -eq 'a' -or $input -eq 'A') {
            $all = @()
            for ($i = 0; $i -lt $n; $i++) { $all += $Options[$i].Value }
            return ($all -join ',')
        }

        # 입력한 번호/이름 = 최종 선택. 순서는 옵션 순서대로 정렬, 중복 제거.
        $chosenIdx = New-Object 'bool[]' $n
        $bad = @()
        foreach ($p in ($input -split '[,\s]+')) {
            $p = $p.Trim()
            if (-not $p) { continue }
            $hit = $false
            if ($p -match '^\d+$' -and [int]$p -ge 1 -and [int]$p -le $n) {
                $chosenIdx[[int]$p - 1] = $true
                $hit = $true
            } else {
                for ($i = 0; $i -lt $n; $i++) {
                    if ($Options[$i].Value -eq $p) { $chosenIdx[$i] = $true; $hit = $true; break }
                }
            }
            if (-not $hit) { $bad += $p }
        }

        if ($bad.Count -gt 0) {
            Write-Host ("  잘못된 입력: {0} — 1~{1} 중에서 다시 입력하세요." -f ($bad -join ', '), $n) -ForegroundColor Red
            continue
        }

        $picked = @()
        for ($i = 0; $i -lt $n; $i++) { if ($chosenIdx[$i]) { $picked += $Options[$i].Value } }
        if ($picked.Count -eq 0) {
            Write-Host "  최소 1개는 선택해야 합니다." -ForegroundColor Red
            continue
        }
        return ($picked -join ',')
    }
}

# ─────────────────────────────────────────────────────────────
# 통합 entry point — 숫자/토글 입력 메뉴로 위임
# ─────────────────────────────────────────────────────────────
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

function Ask-YesNo {
    param(
        [string]$Prompt,
        [string]$DefaultValue = "N"
    )

    # 프롬프트 끝의 Y/N식 꼬리표 제거 (sh ask_yes_no와 동일 정책)
    # "(Y/N, 기본: Y)", "(Y=예 / N=직접입력)", "선택:" 등이 남으면 중복·모순돼 보인다.
    $_title = $Prompt -replace '\s*\([^)]*[YyNn][^)]*\)\s*', '' -replace '\s*:\s*$', ''
    $_title = $_title.Trim()
    if ([string]::IsNullOrWhiteSpace($_title) -or $_title -eq '선택') { $_title = '진행하시겠습니까?' }

    $forceMode = $false
    try { if ($script:Force -eq $true) { $forceMode = $true } } catch {}

    # TTY 대화형(화살표 가능) → 화살표 2지선.
    # 항목 순서는 항상 '1) 예  2) 아니오'로 고정한다 (기본값에 따라 순서가 바뀌면 일관성이 깨진다).
    # 기본값은 순서가 아니라 '커서 초기 위치'로만 표현한다: 기본 Y → 커서 예(0), 기본 N → 커서 아니오(1).
    if ((Test-ArrowMenuSupported) -and -not $forceMode) {
        $opts = @(@{Value='예'; Label=''}, @{Value='아니오'; Label=''})
        $initIdx = if ($DefaultValue -match '^[Yy]$') { 0 } else { 1 }
        $ans = Invoke-ArrowMenu -Prompt $_title -Options $opts -CancelLabel "취소" -InitialIndex $initIdx
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

function Ask-YesNoEdit {
    $forceMode = $false
    try { if ($script:Force -eq $true) { $forceMode = $true } } catch {}

    # TTY 대화형 → 화살표 3지선. ESC = stay(머묾) 신호.
    if ((Test-ArrowMenuSupported) -and -not $forceMode) {
        $ans = Invoke-ArrowMenu -Prompt "위 분석 결과가 맞습니까?" -Options @(
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
        if ($response -eq "" -or $response -eq "Y") {
            return "yes"
        } elseif ($response -eq "N") {
            return "no"
        } elseif ($response -eq "E") {
            return "edit"
        } else {
            Print-Error "잘못된 입력입니다. Y, E, 또는 N을 입력해주세요."
            Write-Host ""
        }
    }
}

# ===================================================================
# 도움말
# ===================================================================

function Show-Help {
    Write-Host @"

GitHub 템플릿 통합 스크립트 v1.0.0 (Windows PowerShell)

사용법:
  .\template_integrator.ps1 [옵션]

통합 모드:
  full        - 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)
  version     - 버전 관리 시스템만 (version.yml + scripts)
  workflows   - GitHub Actions 워크플로우만
  issues      - 이슈/PR 템플릿만
  skills      - Agent Skill 설치만 (Claude, Cursor, Gemini, Codex, PI)
  interactive - 대화형 선택 (기본값, 추천)

옵션:
  -Mode <MODE>          통합 모드 선택
  -Version <VERSION>    초기 버전 (미지정 시 자동 감지)
  -Type <TYPE>          프로젝트 타입 (미지정 시 자동 감지)
  -NoBackup             백업 생성 안 함
  -Force                확인 없이 즉시 실행
  -Synology             Synology 워크플로우 포함 (기본: 제외)
  -NoSynology           Synology 워크플로우 제외
  -Paths "T=P,..."      타입별 프로젝트 경로 (모노레포용, 예: -Paths "flutter=app,react=client")
  -Help                 이 도움말 표시

지원 프로젝트 타입:
  • node / react / next / react-native - Node.js 기반 프로젝트
  • spring            - Spring Boot 백엔드
  • flutter           - Flutter 모바일 앱
  • python            - Python 프로젝트
  • basic             - 기타 프로젝트

자동 감지 기능:
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

사용 예시:
  # 로컬 실행 - 대화형 모드 (추천)
  .\template_integrator.ps1

  # 원격 실행 - 대화형 모드
  $wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.../template_integrator.ps1")

  # 버전 관리만 추가
  .\template_integrator.ps1 -Mode version

  # 전체 통합 (자동 감지)
  .\template_integrator.ps1 -Mode full

  # 수동 설정
  .\template_integrator.ps1 -Mode full -Version "1.0.0" -Type node

통합 후 작업:
  1. README.md - 버전 정보 섹션 자동 추가됨 (기존 내용 보존)
  2. version.yml - 버전 관리 설정 파일 생성
  3. .github/workflows/ - 워크플로우 파일 추가

⚠️  주의사항:
  • 기존 README.md, LICENSE는 절대 덮어쓰지 않습니다
  • 충돌하는 워크플로우는 .bak 파일로 백업됩니다
  • Git 저장소가 아니면 경고만 표시하고 계속 진행합니다

"@
}

# ===================================================================
# 프로젝트 타입 자동 감지
# ===================================================================

function Detect-ProjectType {
    Print-Step "프로젝트 타입 자동 감지 중..."

    # ===================================================
    # 우선순위 1: 명확한 프레임워크 마커 파일 체크
    # Flutter, Spring, Python은 고유한 마커 파일을 가지므로 우선 체크
    # ===================================================

    # Flutter
    if (Test-Path "pubspec.yaml") {
        Print-Info "✓ Flutter 감지됨"
        return "flutter"
    }

    # Spring Boot
    if ((Test-Path "build.gradle") -or (Test-Path "build.gradle.kts") -or (Test-Path "pom.xml")) {
        Print-Info "✓ Spring Boot 감지됨"
        return "spring"
    }

    # Python
    if ((Test-Path "pyproject.toml") -or (Test-Path "setup.py") -or (Test-Path "requirements.txt")) {
        Print-Info "✓ Python 감지됨"
        return "python"
    }

    # ===================================================
    # 우선순위 2: Node.js 에코시스템 세부 분류
    # package.json은 여러 프로젝트 타입에서 보조 도구로 사용될 수 있으므로 나중에 체크
    # ===================================================

    # Node.js / React / React Native / Next.js
    if (Test-Path "package.json") {
        $packageJson = Get-Content "package.json" -Raw

        # React Native 체크
        if ($packageJson -match "@react-native|react-native") {
            # Expo 체크
            if ($packageJson -match "expo") {
                Print-Info "✓ React Native (Expo) 감지됨"
                return "react-native-expo"
            } else {
                Print-Info "✓ React Native 감지됨"
                return "react-native"
            }
        }

        # Next.js 체크 (React보다 먼저 체크해야 함)
        if ($packageJson -match '"next"') {
            Print-Info "✓ Next.js 감지됨"
            return "next"
        }

        # React 체크
        if ($packageJson -match '"react"') {
            Print-Info "✓ React 감지됨"
            return "react"
        }

        # 기본 Node.js
        Print-Info "✓ Node.js 감지됨"
        return "node"
    }

    # ===================================================
    # 감지 실패
    # ===================================================
    Print-Warning "프로젝트 타입을 감지하지 못했습니다. 기본(basic) 타입으로 설정합니다."
    return "basic"
}

# ===================================================================
# 프로젝트 타입 멀티 감지 — 모든 일치 타입을 csv로 반환 (sh detect_project_types 포팅)
# ===================================================================

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

# 모드 키 → 확인 화면용 한국어 라벨 (sh _mode_display_label과 동일)
function Get-ModeDisplayLabel {
    param([string]$ModeKey)
    switch ($ModeKey) {
        'full'      { return '전체 설치 (버전관리 + 워크플로우 + 이슈·PR 템플릿)' }
        'version'   { return '버전 관리만' }
        'workflows' { return '워크플로우만' }
        'issues'    { return '이슈·PR 템플릿만' }
        'skills'    { return 'AI 스킬만' }
        default     { return $ModeKey }
    }
}

function Detect-ProjectTypes {
    Print-Step "프로젝트 타입 자동 감지 중..."

    # ── 0) 기존 version.yml의 project_types 최우선 (sh와 동일) ──
    # 이미 통합된 프로젝트(멀티타입 포함)는 version.yml에 타입이 저장돼 있다.
    # 루트에 마커가 없어도(모노레포) 기존 설정을 그대로 이어받아 basic 오감지를 막는다.
    if (Test-Path "version.yml") {
        $existingTypes = ""
        $lines = Get-Content "version.yml" -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if ($line -match '^\s*#') { continue }
            if ($line -match '^project_types:') {
                # ["spring","flutter"] → spring,flutter
                $tokens = [regex]::Matches($line, '"([a-z\-]+)"') | ForEach-Object { $_.Groups[1].Value }
                if ($tokens.Count -gt 0) { $existingTypes = ($tokens -join ',') }
                break
            }
        }
        # 배열이 없으면 단수 project_type 폴백
        if (-not $existingTypes) {
            foreach ($line in $lines) {
                if ($line -match '^\s*#') { continue }
                if ($line -match '^project_type:\s*"?([a-z\-]+)"?') { $existingTypes = $matches[1]; break }
            }
        }
        # version.yml에 타입이 명시돼 있으면(basic 포함) source of truth → 그대로 사용
        if ($existingTypes) {
            Print-Info "✓ 기존 설정 적용: $existingTypes (version.yml에서 불러옴)"
            return $existingTypes
        }
    }

    # PowerShell 5.1 호환: null += 방지 위해 빈 배열로 초기화
    $detected = @()

    # 고유 마커 파일 — 독립적으로 모두 감지
    if (Test-Path "pubspec.yaml") { $detected += "flutter" }

    if ((Test-Path "build.gradle") -or (Test-Path "build.gradle.kts") -or (Test-Path "pom.xml")) {
        $detected += "spring"
    }

    if ((Test-Path "pyproject.toml") -or (Test-Path "setup.py") -or (Test-Path "requirements.txt")) {
        $detected += "python"
    }

    # package.json 기반 — next / react-native / react-native-expo / react / node 구분
    # (spring/flutter가 build 도구로 쓰는 package.json과 구분하기 위해 내용 검사)
    if (Test-Path "package.json") {
        $packageJson = Get-Content "package.json" -Raw
        if ($packageJson -match "@react-native|react-native") {
            if ($packageJson -match "expo") {
                $detected += "react-native-expo"
            } else {
                $detected += "react-native"
            }
        } elseif ($packageJson -match '"next"') {
            $detected += "next"
        } elseif ($packageJson -match '"react"') {
            $detected += "react"
        } else {
            # spring/flutter가 이미 감지된 경우 순수 node 보조 도구일 수 있어 중복 추가 방지
            if ($detected.Count -eq 0) { $detected += "node" }
        }
    }

    if ($detected.Count -eq 0) { $detected = @("basic") }

    Print-Info "✓ 감지된 타입: $($detected -join ' ')"

    return ($detected -join ',')
}

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

# ===================================================================
# 타입별 프로젝트 경로 (project_paths) 감지·확정
# ===================================================================

# 검색 제외 폴더 (스펙 §4.3) — 경로에 이 폴더가 들어가면 후보에서 제외
$script:PathExcludeRegex = '[\\/](node_modules|\.git|build|dist|\.dart_tool|android|ios|\.gradle|venv|\.venv|__pycache__)([\\/]|$)'

# 타입의 대표 마커 파일명 (감지·version.yml 주석용)
function Get-MarkerForType {
    param([string]$ProjType)
    switch ($ProjType) {
        "flutter" { return "pubspec.yaml" }
        "react" { return "package.json" }
        "next" { return "package.json" }
        "node" { return "package.json" }
        "react-native" { return "package.json" }
        "react-native-expo" { return "app.json" }
        "python" { return "pyproject.toml" }
        "spring" { return "build.gradle" }
        default { return "" }
    }
}

# 디렉토리에 실재하는 마커 파일명 반환 (보조 마커 포함) — 없으면 대표 마커 반환 (표시용)
# sh existing_marker_in_dir 포팅: spring/python은 우선순위순으로 실재 파일을 찾는다
function Get-ExistingMarkerInDir {
    param(
        [string]$ProjType,
        [string]$Dir
    )
    $names = @()
    switch ($ProjType) {
        "spring" { $names = @("build.gradle", "build.gradle.kts", "pom.xml") }
        "python" { $names = @("pyproject.toml", "setup.py", "requirements.txt") }
        default  { $names = @(Get-MarkerForType $ProjType) }
    }
    foreach ($n in $names) {
        if (-not $n) { continue }
        if (Test-Path (Join-Path $Dir $n) -PathType Leaf) { return $n }
    }
    return (Get-MarkerForType $ProjType)
}

# 타입별 마커 파일 후보 검색 — 후보 디렉토리 상대경로 배열 반환 (루트는 ".")
# Depth 2 = 루트 포함 3단계 (bash find -maxdepth 3 대응) + 잡음 폴더 제외 + 타입별 오탐 필터
function Find-TypePathCandidates {
    param([string]$ProjType)

    # 멀티모듈 스프링: settings.gradle(.kts)이 있는 폴더 = 멀티모듈 루트로 축약.
    # 루트뿐 아니라 server/ 같은 하위 폴더도 Depth 2까지 탐색해 그 폴더를 후보로 잡는다.
    # version_manager가 해당 폴더 아래 모든 build.gradle을 일괄 갱신하므로 하위 모듈을 펼치지 않는다.
    # android/ 폴더의 settings.gradle(Flutter/RN)은 spring 모듈이 아니므로 제외.
    if ($ProjType -eq "spring") {
        $root = (Get-Location).Path
        $mmFiles = @(Get-ChildItem -Path . -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
            Where-Object { ($_.Name -eq "settings.gradle" -or $_.Name -eq "settings.gradle.kts") -and
                           $_.FullName -notmatch $script:PathExcludeRegex })
        if ($mmFiles.Count -gt 0) {
            $mmDirs = @()
            foreach ($f in $mmFiles) {
                $dir = Split-Path -Parent $f.FullName
                $rel = $dir.Substring($root.Length).TrimStart('\').TrimStart('/')
                if ([string]::IsNullOrEmpty($rel)) { $rel = "." } else { $rel = $rel.Replace('\', '/') }
                if ($mmDirs -notcontains $rel) { $mmDirs += $rel }
            }
            # settings.gradle 발견 시: 그 폴더(들)만 후보로 반환. 단일이면 자동확정, 복수면 메뉴 선택.
            return ($mmDirs | Sort-Object)
        }
        # settings.gradle 전혀 없음 → 단일 모듈. 아래 build.gradle 탐색 폴백으로 진행.
    }

    $markerNames = @()
    switch ($ProjType) {
        "flutter"           { $markerNames = @("pubspec.yaml") }
        "react"             { $markerNames = @("package.json") }
        "next"              { $markerNames = @("package.json") }
        "node"              { $markerNames = @("package.json") }
        "react-native"      { $markerNames = @("package.json") }
        "react-native-expo" { $markerNames = @("app.json") }
        "python"            { $markerNames = @("pyproject.toml", "setup.py", "requirements.txt") }
        "spring"            { $markerNames = @("build.gradle", "build.gradle.kts", "pom.xml") }
        default             { return @() }
    }

    $root = (Get-Location).Path
    foreach ($name in $markerNames) {
        $files = @(Get-ChildItem -Path . -Recurse -Depth 2 -Filter $name -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch $script:PathExcludeRegex })
        if ($files.Count -eq 0) { continue }

        $dirs = @()
        foreach ($f in $files) {
            $dir = Split-Path -Parent $f.FullName
            $rel = $dir.Substring($root.Length).TrimStart('\').TrimStart('/')
            if ([string]::IsNullOrEmpty($rel)) { $rel = "." } else { $rel = $rel.Replace('\', '/') }

            if ($ProjType -eq "flutter") {
                # example/ 제외 + lib/ 동반 확인 (오탐 방지)
                if ($rel -match 'example') { continue }
                if ($rel -eq ".") { $libDir = "lib" } else { $libDir = "$rel/lib" }
                if (-not (Test-Path $libDir -PathType Container)) { continue }
            }
            if ($ProjType -eq "spring" -and $rel -match 'android') { continue }

            if ($dirs -notcontains $rel) { $dirs += $rel }
        }
        # 우선순위 높은 마커에서 후보가 잡히면 그것만 사용 (sh: 먼저 발견되는 마커만)
        if ($dirs.Count -gt 0) { return ($dirs | Sort-Object) }
    }
    return @()
}

# 기존 version.yml의 project_paths 값을 $script:ProjectPaths에 로드만 한다 (질문 없음).
# 이미 init된 프로젝트는 확인 화면에 저장된 경로를 그대로 보여주기 위해 사용한다.
# 반환: 대상 타입(basic 제외) 전부가 이미 채워졌으면 $true (= 경로 질문 불필요).
function Load-SavedProjectPaths {
    if (-not (Test-Path "version.yml")) { return $false }

    $allTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
    $targets = @($allTypes | Where-Object { $_ -ne "basic" })
    if ($targets.Count -eq 0) { return $true }  # basic만이면 경로 불필요

    # version.yml의 project_paths 블록을 한 번에 파싱해 맵으로 적재
    $saved = @{}
    $inPaths = $false
    foreach ($line in (Get-Content "version.yml")) {
        if ($line -match '^project_paths:') { $inPaths = $true; continue }
        if ($inPaths) {
            if ($line -match '^\s{2}([^\s:]+):\s*"([^"]*)"') { $saved[$matches[1]] = $matches[2]; continue }
            if ($line -match '^[^\s]') { break }  # 다른 최상위 키 → 섹션 종료
        }
    }

    # 대상 타입을 저장값으로 채운다 (-Paths로 이미 지정된 건 건드리지 않음)
    foreach ($t in $targets) {
        if ($script:ProjectPaths.Contains($t)) { continue }
        if ($saved.ContainsKey($t)) { $script:ProjectPaths[$t] = $saved[$t] }
    }

    # 대상 전부가 채워졌는지 확인
    foreach ($t in $targets) {
        if (-not $script:ProjectPaths.Contains($t)) { return $false }
    }
    return $true
}

# 선택된 모든 타입의 경로를 감지·확인하여 $script:ProjectPaths 확정 (스펙 §4)
function Resolve-ProjectPaths {
    # -Paths 사전 검증·정규화: 타입 유효성 + 경로 정규화 (백슬래시→슬래시, 끝 슬래시·앞 ./ 제거)
    if ($script:ProjectPaths.Count -gt 0) {
        $normalized = [ordered]@{}
        foreach ($key in @($script:ProjectPaths.Keys)) {
            $vt = "$key".Trim()
            if ($script:ValidTypes -notcontains $vt) {
                Print-Error "-Paths에 지원하지 않는 타입: '$vt'"
                Print-Error "지원 타입: $($script:ValidTypes -join ' ')"
                exit 1
            }
            $vp = "$($script:ProjectPaths[$key])".Trim().Replace('\', '/').TrimEnd('/') -replace '^\./', ''
            if ([string]::IsNullOrEmpty($vp)) { $vp = "." }
            $vm = Get-ExistingMarkerInDir $vt $vp
            if (-not (Test-Path (Join-Path $vp $vm) -PathType Leaf)) {
                Print-Warning "-Paths: $vt=$vp 경로에서 마커 파일을 찾지 못했지만 입력값을 그대로 기록합니다"
            }
            $normalized[$vt] = $vp
        }
        $script:ProjectPaths = $normalized
    }

    $allTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
    $targets = @($allTypes | Where-Object { $_ -ne "basic" })
    if ($targets.Count -eq 0) { return }  # basic만이면 경로 불필요

    $total = $targets.Count

    Print-Step "타입별 프로젝트 경로 확인 중..."
    Write-Host ""
    # ── 도입부: 무엇이 감지됐고 이제 무엇을 할지 먼저 설명 (에이전트형 안내 톤) ──
    if ($total -gt 1) {
        Write-Host "🔍 멀티타입 프로젝트가 감지되었습니다 — 총 ${total}개 타입"
    } else {
        Write-Host "🔍 $($targets[0]) 프로젝트가 감지되었습니다 — 총 1개 타입"
    }
    foreach ($ml in $targets) {
        # 타입명을 8칸으로 패딩해 마커 파일명을 세로로 정렬
        $mt = Get-ExistingMarkerInDir $ml "."
        Write-Host ("   • {0,-8} → {1}" -f $ml, $mt)
    }
    Write-Host ""
    Write-Host "각 타입의 프로젝트가 레포 어느 폴더에 있는지 확인이 필요합니다."
    if ($total -gt 1) {
        Write-Host "이제 하나씩 차례대로 각 프로젝트의 루트 디렉터리를 설정하겠습니다."
    } else {
        Write-Host "이제 이 프로젝트의 루트 디렉터리를 설정하겠습니다."
    }
    Write-Host ""
    Write-Host "💡 '프로젝트 루트' = 그 타입의 버전 파일이 있는 폴더 (레포 루트 기준 상대경로)"
    Write-Host "   예) 레포루트/app/pubspec.yaml 이면 → `"app`""
    Write-Host "       레포루트/packages/web/package.json 이면 → `"packages/web`""
    Write-Host "       레포 루트에 바로 있으면 → `".`""
    Print-SeparatorLine
    Write-Host ""

    $idx = 0
    foreach ($t in $targets) {
        $idx++
        $prog = "[$idx/$total]"
        # 1) -Paths로 이미 지정됨 → 최우선
        if ($script:ProjectPaths.Contains($t)) {
            Print-Info "  $t → $($script:ProjectPaths[$t]) (-Paths 지정)"
            continue
        }

        # 2) 루트에 마커 존재 → "." 자동 확정 (질문 없이 안내만, 보조 마커 포함)
        $rootMarker = Get-ExistingMarkerInDir $t "."
        if ($rootMarker -and (Test-Path $rootMarker -PathType Leaf)) {
            $script:ProjectPaths[$t] = "."
            Print-Info "  $t → . (루트의 $rootMarker)"
            continue
        }

        # 3) 기존 version.yml의 project_paths 값 → 기본 제안값
        $existing = ""
        if (Test-Path "version.yml") {
            $inPaths = $false
            foreach ($line in (Get-Content "version.yml")) {
                if ($line -match '^project_paths:') { $inPaths = $true; continue }
                if ($inPaths) {
                    if ($line -match "^\s{2}$([regex]::Escape($t)):\s*`"([^`"]*)`"") {
                        $existing = $matches[1]
                        break
                    }
                    if ($line -match '^[^\s]') { break }  # 다른 최상위 키 → 섹션 종료
                }
            }
        }

        # 4) 후보 검색
        $candidates = @(Find-TypePathCandidates $t)
        $chosen = ""

        # ── 비대화형 (-Force): 스펙 §4.5 ──
        if ($Force) {
            if ($existing) {
                $chosen = $existing
                Print-Info "  $t → $chosen (기존 project_paths 유지)"
            } elseif ($candidates.Count -eq 1) {
                $chosen = $candidates[0]
                Print-Info "  $t → $chosen (자동 감지)"
            } else {
                $chosen = "."
                Print-Warning "  $t → 후보 $($candidates.Count)개로 자동 확정 불가, 루트(.)로 기록 (-Paths `"$t=경로`"로 지정 가능)"
            }
            $script:ProjectPaths[$t] = $chosen
            continue
        }

        # ── 대화형: 후보 개수별 분기 (스펙 §4.4) ──
        if ($candidates.Count -eq 1) {
            $c0Marker = Get-ExistingMarkerInDir $t $candidates[0]
            # 루트면 마커만, 하위 폴더면 폴더/마커 — "어디 기준 경로"인지 전체 경로로 노출
            if ($candidates[0] -eq ".") { $c0Full = $c0Marker } else { $c0Full = "$($candidates[0])/$c0Marker" }
            Write-Host ""
            Write-Host "  $prog 🔍 $t — $c0Marker 발견"
            Write-Host "      위치: <레포루트>/$c0Full"
            Write-Host ""
            if (Ask-YesNo "  $t 프로젝트 루트를 '$($candidates[0])'(으)로 설정할까요? ($c0Full 기준 — 아니오 선택 시 직접 입력)" "Y") {
                $chosen = $candidates[0]
            }
        } elseif ($candidates.Count -gt 1) {
            Write-Host ""
            Write-Host "  $prog 🔍 ${t}: 경로 후보 $($candidates.Count)개 발견"
            # 후보들 + '직접 입력'을 화살표 메뉴로 (다른 메뉴와 통일). value=경로, 마지막은 직접입력.
            $candOpts = @()
            foreach ($cand in $candidates) {
                $cMarker = Get-ExistingMarkerInDir $t $cand
                $candOpts += @{Value=$cand; Label=$cMarker}
            }
            $candOpts += @{Value='직접 입력'; Label=''}
            $sel = Invoke-ChooseMenu -Prompt "  $t 프로젝트 루트를 선택하세요" -Options $candOpts
            if ($sel -and $sel -ne '직접 입력') { $chosen = $sel }
            # '직접 입력'이거나 취소면 chosen 미설정 → 아래 직접입력 루프로
        } else {
            Write-Host ""
            Print-Warning "  $prog ${t}: 프로젝트를 찾지 못했습니다 (depth 3)."
        }

        # ── 직접 입력 (위에서 미확정 시) ──
        while ([string]::IsNullOrEmpty($chosen)) {
            # 루트(.) 기준 마커명으로 힌트 — 어떤 파일이 있는 폴더인지 사용자에게 명시
            $hintMarker = Get-ExistingMarkerInDir $t "."
            $promptText = "  $t 프로젝트 루트 경로 입력 ($hintMarker 이 있는 폴더, 예: server, app — 루트면 그냥 Enter"
            if ($existing) { $promptText = "$promptText, 현재값: $existing" }
            $promptText = "$promptText)"
            $userInput = Read-UserInput $promptText
            if ($null -eq $userInput) { $userInput = "" }
            # 정규화: 앞뒤 공백만 트림(내부 공백 보존), 백슬래시→슬래시, 끝 슬래시·앞 ./ 제거
            $userInput = $userInput.Trim().Replace('\', '/').TrimEnd('/') -replace '^\./', ''
            if ([string]::IsNullOrEmpty($userInput)) {
                if ($existing) { $userInput = $existing } else { $userInput = "." }
            }
            # 검증: 입력 경로에 마커 존재 확인 (보조 마커 포함)
            $inMarker = Get-ExistingMarkerInDir $t $userInput
            if (Test-Path (Join-Path $userInput $inMarker) -PathType Leaf) {
                $chosen = $userInput
            } else {
                Print-Warning "  $userInput/$inMarker 파일이 없습니다."
                if (Ask-YesNo "  그래도 이 경로를 사용할까요? (Y/N)" "N") { $chosen = $userInput }
            }
        }

        $script:ProjectPaths[$t] = $chosen
        Print-Success "  $t → $chosen"
    }

    # ── 요약 + 동일 파일 중복 안내 (스펙 §4.4) ──
    Write-Host ""
    Write-Host "📂 타입별 버전 파일 경로 확정:"
    $fileToTypes = @{}
    foreach ($key in $script:ProjectPaths.Keys) {
        $p = $script:ProjectPaths[$key]
        if ([string]::IsNullOrEmpty($p)) { $p = "." }
        $m = Get-ExistingMarkerInDir $key $p
        if ($p -eq ".") { $file = $m } else { $file = "$p/$m" }
        Write-Host "   $key → $file"
        if (-not $fileToTypes.ContainsKey($file)) { $fileToTypes[$file] = @() }
        $fileToTypes[$file] += $key
    }
    foreach ($file in $fileToTypes.Keys) {
        if ($fileToTypes[$file].Count -gt 1) {
            Print-Warning "  ⚠️ 같은 파일($file)을 여러 타입($($fileToTypes[$file] -join ', '))이 바라봅니다."
            Print-Warning "     → 이렇게 하면 sync 때 모두 같은 버전이 기록됩니다. 동작에는 문제없지만 의도한 구성인지 확인하세요."
        }
    }
    Write-Host ""
}

# ===================================================================
# 버전 자동 감지
# ===================================================================

function Detect-Version {
    Print-Step "버전 정보 자동 감지 중..."
    
    $detectedVersion = ""
    
    # package.json
    if (Test-Path "package.json") {
        try {
            $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
            if ($packageJson.version) {
                $detectedVersion = $packageJson.version
                Print-Info "✓ package.json에서 버전 감지: v$detectedVersion"
                return $detectedVersion
            }
        } catch {
            # JSON 파싱 실패 시 무시
        }
    }
    
    # build.gradle (Spring Boot)
    if (Test-Path "build.gradle") {
        $content = Get-Content "build.gradle" -Raw
        if ($content -match 'version\s*=\s*[''"]?([0-9]+\.[0-9]+\.[0-9]+)') {
            $detectedVersion = $matches[1]
            Print-Info "✓ build.gradle에서 버전 감지: v$detectedVersion"
            return $detectedVersion
        }
    }
    
    # pubspec.yaml (Flutter)
    if (Test-Path "pubspec.yaml") {
        $content = Get-Content "pubspec.yaml" -Raw
        if ($content -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
            $detectedVersion = $matches[1]
            Print-Info "✓ pubspec.yaml에서 버전 감지: v$detectedVersion"
            return $detectedVersion
        }
    }
    
    # pyproject.toml (Python)
    if (Test-Path "pyproject.toml") {
        $content = Get-Content "pyproject.toml" -Raw
        if ($content -match 'version\s*=\s*[''"]?([0-9]+\.[0-9]+\.[0-9]+)') {
            $detectedVersion = $matches[1]
            Print-Info "✓ pyproject.toml에서 버전 감지: v$detectedVersion"
            return $detectedVersion
        }
    }
    
    # Git 태그
    try {
        $gitTag = git describe --tags --abbrev=0 2>$null
        if ($gitTag) {
            $detectedVersion = $gitTag -replace '^v', ''
            Print-Info "✓ Git 태그에서 버전 감지: v$detectedVersion"
            return $detectedVersion
        }
    } catch {
        # Git 명령 실패 시 무시
    }
    
    # 기본값
    Print-Warning "버전을 감지하지 못했습니다. 기본값 0.0.1로 설정합니다."
    return "0.0.1"
}

# ===================================================================
# Default Branch 감지
# ===================================================================

function Detect-DefaultBranch {
    $detected = ""
    
    # git symbolic-ref
    try {
        $detected = git symbolic-ref refs/remotes/origin/HEAD 2>$null
        if ($detected) {
            $detected = $detected -replace '^refs/remotes/origin/', ''
            return $detected
        }
    } catch {}
    
    # git remote show
    try {
        $output = git remote show origin 2>$null
        foreach ($line in $output) {
            if ($line -match 'HEAD branch:\s*(.+)') {
                return $matches[1].Trim()
            }
        }
    } catch {}
    
    # 기본값
    return "main"
}

# ===================================================================
# 프로젝트 타입 선택 메뉴
# ===================================================================

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
    if (-not $curVal) { $curVal = "basic" }
    Write-Host ("   • 현재 값: {0}" -f $curVal)
    Write-Host ""

    # ── preselect: 마커 추천이 있으면 그것, 없으면 현재값 ──
    if ($markerCsv) { $preselect = $markerCsv }
    else { $preselect = ($script:ProjectTypes -join ',') }

    $selected = Invoke-ChooseMenu -Multi -CancelLabel "뒤로" -Preselect $preselect -Prompt "프로젝트 타입을 선택하세요" -Options @(
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
        Print-Error "타입 선택을 취소했습니다 — 기존 설정을 그대로 유지합니다."
        if ($script:ProjectTypes.Count -gt 0) { return ($script:ProjectTypes -join ',') }
        return $script:ProjectType
    }

    return $selected
}

# ===================================================================
# 프로젝트 정보 수정 메뉴
# ===================================================================

function Edit-ProjectInfo {
    # 루프 구조(sh handle_project_edit_menu와 대칭): 항목을 고쳐도 메뉴로 되돌아와
    # 다른 항목을 이어서 수정할 수 있다. '모두 맞음, 계속' 또는 '뒤로' → 확인 화면으로 복귀.
    # ps1은 숫자 입력 메뉴라 ESC 키가 없어 '뒤로'를 명시적 항목으로 제공한다.
    while ($true) {
        Print-QuestionHeader "💫" "어떤 항목을 수정할까요?"

        # Synology 항목은 워크플로우를 설치하는 모드(full/workflows)에서만 의미가 있다.
        # (version 모드는 워크플로우를 안 깔아 Synology와 무관 → 메뉴에 노출하지 않는다.)
        $_synEditable = ($script:Mode -eq "full" -or $script:Mode -eq "workflows")

        $_editOptions = @(
            @{Value='type';    Label='프로젝트 타입'},
            @{Value='version'; Label='버전'},
            @{Value='branch';  Label='기본 브랜치'}
        )
        if ($_synEditable) {
            $_synState = if ($script:IncludeSynology -eq $true) { '포함' } else { '제외' }
            $_editOptions += @{Value='synology'; Label="Synology 포함 여부 (현재: $_synState)"}
        }
        $_editOptions += @{Value='done';    Label='모두 맞음, 계속'}
        $_editOptions += @{Value='back';    Label='뒤로 (변경 없이 확인 화면으로)'}

        # 하위 메뉴이므로 ESC는 '뒤로'(상위 확인 화면으로). ESC + '뒤로' 항목 둘 다 제공.
        $editChoice = Invoke-ChooseMenu -CancelLabel "뒤로" -Prompt "어떤 항목을 수정하시겠습니까?" -Options $_editOptions

        # ESC($null) 또는 '뒤로' → 상위 확인 화면으로 복귀 (sh handle_project_edit_menu와 대칭)
        if ((-not $editChoice) -or ($editChoice -eq 'back')) {
            return
        }

        switch ($editChoice) {
            'type' {
                $oldCsv = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes -join ',' } else { $script:ProjectType }
                $newCsv = Show-ProjectTypeMenu
                if ($newCsv) {
                    $script:ProjectTypes = @($newCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                    $script:ProjectType = $script:ProjectTypes[0]
                    if ($script:ProjectTypes.Count -gt 1) {
                        Print-Success "프로젝트 타입을 '$($script:ProjectTypes -join ', ')'(으)로 변경했습니다"
                    } else {
                        Print-Success "프로젝트 타입을 '$($script:ProjectType)'(으)로 변경했습니다"
                    }
                    # ★ 타입이 실제로 바뀌었으면 그 자리에서 path 감지를 바로 이어 붙임
                    # (선택 순서가 달라도 같은 집합이면 변경 아님 — 정렬 후 비교)
                    $oldSorted = (($oldCsv -split ',' | Sort-Object) -join ',')
                    $newSorted = (($newCsv -split ',' | Sort-Object) -join ',')
                    if ($newSorted -ne $oldSorted) {
                        $script:ProjectPaths = [ordered]@{}
                        Resolve-ProjectPaths
                    }
                }
                Write-Host ""
            }
            'version' {
                Write-Host ""
                # 빈 입력(그냥 Enter)은 '뒤로'(기존 값 유지)로 취급 — sh의 ESC=뒤로와 동작 대칭.
                $newVersion = Read-UserInput "새 버전을 입력하세요 (예: 1.0.0, 그냥 Enter=뒤로)"
                Write-Host ""

                if ([string]::IsNullOrWhiteSpace($newVersion)) {
                    Print-Info "이전 메뉴로 돌아갑니다 — 기존 설정을 유지합니다."
                } elseif ($newVersion -match '^[0-9]+\.[0-9]+\.[0-9]+$') {
                    $script:ProjectVersion = $newVersion
                    Print-Success "버전을 '$($script:ProjectVersion)'(으)로 변경했습니다"
                } else {
                    Print-Error "버전 형식이 올바르지 않습니다 (x.y.z 형태로 입력) — 기존 값을 유지합니다."
                }
                Write-Host ""
            }
            'branch' {
                Write-Host ""
                Write-Host "💡 이 설정은 GitHub Actions 워크플로우에서 사용할 기본 브랜치입니다."
                Write-Host ""
                # 빈 입력(그냥 Enter)은 '뒤로'(기존 값 유지)로 취급.
                $newBranch = Read-UserInput "기본 브랜치 이름을 입력하세요 (예: main, develop, 그냥 Enter=뒤로)"
                Write-Host ""

                if (![string]::IsNullOrWhiteSpace($newBranch)) {
                    $script:DetectedBranch = $newBranch
                    Print-Success "기본 브랜치를 '$($script:DetectedBranch)'(으)로 변경했습니다"
                } else {
                    Print-Info "이전 메뉴로 돌아갑니다 — 기존 설정을 유지합니다."
                }
                Write-Host ""
            }
            'synology' {
                # Synology 포함 여부를 다시 묻는다. -ForceAsk로 이미 설정된 값이 있어도 무조건 재질문.
                # Ask-SynologyOption이 폴더를 스캔해 발견 시 안내+질문하고 $script:IncludeSynology를 갱신한다.
                $synTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
                $typeDirs = @($synTypes | ForEach-Object { Join-Path $TEMP_DIR "$WORKFLOWS_DIR\$PROJECT_TYPES_DIR\$_" })
                Ask-SynologyOption -TypeDirs $typeDirs -ForceAsk
                Write-Host ""
            }
            'done' {
                Print-Success "수정을 마쳤습니다 — 확인 화면으로 돌아갑니다"
                Write-Host ""
                return
            }
            'back' {
                # 변경 없이 상위 확인 화면으로 복귀
                return
            }
        }
    }
}

# ===================================================================
# 프로젝트 감지 및 확인
# ===================================================================

function Detect-AndConfirmProject {
    # 자동 감지 (최초 1회만) — -Type으로 ProjectTypes가 이미 채워졌으면 건너뜀
    if ($script:ProjectTypes.Count -eq 0) {
        $detectedCsv = Detect-ProjectTypes
        $script:ProjectTypes = @($detectedCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $script:ProjectType = $script:ProjectTypes[0]
    }
    if ([string]::IsNullOrWhiteSpace($script:ProjectVersion)) {
        $script:ProjectVersion = Detect-Version
    }
    if ([string]::IsNullOrWhiteSpace($script:DetectedBranch)) {
        $script:DetectedBranch = Detect-DefaultBranch
    }

    $confirmed = $false

    # 확인 루프 - Edit 선택 시 다시 확인 질문으로 돌아옴
    while (-not $confirmed) {
        Print-SectionHeader "🛰️" "프로젝트 분석 결과"

        # 감지 결과 표시 — 멀티면 csv로, 단일이면 기존 형식
        Write-Host ""
        if ($script:ProjectTypes.Count -gt 1) {
            Write-Host "       📂 Project Types    : $($script:ProjectTypes -join ',') (멀티)"
        } else {
            Write-Host "       📂 Project Type     : $($script:ProjectType)"
        }
        Write-Host "       🌙 Version          : $($script:ProjectVersion)"
        Write-Host "       🌿 Default Branch   : $($script:DetectedBranch)"
        # 모드 / Synology / 멀티경로 (값이 있을 때만 — sh와 동일)
        if ($script:Mode) { Write-Host "       💫 통합 모드        : $(Get-ModeDisplayLabel $script:Mode)" }
        if ($script:IncludeSynology -eq $true)  { Write-Host "       🗄️ Synology         : 포함" }
        elseif ($script:IncludeSynology -eq $false) { Write-Host "       🗄️ Synology         : 제외" }
        if ($script:ProjectPaths -and $script:ProjectPaths.Count -gt 0) {
            $pathPairs = @($script:ProjectPaths.GetEnumerator() | ForEach-Object { "$($_.Key)→$($_.Value)" }) -join ', '
            Write-Host "       📁 프로젝트 경로    : $pathPairs"
        }
        Write-Host ""

        # 사용자 확인 — 화살표 3지선(Ask-YesNoEdit가 자체 안내 출력). ESC=stay.
        $userChoice = Ask-YesNoEdit

        switch ($userChoice) {
            "yes" {
                $confirmed = $true
                Print-Success "프로젝트 정보 검증 완료 — 이 설정으로 통합을 진행합니다"
                Write-Host ""
            }
            "no" {
                Print-Info "통합을 취소했습니다. (다시 실행하면 처음부터 설정할 수 있습니다)"
                exit 0
            }
            "edit" {
                Edit-ProjectInfo
                # 루프 계속 - 다시 확인 질문으로
            }
            "stay" {
                # ESC 등 중립 상태 — 종료하지 않고 확인 화면을 다시 보여준다 (sh와 동일)
            }
        }
    }
}

# ===================================================================
# 템플릿 다운로드
# ===================================================================

function Download-Template {
    Print-Step "템플릿을 GitHub 저장소에서 내려받고 있습니다..."
    
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }
    
    try {
        git clone --depth 1 --quiet $TEMPLATE_REPO $TEMP_DIR 2>&1 | Out-Null
    } catch {
        Print-Error "템플릿 다운로드 실패"
        exit 1
    }
    
    # 문서 파일 제거 (프로젝트 특화 문서는 복사하지 않음)
    Print-Info "프로젝트에는 불필요한 템플릿 내부 문서를 정리하고 있습니다..."
    $docsToRemove = @(
        "CONTRIBUTING.md",
        "CLAUDE.md",
        "AGENTS.md",
        "GEMINI.md",
        "gemini-extension.json"
    )
    
    foreach ($doc in $docsToRemove) {
        $docPath = Join-Path $TEMP_DIR $doc
        if (Test-Path $docPath) {
            Remove-Item -Path $docPath -Force
        }
    }

    # 플러그인 전용 파일/폴더 제거 (마켓플레이스 전용, template_integrator로 배포하지 않음)
    Print-Info "마켓플레이스 전용 파일(플러그인 메타데이터 등)을 정리하고 있습니다..."
    $pluginItemsToRemove = @(
        ".claude-plugin",   # Claude Code 플러그인 매니페스트
        ".codex-plugin",    # Codex 플러그인 메타데이터
        ".agents",          # Codex 마켓플레이스 메타데이터
        ".cursor",          # Cursor 스킬 복사본
        "scripts",          # 플러그인 스크립트 (마켓플레이스 전용)
        "package.json",     # pi 패키지 매니페스트 (마켓플레이스 전용)
        "harness"           # pi Persona Harness (loader/PERSONA/WORKFLOW, 마켓플레이스 전용)
    )
    # 주의: skills/ 폴더는 Cursor IDE 복사용으로 보존 (Offer-IdeToolsInstall에서 사용 후 정리)

    foreach ($item in $pluginItemsToRemove) {
        $itemPath = Join-Path $TEMP_DIR $item
        if (Test-Path $itemPath) {
            Remove-Item -Path $itemPath -Recurse -Force
        }
    }

    # 사용자 적용 가이드 문서는 포함
    Print-Info "사용자용 적용 가이드 문서를 내려받고 있습니다..."
    $guidePath = Join-Path $TEMP_DIR "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    if (Test-Path $guidePath) {
        Print-Info "✓ SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    }

    # 다운로드한 템플릿에서 버전 읽기 (TemplateVersion 전역 변수에 저장)
    $templateVersionFile = Join-Path $TEMP_DIR "version.yml"
    if (Test-Path $templateVersionFile) {
        $versionContent = Get-Content $templateVersionFile -Raw -ErrorAction SilentlyContinue
        if ($versionContent -match 'version:\s*[''"]?([0-9.]+)') {
            $script:TemplateVersion = $matches[1]
        } else {
            $script:TemplateVersion = $DEFAULT_VERSION
        }
    } else {
        $script:TemplateVersion = $DEFAULT_VERSION
    }

    Print-Success "템플릿 다운로드 완료 — 이제 프로젝트에 맞게 구성합니다"
}

# ===================================================================
# README.md 버전 섹션 추가
# ===================================================================

function Add-VersionSectionToReadme {
    param([string]$Version)
    
    Print-Step "README.md에 버전 관리 섹션 추가 중..."
    
    if (-not (Test-Path "README.md")) {
        Print-Warning "README.md를 찾지 못해 이 단계를 건너뜁니다."
        return
    }
    
    # 이미 버전 섹션이 있는지 확인 (영어 마커만 체크 - 파싱 호환성)
    $readmeContent = Get-Content "README.md" -Raw

    if ($readmeContent -match "<!-- AUTO-VERSION-SECTION") {
        Print-Info "이미 버전 관리 섹션이 있습니다. (마커 감지)"
        return
    }

    # 버전 라인 체크 (버전 번호 패턴 감지)
    if ($readmeContent -match "(?i)##\s*(최신\s*버전|최신버전|Version|버전)\s*:\s*v\d+\.\d+\.\d+") {
        Print-Info "이미 버전 관리 섹션이 있습니다. (버전 라인 감지)"
        return
    }

    # README.md 끝에 버전 섹션 추가
    $versionSection = @"

---

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v$Version

[전체 버전 기록 보기](CHANGELOG.md)
"@
    
    Add-Content -Path "README.md" -Value $versionSection -Encoding UTF8
    
    Print-Success "README.md에 버전 관리 섹션을 추가했습니다"
    Print-Info "📝 위치: README.md 파일 하단"
    Print-Info "🔄 자동 업데이트: PROJECT-README-VERSION-UPDATE.yaml 워크플로우"
}

# ===================================================================
# version.yml 생성
# ===================================================================

function Create-VersionYml {
    param(
        [string]$Version,
        [string]$Type,
        [string]$Branch
    )
    
    $existingVersionCode = 1  # 기본값
    
    Print-Step "version.yml 생성 중..."
    
    if (Test-Path "version.yml") {
        # 기존 version.yml에서 version_code 추출
        # 주석이 아닌 실제 데이터 라인에서만 추출 (주석 내 'version_code: 1' 오탐지 방지)
        $lines = Get-Content "version.yml" -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            # 주석 라인 건너뛰기 (# 으로 시작하는 라인)
            if ($line -match '^\s*#') {
                continue
            }
            # version_code 값 추출 (라인 시작부터 매칭)
            if ($line -match '^version_code:\s*(\d+)') {
                $parsedValue = [int]$matches[1]
                if ($parsedValue -gt 0) {
                    $existingVersionCode = $parsedValue
                    Print-Info "기존 version_code 감지: $existingVersionCode"
                }
                break
            }
        }
        
        # version 보존: version.yml이 버전 관리의 single source of truth.
        # 기존 version.yml의 version을 최우선으로 읽어 유지하고, 없을 때만 감지값($Version) 폴백.
        foreach ($line in $lines) {
            if ($line -match '^\s*#') { continue }
            if ($line -match '^version:\s*["'']?([0-9][0-9.]*)') {
                $Version = $matches[1]
                Print-Info "기존 version 보존: $Version"
                break
            }
        }

        # 덮어쓰기 확인 — version.yml 갱신은 통합에 필수.
        # Y=업데이트하고 계속(기본) / N=통합 전체 취소 (반쪽 상태 방지)
        if (-not $Force) {
            Write-Host ""
            Print-SeparatorLine
            Write-Host " 🔄 version.yml 업데이트 — 안전합니다, 필수입니다"
            Print-SeparatorLine
            Write-Host ""
            Write-Host "  기존 version.yml을 최신 템플릿 구조로 갱신합니다."
            Write-Host "  이 단계는 통합에 반드시 필요합니다."
            Write-Host ""
            Write-Host "  ✅ 유지되는 값 (그대로 보존)"
            Write-Host ("       {0,-14} {1,-11} {2}" -f "version", $Version, "롤백 없음")
            Write-Host ("       {0,-14} {1,-11} {2}" -f "version_code", $existingVersionCode, "스토어 빌드번호 안전")
            Write-Host ""
            Write-Host "  📝 갱신되는 것"
            Write-Host "       구조, 주석, project_paths, metadata"
            Write-Host ""
            Write-Host "  ⚠️  업데이트하지 않으면 구버전 구조가 남아"
            Write-Host "       최신 워크플로우의 버전 자동증가, 체인지로그, 배포"
            Write-Host "       동기화가 깨집니다. 그래서 건너뛸 수 없습니다."
            Write-Host ""

            # 기본값 Y — Enter만 쳐도 업데이트. N이면 통합 전체 중단.
            # 선택지(예/아니오)는 아래 Ask-YesNo가 화살표 메뉴로 직접 보여주므로 여기서 중복 안내하지 않는다.
            if (-not (Ask-YesNo "  선택" "Y")) {
                Print-Error "통합이 취소되었습니다. version.yml은 변경되지 않았습니다."
                exit 0
            }
        }
    }
    
    $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $integrationDate = Get-Date -Format "yyyy-MM-dd"

    # 멀티타입 — ProjectTypes 배열을 ["a","b"] json 형태로, primary는 첫 항목
    # (배열이 비었으면 $Type 단수로 fallback — 하위 호환)
    if ($script:ProjectTypes.Count -gt 0) {
        $typesJson = '[' + (($script:ProjectTypes | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'
        $primaryType = $script:ProjectTypes[0]
    } else {
        $typesJson = "[`"$Type`"]"
        $primaryType = $Type
    }

    # project_paths 블록 (Resolve-ProjectPaths가 확정한 값 — 비어있으면 생략)
    $pathsBlock = ""
    if ($script:ProjectPaths.Count -gt 0) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('project_paths:                # 타입별 프로젝트 폴더 (레포 루트 기준 상대경로)')
        foreach ($key in $script:ProjectPaths.Keys) {
            $p = $script:ProjectPaths[$key]
            if ([string]::IsNullOrEmpty($p)) { $p = "." }
            $m = Get-ExistingMarkerInDir $key $p
            if ($p -eq ".") { $file = $m } else { $file = "$p/$m" }
            [void]$sb.AppendLine("  ${key}: `"$p`"   # $file")
        }
        $pathsBlock = $sb.ToString()
    }

    $part1 = @"
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
# - react/next/node: package.json ("version": "x.y.z")
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

version: "$Version"
version_code: $existingVersionCode  # app build number
project_types: $typesJson   # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능
project_type: "$primaryType"  # project_types[0] 자동 미러 — 직접 수정 금지 (spring, flutter, next, react, react-native, react-native-expo, node, python, basic)

"@

    $part2 = @"
metadata:
  last_updated: "$currentDate"
  last_updated_by: "template_integrator"
  default_branch: "$Branch"
  integrated_from: "SUH-DEVOPS-TEMPLATE"
  integration_date: "$integrationDate"
"@

    $versionYmlContent = $part1.TrimEnd("`r", "`n") + "`r`n" + $pathsBlock + $part2
    Set-Content -Path "version.yml" -Value $versionYmlContent -Encoding UTF8

    Print-Success "version.yml 생성 완료 — 이 파일이 버전 관리의 기준이 됩니다"
}

# ===================================================================
# Synology 옵션 관리 함수
# ===================================================================

function Read-TemplateOptions {
    $versionFile = "version.yml"

    if (-not (Test-Path $versionFile)) {
        return
    }

    $content = Get-Content -Path $versionFile -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        return
    }

    # template.options.synology 값 찾기
    $inTemplate = $false
    $inOptions = $false

    foreach ($line in (Get-Content -Path $versionFile)) {
        # template: 섹션 시작 확인
        if ($line -match "^\s*template:") {
            $inTemplate = $true
            continue
        }

        # template 섹션 내부에서 options: 확인
        if ($inTemplate -and $line -match "^\s+options:") {
            $inOptions = $true
            continue
        }

        # options 섹션 내부에서 synology 값 확인
        if ($inTemplate -and $inOptions) {
            if ($line -match "^\s+synology:\s*(.+)") {
                $synologyVal = $matches[1].Trim().Trim('"').Trim("'")

                if ($synologyVal -eq "true" -or $synologyVal -eq "True") {
                    $script:IncludeSynology = $true
                    Print-Info "이전 설정 기준 Synology 옵션: 포함 — 같은 설정으로 진행합니다"
                }
                elseif ($synologyVal -eq "false" -or $synologyVal -eq "False") {
                    $script:IncludeSynology = $false
                    Print-Info "이전 설정 기준 Synology 옵션: 제외 — 같은 설정으로 진행합니다"
                }
                return
            }

            # 다른 최상위 키 만나면 options 섹션 종료
            if ($line -match "^\s{0,4}[a-z_]+:") {
                $inOptions = $false
                $inTemplate = $false
            }
        }

        # template 섹션 종료 확인
        if ($inTemplate -and $line -match "^[a-z_]+:") {
            $inTemplate = $false
            $inOptions = $false
        }
    }
}

function Save-TemplateOptions {
    param([string]$TemplateVersion = "unknown")

    $versionFile = "version.yml"
    $today = (Get-Date).ToString("yyyy-MM-dd")

    if (-not (Test-Path $versionFile)) {
        return
    }

    $content = Get-Content -Path $versionFile -Raw

    # 기존에 template 섹션이 있는지 확인
    if ($content -match "template:") {
        # synology 값 업데이트 또는 추가
        if ($content -match "synology:") {
            $content = $content -replace "(?m)synology:.*$", "synology: $($script:IncludeSynology.ToString().ToLower())"
        }
        elseif ($content -match "options:") {
            # options 다음 줄에 synology 추가
            $content = $content -replace "(options:)", "`$1`n      synology: $($script:IncludeSynology.ToString().ToLower())"
        }

        # last_update_date 업데이트
        if ($content -match "last_update_date:") {
            $content = $content -replace '(?m)last_update_date:.*$', "last_update_date: `"$today`""
        }

        Set-Content -Path $versionFile -Value $content -Encoding UTF8
    }
    else {
        # template 섹션 새로 추가
        $templateSection = @"
  template:
    source: "SUH-DEVOPS-TEMPLATE"
    version: "$TemplateVersion"
    integrated_date: "$today"
    last_update_date: "$today"
    options:
      synology: $($script:IncludeSynology.ToString().ToLower())
"@
        Add-Content -Path $versionFile -Value $templateSection -Encoding UTF8
        Print-Info "version.yml에 템플릿 설정 저장됨"
    }
}

# 버전 비교 함수 (v1 > v2 이면 1, v1 < v2 이면 -1, 같으면 0)
function Compare-SemVer {
    param(
        [string]$Version1,
        [string]$Version2
    )

    # v 접두사 제거
    $v1 = $Version1 -replace "^v", ""
    $v2 = $Version2 -replace "^v", ""

    $parts1 = $v1.Split(".")
    $parts2 = $v2.Split(".")

    for ($i = 0; $i -lt 3; $i++) {
        $p1 = if ($i -lt $parts1.Length) { [int]$parts1[$i] } else { 0 }
        $p2 = if ($i -lt $parts2.Length) { [int]$parts2[$i] } else { 0 }

        if ($p1 -gt $p2) { return 1 }
        if ($p1 -lt $p2) { return -1 }
    }

    return 0
}

# Breaking Changes 확인 및 알림
function Test-BreakingChanges {
    param(
        [string]$CurrentVersion,
        [string]$NewVersion
    )

    # 버전 정보가 없으면 (레거시 프로젝트) 스킵
    if ([string]::IsNullOrEmpty($CurrentVersion) -or $CurrentVersion -eq "unknown") {
        return $true
    }

    # -Force 모드면 스킵
    if ($Force) {
        return $true
    }

    # breaking-changes.json 다운로드
    $bcUrl = "$script:TemplateRawUrl/.github/config/breaking-changes.json"
    try {
        $bcJson = Invoke-RestMethod -Uri $bcUrl -UseBasicParsing -ErrorAction Stop
    }
    catch {
        return $true
    }

    # breaking changes 버전 목록 추출 (객체 속성 중 _ 로 시작하지 않는 것)
    $versions = $bcJson.PSObject.Properties | Where-Object { $_.Name -notlike "_*" } | Select-Object -ExpandProperty Name

    # 해당 버전 범위의 breaking changes 수집
    $criticalChanges = @()
    $warningChanges = @()

    foreach ($ver in $versions) {
        # CurrentVersion < ver <= NewVersion 인 경우만 해당
        $cmpCurrent = Compare-SemVer -Version1 $ver -Version2 $CurrentVersion
        $cmpNew = Compare-SemVer -Version1 $ver -Version2 $NewVersion

        if ($cmpCurrent -eq 1 -and $cmpNew -ne 1) {
            $change = $bcJson.$ver
            $severity = if ($change.severity) { $change.severity } else { "warning" }
            $title = if ($change.title) { $change.title } else { "" }
            $message = if ($change.message) { $change.message } else { "" }

            $changeInfo = @{
                Version = "v$ver"
                Title = $title
                Message = $message
            }

            if ($severity -eq "critical") {
                $criticalChanges += $changeInfo
            }
            else {
                $warningChanges += $changeInfo
            }
        }
    }

    # breaking change가 없으면 리턴
    $totalChanges = $criticalChanges.Count + $warningChanges.Count
    if ($totalChanges -eq 0) {
        return $true
    }

    # 알림 표시
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗"
    Write-Host "║  ⚠️  BREAKING CHANGES (v$CurrentVersion → v$NewVersion)"
    Write-Host "╠══════════════════════════════════════════════════════════════════╣"

    # Critical changes 표시
    foreach ($change in $criticalChanges) {
        Write-Host "║"
        Write-Host "║  " -NoNewline
        Write-Host "[CRITICAL]" -ForegroundColor Red -NoNewline
        Write-Host " $($change.Version) - $($change.Title)"
        Write-Host "║  → $($change.Message)"
    }

    # Warning changes 표시
    foreach ($change in $warningChanges) {
        Write-Host "║"
        Write-Host "║  " -NoNewline
        Write-Host "[WARNING]" -ForegroundColor Yellow -NoNewline
        Write-Host " $($change.Version) - $($change.Title)"
        Write-Host "║  → $($change.Message)"
    }

    Write-Host "║"
    Write-Host "╚══════════════════════════════════════════════════════════════════╝"
    Write-Host ""

    # Critical이 있으면 Y/N 확인
    if ($criticalChanges.Count -gt 0) {
        Print-Warning "주의가 필요한 호환성 변경(CRITICAL)이 있습니다. 아래 내용을 꼭 확인하세요."
        Write-Host ""
        Write-Host ""

        # 선택지(예/아니오)는 아래 Ask-YesNo가 화살표 메뉴로 직접 보여주므로 여기서 중복 안내하지 않는다.
        if (-not (Ask-YesNo -Prompt "위 호환성 변경을 확인했고 계속 진행할까요? " -Default "N")) {
            Print-Info "통합을 안전하게 취소했습니다."
            exit 0
        }
    }

    return $true
}

# 현재 프로젝트의 템플릿 버전 읽기
function Get-CurrentTemplateVersion {
    $versionFile = "version.yml"

    if (-not (Test-Path $versionFile)) {
        return "unknown"
    }

    $content = Get-Content -Path $versionFile -Raw

    # metadata.template.version 읽기 (template 섹션 내 version만 정확히 매칭)
    if ($content -match "template:\s*\r?\n\s+source:[^\r\n]+\r?\n\s+version:\s*[`"']?([0-9.]+)[`"']?") {
        return $matches[1]
    }

    return "unknown"
}

function Ask-SynologyOption {
    # 여러 TypeDir를 받을 수 있다 (멀티타입). 각 타입의 synology 폴더 +
    # 공통 synology 폴더를 모두 합산해 한 번만 질문한다.
    # -ForceAsk: 이미 설정된 IncludeSynology가 있어도 무조건 다시 묻는다
    #            (확인 화면의 수정 메뉴에서 사용 — 사용자가 명시적으로 다시 고르려는 경우)
    param(
        [string[]]$TypeDirs,
        [switch]$ForceAsk
    )

    if (-not $TypeDirs -or $TypeDirs.Count -eq 0) { return }

    # 비대화형 환경 감지 (파이프라인, 리디렉션, 비대화형 세션 등)
    $isNonInteractive = $false
    try {
        if (-not [Environment]::UserInteractive) {
            $isNonInteractive = $true
        }
        elseif ([Console]::IsInputRedirected) {
            $isNonInteractive = $true
        }
    }
    catch {
        # Console 접근 실패 시 비대화형으로 간주
        $isNonInteractive = $true
    }

    if ($isNonInteractive) {
        $script:IncludeSynology = $false
        return
    }

    # 검사 대상 synology 폴더 목록 구성 (타입별 + 공통, 중복 제거)
    $synologyDirs = New-Object System.Collections.Generic.List[string]
    foreach ($td in $TypeDirs) {
        $sd = Join-Path $td "synology"
        if (-not $synologyDirs.Contains($sd)) { $synologyDirs.Add($sd) }
        $csd = Join-Path (Split-Path $td -Parent) "common\synology"
        if (-not $synologyDirs.Contains($csd)) { $synologyDirs.Add($csd) }
    }

    # synology 폴더가 하나도 존재하지 않으면 건너뛰기
    $anyDir = $false
    foreach ($d in $synologyDirs) { if (Test-Path $d) { $anyDir = $true; break } }
    if (-not $anyDir) { return }

    # CLI 파라미터로 이미 지정된 경우
    if ($Synology) {
        $script:IncludeSynology = $true
        return
    }
    if ($NoSynology) {
        $script:IncludeSynology = $false
        return
    }

    # 이미 설정되어 있으면 건너뛰기 (단, -ForceAsk면 무시하고 다시 묻는다)
    if (-not $ForceAsk -and $null -ne $script:IncludeSynology) {
        return
    }

    # 기존 version.yml에서 설정 읽기 시도 (-ForceAsk면 저장값으로 덮어쓰지 않는다)
    if (-not $ForceAsk) {
        Read-TemplateOptions

        # 이전 설정이 있으면 건너뛰기
        if ($null -ne $script:IncludeSynology) {
            return
        }
    }

    # synology 폴더 내 파일 목록 수집 (전체 대상 폴더 합산, 타입별/공통 구분)
    $typeFiles = @()
    $commonFiles = @()
    foreach ($d in $synologyDirs) {
        if (-not (Test-Path $d)) { continue }
        $yamlFiles = Get-ChildItem -Path $d -Filter "*.yaml" -ErrorAction SilentlyContinue
        $ymlFiles = Get-ChildItem -Path $d -Filter "*.yml" -ErrorAction SilentlyContinue
        $found = @()
        if ($yamlFiles) { $found += $yamlFiles }
        if ($ymlFiles) { $found += $ymlFiles }
        if ($d -like "*\common\synology") { $commonFiles += $found } else { $typeFiles += $found }
    }

    $totalSynologyCount = $typeFiles.Count + $commonFiles.Count
    if ($totalSynologyCount -eq 0) {
        return
    }

    Print-SeparatorLine
    Write-Host ""
    Write-Host "🗄️ Synology NAS 배포용 워크플로우를 발견했습니다. ($totalSynologyCount개 파일)"
    Write-Host ""
    Write-Host "   📦 Synology(시놀로지)란?"
    Write-Host "      개인·소규모 팀이 많이 쓰는 NAS(자체 서버) 장비입니다."
    Write-Host "      이 워크플로우들은 빌드 결과물을 그 Synology 서버에 자동 배포(CI/CD)해 줍니다."
    Write-Host ""
    Write-Host "   ❓ 포함할까요?"
    Write-Host "      • Synology NAS에 직접 배포할 계획이면 → 포함"
    Write-Host "      • AWS·클라우드·다른 서버를 쓰거나 잘 모르겠으면 → 제외 (기본값, 안전)"
    Write-Host "      나중에 --synology 옵션으로 언제든 추가할 수 있습니다."
    Write-Host ""
    Write-Host "   포함되는 워크플로우:"
    foreach ($f in $typeFiles) {
        Write-Host "     • $($f.Name)"
    }
    foreach ($f in $commonFiles) {
        Write-Host "     • $($f.Name) (공통)"
    }
    Write-Host ""

    # 선택지(예/아니오)는 아래 Ask-YesNo가 화살표 메뉴로 직접 보여주므로 여기서 중복 안내하지 않는다.
    if (Ask-YesNo "Synology 워크플로우를 포함할까요?" "N") {
        $script:IncludeSynology = $true
        Print-Info "Synology 워크플로우를 포함합니다 — GitHub Actions에 추가됩니다"
    }
    else {
        $script:IncludeSynology = $false
        Print-Info "Synology 워크플로우를 제외합니다 (나중에 --synology 옵션으로 추가 가능)"
    }
}

# ===================================================================
# 워크플로우 env 동적 설정 (토큰 + @wizard 마커 엔진) — .sh configure_workflow_env와 1:1
# ===================================================================
# 워크플로우 env의 "__TOKEN__"을 프로젝트에 맞게 자동 치환. 마법사는 '# @wizard' 마커를 스캔.
#   ask → 기본값 우선순위로 질문(엔터=기본값) 후 치환 + version.yml 저장
#   auto → 레포명 등 자동값  /  auto-find → find 탐색  /  paths-anchor → 모노레포 paths 주입

# 배포 설정 기억용 (재실행 기본값 제안 + version.yml deploy 블록). type→(KEY→값) 중첩 해시.
$script:WfDeploy = [ordered]@{}
$script:WfUseDefaults = $null   # "전부 기본값 일괄" 모드 (1회 질문)

# 레포명 자동 도출 (PROJECT_NAME auto 값)
function Get-RepoName {
    $url = ""
    try { $url = (git remote get-url origin 2>$null) } catch {}
    if ($url) {
        if ($url -match '[/:]([^/]+)/([^/.]+?)(\.git)?/?$') { return $Matches[2] }
    }
    return (Split-Path -Leaf (Get-Location).Path)
}

# 타입별 상식 기본값 (ask 디폴트 우선순위 2). {name}은 호출측이 치환.
function Get-DefaultForTypeKey {
    param([string]$Type, [string]$Key)
    switch ("${Type}:${Key}") {
        'spring:DEPLOY_PORT' { return '8080' }
        'python:DEPLOY_PORT' { return '8000' }
        'react:DEPLOY_PORT'  { return '3000' }
        'next:DEPLOY_PORT'   { return '3000' }
        'node:DEPLOY_PORT'   { return '3000' }
        'spring:JAVA_VERSION'  { return '21' }
        'flutter:JAVA_VERSION' { return '17' }
        'spring:VOLUME_HOST_PATH' { return '/volume1/projects/{name}' }
        'python:VOLUME_HOST_PATH' { return '/volume1/projects/{name}' }
        'spring:VOLUME_CONTAINER_PATH' { return '/mnt/{name}' }
        'python:VOLUME_CONTAINER_PATH' { return '/mnt/{name}' }
        'spring:DOMAIN_NAME' { return 'example.com' }
        'spring:PRODUCTION_DOMAIN' { return 'example.com' }
        default { return '' }
    }
}

# WfDeploy 조회/저장 (우선순위 1 — 재실행 기존값)
function Get-WfDeploy { param([string]$Type, [string]$Key)
    if ($script:WfDeploy.Contains($Type) -and $script:WfDeploy[$Type].Contains($Key)) {
        return $script:WfDeploy[$Type][$Key]
    }
    return ''
}
function Set-WfDeploy { param([string]$Type, [string]$Key, [string]$Value)
    if (-not $script:WfDeploy.Contains($Type)) { $script:WfDeploy[$Type] = [ordered]@{} }
    $script:WfDeploy[$Type][$Key] = $Value
}

# version.yml deploy 블록에 WfDeploy 기록 (copy_workflows 후 호출, 멱등)
function Update-VersionYmlDeploy {
    if ($script:WfDeploy.Count -eq 0) { return }
    if (-not (Test-Path 'version.yml')) { return }

    $lines = Get-Content 'version.yml'
    # 기존 deploy: 블록 제거 (deploy: ~ 다음 최상위 키 전까지)
    $out = New-Object System.Collections.Generic.List[string]
    $inDeploy = $false
    foreach ($l in $lines) {
        if ($l -match '^deploy:') { $inDeploy = $true; continue }
        if ($inDeploy) {
            if ($l -match '^[^\s]' -or $l -match '^\S') { $inDeploy = $false } else { continue }
        }
        $out.Add($l)
    }

    $block = New-Object System.Collections.Generic.List[string]
    $block.Add('')
    $block.Add('deploy:                          # 마법사가 기억하는 배포 설정 (비민감 / 직접 수정 가능)')
    foreach ($t in $script:WfDeploy.Keys) {
        $block.Add("  ${t}:")
        foreach ($k in $script:WfDeploy[$t].Keys) {
            $v = $script:WfDeploy[$t][$k]
            $block.Add("    ${k}: `"${v}`"")
        }
    }
    ($out + $block) | Set-Content 'version.yml' -Encoding UTF8
    Print-Info "version.yml에 deploy 설정을 기록했습니다 (재통합 시 기본값으로 제안)"
}

# 워크플로우 1개 env 토큰 치환 (.sh configure_workflow_env와 동일 동작)
function Configure-WorkflowEnv {
    param([string]$Type, [string]$File)
    if (-not (Test-Path $File)) { return }
    $content = Get-Content $File -Raw
    if ($content -notmatch '@wizard') { return }   # 안전 폴백: 마커 없으면 미관여

    $repo = Get-RepoName

    # "전부 기본값 일괄" 모드 — 최초 1회 질문
    if ($null -eq $script:WfUseDefaults) {
        $force = $false
        try { if ($script:Force -eq $true) { $force = $true } } catch {}
        if ($force) {
            $script:WfUseDefaults = $true
        } else {
            Print-Step "배포 워크플로우 환경설정을 채웁니다"
            $ans = Read-UserInput "  전부 기본값으로 빠르게 채울까요? (Y=전부기본 / n=하나씩)" "Y"
            if ($ans -match '^[nN]') { $script:WfUseDefaults = $false } else { $script:WfUseDefaults = $true }
        }
    }

    $lines = Get-Content $File
    $newLines = foreach ($line in $lines) {
        if ($line -match '^\s*([A-Z_]+):.*#\s*@wizard\s+(ask|auto-find|auto)') {
            $key = $Matches[1]; $action = $Matches[2]
            $literal = ''
            if ($line -match '\[기본:\s*([^\]]*)\]') { $literal = $Matches[1].Trim() }
            $val = $null

            switch ($action) {
                'auto' {
                    if ($key -eq 'PROJECT_NAME') { $val = $repo } else { $val = $literal }
                }
                'auto-find' {
                    $base = '.'
                    if ($script:ProjectPaths.Contains($Type)) { $base = $script:ProjectPaths[$Type] }
                    $found = Get-ChildItem -Path $base -Recurse -Filter 'application*.yml' -ErrorAction SilentlyContinue |
                             Where-Object { $_.FullName -match 'src[/\\]main[/\\]resources' } | Select-Object -First 1
                    if ($found) {
                        $p = (Resolve-Path -Relative $found.FullName) -replace '^\.[/\\]', '' -replace '\\', '/'
                        if ($key -like '*_DIR') { $p = ($p -replace '/[^/]+$', '') }
                        $val = $p
                    } else {
                        if ($literal -match '__' -or $literal -eq '') { $val = $null } else { $val = $literal }
                    }
                }
                'ask' {
                    $def = Get-WfDeploy $Type $key
                    if (-not $def) { $def = (Get-DefaultForTypeKey $Type $key) -replace '\{name\}', $repo }
                    if ((-not $def) -and $key -eq 'PROJECT_NAME') { $def = $repo }
                    if (-not $def) {
                        if (-not ($literal -match '__|레포|이름|프로젝트')) { $def = $literal }
                    }
                    if ($script:WfUseDefaults) {
                        $val = $def
                    } else {
                        $inp = Read-UserInput "  $key" $def
                        $val = if ([string]::IsNullOrWhiteSpace($inp)) { $def } else { $inp }
                    }
                    Set-WfDeploy $Type $key $val
                }
            }

            if ($null -ne $val -and $val -ne '') {
                # 값 치환 + 마커를 set으로 갱신
                $escVal = $val
                $line = $line -replace "(^\s*${key}:\s*`")[^`"]*(`")", "`${1}$escVal`${2}"
                $line = $line -replace "#\s*@wizard\s+(ask|auto-find|auto).*$", "# @wizard set (직접 수정 가능)"
            }
        }
        $line
    }
    $newLines | Set-Content $File -Encoding UTF8

    # 토큰 재귀 치환: 남은 __PROJECT_NAME__
    (Get-Content $File -Raw) -replace '__PROJECT_NAME__', $repo | Set-Content $File -NoNewline -Encoding UTF8

    # paths 앵커 주입 (멀티타입 모노레포)
    if ((Get-Content $File -Raw) -match '#\s*@wizard\s+paths-anchor') {
        $ppath = ''
        if ($script:ProjectPaths.Contains($Type)) { $ppath = $script:ProjectPaths[$Type] }
        if ($ppath -and $ppath -ne '.') {
            $pl = Get-Content $File
            $pl = foreach ($l in $pl) {
                if ($l -match '^(\s*)#\s*@wizard\s+paths-anchor') {
                    "$($Matches[1])paths: ['$ppath/**']"
                } else { $l }
            }
            $pl | Set-Content $File -Encoding UTF8
        }
    }

    # 잔류 토큰 경고
    $raw = Get-Content $File -Raw
    if ($raw -match '__[A-Z_]+__') {
        $left = ([regex]::Matches($raw, '__[A-Z_]+__') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ' '
        Print-Warning "  $(Split-Path -Leaf $File): 미치환 토큰 남음($left) — 직접 채워주세요"
    }
}

# ===================================================================
# 워크플로우 다운로드
# ===================================================================

# 단일 타입의 워크플로우 복사 (기존 단일 처리 로직을 함수로 추출 — 멀티 순회용)
# 카운터는 호출측이 [ref]로 넘기는 해시테이블($counters)을 공유한다 (PowerShell scope 회피)
function Copy-Workflows-ForType {
    param(
        [string]$Type,
        [string]$ProjectTypesDir,
        [hashtable]$Counters
    )

    # 2. 타입별 워크플로우 처리 (선택적 업데이트)
    $typeDir = Join-Path $ProjectTypesDir $Type
    if (Test-Path $typeDir) {
        # 먼저 이미 존재하는 파일 목록 수집
        $existingFiles = @()
        $newFiles = @()

        # PowerShell 5.1 호환성: 배열 초기화 후 추가
        $workflows = @()
        $yamlFiles = Get-ChildItem -Path $typeDir -Filter "*.yaml" -ErrorAction SilentlyContinue
        $ymlFiles = Get-ChildItem -Path $typeDir -Filter "*.yml" -ErrorAction SilentlyContinue
        if ($yamlFiles) { $workflows += $yamlFiles }
        if ($ymlFiles) { $workflows += $ymlFiles }

        foreach ($workflow in $workflows) {
            $filename = $workflow.Name
            $destPath = Join-Path $WORKFLOWS_DIR $filename

            if (Test-Path $destPath) {
                $existingFiles += $workflow
            } else {
                $newFiles += $workflow
            }
        }

        # 신규 파일은 바로 복사
        if ($newFiles.Count -gt 0) {
            Print-Info "$Type 타입의 신규 워크플로우를 내려받고 있습니다..."
            foreach ($workflow in $newFiles) {
                Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                Write-Host "  ✓ $($workflow.Name) (신규, $Type)"
                $Counters.copied++
            }
        }

        # 이미 존재하는 파일 처리
        if ($existingFiles.Count -gt 0) {
            Write-Host ""
            Print-Warning "이미 존재하는 타입별 워크플로우($Type): $($existingFiles.Count)개"
            foreach ($workflow in $existingFiles) {
                Write-Host "   • $($workflow.Name)"
            }

            # 화살표 3지선 메뉴 (다른 메뉴와 통일). FORCE는 기본 'S'(건너뛰기).
            $choice = "S"
            if (-not $Force) {
                $wfLabel = Invoke-ChooseMenu -Prompt "기존 워크플로우를 어떻게 할까요?" -Options @(
                    @{Value='T'; Label='기존 유지 + 새 버전을 참고용(.template.yaml)으로 추가'},
                    @{Value='S'; Label='건너뛰기 — 기존 파일만 유지'},
                    @{Value='O'; Label='덮어쓰기 — 기존 파일을 .bak 백업 후 교체'}
                )
                $choice = if ($wfLabel) { $wfLabel } else { "S" }
            }
            Write-Host ""

            switch ($choice.ToUpper()) {
                "T" {
                    # .template.yaml로 추가
                    Print-Info "기존 파일은 두고 새 버전을 .template.yaml로 추가합니다 (수동 반영용 참고)..."
                    foreach ($workflow in $existingFiles) {
                        $filename = $workflow.Name
                        $templateName = $filename -replace '\.yaml$', '.template.yaml'
                        $templatePath = Join-Path $WORKFLOWS_DIR $templateName
                        # 기존 .template.yaml이 있으면 삭제
                        if (Test-Path $templatePath) {
                            Remove-Item -Path $templatePath -Force
                        }
                        Copy-Item -Path $workflow.FullName -Destination $templatePath -Force
                        Write-Host "  ✓ $templateName (참고용 추가)"
                        $Counters.templateAdded++
                    }
                    Print-Info "💡 .template.yaml 파일은 GitHub Actions에서 실행되지 않습니다."
                    Print-Info "   필요한 변경사항을 참고하여 기존 파일에 수동으로 반영하세요."
                }
                "S" {
                    # 건너뛰기
                    Print-Info "기존 워크플로우를 그대로 유지합니다..."
                    foreach ($workflow in $existingFiles) {
                        Write-Host "  ⏭ $($workflow.Name) (건너뜀)"
                        $Counters.skipped++
                    }
                }
                "O" {
                    # 기존 방식 (덮어쓰기)
                    Print-Info "기존 파일을 .bak으로 백업한 뒤 새 버전으로 교체합니다..."
                    foreach ($workflow in $existingFiles) {
                        $filename = $workflow.Name
                        $destPath = Join-Path $WORKFLOWS_DIR $filename
                        $backupPath = [string]$destPath + ".bak"
                        Move-Item -Path $destPath -Destination $backupPath -Force
                        Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                        Write-Host "  ✓ $filename (백업: ${filename}.bak)"
                        $Counters.copied++
                    }
                }
                default {
                    # 기본값: 건너뛰기
                    Print-Warning "선택을 인식하지 못해 기존 파일을 유지합니다."
                    foreach ($workflow in $existingFiles) {
                        Write-Host "  ⏭ $($workflow.Name) (건너뜀)"
                        $Counters.skipped++
                    }
                }
            }
        } else {
            Print-Info "$Type 타입의 기존 워크플로우가 없습니다."
        }
    } else {
        Print-Info "$Type 타입의 전용 워크플로우가 없습니다. (공통 워크플로우만 사용)"
    }

    # 3. 타입별 Synology 하위폴더 처리 (선택적)
    $synologyDir = Join-Path $ProjectTypesDir "$Type\synology"

    if (Test-Path $synologyDir) {
        if ($script:IncludeSynology -eq $true) {
            Print-Info "$Type Synology 워크플로우 다운로드 중..."

            $synologyWorkflows = @()
            $yamlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yaml" -ErrorAction SilentlyContinue
            $ymlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yml" -ErrorAction SilentlyContinue
            if ($yamlFiles) { $synologyWorkflows += $yamlFiles }
            if ($ymlFiles) { $synologyWorkflows += $ymlFiles }

            foreach ($workflow in $synologyWorkflows) {
                $filename = $workflow.Name
                $destPath = Join-Path $WORKFLOWS_DIR $filename

                # 이미 존재하는 경우 처리
                if (Test-Path $destPath) {
                    # 기존 파일 백업 후 덮어쓰기
                    $backupPath = [string]$destPath + ".bak"
                    Move-Item -Path $destPath -Destination $backupPath -Force
                    Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                    Write-Host "  ✓ $filename (Synology $Type, 백업: ${filename}.bak)"
                } else {
                    Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                    Write-Host "  ✓ $filename (Synology $Type)"
                }
                $Counters.synologyCopied++
                $Counters.copied++
            }
        } else {
            # Synology 제외됨 - 사용자에게 알림
            $synologyFiles = @()
            $yamlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yaml" -ErrorAction SilentlyContinue
            $ymlFiles = Get-ChildItem -Path $synologyDir -Filter "*.yml" -ErrorAction SilentlyContinue
            if ($yamlFiles) { $synologyFiles += $yamlFiles }
            if ($ymlFiles) { $synologyFiles += $ymlFiles }

            if ($synologyFiles.Count -gt 0) {
                Print-Info "$Type Synology 워크플로우 $($synologyFiles.Count)개 제외됨 (-Synology 옵션으로 포함 가능)"
            }
        }
    }

    # ── 복사된 워크플로우 env 동적 설정 (토큰+@wizard 마커 치환) ──
    foreach ($srcDir in @($typeDir, $synologyDir)) {
        if (-not (Test-Path $srcDir)) { continue }
        foreach ($wf in (Get-ChildItem -Path $srcDir -Include '*.yaml','*.yml' -File -ErrorAction SilentlyContinue)) {
            $target = Join-Path $WORKFLOWS_DIR $wf.Name
            if (Test-Path $target) { Configure-WorkflowEnv -Type $Type -File $target }
        }
    }
}

# 멀티타입 안내·체크 헬퍼 — ProjectTypes 배열에 특정 타입 포함 여부
function Test-ContainsType {
    param([string]$Needle)
    $arr = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
    return ($arr -contains $Needle)
}

function Copy-Workflows {
    Print-Step "프로젝트 타입별 워크플로우 다운로드 중..."
    $typesDisplay = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes -join ',' } else { $script:ProjectType }
    Print-Info "프로젝트 타입: $typesDisplay"

    if (-not (Test-Path $WORKFLOWS_DIR)) {
        New-Item -Path $WORKFLOWS_DIR -ItemType Directory -Force | Out-Null
    }

    # 멀티타입 순회에서 Copy-Workflows-ForType이 공유하는 카운터 (해시테이블 ref)
    $counters = @{ copied = 0; skipped = 0; templateAdded = 0; synologyCopied = 0 }
    $projectTypesDir = Join-Path $TEMP_DIR "$WORKFLOWS_DIR\$PROJECT_TYPES_DIR"

    # project-types 폴더 존재 확인
    if (-not (Test-Path $projectTypesDir)) {
        Print-Error "템플릿 저장소의 폴더 구조가 올바르지 않습니다."
        Print-Error "템플릿 저장소 구조 오류 — project-types 폴더를 찾지 못했습니다."
        exit 1
    }

    # 1. Common 워크플로우 다운로드 (항상 최신으로 업데이트)
    Print-Info "모든 타입에 공통으로 들어가는 기본 워크플로우를 내려받고 있습니다..."
    $commonDir = Join-Path $projectTypesDir "common"
    if (Test-Path $commonDir) {
        # PowerShell 5.1 호환성: 배열 초기화 후 추가 (null += 방지)
        $workflows = @()
        $yamlFiles = Get-ChildItem -Path $commonDir -Filter "*.yaml" -ErrorAction SilentlyContinue
        $ymlFiles = Get-ChildItem -Path $commonDir -Filter "*.yml" -ErrorAction SilentlyContinue
        if ($yamlFiles) { $workflows += $yamlFiles }
        if ($ymlFiles) { $workflows += $ymlFiles }

        foreach ($workflow in $workflows) {
            $filename = $workflow.Name
            $destPath = Join-Path $WORKFLOWS_DIR $filename

            # COMMON은 항상 덮어쓰기 (핵심 기능)
            if (Test-Path $destPath) {
                Print-Info "$filename 업데이트"
            }

            Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
            Write-Host "  ✓ $filename"
            $counters.copied++
        }
    } else {
        Print-Warning "공통 워크플로우 폴더(common)를 찾지 못해 건너뜁니다."
    }

    # 2~3. 타입별 워크플로우 + 타입별 Synology 처리 — ProjectTypes 배열 순회
    #       타입별 파일명은 PROJECT-{TYPE}- prefix로 완전 분리되어 충돌 0.
    $typesToCopy = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
    foreach ($t in $typesToCopy) {
        Copy-Workflows-ForType -Type $t -ProjectTypesDir $projectTypesDir -Counters $counters
    }

    # 카운터를 로컬 변수로 펼침 (이후 요약 출력에서 사용)
    $copied = $counters.copied
    $skipped = $counters.skipped
    $templateAdded = $counters.templateAdded
    $synologyCopied = $counters.synologyCopied

    # 4. Common Synology 워크플로우 처리 (선택적)
    $commonSynologyDir = Join-Path $projectTypesDir "common\synology"
    if (Test-Path $commonSynologyDir) {
        if ($script:IncludeSynology -eq $true) {
            Print-Info "공통 Synology 워크플로우 다운로드 중..."

            $commonSynWorkflows = @()
            $yamlFiles = Get-ChildItem -Path $commonSynologyDir -Filter "*.yaml" -ErrorAction SilentlyContinue
            $ymlFiles = Get-ChildItem -Path $commonSynologyDir -Filter "*.yml" -ErrorAction SilentlyContinue
            if ($yamlFiles) { $commonSynWorkflows += $yamlFiles }
            if ($ymlFiles) { $commonSynWorkflows += $ymlFiles }

            foreach ($workflow in $commonSynWorkflows) {
                $filename = $workflow.Name
                $destPath = Join-Path $WORKFLOWS_DIR $filename

                # 타입별 synology에서 이미 복사된 파일이면 스킵
                if (Test-Path $destPath) {
                    Print-Warning "$($filename): 타입별 Synology에 같은 파일이 있어 타입별 버전을 유지합니다."
                    continue
                }

                Copy-Item -Path $workflow.FullName -Destination $WORKFLOWS_DIR -Force
                Write-Host "  ✓ $filename (공통 Synology)"
                $synologyCopied++
                $copied++
            }
        } else {
            $commonSynFiles = @()
            $yamlFiles = Get-ChildItem -Path $commonSynologyDir -Filter "*.yaml" -ErrorAction SilentlyContinue
            $ymlFiles = Get-ChildItem -Path $commonSynologyDir -Filter "*.yml" -ErrorAction SilentlyContinue
            if ($yamlFiles) { $commonSynFiles += $yamlFiles }
            if ($ymlFiles) { $commonSynFiles += $ymlFiles }

            if ($commonSynFiles.Count -gt 0) {
                Print-Info "공통 Synology 워크플로우 $($commonSynFiles.Count)개 제외됨 (-Synology 옵션으로 포함 가능)"
            }
        }
    }

    # 결과 요약
    Write-Host ""
    $typesSummary = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes -join ',' } else { $script:ProjectType }
    Print-Success "워크플로우 처리 완료 (타입: $typesSummary)"
    Write-Host "   📥 복사됨: $copied 개"
    if ($synologyCopied -gt 0) {
        Write-Host "   🗄️ Synology: $synologyCopied 개"
    }
    if ($templateAdded -gt 0) {
        Write-Host "   📄 참고용 추가 (.template.yaml): $templateAdded 개"
    }
    if ($skipped -gt 0) {
        Write-Host "   ⏭ 건너뜀: $skipped 개"
    }

    # 복사된 워크플로우 수를 전역 변수로 저장
    $script:WorkflowsCopied = $copied

    # 멀티타입 CI 트리거 충돌 경고 — 여러 *-CI.yaml이 같은 push에 동시 발화
    if ($script:ProjectTypes.Count -gt 1) {
        Write-Host ""
        Print-Warning "⚠️  멀티타입 주의: 여러 타입의 CI/CD 워크플로우가 같은 push에 동시 실행됩니다."
        Print-Warning "   각 워크플로우의 paths: 필터를 디렉토리별로 수동 추가해 분리하길 권장합니다."
        Print-Warning "   배포 워크플로우는 PROJECT_NAME/CONTAINER_NAME/DEPLOY_PORT를 타입별로 다르게 설정하세요."
    }

    # CI/CD 워크플로우 안내 — ProjectTypes 배열에 spring 포함 시
    if (Test-ContainsType "spring") {
        Write-Host ""
        Print-Info "🔐 Spring CI/CD 워크플로우 사용 시 GitHub Secrets 설정:"
        Write-Host "     Repository > Settings > Secrets > Actions"
        Write-Host "     필수 Secrets:"
        Write-Host "       - APPLICATION_PROD_YML (Spring 운영 설정)"
        Write-Host "       - DOCKERHUB_USERNAME, DOCKERHUB_TOKEN"
        Write-Host "       - SERVER_HOST, SERVER_USER, SERVER_PASSWORD"
        Write-Host "       - GRADLE_PROPERTIES (Nexus 사용 시)"
    }
}

# ===================================================================
# 스크립트 다운로드
# ===================================================================

function Copy-Scripts {
    Print-Step "버전 관리 스크립트 다운로드 중..."
    
    if (-not (Test-Path $SCRIPTS_DIR)) {
        New-Item -Path $SCRIPTS_DIR -ItemType Directory -Force | Out-Null
    }
    
    $scripts = @(
        "version_manager.sh",
        "changelog_manager.py"
    )
    
    $copied = 0
    foreach ($script in $scripts) {
        $src = Join-Path $TEMP_DIR "$SCRIPTS_DIR\$script"
        $dst = Join-Path $SCRIPTS_DIR $script
        
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $dst -Force
            Write-Host "  ✓ $script"
            $copied++
        }
    }
    
    Print-Success "$copied개 스크립트 다운로드 완료"
}

# ===================================================================
# .github/config 폴더 복사
# ===================================================================

function Copy-ConfigFolder {
    Print-Step ".github/config 폴더 복사 중..."

    $srcConfigDir = Join-Path $TEMP_DIR ".github\config"
    $dstConfigDir = ".github\config"

    if (-not (Test-Path $srcConfigDir)) {
        Print-Info ".github/config 폴더가 템플릿에 없어 건너뜁니다."
        return
    }

    # 기존 config 파일이 있으면 알림
    if ((Test-Path $dstConfigDir) -and (Get-ChildItem $dstConfigDir -ErrorAction SilentlyContinue)) {
        Print-Info "기존 config 파일을 최신 버전으로 덮어씁니다."
    }

    if (-not (Test-Path $dstConfigDir)) {
        New-Item -Path $dstConfigDir -ItemType Directory -Force | Out-Null
    }

    # 항상 최신으로 덮어쓰기
    Copy-Item -Path "$srcConfigDir\*" -Destination $dstConfigDir -Recurse -Force -ErrorAction SilentlyContinue

    # 복사된 파일 개수 계산
    $copied = (Get-ChildItem $dstConfigDir -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Print-Success ".github/config 폴더 복사 완료 ($copied개 파일)"
}

# ===================================================================
# 이슈 템플릿 다운로드
# ===================================================================

function Copy-IssueTemplates {
    Print-Step "이슈/PR 템플릿 다운로드 중..."
    
    $issueTemplateDir = ".github\ISSUE_TEMPLATE"
    if (-not (Test-Path $issueTemplateDir)) {
        New-Item -Path $issueTemplateDir -ItemType Directory -Force | Out-Null
    }
    
    # 기존 템플릿이 있으면 알림
    if ((Test-Path $issueTemplateDir) -and (Get-ChildItem $issueTemplateDir -ErrorAction SilentlyContinue)) {
        Print-Info "기존 이슈 템플릿을 최신 버전으로 덮어씁니다."
    }
    
    # 템플릿 다운로드
    $srcIssueDir = Join-Path $TEMP_DIR ".github\ISSUE_TEMPLATE"
    if (Test-Path $srcIssueDir) {
        Copy-Item -Path "$srcIssueDir\*" -Destination $issueTemplateDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # PR 템플릿
    $srcPrTemplate = Join-Path $TEMP_DIR ".github\PULL_REQUEST_TEMPLATE.md"
    if (Test-Path $srcPrTemplate) {
        Copy-Item -Path $srcPrTemplate -Destination ".github\" -Force
        Print-Success "이슈/PR 템플릿을 적용했습니다"
    }
}

# ===================================================================
# Discussion 템플릿 다운로드
# ===================================================================

function Copy-DiscussionTemplates {
    Print-Step "GitHub Discussions 템플릿 다운로드 중..."
    
    $srcDiscussionDir = Join-Path $TEMP_DIR ".github\DISCUSSION_TEMPLATE"
    if (-not (Test-Path $srcDiscussionDir)) {
        Print-Info "Discussions 템플릿이 템플릿에 없어 건너뜁니다."
        return
    }
    
    $discussionTemplateDir = ".github\DISCUSSION_TEMPLATE"
    if (-not (Test-Path $discussionTemplateDir)) {
        New-Item -Path $discussionTemplateDir -ItemType Directory -Force | Out-Null
    }
    
    # 기존 템플릿이 있으면 알림
    if ((Test-Path $discussionTemplateDir) -and (Get-ChildItem $discussionTemplateDir -ErrorAction SilentlyContinue)) {
        Print-Info "기존 Discussion 템플릿을 최신 버전으로 덮어씁니다."
    }
    
    # 템플릿 다운로드
    Copy-Item -Path "$srcDiscussionDir\*" -Destination $discussionTemplateDir -Recurse -Force -ErrorAction SilentlyContinue
    Print-Success "GitHub Discussions 템플릿을 적용했습니다"
}

# ===================================================================
# .coderabbit.yaml 다운로드
# ===================================================================

function Show-CodeRabbitIntro {
    # CodeRabbit이 무엇이고, 이 파일이 어떤 설정으로 동작하는지 안내한다.
    # (설정을 안 하고 "왜 리뷰가 안 달리지?" 하는 사용자가 많아 명시적으로 설명한다.)
    Write-Host ""
    Write-Host "  🐰 CodeRabbit이란?"
    Write-Host "     PR을 올리면 AI가 코드 변경을 자동으로 읽고 리뷰 코멘트를 달아주는 서비스입니다."
    Write-Host "     (버그·보안·개선점 지적, 변경 요약, PR 내 채팅 질문 응답)"
    Write-Host ""
    Write-Host "  📋 이 .coderabbit.yaml에 들어가는 설정:"
    Write-Host "     • 리뷰 언어        : 한국어(ko-KR)"
    Write-Host "     • 자동 리뷰        : 켜짐 — main 대상 PR에 자동 리뷰 (draft PR 제외)"
    Write-Host "     • 리뷰 성향        : chill (과하지 않게), 변경요약 표시, 변경요청 강제 안 함"
    Write-Host "     • PR 채팅 자동응답  : 켜짐"
    Write-Host ""
    Write-Host "  ⚠️  파일만으로는 끝이 아닙니다 — 한 번만 활성화하면 됩니다:"
    Write-Host "     1) https://coderabbit.ai 접속 → GitHub으로 로그인"
    Write-Host "     2) 이 저장소를 CodeRabbit에 연결(Authorize/Enable)"
    Write-Host "     이 단계를 안 하면 .coderabbit.yaml이 있어도 리뷰가 달리지 않습니다."
    Write-Host ""
}

function Copy-CodeRabbitConfig {
    Print-Step "CodeRabbit AI 리뷰 설정을 확인하고 있습니다..."

    $srcCodeRabbit = Join-Path $TEMP_DIR ".coderabbit.yaml"
    if (-not (Test-Path $srcCodeRabbit)) {
        Print-Info ".coderabbit.yaml이 템플릿에 없어 건너뜁니다."
        return
    }

    # CodeRabbit 소개 + 설정 안내 (덮어쓰기/신규 적용 공통으로 먼저 보여준다)
    Show-CodeRabbitIntro

    # 기존 파일이 있으면 사용자 확인
    if (Test-Path ".coderabbit.yaml") {
        Print-Warning ".coderabbit.yaml이 이미 있습니다 — 덮어쓸지 확인합니다"
        
        if (-not $Force) {
            Print-SeparatorLine
            Write-Host ""

            # 워크플로우 충돌 메뉴와 동일하게 '덮어쓰기 / 건너뛰기' 선택지를 명시한다.
            # (단순 예/아니오는 "건너뛰기"가 직관적이지 않아 사용자가 헷갈린다.)
            $crChoice = Invoke-ChooseMenu -Prompt "기존 .coderabbit.yaml을 어떻게 할까요?" -Options @(
                @{Value='O'; Label='덮어쓰기 — 기존 파일을 .bak 백업 후 교체 (권장)'},
                @{Value='S'; Label='건너뛰기 — 기존 파일만 유지'}
            )
            # ESC($null) 또는 건너뛰기 → 기존 유지
            if ((-not $crChoice) -or ($crChoice -eq 'S')) {
                Print-Info ".coderabbit.yaml 업데이트를 건너뜁니다 — 기존 설정을 유지합니다"
                return
            }

            # PowerShell 5.1 호환성: 백업 경로를 변수로 분리
            $backupPath = ".coderabbit.yaml.bak"
            Copy-Item -Path ".coderabbit.yaml" -Destination $backupPath -Force
            Print-Info "기존 파일을 .coderabbit.yaml.bak으로 백업했습니다"
        } elseif ($Force) {
            # Force 모드에서는 백업하고 덮어쓰기
            # PowerShell 5.1 호환성: 백업 경로를 변수로 분리
            $backupPath = ".coderabbit.yaml.bak"
            Copy-Item -Path ".coderabbit.yaml" -Destination $backupPath -Force -ErrorAction SilentlyContinue
            Print-Info "강제 모드 — 기존 파일을 새 버전으로 교체합니다"
        }
    }
    
    # 다운로드 실행
    Copy-Item -Path $srcCodeRabbit -Destination ".coderabbit.yaml" -Force
    Print-Success ".coderabbit.yaml 설정을 적용했습니다 (CodeRabbit AI 리뷰 활성화)"
    Print-Info "💡 CodeRabbit AI 리뷰가 활성화됩니다 (language: ko-KR)"
}

# ===================================================================
# .gitignore 생성 또는 업데이트
# ===================================================================

# gitignore 항목 정규화 함수 (중복 체크용)
# 예: "/.idea" -> ".idea", ".idea" -> ".idea", "./idea" -> ".idea"
# 예: "/.claude/settings.local.json" -> ".claude/settings.local.json"
function Normalize-GitIgnoreEntry {
    param(
        [string]$Entry
    )
    
    # 주석 제거
    $normalized = $Entry -replace '#.*$', ''
    # 앞뒤 공백 제거
    $normalized = $normalized.Trim()
    # 앞의 슬래시 제거 (루트 경로 표시 제거)
    $normalized = $normalized -replace '^/+', ''
    # "./" 제거 (현재 디렉토리 표시 제거, 하지만 ".idea" 같은 숨김 폴더는 보존)
    $normalized = $normalized -replace '^\./', ''
    # 뒤의 슬래시 제거 (디렉토리 표시 제거)
    $normalized = $normalized -replace '/+$', ''
    
    # 빈 문자열이면 원본 반환
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $Entry
    }
    
    return $normalized
}

# gitignore 파일에서 항목 존재 여부 확인 (정규화된 비교)
function Test-GitIgnoreEntryExists {
    param(
        [string]$TargetEntry,
        [string]$GitIgnoreFile
    )
    
    # 정규화된 타겟 항목
    $normalizedTarget = Normalize-GitIgnoreEntry -Entry $TargetEntry
    
    # gitignore 파일의 각 라인 확인
    $lines = Get-Content -Path $GitIgnoreFile -ErrorAction SilentlyContinue
    if ($null -eq $lines) {
        return $false
    }
    
    foreach ($line in $lines) {
        # 주석 라인 건너뛰기
        if ($line -match '^\s*#') {
            continue
        }
        
        # 빈 라인 건너뛰기
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        
        # 정규화된 라인과 비교
        $normalizedLine = Normalize-GitIgnoreEntry -Entry $line
        
        if ($normalizedLine -eq $normalizedTarget) {
            return $true  # 존재함
        }
    }
    
    return $false  # 존재하지 않음
}

function Ensure-GitIgnore {
    Print-Step ".gitignore 파일 확인 및 업데이트 중..."
    
    $requiredEntries = @(
        "/.idea",
        "/.claude/settings.local.json"
    )
    
    # .gitignore가 없으면 생성
    if (-not (Test-Path ".gitignore")) {
        Print-Info ".gitignore가 없어 필수 항목과 함께 새로 만듭니다."
        
        $gitignoreContent = @"
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json
"@
        
        Set-Content -Path ".gitignore" -Value $gitignoreContent -Encoding UTF8
        
        Print-Success ".gitignore를 새로 만들었습니다"
        return
    }
    
    # 기존 파일이 있으면 누락된 항목만 추가
    Print-Info "기존 .gitignore를 발견했습니다 — 필수 항목이 있는지 확인합니다..."
    
    $added = 0
    $entriesToAdd = @()
    
    foreach ($entry in $requiredEntries) {
        # 정규화된 비교로 중복 체크
        if (-not (Test-GitIgnoreEntryExists -TargetEntry $entry -GitIgnoreFile ".gitignore")) {
            $entriesToAdd += $entry
            $added++
        }
    }
    
    if ($added -eq 0) {
        Print-Info "필수 항목이 이미 모두 있어 업데이트를 건너뜁니다."
        return
    }
    
    # 항목 추가
    Print-Info "$added개 항목 추가 중..."
    
    $appendContent = @"

# ====================================================================
# SUH-DEVOPS-TEMPLATE: Auto-added entries
# ====================================================================
"@
    
    foreach ($entry in $entriesToAdd) {
        $appendContent += "`n$entry"
        Print-Info "  ✓ $entry"
    }
    
    Add-Content -Path ".gitignore" -Value $appendContent -Encoding UTF8

    Print-Success ".gitignore 업데이트 완료 ($added개 항목 추가)"
}

# ===================================================================
# SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 다운로드
# ===================================================================

function Copy-SetupGuide {
    Print-Step "템플릿 설정 가이드 다운로드 중..."
    
    $srcGuide = Join-Path $TEMP_DIR "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    if (-not (Test-Path $srcGuide)) {
        Print-Info "설정 가이드(SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md)가 템플릿에 없어 건너뜁니다."
        return
    }
    
    # 항상 최신 버전으로 다운로드
    Copy-Item -Path $srcGuide -Destination "." -Force
    Print-Success "템플릿 설정 가이드를 적용했습니다 (최신 버전)"
    Print-Info "📖 템플릿 사용법을 SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md에서 확인하세요"
}

# ===================================================================
# 프로젝트 타입별 유틸리티 모듈 다운로드
# ===================================================================
# 프로젝트 타입에 따라 추가 유틸리티 모듈(마법사 등)을 다운로드합니다.
# 현재 지원: flutter (ios-testflight-setup-wizard, android-playstore-setup-wizard)
# 확장 가능: 다른 프로젝트 타입에도 util 모듈 추가 시 자동 지원
# ===================================================================

function Show-UtilModuleDescription {
    param([string]$ProjectType)

    switch ($ProjectType) {
        "flutter" {
            Print-SeparatorLine
            Write-Host ""
            Write-Host "📦 Flutter 추가 유틸리티 모듈:"
            Write-Host ""
            Write-Host "  🧙 ios-testflight-setup-wizard"
            Write-Host "     iOS TestFlight 배포에 필요한 설정 파일들을"
            Write-Host "     웹 브라우저에서 쉽게 생성할 수 있는 마법사입니다."
            Write-Host "     → ExportOptions.plist, Fastfile 등 자동 생성"
            Write-Host ""
            Write-Host "  🧙 android-playstore-setup-wizard"
            Write-Host "     Android Play Store 배포에 필요한 설정 파일들을"
            Write-Host "     웹 브라우저에서 쉽게 생성할 수 있는 마법사입니다."
            Write-Host "     → Fastfile, build.gradle 서명 설정 등 자동 생성"
            Write-Host ""
        }
        # 다른 프로젝트 타입 추가 시 여기에 case 추가
        default {
            # 알 수 없는 타입은 일반 메시지
            Print-SeparatorLine
            Write-Host ""
            Write-Host "📦 $ProjectType 추가 유틸리티 모듈이 있습니다."
            Write-Host ""
        }
    }
}

function Show-UtilUsageGuide {
    param([string]$ProjectType)

    switch ($ProjectType) {
        "flutter" {
            Write-Host ""
            Print-Info "📖 Flutter 마법사 사용법:"
            Write-Host "   iOS TestFlight:"
            Write-Host "     1. 브라우저에서 열기:"
            Write-Host "        .github\util\flutter\ios-testflight-setup-wizard\index.html"
            Write-Host "     2. 필요한 정보 입력 후 파일 생성"
            Write-Host "     3. 생성된 파일을 ios\ 폴더에 복사"
            Write-Host ""
            Write-Host "   Android Play Store:"
            Write-Host "     1. 브라우저에서 열기:"
            Write-Host "        .github\util\flutter\android-playstore-setup-wizard\index.html"
            Write-Host "     2. 필요한 정보 입력 후 파일 생성"
            Write-Host "     3. 생성된 파일을 android\ 폴더에 복사"
            Write-Host ""
        }
        default {
            Write-Host ""
            Print-Info "📖 util 모듈 사용법:"
            Write-Host "   .github\util\$ProjectType\ 폴더 내 README.md를 참고하세요."
            Write-Host ""
        }
    }
}

function Copy-UtilModules {
    param([string]$ProjectType)

    $utilSrc = Join-Path $TEMP_DIR ".github\util\$ProjectType"
    $utilDst = ".github\util\$ProjectType"

    # util 모듈 존재 확인
    if (-not (Test-Path $utilSrc)) {
        # util 모듈이 없으면 조용히 건너뜀 (모든 타입에 모듈이 있는 건 아님)
        return
    }

    Print-Step "$ProjectType 추가 유틸리티 모듈 확인 중..."

    # 모듈 설명 표시
    Show-UtilModuleDescription $ProjectType

    # 사용자 확인 (force 모드가 아닐 때만)
    if (-not $Force) {
        # 선택지(예/아니오)는 아래 Ask-YesNo가 화살표 메뉴로 직접 보여주므로 여기서 중복 안내하지 않는다.
        if (-not (Ask-YesNo "이 유틸리티 모듈을 다운로드할까요?" "Y")) {
            Print-Info "유틸리티 모듈 다운로드를 건너뜁니다"
            return
        }
    } else {
        # Force 모드에서는 자동으로 다운로드
        Print-Info "강제 모드 — 유틸리티 모듈을 자동으로 내려받습니다"
    }

    # 다운로드 실행
    if (-not (Test-Path $utilDst)) {
        New-Item -Path $utilDst -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path "$utilSrc\*" -Destination $utilDst -Recurse -Force -ErrorAction SilentlyContinue

    # 복사된 모듈 개수 계산
    $moduleCount = 0
    $moduleDirs = Get-ChildItem -Path $utilDst -Directory -ErrorAction SilentlyContinue
    if ($moduleDirs) {
        $moduleCount = $moduleDirs.Count
    }

    Print-Success "유틸리티 모듈을 적용했습니다 ($moduleCount개 모듈)"

    # 복사된 모듈 목록 표시
    foreach ($dir in $moduleDirs) {
        Write-Host "  ✓ $($dir.Name)"
    }

    # 사용 가이드 표시
    Show-UtilUsageGuide $ProjectType

    # 복사된 모듈 수를 전역 변수로 저장 (최종 요약에서 사용)
    $script:UtilModulesCopied = $moduleCount
}

# ===================================================================
# 대화형 모드
# ===================================================================

function Start-InteractiveMode {
    # Interactive 모드 플래그 설정
    $script:IsInteractiveMode = $true
    
    # 템플릿 버전 가져오기
    $templateVersion = $DEFAULT_VERSION
    try {
        $versionUrl = "$TEMPLATE_RAW_URL/$VERSION_FILE"
        $versionContent = (Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -TimeoutSec 3).Content
        if ($versionContent -match 'version:\s*[''"]?([^''"]+)') {
            $templateVersion = $matches[1]
        }
    } catch {
        # 버전 가져오기 실패 시 기본값 사용
    }
    
    Print-Banner $templateVersion "Interactive (대화형 모드)"
    
    # ── 1) 모드 선택 먼저 (사용자 의도부터 파악) ── (sh와 동일 구조)
    # 사용자가 무엇을 하려는지 먼저 묻고, 모드에 따라 필요한 정보만 수집한다.
    # (예: skills/issues 모드는 프로젝트 타입·버전·Synology·경로가 전혀 필요 없음)
    Print-QuestionHeader "🚀" "어떤 기능을 통합하시겠습니까?"

    # 라벨은 sh와 동일한 한국어 설명. ps1은 Value/Label 분리라 화면엔 Label만 표시됨(영어 키 비노출).
    $_modeSelected = Invoke-ChooseMenu -Prompt "무엇을 설치할까요?" -Options @(
        @{Value='full';      Label='전체 설치 — 버전관리 + 자동화 워크플로우 + 이슈·PR 템플릿 (처음이라면 추천)'},
        @{Value='version';   Label='버전 관리만 — 버전 자동 증가·동기화 시스템만 설치'},
        @{Value='workflows'; Label='워크플로우만 — 빌드·배포 GitHub Actions만 설치'},
        @{Value='issues';    Label='이슈·PR 템플릿만 — GitHub 이슈/PR 양식만 설치'},
        @{Value='skills';    Label='AI 스킬만 — Claude·Cursor·Gemini·Codex·PI용 스킬만 설치'},
        @{Value='cancel';    Label='취소'}
    )

    if (-not $_modeSelected -or $_modeSelected -eq 'cancel') {
        Print-Info "설치를 취소했습니다. 스크립트를 종료합니다."
        exit 0
    }

    $script:Mode = $_modeSelected

    # 템플릿 다운로드 (모드별 수집·복사에서 사용)
    Download-Template

    # ── 2) 모드별 필요 정보만 수집 ──
    # 수집 매트릭스: full=타입/버전/Synology/경로, version=타입/버전/경로,
    #               workflows=타입/Synology, issues=없음, skills=없음
    switch ($script:Mode) {
        { $_ -in @('skills', 'issues') } {
            # 프로젝트 정보 불필요 → 수집·확인 전부 건너뜀. 바로 실행 단계로.
        }
        default {
            # full/version/workflows → 타입·버전·브랜치 감지 → Synology·경로 수집 → 최종 확인
            # 순서가 핵심: Synology·경로를 확인 화면 '전에' 모아야 확인 화면에 함께 표시된다. (sh와 동일)

            # 1) 타입/버전/브랜치 먼저 감지 (확인은 아직 안 함)
            if ($script:ProjectTypes.Count -eq 0) {
                $detectedCsv = Detect-ProjectTypes
                $script:ProjectTypes = @($detectedCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                $script:ProjectType = $script:ProjectTypes[0]
            }
            if ([string]::IsNullOrWhiteSpace($script:ProjectVersion)) { $script:ProjectVersion = Detect-Version }
            if ([string]::IsNullOrWhiteSpace($script:DetectedBranch)) { $script:DetectedBranch = Detect-DefaultBranch }

            # 2) Synology: 워크플로우 포함 모드(full/workflows)에서만
            if ($script:Mode -eq "full" -or $script:Mode -eq "workflows") {
                $synTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
                $typeDirs = @($synTypes | ForEach-Object { Join-Path $TEMP_DIR "$WORKFLOWS_DIR\$PROJECT_TYPES_DIR\$_" })
                Ask-SynologyOption $typeDirs
            }

            # 3) 경로: full/version 모드에서만 필요
            #    이미 init된 프로젝트(version.yml에 project_paths 있음)는 저장값을 '로드만' 해
            #    확인 화면에 보여주고 질문은 생략한다. 저장값이 없거나 일부만 있으면(신규 init)
            #    확인 화면을 거친 뒤(아래 4번) 비어있는 타입만 Resolve-ProjectPaths로 묻는다.
            if ($script:Mode -eq "full" -or $script:Mode -eq "version") {
                Load-SavedProjectPaths | Out-Null
            }

            # 4) 모든 수집 결과를 확인 화면에 모아 최종 확인
            Detect-AndConfirmProject

            # 5) 확인 후에도 경로가 비어있는 대상 타입이 있으면(신규 init) 그때 질문한다.
            #    (사용자가 '수정 → 타입 변경'을 했다면 그 안에서 이미 경로를 다시 물었으므로 보통 채워져 있다.)
            if ($script:Mode -eq "full" -or $script:Mode -eq "version") {
                $_needPaths = $false
                $_allTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
                $_pathTargets = @($_allTypes | Where-Object { $_ -ne "basic" })
                foreach ($_pt in $_pathTargets) {
                    if (-not $script:ProjectPaths.Contains($_pt)) { $_needPaths = $true; break }
                }
                if ($_needPaths) { Resolve-ProjectPaths }
            }
        }
    }
}

# ===================================================================
# 통합 실행
# ===================================================================

function Start-Integration {
    # Breaking Changes 확인 (업데이트 시)
    $currentTemplateVersion = Get-CurrentTemplateVersion
    if ($currentTemplateVersion -ne "unknown") {
        Test-BreakingChanges -CurrentVersion $currentTemplateVersion -NewVersion $script:DefaultVersion | Out-Null
    }

    # CLI 모드에서만 자동 감지 및 확인 (skills 모드는 프로젝트 정보 불필요)
    if (-not $script:IsInteractiveMode -and $Mode -ne "skills") {
        # -Type으로 ProjectTypes가 안 채워졌으면 멀티 자동 감지
        if ($script:ProjectTypes.Count -eq 0) {
            $detectedCsv = Detect-ProjectTypes
            $script:ProjectTypes = @($detectedCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $script:ProjectType = $script:ProjectTypes[0]
        }

        if ([string]::IsNullOrWhiteSpace($script:ProjectVersion)) {
            $script:ProjectVersion = Detect-Version
        }

        if ([string]::IsNullOrWhiteSpace($script:DetectedBranch)) {
            $script:DetectedBranch = Detect-DefaultBranch
        }

        # CLI 모드에서만 통합 정보 표시 — 멀티면 csv로
        Print-QuestionHeader "🪐" "통합 설정 확인"

        if ($script:ProjectTypes.Count -gt 1) {
            Write-Host "🔭 프로젝트 타입  : $($script:ProjectTypes -join ',') (멀티)"
        } else {
            Write-Host "🔭 프로젝트 타입  : $($script:ProjectType)"
        }
        Write-Host "🌙 초기 버전     : v$($script:ProjectVersion)"
        Write-Host "🌿 Default 브랜치 : $($script:DetectedBranch)"
        Write-Host "💫 통합 모드     : $Mode"
        Print-SeparatorLine
        Write-Host ""

        # CLI 모드에서만 확인 질문 (force 모드가 아닐 때만)
        # ps1은 키 입력 방식이라 입력 안내(Y/N)를 유지한다(sh는 화살표라 제거).
        if (-not $Force) {
            if (-not (Ask-YesNo "이 설정으로 통합을 진행할까요?" "Y")) {
                Print-Info "통합을 취소했습니다. (설정을 다시 검토한 뒤 재실행하세요)"
                exit 0
            }
        }
    }
    
    Write-Host ""

    # 1. 템플릿 다운로드 (CLI 모드에서만, interactive 모드는 이미 다운로드됨)
    if (-not $script:IsInteractiveMode) {
        Download-Template

        # CLI 모드에서도 Synology 질문 (워크플로우 모드에서만)
        # 멀티타입이면 모든 타입의 synology 폴더를 합쳐 한 번만 질문
        if ($Mode -eq "full" -or $Mode -eq "workflows") {
            $synTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
            $typeDirs = @($synTypes | ForEach-Object { Join-Path $TEMP_DIR "$WORKFLOWS_DIR\$PROJECT_TYPES_DIR\$_" })
            Ask-SynologyOption $typeDirs
        }
    }

    # 타입별 경로 확정 — version.yml에 project_paths 기록 (full/version 모드만)
    # interactive 모드는 확인 화면 전에 이미 수집했으므로 중복 호출 방지. (sh와 동일)
    if (($Mode -eq "full" -or $Mode -eq "version") -and -not $script:IsInteractiveMode) {
        Resolve-ProjectPaths
    }

    # 2. 모드별 통합
    switch ($Mode) {
        "full" {
            Create-VersionYml $script:ProjectVersion $script:ProjectType $script:DetectedBranch
            Add-VersionSectionToReadme $script:ProjectVersion
            Copy-Workflows
            Update-VersionYmlDeploy   # 워크플로우 env 설정값을 version.yml deploy 블록에 기록
            Copy-Scripts
            Copy-ConfigFolder
            Copy-IssueTemplates
            Copy-DiscussionTemplates
            Copy-CodeRabbitConfig
            Ensure-GitIgnore
            Copy-SetupGuide
            # util 모듈 — ProjectTypes 배열 순회
            $utilTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
            foreach ($ut in $utilTypes) { Copy-UtilModules $ut }
        }
        "version" {
            Create-VersionYml $script:ProjectVersion $script:ProjectType $script:DetectedBranch
            Add-VersionSectionToReadme $script:ProjectVersion
            Copy-Scripts
            Copy-ConfigFolder
            Ensure-GitIgnore
            Copy-SetupGuide
        }
        "workflows" {
            Copy-Workflows
            Update-VersionYmlDeploy   # 워크플로우 env 설정값을 version.yml deploy 블록에 기록
            Copy-Scripts
            Copy-ConfigFolder
            Copy-SetupGuide
            # util 모듈 — ProjectTypes 배열 순회
            $utilTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
            foreach ($ut in $utilTypes) { Copy-UtilModules $ut }
        }
        "issues" {
            Copy-IssueTemplates
            Copy-DiscussionTemplates
        }
        "skills" {
            # skills 모드: 템플릿 통합 없이 IDE 도구 설치만 진행
            Offer-IdeToolsInstall

            # 임시 파일 정리 후 간결한 완료 메시지 출력하고 종료
            if (Test-Path $TEMP_DIR) {
                Remove-Item -Path $TEMP_DIR -Recurse -Force
            }
            Show-Summary
            return
        }
    }

    # 2.1 템플릿 옵션 저장 (Synology 설정 등)
    if ($Mode -eq "full" -or $Mode -eq "workflows") {
        # IncludeSynology가 설정되지 않은 경우 기본값 false 사용
        # (basic 타입 등 Synology 폴더가 없는 경우를 위한 처리)
        if ($null -eq $script:IncludeSynology) {
            $script:IncludeSynology = $false
        }
        # 다운로드한 템플릿의 실제 버전 전달 (TemplateVersion 사용)
        Save-TemplateOptions $script:TemplateVersion
    }

    # 3. IDE 도구(Skills) 설치 제안
    Offer-IdeToolsInstall

    # 4. 임시 파일 정리
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }

    # 완료 메시지
    Show-Summary
}

# ===================================================================
# IDE 도구(Skills) 설치 제안
# Claude Code: 플러그인 마켓플레이스 자동 설치
# Cursor: skills/ → .cursor/skills/ 복사
# Gemini CLI: extension install/update
# Codex CLI: plugin marketplace registration, fallback to ~/.agents/skills native discovery junction
# ===================================================================

function Offer-IdeToolsInstall {
    $claudeAvailable = $null -ne (Get-Command "claude" -ErrorAction SilentlyContinue)

    # ─── 현재 설치 상태 수집 ───
    $installedScope   = ""
    $installedVersion = ""
    if ($claudeAvailable) {
        try {
            $pluginListRaw = & claude plugin list --json 2>$null
            if ($pluginListRaw) {
                $pluginList  = $pluginListRaw | Out-String | ConvertFrom-Json
                $pluginArray = @($pluginList)
                foreach ($entry in $pluginArray) {
                    if ($entry.id -like "cassiiopeia@*") {
                        $installedScope   = $entry.scope
                        $installedVersion = $entry.version
                        break
                    }
                }
            }
        } catch { }
    }

    # Cursor는 global(user) 한 곳만 관리
    $cursorUserMeta = Join-Path $env:USERPROFILE ".cursor\skills\cursor-skills-meta.json"
    $cursorUserVer  = ""
    if (Test-Path $cursorUserMeta) {
        try { $cursorUserVer = (Get-Content $cursorUserMeta -Raw | ConvertFrom-Json).version } catch { }
    }

    # ─── 통합 상태 표시 ───
    Write-Host ""
    Print-SeparatorLine
    Print-Step "IDE Skills 현재 상태"
    Write-Host ""

    # 상태 표기 통일: scope(user/project) 구분 없이 "skill 설치됨/미설치"로만 안내. (sh와 동일)
    # Claude Code
    if ($claudeAvailable) {
        if ($installedScope) {
            $cvTag = ""
            if ($script:templateVersion -and $installedVersion -eq $script:templateVersion) { $cvTag = " ✓ 최신" }
            elseif ($script:templateVersion) { $cvTag = " -> 업데이트 가능: v$($script:templateVersion)" }
            Print-Info "Claude Code : skill 설치됨 (v${installedVersion})${cvTag}"
        } else {
            Print-Info "Claude Code : skill 미설치"
        }
    } else {
        Print-Info "Claude Code : skill 미설치 (CLI 없음)"
    }

    # Cursor — global(user) 한 곳만 확인
    if (-not $cursorUserVer) {
        Print-Info "Cursor      : skill 미설치"
    } else {
        $utag = ""
        if ($script:templateVersion -and $cursorUserVer -eq $script:templateVersion) { $utag = " ✓ 최신" }
        elseif ($script:templateVersion) { $utag = " -> 업데이트 가능: v$($script:templateVersion)" }
        Print-Info "Cursor      : skill 설치됨 (v${cursorUserVer})${utag}"
    }

    # Gemini
    if (Get-Command "gemini" -ErrorAction SilentlyContinue) {
        Print-Info "Gemini CLI  : 설치 가능 (CLI 감지됨)"
    } else {
        Print-Info "Gemini CLI  : skill 미설치 (CLI 없음)"
    }

    # Codex
    $codexTarget = Join-Path $env:USERPROFILE ".agents\skills\cassiiopeia"
    if (Test-Path $codexTarget) {
        Print-Info "Codex CLI   : skill 설치됨"
    } elseif (Get-Command "codex" -ErrorAction SilentlyContinue) {
        Print-Info "Codex CLI   : 설치 가능 (CLI 감지됨)"
    } else {
        Print-Info "Codex CLI   : skill 미설치 (CLI 없음)"
    }

    # PI — git package. 'pi list'에 우리 패키지가 잡히면 설치됨으로 본다.
    if (Test-PiCli) {
        if (Test-PiInstalled) {
            Print-Info "PI          : skill 설치됨"
        } else {
            Print-Info "PI          : 설치 가능 (CLI 감지됨)"
        }
        # Persona Harness 상태 — skill과 독립
        if (Test-PiHarnessEnabled) {
            Print-Info "PI Harness   : 활성화됨 (Persona/Workflow 주입)"
        } else {
            Print-Info "PI Harness   : 비활성화"
        }
    } else {
        Print-Info "PI          : skill 미설치 (CLI 없음)"
    }
    Write-Host ""

    # ── 2단계 통합 라우터 (sh offer_ide_tools_install과 동일 구조) ──
    # 1단계: 현재 상태(위에서 출력) + 동작 선택(설치·업데이트/제거/그대로)
    # 2단계: 그 동작을 적용할 IDE 멀티셀렉트 → 선택된 IDE만 섹션 함수 호출
    # ps1은 숫자 입력 방식이라 화살표 대신 숫자/토글로 동작하지만 흐름·문구·선택지는 sh와 동일.
    if (-not $Force) {
        # IDE 후보 (감지 여부 표시) — Value는 매핑 키, Label은 표시명
        $ideOpts = @(
            @{Value='Claude Code'; Label='Claude Code'},
            @{Value='Cursor';      Label='Cursor'}
        )
        if (Get-Command "gemini" -ErrorAction SilentlyContinue) { $ideOpts += @{Value='Gemini CLI'; Label='Gemini CLI'} }
        else { $ideOpts += @{Value='Gemini CLI'; Label='Gemini CLI (미감지)'} }
        if ((Get-Command "codex" -ErrorAction SilentlyContinue) -or (Test-Path $codexTarget)) { $ideOpts += @{Value='Codex CLI'; Label='Codex CLI'} }
        else { $ideOpts += @{Value='Codex CLI'; Label='Codex CLI (미감지)'} }
        if (Test-PiCli) { $ideOpts += @{Value='PI'; Label='PI'} }
        else { $ideOpts += @{Value='PI'; Label='PI (미감지)'} }
        # PI Persona Harness — skill과 독립. skill은 두고 harness만 켜고/끌 수 있는 별도 항목.
        # PI 패키지가 설치돼 harness loader가 있을 때만 후보로 노출.
        if ((Test-PiCli) -and (Test-Path (Get-PiHarnessLoaderPath))) { $ideOpts += @{Value='PI Persona Harness'; Label='PI Persona Harness'} }

        $action = Invoke-ChooseMenu -CancelLabel "건너뛰기" -Prompt "AI 스킬을 어떻게 할까요?" -Options @(
            @{Value='apply';  Label='설치 / 업데이트 — 최신 상태로 맞추기'},
            @{Value='remove'; Label='제거 — 설치된 스킬 삭제하기'},
            @{Value='skip';   Label='그대로 두기'}
        )

        if ($action -eq 'apply') {
            # 감지된 IDE 전체 기본 체크 (미감지 항목은 preselect에서 제외)
            $preParts = @('Claude Code', 'Cursor')
            if (Get-Command "gemini" -ErrorAction SilentlyContinue) { $preParts += 'Gemini CLI' }
            if ((Get-Command "codex" -ErrorAction SilentlyContinue) -or (Test-Path $codexTarget)) { $preParts += 'Codex CLI' }
            if (Test-PiCli) { $preParts += 'PI' }
            $targets = Invoke-ChooseMenu -CancelLabel "뒤로" -Prompt "설치 / 업데이트할 IDE를 고르세요" -Options $ideOpts -Multi -Preselect ($preParts -join ',')
            if (-not $targets) { Print-Info "선택한 IDE가 없어 설치/업데이트를 건너뜁니다 (원할 때 다시 실행하세요)."; return }
            $tcsv = ",$($targets -join ','),"
            if ($tcsv -like '*,Claude Code,*') { Invoke-ClaudeSection $claudeAvailable $installedScope $installedVersion }
            if ($tcsv -like '*,Cursor,*')      { Invoke-CursorSection }
            if ($tcsv -like '*,Gemini CLI,*')  { Invoke-GeminiExtensionManage }
            if ($tcsv -like '*,Codex CLI,*')   { Invoke-CodexSkillsManage }
            if ($tcsv -like '*,PI,*')          { Invoke-PiSection }
            if ($tcsv -like '*,PI Persona Harness,*') { Invoke-PiHarnessToggle }
        } elseif ($action -eq 'remove') {
            $targets = Invoke-ChooseMenu -CancelLabel "뒤로" -Prompt "제거할 IDE를 고르세요" -Options $ideOpts -Multi
            if (-not $targets) { Print-Info "선택한 IDE가 없어 설치/업데이트를 건너뜁니다 (원할 때 다시 실행하세요)."; return }
            $tcsv = ",$($targets -join ','),"
            if ($tcsv -like '*,Claude Code,*') { Remove-ClaudeSection $claudeAvailable $installedScope }
            if ($tcsv -like '*,Cursor,*')      { Remove-CursorSection }
            if ($tcsv -like '*,Gemini CLI,*')  { Remove-GeminiSection }
            if ($tcsv -like '*,Codex CLI,*')   { Remove-CodexSection }
            if ($tcsv -like '*,PI,*')          { Remove-PiSection }
            # PI skill은 두고 harness만 해제 (PI 항목과 별개로 단독 선택 가능)
            if ($tcsv -like '*,PI Persona Harness,*') { Remove-PiHarnessOnly }
        } else {
            Print-Info "IDE Skills는 변경하지 않고 넘어갑니다 — 통합은 계속됩니다."
        }
        return
    }

    # ── FORCE — 기존 순차 흐름 유지 (자동 설치/업데이트) ──
    Invoke-ClaudeSection $claudeAvailable $installedScope $installedVersion
    Invoke-CursorSection
    Invoke-GeminiExtensionManage
    Invoke-CodexSkillsManage
    Invoke-PiSection
}

# ── Claude Code 플러그인 관리 (기존 섹션 로직 보존) ──
function Invoke-ClaudeSection {
    param([bool]$claudeAvailable, [string]$installedScope, [string]$installedVersion)

    Print-Step "[ Claude Code 플러그인 관리 ]"
    Write-Host ""

    if ($claudeAvailable) {

        if ($installedScope) {
            # 최신버전 여부 비교
            $versionTag = ""
            if ($script:templateVersion -and $installedVersion -eq $script:templateVersion) {
                $versionTag = " ✓ 최신버전"
            } elseif ($script:templateVersion) {
                $versionTag = " -> 업데이트 가능: v$($script:templateVersion)"
            }

            # 이미 설치된 경우 → 현재 상태 표시 후 선택 메뉴
            Print-Info "현재 설치 상태: cassiiopeia v${installedVersion} (scope: ${installedScope})${versionTag}"
            Write-Host ""

            if (-not $Force) {
                # 라우터에서 이미 '설치/업데이트' 선택됨 → 추가 메뉴 없이 바로 업데이트.
                Print-Step "플러그인 업데이트 중..."
                $null = & claude plugin update "cassiiopeia@cassiiopeia-marketplace" --scope $installedScope 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Print-Success "업데이트 완료 (scope: ${installedScope})"
                    Invoke-ConfigMigration
                } else {
                    Print-Warning "업데이트 실패. 수동 실행: claude plugin update cassiiopeia@cassiiopeia-marketplace --scope ${installedScope}"
                }
            } else {
                Print-Step "플러그인 업데이트 중 (FORCE)..."
                $null = & claude plugin update "cassiiopeia@cassiiopeia-marketplace" --scope $installedScope 2>&1
                Print-Success "업데이트 완료 (scope: ${installedScope})"
                Invoke-ConfigMigration
            }
        } else {
            # 미설치 → 신규 설치. 라우터에서 이미 설치 의사 확인됨 → scope만 묻고 바로 설치.
            if (-not $Force) {
                Print-Info "Claude Code 플러그인(DevOps Skills) 설치 — 설치 후 /cassiiopeia:suh-* 19+ 스킬 사용 가능"
                $scope = "user"
                Invoke-ClaudePluginInstall $scope
            } else {
                Invoke-ClaudePluginInstall "user"
            }
        }
    } else {
        Write-Host "  Claude Code 사용자: claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE"
        Write-Host "                      claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user"
    }
}

# ── Cursor Skills 관리 (기존 섹션 로직 보존) ──
function Invoke-CursorSection {
    # Cursor는 마켓플레이스가 없어 ~/.cursor/skills/에 직접 복사하고,
    # cursor-skills-meta.json(버전 manifest)을 함께 써서 다음 실행 때 버전을 추적한다.
    # global(user) 한 곳만 관리한다. (sh와 동일)
    $cursorMeta = Join-Path $env:USERPROFILE ".cursor\skills\cursor-skills-meta.json"
    $cursorVer  = ""
    if (Test-Path $cursorMeta) { try { $cursorVer = (Get-Content $cursorMeta -Raw | ConvertFrom-Json).version } catch { } }

    # 스킬 소스 (원격 우선, 없으면 로컬)
    $src = Join-Path $TEMP_DIR "skills"
    if (-not (Test-Path $src)) { $src = "skills" }
    if (-not (Test-Path $src)) { $src = "" }

    Write-Host ""
    Print-Step "[ Cursor Skills 관리 ]"
    Write-Host ""

    if ($cursorVer) {
        $utag = ""
        if ($script:templateVersion -and $cursorVer -eq $script:templateVersion) { $utag = " ✓ 최신" }
        elseif ($script:templateVersion) { $utag = " -> v$($script:templateVersion)로 업데이트" }
        Print-Info "  현재: skill 설치됨 (v${cursorVer})${utag}"
    } else {
        Print-Info "  Cursor skill 설치 — /analyze, /review 등 (파일 복사 + 버전 manifest 자동 기록)"
    }

    if (-not $src) {
        Print-Warning "설치할 스킬 소스를 찾지 못했습니다 (다운로드된 템플릿 또는 로컬 skills/ 폴더가 필요합니다)."
        return
    }
    # 라우터에서 '설치/업데이트' 선택됨 → 추가 질문 없이 global(user)로 바로 복사·최신화.
    Invoke-CursorSkillsCopy "user" $src
}

# ── 제거 섹션 (2단계 라우터의 'remove' 동작에서 호출, sh _remove_*_section과 동일) ──
function Remove-ClaudeSection {
    param([bool]$claudeAvailable, [string]$installedScope)
    Write-Host ""
    Print-Step "[ Claude Code 플러그인 제거 ]"
    if (-not $claudeAvailable -or -not $installedScope) {
        Print-Info "  설치된 Claude Code 플러그인이 없어 건너뜁니다"
        return
    }
    Print-Info "  제거할 대상: cassiiopeia@cassiiopeia-marketplace (scope: ${installedScope})"
    $null = & claude plugin uninstall "cassiiopeia@cassiiopeia-marketplace" --scope $installedScope 2>&1
    if ($LASTEXITCODE -eq 0) {
        Print-Success "플러그인 uninstall 완료"
        Remove-ClaudePluginData
    } else {
        Print-Warning "삭제 실패. 수동 실행: claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope ${installedScope}"
    }
}

function Remove-CursorSection {
    Write-Host ""
    Print-Step "[ Cursor Skills 제거 ]"
    # global(user) 한 곳만 관리하므로 ~/.cursor/skills/만 확인·삭제한다. (sh와 동일)
    $cursorDir = Join-Path $env:USERPROFILE ".cursor\skills"
    $cursorMeta = Join-Path $cursorDir "cursor-skills-meta.json"
    if (-not (Test-Path $cursorMeta)) {
        Print-Info "  설치된 Cursor Skills가 없어 건너뜁니다"
        return
    }
    try {
        Remove-Item -Recurse -Force $cursorDir -ErrorAction Stop
        Print-Success "Cursor Skills 제거 완료 ($cursorDir)"
    } catch {
        Print-Warning "Cursor Skills 제거 실패 — 수동 삭제: $cursorDir"
    }
}

function Remove-GeminiSection {
    Write-Host ""
    Print-Step "[ Gemini CLI Extension 제거 ]"
    if (-not (Get-Command "gemini" -ErrorAction SilentlyContinue)) {
        Print-Info "  gemini CLI 미감지 — 건너뜁니다"
        return
    }
    $null = & gemini extensions uninstall cassiiopeia 2>&1
    if ($LASTEXITCODE -eq 0) { Print-Success "Gemini CLI extension 제거 완료" }
    else { Print-Info "  제거할 Gemini extension이 없거나 실패 — 수동: gemini extensions uninstall cassiiopeia" }
}

function Remove-CodexSection {
    Write-Host ""
    Print-Step "[ Codex CLI Plugin 제거 ]"
    $codexTarget = Join-Path $env:USERPROFILE ".agents\skills\cassiiopeia"
    if (Test-Path $codexTarget) {
        Remove-Item -Recurse -Force $codexTarget -ErrorAction SilentlyContinue
        Print-Success "Codex native skills 제거 완료 ($codexTarget)"
    } else {
        Print-Info "  제거할 Codex skills가 없어 건너뜁니다"
    }
    if (Get-Command "codex" -ErrorAction SilentlyContinue) {
        Print-Info "  marketplace 등록 해제는 수동: codex plugin marketplace remove cassiiopeia"
    }
}

function Remove-PiSection {
    Write-Host ""
    Print-Step "[ PI 패키지 제거 ]"
    if (-not (Test-PiCli)) {
        Print-Info "  pi CLI 미감지 — 건너뜁니다"
        return
    }
    if (-not (Test-PiInstalled)) {
        Print-Info "  설치된 PI 패키지가 없어 건너뜁니다"
        return
    }
    Print-Info "  pi remove $Script:PiPackageUrl"
    cmd /c "pi remove `"$Script:PiPackageUrl`" 2>&1" | Out-Null
    if (Test-PiInstalled) {
        Print-Warning "  제거 후에도 패키지가 남아있습니다 — 'pi list'로 확인하세요."
    } else {
        Print-Success "PI 패키지 제거 완료"
    }
    # package 클론이 사라지면 등록된 harness loader 경로가 허공을 가리킨다 — 같이 해제
    if (Test-PiHarnessEnabled) {
        Print-Info "  Persona Harness 등록도 함께 해제됩니다."
        [void](Remove-PiHarnessExtension)
    }
}

# ─── Claude Code 헬퍼 ───────────────────────────────────────────


# 마켓플레이스 등록 + 플러그인 설치
function Invoke-ClaudePluginInstall {
    param([string]$Scope)

    Print-Step "Claude Code 마켓플레이스 등록 중..."
    $null = & claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE 2>&1  # 이미 등록된 경우 exit code가 0이 아닐 수 있으므로 항상 진행
    if ($LASTEXITCODE -eq 0) {
        Print-Success "마켓플레이스 등록 완료"
    } else {
        Print-Info "마켓플레이스 이미 등록되어 있거나 등록 생략"
    }

    Print-Step "Claude Code 플러그인 설치 중 (scope: ${Scope})..."
    $null = & claude plugin install "cassiiopeia@cassiiopeia-marketplace" --scope $Scope 2>&1
    if ($LASTEXITCODE -eq 0) {
        Print-Success "Claude Code 플러그인 설치 완료 (cassiiopeia, scope: ${Scope})"
    } else {
        Print-Warning "플러그인 설치 실패. 수동으로 설치해주세요:"
        Write-Host "    claude plugin install cassiiopeia@cassiiopeia-marketplace --scope ${Scope}"
        Write-Host ""
    }
}

# 업데이트 후 새 버전 캐시 폴더에 config.json이 없으면 이전 버전에서 복사
# Claude Code UI "Update Now" 경로는 install을 거치지 않으므로 이 함수가 두 경로 모두 커버한다.
function Invoke-ConfigMigration {
    $cacheBase = Join-Path $env:USERPROFILE ".claude\plugins\cache\cassiiopeia-marketplace\cassiiopeia"
    if (-not (Test-Path $cacheBase)) { return }

    # semver 내림차순 정렬 → [0]이 최신 버전
    $versions = Get-ChildItem -Path $cacheBase -Directory |
        Sort-Object { [Version]($_.Name -replace '[^0-9.]', '') } -Descending

    if ($versions.Count -lt 2) { return }  # 이전 버전 없으면 스킵

    $latestDir  = $versions[0].FullName
    $olderDirs  = $versions[1..($versions.Count - 1)] | ForEach-Object { $_.FullName }

    $skillsDir = Join-Path $latestDir "skills"
    if (-not (Test-Path $skillsDir)) { return }

    $migratedCount = 0
    foreach ($skillDir in Get-ChildItem -Path $skillsDir -Directory) {
        $destConfig = Join-Path $skillDir.FullName "config.json"
        if (Test-Path $destConfig) { continue }  # 이미 있으면 스킵

        foreach ($older in $olderDirs) {
            $srcConfig = Join-Path $older "skills\$($skillDir.Name)\config.json"
            if (Test-Path $srcConfig) {
                Copy-Item -Path $srcConfig -Destination $destConfig -ErrorAction SilentlyContinue
                $migratedCount++
                break
            }
        }
    }

    if ($migratedCount -gt 0) {
        Print-Success "config.json 마이그레이션 완료 (${migratedCount}개 skill)"
    }
}

# plugin data(config) 디렉토리 삭제
# Claude Code는 $env:USERPROFILE\.claude\plugins\data\{id}\ 에 plugin 설정을 저장한다.
function Remove-ClaudePluginData {
    # Claude Code plugin data 경로: %USERPROFILE%\.claude\plugins\data\{plugin-id}\
    # plugin id는 "cassiiopeia@cassiiopeia-marketplace" 형태 그대로 사용된다.
    $dataDir = Join-Path $env:USERPROFILE ".claude\plugins\data\cassiiopeia@cassiiopeia-marketplace"

    if (Test-Path $dataDir) {
        Remove-Item -Path $dataDir -Recurse -Force -ErrorAction SilentlyContinue
        Print-Success "플러그인 데이터(config) 삭제 완료"
    }
    # data 디렉토리가 없는 경우는 정상 — 별도 메시지 불필요
}

# ─── Cursor 헬퍼 ────────────────────────────────────────────────

# cursor-skills-meta.json 생성/갱신 — global(user) 한 곳 기준
# 인자: $Scope(항상 user), $DestDir(설치 경로 = ~/.cursor/skills)
function Write-CursorSkillsMeta {
    param(
        [string]$Scope   = "user",
        [string]$DestDir = (Join-Path $env:USERPROFILE ".cursor\skills")
    )
    $version   = if ($script:templateVersion) { $script:templateVersion } else { "unknown" }
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $metaFile  = Join-Path $DestDir "cursor-skills-meta.json"

    # 업데이트 시 installedAt 기존 값 보존
    $installedAt = $timestamp
    if (Test-Path $metaFile) {
        try {
            $existing = Get-Content $metaFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($existing -and $existing.installedAt) { $installedAt = $existing.installedAt }
        } catch { }
    }

    if (-not (Test-Path $DestDir)) {
        New-Item -Path $DestDir -ItemType Directory -Force | Out-Null
    }

    # PS5 호환: here-string으로 JSON 직접 작성
    $escapedDest = $DestDir -replace '\\', '\\'
    $json = @"
{
  "name": "cassiiopeia",
  "version": "$version",
  "scope": "$Scope",
  "source": "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE",
  "installPath": "$escapedDest",
  "installedAt": "$installedAt",
  "lastUpdated": "$timestamp"
}
"@
    $json | Set-Content -Path $metaFile -Encoding UTF8
}


# Cursor Skills 실제 복사 실행 — global(user) 한 곳에만. 첫 인자는 하위호환용.
function Invoke-CursorSkillsCopy {
    param([string]$Scope, [string]$Src)
    $dest = Join-Path $env:USERPROFILE ".cursor\skills"
    Print-Step "Cursor Skills 복사 중..."
    if (-not (Test-Path $dest)) { New-Item -Path $dest -ItemType Directory -Force | Out-Null }
    try {
        Copy-Item -Path "$Src\*" -Destination "$dest\" -Recurse -Force -ErrorAction Stop
        # 버전 manifest 자동 기록 → 다음 실행 때 설치 버전 추적 가능
        Write-CursorSkillsMeta "user" $dest
        Print-Success "Cursor Skills 설치 완료 ($dest\, v$($script:templateVersion))"
    } catch {
        Print-Warning "Cursor Skills 복사에 실패했습니다 — 원본 skills/ 폴더를 확인하거나 다시 시도하세요."
    }
}


# ─── Gemini CLI 헬퍼 ────────────────────────────────────────────

function Invoke-GeminiExtensionManage {
    Write-Host ""
    Print-Step "[ Gemini CLI Extension 관리 ]"
    Write-Host ""

    $gemini = Get-Command "gemini" -ErrorAction SilentlyContinue
    if (-not $gemini) {
        Print-Warning "gemini CLI가 감지되지 않았습니다. 수동 설치 명령:"
        Write-Host "    gemini extensions install https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
        return
    }

    # 라우터에서 '설치/업데이트' 선택됨 → 추가 확인 없이 바로 실행.
    Print-Step "Gemini CLI extension 업데이트 중..."
    $null = & gemini extensions update cassiiopeia 2>$null
    if ($LASTEXITCODE -eq 0) {
        Print-Success "Gemini CLI extension 업데이트 완료"
        return
    }

    Print-Step "Gemini CLI extension 설치 중..."
    $null = & gemini extensions install "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Print-Success "Gemini CLI extension 설치 완료"
    } else {
        Print-Warning "Gemini CLI extension 설치 실패. 수동으로 설치해주세요:"
        Write-Host "    gemini extensions install https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    }
}

# ─── Codex CLI 헬퍼 ─────────────────────────────────────────────

function Invoke-CodexSkillsManage {
    Write-Host ""
    Print-Step "[ Codex CLI Plugin 관리 ]"
    Write-Host ""

    if (Get-Command "codex" -ErrorAction SilentlyContinue) {
        # 라우터에서 '설치/업데이트' 선택됨 → 추가 확인 없이 바로 등록/업데이트.
        Invoke-CodexMarketplaceRegister
        return
    } else {
        Print-Warning "codex CLI가 감지되지 않았습니다."
        Print-Info "설치 후 수동으로 실행하세요: codex plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    }
}

function Invoke-CodexMarketplaceRegister {
    Print-Step "Codex plugin marketplace 등록 중..."
    $null = & codex plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE 2>$null
    if ($LASTEXITCODE -eq 0) {
        Print-Success "Codex marketplace 등록 완료"
    } else {
        Print-Info "Codex marketplace가 이미 등록되어 있거나 등록 생략"
    }

    Print-Step "Codex plugin marketplace 업데이트 중..."
    $null = & codex plugin marketplace upgrade cassiiopeia 2>$null
    Print-Success "Codex marketplace 등록 완료 (/plugins에서 확인 가능)"
}

function Invoke-CodexNativeSkillsFallback {
    param([string]$Mode = "interactive")

    Print-Step "[ Codex CLI Native Skills fallback 관리 ]"
    Write-Host ""

    $installDir = Join-Path $env:USERPROFILE ".codex\cassiiopeia"
    $skillsDir  = Join-Path $installDir "skills"
    $targetDir  = Join-Path $env:USERPROFILE ".agents\skills"
    $target     = Join-Path $targetDir "cassiiopeia"

    if ($Mode -ne "auto" -and -not $Force) {
        Write-Host "  설치 경로: $target"
        Write-Host ""
        # 선택지(예/아니오)는 아래 Ask-YesNo가 화살표 메뉴로 직접 보여주므로 여기서 중복 안내하지 않는다.
        if (-not (Ask-YesNo "Codex native skills fallback을 설치/업데이트할까요?" "Y")) {
            Print-Info "Codex native skills fallback을 건너뜁니다 (marketplace 등록 방식만 사용)."
            return
        }
    }

    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Print-Warning "git이 없어 Codex native skills를 자동 설치할 수 없습니다."
        Write-Host "    git clone https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git `"$installDir`""
        Write-Host "    New-Item -ItemType Directory -Force -Path `"$targetDir`""
        Write-Host "    cmd /c mklink /J `"%USERPROFILE%\.agents\skills\cassiiopeia`" `"%USERPROFILE%\.codex\cassiiopeia\skills`""
        return
    }

    if (Test-Path (Join-Path $installDir ".git")) {
        Print-Step "Codex skills 저장소 업데이트 중..."
        $null = & git -C $installDir pull --ff-only 2>$null
        if ($LASTEXITCODE -ne 0) {
            Print-Warning "기존 저장소 업데이트 실패. 수동 확인 필요: $installDir"
        }
    } elseif (Test-Path $installDir) {
        Print-Warning "설치 경로가 이미 존재하지만 git 저장소가 아닙니다: $installDir"
        return
    } else {
        Print-Step "Codex skills 저장소 clone 중..."
        $null = & git clone "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git" $installDir 2>$null
        if ($LASTEXITCODE -ne 0) {
            Print-Warning "Codex skills 저장소 clone에 실패했습니다 — 네트워크를 확인하거나 수동으로 git clone 하세요."
            return
        }
    }

    if (-not (Test-Path $skillsDir)) {
        Print-Warning "skills 디렉토리를 찾을 수 없습니다: $skillsDir"
        return
    }

    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }

    if (Test-Path $target) {
        $item = Get-Item $target -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Remove-Item -Path $target -Force
        } else {
            Print-Warning "대상 경로가 이미 존재하고 junction/symlink가 아닙니다: $target"
            Print-Warning "기존 경로를 보존하기 위해 자동 덮어쓰기를 중단합니다."
            return
        }
    }

    $null = & cmd /c mklink /J "$target" "$skillsDir" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Print-Success "Codex native skills 설치 완료 ($target -> $skillsDir)"
    } else {
        Print-Warning "junction 생성 실패. 수동으로 실행해주세요:"
        Write-Host "    cmd /c mklink /J `"$target`" `"$skillsDir`""
    }
}

# ─── PI 헬퍼 ────────────────────────────────────────────────────
# pi는 native `pi install <git-url>` 사용. raw 다운로드 X.
# 패키지의 skill은 복사되지 않고, settings의 packages에 등록된 패키지 경로를
# pi가 startup마다 직접 스캔한다. 따라서 설치 검증은 폴더 존재가 아니라 'pi list' 출력으로 한다.

# pi.ps1은 내부에서 node를 호출하며 버전을 stderr로 출력한다. PS 5.1 + $ErrorActionPreference='Stop'
# 환경에서 `& pi --version 2>$null`은 NativeCommandError가 terminating error로 격상돼 실패한다.
# → cmd /c로 호출해 stderr를 stdout에 합쳐 받아 ErrorRecord 래핑을 회피한다(Gemini 패턴과 동일).
function Test-PiCli {
    try {
        $out = cmd /c "pi --version 2>&1"
        return ($LASTEXITCODE -eq 0 -and $out -match '\d+\.\d+\.\d+')
    } catch {
        return $false
    }
}

# pi 패키지가 설치돼 있는지: 'pi list' 출력에 우리 레포가 잡히면 true.
function Test-PiInstalled {
    if (-not (Test-PiCli)) { return $false }
    try {
        $output = cmd /c "pi list 2>&1" | Out-String
        return ($output -match 'SUH-DEVOPS-TEMPLATE' -or $output -match 'cassiiopeia')
    } catch {
        return $false
    }
}

# pi 표준 클론 위치: ~/.pi/agent/git/<host>/<owner>/<repo>
function Get-PiCloneDir {
    return Join-Path $env:USERPROFILE ".pi\agent\git\github.com\Cassiiopeia\SUH-DEVOPS-TEMPLATE"
}
function Get-PiHarnessLoaderPath {
    return Join-Path (Get-PiCloneDir) "harness\harness-loader.ts"
}
function Get-PiSettingsPath {
    return Join-Path $env:USERPROFILE ".pi\agent\settings.json"
}

# settings.json의 extensions 배열에 harness loader가 등록돼 있는가
function Test-PiHarnessEnabled {
    $settingsPath = Get-PiSettingsPath
    if (-not (Test-Path $settingsPath)) { return $false }
    try {
        $s = Get-Content -Raw $settingsPath -ErrorAction Stop | ConvertFrom-Json
        return (@($s.extensions) -contains (Get-PiHarnessLoaderPath))
    } catch {
        return $false
    }
}

# extensions 배열에 harness loader 추가 (중복 방지). 성공 $true.
function Add-PiHarnessExtension {
    $settingsPath = Get-PiSettingsPath
    if (-not (Test-Path $settingsPath)) {
        Print-Warning "  PI settings.json이 없습니다 — PI를 한 번 실행한 뒤 다시 시도하세요."
        return $false
    }
    $loader = Get-PiHarnessLoaderPath
    if (-not (Test-Path $loader)) {
        Print-Warning "  harness loader가 없습니다: $loader"
        Print-Warning "  먼저 PI 패키지를 설치/업데이트하세요."
        return $false
    }
    try {
        $s = Get-Content -Raw $settingsPath -ErrorAction Stop | ConvertFrom-Json
    } catch {
        Print-Warning "  settings.json 파싱 실패 — 직접 확인 필요: $settingsPath"
        return $false
    }
    $exts = @(@($s.extensions) | Where-Object { $_ })
    if ($exts -contains $loader) { return $true }
    $exts = @($exts) + $loader
    if ($null -eq $s.PSObject.Properties['extensions']) {
        $s | Add-Member -NotePropertyName extensions -NotePropertyValue @()
    }
    $s.extensions = $exts
    # BOM 없는 UTF-8 — pi(node)는 BOM이 있으면 파싱에 실패할 수 있다
    [System.IO.File]::WriteAllText($settingsPath, ($s | ConvertTo-Json -Depth 10))
    return $true
}

# extensions 배열에서 harness loader 제거. 성공 $true.
function Remove-PiHarnessExtension {
    $settingsPath = Get-PiSettingsPath
    if (-not (Test-Path $settingsPath)) { return $true }
    try {
        $s = Get-Content -Raw $settingsPath -ErrorAction Stop | ConvertFrom-Json
    } catch {
        Print-Warning "  settings.json 파싱 실패 — 직접 확인 필요: $settingsPath"
        return $false
    }
    $loader = Get-PiHarnessLoaderPath
    if ($null -eq $s.PSObject.Properties['extensions']) { return $true }
    $s.extensions = @(@($s.extensions) | Where-Object { $_ -and $_ -ne $loader })
    [System.IO.File]::WriteAllText($settingsPath, ($s | ConvertTo-Json -Depth 10))
    Print-Success "  Persona Harness 해제 완료 — PI 재시작 후 적용됩니다."
    return $true
}

# Persona Harness 설치 제안 (PI 설치/업데이트 직후 호출).
# 이미 활성화돼 있으면 그대로 두고, 꺼져 있을 때만 켤지 묻는다.
# (해제는 PI 제거 흐름 Remove-PiSection에서 함께 처리하므로 여기선 켜기만 다룬다.)
# FORCE/비대화형이면 자동 스킵.
function Offer-PiHarness {
    # 이미 활성화돼 있으면 설치 흐름에서 더 묻지 않는다.
    if (Test-PiHarnessEnabled) {
        Print-Info "  Persona Harness: 이미 활성화됨 (유지)"
        return
    }
    if (-not (Test-Path (Get-PiHarnessLoaderPath))) {
        Print-Info "  harness loader가 아직 없어 건너뜁니다 (PI 패키지 설치 후 재시도)."
        return
    }
    # 비대화형이면 묻지 않고 skill만 사용 (보수적 기본값).
    $forceMode = $false
    try { if ($script:Force -eq $true) { $forceMode = $true } } catch {}
    if ($forceMode) {
        Print-Info "  Persona Harness: 비활성화 (비대화형 — skill만 사용)"
        return
    }

    Print-Step "(PI 전용) Persona Harness 활성화"
    Write-PiHarnessDesc
    Print-Info "  나중에 켜고/끄려면 [설치/업데이트] 또는 [제거] 메뉴의 'PI Persona Harness' 항목을 쓰세요."

    if (Ask-YesNo "Persona Harness를 활성화할까요?" "N") {
        if (Add-PiHarnessExtension) {
            Print-Success "  Persona Harness 활성화 완료 — PI 재시작 후 적용됩니다."
        }
    } else {
        Print-Info "  → 건너뜁니다 (skill만 사용, harness는 비활성)"
    }
}

# harness 개념 설명 출력 (토글/단독 메뉴에서 재사용)
function Write-PiHarnessDesc {
    Print-Info "  Persona Harness는 PI가 대화를 시작할 때마다 '전문가 페르소나'와 'SDLC 워크플로우'를"
    Print-Info "  시스템 프롬프트에 자동 주입하는 기능입니다."
    Print-Info "  • 페르소나(PERSONA): 아키텍트·개발자·리뷰어 등 전문가 역할을 AI에 부여해 답변 품질을 끌어올림"
    Print-Info "  • 워크플로우(WORKFLOW): 요구분석→설계→구현→검증 단계를 따르도록 행동 지침을 부여"
    Print-Info "  skill과는 독립적으로 동작합니다 (skill은 그대로 두고 harness만 켜고/끌 수 있습니다)."
}

# [설치/업데이트] 메뉴에서 'PI Persona Harness' 단독 선택 시 — 현재 상태 토글.
# skill은 건드리지 않고 harness 등록만 켜거나 끈다.
function Invoke-PiHarnessToggle {
    Write-Host ""
    Print-Step "[ PI Persona Harness 관리 ]"
    if (-not (Test-PiCli)) {
        Print-Warning "  pi CLI 미감지 — 건너뜁니다"
        return
    }
    if (-not (Test-Path (Get-PiHarnessLoaderPath))) {
        Print-Warning "  harness loader가 없습니다 — 먼저 [설치/업데이트]에서 PI를 설치하세요."
        return
    }
    Write-PiHarnessDesc
    if (Test-PiHarnessEnabled) {
        Print-Info "  현재 상태: 활성화"
        if (Ask-YesNo "Persona Harness를 비활성화할까요? (PI skill은 유지됩니다)" "N") {
            [void](Remove-PiHarnessExtension)
        } else {
            Print-Info "  → 활성화 상태 유지"
        }
    } else {
        Print-Info "  현재 상태: 비활성화"
        if (Ask-YesNo "Persona Harness를 활성화할까요?" "N") {
            if (Add-PiHarnessExtension) {
                Print-Success "  Persona Harness 활성화 완료 — PI 재시작 후 적용됩니다."
            }
        } else {
            Print-Info "  → 비활성화 상태를 유지합니다 (skill만 사용)"
        }
    }
}

# [제거] 메뉴에서 'PI Persona Harness' 단독 선택 시 — harness만 해제, PI skill은 보존.
function Remove-PiHarnessOnly {
    Write-Host ""
    Print-Step "[ PI Persona Harness 해제 ]"
    if (-not (Test-PiHarnessEnabled)) {
        Print-Info "  Persona Harness가 활성화돼 있지 않아 건너뜁니다"
        return
    }
    Print-Info "  PI skill은 그대로 두고 harness 등록만 해제합니다."
    [void](Remove-PiHarnessExtension)
}

function Invoke-PiSection {
    Write-Host ""
    Print-Step "[ PI 패키지 관리 ]"
    Write-Host ""

    if (-not (Test-PiCli)) {
        Print-Warning "pi CLI가 감지되지 않았습니다. 설치 후 수동으로 실행하세요:"
        Write-Host "    pi install $Script:PiPackageUrl"
        return
    }

    # 라우터에서 '설치/업데이트' 선택됨 → 추가 확인 없이 바로 실행.
    if (Test-PiInstalled) {
        Print-Step "PI 패키지 업데이트 중..."
        cmd /c "pi update `"$Script:PiPackageUrl`" 2>&1" | ForEach-Object { Print-Info "    $_" }
    } else {
        Print-Step "PI 패키지 설치 중..."
        cmd /c "pi install `"$Script:PiPackageUrl`" 2>&1" | ForEach-Object { Print-Info "    $_" }
    }

    if (Test-PiInstalled) {
        Print-Success "PI 패키지 설치 / 업데이트 완료"
        Print-Info "  → 'pi' 재실행 후 'pi list' 로 확인"
        Print-Info "  → 채팅창에서 /suh-analyze, /suh-review 등으로 호출하세요."
        # skill 설치와 별개로, harness는 opt-in으로만 켠다.
        Offer-PiHarness
    } else {
        Print-Warning "PI 설치/업데이트 실패 — 수동으로 실행해주세요:"
        Write-Host "    pi install $Script:PiPackageUrl"
    }
}

# ===================================================================
# 완료 요약
# ===================================================================

function Show-Summary {
    Write-Host ""
    Print-SeparatorLine
    Write-Host ""
    Write-Host "✨ SUH-DEVOPS-TEMPLATE Setup Complete!"
    Write-Host ""
    Print-SeparatorLine
    Write-Host ""
    Write-Host "통합된 기능:"
    
    switch ($Mode) {
        "full" {
            Write-Host "  ✅ 버전 관리 시스템 (version.yml)"
            Write-Host "  ✅ README.md 자동 버전 업데이트"
            Write-Host "  ✅ GitHub Actions 워크플로우"
            Write-Host "  ✅ 이슈/PR/Discussion 템플릿"
            Write-Host "  ✅ CodeRabbit AI 리뷰 설정"
            Write-Host "  ✅ .gitignore 필수 항목"
            Write-Host "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)"
        }
        "version" {
            Write-Host "  ✅ 버전 관리 시스템 (version.yml)"
            Write-Host "  ✅ README.md 자동 버전 업데이트"
            Write-Host "  ✅ .gitignore 필수 항목"
            Write-Host "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)"
        }
        "workflows" {
            Write-Host "  ✅ GitHub Actions 워크플로우"
            Write-Host "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)"
        }
        "issues" {
            Write-Host "  ✅ 이슈/PR/Discussion 템플릿"
        }
        "skills" {
            Write-Host "  ✅ Agent Skill 설치 (Claude, Cursor, Gemini, Codex, PI)"
        }
    }

    # skills 모드: 파일/워크플로우 추가 없으므로 간결하게 종료
    if ($Mode -eq "skills") {
        Write-Host ""
        Write-Host "  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
        Write-Host ""
        Print-SeparatorLine
        Write-Host ""
        return
    }

    Write-Host ""
    Write-Host "추가된 파일:"
    $summaryTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes -join ',' } else { $script:ProjectType }
    Write-Host "  📄 version.yml (버전: $($script:ProjectVersion), 타입: $summaryTypes)"
    Write-Host "  📝 README.md (버전 섹션 추가)"
    Write-Host ""
    Write-Host "추가된 워크플로우:"
    Write-Host "  📦 새로 설치됨 ($($script:WorkflowsCopied)개)"
    Write-Host ""
    Write-Host "  🔧 .github/scripts/"
    Write-Host "     ├─ version_manager.sh"
    Write-Host "     └─ changelog_manager.py"
    Write-Host ""

    # util 모듈 정보 표시 — ProjectTypes 배열 순회
    if ($script:UtilModulesCopied -gt 0) {
        Write-Host "  📦 유틸리티 모듈:"
        $utTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
        foreach ($ut in $utTypes) {
            $utilPath = ".github/util/$ut"
            if (Test-Path $utilPath) {
                $modDirs = Get-ChildItem -Path $utilPath -Directory -ErrorAction SilentlyContinue
                foreach ($d in $modDirs) {
                    Write-Host "     ├─ $($d.Name) ($ut)"
                }
            }
        }
        Write-Host ""

        # Flutter 유틸리티 모듈 안내 — 배열에 flutter 포함 시
        if (Test-ContainsType "flutter") {
            Write-Host "  💡 Flutter 유틸리티 모듈 사용법:"
            Write-Host "     • iOS TestFlight 마법사: .github/util/flutter/ios-testflight-setup-wizard/"
            Write-Host "       → index.html을 브라우저에서 열어 설정 파일 생성"
            Write-Host "     • Android Play Store 마법사: .github/util/flutter/android-playstore-setup-wizard/"
            Write-Host "       → init.ps1 또는 init.sh 실행하여 설정 시작"
            Write-Host ""
        }
    }

    # 프로젝트 타입별 안내 — 배열에 spring 포함 시
    if (Test-ContainsType "spring") {
        Write-Host "  💡 Spring 프로젝트 추가 설정:"
        Write-Host "     • build.gradle의 버전 정보가 자동 동기화됩니다"
        Write-Host "     • CI/CD 워크플로우에서 GitHub Secrets 설정이 필요합니다"
        Write-Host "     • 자세한 설정 방법: .github/workflows/project-types/spring/README.md"
        Write-Host ""
    }
    
    Write-Host "  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    Write-Host "  📚 워크플로우 가이드: .github/workflows/project-types/README.md"
    Write-Host ""
    
    # 필수 3가지 작업 안내
    Print-SeparatorLine
    Write-Host ""
    Write-ColorOutput "⚠️  다음 3가지 작업을 완료해주세요:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1️⃣  GitHub Personal Access Token 설정"
    Write-Host "     → Repository Settings > Secrets > Actions"
    Write-Host "     → Secret Name: _GITHUB_PAT_TOKEN"
    Write-Host "     → Scopes: repo, workflow"
    Write-Host ""
    Write-Host "  2️⃣  deploy 브랜치 생성"
    Write-Host "     → git checkout -b deploy && git push -u origin deploy"
    Write-Host ""
    Write-Host "  3️⃣  CodeRabbit 활성화"
    Write-Host "     → https://coderabbit.ai 방문하여 저장소 활성화"
    Write-Host ""
    Print-SeparatorLine
    Write-Host ""
    Write-ColorOutput "📖 자세한 설정 방법은 다음 파일을 참고하세요:" -ForegroundColor Cyan
    Write-Host "   → SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    Write-Host ""
}

# ===================================================================
# 메인 실행
# ===================================================================

function Main {
    # 도움말 표시
    if ($Help) {
        Show-Help
        exit 0
    }
    
    # 파라미터 검증
    $validModes = @("interactive", "full", "version", "workflows", "issues", "skills")
    if ($Mode -ne "" -and $Mode -notin $validModes) {
        Print-Error "잘못된 모드: $Mode"
        Write-Host "지원되는 모드: $($validModes -join ', ')"
        Write-Host ""
        Write-Host "도움말: .\template_integrator.ps1 -Help"
        exit 1
    }
    
    # -Type csv 분해 → ProjectTypes 배열 (멀티타입). dedup + 검증 후 첫 항목을 ProjectType에 미러
    if ($Type -ne "") {
        $arr = $Type.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $script:ProjectTypes = @($arr | Select-Object -Unique)
        foreach ($t in $script:ProjectTypes) {
            if ($script:ValidTypes -notcontains $t) {
                Print-Error "지원하지 않는 타입: '$t'"
                Write-Host "지원되는 타입: $($script:ValidTypes -join ', ')"
                Write-Host ""
                Write-Host "도움말: .\template_integrator.ps1 -Help"
                exit 1
            }
        }
        if ($script:ProjectTypes.Count -eq 0) {
            Print-Error "-Type 인자가 비어 있습니다"
            exit 1
        }
        $script:ProjectType = $script:ProjectTypes[0]
    }
    
    # Git 저장소 확인 (경고만 표시)
    try {
        git rev-parse --git-dir 2>&1 | Out-Null
    } catch {
        Print-Warning "Git 저장소가 아닙니다. 일부 기능이 제한될 수 있습니다."
        Write-Host ""
    }
    
    # 대화형 모드
    if ($Mode -eq "interactive") {
        Start-InteractiveMode
    }
    
    # 통합 실행
    Start-Integration
}

# 스크립트 실행
Main
