# Sub-project #3: Config System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** skill별 config를 프로젝트 로컬/글로벌 두 단계로 탐색하고 저장하는 인프라를 구축하고, `issue`와 `synology-expose` SKILL.md에 적용한다.

**Architecture:** `config.py`에 글로벌 fallback(`~/.suh-template/config/`)·`save()`·`ensure_gitignore()` 추가, `cli.py`에 `init-config` 커맨드 추가. `.suh-template.example/` 템플릿 파일 생성. `issue`·`synology-expose` SKILL.md를 새 config 시스템으로 교체.

**Tech Stack:** Python 3.8+, 표준 라이브러리만, Markdown 편집

---

## 파일 구조

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `scripts/suh_template/config.py` | Modify | 글로벌 fallback, `save()`, `ensure_gitignore()` 추가 |
| `scripts/suh_template/cli.py` | Modify | `init-config` 커맨드 추가 |
| `scripts/tests/test_config.py` | Modify | 새 함수 테스트 추가 |
| `scripts/tests/test_cli.py` | Modify | `init-config` CLI 테스트 추가 |
| `.suh-template.example/config/issue.config.example.json` | Create | issue config 템플릿 |
| `.suh-template.example/config/synology-expose.config.example.json` | Create | synology-expose config 템플릿 |
| `skills/issue/SKILL.md` | Modify | config 확인 로직 추가 |
| `skills/synology-expose/SKILL.md` | Modify | 기존 config 로직 교체 |
| `.cursor/skills/issue/SKILL.md` | Sync | skills/와 동일 |
| `.cursor/skills/synology-expose/SKILL.md` | Sync | skills/와 동일 |

---

## Task 1: `config.py` — 글로벌 fallback + `save()` + `ensure_gitignore()`

**Files:**
- Modify: `scripts/suh_template/config.py`
- Modify: `scripts/tests/test_config.py`

- [ ] **Step 1: 글로벌 fallback 테스트 작성**

`scripts/tests/test_config.py`에 추가:

