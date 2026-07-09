# projectops SP2 — 마법사 Node.js 포팅 함수 매핑 — HOW 계획

> **[역사 기록]** 이 분석과 병행된 다른 세션의 구현(v4.0.x)이 먼저 배포되었다. 함수 인벤토리·등가성 계약은 그대로 유효하나,
> 일부 결정은 실구현과 다르다: C3/C4(자산 번들)는 **git clone 유지(D7)** 로, @clack/prompts는 **자체 readline 엔진**으로 대체됨.
> 이 문서의 §2 함수 매핑표는 이후 등가성 감사(버그 A1~A3 발견)의 기준 자료로 사용되었다.

작성일: 2026-07-07
참조: docs/suh-template/plan/20260707_001_projectops_rebranding_and_npm_publish.md
설계 문서: docs/superpowers/specs/2026-07-07-projectops-npx-migration-design.md (§3 SP2)
GitHub 이슈: #424

> **목적**: `template_integrator.sh`(5,660줄, 함수 130개) / `template_integrator.ps1`(5,127줄, 함수 120개)를
> 단일 Node.js ESM CLI(`npx projectops`)로 완전 포팅하기 위한 함수→모듈 매핑과 구현 태스크 정의.
> 분석 근거: 두 스크립트 전 구간을 7개 병렬 정찰로 실측 (라인 번호 전부 실측 인용).

---

## 0. 설계 문서 대비 확정/보정 사항

| # | 항목 | 설계 문서(§3) | 실측 결과 → 확정 |
|---|------|--------------|----------------|
| C1 | 모드 목록 | interactive/full/version/workflows/skills + revert | **실제 .sh 모드는 6종: `full/version/workflows/issues/skills/interactive`** (`show_help` L735, `interactive_mode` L4320~4326, `execute_integration` L4501~4545). 독립 `revert` 모드는 존재하지 않음 — "제거"는 skills 모드 내 IDE 도구 2단계 라우터(설치/제거/건너뛰기, L4686~4738)의 한 갈래다. → `commands/issues.js`를 추가하고 `revert.js`는 만들지 않는다 (등가성 우선). |
| C2 | npm 번들 화이트리스트 | bin/, src/, .github/workflows/, .github/scripts/, .github/ISSUE_TEMPLATE/, .github/config/, .github/util/, .github/PULL_REQUEST_TEMPLATE.md | 실측 복사 대상에 **`.github/DISCUSSION_TEMPLATE/`(L3895), 루트 `.coderabbit.yaml`(L3938), 루트 `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md`(L4114)** 가 추가로 존재 → files에 3항목 추가 필수. |
| C3 | skills/ 번들 여부 | 누출 금지 목록에 skills/ 포함 | **Cursor 스킬 설치가 `$TEMP_DIR/skills` → 로컬 `skills/` 순으로 원본을 찾음** (L4856~4858). git clone을 없애면 공급원이 사라진다. → **skills/(528K, gzip 후 ~150K)를 번들에 포함** 권장. pi harness는 pi가 레포를 자체 clone하므로 harness/ 번들 불필요. (대안은 §8 참조) |
| C4 | 자산 공급 | 패키지 번들 | `download_template`(L2064, git clone --depth 1) + `plugin_items_to_remove` TEMP_DIR 정리(L2100~2112) **전체를 제거**. npm files 화이트리스트가 복사원 필터를 대체하므로 Node CLI에 TEMP_DIR 개념 자체가 없다. |
| C5 | 의존성 | @clack/prompts, picocolors, yaml | 유지. 단 semver 비교는 `compare_versions`(L2475, 3자리 숫자 비교)가 단순해 의존성 없이 인라인 구현. |

---

## 1. 변경 파일 목록

| # | 파일 | 함수/위치 | 무엇을 | 실행 순서 |
|---|------|----------|--------|---------|
| 1 | `package.json` | `files`(L33~35), `dependencies`(신설) | files 확장 + deps 3종 추가 | 순차 (T1) |
| 2 | `.gitignore` | 끝부분(L~44) | `node_modules/` 추가 | 순차 (T1) |
| 3 | `src/core/context.js` | 신규 | 전역 상태 컨텍스트 (MODE·PROJECT_TYPES·flags·counters) | 순차 (T1) |
| 4 | `src/ui/output.js` | 신규 | print_* 계열 (L160~230, L1692~1720, L5438~5625) | 순차 (T1) |
| 5 | `src/ui/prompts.js` | 신규 | TTY 감지·메뉴·입력 (L80~732) | 순차 (T1) |
| 6 | `src/core/exec.js` | 신규 | 외부 명령 spawnSync 래퍼 (git/claude/gemini/codex/pi) | 순차 (T1) |
| 7 | `src/core/detect.js` | 신규 | 타입/버전/브랜치 감지 (L923~1180, L1592~1689) | [병렬] (T2) |
| 8 | `src/core/paths.js` | 신규 | 모노레포 project_paths (L1182~1589) | [병렬] (T2) |
| 9 | `src/core/assets.js` | 신규 | 번들 자산 경로 해석 — download_template(L2064) 대체 | [병렬] (T3) |
| 10 | `src/core/exclusions.js` | 신규 | 복사 제외 단일 소스 (integrator L2100~2112 이관) | [병렬] (T3) |
| 11 | `src/core/version-yml.js` | 신규 | version.yml 생성/README 섹션/deploy 블록 (L2145~2354, L2619, L3016~3053) | [병렬] (T4) |
| 11-1 | `src/core/options.js` | 신규 | 템플릿 옵션 읽기/저장 + 선택 워크플로우 질문 (L2361~2472, L2650~2749 — 설계 §3의 options.js 복원) | [병렬] (T4) |
| 12 | `src/core/breaking.js` | 신규 | semver 비교 + breaking changes (L2475~2616) | [병렬] (T4) |
| 13 | `src/core/wizard-env.js` | 신규 | @wizard 시스템 전체 (L2751~3397) | [병렬] (T5) |
| 14 | `src/core/copier.js` | 신규 | 복사 엔진 (L3398~3914, L3938~3991, L4114~4259) | 순차 (T6, T3·T5 의존) |
| 15 | `src/core/gitignore.js` | 신규 | .gitignore 보장 (L3996~4111) | [병렬] (T6) |
| 16 | `src/core/ide-tools.js` | 신규 | 5개 도구 설치/제거/감지 (L4575~5435) | [병렬] (T7) |
| 17 | `src/commands/skills.js` | 신규 | IDE 도구 2단계 라우터 (L4668~4747) | 순차 (T7) |
| 18 | `src/commands/interactive.js` | 신규 | 대화형 메인 메뉴 (L4263~4411) | 순차 (T8) |
| 19 | `src/commands/integrate.js` | 신규 | execute_integration 오케스트레이션 (L4414~4565) | 순차 (T8) |
| 20 | `src/index.js` | 신규 | argv 파싱(L827~920) + main(L5628~5655) 라우팅 | 순차 (T8) |
| 21 | `bin/projectops.js` | 전체 교체 (현 L1~45 스텁) | src/index.js 위임 | 순차 (T9) |
| 22 | `.github/scripts/template_initializer.sh` | `cleanup_template_files()` L478~491 인근 | `package-lock.json`·`test/` 삭제 블록 추가 | [병렬] (T9) |
| 23 | `template_integrator.sh` | `plugin_items_to_remove` L2100~2112 + 파일 상단 L1~10 | 배열에 `package-lock.json`·`test` 추가 + deprecated 배너 | [병렬] (T9) |
| 24 | `template_integrator.ps1` | `$pluginItemsToRemove` 대응 배열 + 파일 상단 | 동일 2건 (ps1 대칭) | [병렬] (T9) |
| 25 | `test/*.test.js` | 신규 (root `test/` 폴더) | node:test 단위테스트 + npm pack 누출 검사 | 순차 (T10) |

