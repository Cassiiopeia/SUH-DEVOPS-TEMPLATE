# Projectops OSS (공모전 제출용 신규 레포) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `npx project-auto-wizard` 한 줄로 9타입+멀티+모노레포 프로젝트에 GitHub-native AI Release Automation(버전·체인지로그·tag·Release)을 설치하는 공모전 제출용 신규 레포를 만든다.

**Architecture:** 신규 레포(**확정: `project-auto-wizard`**, GitHub `Twin-Fang/project-auto-wizard`, 위치 `E:\github\project-auto-wizard`, npm 패키지명 `project-auto-wizard` — 404 확인됨, `npx project-auto-wizard`로 실행)는 3축 — ① npx 마법사(Node, 기존 `src/` 선별 복사 후 개조) ② `payload/`(마법사가 사용자 레포에 심는 워크플로우+Python 스크립트, 단일 진실) ③ Python 자동화 백엔드(`version_manager.py` 신규 재작성 + `changelog_manager.py` 이식·확장). 릴리스 요약은 4단 엔진 체인(CodeRabbit opt-in → AI_API_KEY → GitHub Models → 규칙 fallback)으로 절대 안 막힌다.

**Tech Stack:** Node ≥20 (ESM, `node --test`, 의존성 0) / Python 3 표준 라이브러리만 (`unittest`) / GitHub Actions / gh CLI / GitHub Models (`models.github.ai`)

**Spec:** `E:\github\SUH-DEVOPS-TEMPLATE\docs\superpowers\specs\2026-07-08-projectops-oss-design.md` (승인됨)

**Source repo (복사 원본):** `E:\github\SUH-DEVOPS-TEMPLATE` — 아래에서 `$SRC`로 표기. 신규 레포는 `$DST` = `E:\github\project-auto-wizard`.

---

## 전체 파일 구조 (최종 목표)

```
project-auto-wizard/
├── package.json                  # name: project-auto-wizard(확정), bin: project-auto-wizard, deps 0
├── LICENSE                       # MIT
├── README.md                     # 공모전 심사용 (Task 19)
├── version.yml                   # 자기 자신 버전 (0.1.0 시작)
├── CHANGELOG.md / CHANGELOG.json
├── .gitignore
├── bin/project-auto-wizard.js             # $SRC/bin/project-auto-wizard.js 복사
├── src/                          # $SRC/src 선별 복사 + 개조 (Task 12~17)
│   ├── cli/args.js, help.js
│   ├── commands/interactive.js, full.js, version.js, workflows.js
│   ├── core/ (ide/·wizard-labels.js·copy/coderabbit.js 등 제외)
│   ├── context.js, index.js
│   └── ui/ (skills-prompts.js 제외)
├── payload/                      # 마법사가 심는 자산 — 단일 진실
│   ├── workflows/
│   │   ├── common/
│   │   │   ├── PROJECT-COMMON-VERSION-CONTROL.yaml          # py+placeholder 개조
│   │   │   ├── PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml   # 엔진 체인 재작성
│   │   │   ├── PROJECT-COMMON-RELEASE-PUBLISH.yaml          # 신규
│   │   │   ├── PROJECT-COMMON-README-VERSION-UPDATE.yaml
│   │   │   └── secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml
│   │   ├── spring/ (server-deploy/, nexus/, PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml)
│   │   ├── flutter/ (8개)
│   │   ├── react/ (2개) ├── next/ (2개) └── python/ (3개)
│   ├── scripts/
│   │   ├── version_manager.py    # 신규 (sh 등가 재작성)
│   │   └── changelog_manager.py  # 이식 + ai-summary 추가
│   └── version.yml.template
├── .github/workflows/            # 이 레포 자체용
│   ├── NPM-PUBLISH.yaml
│   └── (도그푸딩: payload common 자기 설치본)
└── tests/
    ├── node/*.test.js            # node --test
    ├── py/test_*.py              # python -m unittest
    └── fixtures/                 # 타입별 가짜 프로젝트 (Task 2~3, 20)
```

**파일 책임 경계:**
- `payload/scripts/*.py` = 사용자 레포에 복사돼 러너에서 단독 실행. 테스트는 `tests/py/`에 (payload에 테스트 안 섞음).
- `src/core/assets.js` = payload 경로 해석의 유일한 창구. 다른 모듈은 payload 물리 경로를 모른다.
- `src/core/branding.js`(신규) = `{{MAIN_BRANCH}}`/`{{DEVELOP_BRANCH}}` 치환 유일 책임.

---

## Phase 0 — 스캐폴드

### Task 1: 신규 레포 초기화

**Files:**
- Create: `$DST/package.json`, `$DST/LICENSE`, `$DST/.gitignore`, `$DST/version.yml`, `$DST/CHANGELOG.json`, `$DST/CHANGELOG.md`

- [ ] **Step 1: 디렉토리 + git init**

```bash
# 레포는 이미 clone돼 있음 (Twin-Fang/project-auto-wizard, main, LICENSE+README 존재) — git init 불필요
cd /e/github/project-auto-wizard
mkdir -p bin src payload/workflows/common payload/scripts tests/node tests/py tests/fixtures .github/workflows
```

- [ ] **Step 2: package.json 작성**

```json
{
  "name": "project-auto-wizard",
  "version": "0.1.0",
  "description": "One command DevOps: npx wizard that installs GitHub-native AI Release Automation into any project",
  "license": "MIT",
  "type": "module",
  "bin": { "project-auto-wizard": "bin/project-auto-wizard.js" },
  "engines": { "node": ">=20.12" },
  "files": ["bin/", "src/", "payload/"],
  "scripts": {
    "test": "npm run test:node && npm run test:py",
    "test:node": "node --test tests/node/",
    "test:py": "python -m unittest discover -s tests/py -v"
  }
}
```

