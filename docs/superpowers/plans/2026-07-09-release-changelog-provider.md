# Release-Changelog Provider 시스템 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CodeRabbit 하드 커플링을 제거하고, GitHub AI를 기본으로 하는 changelog provider 폴백 사다리를 구현한다 (이슈 #455).

> **진행 상태 (2026-07-09):**
> - ✅ **Task 1~7 완료·develop push됨** — 마법사 JS(파싱·생성·질문·연결) + provider 스크립트 3개(commit/coderabbit/openai_compatible). 전부 테스트 통과.
> - ⏸ **Task 8~9 보류** — 763줄 운영 중 워크플로우(`AUTO-CHANGELOG-CONTROL.yaml`) 대규모 개편이라, 로컬 검증 불가 + 프로덕션 릴리스 파이프라인 리스크. CLAUDE.md "운영 중 워크플로우 함부로 안 건드림" 원칙에 따라 **별도 feature 브랜치 + 실제 PR 검증 후 병합** 필요. 사용자 판단 대기.
> - 현재 마법사는 provider를 version.yml에 저장하지만, 워크플로우가 아직 그 값을 읽어 사다리를 돌리지 않음(구 워크플로우 유지 중). Task 8이 그 연결을 완성함.

**Architecture:** 릴리스 노트 생성기를 교체 가능한 provider로 추상화한다. 모든 provider는 `Summary by CodeRabbit` 고정 형식의 `pr_body.md`를 산출하고, 기존 `changelog_manager.py` 파싱은 무수정 재사용한다. 마법사(JS)는 provider 선택값을 version.yml에 저장하고, 워크플로우(yaml+bash)는 그 값으로 폴백 사다리를 실행한다.

**Tech Stack:** GitHub Actions YAML, bash (러너), Node.js ESM (마법사 `src/core/`), `node:test` (테스트), `actions/ai-inference@v1` (GitHub Models).

## Global Constraints

- 공통 워크플로우는 `.github/workflows/` 루트 + `.github/workflows/project-types/common/` **두 곳을 바이트 동일하게 유지**한다 (CLAUDE.md 규칙).
- version.yml은 **주석이 데이터**다 — YAML 재직렬화 금지, `buildVersionYml`의 문자열 템플릿 방식만 사용 (`src/core/version-yml.js:2`).
- 커밋 메시지에 이모지·태그 prefix(`🚀[기능개선]` 등) 금지. 커밋 본문에 Claude/AI 흔적(`Co-Authored-By: Claude` 등) 절대 금지.
- bash 스크립트는 macOS bash 3.2 + BSD 도구 호환 (`grep -P` 금지, `declare -A` 금지, `set -e` 함수 끝 종료코드 주의).
- API 키 값은 version.yml에 **절대** 넣지 않는다. secret 이름(`MODEL_API_KEY`)은 workflow.yaml에 고정, 사용자가 GitHub Secret에 직접 등록.
- GitHub AI 경로는 `permissions: models: read` 필요. rate limit·8K 입력 토큰 제약 → mini 모델 + prefix 필터. **구현 직전 GitHub Models 공식 문서에서 현재 한도 재확인.**
- provider 최종 산출은 항상 `Summary by CodeRabbit` 고정 구조 `pr_body.md`. `commit`은 최후 보루라 절대 실패하지 않아야 한다.

---

## 파일 구조 (생성/수정 맵)

**마법사 (JS) — 파트 A:**
- Modify: `src/core/version-yml.js` — `parseTemplateOptions`에 changelog/code_review 파싱 추가, `buildVersionYml`에 options 블록 확장
- Modify: `src/core/options-ask.js` — `askAllOptionalWorkflows`에 질문 2개(code_review.coderabbit, changelog.provider) 추가
- Test: `test/options-ask.test.js` — 파싱·질문·저장 테스트 추가

**워크플로우 (yaml+bash) — 파트 B:**
- Create: `.github/scripts/changelog_providers/commit.sh` — 커밋 분석 안전망
- Create: `.github/scripts/changelog_providers/coderabbit.sh` — @coderabbitai 요청+폴링
- Create: `.github/scripts/changelog_providers/openai_compatible.sh` — base_url preset swap
- Create: `.github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml` — 리네임+폴백 사다리 (구 AUTO-CHANGELOG-CONTROL 대체)
- Create: `.github/workflows/project-types/common/PROJECT-COMMON-RELEASE-CHANGELOG.yaml` — 원본 (루트와 동일)
- Delete: 구 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` 양쪽
- Test: `.github/scripts/test/` — provider 스크립트 bash 테스트

**진행 순서**: 파트 A(마법사, TDD로 격리 가능) → 파트 B(워크플로우, 통합). A가 저장 스키마를 확정해야 B가 그 값을 읽는다.

---

## 파트 A — 마법사 (version.yml 스키마 + 질문)

### Task 1: version.yml에 changelog/code_review 파싱 추가

**Files:**
- Modify: `src/core/version-yml.js:51-111` (`parseTemplateOptions`)
- Test: `test/options-ask.test.js`

**Interfaces:**
- Consumes: 없음 (기존 파서 확장)
- Produces: `parseTemplateOptions(content)` 반환 객체에 `changelogProvider: string|null`, `changelogBaseUrl: string|null`, `codeReviewCoderabbit: bool|null` 필드 추가. 기존 `deploy/publish/secretBackup` 필드는 유지.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/options-ask.test.js` 상단 VY 헬퍼 근처에 추가:

```javascript
// version.yml — changelog/code_review 옵션 포함
const VY_CHANGELOG = (provider, baseUrl, coderabbit) => `version: "1.0.0"
project_types: ["basic"]
metadata:
  last_updated: "2026-07-09"
  template:
    source: "projectops"
    version: "4.3.0"
    options:
      deploy: "none"
      publish: []
      secret_backup: false
      code_review:
        coderabbit: ${coderabbit}
      changelog:
        provider: "${provider}"
        base_url: "${baseUrl}"
`;
```

그리고 테스트 블록 추가:

