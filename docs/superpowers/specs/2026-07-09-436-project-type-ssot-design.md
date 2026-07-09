# version.yml project_type/project_types 이중화 제거 (SSOT) — 설계

> **관련 이슈**: [#436](https://github.com/Cassiiopeia/projectops/issues/436)
> **Breaking**: v4.1.0 (이슈에는 v4.0.0으로 적혀 있었으나 레포가 이미 v4.0.4까지 릴리스되어 **v4.1.0으로 조정**)
> **함께 릴리스**: [#437 next 타입 제거]와 같은 v4.1.0 메이저로 묶음 (이슈 본문 명시)

---

## 결정 사항

**`project_types` 배열이 유일한 소스. 단수 `project_type` 키는 완전히 제거하며 하위호환을 두지 않는다.**

### 스키마

```yaml
# v4.1.0 이후
project_types: ["spring", "react"]   # 첫 항목이 primary
# project_type: (삭제 — 더 이상 쓰지도 읽지도 않음)
```

### 동작 규칙 (version_manager.sh `read_version_config`)

| version.yml 상태 | 동작 |
|---|---|
| `project_types` 배열 있음 | primary = `project_types[0]` — 정상 |
| 배열 있음 + 단수 키 잔존 | 단수 키 **무시** + `log_warning`으로 제거 안내 (에러 아님 — 기존 프로젝트의 흔한 상태) |
| 배열 없음 + 단수 키만 있음 (legacy) | **hard error** + v4.1.0 전환 절차 안내 (조용한 오작동 방지 — 배포 파이프라인이 basic으로 오판하고 버전 동기화를 건너뛰는 사고 차단) |
| 둘 다 없음 | primary = `basic` (bare 파일 허용 — 기존 기본값 유지) |

`sync_project_type_field()` 미러링 함수는 삭제.

## 변경 지점 (전수 조사 결과)

### 코드 — 단수 키 읽기·쓰기 제거
1. **`version.yml`** — 단수 키 라인 삭제, 헤더 주석 갱신, `version: "4.1.0"` 확정 (bf571ee 선례)
2. **`.github/scripts/version_manager.sh`** — `sync_project_type_field` 삭제, `read_version_config` 위 표대로 재작성
3. **`template_integrator.sh`** — 생성 heredoc에서 단수 라인 제거(L2338), 기존 파일 읽기의 단수 폴백 2층 제거(L1048, L1059), 헤더 주석 갱신 (L923 `detect_project_type` 등 로컬 변수/함수명은 키와 무관 — 유지)
4. **`template_integrator.ps1`** — 동일 (읽기 폴백 L895~900, 쓰기 L1958, 주석)
5. **`src/core/version-yml.js`** — serializer 단수 라인 제거(L141), 헤더 주석 갱신 (parser는 이미 배열 전용)
6. **`.github/scripts/template_initializer.sh`** — 생성 heredoc 단수 라인 제거(L272), 안내 문구 project_types로 (L668)
7. **워크플로우 4파일** (AUTO-CHANGELOG-CONTROL·VERSION-CONTROL × 루트/common 복사본) — version.yml 파싱을 배열 전용으로: `PROJECT_TYPES` 배열 csv 파싱 → `PROJECT_TYPE`(primary) = 첫 항목. 단수 키 grep 제거. **출력 이름(`project_type` output)은 유지** (내부 배관 — primary 의미로 계속 사용)

### 유지 (의도적으로 변경하지 않음)
- **`.github/scripts/changelog_manager.py`** — env 기반(PROJECT_TYPE/PROJECT_TYPES)이라 무수정. CHANGELOG.json의 `project_type`(primary) 필드는 **생성 산출물 스키마**로 유지 (소비자 호환)
- **`skills/changelog-deploy/scripts/changelog_cli.py`의 단수 폴백** — 이 스킬은 v3/v4 템플릿을 쓰는 **타 레포**(RomRom 등)에서도 실행되는 크로스버전 도구라 legacy 읽기 폴백 유지
- **Flutter 워크플로우의 `project_type` output** — `env.PROJECT_TYPE`(워크플로우 내 하드코딩 "flutter") 배관이지 version.yml 단수 키가 아님
- 과거 이력 문서(CHANGELOG.json 히스토리, 옛 스펙/리포트/이슈 md)

### 테스트
- `test/version-yml.test.js` — `project_type:` 단수 라인이 **없음**을 assert로 반전
- `test/regression-fixes.test.js`, `test/options-ask.test.js` — fixture에서 단수 라인 제거
- `.github/scripts/test/test_version_manager_paths.sh` — fixture 정리 + **legacy 단수-only → 에러** 케이스 추가

### breaking-changes.json
`"4.1.0"` critical 등록. 전환 절차: version.yml에서 `project_type` 단수 키 삭제, `project_types: ["타입"]` 배열만 유지. (#437 next 제거 내용은 별도 항목으로 같은 4.1.0에 추가 예정)

### 문서
CLAUDE.md, CONTRIBUTING.md, docs/VERSION-CONTROL.md, docs/TEMPLATE-INTEGRATOR.md, .github/scripts/VERSION_MANAGER_README.md — 단수 키 언급 제거·배열 기준으로 수정

## 검증
- `bash -n` (version_manager.sh, integrator.sh, initializer.sh) + PowerShell `Parser::ParseFile`
- `node --test test/` 전체 green
- `test_version_manager_paths.sh` 실행 (Git Bash)
- 워크플로우 YAML은 실행 로직 diff 최소화 원칙 — 기존 success 이력이 있는 파일이므로 파싱 블록만 정밀 수정
