# changelog-deploy 릴리스 노트 레이스컨디션 해결

## 개요

`suh-changelog-deploy` 스킬이 작성한 릴리스 노트가 deploy PR 본문에서 사라지고 CodeRabbit Summary 10분 대기로 빠지던 문제를 해결했다. 스킬과 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` 워크플로우 간 실행 순서 충돌이 원인이었으며, 워크플로우는 건드리지 않고 스킬의 단계 순서만 재배치해 근본 해결했다.

## 변경 사항

### deploy 모드 단계 재배치
- `skills/suh-changelog-deploy/SKILL.md`: 기존 `PR 생성(빈 본문) → 커밋 분석 → 릴리스 노트 작성 → 본문 업데이트` 순서를 `커밋 분석(4단계) → 릴리스 노트 작성(5단계) → 릴리스 노트 본문 담아 PR 생성(6단계)` 순으로 변경
- 기존 open PR이 있으면 재사용해 `update-pr`로 본문 갱신, 없으면 `create-pr`의 `body_file` 인자에 릴리스 노트 파일을 넘겨 본문 포함 PR 생성

### fix 모드 단계 재배치
- `skills/suh-changelog-deploy/SKILL.md`: fix 모드도 동일 원칙 적용. `커밋 분석(fix 3단계) → 릴리스 노트 작성(fix 4단계) → 본문 담아 PR 생성(fix 5단계)` 순으로 변경

### 레이스컨디션 방지 안내 추가
- `skills/suh-changelog-deploy/SKILL.md`: 3단계 직후와 주의사항 섹션에 "PR 생성을 맨 마지막에 둔다"는 원칙과 그 이유를 명시

## 주요 구현 내용

문제의 핵심은 워크플로우의 PR 본문 초기화 step(`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` 49~72줄)이다. 이 step은 무조건 본문을 지우는 것이 아니라, 본문에 `Summary by CodeRabbit`이 있으면 초기화를 건너뛰는 조건부 로직을 이미 갖고 있다.

```
PR opened 트리거 → 본문 조회
  - "Summary by CodeRabbit" 있음 → 초기화 건너뜀, 즉시 진행
  - 없음 → 본문 초기화
```

기존 스킬은 PR을 빈 본문으로 먼저 만들었기 때문에, 워크플로우가 PR 생성 직후 본문을 확인하는 순간 비어 있어 초기화가 실행됐다. 그 뒤 스킬이 릴리스 노트를 써도 이미 워크플로우는 "Summary 없음"으로 판단해 10분 폴링에 들어간 상태였다.

해결책은 **PR이 처음부터 릴리스 노트를 담고 태어나게** 하는 것이다. `cli.py`의 `create-pr`은 `body_file` 인자가 존재하는 경로면 그 내용을 본문으로 채운다(`cli.py:324`). 스킬이 릴리스 노트를 먼저 완성한 뒤 그 파일을 `body_file`로 넘겨 PR을 생성하면, 워크플로우가 본문을 확인하는 첫 순간 이미 `Summary by CodeRabbit`이 들어 있어 초기화를 건너뛴다. 워크플로우 코드는 한 줄도 수정하지 않았다.

## 주의사항

- 워크플로우(`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`)는 의도적으로 수정하지 않았다. 조건부 초기화 로직은 그대로 유효하다.
- 기존 open deploy PR이 있으면 닫지 않고 재사용한다. 새로 열면 워크플로우가 재트리거되어 본문 초기화 위험이 생긴다.
- 이 PR(#313)이 첫 실전 검증 케이스다. PR 본문이 워크플로우에 의해 초기화되지 않고 릴리스 노트가 유지되는지로 수정 효과를 확인할 수 있다.
