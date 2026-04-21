# 테스트 빌드 워크플로우에 Firebase App Distribution 연동 및 진행상황 댓글 시간 표시 개선

## 개요

테스트 빌드 워크플로우(Android/iOS)에 Firebase App Distribution 업로드 기능을 추가하고, 진행상황 댓글의 시간 표시를 누적 방식에서 개별 단계별 소요 시간 방식으로 변경하였다. 테스터가 Firebase App Tester 앱에서 TestFlight과 동일한 수준으로 Android 테스트 빌드를 설치할 수 있게 되었다.

## 변경 사항

### Android 테스트 빌드 워크플로우
- `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`: Firebase App Distribution 업로드 단계 추가, 진행상황 댓글 시간 표시 개선

### iOS 테스트 빌드 워크플로우
- `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`: 진행상황 댓글 시간 표시를 개별 단계별 소요 시간 방식으로 변경

### 문서
- `CLAUDE.md`: Flutter 워크플로우 테이블 설명 업데이트, Firebase Secrets 섹션 추가
- `README.md`: Claude Code 플러그인 섹션 추가

## 주요 구현 내용

### Firebase App Distribution 연동 (Android)

Firebase 연동은 **선택적(Opt-in)** 방식으로 구현하여 하위 호환성을 유지한다.

- `prepare-test-build` job에서 `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` 시크릿 존재 여부를 확인하여 `firebase_available` output 설정
- `build-android-test` job에서 `firebase_available == 'true'`일 때만 Firebase 업로드 실행
- `wzieba/Firebase-Distribution-Github-Action@v1` 액션으로 APK 업로드
- `continue-on-error: true` 적용 — Firebase 실패 시에도 워크플로우는 성공 처리 (아티팩트 업로드는 이미 완료)
- 서비스 계정 JSON 파일은 업로드 후 `always()` 조건으로 즉시 삭제

### 릴리즈 노트 형식

```
테스트 빌드 #{빌드번호}
브랜치: {브랜치명}
커밋: {커밋해시}
이슈: #{이슈번호} {이슈제목}
```

### 진행상황 댓글 시간 표시 개선 (Android + iOS)

기존 누적 시간 방식에서 **개별 단계별 소요 시간** 방식으로 변경하였다.

**시간 계산 체이닝 구조 (Android):**
```
startTime → step1(준비) → step1.end_time
                               ↓
           step2(빌드) ←───────┘ → step2.end_time
                                         ↓
           artifact_time ←───────────────┘ → artifact_time.end_time
                                                     ↓
           firebase_time ←───────────────────────────┘
```

각 단계의 소요 시간은 이전 단계 종료 시점부터 현재 단계 종료 시점까지의 차이로 계산된다.

### 진행상황 댓글 Firebase 표시 조건

| 상태 | 표시 |
|------|------|
| Firebase 미설정 | Firebase 관련 행 자체가 표시되지 않음 |
| 성공 | 🔥 Firebase App Distribution \| ✅ 완료 + "Firebase App Tester 앱에서 설치 가능합니다" |
| 실패 | 🔥 Firebase App Distribution \| ❌ 실패 + "아티팩트에서 APK를 다운로드해주세요" |

## 주의사항

- `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` 시크릿이 없는 프로젝트에서는 기존과 동일하게 GitHub 아티팩트만 업로드됨 (하위 호환)
- `FIREBASE_APP_ID`와 `FIREBASE_TESTER_GROUP`은 워크플로우 env에서 설정하며, 프로젝트별로 수정 필요
- RomRom-FE에서 동일 기능 구현 및 검증 완료 (TEAM-ROMROM/RomRom-FE#728)
