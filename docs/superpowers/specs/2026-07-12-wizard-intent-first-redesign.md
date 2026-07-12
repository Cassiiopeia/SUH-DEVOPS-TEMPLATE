# 마법사 "의도 우선(intent-first)" 진입 구조 재설계

> 상태: **설계(초안) — 사용자 승인 대기.** 부재중 판단으로 이슈·설계까지만 작성. 구현·배포는 복귀 후 승인받는다.
> 작성 맥락: v4.2.13 배포 후, 사용자가 "질문 2개로 나누는 게 아니라 애초에 구조를 바꿔야 하는 것 아니냐"고 제기.

## 문제 (왜 지금 구조가 잘못됐나)

현재 `askAllOptionalWorkflows`는 옵션을 **낱개로 6번 순차 질문**한다: deploy → publish → code-review → changelog → release-branch → secret.

`#480~483`에서 각 질문의 문구·순서·격리를 다듬었지만, 근본 구조는 그대로다. 근본 문제:

> **마법사가 "이 프로젝트가 뭘 하는 것인지"를 안 묻고, "이 옵션 쓸래? 저 옵션 쓸래?"를 낱개로 던진다.**

그 결과 사용자가 매 질문마다 "이게 나한테 해당되나?"를 스스로 판단해야 한다. 실측 혼란(suh-project-utility, Spring 서버 앱):
- 서버 앱 개발자한테 "라이브러리(Nexus/npm) 배포할래?"를 묻는다 → "난 그거 안 하는데 왜 묻지?"
- deploy 질문 선택지에 "라이브러리/CI 전용" 같은 다른 축 용어가 섞여 혼란.
- publish를 "그냥 Enter로 스킵"하게 해 무엇을 건너뛴 건지 불명확.

