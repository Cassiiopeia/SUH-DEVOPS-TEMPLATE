# 마법사 배포 env 설정 UX 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 마법사가 배포 워크플로우 env를 채울 때, 각 값이 어느 워크플로우/타입에 쓰이는지(사용처)를 보여주고, Y/N 텍스트 입력을 기본값 미리보기 표 + 메뉴(1=전부기본/2=하나씩/3=골라서) 선택으로 바꾼다.

**Architecture:** 현재 "워크플로우 파일별 즉시 처리" 흐름은 그대로 두되, **타입 루프 진입 전에** 전 워크플로우를 스캔해 ask KEY를 모으고(수집), 기본값 표 + 메뉴를 한 번 보여주고, 확정된 값을 기존 `wf_deploy` 캐시에 미리 채운다(prefill). 이후 파일별 치환 함수는 캐시된 값을 꺼내 쓰기만 하므로 "설치 예상 최종형 가상 비교" 경로도 무손상이다. 사용처 문자열은 실제 파일명을 스캔해 만들고, 파일명→사람말 매핑은 `labels.yml`의 `_workflow_names:` 섹션에서 읽는다(없으면 파일명 그대로 폴백).

**Tech Stack:** Bash (POSIX-ish, `set -e`), Windows PowerShell 5.1 / PS Core. 기존 함수 재사용: `interactive_menu`/`Invoke-ChooseMenu`(단일·`--multi`/`-Multi` 멀티, CSV 반환), `wf_field`/`Get-WfField`(labels.yml label/help/example), `wf_deploy_get`/`wf_deploy_set`·`Get-WfDeploy`/`Set-WfDeploy`(KEY 캐시), `_wf_labels_path`/`Get-WfLabelsPath`(labels.yml 경로 폴백), `resolve_token`/`Resolve-Token`(@name 기본값).

## Global Constraints

- `.sh`와 `.ps1`은 **1:1 동일 동작**. 한쪽을 바꾸면 반드시 다른 쪽도 동일 의미로 바꾼다.
- env KEY 이름·labels.yml의 label/help/example·워크플로우 YAML의 `run:`/`uses:`/`with:`/`steps:`는 **건드리지 않는다**. 화면/흐름만 바꾼다.
- "전부 기본값(1번)" 경로의 최종 토큰 치환 결과는 변경 전과 **byte-identical**이어야 한다(최우선 회귀 가드).
- 비대화형/FORCE 모드(`FORCE_MODE=true`/`$script:Force`/`TTY_AVAILABLE != true`)는 표·메뉴 없이 "전부 기본값"으로 자동 진행.
- 메뉴 ESC(취소): `.sh`는 `var=$(menu) || rc=$?`로 비-0 종료코드를 흡수해 `set -e`에서 마법사가 통째로 죽지 않게 한다. `.ps1` 메뉴는 취소 시 `$null` 반환.
- 멀티선택 반환은 **CSV 문자열**(`.sh` `interactive_menu --multi`, `.ps1` `Invoke-ChooseMenu -Multi`). 옵션 형식은 `.sh` `"value|label"`, `.ps1` `@{Value=..; Label=..}`.
- 검증 임시 파일(`/tmp/*.sh`, `/tmp/*.ps1`, `/tmp/*.exp`)은 각 태스크 끝에서 정리한다.
- 커밋 메시지에 AI 서명/이모지 태그 금지(CLAUDE.md). 커밋은 사용자 컨벤션 형식 `{제목} : {타입} : {설명} {이슈URL}`을 따른다.

## 참조 — 기존 코드 좌표 (구현 시점에 줄 번호 재확인할 것; 편집으로 밀릴 수 있음)

- `.sh` `configure_workflow_env()` ≈ 2938. ask 분기 ≈ 2970~2992. Y/N 최초 1회 ≈ 2943~2955.
- `.sh` `_copy_workflows_for_type()` ≈ 3049. 파일 루프 내 `configure_workflow_env "$type" "$_target"` ≈ 3215. 타입 순회 `_copy_workflows_for_type "$_t" ...` ≈ 3284 (이 순회의 **진입 직전**이 수집/표/메뉴를 끼울 자리).
- `.sh` "가상 최종형" `configure_workflow_env "$_type" "$_tmp" >/dev/null 2>&1` ≈ 3038 (이 경로는 사용자에게 안 물어야 함 — prefill·캐시만 사용).
- `.sh` `wf_field()` ≈ 2831, `_wf_labels_path()` ≈ 2807, `wf_deploy_get/set` ≈ 2853~, `resolve_token` ≈ 2799 위.
- `.ps1` `Configure-WorkflowEnv` ≈ 2493. ask 분기 ≈ 2521~2538. Y/N ≈ 2501~2512. 파일 루프 호출 ≈ 2819. 가상 최종형 ≈ 2596.
- `.ps1` `Invoke-ChooseMenu` ≈ 573(멀티 CSV 반환, 취소 `$null`), `Get-WfField` ≈ 2432, `Get-WfLabelsPath` ≈ 2396, `Get/Set-WfDeploy` ≈ 2450~, `Resolve-Token` ≈ 2370 근처.
- `.ps1` `copy_workflows` 타입 순회: `Copy-Workflows`(메인 흐름 3638 근처에서 호출). 타입 루프 진입 직전이 수집/표/메뉴 자리.

---

## Task 1: labels.yml에 `_workflow_names` 매핑 섹션 추가

**Files:**
- Modify: `.github/wizard/labels.yml` (파일 끝에 섹션 추가)

**Interfaces:**
- Produces: `labels.yml`에 `_workflow_names:` 블록. Task 2의 `wf_workflow_name()`/`Get-WfWorkflowName`이 이 블록을 부분매칭으로 읽는다.

- [ ] **Step 1: labels.yml 끝에 매핑 섹션 추가**

`.github/wizard/labels.yml`의 마지막 KEY 블록(`SSH_AUTH_METHOD`) 다음에 빈 줄 두고 아래를 그대로 추가한다:

```yaml

# ── 워크플로우 파일명(부분 매칭) → 사람이 읽는 짧은 이름 ──
# 마법사가 env 질문에 "[사용처]"를 만들 때 쓴다.
# 키는 워크플로우 파일명에 포함되는 부분 문자열, 값은 표시용 이름.
# 매핑에 없으면 파일명(확장자 제거) 그대로 표시되므로, 안 적어도 깨지지 않는다.
_workflow_names:
  NONSTOP-NGINX: "무중단배포(Nginx)"
  NONSTOP-TRAEFIK: "무중단배포(Traefik)"
  PR-PREVIEW: "PR 프리뷰"
  SIMPLE-CICD: "단일 서버 배포"
  REACT-CICD: "프론트 배포"
  REACT-CI: "프론트 빌드"
  NEXT-CICD: "프론트 배포"
  NEXT-CI: "프론트 빌드"
  PYTHON-CI: "빌드 검증"
  FLUTTER-ANDROID-SELFHOSTED: "안드로이드 자체배포"
  FLUTTER-ANDROID-PLAYSTORE: "플레이스토어 배포"
  FLUTTER-ANDROID-FIREBASE: "Firebase 배포"
```