```javascript
test("parseTemplateOptions: changelog/code_review 파싱", () => {
  const r = parseTemplateOptions(VY_CHANGELOG("github-ai", "", "true"));
  assert.equal(r.changelogProvider, "github-ai");
  assert.equal(r.changelogBaseUrl, "");
  assert.equal(r.codeReviewCoderabbit, true);

  const r2 = parseTemplateOptions(VY_CHANGELOG("ollama", "https://ai.suhsaechan.kr/v1", "false"));
  assert.equal(r2.changelogProvider, "ollama");
  assert.equal(r2.changelogBaseUrl, "https://ai.suhsaechan.kr/v1");
  assert.equal(r2.codeReviewCoderabbit, false);

  // 필드 없으면 null
  const r3 = parseTemplateOptions(VY_NEW("vercel", ["npm"], false));
  assert.equal(r3.changelogProvider, null);
  assert.equal(r3.codeReviewCoderabbit, null);
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/options-ask.test.js`
Expected: FAIL — `changelogProvider`가 undefined (파서가 아직 그 필드를 안 만듦)

- [ ] **Step 3: 파서 확장 구현**

`src/core/version-yml.js`의 `parseTemplateOptions`를 수정한다. 반환 객체 초기화(52줄)와 중첩 블록 파싱을 추가한다.

52줄 `const out = ...`을 교체:
```javascript
  const out = { deploy: null, publish: null, secretBackup: null,
                changelogProvider: null, changelogBaseUrl: null, codeReviewCoderabbit: null };
```

중첩 블록(`code_review:`, `changelog:`)은 `options:` 밑 한 단계 더 들어간다. `inOptions` 블록 안에서 중첩 상태를 추적한다. 62줄 `if (inTemplate && inOptions) {` 블록 시작 직후에 중첩 감지 변수를 for 바깥에 선언하고(57줄 `let inOptions = false;` 아래):
```javascript
  let inCodeReview = false;
  let inChangelog = false;
```

그리고 62줄 `if (inTemplate && inOptions) {` 블록 **맨 앞**에 중첩 헤더·필드 파싱을 추가:
```javascript
      // 중첩 블록 헤더 감지 (options 밑 한 단계)
      if (/^\s+code_review:\s*$/.test(line)) { inCodeReview = true; inChangelog = false; continue; }
      if (/^\s+changelog:\s*$/.test(line)) { inChangelog = true; inCodeReview = false; continue; }
      if (inCodeReview) {
        const cm = line.match(/^\s+coderabbit:\s*(.+)/);
        if (cm) { const v = strip(cm[1]); if (v === "true") out.codeReviewCoderabbit = true; if (v === "false") out.codeReviewCoderabbit = false; continue; }
      }
      if (inChangelog) {
        const pm = line.match(/^\s+provider:\s*(.+)/);
        if (pm) { out.changelogProvider = strip(pm[1]); continue; }
        const bm = line.match(/^\s+base_url:\s*(.+)/);
        if (bm) { out.changelogBaseUrl = strip(bm[1]); continue; }
      }
```

주의: 기존 96줄 `if (/^\s{0,4}[a-z_]+:/.test(line))` (options 종료 감지)가 중첩 블록의 자식 라인(`coderabbit:` 등, 들여쓰기 6칸+)을 종료로 오판하지 않도록, 위 continue들이 먼저 걸리게 순서를 지킨다. 중첩 블록을 벗어나는 건 들여쓰기가 다시 줄어들 때인데, `provider`/`base_url`/`coderabbit`은 6칸+라 `\s{0,4}` 패턴에 안 걸린다 — 안전.

- [ ] **Step 4: 테스트 통과 확인**

Run: `node --test test/options-ask.test.js`
Expected: PASS — 신규 테스트 + 기존 테스트 전부 green

- [ ] **Step 5: 커밋**

```bash
git add src/core/version-yml.js test/options-ask.test.js
git commit -m "version.yml changelog provider 파싱 : feat : parseTemplateOptions에 changelog.provider/base_url·code_review.coderabbit 필드 추가 (#455)"
```

---

### Task 2: buildVersionYml에 changelog/code_review 블록 생성

**Files:**
- Modify: `src/core/version-yml.js:204-217` (`buildVersionYml`의 template.options 블록)
- Test: `test/options-ask.test.js`

