# Spring Synology 무중단 배포 워크플로우 템플릿 2종 추가 (Traefik / Nginx Blue-Green)

## 개요

Synology NAS 환경에서 Spring Boot 애플리케이션의 **다운타임 없는 배포**가 가능하도록 Blue-Green 방식 무중단 배포 워크플로우 템플릿 2종을 신규 추가했다. 기존 `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml` 는 단일 컨테이너 교체 방식으로 짧은 다운타임이 발생하는 한계가 있었으며, Synology 환경별로 리버스 프록시 구성이 다른 점(Traefik 설치 환경 / 기존 nginx 환경)을 모두 수용하기 위해 두 가지 변종으로 분리했다. 기본 워크플로우는 `SIMPLE-CICD` 그대로 유지하고, 무중단 옵션은 트리거 주석 처리 상태로 배포(opt-in)되어 사용자가 환경에 맞게 명시적으로 전환하도록 했다.

## 변경 사항

### 신규 워크플로우 (2종)
- `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-TRAEFIK-CICD.yaml`: Traefik 라벨 기반 Blue-Green 토글. 컨테이너에 `traefik.http.routers.${PROJECT_NAME}.rule=Host(\`${PRODUCTION_DOMAIN}\`)` 라벨을 부착하여 Traefik 이 자동 라우팅 등록. 헬스체크는 `localhost:${TRAEFIK_INTERNAL_PORT}` 로 `Host: ${PRODUCTION_DOMAIN}` 헤더 포함 GET 호출 + HTTP 코드 매칭(`200|301|302|308`)
- `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml`: nginx config 의 `proxy_pass` 포트를 awk 로 파싱하여 active 포트 판별 후 반대 포트로 토글. `nginx -t` 검증 + `systemctl reload nginx` 적용. 실패 시 백업 파일로 자동 복구

### 문서 업데이트
- `CLAUDE.md`: Spring 워크플로우 표에 두 신규 파일 추가 ("기본, 단일 컨테이너" / "opt-in" 표기)
- `docs/WORKFLOW-COMMENT-GUIDELINES.md`: project-types/spring/ 적용 현황 표 갱신, SIMPLE-CICD/NONSTOP-TRAEFIK-CICD/NONSTOP-NGINX-CICD 3건 Type D 표기
- `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md`: 개요 표를 3종 → 5종으로 확장, 무중단 배포 섹션 2개 추가(사전 요구사항/Secrets/env/배포 프로세스/리소스 네이밍/자동 롤백 시나리오 표), 트러블슈팅에 무중단 특화 항목 추가

### 이슈 본문 자산
- `docs/suh-template/issue/20260522_301_Spring_Synology_무중단_배포_워크플로우_템플릿_2종_추가.md`: 이슈 #301 본문 로컬 사본

## 주요 구현 내용

