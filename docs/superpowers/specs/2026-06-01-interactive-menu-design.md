# Interactive Menu UI for template_integrator

**Date**: 2026-06-01
**Issue**: #302 멀티타입 (관련) — 본 spec은 별개 UX 개선 작업
**Scope**: `template_integrator.sh` + `template_integrator.ps1` 메뉴 입력 UX 개선

---

## 1. Motivation

현재 두 integrator 스크립트는 메뉴 입력에 `1`/`2`/`3`/`4` 숫자 입력 방식을 사용한다. 사용자가 "낭만 없고 못생겼다"고 평가. 화살표 키 네비게이션 + 시각적 강조가 있는 인터랙티브 메뉴로 교체한다.

```
프로젝트 타입을 선택하세요 (↑↓ 이동, 숫자 점프, Enter 확정, ESC 취소):

> [•] 1) spring         Spring Boot 백엔드
  [ ] 2) flutter        Flutter 모바일 앱
  [ ] 3) react          React 웹 앱
  [ ] 4) react-native   React Native 모바일 앱
```

---

## 2. Goals / Non-Goals

### Goals
- 두 스크립트의 단일 선택 메뉴 6곳을 인터랙티브 UI로 교체
- 화살표 키(↑/↓) + vi 키(k/j) + 숫자 점프(1~9) + Enter 확정 + ESC 취소
- TTY가 아니면 기존 숫자 입력 방식 fallback 유지 (CI 안정성)
- 외부 의존 0 — POSIX `tput`/ANSI escape, PowerShell `[Console]` 표준 API만 사용
- 사용자가 한 파일만 받아 실행하는 stand-alone 구조 유지

### Non-Goals
- 다중 선택(체크박스 토글) 지원 — 현재 적용 지점에 다중 선택 케이스 0개. YAGNI.
- 파일 덮어쓰기 Y/N 루프(`template_integrator.sh` L1520) 교체 — 루프 안 단순 prompt, 화살표 UI 부적합
- 별도 helper 파일 분리 — stand-alone 원격 실행 전제 깨짐

---

## 3. Architecture

### 3.1 컴포넌트

각 스크립트에 단일 함수를 내장.

- **Bash**: `interactive_menu` 함수 (`template_integrator.sh`)
- **PowerShell**: `Invoke-InteractiveMenu` 함수 (`template_integrator.ps1`)

두 함수는 동일한 입출력 계약을 따른다. 언어가 다르므로 구현은 별개.

### 3.2 입출력 계약

**Bash**:
```bash
# Signature
interactive_menu <prompt> <option1> <option2> ...
# 각 option은 "value|label" 형식 (| delimiter)

# Example
selected=$(interactive_menu \
    "프로젝트 타입을 선택하세요" \
    "spring|Spring Boot 백엔드" \
    "flutter|Flutter 모바일 앱" \
    "react|React 웹 앱")

# Output
# - stdout: 선택된 옵션의 value (확정 시)
# - stderr: 사용자 표시용 UI (옵션 목록, 키 안내)
# - exit code: 0 = 확정, 1 = 취소
```

**PowerShell**:
```powershell
# Signature
Invoke-InteractiveMenu -Prompt <string> -Options <hashtable[]> [-DefaultIndex <int>]
# 각 Option은 @{Value='..'; Label='..'} hashtable

# Example
$selected = Invoke-InteractiveMenu `
    -Prompt "프로젝트 타입을 선택하세요" `
    -Options @(
        @{Value='spring';  Label='Spring Boot 백엔드'},
        @{Value='flutter'; Label='Flutter 모바일 앱'},
        @{Value='react';   Label='React 웹 앱'}
    )

# Output
# - return: 선택된 옵션의 Value (확정 시) / $null (취소 시)
# - 화면 출력: 옵션 목록 + 키 안내
```

### 3.3 동작 흐름

```
1. TTY 감지
   - .sh:  [ -t 0 ] && [ -t 1 ]
   - .ps1: -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected
   비TTY → 기존 숫자 입력 fallback 호출

2. 초기 렌더링
   - prompt + 안내 출력
   - 옵션 N개 출력 (첫 행에 ">" + [•], 나머지 "  " + [ ])

3. 키 입력 루프
   ↑ / k         : 커서 위로 (0이면 N-1로 wrap)
   ↓ / j         : 커서 아래로 (N-1이면 0으로 wrap)
   1~9 (숫자)    : 해당 번호로 점프 (범위 밖이면 무시)
   Enter         : 현재 행 확정 → value 반환 → exit 0
   ESC / q       : 취소 → 빈 출력 → exit 1
   Ctrl+C        : 취소 (trap)
   그 외          : 무시

4. 매 키 입력마다 옵션 라인 N줄을 redraw
   - .sh: ANSI \033[<n>A (커서 위로) + \033[K (행 지우기) × N
   - .ps1: [Console]::SetCursorPosition(0, $startY + i) + 빈 문자열 padding
```

### 3.4 시각 출력

```
프로젝트 타입을 선택하세요 (↑↓ 이동, 숫자 점프, Enter 확정, ESC 취소):

> [•] 1) spring         Spring Boot 백엔드
  [ ] 2) flutter        Flutter 모바일 앱
  [ ] 3) react          React 웹 앱
  [ ] 4) react-native   React Native 모바일 앱
```

