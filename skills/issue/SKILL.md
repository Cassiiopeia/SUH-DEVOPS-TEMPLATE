---
name: issue
description: "Issue Mode - GitHub 이슈 작성 전문가. 사용자의 대략적인 설명을 받아 GitHub 이슈 템플릿에 맞는 제목과 본문을 자동 작성하고 로컬 파일로 저장한다. 사용자 확인 후 GitHub에 등록한다. 이슈 생성, 버그 리포트, 기능 요청, QA 요청 작성 시 사용. /issue 호출 시 사용."
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

   파일이 존재하면 → `global_pat`, `repos` 추출. `repos` 중 `default: true`인 repo 사용. repo가 여러 개면 번호를 매겨 선택하게 한다. 선택된 repo의 `pat`이 non-null이면 해당 PAT, 아니면 `global_pat` 사용.

   파일이 없으면 → 아래 항목을 하나씩 수집 후 저장:
   - `global_pat` — GitHub PAT (repo 권한 필요. 발급: GitHub > Settings > Developer settings > Personal access tokens)
   - `default_assignee` — 이슈 기본 담당자 GitHub 사용자명
   - 첫 번째 repo: owner, repo, name

   저장 형식:
   ```json
   {
     "default_assignee": "{GitHub 사용자명}",
     "global_pat": "{입력한 PAT}",
     "repos": [
       { "name": "{프로젝트명}", "owner": "{owner}", "repo": "{repo}", "pat": null, "default": true }
     ]
   }
   ```

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

추출한 키워드로 GitHub Search API를 호출한다:

```bash
KEYWORD="{핵심 키워드 2~3개 공백 구분}"
curl -s \
  -H "Authorization: token {github_pat}" \
  "https://api.github.com/search/issues?q=is:issue+repo:{owner}/{repo}+in:title+$(echo $KEYWORD | tr ' ' '+')" \
  -o /tmp/issue_search.json
```

검색 결과(`/tmp/issue_search.json`)의 `items` 배열을 읽고 AI가 직접 판단한다:

**판단 기준:**
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
- 제목 정규화: 특수문자 제거, 공백→`_`, 50자 이내

반환된 경로(`docs/suh-template/issue/YYYYMMDD_번호_제목.md`)에 파일을 저장한다.

파일 저장 후 **반드시 사용자에게 파일 경로를 알리고 내용을 확인받는다**:

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

### 5단계: GitHub 이슈 생성 (사용자 승인 후)

사용자가 등록을 승인한 경우에만 실행한다.

GitHub 이슈 본문에는 **제목 헤딩(`# ...`)과 라벨/담당자 메타 블록을 포함하지 않는다.**
템플릿 섹션(📝현재 문제점, 🛠️해결 방안 등)만 작성한다.

config에서 읽은 PAT(`repos[].pat` 또는 `global_pat`)을 사용해 GitHub API를 직접 호출한다:

```bash
curl -s -X POST \
  -H "Authorization: token {github_pat}" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"{제목}\", \"body\": \"{본문}\", \"labels\": [\"{라벨}\"], \"assignees\": [\"{default_assignee}\"]}" \
  "https://api.github.com/repos/{owner}/{repo}/issues"
```

반환 JSON에서 `number`와 `html_url`을 추출한다.

반환된 실제 이슈 번호로 로컬 파일의 임시 번호(`TMP1` 등) 부분을 실제 번호로 rename한다.

### 6단계: 브랜치명 즉시 계산

agent가 직접 계산한다:
- 형식: `YYYYMMDD_#{이슈번호}_{정규화된제목}`
- 예시: `20260421_#235_기능추가_Skills_issue_스킬_개선`
- 제목 정규화: 이모지·특수문자 제거, 공백→`_`, 한글 유지, 50자 이내

### 7단계: 커밋 템플릿 계산

agent가 직접 생성한다:
- 형식: `{이슈제목} : feat : {설명} {이슈URL}`
- 예시: `⚙️[기능추가][Skills] issue 스킬 개선 : feat : {설명} https://github.com/.../issues/235`

### 8단계: 다음 작업 선택지 제시

```
이슈 생성 완료: #{번호} — {제목}
브랜치명: {브랜치명}
이슈 URL: {url}

📝 커밋 메시지 템플릿:
{이슈제목} : feat : {변경사항 설명} {이슈URL}
(작업 완료 후 /commit 으로 자동 커밋하거나 위 형식으로 직접 커밋하세요)

다음 작업을 선택하세요:
1. 지금 worktree 생성 (../{브랜치명}/)
2. 브랜치만 생성 (현재 디렉토리에서 작업)
3. 현재 브랜치에서 그대로 작업 (브랜치 변경 없음)
4. 나중에 직접 (브랜치명 복사만)
```

선택에 따라:
- **1 선택**: `git worktree add -b {브랜치명} ../{브랜치명}` 실행 후 이슈 컨텍스트 저장
- **2 선택**: `git checkout -b {브랜치명}` 실행 후 이슈 컨텍스트 저장
- **3 선택**: 아무 git 명령도 실행하지 않음. 브랜치명만 출력하고 종료
- **4 선택**: 브랜치명을 다시 출력하고 종료

**이슈 컨텍스트 저장** (1, 2 선택 시):

```bash
mkdir -p "$PROJECT_ROOT/.suh-template/context"
cat > "$PROJECT_ROOT/.suh-template/context/current-issue.json" << EOF
{
  "issue_number": {번호},
  "issue_title": "{이슈 제목}",
  "issue_url": "{이슈 URL}",
  "branch_name": "{브랜치명}",
  "commit_template": "{이슈제목} : feat : {설명} {이슈URL}"
}
EOF
```

`.suh-template/`은 `.gitignore`에 등록되어 있어 커밋되지 않는다.

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다. agent가 직접 경로를 계산하여 `docs/suh-template/issue/` 하위에 저장한다 (Step 4에서 처리).