```python
def test_load_global_fallback(tmp_path, monkeypatch):
    """로컬 config 없을 때 글로벌 fallback을 사용한다."""
    home = tmp_path / "home"
    global_dir = home / ".suh-template" / "config"
    global_dir.mkdir(parents=True)
    (global_dir / "issue.config.json").write_text(
        json.dumps({"github_pat": "ghp_global"})
    )
    monkeypatch.setenv("HOME", str(home))
    # Path.home()이 monkeypatch HOME을 반영하도록 Path를 재임포트
    import importlib, suh_template.config as cfg
    importlib.reload(cfg)
    result = cfg.load(tmp_path, "issue")  # tmp_path에는 로컬 config 없음
    assert result == {"github_pat": "ghp_global"}
    importlib.reload(cfg)  # 원복


def test_load_local_overrides_global(tmp_path, monkeypatch):
    """로컬 config가 글로벌보다 우선한다."""
    home = tmp_path / "home"
    global_dir = home / ".suh-template" / "config"
    global_dir.mkdir(parents=True)
    (global_dir / "issue.config.json").write_text(
        json.dumps({"github_pat": "ghp_global"})
    )
    local_dir = tmp_path / ".suh-template" / "config"
    local_dir.mkdir(parents=True)
    (local_dir / "issue.config.json").write_text(
        json.dumps({"github_pat": "ghp_local"})
    )
    monkeypatch.setenv("HOME", str(home))
    import importlib, suh_template.config as cfg
    importlib.reload(cfg)
    result = cfg.load(tmp_path, "issue")
    assert result == {"github_pat": "ghp_local"}
    importlib.reload(cfg)


def test_save_local(tmp_path):
    """save(scope='local')는 프로젝트 로컬에 저장하고 경로를 반환한다."""
    from suh_template.config import save
    data = {"github_pat": "ghp_test", "github_repos": []}
    path = save(tmp_path, "issue", data, scope="local")
    assert path == tmp_path / ".suh-template" / "config" / "issue.config.json"
    assert json.loads(path.read_text(encoding="utf-8")) == data


def test_save_global(tmp_path, monkeypatch):
    """save(scope='global')는 ~/.suh-template/config/ 에 저장한다."""
    from suh_template.config import save
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("HOME", str(home))
    import importlib, suh_template.config as cfg
    importlib.reload(cfg)
    data = {"github_pat": "ghp_global"}
    path = cfg.save(tmp_path, "issue", data, scope="global")
    assert path == home / ".suh-template" / "config" / "issue.config.json"
    assert json.loads(path.read_text(encoding="utf-8")) == data
    importlib.reload(cfg)


def test_ensure_gitignore_creates_entry(tmp_path):
    """ensure_gitignore는 .gitignore에 .suh-template/config/ 항목을 추가한다."""
    from suh_template.config import ensure_gitignore
    ensure_gitignore(tmp_path)
    gitignore = tmp_path / ".gitignore"
    assert gitignore.exists()
    assert ".suh-template/config/" in gitignore.read_text(encoding="utf-8")


def test_ensure_gitignore_no_duplicate(tmp_path):
    """ensure_gitignore는 이미 항목이 있으면 중복 추가하지 않는다."""
    from suh_template.config import ensure_gitignore
    gitignore = tmp_path / ".gitignore"
    gitignore.write_text(".suh-template/config/\n", encoding="utf-8")
    ensure_gitignore(tmp_path)
    content = gitignore.read_text(encoding="utf-8")
    assert content.count(".suh-template/config/") == 1


def test_save_local_registers_gitignore(tmp_path):
    """save(scope='local')는 .gitignore에 자동으로 항목을 등록한다."""
    from suh_template.config import save
    save(tmp_path, "issue", {"github_pat": "ghp_test"}, scope="local")
    gitignore = tmp_path / ".gitignore"
    assert gitignore.exists()
    assert ".suh-template/config/" in gitignore.read_text(encoding="utf-8")
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
python3 -m pytest tests/test_config.py -v 2>&1 | tail -20
```

Expected: 새로 추가한 테스트들이 `FAILED` (함수 없음)

- [ ] **Step 3: `config.py` 전체를 새 구현으로 교체**

`scripts/suh_template/config.py`를 아래 내용으로 교체:

```python
"""skill별 사용자 config를 .suh-template/config/ 에서 로딩한다."""

import json
from pathlib import Path
from typing import Any, Optional

_GITIGNORE_ENTRY = ".suh-template/config/"


def _local_config_path(project_root: Path, skill_id: str) -> Path:
    return project_root / ".suh-template" / "config" / f"{skill_id}.config.json"


def _global_config_path(skill_id: str) -> Path:
    return Path.home() / ".suh-template" / "config" / f"{skill_id}.config.json"


def load(project_root: Any, skill_id: str) -> Optional[dict]:
    """
    config를 두 단계로 탐색한다:
    1. {project_root}/.suh-template/config/{skill_id}.config.json
    2. ~/.suh-template/config/{skill_id}.config.json
    둘 다 없으면 None을 반환한다.
    """
    local = _local_config_path(Path(project_root), skill_id)
    if local.exists():
        return json.loads(local.read_text(encoding="utf-8"))
    global_ = _global_config_path(skill_id)
    if global_.exists():
        return json.loads(global_.read_text(encoding="utf-8"))
    return None


def get_value(project_root: Any, skill_id: str, key: str) -> Optional[str]:
    """config에서 특정 키의 값을 반환한다. config 없거나 키 없으면 None."""
    data = load(project_root, skill_id)
    if data is None:
        return None
    return data.get(key)


def save(project_root: Any, skill_id: str, data: dict, scope: str = "local") -> Path:
    """
    config를 저장하고 저장된 경로를 반환한다.
    scope='local': {project_root}/.suh-template/config/ — .gitignore 자동 등록
    scope='global': ~/.suh-template/config/
    """
    if scope == "global":
        path = _global_config_path(skill_id)
    else:
        path = _local_config_path(Path(project_root), skill_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    if scope == "local":
        ensure_gitignore(Path(project_root))
    return path


def ensure_gitignore(project_root: Any) -> None:
    """{project_root}/.gitignore에 .suh-template/config/ 항목이 없으면 추가한다."""
    gitignore = Path(project_root) / ".gitignore"
    if gitignore.exists():
        content = gitignore.read_text(encoding="utf-8")
        if _GITIGNORE_ENTRY in content:
            return
        # 파일 끝에 개행이 없으면 추가
        if content and not content.endswith("\n"):
            content += "\n"
        content += f"{_GITIGNORE_ENTRY}\n"
        gitignore.write_text(content, encoding="utf-8")
    else:
        gitignore.write_text(f"{_GITIGNORE_ENTRY}\n", encoding="utf-8")
```

