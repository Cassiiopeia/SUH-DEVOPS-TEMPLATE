# 브랜치 전략 전면 전환 구현 계획 (deploy 폐기 → develop/main)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 템플릿의 브랜치 전략을 main(개발)/deploy(배포)에서 develop(개발)/main(default=배포) 표준 구조로 전면 전환한다.

**Architecture:** 릴리스 = develop→main PR. AUTO-CHANGELOG-CONTROL이 릴리스 PR 안에서 버전 +1과 CHANGELOG를 머지 전에 확정하고(A-2), 배포·동기화 워크플로우는 deploy push → main push로 단순 교체. VERSION-CONTROL은 main 직접 push 안전망으로 역할 변경(가드).

**Tech Stack:** GitHub Actions YAML, bash, Python(argparse CLI), 마크다운 문서.

**스펙:** `docs/superpowers/specs/2026-07-07-branch-strategy-redesign-design.md`
**이슈:** https://github.com/Cassiiopeia/projectops/issues/425

## Global Constraints

- **커밋 메시지 형식 (모든 태스크 공통)**: `deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : {type} : {설명} https://github.com/Cassiiopeia/projectops/issues/425` — 이모지·태그 prefix 금지, AI 관여 흔적(Co-Authored-By 등) 절대 금지.
- **공통 워크플로우는 두 곳 동일 유지**: `.github/workflows/` 루트 복사본과 `.github/workflows/project-types/common/` 원본에 **동일한 편집**을 적용하고, 태스크 말미에 `diff`로 두 파일이 완전 일치함을 확인한다 (단, 원래부터 다른 파일이었다면 그 차이만 유지).
- **실행 로직 무손상 원칙**: 워크플로우의 `run:` 스크립트·heredoc은 브랜치명 참조와 이 계획에 명시된 블록 외 한 줄도 바꾸지 않는다. 각 태스크에서 `git diff`로 자가검증한다.
- **로컬 YAML 파서는 참고용**: `python -c "import yaml..."` 검증이 실패해도 GitHub 실동작 기준으로 판단한다 (CLAUDE.md 원칙). 단, 자기가 **수정한 라인** 주변의 파스 오류는 반드시 잡는다.
- **git push 금지**: 모든 태스크는 로컬 커밋까지만. push는 Task 11에서 사용자 명시 승인 후에만.
- **작업 브랜치**: 전환 커밋이 push되기 전까지는 기존 규칙대로 `main`에서 작업한다.
- **브랜치명 고정값**: 개발 = `develop`, 프로덕션 = `main`. 다른 이름 금지.
- 현재 버전 3.0.185 (Task 8에서 실행 시점 값으로 재확인).

---

### Task 1: AUTO-CHANGELOG-CONTROL 개편 (핵심 파이프라인)

**Files:**
- Modify: `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`
- Modify: `.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` (동일 편집)

**Interfaces:**
- Produces: update-changelog job output `new_version` (확정 릴리스 버전 문자열, 예 `3.0.186`) — merge-and-deploy의 태그 스텝과 배포 완료 알림이 사용.
- Consumes: `.github/scripts/version_manager.sh increment` (기존 스크립트, 무수정).

두 파일은 현재 동일하므로 루트 파일을 기준으로 편집 후 common에 복사한다. 편집은 아래 순서대로 Edit tool의 old/new 교체로 수행한다.

- [ ] **Step 1: 트리거·헤더 주석 변경**

```yaml
# old (line 30-33)
on:
  pull_request_target:
    types: [opened]
    branches: ["deploy"]
# new
on:
  pull_request_target:
    types: [opened]
    branches: ["main"]
```

헤더 주석(6행, 16행)의 설명도 교체:

```
# old (6행): # 이 워크플로우는 deploy 브랜치로 PR이 생성될 때 CodeRabbit AI의 리뷰를
# new       : # 이 워크플로우는 main 브랜치로 릴리스 PR(develop→main)이 생성될 때 CodeRabbit AI의 리뷰를
# old (16행): # 1. deploy 브랜치로 PR 생성 시 트리거
# new        : # 1. main 브랜치로 릴리스 PR(develop→main) 생성 시 트리거
```

작동 방식 주석에 한 줄 추가 (16행 바로 아래):

```
# 1-1. PR head가 develop이 아니면 전체 파이프라인 스킵 (실수 feature PR 보호)
```

- [ ] **Step 2: detect-and-parse job에 head 가드 추가**

```yaml
# old (line 41-43)
  detect-and-parse:
    name: CodeRabbit Summary 감지 및 파싱
    runs-on: ubuntu-latest
# new
  detect-and-parse:
    name: CodeRabbit Summary 감지 및 파싱
    # head 가드: main이 default라 feature PR의 base가 main으로 잘못 열릴 수 있다.
    # develop발 릴리스 PR만 automerge 파이프라인을 탄다. (후속 job은 needs 조건으로 연쇄 스킵)
    if: github.event.pull_request.head.ref == 'develop'
    runs-on: ubuntu-latest
```

후속 job 연쇄 확인(코드 변경 없음, 검증만): fallback-summary는 `summary_found == 'false'`(스킵 시 빈값이라 불일치), update-changelog는 `summary_found == 'true'` 불일치, merge-and-deploy는 `update-changelog.result == 'success'`(스킵 시 'skipped') 불일치로 모두 자동 스킵된다.

- [ ] **Step 3: 체크아웃 ref 3곳을 PR head(develop)로 교체**

detect-and-parse(90행), fallback-summary(243행), update-changelog(361행)의 동일한 라인 3곳:

```yaml
# old (3곳 모두)
          ref: ${{ github.event.repository.default_branch || 'main' }}
# new (3곳 모두)
          ref: ${{ github.event.pull_request.head.ref }}
```

주의: `replace_all`로 한 번에 교체한다. 이 3곳은 지금까지 "개발측(main)"을 의미했고, 새 구조에서 default_branch는 base(main=프로덕션)를 가리키므로 반드시 head로 바꿔야 한다.

- [ ] **Step 4: fallback-summary의 커밋 수집 기준 교체**

