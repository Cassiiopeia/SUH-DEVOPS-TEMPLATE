# changelog-deploy config·브랜치·provider 정합 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** pro-changelog-deploy 스킬이 릴리스 브랜치(head/base)·provider·자동모드를 config에서 읽고, config가 비면 최초 1회 자동판정 후 기록하도록 정합화한다. 6단계 브랜치 하드코딩을 제거하고 provider별 본문 생성 분기를 명시한다.

**Architecture:** 관심사 분리 — 스크립트(`changelog_cli.py`)는 로컬 파일(version.yml)만 읽어 사실을 반환하고, config 읽기·판단·질문은 agent(SKILL.md)가 한다. 브랜치·provider 판정 우선순위는 config(레포별→글로벌) → version.yml 폴백. 확정값은 config에 기록해 재질문을 없앤다. 스크립트는 이미 브랜치·provider를 지원하므로 변경 최소(하드코딩 기본값 정합 + 회귀 테스트).

**Tech Stack:** Python 3(stdlib only, `changelog_cli.py`·pytest), Markdown(SKILL.md·config-rules.md), JSON(config.json.example). 셸은 Git Bash(Windows).

## Global Constraints

- **config 파일**: `~/.projectops/config/config.json`. 스킬은 Read/Write 도구로 직접 처리(CLI 호출 금지). config-rules.md §4 규칙: 전체 Read → 해당 키만 수정 → Write(다른 섹션·PAT 보존).
- **사용자는 config를 직접 수정하지 않는다.** 모든 설정은 skill이 자연어 질문→답→Write로 관리. 판정 가능하면 안 묻고, 애매할 때만 묻는다. 한 번 물어 기록하면 재질문 없음.
- **사용자에게 config 키·파일 경로를 노출하지 않는다** (자연어로만 안내).
- **브랜치·provider 판정 우선순위**: ① config `github.repos[]`(owner/repo 매칭) `changelog_deploy` → ② config `github.changelog_deploy`(글로벌) → ③ version.yml(`deploy_branch`/`default_branch`/`options.changelog.provider`, `detect-release-context`가 폴백 develop/main/coderabbit로 반환).
- **config 스키마 3키**: `head_branch`(str) / `base_branch`(str) / `provider`(str: `coderabbit`|`commit`|`github-ai`|`openai`). 기존 `auto_approve`/`app_release`와 같은 2레벨 우선순위.
- **워크플로우 계약(변경 불가)**: 최종 PR 본문은 `## Summary by CodeRabbit` + `* **카테고리**` + `  * 항목` 마크다운. 본문에 `Summary by CodeRabbit` 있으면 워크플로우가 존중(provider 무관, RELEASE-CHANGELOG.yaml:191-192). skill 선제 작성 시 provider 무관 안전.
- **provider별 분기**: `coderabbit`/`github-ai`/`openai` → skill 선제 작성. `commit` → 선제 작성할지 1회 질문, 위임 선택 시 빈 흐름으로 워크플로우 fallback job에 맡김.
- **커밋 규칙**: 이모지·태그 prefix 금지, Claude/AI 흔적 금지. `develop` 브랜치 작업. push는 명시 요청 시에만.
- **테스트 기준선**: pytest 48/48, npm test 187/187 green 유지.

## File Structure

| 파일 | 책임 | 변경 |
|------|------|------|
| `skills/pro-changelog-deploy/scripts/changelog_cli.py` | 로컬 파일 사실 반환 | `deploy-status --base` 지시 정합(스크립트 기본값 유지, SKILL이 항상 전달). `_read_release_branches`는 이미 정상 — 무변경 |
| `skills/pro-changelog-deploy/scripts/tests/test_release_branches.py` | 브랜치·provider 파싱 회귀 | **신규** — version.yml 다양한 형태에서 head/base/provider 파싱 검증 |
| `skills/pro-changelog-deploy/SKILL.md` | 판정·질문·본문생성·PR생성 흐름 | [시작 전]에 §5 브랜치·provider 판정 절 추가, 5단계에 provider 분기표, 6·7단계 하드코딩→변수, [핵심 원칙]에 config 미수정 명문화 |
| `skills/config.json.example` | config 예시 | `changelog_deploy`에 3키 추가 |
| `skills/references/config-rules.md` | config 스키마 문서 | §7 changelog_deploy에 3키 문서화 |