> 주의: 매핑 키는 **긴 것이 먼저** 오도록 둔다(`REACT-CICD`를 `REACT-CI`보다 앞에). 부분매칭에서 짧은 키가 먼저 잡히는 것을 막는다.

- [ ] **Step 2: KEY 블록 파서가 이 섹션을 KEY로 오인하지 않는지 확인**

`_wf_read_field`(.sh)/`Read-WfField`(.ps1)는 대문자로 시작하는 `KEY:`만 블록으로 잡는다. `_workflow_names`는 소문자 `_`로 시작하므로 매칭되지 않는다. 아래로 확인:

Run:
```bash
cd /d/0-suh/project/suh-github-template
grep -nE '^_workflow_names:' .github/wizard/labels.yml && echo "SECTION_OK"
```
Expected: `SECTION_OK` 출력. 기존 KEY 조회에 영향 없음(이 섹션은 대문자 KEY가 아님).

- [ ] **Step 3: Commit**

```bash
git add .github/wizard/labels.yml
git commit -m "마법사 배포 env 설정 UX 개선 : feat : labels.yml에 워크플로우 파일명->사람말 매핑(_workflow_names) 섹션 추가 https://github.com/Cassiiopeia/projectops/issues/410"
```

---

## Task 2: 파일명 → 사람말 변환 헬퍼 (`.sh`/`.ps1`)

**Files:**
- Modify: `template_integrator.sh` (`_wf_labels_path` 정의 다음에 함수 추가)
- Modify: `template_integrator.ps1` (`Get-WfLabelsPath` 정의 다음에 함수 추가)
- Test: `/tmp/t2.sh`, `/tmp/t2.ps1` (임시 하네스)

**Interfaces:**
- Consumes: `_wf_labels_path()`/`Get-WfLabelsPath`(labels.yml 경로), `$TEMP_DIR`.
- Produces:
  - `.sh` `wf_workflow_name <filename>` → stdout: 사람말(매핑 히트) 또는 파일명(확장자 제거). 항상 exit 0.
  - `.ps1` `Get-WfWorkflowName([string]$FileName)` → string 반환(동일 의미).

- [ ] **Step 1: `.sh` 헬퍼 작성 (failing 하네스 먼저)**

`/tmp/t2.sh` 생성:

```bash
cat > /tmp/t2.sh <<'SH'
LABELS_FILE=".github/wizard/labels.yml"; TEMP_DIR=".template_download_temp"
_wf_labels_path(){ if [ -f "$LABELS_FILE" ]; then echo "$LABELS_FILE"; return; fi; local s="$TEMP_DIR/.github/wizard/labels.yml"; [ -f "$s" ] && { echo "$s"; return; }; echo ""; }
# === 여기에 구현 붙임 (Step 2) ===
echo "1) $(wf_workflow_name PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml)"
echo "2) $(wf_workflow_name PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml)"
echo "3) $(wf_workflow_name PROJECT-REACT-CICD.yaml)"
echo "4) $(wf_workflow_name PROJECT-UNKNOWN-FOO-CICD.yaml)"
SH
cd /d/0-suh/project/suh-github-template && bash /tmp/t2.sh 2>&1 | head
```
Expected: `wf_workflow_name: command not found` (아직 미구현).

- [ ] **Step 2: `.sh`에 `wf_workflow_name` 구현**

`template_integrator.sh`의 `_wf_labels_path()` 함수 닫는 `}` **다음 줄**에 추가:

```bash
# 워크플로우 파일명 → 사람이 읽는 짧은 이름.
# labels.yml의 _workflow_names: 블록에서 "키가 파일명에 포함되면" 그 값 사용(긴 키 우선).
# 매핑 없으면 파일명에서 .yaml/.yml 확장자만 제거해 그대로 반환.
wf_workflow_name() {
    local _file="$1" _base _lf _line _key _val _best="" _bestlen=0
    _base="${_file##*/}"                 # 경로 제거
    _lf=$(_wf_labels_path)
    if [ -n "$_lf" ]; then
        # _workflow_names: 블록 안의 "  KEY: "값"" 라인을 스캔
        local _inblk=false
        while IFS= read -r _line; do
            case "$_line" in
                _workflow_names:*) _inblk=true; continue ;;
            esac
            if [ "$_inblk" = true ]; then
                # 비들여쓰기 라인 만나면 블록 끝
                case "$_line" in
                    [!\ ]*) _inblk=false; continue ;;
                esac
                _key=$(printf '%s' "$_line" | sed -nE 's/^[[:space:]]+([A-Za-z0-9_-]+):[[:space:]]*".*"[[:space:]]*$/\1/p')
                [ -z "$_key" ] && continue
                case "$_base" in
                    *"$_key"*)
                        # 가장 긴 키 매칭 우선
                        if [ "${#_key}" -gt "$_bestlen" ]; then
                            _val=$(printf '%s' "$_line" | sed -nE 's/^[[:space:]]+[A-Za-z0-9_-]+:[[:space:]]*"(.*)"[[:space:]]*$/\1/p')
                            _best="$_val"; _bestlen="${#_key}"
                        fi
                        ;;
                esac
            fi
        done < "$_lf"
    fi
    if [ -n "$_best" ]; then echo "$_best"; return; fi
    # 폴백: 확장자만 제거
    echo "${_base%.y*ml}"
}
```

- [ ] **Step 3: `.sh` 하네스 재실행 (pass 확인)**

Run: `cd /d/0-suh/project/suh-github-template && bash /tmp/t2.sh`
Expected:
```
1) 무중단배포(Nginx)
2) 무중단배포(Traefik)
3) 프론트 배포
4) PROJECT-UNKNOWN-FOO-CICD
```

- [ ] **Step 4: `.ps1`에 `Get-WfWorkflowName` 구현**

`template_integrator.ps1`의 `Get-WfLabelsPath` 함수 닫는 `}` 다음에 추가:

```powershell
# 워크플로우 파일명 -> 사람이 읽는 짧은 이름 (.sh wf_workflow_name과 1:1).
function Get-WfWorkflowName { param([string]$FileName)
    $base = Split-Path $FileName -Leaf
    $lf = Get-WfLabelsPath
    $best = ''; $bestLen = 0
    if ($lf) {
        $inblk = $false
        foreach ($l in Get-Content $lf -Encoding UTF8) {
            if ($l -match '^_workflow_names:') { $inblk = $true; continue }
            if ($inblk) {
                if ($l -match '^\S') { $inblk = $false; continue }
                if ($l -match '^\s+([A-Za-z0-9_-]+):\s*"(.*)"\s*$') {
                    $k = $Matches[1]; $v = $Matches[2]
                    if ($base -like "*$k*" -and $k.Length -gt $bestLen) { $best = $v; $bestLen = $k.Length }
                }
            }
        }
    }
    if ($best) { return $best }
    return ($base -replace '\.ya?ml$','')
}
```

