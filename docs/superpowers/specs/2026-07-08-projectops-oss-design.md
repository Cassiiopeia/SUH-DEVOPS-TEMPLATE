# Projectops OSS (오픈소스 공모전 제출용) — 설계 명세

- 날짜: 2026-07-08
- 상태: 사용자 승인된 설계 (브레인스토밍 완료)
- 원본: SUH-DEVOPS-TEMPLATE (Cassiiopeia/projectops) v4.0.4

## 1. 목적

오픈소스 공모전 제출용 **신규 레포**를 만든다. 기존 projectops의 기능이 너무 많아 심사에 보여줄 핵심만 담는다. fork가 아니라 **새 레포 신규 생성** — 검증된 코드 로직은 선별 복사하되 git 히스토리는 새로 시작한다.

**핵심 메시지**: `npx projectops` 한 줄로 모든 프로젝트(9타입 + 멀티타입 + 모노레포)를 초기화하고, **GitHub-native AI Release Automation**(별도 API 키 0개, 비용 0원)으로 버전·체인지로그·릴리스를 자동화한다.

## 2. 스코프

### 포함 (3축)

1. **npx 마법사 (CLI)** — 멀티프로젝트 초기화 마법사. 주력 데모.
2. **GitHub Actions 워크플로우** — 버전관리·체인지로그·타입별 CI/CD (payload로 사용자 프로젝트에 설치됨).
3. **버전/체인지로그 자동화 백엔드** — `version_manager.py` + `changelog_manager.py`. **스크립트는 전부 Python** (sh 금지 — Windows 로컬 테스트 가능, ubuntu 러너 python3 기본 탑재, bash 3.2/BSD 크로스플랫폼 함정 소멸. 속도는 요구사항 아님).

### 제외 (가져오지 않음)

- Agent Skills 25종 전부 (`skills/`, `scripts/`(플러그인), `.claude-plugin/`, `.codex-plugin/`, `.agents/`, `.cursor/`, `harness/`)
- 내부 문서(`docs/`), 부가 워크플로우 (issue-helper, QA-bot, `PROJECTS-SYNC-MANAGER`, `SYNC-ISSUE-LABELS`, util-version-sync 등)
- **커스텀 라벨 체계 전부**: `.github/config/issue-labels.yml`(한글 상태 라벨), 라벨 동기화 워크플로우, 라벨→Projects Status 동기화. 새 레포는 **GitHub 기본 라벨**(bug, enhancement, documentation, good first issue, help wanted 등)만 사용 — 상태 추적은 Projects Status 필드/open·closed가 정석. 마법사도 라벨을 건드리지 않는다.
- shell 스크립트 전부 (`version_manager.sh` 포함) — Python으로 재작성해 대체 (§2 포함 3번 참조)
- **템플릿 레포 정체성 전부**: "Use this template" 경로, `PROJECT-TEMPLATE-INITIALIZER.yaml`, `template_initializer.sh`, `template_integrator.sh` / `.ps1`. **배포 경로는 npx CLI 유일.**

## 3. 레포 구조

```
projectops/ (신규)
├── bin/ + src/                  # npx 마법사 (현 npx CLI 코드 선별 복사)
├── payload/                     # 마법사가 사용자 프로젝트에 심는 자산 (npm 패키지에 동봉)
│   ├── workflows/
│   │   ├── common/              # VERSION-CONTROL, AUTO-CHANGELOG(AI+fallback),
│   │   │   │                    #   RELEASE-PUBLISH(tag+Release), README-VERSION-UPDATE
│   │   │   └── secret-backup/   # opt-in (--secret-backup)
│   │   ├── spring/
│   │   │   ├── server-deploy/   # 기본 포함, Nexus opt-in true면 폴더째 제외
│   │   │   └── nexus/           # opt-in (--nexus)
│   │   └── {flutter,react,next,node,python,react-native,react-native-expo,basic}/
│   ├── scripts/                 # version_manager.py, changelog_manager.py (전부 Python)
│   └── version.yml.template
├── .github/workflows/           # 이 레포 자체용: npm publish + 자체 버전관리(도그푸딩)
├── version.yml / CHANGELOG.md / CHANGELOG.json
└── README.md                    # 공모전 심사용 신규 작성
```

**payload 단일 진실 원칙**: 기존 레포의 "템플릿 레포 + 마법사 배포원" 2중 정체성(파일 삭제 목록 + 복사 제외 목록을 3곳 동기화)이 사라진다. 마법사는 `payload/`만 복사하므로 정체성 충돌 문제 자체가 소멸.

