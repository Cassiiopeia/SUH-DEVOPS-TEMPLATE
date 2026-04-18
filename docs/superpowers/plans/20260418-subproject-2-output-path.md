# Sub-project #2: 산출물 경로 표준화 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 8개 skill(`analyze`, `plan`, `design-analyze`, `refactor-analyze`, `troubleshoot`, `report`, `ppt`, `review`)의 SKILL.md에 `doc-output-path.md` reference 참조와 표준 경로 규칙을 적용하여 모든 md 산출물이 `docs/suh-template/{skill_id}/YYYYMMDD_{번호}_{제목}.md` 패턴으로 저장되도록 한다.

**Architecture:** 각 SKILL.md에 "산출물 저장" 섹션을 추가하고, `skills/references/doc-output-path.md`를 참조하도록 지시한다. `skills/`와 `.cursor/skills/` 두 곳을 항상 동일하게 유지한다. `report` skill은 기존 `.report/` 경로를 새 경로로 교체한다.

**Tech Stack:** Markdown 편집, bash (파일 복사 검증)

---

## 파일 구조

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `skills/analyze/SKILL.md` | Modify | 산출물 저장 섹션 추가 |
| `skills/plan/SKILL.md` | Modify | 산출물 저장 섹션 추가 |
| `skills/design-analyze/SKILL.md` | Modify | 산출물 저장 섹션 추가 |
| `skills/refactor-analyze/SKILL.md` | Modify | 산출물 저장 섹션 추가 |
| `skills/troubleshoot/SKILL.md` | Modify | 산출물 저장 섹션 추가 |
| `skills/report/SKILL.md` | Modify | 기존 `.report/` 경로 → 새 경로로 교체 |
| `skills/ppt/SKILL.md` | Modify | 산출물 저장 섹션 추가 |
| `skills/review/SKILL.md` | Modify | 산출물 저장 섹션 추가 |
| `.cursor/skills/analyze/SKILL.md` | Sync | skills/와 동일 내용 |
| `.cursor/skills/plan/SKILL.md` | Sync | skills/와 동일 내용 |
| `.cursor/skills/design-analyze/SKILL.md` | Sync | skills/와 동일 내용 |
| `.cursor/skills/refactor-analyze/SKILL.md` | Sync | skills/와 동일 내용 |
| `.cursor/skills/troubleshoot/SKILL.md` | Sync | skills/와 동일 내용 |
| `.cursor/skills/report/SKILL.md` | Sync | skills/와 동일 내용 |
| `.cursor/skills/ppt/SKILL.md` | Sync | skills/와 동일 내용 |
| `.cursor/skills/review/SKILL.md` | Sync | skills/와 동일 내용 |

---

## 추가할 표준 섹션 (모든 skill 공통)

각 SKILL.md 파일 **맨 끝**에 다음 섹션을 추가한다:

```markdown
## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path <skill_id>
```

반환된 경로에 파일을 저장한다.
```

단, `<skill_id>`는 각 skill마다 실제 값으로 교체:
- analyze → `analyze`
- plan → `plan`
- design-analyze → `design-analyze`
- refactor-analyze → `refactor-analyze`
- troubleshoot → `troubleshoot`
- report → `report`
- ppt → `ppt`
- review → `review`

---

## Task 1: analyze, plan, design-analyze SKILL.md 업데이트

**Files:**
- Modify: `skills/analyze/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/design-analyze/SKILL.md`
- Sync: `.cursor/skills/analyze/SKILL.md`
- Sync: `.cursor/skills/plan/SKILL.md`
- Sync: `.cursor/skills/design-analyze/SKILL.md`

- [ ] **Step 1: `skills/analyze/SKILL.md` 끝에 산출물 저장 섹션 추가**

파일 끝에 다음을 추가한다 (기존 내용은 그대로 유지):

```markdown

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path analyze
```

반환된 경로에 파일을 저장한다.
```

- [ ] **Step 2: `.cursor/skills/analyze/SKILL.md`에 동일 내용 복사**

```bash
cp skills/analyze/SKILL.md .cursor/skills/analyze/SKILL.md
```

- [ ] **Step 3: 두 파일 동일한지 확인**

```bash
diff skills/analyze/SKILL.md .cursor/skills/analyze/SKILL.md
```

Expected: 출력 없음 (동일)

- [ ] **Step 4: `skills/plan/SKILL.md` 끝에 산출물 저장 섹션 추가**