```bash
# old (253-254행)
          # deploy 브랜치 대비 커밋 목록 수집 ([skip ci] 제외)
          git fetch origin deploy 2>/dev/null || true
          COMMITS=$(git log origin/deploy..HEAD --pretty=format:"%s" 2>/dev/null | grep -v "\[skip ci\]" | head -60)
# new
          # main(프로덕션) 대비 커밋 목록 수집 ([skip ci] 제외) — HEAD는 develop 체크아웃
          git fetch origin main 2>/dev/null || true
          COMMITS=$(git log origin/main..HEAD --pretty=format:"%s" 2>/dev/null | grep -v "\[skip ci\]" | head -60)
```

- [ ] **Step 5: update-changelog job — Git 설정의 브랜치 변수 교체**

```bash
# old (365-368행)
          DEFAULT_BRANCH="${{ github.event.repository.default_branch || 'main' }}"
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git pull origin $DEFAULT_BRANCH
# new
          HEAD_BRANCH="${{ github.event.pull_request.head.ref }}"
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git pull origin $HEAD_BRANCH
```

- [ ] **Step 6: update-changelog job — 버전 확정(bump) 스텝 + PR 제목 갱신 스텝 삽입**

"Summary 파일 다운로드" 스텝(370-373행)과 "CHANGELOG 업데이트" 스텝(375행) **사이에** 아래 두 스텝을 삽입:

```yaml
      - name: 릴리스 버전 확정 (patch +1)
        id: bump_version
        run: |
          chmod +x .github/scripts/version_manager.sh
          NEW_VERSION=$(./.github/scripts/version_manager.sh increment | tail -n 1)
          if [ -z "$NEW_VERSION" ]; then
            echo "❌ 버전 증가 실패"
            exit 1
          fi
          echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
          echo "✅ 릴리스 버전 확정: $NEW_VERSION"

      - name: PR 제목 확정 버전으로 갱신
        run: |
          PR_NUMBER=${{ github.event.pull_request.number }}
          VERSION="${{ steps.bump_version.outputs.new_version }}"
          TODAY=$(date '+%Y%m%d')
          NEW_TITLE="🚀 Deploy ${TODAY}-v${VERSION}"

          curl -s -H "Authorization: token ${{ secrets._GITHUB_PAT_TOKEN }}" \
               -H "Content-Type: application/json" \
               -X PATCH \
               -d "{\"title\": \"${NEW_TITLE}\"}" \
               "https://api.github.com/repos/${{ github.repository }}/pulls/${PR_NUMBER}"

          echo "✅ PR 제목 확정 버전으로 갱신: $NEW_TITLE"
```

그리고 update-changelog job 선언에 outputs 추가:

```yaml
# old (347-349행)
  update-changelog:
    name: CHANGELOG 업데이트
    runs-on: ubuntu-latest
# new
  update-changelog:
    name: CHANGELOG 업데이트
    runs-on: ubuntu-latest
    outputs:
      new_version: ${{ steps.bump_version.outputs.new_version }}
```

- [ ] **Step 7: CHANGELOG 업데이트 스텝이 확정 버전을 쓰도록 교체**

```bash
# old (378행)
          VERSION="${{ needs.detect-and-parse.outputs.version }}"
# new
          VERSION="${{ steps.bump_version.outputs.new_version }}"
```

- [ ] **Step 8: 변경사항 커밋 스텝 — 버전 파일 포함 + push 대상 develop**

```bash
# old (410-411행)
          DEFAULT_BRANCH="${{ github.event.repository.default_branch || 'main' }}"
          git add CHANGELOG.json CHANGELOG.md
# new
          HEAD_BRANCH="${{ github.event.pull_request.head.ref }}"
          # bump가 version.yml + 프로젝트 버전 파일도 수정하므로 전체 스테이징
          git add -A
```

```bash
# old (417-419행)
            VERSION="${{ needs.detect-and-parse.outputs.version }}"

            git commit -m "$REPO_NAME 버전 관리 : docs : v$VERSION 릴리즈 문서 업데이트 (PR #${{ github.event.pull_request.number }})"
# new
            VERSION="${{ steps.bump_version.outputs.new_version }}"

            git commit -m "$REPO_NAME 버전 관리 : chore : v$VERSION 릴리즈 버전 확정 및 릴리즈 문서 업데이트 (PR #${{ github.event.pull_request.number }}) [skip ci]"
```

```bash
# old (430행)
              if git push origin HEAD:$DEFAULT_BRANCH; then
# new
              if git push origin HEAD:$HEAD_BRANCH; then
```

```bash
# old (436행)
                if git pull --rebase origin $DEFAULT_BRANCH; then
# new
                if git pull --rebase origin $HEAD_BRANCH; then
```

`[skip ci]`를 붙이는 이유: 이 커밋은 develop에 push되는데, develop CI(FLUTTER-CI 등)가 버전 커밋마다 도는 것을 막는다. 릴리스 머지 커밋(main push)은 [skip ci]가 없으므로 배포는 정상 트리거된다.

- [ ] **Step 9: merge-and-deploy — 릴리스 태그 스텝 추가 + 안내 문구 갱신**

"자동 PR Merge" 스텝 종료 후, "배포 완료 알림" 스텝(698행) **앞에** 삽입:

```yaml
      - name: 릴리스 태그 생성
        run: |
          NEW_VERSION="${{ needs.update-changelog.outputs.new_version }}"
          TAG_NAME="v$NEW_VERSION"
          BASE_BRANCH="${{ github.event.pull_request.base.ref }}"

          git fetch origin $BASE_BRANCH
          git checkout $BASE_BRANCH
          git pull origin $BASE_BRANCH

          if git tag -l | grep -q "^$TAG_NAME$"; then
            echo "⚠️ 태그 $TAG_NAME 이미 존재 — 건너뜀"
          else
            git tag "$TAG_NAME"
            git push origin "$TAG_NAME"
            echo "✅ 릴리스 태그 생성: $TAG_NAME"
          fi
```

배포 완료 알림의 버전 참조 교체:

```bash
# old (703행)
          echo "  • 버전: ${{ needs.detect-and-parse.outputs.version }}"
# new
          echo "  • 버전: ${{ needs.update-changelog.outputs.new_version }}"
```

사용자 안내 문구 2곳의 deploy 표기 교체 (동작 무관, echo/댓글 텍스트):