**Interfaces:**
- Consumes: Task 1의 `parseTemplateOptions` (round-trip 검증에 사용)
- Produces: `buildVersionYml`의 `templateOptions` 파라미터에 `changelogProvider: string`, `changelogBaseUrl: string`, `codeReviewCoderabbit: bool` 추가. 생성된 yaml의 `options:` 블록에 `code_review`/`changelog` 중첩 블록 출력.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/options-ask.test.js`에 추가 (파일 상단 import에 `buildVersionYml` 추가: `import { parseExisting, buildVersionYml } from "../src/core/version-yml.js";`):

```javascript
test("buildVersionYml: changelog/code_review 블록 생성 + round-trip", () => {
  const yml = buildVersionYml({
    version: "1.0.0", types: ["basic"], branch: "main", versionCode: 1,
    now: "2026-07-09 00:00:00", today: "2026-07-09",
    templateOptions: {
      templateVersion: "4.3.0", deployTarget: "none", publishTargets: [], includeSecretBackup: false,
      changelogProvider: "github-ai", changelogBaseUrl: "", codeReviewCoderabbit: true,
    },
  });
  assert.match(yml, /changelog:/);
  assert.match(yml, /provider: "github-ai"/);
  assert.match(yml, /coderabbit: true/);
  // round-trip: 생성 → 파싱 동일
  const parsed = parseTemplateOptions(yml);
  assert.equal(parsed.changelogProvider, "github-ai");
  assert.equal(parsed.codeReviewCoderabbit, true);
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/options-ask.test.js`
Expected: FAIL — 생성된 yml에 `changelog:` 없음

- [ ] **Step 3: 생성 로직 구현**

`src/core/version-yml.js` 206줄 `const { templateVersion = ...` 구조분해에 신규 필드 추가:
```javascript
    const { templateVersion = "unknown", deployTarget = "docker-ssh", publishTargets = [], includeSecretBackup = false, optionsDate = today,
            changelogProvider = "github-ai", changelogBaseUrl = "", codeReviewCoderabbit = true } = templateOptions;
```

216줄 `out += `      secret_backup: ${includeSecretBackup}\n`;` 바로 뒤에 추가:
```javascript
    out += `      code_review:\n`;
    out += `        coderabbit: ${codeReviewCoderabbit}\n`;
    out += `      changelog:\n`;
    out += `        provider: "${changelogProvider}"\n`;
    out += `        base_url: "${changelogBaseUrl}"\n`;
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `node --test test/options-ask.test.js`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add src/core/version-yml.js test/options-ask.test.js
git commit -m "version.yml changelog 블록 생성 : feat : buildVersionYml이 code_review·changelog 옵션 블록을 출력 (#455)"
```

---

### Task 3: 마법사 질문 2개 추가 (code_review.coderabbit + changelog.provider)

**Files:**
- Modify: `src/core/options-ask.js:57-153` (`askAllOptionalWorkflows`)
- Test: `test/options-ask.test.js`

**Interfaces:**
- Consumes: Task 1의 `parseTemplateOptions` (저장값 재사용), 기존 `io.confirm`/`io.select`
- Produces: `askAllOptionalWorkflows` 반환 객체에 `codeReviewCoderabbit: bool`, `changelogProvider: string`, `changelogBaseUrl: string` 추가. 상수 `export const CHANGELOG_PROVIDERS = ["github-ai", "coderabbit", "openai", "gemini", "claude", "ollama", "commit"];`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/options-ask.test.js`의 `stubIo`가 이미 select/confirm을 지원한다. 추가:

```javascript
test("askAllOptionalWorkflows: changelog provider + coderabbit 질문", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    // confirms: [code_review coderabbit] / selects: [deploy 아님 — basic이라 스킵, changelog provider]
    // basic 단독이라 deploy/publish select 스킵 → select는 changelog provider 하나만
    const io = stubIo({ confirms: [true], selects: ["github-ai"] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.codeReviewCoderabbit, true);
    assert.equal(r.changelogProvider, "github-ai");
    assert.equal(r.changelogBaseUrl, "");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: changelog=ollama면 base_url 질문", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    // stubIo에 text 응답 추가 필요 (아래 Step 3에서 stubIo 확장)
    const io = stubIo({ confirms: [false], selects: ["ollama"], texts: ["https://ai.suhsaechan.kr/v1"] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.changelogProvider, "ollama");
    assert.equal(r.changelogBaseUrl, "https://ai.suhsaechan.kr/v1");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});
```

`stubIo`에 text 지원 추가 (53줄 함수 수정):
```javascript
function stubIo({ confirms = [], selects = [], multiselects = [], texts = [] } = {}) {
  const calls = { confirm: [], select: [], multiselect: [], text: [] };
  return {
    calls,
    log: () => {},
    confirm: async (a) => { calls.confirm.push(a.message); return confirms.shift(); },
    select: async (a) => { calls.select.push(a.message); return selects.shift(); },
    multiselect: async (a) => { calls.multiselect.push(a.message); return multiselects.shift(); },
    text: async (a) => { calls.text.push(a.message); return texts.shift(); },
  };
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/options-ask.test.js`
Expected: FAIL — `r.changelogProvider`가 undefined

- [ ] **Step 3: 질문 로직 구현**

`src/core/options-ask.js`에 상수 추가 (19줄 아래):
```javascript
export const CHANGELOG_PROVIDERS = ["github-ai", "coderabbit", "openai", "gemini", "claude", "ollama", "commit"];
```

`askAllOptionalWorkflows`의 62~64줄 초기화에 추가:
```javascript
  let codeReviewCoderabbit = current.codeReviewCoderabbit ?? null;
  let changelogProvider = current.changelogProvider ?? null;
  let changelogBaseUrl = current.changelogBaseUrl ?? null;
```

73~90줄 version.yml 저장값 재사용 블록의 `saved` 사용부에 추가 (89줄 닫는 `}` 앞):
```javascript
      if (codeReviewCoderabbit === null && saved.codeReviewCoderabbit !== null) codeReviewCoderabbit = saved.codeReviewCoderabbit;
      if (changelogProvider === null && saved.changelogProvider !== null) changelogProvider = saved.changelogProvider;
      if (changelogBaseUrl === null && saved.changelogBaseUrl !== null) changelogBaseUrl = saved.changelogBaseUrl;
```

Secret 백업 질문(146줄) **직전**에 changelog 질문 블록 추가:
```javascript
  // ── code_review: CodeRabbit AI 코드 리뷰 (changelog와 무관) ──
  if (forceAsk || codeReviewCoderabbit === null) {
    if (force || !tty || typeof io.confirm !== "function") {
      codeReviewCoderabbit = codeReviewCoderabbit ?? false;
    } else {
      say("");
      say("🤖 CodeRabbit AI 코드 리뷰를 쓸까요? (PR 올릴 때 코드 리뷰 댓글을 답니다)");
      const ans = await io.confirm({ message: "CodeRabbit AI 코드 리뷰 사용", initialValue: false });
      codeReviewCoderabbit = (ans === true && !isCancel(ans));
      say(`CodeRabbit 코드 리뷰: ${codeReviewCoderabbit ? "사용" : "미사용"}`);
    }
  }

  // ── changelog: 릴리스 노트 생성기 (기본 커서 = github-ai) ──
  if (forceAsk || changelogProvider === null) {
    if (force || !tty || typeof io.select !== "function") {
      changelogProvider = changelogProvider ?? "github-ai";
    } else {
      say("");
      say("📝 릴리스 노트(changelog)는 뭘로 만들까요?");
      say("   GitHub AI는 설정 없이 바로 됩니다. 나머지는 나중에 GitHub Secret 등록이 필요할 수 있어요.");
      const ans = await io.select({
        message: "changelog 생성기를 선택하세요",
        options: [
          { value: "github-ai", label: "GitHub AI (추천 · 설정 불필요)" },
          { value: "coderabbit", label: "CodeRabbit" },
          { value: "openai", label: "OpenAI 호환 API (키 등록 필요)" },
          { value: "commit", label: "커밋 분석만 (AI 없음)" },
        ],
      });
      changelogProvider = (!isCancel(ans) && CHANGELOG_PROVIDERS.includes(ans)) ? ans : (changelogProvider ?? "github-ai");
      say(`changelog 생성기: ${changelogProvider}`);
    }
  }

  // ollama/custom 선택 시에만 base_url 질문
  if ((changelogProvider === "ollama") && (forceAsk || changelogBaseUrl === null || changelogBaseUrl === "")) {
    if (force || !tty || typeof io.text !== "function") {
      changelogBaseUrl = changelogBaseUrl ?? "";
    } else {
      const ans = await io.text({ message: "Ollama 서버 base_url (예: https://ai.suhsaechan.kr/v1)" });
      changelogBaseUrl = (typeof ans === "string" && !isCancel(ans)) ? ans.trim() : "";
      say(`Ollama base_url: ${changelogBaseUrl || "(미지정)"}`);
    }
  } else if (changelogBaseUrl === null) {
    changelogBaseUrl = "";
  }
```

152줄 반환 객체 확장:
```javascript
  return {
    deploy: deploy ?? "docker-ssh", publish: publish ?? [], secretBackup: secretBackup === true,
    codeReviewCoderabbit: codeReviewCoderabbit === true,
    changelogProvider: changelogProvider ?? "github-ai",
    changelogBaseUrl: changelogBaseUrl ?? "",
  };
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `node --test test/options-ask.test.js`
Expected: PASS (신규 2개 + 기존 전부). 주의: 기존 테스트들이 `confirms: [false]`로 Secret 질문만 스텁했는데, 이제 code_review confirm이 앞에 추가돼 confirm 호출 순서가 바뀐다. 기존 테스트의 `io.calls.confirm.length` 단언과 confirms 배열을 조정해야 할 수 있다.

- [ ] **Step 5: 기존 테스트 회귀 조정**

기존 테스트 중 `askAllOptionalWorkflows`를 부르는 것들(98·113·127·142·157·172·186·201줄)은 이제 code_review confirm + changelog select가 추가로 호출된다. 각 테스트의 `stubIo` 응답과 `io.calls.*.length` 단언을 실제 호출 수에 맞게 갱신한다. 예: 113줄 basic 테스트는 `confirms: [false(coderabbit)]`, `selects: ["github-ai"]` 추가, deploy/publish select는 여전히 0.

Run: `node --test test/options-ask.test.js`
Expected: PASS 전부

- [ ] **Step 6: 커밋**

```bash
git add src/core/options-ask.js test/options-ask.test.js
git commit -m "마법사 changelog 질문 추가 : feat : CodeRabbit 코드리뷰 여부·changelog provider(기본 github-ai)·ollama base_url 질문 (#455)"
```

---

### Task 4: 마법사 호출부·요약 카드에 changelog 값 연결

**Files:**
- Modify: `src/commands/interactive.js` (askAllOptionalWorkflows 호출·buildVersionYml 전달)
- Modify: `src/ui/summary.js` (분석 카드에 changelog provider 표시)
- Test: `test/options-ask.test.js` 또는 관련 통합 테스트

**Interfaces:**
- Consumes: Task 3의 반환 필드, Task 2의 `buildVersionYml` 파라미터
- Produces: 통합 흐름에서 마법사 선택 → version.yml 저장까지 연결

- [ ] **Step 1: 호출부 확인**

Run: `grep -n "askAllOptionalWorkflows\|buildVersionYml\|templateOptions" src/commands/interactive.js src/ui/summary.js`
Expected: 호출 위치 파악. `askAllOptionalWorkflows` 반환값이 `buildVersionYml`의 `templateOptions`로 흘러가는 경로 확인.

- [ ] **Step 2: 반환값 → templateOptions 매핑 추가**

`interactive.js`에서 `askAllOptionalWorkflows` 결과를 `buildVersionYml`에 넘기는 곳에 신규 필드를 매핑:
```javascript
templateOptions: {
  // ...기존 deployTarget/publishTargets/includeSecretBackup...
  changelogProvider: wf.changelogProvider,
  changelogBaseUrl: wf.changelogBaseUrl,
  codeReviewCoderabbit: wf.codeReviewCoderabbit,
},
```
(`wf`는 askAllOptionalWorkflows 반환 변수명 — Step 1에서 확인한 실제 이름 사용)

- [ ] **Step 3: 요약 카드에 표시**

`src/ui/summary.js`의 분석 카드 항목에 한 줄 추가 (기존 배포/publish 표시 근처):
```javascript
say(`│  📝 changelog     ${provider}`);  // 실제 카드 렌더 패턴에 맞춤
```
(Step 1에서 확인한 실제 렌더 함수·변수에 맞게)

- [ ] **Step 4: 통합 스모크 테스트**

Run: `node --test` (전체 테스트)
Expected: PASS. 회귀 없음.

- [ ] **Step 5: 커밋**

```bash
git add src/commands/interactive.js src/ui/summary.js
git commit -m "마법사 changelog 값 연결 : feat : 선택된 changelog provider를 version.yml 저장·분석 카드 표시에 연결 (#455)"
```

---

## 파트 B — 워크플로우 (provider 스크립트 + 폴백 사다리)

> ⚠️ 파트 B는 GitHub Actions 러너에서 도는 bash라 로컬 유닛 테스트 범위가 제한적이다. `commit.sh`는 오프라인 검증 가능하고, 나머지는 스크립트 구조 검증 + 실제 릴리스 PR 통합 검증으로 확인한다.

### Task 5: commit.sh — 커밋 분석 안전망 provider

**Files:**
- Create: `.github/scripts/changelog_providers/commit.sh`
- Test: `.github/scripts/test/test_commit_provider.sh`

**Interfaces:**
- Consumes: 환경변수 `PR_NUMBER`, 러너 체크아웃 상태(git log 접근). 기존 워크플로우의 `fallback-summary` job 로직(`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml:249-340`)을 스크립트로 이동.
- Produces: `pr_body.md` 파일 생성 (`Summary by CodeRabbit` 고정 구조). 종료코드 0. `parse_method` 힌트로 stdout에 `PROVIDER=commit` 출력.

- [ ] **Step 1: 실패하는 테스트 작성**

`.github/scripts/test/test_commit_provider.sh`:
```bash
#!/bin/bash
# commit.sh가 커밋 로그로 pr_body.md를 만드는지 오프라인 검증
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../changelog_providers/commit.sh"
TMP=$(mktemp -d)
cd "$TMP"
git init -q && git config user.email t@t && git config user.name t
git commit -q --allow-empty -m "feat: 사용자 로그인 기능 추가"
git commit -q --allow-empty -m "fix: 결제 오류 수정 #123"
git branch -M main
git checkout -q -b develop
# main 대비 develop 커밋을 분석하는 구조라면 base를 main으로
COMMIT_RANGE="main..HEAD" bash "$SCRIPT" || { echo "FAIL: exit non-zero"; exit 1; }
grep -q "Summary by CodeRabbit" pr_body.md || { echo "FAIL: no summary header"; exit 1; }
grep -q "새 기능" pr_body.md || { echo "FAIL: no feat section"; exit 1; }
grep -q "버그 수정" pr_body.md || { echo "FAIL: no fix section"; exit 1; }
# 정제: 이슈번호·prefix 제거 확인
grep -q "#123" pr_body.md && { echo "FAIL: 이슈번호 미제거"; exit 1; }
grep -q "fix:" pr_body.md && { echo "FAIL: prefix 미제거"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash .github/scripts/test/test_commit_provider.sh`
Expected: FAIL — commit.sh 없음

- [ ] **Step 3: commit.sh 구현**

`.github/scripts/changelog_providers/commit.sh` 작성. 기존 `AUTO-CHANGELOG-CONTROL.yaml`의 fallback-summary(249~327줄) bash 로직을 옮기되, 정제를 강화한다. 커밋 수집 range는 `COMMIT_RANGE`(기본 `origin/main..HEAD`) 환경변수로 받는다.

```bash
#!/bin/bash
# commit provider — 커밋 분석으로 pr_body.md 생성 (안전망, AI 무의존)
# 입력: COMMIT_RANGE (기본 origin/main..HEAD)
# 출력: pr_body.md (Summary by CodeRabbit 고정 구조), stdout에 PROVIDER=commit
set -u
RANGE="${COMMIT_RANGE:-origin/main..HEAD}"

COMMITS=$(git log "$RANGE" --pretty=format:"%s" 2>/dev/null | grep -v "\[skip ci\]" | head -60)
[ -z "$COMMITS" ] && COMMITS=$(git log --pretty=format:"%s" -30 | grep -v "\[skip ci\]")

FEAT=""; FIX=""; IMP=""; DOC=""; ETC=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  # prefix 추출
  PREFIX=$(echo "$line" | grep -oE '^(feat|fix|refactor|docs|chore|style|test|perf|ci|build|revert)(\([^)]*\))?:' | head -1)
  # 정제: prefix·이슈번호(#123)·URL·파일경로 제거
  MSG=$(echo "$line" | sed -E 's/^[a-z]+(\([^)]*\))?: *//' \
                     | sed -E 's/#[0-9]+//g' \
                     | sed -E 's#https?://[^ ]+##g' \
                     | sed -E 's/ +/ /g' | sed -E 's/^ *//; s/ *$//')
  [ -z "$MSG" ] && MSG="$line"
  case "$PREFIX" in
    feat*) FEAT="$FEAT\n  * $MSG" ;;
    fix*) FIX="$FIX\n  * $MSG" ;;
    refactor*|style*|perf*) IMP="$IMP\n  * $MSG" ;;
    docs*) DOC="$DOC\n  * $MSG" ;;
    *) ETC="$ETC\n  * $MSG" ;;
  esac
