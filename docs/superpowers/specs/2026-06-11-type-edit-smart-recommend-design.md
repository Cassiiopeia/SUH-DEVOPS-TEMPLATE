# 타입 수정 메뉴 스마트 추천 + path 자동 연결 설계

> 작성일: 2026-06-11
> 대상: `template_integrator.sh`, `template_integrator.ps1`
> 관련: [[2026-06-11-monorepo-project-paths-design]]

## 1. 문제 정의

`template_integrator`를 이미 init된 레포(예: passQL)에서 다시 실행하면:

1. 초기 분석 결과는 `version.yml`의 값(예: `basic`)을 그대로 보여준다 — **이건 정답.**
2. 사용자가 `E`(수정)로 타입을 바꾸려고 타입 선택 메뉴에 들어가면, 메뉴는 **레포를 들여다보지 않고** 빈 체크박스 + 기존값만 체크된 채로 던진다. "이 레포에 뭐가 있으니 이걸 추천한다"는 안내가 없다.
3. 마커 파일(`pubspec.yaml`·`package.json`·`build.gradle`·`pyproject.toml` 등)이 없는 레포(passQL)는 무조건 `basic`으로만 떨어져 추천이 불가능하다.
4. 타입을 바꿔도 그 타입의 `project_paths`(모노레포 경로) 감지가 한참 뒤(`resolve_project_paths`, sh 3059줄)에야 돌아 **"타입 선택 → path 확정"이 한 흐름으로 이어지지 않는다.**

핵심: **현재 상태 표시는 그대로 두되, 수정 메뉴에 들어가면 능동적으로 추천하고 path까지 자연스럽게 자동 연결한다.**

## 2. 설계 원칙

- **append-only 로그 흐름**: 이 스크립트는 화면을 다시 그리지 않고 위→아래로 로그가 쌓이는 방식이다. 모든 신규 출력은 "발견 → 판단 → 자동 확정/질문" 순으로 한 줄씩 누적되게 표현한다. 인터랙티브 재draw 없음.
- **사용자 친화 + 최대 자동화**: 자동으로 확정할 수 있는 건 질문 없이 확정하고 그 근거를 로그로 남긴다. 사용자에게는 모호할 때만 묻는다.
- **현재 상태 존중**: `version.yml`에 `basic`이면 basic 표시가 정답. 스캔 추천은 **안내만** 하고 강제 preselect하지 않는다 (사용자가 의도적으로 basic을 골랐을 수 있음).
- **양쪽 스크립트 대칭**: 모든 변경을 `.sh`·`.ps1`에 동일하게 적용.
- **기존 로직 재사용**: path를 잡는 `resolve_project_paths`(타입별 순차 질문)는 이미 멀티 타입을 잘 처리한다. 새로 만들지 않고 호출 시점만 앞으로 당긴다.

## 3. 변경 항목

### A. 타입 선택 메뉴에 추천 표시

`show_project_type_menu`(sh) / `Show-ProjectTypeMenu`(ps1) 진입 직후, 메뉴 출력 **직전**에 레포 스캔 결과를 로그로 쌓는다:

```
🔍 이 레포를 살펴봤습니다:
   • pubspec.yaml 발견 (app/)     → flutter 추천 (자동 선택됨)
   • .py 파일 12개 발견            → python 가능성 (직접 골라주세요)
   • 현재 version.yml 값: basic
```

- **마커가 잡힌 타입**: `detect_project_types` 결과를 그대로 추천으로 표시하고 메뉴 preselect에 포함(⭐ 자동 선택).
- **스캔 추천(마커 없음)**: §B 결과를 "가능성"으로 **안내만** 한다. preselect는 기존값(basic) 유지.
- **아무것도 못 찾음**: `"마커 파일을 찾지 못했습니다 — 직접 선택하세요"` 한 줄.

### B. 마커 없을 때 확장자·디렉터리 스캔 추천 (신규 함수)

`suggest_types_by_scan`(sh) / `Get-SuggestedTypesByScan`(ps1) 신규 추가.

**동작 조건**: 마커 기반 감지가 `basic`만 반환했을 때만 실행.

**스캔 방법**: 레포를 maxdepth 3로 훑어(§ 잡음 폴더 제외 동일 적용) 확장자·특징 파일 빈도를 센다.

| 발견 | 추천 타입 |
|---|---|
| `.dart` ≥ 1 | flutter |
| `.java` / `.kt` / `.gradle` ≥ 3 | spring |
| `.tsx` / `.jsx` ≥ 3 | react |
| `.py` ≥ 3 | python |
| `.ts` / `.js` ≥ 3 (위 추천 없을 때만) | node |

