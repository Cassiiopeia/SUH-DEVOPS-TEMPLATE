# Flutter CI/CD — 스토어 "업데이트 심사 제출" 자동화 (옵션) 설계

- 작성일: 2026-06-19
- 대상 레포: `suh-github-template` (SUH-DEVOPS-TEMPLATE)
- 관련 RomRom-FE 이슈: #155, #158, #300, **#322**, #446, #542/#917, **#658**, #729, #735

---

## 1. 배경 — 이건 "신규 발명"이 아니라 "검증된 구현의 역류(backport)"다

이 작업의 본질은 새 기능을 발명하는 게 아니다. **RomRom-FE에서 이미 다 겪고 풀어놓은 자동화를, 템플릿(`suh-github-template`)으로 끌어올려 옵션으로 일반화**하는 것이다.

RomRom-FE의 실제 이력(전수조사 결과):

- **#300**: Android Play Store 내부 테스트 자동 배포 시작
- **#322**: 첫 출시 전 **"Draft App" 제약**에 부딪힘. Google Play API로는 미출시 앱을 `completed`로 자동 출시할 수 없음. 우회하려고 **Playwright로 Play Console 버튼을 자동 클릭**하는 것까지 시도(`test-playstore-automation.yaml` + `automate_playstore_playwright.py`, `GOOGLE_EMAIL`/`GOOGLE_PASSWORD` secret). 셀레니움 → 크롬드라이버 버전 충돌 → Playwright 교체… 가장 고생한 구간.
- **#658**: 결국 **"첫 출시는 어차피 수동, 그 이후부터는 fastlane으로 완전 자동"** 으로 깔끔하게 결론. `release_status: 'draft' → 'completed'` 전환 + `promote_internal_to_production` lane(= Google 심사 자동 요청)으로 정리됨.

**결론: 첫 정식 출시 1회는 콘솔에서 수동으로 한다. 그 이후 모든 업데이트의 심사 제출은 fastlane으로 자동화한다.** 브라우저 자동화(Playwright)는 막다른 길이었고, 채택하지 않는다.

### 핵심 발견 — 템플릿이 RomRom보다 뒤처져 있고, 마법사 내부도 불일치

