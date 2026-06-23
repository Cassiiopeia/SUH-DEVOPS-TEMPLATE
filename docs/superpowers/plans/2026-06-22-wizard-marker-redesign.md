# @wizard 마커 시스템 재설계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `@wizard` 마커를 `ask:<기본값>`/`auto:<resolver>` 단일 문법으로 교체하고, 한글 질문 문구만 `labels.yml`로 분리하며, 타입별 기본값은 각 워크플로우 리터럴로 직접 박아 `default_for_type_key` 하드코딩 표를 제거한다.

**Architecture:** `template_integrator.sh`(bash)와 `template_integrator.ps1`(PowerShell)의 마커 처리 함수(`configure_workflow_env` / `Configure-WorkflowEnv`)를 새 문법 파서 + resolver 디스패처로 교체한다. 워크플로우 39개 마커 + auto-find 4개를 새 문법으로 마이그레이션한다. 질문 문구는 `.github/wizard/labels.yml`(없으면 키명 폴백). 타입별 다른 기본값(JAVA/포트)은 워크플로우 마커에 리터럴로 직접 둔다.

**Tech Stack:** Bash(POSIX sh, BSD/GNU sed 양립), PowerShell 5.1+, YAML 워크플로우. 검증은 `bash -n`·`expect`(sh TTY)·Docker `mcr.microsoft.com/powershell`(ps1 파서).

## Global Constraints

- **하위호환 미고려** — 기존 `@wizard ask:/auto/auto-find` 마커를 전량 새 문법으로 교체. 레거시 분기 삭제.
- **마커에 한글·따옴표 금지** — `# @wizard ask:<기본값>` / `# @wizard auto:<resolver>`만. 한글 질문은 `labels.yml`로.
- **`.sh`/`.ps1` 동등** — 같은 입력에 같은 결과. resolver 이름·반환 동일.
- **타입별 기본값은 워크플로우 리터럴** — flutter 워크플로우엔 `ask:17`, spring엔 `ask:21`, python 포트는 `ask:8000` 등. `default_for_type_key`/`Get-DefaultForTypeKey` 표 제거.
- **resolver는 동적값만** — `@repo`(레포명). (`flutter-root`는 후행 Flutter 스펙에서 추가.)
- **치환 후 `# @wizard` 주석 줄째 삭제** — 결과 워크플로우엔 값만 남음(`# @wizard set` 안 남김).
- **label 폴백** — `labels.yml`에 키 없거나 파일 자체가 없으면 env 키명으로 질문.
- **paths-anchor 불변** — `# @wizard paths-anchor`(`on.push.paths` 주입)는 env 마커와 별개, 손대지 않음.
- **커밋 컨벤션** — `내용 : type : 상세` 형식. 이모지·태그·AI 흔적 금지(CLAUDE.md). 한 Task = 한 커밋.
- **macOS/Windows 검증** — `.ps1`은 Docker pwsh 파서로, `.sh`는 `bash -n`·`expect`로. 실제 키 입력 주입까지.

---

## 파일 구조

| 파일 | 역할 | 변경 |
|------|------|------|
| `.github/wizard/labels.yml` | ask 마커의 한글 질문 문구 사전(KEY: "문구") | **신규 생성** |
| `template_integrator.sh` | bash 마커 엔진 | `default_for_type_key` 제거, `resolve_token`/resolver 추가, `configure_workflow_env`·`_wf_set_env` 교체 |
| `template_integrator.ps1` | PowerShell 마커 엔진(.sh 1:1) | 위와 동등하게 교체 |
| `.github/workflows/project-types/**/*.yaml` | 마커 박힌 워크플로우 17개 | ask/auto-find 마커를 새 문법으로 마이그레이션 |

## resolver 카탈로그 (이번 스펙)

| resolver | `.sh` 함수 | `.ps1` 함수 | 반환 |
|----------|-----------|-------------|------|
| `repo` | `resolve_repo` | `Resolve-Repo` | 레포명(`detect_repo_name`/`Get-RepoName`) |
| `spring-app-yml-dir` | `resolve_spring_app_yml_dir` | `Resolve-SpringAppYmlDir` | `find <typepath>/src/main/resources/application*.yml` 첫 결과의 dir(상대) |
| `spring-app-yml-path` | `resolve_spring_app_yml_path` | `Resolve-SpringAppYmlPath` | 위 파일 경로 그대로(상대) |

> `flutter-root` resolver는 후행 Flutter 스펙에서 추가(이 계획 비범위).

## 새 마커 문법 (확정)