---

## 2. 함수 매핑표 (130개 전수 — 모듈별 그룹)

> 라인 번호는 `template_integrator.sh` 실측. ps1 대응 함수는 로직 동일(§2.9 델타만 별도 처리).

### 2.1 → `src/ui/prompts.js` (터미널·입력·메뉴 — 20개)

| .sh 함수 (라인) | Node 함수 | 포팅 노트 |
|---|---|---|
| `detect_terminal`(80) | `detectTerminal()` | `process.stdin.isTTY` + Win에선 `/dev/tty` 개념 부재 → stdin.isTTY/stdout.isTTY 기준. STDIN_MODE/TTY_AVAILABLE → context 필드 |
| `safe_read`(231) | `input(prompt, {default})` | @clack/prompts `text()`. `/dev/tty` 직접 읽기·`read -e` readline 대체. ESC=취소는 clack `isCancel`로 오히려 개선 |
| `interactive_menu`(273) | `menu(prompt, options, {multi, preselect, cancelLabel, initialIndex})` | @clack/prompts `select`/`multiselect` 래핑. .sh의 숫자점프(1~9)·a토글은 clack 미지원 — UX 등가는 화살표+Space+Enter+ESC로 충족(§8 REVIEW_LOG-3) |
| `legacy_numeric_menu`(516) | `numericMenu(...)` (동일 시그니처) | 비TTY fallback. stdin readline로 숫자 입력. CI 환경 대비 유지 필수 |
| `choose_menu`(629) | `chooseMenu(...)` | `isTTY(stdin) && isTTY(stderr)` 분기 (L630 실측: TTY_AVAILABLE && -t 2) |
| `ask_yes_no`(639) | `askYesNo(prompt, defaultYes)` | TTY+비FORCE → menu, 그 외 1자 입력 루프 (L642~687 등가) |
| `ask_yes_no_edit`(691) | `askYesNoEdit()` | 'yes'/'no'/'edit' 문자열 반환 |
| `print_*` 7종(178~230), `safe_echo*`(160~176), `get_output_target`(144), `print_to_user`(261), `print_separator_line`(1692), `print_section_header`(1698), `print_question_header`(1710) | → `src/ui/output.js`의 `printInfo/printSuccess/printWarning/printError/printStep/printQuestion/printHeader/printBanner/separator/sectionHeader/questionHeader` | 전부 stderr 출력 유지 (stdout은 메뉴 반환값 전용이던 .sh 관례 → Node에선 반환값이 함수 리턴이므로 stderr 고정만 유지). 색상은 picocolors |
| `cleanup_temp_dir`(118) | 삭제 | TEMP_DIR 자체가 사라짐 (C4) |
| `show_help`(735) | `printHelp()` (src/index.js) | 텍스트 그대로 이식, npx 사용례로 갱신 |

### 2.2 → `src/core/detect.js` (감지 — 7개)

| .sh 함수 (라인) | Node 함수 | 포팅 노트 |
|---|---|---|
| `detect_project_type`(923) | `detectPrimaryType(dir)` | 우선순위 flutter→spring→python→RN→next→react→node→basic 고정 |
| `classify_package_json`(1005) | `classifyPackageJson(file)` | grep 순서 보존: expo→react-native→next→react→node. JSON.parse 아닌 **문자열 포함 검사 유지**(주석 포함 package.json 방어, .sh와 동일 판정) |
| `detect_project_types`(1035) | `detectProjectTypes(dir)` | version.yml(project_types) 최우선 → 마커 스캔. yq 의존 제거: `yaml` 패키지 |
| `suggest_types_by_scan`(1116) | `suggestTypesByScan(dir)` | basic일 때 추천. 마커→확장자 2단계 + 메뉴순 정렬 |
| `_mode_display_label`(1024) | `modeDisplayLabel(mode)` | 정적 매핑 |
| `detect_version`(1592) | `detectVersion(types, paths)` | 체인: package.json(JSON.parse)→build.gradle(정규식 `/version\s*=\s*['"]?(\d+\.\d+\.\d+)/`)→pubspec(`/^version:\s*(\d+\.\d+\.\d+)/m`)→pyproject→git tag→`"0.0.1"` |
| `detect_default_branch`(1661) | `detectDefaultBranch()` | gh api 시도 제거하고 `git symbolic-ref refs/remotes/origin/HEAD`→`git remote show origin`→`"main"` (gh CLI 의존 삭제 — CLAUDE.md gh 금지 규칙 정합) |

### 2.3 → `src/core/paths.js` (모노레포 경로 — 7개)

