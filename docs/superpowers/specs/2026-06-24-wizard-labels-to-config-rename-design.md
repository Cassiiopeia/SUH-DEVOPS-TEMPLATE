# wizard/labels.yml → config/wizard-prompts.yml 이동·개명 설계

- 날짜: 2026-06-24
- 대상: `template_integrator.sh`, `template_integrator.ps1`, `.github/wizard/labels.yml`
- 적용 범위: **템플릿 원본(suh-github-template)만**. 사용자 프로젝트(passQL 등)는 건드리지 않음 — 다음 integrator 업데이트 때 자연 반영. 과거 기록물(specs/plans/report/issue)도 그대로 둠.

---

## 1. 배경 / 문제

`.github/wizard/labels.yml`은 **이름이 함정**이다. "labels"라고 되어 있지만 GitHub 이슈 라벨과 전혀 무관하고, 실제 내용은 다음 둘이다:

1. `@wizard ask` 마커의 **env 질문 문구·도움말(help)·예시(example) 사전** (`PROJECT_NAME`, `JAVA_VERSION` 등 KEY별 블록)
2. `_workflow_names:` — 워크플로우 파일명 → 사람이 읽는 짧은 이름 매핑 (env 질문의 `[사용처]` 표시에 사용)

문제점:
- **위치 분산**: `.github/config/`에 `breaking-changes.json`·`issue-labels.yml` 같은 설정이 모여 있는데, 같은 성격의 이 파일만 `.github/wizard/`에 따로 떨어져 있다.
- **이름 오해**: "labels.yml"이라는 이름이 GitHub 라벨 파일로 오해를 부른다. 실제 GitHub 라벨 파일은 `.github/config/issue-labels.yml`이다.

> ⚠️ 그래서 단순히 `config/`로 옮기면서 `labels.yml` 이름을 유지하면 `config/issue-labels.yml`과 "labels" 두 개가 한 폴더에 섞여 **더** 헷갈린다. 이름도 함께 바꾼다.

## 2. 결정 사항 (사용자 확정)

| 항목 | 결정 |
|------|------|
| 이동 위치 | `.github/config/` |
| 새 이름 | `wizard-prompts.yml` |
| 최종 경로 | **`.github/config/wizard-prompts.yml`** |
| 적용 범위 | 템플릿 원본만 |
| 코드 처리 | 전용 복사 함수(`copy_wizard_labels`/`Copy-WizardLabels`) **삭제 통합** (보수적 경로변경 아님) |
| 문서 | 과거 기록물 유지, 본 spec/리포트에 이동 사실 기록 |

```
.github/config/
  ├─ breaking-changes.json
  ├─ issue-labels.yml        ← GitHub 이슈 라벨 (그대로)
  └─ wizard-prompts.yml      ← (신규) 마법사 env 질문 문구  ← wizard/labels.yml에서 이동
```

## 3. 파일 이동

```
이동: .github/wizard/labels.yml  →  .github/config/wizard-prompts.yml   (내용 무변경, git mv로 히스토리 보존)
삭제: .github/wizard/            (labels.yml 하나뿐이라 이동 후 빈 폴더 → 제거)
```

`git mv "d:/0-suh/project/suh-github-template/.github/wizard/labels.yml" "d:/0-suh/project/suh-github-template/.github/config/wizard-prompts.yml"`
→ 빈 `.github/wizard/` 디렉터리 제거.

파일 **내용은 1바이트도 바꾸지 않는다** (KEY 블록·`_workflow_names:`·주석 전부 그대로).

## 4. 코드 변경 — `template_integrator.sh` / `.ps1` (1:1 동등 유지)

### 4-1. 핵심 통찰: config 복사 함수가 이미 존재

- `.sh` `copy_config_folder()` (3656~3680), `.ps1` `Copy-ConfigFolder` (3256~3282)가 `$TEMP_DIR/.github/config/*`를 **통째로 복사**한다.
- 파일이 `config/`로 가면 → wizard-prompts.yml은 이 함수로 **자동 복사**된다.
- 따라서 별도 `wizard/` 복사 함수는 **죽은 코드**가 되므로 삭제한다.

### 4-2. 순서 의존성 (TEMP_DIR 폴백은 유지)

주석(`.sh` 2802~2806 / `.ps1` 2403~2407)에 명시된 사실: 신규 통합(`full`/`workflows`)에서 복사 함수는 `configure_workflow_env`(env 질문 시점)보다 **늦게** 실행된다. 그래서 env 질문 시점엔 작업 디렉터리(dst)에 파일이 아직 없고, **다운로드 원본(`$TEMP_DIR`)을 가리키는 폴백 경로**가 필요하다.

→ 함수를 삭제해도 이 폴백은 **여전히 필요**하다 (`copy_config_folder`도 env 질문보다 늦게 돈다). **폴백 경로만 `config/wizard-prompts.yml`로 바꾼다.** 폴백 로직 자체는 제거하지 않는다.

### 4-3. 변경 지점 표

#### `template_integrator.sh`

| 위치 | 현재 | 변경 |
|------|------|------|
| 2801 | `LABELS_FILE="${LABELS_FILE:-.github/wizard/labels.yml}"` | `…:-.github/config/wizard-prompts.yml}` |
| 2804 (주석) | `…$TEMP_DIR/.github/wizard/labels.yml — …copy_wizard_labels가` | `…/config/wizard-prompts.yml — …copy_config_folder가` |
| 2809 | `local _src="$TEMP_DIR/.github/wizard/labels.yml"` | `…/.github/config/wizard-prompts.yml"` |
| 2814 (주석) | `labels.yml의 _workflow_names:` | `wizard-prompts.yml의 _workflow_names:` |
| 2817 (주석) | `호출마다 labels.yml을 풀스캔하면` | `…wizard-prompts.yml을…` |
| 3682~3696 | `copy_wizard_labels()` 함수 전체 | **함수 삭제** |
| 4332 | `copy_wizard_labels   # …(labels.yml)` | **행 삭제** |
| 4353 | `copy_wizard_labels   # …(labels.yml)` | **행 삭제** |

