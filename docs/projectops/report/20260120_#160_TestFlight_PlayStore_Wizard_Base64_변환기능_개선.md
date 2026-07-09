# Issue #160: TestFlight/PlayStore 마법사 Base64 변환 기능 개선

## 개요

TestFlight와 PlayStore 마법사의 마지막 Step에 **파일 업로드 → 스마트 변환** 기능을 추가하고, **별도 범용 Secrets Converter 도구**를 신규 생성했습니다.

### 핵심 기능
- **파일 타입별 자동 처리**: 바이너리 파일 → Base64 인코딩, 텍스트 파일 → 원본 그대로
- **동적 Secret 추가/삭제**: 사용자가 커스텀 Secret을 자유롭게 추가 가능
- **범용 Secrets Converter 도구**: 별도의 독립 도구로 활용 가능

---

## 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `.github/util/flutter/playstore-wizard/playstore-wizard.html` | 수정 | Step 7에 커스텀 Secrets UI 추가 |
| `.github/util/flutter/playstore-wizard/playstore-wizard.js` | 수정 | 커스텀 Secrets 로직 + 파일 타입 처리 함수 추가 |
| `.github/util/flutter/playstore-wizard/version.json` | 수정 | 버전 1.1.0 → 1.2.0 |
| `.github/util/flutter/testflight-wizard/testflight-wizard.html` | 수정 | Step 9에 커스텀 Secrets UI 추가 |
| `.github/util/flutter/testflight-wizard/testflight-wizard.js` | 수정 | 커스텀 Secrets 로직 + 파일 타입 처리 함수 추가 |
| `.github/util/flutter/testflight-wizard/version.json` | 수정 | 버전 1.1.0 → 1.2.0 |
| `.github/util/common/secrets-converter/secrets-converter.html` | **신규** | 범용 Secrets Converter UI |
| `.github/util/common/secrets-converter/secrets-converter.js` | **신규** | 범용 Secrets Converter 로직 |
| `.github/util/common/secrets-converter/version.json` | **신규** | 버전 정보 (v1.0.0) |
| `.github/util/common/secrets-converter/version-sync.sh` | **신규** | HTML 버전 동기화 스크립트 |

---

## 구현 상세

### 1. 파일 타입 감지 로직

```javascript
// 텍스트 파일 (원본 그대로 저장) - 워크플로우에서 cat <<EOF 사용
const TEXT_EXTENSIONS = [
    '.json', '.yml', '.yaml', '.env', '.txt', '.xml',
    '.plist', '.properties', '.toml', '.ini', '.cfg', '.conf'
];

// 바이너리 파일 (Base64 인코딩) - 워크플로우에서 base64 -d 사용
const BINARY_EXTENSIONS = [
    '.jks', '.keystore', '.p12', '.mobileprovision', '.p8',
    '.cer', '.pfx', '.pem', '.der', '.key', '.crt'
];

function getFileType(fileName) {
    const lowerName = fileName.toLowerCase();
    // .env로 시작하는 파일은 텍스트로 처리 (.env.production, .env.local 등)
    if (lowerName === '.env' || lowerName.startsWith('.env.')) return 'text';

    const ext = '.' + fileName.split('.').pop().toLowerCase();
    if (TEXT_EXTENSIONS.includes(ext)) return 'text';
    if (BINARY_EXTENSIONS.includes(ext)) return 'binary';
    // 알 수 없는 확장자는 바이너리로 처리 (안전)
    return 'binary';
}
```

### 2. 키 이름 자동 생성 규칙

```javascript
function generateKeyName(fileName, fileType) {
    const baseName = fileName
        .replace(/\.[^/.]+$/, '')  // 확장자 제거
        .toUpperCase()
        .replace(/[^A-Z0-9]/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_|_$/g, '');

    // 바이너리 파일만 _BASE64 접미사 추가
    if (fileType === 'binary') {
        return baseName + '_BASE64';
    }
    return baseName;
}

// 예시:
// service-account.json → SERVICE_ACCOUNT (텍스트)
// release-key.jks → RELEASE_KEY_BASE64 (바이너리)
// .env.production → ENV_PRODUCTION (텍스트)
```

### 3. 파일 처리 함수

```javascript
async function processFile(file) {
    const fileType = getFileType(file.name);

    if (fileType === 'text') {
        // 텍스트 파일: 원본 내용 그대로
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve({
                value: reader.result,
                type: 'text',
                hint: 'cat <<EOF 로 파일 생성'
            });
            reader.onerror = reject;
            reader.readAsText(file);
        });
    } else {
        // 바이너리 파일: Base64 인코딩
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve({
                value: reader.result.split(',')[1],  // data URL에서 base64만 추출
                type: 'binary',
                hint: 'echo $SECRET | base64 -d > file'
            });
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }
}
```

### 4. XSS 방지 (보안 개선)

```javascript
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// 사용 예시 (renderCustomSecrets 함수 내)
<div class="file-info">
    ${escapeHtml(secret.fileName)} (${formatSize(secret.value.length)})
</div>
<div class="usage-hint">💡 ${escapeHtml(secret.hint)}</div>
```

