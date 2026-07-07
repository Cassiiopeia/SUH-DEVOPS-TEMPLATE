# projectops SP3 (리브랜딩 — 중간 범위) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 레포명 변경(완료)에 맞춰 저장소 전반의 `SUH-DEVOPS-TEMPLATE` URL·명칭을 `projectops`로 갱신한다. skills 접두사(`suh-*`)·플러그인명(`cassiiopeia`)·config 경로(`~/.suh-template`)는 유지한다(중간 범위, 스펙 A1).

**Architecture:** URL 패턴(`Cassiiopeia/SUH-DEVOPS-TEMPLATE`)은 기계적 일괄 치환 + git diff 검증. 표시 명칭·파일명은 파일 그룹별 수동 태스크. GitHub이 구 URL을 자동 리다이렉트하므로 치환 누락은 기능 장애가 아니라 표기 문제다(안전망 있음).

**Tech Stack:** sed(일괄 치환), bash -n / PowerShell Parser(문법 검증), git diff(무손상 검증)

**GitHub 이슈:** https://github.com/Cassiiopeia/projectops/issues/424
**설계 스펙:** `docs/superpowers/specs/2026-07-07-projectops-npx-migration-design.md`

## 이미 완료된 것 (이 계획 범위 밖)

- ✅ GitHub 레포명 변경: `Cassiiopeia/SUH-DEVOPS-TEMPLATE` → `Cassiiopeia/projectops` (구/신 URL `git ls-remote` 동일 HEAD 실측 확인)
- ✅ 로컬 git remote / `~/.suh-template/config/config.json` repos 항목 갱신
- ✅ `package.json`(homepage·repository·bugs — provenance 정합)·`bin/projectops.js` URL 갱신 (커밋 `7981978`)

## Global Constraints

- 치환 패턴은 **`Cassiiopeia/SUH-DEVOPS-TEMPLATE` → `Cassiiopeia/projectops`** (owner 포함 전체 매칭만 — 단독 `SUH-DEVOPS-TEMPLATE` 문자열은 태스크별로 판단해 치환).
- **유지(치환 금지)**: `suh-*` 스킬명, `cassiiopeia` 플러그인/마켓플레이스명, `~/.suh-template` config 경로, `docs/suh-template/` 산출물 경로, 과거 이슈/커밋 인용문.
- `.template_download_temp/`(과거 integrator 실행 잔여물)은 건드리지 않는다.
- 워크플로우 YAML은 **URL·문자열만** 변경 — `run:`/`uses:`/`steps:` 실행 로직 무손상을 git diff로 자가검증 (CLAUDE.md 규칙).
- 커밋 메시지: `projectops npx CLI 전환 및 npm 배포 자동화 : feat : {설명} https://github.com/Cassiiopeia/projectops/issues/424`
- push는 사용자 명시 요청 시에만.

## 실측 근거 (2026-07-07)

- `SUH-DEVOPS-TEMPLATE` 참조: 285개 파일 (대부분 docs/skills 표기)
- 핵심 파일 카운트: `template_integrator.sh` 35 / `.ps1` 33 / `README.md` 9 / `template_initializer.sh` 3 / `.claude-plugin/plugin.json` 2 / `marketplace.json` 1
- `metadata.template.source`는 **쓰기 전용** — integrator/initializer 어디에도 비교(read) 로직 없음 → 하위호환 부담 없이 `"projectops"`로 변경 가능
- `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md` 파일명 참조: integrator sh/ps1, `docs/TEMPLATE-INTEGRATOR.md`, `CONTRIBUTING.md`

---

### Task 1: integrator sh/ps1 URL·명칭 치환

**Files:**
- Modify: `template_integrator.sh` (TEMPLATE_REPO 112행, TEMPLATE_RAW_URL 124행, source 문자열 2462행, marketplace source 4517·5037행, clone 안내 5147·5161행 등 35곳)
- Modify: `template_integrator.ps1` (대응 33곳)

**Interfaces:**
- Produces: 신규 통합 프로젝트의 `version.yml`에 `source: "projectops"` 기록 (비교 로직 없음 — 실측 확인됨)

- [ ] **Step 1: URL 패턴 일괄 치환**

```bash
sed -i 's|Cassiiopeia/SUH-DEVOPS-TEMPLATE|Cassiiopeia/projectops|g' template_integrator.sh template_integrator.ps1
```

- [ ] **Step 2: 잔여 단독 명칭 확인 후 컨텍스트별 치환**

```bash
grep -n "SUH-DEVOPS-TEMPLATE" template_integrator.sh template_integrator.ps1
```

남는 항목 유형별 처리:
- `source: "SUH-DEVOPS-TEMPLATE"` (sh 2462행 및 ps1 대응) → `source: "projectops"`
- `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md` 파일명 → **유지** (Task 4에서 파일명 rename 여부 일괄 결정)
- 배너/도움말 표시 텍스트 → `projectops (구 SUH-DEVOPS-TEMPLATE)` 형태로 병기 또는 `projectops` 단독 — 표시 전용이므로 `projectops`로 치환

- [ ] **Step 3: 문법 검증**

Run: `bash -n template_integrator.sh && echo SH_OK`
Expected: `SH_OK`

