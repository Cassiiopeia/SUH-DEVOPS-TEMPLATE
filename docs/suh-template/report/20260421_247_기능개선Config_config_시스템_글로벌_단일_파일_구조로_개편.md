# 🚀[기능개선][Config] config 시스템 글로벌 단일 파일 구조로 개편

## 개요

기존에 프로젝트 루트에 생성되던 로컬 config(`.suh-template/config/issue.config.json`)를 완전히 폐지하고, `~/.suh-template/config/config.json` 글로벌 단일 파일로 일원화했다. 파일 구조도 `global_pat` + `repos[].pat` 방식으로 변경하여 레포별 PAT 개별 설정이 가능해졌으며, 관련 스킬 5종과 `config-rules.md`를 전면 업데이트했다.

## 변경 사항

### Config 규칙 문서

- `skills/references/config-rules.md`: 파일 경로 구조를 글로벌 단일 경로(`~/.suh-template/config/config.json`)로 단순화. 스키마를 `global_pat` + `repos[].pat` 구조로 전면 재작성. 로컬 config 관련 내용 전체 제거. PAT 결정 로직(`repo.pat if repo.pat else global_pat`) 명시.

### 스킬 업데이트

- `skills/issue/SKILL.md`: config 읽기/쓰기 로직을 새 스키마(`global_pat`, `repos`)로 변경. 저장 형식 예시 업데이트.
- `skills/commit/SKILL.md`: PAT 읽기 시 레포별 PAT 우선, `global_pat` fallback 로직 반영.
- `skills/github/SKILL.md`: PAT 추출 및 `repos` 필드 참조로 변경. `github_repos` → `repos` 전체 교체.
- `skills/report/SKILL.md`: PAT + repo 확인 로직을 새 config 구조에 맞게 수정.
- `skills/changelog-deploy/SKILL.md`: 하드코딩된 `issue.config.json` 경로를 `config.json`으로 변경. PAT 추출 스크립트를 레포별 PAT 우선 + `global_pat` fallback Python 인라인 코드로 교체.

## 주요 구현 내용

**PAT 우선순위 로직** (changelog-deploy 기준):
```python
repo_pat = next((r.get('pat') for r in c.get('repos', []) if r.get('repo') == REPO and r.get('pat')), None)
effective_pat = repo_pat or c.get('global_pat', '')
```
레포명으로 매칭한 뒤 `pat` 필드가 non-null이면 개별 PAT, 없으면 `global_pat`을 사용한다. 모든 스킬에 동일한 로직이 적용된다.

## 주의사항

- 기존 `issue.config.json`을 사용하던 환경은 `~/.suh-template/config/config.json`으로 수동 마이그레이션 필요
- `.cursor/skills/` 하위 스킬 파일들은 이번 변경에 포함되지 않음 — 별도 동기화 필요
