# init-worktree 민감 파일 복사 로직 .gitignore 파싱 기반으로 개선

## 개요

`init-worktree` 스킬의 민감 파일 복사 단계가 Flutter/iOS 특정 파일명을 하드코딩하여 Spring `application-dev.yml`, `firebase-key.json` 등 다른 프로젝트 타입의 민감 파일이 누락되는 문제를 수정했다. 파일명 하드코딩 방식을 `.gitignore` 파싱 기반 동적 탐색으로 전환하여 프로젝트 타입에 무관하게 민감 파일이 자동 복사되도록 개선했다.

## 변경 사항

### Skills

- `skills/init-worktree/SKILL.md`: 4단계 민감 파일 복사 로직 전면 개선

## 주요 구현 내용

### 문제

기존 4단계는 복사 대상 파일명을 카테고리별로 하드코딩하고 있었다:

| 카테고리 | 패턴 |
|---------|------|
| Firebase | `google-services.json`, `GoogleService-Info.plist` |
| 서명 키 | `key.properties`, `*.jks` ... |
| 빌드 설정 | `Secrets.xcconfig` |

이 방식의 문제:
- Spring `application-*.yml`, `firebase-key.json` 등 누락
- 새 프로젝트 타입 추가 시마다 SKILL.md 수정 필요
- Claude가 "어떻게 실행하는지" 절차가 없어 복사 단계를 스킵하는 경우 발생

### 해결: .gitignore 파싱 기반 동적 탐색

4단계를 5개 세부 절차로 재구성했다:

**4-1. 소스/대상 경로 확정**
- 소스: `git rev-parse --show-toplevel`로 프로젝트 루트 확인
- 대상: 3단계에서 확인한 `WORKTREE_PATH`

**4-2. .gitignore 파싱으로 복사 후보 추출**

포함 기준:
- negation(`!`), 주석(`#`), 빈 줄 제외
- `**` glob 미포함 단순 경로/확장자 패턴만

즉시 제외 키워드로 빌드 산출물·의존성 걸러냄:
```
build/  target/  .gradle  node_modules  Pods/  .dart_tool
Generated  generate  .framework  .pub-cache  bin/  out/ ...
```

**4-3. find로 실제 파일 탐색**
- 단순 경로: `ls [소스_루트]/[패턴]`
- 와일드카드: `find` + `-not -path` 제외 조건 + `-size -1M` 필터
- 1MB 초과 파일은 민감 설정 파일 가능성 낮으므로 제외

**4-4. 상대경로 계산 후 복사 실행**
- `절대경로` → 소스 루트 기준 상대경로 계산
- `mkdir -p` + `cp`로 디렉토리 구조 유지하며 복사

**4-5. ls로 복사 결과 검증**

### 범용성 확보

`.gitignore`에 등록된 모든 민감 파일을 자동 포함:

| 프로젝트 타입 | .gitignore 패턴 예시 | 복사 여부 |
|------------|-------------------|---------|
| Flutter | `android/key.properties`, `ios/Flutter/Secrets.xcconfig` | ✅ |
| Spring | `src/main/resources/application-*.yml`, `firebase-key.json` | ✅ |
| React/Node | `*.env`, `.env.local` | ✅ |
| 공통 | `*.env` | ✅ |

## 주의사항

- `.gitignore` 파싱 방식이므로 민감 파일이 `.gitignore`에 등록되지 않은 경우 복사 대상에서 제외됨
- `즉시 제외 키워드` 목록이 프로젝트 특성에 따라 오탐 가능성 있음 (추후 피드백 기반 보완 필요)
