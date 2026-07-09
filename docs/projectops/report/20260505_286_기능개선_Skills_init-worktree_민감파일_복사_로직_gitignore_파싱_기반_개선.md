# init-worktree 민감 파일 복사 로직 .gitignore 파싱 기반으로 개선

## 개요

`init-worktree` 스킬의 로컬 설정 파일 복사 단계가 특정 파일명이나 실행자의 경험적 판단에 의존해 일부 파일을 누락할 수 있는 문제를 개선했다. `.gitignore` 기반 후보 inventory를 먼저 만들고, 후보별 복사 필요성을 판단한 뒤 근거와 함께 선택 복사하도록 절차를 보강했다. 복사하지 않은 후보는 마지막에 리포트하여 Spring, React, React Native, Flutter 등 다양한 프로젝트에서 누락 여부를 확인할 수 있게 했다.

## 변경 사항

### Skills

- `skills/init-worktree/SKILL.md`: 4단계 로컬 파일 후보 조사·선택 복사·누락 후보 체크 절차 보강

### Docs

- `docs/SKILLS.md`: `init-worktree` 설명을 자동 복사에서 후보 조사·선택 복사·누락 후보 리포트 방식으로 수정

## 주요 구현 내용

### 문제

기존 4단계는 한 차례 `.gitignore` 파싱 방식으로 개선되었지만, 여전히 실행자가 후보 inventory를 끝까지 확인하지 않고 익숙한 파일만 골라 복사할 여지가 있었다.

실제 문제:
- `.gitignore`에는 등록되어 있고 원본에는 존재하지만 worktree에는 없는 로컬 파일이 누락될 수 있음
- 복사 결과 검증이 "복사한 파일이 존재하는지" 중심이라 "복사하지 않은 후보가 괜찮은지"를 확인하지 못함
- Flutter의 `Secrets.xcconfig`, Spring의 profile 설정, React/RN의 환경 파일처럼 프로젝트 타입별 필요한 파일이 서로 다름
- 모든 gitignored 파일을 무조건 복사하면 build/cache/dependency/IDE 상태 파일까지 섞일 수 있음

### 해결: 후보 inventory 기반 선택 복사

4단계를 7개 세부 절차로 재구성했다:

**4-1. 소스/대상 경로 확정**
- 소스: `git rev-parse --show-toplevel`로 프로젝트 루트 확인
- 대상: 3단계에서 확인한 `WORKTREE_PATH`

**4-2. .gitignore 파싱으로 후보 inventory 생성**

에이전트가 익숙한 파일명만 임의로 고르지 않도록, 먼저 원본 프로젝트에 실제 존재하는 gitignored 파일/디렉토리 후보를 만든다.

포함 기준은 유지했다:
- negation(`!`), 주석(`#`), 빈 줄 제외
- `**` glob 미포함 단순 경로/확장자 패턴만

명백한 제외 대상으로 build/cache/dependency/IDE 상태 파일을 걸러낸다:
```
build/  target/  .gradle  node_modules  Pods/  .dart_tool
Generated  generate  .framework  .pub-cache  bin/  out/ ...
.idea  .vscode  .DS_Store  .flutter-plugins  flutter_export_environment.sh
```

**4-3. 실제 존재 파일 탐색**
- 단순 경로: `ls [소스_루트]/[패턴]`
- 와일드카드: `find` + `-not -path` 제외 조건 + `-size -1M` 필터
- 1MB 초과 파일은 로컬 설정 파일 가능성 낮으므로 제외

**4-4. 에이전트 판단 기준 추가**

탐색된 후보를 바로 전부 복사하지 않고 다음 기준으로 분류한다:

| 분류 | 기준 |
|------|------|
| 복사 권장 | 런타임 환경 설정, 인증/키/서명 설정, 플랫폼 로컬 설정, 빌드/런타임 설정에서 직접 참조되는 파일 |
| 판단 필요 | 프로젝트 고유 json/yml/properties/toml/xcconfig 등 용도 확인이 필요한 로컬 설정 파일 |
| 복사 비권장 | 재생성 가능한 캐시/빌드 결과, IDE 상태 파일, 의존성 디렉토리, 로그/임시/대용량 파일 |

**4-5. 참조 관계 확인**

복사 여부가 애매한 후보는 프로젝트 파일에서 참조되는지 확인한다. 참조되는 gitignored 파일은 복사 권장 후보로 승격한다.

참조 관계 예:
- iOS/Flutter: `*.xcconfig`의 `#include`
- Android/Gradle: signing config, `key.properties`, keystore 참조
- Spring: profile/import 설정, `application-*.yml`, `application-*.properties`
- React/React Native/Node: dotenv/env loader, Firebase 설정 참조

**4-6. 근거와 함께 선택 복사**
- `절대경로` → 소스 루트 기준 상대경로 계산
- `mkdir -p` + `cp`로 디렉토리 구조 유지하며 복사
- 복사/스킵 결과에 reason을 함께 출력

**4-7. 복사 결과 및 누락 후보 체크**

복사 후 원본 inventory 중 대상 worktree에 존재하지 않는 후보를 다시 출력한다. 이 단계는 실패 처리하지 않지만, 각 누락 후보마다 복사하지 않은 이유를 남기도록 했다.

### 범용성 확보

파일명을 고정 목록으로 관리하지 않고, 후보 수집과 판단 기준을 분리했다:

| 프로젝트 타입 | 후보 예시 | 처리 방식 |
|------------|----------|----------|
| Flutter | `android/key.properties`, `ios/Flutter/Secrets.xcconfig` | gitignored 후보 + 설정 참조 확인 후 복사 권장 |
| Spring | `application-*.yml`, `application-*.properties`, `firebase-key*.json` | profile/import/런타임 설정 여부 판단 |
| React/Node | `.env`, `.env.local`, `.env.*` | 런타임 환경 설정으로 복사 권장 |
| React Native | Firebase 설정, `.env*`, signing 파일 | 플랫폼별 설정 참조 확인 후 판단 |

## 문서 반영

`docs/SKILLS.md`의 사용자 설명도 함께 수정했다. 기존의 "민감 파일을 자동으로 복사" 표현을 제거하고, worktree 생성 후 로컬 설정 파일 후보를 찾고 필요한 파일만 선택 복사하며 누락 후보를 리포트한다고 설명했다.

## 주의사항

- `.gitignore`에 등록되지 않은 로컬 파일은 후보 inventory에 포함되지 않는다.
- 누락 후보 체크는 실패 처리하지 않는다. 프로젝트마다 복사할 필요가 없는 gitignored 파일도 많기 때문이다.
- 후보별 판단 근거를 남기는 것이 핵심이다. 그래야 나중에 같은 유형의 누락이 발생했을 때 원인을 추적할 수 있다.
