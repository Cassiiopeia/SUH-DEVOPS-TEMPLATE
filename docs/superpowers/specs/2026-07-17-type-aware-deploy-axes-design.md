# 타입별 deploy/publish 축 적용성 (#498)

> 상태: 설계 확정 + 구현 완료 (같은 세션). 이슈: https://github.com/Cassiiopeia/projectops/issues/498

## 문제

flutter 단독 프로젝트(elum, 실측) 통합 시 마법사가 intent → "실행물(서버/앱)을 어디에 올리나요?"(docker-ssh/vercel/none)를 그대로 노출했다.

- flutter에는 `server-deploy/` 폴더가 없어 deploy 축은 **복사 결과를 전혀 바꾸지 못한다** (docker-ssh 게이트는 `spring/server-deploy/` 전용, vercel은 `common/deploy/vercel/`).
- 질문이 오답을 유도한다: Flutter "앱"이니 intent에서 app을 고르게 되고 → deploy 질문 → 기본값 docker-ssh가 version.yml에 박힌다. 실제 배포(Play Store/TestFlight/Firebase)는 타입 워크플로우로 항상 포함되는데도.
- publish 축(nexus/npm/github-packages)도 flutter에 해당 타겟이 0개. react-native/expo 동일.
- 근본 원인: intent 우선 분기(#485)가 타입 정보를 안 쓴다. `basic` 단독만 특례(isBasicOnly)였다.

## 결정 (사용자 확정)

1. **타입별 적용 가능 타겟 선언** 방식 채택 (특례 나열·문구 수정·모바일 채널 선택 확장안 대비).
2. **적용 불가 저장값은 경고 없이 조용히 정리** — "애초에 flutter는 TestFlight/Play Store 배포라 이 축과 무관하니 보여줄 필요 자체가 없다" (경고 이모지·안내 문구 불필요).

## 설계

`src/core/options-ask.js`:

- `TYPE_DEPLOY_TARGETS` / `TYPE_PUBLISH_TARGETS` 선언 맵. 빈 배열 = 그 축이 개념상 성립하지 않는 타입.
  - 서버형(spring/react/node/python): 현행 선택지 전체 → **동작 무변경** (기존 테스트·사용자 무영향. 타입별 세분화는 후속).
  - 모바일(flutter/react-native/react-native-expo)·basic: 두 축 모두 `[]`.
  - 미선언 타입: 보수적으로 전체 허용 (질문 유지).
- `applicableTargets(types)`: 선택 타입 합집합. 'none'은 항상 허용이라 목록에서 제외하고 계산.
- `askAllOptionalWorkflows`:
  - `noAxes`(두 축 모두 빈 조합) → 구 `isBasicOnly`를 일반화. intent/deploy/publish 질문 전부 스킵, `none`/`[]`/`intent="none"` 조용히 확정.
  - 저장값 로드 직후 **조용한 정리**: 적용 불가 deploy → `none`, publish → 교집합. 로그 없음.
  - 질문 선택지·응답 검증·비대화형 기본값(`docker-ssh` → 적용 가능할 때만)을 `applicable.*` 기준으로 필터.
- `src/index.js`(비대화형): 동일 정리 규칙 + noAxes면 intent=none.
- `src/ui/prompts.js` editMenu: `axes` 파라미터 — 적용 불가 축 항목 숨김 (`axes=null`이면 기존 노출, 테스트 스텁 호환). `src/commands/interactive.js`가 `applicableTargets(types)`를 전달 (타입 수정 시 다음 메뉴부터 재반영).

## 하위호환

- 서버형 타입: 선언이 현행 선택지 전체라 질문·선택지·기본값 모두 기존과 동일.
- flutter+spring 멀티타입: spring 덕에 두 축이 살아 있어 질문 유지.
- 구 version.yml(flutter 단독 + docker-ssh): 업데이트 시 조용히 none으로 정리 — 복사 결과 동일하므로 안전.
- 비대화형 CLI 스크립트: 명시 플래그도 같은 규칙으로 정리되지만 복사 산출물은 변화 없음 (SSOT — 무의미 값 잔존 금지).

## 테스트 (test/options-ask.test.js, 5종 추가 — 총 300 통과)

- applicableTargets 타입별/합집합 산출.
- 선언-폴더 정합성: VALID_TYPES 전 타입 선언 존재, `server-deploy/` 보유 타입은 docker-ssh 선언, `publish/<target>/` 폴더는 선언 포함.
- flutter 단독 대화형 스킵 / 저장값 docker-ssh 조용한 정리(경고 문구 부재 검증) / flutter+spring 질문 유지 / 비대화형 flutter 기본값 none.
