🗒️ 설명
---

Flutter 배포 워크플로우가 AI로 생성한 release notes(`final_release_notes.txt`)를 **길이 제한 없이 그대로** 각 스토어에 업로드한다. 스토어마다 release notes 길이 제한이 있는데 이를 검증·절단하는 로직이 어디에도 없어, changelog가 길어지면 배포가 실패한다.

실제로 `cops-and-robbers-FE` 프로젝트의 Play Store 내부 테스트 배포에서 다음 에러로 배포가 실패했다.

```
Google Api Error: Invalid request - The release created has notes in language ko-KR with length 612, which is too long (max: 500).
```

- AI changelog가 612자로 생성됨 → Google Play 한도(500자) 초과 → `upload_to_play_store`(fastlane) API 거부 → 배포 job 실패.
- 참고 실패 로그: https://github.com/cops-and-robbers/cops-and-robbers-FE/actions/runs/27186484385/job/80257389695

🔄 재현 방법
---

1. Flutter 프로젝트에서 deploy 브랜치로 배포 트리거 (Play Store / TestFlight / Firebase 워크플로우 실행).
2. 직전 버전의 AI 생성 changelog가 스토어 한도를 초과하는 길이로 생성됨 (Play 기준 500자 초과).
3. 배포 job의 release notes 업로드 단계에서 스토어 API가 길이 초과로 요청을 거부 → job 실패.

📸 참고 자료
---

**구조적 원인**

`.github/workflows/project-types/flutter/` 하위 세 배포 워크플로우가 **동일한 `final_release_notes.txt`를 공유**하지만, 어디에도 길이 truncation/검증이 없다.

| 워크플로우 | release notes 사용 지점 | 현재 처리 |
|---|---|---|
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | `changelogs/${VERSION_CODE}.txt`로 복사 (약 632번 라인) | 길이 검증 없음 |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | `RELEASE_NOTES`로 읽어 Fastfile에 전달 (약 419번 라인) | 길이 검증 없음 |
| `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` | `releaseNotesFile`로 전달 (약 569번 라인) | 길이 검증 없음 |

**플랫폼별 release notes 길이 제한 (웹 검색으로 검증)**

| 플랫폼 | 제한 | 단위 | 현재 612자 위험도 |
|---|---|---|---|
| Google Play | **500** | 글자(유니코드 문자) 수 | 🔴 **실제 배포 실패 발생** |
| TestFlight (App Store Connect) | **4000** | **바이트** (fastlane 2.140.0부터 byte 기준 절단) | 🟡 잠재 — 한글 1자=3byte라 실질 약 1,333자, changelog 누적 시 초과 가능 |
| Firebase App Distribution | 제한 존재 (공식 수치 미공개, 사례상 수천 자) | 불명확 | 🟡 잠재 — `Release notes length exceeds maximum character limit` 에러 보고 사례 있음 |

> 핵심: 플랫폼마다 한도뿐 아니라 **계측 단위(글자 vs 바이트)까지 다르다.** Google Play는 글자 수, TestFlight는 바이트 수.

**검증 출처**

- Google Play 500자 제한: https://support.google.com/googleplay/android-developer/answer/9859348 , https://docs.fastlane.tools/actions/supply/
- TestFlight 4000 바이트(글자 아님) 절단: https://github.com/fastlane/fastlane/issues/14443 , https://github.com/fastlane/fastlane/issues/3956
- Firebase release notes 길이 제한 존재: https://github.com/firebase/fastlane-plugin-firebase_app_distribution/issues/249

✅ 예상 동작
---

- release notes가 스토어 한도를 초과하면 **배포 직전 자동으로 안전하게 절단**되어, 배포가 길이 문제로 실패하지 않아야 한다.
- 절단 시 단어/줄 경계를 존중하고 말줄임표(`…`)를 붙여 자연스럽게 마무리한다.
- 절단 처리는 **항상 성공 종료(exit 0)** 하여 배포 파이프라인을 깨지 않는다.

**해결 방향 (제안)**

1. 공통 재사용 스크립트 `.github/scripts/truncate_release_notes.sh` 추가
   - 글자 모드 / 바이트 모드 둘 다 지원 (플랫폼별 계측 단위 차이 대응)
   - 한도 초과 시 (한도-마진)에서 절단 + `…` 부착
   - 내부망/외부망 무관하게 동작하도록 순수 shell + 표준 도구만 사용
2. 각 워크플로우 배포 직전 적용 (마진 포함)

   | 워크플로우 | 적용 한도 | 모드 |
   |---|---|---|
   | PLAYSTORE | 480자 | char |
   | IOS-TESTFLIGHT | 3800byte | byte |
   | FIREBASE | 4000자 (안전망) | char |

⚙️ 환경 정보
---

- **워크플로우 위치**: `.github/workflows/project-types/flutter/`
- **프로젝트 타입**: flutter
- **재현 환경**: GitHub Actions (ubuntu-24.04), fastlane 2.236.0

🙋‍♂️ 담당자
---

- **백엔드**: Cassiiopeia
- **프론트엔드**: 
- **디자인**: 
