# docs 레거시 정리 및 신기능 문서화 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** v4.2~v4.3 대전환(리브랜딩·npx 단일화·provider 사다리·deploy/publish 2축·레거시 마이그레이션) 이후 docs/·README의 레거시 잔재를 제거하고 신기능 문서 공백을 메운다.

**Architecture:** 문서 전용 변경. 코드·워크플로우·스크립트는 한 줄도 수정하지 않는다. 기존 문서 4개 수정(SKILLS, WORKFLOW-COMMENT-GUIDELINES, CHANGELOG-AUTOMATION, VERSION-CONTROL) + 신규 1개(NPX-WIZARD) + README 표기/색인 갱신. 스펙: `docs/superpowers/specs/2026-07-12-docs-legacy-cleanup-design.md`

**Tech Stack:** Markdown, grep 검증, npm test(정합성 테스트)

## Global Constraints

- **모든 문서는 한국어**로 작성한다 (코드/커맨드 제외).
- **보존 계약 — 아래 표기는 절대 수정 금지:**
  - `"Guide by SUH-LAB"` 댓글 마커 전부 (외부 봇 서명 매칭 계약, 커밋 25b798e)
  - `version_manager.sh` 표기 (.sh는 현행 지원 shim, #448)
  - `PROJECT-COMMON-SUH-ISSUE-HELPER-API` / `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE` 워크플로우명 (현행 파일명)
  - `docs/TEMPLATE-INTEGRATOR.md`의 EOF 안내 성격 (Task 4의 링크 1줄 추가만 예외)
  - `WORKFLOW-COMMENT-GUIDELINES.md`의 "next 타입은 v4.1.0에서 흡수" (올바른 이력 서술)
- **커밋 컨벤션**: `제목 : docs : 설명` 형식. 이모지·태그 접두 금지. Co-Authored-By 금지. push 금지(커밋만).
- **docs/는 템플릿 복사 제외 폴더** → `template_initializer.py`/`exclusions.js` 수정 불필요 (신규 파일 추가해도 배선 작업 없음).
- 각 태스크의 검증 grep은 **레포 루트**에서 실행한다.

---

### Task 1: SKILLS.md·README `/projectops:` 스킬 호출 표기 잔재 수정

배경: #459 리브랜딩에서 스킬 호출 표기를 `/pro-<skill>`로 통일했으나(커밋 e67a660) 이 3줄이 누락됐다. 현행 스킬 커맨드는 `pro-github`, `pro-review` 등이며 `/pro-`까지 입력하면 자동완성된다.

**Files:**
- Modify: `docs/SKILLS.md:10` (호출 형태 설명)
- Modify: `docs/SKILLS.md:25` (자동완성 안내)
- Modify: `README.md:127` (자동완성 안내)

**Interfaces:**
- Consumes: 없음 (독립 태스크)
- Produces: 없음 (이후 태스크와 무관)

- [ ] **Step 1: SKILLS.md 10행 수정**

Edit — old_string:
```
Skill은 특정 작업(예: 코드 리뷰, 이슈 작성, 리팩토링)에 특화된 지침과 출력 포맷을 가진 **전문가 모드**입니다. Claude Code에서는 `/projectops:xxx` 형태로 호출하고, Gemini CLI는 extension, Codex CLI는 plugin marketplace를 통해 이 레포의 `skills/`를 읽습니다.
```
new_string:
```
Skill은 특정 작업(예: 코드 리뷰, 이슈 작성, 리팩토링)에 특화된 지침과 출력 포맷을 가진 **전문가 모드**입니다. Claude Code에서는 `/pro-<skill>` 형태(예: `/pro-review`)로 호출하고, Gemini CLI는 extension, Codex CLI는 plugin marketplace를 통해 이 레포의 `skills/`를 읽습니다.
```

- [ ] **Step 2: SKILLS.md 25행 수정**

Edit — old_string:
```
설치 후 Claude Code에서 `/projectops:` 까지 입력하면 사용 가능한 Skill 목록이 자동완성됩니다.
```
new_string:
```
설치 후 Claude Code에서 `/pro-` 까지 입력하면 사용 가능한 Skill 목록이 자동완성됩니다.
```

- [ ] **Step 3: README.md 127행 수정**

Edit — old_string:
```
> Claude Code는 `/projectops:` 자동완성, Gemini는 extension, Codex는 plugin marketplace를 우선 사용합니다. 자세한 설치 방식은 [Skills 가이드](docs/SKILLS.md)를 확인하세요.
```
new_string:
```
> Claude Code는 `/pro-` 자동완성, Gemini는 extension, Codex는 plugin marketplace를 우선 사용합니다. 자세한 설치 방식은 [Skills 가이드](docs/SKILLS.md)를 확인하세요.
```

- [ ] **Step 4: 검증**

Run: `grep -rn "projectops:" docs/SKILLS.md README.md`
Expected: 스킬 호출 표기(`/projectops:`) 매치 0건. (`Cassiiopeia/projectops` 같은 레포 경로 매치는 무관 — 콜론 뒤 스킬명 패턴만 없으면 됨)

- [ ] **Step 5: 커밋**

```bash
git add docs/SKILLS.md README.md
git commit -m "스킬 호출 표기 잔재 정리 : docs : SKILLS.md·README의 /projectops: 표기 3곳을 현행 /pro-<skill>로 수정 (#459 리브랜딩 누락분)"
```

---

### Task 2: WORKFLOW-COMMENT-GUIDELINES.md 구 워크플로우명 수정

배경: `PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER`는 #459에서 `PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER`로 리네임됐다 (registry.js `wf-suh-lab-build-trigger` 항목으로도 확인됨).

**Files:**
- Modify: `docs/WORKFLOW-COMMENT-GUIDELINES.md:281` (적용 파일 목록)
- Modify: `docs/WORKFLOW-COMMENT-GUIDELINES.md:366` (상태 표)

**Interfaces:**
- Consumes: 없음
- Produces: 없음

- [ ] **Step 1: 281행 목록 항목 수정**

Edit — old_string:
```
- SUH-LAB-BUILD-TRIGGER
```
new_string:
```
- PROJECTOPS-APP-BUILD-TRIGGER
```

- [ ] **Step 2: 366행 표 행 수정**

Edit — old_string:
```
| SUH-LAB-BUILD-TRIGGER | E | ✅ |
```
new_string:
```
| PROJECTOPS-APP-BUILD-TRIGGER | E | ✅ |
```

- [ ] **Step 3: 검증**

Run: `grep -rn "SUH-LAB-BUILD" docs/`
Expected: 매치 0건.

Run: `grep -n "Guide by SUH-LAB" docs/ISSUE-AUTOMATION.md | head -1`
Expected: 1건 이상 (보존 계약 생존 확인 — 이 표기를 건드렸다면 되돌릴 것).

- [ ] **Step 4: 커밋**

```bash
git add docs/WORKFLOW-COMMENT-GUIDELINES.md
git commit -m "워크플로우 가이드라인 구명칭 정리 : docs : SUH-LAB-BUILD-TRIGGER 2곳을 현행 PROJECTOPS-APP-BUILD-TRIGGER로 수정"
```

---

### Task 3: CHANGELOG-AUTOMATION.md provider 사다리 개정 (+README 문구 2곳)

배경: #455에서 릴리스 노트 생성이 provider 사다리 구조로 바뀌었으나 문서는 CodeRabbit 단일 전제 그대로다. 33행의 "CHANGELOG-CONTROL"은 구명칭 계열 표기(현행: RELEASE-CHANGELOG).

사실관계 (실물 확인 완료 — `.github/scripts/changelog_providers/ladder.py`, `PROJECT-COMMON-RELEASE-CHANGELOG.yaml`):
- provider는 `version.yml`의 `metadata.template.options.changelog.provider`에서 읽는다. 미설정 시 `coderabbit`(기존 동작 100% 보존), 신규 설치 기본은 `github-ai`.
- 폴백 사다리(ladder.py): `commit`→[commit] / `openai|gemini|claude|ollama`→[해당 provider → github-ai → commit] / `github-ai`·`coderabbit`→[github-ai → commit]. commit은 AI·네트워크 무의존 최후 보루. 폴백 발생 시 PR 댓글 알림.
- github-ai: GitHub Models API(`models.github.ai`), job `permissions: models: read` + GITHUB_TOKEN만으로 동작(API 키 불필요), 기본 모델 `openai/gpt-4o-mini`.
- openai/gemini/claude: OpenAI 호환 `/chat/completions`, `MODEL_API_KEY` secret 필요. ollama: `changelog.base_url` 필수(기본 모델 qwen2.5).
- provider가 coderabbit이 아니면 CodeRabbit 폴링을 건너뛰고 fallback-summary job(사다리)로 위임.

**Files:**
- Modify: `docs/CHANGELOG-AUTOMATION.md` (3행 개요문, 9~14행 개요 표, 20~39행 흐름도, 43행 앞 신규 절 삽입, 108행, 152~158행, 162행, 211~218행)
- Modify: `README.md:137`, `README.md:254`

**Interfaces:**
- Consumes: 없음
- Produces: "릴리스 노트 provider 사다리" 절 — Task 4의 NPX-WIZARD.md가 이 절로 링크한다 (앵커: `CHANGELOG-AUTOMATION.md#릴리스-노트-provider-사다리`)

- [ ] **Step 1: 도입문(3행) 수정**

Edit — old_string:
```
main 브랜치로 PR이 생성되면 CodeRabbit AI 리뷰를 기반으로 체인지로그가 자동 생성됩니다.
```
new_string:
```
main 브랜치로 PR(develop→main)이 생성되면 릴리스 노트 provider(기본: CodeRabbit, 신규 설치 기본: github-ai)가 체인지로그를 자동 생성합니다. provider가 실패해도 폴백 사다리(github-ai → commit)가 릴리스 노트를 끝까지 만들어냅니다 (#455).
```

- [ ] **Step 2: 개요 표(11행) 수정**

Edit — old_string:
```
| **AI 분석** | CodeRabbit이 변경사항 자동 분석 |
```
new_string:
```
| **AI 분석** | 선택한 provider(coderabbit/github-ai/openai 계열/commit)가 변경사항 자동 분석 |
| **폴백 사다리** | provider 실패 시 github-ai → commit 순 폴백, 폴백 발생 시 PR 댓글 알림 |
```

- [ ] **Step 3: 자동화 흐름도(30~33행) 수정**

Edit — old_string:
```
CodeRabbit AI 리뷰
    │
    ▼
CHANGELOG-CONTROL 워크플로우
```
new_string:
```
릴리스 노트 생성 (provider 사다리)
    │
    ▼
RELEASE-CHANGELOG 워크플로우
```

- [ ] **Step 4: "릴리스 노트 provider 사다리" 절 신규 삽입 (흐름도와 "## 출력 파일" 사이)**

Edit — old_string:
````
    ├─ Summary 파싱
    ├─ CHANGELOG.json 업데이트
    ├─ CHANGELOG.md 생성
    └─ PR 자동 머지
```

---

## 출력 파일
````
new_string:
````
    ├─ Summary 파싱
    ├─ CHANGELOG.json 업데이트
    ├─ CHANGELOG.md 생성
    └─ PR 자동 머지
```

> 구명칭 이력: 이 워크플로우는 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL`에서 v4.3.0에 `PROJECT-COMMON-RELEASE-CHANGELOG`로 리네임되었습니다. 구 파일이 남아있으면 `npx projectops` 업데이트가 자동 무해화합니다 ([NPX 마법사 가이드](NPX-WIZARD.md) 참조).

---

## 릴리스 노트 provider 사다리

릴리스 노트 생성기는 `version.yml`의 `metadata.template.options.changelog.provider`로 선택합니다 (#455).

```yaml
metadata:
  template:
    options:
      changelog:
        provider: "github-ai"   # coderabbit | github-ai | openai | gemini | claude | ollama | commit
        # base_url: "http://localhost:11434/v1"   # ollama 전용 (필수)
```

| provider | 방식 | 요구사항 |
|----------|------|---------|
| `coderabbit` (미설정 시 기본 — 기존 동작 보존) | CodeRabbit Summary 폴링 | 저장소에 CodeRabbit 앱 설치 |
| `github-ai` (신규 설치 기본) | GitHub Models API (`github_ai.py`) | 없음 — job의 `permissions: models: read` + GITHUB_TOKEN만으로 동작 (API 키 불필요, 기본 모델 `openai/gpt-4o-mini`) |
| `openai` / `gemini` / `claude` | OpenAI 호환 API (`openai_compatible.py`) | `MODEL_API_KEY` secret |
| `ollama` | OpenAI 호환 API (자체 호스팅) | `changelog.base_url` 필수 (기본 모델 `qwen2.5`) |
| `commit` | 커밋 메시지 분석 (`commit.py`) | 없음 — AI·네트워크 무의존 최후 보루 |

**폴백 순서** (`.github/scripts/changelog_providers/ladder.py`):

- `commit` → commit만 실행
- `openai`/`gemini`/`claude`/`ollama` → 해당 provider → github-ai → commit
- `github-ai` → github-ai → commit
- `coderabbit` → Summary 폴링 무응답 시 github-ai → commit

폴백이 발생하면 어떤 provider로 대체됐는지 **PR 댓글로 알림**이 남습니다. commit provider가 항상 완주하므로 릴리스 노트가 비는 일은 없습니다.

테스트: `python -m pytest .github/scripts/test/test_changelog_providers.py`

---

## 출력 파일
````

- [ ] **Step 5: 카테고리 분류 도입문(108행) 수정**

Edit — old_string:
```
CodeRabbit이 변경사항을 자동으로 분류합니다.
```
new_string:
```
선택한 provider가 변경사항을 자동으로 분류합니다.
```

- [ ] **Step 6: 워크플로우 절 "실행 내용"(152~158행) 수정**

Edit — old_string:
```
**실행 내용**:
1. CodeRabbit Summary 대기
2. Summary 파싱
3. CHANGELOG.json 업데이트
4. CHANGELOG.md 생성
5. 변경사항 커밋
6. PR 자동 머지
```
new_string:
```
**실행 내용**:
1. version.yml에서 changelog provider 판독 (미설정 시 coderabbit)
2. provider=coderabbit이면 Summary 요청·폴링 / 아니면 폴링 생략
3. Summary가 없으면 fallback-summary job이 provider 사다리(ladder.py) 실행
4. Summary/릴리스 노트 파싱 → CHANGELOG.json 업데이트 → CHANGELOG.md 생성
5. 변경사항 커밋 (버전 확정 커밋)
6. PR 자동 머지
```

- [ ] **Step 7: CodeRabbit 연동 절 제목(162행) 수정**

Edit — old_string:
```
## CodeRabbit 연동
```
new_string:
```
## CodeRabbit 연동 (provider=coderabbit일 때)
```

- [ ] **Step 8: 트러블슈팅(215~218행) 확인 사항 보강**

Edit — old_string:
```
**확인 사항**:
1. CodeRabbit이 Summary를 남겼는지 확인
2. `_GITHUB_PAT_TOKEN` Secret 설정 확인
3. Actions 로그에서 에러 확인
```
new_string:
```
**확인 사항**:
1. `version.yml`의 `options.changelog.provider` 값 확인 (coderabbit이면 CodeRabbit이 Summary를 남겼는지 확인)
2. `_GITHUB_PAT_TOKEN` Secret 설정 확인 (openai 계열 provider는 `MODEL_API_KEY`도 확인)
3. Actions 로그에서 fallback-summary job이 어느 provider로 완주했는지 확인 (`PROVIDER=<승자>` 출력)
```

- [ ] **Step 9: README 137행 수정**

Edit — old_string:
```
| **AI 체인지로그** | CodeRabbit 리뷰 기반 CHANGELOG 자동 생성 | [상세](docs/CHANGELOG-AUTOMATION.md) |
```
new_string:
```
| **AI 체인지로그** | provider 사다리(CodeRabbit/GitHub Models/OpenAI 계열/commit) 기반 CHANGELOG 자동 생성 | [상세](docs/CHANGELOG-AUTOMATION.md) |
```

- [ ] **Step 10: README 254행 수정**

Edit — old_string:
```
| [체인지로그 자동화](docs/CHANGELOG-AUTOMATION.md) | CodeRabbit 연동, AI 문서화 |
```
new_string:
```
| [체인지로그 자동화](docs/CHANGELOG-AUTOMATION.md) | 릴리스 노트 provider 사다리, CodeRabbit 연동 |
```

- [ ] **Step 11: 검증**

Run: `grep -n "CHANGELOG-CONTROL" docs/CHANGELOG-AUTOMATION.md`
Expected: `RELEASE-CHANGELOG` 표기만 매치 (RELEASE- 접두 없는 단독 `CHANGELOG-CONTROL` 0건).

Run: `grep -c "provider" docs/CHANGELOG-AUTOMATION.md`
Expected: 10 이상 (사다리 절이 실제로 들어감).

Run: 문서에 적은 사실 대조 —
```bash
grep -n "gpt-4o-mini" .github/scripts/changelog_providers/github_ai.py
grep -n "qwen2.5" .github/scripts/changelog_providers/openai_compatible.py
grep -n "models: read" .github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml
```
Expected: 각 1건 이상 (문서 내용과 실물 일치).

- [ ] **Step 12: 커밋**

```bash
git add docs/CHANGELOG-AUTOMATION.md README.md
git commit -m "체인지로그 문서 provider 사다리 개정 : docs : CodeRabbit 단일 전제를 provider 사다리(coderabbit/github-ai/openai계열/commit) 구조로 재작성, 구명칭 CHANGELOG-CONTROL 정리, README 문구 동기화 (#455 반영)"
```

---

### Task 4: NPX-WIZARD.md 신규 작성 (+README 색인·TEMPLATE-INTEGRATOR 링크)

배경: deploy/publish 2축(#439)·레거시 자동 마이그레이션(#470)·모드/플래그 체계(#424)가 docs에 전혀 없다. npx 마법사가 진입점인 기능을 한 문서로 통합한다.

사실관계 (실물 확인 완료 — `src/cli/args.js`, `src/core/migrations/registry.js`, `src/core/migrations/index.js`):
- deploy 축(택1): `docker-ssh`(기본)·`vercel`·`none` / publish 축(0..n): `nexus`·`npm`·`github-packages`
- `--nexus`는 deprecated → `--publish nexus --deploy none` 해석 + 경고 (args.js:83~86 실측)
- 마이그레이션: safe 티어는 확인 1회 후 `.bak` 무해화(비대화형 자동), confirm 티어는 안내만·`--force`에서도 불변 (registry.js 주석 실측)
- registry 등록 항목: workflow/safe 16종, workflow/confirm 22종, root-file/safe 2종 (2026-07-12 실측: `node -e` 집계)

**Files:**
- Create: `docs/NPX-WIZARD.md`
- Modify: `README.md:252` 아래 색인 표에 행 추가
- Modify: `docs/TEMPLATE-INTEGRATOR.md` 말미 링크 1줄

**Interfaces:**
- Consumes: Task 3의 앵커 `CHANGELOG-AUTOMATION.md#릴리스-노트-provider-사다리`
- Produces: `docs/NPX-WIZARD.md` — Task 5의 VERSION-CONTROL.md가 이 문서로 링크한다

- [ ] **Step 1: docs/NPX-WIZARD.md 생성**

전체 내용 (아래 그대로 Write):

````markdown
# NPX 마법사 가이드 (npx projectops)

기존 프로젝트에 템플릿을 통합·업데이트하는 유일한 공식 경로입니다. 구 `template_integrator.sh`/`.ps1`은 v4.3.0에서 지원 종료(EOF)되었습니다 ([상세](TEMPLATE-INTEGRATOR.md)).

- **요구사항**: Node.js 20.12 이상
- macOS / Linux / Windows 공통 단일 경로

---

## 기본 사용법

```bash
# 대화형 마법사
npx projectops

# 비대화형 (CI 등)
npx projectops --mode full --type spring,react --force

# Agent Skills만 설치
npx projectops --mode skills

# 전체 옵션
npx projectops --help
```

| 모드 | 기능 |
|------|------|
| `full` | 워크플로우 + version.yml + 이슈 템플릿 + Skills 전체 통합 |
| `version` | version.yml만 |
| `workflows` | 워크플로우만 |
| `issues` | 이슈/PR 템플릿만 |
| `skills` | Agent Skills만 |

선택 값은 전부 `version.yml`의 `metadata.template.options.*`에 저장되어, 다음 업데이트 시 재질문 없이 재사용됩니다.

---

## 배포/publish 2축 (#439)

배포는 서로 독립인 **두 개의 축**으로 표현됩니다. 마법사가 타입 확정 직후 질문합니다.

| 축 | 의미 | 다중성 | 값 | version.yml 키 |
|----|------|--------|-----|---------------|
| **deploy** | 실행물(서버/앱)을 어디에 올리나 | **택1** | `docker-ssh`(기본) · `vercel` · `none` | `options.deploy` |
| **publish** | 라이브러리/패키지를 어느 레지스트리에 내나 | **0..n 공존** | `nexus` · `npm` · `github-packages` | `options.publish` 배열 |

```bash
# 비대화형 지정
npx projectops --deploy docker-ssh --publish nexus,npm
```

### 축별로 포함되는 워크플로우

| 선택 | 포함되는 워크플로우 | 원본 위치 |
|------|-------------------|----------|
| `--deploy docker-ssh` | SIMPLE/NONSTOP-TRAEFIK/NONSTOP-NGINX/PR-PREVIEW 등 서버 배포 세트 | `project-types/spring/server-deploy/` |
| `--deploy vercel` | `PROJECT-COMMON-VERCEL-DEPLOY` (VERCEL_TOKEN·VERCEL_ORG_ID·VERCEL_PROJECT_ID secret 필요) | `project-types/common/deploy/vercel/` |
| `--deploy none` | 서버 배포 워크플로우 제외 | - |
| `--publish nexus` | `PROJECT-SPRING-NEXUS-CI` / `-NEXUS-PUBLISH` | `project-types/spring/publish/nexus/` |
| `--publish npm` | `PROJECT-NODE-NPM-PUBLISH` (NPM_TOKEN secret) | `project-types/node/publish/npm/` |
| `--publish github-packages` | `PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH` | `project-types/spring/publish/github-packages/` |
| `--secret-backup` | `PROJECT-COMMON-SECRET-FILE-UPLOAD` (opt-in) | `project-types/common/secret-backup/` |

### 알아둘 규칙

- **`basic` 단독 타입은 배포/publish 질문을 건너뜁니다** — `deploy=none`·`publish=[]`로 조용히 확정됩니다. 타입을 실타입으로 바꾸면 그때 질문이 등장합니다.
- **구 플래그 deprecated**: `--nexus`/`--npm-publish`는 각각 `--publish nexus`/`--publish npm`으로 해석되며 경고가 출력됩니다 (`--nexus`는 추가로 `--deploy none` 함의). 1 minor 유지 후 제거 예정.
- version.yml의 구 키(`nexus`/`npm_publish`)는 업데이트 시 신 축으로 자동 변환·기록됩니다.

---

## 모노레포 경로 (`project_paths`)

타입별 프로젝트가 서브폴더에 있으면 경로를 지정합니다. 상세는 [버전 관리](VERSION-CONTROL.md) 참조.

```bash
npx projectops --paths "flutter=app,react=client"
```

---

## 레거시 워크플로우 자동 마이그레이션 (#470)

`full`/`workflows` 모드로 통합·업데이트하면 마법사가 대상 레포의 **구세대 템플릿 워크플로우 잔재를 자동 감지**합니다. 구 워크플로우가 신 워크플로우와 공존하면 릴리스 PR 이중 처리·CI 중복 실행 같은 실해가 발생하기 때문입니다.

### 2티어 안전 정책

| 티어 | 판정 기준 | 조치 |
|------|----------|------|
| **safe** | 순수 리네임·대체 (공존 시 중복 실행 실해) | 대화형: 확인 1회 후 `.bak` 무해화 / 비대화형(`--force`): 자동 무해화 |
| **confirm** | 배포 파이프라인일 수 있음 (그 레포의 유일한 현역 배포 가능성) | **자동 조치 없음** — 안내만 출력. `--force`에서도 건드리지 않음 |

### 보장 사항

- **커스텀 워크플로우 불가침**: 레지스트리는 정확한 파일명 매칭만 사용합니다 (글롭 금지). 사용자가 직접 만든 워크플로우는 절대 건드리지 않습니다.
- **복원 가능**: safe 조치는 삭제가 아니라 `.bak` 확장자 무해화입니다. 되돌리려면 `.bak`을 제거하면 됩니다.
  ```bash
  mv .github/workflows/PROJECT-OLD-NAME.yaml.bak .github/workflows/PROJECT-OLD-NAME.yaml
  ```
- **멱등**: 같은 명령을 다시 실행해도 이미 처리된 항목은 재조치되지 않습니다.

### 감지 대상 (v4.3.x 스냅샷)

전체 목록의 SSOT는 `src/core/migrations/registry.js`입니다. 요약:

- **workflow / safe (16종)**: 1세대 리네임(`PROJECT-VERSION-CONTROL` 등), 구명칭 릴리스 워크플로우(`PROJECT-AUTO-CHANGELOG-CONTROL`·`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` → `PROJECT-COMMON-RELEASE-CHANGELOG`), 리브랜딩 리네임(`PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER` → `PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER`), next 타입 폐지(`PROJECT-NEXT-CI`/`-CICD` → `PROJECT-REACT-*`), 구 확장자(.yml) CI 등
- **workflow / confirm (22종)**: SYNOLOGY 세대 배포 7종, 1세대 Spring/Python/Android/iOS 배포, AUTO-FILE-UPLOAD 계열, 구 Nexus publish 계열 등 — 전부 "현역 배포일 수 있음"이라 안내만
- **root-file / safe (2종)**: `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md`·`SETUP-GUIDE.md` → `PROJECTOPS-SETUP-GUIDE.md` (구 설치 가이드 잔재)

### 기여자 가이드라인 — 워크플로우를 리네임/삭제할 때

템플릿에서 워크플로우나 루트 파일을 리네임·폐기하면 **반드시 구 이름을 `src/core/migrations/registry.js`에 한 줄 추가**합니다. 이것이 기존 통합 레포의 구 파일을 자동 정리하는 유일한 경로입니다 (레거시 마이그레이션은 전부 이 레지스트리 한 곳에서 관리).

1. 항목 스키마: `id`(kebab-case) · `category`("workflow"|"root-file") · `tier` · `file`(정확한 파일명, 글롭 금지) · `replacedBy`(없으면 null) · `since` · `reason` · `contentMarker`(선택 — 파일명이 범용적일 때 오탐 방지)
2. **tier 판단 기준**: 실해로 고른다 —
   - `safe`: 신형이 같은 기능을 완전 대체(순수 리네임). 공존 시 이중 트리거가 실해
   - `confirm`: 배포 파이프라인일 수 있음. 오살하면 그 레포의 배포가 끊긴다 → 자동 조치 금지
3. `test/migrations.test.js`가 레지스트리 항목이 **현행 배포 세트와 겹치지 않는지**(살아있는 워크플로우 오살 방지) 자동 검증한다. 등록 후 `npm test`로 확인.

---

## 관련 문서

- [Template Integrator EOF 안내](TEMPLATE-INTEGRATOR.md) — 구 스크립트 → npx 플래그 대응표
- [버전 관리](VERSION-CONTROL.md) — version.yml·모노레포 project_paths
- [체인지로그 자동화](CHANGELOG-AUTOMATION.md#릴리스-노트-provider-사다리) — 릴리스 노트 provider 사다리
````

- [ ] **Step 2: README 색인 표에 행 추가**

Edit — old_string:
```
| [통합 스크립트 가이드](docs/TEMPLATE-INTEGRATOR.md) | 기존 프로젝트에 템플릿 통합 |
```
new_string:
```
| [NPX 마법사 가이드](docs/NPX-WIZARD.md) | npx projectops 통합·배포/publish 2축·레거시 자동 마이그레이션 |
| [통합 스크립트 가이드](docs/TEMPLATE-INTEGRATOR.md) | 구 integrator 지원 종료(EOF) 안내 |
```

- [ ] **Step 3: TEMPLATE-INTEGRATOR.md 말미 링크 추가**

Edit — old_string:
```
자세한 사용법은 [README](../README.md)와 `npx projectops --help`를 참고하세요.
```
new_string:
```
자세한 사용법은 [NPX 마법사 가이드](NPX-WIZARD.md), [README](../README.md), `npx projectops --help`를 참고하세요.
```

- [ ] **Step 4: 문서 사실 대조 검증**

```bash
# 플래그 실물 확인 (각 1건 이상 매치해야 함)
grep -n '"--deploy"\|"--publish"\|"--paths"\|"--secret-backup"' src/cli/args.js
grep -n "npm-publish" src/cli/args.js
# 레지스트리 티어 개수 대조 (문서의 16/22/2와 일치해야 함)
node -e "import('./src/core/migrations/registry.js').then(m => { const c = {}; for (const e of m.MIGRATIONS) { const k = e.category + '/' + e.tier; c[k] = (c[k]||0)+1; } console.log(c); })"
```
Expected: `{ 'workflow/safe': 16, 'workflow/confirm': 22, 'root-file/safe': 2 }` — 불일치하면 **문서 숫자를 실물에 맞춰 수정**한다 (레지스트리가 SSOT).

- [ ] **Step 5: 커밋**

```bash
git add docs/NPX-WIZARD.md docs/TEMPLATE-INTEGRATOR.md README.md
git commit -m "NPX 마법사 가이드 신규 작성 : docs : 배포/publish 2축·모드/플래그·레거시 자동 마이그레이션(2티어·복원·기여자 레지스트리 등록 규칙) 문서화 및 README 색인 추가 (#439 #470 반영)"
```

---

### Task 5: VERSION-CONTROL.md 모노레포 project_paths 절 추가 + py shim 각주

배경: 모노레포 `project_paths`(#424에서 version.yml 블록 도입, #448에서 version_manager.py가 시맨틱 유지)가 docs에 없다. version_manager 절에는 ".py가 실 로직"(#448) 각주가 없다.

**Files:**
- Modify: `docs/VERSION-CONTROL.md:44` 직후 (project_types 절 다음)
- Modify: `docs/VERSION-CONTROL.md:63~66` (version_manager.sh 사용법 도입부)

**Interfaces:**
- Consumes: Task 4가 만든 `docs/NPX-WIZARD.md` (링크 대상)
- Produces: 없음

- [ ] **Step 1: project_paths 절 삽입**

Edit — old_string:
````
- `version_manager.sh`가 배열을 순회하여 모든 타입의 버전 파일을 동기화합니다.

---

## 프로젝트 타입별 버전 파일
````
new_string:
````
- `version_manager.sh`가 배열을 순회하여 모든 타입의 버전 파일을 동기화합니다.

### `project_paths` (모노레포 경로 맵)

타입별 프로젝트가 서브폴더에 있는 모노레포는 `project_paths` 맵(타입 → 레포 루트 기준 상대경로)으로 위치를 지정합니다.

```yaml
project_types: ["flutter", "react"]
project_paths:
  flutter: "app"       # app/pubspec.yaml을 동기화
  react: "client"      # client/package.json을 동기화
```

- 키가 없는 타입은 **레포 루트 기준**으로 동작합니다 (기존 동작 100% 유지).
- `npx projectops` 통합 시 마커 파일(`pubspec.yaml`·`package.json`·`pyproject.toml`·`build.gradle` 등)을 자동 감지해 후보를 제안하며, 비대화형은 `--paths "flutter=app,react=client"`로 지정합니다 ([NPX 마법사 가이드](NPX-WIZARD.md) 참조).
- `version_manager.sh`가 이 경로를 따라 서브폴더 버전 파일을 동기화하므로, `PROJECT-COMMON-VERSION-CONTROL` 워크플로우는 수정 없이 모노레포를 지원합니다.

---

## 프로젝트 타입별 버전 파일
````

- [ ] **Step 2: version_manager 절에 py shim 각주 추가**

Edit — old_string:
```
## version_manager.sh 사용법

### 기본 명령어
```
new_string:
```
## version_manager.sh 사용법

> v4.2부터 실 로직은 `version_manager.py`(stdlib 전용 — yq/jq 불필요)에 있고 `.sh`는 Python 위임 shim입니다 (#448). Windows에서는 `python .github/scripts/version_manager.py get`처럼 .py를 직접 실행합니다.

### 기본 명령어
```

- [ ] **Step 3: 검증**

Run: `grep -n "project_paths" docs/VERSION-CONTROL.md`
Expected: 2건 이상 (절 제목 + yaml 예시).

Run: `grep -n "project_paths" .github/scripts/version_manager.py | head -3`
Expected: 1건 이상 (실물에 해당 키가 실제 존재 — 불일치 시 실물 기준으로 문서 수정).

- [ ] **Step 4: 커밋**

```bash
git add docs/VERSION-CONTROL.md
git commit -m "버전 관리 문서 모노레포 보강 : docs : project_paths 경로 맵 절 신설 및 version_manager .py 실로직 각주 추가 (#424 #448 반영)"
```

---

### Task 6: 최종 전수 검증

**Files:**
- 수정 없음 (검증만)

**Interfaces:**
- Consumes: Task 1~5의 모든 변경
- Produces: 없음 (완료 게이트)

- [ ] **Step 1: 레거시 키워드 전수 재스캔**

```bash
# 1) 스킬 호출 구표기 — 0건이어야 함
grep -rn "/projectops:" docs/*.md README.md
# 2) 구 워크플로우명 — 0건이어야 함 (registry.js·breaking-changes 등 코드 영역은 제외)
grep -rn "SUH-LAB-BUILD-TRIGGER" docs/ README.md
# 3) RELEASE- 접두 없는 단독 CHANGELOG-CONTROL — 0건이어야 함
grep -rn "CHANGELOG-CONTROL" docs/*.md README.md | grep -v "RELEASE-CHANGELOG" | grep -v "AUTO-CHANGELOG-CONTROL"
```
Expected: 1)·2) 매치 0건. 3) 매치 0건 (`AUTO-CHANGELOG-CONTROL`은 구명칭 이력 서술이라 허용).