**태스크 순서 원칙**: 스크립트·테스트(검증 가능한 코드) 먼저 → 그 위에 SKILL.md 지시 정합 → config 문서. 코드가 먼저 확정돼야 SKILL.md가 정확한 인터페이스를 참조할 수 있다.

---

## Task 1: 브랜치·provider 파싱 회귀 테스트 추가 (스크립트 검증)

**Files:**
- Create: `skills/pro-changelog-deploy/scripts/tests/test_release_branches.py`
- Reference: `skills/pro-changelog-deploy/scripts/changelog_cli.py:328` (`_read_release_branches`)

**Interfaces:**
- Consumes: `changelog_cli._read_release_branches(project_root: Path) -> dict` — 반환 `{"head": str, "base": str, "provider": str}`
- Produces: 이 함수의 파싱 정확성 회귀 보장. 이후 태스크가 이 함수 동작을 신뢰.

- [ ] **Step 1: 기존 테스트 폴더·import 패턴 확인**

Run:
```bash
cd D:/0-suh/project/suh-github-template
ls skills/pro-changelog-deploy/scripts/tests/ 2>/dev/null
head -20 skills/pro-changelog-deploy/scripts/tests/test_changelog_cli.py 2>/dev/null || echo "기존 테스트 없음 — 새 import 패턴 필요"
```
Expected: 기존 테스트가 있으면 그 import 방식(sys.path 또는 importlib) 확인. 없으면 Step 2에서 importlib.util 패턴 사용.

- [ ] **Step 2: 실패하는 테스트 작성**

Create `skills/pro-changelog-deploy/scripts/tests/test_release_branches.py`:
```python
# skills/pro-changelog-deploy/scripts/tests/test_release_branches.py
# _read_release_branches: version.yml에서 릴리스 head/base 브랜치·provider 파싱 회귀.
import importlib.util
from pathlib import Path

# changelog_cli를 파일 경로로 로드 (스킬 폴더는 패키지가 아님)
_CLI = Path(__file__).resolve().parents[1] / "changelog_cli.py"
_spec = importlib.util.spec_from_file_location("changelog_cli_rb", _CLI)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
_read = _mod._read_release_branches


def _write_version_yml(tmp_path: Path, content: str) -> Path:
    (tmp_path / "version.yml").write_text(content, encoding="utf-8")
    return tmp_path


def test_standard_develop_main_coderabbit(tmp_path):
    # version.yml에 키가 전혀 없으면 폴백 develop/main/coderabbit
    _write_version_yml(tmp_path, 'version: "1.0.0"\n')
    r = _read(tmp_path)
    assert r == {"head": "develop", "base": "main", "provider": "coderabbit"}


def test_custom_branches_and_provider(tmp_path):
    _write_version_yml(tmp_path, (
        'version: "1.0.0"\n'
        'metadata:\n'
        '  deploy_branch: "release"\n'
        '  default_branch: "production"\n'
        '  template:\n'
        '    options:\n'
        '      changelog:\n'
        '        provider: "commit"\n'
    ))
    r = _read(tmp_path)
    assert r["head"] == "release"
    assert r["base"] == "production"
    assert r["provider"] == "commit"


def test_unquoted_values(tmp_path):
    # 따옴표 없는 값도 파싱
    _write_version_yml(tmp_path, (
        'metadata:\n'
        '  deploy_branch: dev\n'
        '  default_branch: master\n'
    ))
    r = _read(tmp_path)
    assert r["head"] == "dev"
    assert r["base"] == "master"
    assert r["provider"] == "coderabbit"  # provider 미설정 → 폴백


def test_missing_version_yml(tmp_path):
    # version.yml 자체가 없으면 전부 폴백
    r = _read(tmp_path)
    assert r == {"head": "develop", "base": "main", "provider": "coderabbit"}
```

- [ ] **Step 3: 테스트 실행 — 통과 확인 (함수가 이미 존재)**