| .sh 함수 (라인) | Node 함수 | 포팅 노트 |
|---|---|---|
| `get_path_for_type`(1182) / `set_path_for_type`(1199) | `Map` 접근자 `paths.get(type)` / `paths.set(type, p)` | PROJECT_PATHS_CSV(문자열 KV) → `Map<string,string>` |
| `marker_for_type`(1220) | `markerForType(type)` | 정적 매핑 (spring→build.gradle 등) |
| `existing_marker_in_dir`(1232) | `existingMarkerInDir(type, dir)` | 보조마커: spring(build.gradle/.kts/pom.xml), python(pyproject/setup.py/requirements.txt) |
| `find_type_path_candidates`(1249) | `findTypePathCandidates(type)` | maxdepth 3 재귀 스캔. Spring settings.gradle 루트 축약(L1255~1268), flutter example/ 제외(L1300), spring android/ 제외(L1305) 규칙 보존 |
| `load_saved_project_paths`(1316) | `loadSavedProjectPaths(ctx)` | version.yml project_paths 로드, 반환 bool(질문 필요 여부) |
| `resolve_project_paths`(1362) | `resolveProjectPaths(ctx)` | 5단계 우선순위 보존: ①--paths ②루트마커 ③기존값 ④후보 ⑤대화형/비대화형. 경로 정규화(`\\`→`/`, 끝`/`·앞`./` 제거, 빈값→`.`) 동일 |

### 2.4 → `src/core/version-yml.js` (4개) + `src/core/options.js` (4개) + `src/core/breaking.js` (2개)

> 옵션 관련 4개(read/save_template_options, ask_optional_workflow, ask_all_optional_workflows)는
> 설계 문서 §3의 `core/options.js`대로 분리한다. `askAllOptionalWorkflows(ctx, forceAsk)`는
> opt-in 폴더(spring/nexus, common/secret-backup)를 번들 자산에서 스캔한다 (TEMP_DIR 인자 소멸).

| .sh 함수 (라인) | Node 함수 | 포팅 노트 |
|---|---|---|
| `create_version_yml`(2184) | `createVersionYml(ctx)` | **주석 헤더 포함 텍스트 템플릿으로 생성** (yaml dump는 주석 소실 — 기존 .sh heredoc과 바이트 등가 목표). 기존 파일의 `version`·`version_code` 보존(L2208~2239), TTY 덮어쓰기 확인(L2241~2274), project_paths 블록+마커 주석(L2277~2294) |
| `read_template_options`(2361) | `readTemplateOptions()` | yaml 파싱으로 `metadata.template.options.{nexus,secret_backup}` 읽기 (상태머신 파서 대체) |
| `save_template_options`(2419) | `saveTemplateOptions(templateVersion)` | 텍스트 수술 유지(기존 키 치환/블록 append). 미설정 → false 보정(L2425~2426) |
| `get_current_template_version`(2619) | `getCurrentTemplateVersion()` | `metadata.template.version` 조회, 없으면 "unknown" |
| `update_version_yml_deploy`(3016) | `updateVersionYmlDeploy(deployMap)` | 기존 `deploy:` 블록 제거 후 타입별 정렬 재생성 (멱등) |
| `compare_versions`(2475) | `compareVersions(a, b)` → breaking.js | v접두 제거, 3자리 숫자비교, 누락=0. 반환 1/-1/0 |
| `check_breaking_changes`(2506) | `checkBreakingChanges(cur, next, ctx)` → breaking.js | fetch(`{RAW_URL}/.github/config/breaking-changes.json`) → 실패 시 **번들본 fallback**(설계 D2). jq 의존 소멸. `cur < ver <= next` 필터, critical→Y/N 게이트(기본 N) |

### 2.5 → `src/core/wizard-env.js` (@wizard 시스템 — 29개)

| .sh 함수 (라인) | Node 함수 | 포팅 노트 |
|---|---|---|
| `_kv_enc/_kv_set/_kv_get/_kv_has/_kv_clear`(2831~2894) | **삭제 — `Map`으로 대체** | 이슈 #418의 bash 3.2 편법 전체 소멸. 키 형식 `"type|KEY"` 문자열 그대로 Map 키 사용 |
| `detect_repo_name`(2751)/`resolve_repo`(2764) | `resolveRepo()` | git remote URL 파싱 → 실패 시 `basename(cwd)` |
| `resolve_spring_app_yml_dir/path`(2766/2775) | `resolveSpringAppYml{Dir,Path}(type)` | find 기반 → fs 재귀 |
| `resolve_flutter_root`(2783) | `resolveFlutterRoot()` | paths.get('flutter') ?? '.' |
| `resolve_token`(2790) | `resolveToken(type, name)` | 4종: repo/spring-app-yml-dir/spring-app-yml-path/flutter-root. 미정의→"" |
| `_wf_labels_path`(2808) | `wizardPromptsPath()` | 대상 프로젝트 `.github/config/wizard-prompts.yml` → **번들 자산 fallback** (TEMP_DIR fallback 대체) |
| `_wf_load_workflow_names`(2895)/`wf_workflow_name`(2917) | `workflowDisplayName(file)` | `_workflow_names` 블록 캐시. 최장 키 매칭 |
| `_wf_read_field`(2934)/`wf_field`(2962) | `wfField(type, key, field)` | 우선순위 `{type}.KEY`→`KEY`→구형 1줄→폴백. yaml 파싱으로 단순화 |
| `wf_deploy_get/set`(2972/2987) | `deployMap` Map 접근 | CSV(`type|KEY=val;...`) → `Map<"type|KEY", val>` |
| `_wf_set_env`(3004) | `setEnvInFile(file, key, value)` | 정규식 치환: `KEY: "..."` 값 교체 + `# @wizard ...` 주석 제거 (sed -i.wftmp → 문자열 replace 후 writeFile) |
| `wf_scope_string`(3059)/`_wf_first_type_for`(3145) | `scopeString(usages)` / `firstTypeFor(key)` | 단일타입→"타입 name·name", 복수→"타입1·타입2" |
| `wf_collect_asks`(3087) | `collectAsks(types)` | 번들 워크플로우에서 `# @wizard ask:` 라인 수집 → `{keys, defaults, scopes, files}` |
| `_wf_print_field_card`(3152) | `printFieldCard(key, idx, tot)` | label/사용처/help/example/기본값 카드 |
| `_wf_prefill_all`(3171)/`_wf_prefill_interactive`(3187) | `prefillAll()` / `prefillInteractive(keys)` | 타입별 기본값 우선 → 공통 폴백 |
| `wf_prompt_env_plan`(3220) | `promptEnvPlan(types)` | 3모드: 전부기본/하나씩/고르기. copy_workflows 진입 시 1회 호출 계약 유지 |
| `configure_workflow_env`(3282) | `configureWorkflowEnv(type, file)` | 마커 파싱(`^[A-Z_]+:` + `@wizard (ask|auto):(.*)$`) → ask(resolver/리터럴 기본값, 재실행 시 deployMap 우선) / auto(resolveToken) → 치환 → `__PROJECT_NAME__`/`__APP_ARTIFACT_NAME__` 재귀 치환 → `# @wizard paths-anchor`에 paths 필터 주입 → 미치환 `__[A-Z_]+__` 경고 |
| `_wf_is_unchanged`(3376) | `isWorkflowUnchanged(type, srcFile, destFile)` | **가상 치환 후 내용 비교**. CRLF 정규화(`\r\n`→`\n`) 필수 — ps1 실측 L2841~2842와 동일 처리 |

