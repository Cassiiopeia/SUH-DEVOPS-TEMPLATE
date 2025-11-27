# Flutter OAuth Key Generator

Android Keystore에서 OAuth 인증에 필요한 키를 자동으로 추출하고, 각 플랫폼 형식으로 변환해주는 도구입니다.

## 지원 OAuth 플랫폼

| 플랫폼 | 필요한 키 | 자동 생성 |
|--------|-----------|-----------|
| Google / Firebase | SHA-1, SHA-256 | ✅ |
| Kakao | Key Hash (Base64) | ✅ |
| Facebook | Key Hash (Base64) | ✅ |
| Naver | Package Name 기반 | 📝 안내 |
| GitHub | OAuth App URL | 📝 안내 |
| X (Twitter) | OAuth App URL | 📝 안내 |

## 빠른 시작

### 방법 1: 스크립트로 키 추출 (권장)

#### macOS / Linux

```bash
# 디버그 키스토어 (자동)
./extract-keys.sh --debug

# 대화형 모드
./extract-keys.sh

# 릴리즈 키스토어
./extract-keys.sh -k ~/my-release-key.jks -a my-alias -p mypassword
```

#### Windows (PowerShell)

```powershell
# 디버그 키스토어 (자동)
.\extract-keys.ps1 -Debug

# 대화형 모드
.\extract-keys.ps1

# 릴리즈 키스토어
.\extract-keys.ps1 -Keystore "C:\keys\release.jks" -Alias "my-alias" -Password "mypass"
```

### 방법 2: 웹 UI에서 확인

1. 스크립트 실행 후 생성된 `oauth-keys.json` 파일 확인
2. `index.html` 더블클릭하여 브라우저에서 열기
3. JSON 파일 드래그앤드롭 또는 파일 선택
4. 각 플랫폼별 키 확인 및 복사

### 방법 3: 수동 입력

1. `index.html` 열기
2. "수동 입력" 탭 선택
3. keytool로 추출한 SHA-1 값 입력
4. 자동으로 모든 형식으로 변환

## 스크립트 옵션

### extract-keys.sh (macOS/Linux)

```
옵션:
  -k, --keystore PATH    키스토어 파일 경로
  -a, --alias NAME       키 별칭 (기본: androiddebugkey)
  -p, --password PASS    키스토어 비밀번호 (기본: android)
  --debug                디버그 키스토어 자동 사용
  -o, --output FILE      출력 파일명 (기본: oauth-keys.json)
  -h, --help             도움말
```

### extract-keys.ps1 (Windows)

```
옵션:
  -Keystore PATH    키스토어 파일 경로
  -Alias NAME       키 별칭 (기본: androiddebugkey)
  -Password PASS    키스토어 비밀번호 (기본: android)
  -Debug            디버그 키스토어 자동 사용
  -Output FILE      출력 파일명 (기본: oauth-keys.json)
  -Help             도움말
```

## 출력 예시

### 터미널 출력

```
════════════════════════════════════════════════════════════════════
📱 추출된 OAuth 키
════════════════════════════════════════════════════════════════════

🔥 Google / Firebase
────────────────────────────────────────────────────────────────────
  SHA-1:          29:6F:C9:4E:7D:17:D5:2A:D6:F1:FE:70:A8:CB:7C:47:C4:71:76:01
  SHA-1 (콜론없음): 296FC94E7D17D52AD6F1FE70A8CB7C47C4717601
  SHA-256:        ...

🟡 Kakao
────────────────────────────────────────────────────────────────────
  Key Hash:       U9otbKrydm6c1RUlmiTbGQ6dzbg=

🔵 Facebook
────────────────────────────────────────────────────────────────────
  Key Hash:       U9otbKrydm6c1RUlmiTbGQ6dzbg=
```

### JSON 출력 (oauth-keys.json)

