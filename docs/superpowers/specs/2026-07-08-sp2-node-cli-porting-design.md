# SP2 — 마법사 Node CLI 완전 포팅 설계 (Master Spec)

작성일: 2026-07-08
상태: 진행 중 (사용자 부재로 추천안 채택하여 착수)
선행: `docs/superpowers/specs/2026-07-07-projectops-npx-migration-design.md` (SP2는 그 문서의 마지막 남은 서브프로젝트)
분석 기반: `docs/superpowers/plans/2026-07-08-sp2-structure-map.md` (구조 맵) + `docs/superpowers/plans/2026-07-08-sp2-behavior-spec.md` (동작 명세)

---

## 1. 목표

`template_integrator.sh`(5,660줄) + `template_integrator.ps1`(5,127줄) 이중 마법사를 **단일 Node.js CLI(`npx projectops`)로 완전 포팅**한다. 기능 등가 기준은 **"기존 .sh와 복사 산출물 파일 목록·내용 diff 0"**.

## 2. 확정 결정 (사용자 부재 → 추천안 채택, D1·D2는 재확인 여지)

| # | 결정 | 값 | 근거 |
|---|------|-----|------|
| D1 | 범위 | **전체 등가 포팅** (6모드 + @wizard + IDE설치) | 원 요청이 "integrator를 전부 npx로 전환". 단 단계적으로(core→commands→IDE) 검증하며 진행 |
| D2 | breaking-changes 버그 | **Node에서는 고쳐서 포팅** (TEMPLATE_VERSION 비교) | diff 0 검증은 산출물 기준이라 이 로직 수정과 무관. 기존 .sh 수정은 별건 |
| D3 | 의존성 | `@clack/prompts` `picocolors` `yaml` `execa` (전부 내부망 미러 확인됨). HTTP=Node내장 `fetch`, 인자파싱=`node:util parseArgs` | 내부망 `pip`류 불가 대비 — 5종 전부 미러 가용 실측 |
| D4 | version.yml 전략 | **전체 재생성**(현행 heredoc과 동일 템플릿 문자열) + deploy/template 블록 병합. YAML 재직렬화 금지 | 주석이 데이터 → 재생성이 diff 최소 (구조맵 §4.3-3) |
| D5 | @wizard 치환 | **라인 단위 문자열 처리** (YAML 파싱 금지) | 포맷·주석 보존이 unchanged 판정 전제 (구조맵 §4.3-2) |
| D6 | revert 모드 | **미구현 유지** (기존 .sh에 없음 — 도움말 텍스트만 허구) | 등가 포팅. 신규 기능은 별도 스펙 |
| D7 | 템플릿 자산 획득 | **git clone --depth 1 (현행 유지)** → SP2 안정화 후 codeload tarball 검토 | 초기엔 현행 동작 그대로가 diff 검증에 유리 |
| D8 | .sh/.ps1 | deprecated 배너 후 유지 → N버전 후 제거(별도 결정) | Node 미설치 사용자 보호 |

## 3. 단계 분해 (각 단계 = 독립 plan + 검증)

| 단계 | 산출물 | 검증 게이트 |
|------|--------|------------|
| **SP2-A** 스캐폴딩 + core 순수 모듈 | `src/core/{exclusions,detect,version-yml,wizard-env,breaking,options}.js` + 단위테스트 | `node:test` 그린 — 순수 로직(감지·파싱·치환·비교)이 .sh와 동일 출력 |
| **SP2-B** assets + 복사 엔진 | `src/core/assets.js` (download/copy_*), 충돌 정책 | 임시 대상 폴더에 복사 → **기존 .sh 실행 결과와 파일트리 diff 0** (full 모드, --force) |
| **SP2-C** UI + commands | `src/ui/prompts.js`, `src/commands/*`, `src/index.js`, `bin` 연결 | 비대화형(--force) 전 모드 E2E, 대화형 스모크 |
| **SP2-D** IDE skills | `src/core/ide-skills.js`, `commands/skills.js` | 각 IDE 설치/제거 실기 스모크 |
| **SP2-E** OS 매트릭스 + 컷오버 | CI 매트릭스(ubuntu/win/mac), `.sh`/`.ps1` deprecated 배너, `files` 확장(자산 번들 or clone 유지 확정) | 3 OS에서 `--mode full --force --type spring,react` diff 0 |

## 4. 모듈 경계 (구조맵 §4.1 채택)

```
bin/projectops.js         # 엔트리 (기존 스텁 → src/index 라우팅으로 확장)
src/index.js              # parseArgs + 모드 라우팅 + tempdir cleanup(finally)
src/context.js            # 공유 상태 객체 {mode,force,types,version,branch,paths:Map,includeNexus,...}
src/commands/{interactive,full,version,workflows,issues,skills}.js
src/flows/confirm.js      # detect_and_confirm_project + handle_project_edit_menu (감지·UI 조정자)
src/core/{exclusions,detect,assets,version-yml,wizard-env,breaking,options,ide-skills}.js
src/ui/prompts.js         # @clack 래핑 — ESC 시맨틱·preselect·initial-index·multi 보존, 비TTY 폴백
```

`src/core/exclusions.js`는 CLAUDE.md "3곳 동시 수정" 규칙의 **4번째 동기화 지점** — 문서화 필요.

## 5. 등가 검증 방법 (핵심)

1. **골든 픽스처**: 대표 프로젝트 6종(spring / flutter / react / python / 멀티(spring,react) / 모노레포) 빈 폴더를 만들고
2. 기존 `.sh --mode full --force --type <t>` 실행 → 결과 파일트리를 `expected/` 스냅샷
3. Node `--mode full --force --type <t>` 실행 → `actual/`
4. `diff -r expected/ actual/` == 빈 출력이 SP2-B·E 게이트
5. version.yml·워크플로우 env 치환 결과까지 바이트 동일 확인 (@wizard 기본값 경로)

## 6. 리스크

- **@wizard 멱등성**: 치환 순서(ask/auto→잔여토큰→paths-anchor)와 `_wf_is_unchanged`의 가상치환-비교가 어긋나면 diff 발생. → SP2-A에서 순수 함수로 먼저 고정하고 단위테스트로 박제.
- **interactive_menu 시맨틱**: ESC 문맥별 의미 4종. → SP2-C에서 대화형 스모크로 확인, 비대화형(--force)은 자동 검증.
- **clone vs 번들**: D7대로 초기엔 clone 유지 → 등가 검증 단순. 번들 전환은 SP2-E에서 별도 diff 재확인.

## 7. 자가 리뷰

- 스펙-코드 불일치(revert 없음·issues 있음) 반영: D6 + issues 커맨드 포함.
- 발견된 버그(breaking 1.3.14) 처리: D2 명시.
- 단계마다 독립 검증 게이트 — 한 단계 실패가 다음을 오염시키지 않음.
