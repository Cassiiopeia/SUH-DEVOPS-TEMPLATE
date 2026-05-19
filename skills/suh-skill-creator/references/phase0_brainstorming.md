# Phase 0 — 브레인스토밍 (무엇을·왜 만들까)

CREATE 모드에서 **Phase 1 슬롯 추출 이전에** 들어가는 짧은 설계 대화. 사용자가 "skill 만들어줘"라고 했을 때 바로 슬롯 채우기로 가지 말고, "정말 이 skill이 필요한가 / 어떤 모양이 가장 좋은가"를 한 번 같이 고민한다.

## 왜 이 Phase가 필요한가

skill은 한 번 만들어지면 **수십·수백 번** 호출된다. 초기에 5분 설계를 건너뛰면 잘못된 scope·잘못된 경계를 가진 skill이 매번 호출될 때마다 사용자 시간을 낭비한다.

brainstorming skill의 가르침을 빌리면: **"이 skill은 간단해서 설계가 필요 없다"는 anti-pattern**이다. 간단해 보이는 skill도 1~2분의 scope 대화를 거쳐야 한다. 길 필요는 없지만, 건너뛰지는 말 것.

## HARD GATE — Phase 0 합의 전에는 파일 쓰기 금지

Phase 0의 4가지 종료 조건(scope·접근법·경계·중복)이 **모두 합의되기 전에는** Phase 3(SKILL.md·스크립트·config 작성)으로 진입할 수 없다. 어떤 경우에도 예외 없다.

> **왜 이게 gate인가**: 파일을 쓰기 시작하면 매몰비용이 생긴다. agent는 "이미 반쯤 썼으니 이대로 가자" 하고, 사용자는 "지워야 하나 아깝네" 한다. 결국 잘못된 scope로 skill이 완성된다. 디스크에 아무것도 쓰지 않은 상태가 **가장 싼 수정 시점**이다.

애매할 땐 사용자에게 한 번 더 확인: "여기서 파일 쓰기 시작해도 될까요?"

## 종료 조건

아래 4가지가 사용자와 합의되면 Phase 0 종료 → Phase 1(슬롯 추출)로 진입:

1. **Scope 적절함** — 너무 크지도(decompose 필요), 너무 작지도(skill 만들 필요가 있나?) 않다
2. **접근법 1개 선택됨** — 2~3개 대안 중 사용자가 하나를 골랐음
3. **경계 명확함** — "이 skill은 X는 하지만 Y는 안 한다"가 한 줄로 말해짐
4. **기존 skill과의 관계 정리됨** — 비슷한 skill이 있는지 찾아봤고, 겹치면 어떻게 할지 정해짐

## 절차

### Step A — 프로젝트 문맥 탐색 (Explore)

질문 던지기 전에 agent가 먼저 확인한다:

- 현재 어떤 skill 디렉터리가 이미 있는가? (`ls ~/.claude/skills`, `ls <plugin>/skills`)
- 사용자가 최근 대화에서 언급한 도구·워크플로우는 무엇인가?
- 만들려는 skill과 이름·기능이 비슷한 기존 skill이 있는가?

찾은 내용은 짧게 사용자에게 공유한다. 예:
> "기존에 `jenkins`, `pg-query`, `ssh-remote-execute` skill이 이미 있네요. 이번에 만들려는 건 이것들과 어떤 관계인가요?"

### Step B — Scope Check

요청된 skill이 아래 중 어느 쪽인지 판정:

| 판정 | 예시 | 조치 |
|------|------|------|
| ✅ **적절** | "사내 GitLab에서 MR·브랜치·변경파일 조회·MR 생성" | Step C로 |
| 🚫 **너무 큼** | "GitLab + Jenkins + Redmine + 배포 파이프라인 통합 관리" | "여러 skill로 쪼개야 할 것 같은데, 어떤 순서로 만들까요?" — decompose 먼저 |
| ⚠️ **너무 작음** | "curl 한 번 치면 되는 걸 skill로 감싸기" | "이건 한 줄 bash 명령인데, skill로 만들 이유가 있나요? (재사용 빈도? 팀원 공유?)" — 왜 skill이 필요한지 재확인 |

### Step C — 2~3개 접근법 제시

bad: 사용자가 말한 그대로 단일 설계를 바로 SKILL.md로 쓴다.

good: 같은 요구를 **다른 모양으로 풀 수 있는 방법 2~3개**를 추천과 함께 제시한다.

예 (GitLab skill 요청 시):

```
이 skill을 설계하는 방법은 몇 가지가 있는데, 제 추천부터 말씀드리면:

추천) 범용 CLI 스크립트 + alias 매핑
  — gitlab_api.py 에 모든 동작(branches/mr-info/mr-create/...) 몰고,
    config.json 에 레포 alias 둔다.
  — 장점: 한 곳에서 관리, 테스트 쉬움
  — 단점: 스크립트가 길어질 수 있음

2) 기능별 분리 (gitlab-mr, gitlab-branch, gitlab-file 등)
  — skill을 여러 개로 쪼갠다
  — 장점: 각 skill이 작고 트리거가 명확함
  — 단점: config·공통 로직 중복

3) 기존 git CLI 래퍼 + GitLab API 하이브리드
  — 로컬 git 명령 + API 호출 섞어서
  — 장점: 이미 checkout 된 경우 빠름
  — 단점: 로컬 clone 필요

어느 쪽으로 갈까요? (1이 보통 제일 깔끔)
```

