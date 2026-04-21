# 프로덕션 빌드 Firebase App Distribution 배포 워크플로우 추가

## 개요

Play Store 내부 테스트로만 제공되던 프로덕션 빌드를 Firebase App Distribution에서도 배포할 수 있도록 `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` 워크플로우를 신규 생성하였다. 테스터가 Play Store와 Firebase App Tester 중 편한 곳에서 프로덕션 빌드를 받을 수 있게 되어 접근성이 향상되었다.

## 변경 사항

### 워크플로우 신규 생성
- `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` (586줄): Firebase App Distribution 프로덕션 배포 워크플로우 (위치: `.github/workflows/project-types/flutter/`)

### 문서
- `CLAUDE.md`: Flutter 워크플로우 테이블에 `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD` 행 추가, Firebase CD Secrets 섹션 추가
- `docs/WORKFLOW-COMMENT-GUIDELINES.md`: Type E 적용 현황에 FIREBASE-CICD 추가

## 주요 구현 내용

### 워크플로우 구조 — 3개 Job

| Job | 내용 | PlayStore CICD 대비 |
|-----|------|---------------------|
| `prepare-build` | 환경 설정, 버전 정보 추출, CHANGELOG.json 기반 릴리즈 노트 생성 | 동일 |
| `build-android` | AAB 빌드, bundletool 매니페스트 검증 (version_code/version_name) | 동일 |
| `deploy-firebase` | Firebase App Distribution에 AAB 업로드 | 변경 (PlayStore → Firebase) |

### 트리거 조건

PlayStore CICD와 동일:
- `deploy` 브랜치 push
- CHANGELOG 자동 업데이트 워크플로우 완료 후
- 수동 실행 (`workflow_dispatch`)

### deploy-firebase Job 흐름

1. AAB 아티팩트 다운로드
2. 릴리즈 노트(`final_release_notes.txt`) 다운로드
3. `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` → base64 디코딩 → JSON 파일 생성
4. `wzieba/Firebase-Distribution-Github-Action@v1`로 AAB 업로드
5. Firebase 인증 파일 삭제 (`always()` 조건)

### PlayStore CICD와의 핵심 차이

| 항목 | PlayStore CICD | Firebase CICD |
|------|----------------|---------------|
| 배포 도구 | Fastlane | Firebase Action (직접 업로드) |
| 에러 처리 | continue-on-error 적용 | 미적용 (프로덕션이므로 실패 시 워크플로우도 실패) |
| 아티팩트 형식 | AAB | AAB (Firebase가 AAB 지원) |
| 릴리즈 노트 | CHANGELOG.json 기반 | CHANGELOG.json 기반 (동일) |

### 버전 검증

`build-android` job에서 bundletool을 사용하여 빌드된 AAB의 매니페스트에서 `VERSION_CODE`와 `VERSION_NAME`이 `version.yml` 값과 일치하는지 검증한다. 불일치 시 상세 오류 메시지를 출력하며, Play Store/Firebase 중복 버전 업로드를 방지한다.

### 필수 GitHub Secrets

```
RELEASE_KEYSTORE_BASE64
RELEASE_KEYSTORE_PASSWORD
RELEASE_KEY_ALIAS
RELEASE_KEY_PASSWORD
FIREBASE_SERVICE_ACCOUNT_JSON_BASE64
```

## 주의사항

- 워크플로우 주석은 Type E (특수) 패턴 적용 — WORKFLOW-COMMENT-GUIDELINES.md 준수
- `FIREBASE_APP_ID`와 `FIREBASE_TESTER_GROUP`은 워크플로우 env에서 설정하며, 프로젝트별로 수정 필요
- 실제 워크플로우 파일 생성은 후속 커밋(`049ee58`, #209)에서 이루어짐 — #206 커밋(`03fef8d`)에서는 기존 파일 수정 및 문서 업데이트만 포함
- RomRom-FE에서 동일 기능 구현 및 검증 완료 (TEAM-ROMROM/RomRom-FE#729)
