# Flutter RomRom 스토어 배포 포팅 + 모노레포 경로 대응 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RomRom-FE에서 실측 검증된 Flutter 스토어 배포 로직(iOS App Store 심사 자동 제출·Android 거짓성공 제거·배포모드 3단계·iOS 파일템플릿 통일)을 SUH-DEVOPS-TEMPLATE에 포팅하고, 모노레포(Flutter 루트가 서브폴더)에서 CICD가 깨지지 않도록 워크플로우 경로를 `FLUTTER_ROOT`로 변수화한다.

**Architecture:** (A) 배포 로직 포팅 — iOS는 RomRom 워크플로우 heredoc(`deploy_appstore` lane)을 템플릿의 `Fastfile.ios.template` 파일로 옮겨 Android와 동일한 "마법사가 깐 파일 = 도는 파일" 구조로 통일하고, 워크플로우 호출을 `fastlane deploy`로 바꾼다. Android는 `Fastfile.playstore.template`에 RomRom의 `deploy_internal`/`promote_internal_to_production` lane(거짓성공 차단 옵션 포함)을 이식한다. 양 플랫폼에 `deploy_mode` workflow_dispatch input + `DEPLOY_MODE` env를 추가한다. (B) 모노레포 — 두 워크플로우의 빌드/배포 job에 `defaults.run.working-directory: ${{ env.FLUTTER_ROOT }}`를 두고, working-directory가 안 먹는 곳(artifact `path:`·`$GITHUB_WORKSPACE` 절대경로)만 개별 변수화한다. `FLUTTER_ROOT`는 선행 완료된 wizard 마커 시스템(#406) 위에 `auto:flutter-root` resolver로 통합 시점 1회 치환한다.

**Tech Stack:** GitHub Actions YAML, fastlane (Ruby: pilot/deliver/upload_to_play_store), Bash/PowerShell 마법사 스크립트, template_integrator 마커 치환.

## Global Constraints

- 정본 스펙: `docs/superpowers/specs/2026-06-22-romrom-store-deploy-port-to-template-design.md` (모든 Task는 이 스펙을 따른다). 흡수 스펙: `2026-06-19-flutter-store-review-submit-automation-design.md`(superseded).
- 포팅 소스 = `D:/0-suh/project/RomRom-FE` 메인 HEAD(a45e3e3, 2026-06-22). 검증 기준 레포는 RomRom-FE(실측 success). **passQL은 신뢰 기준 아님.**
- 대상 워크플로우 2개는 **타입별(flutter)** 워크플로우 → `.github/workflows/project-types/flutter/`만 수정. `.github/workflows/` 루트 복사본 없음(동기화 규칙 비적용).
- 포팅 시 **배포 로직(lane/옵션/env)만** 가져온다. RomRom 고유 하드코딩(`com.alom.romrom`, `ROMROM-`)은 템플릿 정책(`{{APPLICATION_ID}}`(Android) / ENV 기반(iOS))으로 되돌린다. `git diff`로 RomRom 고유값 혼입 자가검증.
- iOS lane명은 `deploy`로 확정(RomRom은 `deploy_appstore`였으나 템플릿은 `deploy`). Android lane명은 RomRom과 동일(`deploy_internal`/`promote_internal_to_production`).
- 배포 모드 3단계 공통 네이밍 `store_only`/`store_prepare`/`store_submit` + iOS 하위호환 별칭 `testflight_only`/`appstore_prepare`/`appstore_submit`(양쪽 Fastlane이 둘 다 인식). 우선순위: workflow_dispatch `deploy_mode` input → repo variable(`ANDROID_DEPLOY_MODE`/`IOS_DEPLOY_MODE`) → 폴백(`store_only`/`testflight_only`).
- `FLUTTER_ROOT` 기본값(폴백) `"."`. 통합 미경유 시 단일레포로 안전 동작. 기본값 `.`일 때 현재 단일레포 동작 100% 보존이 회귀 검증의 1순위.
- YAML 로컬 파서(actionlint/psych/pyyaml) 빨간불을 GitHub 실제 동작으로 착각하지 않는다. 검증은 "RomRom 운영본과의 로직 동형 대조"를 1순위로.
- 커밋 메시지에 이모지·태그 prefix 금지(`🚀[기능개선]` 등). 커밋은 사용자가 컨벤션을 줄 때만 실행 — 이 계획의 commit step은 컨벤션이 주어진 전제에서의 형식 예시이며, 컨벤션 미제공 시 commit은 보류한다.

---

## 파일 구조 (생성/수정 대상)

| 파일 | 책임 | 작업 |
|------|------|------|
| `.github/util/flutter/testflight-wizard/templates/Fastfile` → `Fastfile.ios.template` | iOS 배포 lane(`deploy`: pilot+deliver+whatsNew+Notes초기화) | 개명 + 내용 교체 (Task 1) |
| `.github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template` | Android 배포 lane(거짓성공 차단 + store_* 3단계) | 내용 교체 (Task 2) |
| `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | iOS CICD | deploy_mode input + env + `fastlane deploy` 호출 (Task 3) |
| `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | Android CICD | deploy_mode input + DEPLOY_MODE env 전달 (Task 4) |
| `.github/util/flutter/testflight-wizard/testflight-wizard-setup.sh` | iOS 마법사 셋업 | 템플릿 참조 경로 `.ios.template`로 변경 + DEPLOY_MODE 안내 (Task 5) |
| `.github/util/flutter/playstore-wizard/playstore-wizard-setup.sh` / `.ps1` | Android 마법사 셋업 | ANDROID_DEPLOY_MODE 안내 동기화(.sh/.ps1 동등) (Task 5) |
| `.github/util/flutter/{testflight,playstore}-wizard/*.html` | 마법사 완료 안내 | 배포 모드·출시 로드맵 안내카드 (Task 6) |
| `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | iOS 경로 변수화 | FLUTTER_ROOT env + working-directory + 11곳 (Task 7) |
| `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | Android 경로 변수화 | FLUTTER_ROOT env + working-directory + 23곳 (Task 8) |
| `template_integrator.sh` / `.ps1` | 통합 시 경로 주입 | `resolve_flutter_root`/`Resolve-FlutterRoot` resolver (Task 9) |

---

## Task 1: iOS Fastfile 개명 + `deploy` 통합 lane 작성

**Files:**
- Rename: `.github/util/flutter/testflight-wizard/templates/Fastfile` → `.github/util/flutter/testflight-wizard/templates/Fastfile.ios.template`
- Modify(=교체 후): `.github/util/flutter/testflight-wizard/templates/Fastfile.ios.template`

**Interfaces:**
- Produces: lane명 `deploy`. 인식 env: `DEPLOY_MODE`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `API_KEY_PATH`, `APP_IDENTIFIER`, `IPA_PATH`, `RELEASE_NOTES`, `APP_VERSION`, `BUILD_NUMBER`, `DELIVER_LOCALES`(기본 `ko`), `GITHUB_WORKSPACE`. → Task 3(워크플로우)·Task 5(셋업 스크립트)가 이 lane명·env를 소비.
- Consumes: 없음(소스 = RomRom heredoc).

**배경:** 현재 `templates/Fastfile`(126줄)은 `upload_testflight`(34~76)·`build_and_deploy`(79~124) lane만 있고 deliver/submit 전무. RomRom은 워크플로우 heredoc(`ROMROM-IOS-TESTFLIGHT.yaml` 442~569)에 `deploy_appstore` lane으로 pilot+deliver를 갖고 있다. 이 lane 내용을 lane명 `deploy`로, Bundle ID 하드코딩을 ENV 기반으로 바꿔 템플릿 파일로 옮긴다.

- [ ] **Step 1: git mv로 개명**

```bash
cd "D:/0-suh/project/suh-github-template"
git mv .github/util/flutter/testflight-wizard/templates/Fastfile \
       .github/util/flutter/testflight-wizard/templates/Fastfile.ios.template
```

- [ ] **Step 2: 개명된 파일 내용을 전면 교체**

`.github/util/flutter/testflight-wizard/templates/Fastfile.ios.template` 전체를 아래로 교체한다. (RomRom `deploy_appstore` lane 442~569의 로직 1:1 이식, lane명 `deploy`, `app_id` 폴백을 RomRom 하드코딩 `com.alom.romrom` 제거 → ENV 필수.)

```ruby
# ============================================================
# iOS Fastfile (TestFlight 업로드 + App Store 심사 자동 제출)
# ============================================================
# ★ 이 파일은 마법사(testflight-wizard-setup.sh)가 ios/fastlane/Fastfile 로 깔며,
#   GitHub Actions 워크플로우(PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml)가 그대로 실행합니다.
#   (Android의 Fastfile.playstore 와 동일한 "깐 파일 = 도는 파일" 구조)
#
# 배포 모드(DEPLOY_MODE) — 공통 네이밍 + iOS 하위호환 별칭 둘 다 인식:
#   store_only    (= testflight_only, 기본) : TestFlight 업로드까지만
#   store_prepare (= appstore_prepare)       : TestFlight + ASC 버전 생성·빌드 선택·What's New 채움(제출 직전)
#   store_submit  (= appstore_submit)        : 위 전부 + 심사 자동 제출(submit_for_review)
#
# ⚠️ 신규 앱은 최초 1회 App Store Connect에서 수동 제출이 필요합니다.
#   그 이후 업데이트부터 store_submit으로 완전 자동 제출됩니다.
# ============================================================
default_platform(:ios)

platform :ios do
  desc "TestFlight 업로드 (+ DEPLOY_MODE=store_submit이면 App Store 심사 자동 제출)"
  lane :deploy do
    api_key = app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_filepath: ENV["API_KEY_PATH"]
    )

    app_id = ENV["APP_IDENTIFIER"]
    UI.user_error!("APP_IDENTIFIER(번들 ID) 환경변수가 필요합니다.") if app_id.nil? || app_id.strip.empty?

    deploy_mode = (ENV["DEPLOY_MODE"] || "testflight_only").strip
    prepare_appstore = ["appstore_prepare", "appstore_submit", "store_prepare", "store_submit"].include?(deploy_mode)
    submit_to_appstore = ["appstore_submit", "store_submit"].include?(deploy_mode)
    UI.message("🎛️  배포 모드: #{deploy_mode} (ASC 버전 준비: #{prepare_appstore} / 심사 자동제출: #{submit_to_appstore})")

    # 1) TestFlight 업로드 (항상 수행). ASC 준비/제출 모드면 빌드 처리 완료까지 대기.
    #    ⚠️ Apple Processing(빌드 처리)은 보통 5~15분, 때때로 1시간+ (Apple 서버 사정, 통제 불가).
    #       store_prepare/store_submit은 이 대기에 종속된다. 급할 땐 store_only.
    pilot(
      api_key: api_key,
      app_identifier: app_id,
      ipa: ENV["IPA_PATH"],
      changelog: ENV["RELEASE_NOTES"],
      skip_waiting_for_build_processing: !prepare_appstore,
      distribute_external: false,
      notify_external_testers: false,
      uses_non_exempt_encryption: false
    )
    puts "✅ TESTFLIGHT 업로드 완료!"

    # 2) App Store 버전 준비 (+ store_submit이면 심사 자동 제출)
    if prepare_appstore
      app_ver = ENV["APP_VERSION"]
      release_notes = (ENV["RELEASE_NOTES"] || "버그를 수정하고 안정성을 개선했습니다.").strip
      release_notes = "버그를 수정하고 안정성을 개선했습니다." if release_notes.empty?

      # whatsNew 메타를 절대경로로 생성 (상대경로는 fastlane CWD와 어긋나 공란 → 제출 거부).
      # release_notes.txt만 만들고 다른 메타는 안 만듦 → ASC 기존 메타(설명/키워드 등) 보존.
      workspace = ENV["GITHUB_WORKSPACE"] || Dir.pwd
      metadata_path = File.join(workspace, "ios", "fastlane", "metadata")
      require "fileutils"
      # ⚠️ 로케일 디렉토리명은 deliver가 인정하는 코드만 (ko 유효, ko-KR 무효).
      locales = (ENV["DELIVER_LOCALES"] || "ko").split(",").map(&:strip).reject(&:empty?)
      locales.each do |loc|
        dir = File.join(metadata_path, loc)
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "release_notes.txt"), release_notes)
      end
      UI.message("📝 whatsNew 메타 작성: #{release_notes}")

      # 심사 메모(Notes) 초기화: 이전 버전 거절 대응 소명서가 자동 승계되는 문제 방지.
      # review_information/notes.txt만 공란으로 → 연락처·데모계정 등 다른 심사정보는 ASC 기존값 보존.
      review_dir = File.join(metadata_path, "review_information")
      FileUtils.mkdir_p(review_dir)
      File.write(File.join(review_dir, "notes.txt"), "")
      UI.message("🧹 심사 Notes 초기화 (review_information/notes.txt 공란)")

      UI.message("📂 metadata_path=#{metadata_path}")

      deliver(
        api_key: api_key,
        app_identifier: app_id,
        app_version: app_ver,
        build_number: ENV["BUILD_NUMBER"],
        submit_for_review: submit_to_appstore,
        automatic_release: submit_to_appstore,
        force: true,
        run_precheck_before_submit: false,
        skip_binary_upload: true,
        skip_metadata: false,
        metadata_path: metadata_path,
        skip_screenshots: true,
        precheck_include_in_app_purchases: false,
        submission_information: {
          add_id_info_uses_idfa: false
        }
      )
      if submit_to_appstore
        puts "✅ APP STORE 심사 자동 제출 완료!"
      else
        puts "✅ APP STORE 버전 준비 완료 (Prepare for Submission) — ASC에서 검토 후 'Add for Review'만 누르면 제출됩니다."
      end
    else
      puts "⏭️  store_only(testflight_only) 모드 — App Store 단계 건너뜀 (TestFlight 업로드만 완료)"
    end
  end
end
```

- [ ] **Step 3: RomRom 고유값 혼입·lane 내용 동형 검증**

```bash
cd "D:/0-suh/project/suh-github-template"
# (a) RomRom 고유 하드코딩이 섞이지 않았는지
grep -nE "com\.alom\.romrom|ROMROM" .github/util/flutter/testflight-wizard/templates/Fastfile.ios.template || echo "✅ RomRom 고유값 없음"
# (b) lane명·핵심 옵션 존재
grep -nE "lane :deploy do|submit_for_review|deliver\(|pilot\(|review_information" .github/util/flutter/testflight-wizard/templates/Fastfile.ios.template
```
Expected: (a) "✅ RomRom 고유값 없음", (b) `lane :deploy do`·`submit_for_review`·`deliver(`·`pilot(`·`review_information` 모두 매칭.

- [ ] **Step 4: Ruby 문법 확인(가능 시)**

```bash
ruby -c .github/util/flutter/testflight-wizard/templates/Fastfile.ios.template 2>/dev/null && echo "Syntax OK" || echo "ruby 미설치 — 구조 검토로 갈음(스펙 §7-3)"
```
Expected: `Syntax OK` 또는 ruby 미설치 메시지(둘 다 허용 — 내부망 ruby 부재 가능).

- [ ] **Step 5: Commit** (커밋 컨벤션이 주어진 경우에만)

```bash
git add .github/util/flutter/testflight-wizard/templates/Fastfile.ios.template
git commit -m "iOS Fastfile을 .ios.template로 개명하고 deploy 통합 lane(심사 자동 제출) 추가 : feat : RomRom deploy_appstore lane을 파일 템플릿으로 이식 #399"
```

---

## Task 2: Android Fastfile.playstore.template 거짓성공 제거 + store_* 3단계 이식

**Files:**
- Modify: `.github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template`

**Interfaces:**
- Produces: lane명 `deploy_internal`, `promote_internal_to_production`. 인식 env: `DEPLOY_MODE`(폴백 `store_submit`), `GOOGLE_PLAY_JSON_KEY`. 토큰 `{{APPLICATION_ID}}`. → Task 4(워크플로우)가 `fastlane deploy_internal` 호출 + `DEPLOY_MODE` 전달.
- Consumes: 없음(소스 = RomRom `android/fastlane/Fastfile.playstore`).

**배경:** 현재 template(109줄)은 `release_status:"draft"` 고정, `rescue_changes_not_sent_for_review`·`track_promote_release_status`·`promote_internal_to_production` 전무. RomRom은 거짓성공 차단(`rescue_changes_not_sent_for_review: false`)과 store_* 3단계를 갖춘다. RomRom 운영본을 토큰만 `{{APPLICATION_ID}}`로 바꿔 이식한다.

- [ ] **Step 1: RomRom 소스 확인 (참조)**

```bash
sed -n '1,173p' "D:/0-suh/project/RomRom-FE/android/fastlane/Fastfile.playstore"
```
Expected: `deploy_internal`(24~)·`promote_internal_to_production`(93~) lane, `rescue_changes_not_sent_for_review: false`(113), `track_promote_release_status: status`(103), store_* 분기(34~36) 확인.

- [ ] **Step 2: template 전면 교체**

`.github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template` 전체를 아래로 교체. (RomRom 운영본의 `build_aab`/`deploy_internal`/`promote_internal_to_production`/`validate` lane을, `package_name`을 `{{APPLICATION_ID}}` 토큰으로.)

```ruby
default_platform(:android)

platform :android do
  desc "Build AAB"
  lane :build_aab do
    sh("cd ../.. && flutter build appbundle --release")
  end

  # ============================================================
  # 배포 모드(DEPLOY_MODE):
  #   store_only    : 내부 테스트(internal) 트랙 업로드까지만
  #   store_prepare : internal 업로드 + production에 draft로 승급(콘솔에서 "출시 시작" 대기)
  #   store_submit  : internal 업로드 + production completed 승급(Google 심사 자동 등록) — 완전 자동
  # (구 testflight_only/appstore_prepare/appstore_submit 별칭도 호환)
  #
  # ⚠️ 신규 앱(Draft App)은 release_status: 'completed' 및 프로덕션 자동 승급이 불가합니다.
  #   최초 정식 출시 1회는 Play Console에서 수동으로 하고, 그 이후부터 이 lane으로 자동화됩니다.
  # ============================================================
  desc "Deploy to Play Store (DEPLOY_MODE: store_only | store_prepare | store_submit)"
  lane :deploy_internal do
    aab_path = "../build/app/outputs/bundle/release/app-release.aab"
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"

    deploy_mode = (ENV["DEPLOY_MODE"] || "store_submit").strip
    promote = ["store_prepare", "store_submit", "appstore_prepare", "appstore_submit"].include?(deploy_mode)
    submit = ["store_submit", "appstore_submit"].include?(deploy_mode)

    puts "📦 배포 모드: #{deploy_mode} (프로덕션 승급: #{promote} / 심사 자동등록: #{submit})"

    # 1단계: internal 트랙 업로드
    upload_to_play_store(
      package_name: "{{APPLICATION_ID}}",
      track: "internal",
      aab: aab_path,
      json_key: json_key,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      release_status: 'completed'   # 정식 출시(Published App) 이후 completed로 즉시 배포
    )

    unless promote
      puts "⏭️  store_only 모드 — 프로덕션 승급 건너뜀 (내부 테스트 업로드만 완료)"
      next
    end

    # 2단계: 프로덕션 트랙 승급
    #   store_submit  : completed로 승급 → Google 심사 자동 등록 (완전 자동)
    #   store_prepare : draft로 승급 → Play Console에서 사람이 "출시 시작" 눌러야 심사 진행
    promote_status = submit ? 'completed' : 'draft'
    puts "🚀 2단계: 프로덕션 트랙으로 승급 중... (release_status: #{promote_status})"
    promote_internal_to_production(promote_status: promote_status)
  end

  desc "Promote internal to production"
  lane :promote_internal_to_production do |options|
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"
    status = options[:promote_status] || 'completed'
    #   promote_status: 'completed' → 즉시 심사 등록 (store_submit)
    #   promote_status: 'draft'     → 프로덕션 draft로만 올림, 사람이 콘솔에서 "출시 시작" (store_prepare)
    upload_to_play_store(
      package_name: "{{APPLICATION_ID}}",
      track: "internal",
      track_promote_to: "production",
      track_promote_release_status: status,
      json_key: json_key,
      skip_upload_aab: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      changes_not_sent_for_review: false,        # 변경을 Google 심사로 전송 (기본값이지만 의도 명시)
      rescue_changes_not_sent_for_review: false  # ⚠️ 거짓 성공 차단: 심사 미전송 시 조용히 넘어가지 않고 워크플로우 실패
    )
  end

  desc "Validate Play Store credentials"
  lane :validate do
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"
    validate_play_store_json_key(json_key: json_key)
  end
end
```

> **주의:** `aab_path`·`build_aab`의 `sh("cd ../..")`는 RomRom 운영본 기준이다. Step 3에서 RomRom 실제값과 1:1 대조해 경로가 다르면 RomRom 쪽으로 맞춘다(템플릿 추정 금지 — RomRom이 진실).

- [ ] **Step 3: RomRom 운영본과 로직 동형 대조 + 토큰 검증**

```bash
cd "D:/0-suh/project/suh-github-template"
# RomRom과 의미상 동일한지 핵심 옵션 라인 비교 (플레이스홀더 제외)
echo "=== 템플릿 ==="
grep -nE "rescue_changes_not_sent_for_review|track_promote_release_status|release_status:|track_promote_to|deploy_mode =|promote =|submit =" .github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template
echo "=== RomRom ==="
grep -nE "rescue_changes_not_sent_for_review|track_promote_release_status|release_status:|track_promote_to|deploy_mode =|promote =|submit =" "D:/0-suh/project/RomRom-FE/android/fastlane/Fastfile.playstore"
# 토큰 보존 + RomRom 고유값 미혼입
grep -c "{{APPLICATION_ID}}" .github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template
grep -nE "com\.alom\.romrom" .github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template || echo "✅ RomRom 고유값 없음"
```
Expected: 두 grep의 옵션 라인이 의미상 일치(`rescue_changes_not_sent_for_review: false` 등), `{{APPLICATION_ID}}` ≥ 2회, "✅ RomRom 고유값 없음".

- [ ] **Step 4: Commit** (컨벤션 제공 시)

```bash
git add .github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template
git commit -m "Android Fastfile에 거짓성공 제거·배포모드 3단계 이식 : feat : RomRom deploy_internal/promote lane 포팅 #399"
```

---

## Task 3: iOS 워크플로우 deploy_mode input + env + `fastlane deploy` 호출

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` (input/env/호출 — 라인 70~84 env, 383~391 verify, 401~441 호출)

**Interfaces:**
- Consumes: Task 1의 lane명 `deploy` + env 계약(`DEPLOY_MODE`/`APP_IDENTIFIER`/`APP_VERSION`/`BUILD_NUMBER`/`RELEASE_NOTES`/`DELIVER_LOCALES`).
- Produces: `deploy_mode` workflow_dispatch input, `DEPLOY_MODE` env. → Task 6(HTML 안내)·Task 5(셋업 안내)가 IOS_DEPLOY_MODE repo variable을 참조.

**배경:** 현재 iOS 워크플로우는 workflow_dispatch input 없음, heredoc 없음(마법사가 깐 `ios/fastlane/Fastfile` 검증만, 383~391), 호출이 `fastlane upload_testflight`(441), 호출 step env 3개(402~405). RomRom 호출 step(574~619)의 env 계약을 가져오되, 마법사가 깐 파일(=Task 1 lane `deploy`)을 그대로 쓴다.

- [ ] **Step 1: workflow_dispatch에 deploy_mode input 추가**

워크플로우 상단 `on: workflow_dispatch:`에 input을 추가한다. (현재 input 없음 — `workflow_dispatch:` 빈 블록 또는 inputs 없는 상태. 아래를 inputs로 넣는다.)

```yaml
on:
  workflow_dispatch:
    inputs:
      deploy_mode:
        description: "배포 모드 (store_only=TestFlight까지 / store_prepare=ASC 제출직전 / store_submit=심사 자동제출)"
        required: false
        default: "store_only"
        type: choice
        options:
          - store_only
          - store_prepare
          - store_submit
  # (기존 push/기타 트리거가 있으면 보존)
```

> 실제 파일의 `on:` 블록 원문을 먼저 읽고(기존 push 트리거 등 보존), `workflow_dispatch:` 아래에만 `inputs:`를 삽입한다.

- [ ] **Step 2: 최상위 env에 DEPLOY_MODE 추가**

라인 70~84의 `env:` 블록 끝에 추가:

```yaml
  # ============================================
  # 📝 배포 모드 (store_only | store_prepare | store_submit)
  # ============================================
  DEPLOY_MODE: ${{ github.event.inputs.deploy_mode || vars.IOS_DEPLOY_MODE || 'store_only' }}
```

- [ ] **Step 3: 호출 step을 `fastlane deploy` + env 계약으로 교체**

현재 `Upload to TestFlight` step(401~441, env 402~405, `cd ios`/`fastlane upload_testflight` 440~441)을 아래로 교체. RomRom 호출 step(574~619)의 env export를 가져오되, IPA 검색은 `$GITHUB_WORKSPACE/ios/build/ipa`(Task 7에서 FLUTTER_ROOT로 변수화).

```yaml
      - name: Upload to TestFlight (+ App Store Submit if store_submit)
        env:
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          SKIP_WAITING_FOR_BUILD_PROCESSING: ${{ env.SKIP_WAITING_FOR_BUILD_PROCESSING }}
        run: |
          # IPA 절대경로 탐색
          IPA_PATH=$(find $GITHUB_WORKSPACE/ios/build/ipa -name "*.ipa" | head -1)
          echo "Found IPA at: $IPA_PATH"
          if [ ! -f "$IPA_PATH" ]; then
            echo "❌ IPA 파일을 찾을 수 없습니다!"; ls -la ios/build/ipa/ || true; exit 1
          fi

          # Release notes
          if [ -f "final_release_notes.txt" ]; then
            RELEASE_NOTES=$(cat final_release_notes.txt)
          else
            RELEASE_NOTES="v${{ needs.prepare-build.outputs.version }} 업데이트"
          fi

          export APP_STORE_CONNECT_API_KEY_ID="${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}"
          export APP_STORE_CONNECT_ISSUER_ID="${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}"
          export API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}.p8"
          export IPA_PATH="$IPA_PATH"
          export RELEASE_NOTES="$RELEASE_NOTES"
          export APP_IDENTIFIER="${{ secrets.IOS_BUNDLE_ID || vars.IOS_BUNDLE_ID }}"
          export DEPLOY_MODE="${{ env.DEPLOY_MODE }}"
          export APP_VERSION="${{ needs.prepare-build.outputs.version }}"
          export BUILD_NUMBER="${{ needs.prepare-build.outputs.build_number }}"

          echo "DEPLOY_MODE: $DEPLOY_MODE / APP_IDENTIFIER: $APP_IDENTIFIER"
          cd ios
          bundle exec fastlane deploy
