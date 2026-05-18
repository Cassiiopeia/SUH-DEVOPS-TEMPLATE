# Firebase App Distribution Wizard 설계 (firebase-wizard)

- 작성일: 2026-05-14
- 작성자: Cassiiopeia
- 상태: Draft

---

## 1. 배경

`PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`와 `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` 워크플로우는 Firebase App Distribution 업로드를 이미 지원한다. 그러나 신규 프로젝트에서 이 기능을 활성화하려면 사용자가 다음 5단계를 수동으로 수행해야 한다.

1. Firebase Console에서 프로젝트 생성, Android 앱 등록, App Distribution 활성화, 테스터 그룹 생성
2. Service Account 키 발급 + IAM 권한 부여
3. GitHub Repository Secrets에 `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`, `GOOGLE_SERVICES_JSON` 등 등록
4. 워크플로우 `env:` 섹션의 `{FIREBASE_APP_ID}`, `{TESTER_GROUP}` placeholder 치환
5. 트리거 테스트

기존 `playstore-wizard`, `testflight-wizard`와 동일 패턴으로 정적 HTML 마법사를 제공해 진입장벽을 낮춘다.

---

## 2. 목표 / 비목표

### 목표

- HTML 정적 마법사로 Firebase 배포 설정을 5단계로 안내한다.
- Service Account JSON → base64 변환, GitHub Secrets용 다운로드 산출물(JSON/TXT/ZIP)을 제공한다.
- 워크플로우 placeholder 치환을 위한 안전한 setup 스크립트(bash/PowerShell)를 제공한다.
- 기존 PlayStore/TestFlight wizard와 일관된 UX·디자인 시스템을 유지한다.

### 비목표

- Firebase Console 자동화(Management API 호출). Console 작업은 가이드만 제공한다.
- GitHub API를 통한 Secrets 자동 등록(PAT 입력·libsodium 암호화). 보안·단순성을 위해 사용자가 직접 등록한다.
- 빌드 트리거 자동화. 마지막 단계는 가이드만 제공한다.

---

## 3. 사용자 시나리오

신규 Flutter 프로젝트에 SUH 템플릿을 적용한 사용자가 Firebase App Distribution을 활성화하려는 상황.

1. `firebase-wizard.html` 파일을 브라우저에서 연다.
2. Step 1~2를 따라 Firebase Console과 IAM에서 외부 작업을 마친다.
3. Step 3에서 `FIREBASE_APP_ID`, `FIREBASE_TESTER_GROUP` 입력.
4. Step 4에서 Service Account JSON 파일과 (선택적으로) `google-services.json` 파일을 드래그 업로드.
5. Step 5에서 GitHub Secrets용 산출물을 다운로드하여 GitHub 페이지에 등록 + 워크플로우 placeholder 치환을 위한 setup 스크립트 실행.
6. PR/이슈에 `@suh-lab apk build` 댓글로 빌드 트리거 → Firebase App Distribution 자동 업로드 확인.

---

## 4. 아키텍처

### 4.1 파일 구조

```
.github/util/flutter/firebase-wizard/
├── firebase-wizard.html             # 메인 마법사 UI (단일 페이지)
├── firebase-wizard.js               # 폼 로직, 변환, 다운로드, localStorage
├── firebase-wizard-setup.sh         # 워크플로우 placeholder 치환 (bash)
├── firebase-wizard-setup.ps1        # 워크플로우 placeholder 치환 (PowerShell)
├── version.json                     # 버전 메타데이터
└── version-sync.sh                  # version.json → HTML 동기화
```

`templates/` 폴더는 Firebase의 경우 로컬 생성 파일이 거의 없으므로 만들지 않는다.

### 4.2 컴포넌트 책임

