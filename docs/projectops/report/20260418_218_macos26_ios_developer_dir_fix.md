# macos-26 러너에서 iOS 26.0 빌드 실패 - DEVELOPER_DIR 미설정 수정

## 개요

GitHub Actions `macos-26` 러너에서 `sudo xcode-select -s`로 Xcode 26.0 경로를 지정해도 `DEVELOPER_DIR` 환경변수가 서브프로세스에 자동으로 전파되지 않아 `flutter build ios` 및 `xcodebuild archive` 실행 시 `iOS 26.0 is not installed` 오류가 발생하는 문제를 수정. Flutter 빌드 및 Archive 스텝에 `DEVELOPER_DIR` 환경변수를 명시적으로 추가하고, iOS SDK를 강제 설치하는 `Install iOS device platform` 스텝을 추가하여 해결.

## 변경 사항

### Flutter iOS TestFlight 워크플로우 (운영)
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`
  - `Flutter build (no codesign)` 스텝에 `env: DEVELOPER_DIR` 명시적 추가
  - `Create Archive` 스텝에 `env: DEVELOPER_DIR` 명시적 추가
  - `Select Xcode version` 이후 `Install iOS device platform` 스텝 신규 추가

### Flutter iOS 테스트 TestFlight 워크플로우 (테스트 빌드)
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`
  - `Flutter build (no codesign)` 스텝에 `env: DEVELOPER_DIR` 명시적 추가
  - `Create Archive` 스텝에 `env: DEVELOPER_DIR` 명시적 추가
  - `Select Xcode version` 이후 `Install iOS device platform` 스텝 신규 추가

### 이슈 문서
- `docs/suh-template/issues/756-ios-developer-dir-fix.md`: 이슈 내용 및 수정 사항 정리

## 주요 구현 내용

**문제 원인**: `xcode-select` 변경은 시스템 전역 심볼릭 링크를 바꾸는 명령이지만, 현재 셸 세션 및 서브프로세스의 `DEVELOPER_DIR` 환경변수는 자동으로 갱신되지 않음. `flutter build ios`는 내부적으로 `xcodebuild`를 호출하는데, `DEVELOPER_DIR`이 비어 있으면 기존 Xcode를 참조하게 되어 iOS 26.0 SDK를 찾지 못함.

**해결 방식**:

1. **`DEVELOPER_DIR` 명시적 지정**: `flutter build ios`와 `xcodebuild archive` 스텝 각각에 `env:` 블록으로 `DEVELOPER_DIR`을 직접 주입. `env.XCODE_VERSION` 변수를 활용하므로 향후 버전 업그레이드 시 최상단 `env` 블록의 `XCODE_VERSION` 값만 변경하면 자동 반영.

```yaml
- name: Flutter build (no codesign)
  env:
    DEVELOPER_DIR: /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
  run: flutter build ios --release --no-codesign ...

- name: Create Archive
  env:
    DEVELOPER_DIR: /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
  run: xcodebuild -workspace Runner.xcworkspace ...
```

2. **`Install iOS device platform` 스텝 추가**: `macos-26` 러너 환경에서 iOS SDK가 완전히 초기화되지 않을 수 있어 MobileDevice 패키지 설치, Xcode 라이선스 동의, iOS 플랫폼 다운로드를 명시적으로 수행.

```yaml
- name: Install iOS device platform
  env:
    DEVELOPER_DIR: /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
  run: |
    sudo installer -pkg /Applications/Xcode_26.0.app/.../MobileDevice.pkg -target /
    sudo installer -pkg /Applications/Xcode_26.0.app/.../MobileDeviceDevelopment.pkg -target /
    sudo xcodebuild -license accept
    xcrun simctl list >/dev/null 2>&1 || true
    xcodebuild -downloadPlatform iOS
```

## 주의사항

- 이번 수정은 `SUH-DEVOPS-TEMPLATE` 원본에 반영한 것으로, 이 템플릿으로 새로 생성되는 프로젝트에는 자동으로 적용됨
- 기존 프로젝트(RomRom-FE 등 이미 통합된 프로젝트)는 `template_integrator.sh`로 업데이트하거나 수동으로 동일 변경 사항 적용 필요
- `Install iOS device platform` 스텝은 빌드 시간을 수 분 늘릴 수 있으나, `macos-26` 러너 안정성을 위해 필수
