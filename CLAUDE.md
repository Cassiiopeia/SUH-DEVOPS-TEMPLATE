# Projectops (구 SUH-DEVOPS-TEMPLATE)

완전 자동화된 GitHub 프로젝트 관리 템플릿

---

## ⚠️ 작업 브랜치 규칙 (agent 필독)

**이 프로젝트는 `develop` 브랜치에서 직접 작업하는 것을 기본값으로 한다. `main`은 프로덕션(default) — 직접 커밋·push 금지.**

- 별도 지시가 없으면 feature 브랜치를 만들지 말고 `develop`에서 작업·커밋·푸시한다.
- `develop` push 전에는 **항상 `git pull --rebase origin develop`** 으로 먼저 동기화한다 (릴리스 시 버전 확정 커밋이 develop에 추가되므로 로컬이 뒤처지기 쉽다).
- 릴리스(배포)는 develop→main PR로만 진행한다 (`/cassiiopeia:suh-changelog-deploy`). main 직접 push는 안전망(VERSION-CONTROL 가드)이 버전만 보전할 뿐 지원 경로가 아니다.
- `git push`는 **사용자가 명시적으로 요청한 경우에만** 실행한다.
- 사용자가 명시적으로 브랜치 작업을 요청한 경우에만 feature 브랜치를 사용한다.

---

## 프로젝트 개요

### 지원 프로젝트 타입
| 타입 | 설명 | 버전 동기화 파일 |
|------|------|-----------------|
| `spring` | Spring Boot | `build.gradle` |
| `flutter` | Flutter | `pubspec.yaml` |
| `react` | React.js | `package.json` |
| `next` | Next.js | `package.json` |
| `node` | Node.js | `package.json` |
| `python` | FastAPI/Django | `pyproject.toml` |
| `react-native` | React Native CLI | `Info.plist` + `build.gradle` |
| `react-native-expo` | Expo | `app.json` |
| `basic` | 범용 | `version.yml`만 |

> **멀티타입**: 단일 레포에 여러 타입 공존 시 `--type spring,react,python` csv로 지정. `version.yml`의 `project_types` 배열에 저장되며, 단수 `project_type` 키는 배열 첫 항목으로 자동 미러된다.
>
> **모노레포 경로**: 타입별 프로젝트가 서브폴더에 있으면(예: `app/`, `client/`, `ai/`) `version.yml`의 `project_paths` 맵(타입 → 레포 루트 기준 상대경로)으로 지정한다. integrator가 통합 시 마커 파일(`pubspec.yaml`·`package.json`·`pyproject.toml`·`build.gradle` 등)을 자동 감지·확인하며, 키가 없으면 루트 기준(기존 동작 100% 유지). 비대화형은 `--paths "flutter=app,react=client"`(`.ps1`은 `-Paths`). `version_manager.sh`가 이 경로를 따라 서브폴더 버전 파일을 동기화하므로, `PROJECT-COMMON-VERSION-CONTROL` 워크플로우는 무수정으로 모노레포를 커버한다.

---

## 폴더 구조

```
suh-github-template/
├── .github/
│   ├── workflows/
│   │   ├── PROJECT-TEMPLATE-INITIALIZER.yaml
│   │   ├── PROJECT-COMMON-*.yaml
│   │   └── project-types/
│   │       ├── common/          # 공통 원본 (+ secret-backup/ opt-in)
│   │       ├── flutter/         # Flutter 전용 (배포 워크플로우 루트 포함)
│   │       ├── spring/          # Spring 전용 (server-deploy/ 기본포함·Nexus면제외 + nexus/ opt-in)
│   │       ├── react/
│   │       └── next/
│   ├── scripts/
│   │   ├── version_manager.sh
│   │   ├── changelog_manager.py
│   │   └── template_initializer.sh
│   ├── util/flutter/
│   │   ├── playstore-wizard/
│   │   ├── testflight-wizard/
│   │   └── firebase-wizard/
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── .claude-plugin/              # 플러그인 매니페스트
├── skills/                      # 플러그인 Skills (마켓플레이스 전용)
├── scripts/                     # 플러그인 Scripts (마켓플레이스 전용)
├── .cursor/skills/
├── docs/                        # 상세 문서
├── version.yml
├── CHANGELOG.md / CHANGELOG.json
├── template_integrator.sh
└── template_integrator.ps1
```

---

## 네이밍 컨벤션

### 워크플로우 파일
```
PROJECT-[TYPE]-[FEATURE]-[DETAIL].yaml

TYPE: TEMPLATE | COMMON | FLUTTER | SPRING | REACT | NEXT
```

### 스크립트 파일
```
snake_case.sh / snake_case.py
```

---

## 핵심 워크플로우

### 공통 워크플로우