> `files`에 `payload/` 포함 필수 — npm 패키지에 동봉돼야 마법사가 오프라인 복사 가능.
> 패키지명 확정: `project-auto-wizard` (npm 404 확인, 2026-07-08). CLI UI 문자열의 "ProjectOps" 브랜딩도 "Project Auto Wizard"로 rebrand (Task 12에서 일괄).

- [ ] **Step 3: LICENSE(MIT, author Cassiiopeia), .gitignore(node_modules, __pycache__, .DS_Store), version.yml 작성**

`version.yml`은 `$SRC/version.yml`의 주석 헤더 구조를 유지하되 값만 초기화:

```yaml
version: "0.1.0"
version_code: 1
project_type: "node"
project_types: ["node"]
metadata:
  last_updated: "2026-07-08"
  update_reason: "initial scaffold"
```

- [ ] **Step 4: CHANGELOG.json 시드 `{"versions": []}` + CHANGELOG.md 헤더만 작성**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: scaffold project-auto-wizard repo skeleton"
```

---

## Phase 1 — Python 백엔드 (TDD)

> @superpowers:test-driven-development — 이 Phase 전체는 RED→GREEN→COMMIT 사이클. Python은 표준 라이브러리만(`unittest`, `urllib`, `json`, `re`, `argparse`). **PyYAML 금지** — version.yml은 sh 원본처럼 라인 기반 편집으로 주석·포맷 보존.

### Task 2: version_manager.py — version.yml 읽기/쓰기 코어

**Files:**
- Create: `$DST/payload/scripts/version_manager.py`
- Test: `$DST/tests/py/test_version_manager.py`
- Create: `$DST/tests/fixtures/basic/version.yml` (주석 포함 샘플 — `$SRC/version.yml` 축약 복사)

**참조:** `$SRC/.github/scripts/version_manager.sh` (792줄) — 동작 등가 목표. 서브커맨드: `get` / `set X.Y.Z` / `increment` / `sync` / `get-code` / `increment-code`.

- [ ] **Step 1: 실패 테스트 작성** — `tests/py/test_version_manager.py`

```python
import subprocess, sys, shutil, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "payload" / "scripts" / "version_manager.py"
FIXTURES = Path(__file__).resolve().parents[1] / "fixtures"

def run(args, cwd):
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          cwd=cwd, capture_output=True, text=True)

class TestCore(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        shutil.copytree(FIXTURES / "basic", self.tmp, dirs_exist_ok=True)

    def test_get_returns_version(self):
        r = run(["get"], self.tmp)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip().splitlines()[-1], "0.1.0")

    def test_set_updates_version_and_preserves_comments(self):
        run(["set", "2.3.4"], self.tmp)
        text = (Path(self.tmp) / "version.yml").read_text(encoding="utf-8")
        self.assertIn('version: "2.3.4"', text)
        self.assertIn("# ===", text)  # 주석 헤더 보존

    def test_increment_bumps_patch(self):
        run(["increment"], self.tmp)
        r = run(["get"], self.tmp)
        self.assertEqual(r.stdout.strip().splitlines()[-1], "0.1.1")

    def test_get_code_and_increment_code(self):
        self.assertEqual(run(["get-code"], self.tmp).stdout.strip().splitlines()[-1], "1")
        run(["increment-code"], self.tmp)
        self.assertEqual(run(["get-code"], self.tmp).stdout.strip().splitlines()[-1], "2")

    def test_set_rejects_bad_semver(self):
        r = run(["set", "abc"], self.tmp)
        self.assertNotEqual(r.returncode, 0)
```

- [ ] **Step 2: 실행 → 실패 확인**

Run: `python -m unittest tests.py.test_version_manager -v` (cwd `$DST`)
Expected: FAIL/ERROR (스크립트 없음)

- [ ] **Step 3: 최소 구현** — `payload/scripts/version_manager.py`

구현 규칙 (sh 등가):
- `read_key(path, key)` / `write_key(path, key, value)`: 정규식 `^(\s*)key:\s*"?value"?` 라인 교체. 파일 전체 재작성 아님 — 해당 라인만 치환해 주석 보존.
- `get`: `version` 키 출력(따옴표 제거). `set`: semver 검증(`^\d+\.\d+\.\d+$`) 후 교체 + `metadata.last_updated` 갱신. `increment`: patch+1 후 새 버전 출력. `get-code`/`increment-code`: `version_code` 정수.
- stdout 마지막 줄 = 값 (sh와 동일한 소비 계약 — 워크플로우가 `| tail -n 1`으로 읽음).
- 종료코드: 성공 0, 검증 실패/파일 없음 1.

```python
#!/usr/bin/env python3
"""version_manager.py — version.yml 단일 진실 버전 관리 (sh 등가 Python 재작성)."""
import argparse, re, sys
from datetime import date
from pathlib import Path

VERSION_FILE = "version.yml"
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

def _read(path: Path) -> str:
    if not path.exists():
        sys.exit(f"ERROR: {path} not found")
    return path.read_text(encoding="utf-8")

def read_key(text: str, key: str) -> str | None:
    m = re.search(rf'^{re.escape(key)}:\s*"?([^"\n#]*)"?\s*(#.*)?$', text, re.M)
    return m.group(1).strip() if m else None

def write_key(text: str, key: str, value: str, quote=True) -> str:
    val = f'"{value}"' if quote else value
    return re.sub(rf'^({re.escape(key)}:\s*).*$', rf'\g<1>{val}', text, count=1, flags=re.M)
