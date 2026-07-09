# ❗[버그][Skills] create-issue 라벨 존재 여부 미검증으로 GitHub API 422 에러 발생

- **라벨**: 작업전
- **담당자**: 

---

🗒️ 설명
---

`create-issue` CLI 커맨드가 라벨 존재 여부를 사전에 검증하지 않아, 레포에 없는 라벨명을 전달하면 GitHub API가 422 Validation Failed를 반환합니다.

예: `작업전` 라벨이 없는 레포에 `작업전`을 전달하거나, `작업 전`(띄어쓰기 포함)과 `작업전` 불일치 시 발생합니다.

🔄 재현 방법
---

1. 스킬에서 `create-issue` 호출 시 라벨을 `작업전`으로 전달
2. 대상 레포에 해당 라벨이 없거나 이름이 다를 경우 (예: `작업 전`)
3. GitHub API 422 응답:
   ```
   [ERROR] create-issue: GitHub API 422: Validation Failed (github_api_422)
   ```

📸 참고 자료
---

에러 로그:
```
[ERROR] create-issue: GitHub API 422: Validation Failed (github_api_422)
```

문제 코드 (`gh_client.py` - `create_issue`):
```python
# 라벨 검증 없이 바로 API 호출
payload: dict = {"title": title, "body": body, "labels": labels}
data = _request("POST", f"{_API_BASE}/repos/{owner}/{repo}/issues", payload, pat)
```

✅ 예상 동작
---

- 이슈 생성 전 레포의 실제 라벨 목록을 조회하여 존재하는 라벨만 전달
- 존재하지 않는 라벨은 무시하거나 경고 메시지 출력 후 라벨 없이 이슈 생성

⚙️ 환경 정보
---

- **OS**: macOS 14.x (Darwin 24.1.0)
- **Claude Code**: v2.1.114
- **플러그인 버전**: cassiiopeia 2.9.19

🙋‍♂️ 담당자
---

- **백엔드**: 이름
- **프론트엔드**: 이름
- **디자인**: 이름