```json
{
  "generated_at": "2024-01-15T10:30:00Z",
  "keystore": {
    "path": "~/.android/debug.keystore",
    "alias": "androiddebugkey",
    "type": "debug"
  },
  "keys": {
    "sha1": "29:6F:C9:4E:7D:17:D5:2A:D6:F1:FE:70:A8:CB:7C:47:C4:71:76:01",
    "sha1_no_colon": "296FC94E7D17D52AD6F1FE70A8CB7C47C4717601",
    "sha256": "...",
    "key_hash_base64": "U9otbKrydm6c1RUlmiTbGQ6dzbg="
  },
  "platforms": {
    "google_firebase": {
      "sha1": "296FC94E7D17D52AD6F1FE70A8CB7C47C4717601",
      "console_url": "https://console.firebase.google.com"
    },
    "kakao": {
      "key_hash": "U9otbKrydm6c1RUlmiTbGQ6dzbg=",
      "console_url": "https://developers.kakao.com"
    },
    "facebook": {
      "key_hash": "U9otbKrydm6c1RUlmiTbGQ6dzbg=",
      "console_url": "https://developers.facebook.com"
    }
  }
}
```

## 각 플랫폼 설정 가이드

### 🔥 Google / Firebase

1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 선택 → 프로젝트 설정 → 일반
3. "내 앱" → Android 앱 선택
4. "SHA 인증서 지문" → SHA-1, SHA-256 추가

> **참고**: Firebase Console에는 **콜론 없는** SHA-1을 입력합니다.

### 💬 Kakao

1. [Kakao Developers](https://developers.kakao.com) 접속
2. 내 애플리케이션 → 앱 선택
3. 플랫폼 → Android → 키 해시 추가

> **참고**: Kakao는 **Base64 Key Hash**를 사용합니다.

### 📘 Facebook

1. [Meta for Developers](https://developers.facebook.com) 접속
2. My Apps → 앱 선택
3. Settings → Basic → Key Hashes 추가

> **참고**: Facebook도 **Base64 Key Hash**를 사용합니다.

### 🟢 Naver

1. [Naver Developers](https://developers.naver.com) 접속
2. Application → API 설정
3. 안드로이드 설정 → 패키지명 입력

> **참고**: Naver는 **Package Name** 기반으로 인증합니다.

## 필요 조건

- **JDK**: keytool 명령어 사용을 위해 필요
  - [Adoptium](https://adoptium.net/) 또는 다른 JDK 배포판 설치
  - Flutter 개발 환경이 있다면 이미 설치되어 있을 가능성이 높습니다

- **OpenSSL** (macOS/Linux만): Key Hash 생성에 필요
  - macOS: 기본 설치됨
  - Linux: `apt install openssl` 또는 `yum install openssl`

- **Windows**: OpenSSL 없이도 동작 (PowerShell 내장 암호화 사용)

## 디버그 키스토어 위치

| OS | 경로 |
|----|------|
| macOS / Linux | `~/.android/debug.keystore` |
| Windows | `%USERPROFILE%\.android\debug.keystore` |

## 보안 참고사항

- ✅ 모든 키 추출은 **로컬에서만** 수행됩니다
- ✅ 웹 UI는 **오프라인**에서 동작합니다
- ✅ 키가 외부 서버로 **전송되지 않습니다**
- ⚠️ 릴리즈 키스토어 비밀번호는 안전하게 관리하세요
- ⚠️ `oauth-keys.json` 파일을 git에 커밋하지 마세요 (`.gitignore`에 추가)

## 문제 해결

### keytool을 찾을 수 없습니다

```bash
# JDK 설치 확인
java -version

# JAVA_HOME 환경변수 확인
echo $JAVA_HOME  # macOS/Linux
echo %JAVA_HOME% # Windows

# keytool 직접 경로 사용
$JAVA_HOME/bin/keytool -list -v -keystore ~/.android/debug.keystore
```

### 디버그 키스토어를 찾을 수 없습니다

Android Studio에서 앱을 한 번이라도 빌드했는지 확인하세요. 처음 빌드 시 자동으로 생성됩니다.

```bash
# 수동 생성 (필요한 경우)
keytool -genkey -v -keystore ~/.android/debug.keystore \
  -storepass android -alias androiddebugkey -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000
```

### 비밀번호 오류

- 디버그 키스토어 기본 비밀번호: `android`
- 디버그 키스토어 기본 별칭: `androiddebugkey`

## 라이선스

MIT License - SUH-DEVOPS-TEMPLATE
