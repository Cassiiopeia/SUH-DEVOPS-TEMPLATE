# ❗[버그][Skills] deploy·changelogfix 스킬에서 gh CLI 사용으로 미설치 환경 오작동

- **라벨**: 작업전
- **담당자**: 

---

🗒️ 설명
---

`deploy/SKILL.md`와 `changelogfix/SKILL.md`의 4단계에서 `gh` CLI (`GH_TOKEN=$GITHUB_PAT gh pr list`, `gh pr create`, `gh pr close`)를 사용하고 있습니다.

`common-rules.md`에 `gh` CLI 사용 금지(`gh` CLI는 Windows/Mac 호환성 문제 및 별도 설치 필요로 사용 금지)가 명시되어 있음에도 스킬 내용이 이를 위반하고 있어, `gh`가 설치되지 않은 환경에서 PR 생성·조회가 전혀 동작하지 않습니다.

🔄 재현 방법
---

1. `gh` CLI가 설치되지 않은 환경에서 `/cassiiopeia:deploy` 실행
2. 4단계 deploy PR 생성 시 `command not found: gh` 에러 발생
3. PR이 생성되지 않아 이후 릴리스 노트 작성도 실패

📸 참고 자료
---

에러 로그:
```
(eval):7: command not found: gh
PR_NUMBER=
```

문제 코드 (`deploy/SKILL.md` 4단계):
```bash
EXISTING_PR=$(GH_TOKEN=$GITHUB_PAT gh pr list --repo $OWNER/$REPO ...)
PR_NUMBER=$(GH_TOKEN=$GITHUB_PAT gh pr create ...)
```

문제 코드 (`changelogfix/SKILL.md` 1~3단계):
```bash
GH_TOKEN=$GITHUB_PAT gh pr list --repo $OWNER/$REPO ...
GH_TOKEN=$GITHUB_PAT gh pr close {pr_number} ...
NEW_PR_NUMBER=$(GH_TOKEN=$GITHUB_PAT gh pr create ...)
```

✅ 예상 동작
---

- `suh_template.cli`의 `list-prs`, `create-pr`, `update-issue` 커맨드로 대체
- `gh` CLI 없이도 deploy PR 생성·조회·닫기가 정상 동작

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