- [ ] **Step 5: `.ps1` 하네스로 검증**

`/tmp/t2.ps1` 생성 (Get-WfLabelsPath 스텁 + 위 함수 본문 붙여넣고 4케이스 호출). labels.yml은 실제 경로로 지정.

```bash
cat > /tmp/t2.ps1 <<'PS'
$ErrorActionPreference="Stop"
$lf="D:\0-suh\project\suh-github-template\.github\wizard\labels.yml"
function Get-WfLabelsPath { return $lf }
# === Get-WfWorkflowName 본문 붙여넣기 (Step 4) ===
'1) ' + (Get-WfWorkflowName 'PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml')
'2) ' + (Get-WfWorkflowName 'PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml')
'3) ' + (Get-WfWorkflowName 'PROJECT-REACT-CICD.yaml')
'4) ' + (Get-WfWorkflowName 'PROJECT-UNKNOWN-FOO-CICD.yaml')
PS
powershell -NoProfile -ExecutionPolicy Bypass -File /tmp/t2.ps1
```
Expected: `.sh`와 동일한 4줄 출력(무중단배포(Nginx)/무중단배포(Traefik)/프론트 배포/PROJECT-UNKNOWN-FOO-CICD).

- [ ] **Step 6: 문법 검사 + 정리 + Commit**

```bash
cd /d/0-suh/project/suh-github-template
bash -n template_integrator.sh && echo SH_OK
rm -f /tmp/t2.sh /tmp/t2.ps1
git add template_integrator.sh template_integrator.ps1
git commit -m "마법사 배포 env 설정 UX 개선 : feat : 워크플로우 파일명->사람말 변환 헬퍼(wf_workflow_name/Get-WfWorkflowName) 추가 https://github.com/Cassiiopeia/projectops/issues/410"
```
`.ps1` 문법은 Docker PowerShell이 있으면 `Parser::ParseFile`로, 없으면 로컬 `powershell -Command "[Parser]::ParseFile(...)"`로 확인.

---

## Task 3: ask KEY 수집기 (전 워크플로우 스캔 → KEY 테이블)

**Files:**
- Modify: `template_integrator.sh` (`configure_workflow_env` 위에 함수 추가)
- Modify: `template_integrator.ps1` (`Configure-WorkflowEnv` 위에 함수 추가)
- Test: `/tmp/t3.sh`

**Interfaces:**
- Consumes: 설치 대상 워크플로우 파일 목록, `resolve_token`/`Resolve-Token`, `wf_deploy_get`/`Get-WfDeploy`, `wf_workflow_name`/`Get-WfWorkflowName`(Task 2).
- Produces:
  - `.sh` `wf_collect_asks <type1> <type2> ...` → 전역 배열 채움: `WF_ASK_KEYS`(KEY 순서, 중복 제거), `WF_ASK_DEFAULT[key]`, `WF_ASK_SCOPE[key]`(사용처 문자열). (bash 4 연관배열; 없으면 `KEY=val` CSV로 폴백 — 아래 주석 참조)
  - `.ps1` `Get-WfAskTable([string[]]$Types)` → `[ordered]@{}` 반환: key → `@{ Default=..; Scope=.. }`.

> 수집 대상 파일 경로 규칙: `$WORKFLOWS_DIR/$PROJECT_TYPES_DIR/<type>/` 아래 `*.yaml`+`*.yml` 중 `@wizard ask:` 마커를 가진 것. (이미 `_copy_workflows_for_type`이 같은 디렉토리를 쓰므로 동일 규칙.)

- [ ] **Step 1: `.sh` 수집기 작성**

`configure_workflow_env()` 정의 **바로 위**에 추가. (bash 연관배열 사용; 스크립트가 이미 bash 전제이므로 OK. 만약 `declare -A` 미지원 환경 우려가 있으면 CSV 누적으로 대체하되, 본 계획은 연관배열 기준.)

```bash
# ask KEY를 전 워크플로우에서 수집. 결과는 전역 배열에 채운다.
# WF_ASK_KEYS: KEY 등장 순서(중복 제거). WF_ASK_DEFAULT/WF_ASK_SCOPE: KEY별 기본값/사용처.
declare -gA WF_ASK_DEFAULT 2>/dev/null || true
declare -gA WF_ASK_SCOPE 2>/dev/null || true
WF_ASK_KEYS=()
# KEY -> 등장 파일들의 "type|name" 누적 (사용처 조립용)
declare -gA WF_ASK_FILES 2>/dev/null || true

wf_collect_asks() {
    WF_ASK_KEYS=(); WF_ASK_DEFAULT=(); WF_ASK_SCOPE=(); WF_ASK_FILES=()
    local _type _dir _f _base _line _key _action _arg _default _saved
    for _type in "$@"; do
        _dir="$WORKFLOWS_DIR/$PROJECT_TYPES_DIR/$_type"
        [ -d "$_dir" ] || continue
        for _f in "$_dir"/*.yaml "$_dir"/*.yml; do
            [ -f "$_f" ] || continue
            grep -q "@wizard" "$_f" 2>/dev/null || continue
            _base="${_f##*/}"
            while IFS= read -r _line; do
                _key=$(printf '%s' "$_line" | sed -nE 's|^[[:space:]]*([A-Z_]+):.*#[[:space:]]*@wizard[[:space:]]+ask:.*|\1|p')
                [ -z "$_key" ] && continue
                _arg=$(printf '%s' "$_line" | sed -nE 's~.*#[[:space:]]*@wizard[[:space:]]+ask:(.*)$~\1~p' | sed 's/[[:space:]]*$//')
                # 기본값: @name이면 resolver, 아니면 리터럴. 재통합 저장값 우선.
                case "$_arg" in
                    @*) _default=$(resolve_token "$_type" "${_arg#@}") ;;
                    *)  _default="$_arg" ;;
                esac
                _saved=$(wf_deploy_get "$_type" "$_key"); [ -n "$_saved" ] && _default="$_saved"
                # KEY 처음 보면 등록
                if [ -z "${WF_ASK_DEFAULT[$_key]+x}" ]; then
                    WF_ASK_KEYS+=("$_key")
                    WF_ASK_DEFAULT[$_key]="$_default"
                fi
                # 사용처 파일 누적 (type|humanname)
                local _hn; _hn=$(wf_workflow_name "$_base")
                WF_ASK_FILES[$_key]="${WF_ASK_FILES[$_key]:+${WF_ASK_FILES[$_key]}\n}${_type}|${_hn}"
            done < <(grep -nE '^[[:space:]]*[A-Z_]+:.*@wizard[[:space:]]+ask:' "$_f")
        done
    done
    # 사용처 문자열 조립 (Task 4의 wf_scope_string 사용)
    local _k
    for _k in "${WF_ASK_KEYS[@]}"; do
        WF_ASK_SCOPE[$_k]=$(wf_scope_string "${WF_ASK_FILES[$_k]}")
    done
}
```