파일 끝에 다음을 추가한다:

```markdown

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path plan
```

반환된 경로에 파일을 저장한다.
```

- [ ] **Step 5: `.cursor/skills/plan/SKILL.md` 동기화 및 확인**

```bash
cp skills/plan/SKILL.md .cursor/skills/plan/SKILL.md
diff skills/plan/SKILL.md .cursor/skills/plan/SKILL.md
```

Expected: 출력 없음

- [ ] **Step 6: `skills/design-analyze/SKILL.md` 끝에 산출물 저장 섹션 추가**

파일 끝에 다음을 추가한다:

```markdown

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path design-analyze
```

반환된 경로에 파일을 저장한다.
```

- [ ] **Step 7: `.cursor/skills/design-analyze/SKILL.md` 동기화 및 확인**

```bash
cp skills/design-analyze/SKILL.md .cursor/skills/design-analyze/SKILL.md
diff skills/design-analyze/SKILL.md .cursor/skills/design-analyze/SKILL.md
```

Expected: 출력 없음

- [ ] **Step 8: 커밋**

```bash
git add skills/analyze/SKILL.md skills/plan/SKILL.md skills/design-analyze/SKILL.md
git add .cursor/skills/analyze/SKILL.md .cursor/skills/plan/SKILL.md .cursor/skills/design-analyze/SKILL.md
git commit -m "feat: analyze/plan/design-analyze skill 산출물 경로 표준화 적용"
```

---

## Task 2: refactor-analyze, troubleshoot SKILL.md 업데이트

**Files:**
- Modify: `skills/refactor-analyze/SKILL.md`
- Modify: `skills/troubleshoot/SKILL.md`
- Sync: `.cursor/skills/refactor-analyze/SKILL.md`
- Sync: `.cursor/skills/troubleshoot/SKILL.md`

- [ ] **Step 1: `skills/refactor-analyze/SKILL.md` 끝에 산출물 저장 섹션 추가**

파일 끝에 다음을 추가한다:

```markdown

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path refactor-analyze
```

반환된 경로에 파일을 저장한다.
```

- [ ] **Step 2: `.cursor/skills/refactor-analyze/SKILL.md` 동기화 및 확인**

```bash
cp skills/refactor-analyze/SKILL.md .cursor/skills/refactor-analyze/SKILL.md
diff skills/refactor-analyze/SKILL.md .cursor/skills/refactor-analyze/SKILL.md
```

Expected: 출력 없음

- [ ] **Step 3: `skills/troubleshoot/SKILL.md` 끝에 산출물 저장 섹션 추가**

파일 끝에 다음을 추가한다:

```markdown

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path troubleshoot
```

반환된 경로에 파일을 저장한다.
```

- [ ] **Step 4: `.cursor/skills/troubleshoot/SKILL.md` 동기화 및 확인**

```bash
cp skills/troubleshoot/SKILL.md .cursor/skills/troubleshoot/SKILL.md
diff skills/troubleshoot/SKILL.md .cursor/skills/troubleshoot/SKILL.md
```

Expected: 출력 없음

- [ ] **Step 5: 커밋**

```bash
git add skills/refactor-analyze/SKILL.md skills/troubleshoot/SKILL.md
git add .cursor/skills/refactor-analyze/SKILL.md .cursor/skills/troubleshoot/SKILL.md
git commit -m "feat: refactor-analyze/troubleshoot skill 산출물 경로 표준화 적용"
```

---

## Task 3: report SKILL.md — 기존 경로 교체

**Files:**
- Modify: `skills/report/SKILL.md` (기존 `.report/` 경로 → 새 표준 경로)
- Sync: `.cursor/skills/report/SKILL.md`

