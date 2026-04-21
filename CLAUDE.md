# SUH-DEVOPS-TEMPLATE

완전 자동화된 GitHub 프로젝트 관리 템플릿

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

---

## 폴더 구조

```
suh-github-template/
├── .github/
│   ├── workflows/
│   │   ├── PROJECT-TEMPLATE-INITIALIZER.yaml
│   │   ├── PROJECT-COMMON-*.yaml
│   │   └── project-types/
│   │       ├── common/          # 공통 원본 (+ synology/)
│   │       ├── flutter/         # Flutter 전용 (+ synology/)
│   │       ├── spring/          # Spring 전용 (+ synology/)
│   │       ├── react/
│   │       └── next/
│   ├── scripts/
│   │   ├── version_manager.sh
│   │   ├── changelog_manager.py
│   │   └── template_initializer.sh
│   ├── util/flutter/
│   │   ├── playstore-wizard/
│   │   └── testflight-wizard/
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
| `PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC` | version.yml 변경 | 플러그인 매니페스트 버전 동기화 |
| `PROJECT-COMMON-VERSION-CONTROL` | main 푸시 | patch 버전 자동 증가 |
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` | deploy PR | AI 체인지로그 생성 |
| `PROJECT-COMMON-README-VERSION-UPDATE` | deploy 푸시 | README 버전 동기화 |
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
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD` | Synology APK 배포 | synology/ |

#### Spring
| 파일명 | 용도 | 위치 |
|--------|------|------|
| `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD` | Synology Docker 배포 | synology/ |
| `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW` | PR 프리뷰 배포 | synology/ |
| `PROJECT-SPRING-NEXUS-CI` | Nexus CI | synology/ |
| `PROJECT-SPRING-NEXUS-PUBLISH` | Nexus 라이브러리 배포 | synology/ |

> `synology/` 워크플로우는 `--synology` 옵션으로만 포함됩니다.

#### 공통 Synology
| 파일명 | 기능 | 위치 |
|--------|------|------|
| `PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD` | GitHub Secret → Synology 업로드 | common/synology/ |

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
`--synology` / `--no-synology` 옵션으로 Synology 워크플로우 포함 여부 선택.
선택 값은 `version.yml`의 `metadata.template.options.synology`에 저장.

**초기화/통합 시 복사되지 않는 템플릿 전용 파일**:
```
CLAUDE.md, CONTRIBUTING.md, LICENSE
CHANGELOG.md, CHANGELOG.json
template_integrator.sh / .ps1
docs/, .github/scripts/test/, .github/workflows/test/
.claude-plugin/, skills/, scripts/
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
| `main` | push | VERSION-CONTROL |
| `deploy` | PR | CHANGELOG-CONTROL |
| `deploy` | push | README-UPDATE, CICD |

---

## 이슈/PR 템플릿

**이슈 템플릿**: `bug_report.md` / `feature_request.md` / `design_request.md` / `qa_request.md`

**이슈 라벨**: `긴급, 문서, 작업전, 작업중, 담당자확인, 피드백, 작업완료, 보류, 취소`

---

## Skills (Claude Code 플러그인)

**플러그인명**: `cassiiopeia`

```bash
claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE
claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user
```

| 명령어 | 용도 |
|--------|------|
| `analyze` | 코드 분석 |
| `plan` | 계획 수립 |
| `implement` | 구현 |
| `review` | 코드 리뷰 |
| `refactor` / `refactor-analyze` | 리팩토링 |
| `test` / `testcase` | 테스트 |
| `troubleshoot` | 트러블슈팅 |
| `document` | 문서화 |
| `design` / `design-analyze` | 설계 |
| `build` | 빌드 관리 |
| `figma` | Figma 연동 |
| `ppt` | 프레젠테이션 |
| `suh-spring-test` | Spring 테스트 생성 |
| `init-worktree` | Git worktree 생성 |
| `issue` | 이슈 작성 + GitHub 등록 |
| `commit` | 이슈 기반 커밋 자동화 |
| `github` | GitHub 이슈/PR 조회·관리 |
| `report` | 구현 보고서 생성 |
| `deploy` | main push → deploy PR → automerge |
| `changelogfix` | deploy PR automerge 실패 시 재트리거 |
| `synology-expose` | 시놀로지 서비스 외부 노출 가이드 |

---

## Skills 개발 가이드

### 폴더 구조
```
skills/
├── {skill-name}/SKILL.md
└── references/
    ├── common-rules.md       # 절대 규칙, 커밋 컨벤션
    ├── config-rules.md       # config 경로·스키마·읽기/쓰기 표준
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
5. **skill 시작 시 필독**: `references/common-rules.md` → (config 필요 시) `references/config-rules.md` → (기술별) `tech-*.md`

### config 사용 스킬

| 스킬 | skill_id | 비고 |
|------|---------|------|
| `issue`, `commit`, `github`, `deploy`, `report`, `changelogfix` | `issue` | PAT + repos 공유 |
| `synology-expose` | `synology-expose` | NAS 인스턴스 정보 |

### suh_template CLI 커맨드

```
get-output-path     # 출력 파일 경로 계산
get-issue-number    # 이슈 번호 추출
get-next-seq        # 다음 시퀀스 번호
normalize-title     # 제목 정규화
create-branch-name  # 브랜치명 생성
get-commit-template # 커밋 템플릿 생성
create-issue        # GitHub 이슈 생성 (PAT는 GITHUB_PAT 환경변수로 전달)
add-comment         # 이슈 댓글 추가
get-issue           # 이슈 조회
update-issue        # 이슈 수정
create-pr           # PR 생성
list-prs            # PR 목록 조회
```

> CLI는 Windows 환경에서 인코딩 불안정 이슈 있음. GitHub API 호출은 curl 직접 사용 권장.

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
| 코드 분석, 현황 파악 | `cassiiopeia:analyze` |
| 버그, 오류, 원인 파악 | `cassiiopeia:troubleshoot` |
| 새 기능 설계 | `cassiiopeia:plan` → `cassiiopeia:implement` |
| 코드 리뷰 | `cassiiopeia:review` |
| 이슈 작성 | `cassiiopeia:issue` |
| 커밋 | `cassiiopeia:commit` |
| 배포 | `cassiiopeia:deploy` |
| 보고서 | `cassiiopeia:report` |
| 브레인스토밍 | `superpowers:brainstorming` |
| 구현 계획 | `superpowers:writing-plans` |
| 계획 실행 | `superpowers:executing-plans` |

## 기능 구현 워크플로우

새 기능 구현 시 순서:

1. `superpowers:brainstorming` — 설계 및 스펙 확정
2. `superpowers:writing-plans` — 상세 구현 계획
3. `superpowers:executing-plans` — 실제 구현
4. `superpowers:requesting-code-review` — 코드 리뷰 요청