> `wf_scope_string`은 Task 4에서 정의한다. Task 3 단독 테스트 시에는 `wf_scope_string(){ echo "$1" | tr '\n' ','; }` 스텁으로 둔다.

- [ ] **Step 2: `.sh` 수집기 하네스 테스트**

`/tmp/t3.sh`에서 실제 스크립트를 `source`(main 미실행)하고 spring,react 두 타입 수집 후 KEY/기본값/사용처를 출력:

```bash
cat > /tmp/t3.sh <<'SH'
cd /d/0-suh/project/suh-github-template
WORKFLOWS_DIR=".github/workflows"; PROJECT_TYPES_DIR="project-types"
source ./template_integrator.sh
# resolver/저장값은 실제 함수 사용. 사용처는 Task4 전이면 스텁:
type wf_scope_string >/dev/null 2>&1 || wf_scope_string(){ printf '%s' "$1" | tr '\n' ',' ; }
wf_collect_asks spring react
for k in "${WF_ASK_KEYS[@]}"; do
  echo "$k | def=${WF_ASK_DEFAULT[$k]} | scope=${WF_ASK_SCOPE[$k]}"
done
SH
bash /tmp/t3.sh
```
Expected (정확한 def값은 resolver에 따라 다를 수 있음 — KEY 목록과 SERVICE_DOMAIN이 spring nginx/traefik만 가리키는지가 핵심):
```
PROJECT_NAME | def=... | scope=...spring...react...
SERVICE_DOMAIN | def=... | scope=...무중단배포(Nginx)...무중단배포(Traefik)...
JAVA_VERSION | def=... | scope=...
... (react는 PROJECT_NAME만 추가, 중복 없음)
```

- [ ] **Step 3: `.ps1` 수집기 구현**

`Configure-WorkflowEnv` 정의 위에 추가:

```powershell
# ask KEY를 전 워크플로우에서 수집 -> [ordered] key->@{Default;Scope}
function Get-WfAskTable { param([string[]]$Types)
    $table = [ordered]@{}
    $files = @{}   # key -> @("type|humanname", ...)
    foreach ($t in $Types) {
        $dir = Join-Path $WORKFLOWS_DIR (Join-Path $PROJECT_TYPES_DIR $t)
        if (-not (Test-Path $dir)) { continue }
        $wf = @(); $wf += Get-ChildItem -Path $dir -Filter '*.yaml' -File -ErrorAction SilentlyContinue
        $wf += Get-ChildItem -Path $dir -Filter '*.yml' -File -ErrorAction SilentlyContinue
        foreach ($f in $wf) {
            $raw = Get-Content $f.FullName -Raw
            if ($raw -notmatch '@wizard') { continue }
            foreach ($line in (Get-Content $f.FullName)) {
                if ($line -match '^\s*([A-Z_]+):.*#\s*@wizard\s+ask:(.*)$') {
                    $key = $Matches[1]; $arg = $Matches[2].Trim()
                    if ($arg -like '@*') { $def = Resolve-Token $t ($arg.Substring(1)) } else { $def = $arg }
                    $saved = Get-WfDeploy $t $key
                    if ($saved) { $def = $saved }
                    if (-not $table.Contains($key)) {
                        $table[$key] = @{ Default = $def; Scope = '' }
                        $files[$key] = @()
                    }
                    $files[$key] += ($t + '|' + (Get-WfWorkflowName $f.Name))
                }
            }
        }
    }
    foreach ($key in @($table.Keys)) {
        $table[$key].Scope = Get-WfScopeString $files[$key]   # Task 4
    }
    return $table
}
```

> `Get-WfScopeString`은 Task 4. 단독 테스트 시 스텁: `function Get-WfScopeString($a){ ($a -join ',') }`.

- [ ] **Step 4: `.ps1` 수집기 하네스 테스트**