현재 `report` skill의 출력 경로:
```
**파일 위치**: `.report/[YYYYMMDD]_[#이슈번호]_설명.md`
```

이것을 새 표준 경로 섹션으로 교체한다.

- [ ] **Step 1: `skills/report/SKILL.md`에서 기존 파일 위치 라인 찾기**

```bash
grep -n "파일 위치\|\.report/" skills/report/SKILL.md
```

해당 라인 번호 확인.

- [ ] **Step 2: 기존 파일 위치 라인을 새 표준으로 교체**

`**파일 위치**: `.report/[YYYYMMDD]_[#이슈번호]_설명.md`` 라인을 삭제하고,
파일 끝에 다음 섹션을 추가한다:

```markdown

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path report
```

반환된 경로에 파일을 저장한다.
```

- [ ] **Step 3: 변경 확인**

```bash
grep -n "파일 위치\|\.report/\|doc-output-path\|get-output-path" skills/report/SKILL.md
```

Expected: `.report/` 라인 없음, `doc-output-path` 및 `get-output-path report` 라인 있음

- [ ] **Step 4: `.cursor/skills/report/SKILL.md` 동기화 및 확인**

```bash
cp skills/report/SKILL.md .cursor/skills/report/SKILL.md
diff skills/report/SKILL.md .cursor/skills/report/SKILL.md
```

Expected: 출력 없음

- [ ] **Step 5: 커밋**

```bash
git add skills/report/SKILL.md .cursor/skills/report/SKILL.md
git commit -m "feat: report skill 산출물 경로 표준화 적용 (.report/ → docs/suh-template/report/)"
```

---

## Task 4: ppt, review SKILL.md 업데이트

**Files:**
- Modify: `skills/ppt/SKILL.md`
- Modify: `skills/review/SKILL.md`
- Sync: `.cursor/skills/ppt/SKILL.md`
- Sync: `.cursor/skills/review/SKILL.md`

- [ ] **Step 1: `skills/ppt/SKILL.md` 끝에 산출물 저장 섹션 추가**

파일 끝에 다음을 추가한다:

```markdown

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path ppt
```

반환된 경로에 파일을 저장한다.
```

- [ ] **Step 2: `.cursor/skills/ppt/SKILL.md` 동기화 및 확인**

```bash
cp skills/ppt/SKILL.md .cursor/skills/ppt/SKILL.md
diff skills/ppt/SKILL.md .cursor/skills/ppt/SKILL.md
```

Expected: 출력 없음

- [ ] **Step 3: `skills/review/SKILL.md` 끝에 산출물 저장 섹션 추가**

파일 끝에 다음을 추가한다:

```markdown

## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path review
```

반환된 경로에 파일을 저장한다.
```

- [ ] **Step 4: `.cursor/skills/review/SKILL.md` 동기화 및 확인**

```bash
cp skills/review/SKILL.md .cursor/skills/review/SKILL.md
diff skills/review/SKILL.md .cursor/skills/review/SKILL.md
```

Expected: 출력 없음

- [ ] **Step 5: 커밋**

```bash
git add skills/ppt/SKILL.md skills/review/SKILL.md
git add .cursor/skills/ppt/SKILL.md .cursor/skills/review/SKILL.md
git commit -m "feat: ppt/review skill 산출물 경로 표준화 적용"
```

---

## Task 5: 전체 검증

- [ ] **Step 1: 8개 skill 모두 산출물 저장 섹션 있는지 확인**

```bash
for skill in analyze plan design-analyze refactor-analyze troubleshoot report ppt review; do
  echo -n "$skill: "
  grep -c "get-output-path" skills/$skill/SKILL.md
done
```

Expected: 각 skill마다 `1` 출력

- [ ] **Step 2: skills/와 .cursor/skills/ 동일한지 확인**

```bash
for skill in analyze plan design-analyze refactor-analyze troubleshoot report ppt review; do
  result=$(diff skills/$skill/SKILL.md .cursor/skills/$skill/SKILL.md)
  if [ -z "$result" ]; then
    echo "$skill: ✅ 동일"
  else
    echo "$skill: ❌ 불일치"
  fi
done
```

Expected: 8개 모두 `✅ 동일`

- [ ] **Step 3: report skill `.report/` 경로 제거됐는지 확인**

```bash
grep "\.report/" skills/report/SKILL.md
```

Expected: 출력 없음 (경로 제거됨)

- [ ] **Step 4: 각 skill_id로 get-output-path 실제 동작 확인**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts
for skill in analyze plan design-analyze refactor-analyze troubleshoot report ppt review; do
  echo -n "$skill: "
  python3 -m suh_template.cli get-output-path $skill 2>/dev/null || echo "(경고 있음 — 정상)"
done
```

Expected: 각 skill마다 `docs/suh-template/{skill}/YYYYMMDD_NNN_untitled.md` 형태 경로 반환

- [ ] **Step 5: 최종 커밋**

```bash
git add -A
git commit -m "feat: sub-project #2 8개 skill 산출물 경로 표준화 완료"
```
