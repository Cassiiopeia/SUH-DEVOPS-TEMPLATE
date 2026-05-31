# deploy-status 검증 서브커맨드 설계

작성일: 2026-05-31
대상 스킬: `cassiiopeia:suh-changelog-deploy`

## 문제

`suh-changelog-deploy` 스킬은 deploy PR 생성(6단계)에서 끝나고, **PR이 실제로 automerge 됐는지 확인하는 단계가 없다.** 그래서 agent가 매번 `/tmp`에 일회용 Python(`check_automerge.py`, `verify_deploy.py`, `watch_pr740.py`, `diagnose_pr740.py`)을 즉석 생성해 상태를 조회한다 — 매 배포마다 수천 토큰 낭비, 코드 중복, `sleep` 차단 충돌.

## 목표

이번 대화에서 흩어져 만들던 4개 일회용 스크립트를 **재사용 가능한 단일 서브커맨드 하나**로 통합한다. agent는 인자(owner/repo)만 주고, 반환되는 종합 JSON의 `verdict`/`summary`/`next`를 보고 다음 행동을 판단한다.

## 설계 원칙 (CLAUDE.md "Python 행동 스크립트 표준" 준수)

1. **위치**: 기존 `scripts/suh_template/suh_command.py`에 `deploy-status` 서브커맨드 추가. 새 파일 안 만든다 — `actions` 서브커맨드와 동일한 MCP-style 패턴에 합류.
2. **출력은 언제나 JSON** — `_emit()` 사용. `ok` + 데이터 + `verdict` + `summary` + `next` 힌트.
3. **단발 조회 — sleep 금지**. 1회 조회 후 즉시 반환. 재확인/대기는 agent가 `ScheduleWakeup`으로 자기 페이스 제어.
4. **입력 해석은 agent, 실행은 .py**. 단, `--pr` 생략 시 open deploy PR 자동 탐색은 커맨드가 처리(이게 매번 즉석 스크립트로 하던 일).
5. **표준 라이브러리만** — `gh_client._request`(urllib 기반) 재사용. 추가 의존성 0.
6. **PAT**: `_get_pat(owner, repo)` 기존 로직 재사용 (GITHUB_PAT 환경변수 → config.json).

## 입력 계약

```bash
GITHUB_PAT="..." PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command \
  deploy-status <owner> <repo> [--pr PR_NUM] [--base deploy]
```

- `<owner> <repo>`: 필수.
- `--pr PR_NUM`: 생략 시 `base=deploy`인 open PR을 자동 탐색. open PR이 없으면 `verdict=no_pr`.
- `--base BRANCH`: 기본 `deploy`. PR 탐색 및 deploy 브랜치 반영 확인의 대상 브랜치.

agent는 PR 번호를 몰라도 owner/repo만 주면 된다.

## 반환 JSON 구조

```json
{
  "ok": true,
  "pr": {
    "number": 740,
    "state": "open",
    "merged": false,
    "mergeable_state": "clean",
    "has_coderabbit_summary": true,
    "head_sha": "29df6205...",
    "url": "https://github.com/.../pull/740"
  },
  "workflow": {
    "name": "AUTO-CHANGELOG-CONTROL",
    "status": "in_progress",
    "conclusion": null,
    "run_url": "https://github.com/.../actions/runs/123"
  },
  "deploy_branch": {
    "name": "deploy",
    "head_sha": "e8839805..."
  },
  "verdict": "waiting_for_automerge",
  "summary": "PR #740 open·clean, CodeRabbit 본문 있음, 워크플로우 진행 중 — automerge 대기.",
  "next": "deploy-status TEAM-ROMROM RomRom-BE --pr 740"
}
```

`pr`/`workflow`/`deploy_branch`는 조회 실패 시 해당 키가 `null`이 될 수 있다 (예: `no_pr`이면 `pr=null`). agent는 `verdict`+`summary`만으로도 판단 가능하고, 세부 필드는 필요할 때 참조.

## verdict 값과 agent 행동 매핑

| verdict | 조건 | summary 톤 | agent 다음 행동 |
|---------|------|-----------|----------------|
| `merged` | PR `merged=true` | ✅ automerge 완료 | 완료 안내, 종료 |
| `waiting_for_automerge` | PR open·mergeable clean·CodeRabbit 본문 O·워크플로우 in_progress 또는 미시작 | ⏳ 대기 | ~90초 후 `next`로 재확인 (ScheduleWakeup) |
| `missing_coderabbit_summary` | PR open인데 본문에 `Summary by CodeRabbit` 없음 | 🔧 본문 초기화됨(레이스컨디션) | fix 모드 안내 |
| `workflow_failed` | 연결된 AUTO-CHANGELOG-CONTROL run `conclusion=failure` | 🔧 워크플로우 실패 | fix 모드 + run_url 안내 |
| `conflict` | PR `mergeable_state`가 dirty/blocked/behind | ⚠️ 충돌/차단 | 충돌 해결 안내 |
| `no_pr` | open deploy PR 없음 | ℹ️ PR 없음 | deploy 브랜치 head로 머지 완료 여부 추정 안내 |

