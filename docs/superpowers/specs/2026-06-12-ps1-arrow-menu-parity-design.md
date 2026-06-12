# template_integrator ps1 ↔ sh 화살표 메뉴·ESC 동작 완전 동일화 설계

- 날짜: 2026-06-12
- 관련 이슈: #363 (코드 수정), #370 (사용 가이드 문서, 별도)
- 대상 파일: `template_integrator.ps1` (주 작업), `template_integrator.sh` (대칭 보정)

## 1. 목표와 범위

`template_integrator`의 선택 UI를 Windows(ps1)와 macOS/Linux(sh)에서 **로직·문구·ESC 동작까지 완전히 동일**하게 맞춘다.

- 기준은 **현재 sh**다. sh는 이미 화살표 메뉴 + ESC 분기(`--cancel-label`, stay/back) + Y/N 화살표 전환까지 구현되어 있다. ps1을 이 sh에 1:1로 맞춘다.
- 모든 선택을 화살표로 통일한다: 단일 선택·멀티 셀렉트·예/아니오·예/수정/취소.
- **ESC 의미를 호출처별로 정확히 매핑한다**: 어떤 메뉴는 "뒤로", 어떤 메뉴는 "그 자리 머묾(종료 안 함)", 어떤 메뉴는 "기존값 유지 후 취소".
- ESC를 모르는 사용자도 따라갈 수 있도록 **ESC + 메뉴 내 '뒤로' 항목을 양쪽 모두 제공**한다.

범위 밖(YAGNI): #363의 다른 항목(흐름 재배치·IDE 2단계 등 이미 반영된 것), 마우스 지원, 페이지네이션, 검색 필터.

## 2. 현재 상태 분석 (2026-06-12 기준, sh는 어제 작업 반영됨)

### sh — 이미 진화 완료

- `interactive_menu`: 화살표 메뉴(단일+멀티). `--multi`, `--preselect=csv`, **`--cancel-label=라벨`** 지원. 안내 문구에 `ESC <cancel_label>`을 동적으로 출력. 취소 시 `return 1`.
- `legacy_numeric_menu`: 비TTY/FORCE 폴백 (번호 입력).
- `choose_menu`: 디스패처. TTY면 `interactive_menu`, 아니면 `legacy_numeric_menu`.
- `ask_yes_no`: **이미 화살표 2지선**(`choose_menu`로 `예`/`아니오`). FORCE/비TTY일 때만 Y/N 키 입력 폴백.
- `ask_yes_no_edit`: 예/아니오/편집.

### sh — 호출처별 ESC 동작 (핵심)

| 호출처 | `--cancel-label` | ESC 동작 | 비고 |
|---|---|---|---|
| 타입 선택 (멀티) | `"뒤로"` | 기존값 유지 + 취소(return 1) | 빈 결과 시 기존 타입 echo |
| 확인 화면 "이 정보가 맞습니까?" | (없음) | **`stay`** — 그 자리 머묾, 종료 안 함 | 최상위라 더 뒤로 갈 곳 없음. 종료는 '아니오, 취소' 명시 선택만 |
| 수정 메뉴 "어떤 항목을…" | `"뒤로"` | **`back`** — 상위 확인 화면으로 | |
| 모드 선택 "어떤 기능을…" | (없음) | 명시적 '취소' 항목으로만 종료 | |
| 경로 선택 | (없음) | `직접 입력`으로 폴백 | |
| IDE 관리 메뉴들 | (없음) | 취소 시 변경 없음 | |

### ps1 — sh보다 뒤처져 있음

- `Invoke-ChooseMenu`: 화살표 제거됨. 항상 `Invoke-LegacyNumericMenu`(번호)로 폴백. `-CancelLabel` 파라미터 없음.
- ESC 키 개념이 없어 **'뒤로'를 메뉴 항목으로 직접 추가**해 우회 (ps1 1254 주석: "ps1은 숫자 입력 메뉴라 ESC 키가 없어 '뒤로'를 명시적 항목으로 제공한다").
- `Ask-YesNo`/`Ask-YesNoEdit`: Y/N 키 입력 (sh는 이미 화살표).
- 버전/브랜치 입력: 빈 Enter = 뒤로 (이미 sh와 대칭).

