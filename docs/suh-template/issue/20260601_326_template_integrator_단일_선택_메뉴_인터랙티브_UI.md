📝 현재 문제점
---

- `template_integrator.sh` / `template_integrator.ps1`의 단일 선택 메뉴는 `1`/`2`/`3`/`4` 숫자 입력 방식
- 옵션 목록을 출력하고 사용자가 숫자를 입력해 즉시 다음 단계로 진행 — 시각적 강조·현재 위치 표시·취소 흐름이 없음
- 사용자가 "표 형태로 보기 좋지 않고 못생겼다" 평가
- 화살표 키 네비게이션·취소(ESC)·번호 점프 등 현대적 CLI UX 부재
- 동일 패턴이 6개 이상 메뉴 지점에 반복되어 일관성도 떨어짐

🛠️ 해결 방안 / 제안 기능
---

- 두 스크립트에 **인터랙티브 메뉴 컴포넌트**를 내장해 단일 선택 메뉴를 일괄 교체한다
- 외부 의존성 0 (POSIX `tput`/ANSI, PowerShell `[Console]` 표준 API만 사용)
- 기존 stand-alone 원격 실행 구조 유지 — 사용자가 한 파일만 받아 실행하는 흐름 보존

### 키 매핑

| 키 | 동작 |
|---|---|
| `↑` / `k` | 커서 위로 이동 (wrap) |
| `↓` / `j` | 커서 아래로 이동 (wrap) |
| `1`~`9` | 해당 번호로 즉시 점프 |
| `Enter` | 현재 행 확정 |
| `ESC` / `q` | 취소 → 호출측 cancel 흐름 |
| `Ctrl+C` | 커서 복원 후 종료 |

### 시각

```
프로젝트 타입을 선택하세요 (↑↓ 이동, 숫자 점프, Enter 확정, ESC 취소):

> [•] 1) spring         Spring Boot 백엔드      ← 현재 (cyan)
  [ ] 2) flutter        Flutter 모바일 앱
  [ ] 3) react          React 웹 앱
  [ ] 4) react-native   React Native 모바일 앱
```

- 현재 행: `>` prefix + cyan
- 선택 인디케이터 `[•]`: 라디오 스타일
- `NO_COLOR=1` 환경변수 준수

### 비TTY Fallback

- TTY 감지 → 비TTY(CI/pipe)면 기존 숫자 입력(`legacy_numeric_menu`)으로 자동 분기
- 기존 자동화·`--mode`/`--type` CLI 인자 흐름 100% 보존

### 적용 범위 (단일 선택 메뉴 전부)

- 프로젝트 타입 선택 (spring/flutter/react/...)
- 통합 모드 선택 (full/version/workflows/issues/skills/cancel)
- 프로젝트 정보 편집 (Project Type / Version / Default Branch / done)
- cassiiopeia 플러그인 관리 (update/reinstall/delete/skip)
- Cursor Skills 관리 (update/install/delete/skip)
- Claude scope 선택 (user/project)
- Cursor scope 선택 (user/project)
- Cursor 삭제 scope (user/project/all/cancel)
- Cursor source 선택 (remote/local)

### 다중 선택은 본 범위에서 제외

- 본 이슈는 **단일 선택 메뉴의 UX 개선**에만 집중
- 다중 선택(`[ ]` ↔ `[✓]` 토글, 여러 항목 동시 확정)은 현 적용 지점에 케이스 0개 — YAGNI
- 멀티 프로젝트 타입(#302) 구현 시 다중 선택 컴포넌트 확장은 별도 진행

⚙️ 작업 내용
---

- `template_integrator.sh`: `interactive_menu` / `legacy_numeric_menu` / `choose_menu` 함수 신설
- `template_integrator.ps1`: `Invoke-InteractiveMenu` / `Invoke-LegacyNumericMenu` / `Invoke-ChooseMenu` 함수 신설
- 단일 선택 메뉴 13곳을 신규 컴포넌트로 일괄 교체
- PowerShell 5.1 한글 파싱 호환을 위한 UTF-8 BOM 추가
- 회귀 테스트 (Git Bash / PowerShell 5.1 / 7, 비TTY pipe, `NO_COLOR=1`, ESC/Ctrl+C 취소 흐름)
- spec/plan 문서화: `docs/superpowers/specs/2026-06-01-interactive-menu-design.md`, `docs/superpowers/plans/2026-06-01-interactive-menu.md`

🙋‍♂️ 담당자
---

- 개발: Cassiiopeia
