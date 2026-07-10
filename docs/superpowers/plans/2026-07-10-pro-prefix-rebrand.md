# pro- 프리픽스 스킬 리브랜딩 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** projectops 스킬 25개의 이름을 `pro-<name>`으로 전면 리브랜딩하여, pi 멀티팩 환경에서 사내 somansa-claude-code 스킬(analyze/implement/report/review/skill-creator/ssh/testcase)과의 이름 충돌을 근본 해소한다.

**Architecture:** pi는 skill을 flat `name`(frontmatter `name:` 우선, 없으면 폴더명)으로만 식별하고 플러그인 네임스페이스 호출을 지원하지 않는다(소스 확인: `@earendil-works/pi-coding-agent/dist/core/skills.js`). 따라서 프리픽스가 유일한 충돌 회피책이다. 폴더 rename + `name:` 필드 + 모든 살아있는 참조(SKILL.md 캐시 glob·CLI scripts 경로·테스트·문서 호출 표기)를 `pro-`로 일괄 치환한다. 플러그인명(`projectops`)·레포 URL·Docker 태그는 유지(외부 파급효과 회피).

**Tech Stack:** Git(파일 rename), Node.js `node --test`(JS 회귀), Python `pytest`(py 회귀). 셸은 Git Bash.

## Global Constraints

- **프리픽스**: 정확히 `pro-`. 스킬 이름은 `pro-<name>` (예: `pro-analyze`, `pro-github`).
- **대상 스킬 25개** (정확히 이 목록, `references` 폴더 제외):
  `analyze build changelog-deploy commit design design-analyze document figma github implement init-worktree issue plan ppt refactor refactor-analyze report review skill-creator spring-test ssh synology-expose test testcase troubleshoot`