| 파일명 | 트리거 | 기능 |
|--------|--------|------|
| `PROJECT-TEMPLATE-INITIALIZER` | 저장소 생성 | 템플릿 초기화 (일회성) |
| `PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC` | main 푸시 | 플러그인 매니페스트 버전 동기화 |
| `PROJECT-COMMON-VERSION-CONTROL` | main 직접 푸시(안전망) | 릴리스 머지 외 push 시 patch 증가 |
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` | main PR (develop→main) | 버전 확정 + AI 체인지로그 + automerge |
| `PROJECT-COMMON-README-VERSION-UPDATE` | main 푸시 | README 버전 동기화 |
| `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE` | 이슈 생성 | 브랜치명/커밋 제안 |
| `PROJECT-COMMON-QA-ISSUE-CREATION-BOT` | @suh-lab 멘션 | QA 이슈 자동 생성 |
| `PROJECT-COMMON-SYNC-ISSUE-LABELS` | 라벨 파일 변경 | GitHub 라벨 동기화 |
| `PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC` | version.json 변경 | Util HTML 버전 동기화 |
| `PROJECT-COMMON-PROJECTS-SYNC-MANAGER` | 이슈 라벨 변경 | Issue Label → Projects Status 동기화 |

### 타입별 워크플로우

#### Flutter
| 파일명 | 용도 | 위치 |
|--------|------|------|
| `PROJECT-FLUTTER-CI` | 코드 분석 + 빌드 검증 | 기본 |
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD` | Play Store 배포 | 기본 |
| `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD` | Firebase App Distribution | 기본 |
| `PROJECT-FLUTTER-ANDROID-TEST-APK` | 테스트 APK 빌드 | 기본 |
| `PROJECT-FLUTTER-IOS-TESTFLIGHT` | TestFlight 배포 | 기본 |
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT` | 테스트 빌드 | 기본 |
| `PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER` | 댓글 트리거 빌드 | 기본 |
| `PROJECT-FLUTTER-ANDROID-SELFHOSTED-CICD` | 자체 서버(SMB) APK 배포 | 기본 |

#### Spring
| 파일명 | 용도 | 위치 |
|--------|------|------|
| `PROJECT-SPRING-SIMPLE-CICD` | SSH+Docker 배포 (기본, 단일 컨테이너) | spring/server-deploy/ |
| `PROJECT-SPRING-NONSTOP-TRAEFIK-CICD` | 무중단 배포 (Traefik Blue-Green) | spring/server-deploy/ |
| `PROJECT-SPRING-NONSTOP-NGINX-CICD` | 무중단 배포 (Nginx Blue-Green) | spring/server-deploy/ |
| `PROJECT-SPRING-PR-PREVIEW` | PR 프리뷰 배포 | spring/server-deploy/ |
| `PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH` | GitHub Packages 라이브러리 배포 | spring/ 루트 |
| `PROJECT-SPRING-NEXUS-CI` | Nexus CI | spring/nexus/ |
| `PROJECT-SPRING-NEXUS-PUBLISH` | Nexus 라이브러리 배포 | spring/nexus/ |

> 서버 배포 워크플로우(SIMPLE/NONSTOP-*/PR-PREVIEW)는 `server-deploy/`로 묶여 **기본 포함**됩니다. 단, **`--nexus`(라이브러리 publish) 프로젝트면 서버 배포가 불필요하므로 `server-deploy/` 폴더째 자동 제외**됩니다. `nexus/` 워크플로우는 `--nexus` 옵션으로 포함합니다.
>
> **확장 규칙(agent 필독)**: 새 "서버 배포" 성격의 Spring 워크플로우를 추가할 땐 `spring/server-deploy/`에 파일만 넣으면 된다. integrator가 `INCLUDE_NEXUS=true`일 때 이 폴더를 통째로 건너뛰므로 마법사 코드 수정이 필요 없다. (빌드/라이브러리 publish 워크플로우는 `server-deploy/`에 넣지 않는다.)

#### 공통 — Secret 백업 (opt-in)
| 파일명 | 기능 | 위치 |
|--------|------|------|
| `PROJECT-COMMON-SECRET-FILE-UPLOAD` | GitHub Secret → 서버(SSH) 업로드 | common/secret-backup/ |

> `--secret-backup` 옵션으로 포함합니다.

#### React / Next
| 파일명 | 용도 |
|--------|------|
| `PROJECT-REACT-CI` / `PROJECT-NEXT-CI` | 빌드 검증 |
| `PROJECT-REACT-CICD` / `PROJECT-NEXT-CICD` | Docker 빌드 및 배포 |

---

## 핵심 스크립트

### version_manager.sh
```bash
.github/scripts/version_manager.sh get
.github/scripts/version_manager.sh increment       # patch +1
.github/scripts/version_manager.sh set 2.0.0
.github/scripts/version_manager.sh sync
.github/scripts/version_manager.sh get-code
.github/scripts/version_manager.sh increment-code
```

### changelog_manager.py
```bash
python3 .github/scripts/changelog_manager.py update-from-summary
python3 .github/scripts/changelog_manager.py generate-md
python3 .github/scripts/changelog_manager.py export --version 1.2.3 --output release_notes.txt
```

### template_integrator.sh / .ps1
기존 프로젝트에 템플릿 기능을 추가하는 원격 실행 스크립트. 신규 통합 / 업데이트 / 되돌리기 모드 지원.
배포 워크플로우(SSH+Docker)는 기본 포함되고, `--nexus` / `--secret-backup` 옵션(.ps1은 `-Nexus` / `-SecretBackup`)으로 선택 워크플로우 포함 여부를 정한다.
선택 값은 `version.yml`의 `metadata.template.options.nexus` / `.secret_backup`에 저장.

**초기화/통합 시 복사되지 않는 템플릿 전용 파일**:
```
CLAUDE.md, CONTRIBUTING.md, LICENSE
CHANGELOG.md, CHANGELOG.json
template_integrator.sh / .ps1
docs/, .github/scripts/test/, .github/workflows/test/
.claude-plugin/, .codex-plugin/, .agents/, .cursor/, skills/, scripts/
package.json, harness/         # pi 패키지 매니페스트 + Persona Harness
```

#### ⚠️ 레포 루트에 "마켓플레이스/템플릿 전용" 파일·폴더를 추가할 때 (agent 필독)

이 레포는 **두 정체성**을 동시에 가진다 — 이 점이 일반 레포와 다른 핵심이다.

1. **템플릿 레포**: GitHub "Use this template"로 새 프로젝트를 만들면 `.github/scripts/template_initializer.sh`가 마켓플레이스/템플릿 전용 파일을 **삭제**한다.
2. **마법사 배포원**: `template_integrator.sh` / `.ps1`이 기존 프로젝트에 템플릿을 통합할 때 그 파일들을 **복사 대상에서 제외**한다.

따라서 레포 루트에 새 파일/폴더를 추가했는데 그게 **이 레포에서만 의미 있고 사용자 프로젝트로 흘러가면 안 되는 것**(플러그인 매니페스트, skill, pi 패키지 파일, 내부 문서 등)이라면, **아래 3곳(+필요 시 4번째)을 반드시 함께 수정**한다. 한 곳만 고치면 새 프로젝트가 오염되거나 마법사가 불필요한 파일을 복사한다 — 실제로 자주 빠뜨리는 함정이다.

| # | 파일 | 수정할 위치 | 동작 |
|---|------|------------|------|
| 1 | `.github/scripts/template_initializer.sh` | `cleanup_template_files()` 함수 | `[ -f / -d ]` 가드 + `rm -f / -rf` 한 블록 추가 (**삭제**) |
| 2 | `template_integrator.sh` | `plugin_items_to_remove=( ... )` 배열 | 파일/폴더명 추가 (**복사 제외**) |
| 3 | `template_integrator.ps1` | `$pluginItemsToRemove = @( ... )` 배열 | 파일/폴더명 추가 (**복사 제외**) |
| 4 | `.github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml` | 버전 동기화 step + `git add` | 버전 필드가 있는 매니페스트(`package.json` 등)면 동기화 step 추가 |

> **체크 순서**: 새 루트 파일 추가 → "이게 사용자 프로젝트에도 필요한가?" 자문 → **아니오면 위 1·2·3을 모두 수정**. 버전을 `version.yml`과 맞춰야 하는 매니페스트면 4번도 추가. 수정 후 `bash -n template_integrator.sh`, PowerShell 파서로 `.ps1`, `bash -n .github/scripts/template_initializer.sh`를 각각 돌려 문법을 확인한다.
>
> **반대로**, 추가한 게 사용자 프로젝트에도 같이 가야 하는 공통 자산(워크플로우·스크립트·설정)이라면 위 목록에 넣지 않는다 — 제외하면 통합 대상 프로젝트가 그 기능을 못 받는다.

#### macOS에서 template_integrator 검증하는 법 (실측 정리)

> Mac에는 `pwsh`가 기본 설치되어 있지 않다. `.ps1`은 **Docker로 실제 PowerShell을 돌려** 검증한다. `.sh`는 `expect`로 실제 TTY 동작까지 검증한다. 문법 통과(`bash -n`)만으로는 ESC·메뉴·`set -e` 종료 같은 런타임 버그를 못 잡는다 — 반드시 실제 키 입력을 주입해 동작을 본다.

**1) `.ps1` 구문 검증 — Docker + 실제 PowerShell 파서 (가장 신뢰도 높음)**

```bash
# PowerShell 이미지는 amd64 전용. ARM Mac에서도 --platform linux/amd64로 돌린다(QEMU).
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command '$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile("/work/template_integrator.ps1",[ref]$t,[ref]$e)|Out-Null; if($e -and $e.Count){"ERRORS:"+$e.Count}else{"PS1_PARSE_OK"}'
```

- `Parser::ParseFile`은 **실행 없이** 전체 구문을 검사한다(안전). `PS1_PARSE_OK`면 문법 통과.
- 출력이 파이프(`| grep` 등)에서 사라지면 `> /tmp/out.txt 2>&1` 로 파일에 받아서 읽는다. (Docker stdout 버퍼링 이슈)

**2) `.ps1` 동작 검증 — 함수만 떼어내 입력 주입 (AST 통째 로드 금지)**

- ⚠️ **하지 말 것**: 스크립트 전체를 `Invoke-Expression` 으로 AST 로드 → ARM Mac의 QEMU 에뮬레이션에서 `AccessViolationException`(메모리 폴트)로 죽는다. 실측 확인됨.
- ✅ **할 것**: 검증할 함수 본문만 `sed -n 'START,ENDp'` 로 잘라 최소 하네스에 붙이고, `Invoke-ChooseMenu`·`Read-UserInput`·`Read-Host` 등 입력 함수를 **배열 주입 스텁**으로 덮어쓴다. `Print-*`·`Detect-*`·외부접근 함수도 스텁.
- ⚠️ **QEMU 변종 크래시 (실측)**: 함수를 `function`으로 정의 후 **호출**하면 QEMU가 `assertion failed [block != nullptr]: BasicBlock requested for unrecognized address`로 죽을 수 있다(try-catch·trap도 못 잡는 네이티브 폴트). 이건 **PS 코드 버그가 아니라 QEMU JIT 한계**다. 구별법: ① `Parser::ParseFile`로 구문은 `PS1_PARSE_OK` 통과하는지 ② **함수 본문을 `function` 래핑 없이 인라인으로** 같은 입력에 돌려 정상 동작하는지 확인 → 둘 다 OK면 로직은 정상, QEMU만 못 돌린 것이다. 실제 Windows/Linux PowerShell에선 정상 동작한다.

```bash
# 예: Edit-ProjectInfo(1256~1342행)만 추출해 입력 시퀀스 주입
{ cat <<'PS'
$ErrorActionPreference="Stop"
$script:ProjectVersion='0.0.187'; $script:ProjectTypes=@('spring')
function Print-Success{param($m)Write-Host "OK: $m"}; function Print-Info{param($m)Write-Host "INFO: $m"}
function Print-Error{param($m)Write-Host "ERR: $m"}; function Print-QuestionHeader{param($a,$b)}
function Show-ProjectTypeMenu{''}; function Resolve-ProjectPaths{}
$script:__in=@(); $script:__i=0
function Invoke-ChooseMenu{param($Prompt,$Options,$DefaultIndex,[switch]$Multi,$Preselect) $v=$script:__in[$script:__i];$script:__i++;return $v}
function Read-UserInput{param($Prompt,$DefaultValue="") $v=$script:__in[$script:__i];$script:__i++;return $v}
PS
sed -n '1256,1342p' template_integrator.ps1
cat <<'PS'
$script:__in=@('version','9.9.9','done'); $script:__i=0   # 메뉴→버전입력→done
Edit-ProjectInfo
Write-Host "RESULT Version=$($script:ProjectVersion)"        # 기대: 9.9.9
PS
} > /tmp/ps_min.ps1
docker run --rm --platform linux/amd64 -v /tmp:/tmp -w /tmp mcr.microsoft.com/powershell:latest pwsh -NoProfile -File /tmp/ps_min.ps1
```

- 핵심: **PowerShell의 `$ErrorActionPreference="Stop"`은 `throw`(예외)에만 작동한다.** 함수가 `return $false`/비-0을 줘도 안 죽는다 — sh의 `set -e`와 정반대. 그래서 ps1은 return 기반 흐름이 안전하다.

**3) `.sh` 동작 검증 — `expect`로 실제 TTY + ESC 키 주입 (Mac 기본 제공)**

- `.sh`의 메뉴/`safe_read`는 `/dev/tty`를 직접 읽으므로 **pty가 필요**하다. 단순 stdin 파이프로는 ESC·화살표가 검증 안 된다 → `expect` 사용.
- 스크립트는 끝에서 `[ "${BASH_SOURCE[0]}" = "${0}" ] && main` 가드가 있어 **`source` 하면 main이 안 돈다.** 이를 이용해 함수만 로드하고 감지 함수를 스텁으로 덮어 특정 화면만 격리 실행한다.

```bash
# 하네스: 실제 스크립트를 source(main 미실행) + 감지 함수 스텁 + 검증할 함수 직접 호출
cat > /tmp/h.sh <<'SH'
source "$PWD/template_integrator.sh"
TTY_AVAILABLE=true; FORCE_MODE=false
PROJECT_TYPES=(spring); PROJECT_TYPE=spring; VERSION="0.0.187"; DETECTED_BRANCH="main"
detect_project_types(){ echo "spring"; }; detect_version(){ echo "0.0.187"; }
detect_default_branch(){ echo "main"; }; resolve_project_paths(){ :; }; show_project_type_menu(){ echo ""; }
detect_and_confirm_project
echo "<<END VERSION=$VERSION>>"
SH
# expect로 ESC(\033)·숫자·Enter 주입. send "\033" = ESC, send "2\r" = 2 입력
expect <<'EXP'
set timeout 8
spawn bash -c "cd '$env(PWD)' && bash /tmp/h.sh"
expect "이 정보가 맞습니까?"
send "2\r"; expect "어떤 항목을 수정"
send "2\r"; expect "새 버전을 입력"
after 200; send "\033"                 ;# ESC → '뒤로' 가는지 검증
expect { "돌아갑니다" {puts ">>>PASS"} "<<END" {puts ">>>FAIL_exited"} }
EXP
```

- ESC 직후엔 `after 200`(ms) 정도 텀을 줘야 터미널 시퀀스가 안 깨진다.
- `expect`가 `spawn id ... not open` = 프로세스가 **종료됨**(= ESC가 의도와 달리 마법사를 끝냄). 정상이면 다음 화면 텍스트가 다시 떠야 한다.

**자주 나오는 함정 (실측)**
- `set -e` 환경의 sh에서 `var=$(menu_fn)` 단독 라인은 ESC(비-0 반환) 시 **함수 전체가 즉시 종료**된다. 반드시 `var=$(menu_fn) || rc=$?` 또는 `|| true`로 종료코드를 흡수한다. ("ESC 눌렀더니 마법사가 통째로 꺼짐" 버그의 주원인.)
- `var=$(cmd); rc=$?` 처럼 `;`로 이어 같은 줄에 두면 `set -e` 안전(마지막 명령 `rc=$?`가 성공).
- 임시 하네스/`.exp` 파일은 검증 후 반드시 정리한다(`rm -f /tmp/h.sh /tmp/ps_min.ps1` 등).

---

#### ⚠️ macOS는 bash 3.2 + BSD 도구다 — `.sh` 작성·검증 시 절대 잊지 말 것 (agent 필독, 실측)

> **핵심: 윈도우(`.ps1`·Git Bash)에서 잘 돌아도 macOS에서 깨질 수 있다.** macOS 기본 `/bin/bash`는 라이선스 문제로 **3.2.57(2007년)에 박제**돼 있고, 기본 grep/sed도 **BSD 계열**이다. `.sh`는 항상 **`/bin/bash`(3.2) + BSD 도구**로 검증한다. "윈도우에서만 테스트했다"가 실제 사용자(macOS) 버그를 통째로 놓치게 한 주원인이다. (실측: 이슈 #415·#418 — 윈도우 정상, macOS만 깨짐.)

**bash 3.2에서 못 쓰는 것 (4+ 전용 → macOS에서 조용히 오작동)**
- **연관배열 `declare -A` 금지.** bash 3.2는 미지원 → 모든 문자열 키가 **인덱스 0으로 뭉개져** "키가 1개만 남는" 버그가 된다(실측 #418: @wizard env 키가 6개인데 1개만 수집). 동적 key-value가 필요하면 스크립트에 이미 있는 **`_kv_set`/`_kv_get`/`_kv_has`/`_kv_clear` 헬퍼**(eval 동적변수 + 16진 키 인코딩, 3.2/4 공용)를 쓴다.
- **`declare -g` 금지.** bash 3.2에서 `invalid option`. 최상위 레벨이면 어차피 전역이니 `-g` 없이 선언한다.
- `mapfile`/`readarray`, `${var,,}`/`${var^^}`(대소문자), `&>>`도 4+ 전용 → 사용 금지.

**BSD 도구 함정 (macOS 기본 grep/sed ≠ GNU)**
- **`grep -P`/`-oP`/`\K` 금지** (PCRE는 GNU 전용). `grep -E`로 라인 잡고 `sed -E`로 추출한다. (실측 #415: `grep: invalid option -- P`로 버전 감지 실패.)
- **`grep`이 매치 0건이면 `exit 1`** → `set -e`에서 `var=$(grep ...)` 단독 대입이 스크립트를 죽인다. `|| true`로 흡수하거나 `| head`/`| sed` 파이프로 끝낸다(pipefail 없으면 파이프 마지막 명령 코드만 봄). (실측 #415.)
- `sed -i`는 BSD가 `sed -i ''` / `sed -i.bak` 형태로 인자가 다르다. `readlink -f`·`date -d`·`xargs -r`도 BSD 미지원.

**`set -e` + 함수 끝 종료코드 (메뉴 아닌 일반 함수도 해당)**
- 위 "var=$(menu_fn)" 함정의 일반화: **함수의 마지막 명령이 비-0이면**, 그 함수가 호출부의 마지막 명령일 때 `set -e`가 스크립트를 통째로 죽인다. `[ -d x ] || return`(폴더 없으면 1 전파), `[ cond ] && cmd`(조건 거짓이면 1), `command -v foo && ...`(미설치면 1), `cp ... && ...`(실패면 1) 모두 위험. → early return은 `return 0` 명시, 끝줄 `조건 && 명령`은 `{ ...; } || true`로 감싼다. (실측 #415: Nexus/Secret 메뉴·interactive_mode·codex 제거·config cp 등 5곳.)

**검증 방법**: `bash -n`(문법)만으론 부족하다. **반드시 `/bin/bash`(3.2)로 실제 실행**한다. 함수만 떼어 `source` 후 호출하거나, `--force --mode full --type spring,flutter,react,python`로 전체 통합이 **종료코드 0으로 완주**하는지 본다. `which bash`가 brew bash(`/opt/homebrew/bin/bash`, 4+)를 가리키면 `/bin/bash`로 명시 실행해 3.2를 강제한다.

---

## ⚠️ 워크플로우 YAML 검증 — 로컬 파서를 GitHub 실제 동작으로 착각하지 말 것 (agent 필독)

> **핵심 원칙: 로컬 YAML 검증 도구(`actionlint`·Ruby `psych`·Python `pyyaml`)가 빨갛게 떠도, 그 워크플로우가 GitHub에서 실제로 깨진다는 뜻이 아니다.** 도구가 못 읽는 것과 GitHub이 못 돌리는 것은 **다르다.** 멀쩡히 돌던 워크플로우를 "검증 도구가 오류라고 했으니" 멋대로 고치지 마라 — 이건 실측으로 확인된 함정이다.

### 왜 이런 일이 생기나 (실측 사례)

`run: |` 블록 안에서 heredoc을 **들여쓰기 0칸 본문**으로 쓰는 패턴이 대표적이다:
```yaml
        run: |
          cat > android/key.properties << EOF
