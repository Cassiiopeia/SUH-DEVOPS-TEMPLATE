# projectops SP1 (이름 선점 + npm 배포 파이프라인) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 루트 package.json을 `projectops` npm 매니페스트로 전환하고, 스텁 CLI + npm 자동배포 워크플로우를 구축해 npm 이름을 선점한다.

**Architecture:** 스텁 CLI(`bin/projectops.js`, 의존성 0, ESM)만 먼저 배포해 이름을 확보한다. 배포는 deploy 브랜치 push 트리거(+ workflow_dispatch)의 새 워크플로우가 main 기준으로 수행한다(멱등). CLI 전용 파일은 initializer/integrator 3곳 제외 목록에 즉시 반영해 템플릿 정체성을 보존한다.

**Tech Stack:** Node.js >= 18 (ESM), GitHub Actions (actions/checkout@v5, actions/setup-node@v4), npm registry

**GitHub 이슈:** https://github.com/Cassiiopeia/projectops/issues/424
**설계 스펙:** `docs/superpowers/specs/2026-07-07-projectops-npx-migration-design.md`

## Global Constraints

- 스텁 CLI는 **외부 의존성 0** (dependencies 필드 자체를 두지 않음). Node >= 18.
- SP1의 `files` 화이트리스트는 **`["bin/"]` 만** — 템플릿 자산 번들은 SP2에서 확정 (YAGNI). npm이 README.md·package.json을 자동 포함하는 것은 정상.
- package.json `version`은 **3.0.182 유지** (PLUGIN-VERSION-SYNC가 계속 동기화). 0.0.1로 리셋하지 않는다.
- npm publish는 **GitHub Actions에서만** 실행 (내부망 로컬 publish 금지).
- 커밋 메시지 형식(이모지·태그 금지, AI 흔적 trailer 절대 금지):
  `projectops npx CLI 전환 및 npm 배포 자동화 : feat : {설명} https://github.com/Cassiiopeia/projectops/issues/424`
- main 브랜치 직접 작업. `git push`는 **사용자 명시 요청 시에만**, push 전 `git pull --rebase origin main`.
- 루트 신규 파일(`bin/`, 향후 `src/`)은 3곳 규칙 대상: `template_initializer.sh` + `template_integrator.sh` + `template_integrator.ps1`.

## File Structure

| 파일 | 책임 |
|------|------|
| `package.json` (Modify) | projectops npm 매니페스트 (bin·files·engines·repository) + pi 매니페스트 겸용 |
| `bin/projectops.js` (Create) | 스텁 CLI — 배너·버전·기존 스크립트 안내. SP2에서 `src/` 라우팅으로 확장될 엔트리 |
| `.github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml` (Create) | deploy push → main 기준 npm publish (멱등) |
| `.github/scripts/template_initializer.sh` (Modify) | 템플릿 생성 레포에서 CLI 전용 파일 삭제 |
| `template_integrator.sh` / `.ps1` (Modify) | 통합 시 CLI 전용 파일 복사 제외 |

---

### Task 1: package.json → projectops npm 매니페스트 전환

**Files:**
- Modify: `package.json` (전체 교체)

**Interfaces:**
- Produces: `bin.projectops = "bin/projectops.js"` (Task 2가 이 경로에 파일 생성), `files = ["bin/"]`, `version 3.0.182` (Task 4 워크플로우가 `npm pkg set version`으로 덮어씀)

- [ ] **Step 1: package.json 전체 교체**

```json
{
  "name": "projectops",
  "version": "3.0.182",
  "description": "ProjectOps — 완전 자동화 GitHub 프로젝트 관리 템플릿 통합 CLI (구 SUH-DEVOPS-TEMPLATE 마법사)",
  "keywords": [
    "devops",
    "automation",
    "github-actions",
    "template",
    "cli",
    "pi-package"
  ],
  "license": "MIT",
  "author": {
    "name": "Cassiiopeia",
    "url": "https://github.com/Cassiiopeia"
  },
  "homepage": "https://github.com/Cassiiopeia/projectops",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/Cassiiopeia/projectops.git"
  },
  "bugs": {
    "url": "https://github.com/Cassiiopeia/projectops/issues"
  },
  "type": "module",
  "bin": {
    "projectops": "bin/projectops.js"
  },
  "engines": {
    "node": ">=18"
  },
  "files": [
    "bin/"
  ],
  "pi": {
    "skills": [
      "./skills"
    ]
  }
}
```