### 2.6 → `src/core/copier.js` (복사 엔진 — 16개) + `src/core/gitignore.js` (3개)

| .sh 함수 (라인) | Node 함수 | 포팅 노트 |
|---|---|---|
| `_copy_workflows_for_type`(3398) | `copyWorkflowsForType(type)` | 3분류(신규 즉시복사/동일 조용히 스킵/기존 3지선 메뉴: .template.yaml 추가·스킵(기본)·.bak 백업 후 교체, ESC→스킵). server-deploy/: `INCLUDE_NEXUS=true`면 폴더째 제외(L3520~3528). nexus/: true일 때만 포함(L3618~3650). env 적용은 복사 완료 후 **일괄**(L3652~3671) |
| `_contains_type`(3675) | `types.includes(t)` | 인라인 |
| `copy_workflows`(3683) | `copyWorkflows(ctx)` | 순서: common(항상 최신, 동일 시 스킵) → `promptEnvPlan()` 1회 → 타입별 → secret-backup(opt-in, 기존 있으면 스킵) → 요약+멀티타입 paths 필터 경고(L3797~3801) |
| `copy_scripts`(3818) | `copyScripts()` | version_manager.sh + changelog_manager.py 2개 고정, `fs.chmodSync(0o755)` |
| `copy_config_folder`(3845) | `copyConfigFolder()` | .github/config/ 재귀, 무확인 덮어쓰기 |
| `copy_issue_templates`(3872)/`copy_discussion_templates`(3895) | `copyIssueTemplates()` / `copyDiscussionTemplates()` | ISSUE_TEMPLATE/ + PULL_REQUEST_TEMPLATE.md / DISCUSSION_TEMPLATE/ |
| `show_coderabbit_intro`(3919)/`copy_coderabbit_config`(3938) | `copyCoderabbitConfig(ctx)` | 기존 파일 시 3지선(덮어쓰기/건너뛰기/백업 후 교체) |
| `copy_setup_guide`(4114) | `copySetupGuide()` | SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 무확인 최신화 |
| `show_util_module_description`(4137)/`show_util_usage_guide`(4173)/`copy_util_modules`(4203) | `copyUtilModules(type, ctx)` | .github/util/{type}/ 재귀 + flutter 전용 안내. UTIL_MODULES_COPIED 카운터 |
| `normalize_gitignore_entry`(3996)/`check_gitignore_entry_exists`(4017)/`ensure_gitignore`(4048) | → gitignore.js `ensureGitignore()` | 필수 2항목 `/.idea`, `/.claude/settings.local.json`. 정규화(주석·공백·앞뒤`/`·`./` 제거) 비교 후 누락만 추가 |

### 2.7 → `src/core/ide-tools.js` (IDE 도구 — 29개) + `src/commands/skills.js`

