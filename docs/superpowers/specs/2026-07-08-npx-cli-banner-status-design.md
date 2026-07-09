# npx CLI 첫 화면 + 현재 상태 표시 포팅 — 설계 (브레인스토밍 진행 중)

> **관련 이슈**: [#446](https://github.com/Cassiiopeia/projectops/issues/446) — 🚀[기능개선][CLI] npx 마법사 첫 화면 배너·현재 상태 표시 .ps1 수준으로 포팅
>
> **상태**: 브레인스토밍 **진행 중** (일부 확정, 세부 UI 시안은 미확정).
> 이 문서는 `.ps1`의 첫 화면·상태 표시 로직 조사 결과와, 지금까지 사용자와 확정한 방향을 담는다.
> 이어서 브레인스토밍할 때 이 문서를 기반으로 세부 UI(배너 시안·카드 레이아웃)를 확정한다.

---

## 배경 / 문제점

`template_integrator.ps1`(PowerShell 마법사)에는 **첫 화면 배너 + 현재 상태를 파싱해 보여주는 5개 층**의 UI가 있는데, Node로 포팅한 `npx projectops` CLI에는 이 중 **프로젝트 분석 개요의 축소판(`summarize`)만** 있고 나머지는 없거나 빈약하다.

- 현재 npx 첫 화면: `┌  projectops — 대화형 통합 마법사` (한 줄, clack 톤)
- `.ps1` 첫 화면: ╔═╗ 박스 배너 + Version/Author/Mode/Repo + 감지 로그 + 분석 카드 + IDE 상태 + breaking 박스

즉 npx CLI가 `.ps1`보다 **첫인상·정보량에서 후퇴**해 있다.

## 사용자 요구 (확정)

1. **브랜딩 변경**: `Cassiiopeia · ProjectOPS` (레포명이 SUH-DEVOPS-TEMPLATE → projectops로 바뀜). 배너 타이틀은 **`P R O J E C T O P S`를 자간 벌린 큰 타이틀**로, `Cassiiopeia`는 Author/by 라인에.
2. **npx가 `.ps1`보다 더 멋있어야 함** — 지금보다 후퇴 금지. (범위: **5개 층 전부 포팅**)
3. 현재 상태를 "잘 파싱해서 보여주는" 로직도 함께 포팅.

## 포팅 대상 — `.ps1`의 5개 층 (조사 완료)

> 출처: `template_integrator.ps1`. 라인번호는 조사 시점 기준.

### 층 0. 공통 출력 헬퍼 (L156~247) — 모든 화면의 빌딩 블록
- `Print-Header`(박스), `Print-Step`(🔅 Cyan), `Print-Info`(🔸 Blue), `Print-Success`(✨ Green), `Print-Warning`(⚠️ Yellow), `Print-Error`(💥 Red), `Print-Question`(💫 Magenta), `Print-SeparatorLine`(─×40), `Print-SectionHeader`(─×80), `Print-QuestionHeader`.
- Node 포팅: `src/ui/readline-engine.js`에 이미 ANSI 헬퍼(`paint`, 심볼)가 있으니 이 프리미티브를 확장한다.

### 층 1. 시작 배너 — `Print-Banner` (L173~188, **대화형 모드에서만**)
현재 `.ps1` 출력:
```
╔══════════════════════════════════════════════════════════════════╗
║ 🔮  ✦ S U H · D E V O P S · T E M P L A T E ✦                    ║
╚══════════════════════════════════════════════════════════════════╝
       🌙 Version : v{버전}
       🐵 Author  : Cassiiopeia
       🪐 Mode    : {모드}
       📦 Repo    : github.com/Cassiiopeia/projectops
```
- 박스 문자 `╔═╗║╚╝`(U+2550 계열), `═` 66칸. `·`=U+00B7, `✦`=U+2726.
- **변경 필요**: 타이틀을 `P R O J E C T O P S`(자간)로, Author=Cassiiopeia 유지, Repo 유지.
- npx 매핑: `readline-engine.js`의 `intro()`를 배너 렌더러로 확장. Version은 `package.json` 버전 사용.

### 층 2. 감지 로그 — 상태 수집 3종
- `Detect-ProjectTypes`(L877~948): version.yml `project_types`/`project_type` → 마커 파일 스캔 → `basic`. **이게 신규 통합 vs 업데이트를 판별.** 진행 로그 `🔅 프로젝트 타입 자동 감지 중...` → `🔸 ✓ 감지된 타입: ...`.
- `Detect-Version`(L1338~1402): package.json/build.gradle/pubspec/pyproject/git describe → `0.0.1`.
- `Detect-DefaultBranch`(L1408~1432): git symbolic-ref → `main`.
- npx 매핑: `src/core/detect-fs.js`에 감지 로직은 이미 있음. **진행 로그 출력**만 추가하면 됨.

### 층 3. 프로젝트 분석 개요 카드 — `Print-ProjectAnalysis` (L1497~1520, **정본**)
```
────────────────────────────── (─×80)
🛰️ 프로젝트 분석 결과
──────────────────────────────
       📂 Project Type(s)  : {타입 또는 csv (멀티)}
       🌙 Version          : {버전}
       🌿 Default Branch   : {브랜치}
       💫 통합 모드        : {모드 라벨}
       📦 Nexus publish    : 포함/제외   (값 있을 때만)
       🔐 Secret 백업      : 포함/제외   (값 있을 때만)
       📁 프로젝트 경로    : flutter→app, react→client  (모노레포일 때만)
```
- npx 매핑: `src/commands/interactive.js`의 `summarize()`를 이 형식으로 확장(현재는 축소판).

### 층 4. IDE Skills 현재 상태 — `Offer-IdeToolsInstall` (L4097~4161)
IDE별 설치/버전/업데이트 가능 여부를 파싱해 표시:
```
🔅 IDE Skills 현재 상태
  🔸 Claude Code : skill 설치됨 (v{ver}) ✓ 최신 | -> 업데이트 가능: v{tv} | 미설치
  🔸 Cursor      : ...
  🔸 Gemini CLI  : 설치 가능 (CLI 감지됨) | 미설치 (CLI 없음)
  🔸 Codex CLI   : ...
  🔸 PI          : ...
  🔸 PI Harness  : 활성화됨 | 비활성화
```
- 버전 태그: 설치버전==templateVersion → `✓ 최신`, 아니면 `-> 업데이트 가능: v{templateVersion}`.
- npx 매핑: `src/commands/skills.js` + `src/core/ide/*`에 어댑터·상태 수집이 이미 있음. **상태 표시 포맷**을 `.ps1` 톤으로 맞춘다.

### 층 5. 신규/업데이트 판별 + Breaking Changes 박스 — `Test-BreakingChanges` (L2128~2234)
- 업데이트일 때만(=version.yml에 통합 흔적 있을 때) 원격 `breaking-changes.json` 다운로드 → `현재버전 < ver <= 새버전` 범위 필터 → severity별 박스:
```
╔══════════════════════════════════════╗
║  ⚠️  BREAKING CHANGES (v{cur} → v{new})
╠══════════════════════════════════════╣
║  [CRITICAL] v{ver} - {title}    (빨강)
║  → {message}
║  [WARNING] v{ver} - {title}     (노랑)
║  → {message}
╚══════════════════════════════════════╝
```
- critical 있으면 진행 확인(기본 N), 거부 시 종료.
- npx 매핑: `src/core/breaking.js`에 비교 로직 이미 있음(포팅됨). **박스 렌더링 + 업데이트 판별 연결**만 추가.

## 확정된 결정 (브레인스토밍)

| 항목 | 결정 |
|------|------|
| 포팅 범위 | **5개 층 전부** |
| 목표 수준 | **`.ps1`보다 더 멋지게** (정보량은 `.ps1` 이상 유지, 후퇴 금지) |
| 배너 브랜딩 | **`P R O J E C T O P S` 자간 타이틀** + Author: Cassiiopeia + Repo: github.com/Cassiiopeia/projectops |

## 미확정 (이어서 브레인스토밍할 것)

- 배너 실제 디자인 시안 (박스 스타일·색·이모지·자간 폭) — 시각 mockup으로 비교 예정
- 분석 카드/ IDE 상태 카드의 구체 레이아웃 (표 vs 카드 vs 리스트)
- 색 팔레트 (ANSI 색 조합)
- 비대화형(`--force`) 모드에서 배너를 어디까지 보여줄지

## 구현 시 참고 (기존 자산)

- `src/ui/readline-engine.js` — ANSI/심볼 헬퍼 이미 있음 (clack 대체 완료)
- `src/core/detect-fs.js` — 타입·버전·브랜치 감지 이미 있음 (로그 출력만 추가)
- `src/commands/interactive.js` `summarize()` — 분석 개요 축소판 (확장 대상)
- `src/core/ide/*` + `src/commands/skills.js` — IDE 상태 수집 이미 있음 (표시 포맷만)
- `src/core/breaking.js` — breaking 비교 이미 있음 (박스 렌더링만)

> 핵심: **감지·수집 로직은 대부분 포팅돼 있고, 빠진 건 "예쁘게 표시하는 UI 층"이다.** 이번 작업은 주로 표시 계층 신규 구현.