문구 개선(#480~483)은 증상 완화이고, 근본은 **질문의 출발점**을 바꾸는 것이다.

## 설계 목표

1. 사용자는 "내 프로젝트가 뭔지"만 답하면, 관련 옵션만 좁혀서 물어본다.
2. 무관한 옵션은 조용히 합리적 기본값으로 확정하고, 물어보지 않는다.
3. 기존 저장 스키마(version.yml `options.*`)·비대화형 CLI·수정 메뉴 스코프(#483)와 100% 호환.
4. 되돌리기 쉬운 점진적 도입 — 기존 순차 질문을 "고급/직접 선택" 경로로 남겨 안전망 확보.

## 핵심 설계: intent(프로젝트 성격) 우선 분기

### 1) 진입 질문 하나 추가 (맨 앞)

deploy·publish 질문을 하기 전에 **한 번** 묻는다:

```
🧭 이 프로젝트는 어떤 성격인가요? (배포 관련 질문을 여기에 맞춰 좁혀드립니다)
  1) 서버/호스팅에 올려 돌리는 앱·서비스        → deploy 축만 물음
  2) 남이 가져다 쓰는 라이브러리/패키지          → publish 축만 물음
  3) 둘 다 (서버로도 돌리고 라이브러리로도 냄)    → deploy + publish 둘 다
  4) 배포 안 함 (CI·빌드 검증만)                → 둘 다 none/[]
  5) 직접 하나씩 고를게요 (기존 방식)            → 현행 순차 질문 전부
```

이 선택을 `intent` 값으로 부르자: `app` | `library` | `both` | `none` | `manual`.

### 2) intent → 옵션 축 유도 규칙

| intent | deploy 질문 | publish 질문 | 무관 축 확정값 |
|--------|------------|-------------|---------------|
| `app` | 물음 (docker-ssh/vercel/none) | **안 물음** | publish=[] |
| `library` | **안 물음** | 물음 (nexus/npm/github-packages 다중) | deploy=none |
| `both` | 물음 | 물음 | — |
| `none` | **안 물음** | **안 물음** | deploy=none, publish=[] |
| `manual` | 물음 | 물음 | (현행과 동일) |

- code-review·changelog·release-branch·secret은 intent와 무관하게 지금처럼 묻는다 (프로젝트 성격이 아니라 팀 워크플로우 선택이므로).
- **basic 단독 타입**은 지금처럼 intent 질문도 건너뛰고 none/[]로 확정 (서버·라이브러리 개념 자체가 없음). intent는 실타입일 때만 등장.

### 3) intent 저장 — 재통합 시 재질문 생략

- `version.yml`의 `metadata.template.options.intent`에 저장.
- 재통합(업데이트) 시 저장된 intent가 있으면 진입 질문을 건너뛰고 바로 유도된 축만 검토. (기존 deploy/publish 저장값 재사용 로직과 동일 패턴)
- 구 version.yml(intent 키 없음)은 `deploy`·`publish` 저장값에서 intent를 **역추론**해 채운다:
  - deploy≠none & publish=[] → `app`
  - deploy=none & publish≠[] → `library`
  - deploy≠none & publish≠[] → `both`
  - deploy=none & publish=[] → `none`
  이로써 기존 통합 레포도 재통합 시 자연스럽게 intent 체계로 편입 (하위호환).

### 4) 수정 메뉴(#483)와의 통합

- 수정 메뉴에 "프로젝트 성격(배포 유형)" 항목 추가 → 선택 시 intent 재질문 + 유도된 축 재검토.
- 기존 "배포 방식(deploy)"·"라이브러리 배포(publish)" 개별 항목은 **유지** (intent와 무관하게 특정 축만 바로 고치고 싶은 사용자용). intent를 바꾸면 축이 재유도되고, 개별 축 항목은 그 축만 세밀 조정.

## 구현 범위 (파일)

- `src/core/options-ask.js`:
  - intent 질문 블록 신설 (deploy 블록 앞).
  - intent → 축 게이팅: `willAskDeploy`/`willAskPublish`를 intent 기반으로 산출.
  - intent 저장값/역추론 로직.
  - 반환 객체에 `intent` 추가.
- `src/core/version-yml.js`: `parseTemplateOptions`에 intent 파싱, `buildVersionYml`에 intent 기록, 역추론 헬퍼.
- `src/ui/prompts.js`: 수정 메뉴에 "프로젝트 성격" 항목.
- `src/commands/interactive.js`·`src/index.js`: intent를 context로 전달·저장 배선.
- 비대화형 CLI: `--intent app|library|both|none|manual` 플래그 추가 (`src/cli/args.js`), 미지정 시 기존 `--deploy`/`--publish`로 역추론.

## 하위호환·안전

- `manual` intent = 현행 순차 질문 전부 → 기존 동작을 그대로 재현하는 탈출구. 어떤 사용자도 "옛날처럼" 할 수 있다.
- 비대화형(`--force`)에서 intent 미지정 시: `--deploy`/`--publish` 값에서 역추론(§2 3번) → 기존 CLI 스크립트 무수정 동작.
- 저장 스키마는 **추가만**(intent 키 신설), 기존 deploy/publish 키는 그대로 병기 → 구버전 도구가 읽어도 안 깨짐.

## 테스트 계획

- intent별 축 게이팅: app→publish 안 물음, library→deploy 안 물음, none→둘 다 안 물음, both/manual→둘 다.
- intent 저장/재질문 생략, 구 version.yml 역추론(4케이스).
- 수정 메뉴 "프로젝트 성격" 재질문 시 축 재유도.
- 비대화형 `--intent` 플래그 + 미지정 역추론.
- 기존 순차 질문(manual) 회귀 무손상.

## 열린 결정 (복귀 후 확정 필요)

1. 진입 질문 5지선다가 과한가? → 4개(app/library/both/manual)로 줄이고 "배포 안 함"은 deploy=none으로 흡수할지.
2. intent를 version.yml에 별도 키로 둘지, 아니면 deploy/publish에서 항상 역추론만 할지(저장 안 함). — 저장 쪽이 재질문 UX가 좋지만 스키마가 하나 늘어난다.
3. `manual` 경로를 계속 노출할지, "고급" 하위 메뉴로 숨길지.

## 이번 세션 처리 범위

- ✅ 이슈 등록 (아래) + 이 설계 문서 커밋.
- ⛔ 구현·배포는 **하지 않는다** — 진입 흐름 전면 개편이라 되돌리기 어렵고, 열린 결정 3건은 사용자 취향이 갈리는 지점이라 승인이 필요하다.
