# .issue 폴더 시스템 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** `.report` 패턴과 동일하게 `.issue/` 폴더를 추가하여 이슈 초안을 로컬 마크다운으로 저장하고, gitignore 자동화 및 커맨드 파일을 수정한다.

**Architecture:** `.report` 패턴을 그대로 복제. `.gitignore`, 3개 스크립트(`template_integrator.ps1`, `template_integrator.sh`, `template_initializer.sh`)의 `ensure_gitignore` 함수에 `/.issue` 엔트리 추가. `issue.md` 커맨드를 `.issue/` 폴더에 파일 저장하도록 수정.

**Tech Stack:** PowerShell, Bash, Markdown

---

### Task 1: .gitignore에 /.issue 추가

**Files:**
- Modify: `.gitignore:3` (/.report 바로 아래에 추가)

**Step 1: .gitignore에 /.issue 엔트리 추가**

```
/.idea
/.claude/settings.local.json
/.report
/.issue
```

`/.report` 바로 아래에 `/.issue` 한 줄 추가.

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add /.issue to .gitignore"
```

---

### Task 2: template_integrator.ps1 - Ensure-GitIgnore 수정

**Files:**
- Modify: `template_integrator.ps1:1757-1834`

**Step 1: $requiredEntries 배열에 /.issue 추가**

```powershell
$requiredEntries = @(
    "/.idea",
    "/.claude/settings.local.json",
    "/.report",
    "/.issue"
)
```

Line 1757-1761: `"/.issue"` 추가.

**Step 2: .gitignore 신규 생성 템플릿에 /.issue 추가**

Line 1767-1776: 기존 gitignore 내용에 추가:

```powershell
$gitignoreContent = @"
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json

# Implementation Reports (자동 생성)
/.report

# Issue Drafts (자동 생성)
/.issue
"@
```

**Step 3: .issue 폴더 Git 추적 해제 로직 추가**

Line 1820-1834 부근, 기존 `.report` 추적 해제 블록 바로 아래에 동일한 패턴으로 `.issue` 블록 추가:

```powershell
# .issue 폴더가 이미 Git에 추적 중인 경우 제거
if ($entriesToAdd -contains "/.issue") {
    try {
        git ls-files --error-unmatch .issue 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Print-Info ".issue 폴더가 Git에 추적 중입니다. 추적 해제 중..."
            git rm -r --cached .issue 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Print-Success ".issue 폴더의 Git 추적이 해제되었습니다"
            }
        }
    } catch {
        # Git 명령 실패 시 무시
    }
}
```

**Step 4: Commit**

```bash
git add template_integrator.ps1
git commit -m "feat: add /.issue to Ensure-GitIgnore in PS1 integrator"
```

---

### Task 3: template_integrator.sh - ensure_gitignore 수정

**Files:**
- Modify: `template_integrator.sh:1809-1880`

**Step 1: required_entries 배열에 /.issue 추가**

```bash
local required_entries=(
    "/.idea"
    "/.claude/settings.local.json"
    "/.report"
    "/.issue"
)
```

**Step 2: .gitignore 신규 생성 템플릿에 /.issue 추가**

```bash
cat > .gitignore << 'EOF'
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json

# Implementation Reports (자동 생성)
/.report

# Issue Drafts (자동 생성)
/.issue
EOF
```

**Step 3: .issue 폴더 Git 추적 해제 로직 추가**

기존 `.report` 블록 (line 1872-1880) 바로 아래에:

```bash
# .issue 폴더가 이미 Git에 추적 중인 경우 제거
if printf '%s\n' "${entries_to_add[@]}" | grep -q "^/.issue$"; then
    if git ls-files --error-unmatch .issue >/dev/null 2>&1; then
        print_info ".issue 폴더가 Git에 추적 중입니다. 추적 해제 중..."
        if git rm -r --cached .issue >/dev/null 2>&1; then
            print_success ".issue 폴더의 Git 추적이 해제되었습니다"
        fi
    fi
