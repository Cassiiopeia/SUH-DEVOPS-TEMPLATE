# suh-harness 플러그인 설계 — 페르소나/워크플로우 하네스의 명령어 설치·업데이트 지원

- 작성일: 2026-06-10
- 상태: 설계 승인됨 (구현 전)
- 대상 레포: `Cassiiopeia/projectops` (cassiiopeia-marketplace)

## 1. 배경과 목표

사내 GitLab의 `crowmania/harness-dev` 레포는 PERSONA.md(5개 전문 페르소나 + 핵심 철학)와
WORKFLOW.md(6 Phase SDLC + `hypercortex/` 누적 문서 체계)를 세션 시작 시 시스템 프롬프트에
주입하는 AI 코딩 하네스다. pi에서는 extension(`before_agent_start` 훅)으로 동작한다.

이 컨셉을 Claude Code에서도 쓰되, 다음 요구를 만족해야 한다:

1. **명령어 설치·업데이트** — 수동 파일 복사 금지. `pi install`/`pi update`처럼
   `claude plugin install` / `claude plugin update`로 관리되어야 한다.
2. **선택적 적용** — cassiiopeia 스킬 모음과 독립적으로, 하네스를 원하는 사용자만 설치한다.
3. **콘텐츠 신규 작성** — harness-dev는 회사 내부 레포다. 원문을 공개 GitHub 레포에
   복사하지 않는다. 구조와 컨셉만 본떠 새로 작성한다.
4. **글로벌 주입** — 설치하면 모든 프로젝트의 모든 세션에 적용된다(플러그인 기본 동작).

## 2. 채택한 접근: 같은 마켓플레이스에 별도 플러그인

`SUH-DEVOPS-TEMPLATE` 레포 안에 두 번째 플러그인 `suh-harness`를 추가한다.
Claude Code 플러그인 시스템이 pi package와 1:1 대응하는 메커니즘을 모두 제공한다.

| 요구 | pi | Claude Code (이번 설계) |
|---|---|---|
| 설치 | `pi install <git-url>` | `claude plugin install suh-harness@cassiiopeia-marketplace` |
| 업데이트 | `pi update` | `claude plugin update suh-harness` |
| 주입 | extension `before_agent_start` | plugin hook `SessionStart` (stdout → 세션 컨텍스트) |
| 선택적 | 레포별 설치 | 별도 플러그인 — 설치한 사용자만 적용 |

### 기각한 대안

- **(B) 기존 cassiiopeia 플러그인에 hook 추가** — cassiiopeia 설치자 전원에게 하네스가
  강제 주입된다. "선택적 지원" 요구 위반.
- **(C) 별도 레포 분리** — 마켓플레이스 등록·버전 동기화·CI 관리 포인트가 2배.
  같은 레포 내 플러그인 분리로 충분하다.

## 3. 디렉토리 구조 (신규)

```
SUH-DEVOPS-TEMPLATE/
├── .claude-plugin/
│   └── marketplace.json            # [수정] plugins 배열에 suh-harness 항목 추가
└── plugins/
    └── suh-harness/                # [신규]
        ├── .claude-plugin/
        │   └── plugin.json         # 플러그인 매니페스트 (버전은 version.yml과 동기화)
        ├── hooks/
        │   ├── hooks.json          # SessionStart hook 정의
        │   └── inject_harness.js   # 주입 스크립트 (Node, 크로스 플랫폼)
        └── harness/
            ├── PERSONA.md          # 신규 작성 콘텐츠
            └── WORKFLOW.md         # 신규 작성 콘텐츠
```

## 4. 컴포넌트 상세

### 4.1 marketplace.json 변경

`plugins` 배열에 항목 추가. 같은 레포 안의 하위 디렉토리 플러그인은 상대 경로 source를 쓴다:

```json
{
  "name": "suh-harness",
  "source": "./plugins/suh-harness",
  "description": "AI 코딩 하네스 - 5개 전문 페르소나 + SDLC 워크플로우를 모든 세션에 주입",
  "version": "3.0.104",
  "category": "DevOps",
  "keywords": ["harness", "persona", "workflow", "sdlc"]
}
```

