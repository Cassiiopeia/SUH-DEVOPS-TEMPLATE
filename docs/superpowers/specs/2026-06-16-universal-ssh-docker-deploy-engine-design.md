# 확장 가능한 SSH+Docker 배포 엔진 재설계

- **이슈**: [#388](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/388)
- **작성일**: 2026-06-16
- **상태**: 설계 확정 (구현 계획 대기)
- **적용 범위**: 이번 단계는 **Spring 배포 워크플로우**부터. Python/Flutter는 검증된 패턴 확정 후 동일 확산.

---

## 1. 배경 / 문제 정의

현재 Spring 배포용 워크플로우는 `.github/workflows/project-types/spring/synology/` 폴더로 격리되어 **"Synology 전용"인 것처럼** 취급된다. 대상 파일:

- `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml` (단일 컨테이너 교체)
- `PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml` (Blue-Green 무중단)
- `PROJECT-SPRING-SYNOLOGY-NONSTOP-TRAEFIK-CICD.yaml` (Blue-Green 무중단)

그러나 실제 내부 로직을 실측한 결과, 이들은 모두 **"SSH로 서버 접속 → Docker 이미지 pull → 컨테이너 교체"** 라는 **단일 패턴**이다. Synology냐 AWS EC2냐의 실제 차이는 **단 3가지**뿐이다:

| 구분 | Synology | AWS EC2 |
|------|----------|---------|
| **SSH 인증** | 비밀번호 (`password:`) | `.pem` 키 (`key:`) |
| **sudo 처리** | `echo $PW \| sudo -S` | passwordless `sudo` |
| **경로 기본값** | `/volume1/...` | `/home/ubuntu/...` |

빌드(gradle→docker→push), pull→컨테이너 교체, 포트/볼륨/헬스체크 로직은 **글자 단위로 동일**하다.

### 문제점

1. AWS·GCP·일반 VPS 등 SSH로 접속 가능한 다른 서버에 배포하려는 사용자는 **거의 동일한 워크플로우를 처음부터 다시 만들어야** 한다.
2. 배포처가 늘 때마다 ~200줄짜리 워크플로우를 복제·유지보수해야 한다. 로직 한 줄을 고치면 여러 파일을 동시에 손봐야 한다.
3. "Synology 쓰세요?"라는 양자택일 질문이, 실제로는 "어떤 서버든 SSH+Docker 배포"라는 더 넓은 개념을 가린다.

---

## 2. 설계 목표

- **확장성 최우선**: 새 배포처(GCP/VPS 등)가 와도 워크플로우를 복제하지 않고 **파라미터만 추가**하면 되도록 한다.
- **회귀 없음**: 기존 Synology 배포 동작은 100% 유지한다 (`password`를 기본값으로).
- **문서·주석으로 확장법 명시**: 사용자가 "새 서버 추가하는 법"을 워크플로우 주석/가이드에서 바로 알 수 있어야 한다.

> Synology는 이 엔진의 **첫 번째 사례**로 남고, AWS EC2가 **두 번째 사례**로 공존한다.

---

## 3. 핵심 설계

### 3.1 워크플로우 인증 분기

배포 워크플로우의 `env`에 인증 방식 선택을 `@wizard` 마커로 추가한다.

```yaml
env:
  # 🔐 SSH 인증 방식: "password"(Synology·일반 서버) | "key"(AWS EC2·.pem)
  SSH_AUTH_METHOD: "password"   # @wizard ask: SSH 인증 방식 [기본: password]
  # password → SERVER_PASSWORD secret 사용
  # key      → SSH_KEY secret 사용 (.pem 파일 내용)
```

배포 step의 `appleboy/ssh-action`에 `password`와 `key`를 **둘 다 전달**한다. 액션은 채워진 쪽을 사용하고 빈 쪽은 무시하므로, 사용자는 자신이 등록한 secret만 채우면 된다.

```yaml
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USER }}
    password: ${{ secrets.SERVER_PASSWORD }}   # password 모드용 (빈 값이면 무시됨)
    key: ${{ secrets.SSH_KEY }}                # key 모드용 (빈 값이면 무시됨)
    port: ${{ env.SSH_PORT }}
```

### 3.2 서버 내부 sudo 추상화 — `SUDO()` 헬퍼

서버 안에서 실행되는 모든 `sudo` 호출을 헬퍼 함수로 추상화한다.

```bash
if [ "${SSH_AUTH_METHOD}" = "password" ]; then
  SUDO() { echo "$PW" | sudo -S "$@"; }
else
  SUDO() { sudo "$@"; }
fi
```

기존의 모든 `echo $PW | sudo -S docker ...`를 `SUDO docker ...` 형태로 치환한다.

- `password` 모드 → `echo "$PW" | sudo -S ...` (Synology 기존 동작과 동일)
- `key` 모드 → `sudo ...` (EC2 passwordless sudo)

**`password`가 기본값**이므로 기존 Synology 배포는 회귀 없이 동작하고, `key` 선택 시 AWS EC2를 커버한다.

### 3.3 경로 기본값

`VOLUME_HOST_PATH` 등 경로 기본값은 인증 방식과 직접 묶지 않고 `@wizard ask`로 사용자가 지정하게 둔다. 주석에 Synology(`/volume1/...`)와 EC2(`/home/ubuntu/...`) 예시를 함께 명시한다.

---

## 4. 통합 도구(template_integrator) 변경

### 4.1 질문 흐름 재설계

기존 `ask_synology_option()`의 "Synology 워크플로우를 포함할까요? (y/N)"을, 다음 2단 질문으로 재설계한다:

1. **배포 워크플로우를 포함할까요?** (SSH+Docker 배포 자체)
2. (포함 시) **SSH 인증 방식은?** → `password`(기본) / `key`

`.sh`와 `.ps1` 양쪽에 동일하게 적용한다.

### 4.2 version.yml 옵션 스키마 확장

`metadata.template.options`의 기존 `synology` 불린을 배포 타겟/인증 개념으로 확장한다.

- 기존: `options.synology: true|false`
- 확장: 배포 포함 여부 + 인증 방식을 표현하는 스키마 (구체 키 이름은 구현 계획에서 확정)
- **하위호환**: 기존 프로젝트의 `options.synology: true`를 읽어 새 스키마로 자연스럽게 매핑하는 읽기 로직 포함

### 4.3 breaking-changes.json 검토

스키마가 바뀌는 범위에 한해 `.github/config/breaking-changes.json`에 버전 키로 등록할지 검토한다. 하위호환 읽기 로직으로 무중단 마이그레이션이 보장되면 `warning` 수준, 수동 조치가 필요하면 `critical`로 등록한다.

---

## 5. 문서·주석 (확장성 명시)

- **워크플로우 상단 주석**: "이 워크플로우는 SSH로 접속 가능한 모든 서버에 Docker 배포한다. 새 서버를 추가하려면 인증 방식(`SSH_AUTH_METHOD`)과 경로만 지정하면 된다"를 명시.
- **배포 가이드 문서**: `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md`를 범용 배포 가이드로 보강하거나 신규 문서를 추가하여, Synology/AWS EC2 양쪽 설정 예시와 "새 배포 서버 추가하는 법"을 담는다.

---

## 6. 검증 전략

CLAUDE.md의 "운영 중 워크플로우는 함부로 건드리지 않는다" 원칙을 따른다.

- `password` 경로: 기본값이 유지되므로 기존 Synology 배포가 그대로 동작하는지 확인.
- `key` 경로: AWS EC2에서 `.pem` 인증 배포가 실제 GitHub Actions에서 success하는지 확인.
- `template_integrator.sh`는 `bash -n` + 입력 주입(expect) 동작 검증, `.ps1`은 Docker PowerShell 파서 + 함수 단위 입력 주입 검증.
- **password/key 양쪽 경로 모두 실제 success를 확인**하기 전에는 완료로 간주하지 않는다.

---

## 7. 작업 범위 요약

| # | 대상 | 변경 |
|---|------|------|
| 1 | Spring SIMPLE / NONSTOP-NGINX 워크플로우 | `SSH_AUTH_METHOD` 분기 + `SUDO()` 헬퍼 + 인증 파라미터 이중 전달 |
| 2 | `template_integrator.sh` | 질문 흐름 재설계, version.yml 옵션 확장 + 하위호환 |
| 3 | `template_integrator.ps1` | #2와 동일하게 PowerShell로 |
| 4 | `version.yml` | options 스키마 확장 + 주석 |
| 5 | `breaking-changes.json` | 등록 여부 검토 및 필요 시 반영 |
| 6 | 워크플로우 주석 + 배포 가이드 문서 | 확장 방법 명시 |

> NONSTOP-TRAEFIK은 동일 패턴이 검증된 뒤 같은 방식으로 적용한다. Python/Flutter 배포 워크플로우는 차기 단계.

---

## 8. 미해결/구현 계획에서 확정할 사항

- `version.yml` 옵션 신규 키의 정확한 이름·구조
- `breaking-changes.json` 등록 severity (warning vs critical)
- 워크플로우 파일명 유지 여부 (현 단계는 기존 `SYNOLOGY-*` 이름 유지 가정; 개명은 별도 결정)
- 배포 가이드 문서 신규 작성 vs 기존 문서 보강