```

> **APP_IDENTIFIER 출처:** RomRom은 `com.alom.romrom` 하드코딩이었으나 템플릿은 하드코딩 금지(Global Constraints). 실제 파일에서 Bundle ID를 이미 다루는 곳(예: ExportOptions/secrets/vars)을 먼저 확인해 그 값을 재사용한다. 위 `secrets.IOS_BUNDLE_ID || vars.IOS_BUNDLE_ID`는 그런 값이 없을 때의 기본 패턴 — Step 3 실행 전 실제 파일에서 기존 Bundle ID 참조 방식을 grep해 일치시킨다(`grep -n "BUNDLE_ID\|bundle_id\|PRODUCT_BUNDLE" 파일`).

- [ ] **Step 4: 호출 명령·input 검증**

```bash
cd "D:/0-suh/project/suh-github-template"
F=.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml
grep -nE "fastlane deploy$|fastlane deploy\b|deploy_mode:|DEPLOY_MODE:|fastlane upload_testflight" "$F"
```
Expected: `fastlane deploy`·`deploy_mode:`·`DEPLOY_MODE:` 매칭, `fastlane upload_testflight` **미매칭**(교체됨).

- [ ] **Step 5: Commit** (컨벤션 제공 시)

```bash
git add .github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml
git commit -m "iOS 워크플로우에 deploy_mode 입력·DEPLOY_MODE env 추가하고 fastlane deploy 호출로 통일 : feat : #399"
```

---

## Task 4: Android 워크플로우 deploy_mode input + DEPLOY_MODE env 전달

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` (env 34~40, 호출 661~662)

