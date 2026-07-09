### 문제 요약
PowerShell 환경에서 `template_integrator.ps1` 실행 시 Gemini CLI 업데이트 과정에서 외부 확장 오류로 인한 스크립트 강제 종료 현상 | **타입**: DevOps / Script | **환경**: Windows 11, PowerShell, gemini-cli v3.0.x

### 원인 분석
**근본 원인**: 
1. **Gemini CLI 내부 설계 결함**: `gemini-cli`가 확장 도구 목록을 조회하거나 업데이트할 때, 로컬에 정상적이지 않거나 구버전 형식의 타사 확장(`caveman` 등)이 설치되어 있으면 에이전트 유효성 검사(`Validation failed`) 오류를 내며 실행 프로세스가 비정상 종료(stderr 출력 및 zero가 아닌 exit code 반환)합니다.
2. **PowerShell 스크립트 실행 격리 미흡**: `template_integrator.ps1`은 안전을 위해 스크립트 상단에 `$ErrorActionPreference = "Stop"`을 사용합니다. 이 상태에서 PowerShell 고유의 호출 연산자(`&`)로 외부 CLI 프로그램(`gemini`)을 직접 실행하고, 이 프로그램이 stderr에 에러 메시지를 작성하게 되면 PowerShell이 이를 `NativeCommandError`로 간주하고 스크립트 전체를 즉시 중단(Stop)시켜 버립니다. 이로 인해 다음 조건 검사인 `$LASTEXITCODE` 비교문으로 진입조차 못 하고 스크립트가 튕기게 되었습니다.

**발생 메커니즘**:
1. 사용자가 `template_integrator.ps1`을 실행하고 "AI 스킬 설치" 단계를 거치며 `Invoke-GeminiExtensionManage` 함수가 호출됨.
2. `gemini extensions update cassiiopeia 2>$null`을 호출함.
3. `gemini` CLI가 실행되는 과정에서 사용자 로컬에 존재하던 깨진 확장(`caveman`)의 명세 파일 `C:\Users\USER\.gemini\extensions\cavecrew-builder.md`를 파싱하다가 유효성 검사 실패(`Validation failed: Agent Definition`)로 강제 중지하고 stderr 출력 발생.
4. PowerShell 엔진은 `$ErrorActionPreference = "Stop"` 규칙에 의해 이 stderr 출력을 감지하자마자 치명적 오류(`RemoteException`)를 발생시켜 `template_integrator.ps1` 실행을 즉시 중단 및 튕김 현상 발생.

### 해결 방법
#### Quick Fix
사용자 로컬의 깨진 `gemini` 확장을 수동으로 지워서 `gemini-cli` 자체가 올바르게 작동하도록 만듭니다.
```powershell
# 1. 문제의 원인이 되는 깨진 에이전트 디렉토리를 완전히 지웁니다.
Remove-Item -Recurse -Force "$env:USERPROFILE\.gemini\extensions\caveman"

# 2. 또는 수동으로 다시 설치를 진행해 봅니다.
gemini extensions uninstall caveman
gemini extensions install https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE
```

#### Root Fix (권장)
사용자의 로컬 환경에 상관없이 **통합 스크립트(`template_integrator.ps1`)가 외부 에러를 강력히 견뎌내도록 내부 호출 프로세스를 샌드박싱(Sandbox)하여 예외 처리**합니다.
1. `gemini` 및 `codex`를 다이렉트 연산자(`&`) 대신 `cmd /c`를 통해 실행하여, 외부 프로그램의 stderr 출력이 PowerShell의 호출 도중 치명적 오류로 승격되는 것을 차단합니다.
2. 스킬 업데이트/설치부 함수 전체를 `try-catch` 블록으로 감싸고, 실행 기간 동안에만 임시로 `$ErrorActionPreference = "Continue"`로 낮춘 후 완료 시 원복합니다.

**코드 변경 내용 (template_integrator.ps1):**
```powershell
function Invoke-GeminiExtensionManage {
    # ... 이전 동일 ...
    $gemini = Get-Command "gemini" -ErrorAction SilentlyContinue
    if (-not $gemini) { ... }

    # 외부 명령어 호출 시 발생할 수 있는 원격/네이티브 예외에 대비하여 임시로 ErrorActionPreference를 완화하고 try-catch로 격리합니다.
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        # 라우터에서 '설치/업데이트' 선택됨 → 추가 확인 없이 바로 실행.
        Print-Step "Gemini CLI extension 업데이트 중..."
        # cmd /c와 2>&1 리다이렉션을 사용하여 PowerShell의 무조건적인 NativeCommandError 발생을 차단합니다.
        $null = cmd /c "gemini extensions update cassiiopeia 2>&1"
        if ($LASTEXITCODE -eq 0) {
            Print-Success "Gemini CLI extension 업데이트 완료"
            return
        }

        Print-Step "Gemini CLI extension 설치 중..."
        $null = cmd /c "gemini extensions install `"https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE`" 2>&1"
        if ($LASTEXITCODE -eq 0) {
            Print-Success "Gemini CLI extension 설치 완료"
        } else {
            Print-Warning "Gemini CLI extension 설치 실패. 수동으로 설치해주세요:"
            Write-Host "    gemini extensions install https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
        }
    } catch {
        Print-Warning "Gemini CLI extension 설치/업데이트 중 예외가 발생했습니다:"
        Write-Host "    $_" -ForegroundColor Yellow
        Print-Info "로컬의 다른 Gemini Extension(예: caveman 등)에 오류가 있거나 gemini-cli 환경에 문제가 있을 수 있습니다."
        Print-Info "이 오류는 통합 전체에 영향을 주지 않으므로 건너뛰고 다음 단계를 진행합니다."
    } finally {
        $ErrorActionPreference = $oldEAP
    }
}
```

### 검증
1. 로컬에 의도적으로 깨진 gemini extension 마크다운 파일을 생성하여 `gemini` 실행 시 항상 에러를 반환하는 상황을 모사합니다.
2. `$ErrorActionPreference = "Stop"` 상태의 PowerShell 터미널에서 패치된 `Invoke-GeminiExtensionManage`을 실행합니다.
3. 스크립트가 튕기지 않고, 경고 및 우회 해결 명령어를 부드럽게 출력한 뒤 정상적으로 다음 스크립트 단계로 넘어가는지 확인합니다.

### 재발 방지
- **외부 샌드박스 표준화**: 향후 `template_integrator.ps1`에서 독자적인 외부 CLI 도구(`git`, `npm`, `gemini`, `codex`, `pi` 등)를 호출하는 모든 부서는 `cmd /c`와 `try-catch` 가드 패턴을 일관되게 활용하도록 코딩 규격에 반영합니다.
- **오류 격리 테스트**: 통합 패키지 배포 CI 단계에서 빈 환경 및 더미(오류 유발) CLI 가 설치된 가상 윈도우 환경 테스트를 추가 제안합니다.
