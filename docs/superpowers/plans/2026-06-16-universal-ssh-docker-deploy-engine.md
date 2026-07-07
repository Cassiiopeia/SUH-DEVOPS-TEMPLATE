# 확장 가능한 SSH+Docker 배포 엔진 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spring 배포 워크플로우(SIMPLE / NONSTOP-NGINX)에 SSH 인증 방식(password/key) 분기를 추가하여 Synology와 AWS EC2를 같은 워크플로우 하나로 커버하고, integrator가 인증 방식을 질문해 자동 설정하게 한다.

**Architecture:** 워크플로우 `env`에 `SSH_AUTH_METHOD`(`@wizard ask`, 기본 `password`)를 추가하고, `appleboy/ssh-action`에 `password`와 `key`를 둘 다 전달(빈 쪽 자동 무시)한다. 서버 내부 `sudo` 호출은 `SUDO()` 헬퍼로 추상화하여 password 모드는 `echo $PW | sudo -S`, key 모드는 passwordless `sudo`를 쓴다. `@wizard ask` 마커 엔진이 이미 질문·version.yml 저장을 처리하므로 integrator는 마커 인식만으로 동작한다.

**Tech Stack:** GitHub Actions (YAML), appleboy/ssh-action@v1.0.3, Bash (워크플로우 inline script + template_integrator.sh), PowerShell (template_integrator.ps1)

**하위호환성:** 이번 단계에서는 **고려하지 않는다** (사용자 지시). 기존 `options.synology` 값을 새 스키마로 변환하는 로직, breaking-changes.json 마이그레이션 경고는 작성하지 않는다. version.yml에는 `@wizard ask`가 새 값을 쓰기만 한다.

---

## 검증 환경 주의 (필독)

이 레포는 Windows(PowerShell)에서 작업 중이다. CLAUDE.md의 검증 프로토콜을 따른다:
- 워크플로우 YAML: 로컬 파서(actionlint/psych)가 빨간불이어도 GitHub 실제 동작과 다를 수 있다. **운영 중 워크플로우의 실행 로직(`run:`/`uses:`/`with:`)은 토큰/env 변경 시 건드리지 않는다.**
- `template_integrator.sh`: `bash -n` 문법 검사 + (가능하면) expect 입력 주입.
- `template_integrator.ps1`: Windows 환경이므로 직접 `powershell.exe`로 파서 검증 가능. `[System.Management.Automation.Language.Parser]::ParseFile`로 구문 검사.
- **password/key 양쪽 경로의 실제 GitHub Actions success 검증은 사용자가 별도 서버 환경에서 수행한다** (내부망/서버 자격 필요). 코드 레벨에서는 분기 로직의 정확성까지 책임진다.

---

## File Structure

| 파일 | 책임 | 변경 |
|------|------|------|
| `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml` | 단일 컨테이너 교체 배포 | `SSH_AUTH_METHOD` env + `SUDO()` 헬퍼 + 인증 이중 전달 |
| `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml` | Blue-Green 무중단 배포 | 동일 패턴 적용 |
| `template_integrator.sh` | 통합 마법사 (Bash) | `--help`에 인증 안내 (선택), `default_for_type_key`에 SSH_AUTH_METHOD 기본값 |
| `template_integrator.ps1` | 통합 마법사 (PowerShell) | `.sh`와 동일 |
| `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` | 배포 가이드 | password/key 인증 + AWS EC2 추가법 섹션 |
| `docs/superpowers/specs/2026-06-16-universal-ssh-docker-deploy-engine-design.md` | spec | (이미 작성됨, 변경 없음) |

> NONSTOP-TRAEFIK, PR-PREVIEW는 이번 범위 제외. Python/Flutter도 차기.

---

## 핵심 패턴 레퍼런스 (모든 워크플로우 Task가 참조)

### SSH_AUTH_METHOD env 블록 (워크플로우 env 섹션에 추가)

```yaml
  # 🔐 SSH 인증 방식: "password"(Synology·일반 서버) | "key"(AWS EC2·.pem)
  #   password → SERVER_PASSWORD secret 사용
  #   key      → SSH_KEY secret 사용 (.pem 파일 전체 내용을 secret 값으로)
  SSH_AUTH_METHOD: "password"  # @wizard ask: SSH 인증 방식(password/key) [기본: password]
```

### appleboy/ssh-action 인증 이중 전달 (deploy step의 with: 블록)

```yaml
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          password: ${{ secrets.SERVER_PASSWORD }}
          key: ${{ secrets.SSH_KEY }}
          port: ${{ env.SSH_PORT }}
```

