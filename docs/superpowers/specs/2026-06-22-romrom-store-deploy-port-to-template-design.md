# Flutter 스토어 배포 개선 포팅 + 모노레포 경로 대응 — SUH-DEVOPS-TEMPLATE 설계

- 작성일: 2026-06-22
- 관련 이슈(RomRom-FE): #930(Android/PlayStore 거짓 성공 제거), #931(iOS/AppStore 심사 자동 제출 누락), #934(배포 모드 3단계 통일), #935(마법사·Fastfile 가이드 명확화)
- 관련 템플릿 이슈: SUH-DEVOPS-TEMPLATE #399
- 선행 스펙: `2026-06-19-flutter-store-review-submit-automation-design.md`, `2026-06-19-playstore-review-submit-root-cause.md`

## 1. 목표 (두 갈래)

이번 작업은 같은 Flutter CICD 파일을 건드리는 **두 개선을 함께** 한다.

**(A) RomRom 검증 배포 로직 포팅** — RomRom-FE에서 **실측 검증 완료된** Flutter 스토어 배포 개선(iOS 심사 자동 제출 + Android 거짓 성공 제거 + 배포 모드 3단계 통일 + 마법사 안내 강화)을 템플릿 대응 파일에 이식. iOS는 §2-1대로 파일 템플릿 방식으로 통일.

**(B) 모노레포 경로 대응 (passQL이 증명한 결함)** — Flutter 루트가 레포 루트의 서브폴더(예: `app/`)인 모노레포에서, **마법사는 `PROJECT_PATH` 인자로 올바른 위치에 깔지만 CICD 워크플로우가 `cd ios`/`working-directory: ios`로 레포 루트 기준 하드코딩이라 전부 실패**한다. 워크플로우 상단 `env: FLUTTER_ROOT`를 두고, **integrator 통합 시점에 `project_paths.flutter` 값으로 1회 치환**(런타임 version.yml 읽기 없음)해 Flutter 루트를 잡게 한다. §9 참조.

