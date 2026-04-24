# Config Rules

모든 skill의 config 파일 읽기/쓰기는 이 파일의 규칙을 따른다.

**config 접근 순서: `echo "$HOME"` → Read tool로 `{HOME}/.suh-template/config/config.json` 직접 읽기. Search·find·Bash로 탐색 금지.**

---

## 1. Config 파일 경로 구조

config 파일은 **글로벌 단일 파일**로만 관리한다. 스킬이 추가되어도 파일을 새로 만들지 않는다.

```
{HOME}/.suh-template/config/config.json
```

`{HOME}`은 OS별로 다르다. 아래 §2에서 확인하는 방법을 따른다.

---

## 2. 홈 디렉토리 확인 (OS별)

config를 읽거나 쓰기 전에 아래 커맨드로 홈 디렉토리를 확인한다:

```bash
echo "$HOME"
```

| OS | 반환 예시 |
|----|-----------|
| macOS | `/Users/username` |
| Linux | `/home/username` |
| Windows (Git Bash) | `/c/Users/username` |
| Windows (PowerShell) | `C:\Users\username` (단, `$HOME` 대신 `$env:USERPROFILE`) |

**agent 판단 규칙:**
- `echo "$HOME"` 결과가 `/c/Users/...` 또는 `C:\Users\...` 형태 → Windows
- `/Users/...` → macOS
- `/home/...` → Linux
- 결과가 비어있으면 `echo "$USERPROFILE"` 로 재시도

---

## 3. Config 읽기

agent는 Read tool로 `{HOME}/.suh-template/config/config.json`을 읽는다.

파일이 없으면 → §5 대화형 수집으로 진행한다.

각 스킬은 자신의 `skill_id`에 해당하는 섹션만 읽는다:

```
github 스킬    → config["github"]
synology-expose → config["synology-expose"]
ssh 스킬       → config["ssh"]
```

**github 스킬의 레포 자동 매칭 (읽기 후 즉시 수행):**

```bash
git remote get-url origin 2>/dev/null
```

반환값에서 `owner/repo`를 추출하여 `repos` 배열과 비교한다:
- `https://github.com/owner/repo` → `owner`, `repo` 추출
- `git@github.com:owner/repo.git` → `owner`, `repo` 추출

**레포 선택 우선순위:**
1. git remote URL 매칭 → `repos` 배열 중 `owner`+`repo` 모두 일치하는 항목
2. 매칭 실패 시 → `default: true`인 항목
3. 위 둘 다 없으면 → 번호를 매겨 사용자에게 선택

config에 해당 레포가 없는 경우 → 새 레포 추가 여부를 사용자에게 묻고 §4 절차로 추가한다.

**PAT 우선순위 (레포별 API 호출 시):**
1. 해당 repo 항목의 `pat` 필드가 non-null이면 사용
2. `null`이거나 없으면 `global_pat` fallback

---

## 4. Config 저장 (쓰기)

agent가 Write tool로 `{HOME}/.suh-template/config/config.json`에 저장한다.

**반드시 전체 파일을 Read로 읽은 뒤 수정**하여 덮어쓴다. 기존 다른 섹션을 날리지 않도록 주의한다.

새 섹션 추가 시 기존 파일을 Read로 읽은 뒤 해당 `skill_id` 키를 추가하여 저장한다.

---

## 5. Config 없을 때 — 대화형 수집

파일이 없으면 정보를 하나씩 수집한다. **한 번에 여러 개를 묻지 않는다.**

스킬에 필요한 섹션만 수집한 뒤 §4의 저장 절차를 따른다.

---

## 6. Agent 판단 원칙

- **애매하면 억지 추론 금지** — 즉시 사용자에게 질문
- **한 메시지 = 한 질문** — 여러 항목을 한꺼번에 묻지 않는다
- **이미 준 정보는 다시 묻지 않는다**
- **위험한 작업 실행 전 반드시 확인** — config 덮어쓰기 포함
- PAT, 토큰 등 민감 정보는 `common-rules.md` 마스킹 규칙 적용

---

## 7. Skill별 Config 스키마

모든 스킬의 설정은 단일 `config.json` 안에서 `skill_id`를 키로 구분한다.
전체 구조 예시는 `skills/config.json.example` 참조.

### `github` 섹션

`issue`, `commit`, `changelog-deploy`, `github`, `report` 스킬이 공유한다.

```json
{
  "github": {
    "default_assignee": "GitHub_사용자명",
    "global_pat": "ghp_xxxxxxxxxxxxxxxxxxxx",
    "repos": [
      {
        "name": "프로젝트 이름",
        "owner": "GitHub_사용자명_또는_조직명",
        "repo": "저장소명",
        "pat": null,
        "default": true
      }
    ]
  }
}
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `default_assignee` | ✅ | 이슈 기본 담당자 GitHub 사용자명 |
| `global_pat` | ✅ | 전체 공용 GitHub PAT (repo + workflow 권한) |
| `repos` | ✅ | 사용할 저장소 목록 |
| `repos[].name` | ✅ | 프로젝트 식별 이름 |
| `repos[].owner` | ✅ | GitHub 사용자명 또는 조직명 |
| `repos[].repo` | ✅ | 저장소명 |
| `repos[].pat` | — | 레포별 개별 PAT. `null`이면 `global_pat` 사용 |
| `repos[].default` | — | `true`인 항목이 기본 선택 repo |

**PAT 결정 로직:**
```
effective_pat = repo.pat if repo.pat else config["github"].global_pat
```

### `synology-expose` 섹션

`synology-expose` 스킬이 사용한다.

```json
{
  "synology-expose": {
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
}
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `name` | ✅ | NAS 식별 이름 |
| `ddns` | ✅ | Synology DDNS 주소 |
| `domains` | ✅ | 외부 노출에 사용할 도메인 목록 |
| `email` | ✅ | SSL 인증서 발급용 이메일 |
| `dns_provider` | ✅ | DNS 공급자 (예: `cloudflare`, `route53`) |
| `default` | — | 여러 인스턴스 중 기본 선택 여부 |

### `ssh` 섹션

`ssh` 스킬이 사용한다.

```json
{
  "ssh": {
    "instances": [
      {
        "name": "서버 식별 이름",
        "host": "your-server.example.com",
        "port": 22,
        "user": "username",
        "auth": "key",
        "key_path": "~/.ssh/id_rsa",
        "password": null,
        "default": true
      }
    ]
  }
}
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `name` | ✅ | 서버 식별 이름 |
| `host` | ✅ | 서버 주소 (IP 또는 도메인) |
| `port` | ✅ | SSH 포트 (기본 22) |
| `user` | ✅ | SSH 접속 사용자명 |
| `auth` | ✅ | 인증 방식: `key` 또는 `password` |
| `key_path` | — | `auth: key`일 때 PEM 키 경로 |
| `password` | — | `auth: password`일 때 비밀번호 |
| `default` | — | 여러 인스턴스 중 기본 선택 여부 |

---

## 8. 새 스킬에 Config 추가하는 방법

새 스킬이 config가 필요한 경우:

1. `skill_id`(스킬 폴더명)를 키로 `config.json`에 섹션 추가
2. 이 파일(§7)에 스키마 문서화
3. `skills/config.json.example`에 예시 추가
4. SKILL.md에 `references/config-rules.md §2~3` 참조 명시

**절대 별도 config 파일(`skill-name.config.json` 등)을 새로 만들지 않는다.**
