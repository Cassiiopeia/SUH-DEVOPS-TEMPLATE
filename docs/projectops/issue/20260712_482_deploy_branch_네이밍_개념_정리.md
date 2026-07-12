# ❗[버그][통합마법사] deploy_branch 필드가 이름과 정반대 개념을 가리킴 — 브랜치 3개념 정리 필요

> 라벨: 작업전
> 담당자: Cassiiopeia

🗒️ 설명
---

마법사의 브랜치 질문(`deploy_branch`)이 **이름과 실제 용도가 정반대**라, 사용자가 근본적으로 혼란을 겪는다 (실측: suh-project-utility, v4.2.12).

### 실제 코드 추적 결과

`deploy_branch` 필드가 코드에서 실제로 가리키는 것은 **릴리스 PR의 head 브랜치**, 즉 `develop→main` 릴리스에서 **head 쪽(개발 브랜치 = develop)** 이다.

- `skills/pro-changelog-deploy/scripts/changelog_cli.py:331` — "head = metadata.deploy_branch (릴리스 PR head) — 없으면 'develop' 폴백"
- `skills/pro-changelog-deploy/SKILL.md:44` — "branches.head = 릴리스 PR의 head 브랜치(= metadata.deploy_branch, 폴백 develop). push·PR 생성의 소스"
- `src/core/version-yml.js:249` — "deploy_branch: 릴리스 PR의 head 브랜치(#456)"

즉 **`deploy_branch`라는 이름은 "배포 브랜치"를 뜻하는데, 담고 있는 값은 "개발 브랜치(develop)"** 다. 이름과 실체가 완전히 어긋난다.

### 브랜치는 3개념인데 필드/라벨이 이를 뭉갠다

| 개념 | 실체 | 담는 필드(현재) |
|------|------|----------------|
| 개발 브랜치 | 개발을 모으는 곳 (develop) | `deploy_branch` ← **이름이 틀림** |
| default 브랜치 | 레포 기본·프로덕션 (main) | `default_branch` |
| 배포 트리거 브랜치 | push 시 실제 배포가 도는 브랜치 (보통 default, 또는 사용자가 만든 deploy) | (별도 개념 없음 — 워크플로우 트리거로만 존재) |

마법사 라벨 "🌿 릴리스 **배포** 브랜치"는 사용자에게 "배포가 도는 브랜치"로 읽히지만, 실제로 묻는 것은 "릴리스 PR을 **어느 개발 브랜치에서** 올리나"다. "배포"라고 이름 붙은 것에 개발 브랜치 값(develop)을 기본으로 주니, 사용자도 리뷰어(agent)도 "배포인데 왜 develop?"로 혼란에 빠진다.

📸 참고 자료 (현재 화면)
---

```
🌿 릴리스 배포 브랜치(릴리스 PR의 head)는 무엇인가요?
   develop→main 릴리스 구조면 develop 그대로 두세요.
◆ 배포 브랜치  [초기값: develop]
```

→ "배포 브랜치"라고 물으면서 개발 브랜치(develop)를 기본값으로 준다.

🛠️ 해결 방안
---

1. **개념·용어 정리(SSOT)**: 이 필드가 뜻하는 바를 "릴리스 소스 브랜치 = 개발 브랜치"로 확정하고, 사용자 노출 라벨을 실체에 맞게 바꾼다.
   - 마법사 질문 라벨: "🌿 릴리스 배포 브랜치" → "🌿 개발(릴리스 소스) 브랜치는 무엇인가요? — 개발한 걸 모아 main으로 올리는 브랜치"
   - "배포"라는 단어를 이 질문에서 제거 (배포가 도는 브랜치는 default_branch 쪽 개념).
2. **필드명 검토**: `deploy_branch`는 오해를 부르는 이름이다. `release_source_branch`(또는 `dev_branch`) 등으로 개명 검토. 개명 시 version.yml 하위호환(구 키 자동 매핑)과 스킬(changelog_cli) 소비처를 함께 갱신. 파급이 크면 라벨/문구만 먼저 고치고 필드 개명은 별도 단계로.
3. **동적 안내(#477 연계)**: git으로 감지한 default 브랜치를 함께 보여준다. 예: "감지된 기본 브랜치: main · 릴리스는 그 앞단 개발 브랜치(예: develop)에서 올립니다".
4. **문서 정합**: `docs/BRANCH-CONVENTION.md`·CLAUDE.md에 3개념(개발/default/배포트리거)을 명시하고 필드-개념 매핑을 표로 고정.

✅ 기대 동작
---

- 사용자가 "이건 개발 브랜치를 묻는 거구나"를 라벨만 보고 안다.
- "배포 브랜치"라는 단어가 개발 브랜치 값에 붙는 모순이 사라진다.
- default 브랜치는 감지값으로, 개발(릴리스 소스) 브랜치는 명확한 라벨로 분리 인지된다.

📚 참고 자료
---

- 연관: #481(질문 UX 4건 — 이 이슈가 #481의 4번 항목을 근본 원인 관점으로 승격), #456(deploy_branch 도입), #477(브랜치 전략·동적 감지), #425(develop/main 전환)
- 관련 파일: `src/core/version-yml.js`, `src/core/options-ask.js`, `skills/pro-changelog-deploy/`, `docs/BRANCH-CONVENTION.md`
