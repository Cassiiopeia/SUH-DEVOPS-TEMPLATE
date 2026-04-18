# Sub-project #1: 공통 Python 헬퍼 인프라

**작성일**: 2026-04-18
**상태**: 승인됨
**관련 로드맵**: [마스터 로드맵](./20260418-skill-system-upgrade-roadmap.md)

---

## 목적

모든 skill이 공통으로 사용할 크로스 플랫폼 Python 헬퍼 패키지를 구축한다.
Python 3.8+, 표준 라이브러리만 사용. Mac/Windows 모두 지원.

---

## 패키지 구조

```
scripts/
└── suh_template/
    ├── __init__.py
    ├── cli.py              # 진입점: python3 -m suh_template.cli <command>
    ├── paths.py            # 산출물 경로 계산
    ├── issue_number.py     # 이슈 번호 추출 (worktree 폴더명 / git 브랜치명)
    ├── title.py            # 제목 추출 및 정규화
    ├── config.py           # config 로딩 (.suh-template/config/)
    └── manifest.py         # 매니페스트 읽기/쓰기 (.cursor/skills/MANIFEST.json)
```

기존 `scripts/worktree_manager.py`와 동일 레벨에 패키지로 추가한다.

---

## CLI 커맨드 명세

### `get-output-path <skill_id>`

산출물 md 파일의 전체 경로를 반환한다. skill이 파일 저장 전 반드시 호출한다.

```bash
python3 -m suh_template.cli get-output-path plan
# stdout: docs/suh-template/plan/20260418_427_드롭다운_디자인_변경.md
```

옵션:
- `--title <제목>` — 제목을 직접 지정 (title_not_found fallback 시 재호출용)

경로 결정 순서:
1. **날짜**: 오늘 날짜 `YYYYMMDD`
2. **번호**:
   - 현재 작업 디렉토리 경로에서 `YYYYMMDD_숫자_제목` 패턴 추출 → 이슈번호
   - 없으면 git 브랜치명에서 숫자 추출
   - 둘 다 있고 다르면 → stderr `[WARN]` 출력 후 worktree 우선 사용
   - 둘 다 없으면 → `[WARN] issue_number_not_found` + 그날 누적순번(3자리) fallback
3. **제목**:
   - worktree 폴더명에서 제목 부분 추출 시도
   - 없거나 `--title` 없으면 → stderr `[WARN] title_not_found` + `untitled` fallback
4. **누적순번**: `docs/suh-template/<skill_id>/` 내 오늘 날짜로 시작하는 파일 수 + 1, 3자리 패딩

---

### `get-issue-number`

현재 컨텍스트에서 이슈 번호만 반환한다.

```bash
python3 -m suh_template.cli get-issue-number
# stdout: 427  (없으면 빈 문자열)
# exit: 0 (없어도 에러 아님)
```

---

### `get-next-seq <skill_id>`

해당 skill 폴더에서 오늘 날짜 기준 다음 누적순번을 반환한다.

```bash
python3 -m suh_template.cli get-next-seq plan
# stdout: 001
```

---

### `normalize-title <제목>`

제목 문자열을 파일명 안전 형식으로 정규화한다.

```bash
python3 -m suh_template.cli normalize-title "드롭다운 디자인 변경"
# stdout: 드롭다운_디자인_변경
```

규칙:
- 공백 → `_`
- 한글/영문/숫자/언더스코어만 허용 (나머지 제거)
- 최대 50자 (초과 시 truncate)

---

### `config-get <skill_id> <key>`

skill별 config 파일에서 특정 키의 값을 반환한다.

```bash
python3 -m suh_template.cli config-get issue github_repo
# stdout: https://github.com/Cassiiopeia/RomRom
```

config 파일 위치: `.suh-template/config/<skill_id>.config.json`

---

## 에러 처리 명세

### 출력 형식