| 컴포넌트 | 책임 | 의존성 |
|---|---|---|
| `firebase-wizard.html` | 5단계 UI 렌더링, 외부 링크, 가이드 텍스트, 폼 마크업 | Tailwind CDN, JSZip CDN, Pretendard font CDN |
| `firebase-wizard.js` | step 전환, 파일 업로드 처리, base64 변환, 산출물 생성(JSON/TXT/ZIP), 복사·다운로드 트리거, localStorage 상태 저장, custom secrets 관리 | JSZip 전역, brower File API |
| `firebase-wizard-setup.sh` | 워크플로우 파일 라인 단위 안전 치환, 백업 생성, 충돌 시 사용자 프롬프트, summary 출력 | bash 4+, sed/grep/awk |
| `firebase-wizard-setup.ps1` | 위 동일 동작을 PowerShell 5.1 기반으로 구현 | PowerShell 5.1+ |
| `version.json` | wizard 버전·changelog·호환성 메타데이터 | (없음) |
| `version-sync.sh` | `version.json` 내용을 HTML 내장 `<script id="versionJson">` 블록에 주입 | python3 |

### 4.3 데이터 흐름

```
[사용자 입력]
  ├─ Step 3: APP_ID, TESTER_GROUP            ──┐
  ├─ Step 4: Service Account JSON file       ──┤
  ├─ Step 4: google-services.json (선택)      ──┤
  └─ Step 4: custom secrets (key+file/text)  ──┤
                                                │
                                                ▼
                          [JS state object + localStorage]
                                                │
                                                ▼
                  ┌─────────────────────────────┴─────────────────────────────┐
                  │                                                            │
                  ▼                                                            ▼
        [Step 5 산출물 생성]                                  [setup 스크립트 인자 명령 표시]
          ├─ Secret 키별 복사 버튼                              ├─ macOS/Linux 탭 (bash 명령)
          ├─ JSON 다운로드                                      └─ Windows 탭 (PowerShell 명령)
          ├─ TXT 다운로드                                              │
          └─ ZIP 다운로드 (setup 스크립트 포함)                        │
                                                                       │
                                                                       ▼
                                                       [사용자가 setup 스크립트 실행]
                                                                       │
                                                                       ▼
                                                       [.github/workflows/*.{yaml,yml} 안전 치환]
```

---

## 5. UI 설계 (5단계)

각 step은 기존 PlayStore/TestFlight wizard와 동일한 카드 레이아웃을 따른다.

- 카드 헤더: 단계 번호 박스 + 제목 + 라벨
- 설명 박스 (배경색 강조)
- 외부 링크 "바로가기" 버튼 (SVG 아이콘 포함)
- 가이드 박스 (`ol` 단계 리스트, 강조 마크업)
- CSS로 그린 미니 UI 시뮬레이션 (Console 화면 흉내, 스크린샷 사용 안 함)
- 입력 필드 / 파일 업로드 영역 (해당 단계만)
- 이전 / 다음 / 건너뛰기 버튼

### Step 1: Firebase Console 가이드

