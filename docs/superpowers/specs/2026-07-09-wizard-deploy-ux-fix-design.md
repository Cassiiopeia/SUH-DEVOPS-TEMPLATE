# 마법사 배포/publish 질문 UX 개선 + 분석 카드 정렬 수정 — 설계

> **배경**: v4.2.0(#439) 배포/publish 축 도입 후, `basic` 타입에서도 "배포 방식", "publish 레지스트리", "Secret 백업" 3질문을 무조건 던져 사용자가 "내 프로젝트는 basic인데 왜 이걸 묻지?"라고 당황. 추가로 분석 카드가 CJK 폭 미계산으로 정렬이 깨짐.
> **원칙**: 질문을 없애는 게 목적이 아니라 — **묻든 안 묻든 사용자가 "왜 지금 이걸 하는지" 납득되게** 한다.
> **상태**: **구현 완료**. 3중(js `isBasicOnly`·`.sh` `_is_basic_only`·`.ps1` `Test-BasicOnly`) basic 스킵 + 맥락 문구, npx 카드 `padEndVisual` 정렬. 테스트 161/161 green, basic/spring 흐름 실측 확인.

---

## 문제 1 — basic 타입에 해당 없는 질문을 던짐 (설계 결함, 회귀)

### 원인
`askAllOptionalWorkflows`(js) / `ask_deploy_publish`(.sh) / `Ask-DeployPublish`(.ps1)가 **타입을 보지 않고 무조건 질문**한다. `.sh`엔 주석으로 "타입 비종속 질문"이라 명시돼 있다(#439에서 내가 그렇게 설계). 하지만 `basic`은 마커 파일도 없고 version.yml만 쓰는 범용 타입 — 서버 배포도 라이브러리 publish도 개념상 성립하지 않는다.

과거(#438 이전) nexus/npm-publish 질문은 **해당 폴더가 존재할 때만** 물었다(spring에 nexus/ 있을 때만). 즉 "이 타입에 그 워크플로우가 실재하나?"가 자연스러운 게이트였는데, #439에서 이 게이트를 없앴다.

### 결정
**두 갈래로 처리한다:**

1. **`basic` 단독 타입** → 배포/publish 질문을 **건너뛰고** `deploy=none`·`publish=[]`로 조용히 확정. 감지 로그·분석 카드에 "배포: 없음 (basic — 나중에 타입 변경 시 설정 가능)"으로만 표시. (basic은 애초에 서버/라이브러리 개념이 없으므로 질문 자체가 부적절.)
   - 사용자가 basic이 아닌 걸 원하면? → 확인 화면의 "수정하기 → 프로젝트 타입"에서 타입을 바꾸면 그때 배포/publish 질문이 자연스럽게 등장한다(타입 변경이 트리거).

2. **배포/publish가 의미 있는 타입**(spring·react·node·flutter·python·react-native(-expo))이 하나라도 있으면 → 질문하되 **"왜 묻는지" 맥락 한 줄**을 질문 위에 붙인다:
   ```
   🚀 이 프로젝트를 어디에 배포하나요?
      서버·호스팅에 올릴 계획이 있으면 고르고, 지금 없으면 '배포 안 함'으로 두면 됩니다.
   ```
   ```
   📦 라이브러리로 배포(publish)할 계획이 있나요?
      사내 Nexus·npmjs·GitHub Packages 중 해당되는 걸 고르세요. 없으면 그냥 Enter.
   ```

> **판단 기준(basic 스킵 게이트)**: `types`가 정확히 `["basic"]`이면 스킵. basic이 다른 타입과 섞인 멀티타입은 없다(basic은 "그 외" 폴백이라 단독으로만 존재). 안전을 위해 `types.every(t => t === "basic")` 로 판정.

### Secret 백업 질문
Secret 백업은 **배포축과 무관하고 이미 "폴더 존재 시에만" 게이트가 있다**(common/secret-backup/ 폴더 스캔). basic이어도 이 폴더는 존재하므로 계속 묻는다 — 다만 이것도 "GitHub Secret을 서버에 백업하는 워크플로우인데, 서버 없으면 불필요"라는 맥락이 이미 desc에 있어 상대적으로 덜 당황스럽다. **현행 유지**하되, basic 스킵과 함께 "서버 배포를 안 하기로 했으면 Secret 백업도 보통 불필요"라는 뉘앙스가 자연스러워진다(배포 질문을 건너뛴 흐름 안에서).
> 대안: basic이면 Secret 백업도 스킵. → **채택 보류**. Secret 백업은 basic 프로젝트(예: 정적 설정 저장소)도 쓸 수 있어 폴더 존재 게이트를 유지하는 게 맞다. 다만 문구를 "서버가 있다면"으로 조건부화한다.

## 문제 2 — 분석 카드 정렬 깨짐 (버그)

### 원인
`status-cards.js`의 `printAnalysisCard`가 `label.padEnd(10)`(JS 문자 수 기준)로 라벨을 패딩한다. 한글은 터미널에서 폭 2칸이라 `타입`(2자=4칸 폭)·`Publish`(7자=7칸)·`Secret백업`(혼합)의 실제 표시 폭이 제각각 → 값 열이 안 맞는다.

### 결정
**이미 존재하는 `visualWidth`(ansi.js, 배너 박스 정렬용 CJK 2칸 계산)를 재사용**해 라벨을 시각 폭 기준으로 패딩한다. `padEndVisual(label, targetWidth)` 헬퍼를 ansi.js에 추가(visualWidth로 부족분만큼 스페이스). status-cards의 `row()`가 이걸 쓰도록 교체. targetWidth는 가장 긴 라벨("Secret백업" = 8칸) 기준 여유 두고 12.

## 적용 범위 (3중 구현 — #439와 동일하게 전부)

| 레이어 | 문제1(basic 스킵+맥락) | 문제2(정렬) |
|--------|----------------------|------------|
| Node CLI | `options-ask.js` askAllOptionalWorkflows: types 게이트+맥락 문구, `interactive.js` 호출부 types 전달 확인 | `ansi.js` padEndVisual + `status-cards.js` row (**정렬 문제는 여기만**) |
| `.sh` | `ask_deploy_publish`/`ask_all_optional_workflows`: PROJECT_TYPES basic 게이트+맥락 | 해당 없음 — `print_project_analysis`는 라벨 뒤 고정 스페이스로 이미 정렬됨 |
| `.ps1` | `Ask-DeployPublish`: ProjectTypes basic 게이트+맥락 | 해당 없음 — `Print-ProjectAnalysis`도 고정 스페이스 정렬 |

> **실측 확인됨**: 정렬 깨짐은 npx(clack 톤 카드, `status-cards.js`의 `label.padEnd(10)`)에만 있다. `.sh`/`.ps1`은 라벨을 고정폭 스페이스로 맞춰 출력(`배포 방식        :`)하므로 무손상. 문제2 수정은 Node CLI 한정.

## 테스트
- `options-ask.test.js`: `types=["basic"]`이면 select/multiselect 호출 0회 + deploy=none·publish=[] 반환 (신규 케이스)
- `options-ask.test.js`: 비-basic 타입은 기존대로 질문 (회귀 방지)
- `banner-cards.test.js` / 신규: `padEndVisual`로 한글·영문 혼합 라벨이 같은 시각 폭으로 정렬됨을 assert
- 전체 `npm test` green + `.sh` bash -n + `.ps1` 파서

## 검증(실측)
- `npx projectops@latest`를 basic 프로젝트에서 돌려 배포/publish 질문이 안 뜨는지, 분석 카드 정렬이 맞는지 눈으로 확인
- spring 등 실타입에서는 질문이 맥락과 함께 뜨는지 확인