주의: `"private": true` 제거(게시 가능해야 함), `repository` 필드는 `--provenance` 검증에 필수(실제 레포 URL과 일치해야 함). `pi` 필드는 유지 — pi 패키지 식별자가 `cassiiopeia` → `projectops`로 변경됨(스펙 Q1, 사용자 승인됨).

- [ ] **Step 2: npm pack으로 번들 내용 검증**

Run: `npm pack --dry-run 2>&1 | grep -E "notice.*(B|kB)|total files"`
Expected: `bin/projectops.js`(Task 2 이전엔 아직 없어 package.json + README.md만), `skills/`·`docs/`·`harness/`·`.claude-plugin/` **미포함**. Task 2 완료 후 재실행하여 `bin/projectops.js` 포함 확인.

- [ ] **Step 3: 커밋** (Task 2와 묶어서 커밋해도 됨 — Task 2 Step 4 참조)

---

### Task 2: bin/projectops.js 스텁 CLI

**Files:**
- Create: `bin/projectops.js`

**Interfaces:**
- Consumes: `package.json`의 `version` 필드 (상대 경로 `../package.json`)
- Produces: `projectops` / `projectops --version|-v` / `projectops --help|-h` 명령 동작. SP2가 이 파일을 `src/index.js` 라우팅으로 교체 확장할 예정

- [ ] **Step 1: bin/projectops.js 작성**

```js
#!/usr/bin/env node
// projectops 스텁 CLI — 이름 선점 및 배포 파이프라인 검증용 (SP1)
// 마법사 본체(SP2)가 이식되기 전까지 기존 template_integrator 안내를 제공한다.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const nodeMajor = Number(process.versions.node.split(".")[0]);
if (nodeMajor < 18) {
  console.error(`Node.js 18 이상이 필요합니다 (현재: ${process.versions.node})`);
  process.exit(1);
}

const pkg = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), "..", "package.json"), "utf8"),
);

const args = process.argv.slice(2);
if (args.includes("--version") || args.includes("-v")) {
  console.log(pkg.version);
  process.exit(0);
}

const RESET = "\x1b[0m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const DIM = "\x1b[2m";

console.log(`
${CYAN}=========================================================
  ProjectOps v${pkg.version}
  완전 자동화 GitHub 프로젝트 관리 템플릿 통합 CLI
=========================================================${RESET}

${YELLOW}npx 마법사는 준비 중입니다.${RESET} 지금은 아래 기존 방식으로 통합하세요.

${GREEN}macOS / Linux:${RESET}
  bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh")

${GREEN}Windows (PowerShell):${RESET}
  $wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1")

${DIM}문서: https://github.com/Cassiiopeia/projectops${RESET}
`);
```

`--help`/`-h`는 스텁 단계에서 기본 배너와 동일 출력(별도 분기 불필요 — 배너가 곧 도움말).

- [ ] **Step 2: 스모크 테스트 — 버전 출력**

Run: `node bin/projectops.js --version`
Expected: `3.0.182`

- [ ] **Step 3: 스모크 테스트 — 배너 출력**

Run: `node bin/projectops.js`
Expected: `ProjectOps v3.0.182` 포함 배너 + macOS/Windows 안내 명령 2종 출력, exit code 0

- [ ] **Step 4: npm pack 재검증 후 커밋**

Run: `npm pack --dry-run 2>&1 | grep -E "bin/|total files"`
Expected: `bin/projectops.js` 포함, total files 3 (package.json, README.md, bin/projectops.js)

```bash
git add package.json bin/projectops.js
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : package.json을 projectops npm 매니페스트로 전환하고 스텁 CLI 추가 https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 3: 3곳 제외 목록 반영 (initializer + integrator sh/ps1)

**Files:**
- Modify: `.github/scripts/template_initializer.sh` — `cleanup_template_files()` (package.json 블록 472-475행 부근, PLUGIN-VERSION-SYNC 블록 429-432행 부근)
- Modify: `template_integrator.sh:2100-2109` — `plugin_items_to_remove` 배열
- Modify: `template_integrator.ps1:1719-1728` — `$pluginItemsToRemove` 배열

**Interfaces:**
- Consumes: Task 2의 `bin/` 폴더, Task 4의 워크플로우 파일명 `PROJECT-TEMPLATE-NPM-PUBLISH.yaml` (파일 생성 전이어도 이름은 확정)
- Produces: 없음 (방어 코드). `src/`는 아직 없지만 SP2 누락 방지를 위해 미리 등록 (`[ -d ]` 가드라 무해)

- [ ] **Step 1: template_initializer.sh — pi 매니페스트 블록 뒤에 CLI 삭제 블록 추가**

기존 (472-475행):
```bash
    # pi 패키지 매니페스트 삭제 (마켓플레이스 전용, 일반 프로젝트에서 불필요)
    if [ -f "package.json" ]; then
        rm -f package.json
        echo "  ✓ package.json 삭제 (pi 패키지 매니페스트)"
    fi