- Firebase Console 바로가기 (https://console.firebase.google.com)
- 4개 sub 작업 가이드: 프로젝트 생성, Android 앱 등록, App Distribution 활성화, 테스터 그룹 생성
- 각 sub 작업은 카드 안 노란색 박스로 구분
- "이미 다 했어요 →" 건너뛰기 옵션

### Step 2: Service Account 발급 + IAM 권한 부여

- Google Cloud Console (Service Accounts) 바로가기
- IAM & Admin 페이지 바로가기
- 가이드: Service Account 생성 → JSON 키 발급 → IAM에서 "Firebase App Distribution Admin" 역할 부여
- 검증 체크리스트 (사용자 자체 확인용)

### Step 3: 앱 정보 입력

- 입력 필드 2개:
  - `FIREBASE_APP_ID` (예: `1:905325245238:android:86db75164e0df29a1f3997`)
  - `FIREBASE_TESTER_GROUP` (예: `romrom`)
- 입력값을 미리 채운 setup 스크립트 호출 명령 표시 (OS별 탭)
  - macOS/Linux 탭: `./firebase-wizard-setup.sh --project-path . --app-id "..." --tester-group "..."`
  - Windows 탭: `.\firebase-wizard-setup.ps1 -ProjectPath . -AppId "..." -TesterGroup "..."`
- 각 명령에 복사 버튼

### Step 4: 파일 업로드 → 변환

- Service Account JSON 드래그 업로드 영역 (필수)
  - 업로드 즉시 base64 변환, 결과 미리보기 (앞 100자)
- google-services.json 드래그 업로드 영역 (선택)
  - 원본 그대로 사용
- "추가 Secrets" 섹션 (PlayStore wizard v1.2.0 패턴 동일)
  - 사용자 정의 key 입력 + 파일 업로드 또는 텍스트 입력
  - 파일 타입에 따라 자동 변환 (텍스트 → 원본, 바이너리 → base64, `_BASE64` 접미사 자동 추가)
  - localStorage에 상태 저장

### Step 5: GitHub Secrets 등록 + 산출물 다운로드

- GitHub Secrets 페이지 바로가기 (`https://github.com/{owner}/{repo}/settings/secrets/actions`)
  - 사용자가 owner/repo 입력 시 위 URL을 동적으로 조립해 "Secrets 페이지 열기" 버튼 활성화
  - 미입력 시 https://github.com 일반 링크로 fallback. 입력값은 어디에도 저장·전송되지 않음
- Secret 키 매핑 표:

  | Secret 이름 | 값 출처 | 인코딩 |
  |---|---|---|
  | `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` | Step 4 SA JSON | base64 |
  | `GOOGLE_SERVICES_JSON` | Step 4 google-services.json | 원본 |
  | (custom keys) | Step 4 custom secrets | 자동 판별 |

- 각 Secret 행마다 "값 복사" 버튼
- 산출물 다운로드 버튼 3개:
  - JSON: `firebase-secrets-{appId}-{date}.json`
  - TXT: `firebase-secrets-{appId}-{date}.txt`
  - ZIP: `firebase-setup-{appId}-{date}.zip` (setup 스크립트 + secrets 폴더 + README 포함)

---

## 6. setup 스크립트 알고리즘

### 6.1 인터페이스

bash:
```bash
./firebase-wizard-setup.sh \
  --project-path /path/to/project \
  --app-id "1:905325245238:android:86db75164e0df29a1f3997" \
  --tester-group "romrom" \
  [--dry-run] \
  [--non-interactive] \
  [--no-backup]
```

PowerShell:
```powershell
.\firebase-wizard-setup.ps1 `
  -ProjectPath "C:\path\to\project" `
  -AppId "1:905325245238:android:86db75164e0df29a1f3997" `
  -TesterGroup "romrom" `
  [-DryRun] `
  [-NonInteractive] `
  [-NoBackup]
```

### 6.2 처리 흐름

```
1. 인자 검증
   - project-path 존재 확인
   - .github/workflows 폴더 존재 확인 (없으면 abort)
   - app-id, tester-group non-empty 확인

2. 대상 파일 자동 탐지
   - .github/workflows/*.yaml, .github/workflows/*.yml glob
   - 각 파일에 FIREBASE_APP_ID 또는 FIREBASE_TESTER_GROUP 키 있는지 확인
   - 둘 다 없는 파일은 SKIP (summary에 "키 없음" 표시)

3. 파일별 처리 루프
   for each 대상 파일:
     a. 백업 생성: <file>.bak.<timestamp> (--no-backup이면 skip)
     b. 라인 단위 순회
        for each line:
          regex: ^(\s*)(FIREBASE_APP_ID|FIREBASE_TESTER_GROUP)(\s*:\s*)(.*)$
          if match:
            key = $2, indent = $1, separator = $3, raw_value = $4
            old_value = trim 따옴표·공백 from raw_value
            new_value = (key == FIREBASE_APP_ID ? app-id : tester-group)

            if old_value == "{FIREBASE_APP_ID}" or "{TESTER_GROUP}":
              → 치환: $1$2$3"$new_value"
              로그: "✅ {key}: placeholder → {new_value}"
            elif old_value == new_value:
              → SKIP (이미 같음)
              로그: "ℹ️ {key}: 이미 {new_value}, SKIP"
            else:
              if --non-interactive:
                → SKIP
                로그: "⚠️ {key}: 다른 값 ({old_value}), 비대화형 SKIP"
              else:
                → 사용자 프롬프트:
                  "현재값: {old_value}, 새값: {new_value}. 덮어쓸까? (y/n/abort)"
                  y → 치환
                  n → SKIP
                  abort → 전체 중단 (이미 처리한 파일은 그대로, 진행 중 파일은 백업으로 복원)
          else:
            → 라인 그대로 보존

     c. --dry-run이면 변경사항만 출력 (파일 쓰기 X)
     d. 아니면 파일 쓰기 (UTF-8, 원본 라인엔딩 보존, BOM 보존)

4. Summary 출력
   - 처리한 파일 목록 + 각 파일별 (치환|SKIP|충돌) 상태
   - 총 치환 수 / SKIP 수 / 실패 수
```

### 6.3 안전 장치

- **들여쓰기·라인엔딩·BOM 보존**: 라인 단위 처리로 원본 구조 유지.
- **단어 경계 매칭**: regex `^(\s*)(FIREBASE_APP_ID|FIREBASE_TESTER_GROUP)\s*:` 형태로 prefix/suffix 충돌 방지.
- **백업 자동 생성**: 기본 `.bak.<timestamp>` 생성. `--no-backup`로 끌 수 있음.
- **드라이런**: `--dry-run`으로 실제 수정 없이 미리보기.
- **충돌 시 대화형 선택**: 기본은 사용자 프롬프트, `--non-interactive`로 자동 SKIP.
- **부분 실패 허용**: 한 파일 실패해도 나머지 계속 처리, summary에 명시.

---

## 7. version.json 스키마

```json
{
  "name": "Firebase App Distribution Setup Wizard",
  "version": "1.0.0",
  "description": "Flutter Android 앱을 Firebase App Distribution에 배포하기 위한 설정 마법사",
  "lastUpdated": "2026-05-14",
  "changelog": [
    {
      "version": "1.0.0",
      "date": "2026-05-14",
      "changes": [
        "초기 릴리즈",
        "5단계 마법사 (Console 가이드 → SA 발급 → 앱 정보 → 파일 업로드 → Secrets 등록)",
        "Service Account JSON base64 자동 변환",
        "Custom Secrets 섹션 (사용자 정의 secret 동적 추가)",
        "JSON/TXT/ZIP 산출물 다운로드",
        "워크플로우 placeholder 안전 치환 setup 스크립트 (bash/PowerShell)"
      ]
    }
  ],
  "compatibility": {
    "flutter": ">=3.0.0",
    "android_sdk": ">=33",
    "firebase_app_distribution": "GA"
  },
  "repository": "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
}
```

---

## 8. 에러 처리

| 케이스 | 대응 |
|---|---|
| Service Account JSON 파일이 유효한 JSON 아님 | Step 4에서 즉시 에러 토스트, 업로드 거부 |
| Service Account JSON에 `client_email`, `private_key` 필드 없음 | 경고 토스트 (업로드는 허용, 사용자 확인) |
| `FIREBASE_APP_ID` 입력값이 `1:숫자:android:해시` 패턴 안 맞음 | 경고 표시, 진행은 허용 |
| google-services.json이 유효한 JSON 아님 | 경고 토스트, 업로드 거부 |
| setup 스크립트 — `.github/workflows` 폴더 없음 | 즉시 abort, "템플릿 미적용 프로젝트" 안내 |
| setup 스크립트 — 권한 없는 파일 | 즉시 abort, 파일명 출력 |
| setup 스크립트 — 충돌 (다른 값 존재) | 사용자 프롬프트 또는 SKIP (옵션) |
| setup 스크립트 — 한 파일 처리 중 예외 | 백업으로 자동 복원, 다음 파일 계속 |
| localStorage 저장 실패 (저장공간 초과) | 경고 표시, 메모리상 상태로 계속 진행 |

---

## 9. 테스트 전략

### 9.1 setup 스크립트

- 단위 시나리오 테스트(bash 스크립트로 자동화):
  - placeholder 상태 → 치환 성공
  - 이미 같은 값 → SKIP
  - 다른 값 + `--non-interactive` → SKIP
  - 다른 값 + 대화형 'y' → 치환
  - 다른 값 + 대화형 'n' → SKIP
  - 다른 값 + 대화형 'abort' → 중단
  - `--dry-run` → 파일 변경 없음
  - `--no-backup` → 백업 파일 미생성
  - `.github/workflows` 없음 → abort
  - 권한 없는 파일 → abort
- 들여쓰기/라인엔딩/BOM 보존 검증
- bash + PowerShell 양쪽 동일 동작 확인

### 9.2 HTML 마법사

- 수동 테스트 체크리스트:
  - 5단계 전환 정상
  - 파일 업로드 (Service Account, google-services.json)
  - base64 변환 정확성
  - JSON/TXT/ZIP 다운로드 산출물 검증
  - 복사 버튼 동작
  - localStorage 상태 저장/복원
  - custom secrets 추가/삭제
  - 다국어·이모지 폰트 렌더링
  - Pretendard 폰트 로드 실패 시 fallback

### 9.3 통합 테스트

- 실제 신규 Flutter 프로젝트에 SUH 템플릿 적용
- Firebase wizard 5단계 진행
- setup 스크립트 실행 → 워크플로우 파일 변경 검증
- GitHub Secrets 등록
- `@suh-lab apk build` 트리거 → Firebase App Distribution 업로드 확인

---

## 10. 마이그레이션 / 호환성

- 기존 PlayStore/TestFlight wizard와 독립적. 충돌 없음.
- 워크플로우 placeholder (`{FIREBASE_APP_ID}`, `{TESTER_GROUP}`)는 이미 템플릿에 존재. 추가 변경 불필요.
- Firebase wizard가 처리하지 않는 케이스(이미 다른 값 들어있음)는 사용자 프롬프트로 안전 처리.

---

## 11. 후속 작업 (out of scope)

- Firebase Management API 자동화 (Console 작업 자동화)
- GitHub API를 통한 Secrets 자동 등록
- iOS Firebase App Distribution 지원 (iOS는 별도 wizard 필요)
- Slack 알림 통합 자동화

---

## 12. 결정 기록

| 결정 | 사유 |
|---|---|
| GitHub API 직접 호출 안 함 | PAT 보관 위험, 보안 단순성, 기존 wizard 패턴과 일관성 |
| setup 스크립트 별도 제공 | 워크플로우 placeholder 안전 치환을 위한 라인 단위 처리 필요. sed 한 줄로는 충돌·에러 처리 불가 |
| 충돌 시 사용자 프롬프트 기본 | 자동 덮어쓰기는 위험, 자동 SKIP은 silent failure. 명시적 선택 강제 |
| 백업 자동 생성 | 사용자가 망쳤을 때 복구 가능. `--no-backup`으로 끌 수 있음 |
| 대상 파일 자동 탐지 (glob) | 미래에 새 워크플로우 추가돼도 자동 대응 |
| 스크린샷 사용 안 함 | 외부 이미지 의존 X. CSS로 미니 UI 시뮬레이션 (testflight wizard 키체인 시각화 패턴 차용) |
| Custom Secrets 섹션 포함 | PlayStore wizard v1.2.0 패턴 그대로 차용. 일관성 + 확장성 |