- 현재 커서 행: `>` prefix + cyan 색상
- 선택 인디케이터 `[•]`: green
- 비선택 인디케이터 `[ ]`: 기본색
- value(번호+코드명): 굵게 — `1) spring`
- label(설명): dim — `Spring Boot 백엔드`

### 3.5 색상 정책

- 색상 활성 조건: TTY + `NO_COLOR` 환경변수 미설정 (POSIX `NO_COLOR` 표준)
- 비활성 시: 모든 ANSI escape 제거, `>` / `[•]` ASCII로만 식별
- PowerShell: `$env:NO_COLOR` 동일 체크

### 3.6 키 입력 처리

**Bash — 화살표 키 escape sequence**:
```bash
IFS= read -rsn1 key
if [[ $key == $'\e' ]]; then
    IFS= read -rsn2 -t 0.001 rest
    case "$rest" in
        '[A') key=UP ;;
        '[B') key=DOWN ;;
        '')   key=ESC ;;  # ESC alone
    esac
fi
```

**PowerShell — `[Console]::ReadKey`**:
```powershell
$k = [Console]::ReadKey($true)
switch ($k.Key) {
    'UpArrow'   { ... }
    'DownArrow' { ... }
    'Enter'     { ... }
    'Escape'    { ... }
}
```

### 3.7 TTY Fallback

비TTY 감지 시 기존 동작 그대로 유지. 별도 함수 `legacy_numeric_menu` (sh) / `Invoke-LegacyNumericMenu` (ps1)로 분리. 호출 측은 단일 entry point:

```bash
choose_menu() {
    if [ -t 0 ] && [ -t 1 ]; then
        interactive_menu "$@"
    else
        legacy_numeric_menu "$@"
    fi
}
```

기존 메뉴 코드(현 1/2/3/4 입력)는 legacy 함수로 이전 — 코드 중복 최소화.

---

## 4. 적용 지점 (6곳)

| # | 용도 | template_integrator.sh | template_integrator.ps1 |
|---|------|------------------------|-------------------------|
| 1 | 프로젝트 타입 선택 | L658~681 | L574 부근 (switch $choice) |
| 2 | 통합 모드 (full/version/workflows/issues) | L2141~2164 | L2095 부근 |
| 3 | 버전 정보 편집 (project type/version/branch) | L763~828 | L702 부근 |
| 4 | 플러그인 cassiiopeia 관리 | L2437~2473 | L2375 부근 |
| 5 | 플러그인 cursor 관리 | L2542 부근 | L2460 부근 |
| 6 | 기타 scope/src/del 선택 (ps1 only) | — | L2526 / L2658 / L2687 / L2724 |

**제외**: 파일 덮어쓰기 Y/N 루프 (sh L1520, ps1 L1428) — 단순 Y/N, 화살표 UI 부적합.

---

## 5. 에러 처리

| 상황 | 동작 |
|------|------|
| 비TTY (CI/pipe) | legacy 숫자 입력 fallback 자동 호출 |
| ESC / q | 취소 — exit 1, 호출측이 cancel 흐름 처리 |
| Ctrl+C | trap으로 정리(`tput cnorm` 커서 복원) 후 exit 130 |
| 화살표 escape 깨짐 | 무시하고 루프 계속 |
| 옵션 0개 호출 | 즉시 exit 1 + stderr 에러 메시지 (방어적) |
| 터미널 폭 < 옵션 라벨 폭 | 라벨이 한 행에 안 들어가도 깨지지 않음 — redraw N줄만 보장 |

---

## 6. 테스트 (수동)

다음 조합에서 동작 확인:

| 환경 | 셸 | 기대 |
|------|----|------|
| Windows 11 | Git Bash (`template_integrator.sh`) | 화살표 UI 정상 |
| Windows 11 | PowerShell 5.1 (`template_integrator.ps1`) | 화살표 UI 정상 |
| Windows 11 | PowerShell 7 (`template_integrator.ps1`) | 화살표 UI 정상 |
| macOS | Bash 3.2 / 5.x | 화살표 UI 정상 |
| Linux | Bash 5.x | 화살표 UI 정상 |
| CI (비TTY) | `curl ... \| bash` | legacy 숫자 입력 fallback |
| `NO_COLOR=1` | 임의 셸 | 색상 제거, ASCII만 |
| 입력: ESC | 임의 셸 | 취소 → 기존 cancel 흐름 |
| 입력: Ctrl+C | 임의 셸 | 커서 복원 후 종료 |

---

## 7. 호환성

- 기존 CLI 플래그 (`--synology`, `--no-synology`, env var `MODE` 등) 영향 없음
- 비대화형 자동화 (`echo y | ./template_integrator.sh ...`) 영향 없음 — fallback 자동
- Bash 3.2 (macOS 기본) 호환 — `read -rsn1`, ANSI escape만 사용 (associative array 불필요)
- PowerShell 5.1 호환 — `[Console]::ReadKey`, `[Console]::SetCursorPosition` 5.1부터 가능

---

## 8. Out of Scope (향후)

- 다중 선택 (`[ ]` → `[✓]` 토글) — 필요 발생 시 컴포넌트 확장
- 검색/필터링 — 옵션 수가 9개 초과할 때 고려
- 페이징 — 동일
- 한국어 폭 계산 (East Asian Width) — 현 옵션 라벨이 짧아 미반영