```

바로 뒤에 추가:
```bash
    # projectops npm CLI 전용 파일 삭제 (npx 배포용, 마켓플레이스 전용)
    if [ -d "bin" ]; then
        rm -rf bin
        echo "  ✓ bin 폴더 삭제 (projectops CLI)"
    fi

    if [ -d "src" ]; then
        rm -rf src
        echo "  ✓ src 폴더 삭제 (projectops CLI)"
    fi
```

- [ ] **Step 2: template_initializer.sh — PLUGIN-VERSION-SYNC 삭제 블록 뒤에 NPM-PUBLISH 삭제 블록 추가**

기존 (429-432행):
```bash
    if [ -f ".github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml" ]; then
        rm -f .github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml
        echo "  ✓ PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml 삭제 (마켓플레이스 전용)"
    fi
```

바로 뒤에 추가:
```bash
    # npm 배포 워크플로우 삭제 (projectops 패키지 게시용, 템플릿 레포 전용)
    if [ -f ".github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml" ]; then
        rm -f .github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml
        echo "  ✓ PROJECT-TEMPLATE-NPM-PUBLISH.yaml 삭제 (마켓플레이스 전용)"
    fi
```

- [ ] **Step 3: template_integrator.sh 배열에 3항목 추가**

기존 (2100-2109행):
```bash
    local plugin_items_to_remove=(
        ".claude-plugin"    # Claude Code 플러그인 매니페스트
        ".codex-plugin"     # Codex 플러그인 메타데이터
        ".agents"           # Codex 마켓플레이스 메타데이터
        ".cursor"           # Cursor 스킬 복사본
        "scripts"           # 플러그인 스크립트 (마켓플레이스 전용)
        "package.json"      # pi 패키지 매니페스트 (마켓플레이스 전용)
        "harness"           # pi Persona Harness (loader/PERSONA/WORKFLOW, 마켓플레이스 전용)
        ".github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml"  # 플러그인 매니페스트 버전 동기화 (위 매니페스트가 제거되므로 동기화 대상 없음)
    )
```

`harness` 줄 뒤·PLUGIN-VERSION-SYNC 줄 뒤에 각각 추가하여:
```bash
    local plugin_items_to_remove=(
        ".claude-plugin"    # Claude Code 플러그인 매니페스트
        ".codex-plugin"     # Codex 플러그인 메타데이터
        ".agents"           # Codex 마켓플레이스 메타데이터
        ".cursor"           # Cursor 스킬 복사본
        "scripts"           # 플러그인 스크립트 (마켓플레이스 전용)
        "package.json"      # pi 패키지 매니페스트 (마켓플레이스 전용)
        "harness"           # pi Persona Harness (loader/PERSONA/WORKFLOW, 마켓플레이스 전용)
        "bin"               # projectops npm CLI (마켓플레이스 전용)
        "src"               # projectops npm CLI 소스 (마켓플레이스 전용)
        ".github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml"  # 플러그인 매니페스트 버전 동기화 (위 매니페스트가 제거되므로 동기화 대상 없음)
        ".github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml"  # npm 배포 워크플로우 (템플릿 레포 전용)
    )
```

- [ ] **Step 4: template_integrator.ps1 배열에 3항목 추가 (콤마 주의)**

기존 (1719-1728행):
```powershell
    $pluginItemsToRemove = @(
        ".claude-plugin",   # Claude Code 플러그인 매니페스트
        ".codex-plugin",    # Codex 플러그인 메타데이터
        ".agents",          # Codex 마켓플레이스 메타데이터
        ".cursor",          # Cursor 스킬 복사본
        "scripts",          # 플러그인 스크립트 (마켓플레이스 전용)
        "package.json",     # pi 패키지 매니페스트 (마켓플레이스 전용)
        "harness",          # pi Persona Harness (loader/PERSONA/WORKFLOW, 마켓플레이스 전용)
        ".github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml"  # 플러그인 매니페스트 버전 동기화 (위 매니페스트가 제거되므로 동기화 대상 없음)
    )
