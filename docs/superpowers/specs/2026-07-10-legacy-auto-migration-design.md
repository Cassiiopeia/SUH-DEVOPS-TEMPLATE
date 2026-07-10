# IDE 어댑터 레거시 자동 마이그레이션 설계

- 날짜: 2026-07-10
- 관련: [[2026-07-09-459-namespace-rebrand-design]] (리브랜딩 SUH-DEVOPS-TEMPLATE/cassiiopeia → projectops)
- 트리거: 사용자가 옛 플러그인(`cassiiopeia@cassiiopeia-marketplace`)에서 신규(`projectops@projectops-marketplace`)로 넘어가려면 `marketplace remove` → `add` → `install` 6단계를 **수동으로** 밟아야 했다. `npx projectops@latest` 설치가 이걸 자동으로 해줘야 한다.

---

## 1. 문제 정의

레포/플러그인 이름이 `SUH-DEVOPS-TEMPLATE`·`cassiiopeia` → `projectops`로 바뀌었다(#459). 그런데 각 IDE 어댑터의 `apply()`는 **신규 이름만 알고 옛 설치본을 인지·정리하지 못한다.** 그 결과:

1. **claude**: 옛 `cassiiopeia@cassiiopeia-marketplace`가 `failed to load` 좀비 상태로 남고, 옛 `cassiiopeia-marketplace` 캐시가 신규와 공존한다. `detect()`가 이름에 `projectops`가 있는지만 보므로 옛것을 "미설치"로 오판 → 정리 없이 신규만 설치 → 충돌·혼란.
2. **cursor**: `~/.cursor/skills/cursor-skills-meta.json`의 `name`이 옛값(`cassiiopeia`)이거나 version이 옛 버전이어도 재설치되지 않는다.
3. **config 유실**: 스킬(agent)은 `~/.projectops/config/config.json` **한 곳만** 읽도록 하드코딩돼 있다(`skills/references/config-rules.md`: "config는 절대 탐색하지 않는다"). 옛 경로(`~/.suh-template/config/config.json`, `~/.cassiiopeia/config.json`)에 PAT 등 설정이 남아있어도 신규 스킬은 절대 못 읽어 → 사용자가 PAT를 다시 등록해야 한다.

## 2. 실측 근거 (이 개발 컴퓨터)

전수 조사 결과 3세대 레거시가 실재하며, 테스트 환경으로 활용 가능하다.

**IDE 플러그인:**
| 흔적 | 실측 상태 | 조치 |
|------|----------|------|
| `~/.claude/plugins/cache/cassiiopeia-marketplace` | 신규 `projectops-marketplace`와 **공존**(좀비) | 정리 |
| `~/.cursor/skills/cursor-skills-meta.json` | `name:"cassiiopeia", version:"4.2.3"` (옛 이름+옛 버전) | 재설치 |
| `~/.pi/agent/git/github.com/Cassiiopeia/projectops` | 이미 신규(SUH-DEVOPS-TEMPLATE 없음) | 정상 |
| `~/.agents/skills/` (codex) | 비어있음 | 해당없음 |
| `~/.gemini/extensions/` | projectops 없음 | 해당없음 |

**Config 루트 (모든 스킬 공유):**
```
~/.cassiiopeia/config.json          (1세대 — config 폴더 없이 직접)
~/.suh-template/config/config.json  (2세대)
        ↓ 자동 이관 대상
~/.projectops/config/config.json    (3세대 = SSOT, 스킬이 유일하게 읽는 곳)
```
세 config 모두 스키마 동일(`github.global_pat`, `github.default_assignee`, `github.issue.auto_approve`, `github.changelog_deploy.auto_approve`), 위치만 다름.

## 3. 결정 사항 (사용자 확정)

- **실행 시점**: 별도 명령 없이 **`apply()`(=npx 설치/업데이트) 흐름 안에서 자동** 실행.
- **정리 방식**: **조용히 자동 정리 + 로그만.** 확인 프롬프트 없음(비대화형 npx와 자연스러움).
- **레거시 감지 기준**: **이름 OR 버전** 하이브리드. marketplace형(claude/codex)은 옛 이름 존재로, 수동 복사형(cursor)은 meta의 옛 이름 또는 version ≤ 기준점으로 판정.
- **버전 기준점**: `maxLegacyVersion = "4.2.4"` — 리브랜딩 직후 릴리스가 4.2.5(#463)이므로 그 이하는 옛 세대.
- **config 이관 정책**: **신규(`~/.projectops/config/config.json`)가 없거나 빈 객체일 때만** 옛것에서 복사. 값이 있으면 건드리지 않음(이미 최신 사용 중 = 덮어쓰기 위험 0). 옛 config는 **삭제하지 않고 보존**(민감값 유실 방지).
- **적용 범위**: 어댑터 5개 전부 (claude/codex/gemini/pi/cursor).

## 4. 설계

### 4.1 신규 공용 헬퍼 `src/core/ide/legacy.js`

```js
// 버전 판정: version <= maxLegacy 이면 레거시. (compareCacheName 재사용)
export function isLegacyVersion(version, maxLegacy)   // "4.2.3","4.2.4" → true / "4.2.5" → false / null → false

// config 루트 이관 (모든 어댑터 공통, idempotent — 여러 번 불려도 안전)
export function migrateConfigRoot(io) {
  const target = join(io.home(), ".projectops/config/config.json");
  if (hasNonEmptyJson(target)) return { migrated: false, reason: "target-exists" };
  const sources = [
    join(io.home(), ".suh-template/config/config.json"),  // 2세대 우선
    join(io.home(), ".cassiiopeia/config.json"),           // 1세대 폴백
  ];
  const src = sources.find(hasNonEmptyJson);
  if (!src) return { migrated: false, reason: "no-source" };
  mkdirSync(dirname(target), { recursive: true });
  cpSync(src, target);
  io.log(`  config 마이그레이션 완료: ${src} → ~/.projectops/config/config.json`);
  return { migrated: true, from: src };
}

// 내부: 파일이 존재하고 파싱되며 최소 1개 키가 있으면 true
function hasNonEmptyJson(path) { ... }
```

> **claude 어댑터의 기존 `migrateConfig()`**(같은 이름 캐시 버전 간 config 이동)는 그대로 두되, 이 `migrateConfigRoot()`는 그와 **독립적인 "옛 이름 → 신 이름" 루트 이관**이다.

### 4.2 각 어댑터에 `migrateLegacy(io)` 추가 + `apply()`에서 호출

`apply()` 시작 부분:
```js
function apply(io, ctx) {
  migrateLegacy(io);        // ① 옛 플러그인/마켓/심링크 정리 (조용히, 로그만)
  migrateConfigRoot(io);    // ② 공용 config 루트 이관 (idempotent)
  ...기존 install/update 로직...
}
```

### 4.3 어댑터별 `migrateLegacy` 동작

각 어댑터에 `LEGACY` 상수를 두고 그 명세대로 정리한다.

**claude.js**
```js
const LEGACY = {
  plugins: ["cassiiopeia@cassiiopeia-marketplace", "cassiiopeia"],
  marketplaces: ["cassiiopeia-marketplace"],
};
function migrateLegacy(io) {
  if (!io.which("claude")) return;
  const r = io.run("claude", ["plugin", "list", "--json"]);
  const list = parsePlugins(r.stdout);
  for (const name of LEGACY.plugins) {
    const hit = list.find(p => matchName(p, name));
    if (hit) {
      io.log(`  레거시 플러그인 정리: ${name} (scope: ${hit.scope})`);
      io.run("claude", ["plugin", "uninstall", name, "--scope", hit.scope || "user"]);
    }
  }
  for (const mp of LEGACY.marketplaces) {
    io.run("claude", ["plugin", "marketplace", "remove", mp]);  // 없으면 no-op
  }
}
```
> 옛 캐시 디렉토리(`cache/cassiiopeia-marketplace`)는 `marketplace remove`가 정리한다. remove 실패(이미 없음)는 무해하게 무시.

**codex.js**
```js
const LEGACY = { natives: ["SUH-DEVOPS-TEMPLATE"], marketplaces: ["SUH-DEVOPS-TEMPLATE"] };
function migrateLegacy(io) {
  const oldNative = join(io.home(), ".agents/skills/SUH-DEVOPS-TEMPLATE");
  if (existsSync(oldNative) || isSymlink(oldNative)) { rmSync(oldNative, {recursive:true,force:true}); io.log("  레거시 Codex skills 정리: SUH-DEVOPS-TEMPLATE"); }
  if (io.which("codex")) for (const mp of LEGACY.marketplaces) io.run("codex", ["plugin","marketplace","remove", mp]);
}
```

**gemini.js**
```js
const LEGACY = { exts: ["SUH-DEVOPS-TEMPLATE"] };  // 옛 extension 이름
function migrateLegacy(io) {
  if (!io.which("gemini")) return;
  for (const e of LEGACY.exts) io.run("gemini", ["extensions", "uninstall", e]);  // 없으면 실패 무시
}
```

**pi.js / pi-common.js**
```js
// pi-common에 이미 oldDir(SUH-DEVOPS-TEMPLATE) 인지 로직 존재 → 정리까지 확장
function migrateLegacy(io) {
  const oldDir = join(io.home(), ".pi/agent/git/github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE");
  const newDir = join(io.home(), ".pi/agent/git/github.com/Cassiiopeia/projectops");
  if (existsSync(oldDir) && existsSync(newDir)) {   // 둘 다 있으면 옛것 제거
    // settings.json extensions에서 oldDir/harness loader 경로 항목 제거 후 rm
    removeOldLoaderFromSettings(io, oldDir);
    rmSync(oldDir, {recursive:true,force:true});
    io.log("  레거시 PI clone 정리: SUH-DEVOPS-TEMPLATE");
  }
}
```
> oldDir만 있고 newDir 없으면 `pi install`이 newDir을 만들 때까지 두거나, 안전하게 그대로 둔다(설치 흐름이 처리). 핵심은 **공존 시 옛것 제거**.

**cursor.js** ← 버전 기준점 + 선별 삭제 핵심

⚠️ **중대 발견 & 기존 버그 동반 수정**: 이 컴퓨터 실측 결과 `~/.cursor/skills`에는 **projectops 스킬(`suh-*`)과 somansa-tools 스킬(`gitlab`·`jenkins`·`redmine`·`drive`·`pad`·`sparrow`·`server-deploy` 등)이 공존**한다. 그런데 기존 `cursor.js`의 `remove()`는 `~/.cursor/skills`를 **통째로 rmSync** → **somansa-tools 스킬까지 전부 삭제**되는 버그가 있다. 따라서 `migrateLegacy`도 `remove()`도 **projectops가 설치한 항목만 선별 삭제**해야 한다.

**projectops 소유 판정 규칙** (소스 `skills/` 폴더명 집합 기준):
- 신규 스킬: `pro-*` (예: `pro-analyze`, `pro-github` …)
- 옛 스킬 잔재: `suh-*` (예: `suh-analyze` …)
- 공용 부산물: `references`, `config.json.example`, `cursor-skills-meta.json`
- **접두어 없는 폴더(`analyze`·`implement`·`plan`·`gitlab` 등)는 somansa-tools 소유 → 절대 건드리지 않음.**

```js
const LEGACY = { names: ["cassiiopeia", "suh-devops-template"], maxVersion: "4.2.4" };

// projectops가 이 폴더에 설치했다고 볼 수 있는 항목만 골라낸다.
// 소스 skills/ 폴더명(pro-*) + 옛 잔재(suh-*) + 공용 부산물.
function ownedEntries(io, ctx) {
  const dir = join(io.home(), ".cursor/skills");
  if (!existsSync(dir)) return [];
  const srcNames = new Set(readdirSync(resolveSkillsSrc(ctx)));  // pro-*, references, config.json.example
  const EXTRA = new Set(["cursor-skills-meta.json"]);
  return readdirSync(dir).filter(name =>
    srcNames.has(name) || /^suh-/.test(name) || EXTRA.has(name)
  );
}

function migrateLegacy(io, ctx) {
  const meta = readMeta(io);    // {name, version} | null
  if (!meta) return;
  const oldName = meta.name && LEGACY.names.includes(String(meta.name).toLowerCase());
  const oldVer  = isLegacyVersion(meta.version, LEGACY.maxVersion);
  if (!(oldName || oldVer)) return;
  for (const name of ownedEntries(io, ctx)) {
    rmSync(join(io.home(), ".cursor/skills", name), {recursive:true,force:true});
  }
  io.log(`  레거시 Cursor Skills 정리(선별): name=${meta.name}, v=${meta.version} → 재설치`);
  // 이후 기존 apply()의 복사 로직이 신규 pro-*를 재설치 (meta name=projectops로 갱신)
}
```

> **기존 `remove()`도 동일 규칙으로 수정** — 폴더 통째 rm 대신 `ownedEntries()`만 삭제하고, 삭제 후 폴더가 비면 폴더 제거, 다른 스킬이 남아있으면 폴더 유지. 이렇게 해야 "projectops만 제거" 시 somansa-tools가 보존된다. (별도 버그이므로 이 작업에 포함해 함께 고친다.)

### 4.4 안전성 원칙
- 모든 정리 명령은 **실패 무해**(없는 것 제거 = no-op). try/catch 또는 exit code 무시.
- config는 **복사만, 삭제 안 함**. 신규가 이미 있으면 절대 덮어쓰지 않음.
- `migrateLegacy` + `migrateConfigRoot`는 **idempotent** — 재설치·반복 실행 안전.

## 5. 산출물
1. `src/core/ide/legacy.js` (신규 — `isLegacyVersion`, `migrateConfigRoot`, `hasNonEmptyJson`)
2. `src/core/ide/adapters/claude.js` — `migrateLegacy` + `apply` 호출
3. `src/core/ide/adapters/codex.js` — 동일
4. `src/core/ide/adapters/gemini.js` — 동일
5. `src/core/ide/adapters/pi.js` + `pi-common.js` — 동일 (loader 경로 정리 포함)
6. `src/core/ide/adapters/cursor.js` — 버전/이름 기준 **선별** 재설치 + **기존 `remove()` 통째삭제 버그 동반 수정**(somansa-tools 등 타 스킬 보존)
7. 테스트: `src/core/ide/test/` (레거시 감지·정리·config 이관 단위 테스트, 이 컴퓨터 실측 케이스 반영)
8. GitHub 이슈 등록

## 6. 검증 계획
- 단위 테스트: `isLegacyVersion` 경계값(4.2.3/4.2.4→true, 4.2.5→false, null→false), `migrateConfigRoot`(신규 없음→이관, 신규 있음→skip, 소스 없음→no-op).
- 실측 검증(이 컴퓨터): cursor meta `cassiiopeia/4.2.3` → migrateLegacy가 재설치 판정하는지, **선별 삭제가 somansa-tools 스킬(`gitlab`·`jenkins`·`redmine` 등)을 보존하는지**, claude 좀비 마켓 정리되는지, `~/.projectops/config`가 이미 있으므로 config 이관은 skip되는지.
- `node --test` 전량 green + 기존 정합성 테스트 무손상.

## 7. 리스크
- **cursor 선별 삭제 오판**: 소스 `skills/`에 없는 옛 이름 스킬이 있으면 잔재가 남을 수 있음. `suh-*` 정규식 + 소스 폴더명 집합의 이중 기준으로 커버. somansa-tools가 우연히 `pro-*`/`suh-*` 이름을 쓸 가능성은 없음(별 네임스페이스).
- **claude marketplace remove 부작용**: `cassiiopeia-marketplace`를 다른 플러그인이 참조하지 않음(실측: 그 마켓엔 projectops 하나뿐이었음) → 제거 안전.
- **config 이관 민감값**: 복사만 하고 옛 파일 보존 → 유실 0. 신규가 이미 있으면 skip → 덮어쓰기 0.