### 5. 내보내기 통합

커스텀 Secrets가 기존 내보내기 기능(JSON, TXT, ZIP)에 통합되었습니다:

```javascript
// JSON 내보내기 예시
function downloadAsJson() {
    const secrets = collectAllSecrets(); // 기존 Secrets

    // 커스텀 Secrets 추가
    state.customSecrets.forEach(cs => {
        if (cs.key && cs.value) {
            secrets[cs.key] = cs.value;
        }
    });

    // 다운로드
    const blob = new Blob([JSON.stringify(secrets, null, 2)], {type: 'application/json'});
    // ...
}
```

---

## UI 변경사항

### PlayStore Wizard (Step 7)

Step 7의 기존 Secrets 테이블 아래에 "추가 Secrets" 섹션이 추가되었습니다:

- **"+ 새 Secret 추가" 버튼**: 동적으로 파일 슬롯 추가
- **파일 타입 뱃지**: 📄 Raw Text / 🔐 Base64 자동 표시
- **드래그 & 드롭**: 파일 업로드 지원
- **사용법 힌트**: 각 파일 타입별 워크플로우 사용법 안내

### TestFlight Wizard (Step 9)

PlayStore Wizard와 동일한 UI가 Step 9에 추가되었습니다.

### 범용 Secrets Converter

`.github/util/common/secrets-converter/` 경로에 독립 도구로 생성:

- **단일 페이지 도구**: HTML 파일만 열면 바로 사용 가능
- **파일 타입 가이드**: 텍스트/바이너리 확장자 안내
- **드래그 & 드롭**: 여러 파일 동시 업로드
- **내보내기 옵션**: JSON 복사, JSON 다운로드, TXT 다운로드

---

## 버전 업데이트

| 도구 | 이전 버전 | 새 버전 |
|------|----------|---------|
| PlayStore Wizard | 1.1.0 | **1.2.0** |
| TestFlight Wizard | 1.1.0 | **1.2.0** |
| Secrets Converter | - | **1.0.0** (신규) |

### Changelog (v1.2.0)

```
- Step 7/9에 '추가 Secrets' 섹션 추가 - 사용자 정의 Secret 동적 추가 가능
- 파일 타입별 스마트 변환 (텍스트 파일 → 원본, 바이너리 파일 → Base64)
- 커스텀 Secret 키 이름 자동 생성 (바이너리 파일은 _BASE64 접미사 자동 추가)
- Drag & Drop 파일 업로드 지원
- 커스텀 Secrets를 JSON/TXT/ZIP 내보내기에 통합
- localStorage에 커스텀 Secrets 상태 저장
```

---

## 코드 리뷰 개선 사항

구현 후 코드 리뷰를 통해 다음 사항이 개선되었습니다:

### 1. XSS 취약점 수정 (Major)
- `renderCustomSecrets()` 함수에서 `secret.fileName`과 `secret.hint`가 escape 없이 사용되던 문제 수정
- `escapeHtml()` 함수 추가 및 적용

### 2. 에러 핸들링 개선 (Minor)
- `copyCustomSecretValue()` 함수에 `.catch()` 추가
- 클립보드 복사 실패 시 사용자에게 피드백 제공

### 3. .env 파일 패턴 처리 개선 (Minor)
- `.env.production`, `.env.local` 등 `.env`로 시작하는 파일도 텍스트로 처리
- 기존에는 확장자 기반으로만 감지하여 `.env.production` 같은 파일이 바이너리로 처리됨

### 4. 미사용 변수 제거 (Minor)
- `addCustomSecret()` 함수의 미사용 `const index` 변수 제거

---

## 테스트 방법

### 1. 파일 타입 자동 감지 테스트

| 파일 | 예상 결과 |
|------|----------|
| `service-account.json` | 📄 Raw Text, 키: `SERVICE_ACCOUNT` |
| `release-key.jks` | 🔐 Base64, 키: `RELEASE_KEY_BASE64` |
| `.env.production` | 📄 Raw Text, 키: `ENV_PRODUCTION` |
| `profile.mobileprovision` | 🔐 Base64, 키: `PROFILE_BASE64` |

### 2. 마법사 테스트

1. PlayStore Wizard Step 7 또는 TestFlight Wizard Step 9로 이동
2. "새 Secret 추가" 버튼 클릭
3. 텍스트 파일과 바이너리 파일 각각 업로드
4. 타입 뱃지 및 키 이름 자동 생성 확인
5. JSON/TXT 다운로드 시 커스텀 Secrets 포함 확인

### 3. 범용 도구 테스트

1. `.github/util/common/secrets-converter/secrets-converter.html` 파일을 브라우저에서 열기
2. 여러 파일 드래그 & 드롭
3. 타입별 변환 확인
4. 복사/다운로드 기능 테스트

---

## 관련 이슈

- GitHub Issue: #160
- 계획 파일: `.claude/plans/jolly-doodling-dewdrop.md`

---

## 작성 정보

- **작성일**: 2026-01-20
- **작성자**: Claude Code (claude-opus-4-5-20251101)
