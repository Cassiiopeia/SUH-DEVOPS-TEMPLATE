# 마법사 흐름·문구 UX 전면 정비 설계

작성일: 2026-06-11
대상: `template_integrator.sh` (sh 전용 — ps1/Windows는 숫자 입력 방식 유지)

---

## 배경

passQL에 템플릿을 통합하며 마법사 UX 전반의 문제가 드러났다. 사용자 핵심 불만:
> "스킬만 설치하러 온 사람한테 프로젝트 타입·버전·Synology를 다 물어본다. 순서가 애매하고 문구가 중복되고 비직관적이다. 물 흐르듯 쓰고 싶다."

근본 원인: **모드(무엇을 할지)를 묻기 전에 프로젝트 정보를 먼저 수집·확인**한다. 그래서 모든 사용자가 모드와 무관하게 같은 질문을 받는다.

---

## 현재 흐름 (문제)

```
interactive_mode:
  1. 배너
  2. detect_and_confirm_project   ← 모드 묻기 전에 "이 정보 맞냐?"(타입/버전/브랜치) 강제
  3. download_template
  4. "어떤 기능을 통합?"          ← 모드는 여기서야 물음
  5. (full/workflows면) Synology 질문   ← 뜬금없이 튀어나옴
  execute_integration:
  6. (full/version이면) resolve_project_paths   ← 경로를 한참 뒤에 물음
```

### 3대 문제
1. **모드보다 정보 확인이 먼저** — skills 설치자에게 불필요한 타입/버전 질문.
2. **Synology 질문이 맥락 없이 등장** — "뭘 통합?" 직후 "Synology?"로 흐름이 끊김.
3. **수집·확인이 뒤섞임** — 확인 후에도 Synology·경로를 또 수집. "수집→확인→실행" 한 방향이 아님.

---

## 변경 ① 흐름 재배치 — 모드 먼저, 모드별 수집 (핵심)

### 새 흐름
```
1. 배너
2. "어떤 기능을 통합하시겠습니까?" (모드 선택)   ← 의도부터
3. download_template
4. 모드별 필요 정보만 수집:
     - skills   → 아무것도 안 물음 → 바로 IDE 설치
     - issues   → 아무것도 안 물음 → 템플릿만
     - workflows→ 타입 + Synology
     - version  → 타입/버전/브랜치 + 경로
     - full     → 타입/버전/브랜치 + Synology + 경로
5. "이 정보가 맞습니까?" — 그 모드에 해당하는 항목만 한 화면에 표시
6. 실행 (확인 후엔 추가 질문 없이 진행)
```

### 모드별 수집 매트릭스
| 모드 | 타입/버전/브랜치 | Synology | 경로(project_paths) |
|---|---|---|---|
| full | O | O | O |
| version | O | X | O |
| workflows | 타입만 | O | X |
| issues | X | X | X |
| skills | X | X | X |

### 구현 방향
- `interactive_mode`에서 `detect_and_confirm_project` 호출을 **모드 선택 이후로 이동**.
- 모드가 `skills`/`issues`면 프로젝트 정보 수집·확인·Synology·경로를 전부 건너뜀.
- Synology·경로 수집을 "이 정보가 맞습니까?" 확인 **이전**으로 모아, 확인 화면이 최종 요약이 되게 한다.

---

## 변경 ② 확인 화면 통합 — 모든 설정을 한눈에

"이 정보가 맞습니까?"에 모드별 수집 결과를 모두 표시:
```
🛰️ 통합 정보 확인
   통합 모드   : full
   프로젝트 타입: spring,flutter,react,python (멀티)
   버전        : 0.0.187
   기본 브랜치 : main
   Synology    : 포함            (full/workflows일 때만)
   프로젝트 경로: spring→server, flutter→app, react→client   (full/version일 때만)

   → 예 / 수정 / 취소  (화살표 선택)
```
- 표시 항목은 모드별 수집 매트릭스를 따른다(해당 없는 줄은 생략).
- 확인 후에는 Synology·경로를 다시 묻지 않는다(이미 위에서 수집·표시).

---

## 변경 ③ 문구·메뉴 일관성 정비 (이번 세션 누적분)

이미 적용했거나 이 정비에 포함되는 항목:
- **ask_yes_no 화살표화**: 내부를 choose_menu 2지선(예/아니오)으로. 호출부 13곳 자동 적용. value만 표시(라벨 비움)해 'yes 예' 중복 제거.
- **Y/N 안내 블록 제거**: 호출부의 `Y/y - 예… / N/n - 아니오…` 안내문 전부 제거(메뉴가 자체 안내). 질문은 ask_yes_no 프롬프트로 흡수.
- **Y/N 꼬리표 정리**: 프롬프트의 `(Y/N, 기본: Y)`, `(Y=예 / N=직접입력)` 등을 ask_yes_no가 sed로 제거.
- **3지선 화살표화**: "이 정보가 맞습니까?"(예/수정/취소)를 choose_menu로.
- **IDE 설치 2단계**: 상태 표시 → 동작 선택(설치·업데이트/제거/건너뛰기) → 대상 IDE 멀티셀렉트.
- **choose_menu redraw 보강**: 스크롤 앵커(ESC7/8 + ESC[J). VSCode/iex 환경 한계는 알려진 이슈로 잔존.
- **잔여 점검 대상**: `:1385`의 `(Y/N)` 꼬리표 등 남은 옛 문구를 일괄 확인.

### ESC / 텍스트 입력
- 텍스트 입력(새 버전 입력 등)은 ESC 대신 **빈 입력+Enter = 취소/기본값 유지**로 통일.

---

## 영향 범위
- `interactive_mode`, `execute_integration`의 호출 순서 재배치가 핵심.
- 각 모드별 동작(create_version_yml/copy_workflows/copy_issue_templates/offer_ide_tools_install)은 그대로 — 호출 순서·선행 수집만 조정.
- CLI 모드(`--mode X`)는 이미 모드가 인자로 결정되므로 정보 수집 가드만 모드별로 맞춘다.
- ps1/Windows는 범위 외(숫자 방식 유지).

---

## 테스트 계획
1. skills 모드: 배너 → 모드선택 → IDE 설치만. 타입/버전/Synology/경로 질문이 **하나도 안 뜸** 확인.
2. issues 모드: 템플릿만, 추가 질문 없음.
3. full 모드: 모드선택 → 타입/버전 → Synology → 경로 → "이 정보가 맞습니까?"에 전부 표시 → 실행.
4. version 모드: Synology 질문이 안 뜨고 경로는 뜸.
5. workflows 모드: Synology는 뜨고 경로는 안 뜸.
6. 문구: 모든 Y/N 메뉴에 옛 `Y/y -` 안내·`(Y/N)` 꼬리표가 없는지 grep 검증.