storeFile=keystore/key.jks      # ← 들여쓰기 0칸
EOF
```
- `actionlint`·`psych`·`pyyaml`은 이걸 `could not find expected ':'`로 **파싱 실패** 처리한다 (블록 스칼라 경계를 들여쓰기로만 판단하는 엄격한 go-yaml/libyaml 계열).
- 하지만 **GitHub Actions의 실제 YAML 파서는 이 heredoc을 정상 처리해서 워크플로우가 success한다.** 즉 도구의 한계지 진짜 버그가 아니다.

### 진짜 깨졌는지 확인하는 올바른 순서 (추측 금지, 실측만)

1. **GitHub 실행 이력을 먼저 본다 (가장 강력한 증거).** 같은 파일/패턴이 실제 `success`한 run이 있으면 → **멀쩡한 코드 확정.** 절대 손대지 마라.
   ```bash
   PAT=$(python3 -c "import json;print(json.load(open('$HOME/.suh-template/config/config.json'))['github']['global_pat'])")
   curl -s -H "Authorization: token $PAT" \
     "https://api.github.com/repos/<owner>/<repo>/actions/workflows/<file>.yaml/runs?per_page=20" \
     | python3 -c "import json,sys;from collections import Counter;d=json.load(sys.stdin);print(Counter(r['conclusion'] for r in d.get('workflow_runs',[])))"
   ```
2. **"잘 작동하는 기준 레포"와 대조한다.** 이 템플릿의 검증 기준 레포는 **`TEAM-ROMROM/RomRom-FE`(Flutter)·`TEAM-ROMROM/RomRom-BE`(Spring)** 다 — 실제 운영 중이고 빌드가 success한다. `passQL`은 **이 템플릿을 테스트하는 실험 프로젝트**라 (Flutter init도 미완) **신뢰 기준이 아니다.** passQL의 failure를 근거로 템플릿이 깨졌다고 결론짓지 마라.
3. **YAML 파싱 자체가 깨졌는지는 run annotations로 확인한다.** GitHub이 파싱에 실패하면 `syntax error` annotation을 남긴다. annotation이 없고 job이 빌드 중간 step에서 실패했으면 → **YAML은 정상, 원인은 빌드 로직(secret 누락 등)이다.**
   ```bash
   curl -s -H "Authorization: token $PAT" "https://api.github.com/repos/<owner>/<repo>/check-runs/<job_id>/annotations"
   ```

### 검증 도구를 쓸 때의 자세

- `actionlint`/`psych`/`pyyaml`은 **참고용 신호**다. 빨간불 = "확인해봐라"지 "고쳐라"가 아니다.
- 특히 **이미 운영 중인 워크플로우**(GitHub에 success 이력 있음)는 도구가 뭐라 하든 **건드리지 않는 것이 기본값**이다.
- 정 고쳐야 한다면, "잘 작동하는 RomRom이 같은 자리를 어떻게 쓰는지" 먼저 받아 대조하라. (예: key.properties는 RomRom-FE가 `echo "k=v" >> file` 방식으로 쓰며 success — 0칸 heredoc을 안 쓴다.)
- 내가 토큰화·치환 같은 **env 값만 바꾸는 작업**을 할 때, `run:`/`uses:`/`with:`/`steps:` 등 **실행 로직은 한 줄도 건드리지 않았는지** `git diff`로 자가검증하라:
  ```bash
  git diff <files> | grep "^+" | grep -v "^+++" | grep -vE "내가_의도한_변경_패턴"   # 결과 비면 실행로직 무손상
  ```

---

## 트리거 키워드

### 댓글 기반
| 키워드 | 워크플로우 | 기능 |
|--------|-----------|------|
| `@suh-lab create qa` | QA-ISSUE-CREATION-BOT | QA 이슈 자동 생성 |
| `@suh-lab build app` | SUH-LAB-APP-BUILD-TRIGGER | Android + iOS 빌드 |
| `@suh-lab apk build` | SUH-LAB-APP-BUILD-TRIGGER | Android만 빌드 |
| `@suh-lab ios build` | SUH-LAB-APP-BUILD-TRIGGER | iOS만 빌드 |

### 브랜치 기반
| 브랜치 | 트리거 | 워크플로우 |
|--------|--------|-----------|
| `develop` | push | CI (버전 증가 없음) |
| `main` | PR (develop→main) | CHANGELOG-CONTROL (버전 확정 + automerge) |
| `main` | push (릴리스 머지) | README-UPDATE, PLUGIN-SYNC, NPM-PUBLISH, CICD |
| `main` | push (직접) | VERSION-CONTROL 안전망 (+CICD — 비권장 경로) |

---

## 이슈/PR 템플릿

**이슈 템플릿**: `bug_report.md` / `feature_request.md` / `design_request.md` / `qa_request.md`

**이슈 라벨**: `긴급, 문서, 작업전, 작업중, 담당자확인, 피드백, 작업완료, 보류, 취소`

---

## Skills (Claude Code 플러그인)

**플러그인명**: `cassiiopeia`

```bash
claude plugin marketplace add Cassiiopeia/projectops
claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user
```

| 명령어 | 용도 |
|--------|------|
| `suh-analyze` | 코드 분석 |
| `suh-plan` | 계획 수립 |
| `suh-implement` | 구현 |
| `suh-review` | 코드 리뷰 |
| `suh-refactor` / `suh-refactor-analyze` | 리팩토링 |
| `suh-test` / `suh-testcase` | 테스트 |
| `suh-troubleshoot` | 트러블슈팅 |
| `suh-document` | 문서화 |
| `suh-design` / `suh-design-analyze` | 설계 |
| `suh-build` | 빌드 관리 |
| `suh-figma` | Figma 연동 |
| `suh-ppt` | 프레젠테이션 |
| `suh-spring-test` | Spring 테스트 생성 |
| `suh-init-worktree` | Git worktree 생성 |
| `suh-issue` | 이슈 작성 + GitHub 등록 |
| `suh-commit` | 이슈 기반 커밋 자동화 |
| `suh-github` | GitHub 이슈/PR 조회·관리·Actions Secret 업데이트 |
| `suh-report` | 구현 보고서 생성 |
| `suh-changelog-deploy` | develop push → main으로 릴리스 PR(deploy PR) → 버전 확정 + automerge / automerge 실패 시 재트리거 |
| `suh-synology-expose` | 시놀로지 서비스 외부 노출 가이드 |
| `suh-ssh` | 원격 서버 SSH 접속 및 명령 실행 (AWS EC2, 시놀로지 NAS, Linux 서버 등) |
| `suh-skill-creator` | skill 생성/리뷰/개선 (CREATE·REVIEW·IMPROVE 3모드) |

---

## Skills 개발 가이드

### 폴더 구조
```
skills/
├── {skill-name}/SKILL.md
├── config.json.example       # 전체 config 구조 예시 (모든 skill_id 섹션 포함)
└── references/
    ├── common-rules.md       # 절대 규칙, 커밋 컨벤션, 작업 시작 프로토콜(페르소나 로드 포함)
    ├── personas.md           # 5 전문가 페르소나 + 6 마인드셋 (harness/PERSONA.md single source) — 코드 스킬이 시작 시 로드
    ├── self-review-checklist.md # plan/analyze/implement 산출물 제출 전 자체검토 + Devil's Advocate 게이트
    ├── config-rules.md       # config 경로·스키마·읽기/쓰기 표준
    ├── mcp-subcommand-rules.md # suh_command 서브커맨드 MCP-style 설계 표준 (JSON+next, 코드 템플릿)
    ├── doc-output-path.md
    ├── project-detection.md
    ├── code-style-detection.md
    ├── tech-flutter.md
    ├── tech-react.md
    └── tech-spring.md