Run:
```bash
cd D:/0-suh/project/suh-github-template
PYTHON=$(for _py in python python3; do _p=$(command -v "$_py" 2>/dev/null) || continue; "$_p" -c "import sys;sys.exit(0)" 2>/dev/null && echo "$_p" && break; done)
"$PYTHON" -m pytest skills/pro-changelog-deploy/scripts/tests/test_release_branches.py -v 2>&1 | tail -12
```
Expected: 4 passed. (`_read_release_branches`는 이미 구현돼 있으므로 이 테스트는 현 동작을 고정하는 회귀 테스트 — 바로 통과해야 정상. 실패하면 파싱에 실측과 다른 버그가 있다는 신호이므로 Step 4에서 조사.)

- [ ] **Step 4: 만약 test_custom_branches_and_provider 실패 시 — provider 정규식 확인**

`_read_release_branches`의 provider 정규식은 `r"^\s*provider\s*:\s*[\"']?([a-z-]+)"`. 중첩 들여쓰기(`        provider:`)도 `^\s*`로 매칭되므로 통과해야 한다. 실패하면 실제 에러 메시지를 보고 정규식을 최소 수정(단, **head/base/provider 반환 키 이름·폴백값은 유지** — 다른 코드가 의존).

Run(실패 시만): `"$PYTHON" -m pytest skills/pro-changelog-deploy/scripts/tests/test_release_branches.py::test_custom_branches_and_provider -v 2>&1 | tail -20`

- [ ] **Step 5: 전체 pytest 회귀 확인**

Run:
```bash
"$PYTHON" -m pytest scripts/tests/ skills/pro-changelog-deploy/scripts/tests/ -q 2>&1 | tail -4
```
Expected: 기존 48 + 신규 4 = 52 passed (또는 기존 스킬 테스트 포함 그 이상). fail 0.

- [ ] **Step 6: 커밋**

```bash
git add skills/pro-changelog-deploy/scripts/tests/test_release_branches.py
git commit -m "changelog 릴리스 브랜치·provider 파싱 회귀 테스트 추가 : test : version.yml head/base/provider 4케이스 고정"
```

---

## Task 2: SKILL.md [시작 전]에 브랜치·provider 판정 절 추가

**Files:**
- Modify: `skills/pro-changelog-deploy/SKILL.md` — [시작 전] §4(app_release 판정) 뒤에 §5 신설

**Interfaces:**
- Consumes: `detect-release-context` JSON의 `branches.{head,base,provider}` (changelog_cli.py:402); config `changelog_deploy.{head_branch,base_branch,provider}`
- Produces: agent가 기억하는 `HEAD_BRANCH`/`BASE_BRANCH`/`PROVIDER`/`BRANCH_CONFIG_HAS_KEY` 값. 이후 5·6·7단계가 사용.

- [ ] **Step 1: §4 끝 위치 확인 (§5를 끼울 지점)**

Run:
```bash
cd D:/0-suh/project/suh-github-template
grep -n "### 4) 앱 심사 인지 값 판정\|## 사용자 입력" skills/pro-changelog-deploy/SKILL.md
```
Expected: §4 시작 라인과 "## 사용자 입력" 라인 확인. §5는 이 둘 사이(§4 끝 ~ "## 사용자 입력" 앞)에 삽입.

- [ ] **Step 2: §5 판정 절 삽입**

`skills/pro-changelog-deploy/SKILL.md`의 §4 블록 마지막(`> 글로벌 기본값(...)은 두지 않는다 ...` 줄) 다음, `## 사용자 입력` 앞에 아래를 삽입:

````markdown
### 5) 릴리스 브랜치·provider 판정 — config 우선, version.yml 폴백, 없으면 1회 판정

릴리스 PR의 head/base 브랜치와 릴리스 노트 생성 방식(provider)을 확정한다.
**사용자는 config를 직접 손대지 않는다 — 값이 없어 애매할 때만 자연어로 묻고, 답을 config에 기록한다.**

**우선순위 (위→아래, 먼저 발견되는 값 채택):**

1. config `github.repos[]` 중 `owner == OWNER && repo == REPO`인 항목의 `changelog_deploy.{head_branch, base_branch, provider}`
2. config `github.changelog_deploy.{head_branch, base_branch, provider}` (글로벌)
3. **최초 판정** — 1·2에 값이 없으면 `detect-release-context`(version.yml 폴백)로 자동 추론하고, 애매하면 사용자에게 물은 뒤 config에 기록

1 또는 2에서 세 값을 모두 얻었으면 그대로 쓰고 **묻지 않는다**. 기억할 값:

