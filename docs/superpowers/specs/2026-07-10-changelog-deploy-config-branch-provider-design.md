# changelog-deploy 스킬 브랜치·provider config화 및 워크플로우 정합 설계

> 작성 2026-07-10. 사용자 확정: **배포 브랜치·provider·본문 생성 방식을 config로 관리하되, 사용자는 config를 직접 손대지 않는다.** skill이 애매하면 사용자에게 자연어로 묻고, 그 답을 skill이 config에 기록한다.

## 배경 — 실제로 겪은 문제

방금 릴리스(PR #463)에서 automerge가 `waiting_for_automerge`로 멈췄다. 원인 조사 중 skill과 워크플로우 사이의 구조적 불일치가 드러났다.

### 워크플로우(`PROJECT-COMMON-RELEASE-CHANGELOG.yaml`)의 "지금 로직" — 이게 skill이 맞춰야 할 계약

1. **PR opened 시**: 본문에 `Summary by CodeRabbit` 문자열이 **있으면 보존, 없으면 초기화**(line 80-93).
2. **provider 분기**(version.yml `options.changelog.provider`, 폴백 `coderabbit`):
   - `coderabbit` → `@coderabbitai summary` 요청 후 **최대 10분 폴링**(line 169-245).
   - `commit`/`github-ai`/`openai` → 폴링 건너뛰고 **fallback job이 커밋 분석으로 본문 자동 생성**(line 255-373).
3. **본문 파싱**(`changelog_manager.py` `_parse_summary_markdown`): provider 무관하게 **`* **카테고리**` + `  * 항목`** 마크다운 구조를 3단계(precise→lenient→heuristic)로 파싱. 즉 최종 본문은 이 형식이어야 CHANGELOG에 반영된다.
4. **automerge 트리거 조건**: 본문에 `Summary by CodeRabbit` 문자열 존재 + 위 마크다운 구조.

### skill(`pro-changelog-deploy/SKILL.md`)이 못 따라가는 지점 (3개 결함)

| # | 결함 | 증상 |
|---|------|------|
| **D1** | **브랜치 하드코딩** | 6단계 create-pr가 `"develop" "main"` 리터럴(SKILL.md line 468). 상단(§32, line 30-49)에서 "detect-release-context로 읽어라"고 해놓고 정작 PR 생성은 하드코딩 → 다른 브랜치 구조 레포에서 깨짐. `detect-release-context`는 이미 `branches.head/base`를 반환하는데 6단계가 안 씀. |
| **D2** | **provider 분기 미실행** | provider≠coderabbit일 때 skill이 릴리스 노트를 선제 작성할지 말지가 §32에 **말로만** 있고 5단계 실행 흐름엔 없음. 실제로는 provider 무관하게 항상 선제 작성 → coderabbit 레포에서 CodeRabbit 봇과 skill 본문이 경합. |
| **D3** | **최초 판정→config 고정 없음** | 매번 version.yml만 읽음. "이 레포는 이렇게 배포한다"(브랜치·provider·자동모드)를 config에 저장·재사용하는 개념이 없음. 사용자 요구("레포마다 처음 물어보고 형식 고정")와 불일치. |

## 목표

1. **브랜치·provider를 config(`~/.projectops/config/config.json`)의 `changelog_deploy` 섹션에서 읽는다.** 6단계 하드코딩 제거(D1).
2. **최초 1회 자동판정 후 config에 고정**한다(D3). 판정 소스: version.yml → `.coderabbit.yaml` 존재 여부 → 폴백.
3. **provider별 본문 생성 분기를 5단계 실행 흐름에 명시**한다(D2).
4. **사용자는 config를 직접 수정하지 않는다.** skill이 애매하면 자연어로 묻고, 답을 config에 기록한다.

## 1. config 스키마 확장 (`changelog_deploy` 섹션)

기존(글로벌·레포별 공통):
```json
"changelog_deploy": { "auto_approve": false, "app_release": true }
```

확장:
```json
"changelog_deploy": {
  "auto_approve": false,
  "app_release": true,
  "head_branch": "develop",
  "base_branch": "main",
  "provider": "coderabbit"
}
```

- `head_branch`/`base_branch`: 릴리스 PR의 head(소스)·base(프로덕션) 브랜치.
- `provider`: 릴리스 노트 생성 방식(`coderabbit`/`commit`/`github-ai`/`openai`).
- **레포별(`repos[].changelog_deploy`) 우선, 없으면 글로벌(`github.changelog_deploy`), 둘 다 없으면 "미판정"** → §3 최초 판정 발동.
- 기존 `auto_approve`/`app_release`와 동일한 2레벨 우선순위 규칙. config-rules.md §4(전체 Read 후 해당 키만 수정 Write)를 그대로 따른다.

## 2. 판정 우선순위 — 브랜치·provider를 어디서 읽나

skill 시작 시 아래 순서로 `HEAD_BRANCH`/`BASE_BRANCH`/`PROVIDER` 3값을 확정한다.

| 순위 | 소스 | 비고 |
|------|------|------|
| 1 | config `repos[].changelog_deploy` (현 OWNER/REPO 매칭) | 레포별 고정값 |
| 2 | config `github.changelog_deploy` (글로벌) | 공통 고정값 |
| 3 | **최초 판정** (§3) → 확정 후 config에 기록 | 1·2 모두 없을 때 1회 |

**핵심**: 1·2에서 값을 얻으면 그대로 쓰고 사용자에게 안 묻는다("한 번 판정했으면 형식 그대로"). 3에서만 판정·질문·기록이 일어난다.

## 3. 최초 판정 로직 (config에 값이 없을 때 1회)

`detect-release-context`가 반환하는 신호로 자동 추론한 뒤, **애매하면 사용자에게 묻고** 결과를 config에 기록한다.

### 3-1. 브랜치 자동 추론
- version.yml `metadata.deploy_branch`/`default_branch`가 있으면 그 값(detect-release-context의 `branches.head/base`).
- 없으면 원격 브랜치 조회: `develop` 브랜치가 존재하고 `main`이 default면 → head=develop, base=main (표준 구조, 질문 없이 확정).
- **애매한 경우(develop 없음, 또는 default가 main이 아님)에만** 사용자에게 묻는다:
  ```
  이 저장소의 릴리스는 어느 브랜치에서 어느 브랜치로 진행하나요?
  (예: 개발 브랜치 develop → 배포 브랜치 main)
  1. develop → main (표준)
  2. 직접 알려주기 (예: "release에서 production으로")
  ```

### 3-2. provider 자동 추론
- version.yml `options.changelog.provider`가 있으면 그 값(질문 없이 확정).
- 없고 레포 루트에 **`.coderabbit.yaml` 존재** → `coderabbit`로 추론.
- 없고 `.coderabbit.yaml`도 없음 → **애매** → 사용자에게 묻는다:
  ```
  릴리스 노트를 어떻게 만들까요?
  1. CodeRabbit(AI 리뷰 봇)이 요약을 달아줍니다 (이 레포에 CodeRabbit 사용 시)
  2. 커밋 내역을 분석해 자동 생성합니다 (외부 봇 없이 항상 동작)
  ```
  → 1이면 `coderabbit`, 2면 `commit`.

### 3-3. config 기록
확정된 `head_branch`/`base_branch`/`provider`를 **레포별 항목**(`repos[]`에 현 OWNER/REPO 매칭 시)에, 매칭 항목이 없으면 글로벌(`github.changelog_deploy`)에 Write한다. 이후 실행은 §2 순위 1·2에서 바로 읽혀 재질문 없음.

기록 후 사용자 안내(config 키·경로 노출 금지):
```
✅ 이 저장소 릴리스 방식을 기억했습니다 (develop → main, CodeRabbit 요약).
   바꾸고 싶으면 "배포 브랜치 바꿔줘" 또는 "릴리스 노트 방식 바꿔줘"라고 말씀해주세요.
```

## 4. provider별 5단계(본문 생성) 분기 — D2 해결

5단계에서 `PROVIDER` 값에 따라 분기한다. **어느 경우든 최종 본문은 §1의 공통 마크다운 형식**(`## Summary by CodeRabbit` + `* **카테고리**` + `  * 항목`)이어야 워크플로우가 파싱·automerge한다.

| provider | skill 행동 | 이유 |
|----------|-----------|------|
| `coderabbit` | skill이 릴리스 노트를 **선제 작성**해 본문에 담아 PR 생성. CodeRabbit 10분 대기 우회. | 워크플로우가 coderabbit이면 봇 summary를 10분 폴링하는데, 본문에 이미 `Summary by CodeRabbit`이 있으면 즉시 진행. |
| `commit` | skill이 선제 작성할지 **사용자에게 한 번 물어봄**. 원치 않으면 빈 흐름으로 두고 워크플로우 fallback job(커밋 분석)에 위임. | 워크플로우가 어차피 커밋 분석으로 만들어주므로 skill 선제 작성은 선택. "예쁘게 다듬을까요?" 정도. |
| `github-ai`/`openai` | `coderabbit`과 동일하게 선제 작성(현재 워크플로우가 이 provider의 러너 내 AI 생성을 아직 미구현, commit 폴백으로 완주하므로 skill 선제 작성이 품질상 유리). | 워크플로우 주석(line 255-258)이 "github-ai/openai는 후속 확장 자리, 그때까진 commit이 베이스라인"이라 명시. |

> 이 분기는 **SKILL.md 5단계에 표로 명시**하고, 5.5단계(사용자 승인) 진입 조건과 엮는다. `commit`에서 "위임" 선택 시엔 5.5단계를 건너뛰고 빈 본문으로 PR 생성(워크플로우가 채움).
>
> **왜 provider 무관하게 선제 작성이 안전한가**: 워크플로우 line 191-192가 "skill이 미리 `Summary by CodeRabbit`을 본문에 넣었으면(`already_found=true`) provider 무관하게 그대로 존중"한다. 즉 skill이 선제 작성하면 워크플로우는 폴링·fallback 없이 그 본문을 바로 파싱한다. 따라서 `github-ai`/`openai`를 coderabbit처럼 선제 작성해도 워크플로우와 경합하지 않는다. 유일한 예외가 `commit` "위임" — 이때만 skill이 손 떼고 fallback job에 맡긴다.

## 5. 6단계 브랜치 하드코딩 제거 — D1 해결

SKILL.md 6단계 create-pr 호출(line 468)을 하드코딩에서 변수로:

```bash
# 변경 전
create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "develop" "main"
# 변경 후 (§2에서 확정한 HEAD_BRANCH/BASE_BRANCH 사용)
create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "$HEAD_BRANCH" "$BASE_BRANCH"
```

- 2·3단계 push(`git push origin develop`)도 `$HEAD_BRANCH`로 치환.
- `create-pr` 스크립트 시그니처는 이미 `head base`를 받으므로(§확인) **스크립트 변경 불필요, SKILL.md 지시만 수정**.

## 6. 변경 범위 (파일)

| 파일 | 변경 |
|------|------|
| `skills/pro-changelog-deploy/SKILL.md` | [시작 전]에 브랜치·provider 판정 절 추가(§2·3), 5단계에 provider 분기표(§4), 6단계 하드코딩→변수(§5), [핵심 원칙]에 "사용자 config 미수정" 명문화 |
| `skills/config.json.example` | `changelog_deploy`에 `head_branch`/`base_branch`/`provider` 예시 추가 |
| `skills/references/config-rules.md` | §7 changelog_deploy 스키마에 3키 문서화 |
| (스크립트) | **변경 없음** — `create-pr`·`detect-release-context`가 이미 브랜치·provider를 지원. skill 지시만 정합화 |

## 7. 사용자 상호작용 원칙 (사용자 확정 — 설계 관통)

- **사용자는 config 파일을 직접 열지 않는다.** 모든 설정은 skill이 자연어 질문→답→Write로 관리.
- **판정 가능하면 안 묻는다.** version.yml·`.coderabbit.yaml`로 확신 서면 조용히 확정하고 "기억했다"만 안내.
- **애매할 때만 묻는다.** 브랜치 구조 비표준, provider 신호 없음 등.
- **한 번 물어 config에 기록하면 재질문 없음.** "레포마다 처음 물어보고 형식 고정" 요구 반영.
- config 키·파일 경로를 사용자에게 노출하지 않는다(기존 원칙 유지).

## 8. 검증

- **회귀**: pytest(48)·npm test(187) 전량 통과 유지. 이 변경은 주로 SKILL.md(문서) + config 예시라 코드 테스트 영향 적음.
- **detect-release-context 단위 확인**: version.yml에 `deploy_branch: release`/`default_branch: production`을 넣었을 때 `branches.head=release`/`base=production` 반환하는지(이미 구현됨, 회귀 확인).
- **시나리오 검증**(문서상 추적): ① config에 브랜치 있음 → 질문 없이 그 브랜치로 PR ② config 없고 version.yml에 있음 → version.yml 값으로 확정·기록 ③ 둘 다 없고 develop/main 표준 → 질문 없이 확정 ④ 비표준 → 질문 → 기록.
- 실 릴리스로 최종 검증(다음 배포 시 브랜치·provider가 config에서 읽히고 automerge 정상).
