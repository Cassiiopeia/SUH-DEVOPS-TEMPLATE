# version.yml 덮어쓰기 UX 개선 + 멀티모듈 경로 감지 설계

작성일: 2026-06-11
대상 파일: `template_integrator.sh`, `template_integrator.ps1`, `.github/scripts/test/test_integrator_suggest.sh`

---

## 배경

기존 프로젝트(passQL)에 템플릿을 통합하면서 두 가지 문제가 드러났다.

1. **멀티모듈 spring 경로 감지 실패** — 멀티모듈 루트(`settings.gradle`)가 레포 루트가 아니라 하위 폴더(`server/`)에 있으면, 단락 로직이 안 걸려 하위 모듈 `build.gradle` 9개가 후보로 폭발했다.
2. **version.yml 덮어쓰기 프롬프트가 사용자를 잘못 유도** — "덮어쓰기"라는 파괴적 단어 + 기본값 N(건너뛰기) 때문에, 처음 통합하는 사용자가 두려워 N을 누른다. 그런데 N(version.yml 미갱신)은 구버전 구조를 남겨 최신 워크플로우를 깨뜨리는 위험한 반쪽 상태를 만든다.

---

## 변경 ① 멀티모듈 spring 경로 감지 (구현·테스트 완료)

### 문제
`find_type_path_candidates()`의 멀티모듈 단락이 레포 루트의 `settings.gradle`만 검사했다.

### 해결
spring 분기에서 루트뿐 아니라 하위 폴더(maxdepth 3 / Depth 2)까지 `settings.gradle*`을 탐색해, 발견된 폴더를 멀티모듈 루트 후보로 축약한다.

- `android/` 폴더의 `settings.gradle`(Flutter/RN)은 제외 (sh: prune, ps1: PathExcludeRegex)
- 발견 폴더가 1개면 자동확정, 여러 개면 메뉴 선택
- `settings.gradle`이 전혀 없으면 기존 `build.gradle` 탐색 폴백

### 동작 결과
| 케이스 | 후보 |
|---|---|
| `server/settings.gradle` (passQL) | `server` 하나 |
| 루트 `settings.gradle` | `.` 하나 |
| settings.gradle 없음 | build.gradle 폴백 |
| `app/android/settings.gradle` | spring 후보에서 제외 |
| 멀티모듈 2개 | 둘 다 후보(정렬) → 메뉴 |

### 검증
`test_integrator_suggest.sh`에 케이스 20·21·22 추가. 전체 22/22 통과. (sh 완료, ps1은 로직 대칭 포팅 완료 — pwsh 미설치로 로컬 실행 검증은 미완)

---

## 변경 ② version.yml 덮어쓰기 프롬프트 — 카피 + 동작

### 동작 변경
- 선택지 의미를 바꾼다: 기존 `Y 덮어쓰기 / N 건너뛰고 진행` → `Y 업데이트하고 계속 / N 통합 취소`
- **N은 version.yml만 건너뛰는 게 아니라 통합 전체를 중단**한다. "구버전 version.yml + 신버전 워크플로우"라는 반쪽 상태를 원천 차단.
- 기본값을 `N` → `Y`로 변경 (Enter만 쳐도 업데이트).

### 카피 (최종 확정)
```
────────────────────────────────────────────────────────────
 🔄 version.yml 업데이트 — 안전합니다, 필수입니다
────────────────────────────────────────────────────────────

  기존 version.yml을 최신 템플릿 구조로 갱신합니다.
  이 단계는 통합에 반드시 필요합니다.

  ✅ 유지되는 값 (그대로 보존)
       version        <기존값>    롤백 없음
       version_code   <기존값>    스토어 빌드번호 안전

  📝 갱신되는 것
       구조 · 주석 · project_paths · metadata

  ⚠️  업데이트하지 않으면 구버전 구조가 남아
       최신 워크플로우의 버전 자동증가 · 체인지로그 · 배포
       동기화가 깨집니다. 그래서 건너뛸 수 없습니다.

     Y   업데이트하고 계속  (권장 · 기본)
     N   통합 취소

  선택 [Y]:
```

### 카피 설계 원칙
- 이모지는 섹션 헤더당 1개씩만 (`🔄 ✅ 📝 ⚠️`) — 줄마다 X (가독성)
- "유지되는 값"을 실제 값으로 컬럼 정렬 → "내 데이터 안 날아간다"가 한눈에
- N 선택 시 손해(워크플로우 깨짐)를 명시 → 손실 회피 유도
- 키는 친숙한 Y/N 유지 (U 같은 낯선 키 금지)

---

## 변경 ③ 덮어쓰기 시 version 값 보존

### 문제
②의 카피가 "version 유지"를 약속하지만, 현재 `$VERSION`은 `detect_version()`(build.gradle·package.json·pubspec·git tag 감지)에서만 온다. version.yml의 값은 안 읽는다. 코드 버전과 version.yml 버전이 다르면 카피의 "유지" 약속이 거짓이 된다.

### 해결
덮어쓰기 시 **기존 version.yml의 `version`을 최우선으로 읽어 보존**한다. version.yml에 값이 없을 때만 코드/태그 감지 폴백.

- 우선순위: 기존 version.yml `version` → detect_version()
- version.yml이 버전 관리의 single source of truth라는 원칙과 일치 (version_code 보존과 동일한 철학)

---

## 영향 범위 / 대칭

- `template_integrator.sh`와 `template_integrator.ps1`을 1:1 대칭으로 수정 (프로젝트 규칙)
- 비대화형(`FORCE_MODE` / TTY 없음)은 기존 동작 유지 — 프롬프트 없이 진행
- 테스트는 `find_type_path_candidates` 단위 테스트로 ①을 커버. ②③은 대화형 UI라 단위 테스트 어려움 → 로컬 수동 검증(passQL)으로 확인

---

## 테스트 계획
1. ① 자동: `bash .github/scripts/test/test_integrator_suggest.sh` → 22/22
2. ②③ 수동: passQL 레포에서 로컬 스크립트 실행 → 프롬프트 카피·기본값 Y·N 취소 동작·version 보존 확인
