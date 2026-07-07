# issue skill 중복검색 단계 cross-platform 호환 패치

- **이슈**: [#288](https://github.com/Cassiiopeia/projectops/issues/288)
- **작성일**: 2026-05-08
- **대상 버전**: v3.0.37
- **결정**: B/B/A/B (범위·공통화·호출형태·ssh)

---

## 1. 배경

issue skill v3.0.36 5단계(GitHub POST)는 `PYTHON=$(...)` 검출 + `urllib.request` 패턴으로 Windows/Mac 양쪽에서 동작. 그러나 2-1·4-1단계(중복 이슈 검색)는 누락되어 다음 패턴이 그대로 남음:

```bash
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$KEYWORD', safe=''))")
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/search/issues?..." \
  -o /tmp/issue_search.json
```

Windows Git Bash에서 다음 오류 연쇄:
- `python3` → Windows Store stub → `Exit code 49`
- `/tmp/issue_search.json` → POSIX 경로 매핑 후 native python 재접근 시 `FileNotFoundError`
- agent가 retry·우회 명령으로 토큰 낭비

`skills/ssh/SKILL.md` L104도 동일 `python3 -c` 하드코딩 패턴.

---

## 2. 범위 (결정 Q1=B)

**포함:**
- `skills/issue/SKILL.md` 2-1단계 (L113~131)
- `skills/issue/SKILL.md` 4-1단계 (L207~217)
- `skills/ssh/SKILL.md` L102~109 (PLUGIN_ROOT 추출)

**제외:**
- 그 외 skill 전수 스캔 — scope creep. 별도 이슈로 분리 가능.

---

## 3. 아키텍처 (결정 Q2=B)

### 3.1 공통 스니펫 — 이미 존재 ✅

조사 결과 `skills/references/common-rules.md` §"suh_template CLI 실행 규칙" §2 (L181~194)에 **PYTHON 변수 설정 (크로스 플랫폼 필수)** 패턴이 이미 정의됨:

```bash
PYTHON=$(
  for _py in python3 python; do
    _path=$(command -v "$_py" 2>/dev/null) || continue
    "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break
  done
)
if [ -z "$PYTHON" ]; then echo "❌ Python을 찾을 수 없습니다."; exit 1; fi
```

→ common-rules.md 신규 섹션 추가 **불필요**. 단순히 issue·ssh skill에서 이 섹션을 참조하도록 변경.

### 3.2 위치 이동 권장 (선택)

현재 PYTHON 검출 패턴이 "suh_template CLI 실행 규칙" 하위에 있어 의미상 좁음. 공통 사용 의도면 별도 상위 섹션으로 분리하는 것이 명확. 단 v3.0.37 범위에서는 **위치 그대로 유지**, issue·ssh에서 참조만 추가. 위치 이동은 별도 이슈로.

### 3.3 각 skill에서 참조

issue·ssh skill의 "시작 전" 섹션에 한 줄 추가:

```markdown
4. **Python 실행 시**: `references/common-rules.md`의 §"PYTHON 변수 설정 (크로스 플랫폼 필수)" 패턴 사용 — `python3 -c` 직접 호출 금지.
```

---

## 4. 패치 상세

### 4.1 issue/SKILL.md 2-1단계 (결정 Q3=A)

**변경 전 (L120~131):**
```bash
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$KEYWORD', safe=''))")
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/search/issues?q=is:issue+repo:{owner}/{repo}+in:title+${ENCODED}&per_page=5" \
  -o /tmp/issue_search.json
```
> 검색 결과는 Read tool로 `/tmp/issue_search.json`을 읽어...

**변경 후:**
```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
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
> 검색 결과는 stdout JSON으로 출력된다. agent가 `total_count`와 `items` 배열을 직접 파싱하여 판단한다.

### 4.2 issue/SKILL.md 4-1단계 (L207~217)

2-1단계와 동일 패턴. 단어만 "최종 중복 확인"으로 유지.

### 4.3 ssh/SKILL.md L102~109 (결정 Q4=B)

**변경 전:**
```bash
PLUGIN_ROOT=$(cat ~/.claude/plugins/installed.json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cassiiopeia',{}).get('path',''))" 2>/dev/null)
```

**변경 후:**
```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
PLUGIN_ROOT=$(cat ~/.claude/plugins/installed.json 2>/dev/null \
  | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('cassiiopeia',{}).get('path',''))" 2>/dev/null)
```

> 최소 변경. stdin pipe + 한 줄 파싱이라 heredoc 불필요. `python3` → `$PYTHON` 치환만.

---

## 5. 영향 범위

| 파일 | 변경 종류 | 줄 수 |
|------|---------|------|
| `skills/issue/SKILL.md` | 2-1·4-1 단계 코드블럭 교체 | ~30줄 |
| `skills/ssh/SKILL.md` | L102~104 PYTHON 검출 추가 | +1줄 |
| `skills/references/common-rules.md` | 변경 없음 (이미 §2에 패턴 존재) | 0줄 |

**버전:**
- `version.yml`: 3.0.36 → 3.0.37
- `.claude-plugin/plugin.json`: 자동 동기화 (`PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC` 워크플로우)

**테스트:**
- 자동 테스트 없음. 수동 검증:
  1. Windows Git Bash에서 `/issue` 호출 → 2-1·4-1단계 정상 동작 확인
  2. Mac에서 동일 호출 → 회귀 없음 확인
  3. ssh skill 호출 → PLUGIN_ROOT 추출 정상 확인

---

## 6. 데이터 흐름 (변경 후)

```
사용자 → /issue 호출
  ↓
Step 2-1: PYTHON 검출 → urllib로 검색 API 호출 → stdout JSON
  ↓
agent가 stdout 직접 파싱 (디스크 경유 X)
  ↓
중복 판단 → 진행 또는 중단
  ↓
Step 4 → Step 4-1 (동일 패턴 재실행) → Step 5 (POST)
```

---

## 7. 에러 처리

| 시나리오 | 동작 |
|---------|------|
| 둘 다 없음 (`python3`, `python` 모두 부재) | `$PYTHON` 빈 값 → heredoc 실행 시 즉시 실패 → agent가 사용자에게 Python 설치 안내 |
| GitHub API 401 | urllib `HTTPError` → agent가 PAT 만료 안내 |
| 네트워크 timeout | urllib 기본 timeout 의존. 추후 명시적 timeout 필요시 별도 이슈 |

---

## 8. 마이그레이션

기존 사용자: plugin update만으로 적용. config 변경 없음. 호환성 깨짐 없음.

---

## 9. 다음 단계

이 spec 승인 후 `superpowers:writing-plans` skill로 상세 구현 plan 작성.