- `HEAD_BRANCH` — 릴리스 PR head(소스). 폴백 `develop`.
- `BASE_BRANCH` — 릴리스 PR base(프로덕션). 폴백 `main`.
- `PROVIDER` — `coderabbit`|`commit`|`github-ai`|`openai`. 폴백 `coderabbit`.
- `BRANCH_CONFIG_HAS_KEY` — boolean. 우선순위 1·2에서 세 값을 모두 찾았으면 `true`, 아니면 `false`(최초 판정 케이스).

**`BRANCH_CONFIG_HAS_KEY == false`(최초 판정)일 때만** 아래를 수행한다:

먼저 `detect-release-context`로 version.yml 신호를 읽는다:

```bash
# ⚠️ Bash stateless — PROJECT_ROOT·PYTHON을 [시작 전]에서 구한 실제 값으로 채운다.
PROJECT_ROOT="..."; PYTHON="..."
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-changelog-deploy/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-changelog-deploy/scripts"
PYTHONIOENCODING=utf-8 "$PYTHON" "$SCRIPTS/changelog_cli.py" detect-release-context --project-root "$PROJECT_ROOT"
```

반환 JSON의 `branches.{head,base,provider}`를 초기 후보로 삼는다.

**브랜치 확정:**
- version.yml에서 `deploy_branch`/`default_branch`를 읽었으면(폴백이 아닌 실제 값) 그대로 확정.
- 폴백(develop/main)이고 실제 원격에 `develop`이 있으며 default가 `main`이면 → 표준 구조로 조용히 확정.
- 그 외(develop 없음/default가 main 아님 등 애매) → 사용자에게 자연어로 묻는다:
  ```
  이 저장소의 릴리스는 어느 브랜치에서 어느 브랜치로 진행하나요?
  (예: 개발 브랜치에서 배포 브랜치로)
  1. develop → main (표준)
  2. 직접 알려주기 (예: "release 브랜치에서 production 브랜치로")
  ```
  응답에서 head/base를 확정.

**provider 확정:**
- `branches.provider`가 폴백(`coderabbit`)이 아닌 실제 값이면 그대로 확정.
- 폴백이고 레포 루트에 `.coderabbit.yaml`이 있으면 → `coderabbit`으로 조용히 확정.
- 폴백이고 `.coderabbit.yaml`도 없으면 → 사용자에게 묻는다:
  ```
  릴리스 노트를 어떻게 만들까요?
  1. CodeRabbit(AI 리뷰 봇)이 요약을 달아줍니다 (이 레포에 CodeRabbit 사용 시)
  2. 커밋 내역을 분석해 자동 생성합니다 (외부 봇 없이 항상 동작)
  ```
  → 1이면 `coderabbit`, 2면 `commit`.

`.coderabbit.yaml` 존재 확인:
```bash
PROJECT_ROOT="..."
[ -f "$PROJECT_ROOT/.coderabbit.yaml" ] && echo "coderabbit_config=yes" || echo "coderabbit_config=no"
```

**config 기록 (config-rules.md §4 규칙 — 전체 Read 후 해당 키만 Write):**
확정한 `head_branch`/`base_branch`/`provider`를, `github.repos[]`에 현 OWNER/REPO 매칭 항목이 있으면 그 항목의 `changelog_deploy`에, 없으면 `github.changelog_deploy`(글로벌)에 Write한다. PAT·다른 repos 항목·기존 auto_approve/app_release를 절대 날리지 않는다.

기록 후 사용자에게 자연어로만 안내(키·경로 노출 금지):
```
✅ 이 저장소 릴리스 방식을 기억했습니다 ({HEAD_BRANCH} → {BASE_BRANCH}, {provider 자연어}).
   바꾸고 싶으면 "배포 브랜치 바꿔줘" 또는 "릴리스 노트 방식 바꿔줘"라고 말씀해주세요.
```
(provider 자연어: coderabbit→"CodeRabbit 요약", commit→"커밋 분석", github-ai/openai→"AI 생성")

> **재설정 발화 처리**: 사용자가 이후 "배포 브랜치 바꿔줘"/"릴리스 노트 방식 바꿔줘"라고 하면, 위 질문을 다시 하고 config의 해당 키를 갱신한다(config-rules.md §4 규칙 준수).
````

