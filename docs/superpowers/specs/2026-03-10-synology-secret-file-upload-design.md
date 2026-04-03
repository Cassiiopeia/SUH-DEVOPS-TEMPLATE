# Synology Secret File Upload 워크플로우 템플릿 설계

## 목적

GitHub Secrets에 저장된 설정 파일들을 Synology NAS에 자동 업로드하여 변경 이력을 추적하는 공통 워크플로우 템플릿.

## 핵심 결정

| 항목 | 결정 | 이유 |
|------|------|------|
| 배치 위치 | `project-types/common/synology/` | 모든 프로젝트 타입에서 공통 사용 |
| 업로드 방식 | SSH (appleboy/ssh-action) | 간결, 빠름, Secrets 적음, mkdir -p 지원 |
| 트리거 | main push + workflow_dispatch | 범용성 |
| 주석 타입 | Type D + AI 에이전트 프롬프트 | CD 워크플로우 + 커스텀 가이드 |
| 기본 파일 | ENV_FILE, APPLICATION_PROD_YML | 있으면 업로드, 없으면 스킵 |

## 동작 흐름

```
main push / workflow_dispatch
  ↓
타임스탬프 생성 (YYYY-MM-DD_HH-MM-SS, Asia/Seoul)
  ↓
SSH로 Synology 접속
  ├── 베이스 디렉토리 생성 ({BASE_PATH}/{PROJECT}/{ROLE})
  ├── 타임스탬프 백업 디렉토리 생성
  ├── Secret별 파일 생성 (있으면 업로드, 없으면 스킵)
  ├── 최신 파일은 루트에 덮어쓰기
  └── cicd-gitignore-file.json 메타데이터 생성
```

## 사용자 설정 영역

```yaml
env:
  PROJECT_NAME: "my-project"
  ROLE: "backend"
  SSH_PORT: "2022"
  SYNOLOGY_BASE_PATH: "/volume1/projects"
```

## 필수 Secrets

- SERVER_HOST: Synology NAS 주소
- SERVER_USER: SSH 사용자명
- SERVER_PASSWORD: SSH 비밀번호

## 참고

- RomRom-BE: SSH 방식 (appleboy/ssh-action)
- RomRom-FE: SMB 방식 (smbclient) → SSH로 통일
- 워크플로우 주석 가이드라인: docs/WORKFLOW-COMMENT-GUIDELINES.md
