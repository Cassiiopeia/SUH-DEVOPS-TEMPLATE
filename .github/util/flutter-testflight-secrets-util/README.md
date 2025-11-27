# 🍎 iOS TestFlight Secrets Helper

Flutter iOS 앱을 TestFlight에 배포하기 위한 GitHub Secrets 값 생성 도구입니다.

## 사용 방법

### 1. 도구 실행

`index.html` 파일을 브라우저에서 열기만 하면 됩니다:

- **macOS**: `open index.html`
- **Windows**: 파일 더블클릭
- **직접 열기**: 브라우저에서 파일 드래그앤드롭

### 2. 필요한 파일 준비

| 파일 | 설명 | 획득 방법 |
|------|------|----------|
| `.p12` | 배포 인증서 | Keychain → Apple Distribution 우클릭 → 내보내기 |
| `.mobileprovision` | 프로비저닝 프로파일 | [developer.apple.com](https://developer.apple.com) → Profiles |
| `.p8` | App Store Connect API Key | [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Keys |

### 3. 정보 입력 & 시크릿 생성

1. 기본 정보 입력 (Bundle ID, Team ID 등)
2. 파일 드래그앤드롭
3. "시크릿 생성하기" 클릭
4. 각 값을 GitHub Secrets에 등록

## 생성되는 시크릿

| Secret Name | 설명 |
|-------------|------|
| `IOS_BUNDLE_ID` | 앱 번들 ID |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `IOS_PROVISIONING_PROFILE_NAME` | 프로비저닝 프로파일 이름 |
| `APPLE_CERTIFICATE_BASE64` | 배포 인증서 (Base64) |
| `APPLE_CERTIFICATE_PASSWORD` | 인증서 비밀번호 |
| `APPLE_PROVISIONING_PROFILE_BASE64` | 프로비저닝 프로파일 (Base64) |
| `APP_STORE_CONNECT_API_KEY_BASE64` | API Key (Base64) |
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |

## GitHub Secrets 등록

1. GitHub 저장소 → **Settings**
2. **Secrets and variables** → **Actions**
3. **New repository secret**
4. 각 시크릿 이름과 값 입력

## 보안

- ✅ **완전 로컬 처리** - 모든 파일 처리는 브라우저에서만 이루어집니다
- ✅ **서버 전송 없음** - 어떤 데이터도 외부로 전송되지 않습니다
- ✅ **오프라인 작동** - 인터넷 연결 없이도 사용 가능합니다

## 문제 해결

### 파일이 선택되지 않아요
- 지원 파일: `.p12`, `.mobileprovision`, `.p8`
- 파일 확장자를 확인하세요

### 복사가 안 돼요
- HTTPS 또는 localhost에서만 클립보드 API가 작동합니다
- 파일을 직접 열면 `file://` 프로토콜로 열리므로 "파일로 저장" 기능을 사용하세요

---

**SUH-DEVOPS-TEMPLATE** · [GitHub](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE)
