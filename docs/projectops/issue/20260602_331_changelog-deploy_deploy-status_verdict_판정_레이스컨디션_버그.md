# 🔥[긴급]❗[버그][Skills] changelog-deploy `deploy-status` verdict 판정이 워크플로우 in_progress 시점 race로 오판되어 본문이 반복 사라지는 현상

라벨: 긴급, 작업전
담당자: Cassiiopeia

📝 현재 문제점
---

`suh-changelog-deploy` 스킬로 deploy PR을 생성한 직후 `changelog_cli.py deploy-status`가 `verdict: missing_coderabbit_summary`를 잘못 반환하는 현상이 반복 발생한다. 사용자 관점: "PR 본문이 계속 사라진다".

### 재현 흐름 (실측, 2026-06-02 PR #330)

1. 스킬이 `create-pr`로 본문에 `Summary by CodeRabbit` 포함한 PR 생성 → ✅ 본문 정상 포함
2. `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` 워크플로우가 `pull_request_target.opened`로 트리거
   - step 2 "PR 본문 초기화"가 `Summary by CodeRabbit` 감지 → `already_found=true` → 본문 보존
   - step 6 "PR 제목 즉시 변경"이 `PATCH /pulls/{n}` 호출로 title 변경
   - step 8 "CodeRabbit Summary 감지 (폴링)" — `already_found=true`라 즉시 break
3. 스킬이 7단계 검증으로 `deploy-status` 호출
   - GitHub API 응답 시점이 step 6 PATCH와 겹치거나, CodeRabbit이 자체 Summary 댓글을 추가로 작성하면서 PR body가 일시적으로 비거나 갱신 중인 상태로 잡힘
   - `pr.body`가 빈 문자열로 잡혀 `"Summary by CodeRabbit" in pr.body`가 `False`
4. `changelog_cli.py:131` — `elif not has_summary:` 분기 진입 → `verdict = missing_coderabbit_summary`
5. agent가 verdict 보고 fix 모드 / `update-pr` 본문 재주입 실행
6. 그 사이 워크플로우 다른 step·CodeRabbit이 또 본문 갱신 → race 반복
7. 사용자에게는 "본문이 계속 사라지는" 현상으로 보임

### 근본 원인 — verdict 판정 로직 결함

`skills/suh-changelog-deploy/scripts/changelog_cli.py:121~136`

- **결함 1**: `has_summary == False`이면 워크플로우 상태와 무관하게 무조건 `missing_coderabbit_summary` 판정. 워크플로우가 `in_progress` 중이면 본문이 잠깐 비어도 정상 진행 중인데, 같은 verdict로 분류됨
- **결함 2**: `workflow["status"]`(`in_progress`/`queued`/`completed`) 확인이 없음. `conclusion`만 보는데 in_progress 중에는 conclusion이 `None`이라 어느 분기도 못 잡고 `not has_summary` 분기로 떨어짐
- **결함 3**: `pr.get("body", "")`가 빈 문자열을 반환할 때, 그것이 "워크플로우가 비웠다"인지 "API가 잠시 빈 값을 줬다"인지 구분 불가. 단일 호출 결과만 보고 판정하므로 race 취약
- **결함 4**: PR이 이미 `merged`인 케이스 직전이라 mergeable_state가 `unstable`/`clean`으로 빠르게 전이되는 중인데, has_summary가 한 시점 빈 값으로 잡히면 직전 단계로 잘못 후퇴 권유

### 부수 피해

- agent가 불필요한 `update-pr` 호출로 워크플로우 트리거 부담 증가
- 사용자가 "버그 같은데?"라 인지해 신뢰도 하락
- fix 모드로 PR을 닫고 새로 여는 경로로 진입 시 워크플로우가 한 번 더 트리거되어 또 다른 race 가능성

🛠️ 해결 방안 / 제안 기능
---

### 1. `not has_summary` 분기에 워크플로우 진행 상태 가드 추가

`changelog_cli.py:cmd_deploy_status` 판정 분기를 다음 우선순위로 재배치:

```
1. pr.merged == True              → "merged"
2. mergeable_state ∈ dirty/blocked/behind → "conflict"
3. workflow.conclusion == "failure"        → "workflow_failed"
4. workflow.status ∈ in_progress/queued    → "waiting_for_automerge"  (NEW: in_progress면 has_summary 무관)
5. not has_summary                          → "missing_coderabbit_summary"
6. else                                     → "waiting_for_automerge"
```

핵심: **워크플로우가 진행 중이면 has_summary가 일시적으로 false여도 정상 대기로 본다.** 워크플로우가 끝났는데도 has_summary가 false일 때만 진짜 본문 초기화 사고로 본다.

### 2. body race 완화 — 짧은 재조회 보강 (선택적)

`not has_summary` 분기 진입 직전, PR detail을 한 번 더 즉시 재조회해 두 번 연속 false일 때만 missing 판정. 한 번만 false면 race 가능성이 크므로 `waiting_for_automerge`로 양보. 단일 호출 race로 인한 오판을 줄인다.

### 3. agent 행동 규칙 보강 — `missing_coderabbit_summary` 받았을 때 즉시 update-pr 호출하지 않는다

`skills/suh-changelog-deploy/SKILL.md` 7단계 라우팅 표를 갱신:

- `missing_coderabbit_summary` 받으면 **즉시 update-pr 호출하지 않고**, 60초 후 재확인. 두 번 연속 같은 verdict일 때만 fix 모드 안내. 한 번이면 race 가능성을 우선 가정한다.

### 4. 워크플로우 step 간 race 검토 (별도 진단)

`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`의 step 2(PR 본문 초기화) → step 6(PR 제목 변경) → step 8(폴링) 흐름에서 step 6의 title PATCH가 body 필드를 의도치 않게 영향 주는지 확인. GitHub API PATCH는 명시한 필드만 변경하지만, 동시에 다른 PATCH가 들어오면 last-writer-wins. CodeRabbit 봇이 자체 Summary 본문을 갱신할 때 스킬·워크플로우 PATCH와 겹치면 본문 덮어쓰기 발생 가능.

⚙️ 작업 내용
---

- `skills/suh-changelog-deploy/scripts/changelog_cli.py:cmd_deploy_status` verdict 판정 분기 재배치 (워크플로우 status 가드)
- `skills/suh-changelog-deploy/SKILL.md` 7단계 verdict 라우팅 표 갱신 (missing 받으면 즉시 fix 금지, 1회 재확인 후 분기)
- 회귀 시나리오 검증
  - 워크플로우 in_progress 중 has_summary=false → `waiting_for_automerge` 반환되는지
  - 워크플로우 completed/success + has_summary=true → `merged` 또는 `waiting_for_automerge` 반환
  - 워크플로우 없음 + has_summary=false → `missing_coderabbit_summary` 유지 (진짜 fix 케이스)

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
- 프론트엔드: -
- 디자인: -
