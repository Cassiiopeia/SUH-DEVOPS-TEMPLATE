# 산출물 경로 규칙

이 reference는 `analyze`, `plan`, `design-analyze`, `refactor-analyze`, `troubleshoot`, `report`, `ppt`, `review` skill이 md 산출물을 저장할 때 반드시 따르는 규칙이다.

## 저장 전 경로 계산

산출물 md 저장 전 반드시 아래 커맨드를 실행해 경로를 받아라.  
**`PYTHONPATH`는 항상 필수다** (`common-rules.md` → suh_template CLI 실행 규칙 참조):

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli get-output-path <skill_id>
```

반환값 예시:
- `docs/suh-template/plan/20260418_427_드롭다운_디자인_변경.md`
- `docs/suh-template/analyze/20260418_001_초기_분석.md`

## 실패 시 대응

| 상황 | 대응 |
|------|------|
| `[WARN] title_not_found` (exit 0) | AI가 작업 컨텍스트로 제목 생성 후 `--title "제목"` 옵션으로 재호출 |
| `[WARN] issue_number_not_found` (exit 0) | fallback 경로 그대로 사용, 사용자에게 "이슈번호 없어서 순번 사용" 안내 |
| `[WARN] issue_number_mismatch` (exit 0) | fallback 경로 그대로 사용, 사용자에게 불일치 안내 |
| `[ERROR] git_not_found` (exit 1) | 사용자에게 "git 저장소가 아닙니다" 알리고 중단 |

## 디렉토리 자동 생성

경로를 받은 뒤 파일 쓰기 전 디렉토리를 생성한다:

**Mac/Linux:**
```bash
mkdir -p "$(dirname "<받은 경로>")"
```

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force -Path (Split-Path "<받은 경로>")
```