done <<< "$COMMITS"

{
  echo "<!-- This is an auto-generated comment: release notes by coderabbit.ai -->"
  echo ""
  echo "## Summary by CodeRabbit"
  echo ""
  echo "## 릴리스 노트"
  echo ""
  [ -n "$FEAT" ] && { echo "* **새 기능**"; printf "%b\n" "$FEAT"; echo ""; }
  [ -n "$FIX" ]  && { echo "* **버그 수정**"; printf "%b\n" "$FIX"; echo ""; }
  [ -n "$IMP" ]  && { echo "* **개선**"; printf "%b\n" "$IMP"; echo ""; }
  [ -n "$DOC" ]  && { echo "* **문서**"; printf "%b\n" "$DOC"; echo ""; }
  [ -n "$ETC" ]  && { echo "* **기타**"; printf "%b\n" "$ETC"; echo ""; }
  echo "<!-- end of auto-generated comment: release notes by coderabbit.ai -->"
} > pr_body.md

echo "PROVIDER=commit"
exit 0
```

macOS bash 3.2 호환: `declare -A` 미사용, `grep -P` 미사용(-oE 사용), `set -e` 미사용(마지막 exit 0 명시).

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash .github/scripts/test/test_commit_provider.sh`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add .github/scripts/changelog_providers/commit.sh .github/scripts/test/test_commit_provider.sh
git commit -m "changelog commit provider : feat : 커밋 분석 안전망 provider 스크립트 (prefix·이슈번호·URL 정제) (#455)"
```

---

### Task 6: coderabbit.sh — CodeRabbit summary provider

**Files:**
- Create: `.github/scripts/changelog_providers/coderabbit.sh`

**Interfaces:**
- Consumes: 환경변수 `PR_NUMBER`, `GITHUB_REPOSITORY`, `GITHUB_TOKEN`, `PAT_TOKEN`, `CODERABBIT_TIMEOUT`(기본 600)
- Produces: `pr_body.md` (CodeRabbit이 준 본문). 성공 시 exit 0 + `PROVIDER=coderabbit`. 타임아웃/무응답 시 **exit 1** (워크플로우가 다음 사다리로 폴백).

- [ ] **Step 1: 스크립트 구현**

기존 `AUTO-CHANGELOG-CONTROL.yaml`의 detect-and-parse job(157~223줄, CodeRabbit summary 요청+폴링)을 스크립트로 이동. 핵심 차이: 타임아웃 시 폴백을 위해 **exit 1**.

```bash
#!/bin/bash
# coderabbit provider — @coderabbitai summary 요청 후 폴링
# 입력: PR_NUMBER, GITHUB_REPOSITORY, PAT_TOKEN, CODERABBIT_TIMEOUT(기본 600초)
# 출력: 성공 시 pr_body.md + exit 0. 무응답 시 exit 1 (폴백 트리거)
set -u
TIMEOUT="${CODERABBIT_TIMEOUT:-600}"
REPO="$GITHUB_REPOSITORY"
API="https://api.github.com/repos/$REPO"