- 임계치 미만이면 추천하지 않는다.
- 출력은 csv(예: `python,node`)이며 **추천일 뿐 강제 아님** — preselect하지 않는다.
- 잡음 폴더 제외 regex는 기존 `PathExcludeRegex`(`node_modules|.git|build|dist|.dart_tool|android|ios|.gradle|venv|.venv|__pycache__`)를 재사용.

### C. 타입 수정 직후 path 자동 연결

`handle_project_edit_menu`의 `type` 케이스(sh 1516~1529) / ps1 대응에서:

```
1. show_project_type_menu 로 새 타입 csv 확정
2. PROJECT_TYPES / PROJECT_TYPE 갱신
3. ★ 타입이 실제로 바뀌었으면:
     - PROJECT_PATHS_CSV 초기화 (새 타입 기준으로 다시 잡도록)
     - resolve_project_paths 즉시 호출
4. 확인 화면으로 복귀 → 타입 + 경로가 함께 로그에 남아 있음
```

안전장치:
- **basic만 선택**: `resolve_project_paths`는 basic을 `_targets`에서 제외하므로 즉시 `return` — passQL이 basic 유지 시 path 질문이 뜨지 않는다.
- **맨 끝 `resolve_project_paths`(sh 3059)는 유지**. 단 이미 `PROJECT_PATHS_CSV`가 채워져 있으면 §D 루프가 각 타입을 "기존값 유지/루트 자동확정"으로 빠르게 통과하므로 재질문 부담이 없다. (CLI 모드·수정 안 한 경로에서도 정상 동작 유지)
- 타입이 안 바뀌었으면(같은 csv) path 재감지 스킵.

### D. 멀티 path 진행표시

`resolve_project_paths`의 타입별 루프(`for _t in "${_targets[@]}"`)에 `[현재/전체]` 카운터를 붙인다 (basic 제외한 `_targets` 개수 기준):

```
[1/3] 🔍 spring  : 후보 2개 발견 ...
[2/3] 🔍 flutter : app/pubspec.yaml 발견 → app 으로 설정할까요? (Y/N)
[3/3] 🔍 python  : 후보 없음 — 상대경로 입력 ...
```

후보가 1개면 질문 없이 자동 확정하고 로그만 남긴다(최대 자동화). 여러 개·없음일 때만 묻는다 — 이는 기존 동작을 유지하면서 카운터만 추가.

### E. 불필요 문구 정리

- `"프로젝트 타입 자동 감지 중... (멀티 지원)"` → `"프로젝트 타입 자동 감지 중..."` (sh `detect_project_types` 913 / ps1 655)
- `"프로젝트 타입을 선택하세요 (멀티 가능 — Space로 토글)"` → `"프로젝트 타입을 선택하세요"` (sh 1405). 실제 입력은 `1,2,8` 방식이라 "Space 토글"은 틀린 안내. 메뉴 하단 `"여러 개는 1,3,5"` 안내로 충분.
- 분석 결과 화면의 `(멀티)` 접미사는 정보성이므로 **유지**.

## 4. 영향 범위

| 파일 | 함수 | 변경 |
|---|---|---|
| `template_integrator.sh` | `detect_project_types` | 문구 정리 (E) |
| | `suggest_types_by_scan` | **신규** (B) |
| | `show_project_type_menu` | 추천 블록 출력 + preselect 연동 (A), 문구 정리 (E) |
| | `handle_project_edit_menu` (type 케이스) | path 자동 연결 (C) |
| | `resolve_project_paths` | 진행표시 `[n/N]` (D) |
| `template_integrator.ps1` | 위와 1:1 대칭 (`Get-SuggestedTypesByScan` 등) | 동일 |

## 5. 검증 (내부망 — 외부 연결 없이)

- `bash -n template_integrator.sh` 구문 검사 통과
- PowerShell `[ScriptBlock]::Create((Get-Content ... -Raw))` 파싱 통과
- 시나리오 재현:
  1. 마커 없는 임시 폴더 + `.py` 파일 4개 → 타입 메뉴에서 "python 가능성" 안내, preselect는 basic 유지
  2. basic → python 으로 수정 → 그 자리에서 path 질문이 바로 이어짐
  3. 멀티(spring,flutter,python) 선택 → `[1/3]~[3/3]` 진행표시로 타입별 순차 질문
  4. basic 유지 → path 질문 안 뜸

## 6. 비범위 (하지 않음)

- 초기 분석 결과 화면 변경 (basic 표시는 정답)
- 마커 기반 1차 감지 로직 변경
- `resolve_project_paths` 내부 타입별 순차 질문 구조 변경
- LLM/AI 기반 타입 추론 (내부망 제약)
