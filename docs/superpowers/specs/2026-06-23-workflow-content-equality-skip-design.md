# 워크플로우 "내용 동일 시 건너뛰기" (정규화 비교) — 설계

- 작성일: 2026-06-23
- 대상 파일: `template_integrator.sh`, `template_integrator.ps1`
- 관련 함수: `_copy_workflows_for_type`(.sh) / `Copy-WorkflowsForType`(.ps1), `download_workflows`/`Download-Workflows`의 common 루프, `configure_workflow_env`/`Configure-WorkflowEnv`

---

## 1. 문제

`template_integrator`가 기존 프로젝트에 워크플로우를 통합할 때, **파일명만** 비교한다.
그래서 내용이 한 글자도 안 바뀐 워크플로우도:

- **공통(common)**: 메뉴 없이 무조건 `cp`로 덮어쓰며 `✓ ... 업데이트`만 출력
- **타입별(spring 등)**: "이미 존재함" 목록에 넣고 3지선 메뉴(.template / 건너뛰기 / 덮어쓰기)를 띄움

사용자 입장에서는 **변경점이 0인 파일인데도 ".bak 백업 후 덮어쓸까요?"를 묻는** 셈이라 혼란만 생긴다.
실제 사례: `PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml`이 동일한데도 `.bak`을 만들고 교체.

## 2. 왜 단순 비교가 안 되나

워크플로우는 **복사 직후 `configure_workflow_env`로 env 토큰이 치환**된다.

- 템플릿 원본: `KEY: "__PROJECT_NAME__"  # @wizard ask`, `paths-anchor` 마커 등이 **남은** 상태
- 기존 설치본: 그 자리에 레포명·서버 등 **값이 채워진** 상태

→ 원본 vs 기존본을 그냥 `cmp` 하면 **항상 다르게** 나온다. 정규화(치환분 무력화)가 필요하다.

## 3. 핵심 아이디어 — "설치하면 나올 최종형"과 비교

비교 직전에, **템플릿 원본을 임시 사본으로 떠서 실제 치환 로직(`configure_workflow_env`)을 그대로 한 번 적용**한
"설치 예상 최종형"을 만든다. 그 최종형을 기존 파일과 `cmp -s`(바이트) 비교한다.

> 휴리스틱 마스킹(정규식으로 `KEY: "..."` → `KEY: __MASK__`)이 아니라,
> **"이 템플릿을 지금 설정대로 깔면 결과가 똑같아지는가?"** 를 직접 본다. 오판이 거의 없다.

### 가상 치환의 제약 — 질문 금지 + 기본값 강제

`configure_workflow_env`는 `WF_USE_DEFAULTS` 미설정 + `@wizard ask` 마커가 있으면 **TTY로 사용자에게 값을 물어볼 수 있다.**
비교용 가상 치환에서 이게 또 질문을 띄우면 안 된다.

- 비교용 임시 치환은 **항상 `WF_USE_DEFAULTS=true`(기본값 모드)** 를 강제한 **서브셸/임시 컨텍스트**에서 돌린다.
- 이때 만든 카운터·`WF_DEPLOY_CSV` 같은 부수효과(version.yml deploy 기록 등)는 **실제 설치 흐름에 새지 않도록** 격리한다.
  - .sh: `( ... )` 서브셸 + 임시 디렉토리에서 치환. 서브셸이 끝나면 변수 변경이 부모로 전파되지 않음.
  - .ps1: 임시 파일에 대해 별도 함수로 치환하되, deploy 기록/CSV 누적 같은 부수효과는 비교 모드에서 건너뛰도록 플래그로 제어.
- 결과적으로 사용자가 실제 설치 때 **기본값과 다른 값을 입력**하면, 가상 최종형(기본값)과 기존본(다른 값)이 달라져 **changed로 분류**된다 → 보수적·안전(놓치느니 한 번 더 묻는다).

## 4. 동작 흐름

