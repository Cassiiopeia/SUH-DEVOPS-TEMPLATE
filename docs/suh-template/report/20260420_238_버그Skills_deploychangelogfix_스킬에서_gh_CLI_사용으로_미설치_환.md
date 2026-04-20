# 구현 보고서 — #238 deploy·changelogfix 스킬에서 gh CLI 사용으로 미설치 환경 오작동

**이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/238
**작업일**: 2026-04-20
**커밋**: `619202b`

---

## 문제 요약

`deploy/SKILL.md` 4단계와 `changelogfix/SKILL.md` 1~3단계에서 `gh` CLI(`gh pr list`, `gh pr create`, `gh pr close`)를 사용.
`common-rules.md`에 gh CLI 사용 금지가 명시되어 있음에도 위반하고 있어, gh 미설치 환경에서 `command not found: gh` 에러로 PR 생성·조회가 전혀 동작하지 않음.

## 수정 내용

### `skills/deploy/SKILL.md`

4단계 deploy PR 생성 로직을 `suh_template.cli`의 `list-prs`, `create-pr`로 교체.

```bash
# 기존 open deploy PR 확인
EXISTING_PRS=$(GITHUB_PAT=$GITHUB_PAT PYTHONPATH="$SCRIPTS_PATH" $PYTHON -m suh_template.cli list-prs $OWNER $REPO --state open)
PR_NUMBER=$(echo "$EXISTING_PRS" | $PYTHON -c "
import sys, json
prs = json.load(sys.stdin)
deploy_pr = next((p for p in prs if 'Deploy' in p.get('title','')), None)
print(deploy_pr['number'] if deploy_pr else '')
" 2>/dev/null)

if [ -z "$PR_NUMBER" ]; then
  RESULT=$(GITHUB_PAT=$GITHUB_PAT PYTHONPATH="$SCRIPTS_PATH" $PYTHON -m suh_template.cli create-pr \
    $OWNER $REPO "$TITLE" /dev/null main deploy)
  PR_NUMBER=$(echo "$RESULT" | $PYTHON -c "import sys,json; print(json.load(sys.stdin)['number'])")
fi
```

### `skills/changelogfix/SKILL.md`

1~3단계의 `gh pr list`, `gh pr close`, `gh pr create` 전부 교체.

| 기존 | 수정 |
|------|------|
| `GH_TOKEN=$GITHUB_PAT gh pr list ...` | `suh_template.cli list-prs` |
| `GH_TOKEN=$GITHUB_PAT gh pr close ...` | `suh_template.cli update-issue ... --state closed` |
| `GH_TOKEN=$GITHUB_PAT gh pr create ...` | `suh_template.cli create-pr` |

### 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `skills/deploy/SKILL.md` | 4단계 gh CLI → suh_template CLI 교체 |
| `skills/changelogfix/SKILL.md` | 1~3단계 gh CLI → suh_template CLI 전면 교체 |

## 검증

- gh 미설치 환경(macOS)에서 `/cassiiopeia:deploy` 실행 시 PR #239 정상 생성 확인
- `command not found: gh` 에러 없이 정상 동작