```bash
# old (581행)
            echo "💡 이미 'PR 브랜치 최신화' 단계에서 변경사항이 deploy 브랜치에 적용되었습니다"
# new
            echo "💡 이미 'PR 브랜치 최신화' 단계에서 변경사항이 main 브랜치에 적용되었습니다"
# old (586행)
            gh pr comment $PR_NUMBER --body "✅ 변경사항이 자동으로 deploy 브랜치에 적용되었습니다. PR을 수동으로 닫아주세요."
# new
            gh pr comment $PR_NUMBER --body "✅ 변경사항이 자동으로 main 브랜치에 적용되었습니다. PR을 수동으로 닫아주세요."
```

주석 3곳(496, 501, 505, 517행 부근)의 "(deploy)"/"(main)" 괄호 표기는 `$PR_BASE`/`$PR_HEAD` 동적 변수 기반이므로 주석만 `(main)`/`(develop)`으로 교체.

- [ ] **Step 10: common 복사본 동기화 및 검증**

```bash
cp .github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml .github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml
diff .github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml .github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml
```

Expected: diff 출력 없음.

실행 로직 무손상 자가검증 — 변경 라인이 전부 의도된 패턴인지 확인:

```bash
git diff -- .github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml | grep "^[+-]" | grep -v "^[+-][+-]" | grep -vE "deploy|develop|main|head\.ref|HEAD_BRANCH|DEFAULT_BRANCH|bump_version|new_version|릴리스|버전|태그|outputs|if: github|chmod|NEW_VERSION|TAG_NAME|BASE_BRANCH|git |echo|curl|PATCH|NEW_TITLE|TODAY|PR_NUMBER|VERSION=|스킵|가드|#|name:|id:|run: \||\"|\{|\}|^\+$|^-$"
```

Expected: 출력 없음(전부 의도된 변경). 출력이 있으면 해당 라인을 원복 검토.

- [ ] **Step 11: 커밋**

```bash
git add .github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml .github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : feat : AUTO-CHANGELOG를 develop→main 릴리스 PR 기준으로 개편(head 가드·릴리스 내 버전 확정·태그) https://github.com/Cassiiopeia/projectops/issues/425"
```

---

### Task 2: VERSION-CONTROL 안전망 가드

**Files:**
- Modify: `.github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml`
- Modify: `.github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml` (동일 편집)

**Interfaces:**
- Produces: step output `steps.release_guard.outputs.is_release_merge` (`true`/`false`) — 같은 파일 내 후속 스텝의 `if:` 조건이 사용.

- [ ] **Step 1: 헤더 주석 갱신**

```
# old (6-7행)
# 이 워크플로우는 다양한 프로젝트 타입에서 main 브랜치에 푸시될 때마다
# patch 버전을 자동으로 증가시키고 모든 관련 파일을 동기화합니다.
# new
# [안전망] main(프로덕션)에 릴리스 PR을 거치지 않은 직접 push가 발생했을 때만
# patch 버전을 자동으로 증가시키고 모든 관련 파일을 동기화합니다.
# 정상 릴리스(develop→main PR)의 버전 증가는 AUTO-CHANGELOG-CONTROL이 머지 전에 수행하며,
# 그 머지 push는 version.yml 변경을 포함하므로 이 워크플로우는 가드에 의해 건너뜁니다.
```

- [ ] **Step 2: 가드 스텝 삽입**

"저장소 체크아웃" 스텝(52-57행)과 "버전 관리 스크립트 권한 설정" 스텝(59행) 사이에 삽입:

```yaml
      - name: 릴리스 머지 여부 확인 (안전망 가드)
        id: release_guard
        run: |
          BEFORE="${{ github.event.before }}"
          # 브랜치 신규 생성(zero SHA)·강제 push 등으로 BEFORE가 없으면 직전 커밋 1개만 검사
          if [ "$BEFORE" = "0000000000000000000000000000000000000000" ] || ! git cat-file -e "$BEFORE" 2>/dev/null; then
            RANGE="HEAD^..HEAD"
          else
            RANGE="$BEFORE..HEAD"
          fi
          if git diff --name-only $RANGE 2>/dev/null | grep -qx "version.yml"; then
            echo "is_release_merge=true" >> $GITHUB_OUTPUT
            echo "✅ 릴리스 머지 감지 (push에 version.yml 변경 포함) — 버전 증가 건너뜀"
          else
            echo "is_release_merge=false" >> $GITHUB_OUTPUT
            echo "⚠️ main 직접 push 감지 — 안전망 버전 증가 실행"
          fi
```

- [ ] **Step 3: 후속 5개 스텝에 가드 조건 부여**

"버전 관리 스크립트 권한 설정", "현재 버전 확인 및 동기화", "새 버전 계산 및 업데이트", "프로젝트 타입 확인", "변경사항 확인 및 커밋", "Git 태그 생성" 각 스텝의 `- name:` 바로 아래(또는 기존 `id:` 아래)에 추가:

```yaml
        if: steps.release_guard.outputs.is_release_merge != 'true'
```

"버전 업데이트 완료 요약" 스텝은 `if: always()` 유지 (무수정).

- [ ] **Step 4: common 복사본 동기화 + 검증 + 커밋**

```bash
cp .github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml .github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml
diff .github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml .github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml
git diff -- .github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml
```

Expected: diff(파일 간) 출력 없음. git diff는 가드 스텝·if 라인·주석 외 변경 없음(트리거 `branches: ["main"]`은 그대로여야 함).

```bash
git add .github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml .github/workflows/project-types/common/PROJECT-COMMON-VERSION-CONTROL.yaml
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : feat : VERSION-CONTROL을 main 직접 push 안전망으로 전환(릴리스 머지 가드) https://github.com/Cassiiopeia/projectops/issues/425"
```

---

### Task 3: 배포·동기화 워크플로우 트리거 교체 (deploy → main)

