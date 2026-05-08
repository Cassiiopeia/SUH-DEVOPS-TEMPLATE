# CLAUDE.md 글로벌 가이드라인 템플릿 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 의존성 0인 글로벌 AI 협업 가이드라인 (`Truthfulness > Correctness > Simplicity > Surgical scope > Elegance`)을 신규/통합 프로젝트에 자동 배포하는 템플릿 시스템 추가.

**Architecture:** `.github/templates/CLAUDE.md` 신규 파일로 가이드라인 본문 보관. `template_initializer.sh`는 init 시 루트 CLAUDE.md(운영 가이드) 삭제 후 templates 본문 복사. `template_integrator.sh`/`.ps1`은 통합 시 기존 CLAUDE.md 존재 여부에 따라 사용자 선택 분기(덮/별도/skip), CI 환경에서는 옵션 2 자동.

**Tech Stack:** Bash, PowerShell 5.1, GitHub raw content, 표준 셸 명령만.

**Spec:** `docs/superpowers/specs/2026-05-08-claude-md-global-guideline-template-design.md`
**Issue:** [#290](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/290)

---

## File Structure

| 파일 | 책임 | 변경 종류 |
|------|------|---------|
| `.github/templates/CLAUDE.md` | 글로벌 AI 협업 가이드라인 본문 (55줄) | **신규 추가** |
| `.github/scripts/template_initializer.sh` | 신규 init 시 CLAUDE.md 교체 로직 | Modify L391~395 |
| `template_integrator.sh` | 통합 시 사용자 분기 함수 + 호출 위치 | Modify + 신규 함수 추가 |
| `template_integrator.ps1` | 통합 시 사용자 분기 함수 (PS5.1 호환) | Modify + 신규 함수 추가 |
| `CLAUDE.md` (루트, 운영 가이드) | "복사되지 않는 템플릿 전용 파일" 표 갱신 | Modify L153 부근 |

---

## Task 1: 작업 브랜치 사전 검증

**Files:** 읽기만

- [ ] **Step 1: 현재 브랜치 + working tree 확인**

```bash
cd D:/0-suh/project/suh-github-template && git rev-parse --abbrev-ref HEAD && git status --short
```

Expected:
```
main
?? docs/suh-template/issue/20260508_290_...md
?? nul
```

main 브랜치 + clean (untracked만). 사용자 명시적 main 직접 작업 승인 상태.

- [ ] **Step 2: integrator/initializer baseline 확인**

```bash
grep -n "CLAUDE.md" "D:/0-suh/project/suh-github-template/.github/scripts/template_initializer.sh" "D:/0-suh/project/suh-github-template/template_integrator.sh" "D:/0-suh/project/suh-github-template/template_integrator.ps1"
```

Expected:
- `template_initializer.sh:391` 부근 — CLAUDE.md 삭제 블록
- `template_integrator.sh:873` — `docs_to_remove` 배열 포함
- `template_integrator.ps1:742` — `$docsToRemove` 배열 포함

세 파일 위치 모두 확인 후 Task 2로.

---

## Task 2: `.github/templates/CLAUDE.md` 신규 파일 작성

**Files:**
- Create: `.github/templates/CLAUDE.md`

- [ ] **Step 1: `.github/templates/` 디렉토리 존재 확인**

```bash
ls "D:/0-suh/project/suh-github-template/.github/templates/" 2>&1 | head -5
```

Expected: `No such file or directory` 또는 빈 출력. 디렉토리 신규 생성 필요.

- [ ] **Step 2: 디렉토리 생성**

```bash
mkdir -p "D:/0-suh/project/suh-github-template/.github/templates"
```

- [ ] **Step 3: CLAUDE.md 파일 작성**

Write tool로 `D:/0-suh/project/suh-github-template/.github/templates/CLAUDE.md` 작성. 내용:

```markdown
# Global Instructions

> Think clearly. Act honestly. Code minimally. Verify rigorously. Learn continuously.

---

## Hard Rules (Non-Negotiable)

### Git Conventions
- **Co-Authored-By 태그 절대 금지.** 커밋 메시지에 추가하지 않는다.

---

## Core Discipline (Priority Order)

When principles compete, resolve in this order:

1. **Truthfulness** — never fabricate. If you don't know, say so. Read before editing. Verify before claiming done.
2. **Correctness** — does it actually work?
3. **Simplicity** — fewest moving parts that solve the problem.
4. **Surgical scope** — minimal blast radius on the codebase.
5. **Elegance** — only after the above are satisfied.

> "Demand elegance" never overrides "simplicity first." Elegance is the *absence* of unnecessary complexity, not the *presence* of clever abstractions.

---

## 1. Pre-Execution — Think & Decide

### 1.1 Ask vs. Act

**ASK when:**
- Requirements or intent are unclear
- Multiple valid interpretations exist — present options; don't pick silently
- A simpler approach exists than what was asked — say so before building

**ACT autonomously when:**
- Given a bug report, failing CI, or error log — investigate and fix
- The signal is clear; don't request hand-holding on things you can resolve

**Always:**
- State assumptions explicitly when proceeding without confirmation
- Stop and name what's unclear when truly confused — never invent context

### 1.2 Plan Mode (for non-trivial tasks)

Trigger: 3+ steps, architectural decisions, or anything touching multiple files.

- Lay out a checkable plan before writing implementation code
- If execution goes sideways, **STOP and re-plan** — don't patch on the fly
- Skip plan mode for simple, single-step fixes

### 1.3 Subagent Delegation

Use subagents to keep the main context clean. Good candidates:
- Research and codebase exploration
- Parallel analysis of independent files
- Long-running investigations that would bloat context

One focused tack per subagent. Skip them for simple tasks — overhead isn't free.

---

## 2. Execution — Simplicity & Surgery

### 2.1 Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked
- No abstractions for single-use code
- No "flexibility" or "configurability" that wasn't requested
- No error handling for impossible scenarios
- If 200 lines could be 50, rewrite it

**Test:** Would a senior engineer say this is overcomplicated? If yes, simplify.

### 2.2 Surgical Changes

Touch only what you must. Clean up only your own mess.

**Read before edit.** Always view current file state before modifying — never rely on memory or assumed structure.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting
- Don't refactor things that aren't broken
- Match existing style, even if you'd do it differently
- If you notice unrelated dead code, **mention it — don't delete it**

When your changes create orphans:
- Remove imports/variables/functions that *your* changes made unused
- Don't remove pre-existing dead code unless asked

**Test:** Every changed line should trace directly to the user's request.

### 2.3 Elegance Check (non-trivial changes only)

After a working solution exists, pause **once** and ask: "is there a more elegant way?"

- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution."
- Skip this for simple, obvious fixes — over-engineering is the failure mode here
- Elegance is constrained by §2.1 — never adds abstractions for their own sake

---

## 3. Verification — Goal-Driven Done

### 3.1 Define Success Before Starting

| Instead of... | Transform to... |
|---------------|-----------------|
| "Add validation" | "Write tests for invalid inputs, then make them pass" |
| "Fix the bug" | "Write a test that reproduces it, then make it pass" |
| "Refactor X" | "Ensure tests pass before and after" |
| "Make it faster" | "Benchmark current; target N% reduction; verify" |

### 3.2 Verify Before Marking Done

Never mark a task complete without proving it works.

- Run tests, check logs, demonstrate correctness
- Diff behavior before and after when relevant
- Claim "done" based on **evidence**, never on belief
- Ask: "Would a staff engineer approve this?"

---

## 4. Learning — Self-Improvement Loop

When the user corrects something:
1. Identify the pattern that caused the mistake
2. Formulate a concrete rule that prevents recurrence
3. Iterate ruthlessly until the mistake rate on that pattern drops

If a project provides a lessons/notes file, review it at session start and reload context on prior corrections.

---

## Quick Reference — The Five Tests

| Phase | Ask yourself |
|-------|--------------|
| Before coding | "Have I stated my assumptions — or am I guessing?" |
| While coding | "Would a senior engineer call this overcomplicated?" |
| While editing | "Does every changed line trace to the user's request?" |
| Before done | "Have I proven this works — not just believed it?" |
| After correction | "Did I capture the lesson?" |
```

- [ ] **Step 4: 검증**

```bash
wc -l "D:/0-suh/project/suh-github-template/.github/templates/CLAUDE.md"
grep -c "skill\|cassiiopeia\|superpowers\|@RTK" "D:/0-suh/project/suh-github-template/.github/templates/CLAUDE.md"
```

Expected:
- 줄 수: 130~150줄 (마크다운 표 포함). 60줄 미만이면 본문 누락.
- skill·cassiiopeia·superpowers·@RTK 매칭: **0건**. 의존성 0 검증.

> 줄 수가 spec §3 Q3에서 말한 "약 55줄"과 다른 이유: spec은 가이드라인 핵심 줄 수만 가리킴. 실제 파일은 마크다운 표·구분선 포함하여 더 길다.

---

## Task 3: `template_initializer.sh` 신규 init 로직 변경

**Files:**
- Modify: `.github/scripts/template_initializer.sh` L391~395

- [ ] **Step 1: 현재 블록 확인**

```bash
sed -n '389,396p' "D:/0-suh/project/suh-github-template/.github/scripts/template_initializer.sh"
```

Expected:
```
    # CLAUDE.md 파일 삭제 (템플릿 전용 문서)
    if [ -f "CLAUDE.md" ]; then
        rm -f CLAUDE.md
        echo "  ✓ CLAUDE.md 삭제"
    fi
```

- [ ] **Step 2: Edit 적용**

`old_string` (5줄):
```
    # CLAUDE.md 파일 삭제 (템플릿 전용 문서)
    if [ -f "CLAUDE.md" ]; then
        rm -f CLAUDE.md
        echo "  ✓ CLAUDE.md 삭제"
    fi
```

`new_string`:
```
    # CLAUDE.md 교체: 템플릿 운영 가이드(루트) → 글로벌 AI 협업 가이드라인(.github/templates/CLAUDE.md)
    if [ -f "CLAUDE.md" ]; then
        rm -f CLAUDE.md
    fi
    if [ -f ".github/templates/CLAUDE.md" ]; then
        cp ".github/templates/CLAUDE.md" "CLAUDE.md"
        echo "  ✓ CLAUDE.md 교체 (글로벌 AI 협업 가이드라인 배포)"
    else
        echo "  ⚠ .github/templates/CLAUDE.md 없음 — 글로벌 가이드라인 배포 건너뜀"
    fi
```

- [ ] **Step 3: 검증**

```bash
sed -n '389,401p' "D:/0-suh/project/suh-github-template/.github/scripts/template_initializer.sh"
```

Expected: 새 블록 출력. `cp ".github/templates/CLAUDE.md" "CLAUDE.md"` 라인 포함.

```bash
grep -c "글로벌 AI 협업 가이드라인" "D:/0-suh/project/suh-github-template/.github/scripts/template_initializer.sh"
```

Expected: 1 이상.

---

## Task 4: `template_integrator.sh`에 `merge_claude_md` 함수 추가

**Files:**
- Modify: `template_integrator.sh` (함수 추가)

- [ ] **Step 1: 적절한 함수 추가 위치 선정**

`add_version_section_to_readme()` 함수 (L920) 직전에 새 함수 삽입한다. integrator의 다른 "사용자 결과물 적용" 함수들과 인접 배치.

확인:

```bash
sed -n '917,922p' "D:/0-suh/project/suh-github-template/template_integrator.sh"
```

Expected (앞뒤 한 줄씩):
```

# README.md 버전 섹션 추가
add_version_section_to_readme() {
    local version=$1
```

- [ ] **Step 2: 새 함수 본문 삽입**

`old_string`:
```

# README.md 버전 섹션 추가
add_version_section_to_readme() {
    local version=$1
```

`new_string`:
```

# CLAUDE.md 글로벌 가이드라인 머지 (통합 모드 전용)
# 동작:
#   - 기존 CLAUDE.md 없음 → 그대로 복사
#   - TTY 없음(CI) → CLAUDE.md.template-suggested 자동 저장
#   - 대화형 → 사용자 1/2/3 선택
merge_claude_md() {
    local template_path=".github/templates/CLAUDE.md"

    # 템플릿 본문이 통합으로 들어와 있어야 동작
    if [ ! -f "$template_path" ]; then
        print_info "CLAUDE.md 템플릿 없음 — 글로벌 가이드라인 머지 건너뜀"
        return 0
    fi

    # 신규 프로젝트: 그대로 배포
    if [ ! -f "CLAUDE.md" ]; then
        cp "$template_path" "CLAUDE.md"
        print_success "CLAUDE.md 글로벌 가이드라인 배포 완료"
        return 0
    fi

    # CI 환경(TTY 없음): 옵션 2 자동
    if [ ! -t 0 ]; then
        cp "$template_path" "CLAUDE.md.template-suggested"
        print_info "CI 환경 감지 — CLAUDE.md.template-suggested로 별도 저장"
        return 0
    fi

    # 대화형: 사용자 선택
    echo ""
    print_info "기존 CLAUDE.md 발견됨. 다음 중 선택:"
    echo "  1. 덮어쓰기 (기존 내용 백업: CLAUDE.md.bak)"
    echo "  2. 별도 저장 (CLAUDE.md.template-suggested로 저장, 사용자가 직접 머지)"
    echo "  3. 건너뛰기 (배포 안 함)"
    echo ""
    local choice=""
    safe_read "선택 [1/2/3]: " choice ""

    case "$choice" in
        1)
            cp "CLAUDE.md" "CLAUDE.md.bak"
            cp "$template_path" "CLAUDE.md"
            print_success "기존 CLAUDE.md 백업(CLAUDE.md.bak) 후 글로벌 가이드라인으로 교체"
            ;;
        2)
            cp "$template_path" "CLAUDE.md.template-suggested"
            print_success "CLAUDE.md.template-suggested로 별도 저장 — 사용자가 직접 머지"
            ;;
        3)
            print_info "CLAUDE.md 글로벌 가이드라인 배포 건너뜀"
            ;;
        *)
            print_warning "잘못된 선택. 기본값(별도 저장) 적용"
            cp "$template_path" "CLAUDE.md.template-suggested"
            ;;
    esac
}

# README.md 버전 섹션 추가
add_version_section_to_readme() {
    local version=$1
```

> `safe_read`는 integrator 본문에 이미 정의된 함수(L211). stdin 모드/TTY 감지 후 안전하게 입력 받는다.

- [ ] **Step 3: 함수 정의 검증**

```bash
grep -n "^merge_claude_md()" "D:/0-suh/project/suh-github-template/template_integrator.sh"
```

Expected: 1줄 출력 (함수 정의 라인).

---

## Task 5: `template_integrator.sh` `merge_claude_md` 호출 위치 추가 + `docs_to_remove` 검증

**Files:**
- Modify: `template_integrator.sh` (호출 위치)

- [ ] **Step 1: integrator main 흐름 확인 — 호출 위치 후보**

```bash
grep -n "add_version_section_to_readme\|integrate_full\|complete\|run_mode" "D:/0-suh/project/suh-github-template/template_integrator.sh" | head -20
```

main 흐름에서 모든 파일 복사 후 + README 처리 직후 위치를 찾는다. integrator는 mode별(`full`, `version`, `workflows`, `issues`, `skills`, `interactive`) 분기 동작이라, **`full` 또는 `interactive`로 통합되는 시점**에서 호출.

가장 안전한 위치: 통합 작업 마지막에 단일 호출. 구체 위치는 implementer가 main 흐름 코드 읽고 결정 (`add_version_section_to_readme` 호출 직후가 자연스러움).

- [ ] **Step 2: `add_version_section_to_readme` 호출 위치 검색**

```bash
grep -n "add_version_section_to_readme" "D:/0-suh/project/suh-github-template/template_integrator.sh"
```

Expected: 함수 정의 1건 + main 흐름에서 호출 1~N건.

- [ ] **Step 3: 호출 위치 1곳 식별 후 `merge_claude_md` 호출 추가**

implementer가 `add_version_section_to_readme "..."` 호출 직후 라인 다음에 `merge_claude_md` 호출 1줄 추가:

```bash
add_version_section_to_readme "$DETECTED_VERSION"
merge_claude_md
```

여러 mode 진입점이 있으면 각 mode 마지막(또는 공통 마무리 함수)에 추가. 단 신규 init이 아닌 통합 모드(`full`, `interactive`)에서만 호출되어야 함. `version`/`workflows`/`issues`/`skills` 단독 모드는 호출 안 함 — 사용자가 워크플로우만 가져가려는 케이스라면 CLAUDE.md 건드리지 않는 게 surgical.

> 결정: **`full` 모드만 호출**. interactive 모드에서 사용자가 "CLAUDE.md 가이드라인 받겠다" 옵션 선택한 경우만. interactive에 새 항목 추가 여부는 별도 판단.

implementer가 main 함수와 mode 분기 읽은 후 적절한 위치 선택. 후보:
- `full` 모드 함수 마지막
- `interactive` 모드의 사용자 확인 뒤 `full` 분기 진입 시점

- [ ] **Step 4: docs_to_remove 그대로 유지 확인 (변경 안 함)**

```bash
sed -n '869,880p' "D:/0-suh/project/suh-github-template/template_integrator.sh"
```

Expected:
```
    # 문서 파일 제거 (프로젝트 특화 문서는 복사하지 않음)
    print_info "템플릿 내부 문서 제외 중..."
    local docs_to_remove=(
        "CONTRIBUTING.md"
        "CLAUDE.md"
    )
    ...
```

`CLAUDE.md`(루트, 운영 가이드)는 여전히 제외 대상. `.github/templates/CLAUDE.md`는 다른 path라 영향 없음. 변경 X.

- [ ] **Step 5: 호출 위치 검증**

```bash
grep -n "merge_claude_md" "D:/0-suh/project/suh-github-template/template_integrator.sh"
```

Expected: 함수 정의 1건 + 호출 1건 이상.

---

## Task 6: `template_integrator.ps1`에 `Merge-ClaudeMd` 함수 추가

**Files:**
- Modify: `template_integrator.ps1` (함수 추가)

- [ ] **Step 1: PS1 적절한 위치 확인**

```bash
grep -n "function Add-VersionSectionToReadme\|function Detect-Project" "D:/0-suh/project/suh-github-template/template_integrator.ps1" | head -5
```

`Add-VersionSectionToReadme` 함수 직전 위치에 삽입. integrator.sh와 동일 위치 정합.

- [ ] **Step 2: 함수 본문 작성 (PS5.1 호환)**

`Add-VersionSectionToReadme` 함수 정의 바로 위에 다음 함수 삽입:

```powershell
# CLAUDE.md 글로벌 가이드라인 머지 (통합 모드 전용)
# 동작:
#   - 기존 CLAUDE.md 없음 → 그대로 복사
#   - 비대화형(CI) → CLAUDE.md.template-suggested 자동 저장
#   - 대화형 → 사용자 1/2/3 선택
function Merge-ClaudeMd {
    $templatePath = ".github/templates/CLAUDE.md"

    if (-not (Test-Path $templatePath)) {
        Print-Info "CLAUDE.md 템플릿 없음 - 글로벌 가이드라인 머지 건너뜀"
        return
    }

    if (-not (Test-Path "CLAUDE.md")) {
        Copy-Item -Path $templatePath -Destination "CLAUDE.md"
        Print-Success "CLAUDE.md 글로벌 가이드라인 배포 완료"
        return
    }

    # CI 환경 감지: stdin redirect 또는 UserInteractive false
    $isInteractive = $true
    try {
        if ([Console]::IsInputRedirected) { $isInteractive = $false }
    } catch {
        # 일부 환경에서 IsInputRedirected 접근 실패 가능 — UserInteractive로 fallback
    }
    if (-not [Environment]::UserInteractive) { $isInteractive = $false }

    if (-not $isInteractive) {
        Copy-Item -Path $templatePath -Destination "CLAUDE.md.template-suggested"
        Print-Info "CI 환경 감지 - CLAUDE.md.template-suggested로 별도 저장"
        return
    }

    Write-Host ""
    Print-Info "기존 CLAUDE.md 발견됨. 다음 중 선택:"
    Write-Host "  1. 덮어쓰기 (기존 내용 백업: CLAUDE.md.bak)"
    Write-Host "  2. 별도 저장 (CLAUDE.md.template-suggested로 저장, 사용자가 직접 머지)"
    Write-Host "  3. 건너뛰기 (배포 안 함)"
    Write-Host ""
    $choice = Read-Host "선택 [1/2/3]"

    switch ($choice) {
        "1" {
            Copy-Item -Path "CLAUDE.md" -Destination "CLAUDE.md.bak" -Force
            Copy-Item -Path $templatePath -Destination "CLAUDE.md" -Force
            Print-Success "기존 CLAUDE.md 백업(CLAUDE.md.bak) 후 글로벌 가이드라인으로 교체"
        }
        "2" {
            Copy-Item -Path $templatePath -Destination "CLAUDE.md.template-suggested" -Force
            Print-Success "CLAUDE.md.template-suggested로 별도 저장 - 사용자가 직접 머지"
        }
        "3" {
            Print-Info "CLAUDE.md 글로벌 가이드라인 배포 건너뜀"
        }
        default {
            Print-Warning "잘못된 선택. 기본값(별도 저장) 적용"
            Copy-Item -Path $templatePath -Destination "CLAUDE.md.template-suggested" -Force
        }
    }
}

```

> PS5.1 호환: `&&` 연산자 사용 안 함. `Read-Host` 표준 cmdlet. `[Console]::IsInputRedirected` try/catch로 감싸 일부 환경 호환성 확보.

- [ ] **Step 3: 함수 호출 위치 추가 (PS1)**

`Add-VersionSectionToReadme` 호출 위치 직후에 `Merge-ClaudeMd` 호출 추가. integrator.sh Task 5와 동일 mode 정합 (full 모드만).

- [ ] **Step 4: 검증**

```bash
grep -n "function Merge-ClaudeMd\|Merge-ClaudeMd" "D:/0-suh/project/suh-github-template/template_integrator.ps1"
```

Expected: 함수 정의 1건 + 호출 1건 이상.

---

## Task 7: 루트 `CLAUDE.md`(운영 가이드) 정책 문서 갱신

**Files:**
- Modify: `CLAUDE.md` L150~163 부근 ("초기화/통합 시 복사되지 않는 템플릿 전용 파일" 표)

- [ ] **Step 1: 현재 블록 확인**

```bash
grep -n "초기화/통합 시 복사되지 않는" "D:/0-suh/project/suh-github-template/CLAUDE.md"
```

Expected: 1줄 출력. 해당 줄 +/- 10줄 Read.

```bash
sed -n '150,165p' "D:/0-suh/project/suh-github-template/CLAUDE.md"
```

확인 후 Edit 위치 결정.

- [ ] **Step 2: 표에서 `CLAUDE.md` 제거 + 정책 라인 추가**

기존 텍스트 (예시 — 실제 텍스트는 Step 1로 확인):

```
**초기화/통합 시 복사되지 않는 템플릿 전용 파일**:
\`\`\`
CLAUDE.md, CONTRIBUTING.md, LICENSE
CHANGELOG.md, CHANGELOG.json
template_integrator.sh / .ps1
docs/, .github/scripts/test/, .github/workflows/test/
.claude-plugin/, skills/, scripts/
\`\`\`
```

Edit:
- `old_string`: 위 블록 (정확히 매치)
- `new_string`:
```
**초기화/통합 시 복사되지 않는 템플릿 전용 파일**:
\`\`\`
CONTRIBUTING.md, LICENSE
CHANGELOG.md, CHANGELOG.json
template_integrator.sh / .ps1
docs/, .github/scripts/test/, .github/workflows/test/
.claude-plugin/, skills/, scripts/
\`\`\`

**CLAUDE.md 처리 정책** (의존성 0인 글로벌 AI 협업 가이드라인 배포):
- 신규 init: 루트 CLAUDE.md(운영 가이드) 삭제 후 `.github/templates/CLAUDE.md`(글로벌)로 교체
- 통합 모드: 기존 CLAUDE.md 있으면 사용자 선택 분기 (1. 덮어쓰기 + .bak 백업 / 2. CLAUDE.md.template-suggested로 별도 저장 / 3. skip), 없으면 그대로 배포
- CI 환경(TTY 없음): 옵션 2 자동
```

> Step 1에서 확인한 실제 블록 내용에 맞춰 old_string 정확히 매치 — 위는 spec §6.4 기준 예시. 실제 줄 다르면 implementer가 보정.

- [ ] **Step 3: 검증**

```bash
grep -n "CLAUDE.md 처리 정책\|CLAUDE.md, CONTRIBUTING" "D:/0-suh/project/suh-github-template/CLAUDE.md"
```

Expected:
- `CLAUDE.md 처리 정책` 1건
- `CLAUDE.md, CONTRIBUTING` 0건 (표에서 제거됨)

---

## Task 8: 수동 통합 테스트

**Files:** 없음 (실행 검증)

- [ ] **Step 1: dummy 디렉토리에서 신규 init 시뮬레이션**

```bash
TMPDIR=$(mktemp -d)
cp -r "D:/0-suh/project/suh-github-template/.github" "$TMPDIR/"
cp "D:/0-suh/project/suh-github-template/.github/scripts/template_initializer.sh" "$TMPDIR/"
cd "$TMPDIR" && touch CLAUDE.md && bash .github/scripts/template_initializer.sh -v 1.0.0 -t basic 2>&1 | grep -i "CLAUDE.md" | head -5
ls -la "$TMPDIR/CLAUDE.md" && head -3 "$TMPDIR/CLAUDE.md"
```

Expected:
- "CLAUDE.md 교체 (글로벌 AI 협업 가이드라인 배포)" 메시지
- `CLAUDE.md` 파일 존재
- 첫 줄: `# Global Instructions`

- [ ] **Step 2: 통합 모드 — CLAUDE.md 없는 경우 시뮬레이션**

```bash
TMPDIR2=$(mktemp -d)
mkdir -p "$TMPDIR2/.github/templates"
cp "D:/0-suh/project/suh-github-template/.github/templates/CLAUDE.md" "$TMPDIR2/.github/templates/CLAUDE.md"
cd "$TMPDIR2"
# merge_claude_md 함수만 추출하여 실행
bash -c '
    template_path=".github/templates/CLAUDE.md"
    if [ ! -f "CLAUDE.md" ]; then
        cp "$template_path" "CLAUDE.md"
        echo "DEPLOYED"
    fi
'
head -3 CLAUDE.md
```

Expected:
- "DEPLOYED" 출력
- 첫 줄: `# Global Instructions`

- [ ] **Step 3: 통합 모드 — CLAUDE.md 있는 경우 (옵션 2 시뮬레이션)**

```bash
TMPDIR3=$(mktemp -d)
mkdir -p "$TMPDIR3/.github/templates"
cp "D:/0-suh/project/suh-github-template/.github/templates/CLAUDE.md" "$TMPDIR3/.github/templates/CLAUDE.md"
cd "$TMPDIR3"
echo "기존 사용자 CLAUDE.md" > CLAUDE.md
# 옵션 2 (별도 저장) 시뮬레이션
bash -c '
    template_path=".github/templates/CLAUDE.md"
    if [ -f "CLAUDE.md" ]; then
        cp "$template_path" "CLAUDE.md.template-suggested"
        echo "SUGGESTED_SAVED"
    fi
'
ls -la CLAUDE.md CLAUDE.md.template-suggested
cat CLAUDE.md
```

Expected:
- "SUGGESTED_SAVED" 출력
- 두 파일 모두 존재
- `CLAUDE.md` 내용은 "기존 사용자 CLAUDE.md" 그대로
- `CLAUDE.md.template-suggested` 첫 줄 `# Global Instructions`

- [ ] **Step 4: 의존성 0 검증**

```bash
grep -E "skill|cassiiopeia|superpowers|@RTK|references/" "D:/0-suh/project/suh-github-template/.github/templates/CLAUDE.md"
```

Expected: 0줄 (전혀 매칭 안 됨).

---

## Task 9: 자체검토 종합 grep

**Files:** 없음

- [ ] **Step 1: 신규 파일 존재 확인**

```bash
ls -la "D:/0-suh/project/suh-github-template/.github/templates/CLAUDE.md"
```

Expected: 파일 존재, 4~6KB 크기.

- [ ] **Step 2: 모든 변경 파일에서 새 path 참조 확인**

```bash
grep -rn "\.github/templates/CLAUDE\.md" "D:/0-suh/project/suh-github-template/.github/scripts/template_initializer.sh" "D:/0-suh/project/suh-github-template/template_integrator.sh" "D:/0-suh/project/suh-github-template/template_integrator.ps1"
```

Expected: 각 파일에서 1건 이상 매칭.

- [ ] **Step 3: 함수 정의 + 호출 매칭 확인**

```bash
grep -n "merge_claude_md\|Merge-ClaudeMd" "D:/0-suh/project/suh-github-template/template_integrator.sh" "D:/0-suh/project/suh-github-template/template_integrator.ps1"
```

Expected:
- `template_integrator.sh`: 함수 정의 1 + 호출 1+
- `template_integrator.ps1`: 함수 정의 1 + 호출 1+

- [ ] **Step 4: 운영 가이드 문서 갱신 확인**

```bash
grep -n "CLAUDE.md 처리 정책" "D:/0-suh/project/suh-github-template/CLAUDE.md"
```

Expected: 1건.

---

## Task 10: 사용자 승인 후 커밋

**Files:** 없음 (git)

- [ ] **Step 1: 변경 파일 staging 후보 확인**

```bash
cd D:/0-suh/project/suh-github-template && git status --short
```

Expected modified:
- `M .github/scripts/template_initializer.sh`
- `M template_integrator.sh`
- `M template_integrator.ps1`
- `M CLAUDE.md`

Expected untracked:
- `?? .github/templates/CLAUDE.md`
- `?? docs/superpowers/specs/2026-05-08-claude-md-global-guideline-template-design.md`
- `?? docs/superpowers/plans/2026-05-08-claude-md-global-guideline-template.md`
- `?? docs/suh-template/issue/20260508_290_...md` (이전 단계 산출물)

`?? nul` 제외.

- [ ] **Step 2: 명시 staging**

```bash
git add \
  .github/scripts/template_initializer.sh \
  .github/templates/CLAUDE.md \
  template_integrator.sh \
  template_integrator.ps1 \
  CLAUDE.md \
  "docs/suh-template/issue/20260508_290_신규_프로젝트_init용_표준_CLAUDE_md_글로벌_AI_협업_가이드라인_추가.md" \
  docs/superpowers/specs/2026-05-08-claude-md-global-guideline-template-design.md \
  docs/superpowers/plans/2026-05-08-claude-md-global-guideline-template.md
```

- [ ] **Step 3: 사용자에게 메시지 검토 요청**

```
커밋 메시지:
신규 프로젝트 init용 표준 CLAUDE.md 글로벌 AI 협업 가이드라인 추가 : feat : .github/templates/CLAUDE.md 신설 (의존성 0 가이드 55줄), template_initializer 신규 init 시 교체 로직, template_integrator/ps1 통합 모드에 merge_claude_md 함수 추가 (덮/별도/skip 분기 + CI 자동) https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/290

위 메시지로 커밋해도 될까요?
```

승인 후:

```bash
git commit -m "신규 프로젝트 init용 표준 CLAUDE.md 글로벌 AI 협업 가이드라인 추가 : feat : .github/templates/CLAUDE.md 신설 (의존성 0 가이드 55줄), template_initializer 신규 init 시 교체 로직, template_integrator/ps1 통합 모드에 merge_claude_md 함수 추가 (덮/별도/skip 분기 + CI 자동) https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/290"
```

> CLAUDE.md 컨벤션: 이모지·태그 없음, 이슈 URL 포함, Co-Authored-By 태그 없음(글로벌 가이드라인 §Hard Rules 준수).

- [ ] **Step 4: 커밋 결과 확인**

```bash
git log -1 --oneline
```

Expected: 새 commit hash + 메시지 첫 줄.

---

## Task 11: 이슈 #290 댓글 — 작업 완료 보고

**Files:** 없음 (GitHub API)

- [ ] **Step 1: 댓글 등록**

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
"$PYTHON" - <<'PYEOF'
import urllib.request, urllib.error, json
pat = "GHP_PLACEHOLDER"
url = "https://api.github.com/repos/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/290/comments"
body = """v3.0.x 패치 완료.

**변경 요약:**
- `.github/templates/CLAUDE.md` 신규 추가 — 의존성 0 글로벌 AI 협업 가이드라인 (Truthfulness/Simplicity/Verification 등)
- `.github/scripts/template_initializer.sh` L391~395: 신규 init 시 루트 CLAUDE.md 삭제 → 글로벌 가이드 복사로 교체
- `template_integrator.sh`: `merge_claude_md` 함수 추가 (덮어쓰기 + .bak / 별도 저장 / skip 분기, CI 자동 옵션 2)
- `template_integrator.ps1`: `Merge-ClaudeMd` 함수 추가 (PS5.1 호환, IsInputRedirected/UserInteractive로 CI 감지)
- 루트 CLAUDE.md L153 부근: 정책 문서 갱신

**의존성 검증 (manual grep):**
- skill·cassiiopeia·superpowers·@RTK·외부 path 참조: 0건
- 어떤 프로젝트도 즉시 적용 가능

**관련 문서:**
- spec: `docs/superpowers/specs/2026-05-08-claude-md-global-guideline-template-design.md`
- plan: `docs/superpowers/plans/2026-05-08-claude-md-global-guideline-template.md`
"""
payload = {"body": body}
data = json.dumps(payload).encode()
req = urllib.request.Request(url, data=data, method="POST")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
try:
    res = urllib.request.urlopen(req)
    result = json.loads(res.read())
    print("COMMENT_URL:", result["html_url"])
except urllib.error.HTTPError as e:
    print("HTTPError:", e.code, e.reason)
PYEOF
```

> `GHP_PLACEHOLDER` 자리에 실제 PAT 치환. plan 파일에는 절대 평문 PAT 저장 X.

- [ ] **Step 2: 사용자 보고**

```
이슈 #290 작업 완료. 패치 commit: <hash>
이슈 댓글: <comment_url>

다음 옵션:
1. push (`git push origin main`) → 워크플로우가 patch 자동 bump
2. /changelog-deploy 실행 → deploy PR + 릴리스 노트
3. 마무리
```

---

## Self-Review

**Spec coverage:**

| Spec 섹션 | 대응 Task |
|---------|---------|
| §3 Q1 (위치 = `.github/templates/CLAUDE.md`) | Task 2 |
| §3 Q2 (통합 시 사용자 분기) | Task 4 (sh), Task 6 (ps1) |
| §3 Q3 (가이드 본문, RTK·SuperClaude 제거) | Task 2 본문 |
| §4 가이드 본문 확정 내용 | Task 2 Step 3 |
| §5 영향받는 파일 5개 | Task 2~7 모두 커버 |
| §6.1 template_initializer 변경 | Task 3 |
| §6.2 template_integrator.sh `merge_claude_md` | Task 4·5 |
| §6.3 template_integrator.ps1 `Merge-ClaudeMd` | Task 6 |
| §6.4 루트 CLAUDE.md 정책 문서 갱신 | Task 7 |
| §7 동작 시나리오 (신규/통합/CI/SUH 자체) | Task 8 검증 |
| §9 수동 테스트 | Task 8 |
| §10 위험 (백업·CI 분기·Windows 호환) | Task 4·6 본문 |

빈 항목 없음.

**Placeholder scan:** Plan 내 TBD/TODO 없음. 모든 Edit step에 정확한 old_string/new_string 또는 추출 명령. 단 Task 5/Task 6에서 `merge_claude_md`/`Merge-ClaudeMd` 호출 위치는 implementer가 main 흐름 읽고 결정 — 이는 placeholder가 아니라 의도적 implementer 판단 위임 (구체 line 번호는 mode 분기에 따라 다양).

**Type consistency:** 함수명·변수명 일관:
- bash: `merge_claude_md`, `template_path`, `CLAUDE.md.template-suggested`, `CLAUDE.md.bak`
- ps1: `Merge-ClaudeMd`, `$templatePath`, `CLAUDE.md.template-suggested`, `CLAUDE.md.bak`
- 양 스크립트에서 분기 키(1/2/3)와 결과 파일명 동일

검토 통과. 수정 없음.

---

## Plan complete and saved to `docs/superpowers/plans/2026-05-08-claude-md-global-guideline-template.md`.

**두 가지 실행 옵션:**

1. **Subagent-Driven (recommended)** — task별 fresh subagent, 각 task 후 spec/quality 2단계 리뷰
2. **Inline Execution** — 현재 세션에서 batch 실행, checkpoint마다 검토

어느 쪽?