# summary 요청
curl -s -H "Authorization: token $PAT_TOKEN" -H "Content-Type: application/json" \
  -X POST -d '{"body": "@coderabbitai summary"}' \
  "$API/issues/${PR_NUMBER}/comments" > /dev/null

INTERVAL=5
ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  BODY=$(curl -s -H "Authorization: token $PAT_TOKEN" "$API/pulls/${PR_NUMBER}" | \
         python3 -c "import sys,json; print(json.load(sys.stdin).get('body') or '')" 2>/dev/null)
  if echo "$BODY" | grep -q "Summary by CodeRabbit"; then
    echo "$BODY" > pr_body.md
    echo "PROVIDER=coderabbit"
    exit 0
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "coderabbit: ${TIMEOUT}초 내 Summary 없음 — 폴백" >&2
exit 1
```

- [ ] **Step 2: 문법 검증**

Run: `bash -n .github/scripts/changelog_providers/coderabbit.sh`
Expected: 출력 없음 (문법 OK)

- [ ] **Step 3: 커밋**

```bash
git add .github/scripts/changelog_providers/coderabbit.sh
git commit -m "changelog coderabbit provider : feat : @coderabbitai summary 요청·폴링, 무응답 시 exit 1로 폴백 (#455)"
```

---

### Task 7: openai_compatible.sh — OpenAI 호환 provider (preset swap)

**Files:**
- Create: `.github/scripts/changelog_providers/openai_compatible.sh`
- Test: `.github/scripts/test/test_openai_provider.sh` (mock 응답)

**Interfaces:**
- Consumes: 환경변수 `PROVIDER_NAME`(openai/gemini/claude/ollama), `CHANGELOG_BASE_URL`(ollama일 때), `MODEL_API_KEY`, `COMMIT_RANGE`
- Produces: `pr_body.md`. 성공 exit 0 + `PROVIDER=openai:<name>`. API 실패 exit 1 (폴백).

- [ ] **Step 1: 실패하는 테스트 작성 (mock 엔드포인트)**

`.github/scripts/test/test_openai_provider.sh` — `CHANGELOG_TEST_RESPONSE` 환경변수로 API 응답을 주입해 정규화만 검증:
```bash
#!/bin/bash
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../changelog_providers/openai_compatible.sh"
TMP=$(mktemp -d); cd "$TMP"
git init -q && git config user.email t@t && git config user.name t
git commit -q --allow-empty -m "feat: 로그인"
# mock: 스크립트가 CHANGELOG_TEST_RESPONSE가 있으면 실제 curl 대신 그걸 응답으로 씀
CHANGELOG_TEST_RESPONSE='* **새 기능**
  * 로그인 기능이 추가되었습니다' \
  PROVIDER_NAME=openai MODEL_API_KEY=dummy COMMIT_RANGE="HEAD~1..HEAD" \
  bash "$SCRIPT" || { echo "FAIL exit"; exit 1; }
