# template_integrator.sh 동작 명세 (SP2 Node.js CLI 포팅 기준 문서)

> 작성일: 2026-07-08 · 대상: `template_integrator.sh` (5,660줄, bash 3.2 호환)
> 목적: Node.js CLI 포팅 시 **기능 등가(복사 파일 목록 diff 0)** 검증의 기준.
> 코드 구조가 아니라 "겉으로 보이는 동작·규칙·데이터"만 기록한다.

---

## 0. 전역 상수·환경 초기화

| 항목 | 값 |
|---|---|
| 템플릿 레포 | `https://github.com/Cassiiopeia/projectops.git` (git clone --depth 1) |
| RAW URL | `https://raw.githubusercontent.com/Cassiiopeia/projectops/main` |
| 임시 다운로드 폴더 | `.template_download_temp` (cwd 하위) — EXIT trap으로 항상 정리 |
| 기본 템플릿 버전 폴백 | `DEFAULT_VERSION="1.3.14"` |
| 워크플로우 폴더 | `.github/workflows` / 스크립트 폴더 `.github/scripts` / 타입폴더 `project-types` |
| 워크플로우 접두어 | `PROJECT` / 공통 `PROJECT-COMMON` / init `PROJECT-TEMPLATE-INITIALIZER.yaml` |
| SSL 환경변수 | 시작 시 `CURL_CA_BUNDLE`, `SSL_CERT_FILE`, `SSL_CERT_DIR`, `REQUESTS_CA_BUNDLE` **unset** |
| 색상 | 전부 비활성 (빈 문자열) — 단 interactive_menu 내부는 자체 ANSI 사용 |
| 종료 정책 | `set -e` — 명세 전반의 "경고 후 계속" 항목은 전부 의도적으로 `|| true` 가드됨 |

`TEMPLATE_VERSION`: download 후 `$TEMP_DIR/version.yml`의 `^version:` 값. 없으면 `DEFAULT_VERSION`.

---

## 1. CLI 인터페이스

### 1.1 플래그·인자

| 플래그 | 값 | 기본값 | 의미 |
|---|---|---|---|
| `-m, --mode MODE` | `full` \| `version` \| `workflows` \| `issues` \| `skills` \| `interactive` | `interactive` | 통합 모드. **값 검증 없음** — 알 수 없는 모드면 execute_integration의 case에 안 걸려 복사 0건으로 skills 설치 제안→요약만 출력 (에러 아님) |
| `-v, --version V` | x.y.z | 빈값(자동 감지) | 초기 버전. **형식 검증 없음** (CLI 인자로는 아무 문자열이나 통과) |
| `-t, --type CSV` | 타입 csv | 빈값(자동 감지) | 멀티타입. 공백 제거→중복 제거→검증. 유효 타입: `spring flutter next react react-native react-native-expo node python basic`. 무효 타입 → 에러+exit 1. 빈 결과 → 에러+exit 1. 첫 항목이 `PROJECT_TYPE`(primary) |
| `--force` | - | false | 모든 확인 생략, 비대화형 기본값 사용 |
| `--nexus` / `--no-nexus` | - | 빈값(미설정) | `INCLUDE_NEXUS=true/false` 명시 설정 |
| `--secret-backup` / `--no-secret-backup` | - | 빈값(미설정) | `INCLUDE_SECRET_BACKUP=true/false` 명시 설정 |
| `--paths "t=p,..."` | 예: `flutter=app,react=client` | 빈값 | 타입별 프로젝트 경로 (모노레포). §3.4 참조 |
| `-h, --help` | - | - | 도움말 출력 후 exit 0 |
| 그 외 | - | - | "알 수 없는 옵션" 에러 + 도움말 + **exit 1** |

> ⚠️ **도움말에는 있으나 구현이 없는 것**: `--no-backup`(파서에 없음 → 주면 exit 1),
> `.template_integration/` 백업 폴더, `rollback.sh`. **셋 다 실제 코드 없음.**
> 포팅 시: 구현하지 않고 도움말에서 제거하거나, 동일하게 미구현 유지(등가 기준은 후자).

### 1.2 stdin(curl | bash) 모드 및 TTY 분기

시작 시 `detect_terminal()`:

1. stdin이 TTY(`[ -t 0 ]`) → `STDIN_MODE=false`, `TTY_AVAILABLE=true`.
2. stdin이 파이프 → `STDIN_MODE=true`. `/dev/tty`가 character device이고 실제 read-open 가능하면 `TTY_AVAILABLE=true`(Homebrew 방식 — curl|bash에서도 대화형 가능), 아니면 `false`.

파생 규칙:

- 모든 사용자 대면 출력은 TTY 가능 시 `/dev/tty`, 불가 시 **stderr**. stdout은 함수 반환값 전용(명령어 치환 오염 방지).
- **화살표 메뉴**는 `TTY_AVAILABLE=true` **그리고** stderr가 TTY(`[ -t 2 ]`)일 때만. 아니면 숫자 입력 텍스트 메뉴(legacy) 폴백.
- legacy 메뉴에서 stdin/tty 모두 못 읽으면: multi+preselect → preselect 반환, 아니면 **첫 번째 옵션 자동 선택**.
- `TTY_AVAILABLE=false` + `--mode interactive`(기본) → 에러 안내 + **exit 1**.
- `TTY_AVAILABLE=false` + 명시 모드 + `--force` 없음 → CLI 확인 단계에서 "--force 옵션이 필요합니다" + **exit 1**.
- `safe_read`: TTY 없으면 즉시 return 1(입력 실패). 라인 입력은 `read -e`(readline). 단독 ESC 취소는 없음 — "빈 입력 Enter=기존값 유지" 규약.

### 1.3 main 흐름

```
main → detect_terminal → (git 레포 아니면 경고만) → MODE=interactive면 interactive_mode → execute_integration
```

---

