# SP2 — template_integrator.sh 구조 맵 (Node.js CLI 포팅용)

> 작성일: 2026-07-08
> 대상: `template_integrator.sh` (5,660줄, bash 3.2 호환)
> 목적: projectops 마법사의 Node.js CLI 포팅(SP2)을 위한 전체 함수 인벤토리·콜 체인·전역 상태·모듈 경계 제안.
> 방법: 파일 전체 정독 (1~5,660행). 함수는 **최상위 130개 + `interactive_menu` 내부 중첩 2개 = 132개**.

---

## 0. 최상위 구조 요약

```
1~74      : 헤더 주석, set -e, SSL 환경변수 unset
76~121    : STDIN_MODE/TTY_AVAILABLE 초기값, detect_terminal, TEMP_DIR + cleanup trap(EXIT)
102~137   : 색상(전부 빈 문자열), TEMPLATE_REPO/RAW_URL/상수(readonly)
139~732   : 출력 유틸 + 대화형 메뉴/입력 (interactive_menu / legacy_numeric_menu / choose_menu / ask_*)
735~825   : show_help
827~920   : 전역 기본값 + **인자 파싱 (top-level while-case, 함수 아님)**
923~2061  : 프로젝트 감지 (타입/버전/브랜치/경로) + 확인·수정 메뉴
2064~2141 : download_template
2144~2503 : version.yml 생성/README 섹션/옵션 read·save/버전 비교
2505~2731 : breaking changes + opt-in 워크플로우 질문
2733~3393 : @wizard env 토큰 치환 엔진 (kv맵, resolver, prompts.yml 파서, 치환/비교)
3395~4259 : 파일 복사 계열 (workflows/scripts/config/issue/discussion/coderabbit/gitignore/guide/util)
4262~4411 : interactive_mode
4413~4565 : execute_integration (모드 디스패처)
4567~5435 : IDE Skills 설치/제거 (Claude/Cursor/Gemini/Codex/PI + PI Harness)
5437~5625 : print_summary
5627~5660 : main + source 가드 (`BASH_SOURCE == $0`일 때만 main 실행 — 함수 단위 테스트용)
```

**⚠️ 모드 관련 주의 (기존 스펙과의 차이):**
- 실제 존재하는 MODE 값: `interactive`(기본) / `full` / `version` / `workflows` / `issues` / `skills`.
- **`revert` 모드는 이 스크립트에 존재하지 않는다.** 되돌리기 기능은 (1) IDE Skills 한정 "제거" 액션(`offer_ide_tools_install`의 remove 분기 → `_remove_*_section`), (2) help 텍스트에만 언급되는 `.template_integration/rollback.sh`(실제 생성 코드 없음) 뿐이다. Node 포팅 시 `commands/revert.js`는 **신규 설계**가 필요하다.
- 반대로 스펙 모듈 목록에 없는 `issues` 모드(이슈/PR 템플릿만)가 존재한다 — 포팅 시 커맨드로 추가해야 한다.

---

## 1. 함수 인벤토리 (132개, 그룹별)

표 형식: `이름 | 시작라인 | 한줄 역할 | 호출하는 주요 함수`

### (a) 터미널/출력 유틸 — 19개

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `detect_terminal` | 80 | stdin이 TTY인지, 파이프 실행 시 /dev/tty 접근 가능한지 감지해 `STDIN_MODE`/`TTY_AVAILABLE` 세팅 | (없음 — 순수 감지) |
| `cleanup_temp_dir` | 118 | `TEMP_DIR`(.template_download_temp) 삭제. `trap … EXIT`로 등록돼 ESC/Ctrl+C/set -e 종료에도 잔존 방지 | (없음) |
| `get_output_target` | 144 | 출력 대상 선택: TTY_AVAILABLE=true→/dev/tty, 아니면 probe 후 stderr 폴백 | (없음) |
| `safe_echo` | 160 | 명령어 치환 오염 방지 echo — /dev/tty 우선, stderr 폴백 | get_output_target |
| `safe_echo_e` | 169 | safe_echo의 `echo -e` 버전 | get_output_target |
| `print_header` | 178 | 박스형 헤더 출력 | safe_echo, safe_echo_e |
| `print_banner` | 187 | SUH·DEVOPS 배너(버전/모드/레포) 출력 | safe_echo |
| `print_step` | 202 | 🔅 단계 메시지 | safe_echo_e |
| `print_info` | 206 | 🔸 정보 메시지 | safe_echo_e |
| `print_success` | 210 | ✨ 성공 메시지 | safe_echo_e |
| `print_warning` | 214 | ⚠️ 경고 메시지 | safe_echo_e |
| `print_error` | 218 | 💥 에러 메시지 | safe_echo_e |
| `print_question` | 222 | 💫 질문 메시지 | safe_echo_e |
| `safe_read` | 231 | /dev/tty에서 안전하게 read. 라인 입력은 `read -e`(readline), `-n 1` 옵션 지원. 반환 1=TTY없음/EOF | (없음) |
| `print_to_user` | 261 | safe_echo 별칭 (사용자용 출력) | safe_echo |
| `show_help` | 735 | 도움말 heredoc 출력 | (없음) |
| `print_separator_line` | 1692 | 40자 구분선 | safe_echo |
| `print_section_header` | 1698 | 80자 구분선 + 섹션 타이틀 | safe_echo |
| `print_question_header` | 1710 | 40자 구분선 사이 질문 타이틀 | print_separator_line, safe_echo |