- [ ] **Step 2: 보존 계약 생존 확인**

```bash
grep -rln "Guide by SUH-LAB" docs/
grep -rn "SUH-ISSUE-HELPER" docs/ISSUE-AUTOMATION.md | head -2
```
Expected: 첫 명령 3파일 이상(FLUTTER-TEST-BUILD-TRIGGER·PR-PREVIEW·ISSUE-AUTOMATION), 둘째 명령 1건 이상. **줄었다면 보존 계약 위반 — 해당 커밋을 수정할 것.**

- [ ] **Step 3: 정합성 테스트**

Run: `npm test`
Expected: 전체 PASS (rename-consistency 등 정합성 테스트 포함).

- [ ] **Step 4: 링크 유효성 확인**

```bash
# 문서 간 상대 링크 대상 파일 존재 확인
for f in NPX-WIZARD.md TEMPLATE-INTEGRATOR.md VERSION-CONTROL.md CHANGELOG-AUTOMATION.md; do [ -f "docs/$f" ] && echo "OK docs/$f" || echo "MISSING docs/$f"; done
```
Expected: 4줄 모두 `OK`.

- [ ] **Step 5: 계획 체크박스 완료 표시 후 종료**

수정 커밋이 추가로 발생했다면 (검증 단계에서 문서 수정 시):
```bash
git add -A docs/ README.md
git commit -m "docs 레거시 정리 검증 후속 수정 : docs : 전수 재스캔에서 발견된 잔여 표기 정리"
```