> **(A) 실측 근거**: iOS 1.10.104가 실제 App Store 심사 큐(`Waiting for Review`) 자동 진입, Android 1.10.101 production "검토 중" 진입 검증 완료 (RomRom-FE #934 본문).
> **(B) 실측 결함**: `passQL` 레포는 `version.yml`에 `project_paths.flutter: "app"`, 실제 Flutter 루트가 `app/ios`·`app/android`인데 CICD가 `cd ios`로 레포 루트를 찾아 배포 step이 전부 깨진다(직접 확인).

## 2. 범위 결정 사항 (확정)

| 결정 | 값 |
|------|-----|
| 작업 성격 | RomRom 검증 로직 1:1 이식 + **iOS 구조를 Android와 동일한 파일 템플릿 방식으로 통일** (검증된 배포 동작은 보존, 구조만 개선) |
| iOS 포팅 방식 | **파일 템플릿 방식으로 통일** (heredoc 폐기). 아래 §2-1 참조 — RomRom의 deliver 배포 로직(deploy_mode·deliver·whatsNew·Notes초기화)은 그대로 가져오되, 워크플로우 안 heredoc 동적 생성을 버리고 마법사가 깐 `ios/fastlane/Fastfile`을 그대로 실행한다. Android가 이미 쓰는 구조와 대칭 |
| iOS setup.ps1 (Windows 셋업) | **이번 범위 제외** — RomRom에 없는 신규 자산이라 별도 작업으로 분리. §8 비범위 참조 |
| 소스 오브 트루스 | RomRom-FE의 최종(HEAD) 파일 (단 iOS 워크플로우 구조는 Android 패턴을 따름) |

### 2-1. iOS 구조 결정: heredoc → 파일 템플릿 (관리 편의성)

**문제 (RomRom 현재 iOS에 존재하는 어긋남):**
- 마법사 `testflight-wizard-setup.sh`는 `templates/Fastfile`(lane `deploy`, deliver 포함)을 `ios/fastlane/Fastfile`로 복사한다.
- 그러나 운영 워크플로우(`ROMROM-IOS-TESTFLIGHT.yaml` 433~571행)는 그 파일을 **쓰지 않고**, step 안에서 `cat > fastlane/Fastfile << 'EOF' ... EOF` heredoc으로 **별도 lane `deploy_appstore`를 동적 생성**해 619행 `fastlane deploy_appstore`로 실행한다.
- 결과: 동일한 배포 로직이 **두 곳(마법사 템플릿 + 워크플로우 heredoc)에 중복**되고 lane 이름도 다르다(`deploy` vs `deploy_appstore`). 마법사가 깐 Fastfile은 실제 배포에서 무시된다.

**Android는 이미 깨끗한 파일 템플릿 방식:**
- 마법사가 `android/fastlane/Fastfile.playstore`를 레포에 깔아둠 → 워크플로우가 `cp android/fastlane/Fastfile.playstore android/fastlane/Fastfile`(548행) 후 `fastlane deploy_internal`(661행). 깐 파일 = 도는 파일.

**iOS도 Android와 대칭으로 통일 (이번 작업의 핵심 구조 변경):**
1. 워크플로우의 "Install Fastlane and create Fastfile" heredoc step(433~571행)을 폐기.
2. 대신 마법사가 깐 `ios/fastlane/Fastfile`(= `templates/Fastfile` 사본, lane `deploy`)을 그대로 사용. 워크플로우가 마법사 없이도 동작하도록, Android의 `cp` 보장 패턴과 동형으로 `templates/Fastfile`을 `ios/fastlane/Fastfile`로 복사하는 경량 step만 둔다(또는 레포에 커밋된 `ios/fastlane/Fastfile`을 직접 사용).
3. 실행 명령 `fastlane deploy_appstore` → `fastlane deploy`(`templates/Fastfile`의 lane명).
4. env export(DEPLOY_MODE/APP_VERSION/BUILD_NUMBER/APP_IDENTIFIER/RELEASE_NOTES/DELIVER_LOCALES 등)와 deploy_mode workflow_dispatch input은 RomRom과 동일하게 유지.

**효과:** iOS 배포 로직이 `templates/Fastfile` 한 곳에만 존재 → 유지보수 일원화, IDE Ruby 문법 검증 가능, 마법사·운영 일치. 검증된 배포 동작(deliver 심사 자동 제출 등)은 lane 내용이 동일하므로 보존된다.

> **주의**: 이 구조는 RomRom 운영본과 다르므로 "RomRom과 100% 동형" 검증 기준은 적용 불가. 대신 "templates/Fastfile의 lane 내용(deliver 옵션 등)이 RomRom heredoc의 lane 내용과 동일한가"를 검증 기준으로 삼는다(아래 §7).

## 3. 배포 모드 3단계 (양 플랫폼 통일 — 이식 대상의 핵심)

| 모드(공통) | iOS 별칭 | Android 동작 | iOS 동작 |
|-----------|----------|-------------|----------|
| `store_only` | `testflight_only` | internal 트랙 업로드까지만 | TestFlight 업로드까지만 |
| `store_prepare` | `appstore_prepare` | production `draft` 승급(콘솔에서 "출시 시작" 대기) | ASC 버전 생성·빌드 선택·whatsNew 채움(제출 직전) |
| `store_submit` | `appstore_submit` | production `completed` 승급(Google 심사 자동 등록) | deliver `submit_for_review`로 심사 자동 제출 |

- 위 표의 "iOS 별칭"은 iOS 전용이 아니라 **하위호환 별칭**이다. 양 플랫폼 Fastlane lane이 공통 네이밍(`store_*`)과 별칭(`testflight_only`/`appstore_*`)을 **둘 다** 인식한다(`["store_prepare","store_submit","appstore_prepare","appstore_submit"].include?`). 신규 셋업은 공통 `store_*` 사용 권장, 기존 RomRom 호환을 위해 별칭도 받는다.
- 폴백 기본값: 신규 앱 안전을 위해 `store_only`(iOS 코드 폴백 문자열은 RomRom과 동일하게 `testflight_only`를 써도 동작 동일 — 둘 다 "업로드까지만").
- repo variable로 운영 앱은 `ANDROID_DEPLOY_MODE`/`IOS_DEPLOY_MODE`를 지정. workflow_dispatch `deploy_mode` input이 우선, 없으면 repo variable, 없으면 폴백.

## 4. 거짓 성공 제거 (검증된 근본 원인 수정)

- **Android**: `promote_internal_to_production` lane의 `upload_to_play_store`에
  `track_promote_release_status: status`(completed|draft) + `changes_not_sent_for_review: false` + `rescue_changes_not_sent_for_review: false`.
  fastlane supply 기본값 `rescue_changes_not_sent_for_review: true`가 심사 미전송을 자동 rescue해 저장만 하고 success를 반환하던 "거짓 성공"을 차단.
- **iOS**: 워크플로우의 `|| echo "...성공..."` 거짓 성공 라인 제거(이미 RomRom 운영본에 반영됨). deliver 실패가 정직하게 빨간불로 표면화.

## 5. 포팅 대상 파일 (소스 → 대상 매핑)

> 경로 접두사: RomRom = `RomRom-FE/`, 템플릿 = `suh-github-template/`. 파일명 차이(`ROMROM-*` → `PROJECT-FLUTTER-*`)에 주의.
> **iOS는 구조 변경 포함** — RomRom heredoc 로직을 그대로 베끼는 게 아니라 §2-1 방식으로 파일 템플릿화한다. 그래서 "소스"가 RomRom heredoc(워크플로우)인 항목과 RomRom `templates/Fastfile`인 항목이 섞여 있다.

| # | 대상(템플릿) | 소스(RomRom) | 포팅 내용 | 현재 템플릿 상태 |
|---|--------------|--------------|-----------|------------------|
| 1 | `playstore-wizard/templates/Fastfile.playstore.template` | 동일 경로(RomRom `templates/`) | 파일 전체 교체 | `release_status:"draft"` 고정·rescue 옵션 없음·옛 `promote_to_beta/production` 구조 |
| 2 | **신규** `testflight-wizard/templates/Fastfile.ios.template` ← 기존 `templates/Fastfile`을 **개명** | RomRom `testflight-wizard/templates/Fastfile`의 lane 내용 + RomRom 워크플로우 heredoc(442~569행)의 deliver 로직 | `.template` 접미사 부여 + `deploy` 통합 lane(deliver·whatsNew·Notes초기화 포함)으로 내용 교체. lane명 `deploy` 확정 | 접미사 없는 `Fastfile`·`deploy` lane 없음·deliver 전무 |
| 3 | `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | `.github/workflows/ROMROM-IOS-TESTFLIGHT.yaml` | **heredoc step(433~571행) 폐기** → `templates/Fastfile.ios.template`을 `ios/fastlane/Fastfile`로 복사하는 경량 step + deploy_mode workflow_dispatch input + DEPLOY_MODE/APP_IDENTIFIER/APP_VERSION/BUILD_NUMBER/RELEASE_NOTES/DELIVER_LOCALES env + 호출 `fastlane deploy`(←`deploy_appstore`) | deploy_mode input 없음·env 3개·`upload_testflight` 호출 |
| 4 | `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | `.github/workflows/ROMROM-ANDROID-PLAYSTORE-CICD.yaml` | deploy_mode workflow_dispatch input + `DEPLOY_MODE` env 전달 추가 | input 없음·DEPLOY_MODE 미전달 |
| 5 | `testflight-wizard/testflight-wizard-setup.sh` | 동일 경로 | ① 템플릿 참조 경로 `$TEMPLATE_DIR/Fastfile` → `$TEMPLATE_DIR/Fastfile.ios.template`로 변경(214행), 복사 대상은 `ios/fastlane/Fastfile` 유지(접미사 제거 복사) ② 배포 모드 안내·완료메시지(IOS_DEPLOY_MODE repo variable) 동기화 | 구버전 참조·DEPLOY_MODE 안내 없음 |
| 6 | `testflight-wizard/testflight-wizard.html` (필요시 `.js`) | 동일 경로 | 완료단계 "배포 모드 & 출시 로드맵" 안내카드(IOS_DEPLOY_MODE) | 안내카드 없음 |
| 7 | `playstore-wizard/playstore-wizard.html` (필요시 `.js`) | 동일 경로 | 완료단계 배포 모드 안내카드(ANDROID_DEPLOY_MODE) | 안내카드 없음 |
| 8 | `playstore-wizard/playstore-wizard-setup.sh` / `.ps1` | 동일 경로 | RomRom 변경분(안내 문구) 동기화 — `.sh`/`.ps1` 동등 유지 | 대조 후 차이만 반영 |
| 9 | `testflight-wizard/templates/Gemfile` | 동일 경로 | 내용 동일(EOL 차이만) → **개명 안 함**(setup.sh가 heredoc으로 직접 생성하므로 이 파일은 미사용 사본일 가능성. 실제 사용 여부 확인 후 정리). multi_json 포함 보장만 확인 | 내용 동일 |

### 5-1. iOS `.template` 개명 시 함께 고칠 곳 (누락 주의)
- `testflight-wizard-setup.sh` 214행 `template_fastfile="$TEMPLATE_DIR/Fastfile"` → `.../Fastfile.ios.template`. 복사 결과 경로(`ios/fastlane/Fastfile`)는 그대로(사용자 프로젝트엔 접미사 없이 깔림).
- `ExportOptions.plist`도 컨벤션상 `.template` 후보지만, 이번 배포개선과 무관하므로 **이번 범위에서는 Fastfile만 개명**(ExportOptions·Gemfile 개명은 별도 정리 이슈로). → iOS 템플릿 디렉토리 전면 컨벤션 정리는 비범위.
- iOS Fastfile을 참조하는 다른 곳은 없음(확인됨) → 개명 영향 국소적.

### 5-2. 토큰 치환 주의 (템플릿 ↔ RomRom 차이)
- RomRom은 `com.alom.romrom` 등 **실값 하드코딩**. 템플릿 파일은 `{{APPLICATION_ID}}`(Android) / ENV 기반(iOS) 방식 유지.
- 포팅 시 **배포 로직(lane/옵션/env)만** 가져오고, 패키지명·Bundle ID는 템플릿 정책으로 되돌린다. RomRom heredoc의 `app_id = ENV["APP_IDENTIFIER"] || "com.alom.romrom"` 폴백은 템플릿에선 하드코딩 제거(폴백 없이 ENV 필수, 또는 플레이스홀더).
- `git diff`로 RomRom 고유값(`com.alom.romrom`, `ROMROM-` 등)이 섞여 들어가지 않았는지 자가검증.

## 6. 공통 워크플로우 동기화 규칙 — 적용 여부

- CLAUDE.md 규칙: **공통** 워크플로우는 `project-types/common/` 원본과 `.github/workflows/` 루트 복사본을 동일하게 유지.
- 본 작업 대상(IOS-TESTFLIGHT, ANDROID-PLAYSTORE)은 **타입별(flutter) 워크플로우**이며 루트 복사본이 존재하지 않음(확인됨). → **두 곳 동기화 규칙 비적용.** `project-types/flutter/`만 수정한다.
- 마법사 `templates/` 파일은 `template_initializer.sh`/`template_integrator.*`의 제외목록 대상이 아님(확인됨) → 사용자 프로젝트로 정상 전달. iOS `.template`도 동일.

## 7. 검증 전략 (포팅 후)

YAML은 로컬 파서 빨간불을 GitHub 실제 동작으로 착각하지 않는다(CLAUDE.md 규칙). 검증 순서:
1. **Android는 RomRom 운영본과 동형 대조**: 포팅 후 `diff`해 로직 라인이 동일한지(플레이스홀더 제외) 확인. RomRom은 실제 success 이력 있는 기준 레포.
2. **iOS는 lane 내용 대조**(구조가 RomRom과 다르므로 동형 대조 불가): 템플릿 `Fastfile.ios.template`의 `deploy` lane 내용(pilot/deliver 옵션·whatsNew·Notes 초기화 로직)이 RomRom heredoc `deploy_appstore` lane(442~569행)의 내용과 의미상 동일한지 라인 대조. 워크플로우는 `fastlane deploy` 호출 + 동일 env 전달인지 확인.
3. **Fastfile Ruby 문법 확인**: `ruby -c`(가능 시) 또는 구조 검토.
4. **마법사 HTML**: 브라우저 렌더 깨짐 없는지 구조만 확인. `.sh`/`.ps1` 동등성 재확인(Android).
5. 실제 스토어 배포 검증은 RomRom에서 이미 완료(iOS 1.10.104 Waiting for Review, Android 1.10.101 검토 중). 템플릿은 로직 동일성으로 검증 갈음.

## 8. 비범위 (YAGNI)

- **iOS `setup.ps1` 신규 작성**(Windows에서 iOS 마법사 셋업): RomRom에 없는 신규 자산. Windows에서도 iOS CICD 세팅을 가능케 하는 가치가 있으나(실제 빌드는 GitHub macOS 러너에서 일어나므로 셋업만 OS중립이면 됨), 인증서·plist 처리를 PowerShell로 재구현해야 해 범위·검증 부담이 큼 → **별도 후속 이슈로 분리.**
- iOS 템플릿 디렉토리 전면 `.template` 컨벤션 정리(ExportOptions.plist·Gemfile 개명): 이번엔 배포로직 직결 파일(Fastfile)만. 나머지는 별도 정리.
- 새 배포 모드·새 lane·배포 후 API 폴링 검증 같은 **RomRom에 없는 신규 기능**은 추가하지 않는다.
- 테스트 빌드 워크플로우(`*-TEST-APK`, `*-TEST-TESTFLIGHT`)는 무관(RomRom도 미변경) → 손대지 않는다.

## 9. 모노레포 경로 대응 (개선 B)

### 9-1. 문제 (passQL로 실측 증명)
- Flutter 표준상 Flutter 루트 **안에서는** 경로가 고정이다(`<root>/ios/...`, `<root>/android/app/...`). 그러나 **Flutter 루트가 레포 루트가 아닐 수 있다**(모노레포: `app/`, `client/` 등).
- **마법사 setup.sh/.ps1**: `PROJECT_PATH="$1"` 인자를 받아 `$PROJECT_PATH/ios/...`, `$PROJECT_PATH/android/...`에 깐다 → **이미 모노레포 대응됨.**
- **CICD 워크플로우**: `cd ios`·`working-directory: ios`·`mkdir android/...`·artifact `path: ios/build/...` 등 **레포 루트 기준 하드코딩** → 모노레포에서 전부 깨짐.

### 9-2. 값 주입 방식 — 런타임 읽기 폐기 + `@wizard auto:<resolver>` 디스패처 (사용자 피드백 반영)

> **설계 원칙(사용자 지적 2건)**:
> 1. **런타임 읽기 폐기** — `version_manager.sh get-path`로 매번 읽으면 version.yml이 망가질 때 배포가 죽고, 사용자가 흐름을 모르며, 직관적이지 않다. → 값을 워크플로우 상단 `env`에 박고, 통합 시점에 1회 치환하며, 사람이 보고 고칠 수 있게 한다. 런타임은 version.yml을 읽지 않는다.
> 2. **마커를 resolver 디스패처로 일반화** — `flutter-root` 전용 마커를 case에 또 추가하는 식(마커종류=동작 1:1 하드코딩)은 값 종류가 늘 때마다 분기가 불어난다. → `@wizard auto:<resolver-name>` 형태로 **resolver 이름을 인자로 받아 디스패치**하고, 값 종류가 늘면 **resolver 함수만 추가**한다.
> 3. **하위호환 미고려** — 기존 `auto`/`auto-find` 마커도 신규 디스패처 문법으로 전부 마이그레이션한다. 레거시 분기를 남기지 않는다(깨끗한 단일 문법).

#### 마커 문법 (신규 통일)
```yaml
env:
  FLUTTER_ROOT: "."                              # @wizard auto:flutter-root
  PROJECT_NAME: "__PROJECT_NAME__"               # @wizard auto:project-name
  APPLICATION_YML_DIR: "__APPLICATION_YML_DIR__" # @wizard auto:spring-app-yml-dir
  JAVA_VERSION: "__JAVA_VERSION__"               # @wizard ask: JDK 버전 [기본: 21]
```
- **`# @wizard auto:<resolver> [기본: <값>]`** — integrator가 `<resolver>` 함수를 실행해 반환값으로 env를 치환. 사용자 입력 없음.
- **`# @wizard ask: <질문> [기본: <값>]`** — 기존 ask 문법 유지(사용자에게 물음, 엔터=기본값). 디스패처와 별개 트랙.
- 치환 후 마커는 `# @wizard set (직접 수정 가능)`으로 교체 → 사용자 수동 수정 안내.

#### resolver 디스패처 구조 (`template_integrator.sh` + `.ps1` 동일)
`configure_workflow_env`의 마커 처리부를 **resolver 디스패처**로 교체:
```
resolve_marker(type, resolver_name) →
  case resolver_name in
    flutter-root)      get_path_for_type "flutter"  # "." 또는 "app" (project_paths 확정값)
    project-name)      detect_repo_name
    spring-app-yml-dir) find "$(get_path_for_type type)" -path "*/src/main/resources/application*.yml" | head -1 | dirname
    spring-app-yml-path) (위와 동일하나 파일 경로 그대로)
    *) "" (미지원 → 잔류토큰 경고)
```
- **resolver는 `get_path_for_type`이 통합 시점에 `resolve_project_paths`(1195~)로 이미 채운 CSV를 읽는다.** 별도 find 재탐색·version.yml 직접 파싱 없음.
- 값 종류가 늘면 이 case(=resolver 레지스트리)에 한 줄 추가. 워크플로우는 마커 문자열만 바꾸면 됨 — 엔진 구조 불변.

#### 기존 마커 마이그레이션 (하위호환 없이 전량 교체)
| 기존 | 신규 | 사용처 |
|------|------|--------|
| `# @wizard auto` (PROJECT_NAME) | `# @wizard auto:project-name` | 순수 auto 사용처 0개(코드 분기만 존재) → 그냥 신규로 |
| `# @wizard auto-find: application.yml…` | `# @wizard auto:spring-app-yml-dir` / `…-path` | Spring 4개 파일(NGINX/TRAEFIK/PR-PREVIEW/SIMPLE) |
| `# @wizard paths-anchor` | **유지**(별개 기능 — env 치환이 아니라 `on.push.paths` 주입) | 모노레포 워크플로우 |
| (없음) | `# @wizard auto:flutter-root` 신규 | Flutter IOS/ANDROID 2개 |

#### 적용·폴백
- Flutter PlayStore/TestFlight 워크플로우 상단에 `FLUTTER_ROOT: "."  # @wizard auto:flutter-root` 추가.
- **integrator 미경유**(템플릿 레포 자체 실행/수동 배치): 토큰 기본값 `.`이 남아 단일레포로 동작 → 안전 폴백.
- **`.ps1` 동등성**: `template_integrator.ps1`의 대응 함수(2337행~ "configure_workflow_env와 1:1")도 동일한 resolver 디스패처로 교체. `.sh`/`.ps1` resolver 목록·동작 일치.

### 9-3. 워크플로우 경로 변수화 — job `defaults.run.working-directory` 중심
전수 조사: iOS 경로 의존 **23개**, Android **24개**(총 47개). 두 워크플로우 모두 `defaults working-directory` 미설정 — `cd`가 흩어짐.

1. **빌드/배포 job에 `defaults: run: working-directory: ${{ env.FLUTTER_ROOT }}` 한 줄** → 그 job의 모든 `run:` step이 Flutter 루트에서 돈다. `cd ios`(→`$FLUTTER_ROOT/ios`로 해석), `mkdir android/...`, `cat > android/key.properties` 등 **run 내부 경로 대부분 자동 해결**.
2. **`run:`이 아니라 자동 적용 안 되는 곳만 개별 변수화** (`${{ env.FLUTTER_ROOT }}` 사용):
   - `actions/upload-artifact`·`download-artifact`의 `path:` (working-directory 영향 안 받음)
   - step 레벨 `working-directory:` 값 자체
   - `$GITHUB_WORKSPACE/ios/...` 절대경로(예: iOS `find $GITHUB_WORKSPACE/ios/build/ipa`) → `$GITHUB_WORKSPACE/$FLUTTER_ROOT/ios/...`
   - `git add ios/`처럼 레포 루트에서 도는 게 맞는 것은 working-directory와 별개로 점검(필요 시 `git add $FLUTTER_ROOT/ios/`)
3. 기본값 `.`이면 **현재 단일레포 동작 100% 보존**(RomRom 포함). `defaults working-directory: .`은 레포 루트라 무해.

### 9-4. 검증
- **디스패처 회귀(Spring auto-find 마이그레이션)**: 하위호환을 안 두고 Spring 4개(NGINX/TRAEFIK/PR-PREVIEW/SIMPLE)의 `auto-find`를 `auto:spring-app-yml-dir`/`-path`로 갈아엎으므로, **새 resolver가 기존과 동일 값을 반환하는지 반드시 회귀 검증.** Spring 픽스처(`src/main/resources/application*.yml`)에서 치환 결과가 기존 `auto-find`와 같은지 대조.
- **단일레포 회귀**: `FLUTTER_ROOT="."`일 때 기존과 동일 경로(`./ios`=`ios`, `defaults working-directory: .`)가 되는지 확인. RomRom 동형.
- **모노레포**: passQL(`project_paths.flutter: "app"`)을 integrator로 통합 시 워크플로우 env가 `FLUTTER_ROOT: "app"`으로 치환되는지, `defaults working-directory: app`으로 `cd ios`가 `app/ios`를 가리키는지, artifact path가 `app/build/...`로 잡히는지 확인.
- **치환 엔진(.sh/.ps1 동등)**: resolver 디스패처 추가 후 CLAUDE.md의 integrator 검증법(Docker PowerShell `Parser::ParseFile` / expect TTY)으로 문법·동작 확인. `bash -n` 통과 + 모노레포·Spring 픽스처에서 `.sh`와 `.ps1` 치환 결과가 동일한지 대조.
- **런타임 version.yml 미의존 확인**: 워크플로우 run 로그에 `version_manager.sh get-path` 류 호출이 없어야 함(값은 env에 박혀 있음).

### 9-5. 모노레포 대응 비범위
- `version_manager.sh`에 `get-path` CLI 서브커맨드 추가는 **하지 않는다**(런타임 읽기 폐기로 불필요). 경로 확정은 integrator의 `resolve_project_paths` + `@wizard auto:flutter-root` resolver로 충분.
- 기존 `# @wizard paths-anchor`(`on.push.paths` 주입)는 **유지** — env 치환 디스패처와 별개 기능이라 이번 마이그레이션 대상 아님.
- Firebase/Test-APK/Test-TestFlight/Synology 등 **다른 Flutter 워크플로우**의 경로 변수화는 이번엔 PlayStore/TestFlight 2개만. 동일 패턴이라 후속 확장 용이(별도 정리).
- `project_paths`에 키가 여러 개(멀티타입)여도 이번엔 `flutter`만 사용.