`/tmp/t3.ps1`에서 스크립트를 dot-source하면 main이 도므로, 대신 **함수 본문만 추출**해 최소 하네스에 붙이고 `Resolve-Token`/`Get-WfDeploy`/`Get-WfWorkflowName`를 스텁으로 덮어 spring,react 수집을 출력. CLAUDE.md의 ".ps1 동작 검증" 패턴(함수 본문만 인라인) 사용.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File /tmp/t3.ps1`
Expected: `.sh`와 동일한 KEY 목록·중복제거·SERVICE_DOMAIN scope에 nginx/traefik만.

- [ ] **Step 5: 문법 + 정리 + Commit**

```bash
cd /d/0-suh/project/suh-github-template
bash -n template_integrator.sh && echo SH_OK
rm -f /tmp/t3.sh /tmp/t3.ps1
git add template_integrator.sh template_integrator.ps1
git commit -m "마법사 배포 env 설정 UX 개선 : feat : 전 워크플로우 ask KEY 수집기(wf_collect_asks/Get-WfAskTable) 추가 https://github.com/Cassiiopeia/projectops/issues/410"
```

---

## Task 4: 사용처 문자열 조립 (`wf_scope_string`/`Get-WfScopeString`)

**Files:**
- Modify: `template_integrator.sh` (수집기 위/근처)
- Modify: `template_integrator.ps1`
- Test: `/tmp/t4.sh`, `/tmp/t4.ps1`

**Interfaces:**
- Consumes: KEY별 `"type|humanname"` 목록(.sh는 개행구분 문자열, .ps1은 string[]).
- Produces:
  - `.sh` `wf_scope_string "<type|name\ntype|name...>"` → stdout 사용처 문자열.
  - `.ps1` `Get-WfScopeString([string[]]$Pairs)` → string.
- 규칙(설계 §4.3): 단일 타입+전부 매핑→`"{타입} {name1·name2}"`; 여러 타입→타입명 `·` join; 매핑 없는 name은 이미 파일명이므로 그대로.

- [ ] **Step 1: `.sh` `wf_scope_string` 작성 (failing 하네스)**

`/tmp/t4.sh`:
```bash
cat > /tmp/t4.sh <<'SH'
# === wf_scope_string 구현 붙임 ===
printf '%s\n' "--1 단일타입 2파일--"; wf_scope_string $'spring|무중단배포(Nginx)\nspring|무중단배포(Traefik)'
printf '%s\n' "--2 멀티타입--";      wf_scope_string $'spring|단일 서버 배포\nreact|프론트 배포\nnext|프론트 배포'
printf '%s\n' "--3 단일타입 1파일--"; wf_scope_string $'flutter|플레이스토어 배포'
SH
bash /tmp/t4.sh 2>&1 | head
```
Expected: `wf_scope_string: command not found`.

- [ ] **Step 2: `.sh` 구현**

`wf_collect_asks` 위에 추가:

```bash
# "type|name" 줄들의 사용처 문자열 조립.
# 단일 타입: "{타입} {name1·name2·...}" (name 중복 제거).
# 여러 타입: "type1·type2·..." (타입만, 중복 제거).
wf_scope_string() {
    local _pairs="$1" _line _t _n
    local _types="" _names=""
    while IFS= read -r _line; do
        [ -z "$_line" ] && continue
        _t="${_line%%|*}"; _n="${_line#*|}"
        case "·$_types·" in *"·$_t·"*) ;; *) _types="${_types:+$_types·}$_t" ;; esac
        case "·$_names·" in *"·$_n·"*) ;; *) _names="${_names:+$_names·}$_n" ;; esac
    done <<< "$(printf '%b' "$_pairs")"
    # 타입 개수 세기
    local _tcount; _tcount=$(printf '%s' "$_types" | awk -F'·' '{print NF}')
    if [ "$_tcount" -le 1 ]; then
        echo "${_types} ${_names}"
    else
        echo "$_types"
    fi
}
```

> 주의: 수집기(Task 3)가 `WF_ASK_FILES`에 literal `\n`(역슬래시 n)을 넣으므로 `printf '%b'`로 실제 개행 복원. (`declare` 배열에 실제 개행 저장이 까다로워 `\n` 마커 사용.)

- [ ] **Step 3: `.sh` 하네스 pass 확인**

Run: `bash /tmp/t4.sh`
Expected:
```
--1 단일타입 2파일--
spring 무중단배포(Nginx)·무중단배포(Traefik)
--2 멀티타입--
spring·react·next
--3 단일타입 1파일--
flutter 플레이스토어 배포
```

- [ ] **Step 4: `.ps1` `Get-WfScopeString` 구현**

```powershell
# "type|name" 쌍들의 사용처 문자열 조립 (.sh wf_scope_string과 1:1).
function Get-WfScopeString { param([string[]]$Pairs)
    $types = @(); $names = @()
    foreach ($p in $Pairs) {
        if (-not $p) { continue }
        $t = $p.Split('|',2)[0]; $n = $p.Split('|',2)[1]
        if ($types -notcontains $t) { $types += $t }
        if ($names -notcontains $n) { $names += $n }
    }
    if ($types.Count -le 1) { return (($types -join '·') + ' ' + ($names -join '·')) }
    return ($types -join '·')
}
```

- [ ] **Step 5: `.ps1` 하네스로 동일 출력 검증**

`/tmp/t4.ps1`에 함수 본문 + 3케이스 호출. Expected: `.sh`와 동일 3블록.

- [ ] **Step 6: 문법 + 정리 + Commit**

```bash
cd /d/0-suh/project/suh-github-template
bash -n template_integrator.sh && echo SH_OK
rm -f /tmp/t4.sh /tmp/t4.ps1
git add template_integrator.sh template_integrator.ps1
git commit -m "마법사 배포 env 설정 UX 개선 : feat : 사용처 문자열 조립 함수(wf_scope_string/Get-WfScopeString) 추가 https://github.com/Cassiiopeia/projectops/issues/410"
```

---

## Task 5: 기본값 미리보기 표 + 1/2/3 메뉴 + 값확정 (prefill)

**Files:**
- Modify: `template_integrator.sh` (새 함수 `wf_prompt_env_plan` + `copy_workflows` 타입 순회 진입 전 호출)
- Modify: `template_integrator.ps1` (새 함수 `Invoke-WfEnvPlan` + `Copy-Workflows` 타입 순회 전 호출)
- Test: `/tmp/t5.exp`(.sh expect), `/tmp/t5.ps1`

**Interfaces:**
- Consumes: Task 3 수집 결과(`WF_ASK_KEYS`/`WF_ASK_DEFAULT`/`WF_ASK_SCOPE` / `Get-WfAskTable`), `wf_field`/`Get-WfField`(label/help/example), `interactive_menu`/`Invoke-ChooseMenu`, `wf_deploy_set`/`Set-WfDeploy`(prefill 대상).
- Produces:
  - `.sh` `wf_prompt_env_plan <type1> <type2> ...` → 표 출력 + 메뉴 + 입력받아 **모든 KEY를 `wf_deploy_set`으로 확정**(각 type별로). 그리고 `WF_USE_DEFAULTS=true` 설정(이후 파일별 `configure_workflow_env`는 캐시값만 씀). 비대화형/FORCE면 표·메뉴 없이 즉시 `WF_USE_DEFAULTS=true`.
  - `.ps1` `Invoke-WfEnvPlan([string[]]$Types)` → 동일. `$script:WfUseDefaults = $true`.

> **핵심 불변**: 확정 후 `WF_USE_DEFAULTS=true`이므로 기존 `configure_workflow_env`의 ask 분기는 "캐시값=기본값" 경로를 타고, 사용자에게 다시 묻지 않는다. 가상 비교(`>/dev/null`) 경로도 동일하게 캐시값 사용 → byte-identical 보장.
> **prefill 대상 type**: 같은 KEY가 여러 type에 등장하면, 그 KEY가 등장한 **모든 type**에 동일 값으로 `wf_deploy_set`한다(현재 캐싱 동작과 동일 결과).

- [ ] **Step 1: `.sh` `wf_prompt_env_plan` 작성**

`configure_workflow_env` 위(수집기 근처)에 추가. 표 출력 → `interactive_menu`로 1/2/3 → 분기:

```bash
# 배포 env 설정 계획: 표 미리보기 + 메뉴(전부기본/하나씩/골라서) + 값 확정(prefill).
# 인자: 설치 대상 type 목록. 호출 후 WF_USE_DEFAULTS=true 로 고정.
wf_prompt_env_plan() {
    [ -n "${WF_USE_DEFAULTS:-}" ] && return 0     # 이미 정해졌으면 재실행 안 함
    # 비대화형/FORCE → 표·메뉴 없이 전부 기본값
    if [ "$FORCE_MODE" = true ] || [ "$TTY_AVAILABLE" != true ]; then
        wf_collect_asks "$@"
        _wf_prefill_all "$@"
        WF_USE_DEFAULTS=true
        return 0
    fi
    wf_collect_asks "$@"
    [ ${#WF_ASK_KEYS[@]} -eq 0 ] && { WF_USE_DEFAULTS=true; return 0; }

    print_to_user ""
    print_step "배포 워크플로우 환경설정을 채웁니다"
    print_to_user ""
    print_to_user "   설치되는 배포 워크플로우가 사용할 값입니다. 아래가 기본값이며,"
    print_to_user "   그대로 두거나 원하는 것만 바꿀 수 있습니다."
    print_to_user ""
    # 표 출력
    local _k _label
    for _k in "${WF_ASK_KEYS[@]}"; do
        _label=$(wf_field "$(_wf_first_type_for "$_k")" "$_k" "label")
        printf '   %-26s %-16s %s\n' "$_label" "${WF_ASK_DEFAULT[$_k]}" "${WF_ASK_SCOPE[$_k]}" >&2
    done

    local _choice _rc=0
    _choice=$(interactive_menu "어떻게 채울까요?" \
        "all|위 기본값 그대로 전부 설치" \
        "each|하나씩 직접 입력" \
        "some|몇 개만 골라서 바꾸기 (나머지는 기본값)") || _rc=$?
    [ "$_rc" -ne 0 ] && { WF_USE_DEFAULTS=true; _wf_prefill_all "$@"; return 0; }   # ESC=전부기본

    case "$_choice" in
        all)  _wf_prefill_all "$@" ;;
        each) _wf_prefill_interactive "$@" "${WF_ASK_KEYS[@]}" ;;
        some)
            # 멀티선택으로 바꿀 KEY 고르기
            local _opts=() _sel _rc2=0
            for _k in "${WF_ASK_KEYS[@]}"; do
                _label=$(wf_field "$(_wf_first_type_for "$_k")" "$_k" "label")
                _opts+=("$_k|${_label}   ${WF_ASK_DEFAULT[$_k]}   ${WF_ASK_SCOPE[$_k]}")
            done
            _sel=$(interactive_menu --multi "바꿀 항목을 고르세요" "${_opts[@]}") || _rc2=$?
            if [ "$_rc2" -ne 0 ] || [ -z "$_sel" ]; then
                _wf_prefill_all "$@"            # 아무것도 안 고름 → 전부 기본
            else
                # 고른 KEY만 입력, 나머지는 기본값으로 prefill
                _wf_prefill_all "$@"           # 일단 전부 기본값
                local _csv_k; IFS=',' read -ra _csv_k <<< "$_sel"
                _wf_prefill_interactive "$@" "${_csv_k[@]}"   # 고른 것만 덮어쓰기 입력
            fi
            ;;
    esac
    WF_USE_DEFAULTS=true
    return 0
}

