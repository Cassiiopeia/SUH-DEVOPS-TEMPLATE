# 구현 보고서 — #235 issue 스킬 scripts 경로 하드코딩으로 플러그인 설치 프로젝트에서 ModuleNotFoundError 발생

**이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/235
**작업일**: 2026-04-20
**커밋**: `fcbd957`, `fa2f427`

---

## 문제 요약

모든 스킬의 "시작 전" 섹션에서 `PYTHONPATH="$PROJECT_ROOT/scripts"`를 하드코딩하고 있어,
플러그인(`claude plugin install`)으로 설치된 타 프로젝트(예: RomRom-FE)에는 `scripts/` 폴더가 없어 `ModuleNotFoundError` 발생.

## 수정 내용

### SCRIPTS_PATH 자동 탐지 로직 추가

모든 스킬 파일(18개) 및 references에 아래 탐지 블록 추가:

```bash
if [ -d "$PROJECT_ROOT/scripts/suh_template" ]; then
  SCRIPTS_PATH="$PROJECT_ROOT/scripts"           # 이 레포에서 직접 실행 시
else
  SCRIPTS_PATH=$(find "$HOME/.claude/plugins/cache" -type d -name "suh_template" 2>/dev/null | head -1 | xargs -I{} dirname {} 2>/dev/null)
fi
```

### 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `skills/issue/SKILL.md` | 시작 전 섹션에 SCRIPTS_PATH 탐지 블록 추가 |
| `skills/commit/SKILL.md` | 동일 |
| `skills/deploy/SKILL.md` | 동일 |
| `skills/changelogfix/SKILL.md` | 동일 |
| `skills/github/SKILL.md` | 동일 |
| `skills/init-worktree/SKILL.md` | 동일 |
| `skills/references/common-rules.md` | PYTHONPATH 설정 섹션 전면 개정 |
| `skills/references/doc-output-path.md` | SCRIPTS_PATH 탐지 블록 추가 |
| 나머지 10개 스킬 SKILL.md | `PYTHONPATH="$PROJECT_ROOT/scripts"` → `PYTHONPATH="$SCRIPTS_PATH"` 일괄 치환 |
| `.gitignore` | `.cursor/skills/cursor-skills-meta.json`, `.template_download_temp/` 추가 |

## 검증

```bash
# 플러그인 설치 프로젝트(RomRom-FE)에서 수동 검증
SCRIPTS_PATH=$(find "$HOME/.claude/plugins/cache" -type d -name "suh_template" | head -1 | xargs dirname)
PYTHONPATH="$SCRIPTS_PATH" python3 -m suh_template.cli config-get issue github_pat
# → PAT 정상 반환 확인
```
