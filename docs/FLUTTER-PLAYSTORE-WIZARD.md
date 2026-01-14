# Android Play Store 마법사 상세 가이드

> Flutter Android 앱을 Play Store에 배포하기 위한 설정 마법사

---

## 목차

- [개요](#개요)
- [사전 요구사항](#사전-요구사항)
- [마법사 사용법](#마법사-사용법)
- [생성되는 파일](#생성되는-파일)
- [GitHub Secrets 설정](#github-secrets-설정)
- [연관 워크플로우](#연관-워크플로우)
- [트러블슈팅](#트러블슈팅)

---

## 개요

Play Store 마법사는 웹 UI를 통해 Android 배포에 필요한 설정 파일들을 자동으로 생성해주는 도구입니다.

**위치:** `.github/util/flutter/playstore-wizard/`

**버전:** 1.0.0

**호환성:**
- Flutter >= 3.0.0
- Android SDK >= 33
- Fastlane >= 2.220.0

---

## 사전 요구사항

마법사 실행 전에 다음 항목들을 준비해야 합니다:

### 1. Google Play Console 등록
- [play.google.com/console](https://play.google.com/console) 에서 개발자 계정 등록
- 일회성 등록비 $25

### 2. 서명 키 생성
- Release 서명용 Keystore 파일 필요
- 키 분실 시 앱 업데이트 불가능하므로 안전하게 보관

```bash
# Keystore 생성 명령어
keytool -genkey -v -keystore release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release-key
```

### 3. Google Play 서비스 계정 생성
- Google Cloud Console에서 서비스 계정 생성
- Play Console과 연동
- JSON 키 파일 다운로드

---

## 마법사 사용법

### 실행 방법

```bash
# 브라우저에서 마법사 열기
open .github/util/flutter/playstore-wizard/playstore-wizard.html

# 또는 설정 스크립트 실행
# macOS/Linux
.github/util/flutter/playstore-wizard/playstore-wizard-setup.sh

# Windows
.github/util/flutter/playstore-wizard/playstore-wizard-setup.ps1
```

### 마법사 진행 단계

| 단계 | 내용 | 입력 정보 |
|------|------|-----------|
| 1 | 시작 | 마법사 소개 |
| 2 | 키스토어 | 서명 키 생성 가이드 |
| 3 | 서비스 계정 | Google Play 서비스 계정 생성 가이드 |
| 4 | 앱 정보 | Application ID 입력 |
| 5 | Fastlane | 생성된 설정 파일 다운로드 |
| 6 | 완료 | 설정 완료 확인 |

### 입력해야 할 정보

```yaml
# Application ID (패키지명)
Application ID: "com.company.appname"

# Keystore 정보
Keystore Path: "android/app/release-key.jks"
Keystore Password: "your-keystore-password"
Key Alias: "release-key"
Key Password: "your-key-password"
```

---

## 생성되는 파일

### 1. Fastfile.playstore

Play Store 배포 자동화 스크립트입니다.

**위치:** `android/fastlane/Fastfile.playstore`

**제공하는 lane:**
- `deploy_internal` - Internal Testing 트랙 배포
- `validate` - 서비스 계정 검증
- `promote_to_beta` - Internal → Beta 승급
- `promote_to_production` - Beta → Production 승급 (10% rollout)

**필요한 환경변수:**
- `AAB_PATH` - AAB 파일 경로
- `GOOGLE_PLAY_JSON_KEY` - 서비스 계정 JSON 파일 경로

### 2. build.gradle.kts 서명 설정

앱 서명 설정 코드입니다.

**위치:** `android/app/build.gradle.kts` (수동 추가 필요)

```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file("release-key.jks")
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

---

## GitHub Secrets 설정

워크플로우 실행을 위해 다음 Secrets를 설정해야 합니다:

| Secret 이름 | 설명 | 값 형식 |
|------------|------|---------|
| `ANDROID_KEYSTORE_BASE64` | Release Keystore (.jks) | Base64 인코딩 |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore 비밀번호 | 문자열 |
| `ANDROID_KEY_ALIAS` | 키 별칭 | 문자열 |
| `ANDROID_KEY_PASSWORD` | 키 비밀번호 | 문자열 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | 서비스 계정 JSON 내용 | JSON 문자열 |

### Base64 인코딩 방법

```bash
# Keystore 인코딩
base64 -i release-key.jks | pbcopy   # macOS
base64 release-key.jks               # Linux
```

### 서비스 계정 JSON 설정

서비스 계정 JSON 파일 전체 내용을 Secret으로 설정합니다:

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "your-service-account@your-project.iam.gserviceaccount.com",
  "client_id": "...",
  ...
}
```

---

## 연관 워크플로우

### 본 배포
- **파일:** `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`
- **트리거:** deploy 브랜치 push
- **용도:** Play Store Internal Testing 배포

### 테스트 빌드
- **파일:** `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`
- **트리거:** `@suh-lab build app` 또는 `@suh-lab apk build` 댓글 (repository_dispatch)
- **용도:** PR/이슈에서 테스트 APK 빌드

### Synology NAS 배포
- **파일:** `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml`
- **트리거:** deploy 브랜치 push
- **용도:** 사내 Synology NAS에 APK 배포

---

## 트러블슈팅

### 서명 관련 오류

```
❌ Error: Keystore was tampered with, or password was incorrect
```

**해결:**
1. `ANDROID_KEYSTORE_PASSWORD`가 정확한지 확인
2. Base64 인코딩이 올바르게 되었는지 확인
3. Keystore 파일이 손상되지 않았는지 확인

### 서비스 계정 오류

```
❌ Error: The caller does not have permission
```

**해결:**
1. 서비스 계정에 Play Console 권한이 부여되었는지 확인
2. Play Console → Users and permissions → 서비스 계정 추가
3. "Release apps to testing tracks" 권한 필요

### AAB 파일 오류

```
❌ Error: AAB file not found
```

**해결:**
1. Flutter 빌드가 성공했는지 확인
2. `flutter build appbundle --release` 실행
3. AAB 파일 경로가 맞는지 확인: `build/app/outputs/bundle/release/app-release.aab`

### Application ID 불일치

```
❌ Error: Package name does not match
```

**해결:**
1. Fastfile의 `package_name`과 `android/app/build.gradle`의 `applicationId` 일치 확인
2. Play Console에 등록된 패키지명과 일치하는지 확인

---

## 파일 구조

```
.github/util/flutter/playstore-wizard/
├── playstore-wizard.html          # 마법사 웹 UI
├── playstore-wizard.js            # 마법사 로직
├── playstore-wizard-setup.sh      # 설정 스크립트 (macOS/Linux)
├── playstore-wizard-setup.ps1     # 설정 스크립트 (Windows)
├── playstore-wizard-apply.sh      # 적용 스크립트
├── playstore-wizard-apply.ps1     # 적용 스크립트
├── detect-application-id.sh       # Application ID 감지
├── detect-application-id.ps1      # Application ID 감지
├── patch-build-gradle.py          # build.gradle 패치
├── version.json                   # 버전 정보
├── version-sync.sh                # 버전 동기화 스크립트
├── images/                        # 가이드 이미지
└── templates/
    ├── Fastfile.playstore.template         # Fastfile 템플릿
    └── build.gradle.kts.signing.template   # 서명 설정 템플릿
```

---

## 관련 문서

- [Flutter CI/CD 전체 가이드](FLUTTER-CICD-OVERVIEW.md)
- [테스트 빌드 트리거](FLUTTER-TEST-BUILD-TRIGGER.md)
- [Google Play Console 공식 문서](https://developer.android.com/distribute/console)
