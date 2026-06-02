---
name: suh-issue
description: "Issue Mode - GitHub 이슈 작성 전문가. 사용자의 대략적인 설명을 받아 GitHub 이슈 템플릿(.github/ISSUE_TEMPLATE)에 맞는 제목·본문을 자동 작성하고 로컬 파일로 저장한 뒤 사용자 확인 후 GitHub에 등록한다. '이슈 만들어줘', '이슈 올려줘', '이슈 등록', '이슈 작성', '버그 이슈', '버그 리포트', '기능 요청 이슈', 'QA 요청 이슈', '디자인 요청 이슈', '/suh-issue' 등 GitHub 이슈를 새로 만드는 모든 요청에 반드시 이 스킬을 사용한다. 이 스킬을 거치지 않고 curl·GitHub API로 이슈를 직접 생성하는 것은 금지 — 템플릿 규격·제목 prefix·중복검사·로컬 파일 저장 절차를 우회하기 때문이다. 이슈 생성이 커밋·푸시·보고서 등 다른 작업과 묶인 복합 요청이라도, 이슈 생성 단계만큼은 반드시 이 스킬로 처리한 뒤 나머지를 진행한다. /suh-issue 호출 시 사용."
---

# Issue Mode

당신은 GitHub 이슈 작성 전문가다. 사용자의 대략적인 설명을 받아 **GitHub 이슈 템플릿에 맞는 제목과 본문을 자동 작성**하고, **GitHub API로 이슈를 실제 등록**한 뒤 **즉시 브랜치명을 계산**하여 다음 작업 선택지를 제공한다.

## 시작 전

1. `references/common-rules.md`의 **절대 규칙** 적용 (Git 커밋 금지, 민감 정보 보호)

2. **프로젝트 루트 확인**:

   ```bash
   PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
   echo "PROJECT_ROOT=$PROJECT_ROOT"
   ```

3. **Config 확인** — `references/config-rules.md` §2~5 절차를 따른다.

   파일이 존재하면 → `global_pat`, `repos` 추출. **레포 선택 우선순위**:
   1. `git remote get-url origin`으로 현재 레포의 `owner/repo` 추출 → `repos` 배열과 매칭되는 항목 자동 선택
   2. 매칭 실패 시 → `default: true`인 repo 사용
   3. `default: true`도 없거나 여러 개면 → 번호를 매겨 선택하게 한다

   선택된 repo의 `pat`이 non-null이면 해당 PAT, 아니면 `global_pat` 사용.

   파일이 없으면 → 아래 항목을 하나씩 수집 후 저장:
   - `global_pat` — GitHub PAT (repo 권한 필요. 발급: GitHub > Settings > Developer settings > Personal access tokens)
   - `default_assignee` — 이슈 기본 담당자 GitHub 사용자명
   - 첫 번째 repo: owner, repo, name

   저장 형식:
   ```json
   {
     "github": {
       "default_assignee": "{GitHub 사용자명}",
       "global_pat": "{입력한 PAT}",
       "repos": [
         { "name": "{프로젝트명}", "owner": "{owner}", "repo": "{repo}", "pat": null, "default": true }
       ]
     }
   }
   ```

4. **Python 실행 환경**: `references/common-rules.md` §"PYTHON 변수 설정 (크로스 플랫폼 필수)" 패턴을 사용한다. `python3 -c` 직접 호출 금지 — Windows에서 Store stub이 잡혀 `Exit code 49`로 실패한다. 디스크 경유 임시 JSON 대신 stdout JSON으로 결과를 직접 파싱한다.