- [ ] **Step 4: 테스트 실행 및 확인**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
python3 -m pytest tests/test_config.py -v 2>&1 | tail -25
```

Expected: 모든 테스트 PASSED

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/config.py scripts/tests/test_config.py
git commit -m "feat: config 글로벌 fallback, save(), ensure_gitignore() 추가"
```

---

## Task 2: `cli.py` — `init-config` 커맨드 추가

**Files:**
- Modify: `scripts/suh_template/cli.py`
- Modify: `scripts/tests/test_cli.py`

`init-config` 커맨드는 `.suh-template.example/config/{skill_id}.config.example.json` 파일 경로를 stdout에 출력한다. AI(skill)가 이 경로를 읽어 스키마를 파악하고 대화형 수집 후 `config.save()`를 직접 호출한다.

- [ ] **Step 1: `init-config` CLI 테스트 작성**

`scripts/tests/test_cli.py` 파일을 열어 기존 `run_cli` 헬퍼를 확인한 뒤, 아래 테스트를 추가:

```python
def test_init_config_returns_example_path(tmp_path):
    """init-config는 .example 파일 경로를 stdout에 출력한다."""
    # .example 파일 생성
    example_dir = tmp_path / ".suh-template.example" / "config"
    example_dir.mkdir(parents=True)
    (example_dir / "issue.config.example.json").write_text(
        json.dumps({"github_pat": "", "github_repos": []}), encoding="utf-8"
    )
    result = run_cli(["init-config", "issue"], cwd=tmp_path)
    assert result.returncode == 0
    expected = str(tmp_path / ".suh-template.example" / "config" / "issue.config.example.json")
    assert result.stdout.strip() == expected


def test_init_config_missing_example_file(tmp_path):
    """init-config는 .example 파일이 없으면 ERROR + exit 1."""
    result = run_cli(["init-config", "issue"], cwd=tmp_path)
    assert result.returncode == 1
    assert "example_not_found" in result.stderr


def test_init_config_invalid_skill_id(tmp_path):
    """init-config는 잘못된 skill_id이면 ERROR + exit 1."""
    result = run_cli(["init-config", "nonexistent"], cwd=tmp_path)
    assert result.returncode == 1
    assert "skill_id_invalid" in result.stderr
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
python3 -m pytest tests/test_cli.py -k "init_config" -v 2>&1 | tail -15
```

Expected: FAILED (커맨드 없음)

- [ ] **Step 3: `cli.py`에 `cmd_init_config` 구현 추가**

`cli.py`의 `cmd_config_get` 함수 다음에 아래 함수를 추가:

```python
def cmd_init_config(args: list) -> int:
    """init-config <skill_id>
    
    .suh-template.example/config/{skill_id}.config.example.json 경로를 stdout에 출력한다.
    AI(skill)가 이 파일을 읽어 스키마를 파악하고 대화형 수집 후 config.save()를 호출한다.
    """
    if not args:
        _err("ERROR", "init-config", "skill_id 인수가 필요합니다.", "missing_argument")
        return 1

    skill_id = args[0]
    if skill_id not in SUPPORTED_SKILL_IDS:
        _err("ERROR", "init-config",
             f"지원하지 않는 skill_id입니다. 지원: {', '.join(SUPPORTED_SKILL_IDS)}",
             "skill_id_invalid")
        return 1

    project_root = _get_project_root()
    if project_root is None:
        _err("ERROR", "init-config", "git 저장소가 아닙니다.", "git_not_found")
        return 1

    example_path = project_root / ".suh-template.example" / "config" / f"{skill_id}.config.example.json"
    if not example_path.exists():
        _err("ERROR", "init-config",
             f".suh-template.example/config/{skill_id}.config.example.json 파일이 없습니다.",
             "example_not_found")
        return 1

    print(str(example_path))
    return 0
```

그리고 `_COMMANDS` 딕셔너리에 항목 추가:

```python
_COMMANDS = {
    "get-output-path": cmd_get_output_path,
    "get-issue-number": cmd_get_issue_number,
    "get-next-seq": cmd_get_next_seq,
    "normalize-title": cmd_normalize_title,
    "config-get": cmd_config_get,
    "init-config": cmd_init_config,
}
```

또한 파일 상단 docstring의 커맨드 목록에도 추가:

```python
"""
suh_template CLI 진입점.

사용법:
    python3 -m suh_template.cli <command> [args]

커맨드:
    get-output-path <skill_id> [--title <제목>]
    get-issue-number
    get-next-seq <skill_id>
    normalize-title <제목>
    config-get <skill_id> <key>
    init-config <skill_id>
"""
```

- [ ] **Step 4: 테스트 실행 및 확인**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
python3 -m pytest tests/test_cli.py -k "init_config" -v 2>&1 | tail -15
```

Expected: 3개 테스트 모두 PASSED

- [ ] **Step 5: 전체 테스트 회귀 확인**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
python3 -m pytest tests/ -v 2>&1 | tail -15
```

Expected: 모든 기존 테스트 PASSED

- [ ] **Step 6: 커밋**

```bash
git add scripts/suh_template/cli.py scripts/tests/test_cli.py
git commit -m "feat: cli init-config 커맨드 추가"
```

---

## Task 3: `.example` 템플릿 파일 생성

**Files:**
- Create: `.suh-template.example/config/issue.config.example.json`
- Create: `.suh-template.example/config/synology-expose.config.example.json`

- [ ] **Step 1: 디렉토리 생성 및 `issue.config.example.json` 작성**

```bash
mkdir -p /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/.suh-template.example/config
```

`.suh-template.example/config/issue.config.example.json`:

```json
{
  "_comment": "이 파일을 .suh-template/config/issue.config.json으로 복사하고 값을 채우세요. .suh-template/config/는 .gitignore에 의해 보호됩니다.",
  "github_pat": "ghp_여기에_PAT_토큰_입력",
  "github_repos": [
    {
      "name": "프로젝트 이름",
      "owner": "GitHub_사용자명_또는_조직명",
      "repo": "저장소명",
      "default": true
    }
  ]
}
```

- [ ] **Step 2: `synology-expose.config.example.json` 작성**

`.suh-template.example/config/synology-expose.config.example.json`:

```json
{
  "_comment": "이 파일을 .suh-template/config/synology-expose.config.json으로 복사하고 값을 채우세요.",
  "instances": [
    {
      "name": "NAS 이름 (예: 집 NAS)",
      "ddns": "your-nas.synology.me",
      "domains": ["example.com"],
      "email": "your@email.com",
      "dns_provider": "cloudflare",
      "default": true
    }
  ]
}
```

- [ ] **Step 3: JSON 유효성 확인**

```bash
python3 -c "
import json
for f in ['.suh-template.example/config/issue.config.example.json',
          '.suh-template.example/config/synology-expose.config.example.json']:
    json.loads(open(f).read())
    print(f'{f}: OK')
" 
```

Expected:
```
.suh-template.example/config/issue.config.example.json: OK
.suh-template.example/config/synology-expose.config.example.json: OK
```