## 4. npx 마법사 명세

### 진입

`npx projectops` 한 줄. 대화형 마법사 실행. 엔진은 기존 검증된 `node:readline` 자체 엔진 유지 (clack 1.7.0 Windows TTY Enter 버그로 실측 배제됨).

### 기능 (현행 유지)

- **감지**: 마커 파일(`build.gradle`/`pubspec.yaml`/`package.json`/`pyproject.toml` 등)로 타입 자동 감지. 9타입 + 멀티타입(csv) + 모노레포 경로(`project_paths` 맵, 서브폴더 마커 감지).
- **대화형 계층**: 배너·현재 상태 카드 → 타입/버전/브랜치 확인·수정 → 충돌 3지선 → opt-in 질문들 → 완료 요약.
- **비대화형**: `--force --type ... --paths ...` + 신규 `--main-branch <name>` / `--develop-branch <name>` / `--coderabbit` 플래그. CI 사용 가능. 플래그 생략 시 기본값: main-branch = 감지된 default branch, develop-branch = `develop`, coderabbit = false.
- **모드**: 신규 통합 / 업데이트 / 되돌리기 3모드.
- **산출**: `.github/workflows` 타입별 배치 + `version.yml` 생성 + 충돌 처리.

### 신규 질문 ① — 브랜치 설정

`on: push: branches:` 트리거는 YAML 정적 값이라 런타임 변경 불가 → 마법사가 물어서 치환해야 한다.

- **릴리스 브랜치**: 기본값 = 감지된 default branch (main/master).
- **개발 브랜치**: 기본값 `develop`. `git branch -r` 목록에서 선택 또는 직접 입력.
- **브랜치 자동 생성**: 입력한 개발 브랜치가 원격에 없으면 현 HEAD 기준으로 생성 + push. 대화형은 push 전 확인 질문, `--force` 비대화형은 질문 없이 자동 생성+push.
- payload 워크플로우에는 `{{DEVELOP_BRANCH}}` / `{{MAIN_BRANCH}}` 플레이스홀더 → 복사 시 치환.
- 선택값은 `version.yml`의 `metadata.template.branches`에 저장 → 업데이트 모드에서 재질문 없이 동일 치환 재적용.
- **브랜치 모드 저장**: 마법사가 `version.yml`의 `metadata.template.branches.mode`에 `pr-flow` 또는 `trunk-based` 기록. 워크플로우 설치 구성이 모드별로 갈린다:
  - **pr-flow** (기본): `VERSION-CONTROL`(main 직접 push 안전망) + `AUTO-CHANGELOG-CONTROL`(릴리스 PR) + `RELEASE-PUBLISH`(main push, 릴리스 머지 커밋 감지 시만 동작) 3종 설치.
  - **trunk-based**: **`RELEASE-PUBLISH` 단독 설치** (`VERSION-CONTROL`·`AUTO-CHANGELOG` 설치 제외 — 역할 흡수). main push마다 RELEASE-PUBLISH 하나가 순서대로 처리: patch 증가 → CHANGELOG 갱신(엔진 체인, PR 컨텍스트 없으므로 1순위 CodeRabbit 자동 스킵) → `[skip ci]` 커밋 → **그 커밋에** tag → GitHub Release. 단일 워크플로우라 순서·경합 문제 없음, tag는 항상 bump 후 커밋을 가리킴.
  - **루프 가드**: 봇 커밋은 전부 `[skip ci]` — bump/CHANGELOG 커밋이 워크플로우를 재트리거하지 않는다 (원본 레포 방식 유지).
  - 마법사는 완료 요약에서 선택된 모드와 설치된 워크플로우 구성을 안내.

### 신규 질문 ② — CodeRabbit opt-in

- 질문: "CodeRabbit을 사용합니까? (PR AI 리뷰·요약)" — **기본 false**.
- true면 changelog 워크플로우가 CodeRabbit PR summary를 1순위 소스로 사용.
- `version.yml`의 `metadata.template.options.coderabbit`에 저장 (기존 nexus/secret_backup 패턴).

### 기존 opt-in 유지

- Nexus (`--nexus`): spring 라이브러리 publish. true면 `server-deploy/` 폴더 자동 제외.
- Secret 백업 (`--secret-backup`).

## 5. 릴리스 자동화 명세 (GitHub-native AI Release Automation)

### 흐름 (develop→main 릴리스 PR)