```yaml
PROJECT_NAME: "x"   # @wizard ask:@repo          # 물음, 기본값=레포명(resolver)
JAVA_VERSION: "17"  # @wizard ask:17             # 물음, 기본값=17(리터럴)
DEPLOY_PORT: "8080" # @wizard ask:8080           # 물음, 기본값=8080(리터럴)
APPLICATION_YML_DIR: "x"  # @wizard auto:spring-app-yml-dir   # 안 물음, resolver
SSH_AUTH_METHOD: "password" # @wizard ask:password
```
- 파싱 정규식(sh): `#[[:space:]]*@wizard[[:space:]]+(ask|auto):(.*)$` → group1=action, group2=arg(trim).
- `ask:<arg>` → arg가 `@<name>`이면 resolver, 아니면 리터럴 기본값. label은 labels.yml(없으면 키명).
- `auto:<name>` → resolver 실행값, 안 물음.
- `{PROJECT_NAME}` 등 다른 env 참조 토큰은 기존 `__PROJECT_NAME__` 재귀 치환을 그대로 활용(VOLUME 경로용).

---

### Task 1: labels.yml 생성 + 마커 마이그레이션 (워크플로우 17개)

**Files:**
- Create: `.github/wizard/labels.yml`
- Modify: 아래 17개 워크플로우의 `@wizard` 마커 줄 (auto-find 포함)
- Test: `/tmp/test_markers.sh` (임시 검증 하네스)

**Interfaces:**
- Produces: 새 문법 마커가 박힌 워크플로우 + `labels.yml`. Task 2~3의 엔진이 이 마커를 파싱한다.
- 마커 문법: `# @wizard ask:<arg>` / `# @wizard auto:<resolver>` (group2=arg).

- [ ] **Step 1: labels.yml 생성**

Create `.github/wizard/labels.yml`:
```yaml
# @wizard ask 마커의 사용자 질문 문구. 키=env 키, 값=한글 라벨.
# 여기 없는 ask 키는 env 키명으로 질문된다(폴백). 기본값·resolver는 여기 두지 않는다(마커 소관).
PROJECT_NAME: "프로젝트 이름"
JAVA_VERSION: "JDK 버전"
DEPLOY_PORT: "배포 포트"
DOMAIN_NAME: "서비스 도메인"
PRODUCTION_DOMAIN: "서비스 도메인"
VOLUME_HOST_PATH: "호스트 볼륨 경로"
VOLUME_CONTAINER_PATH: "컨테이너 내부 경로"
SSH_AUTH_METHOD: "SSH 인증 방식(password/key)"
```

- [ ] **Step 2: ask 마커 마이그레이션 — PROJECT_NAME (10개 파일)**

각 파일에서 `# @wizard ask: 프로젝트 이름 [기본: 레포명]` → `# @wizard ask:@repo`로 변경 (env 값·키는 그대로):
- `flutter/PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml:66`
- `flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml:36`
- `flutter/PROJECT-FLUTTER-ANDROID-SELFHOSTED-CICD.yaml:38`
- `next/PROJECT-NEXT-CI.yaml:36`, `next/PROJECT-NEXT-CICD.yaml:30`
- `python/PROJECT-PYTHON-CI.yaml:30`, `python/PROJECT-PYTHON-PR-PREVIEW.yaml:41`, `python/PROJECT-PYTHON-SIMPLE-CICD.yaml:67`
- `react/PROJECT-REACT-CI.yaml:35`, `react/PROJECT-REACT-CICD.yaml:29`
- `spring/PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml:83`, `-TRAEFIK-CICD.yaml:79`, `-PR-PREVIEW.yaml:36`, `-SIMPLE-CICD.yaml:77`

예(PLAYSTORE 36행):
```yaml
  PROJECT_NAME: "__PROJECT_NAME__"  # @wizard ask:@repo
```

- [ ] **Step 3: ask 마커 마이그레이션 — JAVA_VERSION (타입별 리터럴)**

flutter(17): `FIREBASE:69`, `PLAYSTORE:39`, `SELFHOSTED:40`, `TEST-APK:62`, `CI:84` → `# @wizard ask:17`
spring(21): `NGINX:88`, `TRAEFIK:84`, `PR-PREVIEW:39`, `SIMPLE:81` → `# @wizard ask:21`

예(flutter PLAYSTORE 39행):
```yaml
  JAVA_VERSION: "__JAVA_VERSION__"  # @wizard ask:17
```

- [ ] **Step 4: ask 마커 마이그레이션 — 포트·도메인·볼륨·SSH (리터럴)**