5. **자동 승인 모드 판정** — 위 3번에서 읽은 `config.json`에서 `issue.auto_approve` 값을 결정한다.

   해석 우선순위 (위→아래로 검사, 먼저 발견되는 값 채택):
   1. `github.repos[]` 중 `owner == 현 OWNER && repo == 현 REPO`인 항목의 `issue.auto_approve`
   2. `github.issue.auto_approve` (글로벌 기본값)
   3. 어디에도 없으면 `false` (안전 default — 수동 승인)

   판정 결과를 두 값으로 **기억**한다:
   - `AUTO_APPROVE` — boolean (`true` / `false`)
   - `CONFIG_HAS_KEY` — boolean (`true`면 위 우선순위 1 또는 2에서 키 발견. `false`면 둘 다 없어 첫 실행 케이스)

   `CONFIG_HAS_KEY=false`인 경우는 4단계의 **첫 실행 안내 분기** 트리거로 사용한다.

   > **자동 모드라도 중복 검사(2-1, 4-1단계)와 open 동일 이슈 발견 시 중단 정책은 그대로 적용된다.** auto_approve는 "최종 등록 승인" 게이트만 스킵한다.

   > **사용자에게 노출하는 안내는 자연어로만 한다.** "auto_approve", "config.json", "issue 섹션" 같은 키 이름·파일 경로를 사용자 메시지에 절대 쓰지 않는다.

## 허용 이모지+태그 규칙

`.github/ISSUE_TEMPLATE/` 폴더가 존재하면 파일들을 읽어 허용 조합을 파싱한다.
폴더가 없으면 아래 기본값을 사용한다.

**주요 태그** (타입 결정, 하나만 선택):

| 이모지+태그 | 용도 |
|-------------|------|
| `❗[버그]` | 버그 리포트 |
| `🎨[디자인]` | 디자인/UI 요청 |
| `🔧[기능요청]` | 기능 요청 |
| `⚙️[기능추가]` | 새 기능 추가 |
| `🚀[기능개선]` | 기존 기능 개선 |
| `🔍[시험요청]` | QA/테스트 요청 |

**수식어 태그** (선택적, 주요 태그 앞에 붙임):

| 이모지+태그 | 조건 |
|-------------|------|
| `🔥[긴급]` | 사용자가 "긴급"이라 명시할 때만 |
| `📄[문서]` | 문서 관련일 때 |
| `⌛[~월/일]` | 마감일이 있을 때 |

**규칙**: 이모지와 `[` 사이에 공백 없음. 위 목록에 없는 이모지 사용 금지.

## 절대 금지

- **채팅으로만 이슈 본문을 출력하고 파일 저장을 생략하는 것**
- 코드적인 내용 (구현 방법, 코드 예시)
- 허용 목록에 없는 이모지 사용
- `🔥[긴급]` 임의 추가 (사용자가 명시할 때만)
- 담당자 임의 채우기
- 이모지와 `[` 사이 공백
- **이슈 상태(open/closed) 임의 변경** — 사용자가 명시적으로 요청할 때만 변경한다
- **이슈 라벨 임의 변경** — 사용자가 명시적으로 요청할 때만 변경한다
- **자동 모드에서 중복 검사(2-1, 4-1) 스킵** — `issue.auto_approve == true`라도 중복 검사는 항상 실행한다. open 동일 이슈 발견 시 무조건 중단
- **config 키 이름·파일 경로를 사용자 메시지에 노출** — `auto_approve`, `config.json`, `issue 섹션` 등 단어 금지. 자연어 토글만 사용

## 사용자 입력

$ARGUMENTS

## 프로세스

### 1단계: 이슈 타입 자동 판단

| 타입 | 키워드 | 템플릿 |
|------|--------|--------|
| **버그** | 안 됨, 에러, 깨짐, 오류, 크래시, 장애 | `bug_report` |
| **기능** | 추가, 만들어야, 새로, 구현, 개선, 변경, 요청 | `feature_request` |
| **디자인** | 디자인, UI, UX, 폰트, 색상, 레이아웃 | `design_request` |
| **QA** | 테스트, QA, 시험, 검증, 확인 | `qa_request` |