```

### 핵심 원칙

1. **config는 agent가 Read/Write tool로 직접 처리** — `config-get` CLI 호출 금지
2. **config 경로·스키마는 `references/config-rules.md` 참조** — skill 내 직접 기술 금지
3. **GitHub API는 curl 직접 호출** — `gh` CLI, Python CLI 모두 금지
4. **OS 호환성**: Python 실행 시 `PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)` 패턴 사용
5. **skill 시작 시 필독**: `references/common-rules.md` → (코드 스킬이면) `references/personas.md`에서 자기 페르소나 로드 → (config 필요 시) `references/config-rules.md` → (기술별) `tech-*.md`
6. **Python 행동 로직은 재사용 스크립트 파일 + MCP-style 표준** — 아래 "Python 행동 스크립트 표준" 절을 따른다. SKILL.md에 긴 Python heredoc 인라인 금지.

### Python 행동 스크립트 표준 (필수)

스킬이 Python으로 외부 시스템(GitHub API, SSH 등)을 호출할 때 반드시 이 패턴을 따른다.
이 표준은 Windows Git Bash + macOS 양쪽에서 깨지지 않도록 실측 검증된 것이다.

> **`suh_command.py`에 새 서브커맨드를 추가할 때는 `skills/references/mcp-subcommand-rules.md`를 먼저 읽는다.** 입력 계약·JSON 스키마(`ok`/`verdict`/`summary`/`next`)·gh_client와 command 레이어 분리·테스트 패턴을 코드 템플릿과 체크리스트로 정리해 둔 구체적 구현 레퍼런스다. 모범 사례는 `actions`·`deploy-status` 서브커맨드.

#### 1. 로직은 재사용 스크립트 파일에 둔다

- `skills/{skill-name}/scripts/{name}.py` 에 행동 로직을 고정 파일로 저장한다.
- SKILL.md는 **호출법만** 기술한다 (서브커맨드·인자·환경변수). 긴 Python 코드를 SKILL.md에 인라인하지 않는다.
- 이유: SKILL.md는 LLM이 매번 재입력하는 문서다. redirect strip 같은 핵심 로직을 인라인하면 재입력 시 누락·오타 위험.

#### 2. MCP-style 서브커맨드 — 입력 해석은 agent, 실행은 .py

- .py는 `argparse` 서브커맨드로 **명확한 입력 계약**을 갖는다 (예: `show-run RUN_ID`, `joblog JOB_ID`, `resolve-pr PR_NUM`).
- .py는 URL 파싱·PR→run 추적 같은 **해석을 하지 않는다**. agent가 사용자 입력(URL/PR/브랜치/빈입력)을 해석해 정확한 서브커맨드·인자를 넘긴다.
- SKILL.md에 "이런 입력 → 이런 서브커맨드" 라우팅 규칙을 명시해 agent가 제대로 판단하게 한다.
- 효과: .py는 단독 실행·테스트 가능(MCP tool처럼 예측 가능), agent는 유연하게 입력 해석.

#### 3. 인자는 환경변수로 전달 — heredoc·/tmp·stdin pipe 금지

- 민감값(PAT 등)과 인자는 **환경변수**로 넘긴다. heredoc 본문 보간·`/tmp` 임시파일·`curl | python` stdin pipe 전부 금지.
- 이유 (실측):
  - `/tmp` 경로 → Windows Git Bash에서 깨짐.
  - `curl | python3` → Windows에서 Exit code 49.
  - heredoc `{변수}` 보간 → 한글·특수문자 이스케이프 깨짐.

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
GH_PAT="..." GH_OWNER="..." GH_REPO="..." \
  PYTHONIOENCODING=utf-8 "$PYTHON" "$PROJECT_ROOT/skills/{skill}/scripts/{name}.py" show-run 12345
```