- `python/SIMPLE:70` `DEPLOY_PORT` → `# @wizard ask:8000`
- `spring/SIMPLE:90` `DEPLOY_PORT` → `# @wizard ask:8080`
- `spring/NGINX:84` `DOMAIN_NAME` → `# @wizard ask:example.com`
- `spring/TRAEFIK:80` `PRODUCTION_DOMAIN` → `# @wizard ask:example.com`
- `VOLUME_HOST_PATH`(python/SIMPLE:80, spring/NGINX:107, TRAEFIK:102, SIMPLE:101) → `# @wizard ask:/volume1/projects/__PROJECT_NAME__`
- `VOLUME_CONTAINER_PATH`(python/SIMPLE:81, spring/TRAEFIK:103, SIMPLE:102) → `# @wizard ask:/mnt/__PROJECT_NAME__`
- `SSH_AUTH_METHOD`(python/PR-PREVIEW:59, SIMPLE:86, spring/NGINX:113, TRAEFIK:108, PR-PREVIEW:60, SIMPLE:107) → `# @wizard ask:password`

> VOLUME 경로의 `__PROJECT_NAME__`은 기존 재귀 토큰 치환(Task 2 Step에서 보존)이 해소한다.

- [ ] **Step 5: auto-find 마커 마이그레이션 (Spring 4개)**

- `spring/NGINX:92`, `TRAEFIK:88`, `SIMPLE:85` `APPLICATION_YML_DIR` → `# @wizard auto:spring-app-yml-dir`
- `spring/PR-PREVIEW:42` `APPLICATION_YML_PATH` → `# @wizard auto:spring-app-yml-path`

예(SIMPLE 85행):
```yaml
  APPLICATION_YML_DIR: "__APPLICATION_YML_DIR__"  # @wizard auto:spring-app-yml-dir
```

- [ ] **Step 6: 마이그레이션 누락·구문법 잔류 검사**

Run:
```bash
cd /d/0-suh/project/suh-github-template
grep -rn "@wizard ask:\|@wizard auto-find:\|\[기본:" .github/workflows/project-types/ | grep -v "paths-anchor"
```
Expected: 출력 없음(구문법 `ask: `·`auto-find:`·`[기본:]` 전부 사라짐). 남으면 그 줄 수정.

Run:
```bash
grep -rhoE "# @wizard (ask|auto):[^ ]*" .github/workflows/project-types/ | sort -u
```
Expected: `# @wizard ask:17`, `ask:21`, `ask:8000`, `ask:8080`, `ask:@repo`, `ask:example.com`, `ask:password`, `ask:/mnt/__PROJECT_NAME__`, `ask:/volume1/projects/__PROJECT_NAME__`, `auto:spring-app-yml-dir`, `auto:spring-app-yml-path` 만.

- [ ] **Step 7: 워크플로우 YAML 무손상 자가검증 (실행로직 미변경)**

Run:
```bash
git diff .github/workflows/project-types/ | grep "^+" | grep -v "^+++" | grep -vE "# @wizard (ask|auto):"
```
Expected: 출력 없음(추가된 줄이 전부 마커 주석 변경뿐 — `run:`/`uses:`/`steps:` 무손상).

- [ ] **Step 8: 커밋**

```bash
git add .github/wizard/labels.yml .github/workflows/project-types/
git commit -m "wizard 마커를 ask:기본값 / auto:resolver 새 문법으로 마이그레이션 + labels.yml 추가 : refactor : 워크플로우 17개의 @wizard 마커에서 한글설명·[기본:] 제거하고 타입별 기본값은 리터럴로 직접 박음, 한글 질문문구는 labels.yml로 분리, Spring auto-find는 auto:spring-app-yml-dir/path로 교체"
```

---

### Task 2: bash 엔진 교체 (resolver + 새 파서)

**Files:**
- Modify: `template_integrator.sh` (제거: `default_for_type_key` 2763-2777 / 교체: `_wf_set_env` 2813-2823, `configure_workflow_env` 2868-3002 / 추가: resolver 함수, `resolve_token`)
- Test: `/tmp/test_sh_engine.sh` (임시 하네스)

**Interfaces:**
- Consumes: Task 1의 새 마커 문법, `labels.yml`. 기존 헬퍼 `detect_repo_name`, `get_path_for_type`, `wf_deploy_get/set`, `safe_read`, `print_*` 재사용.
- Produces: `resolve_token(type, name)` → resolver 값. `wf_label(key)` → 질문 문구(없으면 키명). `configure_workflow_env(type, file)` 새 동작. Task 3(.ps1)이 동일 시그니처로 미러.

- [ ] **Step 1: 실패하는 검증 하네스 작성 (단일레포 spring)**