## 3. 핵심 기술 (2026-06-12 Windows 실기 검증 완료)

ps1에서 화살표가 안 되던 원인은 PowerShell 한계가 아니라 잘못된 API/판정이었다.

1. **폴백 판정**: `[Console]::IsInputRedirected`가 아니라 **RawUI 커서 제어 동작 여부**. 원격 iex(redirect=True)에서도 `RawUI.ReadKey`는 화살표 키를 정상 인식. (sh의 `/dev/tty` 우회와 같은 역할)
2. **키 입력**: `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")`. `[Console]::ReadKey`는 redirect에서 예외 → 금지.
3. **렌더링**: ANSI 상대 이동 `ESC[nA` + `ESC[2K` (sh의 `\033[1A\033[2K`와 동일). `RawUI.CursorPosition` 절대 좌표는 VT 호스트에서 무시되어 줄이 쌓임.

실행 방식별 동작(검증 완료): 파일 실행/로컬 iex/원격 iex 모두 화살표 동작, ISE·일부 비대화형만 번호 폴백.

## 4. 컴포넌트 설계 (ps1)

### ① `Invoke-ArrowMenu` (신규) — sh `interactive_menu`와 1:1 대칭

- 인터페이스: `-Multi`(스위치), `-Preselect "csv"`, `-CancelLabel "라벨"`(기본 "취소"), `-Prompt`, `-Options @(@{value;label}...)`.
- 반환: 선택 value(들). 취소(ESC) 시 약속된 취소 신호 — `$null` 반환 + 호출처가 구분.
- 단일: ↑/↓ 이동, 숫자 점프, Enter 확정, ESC 취소.
- 멀티: ↑/↓ 이동, Space 토글(`[✓]`/`[ ]`), `a` 전체토글, Enter 확정, ESC 취소, preselect 초기 체크.
- 키 입력 = `RawUI.ReadKey`, 렌더 = ANSI 상대 이동, 진입 시 VT 활성화.
- 안내 문구 (sh와 동일, cancel_label 동적):
  - 멀티: `(↑↓ 이동, Space 토글, a 전체토글, Enter 확정, ESC <취소라벨>)`
  - 단일: `(↑↓ 이동, 숫자 점프, Enter 확정, ESC <취소라벨>)`

### ② `Invoke-ChooseMenu` (수정) — sh `choose_menu` 디스패처와 대칭

- `-CancelLabel` 파라미터 추가.
- RawUI 커서 제어 가능 → `Invoke-ArrowMenu`, 불가(ISE 등) → `Invoke-LegacyNumericMenu`.
- 취소 신호를 호출처가 받을 수 있게 반환 규약 정의 (예: 취소 시 `$null`).

### ③ `Ask-YesNo` (수정) — sh `ask_yes_no`와 대칭

- 화살표 2지선(`예`/`아니오`). default가 첫 항목 = 커서 초기 위치.
- ESC 취소 → `$false`. 반환 `$true`/`$false` 유지 → 호출처 무수정.
- FORCE/RawUI 불가 시 Y/N 키 입력 폴백 (sh와 동일 구조).

### ④ `Ask-YesNoEdit` (수정) — 화살표 3지선

- `예`/`수정`/`취소`(또는 sh와 동일 라벨). 반환 `"yes"`/`"no"`/`"edit"` 유지.

### ⑤ 호출처 ESC 동작을 sh와 1:1 매핑

- **타입 선택**: `-CancelLabel "뒤로"`, ESC → 기존 타입 유지.
- **확인 화면**: cancel-label 없음, ESC → `stay`(머묾). "최상위라 종료 안 함" 안전장치 이식.
- **수정 메뉴**: `-CancelLabel "뒤로"`, ESC → `back`(상위로). **기존 '뒤로' 메뉴 항목은 유지**(ESC + 항목 둘 다).
- **모드 선택**: 명시적 '취소' 항목으로만 종료.

