# issue skill cross-platform fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** issue skill 2-1·4-1단계 + ssh skill L104의 `python3 -c` 하드코딩과 `/tmp/*.json` 디스크 경유 패턴을 제거하여 Windows/Mac/Linux 공통 동작을 보장한다.

**Architecture:** common-rules.md §"PYTHON 변수 설정"에 이미 정의된 검출 패턴을 issue 2-1·4-1단계와 ssh L104에서 사용하도록 SKILL.md를 수정. urllib heredoc으로 검색 API 호출 + stdout JSON 출력으로 디스크 경유 제거. ssh L104는 stdin pipe 유지하되 `python3` → `$PYTHON`만 치환.

**Tech Stack:** Bash heredoc, Python 3 표준 라이브러리(`urllib.request`, `urllib.parse`, `json`), GitHub Search API.

**Spec:** `docs/superpowers/specs/2026-05-08-issue-skill-cross-platform-fix-design.md`
**Issue:** [#288](https://github.com/Cassiiopeia/projectops/issues/288)

---

## File Structure

| 파일 | 책임 | 변경 종류 |
|------|------|---------|
| `skills/issue/SKILL.md` | 이슈 작성 skill 본문 | Modify L113~131 (2-1단계), L207~219 (4-1단계), "시작 전" 섹션에 PYTHON 참조 추가 |
| `skills/ssh/SKILL.md` | SSH skill 본문 | Modify L99~109 (PYTHON 검출 후 `$PYTHON` 사용), "시작 전" 섹션에 PYTHON 참조 추가 |
| `version.yml` | 프로젝트 버전 | Modify version: 3.0.36 → 3.0.37 |
| `.claude-plugin/plugin.json` | plugin 매니페스트 | 자동 동기화 워크플로우가 처리 — 수동 변경 불필요 |
| `skills/references/common-rules.md` | 공통 규칙 | **변경 없음** (이미 §2에 PYTHON 검출 패턴 존재) |

각 SKILL.md는 단일 파일로 자체 완결. 공통 패턴은 references에서 가져온다.

---

## Task 1: 작업 브랜치 사전 검증

**Files:**
- Read: `D:/0-suh/project/suh-github-template/.git/HEAD`

- [ ] **Step 1: 현재 브랜치 확인**

```bash
cd D:/0-suh/project/suh-github-template
git rev-parse --abbrev-ref HEAD
```

Expected: `main` (사용자가 "현재 브랜치 그대로" 선택)

- [ ] **Step 2: working tree 정리 상태 확인**

```bash
git status --short
```

Expected: 미트래킹 파일 (`docs/suh-template/issue/...288...md`, `docs/superpowers/specs/...`, `docs/superpowers/plans/...`, `nul`) 외 변경 없음.

- [ ] **Step 3: ssh/SKILL.md 현재 라인 확인 (변경 전 baseline)**

```bash
grep -n "python3 -c\|PYTHON=" "D:/0-suh/project/suh-github-template/skills/ssh/SKILL.md" | head -10
```

Expected output (예상):
```
104:  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cassiiopeia',{}).get('path',''))" 2>/dev/null)
```

`python3 -c` 단 한 줄. `PYTHON=` 검출 패턴 없음. 이게 baseline.

- [ ] **Step 4: issue/SKILL.md 현재 라인 확인 (변경 전 baseline)**

```bash
grep -n "python3 -c\|/tmp/issue_search" "D:/0-suh/project/suh-github-template/skills/issue/SKILL.md"
```

Expected output:
```
124:ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$KEYWORD', safe=''))")
128:  -o /tmp/issue_search.json
131:검색 결과는 Read tool로 `/tmp/issue_search.json`을 읽어 `items` 배열을 확인하고 AI가 직접 판단한다.
212:ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$KEYWORD', safe=''))")
216:  -o /tmp/issue_search_final.json
219:Read tool로 `/tmp/issue_search_final.json`을 읽어 AI가 결과를 판단한다.
```

확인 후 Task 2로.

---

## Task 2: issue/SKILL.md 2-1단계 패치

**Files:**
- Modify: `skills/issue/SKILL.md` L113~131 (중복 이슈 검색 코드블럭)

- [ ] **Step 1: 변경 전 정확한 old_string 확보 (라인 정확히 매치)**

다음을 그대로 사용:

```bash
KEYWORD="{핵심 키워드 2~3개 공백 구분}"
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$KEYWORD', safe=''))")
curl -s \
  -H "Authorization: token {github_pat}" \
  "https://api.github.com/search/issues?q=is:issue+repo:{owner}/{repo}+in:title+${ENCODED}&per_page=5" \
  -o /tmp/issue_search.json
```

후속 문장:
```
검색 결과는 Read tool로 `/tmp/issue_search.json`을 읽어 `items` 배열을 확인하고 AI가 직접 판단한다.
```

- [ ] **Step 2: Edit으로 패치 적용**

`skills/issue/SKILL.md`에서 위 두 블록을 각각 다음으로 교체.

새 코드블럭:
```bash
PYTHON=$(
  for _py in python3 python; do
    _path=$(command -v "$_py" 2>/dev/null) || continue
    "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break
  done
)
if [ -z "$PYTHON" ]; then echo "❌ Python을 찾을 수 없습니다."; exit 1; fi

KEYWORD="{핵심 키워드 2~3개 공백 구분}"
"$PYTHON" - <<EOF
import urllib.request, urllib.parse, json
keyword = "$KEYWORD"
encoded = urllib.parse.quote(keyword, safe='')
url = f"https://api.github.com/search/issues?q=is:issue+repo:{owner}/{repo}+in:title+{encoded}&per_page=5"
req = urllib.request.Request(url)
req.add_header("Authorization", "token {github_pat}")
res = urllib.request.urlopen(req)
print(json.dumps(json.loads(res.read()), ensure_ascii=False))
EOF
```

새 후속 문장:
```
검색 결과는 stdout JSON으로 출력된다. agent가 `total_count`와 `items` 배열을 직접 파싱하여 판단한다 (디스크 파일 경유 X — Windows/Mac 공통 동작 보장).
```

> **주의**: heredoc delimiter는 `'EOF'` (single-quoted) 아님. `EOF` (unquoted)로 사용해야 `$KEYWORD` shell 변수가 보간됨. `{owner}`, `{repo}`, `{github_pat}`는 placeholder이므로 그대로 둠 (skill 사용자가 실제 값으로 치환).

- [ ] **Step 3: 패치 검증**

```bash
grep -n "python3 -c\|/tmp/issue_search.json" "D:/0-suh/project/suh-github-template/skills/issue/SKILL.md" | head -5
```

Expected: 2-1단계(L113~131) 영역에서 `python3 -c`나 `/tmp/issue_search.json` 잔재 없음. 4-1단계 잔재만 남아있어야 함 (다음 task에서 처리).

```bash
grep -n "PYTHON=$" "D:/0-suh/project/suh-github-template/skills/issue/SKILL.md"
```

Expected: 새로 추가된 PYTHON 검출 패턴 라인이 발견됨 (2-1단계 영역).

- [ ] **Step 4: 커밋 보류**

이슈 #288 기반 작업이고 이슈 번호 확정됨. 그러나 4-1단계·ssh·시작전 참조까지 완료 후 한 번에 커밋. 지금은 커밋 안 함.

---

## Task 3: issue/SKILL.md 4-1단계 패치

**Files:**
- Modify: `skills/issue/SKILL.md` L207~219

- [ ] **Step 1: 변경 전 old_string 확보**

```bash
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$KEYWORD', safe=''))")
curl -s \
  -H "Authorization: token {github_pat}" \
  "https://api.github.com/search/issues?q=is:issue+repo:{owner}/{repo}+in:title+${ENCODED}&per_page=5" \
  -o /tmp/issue_search_final.json
```

후속:
```
Read tool로 `/tmp/issue_search_final.json`을 읽어 AI가 결과를 판단한다.
```

- [ ] **Step 2: 새 블록으로 교체**

```bash
"$PYTHON" - <<EOF
import urllib.request, urllib.parse, json
keyword = "$KEYWORD"
encoded = urllib.parse.quote(keyword, safe='')
url = f"https://api.github.com/search/issues?q=is:issue+repo:{owner}/{repo}+in:title+{encoded}&per_page=5"
req = urllib.request.Request(url)
req.add_header("Authorization", "token {github_pat}")
res = urllib.request.urlopen(req)
print(json.dumps(json.loads(res.read()), ensure_ascii=False))
EOF
```

> **주의**: 4-1단계는 2-1단계 직후 같은 세션에서 호출되는 흐름이므로 `$PYTHON`·`$KEYWORD` shell 변수가 이미 set 되어 있다고 가정. PYTHON 검출 블록 재실행 불필요.

새 후속 문장:
```
stdout JSON 결과를 agent가 직접 파싱하여 결과를 판단한다.
```

- [ ] **Step 3: 패치 검증**

```bash
grep -n "python3 -c\|/tmp/issue_search" "D:/0-suh/project/suh-github-template/skills/issue/SKILL.md"
```

Expected: 빈 출력 (issue/SKILL.md 전체에서 `python3 -c` 및 `/tmp/issue_search*` 모두 제거됨).

- [ ] **Step 4: 커밋 보류**

다음 task로.

---

## Task 4: issue/SKILL.md "시작 전" 섹션에 PYTHON 참조 추가

**Files:**
- Modify: `skills/issue/SKILL.md` L10~19 ("시작 전" 섹션)

- [ ] **Step 1: 현재 "시작 전" 섹션 라인 확인**

```bash
grep -n "^## 시작 전\|^1\.\|^2\.\|^3\." "D:/0-suh/project/suh-github-template/skills/issue/SKILL.md" | head -10
```

Expected: "시작 전" 섹션에 1·2·3번 항목 존재. 4번 항목 자리 비어있음.

- [ ] **Step 2: 항목 추가**

3번 항목 끝 (Config 확인 블록 마지막) 직후에 다음을 추가:

```markdown
4. **Python 실행 환경**: `references/common-rules.md` §"PYTHON 변수 설정 (크로스 플랫폼 필수)" 패턴을 사용한다. `python3 -c` 직접 호출 금지 — Windows에서 Store stub이 잡혀 `Exit code 49`로 실패한다.
```

> 기존 3번 항목이 코드블럭으로 끝나는지, 본문으로 끝나는지에 따라 적절한 위치 선정. Edit tool 사용 시 unique한 surrounding context 확보.

- [ ] **Step 3: 검증**

```bash
grep -n "PYTHON 변수 설정" "D:/0-suh/project/suh-github-template/skills/issue/SKILL.md"
```

Expected: 1줄 출력 (Step 2에서 추가한 라인).

---

## Task 5: ssh/SKILL.md L99~109 패치

**Files:**
- Modify: `skills/ssh/SKILL.md` L99~109

- [ ] **Step 1: 현재 블록 확인**

```bash
sed -n '99,110p' "D:/0-suh/project/suh-github-template/skills/ssh/SKILL.md"
```

Expected output:
```
**스크립트 경로 확인:**

```bash
# 플러그인 설치 경로에서 스크립트 찾기
PLUGIN_ROOT=$(cat ~/.claude/plugins/installed.json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cassiiopeia',{}).get('path',''))" 2>/dev/null)
SCRIPT_PATH="${PLUGIN_ROOT}/skills/ssh/scripts/ssh_connect.py"

# 없으면 로컬 경로 시도
[ ! -f "$SCRIPT_PATH" ] && SCRIPT_PATH="$(git rev-parse --show-toplevel)/skills/ssh/scripts/ssh_connect.py"
```
```

- [ ] **Step 2: 변경 전 old_string**

```bash
# 플러그인 설치 경로에서 스크립트 찾기
PLUGIN_ROOT=$(cat ~/.claude/plugins/installed.json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cassiiopeia',{}).get('path',''))" 2>/dev/null)
SCRIPT_PATH="${PLUGIN_ROOT}/skills/ssh/scripts/ssh_connect.py"

# 없으면 로컬 경로 시도
[ ! -f "$SCRIPT_PATH" ] && SCRIPT_PATH="$(git rev-parse --show-toplevel)/skills/ssh/scripts/ssh_connect.py"
```

- [ ] **Step 3: 새 블록으로 교체**

```bash
# Python 실행 환경 검출 (Windows에서 python3 stub 회피)
PYTHON=$(
  for _py in python3 python; do
    _path=$(command -v "$_py" 2>/dev/null) || continue
    "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break
  done
)
if [ -z "$PYTHON" ]; then echo "❌ Python을 찾을 수 없습니다."; exit 1; fi

# 플러그인 설치 경로에서 스크립트 찾기
PLUGIN_ROOT=$(cat ~/.claude/plugins/installed.json 2>/dev/null \
  | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('cassiiopeia',{}).get('path',''))" 2>/dev/null)
SCRIPT_PATH="${PLUGIN_ROOT}/skills/ssh/scripts/ssh_connect.py"

# 없으면 로컬 경로 시도
[ ! -f "$SCRIPT_PATH" ] && SCRIPT_PATH="$(git rev-parse --show-toplevel)/skills/ssh/scripts/ssh_connect.py"
```

> **주의**: ssh skill 다른 곳(L114·L95 등)에 이미 `$PYTHON` 변수 사용 중. 즉 이 PYTHON 검출 블록이 SKILL.md 내 다른 위치에 이미 있을 가능성. **Step 1에서 전체 SKILL.md grep으로 PYTHON 검출 블록 중복 여부 확인 필요**:

```bash
grep -cn "command -v \"\$_py\"" "D:/0-suh/project/suh-github-template/skills/ssh/SKILL.md"
```

- 0이면 위 새 블록 그대로 추가
- 1 이상이면 이미 존재 → L104의 `python3` → `$PYTHON`만 치환:

```bash
# 플러그인 설치 경로에서 스크립트 찾기 (PYTHON은 위 섹션에서 이미 검출됨)
PLUGIN_ROOT=$(cat ~/.claude/plugins/installed.json 2>/dev/null \
  | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('cassiiopeia',{}).get('path',''))" 2>/dev/null)
```

- [ ] **Step 4: 검증**

```bash
grep -n "python3 -c\|\\\$PYTHON" "D:/0-suh/project/suh-github-template/skills/ssh/SKILL.md"
```

Expected: `python3 -c` 라인 0개. `$PYTHON` 사용 라인 다수.

---

## Task 6: ssh/SKILL.md "시작 전" 섹션에 PYTHON 참조 추가

**Files:**
- Modify: `skills/ssh/SKILL.md` 상단 "시작 전" 또는 동등 섹션

- [ ] **Step 1: ssh/SKILL.md 상단 구조 확인**

```bash
sed -n '1,40p' "D:/0-suh/project/suh-github-template/skills/ssh/SKILL.md"
```

"시작 전" 또는 "사전 준비" 섹션 위치 확인.

- [ ] **Step 2: 항목 추가**

issue/SKILL.md Task 4와 동일한 라인:
```markdown
- **Python 실행 환경**: `references/common-rules.md` §"PYTHON 변수 설정 (크로스 플랫폼 필수)" 패턴을 사용한다. `python3 -c` 직접 호출 금지 — Windows에서 Store stub이 잡혀 `Exit code 49`로 실패한다.
```

해당 섹션의 적절한 항목 위치에 추가.

- [ ] **Step 3: 검증**

```bash
grep -n "PYTHON 변수 설정" "D:/0-suh/project/suh-github-template/skills/ssh/SKILL.md"
```

Expected: 1줄 출력.

---

## Task 7: 수동 통합 테스트 (Windows Git Bash)

자동 테스트 없음. skill 동작 수동 검증.

**Files:** 없음 (실행 검증)

- [ ] **Step 1: 모의 KEYWORD 변수로 검색 API 호출 테스트**

```bash
PYTHON=$(
  for _py in python3 python; do
    _path=$(command -v "$_py" 2>/dev/null) || continue
    "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break
  done
)
echo "PYTHON=$PYTHON"
```

Expected: `PYTHON=/c/Users/USER/AppData/Local/Programs/Python/Python313/python` (또는 Mac/Linux의 python3 실제 경로).
`PYTHON=` 빈 출력 또는 stub 경로(`WindowsApps/python3`)면 실패.

- [ ] **Step 2: heredoc + urllib 검색 호출**

```bash
KEYWORD="test"
"$PYTHON" - <<EOF
import urllib.request, urllib.parse, json
keyword = "$KEYWORD"
encoded = urllib.parse.quote(keyword, safe='')
url = f"https://api.github.com/search/issues?q=is:issue+repo:Cassiiopeia/projectops+in:title+{encoded}&per_page=2"
req = urllib.request.Request(url)
req.add_header("Authorization", "token YOUR_PAT_HERE")
res = urllib.request.urlopen(req)
print(json.dumps(json.loads(res.read()), ensure_ascii=False)[:200])
EOF
```

> **주의**: PAT 자리에 실제 PAT 입력 필요. 테스트 후 transcript에서 PAT 즉시 마스킹.

Expected: JSON 응답 출력 (`{"total_count": ..., "incomplete_results": ..., "items": [...]`). Exit code 0.

`Exit code 49`나 `FileNotFoundError`가 나오면 패치 실패 — Task 2~6 재검토.

- [ ] **Step 3: 한글 키워드 검증**

```bash
KEYWORD="이슈"
"$PYTHON" - <<EOF
import urllib.parse
keyword = "$KEYWORD"
print(urllib.parse.quote(keyword, safe=''))
EOF
```

Expected: `%EC%9D%B4%EC%8A%88` (UTF-8 percent-encoded). 이게 나오면 한글 인코딩 정상.

- [ ] **Step 4: ssh skill PLUGIN_ROOT 추출 테스트**

```bash
PLUGIN_ROOT=$(cat ~/.claude/plugins/installed.json 2>/dev/null \
  | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('cassiiopeia',{}).get('path',''))" 2>/dev/null)
echo "PLUGIN_ROOT=$PLUGIN_ROOT"
```

Expected: 공백이 아닌 cassiiopeia plugin 경로 (예: `C:/Users/USER/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia/3.0.18`).

`installed.json`이 다른 구조거나 cassiiopeia가 설치 안 된 환경이면 빈 출력 가능 — 이 경우 skill에 fallback 경로(L108) 있으니 문제 아님.

---

## Task 8: 버전 bump

**Files:**
- Modify: `version.yml` L24~ (version 필드)

- [ ] **Step 1: 현재 version 확인**

```bash
grep "^version:" "D:/0-suh/project/suh-github-template/version.yml"
```

Expected: `version: "3.0.36"`

- [ ] **Step 2: 3.0.37로 bump**

Edit:
```
old_string: version: "3.0.36"
new_string: version: "3.0.37"
```

- [ ] **Step 3: 검증**

```bash
grep "^version:" "D:/0-suh/project/suh-github-template/version.yml"
```

Expected: `version: "3.0.37"`

> **참고**: `.claude-plugin/plugin.json`은 `PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC` 워크플로우가 자동 동기화한다. 수동 변경하지 않음.
> 또한 main에 push 시 `PROJECT-COMMON-VERSION-CONTROL` 워크플로우가 자동으로 patch를 +1 한다 — 이미 3.0.37로 직접 올린 경우 워크플로우는 skip 또는 3.0.38로 다시 올릴 수 있음. 워크플로우 동작은 별도 운영 책임. 본 plan에서는 수동 bump만 실행.

---

## Task 9: 자체검토 — 패치 종합 grep

**Files:** 없음

- [ ] **Step 1: 전체 skills 디렉토리에서 잔재 패턴 확인**

```bash
grep -rn "python3 -c" "D:/0-suh/project/suh-github-template/skills/"
```

Expected: 다음 두 위치만 남아있어야 함:
- `skills/references/common-rules.md` — §2 PYTHON 검출 패턴 설명용 (L181~194 사이의 금지 패턴 예시 또는 코드블럭). 변경 대상 아님.
- 코드블럭 외 산문에서 "`python3 -c`" 형태로 인용된 라인 (예: 금지 패턴 명시).

issue·ssh의 실제 실행 코드블럭에서는 0건이어야 함.

- [ ] **Step 2: /tmp/ 경로 잔재 확인**

```bash
grep -rn "/tmp/issue_search" "D:/0-suh/project/suh-github-template/skills/"
```

Expected: 0건.

- [ ] **Step 3: 새 PYTHON 검출 블록 카운트**

```bash
grep -rn "command -v \"\$_py\"" "D:/0-suh/project/suh-github-template/skills/"
```

Expected: 다음 위치들에 등장:
- `skills/references/common-rules.md` L189 (원본 정의)
- `skills/issue/SKILL.md` Task 2에서 추가된 위치
- `skills/ssh/SKILL.md` 기존 또는 Task 5에서 추가된 위치

총 3 hit 이상.

---

## Task 10: 커밋

**Files:** 없음 (git 커밋)

- [ ] **Step 1: working tree 확인**

```bash
cd D:/0-suh/project/suh-github-template
git status --short
```

Expected modified 항목:
- `M skills/issue/SKILL.md`
- `M skills/ssh/SKILL.md`
- `M version.yml`

Expected untracked (이전 task 산출물, 함께 커밋):
- `?? docs/suh-template/issue/20260508_288_...md`
- `?? docs/superpowers/specs/2026-05-08-issue-skill-cross-platform-fix-design.md`
- `?? docs/superpowers/plans/2026-05-08-issue-skill-cross-platform-fix.md`

`?? nul` 파일은 이전 세션 산출물 추정 — **커밋하지 않음**. 별도 정리.

- [ ] **Step 2: 커밋 대상 명시 staging**

```bash
git add skills/issue/SKILL.md skills/ssh/SKILL.md version.yml \
  "docs/suh-template/issue/20260508_288_issue_skill_중복검색_단계_Windows_python3_호환_누락.md" \
  "docs/superpowers/specs/2026-05-08-issue-skill-cross-platform-fix-design.md" \
  "docs/superpowers/plans/2026-05-08-issue-skill-cross-platform-fix.md"
```

> `git add -A` 또는 `.` 사용 금지 (CLAUDE.md 규칙 — 민감 파일 사고 방지). `nul` 파일도 무시됨.

- [ ] **Step 3: 사용자 승인 후 커밋**

CLAUDE.md 규칙: 사용자 승인 없이 커밋 금지. 다음 메시지로 사용자에게 검토 요청:

```
커밋 메시지:
issue 스킬 중복검색 단계 Windows python3 호환 누락 : fix : 2-1·4-1단계 PYTHON 검출 + urllib heredoc 패턴으로 통일, ssh L104 동반 점검, v3.0.37 bump https://github.com/Cassiiopeia/projectops/issues/288

위 메시지로 커밋해도 될까요?
```

승인 후:

```bash
git commit -m "issue 스킬 중복검색 단계 Windows python3 호환 누락 : fix : 2-1·4-1단계 PYTHON 검출 + urllib heredoc 패턴으로 통일, ssh L104 동반 점검, v3.0.37 bump https://github.com/Cassiiopeia/projectops/issues/288"
```

> **금지 사항** (CLAUDE.md): 커밋 메시지 앞에 `🚀[기능개선]`, `❗[버그]` 등 이모지+태그 포함 금지. 이슈 제목에서 이모지·태그 제거한 순수 내용만 사용.

- [ ] **Step 4: 커밋 결과 확인**

```bash
git log -1 --oneline
```

Expected: 새 커밋 hash + 위 메시지 첫 줄 표시.

- [ ] **Step 5: push는 사용자 명시 요청 시에만**

CLAUDE.md 규칙: `git push`는 사용자가 명시적으로 요청한 경우에만 실행. 본 plan에서는 push 단계 제외.

---

## Task 11: 이슈 #288 댓글 — 작업 완료 보고

**Files:** 없음 (GitHub API 호출)

- [ ] **Step 1: PAT 확보**

config에서 읽은 PAT 사용 (`ghp_...`). 사용자가 transcript에서 직접 제공했으므로 메모리에서 사용. **revoke 권장 상태**임을 사용자에게 다시 알릴 것.

- [ ] **Step 2: 이슈 #288에 작업 완료 댓글 등록**

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
"$PYTHON" - <<'PYEOF'
import urllib.request, json
pat = "GHP_PLACEHOLDER"
url = "https://api.github.com/repos/Cassiiopeia/projectops/issues/288/comments"
body = """v3.0.37 패치 완료.

**변경:**
- `skills/issue/SKILL.md` 2-1단계 (L113~131): PYTHON 검출 + `urllib` heredoc으로 교체. `/tmp/issue_search.json` 디스크 경유 제거.
- `skills/issue/SKILL.md` 4-1단계 (L207~219): 동일 패턴 적용.
- `skills/issue/SKILL.md` "시작 전" 섹션: PYTHON 환경 참조 추가.
- `skills/ssh/SKILL.md` L99~109: `python3 -c` → `$PYTHON` 치환.
- `skills/ssh/SKILL.md` "시작 전" 섹션: 동일 참조 추가.
- `version.yml`: 3.0.36 → 3.0.37.

`skills/references/common-rules.md` §"PYTHON 변수 설정"는 변경 없음 (이미 패턴 정의되어 있었음).

수동 검증: Windows Git Bash에서 PYTHON 검출, urllib 한글 인코딩, ssh PLUGIN_ROOT 추출 모두 정상.
"""
payload = {"body": body}
data = json.dumps(payload).encode()
req = urllib.request.Request(url, data=data, method="POST")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
res = urllib.request.urlopen(req)
result = json.loads(res.read())
print("COMMENT_URL:", result["html_url"])
PYEOF
```

> **주의**: `GHP_PLACEHOLDER`는 실제 실행 시 사용자 PAT로 치환. 이 plan 파일에는 평문 PAT 절대 저장 금지.

- [ ] **Step 3: 사용자에게 결과 보고**

다음 메시지로 보고:

```
이슈 #288 작업 완료. v3.0.37 패치 커밋됨.
이슈 댓글 등록: <comment_url>

다음 옵션:
1. push (`git push origin main`)
2. PR 생성 — main 브랜치 직접 작업이라 불필요
3. 마무리
```

---

## Self-Review

**Spec coverage:**

| Spec 섹션 | 대응 Task |
|---------|---------|
| §2 패치 범위 (issue 2-1·4-1, ssh L104) | Task 2, 3, 5 |
| §3.1 공통 스니펫 — 이미 존재 (변경 없음) | (작업 없음 — 검증만 Task 9) |
| §3.3 각 skill에서 참조 추가 | Task 4, 6 |
| §4.1 issue 2-1단계 패치 상세 | Task 2 |
| §4.2 issue 4-1단계 패치 상세 | Task 3 |
| §4.3 ssh L104 패치 상세 | Task 5 |
| §5 영향 범위 (version bump) | Task 8 |
| §5 테스트 (수동 검증) | Task 7 |
| §7 에러 처리 (PYTHON 빈 값 → exit 1) | Task 2, 5 (`if [ -z "$PYTHON" ]` 포함) |

빈 항목 없음.

**Placeholder scan:** Plan 내 `TBD`, `TODO`, "implement later" 없음. 모든 step에 실제 코드·명령·기대 출력 명시.

**Type consistency:** 변수명 `PYTHON`, `KEYWORD`, `PLUGIN_ROOT`, `SCRIPT_PATH`가 task 간 일관됨. `urllib.request`·`urllib.parse`·`json` import 일관됨.

검토 통과. 수정 없음.

---

## Plan complete and saved to `docs/superpowers/plans/2026-05-08-issue-skill-cross-platform-fix.md`.

**두 가지 실행 옵션:**

1. **Subagent-Driven (recommended)** — task별 fresh subagent 디스패치, 각 task 후 검토, fast iteration
2. **Inline Execution** — 현재 세션에서 batch 실행, checkpoint마다 검토

어느 쪽으로 진행할까?