# KEY가 처음 등장한 type 반환 (label 조회용 — 타입오버라이드 우선순위 때문)
_wf_first_type_for() {
    local _k="$1" _line
    printf '%b' "${WF_ASK_FILES[$_k]}" | head -1 | sed 's/|.*//'
}

# 모든 KEY를 기본값으로 모든 등장 type에 prefill
_wf_prefill_all() {
    local _types=("$@") _k _t _line
    for _k in "${WF_ASK_KEYS[@]}"; do
        # 이 KEY가 등장한 모든 type에 동일 기본값 기록
        while IFS= read -r _line; do
            [ -z "$_line" ] && continue
            _t="${_line%%|*}"
            wf_deploy_set "$_t" "$_k" "${WF_ASK_DEFAULT[$_k]}"
        done <<< "$(printf '%b' "${WF_ASK_FILES[$_k]}")"
    done
}

# 지정한 KEY들만 사용자에게 입력받아 모든 등장 type에 prefill
_wf_prefill_interactive() {
    # 앞쪽 인자 중 type 목록은 무시하고, KEY 인자만 처리하기 위해
    # 호출자가 KEY들을 뒤에 붙여 넘긴다. 여기선 WF_ASK_KEYS 멤버만 골라 처리.
    local _arg _k _t _line _label _help _ex _in _val
    for _arg in "$@"; do
        # WF_ASK_KEYS에 있는 것만 KEY로 간주
        case " ${WF_ASK_KEYS[*]} " in *" $_arg "*) _k="$_arg" ;; *) continue ;; esac
        _t=$(_wf_first_type_for "$_k")
        _label=$(wf_field "$_t" "$_k" "label")
        _help=$(wf_field "$_t" "$_k" "help")
        _ex=$(wf_field "$_t" "$_k" "example")
        print_to_user "  ▸ ${_label}  [${WF_ASK_SCOPE[$_k]}]"
        [ -n "$_help" ] && print_to_user "    ${_help}"
        [ -n "$_ex" ] && print_to_user "    예) ${_ex}"
        _in=""
        safe_read "  값 입력 [기본: ${WF_ASK_DEFAULT[$_k]}]: " _in "" || _in=""
        [ -z "$_in" ] && _val="${WF_ASK_DEFAULT[$_k]}" || _val="$_in"
        while IFS= read -r _line; do
            [ -z "$_line" ] && continue
            _t="${_line%%|*}"
            wf_deploy_set "$_t" "$_k" "$_val"
        done <<< "$(printf '%b' "${WF_ASK_FILES[$_k]}")"
    done
}
```

> `_wf_prefill_interactive`가 인자에서 type과 KEY가 섞여 오지만 `WF_ASK_KEYS` 멤버십으로 KEY만 거른다. (type 이름과 KEY 이름은 겹치지 않음: type은 소문자 `spring`, KEY는 대문자 `PROJECT_NAME`.)

- [ ] **Step 2: `.sh` `copy_workflows` 타입 순회 직전에 호출 추가**

`_copy_workflows_for_type "$_t" "$project_types_dir"` 를 도는 순회(≈3284) **시작 직전**에, 설치 대상 type 목록으로 한 번 호출:

```bash
# (타입 순회 시작 전) 배포 env 계획을 한 번 수립 — 표·메뉴·prefill
wf_prompt_env_plan "${_types_to_install[@]}"
```
정확한 변수명(`_types_to_install` 등 실제 순회에 쓰는 배열)은 구현 시 해당 루프에서 확인해 맞춘다. **이 호출이 들어가면, 기존 `configure_workflow_env` 내부의 Y/N 최초 1회 블록(≈2943~2955)은 `WF_USE_DEFAULTS`가 이미 설정돼 있어 자동 skip**된다 — 그 블록은 폴백으로 남겨둔다(plan 호출이 어떤 이유로 안 됐을 때 안전).

- [ ] **Step 3: `.sh` expect로 동작 검증 (2번/3번)**

`/tmp/t5.exp`로 실제 TTY 주입: 스크립트를 source(main 미실행)하고 감지 함수 스텁 + `wf_prompt_env_plan spring react` 직접 호출. CLAUDE.md의 expect 패턴 사용. 시나리오:
- "2" 선택 → KEY마다 `▸ label [scope]` 뜨고 Enter로 기본값 확정되는지
- "3" 선택 → 멀티선택에서 SERVICE_DOMAIN만 토글 → 그것만 입력 프롬프트 뜨는지

Run: `expect /tmp/t5.exp`
Expected: 표 출력 → 메뉴 → 분기별 입력 화면이 설계 §4.2와 일치. ESC가 마법사를 안 죽임.

- [ ] **Step 4: `.ps1` `Invoke-WfEnvPlan` 구현 + 호출**

`.sh`와 1:1. `Invoke-ChooseMenu`(단일 1/2/3, 멀티 some)·`Set-WfDeploy` prefill·`$script:WfUseDefaults=$true`. `Copy-Workflows`의 타입 순회 직전 호출. 표 출력은 `Write-Host`/`Write-ColorOutput`.

- [ ] **Step 5: `.ps1` 동작 검증**

Docker PowerShell 또는 로컬에서, 함수 본문 추출 + `Invoke-ChooseMenu`/`Read-UserInput`/`Set-WfDeploy` 스텁 주입으로 2번/3번 분기 출력·prefill 호출 인자 확인(CLAUDE.md ".ps1 동작 검증" 패턴).

- [ ] **Step 6: 문법 + 정리 + Commit**

```bash
cd /d/0-suh/project/suh-github-template
bash -n template_integrator.sh && echo SH_OK
rm -f /tmp/t5.exp /tmp/t5.ps1
git add template_integrator.sh template_integrator.ps1
git commit -m "마법사 배포 env 설정 UX 개선 : feat : 기본값 미리보기 표와 전부기본/하나씩/골라서 메뉴 + 값 prefill 도입(Y/N 텍스트 입력 대체) https://github.com/Cassiiopeia/projectops/issues/410"
```

---

## Task 6: 기존 `configure_workflow_env` ask 분기에 사용처 표시 + 회귀 가드

**Files:**
- Modify: `template_integrator.sh` (ask 분기 라벨 출력 한 줄)
- Modify: `template_integrator.ps1` (동일)
- Test: 회귀 비교 스크립트(임시)

**Interfaces:**
- Consumes: Task 3/5의 `WF_ASK_SCOPE`(있으면). 없을 때(직접 경로)는 사용처 생략 — 안전.

> Task 5에서 prefill+`WF_USE_DEFAULTS=true`가 되면 이 분기는 보통 안 타지만, plan 미호출 폴백 시 여전히 쓰인다. 그때도 사용처를 보여주도록 라벨 줄에 scope를 덧붙인다(있을 때만).

- [ ] **Step 1: `.sh` ask 분기 라벨에 scope 덧붙이기**

기존(2986 근처):
```bash
                    print_to_user "  ▸ ${_label}"
