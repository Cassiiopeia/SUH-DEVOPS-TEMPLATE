# 기존 쉘 스크립트(.sh)의 Python 마이그레이션 — 설계

> **관련 이슈**: [#448](https://github.com/Cassiiopeia/projectops/issues/448)

## 결정 사항

**로직을 Python(stdlib 전용)으로 옮기고, 기존 `.sh` 진입점은 "python 위임 shim"으로 유지한다.**

- 워크플로우 17개+가 `./.github/scripts/version_manager.sh get` 형태로 호출 중 — 성공 이력이 있는 워크플로우의 실행 로직은 건드리지 않는다(CLAUDE.md 원칙). shim이 호출 계약을 100% 보존하므로 워크플로우 무수정.
- Windows(PowerShell/CMD)에서는 `python .github/scripts/version_manager.py get`을 직접 실행 — 이슈의 크로스플랫폼 목표 달성.
- **yq/jq 의존 제거**가 실질 최대 이득: Windows에 yq/jq가 없어 로컬 실행이 사실상 불가였다. Python 포팅은 stdlib(json/re/pathlib)만 사용.

### 대상별 처리

| 스크립트 | 처리 | 근거 |
|---|------|------|
| `version_manager.sh` (790줄) | **P1: `version_manager.py` 전체 포팅 + shim** ✅ 완료 | 모든 워크플로우·릴리스 파이프라인의 핵심. yq/jq 의존 제거 |
| `truncate_release_notes.sh` (155줄) | **P2: `.py` 포팅 + shim** ✅ 완료 | 이미 Python heredoc 구조였음 — 본문을 파일로 추출 |
| `template_initializer.sh` (733줄) | **후속 분리** | GitHub Actions(ubuntu) 전용 1회 실행 — bash 상시 가용이라 크로스플랫폼 이득이 없고, 저장소 생성 파이프라인 리스크 대비 효용 낮음 |
| `template_integrator.sh` (5,720줄) | **포팅하지 않음** | v4.0.0에서 `npx projectops`(Node CLI)가 마법사를 전면 대체 — Python 재포팅은 3중 유지보수를 4중으로 늘릴 뿐. 이슈 등록 시점(전환 직전)과 상황이 바뀜 |
| `.github/util/**/*.sh` (12개) | **후속 분리** | Flutter 로컬 대화형 마법사 — 사용 빈도·리스크 낮음, 별도 이슈로 |

### 구현 완료 내역 (P1·P2)

- `.github/scripts/version_manager.py` 신설 — get/get-code/increment/increment-code/set/sync/validate 전체, v4.1.0 SSOT 시맨틱, project_paths 멀티타입, 라인 단위 편집으로 주석 보존, stdlib 전용
- `.github/scripts/version_manager.sh` → 위임 shim (계약 보존: stdout 마지막 줄 = 결과값)
- `.github/scripts/truncate_release_notes.py` 신설 + `.sh` shim화 (항상 exit 0 계약 유지)
- **복사 목록 갱신 (필수)**: integrator `.sh`/`.ps1`/`src/core/copy/simple.js`에 `.py` 2종 + `truncate_release_notes.*` 추가 — shim만 복사되면 user 프로젝트에서 깨지므로 한 쌍으로 복사
- `test_version_manager_paths.sh`를 yq/jq 무의존으로 재작성 + 케이스 확장(28 assert): increment stdout 계약·set·높은버전 동기화 — Windows Git Bash 실측 28/28 PASS

### shim 규약

```bash
#!/bin/bash
# v4.2 — 로직은 version_manager.py로 이전. 이 파일은 호출 호환용 위임 shim.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY=$(command -v python3 || command -v python) || { echo "❌ Python이 필요합니다" >&2; exit 1; }
exec "$PY" "$SCRIPT_DIR/version_manager.py" "$@"
```

- stdout(결과값)/stderr(로그)/종료코드 계약을 .sh와 동일하게 유지 — 워크플로우의 `| tail -n 1` 파싱 무손상.
- macOS 기본 python3 존재, ubuntu-latest 존재, Windows Git Bash는 python. (bash 3.2 호환 필요 없어짐 — shim 3줄뿐)

### version_manager.py 동작 계약 (.sh 등가)

- 커맨드: `get`(sync 포함) / `get-code` / `increment`(patch+code) / `increment-code` / `set X.Y.Z` / `sync` / `validate`
- version.yml 편집은 **라인 단위 정규식 치환**으로 주석·서식 보존 (yq 재직렬화보다 오히려 안전)
- v4.1.0 SSOT 시맨틱 유지: `project_types` 배열만 소스, legacy 단수-only는 명시적 실패, 잔존 단수 키는 경고 후 무시
- 타입별 파일 갱신: spring(build.gradle sed 등가), flutter(`x.y.z+code`), react/node(package.json — json 모듈), react-native(plist/gradle), expo(app.json), python(pyproject.toml), basic(version.yml만)
- `project_paths` 멀티타입 순회(sync_for_type), 높은 버전 우선 동기화, metadata.last_updated(_by) 존재 시만 갱신
- 로그는 stderr(이모지 동일), 결과값만 stdout

### 검증
- 기존 `test_version_manager_paths.sh` 케이스가 shim 경유로 .py를 그대로 검증 (yq/jq 없이도 동작하도록 스킵 조건 제거)
- `python -m py_compile` + 로컬 실측 (Windows Git Bash)