- [ ] **Step 3: 삽입 검증 (§5가 §4와 사용자입력 사이에 있나)**

Run:
```bash
grep -n "### 5) 릴리스 브랜치·provider 판정\|## 사용자 입력\|### 4) 앱 심사" skills/pro-changelog-deploy/SKILL.md
```
Expected: §4 < §5 < "## 사용자 입력" 순서.

- [ ] **Step 4: 커밋**

```bash
git add skills/pro-changelog-deploy/SKILL.md
git commit -m "changelog-deploy SKILL 브랜치·provider 판정 절 추가 : docs : config 우선 version.yml 폴백 최초 1회 판정 후 기록"
```

---

## Task 3: 5단계에 provider별 본문 생성 분기표 추가

**Files:**
- Modify: `skills/pro-changelog-deploy/SKILL.md` — 5단계(릴리스 노트 작성) 도입부에 provider 분기표 삽입

**Interfaces:**
- Consumes: Task 2가 확정한 `PROVIDER` 값
- Produces: provider에 따라 5단계 선제 작성 여부·5.5단계 진입 조건 결정

- [ ] **Step 1: 5단계 시작 위치 확인**

Run:
```bash
cd D:/0-suh/project/suh-github-template
grep -n "### 5단계: 릴리스 노트 작성\|### 5.5단계" skills/pro-changelog-deploy/SKILL.md
```
Expected: 5단계·5.5단계 시작 라인 확인.

- [ ] **Step 2: 5단계 도입부(`### 5단계: 릴리스 노트 작성` 바로 다음 `> ⚠️ AGENT 필독` 줄 앞)에 provider 분기표 삽입**

`### 5단계: 릴리스 노트 작성` 제목 줄 바로 다음에 아래를 삽입:

````markdown
#### provider별 본문 생성 분기 (Task 2에서 확정한 `PROVIDER` 사용)

| PROVIDER | 이 단계 행동 | 5.5단계 |
|----------|-------------|---------|
| `coderabbit` | skill이 릴리스 노트를 **선제 작성**(아래 절차) | 정상 진입 |
| `github-ai` / `openai` | `coderabbit`과 동일하게 **선제 작성** | 정상 진입 |
| `commit` | 사용자에게 **한 번 묻는다**: "릴리스 노트를 제가 다듬어 드릴까요, 아니면 커밋 내역 자동 생성에 맡길까요?" → **다듬기** 선택 시 선제 작성, **맡기기** 선택 시 릴리스 노트 파일을 만들지 않고 6단계로(빈 본문 PR — 워크플로우 fallback job이 커밋 분석으로 채움) | 다듬기=진입 / 맡기기=건너뜀 |

> **왜 provider 무관하게 선제 작성이 안전한가**: 워크플로우(RELEASE-CHANGELOG.yaml:191-192)는 "skill이 미리 `Summary by CodeRabbit`을 본문에 넣었으면(`already_found`) provider 무관하게 그대로 존중"한다. 따라서 skill이 선제 작성하면 CodeRabbit 폴링·fallback 없이 그 본문을 바로 파싱한다 → 경합 없음. 유일한 예외가 `commit` "맡기기" — 이때만 skill이 손 떼고 워크플로우에 위임한다.

아래 "릴리스 노트 작성 원칙"은 **선제 작성하는 경우**(coderabbit/github-ai/openai, 또는 commit에서 다듬기 선택)에만 수행한다.
````

- [ ] **Step 3: 5.5단계 A/B 분기에 commit-위임 케이스 반영**

`### 5.5단계: 사용자 승인 게이트` 절에서, 릴리스 노트 파일이 없는 경우(commit 맡기기)를 처리하도록 도입부에 한 줄 추가. `### 5.5단계: 사용자 승인 게이트` 제목 다음 줄(심사 배너 `>` 블록 앞)에 삽입:

```markdown
> **commit provider + "맡기기" 선택 시**: 5단계에서 릴리스 노트 파일을 만들지 않았으므로 이 5.5단계를 **건너뛰고** 바로 6단계로 간다(빈 본문 PR 생성 → 워크플로우 fallback job이 채움). 아래 승인 게이트는 릴리스 노트를 선제 작성한 경우에만 적용된다.
```

