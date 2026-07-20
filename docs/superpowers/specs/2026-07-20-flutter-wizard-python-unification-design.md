# Flutter 마법사 스크립트 Python 단일화 설계

- 날짜: 2026-07-20
- 대상: `.github/util/flutter/` (playstore-wizard, firebase-wizard, testflight-wizard)
- 원칙: **기존 로직 100% 보존** (동일 입력, 동일 산출물). 언어와 파일 구성만 변경.

## 배경 / 문제

마법사 로컬 실행 스크립트가 bash(.sh)와 PowerShell(.ps1) 두 벌로 중복 관리되고 있다.
같은 로직을 두 언어로 유지하다 보니 한쪽만 고쳐지는 버그가 반복되고, macOS bash 3.2 제약,
PowerShell 5.1 제약까지 겹쳐 디버깅 비용이 크다. 반면 Python은 이미 필수 의존성이다
(playstore setup이 `patch-build-gradle.py`를 호출하며 python3/python 탐지 로직을 내장).

`version-sync.sh` 3종은 GitHub Actions 내부(ubuntu)에서만 실행되므로 변환 대상에서 제외한다.

## 결정 사항 (사용자 확인 완료)

1. 수정 위치: **projectops 템플릿에서만** 수정한다. 대상 레포는 `npx projectops@latest`로 반영.
2. 통합 단위: **마법사별 1개 py + argparse 서브커맨드**.
3. 구 .sh/.ps1: **완전 삭제**. HTML/JS가 OS별 python 실행 명령을 안내한다.
4. 마이그레이션: 구 sh/ps1 정리는 **migrations registry가 담당**한다 (사용자 리뷰 반영 —
   copy 함수에 삭제 로직을 두지 않는다. registry는 "레거시 마이그레이션 유일 관리 지점" 컨벤션).

## 파일 변경 계획

### playstore-wizard (7파일 -> 1파일)

| 기존 | 변경 후 |
|------|--------|
| playstore-wizard-setup.sh / .ps1 (829/817줄) | `playstore-wizard.py setup PROJECT_PATH APPLICATION_ID KEY_ALIAS STORE_PASSWORD KEY_PASSWORD VALIDITY_DAYS CERT_CN CERT_O CERT_L CERT_C` |
| playstore-wizard-apply.sh / .ps1 | `playstore-wizard.py apply [config.json]` |
| detect-application-id.sh / .ps1 | `playstore-wizard.py detect-app-id [PROJECT_PATH]` |
| patch-build-gradle.py | py 내부 함수로 흡수 (단독 파일 삭제) |

templates/, version.json, version-sync.sh 유지.

### firebase-wizard (4파일 -> 2파일)

| 기존 | 변경 후 |
|------|--------|
| firebase-wizard-setup.sh / .ps1 | `firebase-wizard.py setup --project-path P --app-id A --tester-group T` |
| test/setup-script-test.sh / .ps1 | `test/setup-script-test.py` (fixtures 4종 그대로 사용) |

JS의 ZIP 동봉(fetch 후 zip.file)도 .py 1개로 교체, README 안내문 갱신.

### testflight-wizard (1파일 -> 1파일)

| 기존 | 변경 후 |
|------|--------|
| testflight-wizard-setup.sh (718줄, mac 전용) | `testflight-wizard.py setup PROJECT_PATH BUNDLE_ID TEAM_ID PROFILE_NAME USES_NON_EXEMPT_ENCRYPTION` |

mac 전용이어도 python3는 Xcode CLT와 함께 설치되므로 요구사항 증가 없음.

## Python 공통 규약

- stdlib 전용 (외부 패키지 금지, 내부망/양OS 동작 목표)
- `#!/usr/bin/env python3`, `PYTHONIOENCODING` 없이도 깨지지 않도록 시작 시
  `sys.stdout.reconfigure(encoding="utf-8", errors="replace")` (cp949 콘솔 대응)
- ANSI 색상은 기존 sh와 동일 팔레트, Windows에서는 활성화 시도 후 실패하면 무색 출력
- 외부 도구 호출(keytool, base64 등)은 기존과 동일 인자로 `subprocess` 사용
- 종료 코드, 생성 파일 경로, 파일 내용은 기존 sh(canonical)와 동일. ps1과 sh가 갈리는
  지점이 발견되면 sh를 기준으로 하되 주석으로 기록

## HTML/JS 명령 안내 변경

- Windows: `cd "C:\path"; python .github\util\flutter\<wizard>\<wizard>.py setup ...`
- macOS/Linux: `cd "/path" && python3 .github/util/flutter/<wizard>/<wizard>.py setup ...`
- 기존의 ps1/sh OS 분기 UI 구조는 유지, 명령 문자열만 교체
- 인자 이스케이프는 기존 escapePowerShell/escapeBash 함수 재사용

## 마이그레이션 (npx projectops 업데이트 시)

구 파일 정리는 `src/core/migrations/`의 단일 레지스트리 경로로 처리한다:

- `registry.js`에 **`util-file` 카테고리 신설** + 구 파일 12개 항목(playstore 7, firebase 4,
  testflight 1)을 tier `safe`로 등록. rule은 기존 root-file rule(정확 경로 삭제)을 재사용한다.
- 이 경로는 기존 마이그레이션 UX(계획 카드 + 확인 1회 + 3계층 기록)를 그대로 태우고,
  비대화형(--force)에서도 safe 티어라 자동 정리된다.
- `copyUtilModules`(copy/util.js)는 순수 overlay 복사를 유지한다 — 복사 함수는 삭제하지
  않는다. 향후 util 파일을 리네임/폐기하면 워크플로우와 동일하게 registry에 구 이름을
  추가하는 것이 규율이다.
- version.json은 overlay 복사로 템플릿 값으로 갱신되고 UTIL-VERSION-SYNC 워크플로우가
  HTML 표시 버전을 동기화한다.

## version.json

각 마법사 minor 버전 증가 + changelog 항목 추가
(예: "로컬 실행 스크립트를 Python 단일 파일로 통합 (sh/ps1 이중 관리 제거)").

## 문서 갱신

- docs/FLUTTER-PLAYSTORE-WIZARD.md, docs/FLUTTER-TESTFLIGHT-WIZARD.md,
  docs/FLUTTER-CICD-OVERVIEW.md의 실행 명령 예시를 py 기준으로 교체.

## 테스트 / 검증

1. `python -m py_compile` 전체 py
2. firebase `test/setup-script-test.py`가 fixtures 4종에 대해 기존 기대값과 동일하게 통과
3. playstore `detect-app-id`, `setup`을 임시 Flutter 프로젝트 골격에서 스모크 실행
   (keytool 미존재 시 사전 체크 메시지 확인까지)
4. `npm test` (copyUtilModules mirror 변경 회귀 확인, 신규 테스트 추가)
5. HTML/JS/docs에 구 파일명 참조 잔존 여부 grep 0건 확인

## 비범위

- version-sync.sh 3종 (워크플로우 내부 실행, 유지)
- 마법사 HTML UI 자체의 기능 변경
- 다른 타입(spring 등) util 모듈
