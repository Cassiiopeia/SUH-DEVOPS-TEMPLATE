### 📌 작업 개요
이전 `--force` 임시 패치를 Bundler 기반 방식으로 전면 교체. `gem install fastlane --force` 대신 `Gemfile + bundle install + bundle exec fastlane` 패턴으로 전환하여 gem 충돌 자체를 원천 차단.

**이슈**: [#197](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/197)

### 🔍 문제 분석

**기존 --force 방식의 한계**:
- `--force` 플래그는 충돌하는 실행파일을 강제 덮어쓰는 방식으로 gem 충돌을 우회
- Runner 이미지나 Ruby 버전 업데이트 시 새로운 충돌 발생 가능성 상존
- gem 의존성이 전역 환경에 설치되어 다른 사전 설치 gem과 계속 충돌 위험

**Bundler 방식이 근본 해결책인 이유**:
- `Gemfile`에 fastlane만 명시하여 격리된 번들 스코프 생성
- `bundle exec fastlane`은 전역 gem 환경 대신 번들 스코프 내에서만 실행
- `retriable` 등 Runner 사전 설치 gem과 완전히 분리되어 충돌 불가능

### ✅ 구현 내용

#### Android 테스트 APK 워크플로우
- **파일**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`
- **Install Fastlane 스텝 변경**: `working-directory: android` 추가, `Gemfile` 생성 후 `bundle install`
- **Build 스텝 변경**: `fastlane build --verbose` → `bundle exec fastlane build --verbose`

#### Android CICD (Playstore) 워크플로우
- **파일**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`
- **Install Fastlane 스텝 변경**: `working-directory: android` 추가, Bundler 방식으로 전환
- **Deploy 스텝 변경**: `cd android && fastlane deploy_internal` → `cd android && bundle exec fastlane deploy_internal`

#### iOS TestFlight (프로덕션) 워크플로우
- **파일**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`
- **Install Fastlane 스텝 변경**: `working-directory: ios` 추가, Bundler 방식으로 전환
- **Upload 스텝 변경**: `bundle exec fastlane upload_testflight` 적용

#### iOS 테스트 TestFlight 워크플로우
- **파일**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`
- **Install Fastlane 스텝 변경**: `working-directory: ios` 추가, Bundler 방식으로 전환
- **Upload 스텝 변경**: `bundle exec fastlane upload_testflight` 적용

#### Android Synology CICD 워크플로우
- **파일**: `.github/workflows/project-types/flutter/synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml`
- **Install Fastlane 스텝 변경**: `working-directory: android` 추가, Bundler 방식으로 전환
- **Build 스텝 변경**: `cd android && fastlane build --verbose` → `cd android && bundle exec fastlane build --verbose`

### 🔧 주요 변경사항 상세

#### Bundler 설치 패턴 (Android)
```yaml
- name: Install Fastlane
  working-directory: android
  run: |
    printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile
    bundle install
    echo "Fastlane installed (Bundler)"
    bundle exec fastlane --version
```

#### Bundler 설치 패턴 (iOS)
```yaml
- name: Install Fastlane
  working-directory: ios
  run: |
    printf 'source "https://rubygems.org"\ngem "fastlane"\n' > Gemfile
    bundle install
    echo "✅ Fastlane installed (Bundler)"
```

**특이사항**:
- `Gemfile`은 CI 실행 시 `android/` 또는 `ios/` 디렉토리에 동적 생성 (저장소 커밋 불필요)
- `bundle exec fastlane` 실행은 해당 디렉토리 기준으로 번들 스코프를 로드하므로 `working-directory` 또는 `cd` 경로가 일치해야 함
- `bundle install` 소요 시간은 `gem install`과 유사하며, Bundler 캐시 적용 시 단축 가능

### 🧪 테스트 및 검증
- `gem install fastlane` 잔여 없음 확인 (전체 flutter 워크플로우 검색)
- `bundle exec fastlane` 8개 인스턴스 (5개 파일) 정상 적용 확인
- 5개 파일 YAML 파일 읽기 유효성 확인 완료

### 📌 참고사항
- 이전 `--force` 패치(2026-02-19)는 동일 커밋에서 이 방식으로 교체됨
- Ruby 버전 변경 또는 Runner 이미지 업데이트와 무관하게 안정적으로 동작
- `bundle install` 속도 개선이 필요하면 `actions/cache`에 `~/.bundle` 경로 추가 가능
