# Release-Changelog Provider 시스템 설계 (이슈 #455)

> 작성 2026-07-09. 사용자와 브레인스토밍으로 한 스텝씩 합의한 최종 설계.
> CodeRabbit 하드 커플링을 제거하고, GitHub AI를 기본으로 하는 provider 폴백 사다리를 만든다.

## 목표

- **GitHub AI(GitHub Models)를 changelog 생성 기본값**으로 (최신 트렌드 = AI, 게다가 키 없이 `models: read` 한 줄로 동작).
- 어떤 provider가 실패해도 **커밋 분석(안전망)으로 자동 폴백**해 릴리스 파이프라인이 항상 완주.
- CodeRabbit은 "여러 옵션 중 하나"로 강등(제거는 아님).
- 설정은 version.yml(비민감 선택값) / workflow.yaml(실행) / GitHub Secret(사용자 직접 등록 키) 3층으로 분리.

## 1. 워크플로우 파일명 변경

`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` → **`PROJECT-COMMON-RELEASE-CHANGELOG.yaml`**

- `PROJECT-COMMON-` 접두사는 네이밍 컨벤션이라 유지.
- `AUTO-...-CONTROL`의 모호한 "CONTROL"을 제거하고 "이 워크플로우가 릴리스+changelog를 처리한다"는 의미를 직관적으로.
- `.github/workflows/` 루트 + `project-types/common/` 원본 **양쪽 동일 리네임** (공통 워크플로우 동기화 규칙).

## 2. 마법사의 두 독립 질문

CodeRabbit의 **코드 리뷰**와 **changelog 생성**은 완전히 다른 기능이므로 마법사가 **두 번** 묻는다.

- **질문 ①**: "CodeRabbit AI 코드 리뷰를 쓸까요?" — PR 코드 리뷰용. changelog와 무관.
- **질문 ②**: "changelog(릴리스 노트)는 뭘로 만들까요?" — 생성기 선택. **기본 커서 = GitHub AI**.

두 질문은 독립이라 "리뷰는 켜고 changelog는 GitHub AI" 같은 조합이 자유롭게 가능하다.

## 3. Changelog 생성기 폴백 사다리

CodeRabbit을 changelog 생성기로 고르는지에 따라 사다리가 갈린다.

```
[기본] CodeRabbit 안 씀:
   github-ai  →  openai-compatible  →  commit(안전망)

[선택] CodeRabbit 씀:
   coderabbit  →  github-ai  →  openai-compatible  →  commit(안전망)
```

- 각 단계 실패(응답 없음·rate limit·에러·CodeRabbit이 default 브랜치 아니라 `@coderabbitai summary` 무응답 등) → **다음 단계로 자동 폴백**.
- `commit`은 AI·네트워크 무의존(로컬 git log만)이라 **항상 완주하는 최후 보루**.
- **폴백 발생 시 PR 댓글/로그로 "○○ 실패 → △△로 전환" 알림** (투명성). CodeRabbit이 코드리뷰 댓글을 다는 건 그것대로 두고, 여기서 남기는 건 "생성기 전환" 알림.

## 4. 설정 3층 분리 (핵심 원칙)

| 저장소 | 담는 것 | 예 |
|--------|---------|-----|
| **version.yml** | 마법사가 저장하는 **비민감 선택값** | `changelog.provider: github-ai` |
| **workflow.yaml** | version.yml을 읽어 **실제 실행**. secret은 `${{ secrets.MODEL_API_KEY }}`로 참조만. base_url·모델·secret 이름을 provider별 preset으로 내부 처리 | `permissions: models: read` |
| **GitHub Secret** | API 키 **값** — **사용자가 레포 Settings에 직접 등록** (마법사는 절대 값을 받지 않음) | `MODEL_API_KEY = sk-...` |

- **GitHub AI**: `models: read`만 있으면 됨 → secret 불필요, 깔면 즉시 작동.
- **OpenAI/Ollama 등**: 마법사가 "레포 Settings > Secrets에 `MODEL_API_KEY`를 직접 등록하세요"라고 **안내만** 한다.

## 5. version.yml 스키마 (최종 — 단순화)

