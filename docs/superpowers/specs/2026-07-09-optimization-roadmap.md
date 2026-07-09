# 최적화 로드맵 — CodeRabbit 탈의존 · 마법사 개선 · integrator EOF

> 작성 2026-07-09. 이 문서는 **설계가 아니라 "무엇을 어떤 순서로 왜"를 정리한 지도**다.
> 각 항목의 상세 설계는 항목별 이슈 → 별도 spec에서 진행한다. 사용자의 평소 방식(이슈부터 만들어 작업)에 맞춰 이슈 4개로 쪼갠다.

---

## 배경

npx 마법사(`npx projectops`)로 템플릿을 통합할 때 두 가지 큰 불편이 드러났다.

1. **CodeRabbit 의존성이 과함** — `AUTO-CHANGELOG-CONTROL` 워크플로우가 CodeRabbit을 1급 시민으로 하드코딩. 항상 `@coderabbitai summary`를 요청하고 10분 폴링 후에야 폴백으로 넘어간다. CodeRabbit이 느리거나 안 쓰는 레포도 무의미하게 대기하고, 모든 파싱이 CodeRabbit 마크다운 형식에 묶여 있다. → 사람들이 changelog를 **빠르게** 원할 수 있는데 CodeRabbit이 병목.
2. **마법사가 제대로 안 물어봄** — basic 단독 타입 통합 시 브랜치 전략·CodeRabbit 사용 여부 등을 묻지 않고 넘어간다.

여기에 사용자가 정한 방향 두 가지가 더해진다.

3. **integrator.sh / .ps1 EOF** — 앞으로 npx만 지원. 두 스크립트는 폐기.
4. **최대 확장성** — 릴리스 노트 생성기를 provider 방식으로 추상화해 무한 확장 가능하게.

---

## 전체 일감 지도

| # | 주제 | 이슈 | 크기 | 의존성 | 순서 |
|---|------|------|------|--------|------|
| **A** | **CodeRabbit 탈의존 — changelog provider 아키텍처** | #455 | 큼 | 없음 (토대) | 1순위 |
| **B** | **changelog-deploy 스킬 브랜치·mode config화** | #456 | 중 | A의 옵션과 연동 | 2순위 (A 후) |
| **C** | **마법사 질문 개선 (브랜치·CodeRabbit 여부 등)** | #457 | 중 | A의 옵션을 물어봐야 함 | 2순위 (A 후, B와 병렬 가능) |
| **D** | **integrator.sh/.ps1 EOF — npx 단일화** | #458 | 중 | npx가 A·C를 완전 반영해야 안전 | 3순위 (마지막) |
| **E** | **스킬 네임스페이스 리브랜딩 (suh-* 중립화)** | #459 | 중 | 독립 (커맨드 대량 치환 타이밍만 조율) | A와 함께 채택 개선 축 |

**핵심 통찰**: **A가 축**이다. `changelog` provider 옵션이 생기면 → 마법사가 그걸 물어야 하고(C) → 스킬도 읽어야 하고(B) → 다 되면 integrator 없이 npx로 완결(D). E(네임스페이스)는 A와 별개지만 **채택(adoption) 관점에서 A만큼 중요**하다 — 외부 리서치 검토(아래) 중 발굴.

**진행 순서**: `A → (B, C 병렬) → D`, E는 병렬 (타이밍만 조율)

---

## 외부 리서치 검토 (2026-07-09) — 검증 완료