### Secrets/env 표준 일치 (SIMPLE-CICD 와 호환)
무중단 두 워크플로우는 기존 `SIMPLE-CICD` 와 **동일한 GitHub Secrets** (`APPLICATION_PROD_YML`, `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `SERVER_HOST`, `SERVER_USER`, `SERVER_PASSWORD`) 를 사용한다. 사용자가 워크플로우만 전환하면 추가 Secret 설정 없이 동작한다. Java 버전도 21 로 통일했다(원본 nginx 템플릿은 17 이었음).

### 트리거 정책 (opt-in)
두 워크플로우 모두 `workflow_dispatch` 만 활성, `push: branches: [deploy]` 는 주석 처리 상태로 배포된다. 기본 `SIMPLE-CICD` 가 `deploy` push 트리거를 가지므로 자동 트리거 충돌을 방지하기 위함이다. 사용자가 무중단 옵션으로 전환하려면:
1. 무중단 워크플로우의 `# push.branches` 주석 해제
2. `SIMPLE-CICD` 의 `push` 트리거 주석 처리

### Traefik 변종 — 라벨 기반 자동 라우팅
- active 컨테이너 색(blue/green) 판별은 `docker ps --filter "label=traefik.http.routers.${ROUTER_NAME}.rule"` 로 수행
- Traefik 라벨의 `Host(\`...\`)` 백틱 escape 가 yaml → SSH `envs` forward → bash 거치며 깨지지 않도록, GitHub Actions `env:` 블록에서 변수로 전달 + bash literal 안에서 `\`` escape. 워크플로우는 컨테이너 기동 직후 `docker inspect --format '...'` 로 라벨을 출력해 escape 검증
- `EXTRA_NETWORKS` env 로 추가 docker network connect 지원 (selenium-chrome-network 같은 외부 의존성)
- 헬스체크는 NAS 호스트의 `localhost:${TRAEFIK_INTERNAL_PORT}` 로 호출하여 Traefik 라우팅까지 검증 (단순 컨테이너 status=running 보다 강함)

### Nginx 변종 — config 파일 awk 토글
- 원본 워크플로우는 `test` 브랜치 분기 + `version(` 커밋 메시지 skip 로직을 포함했으나, 사용자 요청대로 모두 제거하여 본 템플릿은 deploy 브랜치 전용
- nginx config 의 `proxy_pass http://(localhost|127.0.0.1):PORT` 패턴을 awk 로 파싱. server 블록 진입 판정에 `server_name` 정규식 메타문자 escape + 중괄호 depth 추적으로 멀티 server 블록 안전 처리
- 토글 후 `nginx -t` 실패 시 백업 파일로 즉시 복구 + 신규 컨테이너 제거 (자동 롤백)
- `systemctl reload nginx` 실패 시 `restart` 재시도 → 그래도 실패면 백업 복구 + restart
- nginx 백업 파일 최신 `NGINX_BACKUP_KEEP` 개(기본 10) 보존

### 자동 롤백 매트릭스
| 실패 단계 | Traefik 변종 | Nginx 변종 |
|----------|--------------|------------|
| 컨테이너 헬스체크 실패 | new 컨테이너 유지 (수동 디버깅) + old 유지 → 자연 롤백 | 신규 컨테이너 제거 + nginx config 유지 |
| `nginx -t` 실패 | 해당 없음 | 백업 파일로 config 복구 + 신규 컨테이너 제거 |
| nginx reload/restart 실패 | 해당 없음 | 백업 복구 후 restart 재시도, 실패 시 신규 컨테이너 제거 |
| 도메인 외부 접근 실패 | 헬스체크 통과로 간주됨 (Traefik 라우팅 OK) | 경고만 — DNS 전파 지연 가능성 |

### 주석 가이드 일치 (Type D 패턴)
`docs/WORKFLOW-COMMENT-GUIDELINES.md` 의 Type D(CD 워크플로우) 패턴을 적용:
- 67자 구분선(`# =...=`) 통일
- `🔑 필수 GitHub Secrets` 헤더 블록 + 1줄 형식 (`SECRET_NAME: 설명`, 선택 항목만 `(선택)` 표기)
- `🔧 환경변수 설정 (env 섹션에서 설정)` 헤더 블록 + 그룹 헤더(🌐 포트/🚦 Traefik / 🔧 Nginx / 📦 볼륨 / 🔌 SSH / ⏱️ 헬스체크)
- GITHUB_TOKEN 언급 금지 (자동 제공)

## 검증

### YAML 문법 검증
두 yaml 모두 `yaml.safe_load` 로 파싱 OK. `jobs = ['build', 'deploy']` 두 job 정상 인식.

### 호환성 확인
- 기존 `SIMPLE-CICD` 의 deploy push 트리거 그대로 유지 → 기존 프로젝트 동작 변경 없음
- 무중단 두 파일은 `workflow_dispatch` 만 활성이라 자동 실행 위험 없음
- 동일 Secret 키 사용으로 추가 인프라 구축 없이 환경에 따라 워크플로우만 선택 가능

## 다음 단계

- 실제 프로젝트(suh-project-utility 등)에서 무중단 워크플로우 dispatch 검증 (이미 검증된 형태를 템플릿화한 것이므로 회귀 위험 낮음)
- template_integrator 의 `--synology` 옵션이 두 신규 파일을 자동 포함하는지 회귀 확인
- 후속 이슈: `/actuator/health` 노출 표준, Slack/Discord 배포 알림 통합, 로그 영속화

## 참고

- 이슈: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/301
- 가이드 문서: `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md`
- 주석 규칙: `docs/WORKFLOW-COMMENT-GUIDELINES.md`
