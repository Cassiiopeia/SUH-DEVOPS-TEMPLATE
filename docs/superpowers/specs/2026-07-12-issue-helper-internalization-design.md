# SUH-ISSUE-HELPER 내재화 설계 (외부 의존성 제거)

- 날짜: 2026-07-12
- 상태: 설계 승인됨
- 관련 파일: `.github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER-*.y*ml`, 외부 액션 `Cassiiopeia/github-issue-helper@deploy` (로컬 레포: `~/Desktop/Programming/project/SUH-ISSUE-HELPER`)

## 배경 / 목표

이슈 생성 시 브랜치명·커밋 메시지를 댓글로 제안하는 기능이 현재 **외부 GitHub 액션 레포에 의존**한다
(`uses: Cassiiopeia/github-issue-helper@deploy`, Node20 + dist 빌드 배포 필요).
이를 **템플릿 내부 Python 스크립트(stdlib 전용)로 내재화**해 공급망 의존성을 제거하고,
동시에 커스터마이징·사용성을 개선한다.

- 외부 액션의 실 로직은 작다: 핵심은 `normalize.ts` 93줄 (제목 정규화 → 브랜치명 → 커밋 템플릿 치환 → 댓글 upsert)
- 이 템플릿의 기존 표준(`version_manager.py` — pip/yq/jq 무의존)과 동일한 방식으로 포팅 가능

## 결정 사항 요약

| 항목 | 결정 |
|---|---|
| API 버전 워크플로우 | 삭제 (이미 deprecated·비활성) + migrations registry 등록 |
| MODULE 버전 워크플로우 | `PROJECT-COMMON-SUH-ISSUE-HELPER.yaml`로 **리네임** + 내용을 내부 py 실행으로 교체 |
| 로직 위치 | `.github/scripts/issue_helper.py` (stdlib 전용, 사용자 프로젝트로 복사됨) |
| 설정 위치 | `version.yml` `metadata.template.options.issue_helper` (SSOT) — 무설정 시 전부 기본값 |
| 브랜치 포맷 | **코어 `YYYYMMDD_#번호_제목` 고정**, prefix·최대길이만 설정 가능 |
| 개선 범위 | 제목 태그 기반 커밋 타입 추론 + 템플릿 변수 확장 + KST 타임존 + 동적 가이드 |
| 가이드 표면화 | 3층: 이슈 댓글(접이식) + 의존 워크플로우 YAML 헤더 주석 + 중앙 문서 |

## 불변 계약 (절대 깨면 안 되는 것)

기존 소비자들이 브랜치명·댓글 형식을 기계 파싱한다. 실측으로 확인된 소비자:

### 브랜치명 `YYYYMMDD_#번호_제목` 소비자

