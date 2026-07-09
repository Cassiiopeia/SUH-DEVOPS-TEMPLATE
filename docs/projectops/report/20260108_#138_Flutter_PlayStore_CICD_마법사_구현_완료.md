# Flutter PlayStore CICD 마법사 전체 구현 완료 보고서

**이슈**: #138
**작업일**: 2026-01-08
**버전**: PlayStore Wizard 1.1.0 / TestFlight Wizard 1.1.0

---

## 📌 작업 개요

Flutter PlayStore CICD 마법사 전면 개선 작업 완료. UX 개선, 내보내기/가져오기 기능 추가, 템플릿 코드 안정화, TestFlight 마법사 기능 동일화 등 대규모 변경 수행.

**주요 변경 영역**:
- PlayStore 마법사 UX 전면 개선
- 설정 내보내기/가져오기 기능 (ZIP, JSON, TXT)
- 셋업 스크립트 및 템플릿 코드 안정화
- TestFlight 마법사 기능 동일화

---

## 🎯 구현 목표

1. 마법사 사용성 개선 - Step 인디케이터 클릭 네비게이션
2. 진행 상태 추적 개선 - 이전 단계로 이동해도 완료 표시 유지
3. 설정 백업/복원 기능 - 다른 프로젝트에서 재사용 가능
4. 템플릿 코드 안정화 - 실제 배포 환경에서 검증된 코드 반영
5. 마법사 간 기능 동일화 - PlayStore와 TestFlight 일관성 유지

---

## ✅ 구현 내용

### 1. Step 네비게이션 클릭 기능 추가

- **파일**: `playstore-wizard.js`
- **변경 내용**: `goToStep()` 함수 추가 - 상단 Step 인디케이터 클릭 시 해당 Step으로 이동
- **이유**: 긴 마법사에서 이전 단계로 돌아가기 불편하다는 피드백 반영

```javascript
function goToStep(stepNumber) {
    if (stepNumber === state.currentStep) return;
    if (stepNumber >= 1 && stepNumber <= state.totalSteps) {
        saveCurrentStepData();
        state.currentStep = stepNumber;
        showStep(state.currentStep);
        updateProgress();
        saveState();
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}
```

### 2. 진행 상태 추적 로직 개선 (maxReachedStep)

- **파일**: `playstore-wizard.js`
- **변경 내용**: `state.maxReachedStep` 변수 추가 - 도달한 최대 단계 별도 추적
- **이유**: 이전 단계로 이동해도 완료한 단계의 체크 표시 유지 필요

**기존 문제**: Step 5까지 진행 후 Step 3 클릭 → Step 1, 2만 체크 표시됨

**해결 방식**:

| 동작 | currentStep | maxReachedStep |
|------|-------------|----------------|
| nextStep() | currentStep++ | max(current, maxReached) |
| goToStep(n) | currentStep = n | 변경 없음 |
| updateProgress() | - | maxReachedStep까지 체크 |

### 3. Step 2에 Keystore 파일 업로드 UI 추가

- **파일**: `playstore-wizard.html`
- **변경 내용**: Step 2 하단에 .jks 파일 업로드 영역 추가
- **이유**: JS에 `handleKeystoreUpload` 함수는 있으나 HTML에 UI 없어서 Step 7에서 `RELEASE_KEYSTORE_BASE64`가 "미설정"으로 표시됨

### 4. 내보내기/가져오기 기능 추가 (Step 7)

- **파일**: `playstore-wizard.html`, `playstore-wizard.js`
- **변경 내용**: Step 7 완료 화면에 설정 내보내기/가져오기 섹션 추가

**추가된 UI 요소**:

| 버튼 | 색상 | 기능 |
|------|------|------|
| 전체 복사 | 녹색 | 모든 Secret을 클립보드에 복사 |
| JSON 내보내기 | 파란색 | JSON 파일로 다운로드 |
| TXT 내보내기 | 회색 | 텍스트 파일로 다운로드 |
| ZIP 내보내기 | 주황색 | ZIP 파일로 다운로드 (실제 파일 포함) |
| 설정 가져오기 | 보라색 | JSON 파일 업로드로 설정 복원 |

**ZIP 파일 구조**:
```
playstore-secrets-{app-id}-{date}.zip
├── release-key.jks              # Keystore 파일 (Base64 디코딩)
├── service-account.json         # Service Account JSON (Base64 디코딩)
├── github-secrets/
│   ├── RELEASE_KEYSTORE_BASE64.txt
│   ├── RELEASE_KEYSTORE_PASSWORD.txt
│   ├── RELEASE_KEY_ALIAS.txt
│   ├── RELEASE_KEY_PASSWORD.txt
│   ├── GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64.txt
│   ├── GOOGLE_SERVICES_JSON.txt (설정된 경우)
│   └── ENV_FILE.txt (설정된 경우)
└── README.md
```

### 5. 셋업 스크립트 안정화

- **파일**: `playstore-wizard-setup.sh`, `playstore-wizard-setup.ps1`
- **변경 내용**: 파일 잠금 문제 해결, 프로세스 종료 로직 추가, 에러 처리 강화