```
변경:
```bash
                    _scope="${WF_ASK_SCOPE[$_key]:-}"
                    if [ -n "$_scope" ]; then print_to_user "  ▸ ${_label}  [${_scope}]"; else print_to_user "  ▸ ${_label}"; fi
```
(`_scope` 지역변수 선언을 ask 분기 상단 `local` 목록에 추가.)

- [ ] **Step 2: `.ps1` 동일 변경**

기존(2530):
```powershell
                    Write-ColorOutput ("  ▸ " + $lbl) -ForegroundColor Cyan
```
변경:
```powershell
                    $scope = ''
                    if ($script:WfAskScope -and $script:WfAskScope.Contains($key)) { $scope = $script:WfAskScope[$key] }
                    if ($scope) { Write-ColorOutput ("  ▸ " + $lbl + "  [" + $scope + "]") -ForegroundColor Cyan }
                    else { Write-ColorOutput ("  ▸ " + $lbl) -ForegroundColor Cyan }
```
(`$script:WfAskScope`는 Task 5 `Get-WfAskTable` 결과에서 key→Scope만 추려 채워두거나, 없으면 빈 해시. Task 5 Step 4에서 `$script:WfAskScope` 채우는 코드를 함께 넣는다.)

- [ ] **Step 3: 회귀 가드 — "전부 기본값" 결과 byte-identical 확인 (.sh)**

핵심 도구: 기존 `_wf_is_unchanged(type, src, existing)`는 **서브셸에서 `WF_USE_DEFAULTS=true`로 `src`를 가상 치환한 결과가 `existing`과 같은지** `cmp`로 본다(0=동일). 이걸 그대로 회귀검증에 쓴다:

1. **base(`7d4e130`, 작업 시작 직전) 코드**로 각 워크플로우 원본을 "전부 기본값" 치환한 산출물을 만든다 → `expected/`.
2. **현재 코드**로 같은 원본을 치환한다 → 그 결과가 1의 산출물과 byte-identical이면 무손상.

base 스크립트와 base 시점 원본 워크플로우를 git에서 꺼내 임시 비교 하네스를 만든다:

```bash
cd /d/0-suh/project/suh-github-template
WORK=$(mktemp -d)
# 1) base 코드 + base 원본으로 "전부 기본값" 산출물 생성
git show 7d4e130:template_integrator.sh > "$WORK/base.sh"
git archive 7d4e130 .github/workflows/project-types | tar -x -C "$WORK"   # base 시점 원본 워크플로우
mkdir -p "$WORK/expected"
cat > "$WORK/gen.sh" <<'GEN'
set +e
WORKFLOWS_DIR=".github/workflows"; PROJECT_TYPES_DIR="project-types"
LABELS_FILE="$ROOT/.github/wizard/labels.yml"   # 라벨 파일은 현재 것 사용(매핑 추가분 무관 — 치환값엔 영향 없음)
source "$SCRIPT"
TTY_AVAILABLE=false; FORCE_MODE=true
for f in "$SRCDIR"/*/*.yaml "$SRCDIR"/*/*.yml; do
  [ -f "$f" ] || continue
  grep -q "@wizard" "$f" || continue
  t=$(basename "$(dirname "$f")")
  cp "$f" "$OUT/$(basename "$f").$t"
  ( WF_USE_DEFAULTS=true; configure_workflow_env "$t" "$OUT/$(basename "$f").$t" >/dev/null 2>&1 )
done
GEN
ROOT="$PWD" SCRIPT="$WORK/base.sh" SRCDIR="$WORK/.github/workflows/project-types" OUT="$WORK/expected" \
  bash "$WORK/gen.sh"

# 2) 현재 코드로 같은 base 원본을 치환 → actual/
mkdir -p "$WORK/actual"
ROOT="$PWD" SCRIPT="$PWD/template_integrator.sh" SRCDIR="$WORK/.github/workflows/project-types" OUT="$WORK/actual" \
  bash "$WORK/gen.sh"