1. PR 열림 → `AUTO-CHANGELOG-CONTROL` 워크플로우 기동
2. 버전 확정 (patch 증가, `version_manager.py`)
3. 직전 릴리스 태그 이후 커밋 목록 + PR 제목/diff 수집 → **요약 생성** (아래 엔진 체인)
4. `changelog_manager.py`가 CHANGELOG.json/md 갱신 → PR에 커밋 → automerge
5. main 머지 후: **별도 워크플로우 `PROJECT-COMMON-RELEASE-PUBLISH`** (main push 트리거. pr-flow 모드: 릴리스 머지 커밋 감지 시만 동작 / trunk-based 모드: `[skip ci]` 아닌 모든 push에서 동작 — §4 브랜치 모드 참조) — **git tag `v{x.y.z}`** 생성·push → **GitHub Release 생성** (`gh release create --notes-file` + `--generate-notes`, gh CLI로 확정 — GitHub-hosted runner 기본 탑재·GITHUB_TOKEN 자동 인증). Release body = `changelog_manager.py export` 산출 요약 + GitHub 자동 노트(Full Changelog 비교 링크·PR 목록) 조합. trunk-based 레포에서는 이 워크플로우가 요약 생성(엔진 체인)까지 직접 수행.

### 요약 엔진 체인 (우선순위)

| 순위 | 엔진 | 조건 | 비용 |
|---|---|---|---|
| 1 | CodeRabbit PR summary | 마법사 opt-in true **이고 PR 컨텍스트 존재** (trunk-based push 실행 시 자동 스킵) | CodeRabbit 요금제 |
| | └ 대기 정책: PR 코멘트를 30초 간격 폴링, **최대 5분**. 미도착 시 2순위로 전환 (원본 레포의 10분 대기 문제 재현 방지) | | |
| 2 | 사용자 지정 provider | `AI_API_KEY` secret 존재 | 사용자 부담 |
| 3 | **GitHub Models** (기본값) | `GITHUB_TOKEN` + `permissions: models: read` | **무료 사용량 (rate limit)** |
| 4 | 규칙 fallback | 위 전부 실패/부재 | 0원, 항상 동작 |

- 2·3은 동일 코드 경로: **OpenAI-호환 chat completions** 형식. `AI_API_BASE_URL`/`AI_MODEL` env로 엔드포인트 교체 (Groq·Gemini 호환모드·Ollama 등 무료 엔드포인트 지원). GitHub Models 엔드포인트: `https://models.github.ai/inference/chat/completions`.
- 표준 라이브러리 `urllib`만 사용. `changelog_manager.py`에 `ai-summary` 서브커맨드 추가.
- 실패(429/타임아웃/키없음/권한없음) → 경고 로그 + 다음 순위 자동 전환. **릴리스는 절대 안 막힘.**

### 규칙 fallback — 3단 파서 (커밋별 매칭, graceful degradation)

1. **projectops 컨벤션** — `제목 : feat : 내용` 형식 → 유형 그룹핑
2. **Conventional Commits** — `feat:` / `fix(scope):` 등 업계 표준 prefix → 유형 그룹핑
3. **무형식** — 매칭 실패 시 "🔧 변경사항" 섹션에 커밋 제목 bullet 나열

최악의 경우에도 커밋 목록 changelog는 항상 산출. GitHub 자동 release notes와 동급 수준이 하한선.

### 필요 권한

```yaml
permissions:
  contents: write       # tag push, CHANGELOG 커밋, release 생성
  models: read          # GitHub Models 호출
  pull-requests: write  # PR 커밋·automerge
```

### 공모전 포지셔닝 문구

> GitHub Actions 내부에서 별도 외부 API Key 없이 GitHub Models를 기본 AI 엔진으로 사용하고, version bump 시 Git tag·CHANGELOG.md·GitHub Release Notes를 자동 동기화한다. rate limit 또는 호출 실패 시 GitHub 자동 Release Notes 및 규칙 기반 changelog 생성기로 fallback하여 릴리스 자동화가 중단되지 않는다.

### version_manager.py (sh 재작성)

- 기존 `version_manager.sh`와 서브커맨드 등가: `get` / `set` / `increment` / `sync` / `get-code` / `increment-code`
- 타입별 버전 파일 동기화 로직(`build.gradle`·`pubspec.yaml`·`package.json`·`pyproject.toml`·`Info.plist`·`app.json`) + `project_paths` 모노레포 경로 지원 그대로 이식
- 표준 라이브러리만 사용 (기존 changelog_manager.py 표준 준수). Windows·mac·ubuntu 러너 동일 동작