Create `/tmp/test_sh_engine.sh`:
```bash
#!/usr/bin/env bash
set -u
ROOT=/d/0-suh/project/suh-github-template
# 픽스처: spring 워크플로우 1개 복사 + application.yml 픽스처
WORK=$(mktemp -d)
mkdir -p "$WORK/src/main/resources"
echo "server:" > "$WORK/src/main/resources/application.yml"
cp "$ROOT/.github/workflows/project-types/spring/PROJECT-SPRING-SIMPLE-CICD.yaml" "$WORK/wf.yaml"
cp "$ROOT/.github/wizard/labels.yml" "$WORK/labels.yml" 2>/dev/null || true
# 엔진 함수만 source (main 미실행 — BASH_SOURCE 가드)
cd "$WORK"
source "$ROOT/template_integrator.sh"
# 스텁: 비대화형 일괄 기본값, 레포명 고정
TTY_AVAILABLE=false; FORCE_MODE=true; WF_USE_DEFAULTS=true
detect_repo_name(){ echo "myrepo"; }
get_path_for_type(){ echo "."; }
LABELS_FILE="$WORK/labels.yml"
configure_workflow_env "spring" "$WORK/wf.yaml"
echo "=== RESULT ==="
grep -E "PROJECT_NAME:|JAVA_VERSION:|DEPLOY_PORT:|APPLICATION_YML_DIR:|@wizard" "$WORK/wf.yaml"
rm -rf "$WORK"
```

- [ ] **Step 2: 하네스 실행 → 현재(구엔진) 실패 확인**

Run: `bash /tmp/test_sh_engine.sh`
Expected: 구엔진은 새 문법(`ask:@repo`)을 못 알아봐 PROJECT_NAME이 `__PROJECT_NAME__`로 남거나 `@wizard` 주석이 남음 → 실패(아직 교체 전).

- [ ] **Step 3: resolver 함수 + resolve_token + wf_label 추가**

`template_integrator.sh`의 `default_for_type_key`(2763-2777) **자리에** 아래로 교체:
```bash
# ── resolver 레지스트리 ──────────────────────────────────────────────
# 동적 기본값(@name)·auto:name 둘 다 사용. $1=type. 반환은 stdout.
resolve_repo() { detect_repo_name; }

resolve_spring_app_yml_dir() {
    local _t="$1" _base
    _base=$(get_path_for_type "$_t"); [ -z "$_base" ] && _base="."
    local _f
    _f=$(find "$_base" -path "*/src/main/resources/application*.yml" 2>/dev/null | head -1)
    [ -z "$_f" ] && { echo ""; return; }
    dirname "$_f" | sed 's#^\./##'
}

resolve_spring_app_yml_path() {
    local _t="$1" _base
    _base=$(get_path_for_type "$_t"); [ -z "$_base" ] && _base="."
    find "$_base" -path "*/src/main/resources/application*.yml" 2>/dev/null | head -1 | sed 's#^\./##'
}

# resolver 디스패처. $1=type $2=resolver명 → 값(없으면 빈문자열)
resolve_token() {
    local _t="$1" _name="$2"
    case "$_name" in
        repo)                 resolve_repo ;;
        spring-app-yml-dir)   resolve_spring_app_yml_dir "$_t" ;;
        spring-app-yml-path)  resolve_spring_app_yml_path "$_t" ;;
        *) echo "" ;;
    esac
}

# labels.yml에서 질문 문구 조회 (없으면 키명). $1=KEY
LABELS_FILE="${LABELS_FILE:-.github/wizard/labels.yml}"
wf_label() {
    local _k="$1" _v=""
    if [ -f "$LABELS_FILE" ]; then
        _v=$(sed -nE "s~^${_k}:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*\$~\1~p" "$LABELS_FILE" | head -1)
    fi
    [ -n "$_v" ] && echo "$_v" || echo "$_k"
}
```

- [ ] **Step 4: `_wf_set_env` 교체 (마커 줄 삭제로)**

`_wf_set_env`(2813-2823)를 교체:
```bash
# env 키 값 치환 + 그 줄의 # @wizard 주석 삭제. $1=파일 $2=KEY $3=값
_wf_set_env() {
    local _file="$1" _key="$2" _val="$3" _esc
    _esc=$(printf '%s' "$_val" | sed 's/[&~\\]/\\&/g')
    # 값 치환: KEY: "..." 따옴표 안
    sed -i.wftmp -E "s~^([[:space:]]*${_key}:[[:space:]]*\")[^\"]*(\")~\1${_esc}\2~" "$_file" 2>/dev/null
    # 그 줄 끝의 # @wizard ... 주석 제거(공백째)
    sed -i.wftmp -E "s~(^[[:space:]]*${_key}:.*[^[:space:]])[[:space:]]*#[[:space:]]*@wizard[[:space:]].*\$~\1~" "$_file" 2>/dev/null
    rm -f "$_file.wftmp"
}
```