> 구현 시 검증: 상대 경로 source가 marketplace add(git URL 방식)에서 정상 해석되는지
> 로컬 마켓플레이스 add로 먼저 확인한다. 안 되면 cassiiopeia처럼 url source + 서브디렉토리
> 지정 방식으로 전환한다.

### 4.2 plugin.json

```json
{
  "name": "suh-harness",
  "description": "AI 코딩 하네스 - 5개 전문 페르소나 + SDLC 워크플로우 주입",
  "version": "3.0.104",
  "author": { "name": "Cassiiopeia", "url": "https://github.com/Cassiiopeia" },
  "homepage": "https://github.com/Cassiiopeia/projectops",
  "repository": "https://github.com/Cassiiopeia/projectops",
  "license": "MIT",
  "keywords": ["harness", "persona", "workflow"]
}
```

### 4.3 hooks/hooks.json — 주입 엔진

SessionStart hook의 stdout은 세션 컨텍스트에 추가된다(pi의 시스템 프롬프트 주입과 동등).

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/inject_harness.js\""
          }
        ]
      }
    ]
  }
}
```

설계 결정:

- **`${CLAUDE_PLUGIN_ROOT}` 변수 사용** — 설치 경로 하드코딩 금지. pi 때 하드코딩 로더
  (`harness-global.ts`)가 package화를 막았던 문제의 재발 방지.
- **Node 스크립트 사용 (shell `cat` 대신)** — hook 명령은 Windows(cmd)와 mac(bash)에서
  모두 실행돼야 한다. `cat`/glob은 Windows cmd에서 깨지므로, 파일 읽기는 Node 스크립트
  내부에서 처리한다. Node는 Claude Code 사용 환경(npm 설치)에 이미 존재한다.

### 4.4 hooks/inject_harness.js

```js
// suh-harness: PERSONA/WORKFLOW md를 세션 컨텍스트로 주입한다.
// SessionStart hook의 stdout이 컨텍스트로 추가되는 메커니즘을 사용.
const fs = require("fs");
const path = require("path");

const harnessDir = path.join(__dirname, "..", "harness");
const files = ["PERSONA.md", "WORKFLOW.md"];

