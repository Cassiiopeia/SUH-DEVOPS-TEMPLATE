# 확장 가능한 SSH+Docker 배포 엔진 재설계 (Synology 구분 전면 제거)

- **이슈**: [#388](https://github.com/Cassiiopeia/projectops/issues/388)
- **작성일**: 2026-06-16
- **상태**: 설계 확정 (구현 계획 대기)
- **적용 범위**: 이번 단계는 **Spring 배포 워크플로우 + template_integrator(.sh/.ps1) + 폴더 구조 + 명명 중립화**. Python/Flutter 배포는 검증된 패턴 확정 후 동일 확산.

---

## 0. 이번 개정의 핵심 (왜 다시 쓰나)

1차 작업(커밋 `0dc619c`~`c97ae06`)에서 **워크플로우 파일명의 `SYNOLOGY`를 제거**하고 **내부 로직에 `SSH_AUTH_METHOD` + `SUDO()` 헬퍼**를 넣는 것까지는 끝났다. 하지만 멈춘 지점이 있다:

- 워크플로우가 여전히 **`spring/synology/` 폴더**에 격리돼 있다. 폴더명에 `synology`가 박혀 "NAS 전용"이라는 잘못된 신호를 준다.
- **`template_integrator.sh` / `.ps1`** 양쪽에 `--synology` 옵션, `INCLUDE_SYNOLOGY` 변수, `ask_synology_option()` 함수, "Synology NAS란?" 안내 텍스트, 메뉴 항목, `version.yml options.synology` 읽기/쓰기가 **전부 Synology 기준으로 남아있다** (양쪽 합쳐 60곳 이상).
- `common/synology/PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml`은 파일명·폴더명에 `SYNOLOGY`가 그대로다.

**근본 인식**: 사람이 서버를 쓴다면 Synology든 AWS EC2든 GCP든 일반 VPS든 **그냥 "SSH로 접속하는 서버"**일 뿐이다. Synology를 별도 카테고리로 구분할 이유가 **하나도 없다**. 따라서 이번 개정의 목표는:

> **`synology`라는 단어와 그 폴더 구분을 프로젝트 전반(워크플로우 폴더·파일명·주석, integrator UX/변수/옵션, version.yml 스키마)에서 전면 제거하고, "어떤 서버든 SSH+Docker 배포"라는 확장 개념으로 통일한다.**

---

## 1. 배경 / 문제 정의

### 1.1 Synology는 특별하지 않다

`spring/synology/` 폴더의 배포 워크플로우들을 실측한 결과, 이들은 모두 **"SSH 접속 → Docker 이미지 pull → 컨테이너 교체"**라는 단일 패턴이다. Synology냐 AWS EC2냐의 실제 차이는 **단 3가지**뿐이다:

| 구분 | Synology | AWS EC2 |
|------|----------|---------|
| **SSH 인증** | 비밀번호 (`password:`) | `.pem` 키 (`key:`) |
| **sudo 처리** | `echo $PW \| sudo -S` | passwordless `sudo` |
| **경로 기본값** | `/volume1/...` | `/home/ubuntu/...` |

빌드(gradle→docker→push), pull→컨테이너 교체, 포트/볼륨/헬스체크 로직은 **글자 단위로 동일**하다. 이 3가지 차이는 1차 작업에서 이미 `SSH_AUTH_METHOD` 분기 + `SUDO()` 헬퍼 + 경로 `@wizard ask`로 흡수됐다.

### 1.2 그래서 폴더를 나눌 이유가 없다

`synology/`라는 폴더 구분은 "이건 NAS 전용"이라는 깨진 전제 위에 있었다. 전제가 사라졌으니 폴더도 사라져야 한다.

**단, Nexus는 진짜로 다르다.** `NEXUS-CI`·`NEXUS-PUBLISH`는 **서버에 배포하는 게 아니라 라이브러리/모듈을 Maven 저장소에 publish**하는, 성격이 완전히 다른 워크플로우다. 이건 배포 워크플로우와 섞이면 안 되므로 **별도 하위폴더로 분리**한다.

`common/synology/SECRET-FILE-UPLOAD`도 "GitHub Secret 파일을 서버에 SSH 업로드"하는 것이라 NAS 전용이 아니다 — 배포 엔진과는 별개의 **보조 워크플로우**이므로 별도 분류한다.

### 1.3 문제점 정리

1. AWS·GCP·일반 VPS로 배포하려는 사용자가 `synology/` 폴더와 "Synology 쓰세요?" 질문을 보면 **자기와 무관하다고 오해**한다.
2. 배포처가 늘 때마다 워크플로우를 복제·유지보수해야 한다는 (틀린) 인상을 준다.
3. integrator의 "Synology 워크플로우를 포함할까요?"라는 양자택일이 **잘못된 축**(NAS 여부)으로 질문을 던진다. 올바른 축은 "이 특수 목적 워크플로우(Nexus publish / Secret 백업)가 필요한가?"다.

---

## 2. 설계 목표

- **synology 단어 전면 제거**: 폴더·파일명·주석·integrator UX/변수/옵션·version.yml 스키마에서 `synology`/`시놀로지`를 걷어낸다.
- **확장성 최우선**: 새 배포처(GCP/VPS 등)가 와도 워크플로우 복제 없이 `SSH_AUTH_METHOD`와 경로만 지정하면 되도록 한다.
- **회귀 없음**: 기존 Synology 배포 동작은 100% 유지(`password`가 기본값). 기존 프로젝트의 `version.yml options.synology` 값도 새 스키마로 매끄럽게 마이그레이션한다.
- **올바른 질문 축**: integrator는 "Synology냐"가 아니라 "Nexus publish가 필요한가 / Secret 백업이 필요한가"를 묻는다. 표준 SSH+Docker 배포는 기본 포함한다.

> Synology는 이 엔진의 **첫 번째 사례**, AWS EC2가 **두 번째 사례**로 공존한다. 둘 다 코드·문구상 특별 취급 없이 "SSH로 접속하는 서버"의 예시일 뿐이다.

---

## 3. 폴더 / 파일 구조 재편

### 3.1 목표 구조

```
.github/workflows/project-types/
├── common/
│   ├── PROJECT-COMMON-*.yaml                       (공통 워크플로우, 루트)
│   └── secret-backup/                              ← common/synology/ 에서 이동·개명
│       └── PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml  ← 파일명 SYNOLOGY 제거
└── spring/
    ├── PROJECT-SPRING-SIMPLE-CICD.yaml             ← synology/ 에서 루트로 (배포·기본 포함)
    ├── PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml      ← synology/ 에서 루트로
    ├── PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml    ← synology/ 에서 루트로
    ├── PROJECT-SPRING-PR-PREVIEW.yaml              ← synology/ 에서 루트로
    ├── PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml  (기존 루트, 유지)
    └── nexus/                                       ← synology/ 에서 분리 (라이브러리 publish)
        ├── PROJECT-SPRING-NEXUS-CI.yml
        └── PROJECT-SPRING-NEXUS-PUBLISH.yml
```

`synology/` 폴더는 **완전히 사라진다** (`spring/synology/`, `common/synology/` 모두).

### 3.2 이동 매핑

| 현재 경로 | 새 경로 | 분류 |
|-----------|---------|------|
| `spring/synology/PROJECT-SPRING-SIMPLE-CICD.yaml` | `spring/PROJECT-SPRING-SIMPLE-CICD.yaml` | 배포(기본 포함) |
| `spring/synology/PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml` | `spring/PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml` | 배포(기본 포함) |
| `spring/synology/PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml` | `spring/PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml` | 배포(기본 포함) |
| `spring/synology/PROJECT-SPRING-PR-PREVIEW.yaml` | `spring/PROJECT-SPRING-PR-PREVIEW.yaml` | 배포(기본 포함) |
| `spring/synology/PROJECT-SPRING-NEXUS-CI.yml` | `spring/nexus/PROJECT-SPRING-NEXUS-CI.yml` | Nexus(별도 질문) |
| `spring/synology/PROJECT-SPRING-NEXUS-PUBLISH.yml` | `spring/nexus/PROJECT-SPRING-NEXUS-PUBLISH.yml` | Nexus(별도 질문) |
| `common/synology/PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml` | `common/secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml` | Secret 백업(별도 질문) |

> **확인됨**: 설치본 루트(`.github/workflows/`)에는 spring 배포 워크플로우 복사본이 없다(common만 존재). 따라서 "원본/설치본 두 곳 동기화" 부담은 이번 spring 이동에는 없다. `common/secret-backup` 이동 시에는 루트 설치본 동기화 규칙(CLAUDE.md "공통 워크플로우 두 곳 동일 유지")을 점검한다 — 단, secret-upload는 현재 루트에 설치본이 없으므로 원본 폴더만 이동하면 된다(구현 시 재확인).
> git 이력 보존을 위해 `git mv`로 이동한다.

---

## 4. 워크플로우 내부 변경

### 4.1 인증 분기 (1차 완료, 유지)

```yaml
env:
  # 🔐 SSH 인증 방식: "password"(예: Synology·일반 서버) | "key"(예: AWS EC2·.pem)
  SSH_AUTH_METHOD: "password"   # @wizard ask: SSH 인증 방식 [기본: password]
```

배포 step의 `appleboy/ssh-action`에 `password`와 `key`를 **둘 다 전달**한다. 액션은 채워진 쪽을 쓰고 빈 쪽은 무시한다.

```yaml
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USER }}
    password: ${{ secrets.SERVER_PASSWORD }}   # password 모드용 (빈 값이면 무시)
    key: ${{ secrets.SSH_KEY }}                # key 모드용 (빈 값이면 무시)
    port: ${{ env.SSH_PORT }}
```

### 4.2 `SUDO()` 헬퍼 (1차 완료, 유지)

```bash
if [ "${SSH_AUTH_METHOD}" = "password" ]; then
  SUDO() { echo "$PW" | sudo -S "$@"; }
else
  SUDO() { sudo "$@"; }
fi
```

### 4.3 주석·name 필드 중립화 (이번 단계 신규)

배포 워크플로우 4개와 secret-backup 워크플로우의 `name:` 필드·상단 주석에서 "Synology NAS"·"시놀로지"를 **서버/SSH 중립 표현**으로 교체한다.

- `Synology NAS 주소` → `서버 호스트(SSH 접속 주소)`
- `Synology 경로` → `서버 배포 경로`
- "Synology NAS에 자동 배포" → "SSH로 접속 가능한 서버에 Docker 자동 배포"
- **예시는 남긴다**: "예: Synology `/volume1/...`, AWS EC2 `/home/ubuntu/...`"처럼 실용 예시로만 언급(특별 취급 아님).

> ⚠️ CLAUDE.md "운영 중 워크플로우는 함부로 안 건드린다" 원칙 준수: `run:`/`uses:`/`with:`/`steps:` 등 **실행 로직은 한 줄도 바꾸지 않는다**. 주석·`name:`·문서 텍스트만 손댄다. 변경 후 `git diff`로 실행 로직 무손상을 자가검증한다.

대상 잔재(실측): SIMPLE 5건, NGINX 2건, TRAEFIK 6건, PR-PREVIEW 8건, secret-upload 12건.

---

## 5. template_integrator (.sh / .ps1) 전면 수정 — 핵심 작업

`--synology` **단일 게이트를 제거**하고, 성격이 다른 두 보조 워크플로우를 **독립 게이트**로 분리한다. 표준 SSH+Docker 배포 워크플로우는 **기본 포함**(질문 없음).

### 5.1 질문 흐름 재설계

| 기존 | 변경 후 |
|------|---------|
| "Synology 워크플로우를 포함할까요? (y/N)" 단일 질문 | (배포 워크플로우는 질문 없이 기본 포함) |
| — | **"Nexus 라이브러리 publish 워크플로우가 필요한가요? (y/N)"** — 라이브러리/모듈 프로젝트만 |
| — | **"GitHub Secret 파일 백업 워크플로우가 필요한가요? (y/N)"** — Secret을 서버에 업로드·이력관리하려는 경우 |

- 각 질문은 **해당 폴더(nexus/, secret-backup/)가 실제로 존재할 때만** 노출한다(기존 폴더 스캔 패턴 유지).
- `--synology`/`--no-synology` 옵션을 제거하고 `--nexus`/`--no-nexus`, `--secret-backup`/`--no-secret-backup`(`.ps1`은 `-Nexus`/`-NoNexus`, `-SecretBackup`/`-NoSecretBackup`)로 대체한다.
- `.sh`와 `.ps1`에 **동일 동작**으로 적용한다.

### 5.2 식별자 리네이밍 (양쪽 파일)

| 기존 | 변경 후 |
|------|---------|
| `INCLUDE_SYNOLOGY` (sh) / `$script:IncludeSynology` (ps1) | `INCLUDE_NEXUS`, `INCLUDE_SECRET_BACKUP` (sh) / `$script:IncludeNexus`, `$script:IncludeSecretBackup` (ps1) |
| `ask_synology_option()` / `Ask-SynologyOption` | `ask_nexus_option()` + `ask_secret_backup_option()` / `Ask-NexusOption` + `Ask-SecretBackupOption` (또는 인자로 폴더·라벨을 받는 범용 `ask_optional_workflow()` 1개로 통합) |
| 메뉴 항목 "Synology 포함 여부" | "Nexus publish 포함 여부", "Secret 백업 포함 여부" |
| 안내 텍스트 "🗄️ Synology NAS 배포용...", "📦 Synology(시놀로지)란?" | 각 워크플로우 성격에 맞는 중립 설명 |
| 요약 출력 "🗄️ Synology : 포함/제외" | "📦 Nexus publish : 포함/제외", "🔐 Secret 백업 : 포함/제외" |

> 구현 권장: 폴더 경로 + 표시 라벨 + 설명을 인자로 받는 **범용 `ask_optional_workflow()` 함수 1개**로 통합하면 nexus/secret-backup 두 게이트를 같은 코드로 처리할 수 있어 중복이 줄고 향후 보조 워크플로우 추가가 쉽다. 구체 구현은 계획 단계에서 확정.

### 5.3 폴더 참조 경로 수정

integrator가 스캔하는 경로를 새 구조에 맞춘다:

- `_td/synology` → 제거 (배포는 이제 `_td` 루트에서 일반 워크플로우로 수집)
- 신규: `_td/nexus` (Nexus 게이트용)
- `common/synology` → `common/secret-backup` (Secret 백업 게이트용)
- 글로브 주석 "common/synology/ 등 하위 디렉토리 제외" → "common/secret-backup/, common/<opt-in>/ 등 하위 디렉토리 제외"로 갱신
- ⚠️ **배포 워크플로우가 `spring/` 루트로 올라오므로**, 기존에 "루트는 무조건 설치"하던 로직이 배포 4개를 자동 포함하게 되는지 확인한다. nexus/secret-backup만 게이트 뒤에 남도록 스캔 로직을 점검한다.

### 5.4 version.yml 옵션 스키마 + 하위호환

```yaml
metadata:
  template:
    options:
      nexus: true|false           # Nexus publish 워크플로우 포함 여부
      secret_backup: true|false   # Secret 백업 워크플로우 포함 여부
```

**하위호환 읽기 로직** (필수):
- 기존 프로젝트의 `options.synology: true|false`를 읽으면:
  - `synology: true` → `nexus`·`secret_backup`를 **둘 다 true로 매핑**(기존엔 한 게이트로 묶여 있었으므로 보수적으로 둘 다 켠다).
  - `synology: false` → 둘 다 false.
  - 매핑 후 `synology` 키는 새 키로 대체하며 쓰기 시 제거(또는 주석으로 deprecated 표기).
- 새 키가 이미 있으면 그대로 사용.

> **하위호환 매핑 정책**(synology:true → nexus·secret_backup 둘 다 true)은 계획 단계에서 한 번 더 검토한다. "둘 다 켜기"가 과한지(배포만 쓰던 사용자가 Nexus까지 받게 됨), 아니면 안전한 기본인지 판단이 필요하다. 대안: `synology:true`는 보조 워크플로우 전부 false로 두되 안내만 출력.

### 5.5 영향 없는 부분(확인됨)

- `cleanup_template_files()`(initializer), `plugin_items_to_remove`(integrator) 배열에는 synology 관련 항목이 **없다** → 복사 제외/삭제 로직 영향 없음.

---

## 6. breaking-changes.json

기존 `3.0.133` 항목 메시지에 `SYNOLOGY-SIMPLE-CICD` 등 **옛 파일명**과 `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` 경로가 박혀 있다. 이번 구조 변경에 맞춰:

- 새 버전 키로 **"배포 워크플로우 폴더 구조 변경 + synology 옵션 → nexus/secret_backup 분리"** 항목 추가.
- `severity`: 하위호환 읽기 로직이 무중단 마이그레이션을 보장하면 **`warning`**, version.yml 수동 조치가 필요하면 `critical`. 기본 방향은 `warning`(자동 매핑되므로).
- 기존 `3.0.133` 메시지의 옛 파일명/문서 경로는 그대로 두되(이미 발행된 이력), 새 항목에서 최신 경로를 안내.

---

## 7. 문서 (README, 배포 가이드)

### 7.1 `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md`

- 파일명을 `docs/SSH-DOCKER-DEPLOYMENT-GUIDE.md`(또는 `DEPLOYMENT-GUIDE.md`)로 **개명**하고 내용을 범용화한다.
- "SSH로 접속 가능한 모든 서버에 Docker 배포", "새 배포 서버 추가하는 법(`SSH_AUTH_METHOD` + 경로 지정)", Synology/AWS EC2 양쪽 설정 예시를 담는다.
- 개명 시 이를 참조하는 곳(README, breaking-changes, 워크플로우 주석)의 링크를 모두 갱신한다.

### 7.2 README.md

synology 언급 6곳 정리:
- `| **Synology 배포** | Docker 기반 NAS 무중단 배포 |` → `| **SSH+Docker 배포** | SSH 접속 서버에 Docker 무중단 배포 (Synology·AWS EC2 등) |`
- 타입별 표 `Synology Docker` → `SSH+Docker 배포` / `Nexus`는 유지.
- 가이드 링크는 7.1 개명에 맞춰 갱신.
- ⚠️ **건드리지 않는 것**: `suh-synology-expose`(별개 스킬명), `suh-ssh` 설명의 "시놀로지 NAS" 예시(실용 예시) — 이번 범위 밖.

---

## 8. CLAUDE.md / 프로젝트 문서 갱신

CLAUDE.md의 워크플로우 표·폴더 구조 설명에 `synology/` 폴더와 `--synology` 옵션이 기술돼 있다. 새 구조(`nexus/`, `secret-backup/`, 배포 루트화, `--nexus`/`--secret-backup`)에 맞춰 갱신한다. (워크플로우 표의 "위치" 열, template_integrator 옵션 설명 등.)

---

## 9. 검증 전략

CLAUDE.md의 "운영 중 워크플로우는 함부로 안 건드린다" + "로컬 YAML 파서 ≠ GitHub 실제 동작" 원칙을 따른다.

1. **워크플로우 이동·중립화**: `git mv` 후 `git diff`로 **실행 로직(`run:`/`with:`/`steps:`) 무변경** 확인. 파싱 검증은 참고용(GitHub success 이력이 진짜 기준).
2. **`template_integrator.sh`**: `bash -n` 문법 검사 + `expect`로 실제 TTY 입력 주입(메뉴 진입→nexus/secret-backup 질문→ESC '뒤로'→version.yml 반영) 동작 검증. `set -e` ESC 종료 함정 점검.
3. **`template_integrator.ps1`**: Docker PowerShell `Parser::ParseFile`로 `PS1_PARSE_OK` + 수정 함수만 떼어내 입력 배열 주입 검증.
4. **하위호환**: `options.synology: true` / `false` / 키 없음 3케이스로 version.yml 읽기→새 키 매핑이 정확한지 확인.
5. **배포 회귀**: `password` 경로는 기본값 유지로 기존 Synology 배포 무영향. `key` 경로는 AWS EC2 `.pem` 배포가 실제 GitHub Actions에서 success하는지 확인(1차에서 진행 중인 검증 연속).
6. 임시 하네스/`.exp` 파일은 검증 후 정리.

---

## 10. 작업 범위 요약

| # | 대상 | 변경 |
|---|------|------|
| 1 | 워크플로우 폴더 구조 | `spring/synology/` 배포 4개 → `spring/` 루트, Nexus 2개 → `spring/nexus/`, `common/synology/` → `common/secret-backup/`. `synology/` 폴더 제거 |
| 2 | secret-upload 파일명 | `PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD` → `PROJECT-COMMON-SECRET-FILE-UPLOAD` |
| 3 | 워크플로우 주석·name | "Synology NAS"·"시놀로지" → SSH/서버 중립 표현 (실행 로직 불변) |
| 4 | `template_integrator.sh` | `--synology` 제거 → `--nexus`/`--secret-backup` 분리, `INCLUDE_*` 리네이밍, 질문/메뉴/안내 텍스트 교체, 폴더 스캔 경로 수정, version.yml 옵션+하위호환 |
| 5 | `template_integrator.ps1` | #4와 동일하게 PowerShell로 |
| 6 | `version.yml` | `options.synology` → `nexus`/`secret_backup` + 주석 + 하위호환 읽기 |
| 7 | `breaking-changes.json` | 구조 변경 새 항목 등록(severity 검토) |
| 8 | `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` | 범용 배포 가이드로 개명·보강 |
| 9 | `README.md` | synology 문구 중립화 (단 별개 스킬명·예시는 유지) |
| 10 | `CLAUDE.md` | 폴더 구조·옵션 설명 갱신 |

> NONSTOP-TRAEFIK 인증 분기는 1차에서 이미 적용됨. 이번 단계는 폴더 이동·중립화에 함께 포함. Python/Flutter 배포 워크플로우는 차기 단계.

---

## 11. 미해결 / 구현 계획에서 확정할 사항

1. **하위호환 매핑 정책**: `synology:true` → `nexus`·`secret_backup` 둘 다 true가 적정한지, 아니면 둘 다 false + 안내만 할지 (§5.4).
2. **`ask_optional_workflow()` 통합 vs 개별 함수 2개**: 범용 함수 1개로 묶을지, nexus/secret-backup 각각 둘지 (§5.2).
3. **배포 가이드 문서 최종 파일명**: `SSH-DOCKER-DEPLOYMENT-GUIDE.md` vs `DEPLOYMENT-GUIDE.md` (§7.1).
4. **breaking-changes severity**: `warning` vs `critical` (§6).
5. **secret-backup 루트 설치본 동기화 필요 여부**: 이동 시 `.github/workflows/` 루트에 설치본을 둬야 하는지(현재 없음) 재확인 (§3.2).