- [ ] **Step 5: `configure_workflow_env` 새 파서로 교체**

`configure_workflow_env`(2868-3002)의 마커 처리 루프를 교체. 핵심 — `# @wizard <action>:<arg>` 파싱, ask/auto 분기, `@name`→resolver, label은 wf_label:
```bash
configure_workflow_env() {
    local _type="$1" _file="$2"
    [ -f "$_file" ] || return 0
    grep -q "@wizard" "$_file" 2>/dev/null || return 0

    # 일괄 기본값 모드 1회 질문 (기존 로직 유지)
    if [ -z "${WF_USE_DEFAULTS:-}" ]; then
        if [ "$FORCE_MODE" = true ] || [ "$TTY_AVAILABLE" != true ]; then
            WF_USE_DEFAULTS=true
        else
            print_to_user ""
            print_step "배포 워크플로우 환경설정을 채웁니다"
            local _ans=""
            safe_read "  전부 기본값으로 빠르게 채울까요? (Y=전부기본 / n=하나씩) [Y]: " _ans "-n 1" || _ans=""
            print_to_user ""
            case "$_ans" in n|N) WF_USE_DEFAULTS=false ;; *) WF_USE_DEFAULTS=true ;; esac
        fi
    fi

    local _line _key _action _arg _val
    while IFS= read -r _line; do
        _key=$(printf '%s' "$_line" | sed -nE 's|^[[:space:]]*([A-Z_]+):.*#[[:space:]]*@wizard[[:space:]].*|\1|p')
        [ -z "$_key" ] && continue
        _action=$(printf '%s' "$_line" | sed -nE 's~.*#[[:space:]]*@wizard[[:space:]]+(ask|auto):.*~\1~p')
        _arg=$(printf '%s' "$_line" | sed -nE 's~.*#[[:space:]]*@wizard[[:space:]]+(ask|auto):(.*)$~\2~p' | sed 's/[[:space:]]*$//')
        [ -z "$_action" ] && continue

        case "$_action" in
            auto)
                _val=$(resolve_token "$_type" "$_arg")
                ;;
            ask)
                # 기본값: @name이면 resolver, 아니면 리터럴. 재실행 기존값 우선.
                local _default
                case "$_arg" in
                    @*) _default=$(resolve_token "$_type" "${_arg#@}") ;;
                    *)  _default="$_arg" ;;
                esac
                local _saved; _saved=$(wf_deploy_get "$_type" "$_key")
                [ -n "$_saved" ] && _default="$_saved"
                if [ "$WF_USE_DEFAULTS" = true ]; then
                    _val="$_default"
                else
                    local _label _in=""
                    _label=$(wf_label "$_key")
                    safe_read "  ${_label} [기본: ${_default}]: " _in "" || _in=""
                    [ -z "$_in" ] && _val="$_default" || _val="$_in"
                fi
                wf_deploy_set "$_type" "$_key" "$_val"
                ;;
        esac
        [ -n "$_val" ] && _wf_set_env "$_file" "$_key" "$_val"
    done < <(grep -nE "#[[:space:]]*@wizard[[:space:]]+(ask|auto):" "$_file" | sed 's/^[0-9]*://')

    # 재귀 토큰 치환: 남은 __PROJECT_NAME__ (VOLUME 경로 등)
    if grep -q "__PROJECT_NAME__" "$_file" 2>/dev/null; then
        local _esc_repo; _esc_repo=$(printf '%s' "$(detect_repo_name)" | sed 's/[&|\\]/\\&/g')
        sed -i.wftmp "s|__PROJECT_NAME__|$_esc_repo|g" "$_file"; rm -f "$_file.wftmp"
    fi

    # paths-anchor (불변 — 기존 로직 그대로 유지)
    if grep -q "#[[:space:]]*@wizard paths-anchor" "$_file" 2>/dev/null; then
        local _ppath; _ppath=$(get_path_for_type "$_type")
        if [ -n "$_ppath" ] && [ "$_ppath" != "." ]; then
            local _indent; _indent=$(grep "@wizard paths-anchor" "$_file" | sed -E 's/([[:space:]]*).*/\1/' | head -1)
            sed -i.wftmp "s~^[[:space:]]*#[[:space:]]*@wizard paths-anchor.*~${_indent}paths: ['${_ppath}/**']~" "$_file"; rm -f "$_file.wftmp"
        fi
    fi

    if grep -qE "__[A-Z_]+__" "$_file" 2>/dev/null; then
        local _leftover; _leftover=$(grep -oE "__[A-Z_]+__" "$_file" | sort -u | tr '\n' ' ')
        print_warning "  $(basename "$_file"): 미치환 토큰 남음($_leftover) — 직접 채워주세요"
    fi
}
```