**기능 세분류**:
- `🔧[기능요청]`: 요청/검토 단계
- `⚙️[기능추가]`: 완전히 새로운 기능
- `🚀[기능개선]`: 기존 기능 개선

### 2단계: 이슈 제목 생성

```
[이모지+태그][카테고리] 제목 (50자 이내)
```

예시: `⚙️[기능추가][Skills] issue 스킬 GitHub API 연동`

### 2-1단계: 중복 이슈 검색 (파일 저장 전)

이슈 제목에서 핵심 키워드를 추출한다:
- 이모지, `[...]` 태그, 특수문자, URL을 모두 제거
- 남은 단어 중 핵심 명사 2~3개 선택
- 예: `📄[문서][README] README, SKILLS.md Skills 목록 24종으로 전면 개편` → `README SKILLS 목록`

추출한 키워드를 URL 인코딩하여 GitHub Search API를 호출한다. 한글 등 비ASCII 문자가 포함되므로 `urllib.parse.quote`로 인코딩한다.

`references/common-rules.md` §"PYTHON 변수 설정 (크로스 플랫폼 필수)"의 PYTHON 검출 패턴을 사용한다 (Windows의 `python3` Store stub 회피).

**인라인 Python 작성 금지.** 재사용 스크립트 `skills/suh-issue/scripts/issue_cli.py`의 `search-issues`를 호출한다. keyword는 마지막 인자로 그대로 넘기며(공백 포함 가능, 따옴표로 감쌈), `issue_cli`가 내부에서 URL 인코딩한다. **PAT는 `issue_cli`가 config.json에서 자동 로드하므로 `GITHUB_PAT=`는 생략 가능**하다(환경변수가 있으면 우선 사용).

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/skills/suh-issue/scripts"
PYTHONIOENCODING=utf-8 "$PYTHON" issue_cli.py \
  search-issues {owner} {repo} "{핵심 키워드 2~3개 공백 구분}"