- [ ] **Step 4: 커밋**

```bash
git add .suh-template.example/
git commit -m "feat: issue/synology-expose config.example 템플릿 파일 추가"
```

---

## Task 4: `issue/SKILL.md` — config 확인 로직 추가

**Files:**
- Modify: `skills/issue/SKILL.md`
- Sync: `.cursor/skills/issue/SKILL.md`

- [ ] **Step 1: 현재 파일 읽기**

```bash
head -20 skills/issue/SKILL.md
```

현재 "시작 전" 섹션 위치와 내용을 파악한다.

- [ ] **Step 2: "시작 전" 섹션 교체**

현재 내용:
```markdown
## 시작 전

`references/common-rules.md`의 **절대 규칙** 적용 (Git 커밋 금지, 민감 정보 보호)
```

아래 내용으로 교체:
```markdown
## 시작 전

1. `references/common-rules.md`의 **절대 규칙** 적용 (Git 커밋 금지, 민감 정보 보호)

2. **Config 확인**:

   ```bash
   python3 -m suh_template.cli config-get issue github_pat
   ```

   - 값이 반환되면 → config 로드 완료. repo가 여러 개면 어느 repo에 작성할지 사용자에게 선택하게 한다.
   - `config_not_found` 에러 → 대화형으로 아래 정보를 하나씩 수집한다:
     - GitHub PAT 토큰 (repo 권한 필요. 발급 방법: GitHub > Settings > Developer settings > Personal access tokens)
     - repo 목록 (owner/repo 형태, 여러 개 가능)
     - 기본 repo 선택
   - 수집 완료 후 저장 위치 선택:
     ```
     설정을 어디에 저장할까요?
     1. 이 프로젝트에만 (.suh-template/config/) — .gitignore 자동 등록
     2. 모든 프로젝트에서 사용 (~/.suh-template/config/)
     ```
   - AI가 직접 `config.save(project_root, "issue", data, scope)` 호출하여 저장.
```

- [ ] **Step 3: 변경 확인**

```bash
grep -A 20 "## 시작 전" skills/issue/SKILL.md | head -25
```

Expected: 새 config 확인 로직이 보임

- [ ] **Step 4: `.cursor/skills/` 동기화 및 확인**

```bash
cp skills/issue/SKILL.md .cursor/skills/issue/SKILL.md
diff skills/issue/SKILL.md .cursor/skills/issue/SKILL.md
```

Expected: diff 출력 없음

- [ ] **Step 5: 커밋**

```bash
git add skills/issue/SKILL.md .cursor/skills/issue/SKILL.md
git commit -m "feat: issue skill config 확인 로직 추가"
```

---

## Task 5: `synology-expose/SKILL.md` — config 시스템으로 교체

**Files:**
- Modify: `skills/synology-expose/SKILL.md`
- Sync: `.cursor/skills/synology-expose/SKILL.md`

- [ ] **Step 1: 현재 "설정 파일 확인" 섹션 위치 파악**

```bash
grep -n "설정 파일 확인\|synology-expose\.json\|\.synology" skills/synology-expose/SKILL.md | head -10
```

Expected: 기존 `.synology-expose.json` 탐색 로직 라인 번호 확인

- [ ] **Step 2: "설정 파일 확인" 섹션 전체를 새 내용으로 교체**