**Interfaces:**
- Consumes: Task 2의 `deploy_internal` lane + `DEPLOY_MODE` env 계약(폴백 `store_submit`).
- Produces: `deploy_mode` workflow_dispatch input, `DEPLOY_MODE` env. → Task 6 HTML·Task 5 셋업이 ANDROID_DEPLOY_MODE repo variable 참조.

**배경:** 현재 Android 워크플로우는 workflow_dispatch input 없음, `DEPLOY_MODE` 미전달, 호출 `cd android`/`fastlane deploy_internal`(661~662). `cp Fastfile.playstore Fastfile`(545~548)은 그대로. lane은 이미 `deploy_internal`이라 호출 명령은 유지하되 `DEPLOY_MODE`를 환경에 주입한다.

- [ ] **Step 1: workflow_dispatch에 deploy_mode input 추가**

```yaml
on:
  workflow_dispatch:
    inputs:
      deploy_mode:
        description: "배포 모드 (store_only=internal까지 / store_prepare=production draft / store_submit=심사 자동등록)"
        required: false
        default: "store_only"
        type: choice
        options:
          - store_only
          - store_prepare
          - store_submit
  # (기존 트리거 보존)
```

> 실제 `on:` 블록을 먼저 읽고 기존 트리거 보존하며 `workflow_dispatch.inputs`만 삽입.