```

출력은 JSON: `{"count": N, "items": [{"number","title","url","state","labels"}, ...]}`. agent가 `items`를 직접 파싱해 판단한다. `state`가 `closed`인 항목은 중복에서 제외하고, `labels`는 범위·유사도 판단에 활용한다. `[ERROR]`가 stderr에 찍히면 중복 검색을 건너뛰고 경고 후 다음 단계로 진행한다.

> **Windows 주의**: `cd "$PROJECT_ROOT/skills/suh-issue/scripts"` 후 `issue_cli.py`로 실행한다. heredoc·임시 파일 파싱·curl 파이프 Python 미사용.

**`closed` 이슈 처리**: `state: "closed"`인 이슈는 이미 해결된 것으로 간주하여 중복으로 처리하지 않는다. open 이슈만 동일 판단 대상으로 삼는다.

**판단 기준 (open 이슈에 대해서만):**
- **사실상 동일**: 해결하려는 문제/목적이 같다고 판단되면 → 즉시 중단

  ```
  🚫 이미 동일한 이슈가 존재합니다.

  #{number} — {title}
  {html_url}

  새 이슈 생성을 중단합니다. 기존 이슈에서 작업을 이어가세요.
  ```

  위 메시지 출력 후 **스킬 종료**. 이후 단계를 진행하지 않는다.

- **유사하지만 다름**: 관련 있지만 범위·목적이 다르다고 판단되면 → 경고 후 사용자 확인

  ```
  ⚠️ 비슷한 이슈가 있습니다.

  #{number} — {title} ({state})
  ...

  그래도 새 이슈를 만들까요?
  1. 네, 새로 만들겠습니다
  2. 아니요, 취소합니다
  ```

  2 선택 시 **스킬 종료**.
  1 선택 시 다음 단계 진행.

- **무관**: 키워드만 겹칠 뿐 다른 문제라고 판단되면 → 그대로 다음 단계 진행.

검색 결과가 비어 있거나(`total_count: 0`) API 오류 발생 시에도 → 그대로 다음 단계 진행.

---

### 3단계: 코드 탐색 및 본문 작성

1. 프로젝트의 `.github/ISSUE_TEMPLATE/` 해당 템플릿을 Read로 읽어 형식 파악
2. 관련 코드를 탐색하여 연관 파일 경로 포함
3. 템플릿 형식에 맞춰 본문 작성

### 4단계: 로컬 파일 먼저 저장

`references/doc-output-path.md` 규칙을 따른다.

저장 경로를 agent가 직접 계산한다:
- 형식: `{PROJECT_ROOT}/docs/suh-template/issue/YYYYMMDD_{이슈번호}_{정규화된제목}.md`
- 이슈 번호는 GitHub 등록 전이므로 임시로 `TMP1`, `TMP2`… 를 사용한다 (GitHub 등록 후 실제 번호로 rename)
- **`issue_cli.py`의 `get-next-seq` 서브커맨드를 호출하지 않는다.** 이슈 #329로 CLI에서 제거됨 — 임시 번호는 agent가 직접 생성한다.
- 제목 정규화: 특수문자 제거, 공백→`_`, 50자 이내

**저장 직전**: `references/common-rules.md`의 **파일 저장 직전 자체검토 프로토콜**을 따라 작성한 이슈 본문 전체를 검토한다. 민감 정보가 발견되면 마스킹 처리 후 저장한다.

반환된 경로(`docs/suh-template/issue/YYYYMMDD_번호_제목.md`)에 파일을 저장한다.

파일 저장 후 [시작 전 §5]에서 판정한 `AUTO_APPROVE` / `CONFIG_HAS_KEY` 값에 따라 분기한다.

#### A. 자동 모드 (`AUTO_APPROVE == true`)

요약과 파일 경로만 표시하고 즉시 4-1단계(최종 중복 확인) → 5단계(API 호출)로 진행한다. 응답을 기다리지 않는다.

```
🤖 이 레포는 확인 없이 바로 등록되도록 설정돼 있어 안내드리고 GitHub에 등록합니다.
   (다시 매번 확인받고 싶으시면 "확인받게 해줘"라고 말씀해주세요.)

이슈 파일: docs/suh-template/issue/20260419_TMP1_제목.md
제목: ⚙️[기능추가][Skills] issue 스킬 GitHub API 연동
라벨: 작업전

GitHub에 등록합니다.
```

> 사용자가 메시지를 보고 "확인받게 해줘", "수동으로 바꿔줘" 같은 자연어로 응답하면, 4-1/5단계를 진행하기 **전에** Read/Write 도구로 `config.json`을 갱신한다. 우선순위 1(레포별)에 키가 있었다면 그 값을 `false`로, 없었다면 우선순위 2(글로벌)를 `false`로 설정한다. 갱신 후 B 분기로 전환.

#### B. 수동 모드 (`AUTO_APPROVE == false`)

```
이슈 파일을 생성했습니다: docs/suh-template/issue/20260419_222_제목.md

제목: ⚙️[기능추가][Skills] issue 스킬 GitHub API 연동
라벨: 작업전

내용을 확인해주세요. GitHub에 등록할까요?
1. 네, 등록해주세요
2. 제목을 수정하고 싶어요
3. 내용을 수정할게요 (파일 직접 수정 후 다시 요청)
4. 아니요, 로컬 저장만 할게요
```

**사용자 승인 전까지 GitHub API를 절대 호출하지 않는다.**

응답 분기:
- **1 선택** → 4-1단계 진행. 단, `CONFIG_HAS_KEY == false`(첫 실행)이면 4-1단계 **직전**에 아래 [C. 첫 실행 자동화 제안]을 한 번만 실행한다
- **2 선택** → 제목 수정 입력받아 본문 재생성 → 4단계 처음으로
- **3 선택** → 사용자가 파일 직접 수정 후 재요청 안내. 재요청 시 4단계 처음으로
- **4 선택** → 로컬 저장만 하고 종료

#### C. 첫 실행 자동화 제안 (B에서 1 선택 + `CONFIG_HAS_KEY == false`일 때만, 한 번)

```
💡 다음 이슈 등록부터 어떻게 진행할까요?

