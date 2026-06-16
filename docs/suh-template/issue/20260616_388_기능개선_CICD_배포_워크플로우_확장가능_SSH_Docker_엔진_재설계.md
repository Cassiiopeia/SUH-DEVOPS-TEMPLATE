📝 현재 문제점
---

현재 Spring 배포용 워크플로우는 `synology/` 폴더로 격리되어 **"Synology 전용"인 것처럼** 취급되고 있습니다. 그러나 실제 내부를 보면:

- `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD`, `NONSTOP-NGINX`, `NONSTOP-TRAEFIK` 모두 본질은 **"SSH로 서버에 접속 → Docker 이미지 pull → 컨테이너 교체"** 라는 단일 패턴입니다.
- Synology냐 AWS EC2냐의 실제 차이는 단 3가지뿐입니다:
  1. **SSH 인증 방식** — Synology는 비밀번호(`password`), AWS EC2는 `.pem` 키(`key`)
  2. **sudo 처리** — Synology는 `echo $PW | sudo -S`, EC2는 passwordless `sudo`
  3. **경로 기본값** — Synology는 `/volume1/...`, EC2는 `/home/ubuntu/...`

이 때문에 발생하는 문제:

- AWS·GCP·일반 VPS 등 **SSH로 접속 가능한 다른 서버에 배포하려는 사용자는 거의 동일한 워크플로우를 처음부터 다시 만들어야** 합니다.
- 배포처가 늘어날 때마다 거의 똑같은 200여 줄짜리 워크플로우를 복제·유지보수해야 하므로, 로직 한 줄을 고치면 여러 파일을 동시에 손봐야 하는 중복 부담이 생깁니다.
- "Synology 쓰세요?"라는 양자택일 질문 구조가, 실제로는 "어떤 서버든 SSH+Docker로 배포"라는 더 넓은 개념을 가립니다.

🛠️ 해결 방안 / 제안 기능
---

Spring 배포 워크플로우를 **확장 가능한 범용 SSH+Docker 배포 엔진 1벌**로 재설계합니다. Synology를 "첫 번째 사례", AWS EC2를 "두 번째 사례"로 같은 워크플로우 위에 공존시키고, 미래 배포처(GCP/VPS 등)는 **파라미터만 추가**하면 되도록 합니다. **확장성 확보가 최우선 목표**입니다.

**핵심 설계**

- 워크플로우 `env`에 `SSH_AUTH_METHOD`(`"password"` 기본 | `"key"`)를 `@wizard ask` 마커로 추가
- 배포 step의 `appleboy/ssh-action`에 `password`와 `key`를 **둘 다 전달**(빈 쪽은 액션이 자동 무시)
- 서버 내부의 `sudo` 호출을 `SUDO()` 헬퍼 함수로 추상화
  - `password` 모드 → `echo "$PW" | sudo -S ...`
  - `key` 모드 → `sudo ...` (passwordless)
  - 기존 `echo $PW | sudo -S docker ...`를 전부 `SUDO docker ...`로 치환
- **`password`를 기본값**으로 두어 기존 Synology 배포 동작을 100% 유지(회귀 없음), `key` 선택 시 AWS EC2 커버

**통합 도구(template_integrator) 변경**

- `template_integrator.sh` / `template_integrator.ps1`의 질문을 "Synology 쓰세요?"에서 "**배포 워크플로우를 포함할까요? / SSH 인증 방식은?**" 형태로 재설계
- `version.yml`의 `metadata.template.options` 스키마를 기존 `synology` 불린에서 배포 타겟/인증 개념으로 확장 (기존 프로젝트 하위호환 처리 포함)
- 스키마가 바뀌는 범위에 한해 `.github/config/breaking-changes.json` 등록 여부 검토

**문서·주석 (확장성 명시)**

- 워크플로우 상단 주석과 배포 가이드 문서에 **"새 배포 서버를 추가하는 법"**(인증/경로 파라미터를 어떻게 지정하는지)을 명시하여, 사용자가 워크플로우를 복제하지 않고도 새 서버를 붙일 수 있게 안내

⚙️ 작업 내용
---

- Spring 배포 워크플로우(SIMPLE / NONSTOP-NGINX 우선)에 `SSH_AUTH_METHOD` 분기 및 `SUDO()` 헬퍼 도입
- `appleboy/ssh-action` 인증 파라미터 이중 전달 구조 적용
- `template_integrator.sh` / `.ps1` 질문 흐름 재설계 + `version.yml` 옵션 스키마 확장(+ 하위호환)
- `breaking-changes.json` 등록 검토 및 필요 시 반영
- 워크플로우 주석 + 배포 가이드 문서에 확장 방법 기술
- password/key 양쪽 경로 모두 실제 GitHub Actions에서 success 검증
- 적용 범위: **이번에는 Spring 배포 워크플로우부터.** Python / Flutter 배포 워크플로우는 검증된 패턴이 확정된 뒤 동일하게 확산

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