## 2. 대화형 마법사 흐름 (`--mode interactive`)

### 2.1 화면 순서

1. **배너**: 원격 `version.yml`을 curl(--max-time 3)로 가져와 템플릿 버전 표시(실패 시 1.3.14). 배너 문구 `S U H · D E V O P S · T E M P L A T E`, Author/Mode/Repo 표시.
2. **모드 선택 메뉴** (단일 선택, ESC=취소→exit 0):
   - `전체 설치 — …(처음이라면 추천)` → full
   - `버전 관리만 — …` → version
   - `워크플로우만 — …` → workflows
   - `이슈·PR 템플릿만 — …` → issues
   - `AI 스킬만 — Claude·Cursor·Gemini·Codex·PI…` → skills
   - `취소` → exit 0 ("설치를 취소했습니다.")
3. **템플릿 다운로드** (§4.1).
4. **모드별 정보 수집 매트릭스**:
   | 모드 | 타입/버전/브랜치 감지 | 선택 WF 질문 | 경로(project_paths) | 확인 화면 |
   |---|---|---|---|---|
   | full | O | O | O (저장값 로드→확인 후 빈 타입만 질문) | O |
   | version | O | X | O | O |
   | workflows | O | O | X | O |
   | issues | X | X | X | X (바로 실행) |
   | skills | X | X | X | X (바로 실행) |
5. **선택 워크플로우 질문**(full/workflows): 각 타입 폴더의 `nexus/`, common의 `secret-backup/`을 스캔해 파일이 있으면 질문 (§4.6). 이미 값 있으면(CLI 플래그·version.yml) 재질문 안 함.
6. **확인 화면**(`detect_and_confirm_project`): "프로젝트 분석 결과" — 타입(멀티면 csv+"(멀티)"), Version, Default Branch, 통합 모드 한국어 라벨, Nexus/Secret 포함·제외(값 있을 때만), 프로젝트 경로(csv, `=`→`→` 표시).
   - 메뉴: `예, 계속 진행` / `수정하기` / `아니오, 취소`(→exit 0). **ESC = stay(그 자리에 머묾, 재출력)** — 종료는 명시적 '아니오'만.
   - 비TTY/FORCE 폴백: Y/E/N 한 글자 입력(빈 입력=Y). 읽기 실패 → "입력을 읽을 수 없습니다" exit 1.
7. **수정 메뉴 루프**(`수정하기` 선택 시): 매 회 분석 결과 재출력 후,
   - `프로젝트 타입` → 타입 멀티선택 메뉴(§2.2). 타입 집합이 실제로 바뀌면(정렬 비교) `PROJECT_PATHS_CSV` 초기화 후 즉시 경로 재감지.
   - `버전` → 텍스트 입력. 빈 입력/읽기 실패=유지. `x.y.z` 정규식 불일치 → 에러 후 기존값 유지.
   - `기본 브랜치` → 텍스트 입력. 빈 입력=유지. **검증 없음.**
   - `Nexus publish 포함 여부 (현재: 포함/제외)` / `Secret 백업 포함 여부 (현재: …)` → **full/workflows 모드에서만 노출.** `--force-ask`로 재질문.
   - `모두 맞음, 계속` → 확인 화면 복귀(return 0)
   - `뒤로 (변경 없이 확인 화면으로)` / ESC → 확인 화면 복귀(return 1)
8. 확인 후에도 경로 미확정 타입이 있으면(신규 init) `resolve_project_paths` 실행.
9. 이후 `execute_integration`(§4)으로.

### 2.2 메뉴 위젯 동작 (interactive_menu)

- 키: ↑↓(또는 `k`/`j`) 이동, 숫자 1-9 점프, Enter 확정, ESC 또는 `q` 취소(return 1), Ctrl+C(INT) → 커서 복원 후 130.
- multi 모드: Space 토글, `a` 전체 토글, Enter로 선택 csv 반환. **하나도 선택 안 하고 Enter → 취소(return 1)와 동일.**
- `--preselect=csv` 초기 선택, `--initial-index=N` 단일 선택 커서 초기 위치(=기본값 표현), `--cancel-label=` ESC 안내 문구(최상위 "취소", 하위 "뒤로", 확인 화면 "머무르기", IDE "건너뛰기").
- 옵션 형식 `"value|label"` — label 비면 value만 표시. 렌더는 stderr, 반환값은 stdout.
- ESC 시퀀스: 후속 바이트 1초 타임아웃으로 2개 읽어 `[A/[B/OA/OB`=화살표, 없으면 진짜 ESC.
- 비TTY 폴백(legacy_numeric_menu): 번호 목록 출력 후 `선택 (1-n):` 프롬프트. multi는 csv 입력(숫자·이름 혼용, 빈 입력+preselect=preselect). 입력 불가 시 §1.2 규칙.

### 2.3 ask_yes_no

- TTY & !FORCE → `1) 예 2) 아니오` 메뉴 (항목 순서 고정, 기본값은 커서 초기 위치로만 표현). ESC → No 취급. 프롬프트 문자열에서 `(Y/N...)`류 꼬리표를 sed로 제거하고 제목이 비면 "진행하시겠습니까?".
- 비TTY/FORCE → 한 글자 입력. 빈 입력=기본값. Y/N 외 → 재입력 루프. safe_read 실패 → return 1(No).

---

## 3. 프로젝트 감지 규칙

### 3.1 타입 감지 (`detect_project_types` — 멀티, csv 반환)

**우선순위 0**: `version.yml`이 있으면 `project_types`(yq 또는 `^project_types:` 라인에서 `"..."` 토큰 추출), 없으면 `project_type` — **값이 있으면(basic 포함) 그대로 사용하고 파일 스캔 안 함** (version.yml = source of truth).

파일 스캔(루트 기준, 모두 독립 누적):