#### 4. 출력은 언제나 JSON — 내부에 `next` 힌트 필드

- 모든 서브커맨드는 **항상 JSON**을 stdout으로 출력한다 (plain text 모드 없음, `--json` 옵션도 두지 않는다).
- JSON에 `ok`(성공 여부), 데이터 필드, 그리고 **`next`**(agent가 이어서 호출할 다음 서브커맨드 힌트)를 담는다.
- agent는 단일 JSON 형식만 파싱 → 다음 행동을 정확히 판단.

```json
{"ok": true, "run_id": 12345, "conclusion": "failure",
 "failed_jobs": [{"job_id": 678, "name": "build", "failed_steps": ["Flutter build"]}],
 "next": "joblog 678"}
```

#### 5. 표준 라이브러리 우선 — 진짜 목표는 mac/Windows 양쪽 동작 + 내부망 대응

- "의존성 0"이 목표가 아니다. **진짜 목표는 mac·Windows 어디서든 깨지지 않고, 내부망(폐쇄망)에서 `pip install` 불가해도 돌아가는 것**이다.
- 따라서 가능하면 표준 라이브러리(`urllib.request`/`json`/`argparse`)로 해결한다 — 추가 설치 없이 양쪽 OS·내부망에서 바로 동작하기 때문.
- 표준 라이브러리로 안 되는 일이면 **외부 패키지를 당연히 쓴다**. 다만 스크립트 내에서 설치 시도(`pip install ... -q`) + 실패 시 수동 설치 안내를 둬서 내부망에서도 우아하게 처리한다. (예: secret 암호화 PyNaCl)

