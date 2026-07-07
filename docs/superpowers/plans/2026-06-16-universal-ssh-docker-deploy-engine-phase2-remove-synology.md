# SSH+Docker 배포 엔진 재설계 Phase 2 — synology 전면 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Phase 1(완료)**: `2026-06-16-universal-ssh-docker-deploy-engine.md` — 워크플로우 파일명 SYNOLOGY 제거 + `SSH_AUTH_METHOD`/`SUDO()` 인증 분기. 이미 커밋됨(`0dc619c`~`c97ae06`).
> **Phase 2(이 문서)**: synology 폴더/옵션/UX/명명을 전면 제거하고 nexus·secret-backup 게이트로 분리.

**Goal:** `synology`라는 단어와 폴더 구분을 워크플로우 폴더·파일명·주석, `template_integrator.sh`/`.ps1`의 UX·변수·옵션, `version.yml` 스키마, 문서에서 전면 제거하고 "어떤 서버든 SSH+Docker 배포"라는 확장 개념으로 통일한다. 배포 워크플로우는 기본 포함, Nexus(라이브러리 publish)와 Secret 백업만 독립 opt-in 게이트로 분리한다.

**Architecture:** (1) `git mv`로 폴더 재편 — 배포 4개는 `spring/` 루트, Nexus 2개는 `spring/nexus/`, secret-upload는 `common/secret-backup/`. (2) integrator 양쪽에서 `--synology` 단일 게이트를 `--nexus`/`--secret-backup` 두 게이트로 분리하고 `INCLUDE_SYNOLOGY`/`ask_synology_option`/안내문구/version.yml 읽기·쓰기를 전부 교체, 하위호환(`options.synology` → `nexus`+`secret_backup`) 매핑 추가. (3) 워크플로우 주석·name·README·CLAUDE.md·가이드 문서 중립화. 검증은 단위테스트가 아니라 CLAUDE.md 명시 절차(`bash -n`+expect, Docker PowerShell 파서, `git diff` 실행로직 무손상).

**Tech Stack:** Bash 3.2 호환 셸 스크립트, PowerShell, GitHub Actions YAML, `git mv`, `expect`(macOS 기본), Docker `mcr.microsoft.com/powershell:latest`.

---

## 확정된 결정 (spec §11 미해결 → 본 plan에서 확정)

1. **하위호환 미고려** (사용자 지시): 기존 `options.synology` 값을 새 스키마로 변환하는 매핑 로직을 **작성하지 않는다**. integrator는 `nexus`/`secret_backup` 새 키만 읽고 쓴다. 구 `synology` 키는 무시하며, 쓰기 시 굳이 제거 처리도 하지 않는다(있으면 그냥 방치 — 기존 동작에 영향 없음).
2. **함수 구조**: 폴더경로·라벨·설명·include변수명을 인자로 받는 **범용 `ask_optional_workflow()` 1개** + 모든 게이트를 묶는 `ask_all_optional_workflows()` 래퍼. nexus·secret-backup 두 게이트를 같은 코드로 처리.
3. **가이드 문서 파일명**: `docs/SSH-DOCKER-DEPLOYMENT-GUIDE.md`.
4. **breaking-changes severity**: `warning` (폴더 구조 변경 안내용).
5. **secret-backup 루트 설치본**: 현재 `.github/workflows/` 루트에 secret-upload 설치본 없음 → 원본 폴더만 이동(설치본 동기화 불필요).

---

## File Structure

**워크플로우 (git mv):**
- `spring/synology/PROJECT-SPRING-{SIMPLE-CICD,NONSTOP-NGINX-CICD,NONSTOP-TRAEFIK-CICD,PR-PREVIEW}` → `spring/` 루트
- `spring/synology/PROJECT-SPRING-NEXUS-{CI,PUBLISH}` → `spring/nexus/`
- `common/synology/PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml` → `common/secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml`

**integrator (전면 수정):**
- `template_integrator.sh` — 옵션 파싱, `ask_optional_workflow()`/`ask_all_optional_workflows()`(신규, `ask_synology_option` 대체), `read_template_options`/`save_template_options`, `_copy_workflows_for_type`, `copy_workflows`, 메뉴/요약/호출부
- `template_integrator.ps1` — sh와 대칭

**문서/설정:**
- `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` → `docs/SSH-DOCKER-DEPLOYMENT-GUIDE.md` (git mv + 범용화)
- `README.md`, `CLAUDE.md`, `.github/config/breaking-changes.json`, `version.yml`

---

## Task 1: 워크플로우 폴더 재편 (git mv)

순수 이동만. 내용은 Task 2에서. git 이력 보존을 위해 `git mv` 사용.

**Files:**
- Move: `spring/synology/*` → `spring/` 루트, `spring/nexus/`
- Move: `common/synology/*` → `common/secret-backup/`

- [ ] **Step 1: 현재 구조 스냅샷 확인**

Run:
```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE
find .github/workflows/project-types/spring .github/workflows/project-types/common/synology -type f | sort
```
Expected: spring/synology/ 6개(배포4+nexus2), common/synology/ 1개.

- [ ] **Step 2: 배포 워크플로우 4개 → spring/ 루트**

Run:
```bash
cd .github/workflows/project-types/spring
git mv synology/PROJECT-SPRING-SIMPLE-CICD.yaml          PROJECT-SPRING-SIMPLE-CICD.yaml
git mv synology/PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml   PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml
git mv synology/PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml
git mv synology/PROJECT-SPRING-PR-PREVIEW.yaml           PROJECT-SPRING-PR-PREVIEW.yaml
cd - >/dev/null
```