### (b) 대화형 메뉴/입력 — 5개 (+중첩 2개)

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `interactive_menu` | 273 | TTY 전용 화살표/숫자/Space/Enter/ESC 메뉴. 옵션 `--multi`, `--preselect=csv`, `--cancel-label`, `--initial-index`. stdout=선택 value, exit 1=ESC 취소. ANSI 커서 앵커(ESC7/ESC8)로 스크롤 안전 렌더 | (중첩) _interactive_menu_render / _clear |
| ├ `_interactive_menu_render` | 361 | (중첩 정의) 옵션 목록 렌더 — 체크박스/커서 표시자 포함 | (없음) |
| └ `_interactive_menu_clear` | 403 | (중첩 정의) 저장 앵커 복원(ESC8) + 화면 끝까지 삭제(ESC[J) | (없음) |
| `legacy_numeric_menu` | 516 | 비TTY 폴백 — 숫자/csv 텍스트 입력 메뉴. `--multi`/`--preselect` 동일 지원, 읽기 불가 시 preselect/첫옵션 자동 선택 | (없음) |
| `choose_menu` | 629 | 통합 진입점 — TTY+stderr TTY면 interactive_menu, 아니면 legacy_numeric_menu | interactive_menu, legacy_numeric_menu |
| `ask_yes_no` | 639 | Y/N 질문. TTY면 예/아니오 화살표 메뉴(기본값=커서 초기위치), 비TTY/FORCE면 한 글자 입력 폴백. 반환 0=Yes | choose_menu, safe_read, print_error |
| `ask_yes_no_edit` | 691 | Y/N/E(수정) 질문 — stdout으로 "yes"/"no"/"edit" 출력 (비TTY 확인 화면용) | safe_read, print_error |

### (c) 프로젝트 감지 (타입/버전/브랜치/경로) — 19개

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `detect_project_type` | 923 | (구형 단수 감지) 마커 파일 우선순위로 단일 타입 stdout. 현재 메인 플로우에서 미사용 — detect_project_types로 대체됨 | print_step/info/warning |
| `classify_package_json` | 1005 | package.json 내용으로 react-native(-expo)/next/react/node 판별 | (없음) |
| `_mode_display_label` | 1024 | 모드 키 → 확인 화면용 한국어 라벨 | (없음) |
| `detect_project_types` | 1035 | **멀티 타입 감지 (메인).** 우선순위: ① 기존 version.yml의 project_types(source of truth) ② 마커 파일 전수 스캔 → csv stdout | (yq 있으면 yq, 없으면 grep/sed) |
| `suggest_types_by_scan` | 1116 | 마커가 없을 때(basic) 추천 — 서브폴더 마커 스캔 + 확장자 빈도 폴백 → 추천 csv (안내용) | find_type_path_candidates, classify_package_json |
| `get_path_for_type` | 1182 | `PROJECT_PATHS_CSV`("t=p,…")에서 타입 경로 조회 | (없음) |
| `set_path_for_type` | 1199 | `PROJECT_PATHS_CSV`에 타입=경로 저장(교체) | (없음) |
| `marker_for_type` | 1220 | 타입 → 대표 마커 파일명 | (없음) |
| `existing_marker_in_dir` | 1232 | 디렉토리에 실재하는 마커(보조 마커 포함) 반환, 없으면 대표 마커(표시용) | marker_for_type |
| `find_type_path_candidates` | 1249 | 타입별 마커 후보 디렉토리 검색(maxdepth 3, 잡음 폴더 prune, spring은 settings.gradle=멀티모듈 루트 축약, flutter는 lib/ 동반 확인) | (find/sed) |
| `load_saved_project_paths` | 1316 | 기존 version.yml의 project_paths를 CSV에 로드만(질문 없음). 반환 0=전 타입 채워짐 | get_path_for_type, set_path_for_type |
| `resolve_project_paths` | 1362 | **경로 확정 메인.** --paths 검증·정규화 → 타입별로 (--paths > 루트마커 "." > version.yml 저장값 > 후보검색 1/N개 > 직접입력) → 요약 + 중복 파일 경고. 비대화형은 기존값/단일후보/"." 자동 | get_path_for_type, set_path_for_type, existing_marker_in_dir, find_type_path_candidates, ask_yes_no, choose_menu, safe_read |
| `detect_version` | 1592 | package.json(jq)→build.gradle→pubspec.yaml→pyproject.toml→git tag 순 버전 감지, 실패 시 0.0.1 (BSD grep 호환: -P 미사용) | (grep/sed/jq/git) |
| `detect_default_branch` | 1661 | gh CLI → git symbolic-ref → git remote show → "main" 순 기본 브랜치 감지 | (gh/git) |
| `show_project_type_menu` | 1722 | 타입 선택 멀티셀렉트 — 감지/스캔 추천 로그 + preselect. ESC=기존 유지(return 1) | detect_project_types, suggest_types_by_scan, marker_for_type, choose_menu |
| `print_project_analysis` | 1806 | 확인 화면 개요 — 타입(멀티)/버전/브랜치/모드/Nexus·Secret/경로 출력 | print_section_header, _mode_display_label |
| `detect_and_confirm_project` | 1843 | 감지(최초 1회) + 확인 루프: 분석 출력 → 예/수정/취소 3지선 → edit면 수정 메뉴, ESC=stay(머무름) | detect_project_types, detect_version, detect_default_branch, print_project_analysis, choose_menu, ask_yes_no_edit, handle_project_edit_menu |
| `handle_project_edit_menu` | 1925 | 수정 메뉴 루프 — 타입(변경 시 경로 재확정)/버전/브랜치/선택WF 항목 수정. done=return 0, ESC=return 1 | print_project_analysis, choose_menu, show_project_type_menu, resolve_project_paths, safe_read, ask_all_optional_workflows |
| `detect_repo_name` | 2751 | git remote origin URL → 레포명, 폴백 현재 디렉토리명 (@wizard `repo` resolver의 실체) | (git) |

### (d) 템플릿 다운로드 — 1개

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `download_template` | 2064 | `git clone --depth 1` → TEMP_DIR. 이미 있으면 스킵(멱등). **문서 제거 목록**(CONTRIBUTING/CLAUDE/AGENTS/GEMINI.md, gemini-extension.json)과 **플러그인 제외 목록**(`plugin_items_to_remove`: .claude-plugin/.codex-plugin/.agents/.cursor/scripts/package.json/harness/bin/src/PLUGIN-VERSION-SYNC·NPM-PUBLISH yaml) 삭제. skills/는 Cursor 복사용으로 보존. TEMP_DIR/version.yml에서 `TEMPLATE_VERSION` 파싱(실패 시 DEFAULT_VERSION) | print_step/info/success/error |

### (e) 파일 복사/제외 — 16개

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `_wf_is_unchanged` | 3376 | 기존 설치본 == "지금 설정으로 깔면 나올 최종형"인지 비교. 원본을 임시 사본에 놓고 **서브셸 격리로 configure_workflow_env 가상 적용** 후 cmp. 0=동일 | configure_workflow_env(서브셸) |
| `_copy_workflows_for_type` | 3398 | 타입 1개의 워크플로우 복사 — ① 타입 루트: 신규/변경/동일 3분류, 변경은 3지선 메뉴(기존유지+.template.yaml / 건너뛰기 / .bak백업+덮어쓰기) ② server-deploy/ 하위: 기본 포함, `INCLUDE_NEXUS=true`면 폴더째 제외 ③ nexus/ 하위: opt-in ④ 복사된 파일마다 configure_workflow_env. 카운터는 전역(_wf_copied 등) 공유 | _wf_is_unchanged, choose_menu, configure_workflow_env |
| `_contains_type` | 3675 | PROJECT_TYPES 배열에 특정 타입 포함 여부 | (없음) |
| `copy_workflows` | 3683 | **워크플로우 복사 메인.** common/ 항상 최신화(동일 시 스킵) → `wf_prompt_env_plan` 1회 → 타입 순회 `_copy_workflows_for_type` → common/secret-backup opt-in → 요약·멀티타입 CI충돌 경고·spring Secrets 안내. `WORKFLOWS_COPIED` 세팅 | wf_prompt_env_plan, _copy_workflows_for_type, _wf_is_unchanged, _contains_type |
| `copy_scripts` | 3818 | version_manager.sh + changelog_manager.py → .github/scripts/ 복사 + chmod +x | (cp) |
| `copy_config_folder` | 3845 | TEMP_DIR/.github/config → .github/config 전체 덮어쓰기 (wizard-prompts.yml, breaking-changes.json 등) | (cp) |
| `copy_issue_templates` | 3872 | ISSUE_TEMPLATE/ 덮어쓰기 + PULL_REQUEST_TEMPLATE.md 복사 | (cp) |
| `copy_discussion_templates` | 3895 | DISCUSSION_TEMPLATE/ 덮어쓰기 (템플릿에 없으면 스킵) | (cp) |
| `show_coderabbit_intro` | 3919 | CodeRabbit 소개 + 설정 내용 + 활성화 절차 안내 | print_to_user |
| `copy_coderabbit_config` | 3938 | .coderabbit.yaml 복사 — 기존 있으면 덮어쓰기/건너뛰기 메뉴(.bak 백업), FORCE=백업 후 덮어쓰기, 비TTY=유지 | show_coderabbit_intro, choose_menu |
| `normalize_gitignore_entry` | 3996 | gitignore 항목 정규화(주석/공백/앞뒤 슬래시/./ 제거) — 중복 판정용 | (없음) |
| `check_gitignore_entry_exists` | 4017 | .gitignore에 정규화 비교로 항목 존재 여부 | normalize_gitignore_entry |
| `ensure_gitignore` | 4048 | .gitignore 생성 또는 필수 항목(/.idea, /.claude/settings.local.json) 누락분만 섹션 추가 | check_gitignore_entry_exists |
| `copy_setup_guide` | 4114 | SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 최신 덮어쓰기 | (cp) |
| `show_util_module_description` | 4137 | 타입별 util 모듈 설명 (flutter: ios-testflight/android-playstore 마법사) | print_to_user |
| `show_util_usage_guide` | 4173 | 타입별 util 모듈 사용법 안내 | print_to_user |
| `copy_util_modules` | 4203 | .github/util/{type}/ 복사 — Y/N 확인(FORCE=자동, 비TTY=스킵), 복사 후 가이드 출력. `UTIL_MODULES_COPIED` 세팅 | show_util_module_description, ask_yes_no, show_util_usage_guide |

### (f) version.yml 생성·갱신 — 6개

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `add_version_section_to_readme` | 2145 | README.md 하단에 `<!-- AUTO-VERSION-SECTION -->` 버전 섹션 append (마커/버전라인 이미 있으면 스킵) | (grep/cat) |
| `create_version_yml` | 2184 | version.yml 신규 작성 — 기존 파일에서 version_code·version **보존**(yq 또는 grep/sed), 갱신 안내 + Y/N(N=통합 전체 취소), 멀티타입 json 배열 + project_paths 블록 + metadata heredoc 생성 | ask_yes_no, existing_marker_in_dir, print_* |
| `read_template_options` | 2361 | version.yml의 `metadata.template.options.nexus/.secret_backup`을 라인 파서로 읽어 INCLUDE_* 세팅 | (없음 — 수제 YAML 파서) |
| `save_template_options` | 2419 | version.yml에 template 섹션 저장/갱신 (nexus/secret_backup/last_update_date, sed 치환 또는 append) | (sed) |
| `get_current_template_version` | 2619 | version.yml의 `metadata.template.version` 읽기, 없으면 "unknown" | (없음 — 수제 파서) |
| `update_version_yml_deploy` | 3016 | `WF_DEPLOY_CSV`(ask로 모은 배포 설정)를 version.yml `deploy:` 블록으로 기록 (기존 블록 제거 후 재생성 — 멱등) | (sed) |

### (g) breaking changes — 2개

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `compare_versions` | 2475 | semver 3필드 비교 → 1/-1/0 stdout | (없음) |
| `check_breaking_changes` | 2506 | raw URL에서 breaking-changes.json curl → jq로 current<ver<=new 범위 수집 → critical/warning 박스 출력, critical이면 Y/N 게이트(N=exit 0). FORCE/비TTY/jq없음/버전unknown이면 스킵 | compare_versions, ask_yes_no |

### (h) 옵션 (nexus / secret-backup) — 2개

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `ask_optional_workflow` | 2650 | opt-in 워크플로우 1종 질문 — 폴더/파일 존재 확인, 이미 설정돼 있으면 스킵(--force-ask 예외), 비TTY=false, 파일 목록 보여주고 Y/N → eval로 INCLUDE_* 변수 세팅. set -e 함정 대응으로 모든 early return이 `return 0` | ask_yes_no |
| `ask_all_optional_workflows` | 2707 | 모든 opt-in 순회 — --force-ask 아니면 먼저 read_template_options로 저장값 로드 → 타입별 nexus/ → 공통 secret-backup/ | read_template_options, ask_optional_workflow |

### (i) skills 설치 (claude/cursor/gemini/codex/pi) — 29개

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `offer_ide_tools_install` | 4575 | **IDE Skills 라우터.** 5개 IDE + PI Harness 상태 수집·표시 → 액션 메뉴(설치·업데이트/제거/그대로) → IDE 멀티셀렉트 → 선택된 IDE의 _manage_*/_remove_* 호출. FORCE/비TTY는 전 IDE 순차 자동 설치 | choose_menu, _pi_is_installed, _pi_harness_enabled, _pi_harness_loader_path, _manage_* 5종, _remove_* 5종, _pi_harness_toggle, _pi_harness_remove_only |
| `_manage_claude_section` | 4751 | Claude 플러그인 — 설치돼 있으면 update(+캐시 config.json 마이그레이션), 미설치면 user scope 신규 설치. (reinstall/delete 분기 코드는 잔존하나 choice=update 고정) | _do_claude_plugin_install, _remove_claude_plugin_data |
| `_manage_cursor_section` | 4850 | Cursor — 마켓플레이스 없음 → TEMP_DIR/skills(또는 로컬 skills/)를 ~/.cursor/skills로 복사 | _do_cursor_skills_copy |
| `_remove_claude_section` | 4883 | Claude 플러그인 uninstall + data 삭제 (미설치 no-op) | _remove_claude_plugin_data |
| `_remove_cursor_section` | 4902 | ~/.cursor/skills 삭제 (meta.json 없으면 no-op) | (rm) |
| `_remove_gemini_section` | 4918 | `gemini extensions uninstall cassiiopeia` | (gemini CLI) |
| `_remove_codex_section` | 4932 | ~/.agents/skills/cassiiopeia 심링크/폴더 삭제 + marketplace 해제 수동 안내 | (rm) |
| `_remove_pi_section` | 4949 | `pi remove <URL>` + 잔존 확인 + harness 등록 동반 해제 | _pi_is_installed, _pi_harness_enabled, _pi_harness_remove |
| `_do_claude_plugin_install` | 4978 | `claude plugin marketplace add` + `claude plugin install --scope` | (claude CLI) |
| `_remove_claude_plugin_data` | 4999 | ~/.claude/plugins/data/cassiiopeia@cassiiopeia-marketplace/ 삭제 | (rm) |
| `_write_cursor_skills_meta` | 5015 | cursor-skills-meta.json 생성/갱신 (버전 manifest, installedAt 보존) | (cat heredoc) |
| `_do_cursor_skills_copy` | 5048 | skills/ → ~/.cursor/skills 복사 + meta 기록 | _write_cursor_skills_meta |
| `_manage_gemini_extension` | 5067 | `gemini extensions update` 시도 → 실패 시 install (CLI 없으면 수동 안내) | (gemini CLI) |
| `_manage_codex_skills` | 5097 | codex CLI 있으면 marketplace 등록/업그레이드 | _do_codex_marketplace_register |
| `_do_codex_marketplace_register` | 5112 | `codex plugin marketplace add` + `upgrade cassiiopeia` | (codex CLI) |
| `_do_codex_native_skills_fallback` | 5130 | (폴백) 레포 clone → ~/.agents/skills/cassiiopeia 심링크. 현 라우터에선 직접 호출 안 됨(레거시 유지) | ask_yes_no, (git) |
| `_pi_python` | 5197 | 실행 검증된 python 경로 탐색 (Windows Store stub 걸러냄: 실제 `-c` 실행 테스트) | (없음) |
| `_pi_is_installed` | 5211 | `pi list` 출력에 레포명 포함 여부로 설치 판정 | (pi CLI) |
| `_pi_clone_dir` | 5222 | pi 클론 경로 — 신 projectops 경로 우선, 구 SUH-DEVOPS-TEMPLATE 경로 폴백 | (없음) |
| `_pi_harness_loader_path` | 5232 | `<클론>/harness/harness-loader.ts` 경로 | _pi_clone_dir |
| `_pi_settings_path` | 5235 | ~/.pi/agent/settings.json 경로 | (없음) |
| `_pi_harness_enabled` | 5240 | settings.json extensions 배열에 loader 등록 여부 (임베디드 python heredoc) | _pi_python, _pi_settings_path, _pi_harness_loader_path |
| `_pi_harness_add` | 5259 | extensions 배열에 loader 추가 (python heredoc, 중복 방지) | _pi_python 외 경로 헬퍼 |
| `_pi_harness_remove` | 5295 | extensions 배열에서 loader 제거 (python heredoc) | _pi_python 외 경로 헬퍼 |
| `_pi_harness_offer` | 5322 | PI 설치 직후 harness 켤지 제안 (활성화면 유지, 비TTY/FORCE는 스킵) | _pi_harness_enabled, _pi_harness_print_desc, ask_yes_no, _pi_harness_add |
| `_pi_harness_print_desc` | 5352 | harness 개념 설명 출력 | print_info |
| `_pi_harness_toggle` | 5362 | [설치/업데이트] 메뉴의 harness 단독 항목 — 현재 상태 토글 | _pi_harness_enabled, _pi_harness_add, _pi_harness_remove, ask_yes_no |
| `_pi_harness_remove_only` | 5394 | [제거] 메뉴의 harness 단독 항목 — skill 보존, harness만 해제 | _pi_harness_enabled, _pi_harness_remove |
| `_manage_pi_section` | 5405 | `pi update`/`pi install` → 검증 → harness offer | _pi_is_installed, _pi_harness_offer |

### (j) revert — 0개

- **해당 함수 없음.** `--mode revert` 미구현. 위 (i)의 `_remove_*` 계열이 "IDE Skills 제거"라는 부분적 되돌리기만 담당.
- help 텍스트(822행)에 `./.template_integration/rollback.sh`가 언급되지만 이 스크립트 어디에서도 `.template_integration/` 백업 폴더나 rollback.sh를 **생성하지 않는다** (레거시 문구). 파일 백업은 개별 `.bak`(워크플로우 덮어쓰기, .coderabbit.yaml)뿐.
- → Node 포팅의 `commands/revert.js`는 기존 동작 이식이 아니라 **신규 기능 설계**임을 스펙에 명시할 것.

### (k) 메인 플로우/인자 파싱 — 4개 (+top-level 파싱 블록)

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| (top-level) 인자 파싱 | 843~920 | 함수 아님 — `while case`로 -m/-v/-t(csv dedup+검증)/--force/--nexus/--no-nexus/--secret-backup/--no-secret-backup/--paths/-h 파싱. 즉시 전역 세팅, -h는 show_help 후 exit | show_help, print_error |
| `interactive_mode` | 4263 | 대화형 플로우 — 원격 version.yml curl로 배너 버전 → 모드 메뉴 → download_template → 모드별 수집(타입/버전/브랜치 → opt-in WF → 경로 로드) → 확인 화면 → 미확정 경로 질문. `IS_INTERACTIVE_MODE=true` | print_banner, choose_menu, download_template, detect_project_types, detect_version, detect_default_branch, ask_all_optional_workflows, load_saved_project_paths, detect_and_confirm_project, resolve_project_paths |
| `execute_integration` | 4414 | **모드 디스패처.** breaking check → (CLI 모드만) 감지+확인+download+opt-in질문+경로확정 → `case $MODE` 복사 체인 → save_template_options → offer_ide_tools_install → TEMP_DIR 정리 → print_summary. skills 모드는 조기 return | get_current_template_version, check_breaking_changes, detect_*, ask_yes_no, download_template, ask_all_optional_workflows, resolve_project_paths, create_version_yml, add_version_section_to_readme, copy_workflows, update_version_yml_deploy, copy_scripts, copy_config_folder, copy_util_modules, copy_issue_templates, copy_discussion_templates, copy_coderabbit_config, ensure_gitignore, copy_setup_guide, save_template_options, offer_ide_tools_install, print_summary |
| `print_summary` | 5438 | 완료 요약 — 모드별 통합 기능 체크리스트, 설치된 워크플로우 분류(공통/타입별/기존), util 모듈, 타입별 안내, 필수 3작업(PAT/deploy브랜치/CodeRabbit) | _contains_type |
| `main` | 5628 | detect_terminal → git repo 경고 → MODE=interactive면 interactive_mode → execute_integration | detect_terminal, interactive_mode, execute_integration |

### (l) 기타 — @wizard env 토큰 치환 엔진 — 27개

> 워크플로우 YAML의 `KEY: "__TOKEN__"  # @wizard ask:기본값 / auto:resolver / paths-anchor` 마커를 스캔해 값을 채우는 서브시스템. 포팅 시 독립 모듈(`core/wizard-env.js`) 권장 — 아래 §4 참조.

| 이름 | 라인 | 역할 | 호출하는 주요 함수 |
|---|---|---|---|
| `resolve_repo` | 2764 | resolver: 레포명 (detect_repo_name 위임) | detect_repo_name |
| `resolve_spring_app_yml_dir` | 2766 | resolver: spring application*.yml 디렉토리 탐색 | get_path_for_type, (find) |
| `resolve_spring_app_yml_path` | 2775 | resolver: application*.yml 파일 경로 | get_path_for_type, (find) |
| `resolve_flutter_root` | 2783 | resolver: project_paths.flutter (없으면 ".") | get_path_for_type |
| `resolve_token` | 2790 | resolver 디스패처 — repo/spring-app-yml-dir/-path/flutter-root | resolve_* 4종 |
| `_wf_labels_path` | 2808 | wizard-prompts.yml 실제 경로 결정 (작업 dst 우선, TEMP_DIR 원본 폴백) | (없음) |
| `_kv_enc` | 2831 | 키 → 변수명 안전 인코딩([A-Za-z0-9_] 외 → _HEX). bash 3.2 연관배열 부재 우회 | (없음) |
| `_kv_set` | 2844 | 맵 대체: `__KV_{MAP}__{encKey}` 동적 변수 대입 (eval) | _kv_enc |
| `_kv_get` | 2853 | 맵 대체: 조회 (없으면 빈 문자열) | _kv_enc |
| `_kv_has` | 2862 | 맵 대체: 키 존재 검사 (`${var+x}` 의미 보존) | _kv_enc |
| `_kv_clear` | 2872 | 맵 대체: 접두 이름 확장으로 전체 unset (멱등 리셋) | (없음) |
| `_wf_load_workflow_names` | 2895 | wizard-prompts.yml `_workflow_names:` 블록 → WF_WFNAME_KEYS/VAL 1회 캐시 로드 (fork 비용 회피) | _wf_labels_path, _kv_set/_kv_clear |
| `wf_workflow_name` | 2917 | 워크플로우 파일명 → 사람이 읽는 이름 (부분문자열 최장 매칭, 폴백=확장자 제거) | _wf_load_workflow_names, _kv_get |
| `_wf_read_field` | 2934 | wizard-prompts.yml에서 KEY(또는 type.KEY)의 label/help/example 1개 읽기 — 1줄 구형·블록 형식 모두 (awk) | _wf_labels_path |
| `wf_field` | 2962 | 필드 조회 우선순위: type.KEY > KEY > (label이면 KEY명) | _wf_read_field |
| `wf_deploy_get` | 2972 | WF_DEPLOY_CSV("type\|KEY=값;…")에서 조회 — 재실행 시 기존값 | (없음) |
| `wf_deploy_set` | 2987 | WF_DEPLOY_CSV에 저장(교체) | (없음) |
| `_wf_set_env` | 3004 | 파일 내 `KEY: "…"` 값 sed 치환 + 그 줄의 `# @wizard …` 주석 제거 | (sed -i) |
| `update_version_yml_deploy` | 3016 | → (f) 그룹 참조 (물리적으로 이 구역에 위치) | (sed) |
| `wf_scope_string` | 3059 | "type\|name" 목록 → 사용처 문자열("타입 name1·name2" 또는 "type1·type2") | (없음) |
| `wf_collect_asks` | 3087 | 설치 대상 타입들의 워크플로우에서 `@wizard ask:` KEY 전수 수집 → WF_ASK_KEYS + DEFAULT/SCOPE/FILES/TYPE_DEFAULT 맵 채움 (grep+bash 내장 파싱, resolver·저장값 우선순위 반영) | wf_workflow_name, resolve_token, wf_deploy_get, _kv_*, wf_scope_string |
| `_wf_first_type_for` | 3145 | KEY가 처음 등장한 타입 (label 조회용) | _kv_get |
| `_wf_print_field_card` | 3152 | KEY 1개를 label·사용처·설명·예시·기본값 카드로 출력 | _wf_first_type_for, wf_field, _kv_get |
| `_wf_prefill_all` | 3171 | 전 KEY를 기본값(타입별 우선)으로 WF_DEPLOY_CSV prefill | _kv_get, wf_deploy_set |
| `_wf_prefill_interactive` | 3187 | 지정 KEY들만 사용자 입력받아 prefill (N/총 진행 표시) | _wf_print_field_card, safe_read, wf_field, wf_deploy_set |
| `wf_prompt_env_plan` | 3220 | **env 계획 메인** — 카드 미리보기 + 3지선(전부기본/하나씩/골라서) → prefill. 비대화형=전부 기본. 완료 후 `WF_USE_DEFAULTS=true` 고정 | wf_collect_asks, _wf_print_field_card, interactive_menu, _wf_prefill_all, _wf_prefill_interactive |
| `configure_workflow_env` | 3282 | **파일 1개 치환 실행** — @wizard ask/auto 라인 순회 치환(WF_USE_DEFAULTS=true면 캐시값), 잔여 `__PROJECT_NAME__`/`__APP_ARTIFACT_NAME__` 일괄 치환, paths-anchor → `paths: ['dir/**']` 주입, 미치환 `__TOKEN__` 경고 | resolve_token, wf_field, wf_deploy_get/set, _wf_set_env, detect_repo_name, get_path_for_type, safe_read |

**그룹별 개수 합계**: (a)19 + (b)5(+중첩2) + (c)19 + (d)1 + (e)16 + (f)6 + (g)2 + (h)2 + (i)29 + (j)0 + (k)4 + (l)27 = **130 (+2) = 132**

---

## 2. 모드별 실행 경로 (콜 체인)

모든 경로의 공통 시작: `main()` → `detect_terminal` → git repo 확인(경고만) → `[MODE=interactive] interactive_mode` → `execute_integration`.

### 2.1 interactive (기본값)

```
main
└─ interactive_mode                      # IS_INTERACTIVE_MODE=true
   ├─ curl 원격 version.yml → template_version (배너용, 실패 시 DEFAULT_VERSION)
   ├─ print_banner
   ├─ TTY_AVAILABLE=false → 에러 안내 후 exit 1
   ├─ choose_menu (모드 선택: 전체/버전/워크플로우/이슈·PR/AI스킬/취소) → MODE 확정
   ├─ download_template                  # 모드 무관 선다운로드 (opt-in 스캔·Cursor 소스에 필요)
   └─ case MODE:
      ├─ skills|issues → 수집 전부 생략
      └─ full|version|workflows →
         ├─ detect_project_types → PROJECT_TYPES / detect_version → VERSION / detect_default_branch → DETECTED_BRANCH
         ├─ [full|workflows] ask_all_optional_workflows(타입별 nexus + common/secret-backup)
         │   └─ read_template_options → ask_optional_workflow × N
         ├─ [full|version] load_saved_project_paths   # 저장값 로드만, 질문 없음
         ├─ detect_and_confirm_project                 # 확인 루프
         │   ├─ print_project_analysis
         │   ├─ choose_menu(예/수정/취소, ESC=stay)
         │   └─ [수정] handle_project_edit_menu
         │       ├─ show_project_type_menu → (타입 변경 시) resolve_project_paths 재실행
         │       ├─ safe_read (버전/브랜치)
         │       └─ ask_all_optional_workflows --force-ask
         └─ [full|version] 경로 미확정 타입 있으면 resolve_project_paths
main
└─ execute_integration                   # IS_INTERACTIVE_MODE=true라 재감지/재확인/재다운로드 전부 스킵
   ├─ get_current_template_version → check_breaking_changes
   └─ (이하 §2.2~2.7의 모드별 복사 체인과 동일)
```

### 2.2 full (CLI: `--mode full`)

```
execute_integration
├─ get_current_template_version → check_breaking_changes(compare_versions, [critical] ask_yes_no)
├─ detect_project_types / detect_version / detect_default_branch   # --type/--version 미지정분만
├─ 통합 설정 확인 화면 + ask_yes_no                                 # --force면 생략, 비TTY+비force면 exit 1
├─ download_template
├─ ask_all_optional_workflows                                       # full|workflows만
├─ resolve_project_paths                                            # full|version만
├─ create_version_yml → add_version_section_to_readme
├─ copy_workflows
│   ├─ common/ 복사 (_wf_is_unchanged로 동일 스킵)
│   ├─ wf_prompt_env_plan (1회: wf_collect_asks → 카드 → 메뉴 → prefill)
│   ├─ _copy_workflows_for_type × 타입          # 루트/server-deploy/nexus 3구역 + configure_workflow_env
│   └─ common/secret-backup (opt-in)
├─ update_version_yml_deploy
├─ copy_scripts → copy_config_folder
├─ copy_util_modules × 타입
├─ copy_issue_templates → copy_discussion_templates
├─ copy_coderabbit_config → ensure_gitignore → copy_setup_guide
├─ save_template_options "$TEMPLATE_VERSION"                        # full|workflows만
├─ offer_ide_tools_install                                          # IDE Skills 라우터
├─ rm -rf TEMP_DIR
└─ print_summary
```

### 2.3 version

```
execute_integration → (공통 전처리, opt-in 질문 없음) → download_template → resolve_project_paths
→ create_version_yml → add_version_section_to_readme → copy_scripts → copy_config_folder
→ ensure_gitignore → copy_setup_guide → offer_ide_tools_install → 정리 → print_summary
```

### 2.4 workflows

```
execute_integration → (공통 전처리) → download_template → ask_all_optional_workflows
→ copy_workflows → update_version_yml_deploy → copy_scripts → copy_config_folder
→ copy_util_modules × 타입 → copy_setup_guide → save_template_options
→ offer_ide_tools_install → 정리 → print_summary
```
(주의: version.yml을 만들지 않지만 `save_template_options`/`update_version_yml_deploy`는 version.yml이 **이미 있을 때만** 기록한다.)

### 2.5 issues

```
execute_integration → (공통 전처리; 경로/opt-in 없음) → download_template
→ copy_issue_templates → copy_discussion_templates
→ offer_ide_tools_install → 정리 → print_summary
```

### 2.6 skills

```
execute_integration
├─ [CLI] MODE=skills라 프로젝트 감지/확인 자체를 스킵 (IS_INTERACTIVE 무관)
├─ [CLI] download_template            # TEMPLATE_VERSION·Cursor 소스(skills/) 확보용
├─ offer_ide_tools_install
│   ├─ 상태 수집: claude plugin list / cursor meta.json / gemini·codex·pi command -v / _pi_is_installed / _pi_harness_enabled
│   ├─ [TTY] 액션 메뉴(설치·업데이트/제거/그대로) → IDE 멀티셀렉트
│   │   ├─ apply → _manage_claude_section / _manage_cursor_section / _manage_gemini_extension
│   │   │          / _manage_codex_skills / _manage_pi_section(→_pi_harness_offer) / _pi_harness_toggle
│   │   └─ remove → _remove_claude/cursor/gemini/codex/pi_section / _pi_harness_remove_only
│   └─ [FORCE·비TTY] _manage_* 5종 순차 자동 실행
├─ rm -rf TEMP_DIR → print_summary
└─ return 0                            # 아래 공통 offer/정리 블록을 타지 않고 조기 종료
```

### 2.7 revert

**없음.** §1(j) 참조 — Node 포팅에서 신규 설계 대상.

---

## 3. 전역 변수 목록

| 변수 | 초기값(라인) | 용도 | 세팅 위치 | 주요 읽기 위치 |
|---|---|---|---|---|
| `STDIN_MODE` | false (76) | stdin이 파이프인지 (curl \| bash) | detect_terminal | interactive_mode, main (안내 문구) |
| `TTY_AVAILABLE` | true (77) | /dev/tty 대화형 입력 가능 여부 — **모든 대화형 분기의 스위치** | detect_terminal | choose_menu, safe_read, ask_yes_no, ask_optional_workflow, resolve_project_paths, copy_*, offer_ide_tools_install 등 전역 |
| `RED…NC` | '' (103~109) | 색상 코드 — 전부 빈 문자열로 비활성화 (interactive_menu만 자체 ANSI 사용) | 고정 | print_* |
| `TEMPLATE_REPO` | URL (112) | clone 원본 레포 | 고정 | download_template |
| `TEMP_DIR` | `.template_download_temp` (113) | 템플릿 clone 임시 폴더 | 고정 | download_template, copy_* 전부, interactive_mode, execute_integration, cleanup_temp_dir(trap) |
| `TEMPLATE_RAW_URL` | readonly (124) | raw.githubusercontent 베이스 | 고정 | check_breaking_changes, interactive_mode(원격 version.yml) |
| `VERSION_FILE` | readonly "version.yml" (125) | 원격 버전 파일명 | 고정 | interactive_mode |
| `WORKFLOWS_DIR` | readonly ".github/workflows" (126) | 워크플로우 대상 폴더 | 고정 | copy_workflows, _copy_workflows_for_type, print_summary, opt-in 경로 조립 |
| `SCRIPTS_DIR` | readonly ".github/scripts" (127) | 스크립트 대상 폴더 | 고정 | copy_scripts |
| `PROJECT_TYPES_DIR` | readonly "project-types" (128) | 타입별 워크플로우 폴더명 | 고정 | copy_workflows, opt-in 경로 조립 |
| `DEFAULT_VERSION` | readonly "1.3.14" (129) | 템플릿 버전 폴백 | 고정 | download_template, interactive_mode, execute_integration(breaking 비교의 new_version) |
| `TEMPLATE_VERSION` | "" (132) | 다운로드한 템플릿의 실제 버전 | download_template | save_template_options, offer_ide_tools_install, _write_cursor_skills_meta, _manage_cursor_section |
| `WORKFLOW_PREFIX` 등 3종 | readonly (135~137) | 워크플로우 파일명 패턴 상수 | 고정 | print_summary |
| `MODE` | "interactive" (828) | 실행 모드 | 인자 파싱(-m), interactive_mode(메뉴) | main, interactive_mode, execute_integration, handle_project_edit_menu, print_project_analysis, print_summary |
| `VERSION` | "" (829) | 프로젝트 버전 | 인자(-v), detect_version(감지), handle_project_edit_menu(수정) | create_version_yml, add_version_section_to_readme, print_summary, 확인 화면 |
| `PROJECT_TYPE` | "" (830) | 단수 타입 (PROJECT_TYPES[0] 미러) | 인자(-t), 감지/수정 시 배열과 함께 | create_version_yml 폴백, 표시용 |
| `PROJECT_TYPES` | () (831) | **멀티타입 배열 (source of truth)** | 인자(-t csv), detect_project_types, show_project_type_menu | resolve_project_paths, copy_workflows, create_version_yml, opt-in 질문, print_summary, _contains_type |
| `FORCE_MODE` | false (832) | 확인 없이 진행 | 인자(--force) | 모든 확인/질문 분기 (ask_yes_no, check_breaking_changes, copy_*, wf_prompt_env_plan, offer_ide_tools_install …) |
| `IS_INTERACTIVE_MODE` | false (833) | interactive_mode를 거쳐 왔는지 — execute_integration의 재감지/재확인/재다운로드 스킵 플래그 | interactive_mode | execute_integration |
| `INCLUDE_NEXUS` | "" (835) | Nexus publish 포함 여부 ("":미설정/true/false). true면 server-deploy/ 폴더째 제외 | 인자(--nexus/--no-nexus), read_template_options, ask_optional_workflow(eval) | _copy_workflows_for_type, print_project_analysis, handle_project_edit_menu, save_template_options |
| `INCLUDE_SECRET_BACKUP` | "" (836) | Secret 백업 워크플로우 포함 여부 | 위와 동일 경로 | copy_workflows(4단계), print_project_analysis, save_template_options |
| `PROJECT_PATHS_CSV` | "" (837) | 타입별 경로 "flutter=app,react=client" (bash 3.2 — 연관배열 금지) | 인자(--paths), load_saved_project_paths, resolve_project_paths, set_path_for_type | get_path_for_type, create_version_yml, resolve_flutter_root, configure_workflow_env(paths-anchor), print_project_analysis |
| `VALID_TYPES` | 배열 (840) | 지원 타입 목록 (검증용) | 고정 | 인자 파싱, resolve_project_paths(--paths 검증) |
| `DETECTED_BRANCH` | (미선언 — 암묵) | 기본 브랜치 | detect_and_confirm_project, interactive_mode, execute_integration(각각 비어 있으면 detect_default_branch), handle_project_edit_menu(수정) | create_version_yml, print_project_analysis, 확인 화면 |
| `WF_DEPLOY_CSV` | env 승계 (2746) | @wizard ask 값 기억 "type\|KEY=값;…" — 재실행 기본값 + version.yml deploy 블록 원천 | wf_deploy_set (prefill/입력/치환 시) | wf_deploy_get, update_version_yml_deploy |
| `WF_USE_DEFAULTS` | "" (2748) | "전부 기본값" 일괄 모드 플래그 (1회 결정 후 고정) | wf_prompt_env_plan, configure_workflow_env(폴백 질문), _wf_is_unchanged(서브셸 한정 true) | configure_workflow_env |
| `LABELS_FILE` | ".github/config/wizard-prompts.yml" (2802) | 질문 문구 파일 경로 (env로 override 가능) | 고정 | _wf_labels_path |
| `WF_WFNAME_KEYS` / `WF_WFNAME_LOADED` | ()/"" (2892·2894) | _workflow_names 매핑 캐시 (fork 비용 회피) | _wf_load_workflow_names | wf_workflow_name |
| `WF_ASK_KEYS` | () (3083) | @wizard ask KEY 등장 순서 | wf_collect_asks | wf_prompt_env_plan, _wf_prefill_* |
| `__KV_{MAP}__{hex}` 동적 변수군 | — | 연관배열 대체 저장소 (WF_ASK_DEFAULT/SCOPE/FILES/TYPE_DEFAULT, WF_WFNAME_VAL) | _kv_set | _kv_get/_kv_has, _kv_clear로 리셋 |
| `_wf_copied` / `_wf_skipped` / `_wf_template_added` / `_wf_optional_copied` | copy_workflows에서 0 초기화 | 멀티타입 순회 공유 카운터 (의도적 전역) | copy_workflows, _copy_workflows_for_type | copy_workflows 요약 |
| `WORKFLOWS_COPIED` | (copy_workflows) | 최종 요약용 복사 수 | copy_workflows | print_summary |
| `UTIL_MODULES_COPIED` | (copy_util_modules) | 최종 요약용 util 모듈 수 | copy_util_modules | print_summary |
| `PI_PACKAGE_URL` | URL (5192) | pi install 대상 | 고정 | _manage_pi_section, _remove_pi_section |

---

## 4. Node 포팅 모듈 경계 제안

기존 스펙 구조: `src/commands/{interactive,full,version,workflows,skills,revert}.js`, `src/core/{detect,assets,version-yml,breaking,options,exclusions}.js`, `src/ui/prompts.js`

### 4.1 매핑 표

| Node 모듈 | 담당 bash 함수 (그룹) | 비고 |
|---|---|---|
| **`src/ui/prompts.js`** | (a) print_* 전부, safe_echo/safe_read/get_output_target/detect_terminal + (b) interactive_menu/legacy_numeric_menu/choose_menu/ask_yes_no/ask_yes_no_edit + print_banner/print_summary의 렌더 헬퍼 | `@inquirer/prompts`류로 대체 시 interactive_menu의 **ESC=뒤로/취소 시맨틱, --preselect, --initial-index(기본값=커서), multi Space/a 토글**을 반드시 보존. `choose_menu`의 TTY/비TTY 이원화는 Node에선 `process.stdout.isTTY` + `--force` 판단 한 곳으로 수렴 가능 |
| **`src/core/detect.js`** | (c) 전부: detect_project_types(+classify_package_json, suggest_types_by_scan), detect_version, detect_default_branch, detect_repo_name, marker_for_type/existing_marker_in_dir/find_type_path_candidates, get/set_path_for_type | `PROJECT_PATHS_CSV`는 `Map<type,path>`로. version.yml 우선 감지(source of truth) 규칙 유지. `resolve_project_paths`는 감지(core)와 질문(UI)이 섞여 있으므로 **후보 산출은 detect.js, 질문 루프는 commands 측**으로 분리 권장 |
| **`src/core/assets.js`** | (d) download_template + (e) copy_workflows/_copy_workflows_for_type/_wf_is_unchanged, copy_scripts/config/issue/discussion/coderabbit/setup_guide/util_modules, ensure_gitignore(+normalize/check) | git clone 대신 **tarball 다운로드(codeload) or simple-git** 선택 필요. `_wf_is_unchanged`의 "가상 치환 후 비교"는 wizard-env 모듈의 순수 함수 호출로 재현 |
| **`src/core/exclusions.js`** | download_template 내부의 `docs_to_remove` + `plugin_items_to_remove` 배열 | 데이터 모듈로 독립 — CLAUDE.md의 "3곳 동시 수정" 규칙에서 이 파일이 sh/ps1과 함께 4번째 동기화 지점이 됨을 문서화 |
| **`src/core/version-yml.js`** | (f) create_version_yml, add_version_section_to_readme, read_template_options, save_template_options, get_current_template_version, update_version_yml_deploy | 현재는 grep/sed 수제 파싱(주석 보존 목적). Node에선 ①주석 포함 템플릿 문자열 재생성(현행과 동일 전략) ②comment 보존 YAML lib(yaml 패키지 Document API) 중 택1 — **①이 현행 출력과 diff 최소** |
| **`src/core/breaking.js`** | (g) compare_versions, check_breaking_changes | semver 패키지 + fetch로 단순화 (jq 의존 제거) |
| **`src/core/options.js`** | (h) ask_optional_workflow, ask_all_optional_workflows (+ INCLUDE_* 상태) | 폴더 스캔(core) / 질문(UI) 분리. eval 동적 변수 → 명시적 상태 객체 |
| **`src/core/wizard-env.js`** *(스펙에 없음 — 신설 강력 권장)* | (l) 27개 전부: resolver 5종, _kv_* 5종, wizard-prompts.yml 파서 4종, wf_deploy_*, _wf_set_env, wf_collect_asks 계열 7종, wf_prompt_env_plan, configure_workflow_env, _wf_is_unchanged(assets와 공유) | _kv_* 는 Node Map으로 소멸. wizard-prompts.yml 파서는 yaml lib로 대체. **_wf_set_env의 정규식 치환(값 치환 + @wizard 주석 제거)은 라인 단위 문자열 처리로 이식** — YAML 재직렬화 금지(포맷 변형 위험) |
| **`src/core/ide-skills.js`** *(스펙에 없음 — 신설 권장)* | (i) 29개 전부 | 외부 CLI(claude/gemini/codex/pi) `execa` 호출 래퍼 + PI settings.json은 임베디드 python 대신 **네이티브 JSON 조작**으로 단순화. `commands/skills.js`는 이 모듈의 라우터 UI만 담당 |
| **`src/commands/interactive.js`** | interactive_mode | 모드 메뉴 → 수집 → 확인 → 해당 command 위임 |
| **`src/commands/full.js`** | execute_integration의 full case 체인 | §2.2 순서 그대로 |
| **`src/commands/version.js`** | version case 체인 | §2.3 |
| **`src/commands/workflows.js`** | workflows case 체인 | §2.4 |
| **`src/commands/issues.js`** *(스펙에 없음 — 추가 필요)* | issues case 체인 | §2.5. 스펙 커맨드 목록에서 누락 |
| **`src/commands/skills.js`** | skills case + offer_ide_tools_install 라우터 | §2.6 |
| **`src/commands/revert.js`** | **대응 bash 코드 없음 — 신규 설계** | 후보 스펙: 통합 시 manifest(설치 파일 목록) 기록 → revert가 그것을 읽어 삭제/복원. 현행 .bak 파일 복원 + version.yml template 섹션 제거 정도가 최소 범위 |
| **`src/index.js` (또는 cli.js)** | main + top-level 인자 파싱 + trap cleanup | commander/yargs로 파싱. `cleanup_temp_dir` trap → `process.on('exit'/'SIGINT')` + finally |
| 공유 상태 | §3 전역 변수 | `context` 객체 하나로 명시화 권장: `{mode, force, types[], version, branch, paths:Map, includeNexus, includeSecretBackup, templateVersion, tempDir, deployValues:Map, counters}` — 함수 간 암묵 전역 의존을 끊는 것이 포팅의 절반 |

### 4.2 확인 화면/수정 메뉴의 위치

`detect_and_confirm_project` / `handle_project_edit_menu` / `print_project_analysis` / `show_project_type_menu`는 감지(core)와 UI가 얽힌 플로우 조정자다. → `src/commands/shared/confirm-project.js` (또는 `src/flows/confirm.js`)로 별도 배치해 interactive/full/version/workflows 커맨드가 공유하게 하는 것을 권장 (bash에서도 interactive·CLI 양쪽에서 재사용되고 있음).

### 4.3 포팅 난이도 상위 지점

1. **`interactive_menu` (273~510)** — 원시 ANSI 이스케이프(커서 앵커 ESC7/8, 스크롤 예약, raw 키 리딩, bash 3.2 타임아웃 우회)로 구현된 자체 TUI. Node에선 라이브러리로 대체하되 **ESC의 문맥별 의미(최상위=취소·stay / 하위=뒤로 / env계획=전부기본), preselect, initial-index(기본값 표현), multi 토글** 4가지 시맨틱 보존이 검증 포인트. 비TTY 폴백(legacy_numeric_menu)의 "읽기 불가 시 preselect/첫옵션 자동 선택"도 CI 경로에서 동작 동일성 필요.
2. **@wizard env 엔진 (2733~3393, 27함수)** — 마커 스캔 → resolver → prompts.yml 라벨 → 캐시(WF_DEPLOY_CSV) → sed 인플레이스 치환 → `_wf_is_unchanged`의 "가상 치환 결과와 바이트 비교"까지 이어지는 파이프라인. **YAML을 파싱하지 않고 텍스트로만 만지는 것이 의도된 설계**(포맷·주석 보존)이므로 Node에서도 라인 단위 문자열 변환으로 이식해야 한다. 치환 순서(ask/auto → 잔여 토큰 → paths-anchor)와 멱등성이 unchanged 판정의 전제.
3. **version.yml 수제 파서/작성기 (f 그룹 + read_template_options/get_current_template_version의 들여쓰기 기반 섹션 추적)** — 주석이 데이터인 파일. 재생성 전략(현행 heredoc과 동일한 템플릿 문자열)과 부분 수정 전략(save_template_options·update_version_yml_deploy의 sed)이 혼재한다. Node에서 하나의 정책(권장: 필드 보존 목록을 명시한 전체 재생성 + deploy/template 블록 병합)으로 통일하지 않으면 sh/ps1/js 3구현의 출력이 어긋난다.
4. (차점) **IDE Skills 계열** — 5개 외부 CLI의 실패 허용 오케스트레이션과 플랫폼별 경로(`~/.claude`, `~/.cursor`, `~/.agents`, `~/.pi`). 로직 자체는 단순하나 실기기 테스트 매트릭스가 크다. PI harness의 임베디드 python 3종은 Node 네이티브 JSON으로 대체하면 오히려 단순해진다.

### 4.4 bash 고유 함정 중 Node에서 소멸/잔존하는 것

| 항목 | Node에서 |
|---|---|
| `set -e` + 함수 끝 비-0 반환 함정 (`\|\| true` 가드 20여 곳) | 소멸 — 예외 기반으로 자연 해소. 단 "ESC=취소를 에러가 아닌 값으로" 설계할 것 |
| bash 3.2 연관배열 부재 (_kv_* 5종, CSV 인코딩 3종) | 소멸 — Map/객체로 대체. WF_DEPLOY_CSV·PROJECT_PATHS_CSV의 **version.yml 직렬화 포맷만 유지** |
| BSD/GNU sed·grep 차이 | 소멸 — 문자열 API로 대체 |
| /dev/tty 직접 읽기 (curl \| bash 대화형) | **잔존 주의** — `node <(curl …)`는 시나리오가 다름. npx 배포가 전제라면 stdin 파이프 이슈는 축소되지만, 비TTY 자동화 경로(--force)는 반드시 유지 |
| trap EXIT 임시폴더 정리 | process 이벤트 + try/finally로 재현 |

---

## 부록 A. 파일이 만들어내는 산출물 (포팅 검증 체크리스트)

| 산출물 | 생성 함수 | 모드 |
|---|---|---|
| `version.yml` (전체 재생성 + project_paths + metadata) | create_version_yml | full, version |
| `version.yml` metadata.template.options | save_template_options | full, workflows |
| `version.yml` deploy 블록 | update_version_yml_deploy | full, workflows |
| `README.md` AUTO-VERSION-SECTION | add_version_section_to_readme | full, version |
| `.github/workflows/*.yaml` (+.bak/.template.yaml) | copy_workflows 계열 | full, workflows |
| `.github/scripts/{version_manager.sh,changelog_manager.py}` | copy_scripts | full, version, workflows |
| `.github/config/*` | copy_config_folder | full, version, workflows |
| `.github/ISSUE_TEMPLATE/*`, `PULL_REQUEST_TEMPLATE.md` | copy_issue_templates | full, issues |
| `.github/DISCUSSION_TEMPLATE/*` | copy_discussion_templates | full, issues |
| `.coderabbit.yaml` (+.bak) | copy_coderabbit_config | full |
| `.gitignore` 필수 항목 | ensure_gitignore | full, version |
| `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md` | copy_setup_guide | full, version, workflows |
| `.github/util/{type}/*` | copy_util_modules | full, workflows |
| `~/.cursor/skills/*` + cursor-skills-meta.json | _do_cursor_skills_copy | (IDE) |
| `~/.pi/agent/settings.json` extensions | _pi_harness_add/remove | (IDE) |