grep -q "Summary by CodeRabbit" pr_body.md || { echo "FAIL header"; exit 1; }
grep -q "로그인 기능이 추가" pr_body.md || { echo "FAIL body"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash .github/scripts/test/test_openai_provider.sh`
Expected: FAIL — 스크립트 없음

- [ ] **Step 3: 스크립트 구현**

preset으로 base_url 자동 결정, `CHANGELOG_TEST_RESPONSE`가 있으면 테스트 모드:
```bash
#!/bin/bash
# openai-compatible provider — base_url preset swap
# 입력: PROVIDER_NAME(openai|gemini|claude|ollama), CHANGELOG_BASE_URL(ollama용),
#       MODEL_API_KEY, COMMIT_RANGE, CHANGELOG_MODEL(선택), CHANGELOG_TEST_RESPONSE(테스트용)
set -u
NAME="${PROVIDER_NAME:-openai}"

case "$NAME" in
  openai) BASE="https://api.openai.com/v1"; MODEL="${CHANGELOG_MODEL:-gpt-4o-mini}" ;;
  gemini) BASE="https://generativelanguage.googleapis.com/v1beta/openai"; MODEL="${CHANGELOG_MODEL:-gemini-1.5-flash}" ;;
  claude) BASE="https://api.anthropic.com/v1"; MODEL="${CHANGELOG_MODEL:-claude-3-5-haiku-latest}" ;;
  ollama) BASE="${CHANGELOG_BASE_URL:-}"; MODEL="${CHANGELOG_MODEL:-qwen2.5}" ;;
  *) echo "unknown provider $NAME" >&2; exit 1 ;;
esac

RANGE="${COMMIT_RANGE:-origin/main..HEAD}"
COMMITS=$(git log "$RANGE" --pretty=format:"%s" 2>/dev/null | grep -vE "\[skip ci\]|^(chore|ci|build|test):" | head -40)
[ -z "$COMMITS" ] && COMMITS=$(git log --pretty=format:"%s" -20)

if [ -n "${CHANGELOG_TEST_RESPONSE:-}" ]; then
  CONTENT="$CHANGELOG_TEST_RESPONSE"
else
  [ -z "$BASE" ] && { echo "base_url 없음" >&2; exit 1; }
  PROMPT="다음 커밋들을 사용자용 릴리스 노트로. 파일명·prefix·이슈번호 금지. 새 기능/버그 수정/개선 분류:\n$COMMITS"
  REQ=$(python3 -c "import json,sys; print(json.dumps({'model':sys.argv[1],'messages':[{'role':'user','content':sys.argv[2]}]}))" "$MODEL" "$PROMPT")
  RESP=$(curl -s --max-time 60 -H "Authorization: Bearer $MODEL_API_KEY" -H "Content-Type: application/json" \
         -X POST -d "$REQ" "$BASE/chat/completions")
  CONTENT=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" 2>/dev/null)
  [ -z "$CONTENT" ] && { echo "API 응답 파싱 실패: $RESP" >&2; exit 1; }