| 마커 | 타입 |
|---|---|
| `pubspec.yaml` | flutter |
| `build.gradle` 또는 `build.gradle.kts` 또는 `pom.xml` | spring |
| `pyproject.toml` 또는 `setup.py` 또는 `requirements.txt` | python |
| `package.json` 내용 분류 | 아래 순서: `@react-native` 또는 `react-native` 문자열 → (`expo` 포함 시 `react-native-expo`, 아니면 `react-native`) → `"next"` → next → `"react"` → react → 그 외 node. **단 node는 다른 타입이 이미 감지됐으면 추가하지 않음**(보조 도구 오탐 방지) |

아무것도 없으면 `basic`.

(단수 버전 `detect_project_type`도 존재 — 첫 일치만 반환, flutter>spring>python>package.json 순. 현재 메인 흐름은 멀티 버전 사용.)

### 3.2 스캔 추천 (`suggest_types_by_scan` — 안내용, 강제 아님)

마커가 전혀 없을 때(타입 수정 메뉴 상단 안내): ① 각 타입 마커를 maxdepth 3 find(§3.4 후보 검색 재사용). ② 그래도 없으면 확장자 빈도: `.dart≥1`→flutter, `.java+.kt+.gradle≥3`→spring, `.tsx+.jsx≥3`→react, `.py≥3`→python, 위 전부 없고 `.ts+.js≥3`→node. 출력은 메뉴 정의 순서(`spring flutter next react react-native react-native-expo node python basic`)로 정렬한 csv.

### 3.3 버전 감지 (`detect_version` — 순서대로 첫 성공)

1. `package.json` + **jq 있을 때만**: `.version`.
2. `build.gradle`: `version =` 라인 → sed로 `x.y.z` 추출(따옴표 유무 무관), `^[0-9]+\.[0-9]+\.[0-9]+$` 검증, 첫 매치.
3. `pubspec.yaml`: `^version:` 라인 → `x.y.z` (뒤의 `+buildNumber` 무시).
4. `pyproject.toml`: `version =` 라인 → `x.y.z`.
5. git 태그: `git describe --tags --abbrev=0`에서 `v` 접두 제거.
6. 폴백 `0.0.1` (경고 출력).

주의: 감지 순서는 프로젝트 타입과 무관하게 **파일 존재 순서** (모노레포 서브폴더는 안 봄 — 루트 파일만).

### 3.4 모노레포 project_paths 해석 (`resolve_project_paths`)

