# template_integrator 단일 선택 메뉴 인터랙티브 UI

## 개요

`template_integrator.sh` / `template_integrator.ps1`의 단일 선택 메뉴 13곳을 화살표 키 + 숫자 점프 + Enter 확정 + ESC 취소 방식의 인터랙티브 UI로 교체했다. 기존 `1`/`2`/`3`/`4` 숫자 입력 방식은 비TTY 환경(CI·pipe)에서 자동 fallback으로 동작해 자동화 흐름을 깨지 않는다. 외부 의존성 0 — POSIX `tput`/ANSI escape, PowerShell `[Console]` 표준 API만 사용해 stand-alone 원격 실행 구조를 그대로 유지했다.

## 변경 사항

### Bash 메뉴 컴포넌트 신설

- `template_integrator.sh`: 신규 함수 3종 추가 (`safe_read` 직후)
  - `interactive_menu` — 화살표 키/숫자 점프/Enter/ESC 처리, ANSI redraw, 색상 cyan/dim
  - `legacy_numeric_menu` — 비TTY 환경용 fallback, stdin/`/dev/tty` 모두 못 읽으면 첫 옵션 자동 선택
  - `choose_menu` — TTY 감지 분기 entry point

### Bash 메뉴 적용

- `template_integrator.sh:653-672` `show_project_type_menu` — 프로젝트 타입 선택 (spring/flutter/react/...)
- `template_integrator.sh:2287-2303` 메인 모드 선택 — full/version/workflows/issues/skills/cancel
- `template_integrator.sh:908-973` `handle_project_edit_menu` — Project Type / Version / Default Branch / done
- `template_integrator.sh:2523-2581` cassiiopeia 플러그인 관리 — update/reinstall/delete/skip
- `template_integrator.sh:2664-2710` Cursor Skills 관리 — update/install/delete/skip

### PowerShell 메뉴 컴포넌트 신설

- `template_integrator.ps1`: 신규 함수 3종 추가 (`Read-SingleKey` 직후)
  - `Invoke-InteractiveMenu` — `[Console]::ReadKey` 기반 키 입력, `[Console]::SetCursorPosition` redraw
  - `Invoke-LegacyNumericMenu` — `Read-Host` fallback, stdin redirect 시 첫 옵션
  - `Invoke-ChooseMenu` — `[Console]::IsInputRedirected` 분기

### PowerShell 메뉴 적용

- `template_integrator.ps1` `Show-ProjectTypeMenu` — 9개 프로젝트 타입
- `template_integrator.ps1` 메인 모드 선택
- `template_integrator.ps1` `Edit-ProjectInfo`
- `template_integrator.ps1` cassiiopeia 플러그인 관리
- `template_integrator.ps1` Cursor Skills 관리
- `template_integrator.ps1` `Get-ClaudeScope` — user/project
- `template_integrator.ps1` `Get-CursorScope` — user/project
- `template_integrator.ps1` `Invoke-CursorDelete` — user/project/all/cancel
- `template_integrator.ps1` `Get-CursorSkillsSrc` — remote/local

### 인코딩 호환

- `template_integrator.ps1` UTF-8 BOM 추가 — Windows PowerShell 5.1이 BOM 없는 UTF-8 파일을 시스템 코드페이지(CP949)로 읽어 한글이 깨지는 문제 해결. PS7 + `iex DownloadString` 원격 실행 경로엔 영향 없음.

### 문서

- `docs/superpowers/specs/2026-06-01-interactive-menu-design.md` — 설계 spec
- `docs/superpowers/plans/2026-06-01-interactive-menu.md` — 14개 task 구현 계획서

## 주요 구현 내용

### 키 매핑 (단일 인터페이스)

| 키 | 동작 |
|---|---|
| `↑` / `k` | 커서 위로 (wrap) |
| `↓` / `j` | 커서 아래로 (wrap) |
| `1`~`9` | 해당 번호로 즉시 점프 |
| `Enter` | 현재 행 확정 → value 반환 → exit 0 |
| `ESC` / `q` | 취소 → exit 1 (호출측 cancel 흐름) |
| `Ctrl+C` | 커서 복원(`\033[?25h`) 후 종료 |

### 입출력 계약

- **Bash**: `selected=$(choose_menu "prompt" "value1|label1" "value2|label2" ...)`
  - stdout = 선택된 value (확정 시)
  - stderr = UI 출력 (프롬프트, 옵션 목록)
  - exit 0 = 확정, exit 1 = 취소
- **PowerShell**: `$selected = Invoke-ChooseMenu -Prompt "..." -Options @(@{Value='..';Label='..'}, ...)`
  - return = Value (확정 시) / `$null` (취소 시)

### TTY 감지 + Fallback

- Bash: `[ "$TTY_AVAILABLE" = true ] && [ -t 2 ]`
- PowerShell: `(-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected)`
- 비TTY → legacy 숫자 입력 함수로 자동 위임 → 기존 자동화 흐름 그대로

### Redraw 메커니즘

- Bash: `\033[1A\033[2K` × N (N줄 위로 + 행 지우기), 매 키 입력마다 옵션 라인 N줄 redraw
- PowerShell: `[Console]::SetCursorPosition(0, $startTop)` + `PadRight(width-1)`로 이전 잔재 제거

### 색상

- 활성 조건: TTY + `NO_COLOR` 환경변수 미설정 (POSIX `NO_COLOR` 표준)
- 비활성 시: ANSI escape 미출력, `>` / `[•]` ASCII만으로 식별 가능
- 현재 행 cyan, label dim

## 주의사항

- **다중 선택은 미구현**: 본 작업은 단일 선택 메뉴 UX 개선에만 집중. `[ ]` ↔ `[✓]` 토글 다중 선택은 현 적용 지점에 케이스 0개 (YAGNI). 멀티 프로젝트 타입(#302) 구현 시 컴포넌트 확장은 별도 진행.
- **파일 덮어쓰기 Y/N 루프**(`template_integrator.sh:1520`, `template_integrator.ps1:1428`)는 교체 대상에서 제외 — 루프 안 단순 Y/N prompt로 화살표 UI 부적합.
- **PS 5.1 dot-source 호환**: 사용자의 일반 실행 경로(`iex $wc.DownloadString(...)`)는 영향 없음. `powershell.exe -File ...` 또는 dot-source 시 한글 파싱 안전성을 위해 UTF-8 BOM 추가.
- **수동 회귀 검증 필요**: 자동 검증으로는 syntax/parse만 확인 가능. 실제 TTY에서 화살표 키·ESC·`NO_COLOR=1` 동작은 Git Bash / PowerShell 5.1 / 7에서 직접 실행 확인 권장.
- **이슈 #326은 사후 등록**: 작업이 main에 머지된 후(PR #325 closed) 트래킹용으로 생성됨. 라벨은 즉시 "작업완료"로 전환 예정.
