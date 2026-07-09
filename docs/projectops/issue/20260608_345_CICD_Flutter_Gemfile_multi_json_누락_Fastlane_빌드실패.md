🗒️ 설명
---

이 템플릿의 **모든 Flutter 워크플로우·마법사**가 Fastlane 실행 단계에서 `multi_json is not part of the bundle. Add it to your Gemfile. (Gem::LoadError)` 로 빌드 실패합니다. 앱 코드와 무관하게 CI 환경 의존성 문제이며, 이 템플릿으로 초기화/통합한 **모든 파생 Flutter 프로젝트가 동일하게 깨집니다.**

- 파생 프로젝트 RomRom-FE에서 먼저 발견: [RomRom-FE#917](https://github.com/TEAM-ROMROM/RomRom-FE/issues/917) (Android 테스트 APK 빌드 `Install Fastlane` step 실패)
- RomRom-FE는 자기 main에 hotfix만 적용했고, **템플릿 원본은 미수정** 상태였습니다 → 다음 초기화/통합 프로젝트가 동일하게 깨진 채로 받게 됨.

**근본 원인**

- `google-apis-*` / `representable` 등 transitive gem이 2026년 5월 말 새 버전에서 `multi_json` 의존성을 추가했으나, 자신의 gemspec에 `multi_json`을 선언하지 않은 upstream 버그.
- 워크플로우/마법사의 Gemfile이 `gem "fastlane"` 만 선언 → `multi_json`이 번들에 포함되지 않아 Fastlane 실행 시 `Gem::LoadError` 발생.
- GitHub Actions 전역 문제: [actions/runner-images#14186](https://github.com/actions/runner-images/issues/14186) (2026-06-05 등록, Ubuntu/macOS/Windows 러너 전체 영향). Fastlane 공식도 `multi_json`을 direct dep로 추가하는 커밋으로 대응함.

**영향 범위 (템플릿 원본 9곳)**

워크플로우 5곳:
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`
- `.github/workflows/project-types/flutter/synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml`

마법사 4곳:
- `.github/util/flutter/testflight-wizard/templates/Gemfile`
- `.github/util/flutter/testflight-wizard/testflight-wizard-setup.sh`
- `.github/util/flutter/playstore-wizard/playstore-wizard-setup.sh`
- `.github/util/flutter/playstore-wizard/playstore-wizard-setup.ps1` (fastlane 버전 미고정 문제도 함께 존재)

🔄 재현 방법
---

1. Ruby 3.4 / fastlane 2.235.0 환경 (GitHub Actions ubuntu 러너와 동일)
2. `printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile` 후 `bundle install`
3. `bundle exec fastlane --version` 실행
4. → `multi_json is not part of the bundle. Add it to your Gemfile. (Gem::LoadError)` 발생, Fastlane 실행 불가

📸 참고 자료
---

**로컬 실측 검증 (Ruby 3.4.7 + fastlane 2.235.0, 이슈 환경과 동일)**

| Gemfile | `bundle exec fastlane --version` 결과 |
|---|---|
| `gem "fastlane"` (수정 전) | ❌ `multi_json is not part of the bundle. Add it to your Gemfile. (Gem::LoadError)` |
| `gem "fastlane"` + `gem "multi_json"` (수정 후) | ✅ `fastlane 2.235.0` 정상 출력 |

- 근거 1: [actions/runner-images#14186](https://github.com/actions/runner-images/issues/14186) — `Could not find 'multi_json' (>= 1.14.1)` (2026-06-05)
- 근거 2: RomRom-FE#917 — 동일 의존성 체인 빌드 실패

✅ 예상 동작
---

- Flutter 워크플로우·마법사의 Fastlane 설치/실행 단계가 정상 통과해야 함.
- 이 템플릿으로 초기화/통합한 모든 Flutter 프로젝트가 추가 조치 없이 정상 빌드되어야 함.

🛠️ 해결 방안
---

위 9곳 Gemfile 생성부에 `gem "multi_json"` 추가 (Fastlane 공식 대응과 동일, 안전한 의존성 선언 보강). `playstore-wizard-setup.ps1`은 미고정 `gem "fastlane"`을 `gem "fastlane", "~> 2.225"`로 함께 고정.

> 코드 수정은 본 이슈 작성 시점에 로컬에 완료된 상태이며, 본 이슈는 근본 원인 기록 + 추적용입니다.

⚙️ 환경 정보
---

- **OS**: GitHub Actions ubuntu 러너 (전역 영향: Ubuntu/macOS/Windows)
- **CI**: GitHub Actions, Ruby 3.3.x~3.4.x, Fastlane 2.235.0
- **기기**: N/A (CI 의존성 문제)

🙋‍♂️ 담당자
---

- **백엔드**: -
- **프론트엔드**: SUH SAECHAN
- **디자인**: -