**Files (Modify):**
- `.github/workflows/PROJECT-COMMON-README-VERSION-UPDATE.yaml` (51행) + `project-types/common/` 동일 파일 (51행)
- `.github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml` (30행)
- `.github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml` (29행)
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` (24행 + workflow_run 25-28행 제거)
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` (54행 + 55-58행 제거)
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-SELFHOSTED-CICD.yaml` (26행 + 27-30행 제거)
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` (60행 + 61-64행 제거)
- `.github/workflows/project-types/next/PROJECT-NEXT-CICD.yaml` (25행)
- `.github/workflows/project-types/react/PROJECT-REACT-CICD.yaml` (24행)
- `.github/workflows/project-types/python/PROJECT-PYTHON-SIMPLE-CICD.yaml` (58행)
- `.github/workflows/project-types/spring/server-deploy/PROJECT-SPRING-SIMPLE-CICD.yaml` (68행)
- `.github/workflows/project-types/spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml` (34행)
- `.github/workflows/project-types/spring/nexus/PROJECT-SPRING-NEXUS-PUBLISH.yml` (14행)
- `.github/workflows/project-types/spring/server-deploy/PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml` (75행 주석), `PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml` (71행 주석)

> 라인 번호는 참고용. Edit는 반드시 아래 anchor 문자열로 수행한다.

- [ ] **Step 1: 단순 트리거 교체 (형식 A — `branches: ["deploy"]`)**

README-VERSION-UPDATE(×2), PLUGIN-VERSION-SYNC, NPM-PUBLISH, PLAYSTORE, FIREBASE, SELFHOSTED, IOS-TESTFLIGHT, PACKAGES-PUBLISH, NEXUS-PUBLISH 각 파일에서:

```yaml
# old
    branches: ["deploy"]
# new
    branches: ["main"]
```

- [ ] **Step 2: 단순 트리거 교체 (형식 B — 리스트 항목)**

NEXT-CICD, REACT-CICD, PYTHON-SIMPLE-CICD, SPRING-SIMPLE-CICD에서 (주석 유지):

```yaml
# old (NEXT/REACT)
      - deploy
# new
      - main
# old (PYTHON)
      - deploy  # 프로덕션 배포
# new
      - main  # 프로덕션 배포
# old (SPRING SIMPLE)
      - deploy  # 배포 환경 (DEPLOY_PORT 사용)
# new
      - main  # 배포 환경 (DEPLOY_PORT 사용)
```

- [ ] **Step 3: Flutter 4종의 죽은 workflow_run 블록 제거**

4개 파일 모두 동일 패턴. 이 블록은 `name: "CHANGELOG 자동 업데이트"`를 참조하지만 실제 AUTO-CHANGELOG의 name은 `AUTO UPDATE PROJECT CHANGELOG`라서 **한 번도 발화한 적 없는 죽은 트리거**로 실측 확인됨. 남겨두면 나중에 name을 "고치는" 순간 push main과 이중 배포되는 함정이 되므로 제거한다:

```yaml
# old (PLAYSTORE 기준 24-28행 — 다른 3개 파일도 동일 구조)
    branches: ["deploy"]
  workflow_run:
    workflows: ["CHANGELOG 자동 업데이트"]
    types: [completed]
    branches: [main]
# new
    branches: ["main"]
```

각 job의 `if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name != 'workflow_run' }}`는 **그대로 둔다** (event_name이 workflow_run일 수 없으므로 항상 true — 무해).

- [ ] **Step 4: NONSTOP 2종의 주석 트리거 정리**

```yaml
# old (NONSTOP-NGINX 74-75행 / NONSTOP-TRAEFIK 70-71행)
  #   branches:
  #     - deploy
# new
  #   branches:
  #     - main
```

- [ ] **Step 5: 검증 — deploy 트리거 잔존 0건 확인**

```bash
grep -rn "branches:.*deploy\|- deploy\b" .github/workflows --include="*.yml" --include="*.yaml" | grep -v "server-deploy\|deploy-status\|# "
diff .github/workflows/PROJECT-COMMON-README-VERSION-UPDATE.yaml .github/workflows/project-types/common/PROJECT-COMMON-README-VERSION-UPDATE.yaml
```

Expected: grep 출력 없음(주석·폴더명 제외), diff 출력 없음.

- [ ] **Step 6: 커밋**

```bash
git add .github/workflows
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : feat : 배포·동기화 워크플로우 13종 트리거를 main push로 교체(죽은 workflow_run 제거 포함) https://github.com/Cassiiopeia/projectops/issues/425"
```

---

### Task 4: CI·개발자산 워크플로우 트리거 교체 (main → develop)

**Files (Modify):**
- `.github/workflows/project-types/flutter/PROJECT-FLUTTER-CI.yaml` (48행 PR, 51행 push)
- `.github/workflows/project-types/react/PROJECT-REACT-CI.yaml` (31행)
- `.github/workflows/project-types/next/PROJECT-NEXT-CI.yaml` (32행)
- `.github/workflows/project-types/python/PROJECT-PYTHON-CI.yaml` (19행 push, 22행 PR — 주석 포함)
- `.github/workflows/project-types/spring/nexus/PROJECT-SPRING-NEXUS-CI.yml` (14행 PR, 17행 push)
- `.github/workflows/project-types/common/secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml` (66행)
- `.github/workflows/PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml` (29행) + `project-types/common/` 동일 파일

- [ ] **Step 1: 트리거 교체**

각 파일에서 (anchor는 파일별 실제 표기 유지 — `[main]` / `["main"]` / `- main` 형식 그대로 브랜치명만 교체):

```yaml
# FLUTTER-CI: branches: [main] → branches: [develop]   (PR·push 2곳)
# REACT-CI:   branches: ["main"] → branches: ["develop"]
# NEXT-CI:    branches: ["main"] → branches: ["develop"]
# PYTHON-CI:  - main  # main 브랜치 push 시 빌드 검증 → - develop  # develop 브랜치 push 시 빌드 검증
#             - main  # main 브랜치로의 PR 시 빌드 검증 → - develop  # develop 브랜치로의 PR 시 빌드 검증
# NEXUS-CI:   branches: [ main ] → branches: [ develop ]   (PR·push 2곳)
# SECRET-FILE-UPLOAD: - main → - develop
# UTIL-VERSION-SYNC:  branches: [ main ] → branches: [ develop ]   (루트+common 2곳)
```

- [ ] **Step 2: 검증 + 커밋**

```bash
diff .github/workflows/PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml .github/workflows/project-types/common/PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml
git diff --stat
```

Expected: diff 출력 없음. stat에 위 8개 파일만.

```bash
git add .github/workflows
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : feat : CI·개발자산 워크플로우 트리거를 develop 기준으로 교체 https://github.com/Cassiiopeia/projectops/issues/425"
```

---

### Task 5: TEMPLATE-INITIALIZER develop 자동 생성 + initializer 스크립트 주석 갱신