# 3) 비교 — 차이 0이어야 함
diff -r "$WORK/expected" "$WORK/actual" && echo "REGRESSION_OK (byte-identical)" || echo "REGRESSION_FAIL"
rm -rf "$WORK"
```
Expected: `REGRESSION_OK (byte-identical)`. (현재 코드의 prefill+전부기본 경로가 base의 파일별 치환과 동일 결과를 냄.) `REGRESSION_FAIL`이면 Task 3/5의 prefill 로직이 기존 치환과 어긋난 것 → 해당 Task로 돌아가 수정.

> **주의(Windows 환경)**: `git archive ... | tar -x`가 Git Bash에서 동작한다. 안 되면 `git -C <base체크아웃> ...` 대신, base 시점 원본을 한 파일씩 `git show 7d4e130:.github/workflows/project-types/<type>/<file>`로 꺼내 `$SRCDIR`에 풀어 같은 비교를 한다.

- [ ] **Step 4: 회귀 가드 — "전부 기본값" 결과 byte-identical 확인 (.ps1)**

`.ps1`은 `Test-WorkflowUnchanged(Type, Src, Existing)`가 `$script:WfUseDefaults=$true` + 상태 저장/복원 + LF 정규화 비교를 한다. base 코드로 만든 산출물(`$WORK/expected`, Step 3에서 .sh로 생성한 것과 동일 입력)을 "existing"으로 두고, **현재 `.ps1`이 base 원본을 치환한 결과가 그것과 unchanged($true)로 판정되는지** 확인한다. 모든 워크플로우가 `$true`면 무손상.

```powershell
# /tmp/reg_ps.ps1 (Git Bash에서 powershell -File로 실행)
$ErrorActionPreference='Stop'
$root='D:\0-suh\project\suh-github-template'
# 현재 .ps1을 dot-source하면 main이 도므로, Test-WorkflowUnchanged + Configure-WorkflowEnv 등
# 필요한 함수만 추출해 최소 하네스에 붙이거나, FORCE 가드를 세워 main 진입을 막은 사본을 만든다.
# 비교 대상 existing = Step3에서 .sh로 만든 $WORK/expected/<file>.<type>
# 각 (type, base원본) 쌍에 대해:
#   Test-WorkflowUnchanged -Type $t -SrcPath <base원본> -ExistingPath <expected> 가 $true 인지
Get-ChildItem "$env:WORK\expected" | ForEach-Object {
    # 파일명 규칙 <name>.<type> 에서 type 분리, base 원본 경로 복원해 비교
}
"PS_REGRESSION done"
```
Expected: 전 워크플로우 `$true`(unchanged). `$false`가 하나라도 나오면 `.ps1` prefill이 base 치환과 어긋난 것 → Task 5로 돌아가 수정. (정확한 base 원본 경로 복원·함수 추출은 구현 시 Step 3의 `$WORK` 레이아웃에 맞춰 채운다.)

- [ ] **Step 5: 문법 + Commit**

```bash
cd /d/0-suh/project/suh-github-template
bash -n template_integrator.sh && echo SH_OK
git add template_integrator.sh template_integrator.ps1
git commit -m "마법사 배포 env 설정 UX 개선 : feat : 하나씩 입력 분기 라벨에도 사용처[scope] 표시 https://github.com/Cassiiopeia/projectops/issues/410"
```

---

## Task 7: 통합 검증 + 무손상 확인

**Files:** (검증만, 코드 변경 없음 — 발견 시 해당 Task로 돌아가 수정)

- [ ] **Step 1: 문법 — 양쪽**

```bash
cd /d/0-suh/project/suh-github-template
bash -n template_integrator.sh && echo SH_OK
```
`.ps1`: Docker PowerShell `Parser::ParseFile` 또는 로컬 `[System.Management.Automation.Language.Parser]::ParseFile(...)` → `PS1_PARSE_OK`.

- [ ] **Step 2: 신규 통합 폴백 — labels.yml 없을 때 `_workflow_names`도 TEMP_DIR에서 읽히는지**

dst에 `.github/wizard/labels.yml`이 없고 `$TEMP_DIR`에만 있는 상태를 재현해 `wf_workflow_name`/`Get-WfWorkflowName`이 사람말을 반환하는지(빈값/파일명 폴백이 아닌지) 확인. (Task 2 하네스를 `_wf_labels_path`가 TEMP_DIR을 가리키도록 변형.)
Expected: 매핑 사람말 정상 반환.

- [ ] **Step 3: 실행 로직 무손상 — git diff**

```bash
cd /d/0-suh/project/suh-github-template
git diff HEAD~6 -- .github/workflows/project-types | grep '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -iE 'run:|uses:|with:|steps:|env:' | head
```
Expected: **빈 출력** (워크플로우 실행 로직·env 블록 무변경 — 이 작업은 워크플로우 YAML을 건드리지 않음). 무언가 나오면 워크플로우를 잘못 수정한 것 → 되돌린다.

- [ ] **Step 4: labels.yml KEY 블록 무변경 확인**

```bash
git diff HEAD~6 -- .github/wizard/labels.yml | grep '^[+-]' | grep -vE '^(\+\+\+|---|\+# |\+_workflow_names|\+  [A-Za-z])' | grep -E '^[+-]' | head
```
Expected: 기존 KEY 블록(PROJECT_NAME/SERVICE_DOMAIN 등 label/help/example) 변경 라인 없음. 추가는 `_workflow_names` 섹션뿐.

- [ ] **Step 5: 최종 — 전부 기본값 회귀 재확인 + 마무리**

Task 6 Step 3(.sh `REGRESSION_OK`)·Step 4(.ps1 전부 `$true`)를 **모든 코드 Task가 끝난 최종 상태**에서 한 번 더 돌린다 — 중간 Task가 통과해도 이후 Task에서 깨질 수 있으므로 최종 1회 재확인이 회귀 가드의 핵심이다.

```bash
cd /d/0-suh/project/suh-github-template
# Task 6 Step 3의 .sh 회귀 하네스를 그대로 재실행 → REGRESSION_OK 확인
```
Expected: `.sh` `REGRESSION_OK (byte-identical)` + `.ps1` 전 워크플로우 `$true`. 통과하면 작업 완료. (필요 시 `superpowers:requesting-code-review`로 리뷰 요청 후 사용자 커밋 컨벤션으로 묶어 main push.)

---

## Self-Review 결과

- **Spec 커버리지**: §4.1 2-pass→Task 3·5 / §4.2 화면(표·1/2/3·멀티)→Task 5 / §4.3 사용처+매핑→Task 1·2·4 / §4.4 메뉴재사용→Task 5 / §6 검증→각 Task + Task 7. 누락 없음.
- **Placeholder**: Task 6 Step 3·Task 7 Step 5의 "전부 기본값 byte-identical diff"는 비대화형 진입점이 구현 시점에 확정되므로 절차 골격만 제시 — 구현자가 실제 FORCE 진입점에 맞춰 채운다(가장 중요한 가드라 명시 유지).
- **타입 정합**: `.sh` 배열 `WF_ASK_KEYS/WF_ASK_DEFAULT/WF_ASK_SCOPE/WF_ASK_FILES`, 함수 `wf_collect_asks`·`wf_scope_string`·`wf_workflow_name`·`wf_prompt_env_plan`·`_wf_prefill_all`·`_wf_prefill_interactive`·`_wf_first_type_for` / `.ps1` `Get-WfAskTable`·`Get-WfScopeString`·`Get-WfWorkflowName`·`Invoke-WfEnvPlan`·`$script:WfAskScope` — 전 Task 일관.
