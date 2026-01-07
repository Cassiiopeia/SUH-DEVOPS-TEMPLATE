# Flutter CI/CD 전체 가이드

> Flutter 프로젝트를 위한 완전 자동화된 배포 파이프라인

---

## 목차

- [개요](#개요)
- [시스템 아키텍처](#시스템-아키텍처)
- [마법사 도구](#마법사-도구)
- [워크플로우 목록](#워크플로우-목록)
- [빠른 시작](#빠른-시작)

---

## 개요

SUH-DEVOPS-TEMPLATE의 Flutter CI/CD 시스템은 **마법사 도구**와 **GitHub Actions 워크플로우**의 조합으로 구성됩니다.

**핵심 특징:**
- 웹 UI 마법사로 복잡한 배포 설정 자동 생성
- PR/이슈 댓글로 테스트 빌드 트리거
- iOS TestFlight + Android Play Store 자동 배포

---

## 시스템 아키텍처

### 전체 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│                        초기 설정 단계                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🧙 TestFlight 마법사          🧙 Play Store 마법사              │
│  ├─ ExportOptions.plist        ├─ Fastfile                      │
│  ├─ Fastfile                   ├─ build.gradle.kts 서명 설정    │
│  └─ Gemfile                    └─ 서명 키 가이드                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        개발 중 테스트                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PR/이슈에 "@suh-lab build app" 댓글                            │
│                     ↓                                            │
│  PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml (트리거)        │
│                     ↓                                            │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ PROJECT-FLUTTER-ANDROID-TEST-APK.yaml  → APK 아티팩트   │    │
│  │ PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml → TestFlight   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                     ↓                                            │
│  빌드 결과 댓글 자동 작성                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        본 배포 단계                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  deploy 브랜치 push                                              │
│           ↓                                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml      → TestFlight   │    │
│  │ PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml → Play Store│    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 마법사-워크플로우 관계

```
.github/util/flutter/testflight-wizard/
    → 생성: ExportOptions.plist, Fastfile, Gemfile
    → 사용 워크플로우:
        - PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml (본 배포)
        - PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml (테스트)

.github/util/flutter/playstore-wizard/
    → 생성: Fastfile, build.gradle.kts 서명 설정
    → 사용 워크플로우:
        - PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml (본 배포)
        - PROJECT-FLUTTER-ANDROID-TEST-APK.yaml (테스트)
```

---

## 마법사 도구

| 마법사 | 용도 | 상세 가이드 |
|--------|------|------------|
| **TestFlight 마법사** | iOS 배포 설정 자동 생성 | [FLUTTER-TESTFLIGHT-WIZARD.md](FLUTTER-TESTFLIGHT-WIZARD.md) |
| **Play Store 마법사** | Android 배포 설정 자동 생성 | [FLUTTER-PLAYSTORE-WIZARD.md](FLUTTER-PLAYSTORE-WIZARD.md) |

---

## 워크플로우 목록

### 본 배포 워크플로우

| 워크플로우 | 용도 | 트리거 |
|-----------|------|--------|
| `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | iOS TestFlight 배포 | deploy 브랜치 push |
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | Android Play Store 배포 | deploy 브랜치 push |
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml` | Android Synology NAS 배포 | deploy 브랜치 push |

### 테스트 빌드 워크플로우

| 워크플로우 | 용도 | 트리거 |
|-----------|------|--------|
| `PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml` | 빌드 트리거 감지 | `@suh-lab build app` 댓글 |
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` | iOS 테스트 빌드 | repository_dispatch |
| `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` | Android APK 테스트 빌드 | repository_dispatch |

상세 가이드: [FLUTTER-TEST-BUILD-TRIGGER.md](FLUTTER-TEST-BUILD-TRIGGER.md)

---

## 빠른 시작

### 1단계: 마법사로 설정 파일 생성

```bash
# iOS TestFlight 설정
open .github/util/flutter/testflight-wizard/testflight-wizard.html

# Android Play Store 설정
open .github/util/flutter/playstore-wizard/playstore-wizard.html
```

### 2단계: GitHub Secrets 설정

**iOS (TestFlight):**
- `IOS_CERTIFICATE_BASE64` - Apple 배포 인증서
- `IOS_CERTIFICATE_PASSWORD` - 인증서 비밀번호
- `IOS_PROVISIONING_PROFILE_BASE64` - Provisioning Profile
- `APP_STORE_CONNECT_API_KEY_ID` - App Store Connect API Key ID
- `APP_STORE_CONNECT_API_ISSUER_ID` - Issuer ID
- `APP_STORE_CONNECT_API_KEY_CONTENT` - API Key 내용

**Android (Play Store):**
- `ANDROID_KEYSTORE_BASE64` - 서명 키스토어
- `ANDROID_KEYSTORE_PASSWORD` - 키스토어 비밀번호
- `ANDROID_KEY_ALIAS` - 키 별칭
- `ANDROID_KEY_PASSWORD` - 키 비밀번호
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` - Google Play 서비스 계정

### 3단계: 워크플로우 설치

```bash
# template_integrator로 Flutter 워크플로우 설치
bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh") \
  --mode workflows --type flutter
```

### 4단계: 테스트 빌드 실행

PR 또는 이슈에 댓글 작성:
```
@suh-lab build app
```

---

## 파일 위치 요약

```
.github/
├── util/flutter/
│   ├── testflight-wizard/           # iOS 마법사
│   │   ├── testflight-wizard.html
│   │   ├── testflight-wizard.js
│   │   ├── testflight-wizard-setup.sh
│   │   └── templates/
│   │       ├── ExportOptions.plist
│   │       ├── Fastfile
│   │       └── Gemfile
│   │
│   └── playstore-wizard/            # Android 마법사
│       ├── playstore-wizard.html
│       ├── playstore-wizard.js
│       ├── playstore-wizard-setup.sh
│       ├── playstore-wizard-setup.ps1
│       └── templates/
│           ├── Fastfile.playstore.template
│           └── build.gradle.kts.signing.template
│
└── workflows/project-types/flutter/
    ├── PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml
    ├── PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml
    ├── PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml
    ├── PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml
    ├── PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml
    └── PROJECT-FLUTTER-ANDROID-TEST-APK.yaml
```

---

## 관련 문서

- [iOS TestFlight 마법사 상세](FLUTTER-TESTFLIGHT-WIZARD.md)
- [Android Play Store 마법사 상세](FLUTTER-PLAYSTORE-WIZARD.md)
- [테스트 빌드 트리거 상세](FLUTTER-TEST-BUILD-TRIGGER.md)