**Files:**
- Modify: `.github/workflows/PROJECT-TEMPLATE-INITIALIZER.yaml` ("변경사항 커밋 및 푸시" 스텝 뒤)
- Modify: `.github/scripts/template_initializer.sh` (294, 313행 주석)

- [ ] **Step 1: INITIALIZER에 develop 생성 스텝 추가**

"변경사항 커밋 및 푸시" 스텝(163행~, `git push --force-with-lease origin $DEFAULT_BRANCH`로 끝나는 블록) **바로 뒤에** 삽입:

```yaml
      - name: develop 브랜치 생성
        run: |
          if git ls-remote --exit-code --heads origin develop >/dev/null 2>&1; then
            echo "✅ develop 브랜치가 이미 존재합니다 — 건너뜀"
          else
            git push origin HEAD:develop
            echo "✅ develop 브랜치 생성 완료 (일상 개발은 develop에서, 릴리스는 develop→main PR)"
          fi
```

- [ ] **Step 2: template_initializer.sh 주석 갱신**

```bash
# old (294행): # - deploy 브랜치 전용 워크플로우는 변경하지 않음
# new        : # - main(프로덕션) push 전용 배포 워크플로우는 변경하지 않음
# old (313행):     # (deploy 브랜치 전용 워크플로우는 포함하지 않음)
# new        :     # (main push 전용 배포 워크플로우는 포함하지 않음)
```

- [ ] **Step 3: 검증 + 커밋**

```bash
bash -n .github/scripts/template_initializer.sh && echo SH_OK
git add .github/workflows/PROJECT-TEMPLATE-INITIALIZER.yaml .github/scripts/template_initializer.sh
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : feat : 템플릿 초기화 시 develop 브랜치 자동 생성 https://github.com/Cassiiopeia/projectops/issues/425"
```

Expected: `SH_OK`.

---

### Task 6: suh-changelog-deploy 스킬 · changelog_cli.py 개정

**Files:**
- Modify: `skills/suh-changelog-deploy/scripts/changelog_cli.py` (404행)
- Modify: `skills/suh-changelog-deploy/SKILL.md` (브랜치 참조 전면)

**Interfaces:**
- Produces: `deploy-status --base` 기본값 `main` — SKILL.md 7단계·fix 1단계 호출부가 `--base deploy` 명시를 제거하고 기본값 사용.

- [ ] **Step 1: changelog_cli.py 기본값 교체**

```python
# old (404행)
    p_ds.add_argument("--base", default="deploy")
# new
    p_ds.add_argument("--base", default="main")
```

- [ ] **Step 2: 기본값 검증**

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
cd skills/suh-changelog-deploy/scripts
PYTHONIOENCODING=utf-8 "$PYTHON" -c "
import changelog_cli
p = changelog_cli.build_parser()
args = p.parse_args(['deploy-status', 'o', 'r'])
assert args.base == 'main', args.base
print('BASE_DEFAULT_OK')
"
cd -
```

Expected: `BASE_DEFAULT_OK`. (`build_parser` 함수명이 다르면 파일 상단에서 parser 구성 함수명을 확인해 동일하게 호출한다 — 436행 `return parser`를 반환하는 함수.)

- [ ] **Step 3: SKILL.md 명령 블록 교체 (기계적 치환 — 아래 표 전부 적용)**

| 위치 | old | new |
|------|-----|-----|
| 10행 개요 | `(deploy PR 감지 → CodeRabbit 대기 → CHANGELOG 업데이트 → automerge)` | `(develop→main 릴리스 PR 감지 → CodeRabbit 대기 → 버전 확정 → CHANGELOG 업데이트 → automerge)` |
| 12행 | `main 브랜치 push → deploy PR 생성 → 릴리스 노트 즉시 작성 → automerge 자동 진행.` | `develop 브랜치 push → main으로 릴리스 PR 생성 → 릴리스 노트 즉시 작성 → automerge 자동 진행.` |
| 21행 이때는 쓰지 마라 | `- \`deploy\` 브랜치가 없는 프로젝트 (이 스킬은 main → deploy PR 구조 전용)` | `- \`develop\` 브랜치가 없는 프로젝트 (이 스킬은 develop → main 릴리스 PR 구조 전용)` |
| 1단계 148-149행 | `# deploy 브랜치 대비 미반영 커밋 목록 (이게 핵심 — main→deploy PR이 목적이므로)`<br>`git log origin/deploy..HEAD --oneline 2>/dev/null` | `# main(프로덕션) 대비 미반영 커밋 목록 (이게 핵심 — develop→main PR이 목적이므로)`<br>`git log origin/main..HEAD --oneline 2>/dev/null` |
| 1단계 153-154행 | `# 위 결과가 비어 있을 경우 대비용 — main remote 대비도 함께 확인`<br>`git log origin/main..HEAD --oneline 2>/dev/null` | `# 위 결과가 비어 있을 경우 대비용 — develop remote 대비도 함께 확인`<br>`git log origin/develop..HEAD --oneline 2>/dev/null` |
| 1단계 판단 기준 164-166행 | `origin/deploy..HEAD` / `origin/main..HEAD` 참조 문구 | 위 명령 교체에 맞춰 `origin/main..HEAD` / `origin/develop..HEAD`로 교체 |
| 2단계 223행 | `📋 push할 커밋 (main → deploy 미반영):` | `📋 push할 커밋 (develop → main 미반영):` |
| 2단계 227행 | `git push origin main 을 실행할까요?` | `git push origin develop 을 실행할까요?` |
| 3단계 235-236행 | `git pull --rebase origin main`<br>`git push origin main` | `git pull --rebase origin develop`<br>`git push origin develop` |
| 3단계 239행 | `push 완료 후 \`VERSION-CONTROL\` (patch 버전 자동 증가) 워크플로우가 자동 트리거된다.` | `push 후 버전은 증가하지 않는다 — 버전은 릴리스 PR에서 AUTO-CHANGELOG-CONTROL이 머지 직전 확정한다(릴리스당 +1).` |
| 4단계 252-255행 | `git fetch origin deploy main 2>/dev/null \|\| true`<br>`# 분석 base는 HEAD가 아닌 origin/main — ...`<br>`git log origin/deploy..origin/main --pretty=format:"%s" \| grep -v "\[skip ci\]" \| head -60` | `git fetch origin main develop 2>/dev/null \|\| true`<br>`# 분석 base는 HEAD가 아닌 origin/develop — README 버전 워크플로우 등이 원격을 앞서게 할 수 있다`<br>`git log origin/main..origin/develop --pretty=format:"%s" \| grep -v "\[skip ci\]" \| head -60` |
| 6단계 433-434행 | `deploy-status "$OWNER" "$REPO" --base deploy` | `deploy-status "$OWNER" "$REPO"` (기본값 main 사용) |
| 6단계 448-449행 | `create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "main" "deploy")` | `create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "develop" "main")` |
| fix 3단계 565-567행 | 4단계와 동일 패턴 (`origin/deploy..origin/main`) | 4단계와 동일하게 `origin/main..origin/develop`으로 교체 |
| fix 5단계 607-608행 | `create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "main" "deploy")` | `create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "develop" "main")` |
| 8단계 502행 | `• push: origin/main` | `• push: origin/develop` |