Run (PowerShell): `$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("D:\0-suh\project\suh-github-template\template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}`
Expected: `PS1_PARSE_OK`

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.sh template_integrator.ps1
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : integrator 레포 URL·명칭 projectops 갱신 https://github.com/Cassiiopeia/projectops/issues/424"
```

### Task 2: initializer + 플러그인 매니페스트 갱신

**Files:**
- Modify: `.github/scripts/template_initializer.sh` (3곳 — `create_version_yml`의 `source: "SUH-DEVOPS-TEMPLATE"`, `.gitignore` 헤더 주석, 가이드 보존 주석)
- Modify: `.claude-plugin/plugin.json` (homepage·repository 2곳)
- Modify: `.claude-plugin/marketplace.json` (plugins[0].source.url 1곳)

- [ ] **Step 1: 치환**

```bash
sed -i 's|Cassiiopeia/SUH-DEVOPS-TEMPLATE|Cassiiopeia/projectops|g' .claude-plugin/plugin.json .claude-plugin/marketplace.json
sed -i 's|source: "SUH-DEVOPS-TEMPLATE"|source: "projectops"|' .github/scripts/template_initializer.sh
```

`template_initializer.sh` 잔여 2곳(주석·echo 텍스트)은 grep 후 문맥 유지하며 `projectops`로 수동 Edit.

- [ ] **Step 2: 검증 및 커밋**

Run: `bash -n .github/scripts/template_initializer.sh && "$PYTHON" -c "import json;json.load(open('.claude-plugin/plugin.json'));json.load(open('.claude-plugin/marketplace.json'));print('JSON_OK')"`
Expected: `JSON_OK`

```bash
git add .github/scripts/template_initializer.sh .claude-plugin/
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : initializer·플러그인 매니페스트 projectops 갱신 https://github.com/Cassiiopeia/projectops/issues/424"
```

> 참고: 플러그인 설치 명령(`claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE`)은 리다이렉트로 계속 동작하나, README의 안내는 Task 3에서 새 이름으로 갱신.

### Task 3: README·CONTRIBUTING·docs 스윕

**Files:**
- Modify: `README.md` (9곳 — 제목·curl URL·플러그인 설치 명령)
- Modify: `CONTRIBUTING.md`, `docs/**/*.md` (TEMPLATE-INTEGRATOR.md 등 다수)
- Modify: `CLAUDE.md` 1행 제목·본문 명칭 (프로젝트 지침 — "SUH-DEVOPS-TEMPLATE" 표기를 "projectops (구 SUH-DEVOPS-TEMPLATE)"로 첫 등장 병기, 이후 projectops)

- [ ] **Step 1: URL 일괄 치환**

```bash
sed -i 's|Cassiiopeia/SUH-DEVOPS-TEMPLATE|Cassiiopeia/projectops|g' README.md CONTRIBUTING.md CLAUDE.md
find docs -name "*.md" -not -path "docs/suh-template/*" -exec sed -i 's|Cassiiopeia/SUH-DEVOPS-TEMPLATE|Cassiiopeia/projectops|g' {} +
```

(`docs/suh-template/` 하위는 과거 산출물 기록이므로 제외)

- [ ] **Step 2: 표시 명칭 갱신** — README 제목/도입부를 `projectops`로, 첫 등장에 `(구 SUH-DEVOPS-TEMPLATE)` 병기. 잔여 확인:

```bash
grep -rn "SUH-DEVOPS-TEMPLATE" README.md CONTRIBUTING.md CLAUDE.md | grep -v "구 SUH-DEVOPS-TEMPLATE" | head -20
```

- [ ] **Step 3: 커밋**

```bash
git add README.md CONTRIBUTING.md CLAUDE.md docs/
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : docs : README·문서 전반 projectops 리브랜딩 https://github.com/Cassiiopeia/projectops/issues/424"
```

### Task 4: 보류 항목 일괄 결정 (사용자 확인 1회)

아래는 기능 영향이 없거나 별도 결정이 필요한 항목 — 한 번에 묻고 처리:

- [ ] `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md` 파일명 → `PROJECTOPS-SETUP-GUIDE.md` rename 여부 (참조 4파일 연동 수정 필요)
- [ ] 워크플로우 커밋 프리픽스(`SUH-DEVOPS-TEMPLATE 버전 관리 : ...`) → `projectops 버전 관리`로 변경 여부 (cosmetic, 워크플로우 YAML 수정 필요 — 실행 로직 무손상 git diff 검증 필수)
- [ ] `skills/` 내부 문서·`version.yml` 헤더 주석의 잔여 표기 (수백 곳, cosmetic) → 일괄 치환 여부

### Task 5: 최종 검증

- [ ] `npm pack --dry-run` — 번들 무손상 확인
- [ ] `node bin/projectops.js` — 새 URL 안내 출력 확인
- [ ] `git diff main@{push}..HEAD -- .github/workflows/` 에 실행 로직 변경 없음 확인 (변경했다면 문자열뿐임을 확인)
- [ ] push(사용자 승인) 후 deploy 시 NPM-PUBLISH provenance 정상 통과 확인

## Self-Review 기록

1. **Spec coverage**: 스펙 §3 SP3 항목(레포명·README·docs·integrator 상수·매니페스트·source 문자열 하위호환) 전부 매핑. source 문자열은 실측 결과 비교 로직이 없어 "하위호환 처리" 대신 단순 치환으로 확정.
2. **Placeholder scan**: 보류 항목은 Task 4에 명시적 결정 대기로 분리 — 모호한 "적절히" 표현 없음.
3. **일관성**: 치환 패턴·제외 목록(Global Constraints)이 전 태스크에서 동일.