**--paths 사전 검증·정규화** (지정 시): 각 `타입=경로` 쌍에 대해 ① 타입 토큰 트림 후 VALID_TYPES 검증(무효 → exit 1) ② 경로 정규화: 앞뒤 공백 제거, `\`→`/`, 끝 `/` 제거, 앞 `./` 제거, 빈값→`.` ③ 그 경로에 마커 파일이 없으면 **경고만 하고 입력값 그대로 기록**.

대상: 선택 타입 중 `basic` 제외. basic만이면 아무것도 안 함.

**타입별 마커 파일**:

| 타입 | 대표 마커(`marker_for_type`) | 보조 마커(`existing_marker_in_dir`) |
|---|---|---|
| flutter | pubspec.yaml | - |
| react/next/node/react-native | package.json | - |
| react-native-expo | app.json | - |
| python | pyproject.toml | + setup.py, requirements.txt |
| spring | build.gradle | + build.gradle.kts, pom.xml |

**후보 검색**(`find_type_path_candidates`, maxdepth 3):
- 공통 prune: `node_modules .git build dist .dart_tool android ios .gradle venv .venv __pycache__`.
- spring 특례: 먼저 `settings.gradle(.kts)` 폴더를 찾음(prune: node_modules .git build dist .gradle android ios) — 발견되면 **그 폴더(들)만** 후보(멀티모듈 루트 축약). 없으면 build.gradle/kts/pom.xml 탐색 폴백.
- 마커 이름 여러 개인 타입은 우선순위 높은 이름에서 발견되면 그것만 사용.
- 오탐 필터: flutter → 경로에 `example` 포함 제외 + 해당 폴더에 `lib/` 없으면 제외. spring → 경로에 `android` 포함 제외.
- 루트는 `.`으로 표기. sort -u.

**타입별 확정 우선순위**:
1. `--paths` 값 (최우선, "(--paths 지정)" 안내).
2. 루트에 마커 존재 → `.` 자동 확정 (질문 없음).
3. 기존 `version.yml`의 `project_paths.<타입>` → 기본 제안값(_existing).
4. 후보 검색 결과로 분기:
   - **비대화형(FORCE 또는 비TTY)**: _existing 있으면 그것 → 후보 1개면 그것 → 아니면 `.` + 경고("--paths로 지정 가능").
   - **대화형**: 후보 1개 → "루트를 '후보'로 설정할까요?" Y/N(기본 Y, 아니오→직접입력). 후보 2+개 → 후보들+`직접 입력` 메뉴(label=마커파일명). 후보 0개 → 경고 후 직접입력.
   - **직접입력 루프**: 정규화(--paths와 동일) 후 빈 입력 → _existing 또는 `.`. 마커 존재 검증 → 없으면 "그래도 사용?" N 기본(예→채택, 아니오→재입력).

**요약 출력 + 중복 경고**: 확정 후 `타입 → 경로/마커` 목록 출력. 같은 파일을 2+ 타입이 바라보면 경고(차단 안 함).

**저장값 로드**(`load_saved_project_paths`, interactive full/version에서 확인 화면 전): version.yml `project_paths:` 블록에서 `  타입: "값"` 라인을 파싱해 CSV에 로드만(질문 없음). 대상 타입 전부 채워지면 0 반환(질문 생략).

### 3.5 default branch 감지 (`detect_default_branch` — 순서대로)

1. `gh repo view --json defaultBranchRef` (gh 있을 때).
2. `git symbolic-ref refs/remotes/origin/HEAD`.
3. `git remote show origin`의 "HEAD branch".
4. 폴백 `main`.

### 3.6 레포명 감지 (`detect_repo_name` — env 토큰용)

`git remote get-url origin`에서 마지막 경로 세그먼트(`.git` 제거). 실패 시 현재 디렉토리명(basename).

---

## 4. 복사 규칙 (가장 중요)

### 4.1 템플릿 다운로드·정리 (`download_template`)

1. `$TEMP_DIR/.github` 이미 있으면 스킵(중복 호출 방지). 아니면 폴더 삭제 후 `git clone --depth 1 --quiet` — **실패 시 exit 1**.
2. **문서 제거** (`docs_to_remove`): `CONTRIBUTING.md`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `gemini-extension.json`.
3. **플러그인 전용 제거** (`plugin_items_to_remove` — 파일·폴더 공용):
   ```
   .claude-plugin  .codex-plugin  .agents  .cursor  scripts  package.json
   harness  bin  src
   .github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml
   .github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml
   ```
   ⚠️ `skills/` 폴더는 **보존** (Cursor 설치 소스로 사용).
4. `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md` 존재 확인 안내.
5. `TEMPLATE_VERSION` = `$TEMP_DIR/version.yml`의 `^version:` (없으면 1.3.14).

### 4.2 모드별 복사 순서

| 모드 | 실행 순서 |
|---|---|
| **full** | create_version_yml → add_version_section_to_readme → copy_workflows → update_version_yml_deploy → copy_scripts → copy_config_folder → (타입별) copy_util_modules → copy_issue_templates → copy_discussion_templates → copy_coderabbit_config → ensure_gitignore → copy_setup_guide |
| **version** | create_version_yml → add_version_section_to_readme → copy_scripts → copy_config_folder → ensure_gitignore → copy_setup_guide |
| **workflows** | copy_workflows → update_version_yml_deploy → copy_scripts → copy_config_folder → (타입별) copy_util_modules → copy_setup_guide |
| **issues** | copy_issue_templates → copy_discussion_templates |
| **skills** | offer_ide_tools_install → TEMP 정리 → print_summary → return (다른 복사 없음) |

full/workflows 종료 후: `INCLUDE_NEXUS`/`INCLUDE_SECRET_BACKUP` 미설정이면 false로 보정 → `save_template_options "$TEMPLATE_VERSION"` (§5.3). 이후(모든 모드, skills 제외): `offer_ide_tools_install` → `rm -rf $TEMP_DIR` → `print_summary`.

### 4.3 copy_workflows 상세

소스 베이스: `$TEMP_DIR/.github/workflows/project-types` — **없으면 exit 1** ("템플릿 저장소 구조 오류").
`mkdir -p .github/workflows`. 카운터: copied/skipped/template_added/optional_copied.

**(0) env 계획 수립** `wf_prompt_env_plan` (§4.5) — 타입 순회 전 1회.

**(1) 공통 워크플로우** `project-types/common/*.{yaml,yml}` (직하위 파일만, 하위 폴더 제외):
- 기존 파일과 **내용 동등**(§4.4)이면 스킵.
- 아니면 **무조건 덮어쓰기** (백업 없음, "COMMON은 항상 최신").
- common 폴더 없으면 경고 후 계속.

**(2) 타입별 워크플로우** — 선택 타입마다 `project-types/<type>/*.{yaml,yml}` (직하위만):
- 파일 3분류: **신규**(대상에 없음) → 즉시 복사. **unchanged**(내용 동등) → 조용히 스킵. **changed**(존재+다름) → 일괄 메뉴:
  - `기존 유지 + 새 버전을 참고용(.template.yaml)으로 추가` → `<이름>.template.yaml`로 복사(기존 .template.yaml 삭제 후). 실행되지 않는 참고 파일 안내.
  - `건너뛰기 — 기존 파일만 유지` (비TTY/FORCE/ESC 기본값)
  - `덮어쓰기 — 기존 파일을 .bak 백업 후 교체` → `mv 기존 기존.bak` 후 복사.
- 타입 폴더 없으면 안내만 ("공통 워크플로우만 사용").

**(3) server-deploy/** — `project-types/<type>/server-deploy/` 존재 시:
- `INCLUDE_NEXUS=true` → **폴더째 제외** ("Nexus 라이브러리 프로젝트라 서버 배포 불필요" + 개수 안내).
- 아니면 (2)와 동일한 신규/unchanged/changed 3분류 + 동일 3지선 메뉴 (별도 메뉴 1회).

**(4) nexus/** — `project-types/<type>/nexus/` 존재 시:
- `INCLUDE_NEXUS=true` → 각 파일: unchanged→스킵 / 기존 존재→`.bak` 백업 후 덮어쓰기(**메뉴 없음**) / 신규→복사.
- false → 개수 안내만 ("--nexus 옵션으로 포함 가능").

**(5) common/secret-backup/** — 존재 시:
- `INCLUDE_SECRET_BACKUP=true` → 각 파일: **기존 존재하면 경고 후 무조건 스킵**(덮어쓰기 없음) / 신규만 복사.
- false → 개수 안내만.

**(6) env 치환**: 타입별로 type_dir·server-deploy·nexus 3개 소스 폴더의 파일 중 대상(`.github/workflows/<이름>`)에 실제 존재하고(건너뛴 파일 제외) unchanged로 분류되지 않은 파일에 `configure_workflow_env` 적용 (§4.5). (@wizard 마커 없는 파일은 no-op.)

**(7) 요약·경고**: 복사/선택/참고용/건너뜀 개수 출력. `WORKFLOWS_COPIED` 전역 저장. 멀티타입이면 CI 동시 발화 경고 + paths 필터 권장. spring 포함 시 필수 GitHub Secrets 안내(APPLICATION_PROD_YML, DOCKERHUB_*, SERVER_*, GRADLE_PROPERTIES).

### 4.4 내용 동등성 비교 (`_wf_is_unchanged`)

원본에는 `__TOKEN__`/`# @wizard` 마커가 있어 단순 cmp 불가 → 원본을 mktemp 사본으로 떠서 **서브셸에서 `WF_USE_DEFAULTS=true`로 `configure_workflow_env`를 가상 적용**한 "설치 예상 최종형"과 기존 설치본을 `cmp -s`. 동일=0(unchanged), 다름·비교실패(mktemp/cp 실패 포함)=1(changed 취급 — 업데이트 놓침 방지). 부수효과는 서브셸 격리.

### 4.5 워크플로우 env 토큰 엔진 (@wizard)

마커 형식 (env 라인 끝 주석):
- `KEY: "__TOKEN__"  # @wizard ask:<기본값|@resolver>` — 질문 대상.
- `KEY: "..."  # @wizard auto:<resolver>` — 자동 치환.
- `# @wizard paths-anchor` — 해당 타입의 project_path가 `.`이 아니면 그 줄을 `paths: ['<경로>/**']`로 교체(들여쓰기 보존).

**resolver**: `repo`→detect_repo_name / `spring-app-yml-dir`→해당 타입 경로 아래 `*/src/main/resources/application*.yml` 첫 파일의 dirname / `spring-app-yml-path`→그 파일 경로 / `flutter-root`→project_paths.flutter(없으면 `.`).

**질문 문구**: `wizard-prompts.yml` (작업 디렉토리 `.github/config/wizard-prompts.yml` 우선, 없으면 `$TEMP_DIR/.github/config/wizard-prompts.yml` 폴백). 조회 우선순위 `type.KEY` → `KEY`. 필드 label/help/example (블록 형식 + 구형 1줄 label 형식). label 폴백=KEY명. `_workflow_names:` 블록은 파일명 부분문자열 매칭(긴 키 우선)으로 워크플로우 표시명 결정, 폴백=확장자 제거한 파일명.

**계획 단계**(`wf_prompt_env_plan`, 타입 순회 전 1회):
1. 설치 대상 타입 전체에서 `@wizard ask:` 키 수집(KEY 등장 순서, 기본값=리터럴 또는 @resolver 결과, `WF_DEPLOY_CSV` 저장값이 있으면 그것이 기본값. 타입별 기본값 별도 유지).
2. 비TTY/FORCE → 전부 기본값 prefill.
3. TTY → 키 카드(label·사용처·help·example·기본값) 전부 출력 후 메뉴:
   - `all` 전부 기본값 / `each` 하나씩 입력(Enter=기본값) / `some` 멀티선택 후 고른 것만 입력, 나머지 기본값. ESC=all.
4. 이후 `WF_USE_DEFAULTS=true` 고정 — 실제 치환 단계에선 재질문 없음.

**치환 실행**(`configure_workflow_env`): 마커 라인마다 값 결정 → `KEY: "값"` 치환 + 그 줄의 `# @wizard ...` 주석 제거. 남은 `__PROJECT_NAME__`/`__APP_ARTIFACT_NAME__`은 레포명으로 전역 치환. 남은 `__대문자__` 토큰이 있으면 경고("직접 채워주세요"). ask 값은 `wf_deploy_set`으로 CSV 캐시.