- [ ] **Step 4: SKILL.md 산문 치환 (의미 기반 — 전수 검토)**

`grep -n "deploy\|main" skills/suh-changelog-deploy/SKILL.md`로 전 행을 나열하고, 남은 서술을 다음 규칙으로 교체한다:

- "deploy 브랜치" (프로덕션 브랜치 의미) → "main 브랜치"
- "main 브랜치" (일상 개발 push 의미) → "develop 브랜치"
- "deploy PR" (릴리스 PR 명칭) → 유지 (스킬 고유 명칭이므로 그대로 두되, 첫 등장에서 "deploy PR(develop→main 릴리스 PR)"로 1회 부연)
- description(3행)의 "main 브랜치를 push하고 deploy PR을 생성한 뒤" → "develop 브랜치를 push하고 main으로 릴리스 PR(deploy PR)을 생성한 뒤"
- 스킬/파일/서브커맨드 이름(`suh-changelog-deploy`, `deploy-status`, `changelog_deploy`)과 config 키는 **절대 변경 금지**

- [ ] **Step 5: 검증 + 커밋**

```bash
grep -n "origin/deploy\|--base deploy\|\"deploy\")" skills/suh-changelog-deploy/SKILL.md
```

Expected: 출력 없음.

```bash
git add skills/suh-changelog-deploy
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : feat : changelog-deploy 스킬을 develop→main 릴리스 흐름으로 개정 https://github.com/Cassiiopeia/projectops/issues/425"
```

---

### Task 7: 참조 문서·CLAUDE.md 갱신

**Files:**
- Modify: `skills/suh-github/SKILL.md` (156-168행)
- Modify: `CLAUDE.md` (작업 브랜치 규칙 · 핵심 워크플로우 표 · 트리거 키워드 표)
- Modify: `skills/references/config-rules.md` — deploy 언급 9곳은 전부 `changelog_deploy` **config 키/스킬명**으로 확인됨 → **변경 없음** (확인만)
- Modify: `skills/references/mcp-subcommand-rules.md` — `deploy-status` 서브커맨드명 3곳 → **변경 없음** (확인만)
- Modify: `skills/references/common-rules.md` (131, 133행 — "main 브랜치" 경고 문구)

- [ ] **Step 1: suh-github SKILL.md 릴리스 노트 섹션 교체**

```
# old (156행)
deploy PR에 CodeRabbit Summary가 없을 때 Claude Code가 직접 커밋을 분석하여 한국어 릴리스 노트를 작성하고 PR 본문에 업데이트한다.
# new
릴리스 PR(develop→main)에 CodeRabbit Summary가 없을 때 Claude Code가 직접 커밋을 분석하여 한국어 릴리스 노트를 작성하고 PR 본문에 업데이트한다.
# old (162행)
1. PR 번호 확인 (사용자 입력 또는 `list-prs`로 최근 deploy PR 조회)
# new
1. PR 번호 확인 (사용자 입력 또는 `list-prs`로 최근 릴리스 PR 조회)
# old (164행)
2. deploy 브랜치 대비 커밋 목록 수집
# new
2. main(프로덕션) 대비 커밋 목록 수집
# old (167-168행)
git fetch origin deploy 2>/dev/null || true
git log origin/deploy..HEAD --pretty=format:"%H %s" | grep -v "\[skip ci\]" | head -60
# new
git fetch origin main 2>/dev/null || true
git log origin/main..HEAD --pretty=format:"%H %s" | grep -v "\[skip ci\]" | head -60
```

- [ ] **Step 2: common-rules.md 브랜치 경고 문구 교체**

131행 부근 "main 브랜치인 경우" 경고(커밋 전 브랜치 확인 규칙)를 읽고, 보호 대상 브랜치를 main+develop 직접 커밋 경고로 문맥에 맞게 갱신한다. 앞뒤 20행을 Read로 확인 후 의미를 보존해 교체한다 (main이 프로덕션이 됐으므로 "main 직접 커밋"은 더 강한 경고가 되어야 함).

- [ ] **Step 3: CLAUDE.md 작업 브랜치 규칙 교체**

```markdown
# old (7-14행)
## ⚠️ 작업 브랜치 규칙 (agent 필독)

**이 프로젝트는 `main` 브랜치에서 직접 작업하는 것을 기본값으로 한다.**

- 별도 지시가 없으면 feature 브랜치를 만들지 말고 `main`에서 작업·커밋·푸시한다.
- `main` push 전에는 **항상 `git pull --rebase origin main`** 으로 먼저 동기화한다 (버전 자동증가 워크플로우가 main에 커밋을 추가하므로 로컬이 뒤처지기 쉽다).
- `git push`는 **사용자가 명시적으로 요청한 경우에만** 실행한다.
- 사용자가 명시적으로 브랜치 작업을 요청한 경우에만 feature 브랜치를 사용한다.
# new
## ⚠️ 작업 브랜치 규칙 (agent 필독)

**이 프로젝트는 `develop` 브랜치에서 직접 작업하는 것을 기본값으로 한다. `main`은 프로덕션(default) — 직접 커밋·push 금지.**

- 별도 지시가 없으면 feature 브랜치를 만들지 말고 `develop`에서 작업·커밋·푸시한다.
- `develop` push 전에는 **항상 `git pull --rebase origin develop`** 으로 먼저 동기화한다 (릴리스 시 버전 확정 커밋이 develop에 추가되므로 로컬이 뒤처지기 쉽다).
- 릴리스(배포)는 develop→main PR로만 진행한다 (`/cassiiopeia:suh-changelog-deploy`). main 직접 push는 안전망(VERSION-CONTROL 가드)이 버전만 보전할 뿐 지원 경로가 아니다.
- `git push`는 **사용자가 명시적으로 요청한 경우에만** 실행한다.
- 사용자가 명시적으로 브랜치 작업을 요청한 경우에만 feature 브랜치를 사용한다.
```