#### `template_integrator.ps1`

| 위치 | 현재 | 변경 |
|------|------|------|
| 2404 (주석) | `…(LabelsFile 또는 기본 .github/wizard/labels.yml)` | `…/config/wizard-prompts.yml)` |
| 2405 (주석) | `…$TEMP_DIR\.github\wizard\labels.yml — …Copy-WizardLabels가` | `…\config\wizard-prompts.yml — …Copy-ConfigFolder가` |
| 2409 | `$dst = if(...){...}else{'.github/wizard/labels.yml'}` | `…else{'.github/config/wizard-prompts.yml'}` |
| 2411 | `$src = Join-Path $TEMP_DIR ".github\wizard\labels.yml"` | `… ".github\config\wizard-prompts.yml"` |
| 3284~3303 | `Copy-WizardLabels` 함수 전체 (+ 위 주석 블록) | **함수 삭제** |
| 3899 | `Copy-WizardLabels` | **행 삭제** |
| 3922 | `Copy-WizardLabels` | **행 삭제** |

> `LABELS_FILE` / `$script:LabelsFile` 변수명 자체는 유지한다(파일명만 wizard-prompts로 바뀜). 변수명까지 바꾸면 diff·env override 인터페이스가 불필요하게 커진다 — YAGNI.

> ⚠️ 행 번호는 작성 시점 기준. 위에서부터 삭제하면 아래 번호가 밀리므로, **편집은 아래(큰 번호)에서 위(작은 번호) 순서로** 하거나 고유 문자열 매칭으로 한다.

## 5. CLAUDE.md cleanup / 제외 목록 — 변경 불필요 (확인됨)

`wizard/labels.yml`은 **사용자 프로젝트로 복사되는 공통 자산**이라 원래부터:
- `template_initializer.sh`의 `cleanup_template_files()`에 없음 (삭제 대상 아님)
- `template_integrator.sh`의 `plugin_items_to_remove`에 없음 (복사 제외 대상 아님)
- `.ps1`의 `$pluginItemsToRemove`에 없음

→ `config/`로 옮겨도 여전히 공통 자산이고, `config/` 폴더는 이미 복사·유지 대상이다. **세 목록 모두 손댈 필요 없다.** (CLAUDE.md "루트 마켓플레이스/템플릿 전용 파일 추가" 절차는 이번 변경과 무관 — 새 루트 파일을 추가하는 게 아니라 기존 공통 자산을 config 하위로 옮기는 것이기 때문.)

`PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml`도 무관(버전 필드 있는 매니페스트 아님).

## 6. 검증 (CLAUDE.md 규정 방식)

1. **문법**
   - `bash -n template_integrator.sh`
   - Docker PowerShell 파서: `Parser::ParseFile` → `PS1_PARSE_OK`
   - `bash -n .github/scripts/template_initializer.sh` (cleanup 미수정 확인 차원, 변경 없어도 1회)
2. **동작 (실측)**
   - `.sh`: `expect` 하네스로 마법사 env 질문 화면에서 `config/wizard-prompts.yml`의 label/help/example가 **정상 출력**되는지(빈값/KEY명 폴백이 아닌지) 확인. TEMP_DIR 폴백 경로도 `config/`를 가리키는지 검증.
   - `.ps1`: 함수 본문 인라인 주입(QEMU 크래시 회피)으로 `Get-WfLabelsPath`/`Get-WfWorkflowName`이 새 경로에서 사람말 반환하는지 확인.
3. **무손상 자가검증**
   - `git diff template_integrator.sh template_integrator.ps1`로 `run:`/실행 로직 외 변경 없음 확인.
   - 삭제한 두 함수 외에 `copy_config_folder`/`Copy-ConfigFolder` 본문은 무변경인지 확인.
4. **임시 하네스 정리** (`/tmp/*.sh`, `/tmp/*.ps1`, `.exp`).

## 7. 영향 받지 않는 것 (명시)

- `.github/config/issue-labels.yml` — GitHub 라벨, 무관·무변경.
- `PROJECT-COMMON-SYNC-ISSUE-LABELS.yaml` 등 라벨 동기화 워크플로우 — `issue-labels.yml`을 보므로 무관.
- passQL 등 사용자 프로젝트 — 이번 작업 범위 밖.
- 과거 specs/plans/report/issue 문서 — 히스토리 박제, 유지.

## 8. 마이그레이션 메모 (범위 외, 기록만)

이전 버전 integrator로 통합한 기존 사용자 프로젝트가 새 버전으로 업데이트하면:
- 새 `config/wizard-prompts.yml`은 `copy_config_folder`로 정상 복사된다.
- 단, 옛 `.github/wizard/labels.yml`은 **삭제되지 않고 고아로 남는다**(integrator는 파일을 지우지 않으므로).
- 영향: 무해(死파일). 마법사는 새 경로를 우선 조회하므로 동작에 지장 없음. dst에 새 파일이 있으면 그걸 읽고, 옛 wizard/labels.yml은 더 이상 참조되지 않는다.
- 본 작업에서 옛 파일 자동 정리는 **하지 않는다**(YAGNI — 동작 무해, 정리 로직 추가는 별도 이슈로 충분). 필요 시 후속 작업으로 분리.