```
복사 대상 워크플로우 파일 each:
  기존 파일 없음?  → 신규 (지금처럼 바로 복사·설정)
  기존 파일 있음:
    ├ 임시폴더에 원본 복사
    ├ (WF_USE_DEFAULTS=true 강제) configure_workflow_env 적용 → "예상 최종형" 생성
    ├ cmp -s  예상최종형  vs  기존파일
    │   ├ 동일(byte-identical) → "unchanged" 분류
    │   └ 다름                 → "changed" 분류
    └ 비교 실패(임시 폴더 생성 불가 등) → 안전하게 "changed"로 취급
```

비교 자체가 어떤 이유로든 실패하면 **changed로 fallback** → 기존 동작 유지, 업데이트를 절대 놓치지 않는다.

## 5. 분기별 동작

### ① 공통(common) 워크플로우 — `download_workflows`/`Download-Workflows`

| 판정 | 동작 | 출력 |
|------|------|------|
| 신규(기존 없음) | `cp` + 설정 | `✓ XXX` |
| changed | `cp`로 덮어씀(지금과 동일) | `✓ XXX (업데이트)` |
| unchanged | **cp 안 함** | `✓ XXX (변경 없음)` |

공통은 원래 `.bak`을 안 만들고 메뉴도 없으므로, unchanged면 그냥 cp를 생략하고 표시만 바꾼다.

### ② 타입별(spring 등) — `_copy_workflows_for_type`/`Copy-WorkflowsForType`

`existing_files`를 비교해서 **`unchanged` / `changed` 두 그룹**으로 분리한다.

- `unchanged` 그룹:
  - 조용히 `⏭ XXX (변경 없음)` 출력하고 끝. **메뉴를 띄우지 않는다.**
  - `_wf_skipped` 카운터 증가.
  - env 설정(`configure_workflow_env`) 단계의 실제 대상에서도 제외(이미 동일하므로 건드릴 이유 없음).
- `changed` 그룹:
  - **1개라도 있을 때만** 기존 3지선 메뉴(.template / 건너뛰기 / 덮어쓰기)를 띄운다.
  - 메뉴의 대상 목록·처리 대상은 `changed`만. (사용자가 본 "변경 없는 파일 .bak 덮어쓰기" 사라짐)
- `changed`가 비어 있으면(전부 unchanged) **메뉴 자체를 건너뛴다.**

### ③ 안전 탈출구 (오판 대비)

- `changed`가 비어서 메뉴를 건너뛸 때, unchanged가 있었으면 한 줄 안내:
  `ℹ N개 워크플로우가 현재 설정과 동일해 건너뜁니다`
- 정규화 비교가 휴리스틱이 아니라 "실치환 후 비교"라 오판 가능성은 낮지만,
  혹시 사용자가 "그래도 전부 새로 받고 싶다"면 다음 재실행에서 값을 바꿔 입력하거나
  파일을 지우고 재통합하면 changed로 잡힌다(별도 강제 옵션은 YAGNI — 추가하지 않음).

### ④ Nexus(opt-in) 워크플로우

- 현재 nexus는 존재 시 무조건 `.bak` 후 덮어쓴다(메뉴 없음).
- 동일하게 정규화 비교를 적용: unchanged면 `⏭ XXX (Nexus, 변경 없음)` 출력하고 cp 생략, changed면 기존대로 `.bak` 후 덮어씀.

## 6. 공통 비교 헬퍼

### .sh

```sh
# 기존 파일이 "이 템플릿을 지금 설정대로 깔면 나올 결과"와 동일한가?
# 0 = 동일(unchanged), 1 = 다름 또는 비교 실패(changed로 취급)
# $1=type  $2=원본 워크플로우 경로  $3=기존(설치된) 파일 경로
_wf_is_unchanged() {
    local _type="$1" _src="$2" _existing="$3"
    [ -f "$_src" ] && [ -f "$_existing" ] || return 1
    local _tmp
    _tmp=$(mktemp 2>/dev/null) || return 1     # 실패 → changed
    cp "$_src" "$_tmp" 2>/dev/null || { rm -f "$_tmp"; return 1; }
    # 질문 금지·부수효과 격리: 서브셸 + 기본값 강제
    (
        WF_USE_DEFAULTS=true
        WF_COMPARE_MODE=true          # deploy 기록/CSV 누적 등 부수효과 차단 플래그
        configure_workflow_env "$_type" "$_tmp" >/dev/null 2>&1
    )
    if cmp -s "$_tmp" "$_existing"; then
        rm -f "$_tmp"; return 0       # unchanged
    fi
    rm -f "$_tmp"; return 1           # changed
}
```