- [ ] **Step 4: CLAUDE.md 워크플로우 표·트리거 표 갱신**

핵심 워크플로우 표(공통) 3행 교체:

```markdown
# old
| `PROJECT-COMMON-VERSION-CONTROL` | main 푸시 | patch 버전 자동 증가 |
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` | deploy PR | AI 체인지로그 생성 |
| `PROJECT-COMMON-README-VERSION-UPDATE` | deploy 푸시 | README 버전 동기화 |
# new
| `PROJECT-COMMON-VERSION-CONTROL` | main 직접 푸시(안전망) | 릴리스 머지 외 push 시 patch 증가 |
| `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` | main PR (develop→main) | 버전 확정 + AI 체인지로그 + automerge |
| `PROJECT-COMMON-README-VERSION-UPDATE` | main 푸시 | README 버전 동기화 |
```

`PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC`의 트리거 설명도 "version.yml 변경" → "main 푸시"로 실제와 일치시킨다.

브랜치 기반 트리거 표 교체:

```markdown
# old
| `main` | push | VERSION-CONTROL |
| `deploy` | PR | CHANGELOG-CONTROL |
| `deploy` | push | README-UPDATE, CICD |
# new
| `develop` | push | CI (버전 증가 없음) |
| `main` | PR (develop→main) | CHANGELOG-CONTROL (버전 확정 + automerge) |
| `main` | push (릴리스 머지) | README-UPDATE, PLUGIN-SYNC, NPM-PUBLISH, CICD |
| `main` | push (직접) | VERSION-CONTROL 안전망 (+CICD — 비권장 경로) |
```

- [ ] **Step 5: 확인 전용 — references 2개 파일**

```bash
grep -n "deploy" skills/references/config-rules.md skills/references/mcp-subcommand-rules.md | grep -v "changelog_deploy\|changelog-deploy\|deploy-status"
```

Expected: 출력 없음 (전부 스킬/키 이름 — 변경 불필요 확정).

- [ ] **Step 6: 커밋**

```bash
git add skills/suh-github/SKILL.md skills/references/common-rules.md CLAUDE.md
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : docs : 작업 브랜치 규칙·트리거 표·스킬 참조 문서 갱신 https://github.com/Cassiiopeia/projectops/issues/425"
```

---

### Task 8: breaking-changes.json critical 등록

**Files:**
- Modify: `.github/config/breaking-changes.json`

- [ ] **Step 1: 등록 버전 키 계산**

```bash
./.github/scripts/version_manager.sh get
```

출력값 +1(patch)을 키로 사용한다 (예: `3.0.185` → `3.0.186`). 전환 커밋이 main에 push되면 안전망 VERSION-CONTROL이 그 버전으로 bump하므로 "이 breaking change가 포함된 최초 버전"과 일치한다.

- [ ] **Step 2: 항목 추가**

기존 `"3.0.137"` 항목 뒤에 추가 (마지막 항목 뒤 콤마 주의):

```json
  "{계산한 버전}": {
    "severity": "critical",
    "title": "브랜치 전략 전면 전환 — deploy 폐기, develop(개발)/main(배포) 표준 구조",
    "message": "브랜치 전략이 전면 개편되었습니다. 기존: main(개발 통합) → deploy(프로덕션). 신규: develop(개발 통합) → main(default=프로덕션). deploy 브랜치는 폐기되었습니다. 배포·README·플러그인/NPM 동기화 워크플로우는 main push 트리거로, CI·시크릿 백업·Util 동기화는 develop 트리거로 변경되었습니다. 버전은 develop→main 릴리스 PR 안에서 AUTO-CHANGELOG-CONTROL이 릴리스당 +1로 확정하며(main 직접 push는 VERSION-CONTROL 안전망이 처리), 일상 develop push는 버전을 올리지 않습니다. 기존 프로젝트 전환 절차: 1) git branch develop main && git push origin develop 2) 템플릿 재통합(업데이트 모드) 3) deploy 브랜치 삭제 4) 이후 개발은 develop에서, 릴리스는 develop→main PR로 진행. 전환 전까지는 이 업데이트를 받지 마세요."
  }