- [ ] **Step 4: 6단계 create-pr가 빈 본문(NOTES_FILE 없음) 케이스를 처리하는지 확인**

Run:
```bash
grep -n "NOTES_FILE\|create-pr\|body_file" skills/pro-changelog-deploy/SKILL.md | head
```
Expected: 6단계가 `NOTES_FILE`를 body로 넘김. commit-맡기기 케이스에선 NOTES_FILE이 없으므로, Task 4에서 6단계에 "NOTES_FILE 없으면 빈 본문으로 create-pr" 분기를 함께 처리(Task 4와 연결). 여기서는 표만 추가하고 6단계 수정은 Task 4에서.

- [ ] **Step 5: 커밋**

```bash
git add skills/pro-changelog-deploy/SKILL.md
git commit -m "changelog-deploy 5단계 provider별 본문 생성 분기표 추가 : docs : coderabbit/github-ai/openai 선제작성·commit 위임 선택"
```

---

## Task 4: 6·7단계 브랜치 하드코딩 제거 (D1 해결)

**Files:**
- Modify: `skills/pro-changelog-deploy/SKILL.md` — 3단계 push, 6단계 create-pr, 7단계 deploy-status의 `develop`/`main` 리터럴 → `$HEAD_BRANCH`/`$BASE_BRANCH`

**Interfaces:**
- Consumes: Task 2가 확정한 `HEAD_BRANCH`/`BASE_BRANCH`
- Produces: 브랜치 하드코딩 0. 비표준 브랜치 레포에서도 동작.

- [ ] **Step 1: 하드코딩 위치 전수 확인**

Run:
```bash
cd D:/0-suh/project/suh-github-template
grep -n '"develop"\|"main"\|origin develop\|origin main\|create-pr.*develop\|--base "main"\|--base main' skills/pro-changelog-deploy/SKILL.md
```
Expected: 3단계 push(`git push origin develop`), 6단계 create-pr(`... "develop" "main"`), 7단계 deploy-status(`--base` 미지정 또는 main) 위치 목록.

- [ ] **Step 2: 3단계 push 브랜치 변수화**

3단계 코드블록의:
```bash
git pull --rebase origin develop
git push origin develop
```
을:
```bash
# HEAD_BRANCH는 [시작 전 §5]에서 확정한 값
git pull --rebase origin "$HEAD_BRANCH"
git push origin "$HEAD_BRANCH"
```
로 변경. 블록 맨 앞 변수 prefix 줄에 `HEAD_BRANCH="..."`도 추가(다른 변수와 함께).

- [ ] **Step 3: 6단계 create-pr 브랜치 변수화 + 빈 본문 케이스**

6단계 코드블록에서:
```bash
create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "develop" "main")
```
을:
```bash
create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "$HEAD_BRANCH" "$BASE_BRANCH")
```
로 변경. 그리고 블록 맨 앞 변수 prefix에 `HEAD_BRANCH="..."; BASE_BRANCH="..."` 추가.

또한 commit-맡기기(NOTES_FILE 없음) 케이스 처리를 위해, `NOTES_FILE=...` 정의 다음에 한 줄 추가:
```bash
# commit provider에서 "맡기기" 선택 시 NOTES_FILE이 없다. 없으면 빈 문자열로 넘겨 빈 본문 PR 생성.
[ -f "$NOTES_FILE" ] || NOTES_FILE=""
```
(create-pr의 body_file 인자가 빈 문자열이면 빈 본문으로 생성됨 — 워크플로우가 채움. 스크립트가 빈 경로를 허용하는지는 Step 5에서 확인.)

- [ ] **Step 4: 7단계 deploy-status에 --base 명시**

7단계 코드블록의:
```bash
deploy-status "$OWNER" "$REPO" --pr "$PR_NUMBER"
```
을:
```bash
deploy-status "$OWNER" "$REPO" --pr "$PR_NUMBER" --base "$BASE_BRANCH"
```
로 변경. 블록 변수 prefix에 `BASE_BRANCH="..."` 추가.

- [ ] **Step 5: create-pr가 빈 body_file을 허용하는지 스크립트 확인**