**version.yml deploy 블록**(`update_version_yml_deploy`, copy_workflows 후): `WF_DEPLOY_CSV`가 비어있지 않고 version.yml이 있으면, 기존 `deploy:` 블록을 삭제하고 파일 끝에 새로 기록:
```yaml
deploy:                          # 마법사가 기억하는 배포 설정 (비민감 / 직접 수정 가능)
  <type>:
    <KEY>: "<값>"
```

### 4.6 선택(opt-in) 워크플로우 질문 (`ask_all_optional_workflows`)

- `--force-ask` 아니면 먼저 `read_template_options`로 version.yml의 `metadata.template.options.nexus/.secret_backup` 저장값 로드(값 있으면 재질문 생략).
- 각 타입의 `nexus/` 폴더 → INCLUDE_NEXUS 질문, common `secret-backup/` → INCLUDE_SECRET_BACKUP 질문.
- 질문 조건: 폴더 존재 + yaml/yml 1개 이상 + 값 미설정(또는 force-ask). 비TTY → 무조건 false. 질문 시 파일 목록·설명 표시, 기본값 **N**.

### 4.7 기타 복사물

| 대상 | 규칙 |
|---|---|
| **scripts** (`copy_scripts`) | `version_manager.sh`, `changelog_manager.py` 2개만 `$TEMP_DIR/.github/scripts/`에서 `.github/scripts/`로 무조건 덮어쓰기 + `chmod +x` |
| **.github/config** (`copy_config_folder`) | 폴더 전체 `cp -r` **항상 덮어쓰기** (기존 있으면 안내만). 템플릿에 없으면 스킵 |
| **이슈 템플릿** | `.github/ISSUE_TEMPLATE/` 전체 덮어쓰기 + `.github/PULL_REQUEST_TEMPLATE.md` 덮어쓰기 |
| **Discussion 템플릿** | `.github/DISCUSSION_TEMPLATE/` 전체 덮어쓰기 (템플릿에 없으면 스킵) |
| **.coderabbit.yaml** | 소개문 출력 후: 기존 없음→복사. 기존 있음: TTY&!FORCE → `덮어쓰기(.bak 백업)/건너뛰기` 메뉴(ESC=건너뛰기); FORCE → .bak 백업 후 덮어쓰기; 비TTY&!FORCE → 유지·스킵 |
| **util 모듈** (`copy_util_modules`, 타입별) | `$TEMP_DIR/.github/util/<type>/` 존재 시(현재 flutter만): 설명 출력 → TTY&!FORCE는 Y/N(기본 **Y**), FORCE는 자동 다운로드, 비TTY&!FORCE는 스킵. 채택 시 `.github/util/<type>/`로 전체 복사, 모듈 수 카운트(`UTIL_MODULES_COPIED`), 사용 가이드 출력 |
| **SETUP-GUIDE** (`copy_setup_guide`) | `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md`를 레포 루트로 **항상 덮어쓰기** (템플릿에 없으면 스킵) |
| **README 버전 섹션** | README.md 없으면 경고·스킵. `<!-- AUTO-VERSION-SECTION` 마커 또는 `## (최신 버전|최신버전|Version|버전) : vX.Y.Z` 패턴(대소문자 무시) 있으면 스킵. 없으면 파일 끝에 `---` + 마커 주석 + `## 최신 버전 : v<버전>` + CHANGELOG 링크 append |
| **.gitignore** (`ensure_gitignore`) | 필수 항목 `/.idea`, `/.claude/settings.local.json`. 파일 없으면 두 항목으로 신규 생성. 있으면 **정규화 비교**(주석 제거·트림·앞 `/`·`./`·뒤 `/` 제거)로 중복 검사 후 누락분만 "projectops: Auto-added entries" 섹션 헤더와 함께 append |