다른 세션의 리서치 대화를 우리 실제 코드로 검증한 결과. **대부분 사실이었고 A(#455)를 구체화하는 데 반영**했다.

**✅ 코드로 확인된 사실:**
- `parsed_changes`가 provider 중립 계약이다 — `changelog_manager.py:285` + CHANGELOG.json 실물 확인. `raw_summary`(생성기 원본)와 `parsed_changes`(카테고리 구조체)가 분리돼 있어, 어떤 생성기든 `Summary by CodeRabbit` 형식 `pr_body.md`만 뱉으면 파이프라인이 provider를 몰라도 된다.
- Ollama·GitHub Models·OpenAI가 전부 OpenAI 호환(`/v1/chat/completions`)이라 `base_url` swap 한 갈래로 수렴 → provider를 `commit | coderabbit | openai-compatible` 3개로 정리.
- `actions/ai-inference@v1`(GitHub 공식 액션) + GitHub Models로 **API 키 없이** `permissions: models: read` 한 줄로 러너 안 AI changelog 가능 → 공개 템플릿의 기본 AI 옵션으로 적합.
- 네임스페이스가 반만 리브랜딩됨(레포=projectops, 스킬 폴더 26개는 `suh-*`), 431 태그, 레거시 shell/ps1 — 모두 사실. → E(#459) 신규 등록.

**⚠️ 단서 유지:**
- GitHub Models rate limit 수치(하루 50/150회, 8K 토큰)는 커뮤니티 추정치 → **구현 직전 공식 문서 재확인**.
- "채택 0이니 확장 말고 수렴" 방향론은 리서치의 의견 — 참고하되 이번 이슈 스코프에 억지로 넣지 않음.

---

## A. CodeRabbit 탈의존 — changelog provider 아키텍처 (1순위, 토대)

### 문제
현재 `AUTO-CHANGELOG-CONTROL.yaml`은 CodeRabbit을 하드코딩했다. 이미 `fallback-summary` job이 있어 **CodeRabbit이 없어도 완주는 하지만**, 10분을 꽉 기다린 뒤에야 폴백한다.

### 핵심 아이디어: 릴리스 노트 = 교체 가능한 provider가 만드는 산출물

릴리스 노트를 "누가 만드는가"를 provider로 추상화한다. 모든 provider는 동일 계약을 지킨다.

> **입력**: PR 번호 + 커밋 목록 → **출력**: `Summary by CodeRabbit` 고정 구조의 `pr_body.md`
> (기존 `changelog_manager.py` 파싱 로직 100% 재사용 — 출력 형식이 같으므로)

### 3계층 아키텍처

```
version.yml
└─ metadata.template.options.changelog:
     mode: commit              # ← 이 값이 provider를 고른다
     coderabbit_timeout: 600   # coderabbit 모드일 때만 의미

         ↓ 워크플로우가 읽음

AUTO-CHANGELOG-CONTROL.yaml (본체 — provider를 몰라도 됨)
└─ "generate-release-notes" step
      → mode에 맞는 provider 스크립트 하나만 호출
      → provider가 pr_body.md를 남기면 끝

         ↓ 어느 provider든 동일 출력

.github/scripts/changelog_providers/
├─ coderabbit.sh   # @coderabbitai 요청 + N분 폴링 (기존 detect 로직 이동)
├─ commit.sh       # 커밋 분석 + 정제 강화 (기존 fallback 로직 이동·개선)
└─ ai.sh           # (자리만) API 키 있으면 Claude/OpenAI 호출, 없으면 commit.sh 폴백
```

### provider별 동작 (리서치 검증 후 3갈래로 확정)

| provider | 동작 | 실행 위치 | 대기 |
|----------|------|-----------|------|
| `commit` | 커밋 분석만으로 즉시 릴리스 노트 → 바로 changelog·automerge (결정론 베이스라인·최후 보루) | 러너(bash) | **0초** |
| `coderabbit` | CodeRabbit 요청 → 폴링 → timeout 시 자동 `commit` 폴백 | 외부 봇 | 최대 timeout |
| `openai-compatible` | 러너 안에서 LLM 직접 호출(GitHub Models/Ollama/OpenAI/OpenRouter를 `base_url` swap 한 갈래로) → 실패 시 `commit` 폴백 | 러너 | API 응답 |

> `openai-compatible` + `preset: github-models`이면 `actions/ai-inference@v1`로 API 키 없이(`models: read`) 동작 — 공개 템플릿 기본 AI 옵션. `preset: ollama|custom`이면 `base_url`+Bearer로 외부 서버(예: `ai.suhsaechan.kr/v1`) 호출.

**폴백 사슬**: `ai → commit`, `coderabbit → commit`. **`commit`은 AI·외부봇 없이 bash만으로 항상 성공하는 최후 보루** → 워크플로우가 절대 멈추지 않는다.

### commit provider 품질 (AI 없이 가능한 최선)
- 커밋 prefix로 분류 (feat/fix/refactor/docs/etc)
- **정제 강화**: 이슈번호·GitHub URL·파일 경로·기술 prefix 제거, 중복 항목 병합
- 각 항목 끝에 "더 정확한 노트는 `/suh-changelog-deploy` 스킬로" 안내 (로컬 Claude가 예쁜 노트 담당)

### 왜 확장적인가
- 새 provider 추가 = **파일 하나** + mode 값 하나. 워크플로우 본체·파싱 로직 무수정.
- `commit`이 최후 보루라 어떤 provider가 실패해도 파이프라인 완주.
- version.yml 옵션이라 레포마다 다른 mode 사용 가능.

### AI provider 방향 (미래, 지금은 자리만)
- 워크플로우는 GitHub 러너에서 도므로 **사용자 PC의 local AI에는 못 닿는다.**
- 따라서 워크플로우 provider는 API 방식(Claude/OpenAI, secret 키)만 가능.
- local AI로 예쁜 노트를 원하면 그건 이미 로컬 Claude를 쓰는 `suh-changelog-deploy` 스킬의 몫 → 역할 분리.

### 연관 파일
- `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` (본체)
- `.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` (원본 — **양쪽 동일 유지**)
- `.github/scripts/changelog_manager.py` (파싱 재사용, 무수정 목표)
- `.github/scripts/changelog_providers/` (신규)
- `version.yml` (options.changelog 추가)

---

## B. changelog-deploy 스킬 브랜치·mode config화 (2순위)

### 문제
`skills/suh-changelog-deploy/SKILL.md`가 `develop`→`main`을 하드코딩. deploy 브랜치·default 브랜치가 다른 레포에서 안 맞는다. A에서 생긴 `changelog.mode`도 스킬이 알아야 자동/수동 흐름을 맞출 수 있다.

### 방향 (미확정 — B 이슈에서 상세 설계)
- 브랜치 정보의 SSOT는 **version.yml**(`metadata.template.default_branch` 이미 존재) + deploy 브랜치 개념 추가 검토.
- 하드코딩 대신 스킬이 version.yml / config.json에서 읽는다.
- `changelog.mode == commit`이면 스킬은 릴리스 노트를 굳이 안 만들고 워크플로우에 맡길지, 아니면 여전히 예쁜 노트를 만들지 정책 결정 필요.

---

## C. 마법사 질문 개선 (2순위, B와 병렬 가능)

### 문제
basic 단독 타입 통합 시 브랜치 전략·CodeRabbit 사용 여부를 안 물어보고 넘어간다.

### 방향 (미확정 — C 이슈에서 상세 설계)
- A에서 생긴 `changelog.mode`를 마법사가 물어본다 (CodeRabbit 쓸지 / 빠른 commit 모드로 갈지).
- CodeRabbit 안 쓰기로 하면 `.coderabbit.yaml`도 조건부로만 복사.
- 브랜치 전략(develop→main 쓸지) 질문도 검토.

---

## D. integrator.sh / .ps1 EOF (3순위, 마지막)

### 문제·방향
npx만 지원하기로 확정. 두 스크립트를 폐기한다. 단, **npx가 A·C를 완전히 반영한 뒤에야** 안전하게 폐기 가능.
- 기존 spec 참고: `2026-07-07-projectops-npx-migration-design.md`, `2026-07-08-projectops-oss-design.md`.
- 폐기 방식(즉시 삭제 vs deprecation 안내 후 삭제)은 D 이슈에서 결정.

---

## 다음 액션

1. 이 로드맵을 사용자가 검토.
2. A~D를 GitHub 이슈 4개로 등록 (의존성·순서 명시). → `/suh-issue` 스킬 사용.
3. 1순위 **A**부터 상세 설계(별도 spec) → 구현.