- [ ] **Step 6: 하네스 재실행 → 통과 확인**

Run: `bash /tmp/test_sh_engine.sh`
Expected:
```
PROJECT_NAME: "myrepo"
JAVA_VERSION: "21"
DEPLOY_PORT: "8080"
APPLICATION_YML_DIR: "src/main/resources"
```
그리고 `@wizard` 줄이 결과에 **없어야** 함(마커 삭제 확인).

- [ ] **Step 7: bash 문법 검사**

Run: `bash -n /d/0-suh/project/suh-github-template/template_integrator.sh`
Expected: 출력 없음(문법 OK).

- [ ] **Step 8: 하네스 정리 + 커밋**

```bash
rm -f /tmp/test_sh_engine.sh
git add template_integrator.sh
git commit -m "integrator.sh 마커 엔진을 resolver 디스패처 + 새 문법 파서로 교체 : refactor : default_for_type_key 하드코딩 표 제거하고 resolve_token(repo/spring-app-yml-dir/path) 도입, @wizard ask:기본값/auto:resolver 파싱·labels.yml 질문문구·치환후 마커삭제로 configure_workflow_env 재작성"
```

---

### Task 3: PowerShell 엔진 교체 (.sh 1:1 미러)

**Files:**
- Modify: `template_integrator.ps1` (제거: `Get-DefaultForTypeKey` 2358-2377 / 교체: `Configure-WorkflowEnv` 2422-2521 마커 루프 / 추가: resolver 함수, `Resolve-Token`, `Get-WfLabel`)
- Test: Docker pwsh 하네스 `/tmp/test_ps_engine.ps1`

**Interfaces:**
- Consumes: Task 1 마커, `labels.yml`, 기존 `Get-RepoName`/`Get-WfDeploy`/`Set-WfDeploy`/`Read-UserInput`/`Print-*`.
- Produces: `Resolve-Token`, `Get-WfLabel`, 새 `Configure-WorkflowEnv` — Task 2 sh와 동일 반환.

- [ ] **Step 1: 실패하는 Docker pwsh 하네스 작성**

Create `/tmp/test_ps_engine.ps1` (함수만 추출해 입력 주입 — CLAUDE.md 방식, AST 통째 로드 금지):
```powershell
$ErrorActionPreference="Stop"
$script:WfUseDefaults=$true; $script:WfDeploy=[ordered]@{}
function Print-Step{param($m)}; function Print-Info{param($m)}; function Print-Warning{param($m)Write-Host "WARN:$m"}
function Print-To-User{param($m)}; function Read-UserInput{param($p,$d) return $d}
function Get-RepoName{ "myrepo" }
function Get-PathForType{param($t) "." }
function Get-WfDeploy{param($t,$k) "" }; function Set-WfDeploy{param($t,$k,$v)}
$script:LabelsFile="/work/labels.yml"
# ↓ 여기에 Configure-WorkflowEnv + resolver + Get-WfLabel 본문을 sed로 주입 (Step3 이후)
# 픽스처
New-Item -ItemType Directory -Force /work/src/main/resources | Out-Null
"server:" | Set-Content /work/src/main/resources/application.yml
Configure-WorkflowEnv "spring" "/work/wf.yaml"
Get-Content /work/wf.yaml | Select-String "PROJECT_NAME:|JAVA_VERSION:|DEPLOY_PORT:|APPLICATION_YML_DIR:|@wizard"
```

- [ ] **Step 2: 현재 ps1 구문 파서 통과 확인 (기준선)**

Run:
```bash
docker run --rm --platform linux/amd64 -v "/d/0-suh/project/suh-github-template":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}'
```
Expected: `PS1_PARSE_OK` (교체 전 기준선).

- [ ] **Step 3: resolver + Resolve-Token + Get-WfLabel 추가**