---

## 5. version.yml 스키마

### 5.1 신규 생성 (`create_version_yml`)

주석 헤더(고정 문구) + 다음 필드:

```yaml
version: "<버전>"                 # 값 소스: 기존 version.yml 최우선 > --version > detect_version
version_code: <N>  # app build number     # 기존 파일의 version_code 보존(양의 정수 검증, 아니면 1), 신규는 1
project_types: ["a","b"]   # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능
project_type: "a"  # project_types[0] 자동 미러 — 직접 수정 금지 (...)
project_paths:                # (PROJECT_PATHS_CSV 있을 때만 블록 생성)
  <type>: "<path>"   # <path>/<marker> (또는 루트면 marker만) 주석
metadata:
  last_updated: "<UTC YYYY-MM-DD HH:MM:SS>"
  last_updated_by: "template_integrator"
  default_branch: "<감지/입력 브랜치>"
  integrated_from: "projectops"
  integration_date: "<UTC YYYY-MM-DD>"
```

### 5.2 기존 파일 있을 때

- `version_code` 추출·보존 (yq 우선, 없으면 `^version_code:` grep — 주석 라인 오탐 방지).
- **`version` 보존**: 기존 값이 있으면 감지값·`--version`보다 우선 ("version.yml이 single source of truth").
- TTY&!FORCE면 "version.yml 업데이트 — 안전합니다, 필수입니다" 안내(유지 값·갱신 항목 표) 후 Y/N(기본 Y). **N → "통합이 취소되었습니다" exit 0** (반쪽 상태 방지 — version.yml 미변경).
- 이후 파일은 **통째로 재작성**(구조·주석 갱신, deploy 블록·template 블록은 각자 함수가 다시 붙임).

### 5.3 metadata.template.options (`save_template_options`)

- 미설정 옵션은 false 보정. version.yml 없으면 no-op.
- 기존에 `template:` 섹션 있으면: `nexus:`/`secret_backup:` 라인 sed 치환(없으면 `options:` 아래 삽입), `last_update_date:` 갱신. (source/version/integrated_date는 유지.)
- 없으면 파일 끝에 append (metadata 하위 들여쓰기 2칸으로 시작):
```yaml
  template:
    source: "projectops"
    version: "<TEMPLATE_VERSION>"
    integrated_date: "<UTC 날짜>"
    last_update_date: "<UTC 날짜>"
    options:
      nexus: true|false
      secret_backup: true|false
```

### 5.4 읽기 규칙

- `read_template_options`: template→options 블록 내 `nexus:`/`secret_backup:` 값(true/false만 인정)을 INCLUDE_* 에 로드. 구 `synology` 키는 자연 무시.
- `get_current_template_version`: `template:` 블록 내 첫 `version: "x.y.z"` — 없으면 `unknown`.

---

## 6. 업데이트(재통합) 로직

1. **기존 통합 감지**: `get_current_template_version` ≠ `unknown` (= version.yml에 `metadata.template.version` 존재).
2. **Breaking changes 검사** (`check_breaking_changes current new`):
   - **스킵 조건**: current가 빈값/unknown, `--force`, 비TTY, curl 실패, JSON 빈값, **jq 없음(경고 후 스킵)**.
   - URL: `https://raw.githubusercontent.com/Cassiiopeia/projectops/main/.github/config/breaking-changes.json`.
   - 버전 키(`_` 시작 키 제외) 중 `current < ver <= new` 범위만 수집. 비교는 3자리 숫자 비교(`compare_versions`, v 접두 제거, 누락 자리=0).
   - severity `critical` / 그 외(`warning` 기본)로 분류해 박스 출력.
   - critical 1개 이상 → "확인했고 계속 진행할까요?" (기본 **N**). 거절 → exit 0. warning만 있으면 표시만 하고 계속.
   - ⚠️ **quirk**: new_version 인자로 다운로드 전 시점이라 `TEMPLATE_VERSION`이 아닌 **하드코딩 `DEFAULT_VERSION`(1.3.14)** 이 전달된다. 포팅 시 등가 유지 여부 결정 필요(사실상 버그 — 1.3.14 초과 버전의 breaking change는 안 잡힘).
3. 재통합 시 데이터 보존: version/version_code/project_paths 저장값/template.options/WF_DEPLOY(deploy 블록 → ask 기본값) 모두 §3~5 규칙대로 이어받음.

---

## 7. skills 모드 / IDE 도구 설치 (`offer_ide_tools_install`)

full/version/workflows/issues 모드 끝에도 동일 함수가 호출됨(즉 skills 모드 전용 아님).

### 7.1 상태 수집·표시