**규칙:**
- 추천안을 **첫 번째**에 두고 "왜 추천인지" 한 줄.
- 대안마다 장점·단점 1줄씩.
- 전문 용어는 풀어서 설명 (H5).
- 한 메시지로 선택지 제시. 사용자 응답 받고 Step D로.

### Step D — 경계 명확화 (What it does / does NOT do)

사용자가 접근법을 골랐으면, **"이 skill은 X는 하지만 Y는 안 한다"** 를 한 줄로 합의한다. YAGNI(You Aren't Gonna Need It) 원칙 — 당장 필요 없는 기능은 빼고, 나중에 필요하면 추가.

예:
> "이 skill은 **GitLab 조회·MR 생성까지만** 하고, **머지·파이프라인 실행은 안 한다**. 괜찮은가요?"

이 한 줄이 나중에 scope creep(기능 팽창)을 막는 방파제가 된다.

### Step E — 중복 확인

기존 skill 중 비슷한 게 있으면 어떻게 할지 정한다:

- **확장**: 기존 skill을 고쳐서 기능 추가 (IMPROVE 모드로 전환할 수도)
- **분리**: 새 skill을 따로 만들되 역할 분담을 명확히
- **대체**: 기존 skill을 지우고 새것으로

**이 결정을 미루면 중복된 trigger로 agent가 어느 skill을 쓸지 헷갈린다.**

### Step F — 단위 분리(action) 밑그림

skill 안의 각 action(CLI 하위 명령)은 **하나의 명확한 목적**을 가져야 한다. 이 Step에서는 action을 전부 설계하는 게 아니라 **대략적인 목록 + 각 action이 한 줄로 뭘 하는지** 만 정한다. 상세 인자·에러 처리는 Phase 3 영역.

판정 질문:

- 이 action 이름만 보고 "뭘 하는지" 알 수 있는가? (예: `mr-changes` ✅ / `process` ❌)
- 각 action은 **한 가지 일**만 하는가? 여러 일을 묶은 action은 쪼갤 것 (예: `sync-all` ❌ → `fetch` + `upload` 분리)
- action 간 의존이 명확한가? (예: `branches` → `mr-create-from-branch` → `mr-info` 흐름)

한 줄씩 적고 끝. 예:

```
branches <project>        — origin 브랜치 목록
mr-create <project> ...   — MR 생성 (수동)
mr-create-from-branch     — 브랜치명 파싱 후 자동 생성
mr-info <project> <iid>   — MR 상세
mr-changes <project> <iid>— MR 변경파일만 요약
file-raw <project> ...    — 특정 브랜치의 파일 원본
```

> **왜 이 Step이 여기 있나**: Phase 1(슬롯)과 Phase 3(작성) 사이에서 "어떤 action으로 쪼갤까"가 빠지면 agent가 모든 걸 한 action에 몰아넣거나(거대 `do-everything`), 반대로 너무 쪼개서(`get-mr`, `get-mr-changes`, `get-mr-commits` ...) 중복투성이로 만든다. Phase 0에서 대략의 action 경계를 잡아두면 Phase 3에서 혼란이 없다.

## Phase 0에서 묻지 말 것 (Phase 1에서 묻는다)

Phase 0의 목적은 **무엇을·왜 만들까** 합의. **어떻게 만들까**(상세 입력/출력/UI 경로 등)는 Phase 1~2 영역. 섞이지 않게:

| Phase 0 | Phase 1~2 |
|---------|----------|
| 이 skill이 필요한가? | 어떤 인증 방식을 쓸까? |
| 어떤 접근법이 좋을까? | config 파일을 어디에 둘까? |
| 기존 skill과 관계는? | 어떤 CLI action을 제공할까? |
| YAGNI — 뺄 기능? | 에러 발생 시 어떤 메시지? |

## 예시: 실제 대화 흐름

**사용자:** "사내 GitLab에 접근해서 MR 변경 파일 보는 skill 만들어줘"

**Step A — Explore:**
> "기존 skills/ 를 훑어보니 jenkins, pg-query, ssh-remote-execute 가 있네요. GitLab 관련 skill은 없고, 이게 첫 번째인 듯합니다."

**Step B — Scope check:** "적절" 판정 (너무 크지도 작지도 않음) → Step C로.

**Step C — 접근법 제시:** 위 예시 그대로. 사용자가 1번 선택.

**Step D — 경계:**
> "이 skill은 **GitLab 조회 + MR 생성**까지만 하고, 머지·파이프라인·webhook은 안 합니다. 나중에 필요하면 그때 확장. 동의?"

사용자: "동의"

**Step E — 중복 확인:**
> "기존 skill과 겹치는 건 없어서 새로 만들면 됩니다."

→ Phase 0 종료, Phase 1(슬롯 추출)로 진입.

## 언제 Phase 0를 건너뛸 수 있나

- 사용자가 **이미 기존 skill과의 관계·scope·접근법을 명확히 제시**한 경우. 예: "기존 gitlab skill 고치는 게 아니라 새로 만들고 싶고, 다른 접근법은 고려 안 함"
- IMPROVE/REVIEW 모드 (Phase 0는 CREATE 전용)

건너뛸 때도 agent는 **"Phase 0를 스킵했습니다 — 다음 이유: ~"** 를 한 줄로 사용자에게 알리고 Phase 1로 진입. 묵묵히 건너뛰지 말 것.
