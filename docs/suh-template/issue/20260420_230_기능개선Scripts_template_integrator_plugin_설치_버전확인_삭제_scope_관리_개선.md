# ⚙️[기능개선][Scripts] template_integrator plugin 설치/버전확인/삭제/scope 관리 개선

**라벨**: `작업전`
**담당자**: 

---

📝현재 문제점
---

- `offer_ide_tools_install` 함수에서 Claude Code 플러그인 설치 시 현재 설치 상태(버전, scope)를 전혀 확인하지 않고 무조건 재설치 시도
- 이미 설치된 경우에도 중복 설치 시도로 오류 발생 가능
- 삭제 처리 로직 없음 (`claude plugin uninstall` 미구현)
- 설치 scope가 항상 `--scope user`로 고정되어 있어 `project` scope 선택 불가
- 삭제 시 plugin data(config) 디렉토리(`~/.claude/plugins/data/`) 미정리
- Cursor는 마켓플레이스 연동이 없음에도 CLI 감지 여부로만 분기하여 설치 상태 추적 불가
- Cursor skill 설치 후 버전/경로 등 메타데이터를 저장하지 않아 이후 업데이트·삭제 관리 불가
- PowerShell 스크립트에서 `switch` 구문 및 `ConvertFrom-Json` 배열 처리 방식이 PS5와 호환되지 않음

🛠️해결 방안 / 제안 기능
---

- `claude plugin list --json` 으로 현재 설치 상태(scope, version) 확인 후 분기
  - 이미 설치된 경우: 1)업데이트 2)재설치(scope 변경) 3)삭제 4)건너뛰기 메뉴 제공
  - 미설치인 경우: 1)user scope 2)project scope 선택 후 신규 설치
- 삭제 선택 시 `claude plugin uninstall --scope {scope}` 실행 + `~/.claude/plugins/data/cassiiopeia@cassiiopeia-marketplace/` 디렉토리 함께 정리
- Cursor는 CLI 감지 대신 `.cursor/skills/cursor-skills-meta.json` 존재 여부로 설치 상태 관리
  - 설치/업데이트 시 메타데이터(버전, 설치 경로, 설치 시각, 최종 업데이트 시각) 저장
  - 업데이트 시 `installedAt` 기존 값 보존, `lastUpdated`만 갱신
  - 삭제 시 `.cursor/skills/` 폴더 전체 제거
- PS5 호환: `switch` → `if/elseif`, `@($pluginList)` 강제 배열화, `$LASTEXITCODE` 기반 결과 확인

⚙️작업 내용
---

- `template_integrator.sh` — `offer_ide_tools_install` 함수 전면 개선
  - `_ask_claude_scope()` 헬퍼 추가
  - `_do_claude_plugin_install()` 헬퍼 추가
  - `_remove_claude_plugin_data()` 헬퍼 추가
  - `_write_cursor_skills_meta()` 헬퍼 추가 (installedAt 보존 로직 포함)
  - `_remove_cursor_skills()` 헬퍼 추가
- `template_integrator.ps1` — 동일 기능 구현 (PS5 호환)
  - `Get-ClaudeScope` 함수 추가
  - `Invoke-ClaudePluginInstall` 함수 추가
  - `Remove-ClaudePluginData` 함수 추가
  - `Write-CursorSkillsMeta` 함수 추가 (installedAt 보존 로직 포함)
  - `Remove-CursorSkills` 함수 추가

🙋‍♂️담당자
---

- 백엔드: Cassiiopeia
