# Firebase App Distribution 설정 마법사 firebase-wizard 추가

## 개요

Flutter 프로젝트에서 Firebase App Distribution 배포를 처음 설정할 때 필요한 정보(Service Account, App ID, Tester Group 등)를 단계별로 수집하고, GitHub Secrets 값을 생성·복사할 수 있는 5단계 HTML 마법사와 안전한 YAML 치환 스크립트를 구현했다. PlayStore wizard / TestFlight wizard와 동일한 구조로 `.github/util/flutter/firebase-wizard/`에 추가되었으며, TDD 방식으로 bash 13개·PowerShell 11개 시나리오를 전부 통과한 후 XSS·CRLF 보안 문제를 코드 리뷰로 추가 발견·수정했다.

## 변경 사항

### HTML 마법사 (5단계 UI)
- `.github/util/flutter/firebase-wizard/firebase-wizard.html`: Tailwind CDN + Pretendard 폰트 기반 다크 테마, 5단계 카드 UI. Step 1~5 각각 Firebase Console 설정 가이드 / Service Account + IAM 권한 / 앱 정보 입력 / 파일 업로드 / Secrets 출력으로 구성
- `.github/util/flutter/firebase-wizard/firebase-wizard.js`: state 관리, 4겹 showStep 래핑 패턴(step 3 → 4 파일 → 4 custom secrets → 5), `escapeHtml()` / `escapeJsString()` XSS 방어 헬퍼, JSZip CDN 기반 ZIP 다운로드, GitHub raw URL에서 setup 스크립트를 fetch하여 ZIP에 포함
- `.github/util/flutter/firebase-wizard/version.json`: 마법사 버전 정보 (`1.0.0`)

### Setup 스크립트 (YAML placeholder 치환)
- `.github/util/flutter/firebase-wizard/firebase-wizard-setup.sh`: bash 스크립트. `FIREBASE_APP_ID` / `FIREBASE_TESTER_GROUP` 키를 워크플로우 YAML에서 라인 단위로 안전하게 치환. 단어 경계 보장(키 직후 공백·콜론만 허용), `{FIREBASE_APP_ID}` / `{TESTER_GROUP}` placeholder 매칭, 충돌 대화형 프롬프트(y/n/abort), `.bak.<timestamp>` 백업 자동 생성
- `.github/util/flutter/firebase-wizard/firebase-wizard-setup.ps1`: PowerShell 5.1 호환 동일 기능. named group regex, `Strip-Quotes` 함수, UTF-8 BOM 쓰기

### TDD 테스트
- `.github/util/flutter/firebase-wizard/test/setup-script-test.sh`: bash 13개 시나리오 검증 (placeholder 치환, 이미 같은 값 SKIP, 대상 키 없음 SKIP, 다른 값 충돌 non-interactive SKIP, 모든 플래그 조합 등)
- `.github/util/flutter/firebase-wizard/test/setup-script-test.ps1`: PS 11개 시나리오 동일 검증
- `.github/util/flutter/firebase-wizard/test/fixtures/`: 4종 YAML fixture (`with-placeholders`, `with-real-values`, `without-keys`, `mixed-keys`)

### 문서·워크플로우 헤더 업데이트
- `README.md`: 배포 설정 마법사 항목에 `firebase-wizard` 경로 추가
- `CLAUDE.md`: 유틸 폴더 구조에 `firebase-wizard/` 항목 추가
- Flutter 워크플로우 파일 헤더(`PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml`, `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`): firebase-wizard 사용 안내 주석 추가

## 주요 구현 내용

### 라인 단위 안전 치환 (단어 경계 보장)

기존 `sed -i`나 전체 파일 `replace`가 아닌 라인 단위 BASH_REMATCH / PowerShell named group 파싱으로 구현했다. `FIREBASE_APP_ID_DEV` 같은 유사 키 이름이 있어도 `^(\s*)(FIREBASE_APP_ID|FIREBASE_TESTER_GROUP)(\s*:\s*)(.*)$` 패턴이 키 직후 공백/콜론만 허용하므로 오탐이 없다.

Placeholder `{FIREBASE_APP_ID}` / `{TESTER_GROUP}` 일치 시 치환, 이미 같은 값이면 SKIP, 다른 값이면 대화형 충돌 프롬프트(비대화형 모드에서는 자동 SKIP)로 처리한다.

### CRLF 안전 처리

Windows에서 작성된 YAML fixture가 CRLF 줄 끝을 포함할 경우, BASH_REMATCH 캡처값 끝에 `\r`이 붙어 `{FIREBASE_APP_ID}\r`이 placeholder로 매칭되지 않는 버그를 방지했다. bash에서는 `raw_value="${raw_value%$'\r'}"`, PowerShell에서는 `.TrimEnd("\`r")`를 quote 제거 직전에 적용했다.

### XSS 방어 (코드 리뷰 후 수정)

Custom Secrets 섹션에서 사용자가 업로드한 파일명·키명을 innerHTML에 직접 삽입하던 코드가 XSS 취약점을 가지고 있었다. `escapeHtml(s)` (innerHTML 컨텍스트), `escapeJsString(s)` (인라인 onclick 속성 컨텍스트, `\`, `'`, `"`, `<`, `>`, `&` 이스케이프)를 추가하고 모든 사용자 데이터 삽입부에 적용했다.

### Custom Secrets 섹션

PlayStore wizard v1.2.0 패턴을 이식했다. 추가 파일 업로드 시 텍스트 파일은 UTF-8 디코딩, 바이너리 파일은 base64 변환하여 Secrets에 포함하며, `_BASE64` 접미사로 자동 구분한다.

## 주의사항

- `exportZip()` 내 setup 스크립트 fetch는 GitHub raw URL을 직접 호출하므로 오프라인 환경에서는 스크립트가 ZIP에 포함되지 않는다. HTML 자체 미리보기 기능(Step 3 OS 탭 명령 표시)은 오프라인에서도 동작한다.
- bash setup 스크립트는 `mapfile`(bash 4.0+)을 사용하므로 macOS 기본 bash 3.2에서는 동작하지 않는다. `brew install bash` 후 `/usr/local/bin/bash`로 실행 필요.
- PS 스크립트는 Windows PowerShell 5.1 기준이며, `Set-Content -Encoding UTF8`은 BOM 포함 UTF-8로 저장된다.