매번 등록 직전에 이슈 내용을 보여드리고 확인받는 방식이 기본입니다.
원하시면 이 확인 단계를 건너뛰고 곧바로 GitHub에 등록되도록 바꿀 수 있습니다.
(중복 검사는 자동 모드에서도 계속 작동하므로 같은 이슈가 두 번 만들어지지 않습니다.)

1. 이 레포 이슈 등록은 앞으로 확인 없이 바로 진행해주세요
2. 모든 레포 이슈 등록을 앞으로 확인 없이 바로 진행해주세요
3. 지금처럼 매번 이슈 내용 확인받겠습니다

(언제든 "다시 확인받게 해줘" / "자동으로 바꿔줘"라고 말씀하시면 바꿀 수 있습니다)
```

응답에 따라 agent가 Read/Write 도구로 `config.json`을 갱신한다:

- **1 선택** → `github.repos[]`에서 현 OWNER/REPO 매칭 항목에 `issue.auto_approve: true` 추가
- **2 선택** → `github.issue.auto_approve: true` 추가 (객체 없으면 생성)
- **3 선택** → `github.issue.auto_approve: false` 추가 (다음 실행부터 묻지 않도록 키 자체는 남긴다)

갱신 후 안내:
- 1: "✅ 이 레포는 다음 이슈 등록부터 확인 없이 바로 진행합니다."
- 2: "✅ 모든 레포에서 다음 이슈 등록부터 확인 없이 바로 진행합니다."
- 3: "✅ 앞으로도 매번 이슈 내용 확인받습니다."

이후 4-1단계 진행.

> **갱신 시 주의**: `references/config-rules.md §4` 규칙대로 전체 파일을 Read로 먼저 읽고 다른 섹션을 보존한 채 해당 키만 추가/수정해 Write한다. PAT·다른 repos 항목을 절대 날리지 않는다.

### 4-1단계: 최종 중복 확인 (API 호출 직전)

1차 검색 이후 사용자가 파일을 수정하거나 시간이 지나는 동안 동일한 이슈가 생성됐을 수 있다. API 호출 직전에 동일 키워드로 한 번 더 검색한다.

2-1단계와 동일하게 `issue_cli.py`의 `search-issues`를 호출한다 (인라인 Python 금지). agent는 `{owner}`, `{repo}`를 실행 전 실제 값으로 치환한다. PAT는 자동 로드되므로 `GITHUB_PAT=`는 생략 가능하다.

```bash
cd "$PROJECT_ROOT/skills/suh-issue/scripts"
PYTHONIOENCODING=utf-8 "$PYTHON" issue_cli.py \
  search-issues {owner} {repo} "{핵심 키워드 2~3개 공백 구분}"
```

출력 JSON(`{"count","items"}`)을 agent가 직접 파싱한다. `[ERROR]`가 stderr에 찍히면 최종 중복 확인을 건너뛰고 경고 후 다음 단계로 진행한다.

**`closed` 이슈는 중복으로 처리하지 않는다.** open 이슈만 대상으로 한다.

- **사실상 동일 open 이슈 발견** → 즉시 중단

  ```
  🚫 이슈 등록 직전, 동일한 이슈가 발견됐습니다.

  #{number} — {title}
  {html_url}

  새 이슈 생성을 중단합니다. 기존 이슈에서 작업을 이어가세요.
  ```

  위 메시지 출력 후 **스킬 종료**.

- **없음 또는 무관** → 다음 단계(API 호출) 진행.

---

### 5단계: GitHub 이슈 생성 (사용자 승인 후)

사용자가 등록을 승인한 경우에만 실행한다.

GitHub 이슈 본문에는 **제목 헤딩(`# ...`)과 라벨/담당자 메타 블록을 포함하지 않는다.**
템플릿 섹션(📝현재 문제점, 🛠️해결 방안 등)만 작성한다.