- **껍데기 폴더 3개 삭제**: `skills/suh-changelog-deploy` `skills/suh-github` `skills/suh-issue` (SKILL.md 없이 scripts만 남은 #459 중단 잔재. 살아있는 코드 참조 없음 — 확인됨).
- **플러그인명/레포/Docker 태그 유지**: `projectops`(플러그인명), `github.com/Cassiiopeia/projectops`(레포), `projectops:latest`(Docker 이미지 태그), `projectops:xxx`(문서 placeholder 예시)는 **치환 금지**.
- **보존 대상 (절대 치환 금지 — 과잉 치환 시 사용자 빌드 파손)**:
  `me.suhsaechan:suh-logger`(Maven), `suh-project-utility`(레포명), `suhsaechan`·`me.suhsaechan`(계정·groupId), `*.suhsaechan.kr`(도메인), `Cassiiopeia`(대문자 조직명), `Guide by SUH-LAB`(외부 봇 서명), `@suh-lab`은 이미 중립화됨(잔재 검사 대상).
- **치환 방식**: 일괄 sed 금지. **화이트리스트(25개 스킬명) 기반 정확 치환**만. `pro-`를 붙일 때 이미 `pro-`가 붙은 것에 중복(`pro-pro-`) 방지.
- **테스트 기준선**: 시작 시 pytest 48/48 green, npm test 186/187(1 fail = `rename-consistency.test.js`가 껍데기 suh- 폴더 3개를 잡는 기존 실패). 완료 시 pytest 48/48 + npm test 187/187 green이어야 한다.
- **커밋 규칙**: 커밋 메시지에 이모지·태그 prefix 금지. Claude/AI 흔적(Co-Authored-By 등) 금지. `develop` 브랜치에서 작업. push는 사용자 명시 요청 시에만.

---

## File Structure

리브랜딩이 건드리는 파일 그룹:

| 그룹 | 파일 | 변경 내용 |
|------|------|----------|
| 스킬 폴더 | `skills/<name>/` × 25 | `git mv` → `skills/pro-<name>/` |
| SKILL.md name | `skills/pro-<name>/SKILL.md` line 2 | `name: <name>` → `name: pro-<name>` |
| SKILL.md 캐시 glob | 각 SKILL.md 내 `skills/<name>/scripts` | → `skills/pro-<name>/scripts` |
| CLI scripts 경로 | `github_cli.py` `issue_cli.py` `report_cli.py` 헤더 주석 `cd skills/<name>/scripts` | → `pro-<name>` |
| py 테스트 경로 | `scripts/tests/test_cli_body_file.py` `sys.path` | `skills/issue`·`skills/github` → `pro-` |
| 정합성 테스트 | `test/rename-consistency.test.js` | 기대 폴더명 25개 → `pro-` 접두, suh- 검사 유지 |
| 문서 호출 표기 | `*.md` 내 `projectops:<skill>`·`/projectops:<skill>`·`cassiiopeia:suh-<skill>` | → `pro-<skill>` (스킬 호출만; 플러그인/Docker/placeholder 제외) |
| 껍데기 삭제 | `skills/suh-{github,issue,changelog-deploy}/` | `git rm -r` |

**참고**: IDE 어댑터(`src/core/ide/adapters/cursor.js`·`codex.js`)는 `skills/` 폴더를 통째 복사하는 방식이라 스킬명 하드코딩이 없다 → 폴더 rename 시 자동으로 따라간다. 매니페스트(`.claude-plugin/plugin.json` 등)는 플러그인명만 담고 개별 스킬명은 없다 → 무변경.

---

## Task 0: GitHub 이슈 생성 (작업 추적)

**Files:** 없음(GitHub 이슈)

**배경:** 이 리브랜딩은 breaking change이며 이슈로 추적한다. CLAUDE.md 규칙상 GitHub 작업은 `github`(구 suh-github) 스킬 / `github_cli.py`로 수행한다. `gh` CLI 금지.

**Interfaces:**
- Consumes: 없음
- Produces: 이슈 번호 `#N`. 이후 모든 Task 커밋 메시지 끝에 이슈 URL을 붙인다 (레포 컨벤션: `... : type : 설명 (#N) https://github.com/Cassiiopeia/projectops/issues/N`).

- [ ] **Step 1: 이슈 생성 (github 스킬 또는 github_cli.py create-issue)**

제목(이모지·태그 prefix 금지, 순수 내용만):
```
Skills pi 멀티팩 환경 스킬 이름 충돌 해소 — 전체 스킬 pro- 프리픽스 리브랜딩
```
본문 요지:
```
## 배경
pi 멀티팩 환경(somansa-claude-code + projectops 동시 로드)에서 projectops 스킬 7개(analyze/implement/report/review/skill-creator/ssh/testcase)가 사내 스킬과 이름 충돌하여 skipped 됨.

## 원인
#459 중립화로 suh- 접두사를 제거해 이름이 사내 스킬과 겹침. pi는 skill을 flat name으로만 식별하고 플러그인 네임스페이스 호출을 지원하지 않음(소스: @earendil-works/pi-coding-agent/dist/core/skills.js) → 프리픽스가 유일 해법.

## 변경
- 스킬 25개 폴더·name·참조를 pro-<name>으로 리브랜딩
- 껍데기 suh-{github,issue,changelog-deploy} 폴더 삭제
- 문서·CLAUDE.md·breaking-changes.json(4.3.0) pro- 반영
- 플러그인명/레포/Docker 태그는 유지

계획: docs/superpowers/plans/2026-07-10-pro-prefix-rebrand.md
```

Run (github_cli.py 경로는 캐시 우선 → 프로젝트 폴백):
```bash
cd D:/0-suh/project/suh-github-template
PYTHON=$(for _py in python python3; do _p=$(command -v "$_py" 2>/dev/null) || continue; "$_p" -c "import sys;sys.exit(0)" 2>/dev/null && echo "$_p" && break; done)
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PWD/skills/pro-github/scripts"
# create-issue 서브커맨드 사용 (본문은 파일로 전달 — heredoc/한글 이스케이프 회피)
```
> **주의:** 이슈 생성은 `github`(구 suh-github) 스킬을 호출해 대화형으로 수행하는 것이 안전하다(제목 정규화·이슈 번호 시퀀스·config PAT 자동 로드). 실행자는 `github` 스킬을 Skill 도구로 호출하고 위 제목·본문을 넘긴다.

- [ ] **Step 2: 생성된 이슈 번호 기록**

이슈 번호 `#N`을 이후 Task 1-8의 커밋 메시지 끝에 붙인다. (계획의 커밋 메시지 예시들은 `(#N) <URL>`을 생략했으니, 실행 시 각 커밋 메시지 끝에 ` (#N) https://github.com/Cassiiopeia/projectops/issues/N`을 추가한다.)

---

## Task 1: 껍데기 suh- 폴더 3개 삭제

**Files:**
- Delete: `skills/suh-changelog-deploy/` `skills/suh-github/` `skills/suh-issue/`
- Verify: `test/rename-consistency.test.js` (line 56-60 "skills/ 아래 suh- 폴더가 0개다")

**Interfaces:**
- Consumes: 없음
- Produces: `skills/` 아래 `suh-` 폴더 0개 상태 (Task 6 테스트의 전제)

- [ ] **Step 1: 삭제 전 껍데기 확인 (SKILL.md 없음·살아있는 코드 참조 없음 재확인)**

Run:
```bash
cd D:/0-suh/project/suh-github-template
for d in suh-changelog-deploy suh-github suh-issue; do
  echo "=== $d ==="; ls skills/$d; [ -f skills/$d/SKILL.md ] && echo "!!! SKILL.md 존재 - 중단" || echo "OK: 껍데기"
done
grep -rn "skills/suh-github\|skills/suh-issue\|skills/suh-changelog-deploy" . --include="*.py" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v "/tests/\|test_\|.superpowers/"
```
Expected: 3개 모두 "OK: 껍데기", 마지막 grep은 **빈 출력**(살아있는 코드 참조 없음). `.superpowers/sdd/` 브리핑 문서 참조는 과거 기록이라 무시.

- [ ] **Step 2: git rm으로 삭제**

Run:
```bash
git rm -r skills/suh-changelog-deploy skills/suh-github skills/suh-issue
```
Expected: 3개 폴더 하위 파일들이 staged deletion.

- [ ] **Step 3: 삭제 확인**

Run: `ls -d skills/suh-*/ 2>/dev/null; echo "exit=$?"`
Expected: 출력 없음(폴더 0개).

- [ ] **Step 4: 정합성 테스트 중 suh- 검사만 통과 확인**

Run: `node --test test/rename-consistency.test.js 2>&1 | grep -E "suh- 폴더가 0개"`
Expected: 해당 테스트 `✔ pass` (다른 테스트는 아직 실패해도 됨 — Task 2·6에서 해결).

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "껍데기 suh- 스킬 폴더 3개 삭제 : chore : SKILL.md 없이 scripts만 남은 #459 중단 잔재 제거"
```

---

## Task 2: 스킬 폴더 25개 rename + name 필드 변경

**Files:**
- Rename: `skills/<name>/` → `skills/pro-<name>/` × 25
- Modify: `skills/pro-<name>/SKILL.md` line 2 `name:` × 25

**Interfaces:**
- Consumes: Task 1 완료 상태(suh- 폴더 없음)
- Produces: `skills/pro-<name>/SKILL.md` 25개, 각 `name: pro-<name>`. Task 3·4·5·6이 이 경로·이름에 의존.

- [ ] **Step 1: rename + name 치환 스크립트 실행 (25개 일괄, git mv)**

Run:
```bash
cd D:/0-suh/project/suh-github-template
SKILLS="analyze build changelog-deploy commit design design-analyze document figma github implement init-worktree issue plan ppt refactor refactor-analyze report review skill-creator spring-test ssh synology-expose test testcase troubleshoot"
for s in $SKILLS; do
  [ -d "skills/$s" ] || { echo "!!! 없음: skills/$s"; continue; }
  git mv "skills/$s" "skills/pro-$s"
  # name: <s> -> name: pro-<s> (line 2, 정확 매칭)
  sed -i "s/^name: ${s}\$/name: pro-${s}/" "skills/pro-$s/SKILL.md"
done
```
Expected: 25개 폴더 rename + name 치환. 에러 없음.

- [ ] **Step 2: name 필드 전수 검증**

Run:
```bash
for d in skills/pro-*/; do
  n=$(grep -m1 "^name:" "$d/SKILL.md" | sed 's/name:[[:space:]]*//')
  exp="pro-$(basename $d | sed 's/^pro-//')"
  [ "$n" = "$exp" ] || echo "MISMATCH: $d -> name=$n (기대 $exp)"
done
echo "검증 완료 (위에 MISMATCH 없으면 OK)"
ls -d skills/pro-*/ | wc -l
```
Expected: MISMATCH 출력 없음. 폴더 개수 25.

- [ ] **Step 3: 남은 프리픽스 없는 스킬 폴더 없는지 확인 (references만 남아야)**

Run:
```bash
for d in skills/*/; do n=$(basename "$d"); case "$n" in pro-*|references) ;; *) echo "잔존: $n";; esac; done
echo "확인 완료"
```
Expected: "잔존:" 출력 없음 (references 제외 전부 pro-).

- [ ] **Step 4: 커밋**

```bash
git add -A
git commit -m "스킬 폴더·name 25개 pro- 프리픽스 적용 : refactor : pi flat name 충돌 회피 위해 skills/<name>->skills/pro-<name>"
```

---

## Task 3: SKILL.md 내부 캐시 glob·scripts 경로 치환

**Files:**
- Modify: `skills/pro-<name>/SKILL.md` 내 `skills/<name>/scripts` 및 `cache/*/projectops/*/skills/<name>/scripts` 참조

**Interfaces:**
- Consumes: Task 2 완료(pro- 폴더·name)
- Produces: SKILL.md 내 자기 scripts 경로가 `skills/pro-<name>/scripts`로 일치. Task 4 CLI 헤더 주석과 정합.

- [ ] **Step 1: 치환 전 현황 파악 (어떤 SKILL.md가 skills/<oldname> 참조하나)**

Run:
```bash
cd D:/0-suh/project/suh-github-template
SKILLS="analyze build changelog-deploy commit design design-analyze document figma github implement init-worktree issue plan ppt refactor refactor-analyze report review skill-creator spring-test ssh synology-expose test testcase troubleshoot"
for s in $SKILLS; do
  # pro- 안 붙은 skills/<s>/ 참조 (단어경계로 정확 매칭, pro-<s> 오검출 방지)
  grep -rln "skills/${s}/" skills/pro-*/SKILL.md 2>/dev/null | while read f; do
    grep -q "skills/pro-${s}/" "$f" && continue  # 이미 pro- 이면 스킵될 케이스는 아래 sed가 처리
    echo "$f: skills/${s}/"
  done
done | sort -u | head -40
```
Expected: `skills/github/scripts` 등 참조 목록. (예: `pro-github/SKILL.md`가 `skills/github/scripts`를 여전히 참조)

- [ ] **Step 2: 정확 치환 실행 (skills/<oldname>/ → skills/pro-<oldname>/, 이미 pro- 인 건 제외)**

Run:
```bash
SKILLS="analyze build changelog-deploy commit design design-analyze document figma github implement init-worktree issue plan ppt refactor refactor-analyze report review skill-creator spring-test ssh synology-expose test testcase troubleshoot"
for f in skills/pro-*/SKILL.md; do
  for s in $SKILLS; do
    # 'skills/pro-<s>'는 건드리지 않고 'skills/<s>'만 치환:
    # 앞에 'pro-'가 안 붙은 skills/<s>/ 를 skills/pro-<s>/ 로. (negative lookbehind 대신 2단계)
    sed -i "s#skills/pro-${s}/#__KEEP_${s}__#g" "$f"      # 이미 pro- 인 것 보호
    sed -i "s#skills/${s}/#skills/pro-${s}/#g" "$f"        # 남은 것 치환
    sed -i "s#__KEEP_${s}__#skills/pro-${s}/#g" "$f"       # 보호 복원
  done
done
echo "치환 완료"
```
Expected: 에러 없음.

- [ ] **Step 3: 이중 프리픽스(pro-pro-) 없는지 검증**

Run: `grep -rn "pro-pro-\|skills/pro-pro" skills/pro-*/SKILL.md 2>/dev/null; echo "exit=$? (빈 출력이면 정상)"`
Expected: 출력 없음.

- [ ] **Step 4: 대표 SKILL.md에서 캐시 glob 경로 확인 (github)**

Run: `grep -n "skills/pro-github/scripts\|skills/github/scripts" skills/pro-github/SKILL.md | head`
Expected: `skills/pro-github/scripts`만 나오고 `skills/github/scripts`(pro- 없는)는 없음.

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "SKILL.md 내부 scripts·캐시 glob 경로 pro- 반영 : refactor : skills/<name>/scripts->skills/pro-<name>/scripts"
```

---

## Task 4: CLI scripts 헤더 주석 경로 치환

**Files:**
- Modify: `skills/pro-github/scripts/github_cli.py:9` (`cd skills/github/scripts`)
- Modify: `skills/pro-issue/scripts/issue_cli.py:9` (`cd skills/issue/scripts`)
- Modify: `skills/pro-report/scripts/report_cli.py:8` (`cd skills/report/scripts`)

**Interfaces:**
- Consumes: Task 2 완료(pro- 폴더)
- Produces: CLI 헤더 주석의 예시 경로가 `skills/pro-<name>/scripts`. (기능 무영향 — 주석. 문서 정합성 목적.)

- [ ] **Step 1: 현황 확인**

Run:
```bash
cd D:/0-suh/project/suh-github-template
grep -n "cd skills/" skills/pro-github/scripts/github_cli.py skills/pro-issue/scripts/issue_cli.py skills/pro-report/scripts/report_cli.py
```
Expected: 3개 파일에서 `cd skills/github/scripts`·`cd skills/issue/scripts`·`cd skills/report/scripts` 각 1건.

- [ ] **Step 2: 치환**

Run:
```bash
sed -i "s#cd skills/github/scripts#cd skills/pro-github/scripts#" skills/pro-github/scripts/github_cli.py
sed -i "s#cd skills/issue/scripts#cd skills/pro-issue/scripts#" skills/pro-issue/scripts/issue_cli.py
sed -i "s#cd skills/report/scripts#cd skills/pro-report/scripts#" skills/pro-report/scripts/report_cli.py
grep -n "cd skills/" skills/pro-github/scripts/github_cli.py skills/pro-issue/scripts/issue_cli.py skills/pro-report/scripts/report_cli.py
```
Expected: 3개 모두 `cd skills/pro-<name>/scripts`.

- [ ] **Step 3: 커밋**

```bash
git add -A
git commit -m "CLI 헤더 주석 scripts 경로 pro- 반영 : docs : github/issue/report cli 예시 경로 정합"
```

---

## Task 5: py 테스트 sys.path 경로 치환

**Files:**
- Modify: `scripts/tests/test_cli_body_file.py:9-12` (`skills/issue/scripts`·`skills/github/scripts` sys.path insert)

**Interfaces:**
- Consumes: Task 2 완료(pro- 폴더)
- Produces: pytest가 `skills/pro-issue/scripts`·`skills/pro-github/scripts`를 import 경로로 사용 → py 테스트 green 유지.

- [ ] **Step 1: 현황 확인**

Run:
```bash
cd D:/0-suh/project/suh-github-template
grep -n "skills/issue/scripts\|skills/github/scripts" scripts/tests/test_cli_body_file.py
```
Expected: line 9-12 부근에 `skills/issue/scripts`·`skills/github/scripts` 참조.

- [ ] **Step 2: 다른 py 테스트도 skills/<name> 하드코딩하는지 전수 확인**

Run:
```bash
grep -rn "skills/[a-z-]*/scripts\|skills/[a-z-]*/SKILL" scripts/tests/*.py 2>/dev/null | grep -v "pro-" | head -20
```
Expected: `test_cli_body_file.py` 외에 다른 파일도 있으면 목록에 나옴. **나오는 모든 파일을 Step 3에서 함께 치환.**

- [ ] **Step 3: 치환 (Step 2에서 발견된 모든 py 테스트 파일 대상)**

Run:
```bash
# test_cli_body_file.py (확인된 파일). Step 2에서 추가 발견된 파일이 있으면 같은 패턴으로 추가.
SKILLS="analyze build changelog-deploy commit design design-analyze document figma github implement init-worktree issue plan ppt refactor refactor-analyze report review skill-creator spring-test ssh synology-expose test testcase troubleshoot"
for f in $(grep -rln "skills/[a-z-]*/scripts\|skills/[a-z-]*/SKILL" scripts/tests/*.py 2>/dev/null); do
  for s in $SKILLS; do
    sed -i "s#skills/pro-${s}/#__KEEP_${s}__#g" "$f"
    sed -i "s#skills/${s}/#skills/pro-${s}/#g" "$f"
    sed -i "s#__KEEP_${s}__#skills/pro-${s}/#g" "$f"
  done
done
grep -n "skills/pro" scripts/tests/test_cli_body_file.py
grep -rn "pro-pro-" scripts/tests/*.py; echo "pro-pro exit=$?"
```
Expected: `test_cli_body_file.py`가 `skills/pro-issue/scripts`·`skills/pro-github/scripts` 참조. pro-pro- 없음.

- [ ] **Step 4: pytest 전체 실행 (green 유지 확인)**

Run:
```bash
PYTHON=$(for _py in python python3; do _p=$(command -v "$_py" 2>/dev/null) || continue; "$_p" -c "import sys;sys.exit(0)" 2>/dev/null && echo "$_p" && break; done)
"$PYTHON" -m pytest scripts/tests/ -q 2>&1 | tail -5
```
Expected: `48 passed` (기준선과 동일).

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "py 테스트 sys.path 스킬 경로 pro- 반영 : test : test_cli_body_file skills/pro-* import 경로 정합"
```

---

## Task 6: 정합성 테스트(rename-consistency) 기대값을 pro-로 갱신

**Files:**
- Modify: `test/rename-consistency.test.js:62-72` (25개 기대 폴더명 → `pro-` 접두)
- Modify: `test/rename-consistency.test.js:56-60` (suh- 검사 — pro-와 무관, 그대로 유지)
- Modify: `test/rename-consistency.test.js:95-98` (보존: suh-logger가 `skills/pro-spring-test/`에 — 경로 갱신)

**Interfaces:**
- Consumes: Task 1(suh- 폴더 0), Task 2(pro- 폴더 25)
- Produces: 정합성 테스트가 pro- 체계를 검증하는 회귀 스펙으로 갱신됨.

- [ ] **Step 1: 기대 폴더 목록 25개를 pro- 접두로 변경 (line 63-68)**

Modify `test/rename-consistency.test.js` line 62-72 블록. 기존:
```js
  test("25개 중립 스킬 폴더가 모두 존재한다", () => {
    const expected = [
      "analyze", "build", "changelog-deploy", "commit", "design", "design-analyze",
      "document", "figma", "github", "implement", "init-worktree", "issue", "plan",
      "ppt", "refactor", "refactor-analyze", "report", "review", "skill-creator",
      "spring-test", "ssh", "synology-expose", "test", "testcase", "troubleshoot",
    ];
    for (const s of expected) {
      assert.ok(existsSync(join(ROOT, "skills", s, "SKILL.md")), `누락: skills/${s}/SKILL.md`);
    }
  });
```
로 변경:
```js
  test("25개 pro- 스킬 폴더가 모두 존재한다", () => {
    const expected = [
      "pro-analyze", "pro-build", "pro-changelog-deploy", "pro-commit", "pro-design", "pro-design-analyze",
      "pro-document", "pro-figma", "pro-github", "pro-implement", "pro-init-worktree", "pro-issue", "pro-plan",
      "pro-ppt", "pro-refactor", "pro-refactor-analyze", "pro-report", "pro-review", "pro-skill-creator",
      "pro-spring-test", "pro-ssh", "pro-synology-expose", "pro-test", "pro-testcase", "pro-troubleshoot",
    ];
    for (const s of expected) {
      assert.ok(existsSync(join(ROOT, "skills", s, "SKILL.md")), `누락: skills/${s}/SKILL.md`);
    }
  });
```

- [ ] **Step 2: 보존 테스트의 spring-test 경로를 pro-spring-test로 (line 95-98)**

Modify line 95-98 블록. 기존:
```js
  test("보존: suh-logger Maven 의존성이 spring-test SKILL에 남아있다", () => {
    const hits = findFiles("me.suhsaechan:suh-logger", ["skills/spring-test/"]);
    assert.ok(hits.length > 0, "me.suhsaechan:suh-logger가 사라짐(과잉 치환)");
  });
```
로 변경:
```js
  test("보존: suh-logger Maven 의존성이 pro-spring-test SKILL에 남아있다", () => {
    const hits = findFiles("me.suhsaechan:suh-logger", ["skills/pro-spring-test/"]);
    assert.ok(hits.length > 0, "me.suhsaechan:suh-logger가 사라짐(과잉 치환)");
  });
```

- [ ] **Step 3: cassiiopeia:suh- 잔재 검사(line 74-77)는 그대로 — Task 7이 통과시킴. suh- 폴더 검사(56-60)도 그대로.** 변경 없음 확인.

Run: `grep -n "cassiiopeia:suh-\|suh- 폴더가 0개" test/rename-consistency.test.js`
Expected: 두 테스트 모두 존재(우리가 지운 건 폴더명 기대값·보존 경로뿐).

- [ ] **Step 4: 이 테스트 파일만 실행**

Run: `node --test test/rename-consistency.test.js 2>&1 | grep -E "^# (pass|fail)|✔|✖" | head -20`
Expected: 모든 서브테스트 pass. (단 `cassiiopeia:suh-` 잔재 테스트는 Task 7 전이면 실패할 수 있음 — 그 경우 Task 7 후 재확인.)

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "정합성 테스트 기대값 pro- 체계로 갱신 : test : rename-consistency 폴더 25개·보존 경로 pro- 반영"
```

---

## Task 7: 문서·CLAUDE.md 스킬 호출 표기 pro-로 치환

**Files:**
- Modify: `*.md`(활성 문서) 내 `projectops:<skill>`·`/projectops:<skill>`·`cassiiopeia:suh-<skill>` → `pro-<skill>`
- 제외: `docs/superpowers/`·`docs/projectops/`(과거 산출물), `CHANGELOG.*`, `breaking-changes.json`, `test/rename-consistency.test.js`(검색어 리터럴 포함)

**Interfaces:**
- Consumes: Task 2(스킬 이름 확정)
- Produces: 활성 문서의 스킬 호출 표기가 `pro-<skill>`로 통일. `rename-consistency` 잔재 테스트(cassiiopeia:suh-·소문자 cassiiopeia) green.

- [ ] **Step 1: 치환 대상 파일 목록 확보 (제외 규칙 적용)**

Run:
```bash
cd D:/0-suh/project/suh-github-template
git ls-files "*.md" | grep -vE "^(docs/superpowers/|docs/projectops/|CHANGELOG)" > /tmp/pro_md_targets.txt
wc -l /tmp/pro_md_targets.txt
# 어떤 표기가 남아있나 미리보기
grep -lE "projectops:[a-z]|cassiiopeia:suh-" $(cat /tmp/pro_md_targets.txt) 2>/dev/null | head -20
```
Expected: 대상 md 목록. CLAUDE.md·README·docs/SKILLS.md 등 포함.

- [ ] **Step 2: 스킬 호출 표기만 정확 치환 (25개 화이트리스트, Docker/placeholder 보호)**

Run:
```bash
SKILLS="analyze build changelog-deploy commit design design-analyze document figma github implement init-worktree issue plan ppt refactor refactor-analyze report review skill-creator spring-test ssh synology-expose test testcase troubleshoot"
for f in $(cat /tmp/pro_md_targets.txt); do
  [ -f "$f" ] || continue
  # 보호: Docker 태그·placeholder (projectops:latest, projectops:xxx)
  sed -i "s#projectops:latest#__DOCKER_TAG__#g; s#projectops:xxx#__PLACEHOLDER__#g" "$f"
  for s in $SKILLS; do
    # /cassiiopeia:suh-<s> 및 cassiiopeia:suh-<s> -> pro-<s>
    sed -i "s#cassiiopeia:suh-${s}\b#pro-${s}#g" "$f"
    # /projectops:<s> 및 projectops:<s> -> pro-<s>  (단어경계로 정확 매칭)
    sed -i "s#projectops:${s}\b#pro-${s}#g" "$f"
  done
  # 보호 복원
  sed -i "s#__DOCKER_TAG__#projectops:latest#g; s#__PLACEHOLDER__#projectops:xxx#g" "$f"
done
echo "치환 완료"
```
Expected: 에러 없음.

- [ ] **Step 3: 잔재·과잉치환 검증**

Run:
```bash
echo "=== 남은 projectops:<skill> (스킬 호출) — Docker/placeholder만 남아야 ==="
grep -rhoE "projectops:[a-z-]+" $(cat /tmp/pro_md_targets.txt) 2>/dev/null | sort | uniq -c
echo "=== cassiiopeia:suh- 잔재 (0이어야) ==="
grep -rl "cassiiopeia:suh-" $(cat /tmp/pro_md_targets.txt) 2>/dev/null | wc -l
echo "=== pro-pro- 이중 프리픽스 (0이어야) ==="
grep -rl "pro-pro-" $(cat /tmp/pro_md_targets.txt) 2>/dev/null | wc -l
echo "=== 보존 확인: projectops:latest 살아있나 ==="
grep -rn "projectops:latest" $(cat /tmp/pro_md_targets.txt) 2>/dev/null | wc -l
```
Expected: 첫 블록은 `projectops:latest`·`projectops:xxx`만(스킬명 없음). cassiiopeia:suh- 0건. pro-pro- 0건. projectops:latest ≥1(보존됨).

- [ ] **Step 4: 커밋**

```bash
git add -A
git commit -m "문서·CLAUDE.md 스킬 호출 표기 pro- 통일 : docs : projectops:<skill>·cassiiopeia:suh->pro-<skill>(Docker 태그·placeholder 보존)"
```

---

## Task 7.5: breaking-changes.json 4.3.0 항목을 pro- 체계로 수정

**Files:**
- Modify: `.github/config/breaking-changes.json` (키 `4.3.0` 항목의 message)

**배경:** 현재 버전은 4.2.4이고 `4.3.0`은 **아직 릴리스되지 않은** 항목이다. #459 중립화와 이번 pro- 리브랜딩이 같은 4.3.0 릴리스에 합쳐지므로, 4.3.0 항목의 스킬 커맨드 안내를 `/projectops:issue` → `pro-issue`로 고쳐 사용자 혼란(중립화했다가 다시 pro-화)을 없앤다. 새 버전 항목을 추가하지 않는다.

**Interfaces:**
- Consumes: Task 2·7(pro- 스킬 이름·문서 표기 확정)
- Produces: 4.3.0 breaking change가 pro- 커맨드 체계를 정확히 안내.

- [ ] **Step 1: 현재 4.3.0 항목 확인**

Run:
```bash
cd D:/0-suh/project/suh-github-template
grep -n "projectops:issue\|4.3.0\|suh-issue" .github/config/breaking-changes.json
```
Expected: `4.3.0` 항목 message에 `/cassiiopeia:suh-issue` → `/projectops:issue` 안내가 있음.

- [ ] **Step 2: 4.3.0 message의 [1] 스킬 커맨드 절을 pro-로 수정**

`.github/config/breaking-changes.json`의 `4.3.0` 항목 message 중 `[1]` 절을 수정한다. 기존 `[1]` 절:
```
[1] 스킬 커맨드: '/cassiiopeia:suh-issue' → '/projectops:issue'(suh- 접두사 제거, 25개 스킬 전부). 기존 커맨드는 더 이상 동작하지 않습니다 — 플러그인을 재설치하세요: 'claude plugin marketplace add Cassiiopeia/projectops && claude plugin install projectops@projectops-marketplace --scope user'.
```
를 다음으로 교체:
```
[1] 스킬 커맨드: '/cassiiopeia:suh-issue' → 'pro-issue'(브랜드 접두사를 pro-로 통일, 25개 스킬 전부). pi 등 멀티팩 환경에서 사내 스킬과 이름이 충돌하지 않도록 모든 스킬 이름에 pro- 접두사를 붙였습니다. 기존 커맨드는 더 이상 동작하지 않습니다 — 플러그인을 재설치하세요: 'claude plugin marketplace add Cassiiopeia/projectops && claude plugin install projectops@projectops-marketplace --scope user'. Claude Code에서는 '/pro-issue', pi에서는 'pro-issue'로 호출합니다.
```

- [ ] **Step 3: JSON 유효성 검증**

Run:
```bash
PYTHON=$(for _py in python python3; do _p=$(command -v "$_py" 2>/dev/null) || continue; "$_p" -c "import sys;sys.exit(0)" 2>/dev/null && echo "$_p" && break; done)
"$PYTHON" -c "import json; json.load(open('.github/config/breaking-changes.json')); print('JSON OK')"
grep -c "pro-issue" .github/config/breaking-changes.json
```
Expected: `JSON OK`. pro-issue 1건 이상.

- [ ] **Step 4: 커밋**

```bash
git add .github/config/breaking-changes.json
git commit -m "breaking-changes 4.3.0 항목 pro- 커맨드 체계로 수정 : docs : 미릴리스 4.3.0 스킬 커맨드 안내를 projectops:->pro-로 통합"
```

---

## Task 8: 전체 회귀 + 최종 검증

**Files:** 없음(검증 전용)

**Interfaces:**
- Consumes: Task 1-7 완료
- Produces: pytest 48/48 + npm test 187/187 green 확정.

- [ ] **Step 1: pytest 전체**

Run:
```bash
cd D:/0-suh/project/suh-github-template
PYTHON=$(for _py in python python3; do _p=$(command -v "$_py" 2>/dev/null) || continue; "$_p" -c "import sys;sys.exit(0)" 2>/dev/null && echo "$_p" && break; done)
"$PYTHON" -m pytest scripts/tests/ -q 2>&1 | tail -5
```
Expected: `48 passed`.

- [ ] **Step 2: npm test 전체**

Run: `npm test 2>&1 | grep -E "^ℹ (tests|pass|fail)"`
Expected: `tests 187`, `pass 187`, `fail 0`.

- [ ] **Step 3: 스킬 로드 정합성 최종 확인 (폴더=name 일치, 25개, 충돌 이름 없음)**

Run:
```bash
echo "=== 폴더명 = name 필드 일치 (25개) ==="
c=0
for d in skills/pro-*/; do
  n=$(grep -m1 "^name:" "$d/SKILL.md" 2>/dev/null | sed 's/name:[[:space:]]*//')
  fn=$(basename "$d")
  [ "$n" = "$fn" ] && c=$((c+1)) || echo "MISMATCH: $fn != $n"
done
echo "일치: $c / 25"
echo "=== 사내 충돌 이름(analyze 등) 프리픽스 없이 남았나 (0이어야) ==="
for s in analyze implement report review skill-creator ssh testcase; do
  [ -d "skills/$s" ] && echo "!!! 충돌 잔존: skills/$s"
done
echo "확인 완료"
```
Expected: 일치 25/25. 충돌 잔존 출력 없음.

- [ ] **Step 4: git 상태 최종 확인 (의도치 않은 변경 없나)**

Run: `git status --short | head; git log --oneline -8`
Expected: clean working tree, Task 1-7 커밋 7개.

- [ ] **Step 5: 사용자에게 pi 재로드 안내**

pi에서 `pi update --extensions` 또는 재시작하여 `[Skill conflicts]`가 사라지고 `pro-*` 스킬이 로드되는지 확인하도록 안내. (실제 pi 재로드는 사용자 환경 액션.)

---

## Self-Review

**Spec coverage:**
- GitHub 이슈 생성 → Task 0 ✓
- 껍데기 폴더 삭제 → Task 1 ✓
- 스킬 폴더 rename → Task 2 ✓
- name 필드 → Task 2 ✓
- SKILL.md 내부 경로 → Task 3 ✓
- CLI scripts 경로 → Task 4 ✓
- py 테스트 경로 → Task 5 ✓
- 정합성 테스트 기대값 → Task 6 ✓
- 문서 호출 표기 → Task 7 ✓
- breaking-changes.json 4.3.0 → Task 7.5 ✓
- 회귀 → Task 8 ✓
- 보존 대상(suh-logger 등) → Task 6 보존 테스트 + Task 7 Docker/placeholder 보호 ✓
- 커밋 → 각 Task Step 마지막 커밋 + Task 0 이슈 번호 연결 ✓

**Placeholder scan:** 없음. 모든 치환 명령·기대 출력 명시.

**Type/naming consistency:** 프리픽스 `pro-` 전 태스크 일관. 화이트리스트 25개 스킬명 모든 태스크 동일. sed 이중치환 보호 패턴(`__KEEP__`/`__DOCKER_TAG__`) 일관.

**주의:** Task 3·5·7의 sed는 GNU sed `\b`(단어경계) 사용. macOS BSD sed는 `\b` 미지원이나, **이 작업은 Windows Git Bash(GNU sed)에서 실행**하므로 안전. (사용자 환경 = Windows.) 만약 macOS에서 재실행 시 `\b`를 `[^a-z-]` 경계 매칭으로 대체 필요.