- [ ] **Step 2: 최상위 env에 DEPLOY_MODE 추가**

라인 34~40 `env:` 블록 끝에 추가:

```yaml
  # 배포 모드 (store_only | store_prepare | store_submit)
  DEPLOY_MODE: ${{ github.event.inputs.deploy_mode || vars.ANDROID_DEPLOY_MODE || 'store_only' }}
```

- [ ] **Step 3: fastlane 호출 step에 DEPLOY_MODE env 전달**

`Upload to Play Store Internal Testing` step(554~)의 `cd android`/`fastlane deploy_internal`(661~662) 직전에 env를 전달한다. 해당 step에 `env:` 블록이 없으면 추가, 있으면 한 줄 추가:

```yaml
      - name: Upload to Play Store Internal Testing
        env:
          DEPLOY_MODE: ${{ env.DEPLOY_MODE }}
        run: |
          # ... (기존 내용 보존) ...
          cd android
          bundle exec fastlane deploy_internal
```

> 기존 step에 다른 env(GOOGLE_PLAY_JSON_KEY 등)가 이미 있으면 그 블록에 `DEPLOY_MODE:` 한 줄만 추가한다(덮어쓰기 금지). Fastfile은 `ENV["DEPLOY_MODE"]`를 읽으므로 step env로 충분.

- [ ] **Step 4: 검증**

```bash
cd "D:/0-suh/project/suh-github-template"
F=.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml
grep -nE "deploy_mode:|DEPLOY_MODE:|fastlane deploy_internal" "$F"
```
Expected: `deploy_mode:`·`DEPLOY_MODE:`(최상위 env + step env)·`fastlane deploy_internal` 모두 매칭.

- [ ] **Step 5: Commit** (컨벤션 제공 시)

```bash
git add .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml
git commit -m "Android 워크플로우에 deploy_mode 입력·DEPLOY_MODE env 전달 추가 : feat : #399"
```

---

## Task 5: 마법사 셋업 스크립트 동기화 (iOS 템플릿 경로 + DEPLOY_MODE 안내)

**Files:**
- Modify: `.github/util/flutter/testflight-wizard/testflight-wizard-setup.sh` (214행 템플릿 참조)
- Modify: `.github/util/flutter/playstore-wizard/playstore-wizard-setup.sh` (안내 문구)
- Modify: `.github/util/flutter/playstore-wizard/playstore-wizard-setup.ps1` (안내 문구, .sh와 동등)

**Interfaces:**
- Consumes: Task 1의 새 파일명 `Fastfile.ios.template`.
- Produces: 마법사가 `ios/fastlane/Fastfile`(접미사 없이)·`android/fastlane/Fastfile.playstore`를 정상 배치 + DEPLOY_MODE repo variable 안내 출력.

