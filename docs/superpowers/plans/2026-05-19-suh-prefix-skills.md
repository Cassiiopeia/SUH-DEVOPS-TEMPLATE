# Skills suh- Prefix 적용 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `cassiiopeia` 플러그인의 모든 스킬명에 `suh-` prefix를 추가해 타 플러그인(somansa-tools 등)과의 네이밍 충돌을 원천 차단한다.

**Architecture:** `skills/` 하위 폴더명 rename → 각 `SKILL.md` name 필드 수정 → SKILL.md 내부 cross-reference(`/commit`, `/report` 등) 수정 → `CLAUDE.md` 스킬 라우팅 표 수정 → `README.md` 스킬 목록 수정 순서로 진행한다. `spring-test`는 이미 prefix 있으므로 제외.

**Tech Stack:** bash (git mv), sed-style Edit tool, Glob/Grep

---

## 변경 대상 파일 목록

### 폴더 rename (23개)
| 현재 | 변경 후 |
|------|---------|
| `skills/analyze/` | `skills/analyze/` |
| `skills/build/` | `skills/build/` |
| `skills/changelog-deploy/` | `skills/changelog-deploy/` |
| `skills/commit/` | `skills/commit/` |
| `skills/design/` | `skills/design/` |
| `skills/design-analyze/` | `skills/design-analyze/` |
| `skills/document/` | `skills/document/` |
| `skills/figma/` | `skills/figma/` |
| `skills/github/` | `skills/github/` |
| `skills/implement/` | `skills/implement/` |
| `skills/init-worktree/` | `skills/init-worktree/` |
| `skills/issue/` | `skills/issue/` |
| `skills/plan/` | `skills/plan/` |
| `skills/ppt/` | `skills/ppt/` |
| `skills/refactor/` | `skills/refactor/` |
| `skills/refactor-analyze/` | `skills/refactor-analyze/` |
| `skills/report/` | `skills/report/` |
| `skills/review/` | `skills/review/` |
| `skills/skill-creator/` | `skills/skill-creator/` |
| `skills/ssh/` | `skills/ssh/` |
| `skills/synology-expose/` | `skills/synology-expose/` |
| `skills/test/` | `skills/test/` |
| `skills/testcase/` | `skills/testcase/` |
| `skills/troubleshoot/` | `skills/troubleshoot/` |

### SKILL.md 수정 (name 필드 + description + 내부 cross-reference)
- `skills/suh-*/SKILL.md` 전체 (rename 후 경로)

### 문서 수정
- `CLAUDE.md` — Skill routing 표, Skills 목록, 알려진 문제 섹션
- `README.md` — 워크플로우 다이어그램, 스킬 목록 표

---

### Task 1: 스킬 폴더 rename (git mv)

**Files:**
- Rename: `skills/analyze/` → `skills/analyze/` (외 22개)

- [ ] **Step 1: git mv로 전체 폴더 rename**

```bash
cd "D:\0-suh\project\suh-github-template"
git mv skills/analyze skills/analyze
git mv skills/build skills/build
git mv skills/changelog-deploy skills/changelog-deploy
git mv skills/commit skills/commit
git mv skills/design skills/design
git mv skills/design-analyze skills/design-analyze
git mv skills/document skills/document
git mv skills/figma skills/figma
git mv skills/github skills/github
git mv skills/implement skills/implement
git mv skills/init-worktree skills/init-worktree
git mv skills/issue skills/issue
git mv skills/plan skills/plan
git mv skills/ppt skills/ppt
git mv skills/refactor skills/refactor
git mv skills/refactor-analyze skills/refactor-analyze
git mv skills/report skills/report
git mv skills/review skills/review
git mv skills/skill-creator skills/skill-creator
git mv skills/ssh skills/ssh
git mv skills/synology-expose skills/synology-expose
git mv skills/test skills/test
git mv skills/testcase skills/testcase
git mv skills/troubleshoot skills/troubleshoot
```

- [ ] **Step 2: rename 결과 확인**

```bash
ls skills/
```

Expected: `analyze  build  changelog-deploy  commit  design  design-analyze  document  figma  github  implement  init-worktree  issue  plan  ppt  refactor  refactor-analyze  report  review  skill-creator  spring-test  ssh  synology-expose  test  testcase  troubleshoot  config.json.example  references`

---

### Task 2: 각 SKILL.md name 필드 업데이트

**Files:**
- Modify: `skills/suh-*/SKILL.md` (각 파일의 frontmatter `name:` 필드)