| 위치 | 현재 상태 |
|------|-----------|
| RomRom-FE `android/fastlane/Fastfile.playstore` (운영본) | ✅ `completed` + `promote_internal_to_production` (심사 자동 요청) |
| 템플릿 `playstore-wizard-apply.sh` (인라인 생성) | ⚠️ `release_status: "completed"`이나 **promote lane 없음** |
| 템플릿 `playstore-wizard/templates/Fastfile.playstore.template` | ❌ `release_status: "draft"` (구버전, promote lane 없음) |
| 템플릿 워크플로우 `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | ❌ `deploy_internal`만 호출 (internal 트랙까지만) |
| 템플릿 iOS `testflight-wizard/templates/Fastfile` | ❌ `upload_testflight`만 (App Store 심사 제출 lane 없음) |

→ **마법사 안에서조차 "인라인 생성 코드"와 "templates/*.template"이 불일치**한다(하나는 completed, 하나는 draft). 이 불일치 해소도 본 작업에 포함한다. 두 산출 경로를 **single source**로 일치시킨다.

---

## 2. 목표와 비목표

### 목표
1. **이미 1회 정식 출시된 앱**의 업데이트에 대해, Android Production 심사 제출 / iOS App Store 심사 제출을 **옵션으로** 자동화.
2. 옵션은 **마법사에서 질문**하고, 그 답에 따라 **Fastfile + 워크플로우 env를 함께 생성**한다.
3. **기본값은 기존 동작 그대로** — 옵션을 켜지 않은 기존 사용자/레포는 영향 0(internal-only / TestFlight-only).
4. 확장성: track(internal/alpha/beta/production)·rollout·submit 여부를 입력값/주석 힌트로 노출.

### 비목표 (YAGNI)
- **첫 출시(앱 최초 등록·메타데이터·스크린샷·심사정보 입력) 자동화 안 함.** 콘솔 수동.
- **Playwright/브라우저 자동화 부활 안 함.** #322에서 막다른 길로 판명.
- iOS 메타데이터·스크린샷·키워드 자동 업로드 안 함 (덮어쓰기 사고 위험). What's New만 갱신.
- Android 단계적 rollout(%)을 기본값으로 강제하지 않음. 기본 100% 전면, 비율은 입력으로만.

---

## 3. 설계 결정 (확정)

| 항목 | 결정 | 근거 |
|------|------|------|
| 범위 | 이미 1회 출시된 앱의 **업데이트 심사 제출** | #658 결론과 일치 |
| 기본값 | 기존 동작 유지 (Android internal-only / iOS TestFlight-only) | 하위호환·기존 사용자 영향 0 |
| iOS 메타데이터 | 건드리지 않음 (`skip_metadata`/`skip_screenshots`), What's New만 | 콘솔 입력값 보호 |
| Android 출시 | 100% 전면 (`rollout: '1.0'`), `internal(completed) → promote production` | RomRom 운영본과 동일 |
| 스위치 위치 | **마법사 질문 → Fastfile + 워크플로우 env 동시 생성** | Fastfile은 마법사가 찍어내는 구조 |
| Hint | 마법사 질문 안내 + 워크플로우 env 주석 + 실행 시 경고 로그 | "최초 1회 수동 출시 필요" 함정 방지 |
| 확장성 | track/rollout/submit를 env·마법사 입력으로 | 향후 alpha/beta 단계 출시 확장 여지 |

---

## 4. 컴포넌트별 변경 설계

전체는 4개 영역이며 각 영역은 독립적으로 이해·검증 가능하다.

### 4.1 Android Fastfile (single source) — `playstore-wizard`

**대상:**
- `playstore-wizard/templates/Fastfile.playstore.template`
- `playstore-wizard-apply.sh` (인라인 생성 부분)
- `playstore-wizard-apply.ps1` (인라인 생성 부분)
- `playstore-wizard-setup.sh` / `.ps1` (인라인 생성 부분)

**해야 할 일:** 위 모든 생성 경로가 **동일한 Fastfile 내용**을 찍도록 통일하고, RomRom 운영본 수준으로 lane을 보강한다.

생성되는 Fastfile.playstore의 lane 구성(목표):

| lane | 동작 | 조건 |
|------|------|------|
| `deploy_internal` | internal 트랙 업로드 (`release_status` = 마법사 답에 따라 draft/completed) | 항상 |
| `promote_internal_to_production` | internal → production 승급 = **Google 심사 자동 요청** (`rollout: '1.0'`) | 심사 자동 제출 옵션 ON일 때만 호출 |
| `validate` | Service Account JSON 검증 | 유지 |
| `promote_to_alpha`/`beta`/`production` | 단계 승급 (확장용) | 유지 |

- `release_status`는 **마법사 질문 "이미 정식 출시된 앱입니까?"** 의 답으로 결정:
  - 아니오(미출시) → `'draft'` + promote 호출 안 함 + 경고 주석
  - 예(출시됨) → `'completed'`, 심사 자동 제출 옵션이 ON이면 promote lane까지
- `package_name`은 기존 `{{APPLICATION_ID}}` / `${APP_ID}` 치환 방식 유지.

### 4.2 iOS Fastfile — `testflight-wizard`

**대상:** `testflight-wizard/templates/Fastfile` (+ setup 스크립트가 생성/복사하는 경로)

**해야 할 일:** 기존 `upload_testflight` lane은 그대로 두고, **`submit_review` lane을 신규 추가**한다.

`submit_review` lane 설계:
- `upload_to_app_store` (deliver) 사용
- `skip_metadata: true`, `skip_screenshots: true` — 콘솔 입력값 보호 (설계 결정)
- `submit_for_review: true`
- What's New(release notes)만 `release_notes`로 전달 (ko / en-US)
- `automatic_release: ?` — 심사 통과 후 자동 출시 여부는 **비목표**이므로 수동(`false`) 기본. (env로 열어둘 수 있으나 기본 off)
- API Key는 기존 `app_store_connect_api_key` 방식 재사용

### 4.3 마법사 UI/스크립트 — 질문 추가

**대상:** `playstore-wizard.html/.js`, `testflight-wizard.html/.js`, 각 `*-setup.sh/.ps1`, `*-apply.sh/.ps1`

**해야 할 일:** 설정 단계에 다음 질문을 추가하고, 답을 Fastfile 생성과 워크플로우 env 치환에 반영.

공통 질문(양 마법사):
1. **"이 앱이 이미 스토어에 정식 출시(최소 1회)되었습니까?"** (예/아니오)
   - 아니오 → 심사 자동 제출 질문 자체를 비활성(skip)하고, "최초 1회는 콘솔에서 수동 출시해야 합니다" 안내.
2. **"업데이트마다 스토어 심사를 자동으로 제출할까요?"** (예/아니오, 1의 답이 '예'일 때만)
   - Android: 예 → `deploy_internal` 후 `promote_internal_to_production` 호출 + 워크플로우 env `PLAY_SUBMIT_FOR_REVIEW=true`
   - iOS: 예 → `upload_testflight` 후 `submit_review` 호출 + 워크플로우 env `IOS_SUBMIT_FOR_REVIEW=true`

(확장 입력은 선택; 기본 track=internal/production, rollout=1.0)

- 마법사 안내 톤은 기존 마법사 통일 톤(#376)을 따른다.
- 중복 Y/N 방지(#381) 등 기존 마법사 규약 준수.

### 4.4 워크플로우 — env 옵션 + 힌트 주석 + 조건부 lane 호출

**대상:**
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`
- (공통 워크플로우 규약상 `project-types/`가 원본. 루트 `.github/workflows/`에 같은 파일이 있으면 동일 유지 — 단, 이 두 파일은 타입별이라 루트 미러 불필요. 작업 시 실제 확인.)