**배경:** iOS 셋업은 214행 `template_fastfile="$TEMPLATE_DIR/Fastfile"` → 개명된 `.ios.template` 참조 필요. 복사 대상(`$PROJECT_PATH/ios/fastlane/Fastfile`)은 접미사 없이 유지. DEPLOY_MODE/IOS_DEPLOY_MODE·ANDROID_DEPLOY_MODE 안내가 양쪽에 없음.

- [ ] **Step 1: iOS 셋업 템플릿 참조 경로 변경**

`testflight-wizard-setup.sh` 214행:
```bash
    local template_fastfile="$TEMPLATE_DIR/Fastfile"
```
→
```bash
    local template_fastfile="$TEMPLATE_DIR/Fastfile.ios.template"
```
(복사 대상 라인 213 `fastfile_path="$fastlane_dir/Fastfile"`·232 `cp`는 그대로 — 사용자 프로젝트엔 접미사 없이 깔림.)

- [ ] **Step 2: iOS 셋업 완료 메시지에 IOS_DEPLOY_MODE 안내 추가**

`testflight-wizard-setup.sh`의 완료 출력부(셋업 끝, `print_success`/요약 출력 부근)에 아래 안내를 추가한다. (정확한 삽입 지점은 파일에서 "설정 완료"/"다음 단계" 류 마지막 출력 블록을 grep해 그 뒤에.)

```bash
    echo ""
    echo "🎛️  배포 모드 설정 (선택):"
    echo "   GitHub repo Variables에 IOS_DEPLOY_MODE 를 설정하면 기본 배포 범위를 정할 수 있습니다."
    echo "     store_only    : TestFlight 업로드까지만 (기본)"
    echo "     store_prepare : App Store 제출 직전까지 (사람이 ASC에서 Add for Review)"
    echo "     store_submit  : App Store 심사 자동 제출 (정식 출시 1회 수동 이후부터 가능)"
    echo "   워크플로우 수동 실행 시 deploy_mode 입력이 이 변수보다 우선합니다."
```

- [ ] **Step 3: Android 셋업(.sh) 완료 메시지에 ANDROID_DEPLOY_MODE 안내 추가**

`playstore-wizard-setup.sh` 완료 출력부에:

```bash
    echo ""
    echo "🎛️  배포 모드 설정 (선택):"
    echo "   GitHub repo Variables에 ANDROID_DEPLOY_MODE 를 설정하면 기본 배포 범위를 정할 수 있습니다."
    echo "     store_only    : 내부 테스트(internal) 업로드까지만 (기본)"
    echo "     store_prepare : production draft 승급 (콘솔에서 '출시 시작' 대기)"
    echo "     store_submit  : production 심사 자동 등록 (정식 출시 1회 수동 이후부터 가능)"
    echo "   워크플로우 수동 실행 시 deploy_mode 입력이 이 변수보다 우선합니다."
```

- [ ] **Step 4: Android 셋업(.ps1)에 동등 안내 추가 (.sh와 1:1)**

`playstore-wizard-setup.ps1` 완료 출력부에 PowerShell 동등 코드:

```powershell
    Write-Host ""
    Write-Host "🎛️  배포 모드 설정 (선택):"
    Write-Host "   GitHub repo Variables에 ANDROID_DEPLOY_MODE 를 설정하면 기본 배포 범위를 정할 수 있습니다."
    Write-Host "     store_only    : 내부 테스트(internal) 업로드까지만 (기본)"
    Write-Host "     store_prepare : production draft 승급 (콘솔에서 '출시 시작' 대기)"
    Write-Host "     store_submit  : production 심사 자동 등록 (정식 출시 1회 수동 이후부터 가능)"
    Write-Host "   워크플로우 수동 실행 시 deploy_mode 입력이 이 변수보다 우선합니다."
```

- [ ] **Step 5: 문법·동등성 검증**

```bash
cd "D:/0-suh/project/suh-github-template"
bash -n .github/util/flutter/testflight-wizard/testflight-wizard-setup.sh && echo "iOS sh OK"
bash -n .github/util/flutter/playstore-wizard/playstore-wizard-setup.sh && echo "Android sh OK"
grep -n "Fastfile.ios.template" .github/util/flutter/testflight-wizard/testflight-wizard-setup.sh
grep -c "ANDROID_DEPLOY_MODE" .github/util/flutter/playstore-wizard/playstore-wizard-setup.sh
grep -c "ANDROID_DEPLOY_MODE" .github/util/flutter/playstore-wizard/playstore-wizard-setup.ps1
```
Expected: `iOS sh OK`·`Android sh OK`, `Fastfile.ios.template` 1회 매칭, ANDROID_DEPLOY_MODE가 .sh/.ps1 각 ≥1회(동등).

PowerShell 문법은 Docker 파서로(CLAUDE.md 방식, 가능 시):
```bash
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/.github/util/flutter/playstore-wizard/playstore-wizard-setup.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}' 2>/dev/null || echo "docker 미사용 — Windows PowerShell 파서로 별도 확인"
```
Expected: `PS1_PARSE_OK` 또는 docker 미사용 메시지.

- [ ] **Step 6: Commit** (컨벤션 제공 시)

```bash
git add .github/util/flutter/testflight-wizard/testflight-wizard-setup.sh \
        .github/util/flutter/playstore-wizard/playstore-wizard-setup.sh \
        .github/util/flutter/playstore-wizard/playstore-wizard-setup.ps1
git commit -m "마법사 셋업에 iOS 템플릿 경로(.ios.template)·배포모드 안내 동기화 : feat : .sh/.ps1 동등 #399"
```

---

## Task 6: 마법사 HTML 완료단계 배포모드 안내카드

**Files:**
- Modify: `.github/util/flutter/testflight-wizard/testflight-wizard.html`
- Modify: `.github/util/flutter/playstore-wizard/playstore-wizard.html`

**Interfaces:**
- Consumes: Task 3·4의 repo variable명(`IOS_DEPLOY_MODE`/`ANDROID_DEPLOY_MODE`)·모드 3단계.
- Produces: 사용자 가시 안내(코드 동작 변화 없음).

**배경:** 두 HTML 완료단계에 배포 모드·출시 로드맵 안내카드 없음. 정적 안내 카드만 추가(JS 동작 불필요. `.js`가 완료단계 마크업을 동적 생성하면 `.js` 수정, 정적 HTML이면 HTML 수정 — Step 1에서 확인).

- [ ] **Step 1: 완료단계 마크업 위치·생성방식 확인**

```bash
cd "D:/0-suh/project/suh-github-template"
grep -nE "완료|complete|finish|success|다음 단계|next-step" .github/util/flutter/testflight-wizard/testflight-wizard.html | head
ls .github/util/flutter/testflight-wizard/*.js 2>/dev/null && grep -nE "완료|complete|innerHTML" .github/util/flutter/testflight-wizard/*.js | head
```
Expected: 완료단계 컨테이너의 id/class 또는 생성 JS 위치 파악.

- [ ] **Step 2: iOS HTML 완료단계에 안내카드 삽입**

완료단계 컨테이너(Step 1에서 찾은 위치) 안에 아래 카드를 추가:

```html
<div class="deploy-mode-card" style="margin-top:16px;padding:14px;border:1px solid #d0d7de;border-radius:8px;background:#f6f8fa;">
  <h4 style="margin:0 0 8px;">🎛️ 배포 모드 &amp; 출시 로드맵 (iOS)</h4>
  <p style="margin:0 0 8px;">GitHub repo <b>Variables → IOS_DEPLOY_MODE</b> 로 기본 배포 범위를 정합니다. 워크플로우 수동 실행 시 <code>deploy_mode</code> 입력이 우선합니다.</p>
  <ul style="margin:0;padding-left:18px;">
    <li><b>store_only</b> — TestFlight 업로드까지만 (기본)</li>
    <li><b>store_prepare</b> — App Store 제출 직전까지 (ASC에서 사람이 'Add for Review')</li>
    <li><b>store_submit</b> — App Store 심사 자동 제출</li>
  </ul>
  <p style="margin:8px 0 0;color:#57606a;">⚠️ 신규 앱은 최초 1회 App Store Connect에서 수동 제출이 필요하고, 이후 업데이트부터 store_submit으로 자동화됩니다.</p>
</div>
```

- [ ] **Step 3: Android HTML 완료단계에 안내카드 삽입**