| 소비자 | 추출 방식 |
|---|---|
| `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml:223` | `sed 's/.*#\([0-9]*\).*/\1/p'` — `#숫자` 필수 |
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` | 동일 패턴 |
| `PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml:167` | `branchName.match(/#(\d+)/)` |
| `scripts/common/issue_number.py:9-10` (pro-commit/report/review 스킬) | worktree 폴더 `\d{8}_(\d+)_` + 브랜치 숫자 패턴 |
| `scripts/common/gh_branch.py:57` (pro-github create-branch-name) | **같은 포맷을 생성** — 결과 일치 필수 |

### 댓글 형식 소비자 (댓글 = 기계가 읽는 API)

`PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml:206-220`:
1. 이슈 댓글 중 `Guide by SUH-LAB` 문자열 포함 댓글 탐색
2. `/### 브랜치\s*```\s*([\s\S]*?)\s*```/` 정규식으로 빌드 대상 브랜치 추출

**⚠️ 이미 통합된 사용자 레포에는 구버전 BUILD-TRIGGER가 계속 돌고 있으므로,
새 헬퍼의 댓글은 구버전 파서로도 파싱돼야 한다 (하위호환 필수).**

따라서 새 구현의 불변 계약:
- 브랜치: `{prefix}YYYYMMDD_#{이슈번호}_{정규화제목}` — 코어 순서·`#` 고정
- 댓글: `Guide by SUH-LAB` 문구 + `### 브랜치` 제목 + 코드블록 구조 유지
- 이 계약은 `issue_helper.py` 파일 헤더 주석에 소비자 목록과 함께 명시한다

## 구현 설계

### 1. 삭제 — `PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml`

- `project-types/common/`에서 삭제 (루트 `.github/workflows/`에는 원래 없음 — 확인됨)
- `src/core/migrations/registry.js`에 등록: tier `safe` (dispatch 전용 비활성 파일 — 자동 `.bak` 무해화)
- 기존 registry 항목의 `replacedBy: "PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml"`(registry.js:39) →
  새 파일명 `PROJECT-COMMON-SUH-ISSUE-HELPER.yaml`로 갱신
- registry.js:36의 `replacedBy: "PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml"`도 동일 갱신

### 2. 신규 — `.github/scripts/issue_helper.py`

stdlib 전용 (`urllib`·`re`·`json`·`datetime`·`pathlib`). 입력은 환경변수 + `GITHUB_EVENT_PATH` 페이로드.

동작 순서:
1. 이벤트 검증: `opened` 또는 `edited`+title 변경만 처리 (기존 동일)
2. `version.yml`에서 `metadata.template.options.issue_helper` 로드 (없으면 기본값 — 기존 통합 레포 무설정 동작 보존)
3. 제목 정규화: `[태그]` 제거 → 이모지/제어문자 제거 → 한글/영문/숫자 외 `_` 치환 → 연속 `_` 축약
   (기존 normalize.ts와 **결과 동일** — 패리티 테스트로 보증, `scripts/common/title.py`와 규칙 일치)
4. 브랜치명 생성: `{branch_prefix}{YYYYMMDD}_#{번호}_{제목}` + max_branch_length 절단
   — 날짜는 설정 타임존(기본 `Asia/Seoul`) 기준 (**개선**: 기존 액션은 UTC 러너 시각이라 한국 새벽 9시간 오차 존재)
5. 커밋 타입 추론 (**개선**): 원본 제목의 태그 → 타입 매핑, 설정으로 오버라이드 가능

   | 제목 태그 | 기본 타입 |
   |---|---|
   | `[버그]` | fix |
   | `[기능요청]` `[기능추가]` `[기능개선]` | feat |
   | `[문서]` | docs |
   | `[디자인]` | design |
   | `[시험요청]` | test |
   | 그 외/태그 없음 | feat |

6. 커밋 메시지 렌더링: 기존 변수 5종(`${issueTitle}` `${issueUrl}` `${issueNumber}` `${branchName}` `${date}`)
   + 신규 3종(`${commitType}` `${labels}` `${assignees}`) (**개선**)
7. 동적 가이드 생성 (아래 §6)
8. 댓글 upsert: 마커 포함 기존 댓글 갱신, 없으면 생성.
   **하위호환**: 구 액션이 남긴 구 마커(`github-issue-helper` URL 포함) 댓글도 매칭해 갱신 (중복 댓글 방지)

### 3. 워크플로우 — `PROJECT-COMMON-SUH-ISSUE-HELPER.yaml` (리네임 + 교체)

```yaml
on:
  issues:
    types: [opened, edited]
permissions:
  issues: write
  contents: read
jobs:
  generate-comment:
    if: github.event.action == 'opened' || (github.event.action == 'edited' && github.event.changes.title)
    steps:
      - uses: actions/checkout@v5
      - run: python3 .github/scripts/issue_helper.py
        env:
          GITHUB_TOKEN: ${{ secrets._GITHUB_PAT_TOKEN || secrets.GITHUB_TOKEN }}
```

- `project-types/common/` + 루트 `.github/workflows/` **두 곳 동일 유지** (CLAUDE.md 규칙)
- 구 `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml` → registry tier `safe`
  (공존 시 댓글 이중 생성 = safe 티어의 전형적 실해 케이스)
- 헤더 주석에 "이 댓글을 소비하는 기능 목록"(BUILD-TRIGGER 등) 명시

### 4. 설정 스키마 — `version.yml` (마법사 setting 메뉴 확장 대비)

```yaml
metadata:
  template:
    options:
      issue_helper:
        branch_prefix: ""                # 브랜치 접두사 (예: "feat/")
        max_branch_length: 100           # 코어부 최대 길이 (prefix 제외)
        timezone: "Asia/Seoul"           # 브랜치 날짜 기준 타임존
        commit_template: "${issueTitle} : ${commitType} : {변경 사항에 대한 설명} ${issueUrl}"
        commit_type_map:                 # 제목 태그 → 커밋 타입 오버라이드 (기본 매핑에 병합)
          "버그": "fix"
        comment_marker: "<!-- SUH-ISSUE-HELPER -->"   # upsert 마커
        show_guide: true                 # 접이식 가이드 표시 여부
```

**확장성 원칙 (사용자 요구 — agent 필독):**
- 이 섹션은 향후 **마법사 "설정 중앙관리(setting)" 메뉴**가 읽고 쓸 대상이다.
  키는 플랫 스칼라(+얕은 맵 1개)로 유지해 메뉴 UI가 기계적으로 나열·편집할 수 있게 한다.
- 스크립트는 "설정 없음 = 기본값" 원칙을 지켜, 마법사가 섹션을 통째로 지워도 동작한다.
- 프로젝트 타입 변경 시 별도 마이그레이션 불필요 — 타입 종속 동작(가이드 문구)은
  설정이 아니라 **파일 실존 기반**(§6)이므로 자동 추종한다.

### 4.5. 자동 마이그레이션 — 구 설정 이관 (settings carryover)

기존 통합 레포의 구 `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml`에는 사용자가 커스터마이징한
`with:` 입력(branch_prefix, max_branch_length, commit_template, comment_marker)이 있을 수 있다.
`.bak` 무해화만 하면 이 설정이 유실되므로, **무해화 직전에 version.yml로 자동 이관**한다.

엔진 확장 (registry의 선언적 구조 유지):
- registry 항목에 선택 필드 `settingsExtractor: "<이름>"` 추가 (문자열 참조 — 데이터 순수성 유지)
- 신규 `rules/settings-extractors.js`에 이름별 추출기 등록.
  `obsolete-workflows.js`의 `apply()`가 `entry.settingsExtractor` 존재 시 `.bak` 리네임 **전에** 실행

`suh-issue-helper-module` 추출기 동작:
1. 구 YAML의 `with:` 블록에서 4개 키 파싱 (단순 라인 정규식 — yaml 파서 불필요)
2. **배포본 기본값과 다른 값만** 이관 대상으로 선별 (기본값 그대로면 이관 불필요)
3. version.yml `metadata.template.options.issue_helper`에 기록하되,
   **이미 존재하는 키는 덮어쓰지 않는다** (신형 설정 우선 — 멱등, 재실행 안전)
4. version.yml이 없는 레포면 조용히 건너뜀 (기본값으로 동작하므로 무손실)
5. 추출기 실패는 마이그레이션 전체를 막지 않음 (경고 후 .bak 진행 — 부분 실패 허용 원칙)

구 커스텀 commit_template은 그대로 이관해도 유효하다 (기존 변수 5종은 신형에서 전부 지원).

**⚠️ 동시 작업 주의**: develop 브랜치에서 다른 에이전트가 마이그레이션 작업을 병행 중 —
구현 시 registry.js 수정은 추가(additive)로만 하고, 커밋 전 `git pull --rebase origin develop` 필수.

### 5. 배선 + 테스트

- `src/core/copy/simple.js`: `issue_helper.py` 복사 목록 추가
  (사용자 프로젝트에 같이 가야 하는 공통 자산 — `exclusions.js`·`template_initializer.py`에는 **넣지 않는다**)
- `.github/scripts/test/test_issue_helper.py`:
  - 정규화 패리티 (기존 TS 케이스 이식: 태그 제거, 이모지, 연속 언더바, 길이 절단)
  - 커밋 타입 추론 (기본 매핑 + 오버라이드 병합)
  - 템플릿 렌더링 (신규 변수 포함)
  - **댓글 계약 테스트**: 생성된 댓글 본문이 BUILD-TRIGGER의 실제 정규식
    `### 브랜치\s*```\s*([\s\S]*?)\s*```` 및 `Guide by SUH-LAB` 탐색으로 파싱되는지 검증
  - 이벤트 필터링 (opened / edited+title / 그 외 무시)
- `test/migrations.test.js`: 충돌가드 통과 + **설정 이관 테스트** (커스텀 with → version.yml 기록,
  기본값 미이관, 기존 키 보존, version.yml 부재 시 skip, 멱등성)
- 검증: `python -m pytest .github/scripts/test/test_issue_helper.py` + `python -m py_compile`

### 6. 브랜치 규칙 가이드 표면화 (3층)

**① 이슈 댓글 — 동적 접이식 안내 (사용 시점, 가장 중요)**

댓글 하단에 `<details>` 접이식으로 "왜 이 브랜치명을 써야 하나요?" 안내를 붙인다.
문구는 **레포에 실제 존재하는 워크플로우 파일 기반으로 동적 생성**한다 (타입 매핑 아님):

```python
# 안내 라인 테이블: (존재해야 하는 워크플로우 파일, 안내 문구)
GUIDE_LINES = [
    ("PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml", "`@projectops app build` 댓글 빌드 — 이 댓글의 브랜치를 자동 인식"),
    ("PROJECT-FLUTTER-ANDROID-TEST-APK.yaml", "테스트 APK 빌드 — `#이슈번호`로 이슈 정보를 빌드 노트에 자동 포함"),
    ("PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml", "테스트 TestFlight 빌드 — 동일"),
]
active = [line for f, line in GUIDE_LINES if (workflows_dir / f).exists()]
```

- 스킬 연동(커밋/보고서/리뷰/worktree 이슈번호 자동 추출) 안내는 레포 구성 무관이므로 고정 문구
- 의존 기능이 하나도 없으면 접이식 생략, "일관된 브랜치 관리를 위한 권장 형식" 한 줄만
- **파일 실존 기반이므로 마법사 setting에서 프로젝트 타입을 바꿔 워크플로우가 추가/제거되면
  다음 이슈부터 자동으로 문구가 추종된다** — 거짓 안내(없는 기능 홍보) 원천 차단
- `<details>`는 파서 계약(`### 브랜치` 블록) 뒤에 붙으므로 구버전 파서와 무충돌
- **확장 규칙 (agent 필독)**: 새 워크플로우가 브랜치 규칙에 의존하게 되면 `GUIDE_LINES`에 한 줄 추가한다

