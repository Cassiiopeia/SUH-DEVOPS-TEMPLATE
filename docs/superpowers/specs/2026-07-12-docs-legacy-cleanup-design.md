# docs 레거시 정리 및 신기능 문서화 설계

- 날짜: 2026-07-12
- 브랜치: develop
- 배경: v4.2~v4.3에 걸친 대규모 전환(projectops 리브랜딩 #459, npx CLI 단일화 #424/#458, provider 사다리 #455, deploy/publish 2축 #439, 레거시 워크플로우 마이그레이션 #470, pro-issue→pro-github 통합 #467) 이후 `docs/`가 부분적으로만 갱신됨. 전수 감사 결과를 바탕으로 레거시 잔재를 수정하고 신기능 문서 공백을 메운다.

---

## 1. 감사 결과 요약

### 🔴 레거시 잔재 (수정 대상)

| # | 파일 | 위치 | 문제 | 조치 |
|---|------|------|------|------|
| 1 | `docs/SKILLS.md` | 10행, 25행 | `/projectops:xxx` 호출 표기 — #459에서 `/pro-<skill>`로 통일했으나 이 2줄 누락 | `/pro-<skill>` 표기로 수정 |
| 2 | `docs/WORKFLOW-COMMENT-GUIDELINES.md` | 281행, 366행 | `SUH-LAB-BUILD-TRIGGER` — 현행 파일명은 `PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER` | `PROJECTOPS-APP-BUILD-TRIGGER`로 수정 |
| 3 | `docs/CHANGELOG-AUTOMATION.md` | 문서 전체 | CodeRabbit 단일 전제로 기술. provider 사다리(#455) 부재, 33행 구 명칭 계열 "CHANGELOG-CONTROL" 표기 | 전면 개정 (아래 §2) |

### 🟡 신기능 문서 공백 (신규 작성 대상)

| 기능 | 도입 이슈 | 현재 문서 상태 | 조치 |
|------|----------|--------------|------|
| changelog provider 사다리 (github-ai 등 5종) | #455 | 없음 (CLAUDE.md에만) | CHANGELOG-AUTOMATION.md 개정에 흡수 |
| deploy/publish 2축 (`--deploy`/`--publish`) | #439 | 없음 | NPX-WIZARD.md 신규 (§3) |
| Vercel 배포 타겟 / Secret 백업 opt-in | #439 | 없음 / 단편 언급 | NPX-WIZARD.md에 포함 |
| node npm publish / github-packages publish | #438 등 | 없음 | NPX-WIZARD.md publish 축에 포함 |
| 레거시 워크플로우 자동 마이그레이션 (registry.js) | #470 | 없음 | NPX-WIZARD.md에 사용자+기여자 가이드 (§4) |
| 모노레포 `project_paths` | (이슈 번호는 구현 시 git log로 확인) | 없음 | VERSION-CONTROL.md에 절 추가 (§5) |

### ✅ 보존 계약 — 절대 수정 금지

- `"Guide by SUH-LAB"` 댓글 마커 전부 — 외부 봇 서명 **매칭 계약**으로 의도적 보존 (커밋 25b798e). `FLUTTER-TEST-BUILD-TRIGGER.md`·`PR-PREVIEW.md`·`ISSUE-AUTOMATION.md`의 해당 표기는 현행 동작 그대로다.
- `version_manager.sh` 표기 — .sh는 현행 지원 shim (#448). 단, "실 로직은 .py" 각주가 없는 곳엔 보강 가능(선택).
- `docs/TEMPLATE-INTEGRATOR.md` — 의도된 EOF 안내문 (#458). EOF 안내 성격 유지 (§6의 NPX-WIZARD.md 링크 1줄 추가만 예외).
- `WORKFLOW-COMMENT-GUIDELINES.md`의 "next 타입은 v4.1.0에서 흡수" — 올바른 이력 서술.
- `PROJECT-COMMON-SUH-ISSUE-HELPER-*` 워크플로우명 — 현행 파일명 그대로 (리네임 안 됨).

### ⚠️ 범위 밖 (별도 이슈로 기록만)

- `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml`·`PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml`이 `project-types/common/`에만 있고 `.github/workflows/` 루트에 없음 — CLAUDE.md "공통 워크플로우 두 곳 동일 유지" 규칙과의 정합 여부는 코드 측 확인 사항. 이번 docs 작업에서는 손대지 않는다.

---

## 2. `docs/CHANGELOG-AUTOMATION.md` 전면 개정

구조를 provider 사다리 중심으로 재작성한다.

1. **개요** — main PR(develop→main) 시 `PROJECT-COMMON-RELEASE-CHANGELOG.yaml`이 버전 확정 + 체인지로그 생성 + automerge. (구 명칭 AUTO-CHANGELOG-CONTROL → RELEASE-CHANGELOG 리네임 이력 1줄 명시)
2. **provider 사다리** — `version.yml`의 `options.changelog.provider` 값에 따라:
   - `coderabbit` (미설정 시 기본 — 기존 동작 보존): CodeRabbit Summary 폴링 → 무응답 시 사다리 폴백
   - `github-ai` (신규 설치 기본): GitHub Models API, `permissions: models: read` + GITHUB_TOKEN만으로 동작
   - `openai`/`gemini`/`claude`/`ollama`: OpenAI 호환, `MODEL_API_KEY` secret 필요 (ollama는 `changelog.base_url`)
   - `commit`: 커밋 분석 — AI·네트워크 무의존 최후 안전망
   - 폴백 순서: **선택 provider → github_ai.py → commit.py**, 폴백 발생 시 PR 댓글 알림
3. **provider별 요구사항 표** — secret/권한/네트워크 요구를 한 표로.
4. **CodeRabbit 연동** — 기존 절을 "coderabbit provider 사용 시"로 격하·유지.
5. **스크립트 레퍼런스** — `changelog_manager.py` 서브커맨드, `changelog_providers/ladder.py`, 테스트 실행법.

정확성 근거: 작성 시 `.github/scripts/changelog_providers/` 실물과 `PROJECT-COMMON-RELEASE-CHANGELOG.yaml`을 읽고 대조한다 (CLAUDE.md 요약을 그대로 베끼지 않는다).

## 3. `docs/NPX-WIZARD.md` 신규 작성

npx 마법사가 진입점인 기능을 한 문서로 통합한다.

1. **개요** — `npx projectops` 대화형/비대화형, 모드(full/version/workflows/issues/skills), Node 20.12+ 요구.
2. **deploy/publish 2축** —
   - deploy(택1): `docker-ssh`(기본)·`vercel`·`none` / publish(0..n): `nexus`·`npm`·`github-packages`
   - version.yml 저장 위치: `metadata.template.options.deploy` / `options.publish` 배열
   - 비대화형 플래그: `--deploy ...` / `--publish a,b` (csv)
   - `basic` 단독 타입은 질문 스킵 (`deploy=none`·`publish=[]` 조용히 확정)
   - deprecated 구 플래그: `--nexus`/`--npm-publish` → 신 축 해석 + 경고, 구 version.yml 키 자동 변환
   - 축별 포함되는 워크플로우 매핑 표 (server-deploy/ 게이트, `<type>/publish/<target>/`, common/deploy/vercel/, secret-backup)
3. **레거시 자동 마이그레이션** — §4 내용.
4. **구 integrator에서 오는 사용자** — TEMPLATE-INTEGRATOR.md 링크.

## 4. 레거시 마이그레이션 가이드라인 (NPX-WIZARD.md 내 섹션)

사용자 관점과 기여자 관점을 모두 담는다 (사용자 강조 요구사항).

**사용자 관점:**
- 마법사 full/workflows 모드가 통합 시 구세대 워크플로우를 자동 감지
- safe 티어: 순수 리네임 잔재 — 자동 `.bak` 무해화 (비대화형은 자동, 대화형은 확인 1회)
- confirm 티어: 배포 파이프라인일 수 있는 것 — 자동 조치 없이 안내만
- 커스텀 워크플로우 불가침·멱등 보장, `.bak` 복원 방법

**기여자 관점 (가이드라인):**
- 워크플로우 리네임/삭제 시 구 이름을 `src/core/migrations/registry.js`에 반드시 등록 (단일 레지스트리 원칙)
- tier 판단 기준: safe(공존 시 중복 실행 실해) vs confirm(배포 파이프라인 가능성)
- `test/migrations.test.js`가 현행 배포 세트와의 충돌(살아있는 워크플로우 오살)을 자동 검증
- 근거: 실물 `src/core/migrations/registry.js`를 읽고 현재 등록된 항목 표로 정리

## 5. `docs/VERSION-CONTROL.md` 보강

- **모노레포 `project_paths`** 절 추가: 타입→상대경로 맵, 마커 파일 자동 감지, 키 없으면 루트 기준(기존 동작 유지), 비대화형 `--paths "flutter=app,react=client"`.
- `version_manager.sh` 절에 ".py가 실 로직, .sh는 위임 shim (#448) — Windows는 `python version_manager.py` 직접 실행" 각주 보강.

## 6. 문서 내비게이션 갱신

- `docs/` 목록을 노출하는 곳(README의 docs 링크 목록 등)에 `NPX-WIZARD.md` 추가. (README에 docs 색인이 없으면 생략)
- `TEMPLATE-INTEGRATOR.md`에서 NPX-WIZARD.md로 상세 링크 1줄 추가.

## 7. 파일 배치 규칙 확인

- `docs/`는 이미 템플릿 초기화 삭제 목록·npx 복사 제외 목록에 폴더째 포함 → `template_initializer.py`/`exclusions.js` 수정 **불필요**.

## 8. 검증 계획

1. 레거시 키워드 재스캔 0건 확인: `projectops:` 호출 표기(스킬 호출 맥락), `SUH-LAB-BUILD-TRIGGER`, `CHANGELOG-CONTROL`(RELEASE- 접두 없는 단독 표기) — 단 보존 계약("Guide by SUH-LAB" 등)은 제외 패턴으로 명시.
2. 신규/개정 문서의 파일명·플래그·키 이름이 실물(워크플로우 yaml·registry.js·providers .py·npx src)과 일치하는지 grep 대조.
3. `npm test` (정합성 테스트 포함) 통과.

## 9. 작업 순서

1. 소규모 레거시 수정 2건 (SKILLS.md, WORKFLOW-COMMENT-GUIDELINES.md)
2. CHANGELOG-AUTOMATION.md 전면 개정 (실물 스크립트/워크플로우 대조)
3. NPX-WIZARD.md 신규 (실물 npx src·registry.js 대조)
4. VERSION-CONTROL.md 보강
5. 내비게이션 링크 + 검증 (§8)