# ... (서브커맨드 dispatch: get/set/increment/sync/get-code/increment-code)
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `python -m unittest tests.py.test_version_manager -v`
Expected: PASS 전체

- [ ] **Step 5: Commit** — `feat(payload): version_manager.py core subcommands (get/set/increment/code)`

### Task 3: version_manager.py — `sync` (9타입 + project_paths 모노레포)

**Files:**
- Modify: `$DST/payload/scripts/version_manager.py`
- Test: `$DST/tests/py/test_version_sync.py`
- Create: `$DST/tests/fixtures/{spring,flutter,react,python,react-native,react-native-expo,monorepo}/…`

**동기화 대상 (sh의 규칙 그대로 이식 — `$SRC/.github/scripts/version_manager.sh`의 sync 부분 참조):**

| 타입 | 파일 | 편집 규칙 |
|---|---|---|
| spring | `build.gradle`(.kts) | `version = 'X.Y.Z'` 라인 치환 |
| flutter | `pubspec.yaml` | `version: X.Y.Z+CODE` (version_code 결합) |
| react/next/node | `package.json` | json 로드→`version` 교체→2-space 재직렬화 |
| python | `pyproject.toml` | `version = "X.Y.Z"` 라인 치환 |
| react-native | `ios/*/Info.plist` + `android/app/build.gradle` | CFBundleShortVersionString / versionName+versionCode |
| react-native-expo | `app.json` | `expo.version` |
| basic | 없음 | version.yml만 |

- [ ] **Step 1: fixture 생성** — 타입별 최소 마커 파일 (예: `fixtures/spring/build.gradle`에 `version = '0.0.1'` 한 줄, `fixtures/monorepo/version.yml`에 `project_types: ["flutter", "react"]` + `project_paths: { flutter: "app", react: "client" }` + `app/pubspec.yaml` + `client/package.json`)

- [ ] **Step 2: 실패 테스트 작성** — `test_version_sync.py`: 타입별 `set 1.2.3` → `sync` → 대상 파일에 1.2.3 반영 assert. 모노레포 케이스: `app/pubspec.yaml`과 `client/package.json` 둘 다 갱신 assert. 대상 파일 없으면 경고만 하고 exit 0 assert (sh 동작 등가).

- [ ] **Step 3: 실행 → 실패 확인** (`sync` 미구현)

- [ ] **Step 4: sync 구현** — `project_types` 배열 파싱(라인 기반: `project_types:` 라인의 `["a", "b"]` 정규식), `project_paths` 맵 파싱(들여쓰긴 블록 스캔), 타입별 sync 함수 dispatch. 각 타입 함수는 위 표의 편집 규칙 단일 책임.

- [ ] **Step 5: 테스트 통과 확인 → Commit** — `feat(payload): version_manager.py sync for 9 types + monorepo project_paths`

### Task 4: version_manager.py — sh 등가성 대조 테스트

**Files:**
- Test: `$DST/tests/py/test_sh_equivalence.py`

- [ ] **Step 1: 등가 테스트 작성** — bash 사용 가능 환경에서만 실행 (`shutil.which("bash")` 없으면 `skipTest`). `$SRC/.github/scripts/version_manager.sh`를 fixture 복사본에 대고 `get/set/increment/sync` 실행, 같은 fixture에 py 실행 → 결과 파일 내용·stdout 마지막 줄 diff 비교. sh 원본 경로는 env `PROJECTOPS_SH_REF`로 주입 (미설정 시 skip — 신규 레포가 원본 레포에 하드 의존하지 않게).

- [ ] **Step 2: 실행** — Windows Git Bash에서 `PROJECTOPS_SH_REF=/e/github/SUH-DEVOPS-TEMPLATE/.github/scripts/version_manager.sh npm run test:py`
Expected: PASS (불일치 발견 시 py를 sh에 맞춰 수정 — sh가 기준)

- [ ] **Step 3: Commit** — `test(payload): sh equivalence harness for version_manager.py`

### Task 5: changelog_manager.py 이식 + 규칙 fallback 3단 파서

**Files:**
- Create: `$DST/payload/scripts/changelog_manager.py` ($SRC 복사 후 수정)
- Test: `$DST/tests/py/test_changelog_fallback.py`

- [ ] **Step 1: `$SRC/.github/scripts/changelog_manager.py` → `$DST/payload/scripts/` 복사, 기존 서브커맨드(update-from-summary/generate-md/export) 그대로. 스모크 테스트 1개(`generate-md`가 시드 CHANGELOG.json으로 md 생성) 작성·통과 확인.**

- [ ] **Step 2: 실패 테스트 작성** — 3단 파서 (순수 함수 `classify_commits(lines) -> dict[str, list[str]]`)

```python
class TestFallbackParser(unittest.TestCase):
    def test_tier1_projectops_convention(self):
        out = classify_commits(["로그인 개선 : feat : 소셜 로그인 추가 https://github.com/o/r/issues/1"])
        self.assertIn("소셜 로그인 추가", out["feat"][0])

    def test_tier2_conventional_commits(self):
        out = classify_commits(["feat(auth): add SSO", "fix: null crash"])
        self.assertEqual(len(out["feat"]), 1)
        self.assertEqual(len(out["fix"]), 1)

    def test_tier3_freeform_goes_to_changes(self):
        out = classify_commits(["update stuff"])
        self.assertEqual(out["changes"], ["update stuff"])

    def test_skip_ci_and_merge_commits_excluded(self):
        out = classify_commits(["chore: bump [skip ci]", "Merge pull request #3"])
        self.assertEqual(sum(len(v) for v in out.values()), 0)
```

- [ ] **Step 3: 실행 → 실패 확인**

