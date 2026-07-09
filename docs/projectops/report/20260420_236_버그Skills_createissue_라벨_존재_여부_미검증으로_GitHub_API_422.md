# 구현 보고서 — #236 create-issue 라벨 존재 여부 미검증으로 GitHub API 422 에러 발생

**이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/236
**작업일**: 2026-04-20
**커밋**: `fcbd957`

---

## 문제 요약

`create-issue` CLI 커맨드가 라벨 존재 여부를 사전에 검증하지 않아,
레포에 없는 라벨명(예: `작업전` vs `작업 전` 불일치)을 전달하면 GitHub API 422 Validation Failed 에러 발생.

## 수정 내용

### `scripts/suh_template/gh_client.py`

`list_labels()` 함수를 신규 추가하고, `create_issue()` 내에서 이슈 생성 전 레포 라벨 목록을 사전 조회하여 존재하지 않는 라벨을 필터링.

```python
def list_labels(owner: str, repo: str, pat: str) -> list[str]:
    """레포의 라벨 이름 목록을 반환한다."""
    items = _request("GET", f"{_API_BASE}/repos/{owner}/{repo}/labels?per_page=100", None, pat)
    return [item["name"] for item in items]


def create_issue(...) -> dict:
    # 존재하지 않는 라벨은 422를 유발하므로 사전에 필터링
    if labels:
        existing = list_labels(owner, repo, pat)
        labels = [l for l in labels if l in existing]
    ...
```

### 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `scripts/suh_template/gh_client.py` | `list_labels()` 함수 추가, `create_issue()`에 라벨 사전 필터링 로직 추가 |

## 검증

- RomRom-FE 레포(`작업 전` 라벨)에서 `작업전`으로 이슈 생성 시 422 없이 정상 생성 확인
- 존재하는 라벨만 payload에 포함되어 전달됨