fi

{
  echo "<!-- This is an auto-generated comment: release notes by coderabbit.ai -->"
  echo ""
  echo "## Summary by CodeRabbit"
  echo ""
  echo "## 릴리스 노트"
  echo ""
  echo "$CONTENT"
  echo ""
  echo "<!-- end of auto-generated comment: release notes by coderabbit.ai -->"
} > pr_body.md

echo "PROVIDER=openai:$NAME"
exit 0
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash .github/scripts/test/test_openai_provider.sh`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add .github/scripts/changelog_providers/openai_compatible.sh .github/scripts/test/test_openai_provider.sh
git commit -m "changelog openai 호환 provider : feat : preset base_url swap(openai/gemini/claude/ollama) + 정규화, 실패 시 폴백 (#455)"
```

---

### Task 8: 워크플로우 리네임 + 폴백 사다리 구조

**Files:**
- Create: `.github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml` (구 AUTO-CHANGELOG-CONTROL 대체)
- Create: `.github/workflows/project-types/common/PROJECT-COMMON-RELEASE-CHANGELOG.yaml` (원본, 루트와 동일)
- Delete: `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` + `project-types/common/` 사본

**Interfaces:**
- Consumes: version.yml `options.changelog.provider`/`base_url`, `options.code_review.coderabbit`, Task 5·6·7의 provider 스크립트
- Produces: 릴리스 PR(develop→main opened) 시 provider 사다리를 실행해 pr_body.md 생성 → 기존 changelog_manager.py 파이프라인(버전 확정·CHANGELOG·automerge)으로 연결. 폴백 시 PR 댓글 알림.

- [ ] **Step 1: 기존 워크플로우 복사 후 개편**

기존 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`을 새 이름으로 복사하고, `detect-and-parse` + `fallback-summary` 두 job을 **하나의 provider-ladder step**으로 교체한다. version.yml에서 provider를 읽는 step 추가:

```yaml
      - name: changelog provider 결정
        id: provider
        run: |
          PROVIDER=$(grep -A5 "changelog:" version.yml | grep "provider:" | head -1 | sed -E 's/.*provider:\s*"?([^"]*)"?.*/\1/' | tr -d ' ')
          [ -z "$PROVIDER" ] && PROVIDER="github-ai"
          BASE_URL=$(grep -A5 "changelog:" version.yml | grep "base_url:" | head -1 | sed -E 's/.*base_url:\s*"?([^"]*)"?.*/\1/' | tr -d ' ')
          CODERABBIT=$(grep -A3 "code_review:" version.yml | grep "coderabbit:" | head -1 | sed -E 's/.*coderabbit:\s*//' | tr -d ' ')
          echo "provider=$PROVIDER" >> $GITHUB_OUTPUT
          echo "base_url=$BASE_URL" >> $GITHUB_OUTPUT
          echo "coderabbit=$CODERABBIT" >> $GITHUB_OUTPUT