- [ ] **Step 4: 구현** — 커밋 한 줄당 1→2→3단 순서 매칭. 산출 dict를 마크다운 섹션(`### ✨ 기능` `### 🐛 수정` `### 🔧 변경사항`)으로 렌더하는 `render_fallback_md(classified) -> str` 추가.

- [ ] **Step 5: 통과 확인 → Commit** — `feat(payload): 3-tier rule fallback parser for changelog`

### Task 6: `ai-summary` 서브커맨드 — 엔진 체인 (AI_API_KEY → GitHub Models → fallback)

**Files:**
- Modify: `$DST/payload/scripts/changelog_manager.py`
- Test: `$DST/tests/py/test_ai_summary.py`

**입력 계약 (MCP-style, 해석은 호출측):**

```
python3 changelog_manager.py ai-summary --commits-file commits.txt --version 1.2.3 --output summary.md [--pr-title "..."]
```

- 커밋 수집은 워크플로우가 `git log --pretty=%s <range>`로 해 파일로 전달 (py는 git 실행 안 함 — 단독 테스트 가능). `--pr-title`(선택)은 릴리스 PR 제목 — AI 프롬프트 컨텍스트에 포함 (스펙 §5 "커밋 목록 + PR 제목"). diff는 토큰 폭발 위험으로 의도적 제외 — 실행 노트에 스코프 컷 기록.
- env: `AI_API_KEY`(2순위), `AI_API_BASE_URL`(기본 `https://models.github.ai/inference`), `AI_MODEL`(기본 `openai/gpt-4o-mini`), `GITHUB_TOKEN`(3순위 GitHub Models 인증).
- 체인: `AI_API_KEY` 있으면 그 키+BASE_URL로 호출 → 없으면 `GITHUB_TOKEN`으로 GitHub Models 호출 → HTTP 오류/타임아웃(30s)/키 전무 시 규칙 fallback. **어떤 경우에도 exit 0 + summary.md 생성.**
- stdout JSON: `{"ok": true, "engine": "user-api"|"github-models"|"fallback", "output": "summary.md"}`

- [ ] **Step 1: 실패 테스트 작성** — `urllib.request.urlopen`을 `unittest.mock.patch`로 대체:
  - 키 있음 + 200 응답 → engine=user-api, 응답 content가 summary.md에 기록
  - 키 없음 + GITHUB_TOKEN 있음 → 요청 URL이 `models.github.ai`, Authorization Bearer 토큰
  - 호출이 `urllib.error.HTTPError(429)` → engine=fallback, fallback md 생성, exit 0
  - env 전무 → engine=fallback
  - OpenAI-호환 요청 body 검증: `model`, `messages[0].role=="user"`

- [ ] **Step 2: 실행 → 실패 확인**

- [ ] **Step 3: 구현** — 단일 `call_openai_compatible(base_url, token, model, prompt)` 함수(urllib, timeout 30). 프롬프트: 커밋 목록 → 한국어 릴리스 요약(섹션: 주요 변경·기능·수정) 지시. 실패는 전부 `except Exception` → fallback (릴리스 절대 안 막힘 원칙).

- [ ] **Step 4: 통과 확인 → Commit** — `feat(payload): ai-summary engine chain (user API → GitHub Models → rule fallback)`

---

## Phase 2 — payload 워크플로우

> 브랜치 자리는 전부 `{{MAIN_BRANCH}}` / `{{DEVELOP_BRANCH}}` 플레이스홀더. `on:` 트리거·`if:` 조건·run 스크립트 내부 문자열 포함 **모든** 하드코딩 develop/main을 치환한다. 봇 커밋은 전부 `[skip ci]`.

### Task 7: VERSION-CONTROL + README-VERSION-UPDATE 이식

**Files:**
- Create: `$DST/payload/workflows/common/PROJECT-COMMON-VERSION-CONTROL.yaml` ($SRC/project-types/common/ 원본 기반)
- Create: `$DST/payload/workflows/common/PROJECT-COMMON-README-VERSION-UPDATE.yaml`
- Test: `$DST/tests/node/payload-yaml.test.js`

- [ ] **Step 1: 실패 테스트 작성** — payload YAML 정적 검증 (node --test):

```javascript
import { test } from "node:test";
import assert from "node:assert";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

// globSync는 Node 22+ 전용 — engines >=20.12 유지 위해 readdirSync recursive 사용
const files = readdirSync("payload/workflows", { recursive: true })
  .filter((f) => /\.ya?ml$/.test(String(f)))
  .map((f) => join("payload/workflows", String(f)));

// Task 7 시점엔 2개뿐 — 최종 개수(>=20)는 Task 10에서 상향
test("payload workflows exist", () => assert.ok(files.length >= 2));

test("no hardcoded branch literals outside placeholders", () => {
  for (const f of files) {
    const body = readFileSync(f, "utf8");
    for (const line of body.split("\n")) {
      if (line.includes("{{MAIN_BRANCH}}") || line.includes("{{DEVELOP_BRANCH}}")) continue;
      // 트리거/조건 라인의 리터럴 develop·main 금지 (placeholder만 허용)
      if (/branches:.*["'\[]\s*(develop|main|master)\b|head\.ref\s*==\s*'(develop|main)'/.test(line))
        assert.fail(`${f}: hardcoded branch → use placeholder: ${line}`);
    }
  }
});

test("no .sh script references in payload", () => {
  for (const f of files) {
    assert.ok(!readFileSync(f, "utf8").includes("version_manager.sh"), f);
  }
});
```

- [ ] **Step 2: 실행 → 실패 확인** (파일 없음)

