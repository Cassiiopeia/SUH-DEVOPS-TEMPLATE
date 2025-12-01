# Flutter Play Store CI/CD Setup Wizard

Flutter 프로젝트를 위한 Play Store 내부 테스트 CI/CD 자동 설정 도구입니다.

## 사용 방법

### 1. HTML 위자드 열기

브라우저에서 `index.html` 파일을 열어 마법사를 시작합니다:

```bash
# Mac
open .github/util/flutter/android-playstore-setup-wizard/index.html

# Windows
start .github/util/flutter/android-playstore-setup-wizard/index.html

# Linux
xdg-open .github/util/flutter/android-playstore-setup-wizard/index.html
```

### 2. 프로젝트 분석 스크립트 실행

**Mac/Linux:**
```bash
cd /path/to/your/flutter/project
bash .github/util/flutter/android-playstore-setup-wizard/init.sh
```

**Windows (PowerShell):**
```powershell
cd C:\path\to\your\flutter\project
powershell -ExecutionPolicy Bypass -File .github/util/flutter/android-playstore-setup-wizard/init.ps1
```

스크립트 출력 (JSON)을 HTML 위자드에 붙여넣기 합니다.

### 3. 단계별 설정

1. **Step 1: 프로젝트 분석** - 스크립트 결과 붙여넣기
2. **Step 2: Keystore 생성** - Release 서명용 keystore 생성
3. **Step 3: 서명 설정** - build.gradle.kts 수정 코드 확인
4. **Step 4: Service Account** - Google Play Console API 설정
5. **Step 5: Fastlane** - 자동 배포 설정
6. **Step 6: 완료** - GitHub Secrets 목록 확인

### 4. 자동 적용 스크립트 (선택)

기본 디렉토리 구조와 파일을 자동 생성합니다:

**Mac/Linux:**
```bash
bash .github/util/flutter/android-playstore-setup-wizard/apply.sh
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File .github/util/flutter/android-playstore-setup-wizard/apply.ps1
```

## 생성되는 파일들

```
your-flutter-project/
├── android/
│   ├── app/
│   │   └── keystore/
│   │       └── key.jks          # Release keystore (직접 생성)
│   ├── fastlane/
│   │   └── Fastfile.playstore   # Fastlane 배포 설정
│   └── key.properties           # Keystore 정보 (Git 제외)
└── .gitignore                   # 자동 업데이트
```

## GitHub Secrets 목록

| Secret 이름 | 설명 |
|------------|------|
| `RELEASE_KEYSTORE_BASE64` | Release keystore 파일 (Base64 인코딩) |
| `RELEASE_KEYSTORE_PASSWORD` | Keystore 비밀번호 |
| `RELEASE_KEY_ALIAS` | Key alias 이름 |
| `RELEASE_KEY_PASSWORD` | Key 비밀번호 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` | Play Store API 인증 JSON (Base64) |
| `GOOGLE_SERVICES_JSON` | Firebase 설정 (선택) |
| `ENV_FILE` | 환경변수 파일 (선택) |

## Keystore 생성 명령어

```bash
keytool -genkey -v \
  -keystore release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias your-key-alias
```

## Base64 인코딩

**Mac/Linux:**
```bash
base64 -i release-key.jks > release-key-base64.txt
```

**Windows PowerShell:**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release-key.jks")) > release-key-base64.txt
```

## Google Play Service Account 설정

1. Play Console → 설정 → API 액세스
2. "서비스 계정 만들기" 또는 Google Cloud Console 링크 클릭
3. Google Cloud Console에서:
   - IAM 및 관리자 → 서비스 계정 → 만들기
   - 키 만들기 → JSON → 다운로드
4. Play Console에서 서비스 계정에 앱 권한 부여

## 주의사항

- **Keystore 백업 필수**: Release keystore를 분실하면 앱 업데이트 불가능
- **첫 번째 릴리스는 수동으로**: Play Console에서 앱 정보 먼저 설정 필요
- **Package name 확인**: `applicationId`가 Play Console에 등록된 것과 일치해야 함

## 파일 구조

```
.github/util/flutter/android-playstore-setup-wizard/
├── index.html              # 메인 위자드 UI
├── init.sh                 # 프로젝트 분석 (Mac/Linux)
├── init.ps1                # 프로젝트 분석 (Windows)
├── apply.sh                # 자동 적용 (Mac/Linux)
├── apply.ps1               # 자동 적용 (Windows)
├── README.md               # 이 파일
├── assets/
│   └── guide-images/       # 가이드 이미지 (선택)
└── templates/
    ├── Fastfile.playstore.template
    └── build.gradle.kts.signing.template
```

## 트러블슈팅

### keytool 명령어를 찾을 수 없음
Java JDK가 설치되어 있어야 합니다. Flutter 설치 시 포함되어 있을 수 있습니다.

### jq 명령어를 찾을 수 없음 (init.sh)
jq 없이도 기본 파싱이 가능하지만, 설치하면 더 정확한 분석이 가능합니다:
- Mac: `brew install jq`
- Ubuntu: `sudo apt-get install jq`

### PowerShell 실행 정책 오류
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