```

- [ ] **Step 2: 폴백 사다리 step 구현**

provider 값에 따라 사다리를 순서대로 시도하는 step. github-ai는 `actions/ai-inference@v1`, 나머지는 스크립트. 실패하면 다음 단계. 최후 commit.

```yaml
    permissions:
      contents: write
      pull-requests: write
      models: read          # github-ai provider용

    steps:
      # ... 체크아웃 ...
      - name: 릴리스 노트 생성 (폴백 사다리)
        id: gen
        env:
          PR_NUMBER: ${{ github.event.pull_request.number }}
          GITHUB_REPOSITORY: ${{ github.repository }}
          PAT_TOKEN: ${{ secrets._GITHUB_PAT_TOKEN }}
          MODEL_API_KEY: ${{ secrets.MODEL_API_KEY }}
          CHANGELOG_BASE_URL: ${{ steps.provider.outputs.base_url }}
          COMMIT_RANGE: origin/main..HEAD
        run: |
          chmod +x .github/scripts/changelog_providers/*.sh
          PROVIDER="${{ steps.provider.outputs.provider }}"
          USED=""; NOTES=""

          try_provider() {
            case "$1" in
              coderabbit) bash .github/scripts/changelog_providers/coderabbit.sh ;;
              github-ai)  return 1 ;;  # github-ai는 아래 별도 step (액션이라 여기선 skip 신호)
              openai|gemini|claude|ollama) PROVIDER_NAME="$1" bash .github/scripts/changelog_providers/openai_compatible.sh ;;
              commit)     bash .github/scripts/changelog_providers/commit.sh ;;
              *) return 1 ;;
            esac
          }

          # 사다리 순서 구성: coderabbit(선택 시) → 지정 provider → commit
          LADDER=""
          [ "$PROVIDER" = "coderabbit" ] && LADDER="coderabbit github-ai openai commit"
          [ "$PROVIDER" = "github-ai" ] && LADDER="github-ai openai commit"
          [ "$PROVIDER" = "openai" ] || [ "$PROVIDER" = "gemini" ] || [ "$PROVIDER" = "claude" ] || [ "$PROVIDER" = "ollama" ] && LADDER="$PROVIDER commit"
          [ "$PROVIDER" = "commit" ] && LADDER="commit"
          [ -z "$LADDER" ] && LADDER="github-ai openai commit"

          echo "ladder=$LADDER" >> $GITHUB_OUTPUT
          # github-ai는 액션 step에서 처리되므로, 여기선 non-github-ai만 순회 시도
          for p in $LADDER; do
            [ "$p" = "github-ai" ] && continue   # 아래 별도 step
            if try_provider "$p"; then USED="$p"; break; fi
          done
          echo "used=$USED" >> $GITHUB_OUTPUT

      # github-ai가 사다리에 있고 아직 pr_body.md가 없으면 AI Inference로 생성
      - name: GitHub AI 릴리스 노트
        if: contains(steps.gen.outputs.ladder, 'github-ai') && steps.gen.outputs.used == ''
        id: ai
        uses: actions/ai-inference@v1
        with:
          model: gpt-4o-mini
          system-prompt: "커밋 목록을 사용자용 릴리스 노트(새 기능/버그 수정/개선)로 만들어라. 파일명·prefix·이슈번호·URL 금지."
          prompt: ${{ steps.commits.outputs.log }}

      - name: GitHub AI 결과 정규화 또는 commit 폴백
        run: |
          if [ ! -f pr_body.md ] && [ -n "${{ steps.ai.outputs.response }}" ]; then
            {
              echo "<!-- This is an auto-generated comment: release notes by coderabbit.ai -->"
              echo ""; echo "## Summary by CodeRabbit"; echo ""; echo "## 릴리스 노트"; echo ""
              echo "${{ steps.ai.outputs.response }}"; echo ""
              echo "<!-- end of auto-generated comment: release notes by coderabbit.ai -->"
            } > pr_body.md
            echo "PROVIDER=github-ai"
          fi
          # 어떤 provider도 pr_body.md를 못 만들었으면 commit 안전망
          if [ ! -f pr_body.md ]; then
            echo "모든 provider 실패 → commit 안전망" >&2
            bash .github/scripts/changelog_providers/commit.sh
          fi

      - name: 폴백 발생 시 PR 댓글 알림
        if: steps.gen.outputs.used != steps.provider.outputs.provider
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh pr comment ${{ github.event.pull_request.number }} \
            --body "ℹ️ 설정된 changelog 생성기(${{ steps.provider.outputs.provider }})가 응답하지 않아 다른 방식으로 릴리스 노트를 생성했습니다."
```

> 나머지 job(update-changelog, merge-and-deploy)은 기존 `AUTO-CHANGELOG-CONTROL.yaml`과 동일하게 유지 — pr_body.md만 있으면 그대로 동작한다. `detect-and-parse`의 `summary_found` output은 항상 true로 간주(사다리가 항상 pr_body.md 생성).

- [ ] **Step 3: version.yml 헤더 주석 참조 갱신**

`src/core/version-yml.js` HEADER의 33~35줄 워크플로우 파일명 참조를 갱신:
```
# - .github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml
```
(구 `PROJECT-AUTO-CHANGELOG-CONTROL.yaml` → 신 이름)

- [ ] **Step 4: 루트↔common 동일성 확인**

두 파일을 바이트 동일하게 만든 뒤:
Run: `diff .github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml .github/workflows/project-types/common/PROJECT-COMMON-RELEASE-CHANGELOG.yaml`
Expected: 출력 없음 (동일)

- [ ] **Step 5: 구 파일 삭제 + 참조 정리**

```bash
git rm .github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml
git rm .github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml
grep -rn "AUTO-CHANGELOG-CONTROL" . --include="*.md" --include="*.js" --include="*.yaml" 2>/dev/null
```
남은 참조(README·CLAUDE.md·docs)를 `RELEASE-CHANGELOG`로 갱신.

- [ ] **Step 6: 커밋**

```bash
git add -A
git commit -m "changelog 워크플로우 리네임·폴백 사다리 : feat : AUTO-CHANGELOG-CONTROL→RELEASE-CHANGELOG, provider 사다리(coderabbit→github-ai→openai→commit)로 개편, 폴백 시 PR 알림 (#455)"
```

---

### Task 9: 통합 검증 + 문서 갱신

**Files:**
- Modify: `README.md`, `CLAUDE.md` (워크플로우 표·이름 참조)
- Modify: `docs/CHANGELOG-AUTOMATION.md` (있으면)

- [ ] **Step 1: 전체 테스트**

Run: `node --test && bash .github/scripts/test/test_commit_provider.sh && bash .github/scripts/test/test_openai_provider.sh`
Expected: 전부 PASS

- [ ] **Step 2: 워크플로우 문법 확인**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml'))" 2>&1 | head`
Expected: 오류 없음 (단, CLAUDE.md의 "로컬 YAML 검증 ≠ GitHub 실동작" 원칙 유의 — heredoc 등은 로컬 파서가 틀릴 수 있음)

- [ ] **Step 3: 문서 갱신**

`README.md`·`CLAUDE.md`의 워크플로우 표에서 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` → `PROJECT-COMMON-RELEASE-CHANGELOG`, 기능 설명에 "provider 선택·GitHub AI 기본" 반영. CodeRabbit이 필수가 아니라 옵션임을 명시.

- [ ] **Step 4: 커밋**

```bash
git add README.md CLAUDE.md docs/
git commit -m "changelog provider 문서 갱신 : docs : 워크플로우 리네임·GitHub AI 기본·CodeRabbit 옵션화 반영 (#455)"
```

---

## Self-Review

**Spec coverage 체크:**
- §1 파일명 변경 → Task 8 ✅
- §2 마법사 두 질문 → Task 3 ✅
- §3 폴백 사다리 → Task 8 ✅ (+ provider 스크립트 Task 5·6·7)
- §4 설정 3층 분리 → Task 1·2(version.yml), Task 8(workflow secret 참조) ✅
- §5 version.yml 스키마 → Task 1·2 ✅
- §6 provider 무관 계약(pr_body.md) → 모든 provider가 동일 구조 산출, 기존 파싱 재사용 ✅
- §7 컴포넌트 구조 → Task 5·6·7·8 ✅
- §8 commit 안전망 품질 → Task 5 (정제 강화) ✅
- 에러 처리(폴백 알림) → Task 8 Step 2 ✅
- 테스트 → 각 Task에 포함 ✅

**미해결/유의:**
- GitHub AI rate limit·8K 토큰 한도는 Task 8 구현 직전 공식 문서 재확인 필요 (Global Constraints에 명시).
- `generate-notes` API 활용(§8 검토 항목)은 commit provider 후속 개선으로 남김 — 현 계획은 prefix 정제까지.
- Task 4 호출부 실제 변수명은 `interactive.js`를 열어 확인 후 매핑 (Step 1에서 grep).

**다음 단계**: 이 계획으로 subagent-driven-development 또는 executing-plans 실행.
