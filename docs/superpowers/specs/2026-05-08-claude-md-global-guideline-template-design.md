# 신규 프로젝트 init용 표준 CLAUDE.md 글로벌 AI 협업 가이드라인 템플릿 추가

- **이슈**: [#290](https://github.com/Cassiiopeia/projectops/issues/290)
- **작성일**: 2026-05-08
- **결정**: Q1=B / Q2=A / Q3=A

---

## 1. 배경

SUH-DEVOPS-TEMPLATE은 신규/통합 프로젝트에 워크플로우·이슈 템플릿·skill 등 다양한 자산을 배포한다. 그러나 AI 협업 가이드라인(CLAUDE.md)은 의도적으로 제외된다:

- `.github/scripts/template_initializer.sh` L391~395 — 신규 init 시 루트 `CLAUDE.md` 삭제
- `template_integrator.sh` L869~880 — 통합 시 `docs_to_remove`로 제외
- `template_integrator.ps1` L738~750 — Windows 동등 제외

이유: 현재 SUH-DEVOPS-TEMPLATE 루트 `CLAUDE.md`(419줄)는 **템플릿 자체 운영 가이드**(skill 라우팅, 워크플로우 추가 규칙 등)이라 신규 프로젝트엔 부적절.

결과: SUH-DEVOPS-TEMPLATE으로 시작한 모든 프로젝트가 AI 협업 표준 원칙(Truthfulness/Simplicity/Verification 등)을 자체 마련해야 함. 표준 부재로 프로젝트별 품질 편차 발생.

---

## 2. 목표

의존성 0인 글로벌 AI 협업 가이드라인을 별도 템플릿 파일로 관리하고, 신규/통합 시 자동 배포한다.

**Non-goal:**
- 현재 SUH-DEVOPS-TEMPLATE 루트 `CLAUDE.md`(419줄, 운영 가이드) 변경 — 그대로 유지
- 글로벌 가이드 본문 자체 수정 — 사용자 제공 65줄 원본 사용 (SuperClaude·RTK 두 섹션만 제거)
- 기존 사용자 CLAUDE.md 자동 머지 — 분기 처리만 제공

---

## 3. 결정 사항 (브레인스토밍 결과)

### Q1. 템플릿 파일 위치 = **B**

`.github/templates/CLAUDE.md`

이유: 목적 명확(`templates/` 폴더 = 배포용 표준 자산). `project-types/common/`은 워크플로우 원본 보관소라 성격 다름.

### Q2. 통합 시 기존 CLAUDE.md 처리 = **A**

사용자 확인 분기 — `template_integrator.sh`/`ps1`이 기존 CLAUDE.md 발견 시 다음 옵션 제시:

```
기존 CLAUDE.md 발견됨. 다음 중 선택:

1. 덮어쓰기 (기존 내용 백업: CLAUDE.md.bak)
2. 별도 저장 (CLAUDE.md.template-suggested로 저장, 사용자가 직접 머지)
3. 건너뛰기 (배포 안 함)
```

기본값 없음. 명시 선택 필수. CI 환경(non-interactive)에서는 옵션 2 자동 선택.

### Q3. 가이드라인 본문 = **A**

사용자 제공 65줄 원본에서 다음 두 섹션만 제거:
- `## SuperClaude Reference` 섹션 — `~/.claude/reference/superclaude/` 사용자 환경 의존
- `@RTK.md` import 라인 — 사용자 환경 전용

제거 후 약 55줄. SUH-DEVOPS-TEMPLATE 자체 CLAUDE.md의 `superpowers:*` 워크플로우 섹션은 추가하지 않음 (플러그인 의존성 발생).

---

## 4. 가이드라인 본문 (확정)

`.github/templates/CLAUDE.md` 내용:

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

55줄. skill·workflow·플러그인·외부 path 참조 0건.

---

## 5. 영향받는 파일 (총 5개)

| 파일 | 변경 종류 | 변경 줄 수 |
|------|---------|---------|
| `.github/templates/CLAUDE.md` | **신규 추가** | +55줄 |
| `.github/scripts/template_initializer.sh` | L391~395 — 삭제 → 교체 (글로벌 가이드 복사) | ~10줄 변경 |
| `template_integrator.sh` | L869~880 + 신규 `merge_claude_md` 함수 추가 | ~50줄 추가/변경 |
| `template_integrator.ps1` | PowerShell 5.1 호환 동등 변경 + `Merge-ClaudeMd` 함수 | ~50줄 추가/변경 |
| `CLAUDE.md` (루트, 운영 가이드) | L153 "복사되지 않는 템플릿 전용 파일" 표 갱신 | 1~3줄 |

---

## 6. 변경 상세

### 6.1 `.github/scripts/template_initializer.sh` L391~395

**변경 전**:
```bash
# CLAUDE.md 파일 삭제 (템플릿 전용 문서)
if [ -f "CLAUDE.md" ]; then
    rm -f CLAUDE.md
    echo "  ✓ CLAUDE.md 삭제"
fi
```

**변경 후**:
```bash
# CLAUDE.md 교체 (템플릿 운영 가이드 → 글로벌 AI 협업 가이드라인)
if [ -f "CLAUDE.md" ]; then
    rm -f CLAUDE.md
fi
if [ -f ".github/templates/CLAUDE.md" ]; then
    cp ".github/templates/CLAUDE.md" "CLAUDE.md"
    echo "  ✓ CLAUDE.md 교체 (글로벌 AI 협업 가이드라인)"
else
    echo "  ⚠ .github/templates/CLAUDE.md 없음 — 글로벌 가이드라인 배포 건너뜀"
fi
```

신규 init 시나리오에서는 기존 사용자 CLAUDE.md 분기 불필요(저장소가 막 만들어진 상태이므로).

### 6.2 `template_integrator.sh` L869~880

**변경 전**:
```bash
# 문서 파일 제거 (프로젝트 특화 문서는 복사하지 않음)
print_info "템플릿 내부 문서 제외 중..."
local docs_to_remove=(
    "CONTRIBUTING.md"
    "CLAUDE.md"
)
```

**변경 후**:
- `docs_to_remove`에서 루트 `CLAUDE.md`는 그대로 제외 유지 (운영 가이드는 통합 안 함)
- `.github/templates/CLAUDE.md`는 통합 대상에 포함 → 통합 후 별도 함수로 사용자 분기 처리

신규 함수 `merge_claude_md`:
```bash
merge_claude_md() {
    local template_path=".github/templates/CLAUDE.md"

    if [ ! -f "$template_path" ]; then
        return 0
    fi

    # 신규 프로젝트: 그대로 복사
    if [ ! -f "CLAUDE.md" ]; then
        cp "$template_path" "CLAUDE.md"
        print_success "CLAUDE.md 글로벌 가이드라인 배포 완료"
        return 0
    fi

    # CI 환경 (TTY 없음): 별도 저장 자동 선택
    if [ ! -t 0 ]; then
        cp "$template_path" "CLAUDE.md.template-suggested"
        print_info "CI 환경 감지 — CLAUDE.md.template-suggested로 저장"
        return 0
    fi

    # 대화형: 사용자 선택
    echo ""
    echo "기존 CLAUDE.md 발견됨. 다음 중 선택:"
    echo "  1. 덮어쓰기 (기존 내용 백업: CLAUDE.md.bak)"
    echo "  2. 별도 저장 (CLAUDE.md.template-suggested로 저장, 사용자가 직접 머지)"
    echo "  3. 건너뛰기 (배포 안 함)"
    echo ""
    read -p "선택 [1/2/3]: " choice

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
```

호출 위치: 통합 마지막 단계, 모든 파일 복사 완료 후. `.github/templates/CLAUDE.md` 자체는 통합으로 들어와 있으므로 함수에서 직접 참조 가능.

### 6.3 `template_integrator.ps1` L738~750

PowerShell 5.1 호환 동등 변경. `&&` 미사용. `Read-Host` 대화형. CI 환경 감지: `[Environment]::UserInteractive` 또는 `[Console]::IsInputRedirected`.

```powershell
function Merge-ClaudeMd {
    $templatePath = ".github/templates/CLAUDE.md"

    if (-not (Test-Path $templatePath)) {
        return
    }

    # 신규 프로젝트
    if (-not (Test-Path "CLAUDE.md")) {
        Copy-Item -Path $templatePath -Destination "CLAUDE.md"
        Print-Success "CLAUDE.md 글로벌 가이드라인 배포 완료"
        return
    }

    # CI 환경 감지
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        Copy-Item -Path $templatePath -Destination "CLAUDE.md.template-suggested"
        Print-Info "CI 환경 감지 - CLAUDE.md.template-suggested로 저장"
        return
    }

    # 대화형
    Write-Host ""
    Write-Host "기존 CLAUDE.md 발견됨. 다음 중 선택:"
    Write-Host "  1. 덮어쓰기 (기존 내용 백업: CLAUDE.md.bak)"
    Write-Host "  2. 별도 저장 (CLAUDE.md.template-suggested로 저장, 사용자가 직접 머지)"
    Write-Host "  3. 건너뛰기 (배포 안 함)"
    Write-Host ""
    $choice = Read-Host "선택 [1/2/3]"

    switch ($choice) {
        "1" {
            Copy-Item -Path "CLAUDE.md" -Destination "CLAUDE.md.bak"
            Copy-Item -Path $templatePath -Destination "CLAUDE.md" -Force
            Print-Success "기존 CLAUDE.md 백업(CLAUDE.md.bak) 후 글로벌 가이드라인으로 교체"
        }
        "2" {
            Copy-Item -Path $templatePath -Destination "CLAUDE.md.template-suggested"
            Print-Success "CLAUDE.md.template-suggested로 별도 저장 - 사용자가 직접 머지"
        }
        "3" {
            Print-Info "CLAUDE.md 글로벌 가이드라인 배포 건너뜀"
        }
        default {
            Print-Warning "잘못된 선택. 기본값(별도 저장) 적용"
            Copy-Item -Path $templatePath -Destination "CLAUDE.md.template-suggested"
        }
    }
}
```

### 6.4 루트 CLAUDE.md L153 운영 문서 갱신

현재 표:
```
**초기화/통합 시 복사되지 않는 템플릿 전용 파일**:
\`\`\`
CLAUDE.md, CONTRIBUTING.md, LICENSE
...
\`\`\`
```

`CLAUDE.md`를 표에서 제거 + 별도 한 줄 추가:
```
**CLAUDE.md 처리 정책**:
- 신규 init: 루트 CLAUDE.md(운영 가이드) 삭제 후 `.github/templates/CLAUDE.md`(글로벌 AI 협업 가이드)로 교체
- 통합: 기존 CLAUDE.md 있으면 사용자 선택(덮어쓰기/별도 저장/skip), 없으면 그대로 배포
```

---

## 7. 동작 시나리오

### 7.1 신규 프로젝트 (GitHub Template으로 생성 → `template_initializer.sh` 실행)

1. 워크플로우·이슈 템플릿 등 표준 자산 배포
2. 루트 `CLAUDE.md`(템플릿 운영 가이드) 삭제
3. `.github/templates/CLAUDE.md` (글로벌 가이드) 루트로 복사
4. 결과: 신규 프로젝트 루트에 의존성 0인 AI 협업 가이드라인 자동 배치

### 7.2 기존 프로젝트 통합 (`template_integrator.sh` 실행, 대화형)

CLAUDE.md 없는 프로젝트:
- `.github/templates/CLAUDE.md` 그대로 루트 복사

CLAUDE.md 있는 프로젝트:
- 사용자에게 1/2/3 선택 입력 요청
- 선택대로 처리

### 7.3 CI 환경 (non-interactive)

- TTY 없음 감지 → 옵션 2 자동 선택 (`CLAUDE.md.template-suggested` 저장)
- 사용자가 나중에 직접 머지

### 7.4 SUH-DEVOPS-TEMPLATE 자체 repo

- 루트 `CLAUDE.md`(419줄 운영 가이드) 그대로 유지
- 새로 추가된 `.github/templates/CLAUDE.md`(55줄 글로벌)와 분리 관리

---

## 8. 영향도 (의존성 검증)

| 영역 | 영향 | 조치 |
|------|------|------|
| 워크플로우 | 0건 — 어떤 워크플로우도 CLAUDE.md를 읽지 않음 | 없음 |
| skill | 0건 — skill들은 자기 폴더 내 references/만 참조 | 없음 |
| 버전 동기화 | 0건 — version.yml에 CLAUDE.md 항목 없음 | 없음 |
| CHANGELOG·릴리스 | patch bump | 자동 |
| 글로벌 가이드 본문 | 0건 — skill·workflow·플러그인·외부 path 참조 전무 | 사용자 검증 완료 |

---

## 9. 테스트

자동 테스트 없음. 수동 검증:

| 항목 | 검증 방법 |
|------|---------|
| 신규 init | dummy repo에서 `template_initializer.sh` 실행 → 루트 CLAUDE.md 내용이 글로벌 가이드(55줄)인지 확인 |
| 통합 — CLAUDE.md 없음 | dummy repo에서 `template_integrator.sh` 실행 → 글로벌 가이드 그대로 배포 확인 |
| 통합 — CLAUDE.md 있음 (대화형) | 1/2/3 각 선택별 결과 확인 (백업·별도 저장·skip) |
| 통합 — CI (non-interactive) | `bash -c '...'` 또는 redirect로 stdin 막은 상태에서 실행 → `.template-suggested` 자동 저장 확인 |
| Windows ps1 | PowerShell 5.1에서 동등 시나리오 검증 |

---

## 10. 위험 / 트레이드오프

| 위험 | 완화책 |
|------|------|
| 기존 사용자 CLAUDE.md 덮어쓰기 사고 | §6.2 사용자 확인 분기 + `CLAUDE.md.bak` 자동 백업 |
| 가이드 본문이 일반적이라 효과 낮음 | 사용자 본인 경험 기반이라 OK 판단 |
| 가이드 업데이트 시 기존 사용자 갱신 어려움 | `template_integrator.sh --update` 모드도 동일 분기 사용 — `.template-suggested`로 머지 유도 |
| Windows·Unix 동작 차이 | 대화형/CI 환경 감지 로직 두 스크립트 독립 구현 |
| Read-Host stdin redirect 환경 | `[Console]::IsInputRedirected` 감지로 처리 |

---

## 11. 마이그레이션

기존 사용자: `template_integrator.sh --update` 실행 시 §6.2 분기 동작. config 변경·호환성 깨짐 없음.

---

## 12. 다음 단계

이 spec 승인 후 `superpowers:writing-plans` skill로 상세 구현 plan 작성.