Run:
```bash
grep -n "def cmd_create_pr\|body_file\|body =" skills/pro-changelog-deploy/scripts/changelog_cli.py | head
```
Expected: `cmd_create_pr`가 body_file을 읽는 로직 확인. 빈 문자열/미존재 파일일 때 빈 본문으로 처리하는지 확인. **처리 안 하면**(예: 파일 못 열어 예외) → 빈 경로일 때 `body=""`로 폴백하는 최소 수정을 이 스텝에서 changelog_cli.py에 추가하고, 그 회귀 테스트를 Task 1 파일에 1개 추가.

- [ ] **Step 6: 하드코딩 잔재 재확인**

Run:
```bash
grep -n 'origin develop\|origin main\|"develop" "main"\|--base "main"' skills/pro-changelog-deploy/SKILL.md
```
Expected: 빈 출력(설명 문장 속 예시는 제외 — 실행 코드블록에 리터럴 브랜치 없어야).

- [ ] **Step 7: 커밋**

```bash
git add skills/pro-changelog-deploy/SKILL.md skills/pro-changelog-deploy/scripts/
git commit -m "changelog-deploy 3·6·7단계 브랜치 하드코딩 제거 : refactor : develop/main 리터럴을 HEAD_BRANCH/BASE_BRANCH 변수로"
```

---

## Task 5: config 스키마 확장 + 문서화

**Files:**
- Modify: `skills/config.json.example` — `changelog_deploy`에 3키
- Modify: `skills/references/config-rules.md` — §7 changelog_deploy 스키마

**Interfaces:**
- Consumes: Task 2가 정의한 3키 이름(`head_branch`/`base_branch`/`provider`)
- Produces: config 예시·문서가 3키를 반영. 스킬이 참조하는 스키마 SSOT.

- [ ] **Step 1: config.json.example의 레포별 changelog_deploy에 3키 추가**

`skills/config.json.example`의 두 번째 repo 항목(line 24) `changelog_deploy`:
```json
"changelog_deploy": { "auto_approve": true, "app_release": true }
```
을:
```json
"changelog_deploy": { "auto_approve": true, "app_release": true, "head_branch": "develop", "base_branch": "main", "provider": "coderabbit" }
```
로 변경.

- [ ] **Step 2: JSON 유효성 검증**

Run:
```bash
cd D:/0-suh/project/suh-github-template
PYTHON=$(for _py in python python3; do _p=$(command -v "$_py" 2>/dev/null) || continue; "$_p" -c "import sys;sys.exit(0)" 2>/dev/null && echo "$_p" && break; done)
PYTHONIOENCODING=utf-8 "$PYTHON" -c "import json; json.load(open('skills/config.json.example', encoding='utf-8')); print('JSON OK')"
```
Expected: `JSON OK`.

- [ ] **Step 3: config-rules.md §7 changelog_deploy 스키마 확인·문서화**

Run:
```bash
grep -n "changelog_deploy\|§7\|## 7\|head_branch\|base_branch\|provider" skills/references/config-rules.md | head
```
Expected: changelog_deploy 문서 위치 확인. 해당 절에 3키 설명을 추가한다:

추가할 내용(changelog_deploy 스키마 설명 절 안, auto_approve/app_release 설명 뒤):
```markdown
- `head_branch` (string, 선택): 릴리스 PR의 head(소스) 브랜치. 없으면 version.yml `deploy_branch` → 폴백 `develop`. skill이 최초 판정 시 기록.
- `base_branch` (string, 선택): 릴리스 PR의 base(프로덕션) 브랜치. 없으면 version.yml `default_branch` → 폴백 `main`.
- `provider` (string, 선택): 릴리스 노트 생성 방식(`coderabbit`|`commit`|`github-ai`|`openai`). 없으면 version.yml `options.changelog.provider` → 폴백 `coderabbit`.

> 이 3키는 레포별(`repos[].changelog_deploy`) 우선, 없으면 글로벌(`github.changelog_deploy`), 둘 다 없으면 skill이 version.yml·`.coderabbit.yaml`로 최초 1회 판정 후 기록한다. 사용자는 직접 편집하지 않는다.
```

- [ ] **Step 4: 커밋**

```bash
git add skills/config.json.example skills/references/config-rules.md
git commit -m "config changelog_deploy에 브랜치·provider 3키 추가·문서화 : docs : head_branch/base_branch/provider 스키마"
```

---

## Task 6: 핵심 원칙 명문화 + 전체 회귀

