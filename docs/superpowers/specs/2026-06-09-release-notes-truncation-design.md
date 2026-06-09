# Flutter 배포 워크플로우 release notes 길이 제한 처리 설계

- 관련 이슈: [#347](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/347)
- 작성일: 2026-06-09
- 대상 레포: SUH-DEVOPS-TEMPLATE (템플릿 원천)

## 1. 배경 / 문제

Flutter 배포 워크플로우 3종이 AI 생성 release notes(`final_release_notes.txt`)를 길이 검증 없이 각 스토어에 업로드한다. 스토어별 길이 한도를 넘으면 배포가 실패한다.

실제 실패: `cops-and-robbers-FE` Play Store 배포에서 changelog 612자 → Google Play 500자 한도 초과 → fastlane `upload_to_play_store` API 거부.

```
Google Api Error: Invalid request - The release created has notes in language ko-KR with length 612, which is too long (max: 500).
```

## 2. 검증된 플랫폼별 한도

| 플랫폼 | 한도 | 단위 | 출처 |
|---|---|---|---|
| Google Play | 500 | 글자(유니코드 문자) | Play Console Help, fastlane supply docs |
| TestFlight (App Store Connect) | 4000 | 바이트 (fastlane 2.140.0부터 byte 절단) | fastlane#14443, fastlane#3956 |
| Firebase App Distribution | 제한 존재(공식 미공개) | 불명확 | firebase fastlane-plugin#249 |

핵심: 한도뿐 아니라 **계측 단위(글자 vs 바이트)까지 플랫폼마다 다르다.**

## 3. 설계

### 3.1 공통 재사용 스크립트

신규 파일: `.github/scripts/truncate_release_notes.sh`

**인터페이스**
```
truncate_release_notes.sh <입력파일> <최대길이> <모드> [출력파일]
```
- `<모드>`: `char`(글자 수) | `byte`(UTF-8 바이트 수)
- `[출력파일]` 생략 시 입력파일을 in-place 수정
- 항상 exit 0 (배포 파이프라인을 절대 깨지 않음)

**동작**
1. 입력을 읽어 현재 길이를 모드에 맞게 측정 (`char`=유니코드 문자 수, `byte`=UTF-8 바이트 수).
2. 한도 이하면 그대로 통과 (변경 없음).
3. 한도 초과 시 절단:
   - 말줄임표 `…`(1글자/3byte) 공간을 한도에서 뺀 **유효 한도** 계산.
   - **줄 경계 우선**: 유효 한도 이내에서 가능한 마지막 줄바꿈(`\n`)까지 자름.
   - 줄바꿈이 없으면 **글자/바이트 경계로 fallback** (byte 모드는 멀티바이트 문자 중간을 깨지 않도록 문자 경계 보장).
   - 끝에 `…` 부착.
4. 절단 발생 시 로그로 원본/절단 후 길이를 출력 (디버깅용).

**구현 도구**: Python 표준 라이브러리(`sys`, 문자열 슬라이싱)로 작성 + shell 래퍼. 내부망에서도 `pip install` 없이 동작해야 하므로 표준 라이브러리만 사용. (`wc -m`은 로케일 의존성이 있어 유니코드 문자 수 계산이 부정확할 수 있어 Python `len()` 사용.) CLAUDE.md의 "Python 행동 스크립트 표준" 및 크로스 플랫폼 PYTHON 검출 패턴을 따른다.

### 3.2 워크플로우별 적용

각 워크플로우의 release notes 사용 **직전**에 스크립트를 호출한다. 마진을 두어 계산 오차에 대비한다.

| 워크플로우 | 적용 한도 | 모드 | 적용 위치 |
|---|---|---|---|
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | 480 | char | changelog 복사(`cp ... changelogs/${VERSION_CODE}.txt`) 직전 (약 632번 라인) |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | 3800 | byte | `RELEASE_NOTES=$(cat ...)` 읽기 직전 (약 419번 라인) |
| `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` | 4000 | char | `releaseNotesFile` 사용 직전 (약 569번 라인) — 안전망 |

> 생성 단계(`final_release_notes.txt` 만드는 곳)에서 일괄 절단하지 않는다. 플랫폼별 한도·단위가 달라 가장 빡빡한 기준으로 깎으면 TestFlight 같은 넉넉한 곳이 손해를 보기 때문. **각 플랫폼 배포 직전에 그 플랫폼 기준으로 절단**한다.

### 3.3 적용 범위 / 비범위

**범위**
- 위 3개 Flutter 배포 워크플로우 (`project-types/flutter/`)
- 신규 공통 스크립트 1개

**비범위**
- 공통 워크플로우(`project-types/common/` + 루트)는 release notes를 스토어에 올리지 않으므로 무관 → 양쪽 동기화 규칙 해당 없음.
- `changelog_manager.py`의 생성 로직은 변경하지 않음 (긴 changelog 자체는 GitHub Release 등 다른 용도로 그대로 유지).

## 4. 검증 방법

- 스크립트 단독 테스트: char/byte 모드 각각에 대해 (a) 한도 미만 통과, (b) 한도 초과 절단 + `…`, (c) 줄 경계 절단, (d) 한글 멀티바이트가 byte 모드에서 깨지지 않음 — 4개 케이스.
- 실제 배포는 사용자가 별도 환경에서 수행(내부망 제약). 본 레포에서는 스크립트 로직 검증까지.

## 5. 에러 처리

- 입력파일 없음 / 빈 파일 → 변경 없이 exit 0 (배포 단계에 이미 기본 release notes fallback 존재).
- 잘못된 모드 인자 → stderr 경고 후 char 모드로 동작, exit 0.
- 어떤 경우에도 비정상 종료하지 않아 배포를 막지 않는다.