let out = "";
for (const file of files) {
  const p = path.join(harnessDir, file);
  if (fs.existsSync(p)) {
    out += `\n\n--- HARNESS: ${file} ---\n\n` + fs.readFileSync(p, "utf-8");
  }
}
if (out) {
  console.log("## SYSTEM GUIDELINES & PERSONAS (suh-harness)" + out);
}
```

- 경로는 `__dirname` 기준 상대 — 어디에 설치되든 동작.
- 파일이 없으면 조용히 빈 출력(세션 진행을 막지 않음). 읽기 실패는 stderr로만 남긴다.
- 쓰기 동작 없음 — 주입은 항상 읽기 전용이므로 동시 세션 충돌이 원천적으로 없다.

### 4.5 harness/PERSONA.md, WORKFLOW.md — 콘텐츠 (신규 작성)

원문 복사 금지. harness-dev에서 본뜨는 것은 **구조**다:

**PERSONA.md 구조** (한국어, 약 50~70줄):
- 핵심 철학: 결과 중심 자율성, 선제적 탁월함, 안티 컨퍼메이션 바이어스,
  건조한 기술 중심 소통, 지적 겸손
- 5개 페르소나: ① 시스템 아키텍트 ② 소프트웨어 개발자 ③ 프론트엔드/디자이너
  ④ 리뷰어 ⑤ SDET — 각각 목표 + 핵심 책무 3~4개

**WORKFLOW.md 구조** (한국어, 약 80~100줄):
- `hypercortex/` 지식 시스템 선언: 프로젝트별 영구 메모리.
  `TODO.md`(작업 트래커), `REQUIREMENT.md`, `DESIGN.md`, `SPECIFICATION.md`,
  `DEVELOPMENT.md` — 작업하면서 생성·갱신되어 프로젝트와 함께 누적된다.
- 6 Phase SDLC: 요구분석 → 설계 → 사양 → 개발 → 감사 → 검증.
  각 Phase는 담당 페르소나 + 목표 + 완료 조건(DoD) 체크리스트 + 리뷰어 REVIEW_LOG 강제.

문장은 전부 새로 쓴다. 사내 원문과 문장 단위로 일치하는 부분이 없어야 한다.

## 5. 기존 인프라 연동 (수정 2곳)

### 5.1 PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml

version.yml 변경 시 매니페스트 버전을 동기화하는 기존 워크플로우에
`plugins/suh-harness/.claude-plugin/plugin.json`과 marketplace.json의 suh-harness 항목
version 필드를 추가한다. (현재 동기화 대상: `.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`)

### 5.2 템플릿 초기화/통합 제외 목록

`plugins/`는 마켓플레이스 전용 디렉토리다. `skills/`, `scripts/`, `.claude-plugin/`과
동일하게 **템플릿 초기화(`template_initializer.sh`)와 통합(`template_integrator.sh/.ps1`)
복사 대상에서 제외**한다. CLAUDE.md의 "복사되지 않는 템플릿 전용 파일" 목록에도 추가한다.

### 5.3 template_integrator의 harness 설치 지원 (sh + ps1 동일)

integrator에는 이미 IDE 도구 설치 흐름(`offer_ide_tools_install` — "IDE Skills 현재 상태"
표시 → "[ Claude Code 플러그인 관리 ]" choose_menu)이 있다. harness는 **별도 질문이 아니라
이 기존 흐름에 통합**한다. (`skills` 모드에서도 자동으로 함께 처리되는 효과)

**(1) 상태 표시 확장** — "IDE Skills 현재 상태"의 Claude Code 항목을 플러그인 2종으로:

```
Claude Code (cassiiopeia)  user   v3.0.104 ✓ 최신버전
Claude Code (suh-harness)  미설치
```

cassiiopeia와 동일하게 `claude plugin list --json`에서 suh-harness의 scope/version을
파싱하고, `✓ 최신버전` / `→ 업데이트 가능: vX` 태그를 단다.

**(2) 플러그인 관리 메뉴 확장** — cassiiopeia 메뉴 처리 직후, suh-harness 메뉴를 추가한다.
미설치면 `install|설치 / skip|건너뛰기(기본)`, 설치돼 있으면 cassiiopeia와 동일한
`update / reinstall / delete / skip`.

**(3) 1줄 설명 의무화 (핵심 요구)** — 사용자가 "이게 뭔지" 모른 채 선택하지 않도록,
각 플러그인 메뉴를 띄우기 **직전에 한 줄 설명을 출력**한다. suh-harness뿐 아니라
기존 cassiiopeia 메뉴에도 소급 적용한다:

```
[ Claude Code 플러그인 관리 ]

  cassiiopeia — DevOps 자동화 스킬 모음. /analyze, /implement, /issue 등
                23+ 슬래시 커맨드를 추가합니다.
  (메뉴: update / reinstall / delete / skip)

  suh-harness — AI 코딩 하네스. 5개 전문 페르소나(아키텍트·개발자·프론트·리뷰어·SDET)와
                SDLC 워크플로우를 모든 Claude Code 세션에 자동 주입합니다.
                설치하면 작업 시 프로젝트마다 hypercortex/ 산출 문서가 생성됩니다.
  (메뉴: install / skip — 기본 skip)
```

suh-harness 설명에는 **부작용 고지**(모든 세션 주입 + hypercortex/ 문서 생성)를 반드시
포함한다 — 설치 후 "왜 이상한 폴더가 생기지?"를 예방.

**(4) 동작** — 선택 시:
1. marketplace 미등록이면 `claude plugin marketplace add Cassiiopeia/projectops`
   (기존 cassiiopeia 설치 로직과 같은 처리 재사용).
2. `claude plugin install suh-harness@cassiiopeia-marketplace --scope user` 또는
   `claude plugin update suh-harness@cassiiopeia-marketplace`.
3. claude CLI 미감지 시: 기존 동작과 동일하게 상태에 "CLI 미감지 (수동 설치 필요)"만
   표시하고 메뉴를 건너뛴다 (integrator 전체 중단 없음).

**(5) 비대상** — harness는 머신(user scope) 단위 설치라 레포 파일을 바꾸지 않는다.
version.yml에 선택을 저장하지 않으며(synology와 다른 점 — synology는 레포에 파일이
복사되므로 저장이 필요했음), 되돌리기(revert) 모드의 복원 대상도 아니다.

**(6) sh/ps1 동등성** — 두 스크립트의 상태 표시·설명 문구·메뉴·동작이 동일해야 한다.

## 6. 사용자 흐름

```bash
# 최초 1회 (이미 마켓플레이스 등록자는 생략)
claude plugin marketplace add Cassiiopeia/projectops