- [ ] **Step 3: 이식** — `$SRC/.github/workflows/project-types/common/`에서 두 파일 복사 후:
  - `version_manager.sh` 호출 전부 → `python3 .github/scripts/version_manager.py …` (chmod 불필요, `| tail -n 1` 계약 유지)
  - `branches: ["main"]` → `branches: ["{{MAIN_BRANCH}}"]`, develop 참조 → `{{DEVELOP_BRANCH}}`
  - VERSION-CONTROL의 "릴리스 머지 감지" 커밋 메시지 패턴은 유지 (안전망 역할 동일)

- [ ] **Step 4: 테스트 통과 확인 → Commit** — `feat(payload): port VERSION-CONTROL & README-VERSION-UPDATE (py + branch placeholders)`

### Task 8: AUTO-CHANGELOG-CONTROL 재작성 (엔진 체인)

**Files:**
- Create: `$DST/payload/workflows/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`
- Modify: `$DST/tests/node/payload-yaml.test.js` (검증 추가)

**참조:** `$SRC/.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` (763줄) — 뼈대(트리거·버전확정·PR 커밋·automerge)는 유지, CodeRabbit 10분 대기 구조를 엔진 체인으로 교체.

**새 Job 구조:**

```
Job 1 summary   : 요약 확보
  - version.yml에서 coderabbit 옵션 읽기 (python3 one-liner)
  - coderabbit=true → PR body "Summary by CodeRabbit" 폴링 30s×최대 5분 → 있으면 채택
  - 미채택 시: git log {{MAIN_BRANCH}}..HEAD 커밋 수집 → ai-summary 실행 (`--pr-title "${{ github.event.pull_request.title }}"` 전달, 내부에서 2→3→4순위)
Job 2 version   : version_manager.py increment → 버전 확정 커밋 [skip ci]
Job 3 changelog : changelog_manager.py update-from-summary + generate-md → PR 커밋 [skip ci]
Job 4 automerge : gh pr merge --auto --merge
```

**permissions:** `contents: write`, `pull-requests: write`, `models: read`

- [ ] **Step 1: 테스트 추가** — payload-yaml.test.js에: 이 파일이 `models: read` 포함, `ai-summary` 호출 존재, `@coderabbitai summary` 문자열이 coderabbit 조건 블록 안에만 존재, 폴링 timeout이 5분(10회×30s) assert (문자열 검사 수준).

- [ ] **Step 2: 실행 → 실패 확인**

- [ ] **Step 3: 재작성** — 위 Job 구조로 작성. 원본의 보호 로직(head가 `{{DEVELOP_BRANCH}}` 아니면 스킵, PR 본문 초기화 보호, concurrency, workflow_dispatch)은 유지.

- [ ] **Step 4: 통과 확인 → Commit** — `feat(payload): AUTO-CHANGELOG-CONTROL with 4-tier summary engine chain`

### Task 9: RELEASE-PUBLISH 신규 워크플로우

**Files:**
- Create: `$DST/payload/workflows/common/PROJECT-COMMON-RELEASE-PUBLISH.yaml`
- Modify: `$DST/tests/node/payload-yaml.test.js`

**동작 (스펙 §5.5):**

```yaml
name: PROJECT-COMMON-RELEASE-PUBLISH
on:
  push:
    branches: ["{{MAIN_BRANCH}}"]
  workflow_dispatch:
permissions:
  contents: write
  models: read
concurrency:
  group: release-publish-${{ github.ref }}
  cancel-in-progress: false
jobs:
  publish:
    if: "!contains(github.event.head_commit.message, '[skip ci]')"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: 모드·버전 판별
        id: mode
        run: |
          MODE=$(python3 -c "import re;t=open('version.yml',encoding='utf-8').read();m=re.search(r'mode:\s*\"?([\w-]+)',t);print(m.group(1) if m else 'pr-flow')")
          echo "mode=$MODE" >> "$GITHUB_OUTPUT"
          # pr-flow: 릴리스 머지 커밋(버전 확정 커밋 패턴)일 때만 계속, 아니면 스킵
      - name: trunk-based 전처리 (해당 시)
        if: steps.mode.outputs.mode == 'trunk-based'
        run: |
          # increment → 커밋 수집 → ai-summary → CHANGELOG 갱신 → [skip ci] 커밋+push
      - name: 태그 + Release 생성
        run: |
          VERSION=$(python3 .github/scripts/version_manager.py get | tail -n 1)
          git tag "v$VERSION" && git push origin "v$VERSION"
          python3 .github/scripts/changelog_manager.py export --version "$VERSION" --output ai_notes.md
          gh api "repos/${GITHUB_REPOSITORY}/releases/generate-notes" \
            -f tag_name="v$VERSION" --jq '.body' > gh_notes.md || true
          cat ai_notes.md gh_notes.md > notes.md
          gh release create "v$VERSION" --title "v$VERSION" --notes-file notes.md
        env: { GH_TOKEN: "${{ github.token }}" }
```

> `--generate-notes`와 `--notes-file` 동시 사용은 gh 버전별 거동 차이가 있어 **generate-notes API로 받아 파일에 합치는 방식으로 고정** (스펙의 "gh CLI + 자동 노트 조합" 충족, 플래그 조합 리스크 제거).

- [ ] **Step 1: 테스트 추가** — 파일 존재, `gh release create` 포함, trunk-based 분기 존재, `[skip ci]` 가드 존재 assert
- [ ] **Step 2: 실행 → 실패 확인**
- [ ] **Step 3: 작성 (위 골격 완성)** — pr-flow 릴리스 머지 감지는 AUTO-CHANGELOG의 버전 확정 커밋 메시지 패턴 grep. trunk-based 전처리는 Job 내 순차 step (경합 없음).
- [ ] **Step 4: 통과 확인 → Commit** — `feat(payload): RELEASE-PUBLISH workflow (tag + GitHub Release, dual-mode)`

