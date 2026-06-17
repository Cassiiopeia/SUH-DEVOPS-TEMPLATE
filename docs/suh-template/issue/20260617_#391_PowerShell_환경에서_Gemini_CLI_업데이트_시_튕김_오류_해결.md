🗒️ 설명
---
PowerShell 환경에서 `template_integrator.ps1`을 실행할 때, Gemini CLI 혹은 Codex CLI 등의 외부 확장 설치/업데이트 과정에서 비정상적인 타사 에이전트로 인해 에러 출력(stderr)이 발생하면 `$ErrorActionPreference = "Stop"` 규칙에 의해 전체 통합 프로세스가 비정상적으로 강제 종료(튕김)되는 문제가 발생합니다.

- 외부 에러(NativeCommandError) 발생 시 PowerShell이 이를 가로채어 스크립트 실행 전체를 치명적으로 끊어버리는 현상을 방지해야 합니다.
- 또한, 특정 확장의 이름을 하드코딩해서 원인을 섣불리 단정 짓지 않고, 예외가 나더라도 단순하고 범용적인 알림을 출력한 후 우회하여 완료될 수 있도록 안전한 샌드박싱(cmd /c 호출 및 try-catch 격리) 처리가 필요합니다.

🔄 재현 방법
---
1. 로컬 `gemini` CLI 확장 설정 디렉토리에 규격에 맞지 않거나 손상된 확장 파일(예: `cavecrew-builder.md`)을 인위적으로 배치합니다.
2. PowerShell에서 `template_integrator.ps1`을 실행하여 "AI 스킬 설치 / 업데이트" 기능을 호출합니다.
3. `gemini extensions update`가 호출되면서 유효성 검사 실패 예외가 발생하고 stderr가 흐릅니다.
4. PowerShell 터미널 전체가 `NativeCommandError` 메시지와 함께 튕기며 중단됩니다.

📸 참고 자료
---
```
node.exe : [ExtensionManager] Error loading agent from caveman: Failed to load agent from C:\Users\USER\.gemini\extensions\cavecrew-builder.md: Validation failed: Agent Definition:
위치 C:\Users\USER\AppData\Roaming\npm\gemini.ps1:24 문자:5
+     & "node$exe"  "$basedir/node_modules/@google/gemini-cli/bundle/ge ...
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: ([ExtensionManag...ent Definition::String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
```

✅ 예상 동작
---
- 외부 에러가 발생하더라도 스크립트 본체가 죽지 않습니다.
- 특정 에이전트('caveman' 등)에 한정된 복잡하고 불안한 메시지를 노출하지 않고, "Gemini CLI extension 관리 중 오류가 발생했습니다." 수준의 깔끔하고 범용적인 알림과 함께 다음 단계로 우회 완료됩니다.

⚙️ 환경 정보
---
- **OS**: Windows (PowerShell)
- **브라우저**: N/A
- **기기**: PC

🙋‍♂️ 담당자
---
- **프론트엔드**: Cassiiopeia
