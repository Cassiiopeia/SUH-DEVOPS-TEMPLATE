🗒️ 설명
---

`template_integrator.ps1`(PowerShell 마법사)로 템플릿을 설치할 때, 배포 워크플로우의 `@wizard` 토큰 치환이 **전부 스킵**된다. 그 결과 `PROJECT-REACT-CICD.yaml` 등에 `__PROJECT_NAME__` 같은 placeholder가 미치환 상태로 남는다.

원인은 `template_integrator.ps1:2695`의 한 줄이다.

```powershell
foreach ($wf in (Get-ChildItem -Path $srcDir -Include '*.yaml','*.yml' -File -ErrorAction SilentlyContinue)) {
    ...
    Configure-WorkflowEnv -Type $Type -File $target
}
```

Windows PowerShell 5.1에서 `Get-ChildItem -Include`는 **경로 끝에 `\*`가 붙거나 `-Recurse`가 있어야만 동작**한다. 둘 다 없으면 **에러 없이 0개를 반환**한다(PowerShell의 알려진 함정). 따라서 위 `foreach`가 한 번도 돌지 않고, env 치환 엔진(`Configure-WorkflowEnv`)이 **단 한 번도 호출되지 않는다**.

`Configure-WorkflowEnv` 호출부는 코드 전체에서 이 2695줄 **단 한 곳**뿐이라, 이 한 줄이 죽으면 `.ps1`의 워크플로우 토큰 치환 기능 전체가 무력화된다.

영향:
- `__PROJECT_NAME__` 미치환 (레포명으로 자동 치환되어야 함)
- `# @wizard paths-anchor` 모노레포 paths 필터 주입 안 됨
- 잔류 토큰 경고 미출력
- "배포 워크플로우 환경설정을 채웁니다" 질문 자체가 안 뜸

`.sh`(`configure_workflow_env`)는 glob `"$_src_dir"/*.{yaml,yml}`를 써서 정상 동작한다. **이 버그는 `.ps1` 전용**이다.

🔄 재현 방법
---

1. Windows PowerShell에서 `template_integrator.ps1`을 실행해 react(또는 next/spring/python/flutter) 타입으로 전체 설치
2. 설치 완료 후 `.github/workflows/PROJECT-REACT-CICD.yaml` 확인
3. `env:` 블록의 `PROJECT_NAME: "__PROJECT_NAME__"`가 그대로 남아 있음 (레포명으로 치환되지 않음)
4. 설치 로그에 "배포 워크플로우 환경설정을 채웁니다" 단계가 전혀 출력되지 않음

📸 참고 자료
---

실측 재현 (Windows PowerShell 5.1):

| 방식 | 반환 개수 |
|------|-----------|
| 현재 `.ps1` 코드 (`-Include` only) | **0개** ❌ |
| `-Filter '*.yaml'` + `-Filter '*.yml'` 누적 | 2개 ✅ |
| 경로 끝에 `\*` 추가 + `-Include` | 2개 ✅ |

`@wizard ask` 마커 존재 위치 (영향받는 워크플로우):
`PROJECT-REACT-CICD.yaml`, `PROJECT-REACT-CI.yaml`, `PROJECT-NEXT-CICD.yaml`, `PROJECT-NEXT-CI.yaml`, `PROJECT-SPRING-*`, `PROJECT-PYTHON-*`, `PROJECT-FLUTTER-ANDROID-*` 등.

✅ 예상 동작
---

- `.ps1` 설치 시에도 `Configure-WorkflowEnv`가 각 워크플로우에 대해 호출되어야 함
- `__PROJECT_NAME__`가 레포명으로 자동 치환되어야 함
- 잔류 토큰 경고 / paths 앵커 주입 등 `.sh`와 동일하게 동작해야 함
- **수정안은 Windows PowerShell 5.1과 macOS PowerShell Core 양쪽에서 모두 동작해야 함**

해결 방향: 2695줄을 `.sh` 및 코드 내 다른 곳(2544~2547)에서 이미 검증된 `-Filter` 누적 방식으로 교체.

```powershell
$wfFiles = @()
$wfFiles += Get-ChildItem -Path $srcDir -Filter '*.yaml' -File -ErrorAction SilentlyContinue
$wfFiles += Get-ChildItem -Path $srcDir -Filter '*.yml'  -File -ErrorAction SilentlyContinue
foreach ($wf in $wfFiles) { ... }
```

⚙️ 환경 정보
---

- **OS**: Windows 11 (PowerShell 5.1), macOS (PowerShell Core) 공통 대응 필요
- **버전**: SUH-DEVOPS-TEMPLATE v3.0.142
- **파일**: `template_integrator.ps1:2695`
