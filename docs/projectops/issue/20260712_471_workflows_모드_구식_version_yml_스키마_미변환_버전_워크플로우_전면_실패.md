# ❗[버그][통합마법사] workflows 모드 구식 version.yml 스키마 미변환으로 버전 워크플로우 전면 실패

> 라벨: 작업전
> 담당자: Cassiiopeia

🗒️ 설명
---

- 통합 마법사의 **workflows 모드**(대화형 메뉴 "워크플로우만" / 비대화형 `--mode workflows`)가 v4.1.0 이전 형식의 version.yml(단수 `project_type` 키)을 가진 레포에서 **모순된 중간 상태**를 만듭니다.
- workflows 모드는 단수 키를 명시적으로 거부하는 신형 `version_manager.py`(+`.sh` shim)를 복사하면서, 정작 version.yml의 단수 → 배열(`project_types`) 스키마 변환은 수행하지 않습니다 (deploy 블록만 append).
- 결과: 통합 직후부터 `version_manager`를 호출하는 모든 워크플로우(PROJECT-COMMON-VERSION-CONTROL, PROJECT-COMMON-RELEASE-CHANGELOG 등)가 버전 조회 단계에서 즉시 실패합니다.
- full 모드는 version.yml을 전체 재생성하므로 정상입니다. 이 갭은 #470 레거시 마이그레이션과 무관하게 **v4.1.0 SSOT 전환(단수 키 제거) 시점부터** 존재했으며, 구 template_integrator.sh 시절의 workflows 경로도 동일했습니다.

🔄 재현 방법
---

1. v4.1.0 이전 템플릿이 통합된 레포 준비 — version.yml에 `project_type: "spring"` 단수 키만 존재 (실측 레포: `Cassiiopeia/suh-project-utility`, 템플릿 v2.7.7 통합 상태)
2. `npx projectops --mode workflows --type spring --force` 실행 (또는 대화형 마법사에서 "워크플로우만" 선택)
3. 통합 완료 후 `python3 .github/scripts/version_manager.py get` 실행
4. 오류로 즉시 실패 확인 — 이 상태로 push 되면 버전 관련 워크플로우가 전부 실패

📸 참고 자료
---

통합 직후 실측 출력 (suh-project-utility, 2026-07-12):

```
❌ version.yml이 v4.1.0 이전 형식입니다 (project_type 단수 키만 존재).
❌ 전환 절차: project_type 라인을 삭제하고 project_types 배열로 교체하세요.
❌   예) project_type: "spring"  →  project_types: ["spring"]
```

- workflows 모드가 version.yml에 한 조치: `deploy:` 블록 append만 (스키마 변환 없음, `metadata.template.version`도 구버전 유지)
- 같은 레포에 `--mode full` 실행 시에는 `project_types: ["spring"]` 배열 + 신 옵션 축으로 정상 재생성됨 (대조 확인)

✅ 예상 동작
---

- workflows 모드가 구식 스키마(단수 `project_type`만 존재)를 감지하면, 아래 둘 중 하나로 동작해야 합니다:
  - (a) 최소 변환만 수행 — 단수 키를 `project_types` 배열로 교체하고 나머지는 보존 (workflows 모드의 "version.yml 생성 안 함" 원칙 유지)
  - (b) 변환 없이 진행이 불가능함을 안내하고 full 모드 실행을 유도 후 중단
- 어느 쪽이든 "신 스키마 요구 스크립트 + 구 스키마 version.yml" 조합의 깨진 상태로 완료되면 안 됩니다.

⚙️ 환경 정보
---

- **OS**: macOS (darwin 24.1.0) — OS 무관 (스키마 처리 로직 이슈)
- **버전**: projectops develop(4.2.8 이후) 로컬 실행으로 실측, v4.1.0 이후 전 버전 해당
- **관련 파일**: `src/commands/workflows.js`, `src/core/version-yml.js`, `.github/scripts/version_manager.py`

🙋‍♂️ 담당자
---

- **백엔드**: Cassiiopeia