# 설치 (선택적 — 하네스를 원하는 사람만)
claude plugin install suh-harness@cassiiopeia-marketplace --scope user

# 업데이트
claude plugin update suh-harness
```

설치 후 새 세션부터 PERSONA/WORKFLOW가 주입되고, 작업 시 프로젝트마다 `hypercortex/`
문서가 생성·누적된다.

## 7. 동시 세션 운영 노트

- **주입(PERSONA/WORKFLOW 읽기)**: 충돌 없음. 세션 몇 개를 띄워도 안전하다.
- **`hypercortex/` 문서(쓰기)**: 레포 안의 파일이므로, 같은 레포 같은 디렉토리에서
  세션 여러 개가 동시에 작업하면 TODO.md 등을 서로 덮어쓸 수 있다.
  **worktree로 세션별 작업 공간을 분리**하면 각 세션이 독립 사본을 갖고 git 머지로
  합쳐진다 — 기존 worktree 작업 패턴을 그대로 쓰면 된다.

## 8. 검증 계획

1. `claude plugin validate` (또는 로컬 marketplace add)로 매니페스트 스키마 검증.
2. 로컬 설치 → 새 세션에서 "지금 적용된 페르소나가 뭐야?"로 주입 확인 (Windows에서 필수,
   가능하면 mac에서도).
3. hook 미동작 시 1차 의심 지점: hooks.json 스키마(`hooks` 래핑 여부),
   Windows에서의 `${CLAUDE_PLUGIN_ROOT}` 치환, node PATH.
4. version.yml을 올려 SYNC 워크플로우가 suh-harness 버전까지 갱신하는지 확인.
5. 기존 cassiiopeia 플러그인 설치·동작에 영향 없는지 확인 (마켓플레이스 회귀).
6. integrator 검증 (sh/ps1 양쪽):
   - 상태 표시에 suh-harness 줄이 미설치/설치(scope·버전·최신 태그) 각각 올바르게 출력.
   - cassiiopeia·suh-harness 메뉴 직전에 1줄 설명이 출력되는지 확인.
   - suh-harness install → 실제 설치 확인, 재실행 시 update/delete 메뉴로 전환 확인.
   - claude CLI 없는 환경에서 graceful skip (integrator 중단 없음).
   - skip 선택·되돌리기 모드에서 플러그인을 건드리지 않는지 확인.
   - version.yml이 harness 관련해 변경되지 않는지 확인 (저장 비대상).

## 9. 범위 제외 (Phase 2 이후)

- **Gemini CLI**: `gemini extensions install <git-url>`로 동일한 명령어 관리가 가능하지만,
  Gemini extension은 **레포당 1개**(루트 `gemini-extension.json`)라 이 레포의 기존
  cassiiopeia extension과 공존 문제를 따로 풀어야 한다(컨텍스트 병합 또는 별도 레포).
  Phase 1 완료 후 결정.
- **Codex**: 명령어 설치 메커니즘이 없다. `~/.codex/AGENTS.md` 수동 배치 또는
  스크립트 배포 — Phase 2에서 검토.
- **pi**: 이 레포가 아닌 사내 somansa-claude-code 레포 소관. 별도 작업.
- **하네스 자동 누적(세션이 PERSONA/WORKFLOW를 자동 수정)**: 하지 않는다.
  주입 파일은 읽기 전용, 개선은 사람이 커밋으로 다듬는다(원본과 동일한 정책).