**Files:**
- Modify: `skills/pro-changelog-deploy/SKILL.md` — [핵심 원칙]에 config 미수정 원칙 추가
- Verify: 전체 pytest·npm test

**Interfaces:**
- Consumes: Task 1-5 완료
- Produces: 회귀 green 확정. 원칙 명문화.

- [ ] **Step 1: [핵심 원칙]에 config 미수정 원칙 추가**

`skills/pro-changelog-deploy/SKILL.md`의 `## 핵심 원칙` 목록 마지막 항목 다음에 추가:
```markdown
- **사용자는 config를 직접 수정하지 않는다**. 브랜치·provider·자동모드 등 모든 설정은 skill이 자연어로 묻고 답을 config에 기록한다. 판정 가능하면 묻지 않고, 애매할 때만 묻는다. 한 번 물어 기록하면 재질문하지 않는다.
```

- [ ] **Step 2: pytest 전체**

Run:
```bash
cd D:/0-suh/project/suh-github-template
PYTHON=$(for _py in python python3; do _p=$(command -v "$_py" 2>/dev/null) || continue; "$_p" -c "import sys;sys.exit(0)" 2>/dev/null && echo "$_p" && break; done)
"$PYTHON" -m pytest scripts/tests/ skills/pro-changelog-deploy/scripts/tests/ -q 2>&1 | tail -4
```
Expected: 52+ passed, fail 0.

- [ ] **Step 3: npm test 전체**

Run: `npm test 2>&1 | grep -E "^ℹ (tests|pass|fail)"`
Expected: pass = tests, fail 0.

- [ ] **Step 4: SKILL.md 최종 정합 확인 (하드코딩 0, §5 존재, provider 표 존재)**

Run:
```bash
echo "=== 실행 코드블록 브랜치 하드코딩 (0이어야) ==="
grep -nE 'origin develop|origin main|"develop" "main"' skills/pro-changelog-deploy/SKILL.md
echo "=== §5·provider 분기표 존재 ==="
grep -c "릴리스 브랜치·provider 판정\|provider별 본문 생성 분기" skills/pro-changelog-deploy/SKILL.md
```
Expected: 첫 grep 빈 출력. 둘째 count ≥ 2.

- [ ] **Step 5: 커밋**

```bash
git add skills/pro-changelog-deploy/SKILL.md
git commit -m "changelog-deploy 핵심 원칙에 config 미수정 명문화 : docs : 사용자는 config 직접 수정 안 함 skill이 질문·기록"
```

---

## Self-Review

**Spec coverage:**
- config 스키마 3키(설계 §1) → Task 5 ✓
- 판정 우선순위(설계 §2) → Task 2 §5 ✓
- 최초 판정 로직(설계 §3) → Task 2 ✓
- provider별 5단계 분기(설계 §4) → Task 3 ✓
- 6단계 하드코딩 제거(설계 §5) → Task 4 ✓
- 스크립트 검증·보강(설계 §6-1) → Task 1(테스트)·Task 4 Step 5(빈 body 처리) ✓
- 사용자 상호작용 원칙(설계 §7) → Task 2 §5 + Task 6 ✓
- 검증(설계 §8) → Task 1·6 ✓

**Placeholder scan:** 없음. 모든 삽입 텍스트·명령·기대 출력 명시. (Task 4 Step 5·Task 3 Step 4는 "조건부 수정" — 실제 코드 확인 후 분기이나, 확인 명령과 수정 내용을 명시했으므로 placeholder 아님.)

**Type/naming consistency:** `HEAD_BRANCH`/`BASE_BRANCH`/`PROVIDER`/`BRANCH_CONFIG_HAS_KEY` 변수명 Task 2·3·4 일관. config 키 `head_branch`/`base_branch`/`provider` Task 2·5 일관. `_read_release_branches` 반환 키 `head`/`base`/`provider` Task 1·2 일관.

**주의:** Task 순서는 스크립트·테스트(1) → SKILL 판정(2) → provider 분기(3) → 하드코딩 제거(4) → config 문서(5) → 원칙·회귀(6). Task 3·4는 SKILL.md 같은 파일을 순차 수정하므로 subagent 병렬 실행 시 3→4 순서 보장 필요(같은 파일 = 순차).
