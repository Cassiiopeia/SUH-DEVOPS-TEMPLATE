---
title: "🚀[기능개선][Skills] changelog-deploy 스킬 리뷰 반영 개선"
label: 작업전
---

## 📝 현재 문제점

`changelog-deploy` 스킬(deploy + changelogfix 병합 버전)을 Somansa skill-creator 8대 원칙 + 공식 모범사례로 리뷰한 결과, 아래 이슈 발견.

### 🟥 버그급

**1. `$GITHUB_PAT` 변수 초기화 코드 누락**
- "시작 전" 섹션에서 config 파일에서 `github_pat`을 추출한다고 설명하지만, 실제 추출 코드가 없음
- curl 호출에서 `$GITHUB_PAT`을 쓰는데 변수가 초기화되지 않아 빈 문자열 → GitHub API 401 오류
- 처음 쓰는 사람은 원인을 알 수 없음

**2. fix 4~5단계가 "deploy 모드와 동일하게"로만 처리됨**
- fix 4단계: "deploy 모드 5단계와 동일한 방식으로"
- fix 5단계: "deploy 모드 6단계와 동일한 형식으로 `$PR_NUMBER`(새 PR 번호)에 업데이트"
- 변수명 혼재 (`$NEW_PR_NUMBER` vs `$PR_NUMBER`) + 실제 코드 예시 없어서 agent가 추론에 의존

### 🟨 UX 저하

**3. 전문 용어 첫 등장 시 설명 없음**
- `AUTO-CHANGELOG-CONTROL`, `VERSION-CONTROL 워크플로우`, `CodeRabbit` 등 첫 등장 시 한 줄 설명 없음

**4. config 파일 경로가 외부 참조에만 의존**
- `references/config-rules.md §2~3 절차를 따른다`고만 써 있어, 이 스킬만 보고는 config 경로를 알 수 없음

**5. 핵심 원칙 섹션과 절차 중복**
- "커밋되지 않은 변경사항이 있으면 push하지 않는다"가 핵심 원칙 + 1단계 두 군데에 중복

**6. fix 모드 릴리스 노트 작성 로직 중복**
- deploy 5~6단계와 fix 4~5단계가 동일 내용인데 분리되지 않음

### 🟩 있으면 좋은 것

- "이때는 쓰지 마라" 케이스 명시 없음
- curl 실패 시 (`$PR_NUMBER` 빈 문자열) 무음 실패 — exit 1 핸들링 없음
- Windows 내부망 `--ssl-no-revoke` 안내 없음 (common-rules.md에는 있음)

## 🛠️ 해결 방안

1. "시작 전" 섹션에 `$GITHUB_PAT` 추출 코드 추가 (로컬 → 글로벌 config 순서 탐색)
2. fix 4~5단계를 명시적 코드로 인라인화, 변수명 통일
3. 전문 용어 첫 등장 시 괄호 설명 추가
4. config 파일 위치 한 줄 명시
5. 핵심 원칙 중복 제거
6. curl 실패 핸들링 추가
7. 주의사항에 SSL 오류 안내 한 줄 추가
