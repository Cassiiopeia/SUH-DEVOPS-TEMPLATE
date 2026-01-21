# GitHub Projects Sync Wizard

GitHub Projects Status와 Issue Label 간 **양방향 실시간 동기화**를 위한 Cloudflare Worker 설정 마법사입니다.

## 문제점

GitHub Actions는 `projects_v2_item` 이벤트를 트리거로 지원하지 않습니다. 이로 인해 Projects Board에서 Status를 변경해도 Issue Label이 자동으로 동기화되지 않습니다.

## 해결책

**Cloudflare Workers**를 사용하여 GitHub Organization Webhook을 받아 실시간으로 Label을 동기화합니다.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    양방향 동기화 시스템                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────────┐                           ┌─────────────┐         │
│   │ Issue Label │ ◀───────────────────────▶ │  Projects   │         │
│   │             │       항상 동기화됨       │   Status    │         │
│   └──────┬──────┘                           └──────┬──────┘         │
│          │                                         │                │
│          │ Label 변경 시                           │ Status 변경 시 │
│          ▼                                         ▼                │
│   ┌─────────────┐                           ┌─────────────┐         │
│   │   GitHub    │                           │  Cloudflare │         │
│   │   Actions   │                           │   Worker    │         │
│   └─────────────┘                           └─────────────┘         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 사용 방법

### 1. 마법사 실행

`projects-sync-wizard.html` 파일을 브라우저에서 열어 마법사를 실행합니다.

### 2. 7단계 설정 진행

| 단계 | 설명 |
|------|------|
| Step 1 | GitHub Projects URL 입력 |
| Step 2 | 동기화할 Status Labels 설정 |
| Step 3 | Cloudflare 계정 설정 |
| Step 4 | Worker 파일 다운로드 (ZIP) |
| Step 5 | Cloudflare Worker 배포 |
| Step 6 | GitHub Organization Webhook 설정 |
| Step 7 | 완료 및 Secrets 내보내기 |

### 3. 필요한 Secrets

| Secret | 설명 |
|--------|------|
| `GITHUB_TOKEN` | GitHub PAT (repo, project 권한) |
| `WEBHOOK_SECRET` | Webhook 검증용 비밀키 (마법사에서 자동 생성) |

## 요구사항

- Node.js 18.0.0 이상
- Cloudflare 계정 (무료 티어 가능)
- GitHub Organization (Projects V2)

## 파일 구조

```
projects-sync-wizard/
├── version.json                  # 버전 정보
├── version-sync.sh               # HTML 버전 동기화
├── projects-sync-wizard.html     # 마법사 UI
├── projects-sync-wizard.js       # 클라이언트 로직
├── README.md                     # 이 문서
└── templates/
    ├── wrangler.toml.template    # Cloudflare 설정 템플릿
    ├── package.json.template     # npm 패키지 템플릿
    ├── tsconfig.json.template    # TypeScript 설정 템플릿
    └── src/
        └── index.ts.template     # Worker 코드 템플릿
```

## 비용

Cloudflare Workers Free Tier로 **완전 무료** 운영 가능합니다.

| 항목 | Free Tier | 예상 사용량 |
|------|-----------|-------------|
| 일일 요청 수 | 100,000건 | ~100건 |
| 요청당 CPU 시간 | 10ms | ~5ms |

## 트러블슈팅

### SSL 오류 발생 시

```bash
# npm install 시
npm config set strict-ssl false
npm install
npm config set strict-ssl true

# wrangler login 시
export NODE_TLS_REJECT_UNAUTHORIZED=0
npx wrangler login
```

### Cloudflare 이메일 인증 필요

Workers를 사용하려면 Cloudflare 계정의 이메일 인증이 필요합니다.
https://dash.cloudflare.com 에서 인증을 완료하세요.

### 서브도메인 충돌

이미 사용 중인 서브도메인은 선택할 수 없습니다. 다른 이름을 입력하세요.

## 관련 문서

- [GITHUB-PROJECTS-SYNC-WIZARD.md](../../../docs/GITHUB-PROJECTS-SYNC-WIZARD.md) - 상세 가이드
- [PROJECT-COMMON-PROJECTS-SYNC-MANAGER.yaml](../../workflows/PROJECT-COMMON-PROJECTS-SYNC-MANAGER.yaml) - Label → Status 동기화

## 버전 히스토리

- **v1.0.0** (2026-01-21): 초기 릴리즈