fi
```

**Step 4: Commit**

```bash
git add template_integrator.sh
git commit -m "feat: add /.issue to ensure_gitignore in bash integrator"
```

---

### Task 4: template_initializer.sh - ensure_gitignore 수정

**Files:**
- Modify: `.github/scripts/template_initializer.sh:421-492`

**Step 1: required_entries 배열에 /.issue 추가**

```bash
local required_entries=(
    "/.idea"
    "/.claude/settings.local.json"
    "/.report"
    "/.issue"
)
```

**Step 2: .gitignore 신규 생성 템플릿에 /.issue 추가**

```bash
cat > .gitignore << 'EOF'
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json

# Implementation Reports (자동 생성)
/.report

# Issue Drafts (자동 생성)
/.issue
EOF
```

**Step 3: .issue 폴더 Git 추적 해제 로직 추가**

기존 `.report` 블록 (line 484-492) 바로 아래에:

```bash
# .issue 폴더가 이미 Git에 추적 중인 경우 제거
if printf '%s\n' "${entries_to_add[@]}" | grep -q "^/.issue$"; then
    if git ls-files --error-unmatch .issue >/dev/null 2>&1; then
        print_info ".issue 폴더가 Git에 추적 중입니다. 추적 해제 중..."
        if git rm -r --cached .issue >/dev/null 2>&1; then
            print_success ".issue 폴더의 Git 추적이 해제되었습니다"
        fi
    fi
fi
```

**Step 4: Commit**

```bash
git add .github/scripts/template_initializer.sh
git commit -m "feat: add /.issue to ensure_gitignore in initializer"
```

---

### Task 5: issue.md 커맨드 수정 (Claude + Cursor)

**Files:**
- Modify: `.claude/commands/issue.md`
- Modify: `.cursor/commands/issue.md` (동일 내용)

**Step 1: issue.md에 .issue 폴더 저장 로직 추가**

기존 `## 절대 금지 사항` 섹션에서 `Edit/Write 도구 사용 금지` 제거하고, 파일 저장 관련 내용 추가.

기존 `### 3단계: 이슈 출력` 섹션을 `### 3단계: 이슈 파일 저장`으로 변경.

추가할 섹션 (report.md 패턴 참고):

```markdown
## 절대 금지 사항

- ❌ 코드적인 내용 작성 금지 (구현 방법, 코드 예시 등 포함하지 않음)
- ❌ 긴급(🔥) 태그를 임의로 추가하지 않음 (사용자가 직접 "긴급"이라고 말한 경우에만)
- ❌ 담당자 내용을 임의로 채우지 않음 (템플릿 기본값 그대로 유지)
```

(기존 `Edit/Write 도구 사용 금지` 줄 제거)

`### 3단계` 변경:

```markdown
### 3단계: 이슈 파일 저장

판단된 타입에 맞는 템플릿을 사용하여 **제목 + 본문**을 `.issue/` 폴더에 마크다운 파일로 저장합니다.

### 이슈 파일 생성 로직

1. **.issue 폴더 확인**
   - `.issue/` 폴더가 없으면 자동 생성

2. **파일명 생성**
   - 형식: `[YYYYMMDD]_[이슈타입]_[간단한설명].md`
   - 날짜: 현재 날짜 (YYYYMMDD 형식)
   - 이슈타입: `버그`, `기능추가`, `기능개선`, `기능요청`, `디자인`, `시험요청`
   - 설명: 한글/영문, 언더스코어로 단어 구분
   - 특수문자 제거 및 안전한 파일명으로 변환
   - 예시: `20260214_기능요청_알림_아이콘_정렬_수정.md`

3. **파일 내용**
   - 첫 줄: `# 제목` (GitHub 이슈 제목으로 복사용)
   - 빈 줄
   - 나머지: 본문 (GitHub 이슈 본문으로 복사용)

4. **파일 저장**
   - `.issue/` 폴더에 직접 저장
   - Git 추적 안 됨 (`.gitignore`에 `/.issue` 등록)

### 출력

1. 저장된 파일 경로 표시
2. 이슈 내용 요약 표시
3. "GitHub에 이슈를 생성하려면 위 제목과 본문을 복사해서 붙여넣으세요" 안내
```

**Step 2: .cursor/commands/issue.md에 동일 내용 복사**

`.claude/commands/issue.md`와 `.cursor/commands/issue.md`는 항상 동일 내용 유지.

**Step 3: Commit**

```bash
git add .claude/commands/issue.md .cursor/commands/issue.md
git commit -m "feat: update issue command to save drafts to .issue/ folder"
```
