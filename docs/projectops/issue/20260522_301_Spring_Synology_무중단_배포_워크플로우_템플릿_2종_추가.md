# ⚙️[기능추가][워크플로우] Spring Synology 무중단 배포 워크플로우 템플릿 2종 추가 (Traefik / Nginx Blue-Green)

- 라벨: 작업전
- 담당자: Cassiiopeia

---

📝 현재 문제점
---

- 기존 `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml` 는 단일 컨테이너 교체 방식이라 배포 시 짧은 다운타임 발생
- Synology 환경별로 리버스 프록시 구성이 다름 (Traefik 설치 환경 / 기존 nginx 환경)
- 무중단 배포 워크플로우가 검증된 형태로 템플릿화되지 않아 프로젝트마다 매번 새로 작성

🛠️ 해결 방안 / 제안 기능
---

- Synology 환경에서 사용 가능한 무중단 배포 워크플로우 2종을 템플릿으로 추가
- 기본 워크플로우는 `SIMPLE-CICD` 로 유지하고, 무중단 옵션은 opt-in (트리거 주석 처리 상태로 배포)
- 사용자가 사용 환경에 맞게 워크플로우를 선택해 트리거 주석을 해제하는 방식

### 신규 워크플로우

| 파일 | 방식 | 사전 조건 |
|------|------|----------|
| `PROJECT-SPRING-SYNOLOGY-NONSTOP-TRAEFIK-CICD.yaml` | Traefik 라벨 기반 Blue-Green 토글 | Synology Traefik 컨테이너 + DSM 역방향 프록시 |
| `PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml` | nginx config `proxy_pass` 포트 awk 토글 + reload | nginx 설치 + sites-enabled config |

### 공통 특성

- `SIMPLE-CICD` 와 동일한 GitHub Secrets 사용 (`APPLICATION_PROD_YML`, `DOCKERHUB_*`, `SERVER_*`)
- Java 21 통일
- 트리거: `workflow_dispatch` 만 활성, `# push: deploy` 주석 처리 (전환 시 사용자가 해제)
- WORKFLOW-COMMENT-GUIDELINES.md Type D 패턴 일치 (`🔑 필수`, `🔧 환경변수`, 그룹 헤더 🌐/🚦/🔧/📦/🔌/⏱️)
- 헬스체크 실패 시 자동 롤백 (Traefik: new 유지 + old 그대로 / Nginx: 백업 복구 + 신규 컨테이너 제거)

⚙️ 작업 내용
---

- `.github/workflows/project-types/spring/synology/` 에 두 yaml 신규 추가
- `CLAUDE.md` Spring 워크플로우 표 갱신
- `docs/WORKFLOW-COMMENT-GUIDELINES.md` 적용 현황 표 갱신
- `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` 무중단 배포 섹션 2개 추가 + 트러블슈팅 항목 추가

🙋‍♂️ 담당자
---

- 개발: Cassiiopeia