| .sh 함수 (라인) | Node 함수 | 포팅 노트 |
|---|---|---|
| `offer_ide_tools_install`(4575) | skills.js `offerIdeTools(ctx)` | 1단계 상태표시 → 2단계 동작선택(설치·업데이트/제거/그대로, ESC→skip) → 3단계 IDE 멀티선택 → 도구별 실행. 비TTY/FORCE → 순차 자동(L4742~4747) |
| `_manage_claude_section`(4751)/`_do_claude_plugin_install`(4978)/`_remove_claude_section`(4883)/`_remove_claude_plugin_data`(4999) | `claude.{status,install,update,remove}()` | `claude plugin marketplace add Cassiiopeia/projectops` → `claude plugin install/update cassiiopeia@cassiiopeia-marketplace --scope {user\|project}` → uninstall + `~/.claude/plugins/data/...` 삭제. **config 마이그레이션**(L4769~4782): update 후 구캐시 config.json 복사 — ps1 `Invoke-ConfigMigration`(ps1 L4434)과 통합, semver 정렬로 최신 구버전 탐색 |
| `_manage_cursor_section`(4850)/`_do_cursor_skills_copy`(5048)/`_write_cursor_skills_meta`(5015)/`_remove_cursor_section`(4902) | `cursor.{status,install,remove}()` | 원본: **번들 skills/** (C3). 대상 `~/.cursor/skills/`. 메타 `cursor-skills-meta.json`{name,version,scope,source,installPath,installedAt(보존),lastUpdated} |
| `_manage_gemini_extension`(5067)/`_remove_gemini_section`(4918) | `gemini.{install,remove}()` | `gemini extensions update cassiiopeia` 실패 시 `install https://github.com/Cassiiopeia/projectops` |
| `_manage_codex_skills`(5097)/`_do_codex_marketplace_register`(5112)/`_do_codex_native_skills_fallback`(5130)/`_remove_codex_section`(4932) | `codex.{install,remove}()` | marketplace add→upgrade. native fallback(git clone+symlink)은 .sh에서도 미호출 — **포팅 제외**, remove의 `~/.agents/skills/cassiiopeia` 삭제만 유지 |
| `_pi_python`(5197) | **삭제** | settings.json 조작을 Node 네이티브 JSON으로 — Python 의존 소멸 |
| `_pi_is_installed`(5211)/`_pi_clone_dir`(5222)/`_pi_harness_loader_path`(5232)/`_pi_settings_path`(5235)/`_pi_harness_enabled`(5240)/`_pi_harness_add`(5259)/`_pi_harness_remove`(5295)/`_pi_harness_offer`(5322)/`_pi_harness_print_desc`(5352)/`_pi_harness_toggle`(5362)/`_pi_harness_remove_only`(5394)/`_manage_pi_section`(5405)/`_remove_pi_section`(4949) | `pi.*` 네임스페이스 | `pi list` 패턴 매칭(구명 SUH-DEVOPS-TEMPLATE 포함), clone 경로 신규→구 fallback(L5224~5227), `~/.pi/agent/settings.json` extensions 배열 직접 조작(JSON.parse/stringify), update→install fallback, remove 시 harness 동반 해제(L4970) |

### 2.8 → `src/commands/*.js` + `src/index.js` (오케스트레이션 — 5개)

| .sh 함수 (라인) | Node 위치 | 포팅 노트 |
|---|---|---|
| 인자 파싱(827~920) | `src/index.js` `parseArgs(argv)` | 수동 파싱 (의존성 불필요). 플래그 전수: `-m/--mode`, `-v/--version`, `-t/--type`(csv, VALID_TYPES 검증+dedup+빈배열 에러), `--paths`, `--force`, `--nexus/--no-nexus`, `--secret-backup/--no-secret-backup`, `-h/--help`, 미지원→에러+help+exit 1. **`--no-backup`은 .sh 도움말에만 있고 파서에 없음(L843~920 실측) — 포팅 제외** |
| `interactive_mode`(4263) | `commands/interactive.js` | 6항목 메뉴(전체/버전만/워크플로우만/이슈템플릿만/AI스킬만/취소, ESC→취소). 모드별 수집 매트릭스: skills·issues는 수집 생략, full·version·workflows는 감지→(full·workflows)옵션질문→(full·version)경로로드→확인화면→경로질문 |
| `execute_integration`(4414) | `commands/integrate.js` | breaking 확인 → CLI모드 감지·확인 → 모드별 시퀀스(§표) → save_template_options(full·workflows) → offerIdeTools(skills 외) → summary |
| `main`(5628) | `src/index.js` `main()` | detectTerminal → git 저장소 경고 → interactive면 메뉴 → integrate |
| `print_summary`(5438) | `ui/output.js` `printSummary(ctx)` | 모드별 요약 + 복사 워크플로우 분류(공통/타입별/기존유지) + 필수 3작업 안내 |

**모드별 실행 시퀀스 (execute_integration L4501~4545 실측 — 등가성 계약)**:

| 모드 | 시퀀스 |
|---|---|
| full | createVersionYml → addVersionSectionToReadme → copyWorkflows → updateVersionYmlDeploy → copyScripts → copyConfigFolder → copyUtilModules(타입 순회) → copyIssueTemplates → copyDiscussionTemplates → copyCoderabbitConfig → ensureGitignore → copySetupGuide |
| version | createVersionYml → addVersionSectionToReadme → copyScripts → copyConfigFolder → ensureGitignore → copySetupGuide |
| workflows | copyWorkflows → updateVersionYmlDeploy → copyScripts → copyConfigFolder → copyUtilModules → copySetupGuide |
| issues | copyIssueTemplates → copyDiscussionTemplates |
| skills | offerIdeTools → summary → return |

### 2.9 ps1 델타 → Node 처리 (별도 함수 아닌 횡단 관심사)

| ps1 전용 (라인) | Node 처리 |
|---|---|
| `Read-SingleKey`(270)/`Test-ArrowMenuSupported`(314)/VT 활성화 P/Invoke(341~349) | @clack/prompts가 Win 콘솔 raw mode·ANSI 자체 처리 — 코드 불필요 |
| `Invoke-ConfigMigration`(4434) | ide-tools.js claude 네임스페이스에 통합 (§2.7). `os.homedir()` 단일 경로 |
| `Test-PiCli`(4723) | exec.js `commandExists(cmd)` — `spawnSync(cmd, ['--version'])` status 체크 (Win Store python stub 같은 가짜 실행파일 방어 패턴 일반화) |
| CRLF 정규화(2841~2842)/UTF-8 BOM | 파일 비교 시 `\r\n`→`\n` 정규화, 쓰기는 항상 BOM 없는 UTF-8 LF |
| `-Mode`(param 블록 L59~91) | .sh 플래그 문법만 지원 (단일 CLI가 되므로 ps1식 `-Mode` 별칭 불필요) |

---

## 3. 태스크별 상세

### Task 1: 기반 — package.json·.gitignore·context·ui·exec [T1, 순차]

**파일**: `package.json`
**위치**: `files`(L33~35) / 최하단 `pi` 필드 뒤
**변경 이유**: 자산 번들(D2) + 런타임 의존성

**Before** (실측 L33~41):
```json
  "files": [
    "bin/"
  ],
  "pi": {
    "skills": [
      "./skills"
    ]
  }
```

**After**:
```json
  "files": [
    "bin/",
    "src/",
    "skills/",
    ".github/workflows/",
    ".github/scripts/",
    ".github/ISSUE_TEMPLATE/",
    ".github/DISCUSSION_TEMPLATE/",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/config/",
    ".github/util/",
    ".coderabbit.yaml",
    "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
  ],
  "dependencies": {
    "@clack/prompts": "^0.11.0",
    "picocolors": "^1.1.0",
    "yaml": "^2.6.0"
  },
  "pi": {
    "skills": [
      "./skills"
    ]
  }
```

**파일**: `.gitignore` — 끝에 추가:

**Before** (실측 tail):
```
# CodeGraph 로컬 인덱스 (SQLite 지식 그래프)
.codegraph/
```

**After**:
```
# CodeGraph 로컬 인덱스 (SQLite 지식 그래프)
.codegraph/

# Node.js (projectops CLI 개발)
node_modules/
```

**신규**: `src/core/context.js` — 전역 상태를 단일 객체로:
```js
// 마법사 전역 상태 — .sh의 전역변수 군을 단일 컨텍스트로 통합
export function createContext() {
  return {
    mode: 'interactive',            // MODE
    version: '',                    // VERSION (감지/지정)
    projectTypes: [],               // PROJECT_TYPES 배열
    projectPaths: new Map(),        // PROJECT_PATHS_CSV → Map<type, path>
    detectedBranch: '',             // DETECTED_BRANCH
    forceMode: false,               // FORCE_MODE
    includeNexus: null,             // INCLUDE_NEXUS tri-state("",true,false → null|bool)
    includeSecretBackup: null,      // INCLUDE_SECRET_BACKUP
    ttyAvailable: process.stdin.isTTY === true && process.stderr.isTTY === true,
    stdinMode: process.stdin.isTTY !== true,
    deployMap: new Map(),           // WF_DEPLOY_CSV → Map<"type|KEY", value>
    useDefaults: null,              // WF_USE_DEFAULTS
    counters: { workflows: 0, utilModules: 0, skipped: 0, templateAdded: 0 },
  };
}
```

**신규**: `src/core/exec.js`:
```js
import { spawnSync } from 'node:child_process';
// 외부 CLI 존재+실행 확인 (Win Store stub 방어: 실제 실행 결과로 판정)
export function commandExists(cmd, args = ['--version']) { /* spawnSync status===0 */ }
export function run(cmd, args, opts = {}) { /* spawnSync 래핑, {status, stdout, stderr} 반환 */ }
```

**검증**: `npm install && node -e "import('./src/core/context.js').then(m=>console.log(m.createContext().mode))"` → `interactive`

---

### Task 2: detect.js + paths.js [병렬 가능 (T1 후)]

**신규**: `src/core/detect.js`, `src/core/paths.js` — §2.2·§2.3 매핑표 전 함수. 시그니처 예:
```js
// detect.js
export function detectProjectTypes(dir = '.') {}   // → string[] (version.yml 우선)
export function classifyPackageJson(file) {}       // → 'react-native-expo'|'react-native'|'next'|'react'|'node'|''
export function detectVersion(ctx) {}              // → 'x.y.z' | '0.0.1'
export function detectDefaultBranch() {}           // → 'main' 등
// paths.js
export function resolveProjectPaths(ctx, ui) {}    // 5단계 우선순위, ctx.projectPaths 확정
export function findTypePathCandidates(type) {}    // → string[] (maxdepth 3)
```

**검증**: `node --test test/detect.test.js` — 픽스처 디렉토리(spring/flutter/react 마커)로 감지 결과 assert. 파괴 케이스: 마커 없는 빈 폴더 → `['basic']`, expo+react-native 동시 → `react-native-expo`.

---

### Task 3: assets.js + exclusions.js [병렬]

**신규**: `src/core/assets.js`:
```js
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
// 패키지 루트 = src/core/assets.js 기준 2단계 상위 (bin/·src/ 구조 고정)
const PKG_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
export function assetPath(...seg) { return join(PKG_ROOT, ...seg); }
export function workflowsSourceDir() { return assetPath('.github', 'workflows', 'project-types'); }
export function templateVersion() { /* PKG_ROOT/version.yml 의 version — 번들 기준 단일 진실 */ }
```

**신규**: `src/core/exclusions.js` — integrator L2100~2112 배열을 데이터로 이관:
```js
// 사용자 프로젝트로 절대 복사되면 안 되는 항목 (구 plugin_items_to_remove 단일 소스)
// npm files 화이트리스트가 1차 필터, 이 목록은 복사 시 2차 방어 + 누출 테스트 기준
export const NEVER_COPY = [
  '.claude-plugin', '.codex-plugin', '.agents', '.cursor',
  'scripts', 'package.json', 'package-lock.json', 'harness', 'bin', 'src', 'test',
  '.github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml',
  '.github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml',
];
```

**검증**: `node -e` 로 `templateVersion()` === version.yml 값. `npm pack --dry-run` 출력에 `skills/` 포함·`docs/`·`harness/`·`.claude-plugin/` 미포함.

---

### Task 4: version-yml.js + breaking.js [병렬]

§2.4 매핑. 핵심 계약 — 생성 파일이 .sh 산출물과 **텍스트 등가**여야 E2E diff 0 달성:
- 주석 헤더·키 순서·들여쓰기(2칸)·`project_paths` 마커 주석(`spring: "."   # build.gradle`) 재현
- `deploy:` 블록 멱등 재생성(기존 블록 제거 후)