```
# stdout: 결과값만 (AI나 스크립트가 파싱하기 쉽도록 순수 값만)
# stderr: [LEVEL] <command>: <한국어 설명> (<error_code>)
# exit:   0 (성공 또는 WARN) / 1 (ERROR)
```

### 에러 코드 목록

| 코드 | 레벨 | 상황 | AI 대응 |
|------|------|------|---------|
| `git_not_found` | ERROR | git 저장소가 아님 | 사용자에게 git init 안내 후 중단 |
| `issue_number_not_found` | WARN | 이슈번호 추출 실패 | 누적순번 fallback 사용, 사용자에게 안내 |
| `title_not_found` | WARN | 제목 추출 실패 | AI가 컨텍스트로 제목 생성 후 `--title`로 재호출 |
| `skill_id_invalid` | ERROR | 존재하지 않는 skill_id | 사용 가능한 skill_id 목록 stderr 출력 |
| `config_not_found` | ERROR | config 파일 없음 | .example 파일로 초기화 안내 |
| `python_version_error` | ERROR | Python 3.8 미만 | 버전 업그레이드 안내 |

### 예시

```bash
# 성공
$ python3 -m suh_template.cli get-output-path plan
docs/suh-template/plan/20260418_427_드롭다운_디자인_변경.md
# exit: 0

# WARN (fallback 사용, 결과는 반환)
$ python3 -m suh_template.cli get-output-path plan
[WARN] get-output-path: 이슈 번호를 찾을 수 없어 누적순번으로 대체합니다. (issue_number_not_found)
docs/suh-template/plan/20260418_001_드롭다운_디자인_변경.md
# exit: 0

# ERROR (결과 없음)
$ python3 -m suh_template.cli get-output-path plan
[ERROR] get-output-path: git 저장소를 찾을 수 없습니다. (git_not_found)
# exit: 1
```

---

## `skills/references/doc-output-path.md` 내용

8개 skill의 SKILL.md가 참조하는 공통 reference 문서 내용:

```markdown
# 산출물 경로 규칙

산출물 md 저장 전 반드시 아래 커맨드로 경로를 받아라:

\`\`\`bash
python3 -m suh_template.cli get-output-path <skill_id>
\`\`\`

## 실패 시 대응

- exit 1 + `title_not_found` (WARN) → AI가 컨텍스트로 제목 생성 후
  \`python3 -m suh_template.cli get-output-path <skill_id> --title "제목"\` 재호출
- exit 1 + `git_not_found` (ERROR) → 사용자에게 알리고 중단
- [WARN] 출력 + exit 0 → fallback 경로 그대로 사용, 사용자에게 안내

## 디렉토리 자동 생성

경로를 받은 뒤 파일 쓰기 전:

\`\`\`bash
mkdir -p "$(dirname "<받은 경로>")"
\`\`\`
```

---

## 적용 대상 Skill (Sub-project #2에서 처리)

이 헬퍼를 사용하도록 SKILL.md를 업데이트할 skill 목록:

| Skill | 카테고리 |
|-------|---------|
| `analyze` | analysis |
| `plan` | analysis |
| `design-analyze` | analysis |
| `refactor-analyze` | analysis |
| `troubleshoot` | analysis |
| `report` | report |
| `ppt` | report |
| `review` | report |

---

## 결정 사항

| 항목 | 결정 |
|------|------|
| 위치 | `scripts/suh_template/` 패키지 |
| 호출 방식 | `python3 -m suh_template.cli <command>` |
| Python 버전 | 3.8+, 표준 라이브러리만 |
| 외부 의존성 | 없음 |
| 에러 형식 | stderr: `[LEVEL] 커맨드: 설명 (error_code)`, exit 0/1 |
| Skill 연동 | `skills/references/doc-output-path.md` 참조 문서로 통일 |
| 크로스 플랫폼 | `pathlib.Path` 사용으로 Mac/Windows 동일 동작 |