판정 우선순위(위→아래): `merged` → `conflict` → `workflow_failed` → `missing_coderabbit_summary` → `waiting_for_automerge`. PR 자체가 없으면 `no_pr`.

## 워크플로우 식별

`resolve_pr_runs`로 PR head_sha에 연결된 run 목록을 가져온 뒤, `name`에 `AUTO-CHANGELOG-CONTROL`이 포함된 run을 골라 `workflow` 필드를 채운다. 매칭 run이 없으면 `workflow=null`이고, 이 경우 워크플로우가 아직 트리거 안 된 것으로 보아 `waiting_for_automerge`로 간주.

## gh_client.py 변경

재사용:
- `_request` — 모든 API 호출.
- `resolve_pr_runs` — PR head_sha → 연결 run 목록.
- `_run_summary` — run 요약.

신규 헬퍼(3개):
- `get_pull_detail(owner, repo, pr_number, pat) -> dict`
  단일 PR 상세에서 `number/state/merged/mergeable_state/body/head_sha/url` 추출.
  (기존 `list_pulls`는 `body`·`mergeable_state` 없음, `resolve_pr_runs`는 PR을 가져오지만 이 필드들을 노출 안 함)
- `find_open_pr_by_base(owner, repo, base, pat) -> dict | None`
  `state=open` PR 중 `base.ref == base`인 첫 PR의 상세를 반환. `--pr` 생략 시 사용.
- `get_branch_head(owner, repo, branch, pat) -> str | None`
  `git/ref/heads/{branch}`로 deploy 브랜치 HEAD SHA 조회. 브랜치 없으면 None.

`has_coderabbit_summary`는 PR `body`에 문자열 `Summary by CodeRabbit` 포함 여부로 판정 (gh_client는 raw 데이터만, 판정은 suh_command에서).

## suh_command.py 변경

- `cmd_deploy_status(args)` 함수 추가 — `cmd_actions`와 동일한 구조(인자 파싱 → PAT → 헬퍼 호출 → `_emit`).
- 커맨드 매핑 dict에 `"deploy-status": cmd_deploy_status` 등록.
- verdict 판정 로직은 이 함수 안에 둔다(데이터는 gh_client, 판정은 command 레이어 — 기존 `actions`의 `next` 힌트 생성과 같은 분리).

## SKILL.md 변경

- **deploy 모드**: 현재 7단계(결과 안내)를 8단계로 밀고, 새 **7단계: automerge 검증** 삽입.
  PR 생성 직후 `deploy-status <owner> <repo> --pr <PR_NUMBER>` 호출 → verdict 표로 라우팅.
  - `merged` → 8단계 완료 안내
  - `waiting_for_automerge` → ScheduleWakeup ~90초 후 `next` 재확인 (sleep 금지 명시)
  - `missing_coderabbit_summary`/`workflow_failed`/`conflict` → fix 모드 또는 해당 안내
- **fix 모드**: 1단계(현재 PR 상태 확인)를 `deploy-status` 호출로 교체. curl + grep 즉석 파싱 제거.
- **주의사항**에 "PR 생성 후 반드시 deploy-status로 검증. /tmp 즉석 스크립트 생성 금지" 명시.

## 테스트

`scripts/tests/`에 기존 테스트 패턴(`test_cli.py`, `test_cli_github.py`)을 따라:
- `gh_client`의 3개 신규 헬퍼: URL·파싱 단위 테스트 (urllib monkeypatch).
- `cmd_deploy_status`의 verdict 판정: 6개 verdict 각각에 대해 입력 dict → 기대 verdict 검증 (네트워크 mock).

## 범위 밖 (YAGNI)

- 커맨드 내부 폴링/대기 — agent의 ScheduleWakeup 책임.
- deploy 브랜치 "특정 변경분 반영 여부"의 파일 단위 diff — `deploy_branch.head_sha`만 제공하고, 세부 비교는 필요 시 agent가 별도 판단. (이번 대화의 `verify_deploy.py`가 과하게 파일 내용까지 본 것은 재현 안 함 — head_sha 노출로 충분)
- `actions` 서브커맨드와의 통합 — 별개 커맨드로 유지(관심사 분리).