### Task 10: 타입별 워크플로우 + secret-backup 이식

**Files:**
- Create: `$DST/payload/workflows/{spring,flutter,react,next,python}/**` ($SRC/project-types/ 대응 폴더 전체)
- Create: `$DST/payload/workflows/common/secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml`

- [ ] **Step 1: 복사** — `cp -r $SRC/.github/workflows/project-types/{spring,flutter,react,next,python}/* $DST/payload/workflows/<type>/` + secret-backup. **제외 확인:** QA-ISSUE-CREATION-BOT, SUH-ISSUE-HELPER-*, SYNC-ISSUE-LABELS, PROJECTS-SYNC-MANAGER, TEMPLATE-UTIL-VERSION-SYNC은 복사 금지 (스펙 §2 제외 목록).

  > 참고: `node`/`react-native`/`react-native-expo`/`basic` 4타입은 `$SRC`에 타입 전용 워크플로우가 없다 (common만 설치). 폴더 없음이 정상 — 찾아 헤매지 말 것.
- [ ] **Step 2: 일괄 치환** — 각 파일에서 `develop`/`main` 브랜치 리터럴 → 플레이스홀더, `version_manager.sh` → `version_manager.py` 호출. `grep -rn "version_manager.sh" payload/` 결과 0 확인.
- [ ] **Step 3: 테스트 상향 + 실행** — payload-yaml.test.js의 개수 assert를 `files.length >= 20`으로 상향 (Task 7 시점 임시값 2 교체). 전체 파일 대상 하드코딩 브랜치·sh 잔존 검출. Expected: PASS
- [ ] **Step 4: Commit** — `feat(payload): port type workflows (spring/flutter/react/next/python) + secret-backup`

### Task 11: version.yml.template

**Files:**
- Create: `$DST/payload/version.yml.template`

- [ ] **Step 1: 작성** — `$SRC/version.yml` 주석 헤더 유지 + 플레이스홀더 (`{{VERSION}}`, `{{PROJECT_TYPES}}`, `{{PROJECT_PATHS}}`) + 신규 metadata 블록:

```yaml
metadata:
  template:
    branches:
      main: "{{MAIN_BRANCH}}"
      develop: "{{DEVELOP_BRANCH}}"
      mode: "{{BRANCH_MODE}}"        # pr-flow | trunk-based
    options:
      nexus: {{OPT_NEXUS}}
      secret_backup: {{OPT_SECRET_BACKUP}}
      coderabbit: {{OPT_CODERABBIT}}
```

- [ ] **Step 2: Commit** — `feat(payload): version.yml.template with branches/options metadata`

---

## Phase 3 — npx 마법사

> 원본 `$SRC/src`(2,828줄)를 선별 복사 후 개조. Node 테스트는 `node --test`, 대화형 로직은 순수 함수로 분리해 유닛 테스트 (readline 자체는 원본에서 검증됨 — 재검증 안 함).

### Task 12: src 선별 복사 + 프루닝 + payload 경로 전환

**Files:**
- Create: `$DST/bin/project-auto-wizard.js`, `$DST/src/**` (선별)
- Modify: `$DST/src/core/assets.js`
- Test: `$DST/tests/node/assets.test.js`

**복사 제외 목록 (스펙 §2 제외 기능의 코드):**
- `src/commands/skills.js`, `src/commands/issues.js` (Skills·이슈템플릿 기능)
- `src/core/ide/**` (IDE 어댑터), `src/core/wizard-labels.js` (라벨), `src/ui/skills-prompts.js`
- `src/core/copy/coderabbit.js` — .coderabbit.yaml 복사 기능은 **유지 검토**: coderabbit opt-in true일 때만 복사하도록 Task 15에서 재배선. 일단 복사해 두고 Task 15에서 조건 연결.

- [ ] **Step 1: 복사 실행** — 위 제외 빼고 `bin/`, `src/` 복사. `src/index.js`·`src/cli/args.js`·`src/cli/help.js`에서 제외 기능 참조(import·서브커맨드·도움말) 제거.
- [ ] **Step 2: 실패 테스트 작성** — `assets.test.js`: `resolvePayloadRoot()`가 패키지 루트의 `payload/`를 가리킴, `listCommonWorkflows()`가 RELEASE-PUBLISH 포함 4개+secret-backup 반환, 제거된 모듈 import 잔존 없음(전 src 파일 대상 `grep`식 문자열 검사로 `wizard-labels`/`ide/`/`skills` 참조 0 assert).
- [ ] **Step 3: assets.js 개조** — ⚠️ 원본 `$SRC/src/core/assets.js`는 로컬 경로 해석이 아니라 **런타임에 `TEMPLATE_REPO`를 tempDir로 git clone**(`acquireTemplate`)하고 하위 copy 모듈들이 그 tempDir을 소비하는 구조다. 다음 3가지를 명시적으로 수행:
  1. git clone/`TEMPLATE_REPO`/tempDir 획득 로직 **전부 삭제** — 네트워크 접근 0.
  2. payload 루트는 `import.meta.url` 기준으로 해석 (`new URL("../../payload/", import.meta.url)`) — npx 글로벌 캐시에서 실행돼도 패키지 내 payload를 정확히 가리킴. 이것이 `resolvePayloadRoot()`.
  3. `src/core/copy/*.js`의 소스 인자를 tempDir → payload 경로로 재배선. **`payload/scripts/*.py` → 사용자 레포 `.github/scripts/` 복사 배선 포함** (워크플로우가 전부 이 경로를 호출 — 누락 시 설치물 전체가 런타임 사망).
  exclusions.js의 "템플릿 전용 파일 제외 목록"은 payload 방식에선 불필요 → 삭제하고 참조 제거.