#### 6. redirect 시 Authorization 헤더 strip (필수 보안·동작)

- GitHub job logs 등 일부 엔드포인트는 Azure Blob(SAS URL)로 302 redirect된다.
- urllib 기본 동작은 `Authorization` 헤더를 redirect 대상까지 전달 → Azure가 `403 AuthenticationFailed`.
- redirect 시 `Authorization` 헤더를 제거하는 핸들러를 반드시 둔다:

```python
class StripAuthRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is not None:
            new.headers.pop("Authorization", None)
            new.unredirected_hdrs.pop("Authorization", None)
        return new
opener = urllib.request.build_opener(StripAuthRedirect)
```

### config 구조

모든 스킬의 config는 **단일 파일** `~/.suh-template/config/config.json` 하나로 관리한다.
skill_id를 키로 각 스킬의 설정을 네임스페이스로 분리한다.

| 스킬 | config 섹션 키 | 비고 |
|------|--------------|------|
| `issue`, `commit`, `github`, `changelog-deploy`, `report` | `github` | PAT + repos 공유 |
| `synology-expose` | `synology-expose` | NAS 인스턴스 정보 |
| `ssh` | `ssh` | SSH 서버 접속 정보 |

### 새 스킬에 config 추가하는 방법

1. `skill_id`(스킬 폴더명)를 키로 `config.json`에 섹션 추가
2. `skills/references/config-rules.md` §7에 스키마 문서화
3. `skills/config.json.example`에 예시 추가
4. SKILL.md에 `references/config-rules.md §2~3` 참조 명시