**Android env (예시 — placeholder + @wizard 힌트):**
```yaml
env:
  # 스토어 심사 자동 제출: internal 업로드 후 production 트랙으로 승급(=Google 심사 요청)
  #   ⚠️ 최초 1회 정식 출시가 완료된(Published) 앱에서만 동작합니다.
  #      미출시(Draft) 앱은 false로 두고, Play Console에서 첫 출시를 수동으로 완료하세요.
  PLAY_SUBMIT_FOR_REVIEW: "__PLAY_SUBMIT_FOR_REVIEW__"  # @wizard ask: 업데이트 심사 자동 제출 [기본: false]
```

**iOS env:**
```yaml
env:
  # TestFlight 업로드 후 App Store 정식 심사까지 제출할지
  #   ⚠️ 메타데이터·스크린샷은 건드리지 않고 빌드+릴리스노트만 갱신해 심사 제출합니다.
  IOS_SUBMIT_FOR_REVIEW: "__IOS_SUBMIT_FOR_REVIEW__"  # @wizard ask: App Store 심사 자동 제출 [기본: false]
```

**조건부 lane 호출(배포 step):**
```bash
cd android
bundle exec fastlane deploy_internal
if [ "${PLAY_SUBMIT_FOR_REVIEW}" = "true" ]; then
  echo "⚠️ production 승급(심사 제출)은 최초 출시가 완료된 앱에서만 동작합니다."
  bundle exec fastlane promote_internal_to_production
fi
```
(iOS도 `upload_testflight` 후 `IOS_SUBMIT_FOR_REVIEW=true`면 `submit_review` 호출, 동일 패턴)

**불변식 — 실행 로직 무손상:** env 추가와 조건부 호출 외에 기존 `run:`/`uses:`/`with:`/빌드 step은 한 줄도 바꾸지 않는다. CLAUDE.md의 "토큰화·치환만 한 경우 git diff 자가검증" 규칙을 적용한다.

---

## 5. 데이터 흐름

```
[사용자] 마법사 실행
  └─> Q1 "정식 출시됨?"  Q2 "심사 자동 제출?"
        │
        ├─> Fastfile 생성 (release_status / promote·submit lane 포함 여부 결정)
        └─> 워크플로우 env 치환 (__PLAY_SUBMIT_FOR_REVIEW__ / __IOS_SUBMIT_FOR_REVIEW__)
                │
        [deploy 브랜치 push / CHANGELOG 완료]
                │
        워크플로우 실행
          ├─ build (기존 그대로)
          └─ deploy step
               ├─ fastlane deploy_internal / upload_testflight   (항상)
               └─ if SUBMIT_FOR_REVIEW == true:
                    fastlane promote_internal_to_production / submit_review  (심사 제출)
```

---

## 6. 하위호환 / 안전장치

1. **기본값 false** → 옵션 미설정 시 기존 동작과 100% 동일. 기존 RomRom·passQL 등 영향 없음.
2. **3중 힌트**: 마법사 질문 안내 + 워크플로우 env 주석(⚠️) + 실행 시 경고 로그. "최초 1회 수동" 함정을 세 곳에서 알린다.
3. **iOS 메타데이터 보호**: `skip_metadata/skip_screenshots`로 콘솔 입력값 덮어쓰기 원천 차단.
4. **마법사 single source 일치**: 인라인 생성 코드와 `templates/*.template`을 동일 내용으로 통일(현 불일치 해소).

---

## 7. 검증 계획

- **Android Fastfile**: RomRom-FE 운영본 `android/fastlane/Fastfile.playstore`와 lane 시그니처 대조(검증 기준 레포).
- **워크플로우 YAML**: 로컬 파서(actionlint 등) 빨간불을 곧바로 신뢰하지 않는다(CLAUDE.md 규칙). 실행 로직 미변경을 `git diff`로 자가검증.
- **마법사 스크립트**: `bash -n` + (`.ps1`) PowerShell 파서. setup/apply의 입력 주입 동작은 CLAUDE.md "template_integrator 검증법"에 준해 함수 격리 + 입력 주입으로 확인.
- **기본값 회귀**: 옵션 off로 생성 시 기존 Fastfile/워크플로우와 동등한지 비교.

---

## 8. 작업 분해 (writing-plans 입력용 개요)

1. Android Fastfile single source 통일 + `completed`/`promote_internal_to_production` 보강
2. iOS Fastfile `submit_review` lane 추가 (메타 skip)
3. 마법사(playstore/testflight) 질문 2개 추가 + Fastfile·env 치환 반영
4. 워크플로우 2종 env placeholder + 힌트 주석 + 조건부 lane 호출 step
5. 회귀·대조 검증 (RomRom 운영본 기준)

> 멀티타입/모노레포 고려: 본 변경은 Flutter 타입 한정. `project_paths` 등 다른 타입 경로에 영향 없음.