- [ ] **Step 4: 스모크 확인** — `node bin/project-auto-wizard.js --help` 정상 출력 + `npm run test:node` PASS
- [ ] **Step 5: Commit** — `feat(cli): selective port of wizard with payload as single source`

### Task 13: 브랜치 질문 + 플래그 + 자동 생성·push

**Files:**
- Create: `$DST/src/core/branches.js`
- Modify: `$DST/src/cli/args.js`, `$DST/src/commands/interactive.js`, `$DST/src/commands/full.js`
- Test: `$DST/tests/node/branches.test.js`

**branches.js 공개 인터페이스:**

```javascript
// 감지: 로컬 git에서 default branch + 원격 브랜치 목록
export async function detectBranches(cwd) // -> { defaultBranch, remoteBranches: string[] }
// 결정: 플래그/답변 → 최종 구성 (순수 함수)
export function resolveBranchConfig({ mainBranch, developBranch, defaultBranch })
// -> { main, develop, mode: main === develop ? "trunk-based" : "pr-flow" }
// 생성: develop이 remoteBranches에 없으면 생성+push (force=true면 무질문)
export async function ensureDevelopBranch({ develop, remoteBranches, confirm, cwd })
```

- [ ] **Step 1: 실패 테스트 작성** — `resolveBranchConfig` 순수 함수: 기본값(develop/감지 default), 동일 브랜치→trunk-based, 플래그 우선. `ensureDevelopBranch`: git 명령을 주입 가능한 `exec` 파라미터로 받아 mock — 브랜치 존재 시 no-op, 부재+confirm true 시 `git branch develop` + `git push -u origin develop` 호출 순서 assert.
- [ ] **Step 2: 실행 → 실패 확인**
- [ ] **Step 3: 구현 + args.js에 `--main-branch`/`--develop-branch` 추가 + interactive.js에 질문 2개(기본값 제시·원격 목록 선택) + full.js(--force)는 무질문 자동 생성 경로.**
- [ ] **Step 4: 통과 확인 → Commit** — `feat(cli): branch config questions, flags, auto-create+push`

### Task 14: 플레이스홀더 치환 파이프라인 + version.yml 기록

**Files:**
- Create: `$DST/src/core/branding.js`
- Modify: `$DST/src/core/copy/workflows.js`, `$DST/src/core/version-yml.js`
- Test: `$DST/tests/node/branding.test.js`

- [ ] **Step 1: 실패 테스트 작성** —

```javascript
import { substitute } from "../../src/core/branding.js";

test("substitutes all branch placeholders", () => {
  const out = substitute('branches: ["{{MAIN_BRANCH}}"]\nref == \'{{DEVELOP_BRANCH}}\'',
                         { main: "master", develop: "dev" });
  assert.ok(!out.includes("{{"));
  assert.ok(out.includes('"master"') && out.includes("'dev'"));
});

test("throws on unknown placeholder left behind", () => {
  assert.throws(() => substitute("x {{TYPO_BRANCH}}", { main: "m", develop: "d" }));
});
```

- [ ] **Step 2: 실행 → 실패 확인**
- [ ] **Step 3: 구현** — `substitute(text, cfg)`: 치환 후 `{{…}}` 잔존 시 throw (복사 무결성 가드). workflows.js 복사 경로에 주입. version-yml.js: 업데이트 모드에서 `metadata.template.branches` 읽어 재질문 없이 동일 치환 (스펙 §4).
- [ ] **Step 4: 통과 확인 → Commit** — `feat(cli): branch placeholder substitution + branches metadata persistence`

### Task 15: CodeRabbit opt-in

**Files:**
- Modify: `$DST/src/cli/args.js` (`--coderabbit`), `$DST/src/commands/interactive.js` (질문, 기본 아니오), `$DST/src/core/copy/coderabbit.js` (opt-in 시만 .coderabbit.yaml 복사), `$DST/src/core/version-yml.js` (`options.coderabbit` 기록)
- Test: `$DST/tests/node/coderabbit-optin.test.js`

- [ ] **Step 1: 실패 테스트 작성** — opt-in false(기본): .coderabbit.yaml 미복사 + version.yml `coderabbit: false`. true: 복사 + true 기록. (fs 조작은 tmp dir fixture)
- [ ] **Step 2: 실행 → 실패 확인 → 구현 → 통과 확인**
- [ ] **Step 3: Commit** — `feat(cli): CodeRabbit opt-in (default false)`

### Task 16: 브랜치 모드별 워크플로우 설치 구성

**Files:**
- Modify: `$DST/src/core/copy/workflows.js`
- Test: `$DST/tests/node/install-matrix.test.js`

**설치 매트릭스 (스펙 §4 브랜치 모드):**

| 모드 | VERSION-CONTROL | AUTO-CHANGELOG | RELEASE-PUBLISH |
|---|---|---|---|
| pr-flow | ✅ | ✅ | ✅ |
| trunk-based | ❌ | ❌ | ✅ |

기존 opt-in 매트릭스 유지: nexus=true → `spring/server-deploy/` 폴더째 제외 + `spring/nexus/` 포함. secret_backup=true → `common/secret-backup/` 포함.

- [ ] **Step 1: 실패 테스트 작성** — tmp fixture에 모드별 설치 실행 → 설치된 파일 목록이 매트릭스와 일치 assert (trunk-based에 AUTO-CHANGELOG 없음 등). nexus/secret-backup 조합 케이스 포함.
- [ ] **Step 2: 실행 → 실패 확인 → 구현 → 통과 확인**
- [ ] **Step 3: Commit** — `feat(cli): mode-aware workflow install matrix (pr-flow / trunk-based)`