```yaml
metadata:
  template:
    options:
      code_review:
        coderabbit: true          # 질문① — PR 코드 리뷰 사용 여부
      changelog:
        provider: github-ai       # 질문② — github-ai | coderabbit | openai
                                  #  | gemini | claude | ollama | commit
        base_url: ""              # ollama/custom 일 때만 채움 (나머진 빈 값 → workflow가 preset 사용)
```

**단순화 결정 (사용자 확정)**:
- `model` 키 없음 — provider별 무난한 **기본 모델을 workflow가 자동 지정**. 커스텀 모델 선택은 너무 깊어 지금은 안 함(Ollama 서버 모델 선택은 향후 확장).
- `api_key_secret` 키 없음 — secret 이름(`MODEL_API_KEY`)은 workflow.yaml에 고정. version.yml에 중복 저장 안 함. 마법사는 그 고정 이름으로 등록하라고 가이드만.
- `base_url`은 provider가 정해지면 대부분 자동(openai/gemini/claude는 고정 엔드포인트). **ollama/custom일 때만** 사용자 지정(자기 서버라서).

## 6. Provider 무관 계약 (기존 코드 재사용)

어떤 provider든 최종 산출은 `Summary by CodeRabbit` 고정 구조의 `pr_body.md`. → 기존 `changelog_manager.py`의 `update-from-summary` 파싱, CHANGELOG.json 스키마(`parsed_changes`), automerge가 **provider를 몰라도 그대로 동작**. 파싱 로직 무수정 재사용.

`parse_method`에 출처 기록: `github-ai` / `coderabbit` / `openai:ollama` / `commit` 등.

고정 구조:
```
<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

## Summary by CodeRabbit

## 릴리스 노트

* **새 기능**
  * ...
* **버그 수정**
  * ...
(개선/문서/기타 — 있는 것만)

<!-- end of auto-generated comment: release notes by coderabbit.ai -->
```

## 7. 컴포넌트 구조

```
.github/scripts/changelog_providers/
├─ commit.sh              # 커밋 분석 (안전망, 기존 fallback-summary 로직 이동 + 정제 강화)
├─ coderabbit.sh          # @coderabbitai 요청 + 폴링 (기존 detect 로직 이동)
├─ openai_compatible.sh   # openai/gemini/claude/ollama — base_url preset swap + Bearer
└─ (github-ai)            # actions/ai-inference@v1 step (스크립트 아닌 워크플로우 step)
```

워크플로우 본체(`PROJECT-COMMON-RELEASE-CHANGELOG.yaml`)는 `changelog.provider`를 읽어 사다리 순서대로 시도하고, 실패 시 다음 단계로 폴백. 최종 산출 `pr_body.md`를 기존 changelog 파이프라인에 넘긴다.

## 8. commit 안전망 품질

- prefix 분류(feat/fix/refactor/docs/etc) + 정제: 이슈번호·URL·파일 경로·기술 prefix 제거, 중복 병합.
- 검토: GitHub `releases/generate-notes` API 활용(AI 0%, 기여자·PR 자동 정리).

## 에러 처리 요약

- 사다리 각 단계 실패 → 다음으로 폴백 → 최후 `commit`은 절대 실패 안 함.
- 폴백 발생 시 PR 댓글/로그 알림.
- GitHub AI rate limit·8K 입력 토큰 제약 → mini 모델 기본 + prefix 필터. **구현 직전 공식 문서에서 현재 한도 재확인.**

## 테스트

- `commit.sh`: 샘플 커밋 로그 → 기대 pr_body.md 구조 (bash, 오프라인).
- 각 provider 산출 pr_body.md → `changelog_manager.py update-from-summary` → `parsed_changes` 동일 스키마 검증.
- `commit` 모드로 릴리스 PR이 10분 대기 없이 즉시 automerge 완주 (기준 레포).
- 폴백: coderabbit 무응답 상황 → github-ai로 전환되고 PR 댓글 알림 뜨는지.

## 범위 밖 (다른 이슈)

- 스킬이 브랜치·provider를 읽는 부분 → B(#456)
- 마법사 질문 UI 상세 → C(#457) (이 spec은 "무엇을 묻는지"만 정의)
- Ollama 모델 선택지 → 향후 확장
- 네임스페이스 리브랜딩 → #459

## 다음 단계

이 spec 검토 후 `writing-plans`로 구현 계획 작성.