```html
<div class="deploy-mode-card" style="margin-top:16px;padding:14px;border:1px solid #d0d7de;border-radius:8px;background:#f6f8fa;">
  <h4 style="margin:0 0 8px;">🎛️ 배포 모드 &amp; 출시 로드맵 (Android)</h4>
  <p style="margin:0 0 8px;">GitHub repo <b>Variables → ANDROID_DEPLOY_MODE</b> 로 기본 배포 범위를 정합니다. 워크플로우 수동 실행 시 <code>deploy_mode</code> 입력이 우선합니다.</p>
  <ul style="margin:0;padding-left:18px;">
    <li><b>store_only</b> — 내부 테스트(internal) 업로드까지만 (기본)</li>
    <li><b>store_prepare</b> — production draft 승급 (콘솔에서 '출시 시작' 대기)</li>
    <li><b>store_submit</b> — production 심사 자동 등록</li>
  </ul>
  <p style="margin:8px 0 0;color:#57606a;">⚠️ 신규 앱은 최초 1회 Play Console에서 수동 출시가 필요하고, 이후 업데이트부터 store_submit으로 자동화됩니다.</p>
</div>
```

> JS가 완료단계를 동적 생성하면 위 HTML을 해당 템플릿 문자열(innerHTML/template literal)에 삽입한다. 표/마크업은 template literal 들여쓰기 영향을 받으니 한 줄 문자열 또는 배열 join으로 넣는다(CLAUDE.md GitHub 댓글 표 규칙 동일 원리).

- [ ] **Step 4: 렌더 구조 검증**

```bash
cd "D:/0-suh/project/suh-github-template"
grep -c "deploy-mode-card" .github/util/flutter/testflight-wizard/testflight-wizard.html
grep -c "deploy-mode-card" .github/util/flutter/playstore-wizard/playstore-wizard.html
# 태그 균형 간이 확인
grep -c "<div" .github/util/flutter/testflight-wizard/testflight-wizard.html
grep -c "</div>" .github/util/flutter/testflight-wizard/testflight-wizard.html
```
Expected: 각 HTML에 `deploy-mode-card` 1회, `<div`/`</div>` 개수 동일(불일치 시 닫는 태그 보정).

- [ ] **Step 5: Commit** (컨벤션 제공 시)

```bash
git add .github/util/flutter/testflight-wizard/testflight-wizard.html \
        .github/util/flutter/playstore-wizard/playstore-wizard.html
git commit -m "마법사 완료단계에 배포모드·출시 로드맵 안내카드 추가 : feat : #399"
```

---

## Task 7: iOS 워크플로우 모노레포 경로 변수화 (FLUTTER_ROOT, 11곳)

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`

**Interfaces:**
- Consumes: Task 9의 resolver가 통합 시점에 치환할 `# @wizard auto:flutter-root` 마커. (마커 시스템 자체는 선행 완료된 #406.)
- Produces: `env: FLUTTER_ROOT` + 빌드/배포 job `defaults.run.working-directory` + 개별 변수화된 절대경로.

**배경:** iOS 워크플로우의 레포루트 기준 하드코딩 **11곳**: `cd ios`(104,300,320,373,386,436,618), `cat > ios/Runner/GoogleService-Info.plist`(353), artifact `path: ios/build/ipa/*.ipa`(397)·`path: ios/build/ipa/`(423), `find $GITHUB_WORKSPACE/ios/build/ipa`(577). 빌드/배포 job에 `defaults.run.working-directory: ${{ env.FLUTTER_ROOT }}`를 두면 `cd ios`는 `$FLUTTER_ROOT/ios`로 해석되고, working-directory 안 먹는 곳(artifact path·`$GITHUB_WORKSPACE` 절대경로)만 개별 변수화.

- [ ] **Step 1: 최상위 env에 FLUTTER_ROOT 마커 추가**

`env:` 블록(라인 70 부근) 시작에:
```yaml
env:
  FLUTTER_ROOT: "."   # @wizard auto:flutter-root
  # ... (기존 env 보존) ...
```

- [ ] **Step 2: 빌드/배포 job에 defaults.run.working-directory 추가**

iOS 워크플로우의 빌드/배포 job(=`run:`에서 `cd ios`를 쓰는 job들)의 job 정의에 추가한다. 먼저 job 구조를 확인:
```bash
grep -nE "^  [a-z0-9_-]+:$|runs-on:|defaults:|working-directory:" .github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml | head -40
```
각 해당 job의 `runs-on:` 다음에:
```yaml
    defaults:
      run:
        working-directory: ${{ env.FLUTTER_ROOT }}
```

> 이러면 `cd ios`(104,300,320,373,386,436,618)는 `$FLUTTER_ROOT/ios`에서 돈다(기본값 `.`이면 `./ios`=현행). `cat > ios/Runner/...`(353)·기타 `ios/` 상대경로 run도 자동 해결.

- [ ] **Step 3: working-directory 안 먹는 곳 개별 변수화 (artifact path·절대경로)**

다음 3곳은 working-directory 영향을 안 받으므로 직접 변수화:

(a) 라인 397 `path: ios/build/ipa/*.ipa` →
```yaml
          path: ${{ env.FLUTTER_ROOT }}/ios/build/ipa/*.ipa
```
(b) 라인 423 `path: ios/build/ipa/` →
```yaml
          path: ${{ env.FLUTTER_ROOT }}/ios/build/ipa/
```
(c) 라인 577 `IPA_PATH=$(find $GITHUB_WORKSPACE/ios/build/ipa -name "*.ipa" | head -1)` →
```bash
          IPA_PATH=$(find "$GITHUB_WORKSPACE/${FLUTTER_ROOT}/ios/build/ipa" -name "*.ipa" | head -1)
```

> `${FLUTTER_ROOT}`를 run 안에서 쓰려면 그 step이 env로 FLUTTER_ROOT를 본다(최상위 env라 자동 노출). artifact `path:`는 `${{ env.FLUTTER_ROOT }}` 표현식 사용.

- [ ] **Step 4: 단일레포 회귀 검증 (기본값 `.`)**

```bash
cd "D:/0-suh/project/suh-github-template"
F=.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml
grep -nE "FLUTTER_ROOT: \"\.\"|@wizard auto:flutter-root|working-directory: \\$\\{\\{ env.FLUTTER_ROOT" "$F"
# 절대경로/아티팩트 path 변수화 확인
grep -nE "FLUTTER_ROOT./ios/build/ipa|env.FLUTTER_ROOT./ios/build/ipa" "$F"
# 남은 비변수화 절대경로 없는지
grep -nE "GITHUB_WORKSPACE/ios/build" "$F" && echo "⚠️ 미변수화 잔존" || echo "✅ 절대경로 변수화 완료"
```
Expected: FLUTTER_ROOT env·마커·working-directory 매칭, artifact/절대경로 변수화됨, "✅ 절대경로 변수화 완료". 기본값 `.`이라 `working-directory: .`은 레포루트=현행.

- [ ] **Step 5: Commit** (컨벤션 제공 시)

```bash
git add .github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml
git commit -m "iOS 워크플로우 경로를 FLUTTER_ROOT로 변수화(모노레포 대응) : feat : working-directory + 절대경로 11곳 #399"
```

---

## Task 8: Android 워크플로우 모노레포 경로 변수화 (FLUTTER_ROOT, 23곳)

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`

**Interfaces:**
- Consumes: Task 9 resolver 마커 `# @wizard auto:flutter-root`.
- Produces: `env: FLUTTER_ROOT` + 빌드/배포 job `defaults.run.working-directory` + 개별 변수화.

**배경:** Android 하드코딩 23곳. job 3개(`prepare-build` 43 / `build-android` 172 / `deploy-playstore` 495) 모두 `defaults working-directory` 없음. `run:` 안의 `mkdir android/`·`cat > android/key.properties`·`android/local.properties`·`cd android` 등은 working-directory로 자동 해결되나, artifact `path: build/app/...`(492,519)와 step 레벨 `working-directory: android`(535)와 metadata 경로(629)는 점검 필요.

