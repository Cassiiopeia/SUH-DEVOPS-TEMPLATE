# 🚀[기능개선][Skills] changelog-deploy 스킬 ↔ AUTO-CHANGELOG-CONTROL 워크플로우 본문 관리 책임 분리 (라벨 기반 컨트랙트)

라벨: 작업전
담당자: Cassiiopeia

📝 현재 문제점
---

`suh-changelog-deploy` 스킬과 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` 워크플로우가 **같은 자원(PR body)을 동시 수정**하는 구조라 race가 본질적으로 해결되지 않는다.

- 스킬: PR을 본문에 `Summary by CodeRabbit` 포함해 생성 (`create-pr` body_file 전달)
- 워크플로우 step 2: PR opened 트리거 직후 body 조회 → Summary 있으면 보존, 없으면 초기화
- 워크플로우 step 6: PR title 변경 (PATCH /pulls/{n})
- CodeRabbit 봇: 자체 Summary 본문 갱신

이 4개 주체가 PR opened 직후 약 30초 안에 모두 PATCH /pulls를 호출한다. GitHub API는 last-writer-wins라 어느 시점에 누가 마지막에 썼는지에 따라 본문 상태가 흔들린다.

기존 fix(이슈 #331)와 retry(워크플로우 step 2)는 race **빈도를 줄이는** 패치이지 race 자체를 없애는 것이 아니다. 본질 해결은 두 주체의 책임을 분리하는 것이다.

🛠️ 해결 방안 / 제안 기능
---

**라벨 기반 컨트랙트로 책임 분리**.

스킬이 본문을 직접 채워 PR을 만들었음을 PR 라벨(예: `release-notes:ready`)로 명시한다. 워크플로우는 그 라벨이 있는 PR은 본문을 절대 건드리지 않는다.

### 변경

1. `skills/suh-changelog-deploy/scripts/changelog_cli.py` `create-pr`
   - PR 생성 직후 라벨 `release-notes:ready` 부여
2. `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`
   - step 2(PR 본문 초기화) 가장 먼저 PR 라벨 조회
   - `release-notes:ready` 라벨이 있으면 본문 검사·초기화 step 자체를 skip + `already_found=true`로 설정
   - 라벨이 없는 PR(수동 생성·다른 도구가 만든 PR)에 한해서만 기존 본문 초기화 로직 적용
3. `.github/sync-issue-labels.yml`(혹은 라벨 동기화 워크플로우)에 `release-notes:ready` 라벨 등록
4. `skills/suh-changelog-deploy/SKILL.md` 6단계 본문에 라벨 부여 절차 명시

### 효과

- 스킬이 만든 PR은 워크플로우가 본문에 손대지 않음 → race 0
- 수동 생성 PR이나 다른 스킬이 만든 PR은 기존 로직 그대로 → 호환성 유지
- 라벨이라는 명시적 신호로 스킬·워크플로우 책임 분리 — 묵시적 본문 검사보다 견고

### 비범위

- CodeRabbit 봇의 자체 Summary 작성은 별 문제 — 본문에 이미 Summary 있으면 봇이 덧붙이는 정도라 영향 작음
- 이슈 #331 fix(verdict 판정 race 가드)는 그대로 유지 — 라벨 컨트랙트가 더 근본이지만 보호선으로 둠

⚙️ 작업 내용
---

- `skills/suh-changelog-deploy/scripts/changelog_cli.py:cmd_create_pr` — PR 생성 후 라벨 부여 호출 추가
- `scripts/common/gh_client.py` — `add_pr_labels(owner, repo, pr_num, labels[])` 헬퍼 추가 (없으면)
- `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` step 2 — 라벨 가드 분기 추가
- `.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` — 동일하게 수정
- `.github/labels/*.yml`(라벨 동기화 파일) — `release-notes:ready` 라벨 정의 추가
- `skills/suh-changelog-deploy/SKILL.md` 6단계 — 라벨 부여 절차 명시
- 회귀 검증
  - 스킬로 deploy PR 만들면 본문 보존되는지
  - 수동으로 본문 없는 PR 만들면 기존대로 초기화되는지

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
- 프론트엔드: -
- 디자인: -
