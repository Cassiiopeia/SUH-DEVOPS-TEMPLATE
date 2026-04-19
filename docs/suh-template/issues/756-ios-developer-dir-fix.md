---
title: "❗ [버그][Flutter-iOS-CI] macos-26 러너에서 iOS 26.0 빌드 실패 - DEVELOPER_DIR 미설정"
labels: [작업전]
assignees: [Cassiiopeia]
---

<!--
이슈 제목 예시:
❗ [버그][Flutter-iOS-CI] macos-26 러너 iOS 26.0 빌드 실패 - DEVELOPER_DIR 미설정
-->

🗒️ 설명
---

`macos-26` GitHub Actions 러너에서 iOS 빌드 시 `iOS 26.0 is not installed` 오류 발생.

`sudo xcode-select -s` 명령으로 Xcode 26.0 경로를 지정해도 `DEVELOPER_DIR` 환경변수가
서브프로세스(`flutter build ios`, `xcodebuild`)에 자동으로 전파되지 않아 기존 Xcode를
참조하는 것이 원인.

**에러 메시지**:
```
Unable to find a destination matching the provided destination specifier:
  { generic/platform=iOS, error: iOS 26.0 is not installed. }
```

🔄 재현 방법
---

1. `macos-26` 러너 기반 Flutter iOS CI/CD 워크플로우 실행
2. `Select Xcode version` 스텝에서 `sudo xcode-select -s` 로 Xcode 26.0 지정
3. `Flutter build (no codesign)` 또는 `Create Archive` 스텝 실행
4. → `iOS 26.0 is not installed` 오류 발생

📸 참고 자료
---

- 관련 이슈 (RomRom-FE): https://github.com/TEAM-ROMROM/RomRom-FE/issues/756
- `xcode-select` 변경은 글로벌 심볼릭 링크 변경이며, 현재 셸의 `DEVELOPER_DIR` 환경변수는
  자동으로 세팅되지 않음
- `DEVELOPER_DIR` 환경변수는 `xcodebuild`, `xcrun` 등 Xcode CLI 도구에서 우선 참조

✅ 예상 동작
---

- `flutter build ios`, `xcodebuild archive` 실행 시 Xcode 26.0 SDK를 정상 참조
- iOS 26.0 플랫폼을 찾지 못하는 오류 없이 빌드 성공

⚙️ 수정 내용
---

**영향 파일**:
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`

**변경 1: `Flutter build (no codesign)` 스텝에 `DEVELOPER_DIR` 추가**
```yaml
- name: Flutter build (no codesign)
  env:
    DEVELOPER_DIR: /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
  run: |
    flutter build ios --release --no-codesign ...
```

**변경 2: `Create Archive` 스텝에 `DEVELOPER_DIR` 추가**
```yaml
- name: Create Archive
  env:
    DEVELOPER_DIR: /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
  run: |
    xcodebuild -workspace Runner.xcworkspace ...
```

**변경 3: `Install iOS device platform` 스텝 추가** (Select Xcode version 다음)
```yaml
- name: Install iOS device platform
  env:
    DEVELOPER_DIR: /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
  run: |
    sudo installer -pkg /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Resources/Packages/MobileDevice.pkg -target /
    sudo installer -pkg /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Resources/Packages/MobileDeviceDevelopment.pkg -target /
    sudo xcodebuild -license accept
    xcrun simctl list >/dev/null 2>&1 || true
    xcodebuild -downloadPlatform iOS
```

🙋‍♂️ 담당자
---

- **인프라/CI**: Cassiiopeia
