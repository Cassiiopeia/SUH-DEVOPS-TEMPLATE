## 테스트케이스: release notes 길이 제한 (truncate_release_notes.sh)

| 구분 | 내용 |
|------|------|
| 이슈 번호 | #347 |
| 대상 | .github/scripts/truncate_release_notes.sh + Flutter 배포 워크플로우 3종 |
| 담당자 | @Cassiiopeia |
| 작성일 | 2026-06-09 |

---

### TC-01: char 모드 한도 이내 통과

| 항목 | 내용 |
|------|------|
| 전제조건 | 한도(예: 480자)보다 짧은 release notes 파일 준비 |
| 절차 | `bash .github/scripts/truncate_release_notes.sh notes.txt 480 char` 실행 |
| 기대 | 파일 내용 변경 없음, "한도 이내" 로그 출력, exit 0 |
| 결과 | |

### TC-02: char 모드 한도 초과 절단

| 항목 | 내용 |
|------|------|
| 전제조건 | 600자 분량 파일 준비 |
| 절차 | `bash truncate_release_notes.sh notes.txt 480 char` 실행 |
| 기대 | 결과 글자수 `<= 480`, 끝에 말줄임표(`…`) 부착, "절단 완료" 로그 |
| 결과 | |

### TC-03: byte 모드 한글 멀티바이트 무손상

| 항목 | 내용 |
|------|------|
| 전제조건 | 한글 위주(1자=3byte) 200byte 초과 파일 준비 |
| 절차 | `bash truncate_release_notes.sh notes.txt 100 byte` 실행 |
| 기대 | 결과 바이트수 `<= 100`, 한글이 중간에서 깨지지 않고 UTF-8 디코드 정상 |
| 결과 | |

### TC-04: CRLF 줄 경계 절단

| 항목 | 내용 |
|------|------|
| 전제조건 | 여러 줄(`\r\n` 줄바꿈)로 한도 초과하는 파일 준비 |
| 절차 | `bash truncate_release_notes.sh notes.txt 100 char` 실행 |
| 기대 | 한도 이내로 줄 경계에서 절단, 결과에 `\r`(CR) 잔존 0개, 말줄임표 부착 |
| 결과 | |

### TC-05: 없는 파일 / 빈 파일 안전 처리

| 항목 | 내용 |
|------|------|
| 절차 | (1) 존재하지 않는 파일 경로로 실행 (2) 빈 파일로 실행 |
| 기대 | 두 경우 모두 비정상 종료 없이 exit 0, 경고/통과 로그 출력 (배포 파이프라인 차단 안 함) |
| 결과 | |

### TC-06: 잘못된 모드 fallback

| 항목 | 내용 |
|------|------|
| 절차 | `bash truncate_release_notes.sh notes.txt 480 bogus` 실행 |
| 기대 | "알 수 없는 모드 → char 모드로 동작" 경고 후 char 기준 처리, exit 0 |
| 결과 | |

### TC-07: 출력파일 분리 (입력 보존)

| 항목 | 내용 |
|------|------|
| 전제조건 | 한도 초과 입력 파일 준비 |
| 절차 | `bash truncate_release_notes.sh in.txt 480 char out.txt` 실행 |
| 기대 | 입력 파일은 원본 그대로 보존, 출력 파일만 `<= 480`으로 절단 |
| 결과 | |

### TC-08: Play Store 배포 시 500자 초과 에러 미발생 (통합)

| 항목 | 내용 |
|------|------|
| 전제조건 | changelog가 500자를 초과하는 Flutter 프로젝트, PLAYSTORE-CICD 워크플로우 설정 |
| 절차 | deploy 트리거 → Play Store 배포 job 실행 |
| 기대 | release notes가 480자로 자동 절단되어 업로드, `notes ... too long (max: 500)` 에러 없이 배포 성공 |
| 결과 | |

### TC-09: TestFlight / Firebase 배포 절단 적용 (통합)

| 항목 | 내용 |
|------|------|
| 전제조건 | 긴 changelog, IOS-TESTFLIGHT / ANDROID-FIREBASE-CICD 워크플로우 설정 |
| 절차 | 각 배포 트리거 → 업로드 단계 로그 확인 |
| 기대 | TestFlight는 3800byte, Firebase는 4000자 기준으로 절단 후 업로드, 길이 초과 거부 없음 |
| 결과 | |

---

### TC-10: Flutter 플랫폼 공통 — 워크플로우 문법

| 항목 | 내용 |
|------|------|
| 절차 | 수정된 워크플로우 3종을 GitHub Actions에서 로드 |
| 기대 | YAML 파싱 오류 없이 정상 트리거, truncate step이 배포 단계 직전에 실행됨 |
| 결과 | |