- **Claude Code**: `command -v claude`. 설치 여부는 `claude plugin list --json` 출력에서 `"cassiiopeia@` 항목의 scope/version 파싱. TEMPLATE_VERSION과 비교해 "✓ 최신"/"업데이트 가능" 표시.
- **Cursor**: `~/.cursor/skills/cursor-skills-meta.json`의 `"version"`.
- **Gemini**: `command -v gemini` 여부만.
- **Codex**: `~/.agents/skills/cassiiopeia` 심링크/디렉토리 존재 → 설치됨; 아니면 CLI 감지 여부.
- **PI**: `command -v pi` + `pi list 2>&1` 출력에 `SUH-DEVOPS-TEMPLATE|projectops|cassiiopeia` 포함 → 설치됨. Harness: `~/.pi/agent/settings.json`의 `extensions` 배열에 loader 경로 포함 여부(python으로 JSON 파싱).

### 7.2 라우터 (TTY & !FORCE)

1. 동작 메뉴: `설치 / 업데이트` / `제거` / `그대로 두기` (ESC=건너뛰기).
2. IDE 멀티선택: 후보 = Claude Code, Cursor, Gemini CLI(미감지 표기), Codex CLI(미감지 표기), PI(미감지 표기), (pi CLI 있고 harness loader 파일 존재 시) PI Persona Harness. apply 시 preselect = 감지된 IDE 전체. 무선택/ESC → 건너뜀.

**비TTY 또는 FORCE**: 메뉴 없이 Claude→Cursor→Gemini→Codex→PI 순 자동 설치/업데이트.

### 7.3 IDE별 정확한 조작

| IDE | 설치/업데이트 | 제거 |
|---|---|---|
| **Claude Code** | 미설치: `claude plugin marketplace add Cassiiopeia/projectops`(실패=이미 등록 안내) → `claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user`(실패 시 수동 명령 안내). 설치됨: `claude plugin update ... --scope <기존scope>` + **config 마이그레이션**: 업데이트 전후 `~/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia/` 아래 최신(sort -V) 버전 폴더가 바뀌었으면 이전 `config/*.json`을 새 폴더 `config/`로 복사 | `claude plugin uninstall ... --scope <scope>` + `~/.claude/plugins/data/cassiiopeia@cassiiopeia-marketplace/` 삭제. CLI 없거나 미설치면 no-op 안내 |
| **Cursor** | 소스: `$TEMP_DIR/skills` → 없으면 로컬 `skills/` → 둘 다 없으면 경고·중단. `~/.cursor/skills/`로 `cp -r` 후 `cursor-skills-meta.json` 작성(name/version=TEMPLATE_VERSION/scope=user/source/installPath/installedAt(기존값 보존)/lastUpdated) | meta 파일 없으면 no-op. 있으면 `rm -rf ~/.cursor/skills` |
| **Gemini** | CLI 없으면 수동 명령 안내. `gemini extensions update cassiiopeia` 성공 시 끝, 실패 시 `gemini extensions install https://github.com/Cassiiopeia/projectops`, 그것도 실패 시 수동 안내 | `gemini extensions uninstall cassiiopeia` (실패해도 안내만) |
| **Codex** | CLI 있으면 `codex plugin marketplace add Cassiiopeia/projectops` → `codex plugin marketplace upgrade cassiiopeia`(실패 시 수동 안내). CLI 없으면 수동 안내. *(native fallback 함수 `_do_codex_native_skills_fallback` 존재: `~/.codex/cassiiopeia`에 git clone/pull 후 `~/.agents/skills/cassiiopeia` → `<클론>/skills` 심링크 — 현재 메인 흐름에서는 호출되지 않음)* | `~/.agents/skills/cassiiopeia` 심링크/폴더 rm -rf. marketplace 해제는 수동 명령 안내만 |
| **PI** | CLI 없으면 수동 안내(`pi install <URL>`). 설치됨: `pi update <URL>` 실패 시 `pi install <URL>` 폴백. 미설치: `pi install <URL>`. URL=`https://github.com/Cassiiopeia/projectops`. 검증은 다시 `pi list`. 성공 시 harness offer(§7.4) | `pi remove <URL>` 후 `pi list` 재검증(남아있으면 경고). harness 활성 상태였으면 함께 해제 |

### 7.4 PI Persona Harness

- **클론 경로 폴백**: `~/.pi/agent/git/github.com/Cassiiopeia/projectops`가 없고 구 경로 `~/.pi/agent/git/github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE`가 있으면 구 경로 사용.
- loader = `<클론경로>/harness/harness-loader.ts`, settings = `~/.pi/agent/settings.json`.
- **활성화** = settings의 `extensions` 배열에 loader 경로 추가(python JSON, 중복 방지, indent 2). settings 없음/loader 없음/python 없음 → 경고·중단. python 탐색은 `python3→python→py` 순서로 **실제 실행 검증**(`-c "import sys; sys.exit(0)"` — Windows Store stub 배제).
- **해제** = extensions에서 loader 제거.
- 설치 직후 offer: 이미 활성 → 유지 안내. 비TTY/FORCE → 자동 스킵(비활성 유지). TTY → 설명 후 Y/N(기본 **N**).
- 라우터의 `PI Persona Harness` 항목: apply=토글(현 상태 반대로 물음), remove=harness만 해제(skill 보존).

### 7.5 skills 모드 특이점

`execute_integration`에서 skills 모드는 위 함수만 실행하고 TEMP 정리 후 간결 요약(설치 항목 1줄 + 레포 링크) 출력하고 종료. 프로젝트 파일은 일절 건드리지 않음.

---

## 8. revert 모드

**존재하지 않는다.** `--mode revert`도, 백업 폴더(`.template_integration/`)도, `rollback.sh` 생성 코드도 없다 (도움말 텍스트에만 언급 — §1.1 참조). 되돌리기에 해당하는 실제 기능은:

- IDE 스킬 **제거** 흐름(§7.3 제거 열) — 이것이 유일한 "삭제" 기능.
- 워크플로우 덮어쓰기 시 생성되는 `.bak` 파일 / `.template.yaml` 참고 파일 (수동 복원용 부산물).