하드코딩 23곳(에이전트 전수): 205,206,208(`mkdir/base64 -d/ls android/app/keystore`), 213,220(`cat > android/key.properties`/`cat`), 225(`cat > android/app/google-services.json`), 266(`grep android/app/build.gradle.kts`), 312,313,314,316,320,321(`android/local.properties` 처리), 492(`path: build/app/outputs/bundle/release/app-release.aab`), 519(`path: build/app/outputs/bundle/release/`), 535(`working-directory: android`), 538(`Gemfile` 생성 — working-directory 하위라 무해), 547,548,551(`mkdir/cp/cat android/fastlane`), 629(`CHANGELOG_DIR="android/fastlane/metadata/..."`), 661(`cd android`).

- [ ] **Step 1: 최상위 env에 FLUTTER_ROOT 마커 추가**

```yaml
env:
  FLUTTER_ROOT: "."   # @wizard auto:flutter-root
  # ... (기존 env 보존) ...
```

- [ ] **Step 2: 빌드/배포 job에 defaults.run.working-directory 추가**

`build-android`(172)·`deploy-playstore`(495) 두 job의 `runs-on:` 다음에:
```yaml
    defaults:
      run:
        working-directory: ${{ env.FLUTTER_ROOT }}
```

> `prepare-build`(43)는 버전 계산 등 레포루트 작업이면 추가하지 않는다 — Step 2 직전 그 job이 `android/` 경로를 만지는지 확인(만지면 추가, 안 만지면 제외). 위 하드코딩 라인들(205~321, 547~661)이 어느 job에 속하는지 grep으로 매핑한 뒤 그 job에만 defaults를 건다.

이 한 줄로 자동 해결되는 라인: 205,206,208,213,220,225,266,312~321,538,547,548,551,629,661 (전부 `run:` 내부 `android/` 상대경로).

- [ ] **Step 3: working-directory 안 먹는 곳 개별 변수화**

(a) artifact upload path 라인 492 `path: build/app/outputs/bundle/release/app-release.aab` →
```yaml
          path: ${{ env.FLUTTER_ROOT }}/build/app/outputs/bundle/release/app-release.aab
```
(b) artifact 라인 519 `path: build/app/outputs/bundle/release/` →
```yaml
          path: ${{ env.FLUTTER_ROOT }}/build/app/outputs/bundle/release/
```
(c) step 레벨 라인 535 `working-directory: android` (이미 step에 명시) — job defaults와 별개로 그대로 두면 `android`가 레포루트 기준이 된다. 모노레포에선 깨지므로:
```yaml
        working-directory: ${{ env.FLUTTER_ROOT }}/android
```

> **주의(download-artifact):** deploy job이 upload된 aab를 download할 때 `path:`도 같은 방식으로 변수화돼야 build job의 upload 경로와 짝이 맞는다. download-artifact의 `path:`가 `build/...` 또는 `android/...`이면 동일 패턴으로 `${{ env.FLUTTER_ROOT }}/` 접두. Step 3 실행 시 `grep -n "download-artifact" -A3` 로 그 path도 함께 변수화.

- [ ] **Step 4: 단일레포 회귀 + 변수화 누락 점검**

```bash
cd "D:/0-suh/project/suh-github-template"
F=.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml
grep -nE "FLUTTER_ROOT: \"\.\"|@wizard auto:flutter-root|working-directory: \\$\\{\\{ env.FLUTTER_ROOT" "$F"
# artifact path 변수화
grep -nE "path: \\$\\{\\{ env.FLUTTER_ROOT \\}\\}/build/app" "$F"
# 미변수화 잔존(artifact/working-directory에서 레포루트 기준 build/·android)
grep -nE "^\s+path: build/app|working-directory: android$" "$F" && echo "⚠️ 미변수화 잔존" || echo "✅ 변수화 완료"
```
Expected: env·마커·defaults 매칭, artifact path 변수화, "✅ 변수화 완료". 기본값 `.`이면 `./android`=현행.

- [ ] **Step 5: Commit** (컨벤션 제공 시)

```bash
git add .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml
git commit -m "Android 워크플로우 경로를 FLUTTER_ROOT로 변수화(모노레포 대응) : feat : working-directory + artifact path 23곳 #399"
```

---

## Task 9: integrator에 flutter-root resolver 추가 (통합 시점 치환)

**Files:**
- Modify: `template_integrator.sh` (`resolve_flutter_root` 함수 + resolver 등록)
- Modify: `template_integrator.ps1` (`Resolve-FlutterRoot` 함수 + resolver 등록, .sh와 동등)