> `configure_workflow_env`/`save_deploy_csv` 류에 `WF_COMPARE_MODE`가 true면 version.yml 기록·CSV 누적을 건너뛰는 가드를 추가한다(비교가 실제 설정을 오염시키지 않도록).

### .ps1

```powershell
# 동일하면 $true. 비교 실패 시 $false(=changed로 취급).
function Test-WorkflowUnchanged {
    param([string]$Type, [string]$SrcPath, [string]$ExistingPath)
    if (-not (Test-Path $SrcPath) -or -not (Test-Path $ExistingPath)) { return $false }
    $tmp = $null
    try {
        $tmp = [System.IO.Path]::GetTempFileName()
        Copy-Item $SrcPath $tmp -Force
        $script:WF_USE_DEFAULTS = $true
        $script:WF_COMPARE_MODE = $true
        Configure-WorkflowEnv -Type $Type -File $tmp | Out-Null
        # 줄바꿈(CRLF/LF) 차이로 인한 거짓 'changed' 방지 위해 정규화 후 비교
        $a = (Get-Content $tmp -Raw) -replace "`r`n","`n"
        $b = (Get-Content $ExistingPath -Raw) -replace "`r`n","`n"
        return ($a -eq $b)
    } catch {
        return $false
    } finally {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        $script:WF_COMPARE_MODE = $false
    }
}
```

> `WF_USE_DEFAULTS`/`WF_COMPARE_MODE`는 비교 호출 전후로 상태를 저장·복원해 실제 설치 흐름의 모드를 망치지 않게 한다.
> .ps1은 줄바꿈 차이로 인한 거짓 변경을 막기 위해 LF 정규화 후 문자열 비교를 쓴다(.sh의 `cmp`는 바이트 비교이므로, 양쪽 원본의 줄바꿈이 일관되면 동일 결과).

## 7. 적용 범위 / 동작 보존

- `.sh`와 `.ps1` **양쪽 동일**하게 구현(1:1 유지가 이 레포 규칙).
- 변경 대상은 **분기·출력·복사 여부 판단**뿐. `configure_workflow_env`의 치환 로직, 메뉴 UI, 카운터 의미는 그대로.
- 신규 파일(기존 없음) 경로는 **무손상** — 지금과 100% 동일.
- 비교가 실패하면 항상 기존 동작(changed)으로 떨어지므로, **회귀 위험이 한쪽(놓침)으로 절대 안 생긴다.**

## 8. 검증 (CLAUDE.md 규칙)

- `.sh`: `bash -n template_integrator.sh` + `expect` 하네스로
  - (a) 동일 파일만 있는 타입 → **메뉴가 안 뜨고** `⏭ ... (변경 없음)`만 출력
  - (b) 일부만 changed → 메뉴가 뜨되 목록에 changed만 나옴
- `.ps1`: Docker PowerShell `Parser::ParseFile`로 `PS1_PARSE_OK` + 함수 추출 하네스로 `Test-WorkflowUnchanged` 단위 동작(동일/상이/임시파일 실패) 확인.
- common 루프: 동일 파일 → `✓ ... (변경 없음)`, cp 호출 안 됨 확인.
- 임시 하네스·`.exp` 파일은 검증 후 정리.

## 9. YAGNI로 뺀 것

- 워크플로우에 버전 마커(`# template-version:`)를 심는 방식 — 모든 원본 파일을 수정해야 해 비용이 큼. "실치환 후 비교"가 더 정확하므로 불필요.
- "전부 강제로 새로 받기" 별도 옵션 — 파일 삭제 후 재통합으로 충분. 표면적 추가 금지.