**추가된 기능**:
- `stop_processes_using_file()`: 파일 사용 중인 Java/Gradle 프로세스 자동 종료
- 기존 Keystore/key.properties 파일 백업 및 덮어쓰기 처리
- .gitignore 자동 커밋 (Keystore 생성 전 실행)

### 6. Fastfile 템플릿 개선

- **파일**: `Fastfile.playstore.template`
- **변경 내용**: `release_status: "draft"` 기본값 및 상세 가이드 주석 추가

**release_status 가이드**:
- `"draft"`: 신규 앱 (Play Console에서 첫 출시 전)
- `"completed"`: 검토 완료된 앱 (자동 배포 가능)

### 7. TestFlight 마법사 기능 동일화

- **파일**: `testflight-wizard.html`, `testflight-wizard.js`
- **변경 내용**: PlayStore 마법사와 동일한 내보내기/가져오기 기능 추가

---

## 🔧 주요 변경사항 상세

### copyAllSecrets() 함수

설정된 Secret만 필터링하여 `KEY=VALUE` 형식으로 클립보드 복사

```
===== GitHub Secrets for Play Store =====
생성일: 2026-01-08 오후 3:30:00
Application ID: {APP_ID}

RELEASE_KEYSTORE_BASE64={BASE64}
RELEASE_KEYSTORE_PASSWORD={PASSWORD}
...
=========================================
```

### importFromJson() 함수

FileReader API로 JSON 파일 읽기 → 파싱 → 7개 Secret 키에 대해 state 매핑 → localStorage 동기화 → 테이블 갱신

### downloadAsZip() 함수

JSZip 라이브러리 사용:
- `atob()`으로 Base64 디코딩 → `Uint8Array` 변환 → 바이너리 파일 생성
- 파일명에 applicationId 포함 (점 → 하이픈 변환)
- async/await 비동기 구현

---

## 📦 의존성 변경

| 라이브러리 | 버전 | 용도 |
|-----------|------|------|
| JSZip | 3.10.1 | 브라우저 ZIP 파일 생성 (CDN) |

---

## 🔄 수정된 파일 목록

### PlayStore Wizard (10개)

| 파일 | 상태 | 설명 |
|------|------|------|
| playstore-wizard.html | M | UI 전면 개선 |
| playstore-wizard.js | M | State 관리, 네비게이션, 내보내기 |
| playstore-wizard-setup.sh | M | 프로세스 종료 로직 |
| playstore-wizard-setup.ps1 | M | Windows용 동일 로직 |
| detect-application-id.sh | M | App ID 감지 개선 |
| detect-application-id.ps1 | M | Windows용 동일 로직 |
| patch-build-gradle.py | M | Kotlin DSL 패치 |
| Fastfile.playstore.template | M | draft 상태 기본값 |
| build.gradle.kts.signing.template | M | R8 설정 추가 |
| version.json | M | 버전 1.1.0 |

### TestFlight Wizard (4개)

| 파일 | 상태 | 설명 |
|------|------|------|
| testflight-wizard.html | M | 내보내기/가져오기 추가 |
| testflight-wizard.js | M | 동일 기능 함수 |
| version-sync.sh | M | 버전 동기화 |
| version.json | M | 버전 1.1.0 |

### 삭제 (2개)

| 파일 | 설명 |
|------|------|
| playstore-wizard/images/.gitkeep | 불필요한 플레이스홀더 |
| testflight-wizard/images/.gitkeep | 불필요한 플레이스홀더 |

---

## 🧪 테스트 및 검증

- [x] 전체 복사 버튼 → 클립보드 복사 확인
- [x] JSON 내보내기 → 파일 다운로드 확인
- [x] TXT 내보내기 → 파일 다운로드 확인
- [x] ZIP 내보내기 → 파일 구조 확인
- [x] JSON 가져오기 → 설정 복원 확인
- [x] Step 인디케이터 클릭 네비게이션 동작
- [x] maxReachedStep 상태 유지
- [x] localStorage 이전 버전 호환성

---

## 📌 참고사항

1. **보안**: 내보낸 파일에 비밀번호, Base64 키 포함 → 안전 보관 필요
2. **ZIP 활용**: `release-key.jks`는 실제 Keystore로 바로 사용 가능
3. **가져오기 제한**: 동일 형식 JSON만 지원
4. **draft 상태**: 신규 앱은 `"draft"` → 첫 검토 완료 후 `"completed"`로 변경

---

## 🔗 관련 커밋

- `e382365`: 마법사 고도화
- `5a9bb84`: 버전 1.1.0 업데이트
- `9aab571`: 템플릿 코드 안정화
- `947fac1`: zip, txt, json, 가져오기 기능
- `438c6d1`: HEREDOC 라인 시작 수정
- `df28977`: echo 문법 오류 수정
- `f7effc7`: 템플릿 사용 리팩토링
- `b3a9b58`: draft 상태 수동 출시 안내
- `c2c88dd`: start 부탁 코드 추가
- `0d6131f`: testflight 마지막 step 동일화
