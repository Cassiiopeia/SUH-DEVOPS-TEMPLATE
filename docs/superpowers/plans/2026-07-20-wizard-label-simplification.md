# 마법사 메뉴 라벨 축약 및 중간점 제거 구현 계획서

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `npx projectops` 마법사의 메뉴 라벨을 더 간결하고 직관적으로 축약(대안 A 채택)하며, 혼란을 주는 모든 중간점(`·`, `—` 등) 기호를 전면 제거하여 최상의 터미널 가독성 및 정합성을 구현합니다.

**Architecture:** UI 지향 문구 수정 및 동적 라벨 해석 헬퍼 보정, 연관 테스트 케이스의 정규표현식 동기화.

**Tech Stack:** Node.js, node:test 단독 검증.

## Global Constraints
- `src/ui/prompts.js` 와 `src/commands/interactive.js` 에 정의된 한글 라벨 텍스트는 100% 동일한 글자로 철저히 동기화되어야 한다.
- 모든 중간점 기호(`·`, `—` 등)는 메뉴 라벨 및 설명 출력에서 전면 제거하고 슬래시(`/`), 쉼표(`,`) 혹은 공백 대시(`-`)로 정정한다.
- 커밋 메시지에 AI 서명이나 Co-authored 트레일러를 절대 남기지 않는다.

---

### Task 1: 메뉴 라벨 텍스트 개편 및 중간점 전면 제거

**Files:**
- Modify: `src/ui/prompts.js`
- Modify: `src/commands/interactive.js`
- Test: `test/banner-cards.test.js`

**Interfaces:**
- Consumes: `selectMode` 시그니처, `modeLabel` 헬퍼 함수.
- Produces: 개편된 간결하고 직관적인 메뉴 명사 출력 정보.

- [ ] **Step 1: 실패하는 테스트 작성**
  `test/banner-cards.test.js` 에 있는 `printInstallKind` 및 `selectMode` 관련 검증 로직에서 개편될 새로운 명사형 문구가 출력되는지, 중간점 기호가 완전히 소멸되었는지 검증하는 코드를 작성합니다.
  
  `test/banner-cards.test.js` 의 L114 부근 수정:
  ```javascript
  // 기존
  const out2 = capture();
  printInstallKind({ currentTemplateVersion: "3.0.188", templateVersion: "4.0.3" }, out2);
  const t2 = strip(out2.text());
  assert.match(t2, /업데이트 — 템플릿 v3\.0\.188 → v4\.0\.3/);
  // 변경
  const out2 = capture();
  printInstallKind({ currentTemplateVersion: "3.0.188", templateVersion: "4.0.3" }, out2);
  const t2 = strip(out2.text());
  assert.match(t2, /업데이트 - 템플릿 v3\.0\.188 → v4\.0\.3/); // — 중간점 기호를 대시 - 로 보정 검증
  ```

- [ ] **Step 2: 테스트를 실행하여 실패하는지 확인**
  실행 명령: `npm test`
  예상 출력: `AssertionError: ... 업데이트 - 템플릿 ...` 패턴 매칭 실패 (Red)

- [ ] **Step 3: prompts.js의 라벨 축약 및 중간점 전면 제거 구현**
  `src/ui/prompts.js` 의 `selectMode` 함수 옵션들을 대안 A 정밀 사양으로 전면 수정합니다.
  ```javascript
  // src/ui/prompts.js 수정
  export async function selectMode({ update = null } = {}) {
    const options = [];
    if (update) {
      const range = update.from ? `v${update.from} → v${update.to}` : `v${update.to}`;
      options.push({ value: "update", label: `업데이트 (v${range})` });
    }
    options.push(
      { value: "full", label: "전체 설치 (버전관리 + 워크포트 + 템플릿)" }, // 실제 대안 A 적용
      { value: "version", label: "버전 관리 전용 (자동화 시스템)" },
      { value: "workflows", label: "워크플로우 전용 (GitHub Actions 빌드, 배포)" },
      { value: "issues", label: "이슈/PR 템플릿 전용" },
      { value: "skills", label: "AI 스킬 전용 (Claude, Cursor, Gemini, Codex, PI)" }
    );
    return engine.select({ message: "무엇을 설치할까요?", options });
  }
  ```

- [ ] **Step 4: interactive.js의 modeLabel 헬퍼 라벨 전면 동기화**
  `src/commands/interactive.js` 의 `modeLabel` 함수 매핑을 `prompts.js` 의 실제 문구와 글자 수준으로 정확하게 일치시킵니다.
  ```javascript
  // src/commands/interactive.js L405 부근 수정
  function modeLabel(m) {
    return { 
      full: "전체 설치 (버전관리 + 워크플로우 + 템플릿)", 
      version: "버전 관리 전용 (자동화 시스템)", 
      workflows: "워크플로우 전용 (GitHub Actions 빌드, 배포)", 
      issues: "이슈/PR 템플릿 전용", 
      skills: "AI 스킬 전용 (Claude, Cursor, Gemini, Codex, PI)", 
      update: "업데이트" 
    }[m] || m;
  }
  ```

- [ ] **Step 5: status-cards.js 중간점 기호 전면 제거**
  `src/ui/status-cards.js` 의 출력 문구 내 중간점(`—`, `·`) 기호를 완벽히 정정하여 가독성을 높입니다.
  ```javascript
  // src/ui/status-cards.js L85 부근 수정
  export function printInstallKind({ currentTemplateVersion = "", templateVersion = "" }, out = (s) => process.stdout.write(s)) {
    if (currentTemplateVersion) {
      out(`${GUT}  ♻️  ${paint("업데이트", A.bold)} - 템플릿 ${paint(`v${currentTemplateVersion}`, A.dim)} → ${paint(`v${templateVersion}`, A.green)}\n`);
      out(`${GUT}     ${paint("version.yml에 이전 통합 기록이 있습니다 - 메뉴 맨 위 '업데이트'가 저장된 설정 그대로 반영합니다", A.dim)}\n`);
    } else {
  ```

- [ ] **Step 6: 전체 검증 실행**
  실행 명령: `npm test`
  예상 출력: Tests run: 311, Failures: 0 (모두 정상 통과 - Green)

- [ ] **Step 7: 커밋 수행**
  AI 푸터를 포함시키지 않고 오직 순수 사용자 작성 포맷으로 커밋을 이행합니다.
  ```bash
  git add src/ui/prompts.js src/commands/interactive.js src/ui/status-cards.js test/banner-cards.test.js
  git commit -m "npx 마법사 업데이트 모드 : ui : 대안 A 기반 메뉴 라벨 단순화 및 중간점 전면 제거"
  ```