포팅 시: CLAUDE.md의 "신규 통합 / 업데이트 / 되돌리기 모드 지원" 문구와 달리 sh에는 revert가 없으므로, 등가 포팅이라면 미구현 유지, 신규 구현이라면 별도 스펙 필요.

---

## 9. 에러·경고 동작 목록

### 9.1 즉시 종료 (exit 1)

| 상황 |
|---|
| 알 수 없는 CLI 옵션 (`--no-backup` 포함) |
| `--type`에 무효 타입 / 빈 값 |
| `--paths`에 무효 타입 |
| 템플릿 git clone 실패 |
| `$TEMP_DIR/.github/workflows/project-types` 없음 (copy_workflows) |
| interactive 모드인데 TTY 불가 (사용 예시 안내 후) |
| CLI 모드 확인 단계에서 TTY 불가 + `--force` 없음 |
| ask_yes_no_edit(비TTY 확인 폴백)에서 입력 읽기 실패 |

### 9.2 정상 종료 (exit 0 — 사용자 취소)

| 상황 |
|---|
| `--help` |
| 모드 선택 메뉴에서 `취소`/ESC |
| 확인 화면에서 `아니오, 취소` (명시적으로만 — ESC는 stay) |
| CLI 모드 확인 질문에 아니오 |
| 기존 version.yml 갱신 거부 (version.yml 미변경 보장) |
| Breaking change CRITICAL 확인 거부 |

### 9.3 경고 후 계속 (절대 죽지 않음)

| 상황 | 동작 |
|---|---|
| git 저장소 아님 | 경고만, 계속 |
| README.md 없음 | 버전 섹션 스킵 |
| jq 없음 (breaking changes) | 검사 스킵 + jq 설치 권장 |
| breaking-changes.json 다운로드/파싱 실패 | 조용히 스킵 |
| `--paths` 경로에 마커 없음 | 경고 후 입력값 그대로 기록 |
| 비대화형 경로 후보 다수 | `.`로 기록 + `--paths` 안내 |
| 직접입력 경로에 마커 없음 | "그래도 사용?" 재확인(기본 N) |
| common/ 폴더 없음, 타입 폴더 없음, config/DISCUSSION/coderabbit/SETUP-GUIDE/util이 템플릿에 없음 | 각각 안내 후 스킵 |
| secret-backup 파일이 이미 존재 | 경고 후 해당 파일 스킵 |
| env 치환 후 `__TOKEN__` 잔존 | 경고 ("직접 채워주세요") |
| 모든 IDE CLI 부재/명령 실패 | 경고 + 수동 명령 안내 (통합은 계속) |
| Cursor 스킬 소스 없음 / 복사 실패 | 경고 후 계속 |
| Codex 설치 경로가 git 레포 아님 / 대상이 심링크 아닌 실존 경로 | 경고 후 해당 단계 중단(보존) |
| PI settings/loader/python 없음 | 경고 후 harness 단계 스킵 |
| ESC/메뉴 취소 전반 | 항상 "안전한 기본값"(건너뛰기·유지·기본값·stay)으로 폴백 — 어떤 ESC도 스크립트를 죽이지 않음 |

### 9.4 완료 요약 (print_summary)

모드별 "통합된 기능" 체크리스트 → (skills면 여기서 끝) → 추가 파일(version.yml 버전·타입, README) → 워크플로우 분류 출력: `.github/workflows/PROJECT-*.{yaml,yml}` 실측 스캔으로 `PROJECT-TEMPLATE-INITIALIZER`=기존 파일, `PROJECT-COMMON-*`=공통(📌), `PROJECT-<TYPE대문자>-*`(선택 타입 매칭)=타입별(🎯) → scripts 2종 → util 모듈 목록 → spring/flutter 팁 → **필수 3작업 안내**: ① Secret `_GITHUB_PAT_TOKEN`(repo, workflow scope) ② `deploy` 브랜치 생성 ③ CodeRabbit 활성화 → SETUP-GUIDE 참조 안내.

---

## 10. 포팅 시 주의할 quirk 정리

1. **breaking-changes의 new_version이 하드코딩 1.3.14** (§6) — TEMPLATE_VERSION이 아님.
2. **`--no-backup`·rollback은 도움말 전용 허구** — 실제 주면 exit 1.
3. **MODE 값 무검증** — 오타 모드는 에러 없이 "아무것도 복사 안 하고" IDE 설치 제안으로 직행.
4. **내용 동등성 비교는 "가상 치환 후 cmp"** (§4.4) — 파일 목록 diff 0 검증의 핵심. Node 포팅에서도 동일 파이프라인(기본값 치환 → 바이트 비교)이어야 스킵/덮어쓰기 판단이 같아진다.
5. **version.yml이 version/type의 source of truth** — 기존 값이 감지값·CLI 인자보다 우선(version은 CLI `--version`보다도 우선).
6. **secret-backup은 절대 덮어쓰지 않고, common은 절대 묻지 않고 덮어쓰고, nexus는 묻지 않고 .bak 덮어쓰기** — 카테고리마다 충돌 정책이 다르다.
7. **stdout은 반환값 전용, 화면 출력은 /dev/tty→stderr** — 파이프 실행(`curl | bash`) 등가성의 전제.
8. **detect_version의 package.json 경로는 jq 의존** — jq 없으면 package.json 버전을 못 읽고 다음 소스로 넘어간다.
9. **configure_workflow_env의 unchanged 제외 목록은 타입 루트 폴더 기준만** — server-deploy/nexus의 unchanged는 재-configure 대상이지만 설치본에 @wizard 마커가 없어 사실상 no-op.
10. **legacy 메뉴의 무입력 자동 선택**(첫 옵션/preselect) — CI에서 --force 없이 돌 때의 실질 기본값.