## 6. README + 심사위원 어필 전략 (수상 목표)

**목표: 심사위원이 "개발 좀 치는 사람들이네" 느끼게.** 기능 나열이 아니라 엔지니어링 판단력을 보여주는 구성.

### README 구성

- **히어로**: `npx projectops` 한 줄 + 30초 데모 GIF + 배지(npm·버전·라이선스·CI status)
- **문제 정의 훅**: "새 프로젝트마다 CI/CD·버전관리·체인지로그 셋업에 반나절" → "npx 한 줄, 3분"
- 3축 구조: ① 마법사(9타입+멀티+모노레포) ② GitHub-native AI Release Automation ③ 타입별 CI/CD
- 아키텍처 mermaid + 엔진 체인 다이어그램

### 심사위원 어필 포인트 (README·발표 공통 강조)

| 포인트 | 왜 "치는 사람들"로 보이나 |
|---|---|
| **API 키 0개 AI** | GitHub Models + `GITHUB_TOKEN`으로 AI changelog — "AI 붙였어요"가 아니라 플랫폼 네이티브 통합의 이해도 증명 |
| **4단 엔진 체인 + graceful degradation** | "AI 실패해도 릴리스는 절대 안 막힘" — 장애 설계 사고방식. 데모에서 일부러 실패시켜 fallback 시연 |
| **9타입+멀티타입+모노레포 자동 감지** | 마커 파일 기반 감지 → 질문 최소화. 제품 감각 |
| **크로스플랫폼 무결점** | Node CLI + Python 스크립트만 — bash/PowerShell 이중 유지·bash 3.2 함정을 설계로 제거했다는 스토리 |
| **payload 단일 진실** | 배포물 관리 아키텍처 자체가 설계 결정의 근거 문서화 |
| **표준 존중** | GitHub 기본 라벨·Projects·Releases·Conventional Commits — 커스텀 발명 대신 생태계 표준 위에 구축 |

### 3분 데모 영상 (YouTube 업로드)

| 구간 | 내용 |
|---|---|
| 0:00–0:20 | 훅: 빈 레포 + "CI/CD 셋업 몇 시간 걸리세요?" 한 문장 |
| 0:20–1:10 | **`npx projectops` 라이브 실행** — 멀티타입 모노레포(예: spring+flutter) 자동 감지 → 브랜치 질문 → 완료 요약. 마법사 UI가 주인공 |
| 1:10–2:20 | **릴리스 자동화** — 커밋 몇 개 → develop→main PR → AI changelog 생성 장면 → automerge → tag + GitHub Release 페이지 (AI 요약 노트) 화면 전환 |
| 2:20–2:45 | **fallback 시연** — `models: read` 제거하고 재실행 → 규칙 기반 changelog로도 릴리스 완주. "절대 안 막힌다" 증명 |
| 2:45–3:00 | 아키텍처 슬라이드 1장 + npx 명령어 클로징 |

- 편집 원칙: 대기 시간 전부 점프컷, 터미널 폰트 크게, 자막으로 단계 표시. Actions 실행 대기는 미리 돌린 화면 재사용.

## 7. 검증 전략

- **마법사**: 타입별 fixture 폴더(9종 + 멀티 + 모노레포)에 `--force` 비대화형 실행 → 산출 파일(워크플로우 배치·version.yml·브랜치 치환) 검증. Windows + mac 양쪽 (Node 단일 경로라 sh/ps1 크로스플랫폼 함정 소멸).
- **릴리스 체인**: 테스트 레포에서 develop→main PR 실제 1회 실행 → tag·GitHub Release·CHANGELOG 3종 생성 실측.
- **fallback**: `models: read` 권한 제거 상태로 실행 → 규칙 파서 경로 동작 확인.
- **브랜치 생성**: 개발 브랜치 미존재 fixture에서 생성+push 동작 확인.
- **version_manager.py 등가성**: 기존 sh 버전과 동일 입력→동일 출력 대조 테스트 (get/set/increment/sync, 타입별 동기화 파일). Windows 로컬에서 직접 실행 검증 가능.

## 8. 미결정 사항

- 신규 레포 이름 / npm 패키지명 (기존 `projectops` npm 패키지와의 관계 — 대회용 별도 패키지명 필요 여부)
- GitHub Models 기본 모델 선택 (예: `openai/gpt-4o-mini`)
- 라이선스 (공모전 요건 확인 필요)