```

- [ ] **Step 3: 검증 + 커밋**

```bash
python -c "import json; json.load(open('.github/config/breaking-changes.json', encoding='utf-8')); print('JSON_OK')"
git add .github/config/breaking-changes.json
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : chore : breaking-changes critical 등록(수동 전환 절차 포함) https://github.com/Cassiiopeia/projectops/issues/425"
```

Expected: `JSON_OK`.

---

### Task 9: README·CONTRIBUTING·docs 브랜치 서술 스윕

**Files:**
- Modify: `README.md`, `CONTRIBUTING.md`, `docs/**/*.md` 중 deploy/main 브랜치 흐름을 서술하는 파일 (스윕으로 확정)

- [ ] **Step 1: 대상 나열**

```bash
grep -rln "deploy 브랜치\|deploy branch\|main → deploy\|main→deploy" README.md CONTRIBUTING.md docs --include="*.md" | grep -v "docs/superpowers\|docs/suh-template"
```

(`docs/superpowers/`·`docs/suh-template/`는 이력 문서라 제외 — 과거 기록은 수정하지 않는다.)

- [ ] **Step 2: 매핑 규칙으로 파일별 수정**

각 파일을 Read로 열어 맥락을 확인한 뒤 적용:

| 의미 | old | new |
|------|-----|-----|
| 프로덕션 브랜치 | "deploy 브랜치" | "main 브랜치" |
| 릴리스 PR | "main → deploy PR" | "develop → main PR" |
| 개발 통합 브랜치 (push 문맥) | "main 브랜치에 push" | "develop 브랜치에 push" |
| 버전 증가 서술 | "main push마다 patch 증가" | "릴리스(develop→main PR)마다 patch 증가" |
| 폴더/행위 의미 | "server-deploy/", "배포(deploy)" 행위 서술 | **유지** |

- [ ] **Step 3: 검증 + 커밋**

```bash
grep -rn "deploy 브랜치" README.md CONTRIBUTING.md docs --include="*.md" | grep -v "docs/superpowers\|docs/suh-template\|폐기\|과거\|기존"
git add README.md CONTRIBUTING.md docs
git commit -m "deploy 브랜치 폐기 및 develop/main 표준 브랜치 전략 전환 : docs : README·CONTRIBUTING·docs 브랜치 흐름 서술 갱신 https://github.com/Cassiiopeia/projectops/issues/425"
```

Expected: grep은 "폐기됨" 안내 등 의도된 서술만 남음.

---

### Task 10: 전체 정합성 검증 (커밋 없음)

- [ ] **Step 1: 트리거 전수 확인**

```bash
grep -rn -A3 "^on:" .github/workflows --include="*.yaml" --include="*.yml" | grep -B1 -A3 "branches" | grep -c "deploy" || echo "DEPLOY_TRIGGER_ZERO"
```

Expected: `DEPLOY_TRIGGER_ZERO` (또는 count 0).

- [ ] **Step 2: YAML 파스 (참고용 — 실패해도 heredoc 0칸 들여쓰기 패턴이면 무시)**

```bash
PYTHON=$(command -v python3 || command -v python)
for f in .github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml .github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml .github/workflows/PROJECT-TEMPLATE-INITIALIZER.yaml; do
  "$PYTHON" -c "import yaml,sys; yaml.safe_load(open('$f', encoding='utf-8')); print('PARSE_OK $f')" || echo "PARSE_WARN $f (로컬 파서 한계 가능 — 변경 라인 주변만 육안 재확인)"
done
```

- [ ] **Step 3: 공통 워크플로우 루트/원본 쌍 전수 diff**

```bash
for f in PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml PROJECT-COMMON-VERSION-CONTROL.yaml PROJECT-COMMON-README-VERSION-UPDATE.yaml PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml; do
  diff ".github/workflows/$f" ".github/workflows/project-types/common/$f" && echo "SYNC_OK $f"
done
```

Expected: 4건 모두 `SYNC_OK`.

- [ ] **Step 4: 실행 로직 무손상 최종 확인**

```bash
git diff origin/main...HEAD -- .github/workflows | grep "^-" | grep -v "^---" | grep -vE "deploy|main|develop|DEFAULT_BRANCH|워크플로우는|브랜치|# |CHANGELOG 자동|workflow_run|workflows:|types: \[completed\]|branches:|VERSION=|git add CHANGELOG|docs : v|git push origin HEAD|git pull --rebase origin \$DEFAULT_BRANCH|echo|버전: \$"
```

Expected: 출력 없음 — 삭제된 라인이 전부 의도된 범위(브랜치 참조·죽은 트리거·교체 대상 명령)에 속함. 출력이 있으면 해당 라인 원복 검토.

---

### Task 11: 레포 브랜치 재편 (⚠️ 사용자 승인 후에만)

> **이 태스크의 모든 push·브랜치 조작은 사용자가 명시적으로 승인해야 실행한다.** 실행 전 요약을 보여주고 확인받는다.

- [ ] **Step 1: 전환 커밋 push (사용자 승인)**

```bash
git pull --rebase origin main
git push origin main
```

push 후 확인: 안전망 VERSION-CONTROL이 직접 push로 인식해 +1 bump·태그를 만드는 것이 **정상**이다 (전환 커밋에 version.yml 변경이 없으므로).

- [ ] **Step 2: develop 생성 (사용자 승인)**

```bash
git fetch origin main
git push origin origin/main:refs/heads/develop
```

- [ ] **Step 3: deploy 삭제 (사용자 승인 — 파괴적)**

삭제 전 deploy가 main 대비 앞선 커밋이 없는지 확인:

```bash
git fetch origin deploy main
git log origin/main..origin/deploy --oneline
```

Expected: 출력 없음(있으면 사용자에게 보고 후 중단). 이후:

```bash
git push origin --delete deploy
```

- [ ] **Step 4: 전환 후 첫 릴리스 실측 (스펙 §12)**

develop에서 사소한 변경(예: docs) 커밋 → `/cassiiopeia:suh-changelog-deploy`로 develop→main 릴리스 PR 생성 → 확인 항목:
1. AUTO-CHANGELOG가 head 가드를 통과하고 develop에 버전 확정 커밋(+CHANGELOG)을 push하는가
2. PR 제목이 확정 버전으로 갱신되는가
3. automerge 후 main push로 README-UPDATE·PLUGIN-SYNC·NPM-PUBLISH가 확정 버전을 읽는가
4. 릴리스 태그 v{버전}이 main 머지 커밋에 생성되는가
5. VERSION-CONTROL이 릴리스 머지를 가드로 건너뛰는가 (Actions 로그에서 "릴리스 머지 감지" 확인)

문제 발견 시: 수정 커밋은 develop에서 작업하고, 긴급하면 fix 모드 대신 워크플로우 수정 → 새 릴리스 PR로 재검증.

---

## Self-Review 결과 (계획 작성 후 점검)

- **스펙 커버리지**: §5 트리거 표 → Task 3·4, §6 → Task 1, §7 → Task 2, §8 → Task 6·7, §9 → Task 5·8·9, §10 → Task 11, §12 → Task 3(죽은 workflow_run 실측 확인 완료·제거) + Task 11 Step 4. NPM-PUBLISH는 스펙 이후 신설된 워크플로우로 Task 3에 추가 반영.
- **타입 일관성**: `steps.bump_version.outputs.new_version`(Task 1 Step 6·7·8·9), `steps.release_guard.outputs.is_release_merge`(Task 2 Step 2·3), `deploy-status --base` 기본값 `main`(Task 6 Step 1↔SKILL.md 호출부) 상호 일치 확인.
- **잔여 리스크**: 릴리스 실패 시 develop 고아 bump(다음 릴리스가 그 버전으로 진행 — 버전 공백 없음), main 직접 push 시 해당 push의 CICD는 bump 전 버전 사용(비지원 경로 문서화). 스펙 §13과 일치.