`Get-DefaultForTypeKey`(2358-2377) **자리에** 교체:
```powershell
function Resolve-Repo { Get-RepoName }
function Resolve-SpringAppYmlDir { param([string]$Type)
    $base='.'; $p=(Get-PathForType $Type); if($p){$base=$p}
    $f=Get-ChildItem -Path $base -Recurse -Filter 'application*.yml' -ErrorAction SilentlyContinue |
       Where-Object { $_.FullName -match 'src[/\\]main[/\\]resources' } | Select-Object -First 1
    if(-not $f){ return '' }
    ((Resolve-Path -Relative $f.FullName) -replace '^\.[/\\]','' -replace '\\','/') -replace '/[^/]+$',''
}
function Resolve-SpringAppYmlPath { param([string]$Type)
    $base='.'; $p=(Get-PathForType $Type); if($p){$base=$p}
    $f=Get-ChildItem -Path $base -Recurse -Filter 'application*.yml' -ErrorAction SilentlyContinue |
       Where-Object { $_.FullName -match 'src[/\\]main[/\\]resources' } | Select-Object -First 1
    if(-not $f){ return '' }
    (Resolve-Path -Relative $f.FullName) -replace '^\.[/\\]','' -replace '\\','/'
}
function Resolve-Token { param([string]$Type,[string]$Name)
    switch ($Name) {
        'repo'                { return (Resolve-Repo) }
        'spring-app-yml-dir'  { return (Resolve-SpringAppYmlDir $Type) }
        'spring-app-yml-path' { return (Resolve-SpringAppYmlPath $Type) }
        default { return '' }
    }
}
function Get-WfLabel { param([string]$Key)
    $lf = if($script:LabelsFile){$script:LabelsFile}else{'.github/wizard/labels.yml'}
    if (Test-Path $lf) {
        foreach($l in Get-Content $lf){
            if($l -match "^${Key}:\s*`"?([^`"]*)`"?\s*$"){ return $Matches[1] }
        }
    }
    return $Key
}
```

- [ ] **Step 4: `Configure-WorkflowEnv` 마커 루프 교체**

