# Sub-project #3: Skill별 Config 시스템

**작성일**: 2026-04-19
**상태**: 승인됨
**관련 로드맵**: [마스터 로드맵](./20260418-skill-system-upgrade-roadmap.md)

---

## 목적

각 skill이 필요로 하는 사용자/환경별 설정(GitHub PAT 토큰, repo 목록, NAS 정보 등)을 안전하게 보관할 표준 메커니즘을 도입한다. config가 없을 때 AI가 대화형으로 수집해서 자동 저장하고, 민감 정보는 gitignore로 보호한다.

---

## 디렉토리 구조

```
{프로젝트 루트}/
├── .suh-template/
│   └── config/
│       ├── issue.config.json           # 실제 값 (gitignore)
│       └── synology-expose.config.json # 실제 값 (gitignore)
└── .suh-template.example/
    └── config/
        ├── issue.config.example.json           # 템플릿 (커밋)
        └── synology-expose.config.example.json # 템플릿 (커밋)

~/.suh-template/
└── config/
    ├── issue.config.json           # 글로벌 fallback
    └── synology-expose.config.json # 글로벌 fallback
```

---

## Config 탐색 순서

1. `{git 루트}/.suh-template/config/{skill_id}.config.json` (프로젝트 로컬)
2. `~/.suh-template/config/{skill_id}.config.json` (글로벌 fallback)
3. 둘 다 없으면 → `config_not_found` (exit 0, AI가 대화형 수집 흐름 진행)

---

## Config 스키마

### `issue.config.json`

```json
{
  "github_pat": "ghp_xxxxxxxxxxxxxxxxxxxx",
  "github_repos": [
    {
      "name": "메인 프로젝트",
      "owner": "Cassiiopeia",
      "repo": "RomRom",
      "default": true
    },
    {
      "name": "DevOps 템플릿",
      "owner": "Cassiiopeia",
      "repo": "SUH-DEVOPS-TEMPLATE",
      "default": false
    }
  ]
}
```

- `github_pat`: GitHub Personal Access Token (repo 권한 필요)
- `github_repos`: repo 목록. `default: true`인 항목을 기본으로 사용. 여러 개면 skill 실행 시 선택
- `owner` + `repo`: GitHub API 호출에 사용 (`owner/repo` 형태)

### `synology-expose.config.json`

```json
{
  "instances": [
    {
      "name": "집 NAS",
      "ddns": "my-nas.synology.me",
      "domains": ["example.com", "mysite.kr"],
      "email": "user@example.com",
      "dns_provider": "cloudflare",
      "default": true
    }
  ]
}
```

- `instances`: NAS 인스턴스 목록 (여러 NAS 지원)
- `default: true`인 인스턴스를 기본으로 사용
- 기존 `.synology-expose.json`의 `domains` 배열 구조에서 진화한 형태

---

## Python 헬퍼 변경사항

### `config.py` 수정

기존 `load()`, `get_value()`에 글로벌 fallback 탐색 추가:

```python
def load(project_root, skill_id) -> Optional[dict]:
    # 1. 프로젝트 로컬
    local = _config_path(Path(project_root), skill_id)
    if local.exists():
        return json.loads(local.read_text(encoding="utf-8"))
    # 2. 글로벌 fallback
    global_ = Path.home() / ".suh-template" / "config" / f"{skill_id}.config.json"
    if global_.exists():
        return json.loads(global_.read_text(encoding="utf-8"))
    return None

def save(project_root, skill_id, data: dict, scope: str = "local") -> Path:
    """
    config를 저장하고 저장된 경로를 반환한다.
    scope: "local" → 프로젝트 루트, "global" → ~/.suh-template/
    프로젝트 로컬 저장 시 .gitignore에 자동 등록한다.
    """

def ensure_gitignore(project_root) -> None:
    """
    {project_root}/.gitignore에 .suh-template/config/ 항목이 없으면 추가한다.
    """
```

### `cli.py` 신규 커맨드: `init-config <skill_id> [--scope local|global]`

```bash
python3 -m suh_template.cli init-config issue
# stdout: .suh-template/config/issue.config.json
# exit: 0 (성공)
```