**Interfaces:**
- Consumes: 선행 완료 마커 시스템(#406)의 resolver 레지스트리 + `get_path_for_type`/통합 시점 `resolve_project_paths`로 채워진 `project_paths.flutter` 값. Task 7·8이 워크플로우에 심은 `# @wizard auto:flutter-root` 마커.
- Produces: 통합 시 워크플로우의 `FLUTTER_ROOT: "."` → `FLUTTER_ROOT: "app"`(모노레포) 치환 + `# @wizard` 주석 제거.

**배경:** 마커 시스템(#406)이 `auto:<resolver>` 문법과 resolver 레지스트리를 이미 제공한다. Flutter는 그 위에 `flutter-root` resolver 하나만 추가하면 된다. resolver는 `get_path_for_type "flutter"`(통합 시 채워진 값, `.` 또는 `app`)를 반환.

- [ ] **Step 1: 마커 시스템의 resolver 등록 패턴 확인 (선행 #406 산출물)**

```bash
cd "D:/0-suh/project/suh-github-template"
grep -nE "auto:|resolver|get_path_for_type|resolve_project_paths|@wizard" template_integrator.sh | head -30
grep -nE "auto:|[Rr]esolver|Get-PathForType|Resolve-ProjectPaths|@wizard" template_integrator.ps1 | head -30
```
Expected: 마커 치환 엔진의 resolver 디스패치 위치·기존 resolver 함수 네이밍·등록 방식 파악(예: `case "$resolver" in flutter-root) ...`). 이 패턴을 그대로 따른다.

- [ ] **Step 2: `.sh`에 resolve_flutter_root 추가 + 디스패치 등록**

Step 1에서 확인한 resolver 디스패치(예: `case` 또는 함수 매핑)에 `flutter-root`를 추가하고 함수를 정의:

```bash
# auto:flutter-root resolver — Flutter 루트 경로(레포 루트 기준). 단일레포면 ".", 모노레포면 "app" 등.
resolve_flutter_root() {
    local p
    p="$(get_path_for_type "flutter")"
    if [ -z "$p" ]; then
        echo "."
    else
        echo "$p"
    fi
}
```

디스패치 등록(Step 1의 실제 패턴에 맞춤. 예시가 `case`라면):
```bash
        flutter-root) resolve_flutter_root ;;
```

> 함수명·`get_path_for_type` 시그니처는 Step 1에서 확인한 실제 마커 시스템 API에 맞춘다. 위는 마커 스펙 §9-2 기준 표준형.

- [ ] **Step 3: `.ps1`에 Resolve-FlutterRoot 추가 + 디스패치 등록 (.sh와 동등)**

```powershell
# auto:flutter-root resolver — Flutter 루트 경로. 단일레포면 ".", 모노레포면 "app" 등.
function Resolve-FlutterRoot {
    $p = Get-PathForType "flutter"
    if ([string]::IsNullOrEmpty($p)) { return "." }
    return $p
}
```

디스패치 등록(Step 1의 .ps1 실제 패턴에 맞춤. 예: switch):
```powershell
        'flutter-root' { Resolve-FlutterRoot }
```

- [ ] **Step 4: 문법 검증**

```bash
cd "D:/0-suh/project/suh-github-template"
bash -n template_integrator.sh && echo "sh OK"
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}' 2>/dev/null || echo "docker 미사용 — Windows PowerShell 파서로 확인"
grep -n "resolve_flutter_root\|flutter-root" template_integrator.sh
grep -n "Resolve-FlutterRoot\|flutter-root" template_integrator.ps1
```
Expected: `sh OK`, `PS1_PARSE_OK`(또는 docker 미사용), 양쪽에 resolver 함수·`flutter-root` 등록 매칭.

- [ ] **Step 5: 치환 시뮬레이션 (단일레포 `.` / 모노레포 `app`)**

마커 시스템 #406이 제공하는 치환 진입점(Step 1에서 확인)을 단일레포·모노레포 입력으로 돌려, 워크플로우 env가 각각 `FLUTTER_ROOT: "."`(주석 제거)·`FLUTTER_ROOT: "app"`(주석 제거)로 바뀌는지 확인한다. 별도 치환 테스트 하네스가 마커 스펙 §5에 있으면 그것을 재사용한다.

```bash
# 마커 스펙 #406의 치환 테스트가 있다면:
ls .github/scripts/test/ 2>/dev/null | grep -i marker
# 없으면 resolver 단위 호출:
cd "D:/0-suh/project/suh-github-template"
bash -c 'source template_integrator.sh 2>/dev/null; get_path_for_type(){ echo "app"; }; resolve_flutter_root' 2>/dev/null || echo "함수 격리 호출은 마커 시스템 API 확인 후"
```
Expected: 모노레포 입력 시 `app` 반환, 단일레포(또는 빈값) 시 `.` 반환.

- [ ] **Step 6: Commit** (컨벤션 제공 시)

```bash
git add template_integrator.sh template_integrator.ps1
git commit -m "integrator에 flutter-root resolver 추가(모노레포 경로 통합시 치환) : feat : .sh/.ps1 동등 #399"
```

---

## Task 10: 통합 회귀 검증 + 정본 스펙 §7 검증전략 수행

**Files:**
- 변경 없음 (검증 전용). RomRom 운영본과의 동형 대조 + 단일레포 회귀.

**Interfaces:**
- Consumes: Task 1~9 산출물 전부.

- [ ] **Step 1: RomRom 동형 대조 (Android — 1순위 기준)**

```bash
cd "D:/0-suh/project/suh-github-template"
# Android Fastfile 핵심 로직 라인이 RomRom과 의미상 동일한지 (플레이스홀더 제외)
diff <(grep -vE "\{\{|^\s*#|^\s*$" .github/util/flutter/playstore-wizard/templates/Fastfile.playstore.template | grep -oE "rescue_changes_not_sent_for_review:.*|track_promote_release_status:.*|release_status:.*|track_promote_to:.*|deploy_mode =.*|promote = .*|submit = .*") \
     <(grep -vE "^\s*#|^\s*$" "D:/0-suh/project/RomRom-FE/android/fastlane/Fastfile.playstore" | grep -oE "rescue_changes_not_sent_for_review:.*|track_promote_release_status:.*|release_status:.*|track_promote_to:.*|deploy_mode =.*|promote = .*|submit = .*") \
  && echo "✅ Android 핵심 로직 RomRom 동형" || echo "⚠️ 차이 검토 필요(의미상 동일하면 OK)"
```
Expected: 핵심 옵션 라인 동형(차이 있으면 의미상 동일성 수동 확인).

- [ ] **Step 2: iOS lane 내용 대조 (구조 다르므로 lane 내용만)**

```bash
cd "D:/0-suh/project/suh-github-template"
# 템플릿 deploy lane의 deliver/pilot 옵션이 RomRom heredoc deploy_appstore와 의미상 동일한지
echo "=== 템플릿 deploy lane 핵심 ==="
grep -nE "submit_for_review|automatic_release|skip_binary_upload|skip_metadata|metadata_path|review_information|add_id_info_uses_idfa|skip_waiting_for_build_processing" .github/util/flutter/testflight-wizard/templates/Fastfile.ios.template
echo "=== RomRom deploy_appstore 핵심 ==="
grep -nE "submit_for_review|automatic_release|skip_binary_upload|skip_metadata|metadata_path|review_information|add_id_info_uses_idfa|skip_waiting_for_build_processing" "D:/0-suh/project/RomRom-FE/.github/workflows/ROMROM-IOS-TESTFLIGHT.yaml"
```
Expected: 같은 옵션 집합이 양쪽에 존재(값 의미 동일).

- [ ] **Step 3: 단일레포 회귀 — FLUTTER_ROOT="." 동작 보존**

```bash
cd "D:/0-suh/project/suh-github-template"
for F in .github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml \
         .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml; do
  echo "=== $F ==="
  grep -nE "FLUTTER_ROOT: \"\.\"" "$F" && echo "기본값 . 확인(단일레포 안전)"
  # 변수화 안 된 채 남은 레포루트 기준 절대경로(아티팩트/GITHUB_WORKSPACE)가 없는지
  grep -nE "GITHUB_WORKSPACE/(ios|android)/build|^\s+path: (ios|android|build)/" "$F" && echo "⚠️ 미변수화 잔존: $F" || echo "✅ $F 변수화 완전"
done
```
Expected: 두 파일 기본값 `.`, 미변수화 잔존 없음.

- [ ] **Step 4: 런타임 version.yml 미의존 확인**

```bash
cd "D:/0-suh/project/suh-github-template"
grep -nE "version_manager.sh get-path|version.yml" \
  .github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml \
  .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml \
  && echo "⚠️ 런타임 version.yml 읽기 잔존(스펙 §9-2 위반)" || echo "✅ 런타임 version.yml 미의존(값은 env에 박힘)"
```
Expected: "✅ 런타임 version.yml 미의존".

- [ ] **Step 5: RomRom 고유값 전역 미혼입 최종 확인**

```bash
cd "D:/0-suh/project/suh-github-template"
grep -rnE "com\.alom\.romrom|ROMROM-|alom" \
  .github/util/flutter/ \
  .github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml \
  .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml \
  && echo "⚠️ RomRom 고유값 혼입" || echo "✅ RomRom 고유값 없음"
```
Expected: "✅ RomRom 고유값 없음".

- [ ] **Step 6: 최종 보고 (커밋은 사용자 컨벤션 제공 시)**

검증 결과를 요약하고, 사용자에게 PR/배포 검증 절차(RomRom 동형이므로 템플릿은 로직 동일성으로 검증 갈음, 실제 스토어 검증은 RomRom에서 완료됨)를 안내한다.

---

## Self-Review (작성자 점검 결과)

**1. Spec coverage (정본 §별 → Task 매핑):**
- §2-1 iOS heredoc→파일템플릿 통일 → Task 1·3 ✅
- §3 배포모드 3단계(별칭 포함) → Task 1(iOS lane)·2(Android lane)·3·4(input/env) ✅
- §4 거짓성공 제거(Android rescue:false / iOS 거짓성공 라인 — iOS는 이미 제거됨 확인) → Task 2 ✅ (iOS는 에이전트 확인 "없음(이미 제거)" — 추가 작업 불요)
- §5 포팅표 9항목: #1 Android template(T2) #2 iOS .ios.template(T1) #3 iOS WF(T3,T7) #4 Android WF(T4,T8) #5 iOS setup(T5) #6 iOS html(T6) #7 Android html(T6) #8 Android setup .sh/.ps1(T5) #9 Gemfile(미사용 사본 — §5 "실제 사용 여부 확인 후 정리", 본 계획 비범위 명시) ✅
- §6 동기화 규칙 비적용(타입별) → Global Constraints 반영 ✅
- §7 검증전략 1~5 → Task 10 ✅
- §8 비범위(iOS setup.ps1·ExportOptions·Gemfile 개명) → 본 계획에서 제외 ✅
- §9 모노레포(B): §9-2 값주입(T9) §9-3 경로변수화 iOS/Android(T7/T8) §9-4 검증(T10) ✅

**갭:** §5 #9 Gemfile은 "미사용 사본 가능성, 실제 사용 여부 확인 후 정리"로 스펙도 조건부 → 본 계획은 명시적 비범위(Task에 안 넣음). iOS 거짓성공 라인은 RomRom 운영본에 이미 없어(에이전트 확인) 별도 Task 불요.

**2. Placeholder scan:** 모든 코드 step에 실제 코드 블록 존재. "기존 보존" 류는 실제 파일 원문을 Step에서 grep 후 삽입하도록 명시(추측 아님). ✅

**3. Type consistency:** iOS lane명 `deploy`(T1 정의 = T3 호출 = T5 셋업이 깐 파일). Android lane명 `deploy_internal`/`promote_internal_to_production`(T2=T4). env명 `DEPLOY_MODE`·`FLUTTER_ROOT`·`APP_IDENTIFIER` 전 Task 일관. 마커 `# @wizard auto:flutter-root`(T7,T8 심음 = T9 resolver가 해석). ✅