- [ ] **Step 3: Nexus 2개 → spring/nexus/**

Run:
```bash
cd .github/workflows/project-types/spring
mkdir -p nexus
git mv synology/PROJECT-SPRING-NEXUS-CI.yml      nexus/PROJECT-SPRING-NEXUS-CI.yml
git mv synology/PROJECT-SPRING-NEXUS-PUBLISH.yml nexus/PROJECT-SPRING-NEXUS-PUBLISH.yml
rmdir synology 2>/dev/null || true
cd - >/dev/null
```
Expected: `spring/synology/`가 비어 삭제됨.

- [ ] **Step 4: secret-upload → common/secret-backup/ + 파일명 SYNOLOGY 제거**

Run:
```bash
cd .github/workflows/project-types/common
mkdir -p secret-backup
git mv synology/PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml
rmdir synology 2>/dev/null || true
cd - >/dev/null
```

- [ ] **Step 5: 새 구조 검증 + synology 폴더 완전 소멸**

Run:
```bash
find .github/workflows/project-types -type d -iname "synology"   # 비어야 함
find .github/workflows/project-types/spring -type f | sort
find .github/workflows/project-types/common -type f | sort
```
Expected: synology 디렉토리 0개. 배포 4개 spring/ 루트, nexus/ 2개, common/secret-backup/ 1개.

- [ ] **Step 6: Commit**

```bash
git add -A .github/workflows/project-types
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : refactor : synology 폴더 제거 — 배포 워크플로우 루트화·nexus 분리·secret-backup 이동 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 2: 워크플로우 주석·name 중립화 (실행 로직 불변)

`run:`/`uses:`/`with:`/`steps:`는 **한 줄도 건드리지 않는다.** 주석(`#`)·`name:`·env 주석 텍스트만 교체. 예시("예: Synology /volume1, AWS EC2 /home/ubuntu")는 실용 예시로 남긴다.

**Files (Modify):**
- `spring/PROJECT-SPRING-SIMPLE-CICD.yaml` (synology 5건)
- `spring/PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml` (2건)
- `spring/PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml` (6건)
- `spring/PROJECT-SPRING-PR-PREVIEW.yaml` (8건)
- `common/secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml` (12건)

- [ ] **Step 1: 각 파일의 synology 라인 실제 확인**

Run:
```bash
for f in spring/PROJECT-SPRING-SIMPLE-CICD.yaml spring/PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml spring/PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml spring/PROJECT-SPRING-PR-PREVIEW.yaml common/secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml; do
  echo "=== $f ==="; grep -niE "synology|시놀로지" ".github/workflows/project-types/$f"
done
```
각 매치가 **주석/`name:`/문서 텍스트인지** 확인. `run:` 블록 내부 셸 변수·경로(실행 로직)에 박혀 있으면 그 라인은 **건드리지 않는다**.

- [ ] **Step 2: 주석/name 텍스트만 중립화 (Edit으로 라인별)**

치환 규칙:
- `name: ...Synology...` → 중립 (예: `name: Spring 단일 컨테이너 배포 (SSH+Docker)`)
- 주석 `Synology NAS 주소` → `서버 호스트(SSH 접속 주소)`
- 주석 `Synology NAS에 자동 배포` → `SSH 접속 가능한 서버에 Docker 자동 배포`
- 주석 `Synology 경로` → `서버 배포 경로 (예: Synology /volume1/..., AWS EC2 /home/ubuntu/...)`
- secret-upload 상단 블록 `Synology NAS 자동 업로드` → `서버(SSH) 자동 업로드`, AI 가이드 프롬프트 `Synology 경로` → `서버 배포 경로`

> env `SSH_AUTH_METHOD` 주석의 "password(예: Synology...)" 같은 예시는 유지 가능. 목표는 "특별 취급 문구" 제거이지 예시 단어 박멸이 아니다.

- [ ] **Step 3: 실행 로직 무손상 자가검증 (CLAUDE.md 절차)**

Run:
```bash
git diff .github/workflows/project-types/spring .github/workflows/project-types/common/secret-backup \
  | grep "^[+-]" | grep -v "^[+-][+-]" | grep -vE "^[+-]\s*#|^[+-]\s*name:"
```
Expected: **결과 비어야 함**(주석/name 외 변경 없음). `run:`/`with:`/`uses:` 라인이 나오면 되돌린다.

- [ ] **Step 4: synology 잔재 재확인**

Run:
```bash
grep -rniE "synology|시놀로지" .github/workflows/project-types/spring .github/workflows/project-types/common/secret-backup | grep -viE "예:|example|/volume1"
```
Expected: 실용 예시 외 0건.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/project-types/spring .github/workflows/project-types/common/secret-backup
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : docs : 워크플로우 주석·name의 synology 표현 SSH/서버 중립화 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 3: integrator(.sh) — CLI 옵션 파싱 교체

`--synology`/`--no-synology` → `--nexus`/`--no-nexus`, `--secret-backup`/`--no-secret-backup`. `INCLUDE_SYNOLOGY` → `INCLUDE_NEXUS` + `INCLUDE_SECRET_BACKUP`.

**Files:** Modify `template_integrator.sh` (~773-774 도움말, ~849 변수, ~901-906 파싱)

- [ ] **Step 1: 현재 파싱부 확인**

Run: `sed -n '770,776p;847,851p;899,908p' template_integrator.sh`
Expected: `--synology`/`--no-synology` case, `INCLUDE_SYNOLOGY=""` 확인.

- [ ] **Step 2: 변수 선언 교체 (~849)**

`INCLUDE_SYNOLOGY=""` 라인을:
```bash
# 선택적 워크플로우 포함 여부 (빈 값: 미설정, true/false: 명시적 설정)
INCLUDE_NEXUS=""          # Nexus 라이브러리 publish (spring/nexus/)
INCLUDE_SECRET_BACKUP=""  # GitHub Secret 파일 서버 백업 (common/secret-backup/)
```

- [ ] **Step 3: CLI case 교체 (~901-906)**

`--synology|--include-synology)` + `--no-synology)` 블록을:
```bash
        --nexus)
            INCLUDE_NEXUS=true
            shift
            ;;
        --no-nexus)
            INCLUDE_NEXUS=false
            shift
            ;;
        --secret-backup)
            INCLUDE_SECRET_BACKUP=true
            shift
            ;;
        --no-secret-backup)
            INCLUDE_SECRET_BACKUP=false
            shift
            ;;
```

- [ ] **Step 4: 도움말 교체 (~773-774)**

```bash
  --nexus                  Nexus 라이브러리 publish 워크플로우 포함 (기본: 제외)
  --no-nexus               Nexus publish 워크플로우 제외
  --secret-backup          GitHub Secret 서버 백업 워크플로우 포함 (기본: 제외)
  --no-secret-backup       Secret 백업 워크플로우 제외
```

- [ ] **Step 5: 문법 검사**

Run: `bash -n template_integrator.sh`
Expected: 출력 없음. (이 시점엔 `INCLUDE_SYNOLOGY` 런타임 참조가 남아 있어도 bash -n 통과.)

- [ ] **Step 6: Commit**

```bash
git add template_integrator.sh
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : integrator(sh) --synology를 --nexus/--secret-backup 게이트로 분리 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 4: integrator(.sh) — 범용 ask_optional_workflow() + 호출부

`ask_synology_option()`(2616-2719)을 범용 함수로 대체. 폴더·라벨·설명·include변수명을 인자로 받아 nexus·secret-backup 각각 호출.

**Files:** Modify `template_integrator.sh` (2616-2719 함수, 2024-2029·3836·3941 호출부)

- [ ] **Step 1: ask_synology_option 전체를 범용 함수로 교체 (2616-2719)**

```bash
# 선택적(opt-in) 워크플로우 1종의 포함 여부를 묻는다.
# 인자: [--force-ask] $1=폴더경로 $2=아이콘 $3=짧은이름 $4=한줄설명 $5=include변수명
# 폴더가 없거나 파일이 0개면 조용히 return. 이미 값이 있으면(--force-ask 아니면) 건너뜀.
ask_optional_workflow() {
    local _force_ask=false
    if [ "$1" = "--force-ask" ]; then _force_ask=true; shift; fi
    local _dir="$1" _icon="$2" _short="$3" _desc="$4" _varname="$5"

    local _cur; eval "_cur=\"\${$_varname}\""   # bash 3.2 — nameref 없이 eval

    [ -d "$_dir" ] || return
    local _count=0 f
    for f in "$_dir"/*.{yaml,yml}; do [ -e "$f" ] && _count=$((_count + 1)); done
    [ "$_count" -eq 0 ] && return

    if [ "$_force_ask" = false ] && { [ "$_cur" = true ] || [ "$_cur" = false ]; }; then
        return
    fi
    if [ "$TTY_AVAILABLE" = false ]; then
        eval "$_varname=false"; return
    fi

    print_separator_line
    print_to_user ""
    print_to_user "$_icon $_short 워크플로우를 발견했습니다. ($_count개 파일)"
    print_to_user "   $_desc"
    print_to_user ""
    print_to_user "   포함되는 워크플로우:"
    for f in "$_dir"/*.{yaml,yml}; do
        [ -e "$f" ] || continue
        print_to_user "     • $(basename "$f")"
    done
    print_to_user ""

    if ask_yes_no "$_short 워크플로우를 포함할까요?" "N"; then
        eval "$_varname=true"
        print_info "$_short 워크플로우를 포함합니다 — GitHub Actions에 추가됩니다"
    else
        eval "$_varname=false"
        print_info "$_short 워크플로우를 제외합니다 (나중에 옵션으로 추가 가능)"
    fi
}

# 모든 opt-in 워크플로우를 순서대로 묻는다. type_dirs = project_types_dir 하위 타입 폴더 목록.
ask_all_optional_workflows() {
    local _fa=""
    if [ "$1" = "--force-ask" ]; then _fa="--force-ask"; shift; fi
    local type_dirs=("$@")
    [ ${#type_dirs[@]} -eq 0 ] && return
    local _common_root; _common_root="$(dirname "${type_dirs[0]}")/common"

    local _td
    for _td in "${type_dirs[@]}"; do
        ask_optional_workflow $_fa "$_td/nexus" "📦" "Nexus 라이브러리 publish" \
            "라이브러리/모듈을 Maven 저장소(Nexus)에 배포하는 워크플로우입니다. 일반 서버 배포가 아니라 라이브러리 프로젝트에만 필요합니다." \
            INCLUDE_NEXUS
    done
    ask_optional_workflow $_fa "$_common_root/secret-backup" "🔐" "Secret 서버 백업" \
        "GitHub Secret에 저장한 설정 파일을 SSH로 서버에 업로드·이력관리하는 워크플로우입니다." \
        INCLUDE_SECRET_BACKUP
}
```

- [ ] **Step 2: 3개 호출부 교체 (2029, 3836, 3941)**

- `ask_synology_option --force-ask "${_syn_dirs[@]}"` → `ask_all_optional_workflows --force-ask "${_syn_dirs[@]}"`
- `ask_synology_option "${_syn_dirs[@]}"` → `ask_all_optional_workflows "${_syn_dirs[@]}"`

(주: 2022-2029 메뉴 핸들러는 Task 6 Step 5에서 최종 정리. 여기선 함수명만 교체해 동작 유지.)

- [ ] **Step 3: 문법 검사**

Run: `bash -n template_integrator.sh`
Expected: 출력 없음.

- [ ] **Step 4: expect 동작 검증 — nexus 질문**

Run:
```bash
cat > /tmp/h.sh <<'SH'
source "$PWD/template_integrator.sh"
TTY_AVAILABLE=true; FORCE_MODE=false
INCLUDE_NEXUS=""; INCLUDE_SECRET_BACKUP=""
ask_optional_workflow "$PWD/.github/workflows/project-types/spring/nexus" "📦" "Nexus 라이브러리 publish" "설명" INCLUDE_NEXUS
echo "<<RESULT NEXUS=$INCLUDE_NEXUS>>"
SH
expect <<'EXP'
set timeout 8
spawn bash -c "cd '$env(PWD)' && bash /tmp/h.sh"
expect "포함할까요" { send "y\r" }
expect "<<RESULT NEXUS=true>>" { puts ">>>PASS" }
EXP
rm -f /tmp/h.sh
```
Expected: `>>>PASS`.

- [ ] **Step 5: _syn_dirs 변수 리네이밍**

Run: `grep -n "_syn_dirs" template_integrator.sh` 로 정의·사용처 확인 후 `_opt_dirs`로 일괄 치환(동작 동일, 의미 명확화).

- [ ] **Step 6: bash -n 재검사 + Commit**

```bash
bash -n template_integrator.sh
git add template_integrator.sh
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : integrator(sh) ask_synology_option을 범용 ask_optional_workflow로 교체 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 5: integrator(.sh) — version.yml 읽기/쓰기 (하위호환 없음)

`read_template_options`(2339-2394)·`save_template_options`(2397-2442) 교체. `options.synology` → `nexus`+`secret_backup` 새 키만. 구 synology 키는 무시(읽지도 쓰지도 제거하지도 않음).

**Files:** Modify `template_integrator.sh` (2339-2442)

- [ ] **Step 1: read_template_options의 options 파싱 블록 교체 (2364-2386)**

기존 synology 매치(`return`) 블록을 nexus·secret_backup 2종 파싱(`continue`)으로:
```bash
        # options 섹션 내부: nexus / secret_backup
        if [ "$in_template" = true ] && [ "$in_options" = true ]; then
            if [[ "$line" =~ ^[[:space:]]+nexus:[[:space:]]*(.+) ]]; then
                local _v=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | tr -d "'" | xargs)
                [ "$_v" = true ] && INCLUDE_NEXUS=true
                [ "$_v" = false ] && INCLUDE_NEXUS=false
                continue
            fi
            if [[ "$line" =~ ^[[:space:]]+secret_backup:[[:space:]]*(.+) ]]; then
                local _v=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | tr -d "'" | xargs)
                [ "$_v" = true ] && INCLUDE_SECRET_BACKUP=true
                [ "$_v" = false ] && INCLUDE_SECRET_BACKUP=false
                continue
            fi
            if [[ "$line" =~ ^[[:space:]]{0,4}[a-z_]+: ]]; then
                in_options=false; in_template=false
            fi
        fi
```
> 핵심: 기존은 synology 매치 시 `return`이라 한 키만 읽고 끝났다. 새 코드는 `continue`로 nexus·secret_backup 두 키가 한 블록에 공존해도 모두 읽는다. 구 synology 키는 어떤 분기에도 안 걸려 무시된다.

- [ ] **Step 2: save_template_options 교체 (2411-2439)**

함수 진입부에 기본값 보정 추가: `: "${INCLUDE_NEXUS:=false}"; : "${INCLUDE_SECRET_BACKUP:=false}"`.
synology 쓰기(2412-2421)를 nexus+secret_backup 쓰기로:
```bash
        # nexus 값 업데이트 또는 추가
        if grep -q "nexus:" "$version_file"; then
            sed "s/nexus:.*$/nexus: $INCLUDE_NEXUS/" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        elif grep -q "options:" "$version_file"; then
            sed "/options:/a\\
      nexus: $INCLUDE_NEXUS" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        fi
        # secret_backup 값 업데이트 또는 추가
        if grep -q "secret_backup:" "$version_file"; then
            sed "s/secret_backup:.*$/secret_backup: $INCLUDE_SECRET_BACKUP/" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        elif grep -q "options:" "$version_file"; then
            sed "/options:/a\\
      secret_backup: $INCLUDE_SECRET_BACKUP" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        fi
```
새 template 섹션 heredoc(2437-2438)의 `synology: $INCLUDE_SYNOLOGY` →
```bash
    options:
      nexus: $INCLUDE_NEXUS
      secret_backup: $INCLUDE_SECRET_BACKUP
```

- [ ] **Step 3: 문법 검사**

Run: `bash -n template_integrator.sh`
Expected: 출력 없음.

- [ ] **Step 4: 읽기 검증 (새 키)**

Run:
```bash
cat > /tmp/h5.sh <<'SH'
source "$PWD/template_integrator.sh"
INCLUDE_NEXUS=""; INCLUDE_SECRET_BACKUP=""
cd /tmp
printf 'metadata:\n  template:\n    source: "X"\n    options:\n      nexus: true\n      secret_backup: false\n' > version.yml
read_template_options
echo "<<NEXUS=$INCLUDE_NEXUS SECRET=$INCLUDE_SECRET_BACKUP>>"
SH
bash /tmp/h5.sh
rm -f /tmp/version.yml /tmp/h5.sh
```
Expected: `<<NEXUS=true SECRET=false>>`.

- [ ] **Step 5: 쓰기 검증 (새 키 기록)**

Run:
```bash
cat > /tmp/h5w.sh <<'SH'
source "$PWD/template_integrator.sh"
INCLUDE_NEXUS=true; INCLUDE_SECRET_BACKUP=false
cd /tmp
printf 'metadata:\n  template:\n    source: "X"\n    options:\n      nexus: false\n      secret_backup: false\n' > version.yml
save_template_options "9.9.9"
echo "=== 결과 ==="; cat version.yml
SH
bash /tmp/h5w.sh
rm -f /tmp/version.yml /tmp/h5w.sh
```
Expected: `nexus: true`, `secret_backup: false`.

- [ ] **Step 6: Commit**

```bash
git add template_integrator.sh
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : integrator(sh) version.yml options를 nexus/secret_backup로 전환 + synology 하위호환 매핑 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 6: integrator(.sh) — 워크플로우 복사 + 메뉴/요약

배포 워크플로우가 `spring/` 루트로 올라와 기본 복사에 자동 포함된다. `_copy_workflows_for_type`의 synology 하위폴더 처리(3093-3121)→nexus, `copy_workflows`의 common/synology(3199-3228)→secret-backup, 메뉴(1916-1939, 2022-2029)·요약(3160, 3238-3240, 1838-1841) 정리.

**Files:** Modify `template_integrator.sh`

- [ ] **Step 1: _copy_workflows_for_type synology 블록 → nexus (3093-3121)**

`synology_dir="$project_types_dir/$type/synology"` 블록을:
```bash
    # 타입별 nexus 하위폴더 처리 (opt-in)
    local nexus_dir="$project_types_dir/$type/nexus"
    if [ -d "$nexus_dir" ]; then
        if [ "$INCLUDE_NEXUS" = true ]; then
            print_info "$type Nexus 워크플로우 다운로드 중..."
            for workflow in "$nexus_dir"/*.{yaml,yml}; do
                [ -e "$workflow" ] || continue
                local filename=$(basename "$workflow")
                if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                    mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
                fi
                cp "$workflow" "$WORKFLOWS_DIR/"
                echo "  ✓ $filename (Nexus $type)"
                _wf_optional_copied=$((_wf_optional_copied + 1))
                _wf_copied=$((_wf_copied + 1))
            done
        else
            local nexus_count=0
            for f in "$nexus_dir"/*.{yaml,yml}; do [ -e "$f" ] && nexus_count=$((nexus_count + 1)); done
            [ $nexus_count -gt 0 ] && print_info "$type Nexus 워크플로우 $nexus_count개 제외됨 (--nexus로 포함 가능)"
        fi
    fi
```
configure 루프(3127)의 `for _src_dir in "$type_dir" "$synology_dir"` → `for _src_dir in "$type_dir" "$nexus_dir"`.

- [ ] **Step 2: copy_workflows common/synology 블록 → secret-backup (3199-3228)**

```bash
    # 4. 공통 Secret 백업 워크플로우 처리 (opt-in)
    local common_secret_dir="$project_types_dir/common/secret-backup"
    if [ -d "$common_secret_dir" ]; then
        if [ "$INCLUDE_SECRET_BACKUP" = true ]; then
            print_info "공통 Secret 백업 워크플로우 다운로드 중..."
            for workflow in "$common_secret_dir"/*.{yaml,yml}; do
                [ -e "$workflow" ] || continue
                local filename=$(basename "$workflow")
                if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                    print_warning "$filename: 이미 존재하여 건너뜁니다."
                    continue
                fi
                cp "$workflow" "$WORKFLOWS_DIR/"
                echo "  ✓ $filename (Secret 백업)"
                _wf_optional_copied=$((_wf_optional_copied + 1))
                _wf_copied=$((_wf_copied + 1))
            done
        else
            local _sc=0
            for f in "$common_secret_dir"/*.{yaml,yml}; do [ -e "$f" ] && _sc=$((_sc + 1)); done
            [ $_sc -gt 0 ] && print_info "공통 Secret 백업 워크플로우 $_sc개 제외됨 (--secret-backup으로 포함 가능)"
        fi
    fi
```

- [ ] **Step 3: 카운터 변수 정리 (3160, 3238-3240)**

`_wf_synology_copied` → `_wf_optional_copied`(선언 3160 + 요약 3238-3240). 요약 라벨 `🗄️ Synology:` → `🧩 선택 워크플로우:`.

- [ ] **Step 4: 확인화면 요약 (1838-1841)**

`INCLUDE_SYNOLOGY` "🗄️ Synology : 포함/제외" 두 줄을 nexus·secret-backup으로:
```bash
        if [ "$INCLUDE_NEXUS" = true ]; then print_to_user "       📦 Nexus publish    : 포함";
        elif [ "$INCLUDE_NEXUS" = false ]; then print_to_user "       📦 Nexus publish    : 제외"; fi
        if [ "$INCLUDE_SECRET_BACKUP" = true ]; then print_to_user "       🔐 Secret 백업      : 포함";
        elif [ "$INCLUDE_SECRET_BACKUP" = false ]; then print_to_user "       🔐 Secret 백업      : 제외"; fi
```

- [ ] **Step 5: 수정 메뉴 (1916-1939, 2022-2029)**

메뉴 옵션 `"Synology 포함 여부"`(1921-1922)를 두 항목으로, case 매핑(1939)·핸들러(2022)를 nexus·secret-backup으로:
```bash
            _nx_state="미설정"; [ "$INCLUDE_NEXUS" = true ] && _nx_state="포함"; [ "$INCLUDE_NEXUS" = false ] && _nx_state="제외"
            _sb_state="미설정"; [ "$INCLUDE_SECRET_BACKUP" = true ] && _sb_state="포함"; [ "$INCLUDE_SECRET_BACKUP" = false ] && _sb_state="제외"
            _edit_opts+=("Nexus publish 포함 여부 (현재: ${_nx_state})|")
            _edit_opts+=("Secret 백업 포함 여부 (현재: ${_sb_state})|")
```
case 라벨(1939): `Nexus*) edit_choice="optional" ;;` / `Secret*) edit_choice="optional" ;;`.
핸들러(2022) `synology)` 블록을 `optional)` 로 바꾸고 `ask_all_optional_workflows --force-ask "${_opt_dirs[@]}"` 호출(둘 다 재질문). (두 메뉴 항목 모두 같은 핸들러로 보내 단순화.)

- [ ] **Step 6: bash -n + synology 완전 소멸**

Run:
```bash
bash -n template_integrator.sh
grep -niE "synology|INCLUDE_SYNOLOGY|ask_synology" template_integrator.sh
```
Expected: bash -n 통과. grep **0건**.

- [ ] **Step 7: expect 통합 동작 검증**

Run:
```bash
cat > /tmp/h6.sh <<'SH'
source "$PWD/template_integrator.sh"
TTY_AVAILABLE=true; FORCE_MODE=false
INCLUDE_NEXUS=""; INCLUDE_SECRET_BACKUP=""
_opt_dirs=("$PWD/.github/workflows/project-types/spring")
ask_all_optional_workflows "${_opt_dirs[@]}"
echo "<<NEXUS=$INCLUDE_NEXUS SECRET=$INCLUDE_SECRET_BACKUP>>"
SH
expect <<'EXP'
set timeout 10
spawn bash -c "cd '$env(PWD)' && bash /tmp/h6.sh"
expect "Nexus 라이브러리 publish 워크플로우를 포함할까요" { send "n\r" }
expect "Secret 서버 백업 워크플로우를 포함할까요" { send "y\r" }
expect "<<NEXUS=false SECRET=true>>" { puts ">>>PASS" }
EXP
rm -f /tmp/h6.sh
```
Expected: `>>>PASS`.

- [ ] **Step 8: Commit**

```bash
git add template_integrator.sh
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : integrator(sh) 복사·메뉴·요약을 nexus/secret-backup으로 전환, synology 완전 제거 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 7: integrator(.ps1) — sh와 대칭 적용

`.ps1`을 Task 3~6과 동일 구조로. 검증은 Docker PowerShell 파서 + 함수 단위 입력 주입.

**Files:** Modify `template_integrator.ps1` (76·79 param, 129 변수, 693-694 도움말, 1479-1490·1558-1563 메뉴, 1612-1615 요약, 1937-2042 옵션함수, 2198-2300 Ask함수, 2245-2250 CLI분기, 2513~ Copy-Workflows-ForType, 2693~ Copy-Workflows, 2755-2790 common synology, 3379·3471 호출부)

- [ ] **Step 1: param 교체 (76, 79)**

`[switch]$Synology` / `[switch]$NoSynology` →
```powershell
    [switch]$Nexus,
    [switch]$NoNexus,
    [switch]$SecretBackup,
    [switch]$NoSecretBackup,
```

- [ ] **Step 2: 변수 선언 (129)**

`$script:IncludeSynology = $null` →
```powershell
$script:IncludeNexus = $null
$script:IncludeSecretBackup = $null
```

- [ ] **Step 3: 도움말 (693-694)** — Task 3 Step 4 문구의 PowerShell 버전.

- [ ] **Step 4: Ask-SynologyOption(2198-2300) → Ask-OptionalWorkflow + Ask-AllOptionalWorkflows**

sh의 `ask_optional_workflow`/`ask_all_optional_workflows`와 동일 시그니처·동작. include 변수는 `$script:IncludeNexus`/`$script:IncludeSecretBackup`를 `[ref]` 또는 변수명 문자열+`Set-Variable -Scope Script`로 갱신. CLI 분기(2245-2250) `if ($Synology)`/`if ($NoSynology)`를 Nexus·SecretBackup 4분기로.

예 (Ask-OptionalWorkflow 핵심):
```powershell
function Ask-OptionalWorkflow {
    param([string]$Dir, [string]$Icon, [string]$Short, [string]$Desc, [string]$VarName, [switch]$ForceAsk)
    $cur = Get-Variable -Name $VarName -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if (-not (Test-Path $Dir)) { return }
    $files = @(Get-ChildItem -Path $Dir -Include *.yaml,*.yml -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return }
    if (-not $ForceAsk -and ($cur -eq $true -or $cur -eq $false)) { return }
    if (-not $script:TtyAvailable) { Set-Variable -Name $VarName -Scope Script -Value $false; return }
    Write-Host ""; Write-Host "$Icon $Short 워크플로우를 발견했습니다. ($($files.Count)개 파일)"
    Write-Host "   $Desc"; Write-Host ""
    foreach ($f in $files) { Write-Host "     • $($f.Name)" }
    if (Ask-YesNo "$Short 워크플로우를 포함할까요?" "N") {
        Set-Variable -Name $VarName -Scope Script -Value $true;  Print-Info "$Short 포함"
    } else {
        Set-Variable -Name $VarName -Scope Script -Value $false; Print-Info "$Short 제외"
    }
}
```
> `Get-ChildItem -Include`는 `-Path`에 와일드카드나 `-Recurse`가 필요할 수 있으므로, 구현 시 기존 `.ps1`이 쓰던 `-Filter "*.yaml"` + `-Filter "*.yml"` 2회 패턴(2761-2762)을 그대로 차용해 합산하는 것이 안전하다. (TtyAvailable/Ask-YesNo 실제 변수·함수명은 기존 코드에 맞춘다.)

- [ ] **Step 5: version.yml 읽기/쓰기 (1937-2042)** — sh Task 5 로직을 PowerShell 정규식으로. `nexus:`/`secret_backup:` 읽기·쓰기만. 구 `synology` 키는 무시(읽기·쓰기·제거 모두 안 함). 하위호환 매핑 없음.

- [ ] **Step 6: Copy-Workflows-ForType / Copy-Workflows synology 처리 (2513~, 2755-2790)** — `$type\nexus`(INCLUDE_NEXUS), `common\secret-backup`(INCLUDE_SECRET_BACKUP)로. `$_synologyCopied`/`$commonSynologyDir` → `$_optionalCopied`/`$commonSecretDir`.

- [ ] **Step 7: 메뉴(1479-1490, 1558-1563)·요약(1612-1615)** — sh Task 6 Step 4-5 대칭. 메뉴 두 항목, 핸들러는 `Ask-AllOptionalWorkflows -TypeDirs $typeDirs -ForceAsk`.

- [ ] **Step 8: 호출부(3379, 3471)** — `Ask-SynologyOption $typeDirs` → `Ask-AllOptionalWorkflows -TypeDirs $typeDirs`.

- [ ] **Step 9: Docker 파서 검증**

Run:
```bash
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}' > /tmp/psout.txt 2>&1
cat /tmp/psout.txt; rm -f /tmp/psout.txt
```
Expected: `PS1_PARSE_OK`.

- [ ] **Step 10: 함수 단위 입력 주입 (새 키 읽기)** — CLAUDE.md "함수만 떼어내 입력 주입" 패턴. `Read-TemplateOptions` 상당 로직만 잘라 `nexus: true / secret_backup: false` version.yml 주입 → `IncludeNexus=$true`·`IncludeSecretBackup=$false` 확인. (QEMU 함수호출 크래시 시 인라인 실행으로 로직 정상 여부 구별 — CLAUDE.md 절차.)

- [ ] **Step 11: synology 완전 소멸 + Commit**

Run: `grep -niE "synology|IncludeSynology|Ask-Synology" template_integrator.ps1` → **0건**.
```bash
git add template_integrator.ps1
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : integrator(ps1) synology 전면 제거 — nexus/secret-backup 게이트로 전환 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 8: version.yml 본체 + breaking-changes.json

**Files:** Modify `version.yml`, `.github/config/breaking-changes.json`

- [ ] **Step 1: 이 레포 version.yml options 확인**

Run: `grep -nA6 "options:" version.yml; grep -n "synology" version.yml`

- [ ] **Step 2: options 갱신**

`options:` 아래 `synology:` 키가 있으면 제거하고 `nexus: false`·`secret_backup: false` 추가(이 레포는 템플릿 원본이라 둘 다 false). 주석으로 의미 명시. (없으면 추가하지 않아도 됨 — 템플릿 원본은 옵션 미설정이 자연스러울 수 있으니, 기존에 synology 키가 있었을 때만 대체.)

- [ ] **Step 3: breaking-changes.json 새 항목**

`version.yml` 현재 버전 확인 후 다음 patch 버전 키로 `warning` 항목 추가:
```json
  "<다음버전>": {
    "severity": "warning",
    "title": "배포 워크플로우 synology 폴더/옵션 제거 — SSH+Docker 엔진으로 통일",
    "message": "Spring 배포 워크플로우(SIMPLE/NONSTOP-NGINX/NONSTOP-TRAEFIK/PR-PREVIEW)가 synology/ 폴더에서 spring/ 루트로 이동해 기본 포함됩니다. Nexus는 spring/nexus/, Secret 백업은 common/secret-backup/으로 분리되어 --nexus/--secret-backup 옵션으로 선택합니다. version.yml의 옵션 키가 synology에서 nexus/secret_backup으로 변경되었습니다 — 기존 synology 키는 더 이상 사용되지 않으니, 통합 마법사를 다시 실행해 새 옵션을 설정하세요. 다른 서버(AWS EC2 등)는 SSH_AUTH_METHOD=key + SSH_KEY secret으로 설정하세요. 자세한 내용은 docs/SSH-DOCKER-DEPLOYMENT-GUIDE.md 참고."
  }
```
> 버전 키는 `grep version: version.yml`로 현재 버전 확인 후 +patch로 기입. (version-control 워크플로우가 push 시 자동증가하므로, 현재값보다 1 높은 patch가 안전.)

- [ ] **Step 4: JSON 유효성**

Run: `python3 -m json.tool .github/config/breaking-changes.json > /dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add version.yml .github/config/breaking-changes.json
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : chore : version.yml options 전환 + breaking-changes 폴더구조 변경 안내 등록 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 9: 문서 — 배포 가이드 개명·범용화 + README + CLAUDE.md

**Files:**
- Move+Modify: `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` → `docs/SSH-DOCKER-DEPLOYMENT-GUIDE.md`
- Modify: `README.md`, `CLAUDE.md`

- [ ] **Step 1: 가이드 git mv + 범용화**

```bash
git mv docs/SYNOLOGY-DEPLOYMENT-GUIDE.md docs/SSH-DOCKER-DEPLOYMENT-GUIDE.md
```
내용: 제목·도입부 "SSH로 접속 가능한 모든 서버에 Docker 배포", "새 배포 서버 추가하는 법"(`SSH_AUTH_METHOD` password/key + 경로) 섹션 보강, Synology/AWS EC2 양쪽 예시 유지. 본문 내 옛 폴더 경로(`spring/synology/`)·옛 파일명(`SYNOLOGY-SIMPLE-CICD`) 참조를 새 경로로 갱신.

- [ ] **Step 2: README synology 6곳 정리**

- L140 → `| **SSH+Docker 배포** | SSH 접속 서버에 Docker 무중단 배포 (Synology·AWS EC2 등) | [상세](docs/SSH-DOCKER-DEPLOYMENT-GUIDE.md) |`
- L197 `Synology Docker, Nexus` → `SSH+Docker 배포, Nexus`
- L202 `Synology Docker` → `SSH+Docker 배포`
- L257 가이드 링크·라벨 갱신
- **건드리지 않음**: L187 `suh-synology-expose`(별개 스킬명), L188 `suh-ssh` 설명의 "시놀로지 NAS" 예시.

- [ ] **Step 3: CLAUDE.md 갱신**

- Spring 워크플로우 표 "위치" 열 `synology/` → 루트/`nexus/`, 파일명(SIMPLE-CICD 등) 갱신.
- 공통 표 `PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD`/`common/synology/` → `PROJECT-COMMON-SECRET-FILE-UPLOAD`/`common/secret-backup/`.
- template_integrator 설명 `--synology`/`--no-synology` → `--nexus`/`--secret-backup`, `options.synology` → `options.nexus`/`secret_backup`.
- 폴더 구조 트리에서 synology 제거.

- [ ] **Step 4: 전 저장소 synology 잔재 최종 스캔**

Run:
```bash
grep -rniE "synology|시놀로지" . --include="*.sh" --include="*.ps1" --include="*.md" --include="*.yaml" --include="*.yml" --include="*.json" \
  | grep -vE "suh-synology-expose|suh-ssh|예:|/volume1|specs/2026-06-16|plans/2026-06-16|breaking-changes.json|SSH-DOCKER" | grep -v "/.git/"
```
Expected: 의도적 예외(스킬명, 실용 예시, spec/plan 문서, breaking-changes 이력) 외 0건. 남으면 검토 후 정리.

- [ ] **Step 5: Commit**

```bash
git add docs/ README.md CLAUDE.md
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : docs : 배포 가이드 범용화 개명 + README/CLAUDE.md synology 표현 정리 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 10: 최종 통합 검증

검증 전용, 코드 변경 없음.

- [ ] **Step 1: 양쪽 문법 최종 확인**

Run:
```bash
bash -n template_integrator.sh && echo "SH_OK"
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERR:"+$e.Count}else{"PS1_PARSE_OK"}' > /tmp/ps.txt 2>&1; cat /tmp/ps.txt; rm -f /tmp/ps.txt
```
Expected: `SH_OK` + `PS1_PARSE_OK`.

- [ ] **Step 2: synology 완전 소멸 (코드)**

Run: `grep -rniE "synology|IncludeSynology|ask_synology|INCLUDE_SYNOLOGY" template_integrator.sh template_integrator.ps1`
Expected: **0건**.

- [ ] **Step 3: 폴더 구조 최종**

Run: `find .github/workflows/project-types -type d -iname synology` (0개) + 새 구조 트리.

- [ ] **Step 4: 워크플로우 실행 로직 무손상 종합**

Run: `git diff <Task1 직전 커밋>..HEAD -M -- .github/workflows/project-types/spring | grep -E "^[+-]\s*(run:|uses:|with:|steps:)" | grep -v "^[+-][+-]"`
Expected: rename(파일 이동) 외 실행 로직 변경 0줄.

- [ ] **Step 5: 임시 파일 정리 확인**

Run: `ls /tmp/h*.sh /tmp/version.yml 2>/dev/null` → 없어야 함.

- [ ] **Step 6: 최종 보고**

push는 사용자 명시 요청 시에만. 변경 요약(폴더 이동, integrator 전환, 문서)·검증 결과 보고 후 push 여부 확인.

---

## Self-Review

**1. Spec coverage:**
- spec §3 폴더재편 → Task 1 ✅ / §4 워크플로우 내부 주석·name → Task 2 ✅ (인증분기·SUDO는 Phase 1 완료) / §5 integrator → Task 3-7 ✅ / §5.4 version.yml(하위호환은 사용자 지시로 제외, 새 키만) → Task 5,8 ✅ / §6 breaking-changes → Task 8 ✅ / §7 문서 → Task 9 ✅ / §8 CLAUDE.md → Task 9 ✅ / §9 검증 → 각 Task + Task 10 ✅. spec §11 미해결 5건 → 본 plan 상단에서 전부 확정 ✅.

**2. Placeholder scan:** TBD/TODO 없음. breaking-changes 버전 키만 "구현 시점 실제 다음 patch로 확정"으로 규칙 제시(공백 placeholder 아님 — 산출 방법 명시). expect/Docker 명령은 그대로 실행 가능한 완전형.

**3. Type consistency:**
- sh: `INCLUDE_NEXUS`/`INCLUDE_SECRET_BACKUP`, `ask_optional_workflow`/`ask_all_optional_workflows`, `_wf_optional_copied`, `_opt_dirs`, `nexus_dir`/`common_secret_dir` — Task 3-6 일관.
- ps1: `$script:IncludeNexus`/`$script:IncludeSecretBackup`, `Ask-OptionalWorkflow`/`Ask-AllOptionalWorkflows`, `$_optionalCopied`, `$commonSecretDir` — Task 7 일관.
- version.yml 키: `nexus`/`secret_backup` — Task 5,8 일관.
- 폴더: `spring/nexus`, `common/secret-backup` — Task 1,4,6,7,9 일관.