**② 의존 워크플로우 YAML 헤더 — 표준 의존성 블록 (주석만, 실행 로직 무손상)**

TEST-APK · IOS-TEST-TESTFLIGHT · BUILD-TRIGGER 3종 헤더에 통일 블록 추가:

```yaml
# ⚠️ 브랜치 규칙 의존:
# 이 워크플로우는 브랜치명 `YYYYMMDD_#이슈번호_제목` 형식에서 이슈 번호를 추출합니다.
# 이슈 생성 시 SUH-ISSUE-HELPER 댓글이 제안하는 브랜치명을 그대로 사용하세요.
# 형식이 다르면: 이슈 연동 빌드 정보가 누락됩니다 (빌드 자체는 진행).
```

수정 후 `git diff`로 주석 외 실행 로직 무손상 자가검증 (CLAUDE.md YAML 검증 규칙).

**③ 중앙 문서 — `docs/BRANCH-CONVENTION.md`**

포맷 정의·소비자 전체 목록·깨질 때 증상을 한 곳에 정리. ①②가 이 문서의 GitHub URL을 링크.
`docs/`는 사용자 프로젝트로 복사되지 않으므로 유지보수자용 — 최종 사용자 안내는 ①②가 담당.

### 7. 문서 갱신

- `CLAUDE.md`: 공통 워크플로우 표의 `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE` → 새 이름,
  §6의 GUIDE_LINES 확장 규칙 추가
- `docs/ISSUE-AUTOMATION.md`: 외부 액션 설명 → 내부 py 설명으로 교체 (해당 내용 존재 시)

## 변경 파일 목록 (예상)

| 작업 | 파일 |
|---|---|
| 삭제 | `.github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml` |
| 삭제(리네임) | `.github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml`, 루트 동일 파일 |
| 신규 | `.github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml` + 루트 복사본 |
| 신규 | `.github/scripts/issue_helper.py`, `.github/scripts/test/test_issue_helper.py` |
| 신규 | `docs/BRANCH-CONVENTION.md` |
| 수정 | `src/core/migrations/registry.js` (신규 2건 + replacedBy 2건 갱신 + settingsExtractor 필드) |
| 신규 | `src/core/migrations/rules/settings-extractors.js` (구 with → version.yml 이관) |
| 수정 | `src/core/migrations/rules/obsolete-workflows.js` (apply 전 추출기 실행) |
| 수정 | `src/core/copy/simple.js` (py 복사 추가) |
| 수정 | Flutter 워크플로우 3종 헤더 주석 (양쪽 위치) |
| 수정 | `CLAUDE.md`, `docs/ISSUE-AUTOMATION.md` |

## 하지 않는 것 (YAGNI)

- 브랜치 포맷 완전 템플릿화 (코어 고정으로 결정 — 소비자 파손 위험 대비 실익 없음)
- 마법사 신규 질문 추가 (기본값으로 충분 — 향후 setting 메뉴가 이 섹션을 편입)
- 외부 액션 레포(`SUH-ISSUE-HELPER`) 아카이브 처리 (별도 작업 — 이 레포 범위 밖)
- BUILD-TRIGGER 파서 개선 (댓글 하위호환으로 해결 — 파서는 무수정)
