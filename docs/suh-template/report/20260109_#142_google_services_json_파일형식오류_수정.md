# 🔧 구현 보고서

## 📌 작업 개요

Flutter Android CI/CD에서 `google-services.json` 파일 생성 시 JSON 파싱 오류 발생 문제 수정

**이슈**: [#142](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/142)

---

## 🔍 문제 분석

### 에러 메시지
```
Execution failed for task ':app:processReleaseGoogleServices'.
> com.google.gson.stream.MalformedJsonException: Unterminated object at line 10 column 29
  path $.client[0].client_info.mobilesdk_app_id
```

### 원인
GitHub Actions에서 `echo` 명령어로 멀티라인 JSON을 파일로 생성할 때 발생하는 문제

```yaml
# 기존 코드 (문제 발생)
echo "${{ secrets.GOOGLE_SERVICES_JSON }}" > android/app/google-services.json
```

**문제점**:
- `echo` 명령어는 멀티라인 JSON의 줄바꿈을 제대로 처리하지 못함
- 특수문자(따옴표, 백슬래시 등)가 escape되지 않음
- 결과적으로 불완전한 JSON 파일 생성 → 파싱 실패

---

## ✅ 구현 내용

### 해결 방법: Heredoc 방식 적용

`echo` 대신 `cat << 'EOF'` (heredoc) 방식으로 변경하여 멀티라인 JSON을 안전하게 처리

```yaml
# 수정 후 코드
cat << 'EOF' > android/app/google-services.json
${{ secrets.GOOGLE_SERVICES_JSON }}
EOF
```

**장점**:
- 멀티라인 텍스트를 그대로 파일에 기록
- 줄바꿈 완벽 보존
- 특수문자 처리 안전

---

## 🔧 주요 변경사항

### 1. PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml
**파일**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`
**라인**: 200-205

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 방식 | `echo` | `cat << 'EOF'` |
| 경로 | `android/app/google-services.json` | 동일 (유지) |

### 2. PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml
**파일**: `.github/workflows/project-types/flutter/synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml`
**라인**: 74-80

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 방식 | `echo` | `cat << 'EOF'` |
| 경로 | `android/Google-services.json` | `android/app/google-services.json` |

**참고**: Synology 워크플로우의 경로도 표준 경로(`android/app/`)로 통일

---

## 📋 변경 파일 목록

| 파일 | 변경 유형 |
|------|----------|
| `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | 수정 |
| `.github/workflows/project-types/flutter/synology/PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml` | 수정 |

---

## 🧪 테스트 및 검증

### 검증 방법
1. GitHub Actions에서 Android 빌드 실행
2. `processReleaseGoogleServices` 태스크 통과 확인
3. AAB/APK 파일 정상 생성 확인

### 성공 기준
- [ ] `google-services.json` 파일이 정상적으로 생성됨 (JSON 파싱 오류 없음)
- [ ] Android AAB 빌드 성공
- [ ] 기존 CI/CD 플로우 유지

---

## 📌 참고사항

- iOS 관련 파일(GoogleService-Info.plist 등)은 현재 정상 작동 중이므로 수정하지 않음
- `.env` 파일 생성 로직은 JSON 파일만 해당하므로 변경하지 않음
- 향후 유사한 JSON 파일 생성 시 heredoc 방식 권장
