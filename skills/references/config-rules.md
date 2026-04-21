# Config Rules

모든 skill의 config 파일 읽기/쓰기는 이 파일의 규칙을 따른다.

---

## 1. Config 파일 경로 구조

```
# 로컬 (프로젝트별)
{PROJECT_ROOT}/.suh-template/config/{skill_id}.config.json

# 글로벌 (모든 프로젝트 공유)
{HOME}/.suh-template/config/{skill_id}.config.json
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

**글로벌 config 실제 경로 예시:**

| OS | 실제 경로 |
|----|-----------|
| macOS | `/Users/chan4760/.suh-template/config/issue.config.json` |
| Windows (Git Bash) | `/c/Users/chan4760/.suh-template/config/issue.config.json` |
| Windows (탐색기 경로) | `C:\Users\chan4760\.suh-template\config\issue.config.json` |

> `chan4760` 부분은 `echo "$HOME"` 결과에서 추출한 실제 username으로 대체한다.

---

## 3. Config 읽기 순서

agent는 Read tool로 다음 순서로 파일을 탐색한다. 먼저 찾은 파일을 사용한다.

```
1순위: {PROJECT_ROOT}/.suh-template/config/{skill_id}.config.json
2순위: {HOME}/.suh-template/config/{skill_id}.config.json
        (HOME은 위 §2에서 확인한 실제 경로 사용)
```

**예시 (issue config, macOS, username=chan4760):**
```
1순위: /Users/chan4760/projects/my-app/.suh-template/config/issue.config.json
2순위: /Users/chan4760/.suh-template/config/issue.config.json
```

**예시 (issue config, Windows Git Bash, username=chan4760):**
```
1순위: /c/Users/chan4760/projects/my-app/.suh-template/config/issue.config.json
2순위: /c/Users/chan4760/.suh-template/config/issue.config.json
```

두 파일 모두 없으면 → §5 대화형 수집으로 진행한다.

---

## 4. Config 저장 (쓰기)

수집 완료 후 저장 위치를 사용자에게 선택받는다:

```
설정을 어디에 저장할까요?
1. 이 프로젝트에만 (.suh-template/config/) — .gitignore 자동 등록
2. 모든 프로젝트에서 사용 (~/.suh-template/config/)
```

agent가 Write tool로 저장한다:

| 선택 | 저장 경로 |
|------|-----------|
| 1 (로컬) | `{PROJECT_ROOT}/.suh-template/config/{skill_id}.config.json` |
| 2 (글로벌) | `{HOME}/.suh-template/config/{skill_id}.config.json` |

**로컬 저장(1번) 선택 시 추가 작업:**
`{PROJECT_ROOT}/.gitignore`에 `.suh-template/config/` 항목이 없으면 추가한다.

---

## 5. Config 없을 때 — 대화형 수집

파일이 없으면 정보를 하나씩 수집한다. **한 번에 여러 개를 묻지 않는다.**

수집할 항목은 skill별로 다르다. 각 skill의 "Config 확인" 섹션을 참조.

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

### issue.config.json (`skill_id = issue`)

`issue`, `commit`, `deploy`, `github`, `report` 스킬이 공유한다.

```json
{
  "github_pat": "ghp_xxxxxxxxxxxxxxxxxxxx",
  "default_assignee": "GitHub_사용자명",
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

| 필드 | 필수 | 설명 |
|------|------|------|
| `github_pat` | ✅ | GitHub Personal Access Token (repo + workflow 권한) |
| `default_assignee` | ✅ | 이슈 담당자 GitHub 사용자명 |
| `github_repos` | ✅ | 사용할 저장소 목록. `default: true`인 항목이 기본 선택 |

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
