# #326 template_integrator 단일 선택 메뉴 인터랙티브 UI — 구현 보고서

이슈: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/326

## 무엇을 / 왜 바꿨는가

`template_integrator.sh` / `template_integrator.ps1`의 단일 선택 메뉴가 1/2/3 숫자 입력만 받아 시각적 강조·취소 흐름이 없었다. 화살표 키 네비게이션·번호 점프·ESC 취소 등 현대적 CLI UX를 13곳 메뉴에 일괄 도입했다.

## 변경 사항

### 1) 인터랙티브 메뉴 컴포넌트 신설

**`template_integrator.sh`** (POSIX `tput`/ANSI):
- `interactive_menu` — TTY 환경에서 화살표 키 + 번호 점프 + Enter/ESC
- `legacy_numeric_menu` — 비TTY(CI/pipe) fallback
- `choose_menu` — TTY 감지해 자동 분기

**`template_integrator.ps1`** (PowerShell `[Console]` 표준 API):
- `Invoke-InteractiveMenu`
- `Invoke-LegacyNumericMenu`
- `Invoke-ChooseMenu`

외부 의존성 0. stand-alone 원격 실행 구조 유지.

### 2) 키 매핑

| 키 | 동작 |
|---|---|
| `↑` / `k` | 커서 위 (wrap) |
| `↓` / `j` | 커서 아래 (wrap) |
| `1`~`9` | 즉시 점프 |
| `Enter` | 확정 |
| `ESC` / `q` | 취소 |
| `Ctrl+C` | 커서 복원 후 종료 |

### 3) 시각 디자인

- 현재 행: `>` prefix + cyan
- 라디오 인디케이터 `[•]`
- `NO_COLOR=1` 환경변수 준수

### 4) 비TTY Fallback

TTY 감지 실패 시 자동으로 `legacy_numeric_menu`로 분기. 기존 자동화·`--mode`/`--type` CLI 인자 흐름 100% 보존.

### 5) 적용 범위

단일 선택 메뉴 13곳 일괄 교체:
- 프로젝트 타입 선택
- 통합 모드 선택
- 프로젝트 정보 편집
- cassiiopeia 플러그인 관리
- Cursor Skills 관리
- Claude scope 선택 / Cursor scope 선택
- Cursor 삭제 scope / Cursor source 선택

### 6) PowerShell 5.1 한글 호환

UTF-8 BOM 추가로 한글 파싱 정상화.

## 다중 선택은 본 범위 제외

본 이슈는 단일 선택 UX 개선에만 집중. 다중 선택(`[ ]` ↔ `[✓]` 토글)은 현 적용 지점에 케이스 0개 — YAGNI. 멀티 프로젝트 타입(#302) 구현 시 별도 진행.

## 변경 파일

- `template_integrator.sh` — 신규 컴포넌트 + 13곳 일괄 교체
- `template_integrator.ps1` — 신규 컴포넌트 + 13곳 일괄 교체 + UTF-8 BOM
- spec: `docs/superpowers/specs/2026-06-01-interactive-menu-design.md`
- plan: `docs/superpowers/plans/2026-06-01-interactive-menu.md`

## 검증

- Git Bash / PowerShell 5.1 / PowerShell 7 회귀 테스트 통과
- 비TTY pipe → legacy_numeric_menu 자동 분기 확인
- `NO_COLOR=1` 환경 정상 동작
- ESC/Ctrl+C 취소 흐름 검증
