# [설계] GitHub 이슈 생성 시 본문 검증 강화 및 본문 사후 수정(복구) 지원

* **작성일**: 2026-07-07
* **상태**: 승인 대기 (User Review)

---

## 1. 개요 및 배경

현재 `issue` 및 `github` 스킬에서 사용하는 CLI 도구들(`issue_cli.py`, `github_cli.py`)은 이슈 본문 생성 실패 시 빈 본문(`""`)으로 조용히 처리해 버립니다(Silent Fallback). 이로 인해 특히 Windows 한글 경로 깨짐 등의 환경적 요인으로 본문 파일 로드에 실패했을 때, AI나 사용자에게 아무런 에러 없이 빈 이슈가 등록됩니다. 

또한 이미 등록된 빈 이슈를 사후에 복구하려 해도 `update-issue` 명령어가 이슈 본문(`body`) 수정을 인자로 받지 않아 CLI 수준에서 사후 복구할 방법이 부재합니다.

이 문제를 해결하고, 에러 발생 시 AI가 반환된 JSON 코드를 보고 명확하게 복구하거나 사용자에게 조치 가이드를 제공할 수 있도록 규격을 표준화합니다.

---

## 2. 요구사항 및 성공 기준 (DoD)

1. **이슈 생성 시 강력한 파일 검증**:
   - `create-issue` 시 지정한 `body_file`이 물리적으로 존재하지 않는 경우, 성공 처리하지 않고 명확한 기계 판독용 에러 코드와 함께 실패를 반환합니다.
2. **이슈 수정 시 본문 변경 지원**:
   - `issue_cli.py` 및 `github_cli.py` 의 `update-issue` 명령어에 `--body-file` 파라미터를 추가하여, 파일 기반으로 이슈 본문을 안전하게 업데이트할 수 있도록 합니다.
3. **AI 친화적인 기계 판독성 극대화 (핵심)**:
   - 오류가 발생하면 무조건 `{"ok": false, "code": "SNAKE_CASE_CODE", "error": "인간용 메시지"}` 형태로 균일하게 응답을 표준화합니다.
   - AI가 응답 JSON의 `ok` 필드 및 `code` 필드만으로 즉시 오류 타입을 분기할 수 있게 합니다.

---

## 3. 세부 설계 및 표준 에러 응답 규격

### 3.1 에러 반환 구조 규격 (Standard Error Response)

AI가 가장 쉽고 직관적으로 대응할 수 있도록 에러 반환 시 항상 아래 구조를 강제합니다.

```json
{
  "ok": false,
  "code": "body_file_not_found",
  "error": "본문 파일이 존재하지 않습니다: C:\\한글경로\\temp_body.md",
  "path_attempted": "C:\\한글경로\\temp_body.md"
}
```

* **`ok`**: 무조건 `false`
* **`code`**: 기계(AI) 분기용 고유 문자열. 아래 정의된 표준 코드 중 하나를 반환합니다.
* **`error`**: 사용자 대화창에 보여줄 수 있는 자연어 한국어 에러 메시지.

#### **에러 코드 정의 테이블**
| 에러 코드 (`code`) | 의미 | AI 권장 후속 행동 (Next Action) |
|:---|:---|:---|
| `body_file_not_found` | 지정한 이슈/PR 본문 파일이 경로에 없음 | Windows 환경 한글 경로 깨짐을 의심하고, 임시 영문 경로 파일 생성을 재시도하거나 사용자에게 확인 요청 |
| `missing_pat` | GitHub Personal Access Token이 누락됨 | 사용자에게 PAT 설정 가이드를 표시하고 `/issue` 등의 스킬로 유도 |
| `github_api_404` | 지정한 이슈 번호나 레포지토리가 존재하지 않음 | 이슈 번호 또는 레포지토리 이름이 잘못되었는지 검사하고 정정 유도 |
| `github_api_403` | 권한 부족 (Collaborator 권한 부재 등) | PAT 권한 범위(scope) 및 레포지토리 쓰기 권한이 유효한지 사용자에게 안내 |
| `github_api_422` | API 유효성 검사 실패 (유효하지 않은 필드 등) | 전송한 데이터 규격을 재조정하고 수정 요청 |

---

## 4. 컴포넌트별 구현 사양

### 4.1 `skills/issue/scripts/issue_cli.py`

#### **`create-issue` 서브커맨드**
1. `args.body_file`의 존재 여부를 물리적으로 엄격하게 체크합니다.
2. 파일이 없으면 `body_file_not_found` 코드로 즉시 실패 처리합니다.
3. 성공 시 응답에 `"body_length": len(body)`를 포함시켜 AI가 정상 저장 크기를 크로스체크할 수 있게 만듭니다.

```python
def cmd_create_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    
    body_path = Path(args.body_file)
    if not body_path.exists():
        return emit({
            "ok": False, 
            "code": "body_file_not_found", 
            "error": f"본문 파일이 존재하지 않습니다: {args.body_file}",
            "path_attempted": str(body_path.resolve())
        })
    
    body = body_path.read_text(encoding="utf-8")
    # ... (생략) ...
    # 성공 응답 추가 필드
    out = {**result, "summary": f"이슈 #{result.get('number')} 생성 완료", "body_length": len(body)}
```

#### **`update-issue` 서브커맨드**
1. `argparse` 파서에 `--body-file` 인자를 추가합니다.
2. `cmd_update_issue` 핸들러에서 `args.body_file`이 지정된 경우:
   * 파일 미존재 시 `body_file_not_found` 에러를 반환합니다.
   * 존재 시 UTF-8로 읽어 `body` 값을 구한 뒤 `update_issue(..., body=body)`로 보냅니다.
   * 지정되지 않은 경우 기존과 마찬가지로 `body=None`으로 넘겨 수정하지 않습니다.

```python
def cmd_update_issue(args) -> int:
    # ... (생략) ...
    body = None
    if args.body_file:
        body_path = Path(args.body_file)
        if not body_path.exists():
            return emit({
                "ok": False,
                "code": "body_file_not_found",
                "error": f"수정용 본문 파일이 존재하지 않습니다: {args.body_file}",
                "path_attempted": str(body_path.resolve())
            })
        body = body_path.read_text(encoding="utf-8")
        
    try:
        result = update_issue(
            args.owner, args.repo, args.number, pat,
            title=args.title, body=body, state=args.state, labels=labels, assignees=assignees,
        )
```

---

### 4.2 `skills/github/scripts/github_cli.py`

#### **`update-issue` 서브커맨드**
`issue_cli.py`와 마찬가지로 `--body-file` 인자를 Argument Parser에 수용하고, 파일 내용을 읽어 `body` 인자로 사후 복구할 수 있는 로직을 동일 구조로 이식합니다.

```python
# build_parser 안의 p_ui 영역
p_ui.add_argument("--body-file", help="본문 파일 경로")
```

---

## 5. 검증 계획 (Testing Plan)

1. **파일 미존재 실패 검증**:
   * 가상의 존재하지 않는 파일 경로를 지정하여 `create-issue` 및 `update-issue`를 실행하고, 정확히 `"code": "body_file_not_found"` 오류가 반환되는지 확인합니다.
2. **정상 생성 검증**:
   * 유효한 임시 영문 파일 경로를 지정하여 `create-issue`를 수행하고, 이슈가 정상 생성되며 `"body_length"` 필드가 정상 반환되는지 확인합니다.
3. **사후 복구(수정) 검증**:
   * 생성된 테스트용 이슈 번호를 타겟으로 하여 `--body-file`을 사용하여 수정하고, 실제 GitHub 상에서 본문이 잘 업데이트되는지 확인합니다.