**검증**: 픽스처로 .sh `create_version_yml` 산출물과 `diff` — 공백·주석 포함 일치. 파괴 케이스: 기존 version.yml에 `version_code: 380` 있을 때 보존되는지, 잘못된 `version_code: abc` → 1로 폴백.

---

### Task 5: wizard-env.js [병렬]

§2.5 매핑. 마커 문법 계약(실측):
```yaml
PROJECT_NAME: "__PROJECT_NAME__"  # @wizard ask:@repo
DEPLOY_PORT: "__DEPLOY_PORT__"    # @wizard ask:8000
FLUTTER_ROOT: "."                 # @wizard auto:flutter-root
    # @wizard paths-anchor
```
resolver 4종(@repo/@spring-app-yml-dir/@spring-app-yml-path/@flutter-root), wizard-prompts.yml 조회 우선순위(`{type}.KEY`→`KEY`→구형 1줄→label이면 KEY명).

**검증**: `node --test test/wizard-env.test.js` — 실제 `.github/workflows/project-types/python/PROJECT-PYTHON-SIMPLE-CICD.yaml` 픽스처로 collectAsks 키 6종 전부 수집(#418 회귀 테스트), configureWorkflowEnv 후 `__[A-Z_]+__` 잔존 0. 파괴 케이스: 미정의 resolver `@unknown` → "" + 경고.

---

### Task 6: copier.js + gitignore.js [T3·T5 의존]

§2.6 매핑. 3분류(신규/동일/기존) 판정에 `isWorkflowUnchanged`(가상 치환+CRLF 정규화) 사용. server-deploy/nexus 규칙:
```
INCLUDE_NEXUS=true  → {type}/server-deploy/ 폴더째 제외, {type}/nexus/ 포함
INCLUDE_NEXUS=false → server-deploy/ 3분류 처리, nexus/ 제외(개수만 안내)
```

**검증**: 임시 폴더에 `--mode workflows --force --type spring` 실행 → `.github/workflows/` 파일 목록이 .sh 동일 실행과 diff 0.

---

### Task 7: ide-tools.js + commands/skills.js [병렬 (T1 후)]

§2.7 매핑. 모든 외부 CLI는 exec.js 경유. pi settings.json 조작은 JSON.parse→배열 조작→stringify(2칸 들여쓰기)로 Python heredoc 5종 대체.

**검증**: CLI 미설치 환경에서 `--mode skills --force` → 크래시 없이 각 도구 "미감지 안내" 후 정상 종료(종료코드 0). 파괴 케이스: settings.json이 깨진 JSON일 때 → 경고 후 해당 도구만 스킵.

---

### Task 8: interactive.js + integrate.js + index.js [T2~T7 의존]

§2.8 매핑. argv 파서는 .sh와 에러 문구 수준까지 등가(알 수 없는 옵션 → 에러+help+exit 1).

**검증**: `node bin/projectops.js --help` 도움말, `--type wrongtype` → exit 1 + "지원하지 않는 타입", `--mode full --force --type spring,react --paths "spring=server,react=client"` 전 플래그 조합 스모크.

---

### Task 9: bin 교체 + 3곳 규칙 + deprecated 배너 [T8 후]

**파일**: `bin/projectops.js` — 스텁(현 L1~45) 전체 교체:

**Before** (실측 L30~45 발췌):
```js
console.log(`
${CYAN}=========================================================
  ProjectOps v${pkg.version}
...
${YELLOW}npx 마법사는 준비 중입니다.${RESET} 지금은 아래 기존 방식으로 통합하세요.
...
`);
```

**After**:
```js
#!/usr/bin/env node
// projectops CLI 엔트리 — 실제 로직은 src/index.js (SP2 마법사 본체)
const nodeMajor = Number(process.versions.node.split('.')[0]);
if (nodeMajor < 18) {
  console.error(`Node.js 18 이상이 필요합니다 (현재: ${process.versions.node})`);
  process.exit(1);
}
const { main } = await import('../src/index.js');
await main(process.argv.slice(2));
```

**파일**: `.github/scripts/template_initializer.sh` `cleanup_template_files()` — src 블록(L489~491) 뒤에 추가:

**Before** (실측 L489~491):
```bash
    if [ -d "src" ]; then
        rm -rf src
        echo "  ✓ src 폴더 삭제 (projectops CLI)"
```

**After** (블록 뒤 이어서):
```bash
    if [ -f "package-lock.json" ]; then
        rm -f package-lock.json
        echo "  ✓ package-lock.json 삭제 (projectops CLI)"
    fi

    if [ -d "test" ]; then
        rm -rf test
        echo "  ✓ test 폴더 삭제 (projectops CLI 테스트)"
    fi
```

**파일**: `template_integrator.sh` `plugin_items_to_remove`(L2100~2112) — `"src"` 라인 뒤에:

**Before** (실측 L2108~2109):
```bash
        "bin"               # projectops npm CLI (마켓플레이스 전용)
        "src"               # projectops npm CLI 소스 (마켓플레이스 전용)
```

**After**:
```bash
        "bin"               # projectops npm CLI (마켓플레이스 전용)
        "src"               # projectops npm CLI 소스 (마켓플레이스 전용)
        "package-lock.json" # projectops npm CLI 잠금파일 (마켓플레이스 전용)
        "test"              # projectops npm CLI 테스트 (마켓플레이스 전용)
```

**파일**: `template_integrator.ps1` `$pluginItemsToRemove` — 동일 2항목 추가 (ps1 대칭).

**파일**: `template_integrator.sh`/`.ps1` 상단 주석 — deprecated 배너 추가 (설계 D6):
```bash
# ⚠️ DEPRECATED: 이 스크립트는 유지보수 모드입니다. 신규 통합은 `npx projectops`를 사용하세요.
```

**검증**: `bash -n template_integrator.sh`, `bash -n .github/scripts/template_initializer.sh`, Docker pwsh `Parser::ParseFile` → PS1_PARSE_OK.

---

### Task 10: 테스트 스위트 [T9 후]

**신규**: `test/` — node:test 기반:
- `detect.test.js` / `paths.test.js` / `version-yml.test.js` / `breaking.test.js` / `wizard-env.test.js` / `exclusions-leak.test.js`
- `exclusions-leak.test.js`: `npm pack --dry-run --json` 파싱 → `docs/`·`harness/`·`.claude-plugin/`·`CLAUDE.md` 포함 시 실패, `skills/`·`.github/workflows/` 미포함 시 실패
- 로컬 등가성: 스크래치 폴더 2개에 `.sh --mode full --force --type spring`과 `node bin/projectops.js --mode full --force --type spring` 실행 → `diff -rq` 파일 목록 0 (version.yml 타임스탬프 라인만 허용 예외)

**검증**: `node --test test/` 전체 green. package.json에 `"scripts": {"test": "node --test test/"}` 추가.

---

## 4. 현재 상태 (코드 인용)

- `template_integrator.sh:5658` — `[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"` (source 시 main 미실행 — 함수 단위 테스트 가능 구조)
- `template_integrator.sh:827~920` — 인자 파싱: 플래그 10종 + VALID_TYPES 9종 검증
- `template_integrator.sh:2064~2141` — `download_template()`: `git clone --depth 1` + 문서/플러그인 삭제 → **Node에선 통째 소멸**
- `template_integrator.sh:2831~2894` — `_kv_*` 5종: eval+16진 인코딩 (bash 3.2 연관배열 대체) → **Map으로 소멸**
- `template_integrator.sh:5197~5207` — `_pi_python()`: Python 탐색 (settings.json 조작용) → **Node 네이티브 JSON으로 소멸**
- `bin/projectops.js:36` — 스텁: "npx 마법사는 준비 중입니다" 안내만 출력 중
- `package.json:33~35` — `files: ["bin/"]` (자산 미번들 상태)
- `.github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml` — 트리거 `push: main` + `npm pkg set version` 주입 (SP1·#425 완료 상태, SP2에서 무수정)

## 5. 위험 & 완화 [RISK]

- **[RISK] version.yml 텍스트 등가 실패로 E2E diff 실패** — .sh heredoc의 주석·공백을 yaml dump로는 재현 불가 → **완화**: 생성은 텍스트 템플릿, 파싱만 yaml 패키지. 등가성 테스트를 Task 4 단위테스트에 선행 배치.
- **[RISK] @clack/prompts의 ESC 의미가 .sh와 다름** — .sh는 ESC=뒤로/머무르기 문맥이 화면마다 다름(확인 화면 ESC=머무르기 L1884, 기존파일 메뉴 ESC=스킵 L3463) → **완화**: prompts.js 래퍼에서 `isCancel()` 반환을 호출부 문맥별로 매핑하는 계약을 시그니처(`cancelLabel`)로 강제. 화면별 ESC 의미를 Task 8 스모크 체크리스트에 명시.
- **[RISK] Windows에서 `~/.claude` 등 홈 경로·CRLF 회귀** — ps1이 처리하던 USERPROFILE·BOM·CRLF 이슈가 Node 단일 코드로 이동 → **완화**: `os.homedir()` 단일화, 모든 파일 비교 전 `\r\n`→`\n` 정규화, 쓰기는 LF 고정. CI 매트릭스에 windows-latest 포함(SP2 완료 게이트).
- **[RISK] npm 번들에 skills/ 포함 → 기존 integrator/initializer와 무관하게 npm 사용자에게 skills/가 노출** — 사용자 프로젝트 오염은 없음(CLI가 복사 안 함, NEVER_COPY 2차 방어)이나 패키지 크기 +528K → **완화**: exclusions-leak 테스트가 "번들엔 있되 복사 안 됨"을 검증. 크기는 gzip ~150K로 허용 범위.
- **[RISK] 외부 CLI(claude/gemini/codex/pi) 인터페이스 변경 시 skills 모드 파손** — **완화**: exec.js 경유 단일 지점 + 미감지/실패 시 경고 후 계속(기존 .sh 동작 등가). 도구별 실패가 전체 마법사를 죽이지 않음.
- **[RISK] 번들 자산과 레포 최신 사이 버전 지연** — npm 게시 시점의 자산이 고정됨(.sh는 항상 main clone) → **완화**: 이는 설계 D2가 의도한 원자성(버전 고정·롤백 가능). breaking-changes.json만 원격 우선+번들 fallback으로 최신성 유지.

## 6. 검증 방법

- [ ] `npm install` 후 `node --test test/` → 전체 green
- [ ] `npm pack --dry-run` → `skills/`·`.github/workflows/` 포함, `docs/`·`harness/`·`.claude-plugin/`·`CLAUDE.md` 누출 0
- [ ] 스크래치 폴더: `node bin/projectops.js --mode full --force --type spring,react --paths "spring=.,react=client"` → 종료코드 0, `.github/workflows/` 파일 목록 = .sh 실행 결과와 `diff -rq` 0
- [ ] `--type wrongtype` → exit 1 + "지원하지 않는 타입" / `--mode skills --force` (CLI 전부 미설치) → exit 0 + 도구별 미감지 안내
- [ ] `.github/workflows/project-types/python/PROJECT-PYTHON-SIMPLE-CICD.yaml` 복사 후 `grep -E '__[A-Z_]+__|@wizard'` → 0건 (마커 완전 소비, #418 회귀)
- [ ] `bash -n` 2종 + Docker pwsh ParseFile → 문법 무손상
- [ ] macOS 기본 `/bin/bash`(3.2)에서 기존 `.sh --force --mode version` 여전히 완주 (deprecated 배너가 실행에 영향 없음)

## 7. 다음 단계

구현 방식을 선택하세요:

**1. Subagent-Driven (권장)** — `/implement` 호출 시 태스크별 서브에이전트 + Self-Review 자동 진행
**2. Inline** — 현재 세션에서 순차 실행

병렬 태스크 있음: Task 2·3·4·5(T1 후), Task 7(독립) → Subagent-Driven 선택 시 병렬 dispatch 가능.

## 8. [REVIEW_LOG] — Reviewer 적대적 검증

- **[REVIEW_LOG-1] "diff 0" 게이트는 그대로는 달성 불가능하다.** version.yml의 `last_updated`·`integration_date`(L2346~2350)는 실행 시각에 의존하므로 .sh와 Node 산출물이 바이트 일치할 수 없다. → §6 검증 항목에 "타임스탬프 라인 허용 예외"를 명시했고, 등가성 판정은 **파일 목록 diff + 타임스탬프 제외 내용 diff**의 2단으로 정의함 (반영: Task 10).
- **[REVIEW_LOG-2] npx 실행 시 cwd가 대상 프로젝트라는 가정이 깨질 수 있다.** `.sh`는 `bash <(curl ...)`로 cwd=대상이 보장되지만, `npx projectops`를 홈에서 실행하면 홈이 오염된다. .sh도 동일 취약점이 있으나(마커 없으면 basic으로 진행) Node에서는 **git 저장소 아님 경고(main L5643~5646 등가) + basic 감지 시 확인 질문**이 마지막 방어선 — interactive 확인 화면이 이를 커버하므로 별도 가드 추가는 범위 외로 유지하되, `--force` + 마커 0개 조합은 위험. → integrate.js에서 비대화형+basic 폴백 시 경고 문구를 .sh(L1483~1485)와 동일하게 유지 (반영: Task 8).
- **[REVIEW_LOG-3] @clack/prompts는 .sh interactive_menu의 숫자 점프(1~9)·`a` 전체토글(L433~467)을 지원하지 않는다.** "플래그 100% 호환"(D5)은 지키지만 **대화형 키 UX는 100% 등가가 아니다** — 이를 숨기지 않고 명시함. 등가 기준을 "비대화형 인터페이스(플래그·산출물) 100% + 대화형은 기능 등가(선택·취소·다중선택 가능)"로 정의. 완전 키 등가가 요구되면 ui/prompts.js를 자체 raw-mode 구현으로 교체하는 후속 이슈로 분리 (§9 대안 2 참조).
- **[REVIEW_LOG-4] `--no-backup` 플래그가 도움말(L44)에는 있으나 파서(L843~920)에 없음을 실측 확인** — 이미 .sh 자체가 죽은 문서다. Node 도움말에서는 제거해 문서-구현 불일치를 승계하지 않는다 (반영: §2.8).

## 9. [ALTERNATIVES_CONSIDERED] — 기각한 대안

- **기각 대안 1: 자산을 번들하지 않고 런타임에 GitHub tarball fetch** (`codeload.github.com/.../tar.gz/main`) → npm 버전=자산 버전 원자성(설계 D2)이 깨지고, 내부망(npm 미러만 있는 환경)에서 동작 불가, tar 해제 의존성 추가. **번들이 우월**.
- **기각 대안 2: 대화형 메뉴를 자체 raw-mode 구현으로 .sh와 키 단위 100% 등가화** → interactive_menu(L273~510)의 ANSI 앵커·스크롤 잔상 처리 같은 저수준 로직을 Node로 재작성하는 것은 500줄+ 재발명이고 크로스플랫폼 검증 부담이 큼. @clack/prompts는 Win/mac/Linux 실검증된 라이브러리로 유지보수 비용이 압도적으로 낮음. 키 UX 완전 등가는 요구가 확인되면 후속 이슈로.
- **기각 대안 3: commander/yargs로 argv 파싱** → 플래그 10종의 단순 문법에 의존성 1개 추가는 과잉. .sh의 에러 문구·검증 순서까지 등가로 만들려면 수동 파서가 오히려 정확 (약 60줄).
- **기각 대안 4: skills/를 번들하지 않고 Cursor 설치만 git clone 유지** → CLI에 git 의존성이 잔존하고 "TEMP_DIR 소멸" 원칙이 깨짐. skills 모드만을 위한 clone 경로·정리 로직 유지 비용 > 528K 번들 비용.