- [ ] **Step 1: 각 SKILL.md의 `name:` 필드에 suh- prefix 추가**

Edit tool로 각 파일 수정. 변경 목록:

| 파일 | 변경 전 | 변경 후 |
|------|---------|---------|
| `skills/analyze/SKILL.md` | `name: analyze` | `name: analyze` |
| `skills/build/SKILL.md` | `name: build` | `name: build` |
| `skills/changelog-deploy/SKILL.md` | `name: changelog-deploy` | `name: changelog-deploy` |
| `skills/commit/SKILL.md` | `name: commit` | `name: commit` |
| `skills/design/SKILL.md` | `name: design` | `name: design` |
| `skills/design-analyze/SKILL.md` | `name: design-analyze` | `name: design-analyze` |
| `skills/document/SKILL.md` | `name: document` | `name: document` |
| `skills/figma/SKILL.md` | `name: figma` | `name: figma` |
| `skills/github/SKILL.md` | `name: github` | `name: github` |
| `skills/implement/SKILL.md` | `name: implement` | `name: implement` |
| `skills/init-worktree/SKILL.md` | `name: init-worktree` | `name: init-worktree` |
| `skills/issue/SKILL.md` | `name: issue` | `name: issue` |
| `skills/plan/SKILL.md` | `name: plan` | `name: plan` |
| `skills/ppt/SKILL.md` | `name: ppt` | `name: ppt` |
| `skills/refactor/SKILL.md` | `name: refactor` | `name: refactor` |
| `skills/refactor-analyze/SKILL.md` | `name: refactor-analyze` | `name: refactor-analyze` |
| `skills/report/SKILL.md` | `name: report` | `name: report` |
| `skills/review/SKILL.md` | `name: review` | `name: review` |
| `skills/skill-creator/SKILL.md` | `name: skill-creator` | `name: skill-creator` |
| `skills/ssh/SKILL.md` | `name: ssh` | `name: ssh` |
| `skills/synology-expose/SKILL.md` | `name: synology-expose` | `name: synology-expose` |
| `skills/test/SKILL.md` | `name: test` | `name: test` |
| `skills/testcase/SKILL.md` | `name: testcase` | `name: testcase` |
| `skills/troubleshoot/SKILL.md` | `name: troubleshoot` | `name: troubleshoot` |

- [ ] **Step 2: description 필드 내 `/스킬명` 호출 예시 업데이트**

각 SKILL.md description 필드 끝의 `/xxx 호출 시 사용` 패턴을 `/suh-xxx 호출 시 사용`으로 수정.

예시 (analyze):
```
변경 전: "/analyze 호출 시 사용."
변경 후: "/analyze 호출 시 사용."
```

---

### Task 3: SKILL.md 내부 cross-reference 업데이트

**Files:**
- Modify: `skills/suh-*/SKILL.md` (내부에서 `/다른스킬` 참조하는 부분)

cross-reference 패턴 (SKILL.md 본문 내):
- `/implement` → `/implement`
- `/review` → `/review`
- `/test` → `/test`
- `/commit` → `/commit`
- `/issue` → `/issue`
- `/analyze` → `/analyze`
- `/plan` → `/plan`
- `/design` → `/design`
- `/design-analyze` → `/design-analyze`
- `/refactor` → `/refactor`
- `/refactor-analyze` → `/refactor-analyze`
- `/report` → `/report`
- `/github` → `/github`
- `/init-worktree` → `/init-worktree`
- `/changelog-deploy` → `/changelog-deploy`
- `/skill-creator` → `/skill-creator`

**주의**: `/issue` 패턴 교체 시 URL 경로(`/issues/`)나 `docs/suh-template/issue/` 등 다른 문맥의 `/issue`를 건드리지 않도록 주의. 정확히 슬래시커맨드 패턴(`/스킬명` 뒤에 공백·줄바꿈·마침표·괄호가 오는 것)만 교체.

- [ ] **Step 1: 각 SKILL.md에서 cross-reference 검색 후 Edit 수정**

영향받는 파일 확인:
```bash
grep -rn "→ \`/implement\`\|→ \`/review\`\|→ \`/test\`\|/commit\b\|/analyze\b\|/plan\b\|/design\b\|/refactor\b\|/issue\` 스킬\|/init-worktree\|/changelog-deploy" skills/suh-*/SKILL.md
```

확인된 파일들을 Edit tool로 수정.

---

### Task 4: CLAUDE.md 스킬 라우팅 표 및 Skills 목록 업데이트

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Skill routing 표 업데이트**

