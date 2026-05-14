# Firebase wizard setup script - PowerShell 시나리오 테스트
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WizardDir = Split-Path -Parent $ScriptDir
$Setup = Join-Path $WizardDir "firebase-wizard-setup.ps1"
$Fixtures = Join-Path $ScriptDir "fixtures"

$Pass = 0
$Fail = 0
$FailLog = @()

function Assert-Contains {
    param($Needle, $Haystack, $Label)
    if ($Haystack -like "*$Needle*") {
        $script:Pass++
        Write-Host "  [OK] $Label" -ForegroundColor Green
    } else {
        $script:Fail++
        $script:FailLog += "$Label -- 기대 문자열 '$Needle' 누락"
        Write-Host "  [FAIL] $Label" -ForegroundColor Red
    }
}

function Setup-Workspace {
    $ws = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path "$ws\.github\workflows" -Force | Out-Null
    Copy-Item "$Fixtures\*.yaml" -Destination "$ws\.github\workflows\"
    return $ws
}

function Cleanup-Workspace { param($ws); Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue }

$NewAppId = "1:905325245238:android:86db75164e0df29a1f3997"
$NewTester = "romrom"

Write-Host "=== 시나리오 1: placeholder -> 새 값 치환 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$content = Get-Content "$ws\.github\workflows\workflow-with-placeholders.yaml" -Raw
Assert-Contains $NewAppId $content "placeholder fixture에 새 APP_ID 적용"
Assert-Contains $NewTester $content "placeholder fixture에 새 TESTER 적용"
Cleanup-Workspace $ws

Write-Host "=== 시나리오 2: 키 없는 파일 변경 없음 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$origHash = (Get-FileHash "$Fixtures\workflow-without-keys.yaml").Hash
$newHash = (Get-FileHash "$ws\.github\workflows\workflow-without-keys.yaml").Hash
if ($origHash -eq $newHash) {
    $Pass++; Write-Host "  [OK] 키 없는 fixture 변경 없음" -ForegroundColor Green
} else {
    $Fail++; $FailLog += "키 없는 fixture가 변경됨"
    Write-Host "  [FAIL] 키 없는 fixture 변경 없음" -ForegroundColor Red
}
Cleanup-Workspace $ws

Write-Host "=== 시나리오 3: 같은 값 SKIP ==="
$ws = Setup-Workspace
$out = & $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup *>&1 | Out-String
Assert-Contains "이미" $out "같은 값 SKIP 메시지"
Cleanup-Workspace $ws

Write-Host "=== 시나리오 4: 다른 값 + non-interactive SKIP ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$content = Get-Content "$ws\.github\workflows\workflow-with-real-values.yaml" -Raw
Assert-Contains "1:111111111111:android:aaaaaaaaaaaaaaaaaaaaaa" $content "real-values APP_ID SKIP 보존"
Assert-Contains "old-group" $content "real-values TESTER_GROUP SKIP 보존"
Cleanup-Workspace $ws

Write-Host "=== 시나리오 5: -DryRun 시 변경 없음 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup -DryRun | Out-Null
$origHash = (Get-FileHash "$Fixtures\workflow-with-placeholders.yaml").Hash
$newHash = (Get-FileHash "$ws\.github\workflows\workflow-with-placeholders.yaml").Hash
if ($origHash -eq $newHash) {
    $Pass++; Write-Host "  [OK] dry-run 시 변경 없음" -ForegroundColor Green
} else {
    $Fail++; $FailLog += "dry-run인데 파일이 변경됨"
    Write-Host "  [FAIL] dry-run" -ForegroundColor Red
}
Cleanup-Workspace $ws

Write-Host "=== 시나리오 6: 백업 생성 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive | Out-Null
$bakCount = (Get-ChildItem "$ws\.github\workflows\*.bak.*" -ErrorAction SilentlyContinue).Count
if ($bakCount -ge 2) {
    $Pass++; Write-Host "  [OK] 백업 자동 생성 ($bakCount개)" -ForegroundColor Green
} else {
    $Fail++; $FailLog += "백업 부족 ($bakCount개)"
    Write-Host "  [FAIL] 백업" -ForegroundColor Red
}
Cleanup-Workspace $ws

Write-Host "=== 시나리오 7: -NoBackup 시 백업 미생성 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$bakCount = (Get-ChildItem "$ws\.github\workflows\*.bak.*" -ErrorAction SilentlyContinue).Count
if ($bakCount -eq 0) {
    $Pass++; Write-Host "  [OK] -NoBackup 시 백업 미생성" -ForegroundColor Green
} else {
    $Fail++; $FailLog += "-NoBackup인데 백업 생성됨 ($bakCount개)"
    Write-Host "  [FAIL] -NoBackup" -ForegroundColor Red
}
Cleanup-Workspace $ws

Write-Host "=== 시나리오 8: workflows 폴더 없음 abort ==="
$ws = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $ws -Force | Out-Null
$out = & $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup *>&1 | Out-String
Assert-Contains "workflows" $out "workflows 폴더 없음 에러"
Cleanup-Workspace $ws

Write-Host "=== 시나리오 9: 단어 경계 (FIREBASE_APP_ID_DEV 보호) ==="
$ws = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path "$ws\.github\workflows" -Force | Out-Null
@'
env:
  FIREBASE_APP_ID: "{FIREBASE_APP_ID}"
  FIREBASE_APP_ID_DEV: "{FIREBASE_APP_ID}"
'@ | Out-File -Encoding utf8 "$ws\.github\workflows\edge.yaml"
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$line = (Select-String -Path "$ws\.github\workflows\edge.yaml" -Pattern "FIREBASE_APP_ID_DEV").Line
Assert-Contains "{FIREBASE_APP_ID}" $line "FIREBASE_APP_ID_DEV는 단어 경계 매칭으로 변경되지 않음"
Cleanup-Workspace $ws

Write-Host ""
Write-Host "===================="
Write-Host "PASS: $Pass"
Write-Host "FAIL: $Fail"
if ($Fail -gt 0) {
    Write-Host ""
    Write-Host "실패 항목:"
    foreach ($m in $FailLog) { Write-Host "  - $m" }
    exit 1
}
exit 0
