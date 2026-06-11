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
| `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD` | Synology Docker 배포 (기본, 단일 컨테이너) | synology/ |
| `PROJECT-SPRING-SYNOLOGY-NONSTOP-TRAEFIK-CICD` | 무중단 배포 (Traefik Blue-Green, opt-in) | synology/ |
| `PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD` | 무중단 배포 (Nginx Blue-Green, opt-in) | synology/ |
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
| `suh-changelog-deploy` | main push → deploy PR → automerge / automerge 실패 시 재트리거 |
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
    ├── common-rules.md       # 절대 규칙, 커밋 컨벤션
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
5. **skill 시작 시 필독**: `references/common-rules.md` → (config 필요 시) `references/config-rules.md` → (기술별) `tech-*.md`
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

**문제**: 스킬이 `git remote get-url origin`으로 현재 디렉토리의 repo를 감지하는데, Claude Code가 **SUH-DEVOPS-TEMPLATE** 레포 컨텍스트에서 실행 중이면 `TEAM-ROMROM/RomRom-BE`가 아닌 `Cassiiopeia/SUH-DEVOPS-TEMPLATE`를 origin으로 잡음.

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