현재 "설정 파일 확인" 섹션 (## 설정 파일 확인 ~ ## 서비스 정보 수집 직전까지) 전체를 아래로 교체:

```markdown
## 설정 파일 확인

```bash
python3 -m suh_template.cli config-get synology-expose instances
```

- 값이 반환되면 → config 로드 완료.
  - instances가 1개면 그대로 사용.
  - instances가 여러 개면 번호를 매겨 선택하게 한다:
    ```
    등록된 NAS 인스턴스가 여러 개입니다. 어떤 것을 사용하시겠습니까?
    1. 집 NAS (my-nas.synology.me)
    2. 사무실 NAS (office-nas.synology.me)
    ```
- `config_not_found` 에러 → 대화형으로 아래 정보를 하나씩 수집한다:
  - NAS 이름 (예: 집 NAS)
  - 시놀로지 DDNS 주소 (예: my-nas.synology.me)
  - 사용하는 도메인 목록
  - Let's Encrypt 이메일
  - DNS 제공자 (cloudflare, route53, gabia 등)
- 수집 완료 후 저장 위치 선택:
  ```
  설정을 어디에 저장할까요?
  1. 이 프로젝트에만 (.suh-template/config/) — .gitignore 자동 등록
  2. 모든 프로젝트에서 사용 (~/.suh-template/config/)
  ```
- AI가 직접 `config.save(project_root, "synology-expose", data, scope)` 호출하여 저장.
```

- [ ] **Step 3: 기존 `.synology-expose.json` 참조가 없는지 확인**

```bash
grep "synology-expose\.json\|\.synology-expose" skills/synology-expose/SKILL.md
```

Expected: 출력 없음

- [ ] **Step 4: `.cursor/skills/` 동기화 및 확인**

```bash
cp skills/synology-expose/SKILL.md .cursor/skills/synology-expose/SKILL.md
diff skills/synology-expose/SKILL.md .cursor/skills/synology-expose/SKILL.md
```

Expected: diff 출력 없음

- [ ] **Step 5: 커밋**

```bash
git add skills/synology-expose/SKILL.md .cursor/skills/synology-expose/SKILL.md
git commit -m "feat: synology-expose skill 기존 config 로직을 새 config 시스템으로 교체"
```

---

## Task 6: 전체 검증

**Files:** 없음 (검증만)

- [ ] **Step 1: 전체 테스트 실행**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
python3 -m pytest tests/ -v 2>&1 | tail -20
```

Expected: 모든 테스트 PASSED

- [ ] **Step 2: 새 config 함수 smoke test**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
python3 -c "
import sys, json
sys.path.insert(0, '.')
from suh_template.config import save, load, ensure_gitignore
from pathlib import Path
import tempfile, os

with tempfile.TemporaryDirectory() as tmp:
    p = Path(tmp)
    # git init (get_project_root 없이 직접 테스트)
    data = {'github_pat': 'ghp_test', 'github_repos': []}
    saved = save(p, 'issue', data, scope='local')
    print('saved:', saved)
    loaded = load(p, 'issue')
    print('loaded:', loaded)
    gi = (p / '.gitignore').read_text()
    print('.gitignore:', gi.strip())
    assert loaded == data
    assert '.suh-template/config/' in gi
    print('smoke test: OK')
"
```

Expected: `smoke test: OK`

- [ ] **Step 3: `.example` 파일 존재 확인**

```bash
ls .suh-template.example/config/
```

Expected:
```
issue.config.example.json
synology-expose.config.example.json
```

- [ ] **Step 4: `init-config` CLI 동작 확인**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
python3 -m suh_template.cli init-config issue
```

Expected: `.suh-template.example/config/issue.config.example.json` 경로 출력

- [ ] **Step 5: SKILL.md 변경 확인**

```bash
# issue: config 로직 존재
grep -c "config-get issue" skills/issue/SKILL.md

# synology-expose: 기존 경로 제거됨
grep "synology-expose\.json" skills/synology-expose/SKILL.md
```

Expected: 첫 번째 `1`, 두 번째 출력 없음

- [ ] **Step 6: skills/ ↔ .cursor/skills/ 동일성 확인**

```bash
for skill in issue synology-expose; do
  result=$(diff skills/$skill/SKILL.md .cursor/skills/$skill/SKILL.md)
  if [ -z "$result" ]; then echo "$skill: OK"; else echo "$skill: MISMATCH"; fi
done
```

Expected: 둘 다 `OK`

- [ ] **Step 7: 최종 커밋**

```bash
git add -A
git commit -m "feat: sub-project #3 Config 시스템 구축 완료"
```

변경 사항이 없으면 스킵.