`## Skill routing` 섹션의 `cassiiopeia:xxx` → `cassiiopeia:suh-xxx` 전체 교체.

변경 전:
```
| **PR 생성, PR 올려줘, ...** | **`cassiiopeia:github` ← 최우선 트리거** |
| 코드 분석, 현황 파악 | `cassiiopeia:analyze` |
...
```

변경 후:
```
| **PR 생성, PR 올려줘, ...** | **`projectops:github` ← 최우선 트리거** |
| 코드 분석, 현황 파악 | `projectops:analyze` |
...
```

전체 교체 대상 (14개):
- `cassiiopeia:github` → `projectops:github`
- `cassiiopeia:analyze` → `projectops:analyze`
- `cassiiopeia:troubleshoot` → `projectops:troubleshoot`
- `cassiiopeia:plan` → `projectops:plan`
- `cassiiopeia:implement` → `projectops:implement`
- `cassiiopeia:review` → `projectops:review`
- `cassiiopeia:issue` → `projectops:issue`
- `cassiiopeia:commit` → `projectops:commit`
- `cassiiopeia:changelog-deploy` → `projectops:changelog-deploy`
- `cassiiopeia:report` → `projectops:report`
- `cassiiopeia:ssh` → `projectops:ssh`
- `cassiiopeia:brainstorming` (없음 — superpowers 유지)
- `cassiiopeia:synology-expose` → `projectops:synology-expose`
- `cassiiopeia:init-worktree` → `projectops:init-worktree`

- [ ] **Step 2: Skills 목록 표 업데이트 (`## Skills` 섹션)**

```
| `analyze` | ... | → | `analyze` | ... |
| `plan` | ... | → | `plan` | ... |
...
```

- [ ] **Step 3: 알려진 문제 섹션의 `cassiiopeia:github` 참조 업데이트**

`## 알려진 스킬 동작 문제` 섹션에서 `cassiiopeia:github` → `projectops:github` 교체.

---

### Task 5: README.md 스킬 목록 업데이트

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 워크플로우 다이어그램 내 `/cassiiopeia:xxx` 참조 업데이트**

mermaid 다이어그램 내:
```
"/cassiiopeia:issue\n..." → "/projectops:issue\n..."
"/cassiiopeia:init-worktree\n..." → "/projectops:init-worktree\n..."
...
```

- [ ] **Step 2: 스킬 목록 표 업데이트**

`| `/cassiiopeia:issue` | ...` 형식의 모든 행에서 prefix 추가.

변경 전:
```markdown
| `/cassiiopeia:issue` | 설명 한 줄 → GitHub 이슈 템플릿 자동 작성 + 등록 |
| `/cassiiopeia:commit` | ... |
...
```

변경 후:
```markdown
| `/projectops:issue` | 설명 한 줄 → GitHub 이슈 템플릿 자동 작성 + 등록 |
| `/projectops:commit` | ... |
...
```

전체 교체 대상: README.md 내 `/cassiiopeia:` 참조 전체 (약 20개).

---

### Task 6: .cursor/skills/ 동기화 확인

**Files:**
- Check: `.cursor/skills/`

- [ ] **Step 1: .cursor/skills/ 존재 여부 및 내용 확인**

```bash
ls .cursor/skills/ 2>/dev/null || echo "없음"
```

존재하면 → `skills/` 와 동일하게 rename 필요 여부 확인.
없으면 → 건너뜀.

---

### Task 7: 최종 검증 및 커밋

**Files:**
- Verify: 전체 변경사항

- [ ] **Step 1: 변경된 스킬 name 필드 전체 확인**

```bash
grep -rn "^name:" skills/suh-*/SKILL.md
```

Expected: 모든 항목이 `name: suh-` 로 시작

- [ ] **Step 2: 구 스킬명 잔존 여부 확인**

```bash
grep -rn "cassiiopeia:analyze\|cassiiopeia:commit\|cassiiopeia:report\|cassiiopeia:review\|cassiiopeia:issue\b\|cassiiopeia:plan\b\|cassiiopeia:implement\|cassiiopeia:test\b\|cassiiopeia:build\b\|cassiiopeia:github\b\|cassiiopeia:ssh\b" CLAUDE.md README.md
```

Expected: 없음 (0 matches)

- [ ] **Step 3: 커밋**

```bash
git add skills/ CLAUDE.md README.md
git status
git commit -m "모든 스킬명에 suh- prefix 적용 : feat : cassiiopeia 플러그인 스킬명 충돌 방지를 위해 전체 suh- prefix 추가 https://github.com/Cassiiopeia/projectops/issues/299"
```
