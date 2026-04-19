# macos-26 러너에서 iOS 26.0 빌드 실패 수정 - DEVELOPER_DIR 명시적 설정

**이슈**: [#218](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/218)

---

### 📌 작업 개요

GitHub Actions `macos-26` 러너에서 iOS 빌드 시 `iOS 26.0 is not installed` 오류 발생. `sudo xcode-select -s`로 Xcode 경로를 변경해도 현재 셸의 `DEVELOPER_DIR` 환경변수는 자동으로 세팅되지 않아, 서브프로세스(`flutter build ios`, `xcodebuild`)가 잘못된 Xcode를 참조하는 것이 원인. 빌드·아카이브 스텝에 `DEVELOPER_DIR`을 명시적으로 추가하여 해결.

---

### 🔍 문제 분석

**에러 메시지**:
```
Unable to find a destination matching the provided destination specifier:
  { generic/platform=iOS, error: iOS 26.0 is not installed. }
```

**원인 흐름**:
1. `sudo xcode-select -s /Applications/Xcode_26.0.app/Contents/Developer` 실행
2. 글로벌 심볼릭 링크만 변경됨 — 현재 셸의 `DEVELOPER_DIR` 환경변수는 **자동 전파 안 됨**
3. `flutter build ios`, `xcodebuild archive`가 `DEVELOPER_DIR` 없이 실행되어 기존 Xcode 참조
4. 기존 Xcode에 iOS 26.0 SDK 없음 → 빌드 실패

---

### ✅ 구현 내용

#### Flutter build (no codesign) 스텝에 DEVELOPER_DIR 추가
- **파일**: `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`, `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`
- **변경 내용**: `Flutter build (no codesign)` 스텝에 `env: DEVELOPER_DIR` 명시적 추가
- **이유**: flutter 내부에서 호출하는 xcodebuild가 Xcode 26.0을 정확히 참조하도록 강제

#### Create Archive 스텝에 DEVELOPER_DIR 추가
- **파일**: `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`, `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`
- **변경 내용**: `Create Archive` 스텝에 `env: DEVELOPER_DIR` 명시적 추가
- **이유**: `xcodebuild archive -destination 'generic/platform=iOS'` 실행 시 iOS 26.0 SDK를 정확히 찾도록 강제

#### Install iOS device platform 스텝에도 DEVELOPER_DIR 추가
- **파일**: `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`
- **변경 내용**: `Install iOS device platform` 스텝에도 동일한 `DEVELOPER_DIR` 추가
- **이유**: `xcodebuild -downloadPlatform iOS` 실행 시에도 올바른 Xcode 경로 참조 보장

---

### 🔧 주요 변경사항 상세

#### 적용된 환경변수 설정 패턴

```yaml
- name: Flutter build (no codesign)
  env:
    # xcode-select만으로는 서브프로세스에 전파되지 않아 명시적으로 지정
    DEVELOPER_DIR: /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
  run: |
    flutter build ios --release --no-codesign ...

- name: Create Archive
  env:
    # xcode-select만으로는 서브프로세스에 전파되지 않아 명시적으로 지정
    DEVELOPER_DIR: /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer
  run: |
    xcodebuild -workspace Runner.xcworkspace ...
```

**특이사항**:
- `env.XCODE_VERSION` 변수를 활용하여 `DEVELOPER_DIR` 경로 구성. 향후 Xcode 버전 업그레이드 시 `XCODE_VERSION` 값만 수정하면 자동 반영됨
- `sudo xcode-select -s` 스텝은 유지. `DEVELOPER_DIR`과 병행 설정하는 방식으로 호환성 확보
- `IOS_PROVISIONING_PROFILE_NAME` 등 기존 `env` 항목이 있는 스텝은 해당 항목 아래에 `DEVELOPER_DIR`을 추가하는 방식으로 적용

#### 영향 파일 요약
| 파일 | 수정된 스텝 |
|------|------------|
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` | Install iOS device platform, Flutter build (no codesign), Create Archive |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | Flutter build (no codesign), Create Archive |

---

### 🧪 테스트 및 검증

- `macos-26` 러너에서 iOS 빌드 정상 완료 확인
- TestFlight 배포까지 전체 파이프라인 정상 동작 확인 (RomRom-FE #756에서 선행 검증)

---

### 📌 참고사항

- `DEVELOPER_DIR`은 `xcodebuild`, `xcrun` 등 Xcode CLI 도구에서 가장 우선 참조하는 Xcode 경로 지정 방법. `xcode-select` 변경과 달리 서브셸까지 확실히 전파됨
- 이 수정은 RomRom-FE 레포의 동일 이슈([#756](https://github.com/TEAM-ROMROM/RomRom-FE/issues/756)) 해결 경험을 바탕으로 템플릿에 반영
