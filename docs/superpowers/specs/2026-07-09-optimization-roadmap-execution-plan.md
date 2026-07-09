# 최적화 로드맵 실행 순위 + TDD 전체 검증 설계 (#455~#459)

> 작성 2026-07-09. 목적: 열린 이슈 실측 조사 결과를 바탕으로 **무엇을 어떤 순서로, 각 단계에서 어떻게 테스트하며** 완결할지를 확정한다.
> 사용자 확정 스코프: **로드맵 A~E 완결** + **#455 워크플로우 개편은 신중 개편 + 폴백 안전망 검증** + **npx 단일 지원 전제로 전 구간 TDD 검증**.

---

## 0. 조사 결론 — 실제 작업 대상과 현재 상태

221개 "열린" 이슈 중 **211개는 이미 `작업완료` 라벨**(닫지 않았을 뿐). 실제 미완은 **`작업전` 9 + `긴급` 1 = 10개**. 그중 **#455~#459가 하나의 로드맵**(사용자가 브레인스토밍으로 확정, 의존 순서 고정)이며 나머지(#156/#200/#345/#399/#424)는 이번 스코프 밖(§7).

**커밋 히스토리·코드 실측으로 확정한 현재 상태:**

| 이슈 | 주제 | 실측 상태 |
|---|---|---|
| **#455 (A)** | CodeRabbit 탈의존 changelog provider | provider 스크립트 3개(`commit/coderabbit/openai_compatible.sh`) **실구현 완료**, 마법사 질문·version.yml 배선 완료. **워크플로우 본체 리네임+폴백 사다리 개편만 "프로덕션 리스크로 보류"** (커밋 `6fb41f3`) |
| **#456 (B)** | changelog-deploy 스킬 브랜치·mode config화 | 미착수. version.yml `default_branch`는 이미 존재, 스킬 SKILL.md가 `develop`/`main` 하드코딩 |
| **#457 (C)** | 마법사 질문 개선 | 질문 자체는 A에서 배선 완료. **`.coderabbit.yaml` 조건부 복사 미배선**(현재 무조건 복사) + 브랜치 질문 검토가 잔여 |
| **#458 (D)** | integrator.sh/.ps1 EOF | 마지막. A·C 완전 반영 후 안전 |
| **#459 (E)** | 스킬 네임스페이스 `suh-*` 중립화 | 미착수. 레포 원본 `skills/suh-*` **25개 폴더** 리네임 |

**기반 건전성 (실행 검증):**
- `npm test` → **171개 전부 통과** ✅
- provider bash 테스트(`test_commit_provider.sh`·`test_openai_provider.sh`, `/bin/bash` 3.2) → **PASS** ✅

즉, "절반 지어진 다리의 마지막 상판" 상태다. 기반이 견고하므로 TDD로 안전하게 완결 가능하다.

---

## 1. TDD 최상위 원칙 (npx 단일 지원 전제)