> `appleboy/ssh-action`은 `password`와 `key`가 둘 다 제공되면 `key`를 우선 사용하고, 한쪽이 빈 값이면 채워진 쪽을 쓴다. 사용자는 자신이 쓰는 secret만 등록하면 된다.

### SUDO() 헬퍼 (script 본문 최상단, 변수 설정 직후)

```bash
            # 🔐 SSH 인증 방식에 따른 sudo 추상화
            #   password 모드: echo $PW | sudo -S  (Synology 등 sudo 비밀번호 필요 서버)
            #   key 모드: sudo 직접  (AWS EC2 등 passwordless sudo 서버)
            SSH_AUTH_METHOD="${SSH_AUTH_METHOD:-password}"
            if [ "${SSH_AUTH_METHOD}" = "key" ]; then
              SUDO() { sudo "$@"; }
            else
              SUDO() { echo "$PW" | sudo -S "$@"; }
            fi
```

---

## Task 1: SIMPLE 워크플로우 — env에 SSH_AUTH_METHOD 추가

**Files:**
- Modify: `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml` (env 섹션, 현재 103~106행의 SSH 연결 설정 블록 근처)

- [ ] **Step 1: env에 SSH_AUTH_METHOD 마커 추가**

기존 `# 🔌 SSH 연결 설정` 블록(현재 103행 `SSH_PORT: "2022"` 위)에 인증 방식 키를 추가한다. `SSH_PORT` 라인 바로 앞에 삽입:

```yaml
  # 🔐 SSH 인증 방식: "password"(Synology·일반 서버) | "key"(AWS EC2·.pem)
  #   password → SERVER_PASSWORD secret 사용
  #   key      → SSH_KEY secret 사용 (.pem 파일 전체 내용을 secret 값으로)
  SSH_AUTH_METHOD: "password"  # @wizard ask: SSH 인증 방식(password/key) [기본: password]

  # 🔌 SSH 연결 설정
  SSH_PORT: "2022"  # SSH 포트 (Synology 기본: 2022)
```

- [ ] **Step 2: 상단 주석 헤더에 SSH_KEY secret 안내 추가**

파일 상단의 `🔑 필수 GitHub Secrets` 블록(현재 9~17행)에서 `SERVER_PASSWORD: SSH 비밀번호` 라인 아래에 추가:

```
# SERVER_PASSWORD: SSH 비밀번호 (SSH_AUTH_METHOD=password일 때)
# SSH_KEY: SSH 개인키 .pem 내용 (SSH_AUTH_METHOD=key일 때, AWS EC2 등)
```

- [ ] **Step 3: YAML 문법 검증**

Run (PowerShell):
```powershell
powershell -NoProfile -Command "try { $null = [System.IO.File]::ReadAllText('.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml'); Write-Host 'READ_OK' } catch { Write-Host \"ERR: $_\" }"
```
Expected: `READ_OK` (파일 읽기 정상 — env 추가는 들여쓰기 2칸 유지 확인이 핵심)

들여쓰기 육안 확인: `SSH_AUTH_METHOD`가 다른 env 키와 동일하게 2칸 들여쓰기인지 확인.

- [ ] **Step 4: 커밋**

```bash
git add ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml"
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : SIMPLE 워크플로우 env에 SSH_AUTH_METHOD 인증 방식 추가 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 2: SIMPLE 워크플로우 — 인증 이중 전달 + SUDO() 헬퍼

**Files:**
- Modify: `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml` (deploy job, 현재 209~307행)

- [ ] **Step 1: appleboy/ssh-action with: 블록에 key + env 전달 추가**

현재 deploy step(211~215행)의 `with:` 블록:
```yaml
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          password: ${{ secrets.SERVER_PASSWORD }}
          port: ${{ env.SSH_PORT }}
```
를 다음으로 교체 (key 추가 + envs로 SSH_AUTH_METHOD 전달):
```yaml
        env:
          SSH_AUTH_METHOD: ${{ env.SSH_AUTH_METHOD }}
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          password: ${{ secrets.SERVER_PASSWORD }}
          key: ${{ secrets.SSH_KEY }}
          port: ${{ env.SSH_PORT }}
          envs: SSH_AUTH_METHOD
