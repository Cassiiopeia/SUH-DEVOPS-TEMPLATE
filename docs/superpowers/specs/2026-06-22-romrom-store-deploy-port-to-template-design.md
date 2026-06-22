# RomRom-FE 스토어 배포 개선 → SUH-DEVOPS-TEMPLATE 포팅 설계

- 작성일: 2026-06-22
- 관련 이슈(RomRom-FE): #930(Android/PlayStore 거짓 성공 제거), #931(iOS/AppStore 심사 자동 제출 누락), #934(배포 모드 3단계 통일), #935(마법사·Fastfile 가이드 명확화)
- 관련 템플릿 이슈: SUH-DEVOPS-TEMPLATE #399
- 선행 스펙: `2026-06-19-flutter-store-review-submit-automation-design.md`, `2026-06-19-playstore-review-submit-root-cause.md`

## 1. 목표 (한 줄)

RomRom-FE에서 **실측 검증 완료된** Flutter 스토어 배포 개선(iOS 심사 자동 제출 + Android 거짓 성공 제거 + 배포 모드 3단계 통일 + 마법사 안내 강화)을 SUH-DEVOPS-TEMPLATE의 대응 파일에 **1:1로 포팅**한다. 검증 안 된 새 아이디어는 추가하지 않는다.

> **실측 근거**: iOS 1.10.104가 실제 App Store 심사 큐(`Waiting for Review`) 자동 진입, Android 1.10.101 production "검토 중" 진입 검증 완료 (RomRom-FE #934 본문).

## 2. 범위 결정 사항 (확정)

| 결정 | 값 |
|------|-----|
| 작업 성격 | 검증된 것만 1:1 이식 (구조 개선·신규 아이디어 추가 금지) |
| iOS 포팅 방식 | **RomRom 운영 구조 그대로** — 템플릿 iOS 워크플로우도 heredoc으로 Fastfile을 동적 생성하도록 전환하고, deploy_mode input·env·deliver 로직을 RomRom 운영본과 100% 동일하게 이식. 마법사 Fastfile 템플릿도 같은 로직으로 동기화 |
| 소스 오브 트루스 | RomRom-FE의 최종(HEAD) 파일 |

## 3. 배포 모드 3단계 (양 플랫폼 통일 — 이식 대상의 핵심)

| 모드(공통) | iOS 별칭 | Android 동작 | iOS 동작 |
|-----------|----------|-------------|----------|
| `store_only` | `testflight_only` | internal 트랙 업로드까지만 | TestFlight 업로드까지만 |
| `store_prepare` | `appstore_prepare` | production `draft` 승급(콘솔에서 "출시 시작" 대기) | ASC 버전 생성·빌드 선택·whatsNew 채움(제출 직전) |
| `store_submit` | `appstore_submit` | production `completed` 승급(Google 심사 자동 등록) | deliver `submit_for_review`로 심사 자동 제출 |

- Fastlane lane은 공통 네이밍과 iOS 별칭을 **둘 다** 인식한다(`["store_prepare","store_submit","appstore_prepare","appstore_submit"].include?`).
- 폴백 기본값: 신규 앱 안전을 위해 `store_only`/`testflight_only`.
- repo variable로 운영 앱은 `ANDROID_DEPLOY_MODE`/`IOS_DEPLOY_MODE`를 지정.

## 4. 거짓 성공 제거 (검증된 근본 원인 수정)

- **Android**: `promote_internal_to_production` lane의 `upload_to_play_store`에
  `track_promote_release_status: status`(completed|draft) + `changes_not_sent_for_review: false` + `rescue_changes_not_sent_for_review: false`.
  fastlane supply 기본값 `rescue_changes_not_sent_for_review: true`가 심사 미전송을 자동 rescue해 저장만 하고 success를 반환하던 "거짓 성공"을 차단.
- **iOS**: 워크플로우의 `|| echo "...성공..."` 거짓 성공 라인 제거(이미 RomRom 운영본에 반영됨). deliver 실패가 정직하게 빨간불로 표면화.

## 5. 포팅 대상 파일 (소스 → 대상 매핑)

> 경로 접두사: RomRom = `RomRom-FE/`, 템플릿 = `suh-github-template/`. 파일명 차이(`ROMROM-*` → `PROJECT-FLUTTER-*`)에 주의.

| # | 대상(템플릿) | 소스(RomRom) | 포팅 내용 | 현재 템플릿 상태 |
|---|--------------|--------------|-----------|------------------|
| 1 | `.github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template` | 동일 경로 | 파일 전체 교체 | `release_status:"draft"` 고정·rescue 옵션 없음·옛 `promote_to_beta/production` 구조 |
| 2 | `.github/util/flutter/testflight-wizard/templates/Fastfile` | 동일 경로 | 파일 전체 교체(`deploy` 통합 lane + deliver) | `deploy` lane 없음·deliver 전무 |
| 3 | `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | `.github/workflows/ROMROM-IOS-TESTFLIGHT.yaml` | heredoc Fastfile 동적생성 + deploy_mode input + DEPLOY_MODE/APP_IDENTIFIER/APP_VERSION/BUILD_NUMBER env + `fastlane deploy_appstore` 호출 | deploy_mode input 없음·env 3개·`upload_testflight` 호출 |
| 4 | `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | `.github/workflows/ROMROM-ANDROID-PLAYSTORE-CICD.yaml` | deploy_mode input + `DEPLOY_MODE` env 전달 추가 | input 없음·DEPLOY_MODE 미전달 |
| 5 | `.github/util/flutter/testflight-wizard/testflight-wizard.html` | 동일 경로 | 완료단계 "배포 모드 & 출시 로드맵" 안내카드 | 안내카드 없음 |
| 6 | `.github/util/flutter/playstore-wizard/playstore-wizard.html` | 동일 경로 | 완료단계 배포 모드 안내카드 | 안내카드 없음 |
| 7 | `.github/util/flutter/playstore-wizard/playstore-wizard.js` / `-setup.sh` / `-setup.ps1` | 동일 경로 | RomRom 변경분 동기화(안내 문구) | 대조 후 차이만 반영 |
| 8 | `.github/util/flutter/testflight-wizard/testflight-wizard-setup.sh` | 동일 경로 | RomRom 변경분 동기화(안내 문구) | 대조 후 차이만 반영 |
| 9 | `.github/util/flutter/testflight-wizard/templates/Gemfile` | 동일 경로 | 줄바꿈(EOL) 외 내용 동일 — 차이 없으면 스킵 | 내용 동일(EOL 차이만) |

### 토큰 치환 주의 (템플릿 ↔ RomRom 차이)
- RomRom은 `com.alom.romrom` 등 **실값 하드코딩**. 템플릿 파일은 `{{APPLICATION_ID}}` 같은 **플레이스홀더**를 유지해야 한다.
- 포팅 시 **배포 로직(lane/옵션/env)만** 가져오고, 패키지명·Bundle ID·앱 식별자는 템플릿의 플레이스홀더로 되돌린다. iOS 워크플로우 heredoc 내 `app_id = ENV["APP_IDENTIFIER"] || "com.alom.romrom"`의 폴백은 템플릿 정책에 맞게 처리.
- `git diff`로 `run:`/`uses:`/`with:` 등 실행 로직 외 RomRom 고유값이 섞여 들어가지 않았는지 자가검증.

## 6. 공통 워크플로우 동기화 규칙 — 적용 여부

- CLAUDE.md 규칙: **공통** 워크플로우는 `project-types/common/` 원본과 `.github/workflows/` 루트 복사본을 동일하게 유지.
- 본 작업 대상(IOS-TESTFLIGHT, ANDROID-PLAYSTORE)은 **타입별(flutter) 워크플로우**이며 루트 복사본이 존재하지 않음(확인됨). → **두 곳 동기화 규칙 비적용.** `project-types/flutter/`만 수정한다.

## 7. 검증 전략 (포팅 후)

YAML은 로컬 파서 빨간불을 GitHub 실제 동작으로 착각하지 않는다(CLAUDE.md 규칙). 검증 순서:
1. **기준 대조**: 포팅 후 템플릿 파일 ↔ RomRom 운영본을 `diff`해 로직 라인이 동일한지(플레이스홀더·앱고유값 제외) 확인. RomRom은 실제 success 이력이 있는 "잘 작동하는 기준 레포".
2. **문법 확인**: Fastfile(Ruby) 문법, 워크플로우 YAML은 GitHub success 이력 있는 RomRom과 동형이면 통과로 본다.
3. **마법사 HTML**: 브라우저 렌더 깨짐 없는지 구조만 확인.
4. 실제 스토어 배포 검증은 사용자 별도 환경(RomRom에서 이미 완료).

## 8. 비범위 (YAGNI)

- 새 배포 모드·새 lane·배포 후 API 폴링 검증 같은 **RomRom에 없는 신규 기능**은 추가하지 않는다.
- 테스트 빌드 워크플로우(`*-TEST-APK`, `*-TEST-TESTFLIGHT`)는 이번 배포개선과 무관(RomRom도 미변경) → 손대지 않는다.
- `template_initializer.sh`/`template_integrator.*`의 제외목록은 이 파일들이 모두 **사용자 프로젝트로 가야 하는 공통 자산**이므로 수정 불필요.
