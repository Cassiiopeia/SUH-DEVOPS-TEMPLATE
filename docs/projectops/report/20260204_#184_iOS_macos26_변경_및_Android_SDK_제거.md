# iOS 워크플로우 macos-26 변경 및 Android SDK 관리 로직 제거

**이슈**: [#184](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/184)

---

### 📌 작업 개요

macOS 15 지원 종료로 인한 Flutter iOS 빌드 실패 문제 수정. 모든 iOS 워크플로우의 runner를 macos-26으로 변경하고, Android 워크플로우에서 불필요한 SDK 설정 로직 제거.

---

### 🔍 문제 분석

**iOS 빌드 실패 원인**:
- GitHub Actions에서 `macos-15` runner 지원 종료
- iOS 26.0 SDK는 Xcode 26.0에서만 제공되며, `macos-26` runner에서만 사용 가능

**Android 빌드 문제 원인**:
- `android-actions/setup-android@v3` action이 SDK 라이선스 수락 문제 발생
- Flutter가 자체적으로 Android SDK를 관리하므로 별도 설정 불필요

---

### ✅ 구현 내용

#### 1. iOS 워크플로우 runner 변경 (macos-15 → macos-26)

| 파일 | 변경 위치 |
|------|----------|
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` | 3곳 (prepare-test-build, build-ios-test, deploy-testflight-test) |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | 3곳 (prepare-build, build-ios, deploy-testflight) |
| `PROJECT-FLUTTER-CI.yaml` | 1곳 (build-ios) |

**변경 내용**:
```yaml
# 변경 전
runs-on: macos-15

# 변경 후
runs-on: macos-26
```

#### 2. Android SDK 설정 로직 제거

| 파일 | 제거된 내용 |
|------|------------|
| `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` | `android-actions/setup-android@v3` action 및 검증 step |
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml` | `android-actions/setup-android@v3` action 및 검증 step |

**제거된 코드**:
```yaml
# 제거됨
- name: Set up Android SDK
  uses: android-actions/setup-android@v3

- name: Verify Android SDK setup
  run: echo "Android SDK setup completed"
```

#### 3. Android 키스토어 설정 단순화 (TEST-APK)

| 파일 | 변경 내용 |
|------|----------|
| `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` | DEBUG_KEYSTORE 조건 로직 제거, RELEASE_KEYSTORE 직접 사용 |

**변경 전** (복잡한 조건 로직):
```yaml
- name: Setup Debug Keystore
  run: |
    if [ -n "${{ secrets.DEBUG_KEYSTORE }}" ]; then
      # DEBUG_KEYSTORE 사용
    fi

- name: Setup Keystore and key.properties
  run: |
    if [ -n "${{ secrets.DEBUG_KEYSTORE }}" ]; then
      # DEBUG_KEYSTORE로 key.jks 생성
    fi
```

**변경 후** (Play Store 패턴과 동일):
```yaml
- name: Setup Release Keystore
  run: |
    mkdir -p android/keystore
    echo "${{ secrets.RELEASE_KEYSTORE_BASE64 }}" | base64 -d > android/keystore/key.jks

- name: Create key.properties
  run: |
    cat > android/key.properties << EOF
    storeFile=keystore/key.jks
    storePassword=${{ secrets.RELEASE_KEYSTORE_PASSWORD }}
    keyAlias=${{ secrets.RELEASE_KEY_ALIAS }}
    keyPassword=${{ secrets.RELEASE_KEY_PASSWORD }}
    EOF
```

**이유**: DEBUG_KEYSTORE는 불필요한 관리 포인트 - Play Store 워크플로우와 동일한 RELEASE_KEYSTORE 사용

#### 4. iOS Platform 다운로드 스텝 추가

| 파일 | 변경 위치 |
|------|----------|
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` | 2곳 (prepare-test-build, build-ios-test) |

**추가된 코드**:
```yaml
- name: Install iOS Platform
  run: |
    echo "📱 iOS Platform 다운로드 중..."
    xcodebuild -downloadPlatform iOS
    echo "✅ iOS Platform 설치 완료"
```

**이유**: iOS 26.0 SDK는 Xcode 26.0 선택만으로 자동 설치되지 않음, 명시적 다운로드 필요

#### 5. 워크플로우 주석 표준화 (WORKFLOW-COMMENT-GUIDELINES.md 준수)

| 파일 | 변경 내용 |
|------|----------|
| `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | 주석 형식 표준화 |
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` | 주석 형식 표준화 |
| `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` | 주석 형식 표준화 (RELEASE_KEYSTORE 반영) |

**변경 전** (비표준 형식):
```yaml
# 📋 필요한 GitHub Secrets
# ...
#   - SECRET_NAME: 설명
```

**변경 후** (Type E 표준 형식):
```yaml
# 🔑 필수 GitHub Secrets
# ===================================================================
#
# 🔐 그룹 헤더:
# SECRET_NAME: 설명
```

**수정 내용**:
- `📋 필요한` → `🔑 필수` 헤더 변경
- bullet point 형식 (`#   - SECRET:`) → 1줄 형식 (`# SECRET:`)
- 그룹 헤더에서 "(필수)" 텍스트 제거 (기본이 필수이므로)
- 선택 항목만 `(선택)` 표시

---

### 🔧 주요 변경사항 상세

#### iOS 워크플로우 (총 7곳 변경)

**PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml** (테스트 빌드):
- Line 66: `prepare-test-build` job
- Line 397: `build-ios-test` job
- Line 662: `deploy-testflight-test` job

**PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml** (자동 배포):
- Line 91: `prepare-build` job
- Line 217: `build-ios` job
- Line 336: `deploy-testflight` job

**PROJECT-FLUTTER-CI.yaml** (CI 검증):
- Line 441: `build-ios` job

#### Android 워크플로우 (2개 파일)

**PROJECT-FLUTTER-ANDROID-TEST-APK.yaml**:
- `android-actions/setup-android@v3` action 제거
- 검증 step 제거

**synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml**:
- `android-actions/setup-android@v3` action 제거
- 검증 step 제거

---

### 🧪 테스트 및 검증

**검증 완료**:
- `macos-15` 패턴 검색 결과: 0개 (모두 제거됨)
- `setup-android` 패턴 검색 결과: 0개 (모두 제거됨)

**테스트 방법**:
1. PR에서 `@suh-lab ios build` 댓글로 iOS 빌드 트리거
2. PR에서 `@suh-lab apk build` 댓글로 Android 빌드 트리거
3. 각각 빌드 성공 확인

---

### 📌 참고사항

- `macos-26` runner는 사용자가 실제 프로젝트에서 테스트 완료
- GitHub Secrets 구조 변경 없음 (기존 wizard와 워크플로우 연동 유지)
- Xcode 버전 설정(`XCODE_VERSION: "26.0"`)과 runner 버전이 일치함

---

### 📁 변경된 파일 목록

```
.github/workflows/project-types/flutter/
├── PROJECT-FLUTTER-CI.yaml                    # macos-26 변경 (1곳)
├── PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml        # macos-26 변경 (3곳) + 주석 표준화
├── PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml   # macos-26 변경 (3곳) + iOS Platform 스텝 추가 (2곳) + 주석 표준화
├── PROJECT-FLUTTER-ANDROID-TEST-APK.yaml      # setup-android 제거 + 키스토어 설정 단순화 + 주석 표준화
└── synology/
    └── PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml  # setup-android 제거
```
