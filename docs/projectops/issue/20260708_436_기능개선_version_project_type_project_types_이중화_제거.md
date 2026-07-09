📝 현재 문제점
---

`version.yml`에 프로젝트 타입이 **두 개의 키로 이중 저장**되고 있어 single source of truth(SSOT)를 위반한다.

```yaml
project_types: ["basic"]   # 멀티타입 배열 (실제 소스)
project_type: "basic"      # project_types[0] 미러 — "직접 수정 금지"
```

- 원래 단수 `project_type`만 있었으나, 멀티타입 지원을 추가하면서 복수 `project_types` 배열을 도입했다.
- 하위호환을 위해 단수 키를 남겨두면서 **같은 정보가 두 곳에 중복 저장**되는 구조가 되었다.
- `version_manager.sh`의 `sync_project_type_field()`가 매번 실행되어 단수 키를 배열 첫 항목으로 강제 동기화한다. 즉 이중화를 코드로 계속 봉합하고 있는 상태다.
- 데이터가 두 벌이면 사용자 수동 편집·릴리스 과정에서 언젠가 어긋난다. 실제로 혼란의 원인이 되고 있다.

관련 파일:
- `version.yml` (스키마)
- `.github/scripts/version_manager.sh` (`sync_project_type_field`, `parse_project_types`, `read_version_config` 등)
- `src/core/version-yml.js`, `template_integrator.sh`, `template_integrator.ps1` (3중 구현)
- 워크플로우 YAML, 테스트, 문서 — `project_type`/`project_types` 참조가 총 21개 파일에 분산

🛠️ 해결 방안 / 제안 기능
---

**`project_types` 배열을 유일한 소스로 통일하고, 단수 `project_type` 키를 완전히 제거한다.**

- `version.yml`에서 `project_type` 단수 키 삭제 → `project_types` 배열만 남긴다.
- `sync_project_type_field()` 미러링 로직 제거.
- "primary 타입"이 필요한 곳(버전 파일 결정 등)은 별도 키 없이 `project_types[0]`으로 읽는다.
- `.sh` / `.ps1` / `.js` 3중 구현 및 워크플로우·테스트·문서에서 단수 참조를 모두 배열 기반으로 정리한다.

**하위호환을 지원하지 않는다.** 억지 하위호환이 문제의 근본 원인이었으므로 깔끔히 끊는다.

- **v4.0.0 메이저 버전**으로 올리며 breaking change로 처리한다.
- `.github/config/breaking-changes.json`에 `4.0.0` 항목을 등록한다 (severity: critical). 기존 프로젝트는 `version.yml`에서 `project_type` 단수 키를 제거하고 `project_types` 배열만 남기도록 전환 절차를 안내한다.

⚙️ 작업 내용
---

- `version.yml` 스키마에서 단수 키 제거 + 주석 갱신
- `version_manager.sh`: `sync_project_type_field` 제거, primary = `project_types[0]` 참조로 변경
- `template_integrator.sh` / `.ps1` / `src/core/version-yml.js`의 단수 키 읽기·쓰기 제거
- 워크플로우 YAML의 `project_type` 참조 정리
- 테스트(`test/version-yml.test.js`, `test_version_manager_paths.sh`) 갱신
- `breaking-changes.json`에 4.0.0 등록 + 전환 절차 문서화
- macOS bash 3.2 + BSD 도구 호환 검증 (CLAUDE.md 규칙)

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
