# 서브폴더 마커 스캔 추천 + 멀티모듈 스프링 정합 설계

> 작성일: 2026-06-11
> 대상: `template_integrator.sh`, `template_integrator.ps1`
> 관련: [[2026-06-11-type-edit-smart-recommend-design]], [[2026-06-11-monorepo-project-paths-design]]

## 1. 문제 정의

직전 작업([[2026-06-11-type-edit-smart-recommend-design]])으로 마커 없는 레포에서 확장자 빈도 스캔 추천(`suggest_types_by_scan`)을 넣었으나, passQL 실측에서 두 가지가 드러났다.

### 1-1. react 누락 (확장자 스캔의 한계)
- passQL `client/`에 React(TS) 프로젝트가 있는데 추천에서 react가 빠졌다.
- 실측: `client/`의 `.tsx` 50개 중 **48개가 깊이 4**(`./client/src/.../*.tsx`), 깊이 3엔 2개뿐.
- `suggest_types_by_scan`은 `maxdepth 3` → `.tsx` 2개만 카운트 → react 임계(3) 미달 → 누락.
- 정작 `client/package.json`(깊이 2)이라는 **확실한 마커**는 스캔이 보지 않는다.

### 1-2. 멀티모듈 스프링 후보 과다 검출
- `find_type_path_candidates spring`이 루트 + 모든 서브모듈 build.gradle을 잡는다.
- 실측: 루트 `settings.gradle` + `api/build.gradle` + `core/build.gradle` 구조 → 후보가 `.`, `api`, `core` **3개** 반환.
- 멀티모듈 스프링은 버전을 루트에서 관리하므로 `.` 하나가 정답인데, 과다 검출되어 사용자가 혼란스럽고 잘못 고르면 동기화 누락 위험.

## 2. 핵심 근거 — version_manager.sh는 이미 멀티모듈을 지원한다

`.github/scripts/version_manager.sh`를 코드로 확인한 결과, 스프링 동기화는 **경로 아래 모든 build.gradle을 일괄 갱신**한다.

- `sync_for_type`(spring, 522~527행): `find "$p" -maxdepth 2 -name "build.gradle" -type f` 순회하며 각 파일 version 치환.
- `update_project_file_version`(spring, 458행, legacy 단일): `find . -maxdepth 2 -name "build.gradle"` 동일.

따라서:
- **단일모듈**: `project_paths` 없이 루트 `.` → `./build.gradle` 갱신.
- **멀티모듈**: `project_paths`에 `spring=.` 하나면 → 루트 + 서브모듈(maxdepth 2) build.gradle 전부 갱신.
- **서브폴더형**: `spring=server` → `server/` 아래 build.gradle 갱신.

→ **integrator가 멀티모듈 스프링에서 `spring=.` 하나만 기록하면 version_manager가 나머지를 처리한다.** 이는 §3-B 수정 방향(settings.gradle 있으면 `.`만)과 정확히 정합한다. version_manager는 **수정하지 않는다.**

## 3. 변경 항목

### A. 마커 우선 스캔 추천 (`suggest_types_by_scan` 보강)

확장자 빈도만 보던 것을, **서브폴더 마커 파일 우선**으로 보강한다.

```
1. 모든 마커 타입(flutter, spring, python, react, next, node, react-native, react-native-expo)에
   대해 find_type_path_candidates 실행 → 후보 디렉터리가 하나라도 있으면 그 타입을 추천.
2. package.json 계열(react/next/node/react-native/-expo)은 마커가 동일하므로,
   각 후보 디렉터리의 package.json 내용을 classify_package_json으로 판별해 정확한 타입 결정.
3. 마커가 전혀 없는 타입은 기존 확장자 빈도 스캔으로 폴백(순수 .py 스크립트 모음 등).
4. 결과 csv 반환(중복 제거, 메뉴 정의 순서로 정렬).
```

신규 헬퍼 `classify_package_json PATH`: `detect_project_types`의 package.json 인라인 판별 로직을 추출.
규칙(우선순위): `@react-native`/`react-native` 포함 → (`expo` 포함 시 `react-native-expo` / 아니면 `react-native`) → `"next"` → `"react"` → 그 외 `node`.

### B. 멀티모듈 스프링 오탐 수정 (`find_type_path_candidates` spring 분기)

spring 후보를 거르기 전에:
- 루트에 `settings.gradle` 또는 `settings.gradle.kts`가 있으면 → 멀티모듈로 판단, 후보를 `.` 하나로 고정(서브모듈 build.gradle 제외).
- 없으면 → 기존 동작 유지(각 build.gradle 디렉터리, `*android*` 오탐 제외).

이는 version_manager의 "spring=. → 하위 모든 build.gradle 일괄 갱신"과 정합한다.

### C. 확장자 스캔은 폴백으로 유지

§A-3. 마커가 전혀 없는 타입(예: 빌드도구 없는 순수 Python 스크립트, .dart만 있는 조각)은 기존 `.dart`/`.py`/`.tsx`/`.ts`·`.js` 빈도 임계로 폴백 추천한다.

## 4. 영향 범위

| 파일 | 함수 | 변경 |
|---|---|---|
| `template_integrator.sh` | `classify_package_json` | **신규** — package.json 경로 → react/next/node/react-native(-expo) |
| | `find_type_path_candidates` (spring) | settings.gradle 있으면 `.`만 (B) |
| | `suggest_types_by_scan` | 마커 우선 스캔 + 확장자 폴백 (A·C) |
| `template_integrator.ps1` | `Get-PackageJsonType`·`Find-TypePathCandidates`·`Get-SuggestedTypesByScan` | sh와 1:1 대칭 |
| `.github/scripts/test/test_integrator_suggest.sh` | 케이스 추가 | 서브폴더 react·멀티모듈 spring `.`·서브폴더 spring + 기존 6 |

## 5. 검증 (내부망 — 외부 연결 없이)

- `bash -n template_integrator.sh`, ps1 `[ScriptBlock]::Create` 파싱
- 단위 테스트:
  1. (기존 6 유지) 확장자 폴백 케이스
  2. 서브폴더 react: `client/package.json`(react 의존성) → 추천에 `react` 포함
  3. 멀티모듈 spring: 루트 `settings.gradle` + `api/`,`core/` build.gradle → `find_type_path_candidates spring` == `.` 하나
  4. 서브폴더 spring: `server/build.gradle`(settings 없음) → `server`
  5. 서브폴더 next: `web/package.json`("next" 의존성) → `next`
- passQL 재현: 마커 스캔으로 flutter·spring·python·**react** 모두 추천에 포함

## 6. 비범위 (하지 않음)

- `version_manager.sh` 수정 — 이미 멀티모듈/서브폴더 스프링을 `find maxdepth 2 build.gradle`로 완전 지원함을 코드로 확인.
- `detect_project_types`(루트 1차 감지) 변경 — 서브폴더 탐지는 추천 단계가 담당.
- 확장자 스캔 maxdepth 증가 — 마커 우선 스캔이 본질적 해결이므로 불필요(YAGNI).
- AI/LLM 기반 추론(내부망 제약).