## 5. 컴포넌트 설계 (sh, 대칭 보정)

- ps1과 진짜 동일하게 만들기 위해 **'뒤로'가 의미 있는 메뉴(수정 메뉴 등)에 sh도 '뒤로' 명시 항목을 추가**한다. 결과적으로 양쪽 모두 "ESC + 뒤로 항목" 동작.
- sh의 ESC 분기 로직(stay/back/유지)은 이미 존재하므로 항목 라벨만 정합.

## 6. 핵심 설계 원칙 — 반환 계약 보존

키 입력 → 화살표로 **내부 구현만** 교체하고, 래퍼의 반환 계약(return value/exit code)을 유지한다. 호출처(sh 16 / ps1 17 + 선택 메뉴 ps1 10)를 최소 수정으로 회귀 위험을 없앤다. 단, ESC 동작 매핑이 필요한 호출처(확인 화면 stay, 수정 메뉴 back)는 의도적으로 분기 코드를 sh와 대칭으로 맞춘다.

## 7. 문구/안내 완전 동일화

- 기준 = sh. 메뉴 prompt·옵션 label·안내 문구·선택지 텍스트·ESC 안내(`ESC <라벨>`)를 sh에서 추출해 ps1과 1:1 대조표를 만들어 맞춘다.
- 대상: 모드 선택, 확인 화면, 타입 메뉴, 수정 메뉴, Synology 질문, IDE 설치 메뉴, 모든 예/아니오 프롬프트.
- 선택지 라벨: `예`/`아니오`(Y/N 표기 제거), 3지선 sh와 동일 라벨.
- 대조표 작성은 구현 계획에서 별도 단계(가장 품이 드는 부분).

## 8. 테스트/검증 전략 (CLAUDE.md "macOS 검증법" 반영)

- **ps1 문법**: Docker + 실제 PowerShell 파서. `mcr.microsoft.com/powershell:latest`에서 `Parser::ParseFile`로 실행 없이 구문 검사 → `PS1_PARSE_OK`. (ARM Mac은 `--platform linux/amd64`)
- **ps1 동작**: 함수 본문만 `sed`로 잘라 최소 하네스에 붙이고 입력 함수를 배열 주입 스텁으로 덮어 검증. 스크립트 전체 `Invoke-Expression` AST 로드 금지(QEMU AccessViolation).
- **sh 동작**: `expect`로 실제 TTY에 ↑/↓/Space/Enter/ESC 키 주입해 stay/back/취소 분기까지 확인. `bash -n` 문법 + 기존 회귀(`test_integrator_suggest.sh`).
- **ps1 실기**: 사용자가 Windows에서 파일 실행/원격 iex 재현 양쪽으로 단일·멀티·예아니오·ESC(stay/back) 직접 확인. 내부망에 pwsh 자동 실행 없음 → 최종 확인은 사용자.
- **대칭성**: sh와 ps1의 메뉴 prompt·옵션 label·안내 문구를 추출해 diff가 비도록 대조.

## 9. 작업 산출물

- `template_integrator.ps1`: `Invoke-ArrowMenu` 추가, `Invoke-ChooseMenu`(+`-CancelLabel`)/`Ask-YesNo`/`Ask-YesNoEdit` 수정, 호출처 ESC 동작(확인=stay·수정=back·타입=유지)을 sh와 대칭 이식. '뒤로' 항목 유지.
- `template_integrator.sh`: '뒤로'가 의미 있는 메뉴에 '뒤로' 명시 항목 추가(라벨 정합). ESC 분기 로직은 기존 유지.
- 문구 대조표 기반 ps1 문구 정정.
- 검증: Docker pwsh 파서 + 함수 하네스 + sh expect + 사용자 실기.