`.sh`/`.ps1`은 D(#458)에서 EOF된다. 따라서 **앞으로 검증 대상은 오직 두 축**이다:

1. **npx CLI (Node.js)** — `npm test` (`node --test`). 모든 마법사 로직·복사·옵션·version.yml.
2. **워크플로우 실행 자산 (bash provider·scripts)** — `.github/scripts/test/*.sh`를 **`/bin/bash`(macOS 3.2) + BSD 도구**로 실행.

**철칙 (모든 태스크 공통):**
- **Red→Green→Refactor**: 기능 코드 전에 실패하는 테스트부터 쓴다. 기존 `test/*.test.js` 패턴(node:test + node:assert)을 그대로 따른다.
- **회귀 0**: 각 태스크 종료 시 `npm test` 전체(현재 171개)가 통과해야 한다. 숫자가 줄면 회귀.
- **provider/bash는 3.2로**: `which bash`가 brew(4+)를 가리켜도 `/bin/bash`로 명시 실행해 3.2 함정(연관배열·`grep -P`·`set -e` 종료)을 잡는다.
- **워크플로우 YAML은 로컬 파서를 GitHub 진실로 착각 금지**(CLAUDE.md 규칙): actionlint 빨간불 ≠ GitHub 실패. 운영 이력·기준 레포(RomRom) 대조로 판단.
- **커버리지 게이트**: 새로 추가/변경한 모든 공개 함수·복사 분기·옵션 분기·폴백 단계에 최소 1개 테스트를 붙인다. "테스트 없는 신규 로직" 금지.

---

## 2. 실행 순서 (의존성 기반)

로드맵의 확정 순서 `A → (B, C 병렬) → D`, `E는 병렬`를 **테스트 안전성 순으로 재배치**한다. 리스크 낮고 독립적인 것을 먼저 해 신뢰를 쌓고, 프로덕션 파이프라인을 건드리는 A 워크플로우 개편을 충분한 안전망 위에서 수행한다.

```
Phase 1  C-잔여 (#457)   .coderabbit 조건부 복사   ← 순수 npx, 리스크 최저, TDD 교과서적
Phase 2  E (#459)        스킬 네임스페이스 중립화   ← 독립, 기계적 치환, 스냅샷 테스트로 안전
Phase 3  A-잔여 (#455)   워크플로우 본체 개편       ← 프로덕션 파이프라인. 안전망 최대 (핵심)
Phase 4  B (#456)        스킬 브랜치·mode config화  ← A 확정 후. 스킬 문서+cli
Phase 5  D (#458)        integrator EOF            ← 맨 마지막. A·C 완전 반영 확인 후
Phase 6  전체 회귀 + 통합검증                       ← npm test 전량 + bash 3.2 + 통합 스모크
```

> **왜 C-잔여를 먼저?** #457의 질문 배선은 이미 끝났고 남은 건 `.coderabbit.yaml` 조건부 복사 하나다. 작고 순수 npx라 TDD 리듬을 확립하기 좋다. **왜 E를 A보다 먼저?** E는 프로덕션 파이프라인을 안 건드리고(스킬 폴더 리네임), A 워크플로우 개편이 커맨드 치환과 충돌하면 안 되므로 먼저 끝내 타이밍을 정리한다.

---

## 3. Phase별 상세 — 작업 + TDD

### Phase 1 — #457 잔여: `.coderabbit.yaml` 조건부 복사

**작업**: `codeReviewCoderabbit === false`면 `.coderabbit.yaml`을 복사하지 않는다. 현재 `copyCoderabbit`은 무조건 복사.

**TDD**:
1. (Red) `test/copy-coderabbit-util.test.js`에 케이스 추가: "codeReview=false면 복사 스킵", "true면 복사". 지금은 옵션 인자가 없으므로 실패.
2. (Green) `copyCoderabbit`에 `{ enabled }` 분기 추가 + 호출부(`index.js`/`interactive.js`)가 옵션 값을 전달.
3. (검증) 브랜치 전략 질문은 로드맵상 "검토"이므로 **필요성 확인 후 결정**(default_branch가 이미 있으니 마법사 질문 추가는 별도 판단). 안 넣으면 스펙에 "범위 밖" 명시.
- 산출: 조건부 복사 테스트 통과 + `npm test` 전량 유지.

### Phase 2 — #459: 스킬 네임스페이스 `suh-*` 중립화

**핵심 결정 필요(구현 전 확정)**: `suh-*` → `projectops:*` vs 무접두사(`projectops:issue`) + **구 커맨드 alias 유지 여부**. → §6 결정 게이트에서 확정.

**작업**: `skills/suh-*` 25개 폴더 리네임 + SKILL.md 내부 참조 갱신 + 4개 IDE 매니페스트(`.claude-plugin/`·`.cursor/`·Codex·Gemini + PI) 커맨드명 + README·CLAUDE.md·docs 일괄 치환 + 루트 `SUH` 잔재 파일.

**TDD** (문서 리네임이라 단위테스트가 아닌 **정합성 검증 테스트**):
1. 매니페스트 파서 테스트: 리네임 후 4개 IDE 매니페스트에 `suh-` 잔재가 0건인지 grep 기반 검증 스크립트(`test/rename-consistency.test.js` 신규).
2. 스킬 폴더명 ↔ 매니페스트 등록명 일치 검증(불일치 시 fail).
3. alias 유지를 택하면: 구 이름 호출이 새 스킬로 매핑되는지 확인.
- 주의: **skills/는 사용자 프로젝트로 안 감**(integrator 제외 목록). 리네임이 제외 목록·template_initializer와 안 어긋나는지 확인.

### Phase 3 — #455 잔여: 워크플로우 본체 개편 (신중, 최대 안전망)

**작업** (스펙 `2026-07-09-release-changelog-provider-design.md` §1~9 따름):
1. `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` → `PROJECT-COMMON-RELEASE-CHANGELOG.yaml` (루트 + `project-types/common/` **양쪽 동일**).
2. 본체를 `changelog.provider` 읽어 **폴백 사다리**(github-ai→openai→commit / coderabbit 선행 시 맨 앞)로 개편. 기존 4-job(`detect-and-parse`/`fallback-summary`/`update-changelog`/`merge-and-deploy`) 구조에서 생성 부분을 provider 호출로 교체, **파싱·automerge·CHANGELOG는 무수정 재사용**.
3. github-ai step(`actions/ai-inference@v1` + `permissions: models: read`).
4. 폴백 발생 시 PR 댓글 알림.
5. 리네임에 따른 참조 갱신: 스킬(#456과 겹침)·문서·`changelog-deploy`가 부르는 워크플로우명.

**TDD / 안전망 (프로덕션 파이프라인이므로 가장 두껍게)**:
1. **provider 계약 테스트**(신규 `test_provider_contract.sh`): 각 provider 산출 `pr_body.md` → `changelog_manager.py update-from-summary` → `parsed_changes` 스키마 동일 검증. github-ai만 러너 전용이라 `CHANGELOG_TEST_RESPONSE` 주입으로 오프라인 검증.
2. **폴백 사다리 단위 테스트**: 사다리 순서 결정 로직을 스크립트로 분리(`resolve_ladder.sh` 또는 본체 인라인 대신 테스트 가능한 함수)해 "coderabbit=on → [coderabbit,github-ai,openai,commit]", "off → [github-ai,openai,commit]" 검증.
3. **commit 안전망 절대완주 테스트**: 네트워크·AI 전부 실패 모사 → 그래도 `pr_body.md` 나오고 exit 0. (이미 `test_commit_provider.sh` 존재 — 폴백 경로까지 확장)
4. **YAML 무결성**: 로컬 파서는 참고만. **기준 레포(RomRom) 운영 이력과 대조**하고, 리네임 후 `git diff`로 `run:`/`uses:`/`with:` 실행 로직 무손상 자가검증(CLAUDE.md의 diff grep 패턴).
5. **회귀 방지**: 리네임 전후 `merge-and-deploy` job이 그대로인지 확인(automerge 깨지면 릴리스 전체 마비).

### Phase 4 — #456: changelog-deploy 스킬 브랜치·mode config화

**작업**:
- **`deploy_branch` 신규 도입 (게이트 4 확정)**: `default_branch`와 **별개 개념**. 마법사가 "릴리스 배포 브랜치(릴리스 PR의 head)는 무엇인가요?"를 **별도 질문**하고 version.yml에 저장. `buildVersionYml`/`parseTemplateOptions`(npx `src/core/version-yml.js`) + `options-ask.js`에 배선 + 테스트.
- SKILL.md의 `develop`/`main` 하드코딩 → version.yml에서 읽기: **head 브랜치 = `deploy_branch`(없으면 `develop` 폴백)**, base 브랜치 = `default_branch`(없으면 `main` 폴백).
- A의 `changelog.provider`를 스킬이 읽어 `commit` 모드면 노트 정책 분기.
- `changelog_cli.py`에 브랜치/mode 조회 서브커맨드 추가.

**TDD**:
- npx: `deploy_branch` 질문·저장·파싱 라운드트립 테스트(`test/version-yml.test.js`·`test/options-ask.test.js` 패턴). deploy_branch 미지정 시 `develop` 폴백 테스트.
- 스킬: `changelog_cli.py` 신규 서브커맨드는 `mcp-subcommand-rules.md` 기준(JSON `ok`/`next`) + `scripts/test/` 단위 테스트. 브랜치 읽기 실패 시 `develop→main` 폴백 테스트.
- 워크플로우 리네임(Phase 3) 반영이 스킬 문서에도 되어야 하므로 Phase 3 후 진행.

### Phase 5 — #458: integrator.sh/.ps1 EOF (게이트 3 확정 = 삭제 아님, 라우팅 유도)

**작업 (게이트 3 확정)**: **두 스크립트의 본문 로직은 삭제하지 않는다.** 진입부(`main` 호출 직전 또는 최상단)에 **"이제 `npx projectops`를 쓰세요"라는 안내를 출력하고 npx 경로로 유도**하는 라우팅 메시지만 추가한다. `.sh`·`.ps1` 양쪽 동일. CLAUDE.md의 integrator 검증 가이드(bash 3.2·Docker PowerShell)를 **npx 기준으로 대체**, README·docs 사용법을 npx로 교체.

**TDD**:
- `.sh`: `expect`(또는 stdin 주입)로 실행 시 npx 안내 문구가 뜨는지 스모크. 본문 로직 보존 확인(diff로 진입부만 변경).
- `.ps1`: Docker PowerShell 파서로 `PS1_PARSE_OK` + 안내 출력 확인.
- **npx 통합이 A·C·E를 전부 반영했는지** 통합 스모크(`--force --mode full --type spring,flutter,react,python`)가 종료코드 0으로 완주 — 이게 D의 안전 전제.

### Phase 6 — 전체 회귀 + 통합 검증

- `npm test` 전량(171 + 신규) 통과.
- `.github/scripts/test/*.sh` 전량을 `/bin/bash` 3.2로 PASS.
- npx 통합 스모크: basic·멀티타입 각각 `--force`로 완주 + 생성된 `version.yml`에 changelog/code_review 옵션 정확 기록.
- 리네임(E)·워크플로우명(A) 정합성 grep 0건.

---

## 4. 완료 정의 (Definition of Done)

각 Phase는 아래를 **모두** 만족해야 완료:
1. 신규/변경 로직에 대응 테스트 존재 (Red→Green 증거).
2. `npm test` 전량 통과 (회귀 0).
3. bash 자산 변경 시 `/bin/bash` 3.2로 PASS.
4. 이슈별 커밋 컨벤션 준수(이모지·태그 금지, `제목 : type : 설명 URL`).
5. 프로덕션 영향(Phase 3/5)은 기준 레포 대조 또는 스모크로 안전 확인.

---

## 5. 리스크와 완화

| 리스크 | 영향 | 완화 |
|---|---|---|
| 워크플로우 개편이 automerge 파이프라인 마비 | 릴리스 전체 중단 | Phase 3 안전망 5종 + `merge-and-deploy` 무수정 + 기준 레포 대조 |
| E 리네임이 구 커맨드·문서 링크 깨뜨림 | 사용자 혼란 | alias 유지 결정(§6) + 정합성 테스트 |
| github-ai rate limit·8K 토큰 | changelog 실패 | commit 안전망 자동 폴백(항상 완주) + 구현 직전 공식 문서 재확인 |
| bash 3.2/BSD 함정 재발 | macOS만 깨짐 | 모든 bash 테스트 `/bin/bash` 강제 |
| npx가 A·C·E 미반영 상태서 D 실행 | 기능 공백 | D를 맨 마지막 + 통합 스모크 게이트 |

---

## 6. 결정 게이트 — 확정됨 (2026-07-09 사용자 확정)

| # | 결정 | 확정 내용 |
|---|------|----------|
| 1 | **E 네임스페이스** | **`projectops:issue` 무접두사**. `suh-` 완전 제거. **구 커맨드 alias는 두지 않음**(즉시 전환). |
| 2 | **#457 브랜치 질문** | **추가 안 함 (범위 밖)**. `default_branch`가 이미 version.yml에 있고 감지되므로 마법사 질문을 늘리지 않는다. changelog/coderabbit 질문만 유지. |
| 3 | **#458 integrator 폐기** | **코드 로직은 삭제하지 않는다.** 두 스크립트가 실행되면 **"이제 `npx projectops`를 쓰세요"라는 라우팅 안내로 연결되도록 내부 진입부만 수정**(얇은 라우팅 메시지). 본문 로직은 보존하되 실행 경로가 npx로 유도되게 한다. README·docs·CLAUDE.md의 사용법은 npx 기준으로 갱신. |
| 4 | **B deploy 브랜치** | **`deploy_branch`를 별개 개념으로 추가한다.** `default_branch`(레포가 이미 아는 기본 브랜치)와 **배포 브랜치(릴리스 PR의 head)는 다른 개념** — 마법사가 **별도로 물어보고** version.yml에 저장한다. |

> 게이트 확정에 따른 스펙 반영:
> - **Phase 1**: 브랜치 질문 없음 확정 → `.coderabbit.yaml` 조건부 복사만.
> - **Phase 2**: alias 없이 `projectops:issue`로 즉시 리네임. 리네임 후 구 이름 잔재 0건이 정합성 테스트 통과 조건.
> - **Phase 4**: version.yml 스키마에 `metadata.template.deploy_branch`(또는 `metadata.template.options.deploy_branch`) 추가 + 마법사 질문 + `buildVersionYml`/`parseTemplateOptions` 배선 + 테스트. 스킬은 이 값을 읽어 릴리스 PR head를 결정(없으면 `develop` 폴백).
> - **Phase 5**: integrator를 **삭제하지 않고** 진입부 라우팅 메시지로 npx 유도. shim 스모크 = "실행 시 npx 안내 출력".

---

## 7. 범위 밖 (이번 스코프 제외 — 사용자 확정)

- **#345** Flutter Gemfile multi_json — 이미 `작업완료`(라벨만 미종료). 별도 정리.
- **#399** Flutter 스토어 배포 포팅(큼), **#424** npx 전환(대부분 완료·D와 중복), **#200** Copilot 지원, **#156** OAuth 마법사(스펙 미확정) — 다음 스코프.

## 8. 다음 단계

이 실행 계획 검토 후 §6 결정 게이트 확정 → `writing-plans`로 Phase별 상세 구현 계획 작성 → `executing-plans`(또는 각 이슈 브랜치에서 `implement`).