2444행 이후 `foreach ($line in $lines)` 루프를 새 파싱으로 교체:
```powershell
    $lines = Get-Content $File
    $newLines = foreach ($line in $lines) {
        if ($line -match '^\s*([A-Z_]+):.*#\s*@wizard\s+(ask|auto):(.*)$') {
            $key=$Matches[1]; $action=$Matches[2]; $arg=$Matches[3].Trim()
            $val=$null
            if ($action -eq 'auto') {
                $val = Resolve-Token $Type $arg
            } else {
                if ($arg -like '@*') { $def = Resolve-Token $Type ($arg.Substring(1)) } else { $def = $arg }
                $saved = Get-WfDeploy $Type $key
                if ($saved) { $def = $saved }
                if ($script:WfUseDefaults) { $val = $def }
                else { $inp = Read-UserInput ("  " + (Get-WfLabel $key)) $def; $val = if([string]::IsNullOrWhiteSpace($inp)){$def}else{$inp} }
                Set-WfDeploy $Type $key $val
            }
            if ($null -ne $val -and $val -ne '') {
                $line = $line -replace "(^\s*${key}:\s*`")[^`"]*(`")", "`${1}$val`${2}"
                # 그 줄의 # @wizard 주석 삭제
                $line = $line -replace "\s*#\s*@wizard\s+(ask|auto):.*$", ""
            }
        }
        $line
    }
    $newLines | Set-Content $File -Encoding UTF8
```
(이후 `__PROJECT_NAME__` 재귀 치환·paths-anchor 블록은 기존 유지.)

- [ ] **Step 5: ps1 구문 파서 재확인**

Run: (Step 2와 동일 Docker 명령)
Expected: `PS1_PARSE_OK`.

- [ ] **Step 6: Docker pwsh 동작 하네스 실행**

함수 본문을 `sed`로 `/tmp/test_ps_engine.ps1`에 주입 후:
```bash
cp /d/0-suh/project/suh-github-template/.github/workflows/project-types/spring/PROJECT-SPRING-SIMPLE-CICD.yaml /tmp/wf.yaml
cp /d/0-suh/project/suh-github-template/.github/wizard/labels.yml /tmp/labels.yml
docker run --rm --platform linux/amd64 -v /tmp:/work -w /work mcr.microsoft.com/powershell:latest pwsh -NoProfile -File /work/test_ps_engine.ps1
```
Expected (sh Task2 Step6과 동일):
```
PROJECT_NAME: "myrepo"
JAVA_VERSION: "21"
DEPLOY_PORT: "8080"
APPLICATION_YML_DIR: "src/main/resources"
```
`@wizard` 줄 없음.

- [ ] **Step 7: 하네스 정리 + 커밋**

```bash
rm -f /tmp/test_ps_engine.ps1 /tmp/wf.yaml /tmp/labels.yml /tmp/src -r 2>/dev/null
git add template_integrator.ps1
git commit -m "integrator.ps1 마커 엔진을 sh와 동일하게 교체 : refactor : Get-DefaultForTypeKey 제거하고 Resolve-Token(repo/spring-app-yml-dir/path)·Get-WfLabel 도입, Configure-WorkflowEnv를 @wizard ask:기본값/auto:resolver 파싱·labels.yml·치환후 마커삭제로 재작성(.sh 1:1)"
```

---

### Task 4: .sh/.ps1 동등성 회귀 검증 (전 타입)

**Files:**
- Test: `/tmp/parity/` (임시 — 타입별 픽스처로 sh·ps1 결과 대조)

**Interfaces:**
- Consumes: Task 1~3 완성본.

- [ ] **Step 1: 타입별 픽스처로 sh 결과 수집**

각 타입 대표 워크플로우(flutter PLAYSTORE, spring SIMPLE, python SIMPLE, react CICD, next CICD)를 Task 2 하네스 방식으로 돌려 치환 결과를 `/tmp/parity/<type>.sh.out`에 저장. flutter는 JAVA_VERSION=17, spring=21, python 포트=8000 등 **타입별 리터럴이 맞게 박히는지** 확인.

Run: 각 타입별로 하네스 실행 → 결과 저장.
Expected: 각 타입의 env가 기대값으로 치환, `@wizard` 줄 0개.

- [ ] **Step 2: 동일 픽스처로 ps1 결과 수집 + 대조**

같은 픽스처를 Docker pwsh 하네스로 돌려 `/tmp/parity/<type>.ps.out` 저장 후 `diff`:
```bash
for t in flutter spring python react next; do diff "/tmp/parity/$t.sh.out" "/tmp/parity/$t.ps.out" && echo "$t OK" || echo "$t MISMATCH"; done
```
Expected: 전부 `OK`(sh·ps1 치환 결과 동일).

- [ ] **Step 3: 기존 동작 회귀 — Spring application.yml 탐색값**

마이그레이션 전 git stash로 구엔진 결과를 받아 둘 필요 없이, **기대값 직접 대조**: spring SIMPLE에서 `APPLICATION_YML_DIR`이 `src/main/resources`(픽스처 기준)로, PR-PREVIEW에서 `APPLICATION_YML_PATH`가 `src/main/resources/application.yml`로 나오는지.
Expected: 일치.

- [ ] **Step 4: labels.yml 폴백 검증**

`labels.yml`을 임시로 비우고(또는 없는 키로) `WF_USE_DEFAULTS=false`+입력 스텁으로 sh 하네스 실행 → 질문 프롬프트가 env 키명(예: `JAVA_VERSION [기본: 21]`)으로 뜨는지. labels.yml 파일 자체를 지운 케이스도.
Expected: 키명 폴백 동작, 에러 없음.

- [ ] **Step 5: 정리 + 커밋(검증 메모)**

검증 통과 확인 후 임시 디렉토리 정리. 코드 변경 없으면 커밋 생략(검증만). 변경 있었으면:
```bash
rm -rf /tmp/parity
git add -A && git commit -m "wizard 마커 엔진 .sh/.ps1 동등성·회귀 검증 반영 : test : 타입별 픽스처로 sh·ps1 치환 결과 대조 및 labels.yml 폴백 확인"
```

---

## Self-Review

**1. Spec coverage** (마커 스펙 §3~6 대조):
- §3-1 마커 문법(ask:/auto:) → Task 1(마이그레이션) + Task 2/3(파서). ✓
- §3-2 labels.yml + 폴백 → Task 1(생성), Task 2 `wf_label`/Task 3 `Get-WfLabel`, Task 4 Step4(폴백 검증). ✓
- §3-3 resolver 레지스트리(repo/spring-app-yml-dir/path) + 타입별 기본값 리터럴 → Task 2/3 resolver, Task 1 Step3/4(리터럴). ✓
- §3-4 처리 흐름(auto/ask 분기, @토큰 해소, 마커 삭제, version.yml 저장) → Task 2 Step5/Task 3 Step4. ✓
- §3-5 paths-anchor 불변 → Task 2 Step5(유지 명시). ✓
- §4 마이그레이션(ask 39 + auto-find 4) → Task 1 Step2~5. ✓
- §5 검증(.sh/.ps1 동등, Spring 회귀, label 폴백, 마커삭제) → Task 4 + 각 Task 검증 Step. ✓
- §6 비범위(flutter-root 후행, YAML 파서 전면도입 안 함) → 계획도 flutter-root 제외, sed 줄단위 유지. ✓

**2. Placeholder scan:** 모든 코드 Step에 실제 bash/PowerShell 코드 포함. "적절히 처리" 류 없음. ✓

**3. Type consistency:** `resolve_token`(sh)/`Resolve-Token`(ps1) 시그니처 `(type, name)` 일치. resolver명(repo/spring-app-yml-dir/spring-app-yml-path) 세 곳(카탈로그·Task2·Task3) 동일. `wf_label`/`Get-WfLabel` 폴백 동일. `_wf_set_env` 마커삭제 정규식과 `Configure-WorkflowEnv` -replace 마커삭제 동일 동작. ✓