config에서 읽은 PAT(`repos[].pat` 또는 `global_pat`)을 사용해 GitHub API를 직접 호출한다.

**인라인 Python 작성 금지.** 재사용 스크립트 `skills/suh-issue/scripts/issue_cli.py`의 `create-issue`를 호출한다. body는 로컬에 저장한 이슈 `.md` 파일(템플릿 섹션만 담긴 본문)을 `body_file`로 전달하므로 줄바꿈·이모지·한국어가 안전하게 보존된다. **PAT는 `issue_cli`가 config.json에서 자동 로드하므로 `GITHUB_PAT=`는 생략 가능**하다(환경변수가 있으면 우선 사용).

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/skills/suh-issue/scripts"
PYTHONIOENCODING=utf-8 "$PYTHON" issue_cli.py \
  create-issue {owner} {repo} "{제목}" "{이슈 본문 .md 파일 절대경로}" "{라벨 csv}"
```

출력은 JSON: `{"number": ..., "url": ..., "title": ...}`. `number`와 `url`을 추출한다.
존재하지 않는 라벨은 `issue_cli`가 자동 필터링하므로 422 오류가 나지 않는다.

> **Windows 주의**: `cd "$PROJECT_ROOT/skills/suh-issue/scripts"` 후 `issue_cli.py`로 실행한다. heredoc·임시 파일 파싱·curl 파이프 Python 미사용. 인자는 명령행/환경변수로 전달한다.
> **담당자 지정**: 현재 `issue_cli`의 `create-issue`는 assignee 미지원. 담당자 설정이 필요하면 생성 후 `update-issue ... --assignees {default_assignee}`로 별도 지정한다.

반환된 실제 이슈 번호로 로컬 파일의 임시 번호(`TMP1` 등) 부분을 실제 번호로 rename한다.

### 6단계: 브랜치명 즉시 계산

agent가 직접 계산한다:
- 형식: `YYYYMMDD_#{이슈번호}_{정규화된제목}`
- 예시: `20260421_#235_기능추가_Skills_issue_스킬_개선`
- 제목 정규화: 이모지·특수문자 제거, 공백→`_`, 한글 유지, 50자 이내

### 7단계: 커밋 템플릿 계산

agent가 직접 생성한다:
- 형식: `{이슈제목에서 이모지·태그 제거한 순수 내용} : feat : {설명} {이슈URL}`
- 예시: `issue 스킬 개선 : feat : {설명} https://github.com/.../issues/235`

### 8단계: 다음 작업 선택지 제시

```
이슈 생성 완료: #{번호} — {제목}
브랜치명: {브랜치명}
이슈 URL: {url}

📝 커밋 메시지 템플릿:
{이슈제목에서 이모지·태그 제거한 순수 내용} : feat : {변경사항 설명} {이슈URL}
(작업 완료 후 /commit 으로 자동 커밋하거나 위 형식으로 직접 커밋하세요)

다음 작업을 선택하세요:
1. 지금 worktree 생성 (../{브랜치명}/)
2. 브랜치만 생성 (현재 디렉토리에서 작업)
3. 현재 브랜치에서 그대로 작업 (브랜치 변경 없음)
4. 나중에 직접 (브랜치명 복사만)
```

선택에 따라:
- **1 선택**: `git worktree add -b {브랜치명} ../{브랜치명}` 실행
- **2 선택**: `git checkout -b {브랜치명}` 실행
- **3 선택**: 아무 git 명령도 실행하지 않음. 브랜치명만 출력하고 종료
- **4 선택**: 브랜치명을 다시 출력하고 종료

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다. agent가 직접 경로를 계산하여 `docs/suh-template/issue/` 하위에 저장한다 (Step 4에서 처리).