### Task 17: 완료 요약 UI + help 정리

**Files:**
- Modify: `$DST/src/ui/summary.js`, `$DST/src/cli/help.js`

- [ ] **Step 1: summary.js에 브랜치 모드·설치 워크플로우 목록·요약 엔진(coderabbit/GitHub Models) 안내 라인 추가. help.js에 신규 플래그 3종 문서화. 제거된 기능(skills 등) 언급 잔존 0 확인 (`grep -rn "suh-\|skills" src/ | wc -l` → 0).**
- [ ] **Step 2: `node bin/project-auto-wizard.js --help` 육안 확인 + `npm test` 전체 PASS → Commit** — `feat(cli): completion summary with mode/engine info`

---

## Phase 4 — 자체 CI·README·E2E

### Task 18: 자체 레포 워크플로우 (npm publish + 도그푸딩)

**Files:**
- Create: `$DST/.github/workflows/NPM-PUBLISH.yaml`
- Create: `$DST/.github/workflows/RELEASE-PUBLISH.yaml` 등 (자기 자신에 payload 설치)
- Create: `$DST/.github/scripts/` (payload 스크립트 자기 설치본)

- [ ] **Step 1: 도그푸딩 설치** — `node bin/project-auto-wizard.js --force --type node --main-branch main --develop-branch develop` 을 `$DST` 자신에 실행 → payload가 자기 레포에 설치되는 것 자체가 E2E 1차 검증. 설치 결과 커밋.
- [ ] **Step 2: NPM-PUBLISH.yaml 작성** — main push(릴리스 머지) 시 `npm publish` (`NPM_TOKEN` secret, `[skip ci]` 가드, version.yml 버전과 package.json 동기 확인 step). `$SRC`의 npm 배포 워크플로우 참조.
- [ ] **Step 3: Commit** — `chore: dogfood payload install + npm publish workflow`

### Task 19: README (공모전 심사용)

**Files:**
- Create: `$DST/README.md`

- [ ] **Step 1: 스펙 §6 구성대로 작성** — 히어로(`npx project-auto-wizard` + GIF 자리표시) / 문제 정의 훅 / 3축 / 어필 포인트 6종 표 / 아키텍처 mermaid + 엔진 체인 다이어그램 / 배지. 데모 GIF·유튜브 링크는 자리표시자(TODO 마커).
- [ ] **Step 2: Commit** — `docs: competition README`

### Task 20: E2E fixture 매트릭스 검증

**Files:**
- Test: `$DST/tests/node/e2e-matrix.test.js`
- Create: `$DST/tests/fixtures/e2e/{spring,flutter,react,next,node,python,react-native,react-native-expo,basic,multi,monorepo}/…` (마커 파일만 있는 최소 fixture)

- [ ] **Step 1: 실패 테스트 작성** — fixture별로 tmp 복사 → `node bin/project-auto-wizard.js --force …` subprocess 실행 → assert:
  - 종료코드 0
  - 타입별 워크플로우 배치 정확 (spring이면 server-deploy 포함, --nexus면 제외)
  - **`.github/scripts/version_manager.py`·`changelog_manager.py` 설치됨** (워크플로우 전부가 이 경로 호출 — 배선 누락 검출)
  - `version.yml` 생성 + branches/options metadata 기록
  - 설치된 YAML 전체에 `{{` 잔존 0 (치환 무결성)
  - trunk-based 케이스(`--main-branch main --develop-branch main`): RELEASE-PUBLISH만 설치
  - **되돌리기 모드**: 설치 → revert 실행 → payload 유래 파일(워크플로우·스크립트) 제거 확인 (원본 revert 동작 등가)
- [ ] **Step 2: 실행 → 실패 확인 → 구현 수정 반복 → 전체 PASS**

Run: `npm test`
Expected: node + py 전체 PASS

- [ ] **Step 3: Commit** — `test: E2E install matrix across 11 fixtures`

- [ ] **Step 4: 수동 실기 검증 (커밋 없음, 체크만)** — 실제 GitHub 테스트 레포 1개에 마법사 실행 → develop 커밋 → develop→main PR → AI changelog·automerge·tag·Release 실측. GitHub Models 호출은 로컬 재현 불가 — 이 단계가 유일한 실측 지점. 실패 시 워크플로우 수정 후 재실행.
- [ ] **Step 5: fallback 실기 검증 (스펙 §7)** — 같은 테스트 레포에서 워크플로우의 `models: read` 권한 제거 커밋 후 릴리스 1회 재실행 → 규칙 fallback 경로로 changelog·Release 완주 확인. 확인 후 권한 복원.

---

## 실행 노트

- **커밋 규칙**: 신규 레포는 Conventional Commits (`feat:`/`fix:`/`chore:` — 스펙 §5 fallback 2단과 자기 정합). 원본 레포의 이모지 금지 규칙 동일 적용.
- **원본 레포는 읽기 전용** — `$SRC` 어떤 파일도 수정하지 않는다.
- **Windows 주의**: 테스트는 `python` (py launcher), CI는 `python3`. subprocess는 `sys.executable` 사용으로 양쪽 무관.
- **미결정 잔여** (스펙 §8): npm 패키지명·GitHub Models 기본 모델(`openai/gpt-4o-mini`로 가정, Task 6 env로 교체 가능)·라이선스(MIT 가정) — 게시 직전 확정, 코드 영향 없음.
- **의도적 스코프 컷**: AI 프롬프트 입력은 커밋 목록 + PR 제목까지 — **diff 본문은 제외** (토큰 폭발·rate limit 리스크 대비 이득 없음. 스펙 §5 "PR 제목/diff" 중 diff는 컷).