**별도 config 파일(`skill-name.config.json` 등)을 새로 만들지 않는다.**

### skill별 CLI 커맨드 (3-layer 아키텍처)

각 skill이 자체 `scripts/<scope>_cli.py`를 보유한다. 호출 패턴 = self-contained 5줄 (`skills/references/common-rules.md` §"skill별 py 분산 호출" 참조).

| skill | cli 파일 | 주요 서브커맨드 |
|---|---|---|
| suh-github | `skills/suh-github/scripts/github_cli.py` | get-issue, get-issues, update-issue, create-pr, list-prs, update-pr, search-issues, add-comment, explore, secrets |
| suh-issue | `skills/suh-issue/scripts/issue_cli.py` | create-issue, search-issues, update-issue, get-next-seq, normalize-title, create-branch-name, get-commit-template |
| suh-commit | `skills/suh-commit/scripts/commit_cli.py` | get-issue-number, get-issue, normalize-title, get-commit-template |
| suh-report | `skills/suh-report/scripts/report_cli.py` | get-output-path, add-comment |
| suh-review | `skills/suh-review/scripts/review_cli.py` | get-output-path |
| suh-troubleshoot | `skills/suh-troubleshoot/scripts/troubleshoot_cli.py` | get-output-path |
| suh-changelog-deploy | `skills/suh-changelog-deploy/scripts/changelog_cli.py` | actions, deploy-status, list-prs, update-pr, create-pr |

공유 도메인 로직은 `scripts/common/`에 있다 (gh_client, config, paths, title, issue_number, gh_branch, manifest, emit, bootstrap).

> GitHub API 호출은 각 skill의 `<scope>_cli.py` 서브커맨드 우선. 새 동작이 필요하면 `skills/references/mcp-subcommand-rules.md` 기준으로 `common/gh_client` 헬퍼 + cli 서브커맨드 + 테스트를 추가한다. 신규 skill에 py 필요하면 `skills/suh-skill-creator/templates/python_cli_script.py` 골격을 복사.

### Agent 주의사항

| 상황 | 처리 |
|------|------|
| config 없음 | 대화형 수집 — 억지 추론 금지 |
| repo owner/repo 불명확 | `git remote get-url origin` 추출 → 실패 시 config `github_repos` 참조 |
| GitHub API 401 | PAT 만료 안내 + `/issue` 스킬에서 재등록 유도 |
| `gh` CLI 사용 시도 | 금지 — curl로 대체 |
| 공통 워크플로우 수정 | `project-types/common/`과 `.github/workflows/` 루트 **두 곳 동일하게** 유지 |
| GitHub 댓글에 마크다운 표 | `array.join('\n')` 패턴 사용 (template literal 들여쓰기 시 표 깨짐) |

---

## 기여 가이드라인 핵심

> 상세 내용: `CONTRIBUTING.md`, `docs/WORKFLOW-COMMENT-GUIDELINES.md`

### 워크플로우 추가 시
- 공통 워크플로우: `project-types/common/` (원본) + `.github/workflows/` 루트 (복사본) **동일 유지**
- 타입별 워크플로우: `project-types/[type]/`만
- 필수 요소: `workflow_dispatch`, `concurrency`, `[skip ci]`

### Breaking Changes
호환성 문제 변경 시 `.github/config/breaking-changes.json`에 등록:
```json
{
  "버전": {
    "severity": "critical | warning",
    "title": "제목",
    "message": "상세 설명 및 조치 방법"
  }
}
```

---

## Skill routing

이 프로젝트에서 사용 가능한 스킬 호출 규칙:

| 요청 유형 | 호출 스킬 |
|----------|----------|
| **PR 생성, PR 올려줘, 이슈 댓글, 댓글 달아줘, 이슈 확인, 이슈 닫기, PR 조회, GitHub API** | **`cassiiopeia:suh-github` ← 최우선 트리거** |
| 코드 분석, 현황 파악 | `cassiiopeia:suh-analyze` |
| 버그, 오류, 원인 파악 | `cassiiopeia:suh-troubleshoot` |
| 새 기능 설계 | `cassiiopeia:suh-plan` → `cassiiopeia:suh-implement` |
| 코드 리뷰 | `cassiiopeia:suh-review` |
| 이슈 작성 | `cassiiopeia:suh-issue` |
| 커밋 | `cassiiopeia:suh-commit` |
| 배포 / automerge 실패 재트리거 | `cassiiopeia:suh-changelog-deploy` |
| 보고서 | `cassiiopeia:suh-report` |
| 원격 서버 SSH 접속, 로그/상태 확인 | `cassiiopeia:suh-ssh` |
| 브레인스토밍 | `superpowers:brainstorming` |
| 구현 계획 | `superpowers:writing-plans` |
| 계획 실행 | `superpowers:executing-plans` |

## 커밋 컨벤션 필수 규칙

커밋 메시지 앞에 이모지·태그(`🚀[기능개선]`, `⚙️[기능추가]` 등) **절대 포함 금지**.
이슈 제목에서 이모지+태그를 제거한 순수 내용만 사용한다.

- 올바른 예: `AUTO-CHANGELOG-CONTROL PR 본문 초기화 보호 로직 추가 : feat : ... https://...`
- 잘못된 예: `🚀[기능개선][ChangeLog] AUTO-CHANGELOG-CONTROL : feat : ...`

report·implement 등 커밋을 직접 실행하는 스킬도 이 규칙을 따른다.

## 기능 구현 워크플로우

새 기능 구현 시 순서:

1. `superpowers:brainstorming` — 설계 및 스펙 확정
2. `superpowers:writing-plans` — 상세 구현 계획
3. `superpowers:executing-plans` — 실제 구현
4. `superpowers:requesting-code-review` — 코드 리뷰 요청

---

## 알려진 스킬 동작 문제 및 해결 가이드

### 1. `cassiiopeia:suh-github` 스킬 자동 트리거 실패

**문제**: 사용자가 "PR 올려줘", "댓글 달아줘" 등을 요청해도 `cassiiopeia:suh-github` 스킬이 자동으로 트리거되지 않고, 다른 스킬(brainstorming 등)이 먼저 실행됨.

**원인**: `superpowers:using-superpowers` 규칙에서 어떤 스킬이든 1% 가능성이면 먼저 호출하도록 강제되는데, `brainstorming` 등 범용 스킬이 더 넓은 설명을 가지고 있어 우선 매칭됨. `cassiiopeia:suh-github` description의 트리거 키워드("PR 만들어줘", "댓글 달아줘")가 있어도 다른 스킬보다 낮은 우선순위로 처리됨.

**해결 방법 (사용자 관점)**:
- GitHub 작업 시 명시적으로 `/cassiiopeia:suh-github` 슬래시 커맨드를 입력
- 또는 메시지 앞에 "github:" 접두어 사용 ("github: PR 올려줘")

**해결 방법 (스킬 개발 관점)**:
- `skills/github/SKILL.md`의 description에 더 구체적인 트리거 키워드 추가 필요
- 또는 `cassiiopeia:suh-github`를 Skill routing 표에 더 명확한 패턴으로 등록
- PR 생성, 이슈 댓글, GitHub API 작업은 **반드시 `/cassiiopeia:suh-github` 명시 호출** 원칙을 CLAUDE.md에 명시

### 2. `cassiiopeia:suh-github` 스킬 실행 시 Repo 자동 감지 실패 (워크트리 환경)

**문제**: 스킬이 `git remote get-url origin`으로 현재 디렉토리의 repo를 감지하는데, Claude Code가 **SUH-DEVOPS-TEMPLATE** 레포 컨텍스트에서 실행 중이면 `TEAM-ROMROM/RomRom-BE`가 아닌 `Cassiiopeia/projectops`를 origin으로 잡음.

**원인**: 작업 대상 레포(RomRom-BE)가 별도 워크트리에 있거나, 현재 Claude Code 세션의 primary working directory가 다른 레포인 경우 발생.

**해결 방법**:
- 스킬 호출 시 대상 레포를 명시: `/cassiiopeia:suh-github TEAM-ROMROM/RomRom-BE 이슈 #653 PR 생성`
- config의 `repos` 목록에 등록된 레포는 이름으로 지정 가능: "RomRom-BE PR 올려줘"

### 3. Windows 환경 Python `urllib` 에러 (Exit code 49)

**문제**: `curl ... | python3 -c "..."` 파이프라인에서 `Exit code 49` 오류 발생. Python이 정상 설치되어 있어도 bash 파이프에서 python3 경로 인식 실패.

**원인**: Windows Git Bash 환경에서 `python3` 명령이 Windows Store python stub을 가리키거나, 파이프 stdin 처리 방식 차이.

**해결 방법 (스킬 개선 필요)**:
- Windows 환경에서 GitHub API JSON 파싱은 `curl | python3 -c` 대신 **PowerShell `Invoke-RestMethod`** 사용
- 또는 curl 응답을 파일로 저장 후 파싱: `curl ... -o /tmp/out.json && python3 /tmp/out.json`
- `skills/github/SKILL.md`에 Windows 대응 PowerShell 코드블록 추가 필요

**임시 해결**: Claude가 PowerShell tool을 직접 사용하여 `Invoke-RestMethod`로 GitHub API 호출

### 4. PR head 브랜치명 422 오류 (한글 브랜치명)

**문제**: 브랜치명에 한글이 포함된 경우(`20260420_#653_FCM_푸시_페이로드에_라우팅용_데이터_포함_필요`) GitHub API PR 생성 시 `422 Validation Failed: head invalid` 오류.

**원인**: PowerShell `ConvertTo-Json`이 한글 포함 문자열을 올바르게 인코딩하지 못하거나, GitHub API가 URL-encoded 브랜치명을 다르게 처리.

**해결 방법**:
- PR 생성 전 실제 remote 브랜치 존재 여부를 먼저 확인: `git ls-remote origin "브랜치명"`
- 브랜치명이 push되어 있는지 확인 후 API 호출
- `head`에 `owner:branch` 형식 사용: `"TEAM-ROMROM:브랜치명"`
