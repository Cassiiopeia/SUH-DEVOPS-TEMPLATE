<#
.SYNOPSIS
  Firebase App Distribution Wizard - Setup Script (PowerShell)

.DESCRIPTION
  워크플로우 파일들의 FIREBASE_APP_ID, FIREBASE_TESTER_GROUP 키를
  라인 단위로 안전하게 치환합니다.

.EXAMPLE
  .\firebase-wizard-setup.ps1 -ProjectPath . -AppId "1:905..." -TesterGroup "romrom"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ProjectPath,
    [Parameter(Mandatory)] [string]$AppId,
    [Parameter(Mandatory)] [string]$TesterGroup,
    [switch]$DryRun,
    [switch]$NonInteractive,
    [switch]$NoBackup
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path -PathType Container $ProjectPath)) {
    Write-Host "[ERROR] project-path 디렉터리가 존재하지 않음: $ProjectPath" -ForegroundColor Red
    exit 2
}

$WorkflowsDir = Join-Path $ProjectPath ".github\workflows"
if (-not (Test-Path -PathType Container $WorkflowsDir)) {
    Write-Host "[ERROR] .github/workflows 폴더가 없음. 템플릿 미적용 프로젝트입니다." -ForegroundColor Red
    Write-Host "        확인 경로: $WorkflowsDir" -ForegroundColor Yellow
    exit 3
}

$YamlFiles = Get-ChildItem -Path $WorkflowsDir -File | Where-Object { $_.Extension -in '.yaml', '.yml' } | Sort-Object Name

if ($YamlFiles.Count -eq 0) {
    Write-Host "[WARN] workflows 폴더에 yaml/yml 파일이 없음" -ForegroundColor Yellow
    exit 0
}

$Timestamp = [int][double]::Parse((Get-Date -UFormat %s))
$script:TotalReplaced = 0
$script:TotalSkipped = 0
$script:TotalConflicts = 0
$script:Summary = @()
$script:Aborted = $false

# regex: indent + key + sep + value (단어 경계 보장 — 키 다음에 공백·콜론만 허용)
$KeyPattern = '^(?<indent>\s*)(?<key>FIREBASE_APP_ID|FIREBASE_TESTER_GROUP)(?<sep>\s*:\s*)(?<value>.*)$'

function Strip-Quotes {
    param([string]$Raw)
    # CRLF 안전: trailing \r 먼저 제거
    $v = $Raw.TrimEnd("`r").Trim()
    if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
        $v = $v.Substring(1, $v.Length - 2)
    }
    return $v.Trim()
}

function Process-File {
    param([string]$FilePath)
    $rel = $FilePath.Substring($ProjectPath.Length).TrimStart('\','/')
    $fileReplaced = 0
    $fileSkipped = 0
    $fileConflicts = 0

    $lines = Get-Content -LiteralPath $FilePath -Encoding UTF8
    $hasTargetKey = $false
    foreach ($l in $lines) {
        if ($l -match $KeyPattern) { $hasTargetKey = $true; break }
    }
    if (-not $hasTargetKey) {
        $script:Summary += "[SKIP] $rel -- 대상 키 없음"
        return $false
    }

    if (-not $NoBackup -and -not $DryRun) {
        Copy-Item -LiteralPath $FilePath -Destination "$FilePath.bak.$Timestamp" -Force
    }

    $newLines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -match $KeyPattern) {
            $indent = $Matches['indent']
            $key = $Matches['key']
            $sep = $Matches['sep']
            $rawValue = $Matches['value']
            $stripped = Strip-Quotes $rawValue

            $newValue = if ($key -eq 'FIREBASE_APP_ID') { $AppId } else { $TesterGroup }
            $placeholder = if ($key -eq 'FIREBASE_APP_ID') { '{FIREBASE_APP_ID}' } else { '{TESTER_GROUP}' }

            if ($stripped -eq $placeholder) {
                $newLines.Add("$indent$key$sep`"$newValue`"")
                $fileReplaced++
                Write-Host "  [OK] $rel -- ${key}: placeholder -> $newValue" -ForegroundColor Green
            } elseif ($stripped -eq $newValue) {
                $newLines.Add($line)
                $fileSkipped++
                Write-Host "  [INFO] $rel -- ${key}: 이미 같은 값, SKIP" -ForegroundColor Cyan
            } else {
                if ($NonInteractive) {
                    $newLines.Add($line)
                    $fileSkipped++
                    $fileConflicts++
                    Write-Host "  [WARN] $rel -- ${key}: 다른 값 ('$stripped'), 비대화형 SKIP" -ForegroundColor Yellow
                } else {
                    Write-Host ""
                    Write-Host "[!] 충돌 감지: $rel" -ForegroundColor Yellow
                    Write-Host "    키:    $key"
                    Write-Host "    현재값: $stripped"
                    Write-Host "    새 값: $newValue"
                    $choice = Read-Host "    덮어쓸까? (y/n/abort)"
                    switch -Regex ($choice) {
                        '^[yY]' {
                            $newLines.Add("$indent$key$sep`"$newValue`"")
                            $fileReplaced++
                            Write-Host "    [OK] 덮어씀" -ForegroundColor Green
                        }
                        '^[nN]' {
                            $newLines.Add($line)
                            $fileSkipped++
                            Write-Host "    [INFO] SKIP" -ForegroundColor Cyan
                        }
                        '^[aA]' {
                            Write-Host "[ERROR] 사용자 abort" -ForegroundColor Red
                            if (-not $NoBackup -and -not $DryRun) {
                                Move-Item -Force "$FilePath.bak.$Timestamp" $FilePath
                            }
                            $script:Aborted = $true
                            return $true
                        }
                        default {
                            $newLines.Add($line)
                            $fileSkipped++
                            Write-Host "    [INFO] 알 수 없는 입력 -> SKIP" -ForegroundColor Cyan
                        }
                    }
                }
            }
        } else {
            $newLines.Add($line)
        }
    }

    if (-not $DryRun) {
        $newLines -join [Environment]::NewLine | Set-Content -LiteralPath $FilePath -Encoding UTF8
    }

    $script:TotalReplaced += $fileReplaced
    $script:TotalSkipped += $fileSkipped
    $script:TotalConflicts += $fileConflicts
    $script:Summary += "[FILE] $rel -- 치환 $fileReplaced, SKIP $fileSkipped, 충돌 $fileConflicts"
    return $false
}

Write-Host "[Firebase Wizard Setup]" -ForegroundColor Cyan
Write-Host "  project-path: $ProjectPath"
Write-Host "  app-id:       $AppId"
Write-Host "  tester-group: $TesterGroup"
Write-Host "  dry-run: $DryRun | non-interactive: $NonInteractive | no-backup: $NoBackup"
Write-Host ""

foreach ($f in $YamlFiles) {
    $abort = Process-File $f.FullName
    if ($abort) { break }
}

Write-Host ""
Write-Host "===== Summary =====" -ForegroundColor Cyan
foreach ($s in $script:Summary) { Write-Host "  $s" }
Write-Host ""
Write-Host "총 치환: $($script:TotalReplaced) | SKIP: $($script:TotalSkipped) | 충돌(SKIP): $($script:TotalConflicts)"

if ($DryRun) {
    Write-Host "[!] -DryRun: 실제 파일은 수정되지 않았습니다" -ForegroundColor Yellow
}
if ($script:Aborted) {
    Write-Host "[ERROR] 사용자 abort로 중단됨" -ForegroundColor Red
    exit 4
}
exit 0