```

변경 후 (기존 마지막 항목 뒤에 콤마 추가 필수):
```powershell
    $pluginItemsToRemove = @(
        ".claude-plugin",   # Claude Code 플러그인 매니페스트
        ".codex-plugin",    # Codex 플러그인 메타데이터
        ".agents",          # Codex 마켓플레이스 메타데이터
        ".cursor",          # Cursor 스킬 복사본
        "scripts",          # 플러그인 스크립트 (마켓플레이스 전용)
        "package.json",     # pi 패키지 매니페스트 (마켓플레이스 전용)
        "harness",          # pi Persona Harness (loader/PERSONA/WORKFLOW, 마켓플레이스 전용)
        "bin",              # projectops npm CLI (마켓플레이스 전용)
        "src",              # projectops npm CLI 소스 (마켓플레이스 전용)
        ".github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml",  # 플러그인 매니페스트 버전 동기화 (위 매니페스트가 제거되므로 동기화 대상 없음)
        ".github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml"  # npm 배포 워크플로우 (템플릿 레포 전용)
    )
```

- [ ] **Step 5: 문법 검증 3종**

Run: `bash -n .github/scripts/template_initializer.sh && bash -n template_integrator.sh && echo SH_OK`
Expected: `SH_OK`

Run (PowerShell 도구, Windows 네이티브):
```powershell
$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("D:\0-suh\project\suh-github-template\template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}
```
Expected: `PS1_PARSE_OK`

- [ ] **Step 6: 커밋**

```bash
git add .github/scripts/template_initializer.sh template_integrator.sh template_integrator.ps1
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : CLI 전용 파일(bin·src·NPM-PUBLISH)을 initializer·integrator 3곳 제외 목록에 반영 https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 4: PROJECT-TEMPLATE-NPM-PUBLISH.yaml 신설

**Files:**
- Create: `.github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml`

**Interfaces:**
- Consumes: Task 1의 package.json (`name: projectops`), `.github/scripts/version_manager.sh get` (마지막 줄이 버전 문자열)
- Produces: deploy push / 수동 실행 시 npm 게시. 이미 게시된 버전이면 성공 종료(멱등)

- [ ] **Step 1: 워크플로우 파일 작성**

```yaml
# ===================================================================
# PROJECT-TEMPLATE-NPM-PUBLISH.yaml
# projectops npm 패키지 자동 배포 워크플로우 v1.0
# ===================================================================
#
# 이 워크플로우는 SUH-DEVOPS-TEMPLATE 저장소 전용입니다.
# template_integrator로 복사되지 않으며, template_initializer가 삭제합니다.
#
# 동작:
# - main 기준으로 version.yml 버전을 읽어 package.json에 주입 후 npm publish
# - 이미 레지스트리에 있는 버전이면 성공 종료 (멱등)
#
# 트리거: deploy 브랜치 push 시 (+ 수동 실행)
# (VERSION-CONTROL이 GITHUB_TOKEN으로 version.yml을 변경하면
#  후속 워크플로우가 트리거되지 않으므로 deploy push를 트리거로 사용
#  — PLUGIN-VERSION-SYNC와 동일 패턴)
#
# 필요 Secret: NPM_TOKEN (npm Granular Access Token, 2FA bypass 허용)
# ===================================================================

name: PROJECT-TEMPLATE-NPM-PUBLISH

concurrency:
  group: npm-publish
  cancel-in-progress: false

on:
  push:
    branches: ["deploy"]
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  publish-npm:
    name: npm 패키지 배포
    runs-on: ubuntu-latest

    steps:
      - name: 저장소 체크아웃 (main 기준)
        uses: actions/checkout@v5
        with:
          ref: main

      - name: Node.js 설정
        uses: actions/setup-node@v4
        with:
          node-version: 20
          registry-url: https://registry.npmjs.org

      - name: version.yml에서 버전 추출
        id: version
        run: |
          chmod +x .github/scripts/version_manager.sh
          VERSION=$(./.github/scripts/version_manager.sh get | tail -n 1)
          if [ -z "$VERSION" ]; then
            echo "❌ version.yml에서 버전을 추출할 수 없습니다"
            exit 1
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "📦 배포 대상 버전: $VERSION"

      - name: package.json 버전 주입
        run: npm pkg set version=${{ steps.version.outputs.version }}

      - name: 이미 배포된 버전인지 확인 (멱등)
        id: check
        run: |
          PKG_NAME=$(npm pkg get name | tr -d '"')
          VERSION="${{ steps.version.outputs.version }}"
          if npm view "${PKG_NAME}@${VERSION}" version >/dev/null 2>&1; then
            echo "skip=true" >> $GITHUB_OUTPUT
            echo "ℹ️ ${PKG_NAME}@${VERSION} 은 이미 배포되어 있습니다. 건너뜁니다."
          else
            echo "skip=false" >> $GITHUB_OUTPUT
          fi

      - name: npm 배포
        if: steps.check.outputs.skip == 'false'
        run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

      - name: 배포 결과 요약
        if: steps.check.outputs.skip == 'false'
        run: echo "✅ projectops@${{ steps.version.outputs.version }} npm 배포 완료"
```

- [ ] **Step 2: 로컬 YAML 파싱 확인 (참고용 신호 — CLAUDE.md 규칙: 로컬 파서 ≠ GitHub 실제 동작)**

Run: `PYTHON=$(command -v python3 || command -v python); "$PYTHON" -c "import yaml,io; yaml.safe_load(io.open('.github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml', encoding='utf-8')); print('YAML_OK')"`
Expected: `YAML_OK` (pyyaml 미설치면 이 단계는 건너뛰고 GitHub 실행에서 확인)

- [ ] **Step 3: 커밋 (스펙 문서 수정분 포함)**

```bash
git add .github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml docs/superpowers/specs/2026-07-07-projectops-npx-migration-design.md docs/superpowers/plans/2026-07-07-projectops-sp1-npm-package.md docs/suh-template/issue/
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : deploy 트리거 npm 자동배포 워크플로우 신설(멱등 publish) https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 5: NPM_TOKEN 등록 + push + 최초 배포 (사용자 개입 필요)

**Files:** 없음 (외부 시스템 작업)

**Interfaces:**
- Consumes: Task 4의 워크플로우 (`workflow_dispatch`), 사용자가 발급한 npm 토큰
- Produces: npm 레지스트리에 `projectops@3.0.x` 게시 (이름 선점 완료)

- [ ] **Step 1 (사용자): npm Granular Access Token 발급**

npmjs.com → 프로필 → Access Tokens → Generate New Token → **Granular Access Token**
- Packages and scopes: Read and write
- 2FA 요구 설정이 있다면 "Bypass 2FA" 허용 (CI 자동 배포용)

- [ ] **Step 2: GitHub Actions Secret 등록**

사용자가 토큰 값을 제공하면 github 스킬(secrets 서브커맨드)로 `NPM_TOKEN` 등록, 또는 사용자가 직접: 레포 Settings → Secrets and variables → Actions → New repository secret → Name `NPM_TOKEN`

- [ ] **Step 3 (사용자 승인 후): push**

```bash
git pull --rebase origin main
git push origin main
```

- [ ] **Step 4: workflow_dispatch로 최초 배포 실행**

GitHub API(`POST /repos/Cassiiopeia/projectops/actions/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml/dispatches`, body `{"ref":"main"}`) 또는 Actions 탭에서 수동 실행.

- [ ] **Step 5: 게시 확인**

Run: `npm view projectops version --registry https://registry.npmjs.org` (외부망) 또는 GitHub Actions 로그 확인
Expected: `3.0.18x` (현재 version.yml 버전)

**실패 분기 — 이름이 이미 선점된 경우** (`403 Forbidden` / `You do not have permission to publish "projectops"`):
package.json `name`을 `@cassiiopeia/projectops`로 변경 후 재배포 (스펙 §7 fallback). README 안내 명령도 `npx @cassiiopeia/projectops`로 갱신.

---

## Self-Review 기록

1. **Spec coverage**: SP1 산출물 6항목(§3) 전부 태스크 매핑 — package.json(T1), 스텁 CLI(T2), 3곳 규칙(T3), 워크플로우(T4), NPM_TOKEN·최초배포(T5). 스펙 D3 트리거 수정(deploy push)도 T4에 반영.
2. **Placeholder scan**: 전체 코드·명령·기대출력 명시 확인. "적절히 처리" 류 표현 없음.
3. **Type consistency**: `bin/projectops.js` 경로(T1 bin 필드 ↔ T2 생성 ↔ T3 삭제 목록 "bin"), 워크플로우 파일명(T3 ↔ T4), 커밋 메시지 형식 일관 확인.
