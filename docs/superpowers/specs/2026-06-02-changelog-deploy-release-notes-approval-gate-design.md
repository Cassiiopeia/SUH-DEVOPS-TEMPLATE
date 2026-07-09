# changelog-deploy 릴리스 노트 사용자 승인 게이트 설계

## 배경

현재 `changelog-deploy` 스킬은 5단계에서 릴리스 노트 파일을 작성한 직후 곧바로 6단계 PR 생성으로 진행한다. 사용자가 본문 내용을 검토할 기회 없이 자동으로 PR이 생성되므로, 다음 문제가 발생한다.

- 릴리스 노트가 사용자의 의도와 다르게 작성돼도 사용자가 개입할 시점이 없다.
- 잘못된 본문으로 PR이 생성되면 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` 워크플로우가 automerge를 진행해 운영 배포까지 그대로 흘러간다.
- 사용자가 추가로 PR 본문을 update하려 해도 워크플로우가 이미 본문을 기준으로 동작 중이라 레이스컨디션이 발생할 위험이 있다.

문서·SKILL.md 검토 결과 `브레인스토밍 도중 사용자가 "이 게이트를 추가했다"고 기억하던 변경 사항이 실제로는 어디에도 반영되지 않았음`을 확인했다 (git log·이슈·docs 전부 검색).

## 목표

- 릴리스 노트 작성 후 PR을 생성하기 직전에 사용자에게 본문을 보여주고 명시적 승인을 받는다.
- 단, "자리 비우고 자동화 원하는 사용자"는 별도 config로 게이트를 건너뛸 수 있어야 한다.
- 기본값은 안전한 쪽(수동 승인). 자동화를 원하면 명시적으로 켜야 한다.

## 비목표

- 워크플로우(`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL`) 변경 — 손대지 않는다.
- `changelog_cli.py` 등 Python 스크립트 변경 — 절차만 추가하고 코드는 그대로 둔다.
- 다른 스킬의 승인 게이트 일반화 — 이 PR은 changelog-deploy에만 적용한다.

## 설계

### Config 스키마

`~/.suh-template/config/config.json`의 `github` 섹션에 `changelog_deploy` 하위 객체를 추가한다.

```json
{
  "github": {
    "default_assignee": "...",
    "global_pat": "...",
    "changelog_deploy": {
      "auto_approve_release_notes": false
    },
    "repos": [
      {
        "name": "PickerPicker",
        "owner": "PickerPicker",
        "repo": "PickerPicker",
        "pat": null,
        "default": false,
        "changelog_deploy": {
          "auto_approve_release_notes": true
        }
      }
    ]
  }
}
```

### 해석 우선순위

agent는 현재 작업 중인 `owner/repo`를 `repos[]`에서 매칭한 뒤 다음 순서로 `auto_approve_release_notes` 값을 결정한다.

1. `github.repos[i].changelog_deploy.auto_approve_release_notes` (현 repo 매칭 결과)
2. `github.changelog_deploy.auto_approve_release_notes`
3. 기본값 `false` (수동 승인)

### deploy 모드 변경 — 5.5단계 신규

```
5단계 — 릴리스 노트 파일 작성 (_release_notes.md)
5.5단계 — 사용자 승인 게이트 (NEW)
  - auto_approve_release_notes == true → 본문 안내 후 6단계 자동 진행
  - 그 외 → 본문 표시 + 승인 요청
    - 승인 → 6단계
    - 수정 요청 → 노트 재작성 → 5.5단계 재진입
6단계 — PR 생성 (본문 포함)
```

### fix 모드 변경 — 4.5단계 신규

deploy 5.5와 동일한 구조를 fix 4단계와 fix 5단계 사이에 삽입한다.

### 핵심 원칙 섹션 보강

SKILL.md 상단의 "핵심 원칙"에 한 줄 추가한다.

- 릴리스 노트 본문은 PR 생성 전 사용자에게 보여준다. `auto_approve_release_notes=true`로 명시한 레포만 자동 진행한다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `skills/changelog-deploy/SKILL.md` | 핵심 원칙 한 줄 + deploy 5.5단계 + fix 4.5단계 |
| `skills/config.json.example` | github 글로벌·repos[] 양쪽에 `changelog_deploy` 블록 예시 |
| `skills/references/config-rules.md` §7 github 섹션 | `changelog_deploy` 필드 표 + 해석 우선순위 추가 |

## 검증 시나리오

| 시나리오 | 기대 동작 |
|---------|----------|
| config 없음 | 5.5단계에서 본문 표시 후 승인 대기 |
| repos[].changelog_deploy.auto_approve = true | 본문 안내 후 자동 6단계 진행 |
| github.changelog_deploy.auto_approve = true, repos[]에 미설정 | 자동 진행 |
| github.changelog_deploy.auto_approve = true, repos[].changelog_deploy.auto_approve = false | 수동 승인 (repo 오버라이드 적용) |
| 사용자가 수정 요청 | 노트 재작성 후 5.5단계 재진입, 승인 떨어질 때까지 반복 |

## 위험·완화

- **수동 모드에서 사용자 부재 시 PR 미생성**: 의도된 동작. 자동화를 원하면 config로 명시.
- **자동 모드에서 잘못된 노트로 PR 생성**: 사용자가 명시적으로 자동 모드를 켰으므로 책임은 사용자에게 있음. 기본값은 false로 유지해 신규 사용자를 보호.
- **config 파일이 없는 상태에서 자동 모드 기대**: 기본값이 false이므로 항상 안전한 쪽으로 동작.