```

> `envs: SSH_AUTH_METHOD`는 appleboy/ssh-action이 호스트의 환경변수를 원격 셸로 전달하는 표준 방식(NONSTOP-NGINX 워크플로우 227행에서 이미 사용 중인 패턴).

- [ ] **Step 2: script 본문 최상단에 SUDO() 헬퍼 삽입**

현재 `script: |` 블록의 `export PW=...`(224행) 직후, `BRANCH=...`(227행) 앞에 헬퍼 함수 추가:

```bash
            export PW=${{ secrets.SERVER_PASSWORD }}

            # 🔐 SSH 인증 방식에 따른 sudo 추상화
            #   password 모드: echo $PW | sudo -S  (Synology 등 sudo 비밀번호 필요 서버)
            #   key 모드: sudo 직접  (AWS EC2 등 passwordless sudo 서버)
            SSH_AUTH_METHOD="${SSH_AUTH_METHOD:-password}"
            if [ "${SSH_AUTH_METHOD}" = "key" ]; then
              SUDO() { sudo "$@"; }
            else
              SUDO() { echo "$PW" | sudo -S "$@"; }
            fi
            echo "🔐 SSH 인증 방식: ${SSH_AUTH_METHOD}"
```

- [ ] **Step 3: 모든 `echo $PW | sudo -S` 를 `SUDO` 로 치환**

SIMPLE 워크플로우 script 본문에서 다음을 치환한다:

| 현재 (행 근처) | 변경 후 |
|----------------|---------|
| `echo $PW \| sudo -S docker pull ...` (260행) | `SUDO docker pull ...` |
| `echo $PW \| sudo -S docker rm -f $CONTAINER_NAME` (270행) | `SUDO docker rm -f $CONTAINER_NAME` |
| `echo $PW \| sudo -S mkdir -p "..."` (287행) | `SUDO mkdir -p "..."` |
| `echo $PW \| sudo -S docker run -d \` (300행) | `SUDO docker run -d \` |
| `echo $PW \| sudo -S docker ps ...` (317행) | `SUDO docker ps ...` |
| `echo $PW \| sudo -S docker logs ...` (319, 374행) | `SUDO docker logs ...` |

> `sudo docker ps -a` 처럼 이미 `echo $PW |` 없이 `sudo`로 시작하는 라인(268행 등)도 `SUDO`로 통일한다. password 모드에서 `SUDO`는 `echo $PW | sudo -S`로 동작하므로 기존과 동일.

육안 확인: 치환 후 `grep -n "sudo" 파일`로 남은 raw `sudo`/`echo $PW`가 의도된 것(없어야 함)인지 확인.

- [ ] **Step 4: 치환 누락 검증**

Run (PowerShell):
```powershell
Select-String -Path ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml" -Pattern 'echo \$PW \| sudo' | Measure-Object | Select-Object -ExpandProperty Count
```
Expected: `0` (모든 `echo $PW | sudo -S`가 SUDO로 치환됨)

Run:
```powershell
Select-String -Path ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml" -Pattern '\bSUDO\b' | Measure-Object | Select-Object -ExpandProperty Count
```
Expected: 헬퍼 정의 2곳(`SUDO() {`) + 치환된 호출 수 (8개 이상)

- [ ] **Step 5: 커밋**

```bash
git add ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml"
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : SIMPLE 워크플로우 인증 이중 전달 및 SUDO 헬퍼로 password/key 분기 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 3: NONSTOP-NGINX 워크플로우 — env에 SSH_AUTH_METHOD 추가

**Files:**
- Modify: `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml` (env 섹션, 현재 109~112행 SSH 연결 설정 근처)

- [ ] **Step 1: env에 SSH_AUTH_METHOD 마커 추가**

현재 `# 🔌 SSH 연결 설정`(109행) `SSH_PORT: "2022"`(110행) 앞에 삽입:

```yaml
  # 🔐 SSH 인증 방식: "password"(Synology·일반 서버) | "key"(AWS EC2·.pem)
  #   password → SERVER_PASSWORD secret 사용
  #   key      → SSH_KEY secret 사용 (.pem 파일 전체 내용을 secret 값으로)
  SSH_AUTH_METHOD: "password"  # @wizard ask: SSH 인증 방식(password/key) [기본: password]

  # 🔌 SSH 연결 설정
  SSH_PORT: "2022"
```

- [ ] **Step 2: 상단 주석 헤더에 SSH_KEY secret 안내 추가**

파일 상단 `🔑 필수 GitHub Secrets` 블록(13~21행)의 `SERVER_PASSWORD: SSH 비밀번호` 아래에 추가:

```
# SERVER_PASSWORD: SSH 비밀번호 (SSH_AUTH_METHOD=password일 때)
# SSH_KEY: SSH 개인키 .pem 내용 (SSH_AUTH_METHOD=key일 때, AWS EC2 등)
```

- [ ] **Step 3: YAML 읽기 검증**

Run (PowerShell):
```powershell
powershell -NoProfile -Command "try { $null = [System.IO.File]::ReadAllText('.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml'); Write-Host 'READ_OK' } catch { Write-Host \"ERR: $_\" }"
```
Expected: `READ_OK`. 들여쓰기 2칸 육안 확인.

- [ ] **Step 4: 커밋**

```bash
git add ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml"
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : NONSTOP-NGINX 워크플로우 env에 SSH_AUTH_METHOD 인증 방식 추가 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 4: NONSTOP-NGINX 워크플로우 — 인증 이중 전달 + SUDO() 헬퍼

**Files:**
- Modify: `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml` (deploy job, 현재 196~227행 + script 본문)

- [ ] **Step 1: with: 블록에 key 추가, envs에 SSH_AUTH_METHOD 추가**

현재 deploy step의 `with:`(220~227행):
```yaml
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          password: ${{ secrets.SERVER_PASSWORD }}
          port: ${{ env.SSH_PORT }}
          command_timeout: ${{ env.SSH_COMMAND_TIMEOUT }}
          timeout: ${{ env.SSH_CONNECTION_TIMEOUT }}
          envs: PROJECT_NAME,DOMAIN_NAME,SPRING_PROFILE,...,SERVER_PASSWORD
```
에서 두 곳을 수정한다:
1. `password:` 라인 다음에 `key: ${{ secrets.SSH_KEY }}` 추가
2. `envs:` 줄 끝에 `,SSH_AUTH_METHOD` 추가

그리고 step의 `env:` 블록(198~219행) 끝에 한 줄 추가:
```yaml
          SSH_AUTH_METHOD: ${{ env.SSH_AUTH_METHOD }}
```

- [ ] **Step 2: script 본문에 SUDO() 헬퍼 삽입**

현재 script 본문 최상단(229~231행)의:
```bash
            set -e
            export PATH=$PATH:/usr/local/bin
            export PW="${SERVER_PASSWORD}"
```
직후에 헬퍼 추가:
```bash
            export PW="${SERVER_PASSWORD}"

            # 🔐 SSH 인증 방식에 따른 sudo 추상화
            SSH_AUTH_METHOD="${SSH_AUTH_METHOD:-password}"
            if [ "${SSH_AUTH_METHOD}" = "key" ]; then
              SUDO() { sudo "$@"; }
            else
              SUDO() { echo "$PW" | sudo -S "$@"; }
            fi
            echo "🔐 SSH 인증 방식: ${SSH_AUTH_METHOD}"
```

- [ ] **Step 3: 모든 `echo "$PW" | sudo -S` / `sudo` 호출을 SUDO로 치환**

NONSTOP-NGINX는 `echo "$PW" | sudo -S` (큰따옴표) 형태와 raw `sudo` (awk/docker ps)가 섞여 있다. 다음 패턴을 모두 `SUDO`로 통일:

| 현재 패턴 (행 근처) | 변경 후 |
|---------------------|---------|
| `echo "$PW" \| sudo -S docker pull "${IMAGE}"` (251행) | `SUDO docker pull "${IMAGE}"` |
| `echo "$PW" \| sudo -S mkdir -p "${NGINX_BACKUP_DIR}"` (257행) | `SUDO mkdir -p "${NGINX_BACKUP_DIR}"` |
| `echo "$PW" \| sudo -S cp "${NGINX_RP_CONF}" "${BACKUP_FILE}"` (261행) | `SUDO cp ...` |
| `printf '%s\n' "$PW" \| sudo -S awk ...` (268행) | `printf '%s\n' "$PW" \| sudo -S awk ...` — **주의: 활성포트 탐색 awk는 stdin으로 PW를 먹어야 함. password 모드 전용 처리 필요 (Step 4 참조)** |
| `sudo docker ps -a ...` (321, 470행) | `SUDO docker ps -a ...` |
| `echo "$PW" \| sudo -S docker rm -f ...` (323, 373행 등) | `SUDO docker rm -f ...` |
| `echo "$PW" \| sudo -S mkdir -p "${VOLUME_HOST_PATH}"` (333행) | `SUDO mkdir -p ...` |
| `echo "$PW" \| sudo -S docker run -d \` (345행) | `SUDO docker run -d \` |
| `echo "$PW" \| sudo -S docker logs ...` (371행) | `SUDO docker logs ...` |
| `sudo awk -v dom=... > "${TMP_FILE}"` (382행) | **주의: 출력 리다이렉트 awk. key/password 양쪽에서 `SUDO awk ... > file` 형태로 동작 (Step 4 참조)** |
| `echo "$PW" \| sudo -S cp "${TMP_FILE}" "${NGINX_RP_CONF}"` (417행) | `SUDO cp ...` |
| `echo "$PW" \| sudo -S nginx -t` (418, 420행 등) | `SUDO nginx -t` |
| `echo "$PW" \| sudo -S systemctl reload nginx` (431행 등) | `SUDO systemctl reload nginx` |
| `echo "$PW" \| sudo -S docker image prune -af` (481행) | `SUDO docker image prune -af` |
| `echo "$PW" \| sudo -S /bin/bash -c "..."` (485행) | `SUDO /bin/bash -c "..."` |

- [ ] **Step 4: stdin/리다이렉트가 얽힌 awk 2곳 특수 처리**

`SUDO` 함수는 password 모드에서 `echo "$PW" | sudo -S "$@"`로 확장되므로 **stdin을 이미 PW가 점유**한다. 따라서 stdin/파이프/리다이렉트가 얽힌 2곳은 SUDO로 단순 치환하면 안 된다. 다음과 같이 명시적으로 분기한다.

(a) **활성 포트 탐색 awk** (현재 267~297행) — `ACTIVE_PORT=$(... | sudo -S awk ... "${NGINX_RP_CONF}")`:

`sudo awk`는 입력 파일을 인자로 받으므로 stdin이 필요 없다. password 모드의 `-S`만 PW를 먹으면 된다. 다음으로 교체:
```bash
            ACTIVE_PORT=$(
              SUDO awk -v dom="${DOMAIN_NAME}" '
                ... (awk 본문 그대로) ...
              ' "${NGINX_RP_CONF}" || true
            )
```
> password 모드: `echo "$PW" | sudo -S awk '...' file` — PW는 `-S`로 소비되고 awk는 file 인자를 읽음. 정상.
> key 모드: `sudo awk '...' file` — 정상.

(b) **포트 토글 awk → 파일 출력** (현재 382~411행) — `sudo awk ... "${NGINX_RP_CONF}" > "${TMP_FILE}"`:

리다이렉트 `> "${TMP_FILE}"`는 `SUDO` 함수 바깥에서 일어나므로 그대로 둔다:
```bash
            SUDO awk -v dom="${DOMAIN_NAME}" -v new_port="${NEW_PORT}" '
              ... (awk 본문 그대로) ...
            ' "${NGINX_RP_CONF}" > "${TMP_FILE}"
```
> 함수 호출의 stdout이 `> TMP_FILE`로 가고, password 모드의 `echo $PW`는 sudo의 stdin으로만 들어간다. 정상.

- [ ] **Step 5: 치환 검증**

Run (PowerShell):
```powershell
Select-String -Path ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml" -Pattern 'echo "\$PW" \| sudo' | Measure-Object | Select-Object -ExpandProperty Count
```
Expected: `0`

Run:
```powershell
Select-String -Path ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml" -Pattern '(?<!S)\bsudo ' | Where-Object { $_.Line -notmatch 'SUDO' } | Measure-Object | Select-Object -ExpandProperty Count
```
Expected: `0` (raw `sudo ` 호출이 모두 SUDO로 치환됨 — 단 헬퍼 정의 `sudo "$@"`는 의도된 것이므로 육안 확인)

- [ ] **Step 6: 커밋**

```bash
git add ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml"
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : NONSTOP-NGINX 워크플로우 인증 이중 전달 및 SUDO 헬퍼로 password/key 분기 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 5: integrator(.sh) — SSH_AUTH_METHOD 기본값 등록

`@wizard ask` 마커는 integrator의 마커 스캔 엔진이 자동으로 질문·치환·version.yml 저장한다(`configure_workflow_env` 함수, 2884~2960행). 따라서 별도 질문 함수 추가는 불필요하다. 단, 기본값 우선순위에서 타입별 기본값을 제공하면 UX가 좋아진다.

**Files:**
- Modify: `template_integrator.sh` (`default_for_type_key` 함수)

- [ ] **Step 1: default_for_type_key 함수 위치 확인**

Run:
```powershell
Select-String -Path "template_integrator.sh" -Pattern "default_for_type_key\(\)" | Select-Object LineNumber, Line
```
Expected: 함수 정의 라인 번호 출력. 함수 본문의 case 문 구조를 Read로 확인한다.

- [ ] **Step 2: SSH_AUTH_METHOD 기본값 case 추가**

`default_for_type_key` 함수의 case 문에 `SSH_AUTH_METHOD` 분기를 추가한다. (함수가 `KEY`를 받아 기본값을 echo하는 구조 — 실제 구조를 Step 1에서 확인 후 동일 패턴으로 추가):

```bash
        SSH_AUTH_METHOD) echo "password" ;;
```

> 이미 마커에 `[기본: password]`가 있으므로 이 case가 없어도 동작하지만, 명시적으로 두어 마커 리터럴 파싱에 의존하지 않게 한다.

- [ ] **Step 3: 문법 검증**

Run (Git Bash 또는 WSL 가능 시):
```bash
bash -n template_integrator.sh && echo "SYNTAX_OK"
```
Git Bash가 없으면 PowerShell에서 변경 라인만 육안 확인 (case 들여쓰기·`;;` 종결).
Expected: `SYNTAX_OK`

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.sh
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : integrator(sh) SSH_AUTH_METHOD 기본값 password 등록 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 6: integrator(.ps1) — SSH_AUTH_METHOD 기본값 등록

**Files:**
- Modify: `template_integrator.ps1` (`.sh`의 `default_for_type_key`에 대응하는 PowerShell 함수)

- [ ] **Step 1: 대응 함수 위치 확인**

Run (PowerShell):
```powershell
Select-String -Path "template_integrator.ps1" -Pattern "DefaultForTypeKey|default_for_type_key|Get-DefaultForTypeKey" | Select-Object LineNumber, Line
```
Expected: `.sh`의 `default_for_type_key`에 대응하는 함수명·위치 출력. 없으면 `@wizard` 처리 함수(`Set-WorkflowEnv` 등)를 찾아 기본값 case 위치를 확인한다.

- [ ] **Step 2: SSH_AUTH_METHOD 기본값 분기 추가**

Step 1에서 찾은 함수의 switch/분기에 `.sh`와 동일하게 추가:

```powershell
        'SSH_AUTH_METHOD' { 'password' }
```

(함수가 switch 구조가 아니면 해당 함수의 기본값 반환 패턴에 맞춰 동일 의미로 추가)

- [ ] **Step 3: PowerShell 구문 검증**

Run (PowerShell):
```powershell
$t=$null; $e=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "template_integrator.ps1").Path, [ref]$t, [ref]$e) | Out-Null
if ($e -and $e.Count) { "ERRORS: $($e.Count)"; $e | ForEach-Object { $_.Message } } else { "PS1_PARSE_OK" }
```
Expected: `PS1_PARSE_OK`

- [ ] **Step 4: 커밋**

```bash
git add template_integrator.ps1
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : feat : integrator(ps1) SSH_AUTH_METHOD 기본값 password 등록 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 7: 배포 가이드 문서 — 인증 방식 + AWS EC2 추가법

**Files:**
- Modify: `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` (문서 끝에 신규 섹션 추가)

- [ ] **Step 1: 현재 문서 구조 확인**

Run (PowerShell):
```powershell
Select-String -Path "docs/SYNOLOGY-DEPLOYMENT-GUIDE.md" -Pattern "^#" | Select-Object LineNumber, Line
```
Expected: 헤딩 목록 출력. 마지막 섹션 위치 파악.

- [ ] **Step 2: "SSH 인증 방식 / 다른 서버(AWS EC2) 배포" 섹션 추가**

문서 끝에 다음 섹션을 추가한다:

```markdown
## SSH 인증 방식과 다른 서버(AWS EC2 등) 배포

이 배포 워크플로우는 Synology 전용이 아니라, **SSH로 접속 가능한 모든 서버**에 Docker 컨테이너를 배포하는 범용 엔진이다. 서버 종류는 `SSH_AUTH_METHOD` 환경변수와 등록하는 Secret으로 결정된다.

### 인증 방식 선택 (`SSH_AUTH_METHOD`)

워크플로우 `env`의 `SSH_AUTH_METHOD` 값으로 인증 방식을 고른다 (통합 마법사가 질문하며, 기본값은 `password`).

| 값 | 사용 Secret | sudo 처리 | 적합한 서버 |
|----|-------------|-----------|-------------|
| `password` | `SERVER_PASSWORD` | `echo $PW \| sudo -S` | Synology NAS, sudo 비밀번호가 필요한 일반 서버 |
| `key` | `SSH_KEY` (.pem 내용) | passwordless `sudo` | AWS EC2, GCP, passwordless sudo 설정된 VPS |

### AWS EC2에 배포하기

1. 워크플로우 `env`에서 `SSH_AUTH_METHOD: "key"`로 설정 (또는 통합 마법사에서 `key` 선택).
2. GitHub Secrets에 다음을 등록:
   - `SERVER_HOST`: EC2 퍼블릭 IP 또는 도메인
   - `SERVER_USER`: `ubuntu` (Ubuntu AMI) 또는 `ec2-user` (Amazon Linux)
   - `SSH_KEY`: EC2 키페어 `.pem` 파일의 **전체 내용**을 그대로 붙여넣기
   - `SSH_PORT`: 보통 `22` (워크플로우 env의 SSH_PORT를 22로 조정)
3. EC2 보안 그룹에서 GitHub Actions의 SSH 접근을 허용하고, 서버에 Docker가 설치돼 있어야 한다.
4. DB(PostgreSQL/Redis/Mongo 등)는 서버에 미리 떠 있다고 가정한다. 이 워크플로우는 **앱 컨테이너만** 교체한다.

### 새로운 서버 유형을 추가하려면

`SSH_AUTH_METHOD`는 `password`/`key` 두 가지를 지원한다. 새 서버가 둘 중 하나의 인증을 쓴다면 **워크플로우를 복제할 필요 없이** 해당 값과 Secret만 설정하면 된다. 인증·경로 외에 서버별 특수 로직이 필요하면 `script:` 본문에서 `SSH_AUTH_METHOD` 값으로 분기를 추가한다.
```

- [ ] **Step 3: 커밋**

```bash
git add "docs/SYNOLOGY-DEPLOYMENT-GUIDE.md"
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : docs : SSH 인증 방식 및 AWS EC2 배포 가이드 추가 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 7.5: breaking-changes.json — 안내 등록 (마이그레이션 코드 없음)

하위호환 변환 로직은 만들지 않지만, 통합 업데이트하는 사용자가 "배포 워크플로우에 인증 방식 설정이 추가됐으니 재설정하면 된다"를 안내받도록 `breaking-changes.json`에 한 항목만 등록한다. 보통 사용자에겐 문제없는 변경이고 재설정만 하면 되므로 severity는 `warning`이다.

**Files:**
- Modify: `.github/config/breaking-changes.json`

- [ ] **Step 1: 현재 템플릿 버전 확인**

Run (PowerShell):
```powershell
Select-String -Path "version.yml" -Pattern '^version:' | Select-Object -ExpandProperty Line
```
Expected: `version: "3.0.132"` 형태. 이 값(또는 이 작업이 릴리스될 다음 버전)을 breaking-changes 키로 쓴다. **계획 실행 시점의 실제 version.yml 값을 사용**한다 (아래 예시의 `3.0.133`은 실행 시점 값으로 교체).

- [ ] **Step 2: breaking-changes.json에 항목 추가**

현재 파일은 `2.6.23`, `2.9.0` 두 항목이 있는 JSON 객체다. 마지막 항목(`2.9.0`) 뒤에 새 버전 키를 추가한다. `2.9.0` 객체의 닫는 `}` 뒤에 `,`를 붙이고 다음을 삽입:

```json
  "3.0.133": {
    "severity": "warning",
    "title": "Spring 배포 워크플로우 SSH 인증 방식(password/key) 추가",
    "message": "Spring 배포 워크플로우(SYNOLOGY-SIMPLE-CICD, SYNOLOGY-NONSTOP-NGINX-CICD)에 SSH_AUTH_METHOD 환경변수가 추가되어 Synology(password) 외에 AWS EC2 등 .pem 키(key) 인증 서버에도 배포할 수 있습니다. 기존 Synology 배포는 SSH_AUTH_METHOD 기본값이 password라 영향이 없습니다. 워크플로우를 새로 받으면 env의 SSH_AUTH_METHOD 값을 확인하고, key 인증을 쓰는 경우 GitHub Secret에 SSH_KEY(.pem 내용)를 등록하세요. 자세한 설정은 docs/SYNOLOGY-DEPLOYMENT-GUIDE.md의 'SSH 인증 방식과 다른 서버(AWS EC2 등) 배포' 섹션을 참고하세요."
  }
```

> 버전 키 `3.0.133`은 Step 1에서 확인한 실제 버전으로 교체한다.

- [ ] **Step 3: JSON 유효성 검증**

Run (PowerShell):
```powershell
try { Get-Content ".github/config/breaking-changes.json" -Raw | ConvertFrom-Json | Out-Null; "JSON_OK" } catch { "JSON_ERR: $_" }
```
Expected: `JSON_OK`

- [ ] **Step 4: 커밋**

```bash
git add ".github/config/breaking-changes.json"
git commit -m "배포 워크플로우를 확장 가능한 SSH+Docker 엔진으로 재설계 : docs : SSH 인증 방식 추가 breaking-changes 안내 등록 https://github.com/Cassiiopeia/projectops/issues/388"
```

---

## Task 8: 최종 통합 검증

**Files:** (검증만, 변경 없음)

- [ ] **Step 1: 두 워크플로우의 SUDO 헬퍼 일관성 확인**

Run (PowerShell):
```powershell
@(
  ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml",
  ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml"
) | ForEach-Object {
  $c = Get-Content $_ -Raw
  $hasMethod = $c -match 'SSH_AUTH_METHOD'
  $hasHelper = $c -match 'SUDO\(\)'
  $hasKey    = $c -match 'key:\s*\$\{\{\s*secrets\.SSH_KEY'
  "$_`n  SSH_AUTH_METHOD=$hasMethod  SUDO()=$hasHelper  key=$hasKey"
}
```
Expected: 두 파일 모두 `SSH_AUTH_METHOD=True  SUDO()=True  key=True`

- [ ] **Step 2: integrator @wizard 마커 인식 확인**

Run (PowerShell):
```powershell
Select-String -Path ".github/workflows/project-types/spring/synology/*.yaml" -Pattern "SSH_AUTH_METHOD.*@wizard ask" | Select-Object Path, LineNumber
```
Expected: SIMPLE, NONSTOP-NGINX 두 파일에서 마커 라인 검출 (integrator가 질문 대상으로 인식함을 의미)

- [ ] **Step 3: 잔여 raw sudo 최종 스캔**

Run (PowerShell):
```powershell
Select-String -Path ".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml",".github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml" -Pattern 'echo .*PW.* \| sudo' | Select-Object Path, LineNumber, Line
```
Expected: 결과 없음 (모든 `echo $PW | sudo`가 SUDO로 치환됨)

- [ ] **Step 4: 푸시 (사용자 요청 시에만)**

> CLAUDE.md 규칙: `git push`는 사용자가 명시적으로 요청한 경우에만 실행한다. push 전 `git pull --rebase origin main` 선행.

```bash
git pull --rebase origin main && git push origin main
```

---

## Self-Review 결과

**1. Spec coverage:**
- spec §3.1 인증 분기 → Task 1,3 (env) + Task 2,4 Step 1 (이중 전달) ✅
- spec §3.2 SUDO() 헬퍼 → Task 2,4 Step 2~4 ✅
- spec §3.3 경로 기본값 → 기존 `@wizard ask` 유지 (VOLUME_HOST_PATH 등 변경 없음), 주석은 Task 7 가이드에 명시 ✅
- spec §4.1 integrator 질문 재설계 → `@wizard ask` 마커가 자동 질문 처리(Task 1,3에서 마커 추가) + Task 5,6 기본값 ✅
- spec §4.2 version.yml 스키마 확장 → `@wizard ask`가 SSH_AUTH_METHOD를 version.yml에 자동 저장 (하위호환 제외 방침 반영, 신규 키만 추가) ✅
- spec §4.3 breaking-changes → Task 7.5에서 **마이그레이션 코드 없이 안내 항목만** 등록 (severity warning, 재설정 안내). 하위호환 변환 로직은 의도적으로 제외 ✅
- spec §5 문서·주석 → Task 1,3 상단 주석 + Task 7 가이드 ✅
- spec §6 검증 → Task 8 + 각 Task의 검증 step ✅

**2. Placeholder scan:** 모든 코드 step에 실제 코드 블록 포함. "적절히 처리"류 표현 없음. ✅

**3. Type consistency:** `SSH_AUTH_METHOD`, `SUDO()` 명칭이 Task 1~8 전체에서 일관. appleboy secret 명칭 `SSH_KEY`/`SERVER_PASSWORD` 일관. ✅

**범위 외 명시(silent cap 방지):** NONSTOP-TRAEFIK, PR-PREVIEW 워크플로우와 Python/Flutter 배포 워크플로우는 이번 계획에서 제외. 검증된 패턴 확정 후 차기 단계에서 동일 적용.