- `.example` 파일을 읽어 필요한 키 목록을 파악
- 각 키에 대한 값을 stdin에서 읽어 config 파일 생성
- `--scope` 없으면 stdout에 경로만 출력하고 실제 저장은 AI가 담당 (AI가 대화형 수집 후 `save` 호출)
- `--scope local|global` 지정 시 해당 위치에 직접 저장

**실제 사용 패턴**: AI(skill)가 직접 `config.save()`를 호출. CLI `init-config`는 `.example` 파일 경로 반환 및 검증용.

---

## .gitignore 자동 등록

`config.save(scope="local")` 호출 시 자동으로:

```
# .gitignore에 추가되는 내용
.suh-template/config/
```

- `.gitignore`가 없으면 새로 생성
- 이미 해당 항목이 있으면 중복 추가하지 않음

---

## .example 템플릿 파일

### `.suh-template.example/config/issue.config.example.json`

```json
{
  "_comment": "이 파일을 .suh-template/config/issue.config.json으로 복사하고 값을 채우세요.",
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

### `.suh-template.example/config/synology-expose.config.example.json`

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

---

## SKILL.md 변경사항

### `issue/SKILL.md`

"시작 전" 섹션에 config 확인 로직 추가:

```markdown
## 시작 전

1. `references/common-rules.md` 절대 규칙 적용
2. config 확인:
   - `python3 -m suh_template.cli config-get issue github_pat` 실행
   - 결과 없으면 → 대화형으로 PAT 토큰과 repo 정보 수집 후
     `python3 -m suh_template.cli` 경로 저장 (scope: local 또는 global 사용자 선택)
   - repo가 여러 개면 어느 repo에 작성할지 사용자에게 선택하게 함
```

### `synology-expose/SKILL.md`

"설정 파일 확인" 섹션을 새 config 시스템으로 교체:

```markdown
## 설정 파일 확인

`python3 -m suh_template.cli config-get synology-expose instances` 실행.
없으면 → 대화형으로 NAS 정보 수집 후 저장 (scope 사용자 선택).
```

기존 `.synology-expose.json` 탐색 로직 완전 제거.

---

## 에러 처리

| 코드 | 레벨 | 상황 | 대응 |
|------|------|------|------|
| `config_not_found` | WARN | config 파일 없음 (양쪽 다) | AI가 대화형 수집 후 저장 |
| `config_parse_error` | ERROR | JSON 파싱 실패 | 파일 손상 안내, `.example`로 재생성 유도 |
| `gitignore_write_error` | WARN | .gitignore 쓰기 실패 | 수동 등록 안내 |

---

## 결정 사항

| 항목 | 결정 |
|------|------|
| config 위치 | 프로젝트 로컬 우선, 없으면 글로벌 fallback |
| 초기화 방식 | AI 대화형 수집 (config 없을 때 skill 실행 시) |
| gitignore | `config.save(scope="local")` 시 자동 등록 |
| 적용 skill | `issue`, `synology-expose` (이번 sub-project) |
| 하위 호환 | 없음 — 기존 `.synology-expose.json` 무시 |
| Python 버전 | 3.8+, 표준 라이브러리만 |

---

## 적용 범위 (이번 Sub-project)

| 파일 | 변경 유형 |
|------|----------|
| `scripts/suh_template/config.py` | 수정 — 글로벌 fallback, `save()`, `ensure_gitignore()` 추가 |
| `scripts/suh_template/cli.py` | 수정 — `init-config` 커맨드 추가 |
| `.suh-template.example/config/issue.config.example.json` | 신규 |
| `.suh-template.example/config/synology-expose.config.example.json` | 신규 |
| `skills/issue/SKILL.md` | 수정 — config 확인 로직 추가 |
| `skills/synology-expose/SKILL.md` | 수정 — 기존 config 로직 교체 |
| `.cursor/skills/issue/SKILL.md` | 동기화 |
| `.cursor/skills/synology-expose/SKILL.md` | 동기화 |
| `tests/test_config.py` | 신규 — 글로벌 fallback, save, gitignore 테스트 |

---

## 다음 Sub-project

- **#4**: Cursor 매니페스트 (버전 관리)
- **#6**: `issue` skill GitHub API 연동 (이슈 생성/조회/댓글)
