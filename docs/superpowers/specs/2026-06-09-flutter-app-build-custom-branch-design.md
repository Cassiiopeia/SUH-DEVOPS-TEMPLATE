# Flutter 앱빌드 트리거 — 특정 브랜치명 인자 지원 설계

- 작성일: 2026-06-09
- 대상 파일: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml`

## 1. 배경 / 문제

현재 댓글 기반 빌드 트리거의 동작이 프로젝트 타입별로 비대칭이다.

| 워크플로우 | 명령어 | 브랜치명 인자 |
|---|---|---|
| Spring PR-PREVIEW | `@suh-lab server build/destroy/status [브랜치]` | ✅ 지원 (`custom_branch`) |
| Python PR-PREVIEW | `@suh-lab server build/destroy/status [브랜치]` | ✅ 지원 (`custom_branch`) |
| Flutter APP-BUILD-TRIGGER | `@suh-lab build app` / `apk build` / `ios build` | ❌ 미지원 |

Flutter 트리거는 댓글 본문을 **빌드 타입(app/apk/ios) 판별에만** 쓰고, 브랜치는
PR head(`pr.data.head.ref`) 또는 이슈의 `Guide by SUH-LAB` 댓글 `### 브랜치` 블록에서
**자동 추출**한다. 즉 `@suh-lab build app feature/xxx` 라고 써도 뒤 브랜치명은 무시된다.

## 2. 목표

`@suh-lab build app <브랜치명>` 형태로 **빌드할 브랜치를 직접 지정**할 수 있게 한다.
Spring/Python의 `custom_branch` 방식과 동일한 UX·동작으로 일관성을 맞춘다.

## 3. 명령어 문법

| 명령어 | 동작 |
|---|---|
| `@suh-lab build app` | 기존대로 (PR head / 이슈 Guide 댓글 브랜치) |
| `@suh-lab build app <브랜치명>` | 명시 브랜치로 Android + iOS 빌드 |
| `@suh-lab apk build <브랜치명>` | 명시 브랜치로 Android만 |
| `@suh-lab ios build <브랜치명>` | 명시 브랜치로 iOS만 |

명령어 키워드 뒤에 오는 토큰을 옵셔널 브랜치 인자로 캡처한다.

## 4. 동작 로직

```
1. 댓글 본문 파싱 → buildType(app/apk/ios) + customBranch(옵셔널) 캡처
2. 브랜치 결정 (우선순위):
   customBranch 있음 → branchName = customBranch  (is_custom_branch=true)
   PR 댓글          → branchName = pr.head.ref      (기존)
   이슈 댓글        → Guide by SUH-LAB 댓글에서 추출 (기존)
3. relatedIssueNumber:
   branchName(=명시 브랜치 포함)에서 #숫자 추출  (기존 정규식 그대로, 입력만 명시 브랜치)
4. 빌드 번호:
   소스 번호 = 댓글이 달린 PR/이슈 번호 (명시 브랜치 무관, 기존 그대로)
   → 빌드 위치 추적은 댓글 컨텍스트 유지
5. 브랜치 존재 확인(getBranch): 명시 브랜치도 동일하게 검증 (기존 스텝 재사용)
```

## 5. 책임 분리 원칙

| 관심사 | 결정 기준 |
|---|---|
| 빌드 대상 (무엇을 빌드) | 명시 브랜치 > PR head > 이슈 Guide |
| 빌드 추적 (어디에 결과 댓글) | 댓글이 달린 PR/이슈 번호 — 항상 고정 |
| 관련 이슈 (코드↔이슈 연결) | 빌드 대상 브랜치명의 `#숫자` |

빌드 대상만 명시 브랜치로 바뀌고, PR/이슈 추적 식별자는 그대로 유지한다.
(Spring/Python `custom_branch`와 정확히 동일한 책임 분리.)

## 6. 파싱 방식

명령어 키워드가 여러 단어(`build app`)라 단순 split이 까다롭다.
Spring/Python의 bash 정규식을 github-script JS 정규식으로 옮긴다.

- `@suh-lab\s+build\s+app(?:\s+(\S+))?`
- `@suh-lab\s+apk\s+build(?:\s+(\S+))?`
- `@suh-lab\s+ios\s+build(?:\s+(\S+))?`

`if:` 트리거 조건(현재 `contains` 기반)은 건드리지 않는다.
정규식은 `build_type` 판별 스텝 내부에서만 적용 → 트리거 감지 범위는 그대로.

## 7. 변경 범위

- **단일 파일 수정**: `PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml`
- 하위 빌드 워크플로우(`PROJECT-FLUTTER-ANDROID-TEST-APK`, `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT`)는
  이미 `branch_name`을 `client_payload`로 받으므로 **수정 불필요**.

## 8. 에러 처리

- 명시 브랜치 미존재 → 기존 "브랜치를 찾을 수 없습니다" 에러 댓글 스텝 그대로 재사용. 추가 작업 없음.

## 9. 엣지 케이스

- 명시 브랜치명에 `#숫자`가 없으면 relatedIssueNumber 빈 값 (기존도 동일하게 허용).
- 빌드 카운트(중복 빌드 번호 방지)는 소스 번호 기준이라 명시 브랜치와 무관하게 정상 동작.
