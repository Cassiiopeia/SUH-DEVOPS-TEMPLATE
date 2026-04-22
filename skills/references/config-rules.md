# Config Rules

모든 skill의 config 파일 읽기/쓰기는 이 파일의 규칙을 따른다.

---

## 1. Config 파일 경로 구조

config 파일은 **글로벌 단일 파일**로만 관리한다. 프로젝트별 로컬 config는 사용하지 않는다.

```
# 글로벌 (모든 프로젝트 공유) — 유일한 경로
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
| macOS | `/Users/chan4760` |
| Linux | `/home/chan4760` |
| Windows (Git Bash) | `/c/Users/chan4760` |
| Windows (PowerShell) | `C:\Users\chan4760` (단, `$HOME` 대신 `$env:USERPROFILE`) |

**agent 판단 규칙:**
- `echo "$HOME"` 결과가 `/c/Users/...` 또는 `C:\Users\...` 형태 → Windows
- `/Users/...` → macOS
- `/home/...` → Linux
- 결과가 비어있으면 `echo "$USERPROFILE"` 로 재시도

**실제 경로 예시:**

| OS | 실제 경로 |
|----|-----------|
| macOS | `/Users/chan4760/.suh-template/config/config.json` |
| Linux | `/home/chan4760/.suh-template/config/config.json` |
| Windows (Git Bash) | `/c/Users/chan4760/.suh-template/config/config.json` |

> `chan4760` 부분은 `echo "$HOME"` 결과에서 추출한 실제 username으로 대체한다.

---

## 3. Config 읽기

agent는 Read tool로 `{HOME}/.suh-template/config/config.json`을 읽는다.

파일이 없으면 → §5 대화형 수집으로 진행한다.

**레포 자동 매칭 (읽기 후 즉시 수행):**

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

새 repo 추가 시 기존 파일을 Read로 읽은 뒤 `repos` 배열에 항목을 추가하여 덮어쓴다.
**기존 내용을 날리지 않도록 반드시 전체 파일을 읽고 수정한다.**

---

## 5. Config 없을 때 — 대화형 수집

파일이 없으면 정보를 하나씩 수집한다. **한 번에 여러 개를 묻지 않는다.**

수집 순서:
1. `global_pat` — GitHub Personal Access Token (repo + workflow 권한)
2. `default_assignee` — 이슈 기본 담당자 GitHub 사용자명
3. 첫 번째 repo: `owner`, `repo`, `name` (이 repo를 `default: true`로 설정)

수집 완료 후 §4의 저장 절차를 따른다.

---

## 6. Agent 판단 원칙

- **애매하면 억지 추론 금지** — 즉시 사용자에게 질문
- **한 메시지 = 한 질문** — 여러 항목을 한꺼번에 묻지 않는다
- **이미 준 정보는 다시 묻지 않는다**
- **위험한 작업 실행 전 반드시 확인** — config 덮어쓰기 포함
- PAT, 토큰 등 민감 정보는 `common-rules.md` 마스킹 규칙 적용

---

## 7. Skill별 Config 스키마

### config.json

`issue`, `commit`, `changelog-deploy`, `github`, `report` 스킬이 공유한다.

```json
{
  "default_assignee": "GitHub_사용자명",
  "global_pat": "ghp_xxxxxxxxxxxxxxxxxxxx",
  "repos": [
    {
      "name": "프로젝트 이름",
      "owner": "GitHub_사용자명_또는_조직명",
      "repo": "저장소명",
      "pat": null,
      "default": true
    },
    {
      "name": "다른 프로젝트",
      "owner": "GitHub_사용자명_또는_조직명",
      "repo": "저장소명",
      "pat": "ghp_별도PAT_있으면_입력",
      "default": false
    }
  ]
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

**PAT 결정 로직 (agent 구현 시):**
```
effective_pat = repo.pat if repo.pat else config.global_pat
```

### synology-expose.config.json (`skill_id = synology-expose`)

```json
{
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

| 필드 | 필수 | 설명 |
|------|------|------|
| `name` | ✅ | NAS 식별 이름 |
| `ddns` | ✅ | Synology DDNS 주소 |
| `domains` | ✅ | 외부 노출에 사용할 도메인 목록 |
| `email` | ✅ | SSL 인증서 발급용 이메일 |
| `dns_provider` | ✅ | DNS 공급자 (예: `cloudflare`, `route53`) |
| `default` | — | 여러 인스턴스 중 기본 선택 여부 |
