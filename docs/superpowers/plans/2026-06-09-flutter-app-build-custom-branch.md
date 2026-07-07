# Flutter 앱빌드 트리거 특정 브랜치명 인자 지원 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter 앱빌드 댓글 트리거(`@suh-lab build app`)에서 명령어 뒤에 브랜치명을 적으면 그 브랜치를 빌드하도록 지원한다.

**Architecture:** 단일 워크플로우 파일(`PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml`)의 두 개 github-script 스텝만 수정한다. (1) "빌드 타입 판별" 스텝에서 정규식으로 buildType + customBranch를 동시에 캡처하고, (2) "PR/이슈 정보 확인 및 추출" 스텝에서 customBranch가 있으면 자동결정 브랜치보다 우선 적용한다. 빌드 번호·결과 댓글의 소스 번호(PR/이슈 번호)는 댓글 컨텍스트를 그대로 유지한다.

**Tech Stack:** GitHub Actions (`issue_comment` 트리거), `actions/github-script@v7` (Node.js), 검증은 로컬 Node 스크립트 + Python YAML 파싱.

> **작업 브랜치:** 사용자 명시 동의로 `main` 브랜치에서 직접 작업한다. worktree/feature 브랜치를 만들지 않는다.

> **참고 설계 문서:** `docs/superpowers/specs/2026-06-09-flutter-app-build-custom-branch-design.md`

> **검증된 정규식 (이미 Node로 테스트 통과):** 같은 줄 공백만 구분자로 인정(`[^\S\r\n]+`)하여 줄바꿈 너머 단어가 브랜치로 오인되는 것을 막는다.
> - `app`: `/@suh-lab[^\S\r\n]+build[^\S\r\n]+app(?:[^\S\r\n]+(\S+))?/`
> - `apk`: `/@suh-lab[^\S\r\n]+apk[^\S\r\n]+build(?:[^\S\r\n]+(\S+))?/`
> - `ios`: `/@suh-lab[^\S\r\n]+ios[^\S\r\n]+build(?:[^\S\r\n]+(\S+))?/`

---

## File Structure

- **Modify only**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml`
  - "빌드 타입 판별" 스텝(현재 73~97행): 정규식 파싱 + `customBranch` 출력 추가
  - "PR/이슈 정보 확인 및 추출" 스텝(현재 101~197행): `customBranch` 우선 적용 분기 추가
- **Create (임시 검증용, 커밋 안 함)**: `scripts/_parse_test.js` — 정규식 파싱 단위 검증. 검증 후 삭제한다.
- **수정 불필요 (확인만)**: `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`, `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` — 이미 `client_payload.branch_name`을 받음.

---

## Task 1: 파싱 로직 단위 검증 스크립트 작성·실행

**Files:**
- Create (임시): `scripts/_parse_test.js`

- [ ] **Step 1: 검증 스크립트 작성 (실패하는 테스트 먼저 — 아직 워크플로우 미수정이지만 로직 정합성 고정)**

`scripts/_parse_test.js` 생성:

```javascript
// 워크플로우 "빌드 타입 판별" 스텝에 들어갈 파싱 로직과 동일한 함수.
// 이 함수를 여기서 통과시킨 뒤, 같은 코드를 워크플로우 YAML에 이식한다.
function parseBuildComment(rawBody) {
  const comment = rawBody.toLowerCase();
  let buildAndroid = false;
  let buildIos = false;
  let buildType = '';
  let customBranch = '';
  let m;
  if ((m = comment.match(/@suh-lab[^\S\r\n]+build[^\S\r\n]+app(?:[^\S\r\n]+(\S+))?/))) {
    buildAndroid = true; buildIos = true; buildType = 'app'; customBranch = m[1] || '';
  } else if ((m = comment.match(/@suh-lab[^\S\r\n]+apk[^\S\r\n]+build(?:[^\S\r\n]+(\S+))?/))) {
    buildAndroid = true; buildType = 'apk'; customBranch = m[1] || '';
  } else if ((m = comment.match(/@suh-lab[^\S\r\n]+ios[^\S\r\n]+build(?:[^\S\r\n]+(\S+))?/))) {
    buildIos = true; buildType = 'ios'; customBranch = m[1] || '';
  }
  return { buildType, buildAndroid, buildIos, customBranch };
}

const cases = [
  ['@suh-lab build app',                 { buildType: 'app', buildAndroid: true,  buildIos: true,  customBranch: '' }],
  ['@suh-lab build app feature/login',   { buildType: 'app', buildAndroid: true,  buildIos: true,  customBranch: 'feature/login' }],
  ['@suh-lab apk build',                 { buildType: 'apk', buildAndroid: true,  buildIos: false, customBranch: '' }],
  ['@suh-lab apk build 20260609_#349_x', { buildType: 'apk', buildAndroid: true,  buildIos: false, customBranch: '20260609_#349_x' }],
  ['@suh-lab ios build dev',             { buildType: 'ios', buildAndroid: false, buildIos: true,  customBranch: 'dev' }],
  ['@suh-lab build app   spaced  ',      { buildType: 'app', buildAndroid: true,  buildIos: true,  customBranch: 'spaced' }],
  ['please @suh-lab build app main now', { buildType: 'app', buildAndroid: true,  buildIos: true,  customBranch: 'main' }],
  ['@suh-lab build app\n다음줄무시',      { buildType: 'app', buildAndroid: true,  buildIos: true,  customBranch: '' }],
];

let failed = 0;
for (const [input, expected] of cases) {
  const got = parseBuildComment(input);
  const ok = JSON.stringify(got) === JSON.stringify(expected);
  if (!ok) failed++;
  console.log(ok ? 'PASS' : 'FAIL', JSON.stringify(input.replace(/\n/g, '\\n')), '=>', JSON.stringify(got));
}
if (failed) { console.error(`${failed} case(s) FAILED`); process.exit(1); }
console.log('ALL PASS');
```

- [ ] **Step 2: 실행하여 전부 통과 확인**

Run: `node scripts/_parse_test.js`
Expected: 마지막 줄에 `ALL PASS`, exit code 0

---

## Task 2: "빌드 타입 판별" 스텝에 정규식 파싱 + customBranch 출력 적용

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml` (현재 74~97행 `script:` 본문)

- [ ] **Step 1: 빌드 타입 판별 script 본문 교체**

현재 코드 (74~97행):

```javascript
            const comment = context.payload.comment.body.toLowerCase();

            let buildAndroid = false;
            let buildIos = false;
            let buildType = '';

            if (comment.includes('build') && comment.includes('app')) {
              // @suh-lab build app → 양쪽 모두
              buildAndroid = true;
              buildIos = true;
              buildType = 'app';
            } else if (comment.includes('apk') && comment.includes('build')) {
              // @suh-lab apk build → Android만
              buildAndroid = true;
              buildType = 'apk';
            } else if (comment.includes('ios') && comment.includes('build')) {
              // @suh-lab ios build → iOS만
              buildIos = true;
              buildType = 'ios';
            }

            core.setOutput('buildAndroid', buildAndroid.toString());
            core.setOutput('buildIos', buildIos.toString());
            core.setOutput('buildType', buildType);
```

다음으로 교체:

```javascript
            const comment = context.payload.comment.body.toLowerCase();

            let buildAndroid = false;
            let buildIos = false;
            let buildType = '';
            let customBranch = '';
            let m;

            // 명령어 키워드 뒤의 같은 줄 토큰을 옵셔널 브랜치 인자로 캡처
            // (줄바꿈 너머 단어가 브랜치로 오인되지 않도록 [^\S\r\n]+ 로 같은 줄 공백만 허용)
            if ((m = comment.match(/@suh-lab[^\S\r\n]+build[^\S\r\n]+app(?:[^\S\r\n]+(\S+))?/))) {
              // @suh-lab build app [브랜치] → 양쪽 모두
              buildAndroid = true;
              buildIos = true;
              buildType = 'app';
              customBranch = m[1] || '';
            } else if ((m = comment.match(/@suh-lab[^\S\r\n]+apk[^\S\r\n]+build(?:[^\S\r\n]+(\S+))?/))) {
              // @suh-lab apk build [브랜치] → Android만
              buildAndroid = true;
              buildType = 'apk';
              customBranch = m[1] || '';
            } else if ((m = comment.match(/@suh-lab[^\S\r\n]+ios[^\S\r\n]+build(?:[^\S\r\n]+(\S+))?/))) {
              // @suh-lab ios build [브랜치] → iOS만
              buildIos = true;
              buildType = 'ios';
              customBranch = m[1] || '';
            }

            core.setOutput('buildAndroid', buildAndroid.toString());
            core.setOutput('buildIos', buildIos.toString());
            core.setOutput('buildType', buildType);
            core.setOutput('customBranch', customBranch);

            console.log(`📱 빌드 타입: ${buildType} (Android=${buildAndroid}, iOS=${buildIos})`);
            if (customBranch) {
              console.log(`🌿 댓글에서 지정된 브랜치: ${customBranch}`);
            }
```

> 주의: 원본 97행 다음에 있던 기존 `console.log('📱 빌드 타입: ...')` 줄(99행)은 위 교체 블록이 동일 로그를 포함하므로 **중복 제거**한다. 교체 후 `build_type` 스텝 끝에 `console.log`가 한 벌만 남아야 한다.

- [ ] **Step 2: 빌드 타입 우선순위 회귀 확인 (app이 apk/ios보다 먼저)**

`@suh-lab build app` 댓글이 `app` 분기로 가야 한다(과거 `includes` 순서와 동일). Task 1의 케이스가 이미 이 순서를 고정하므로 추가 작업 없음. YAML만 저장.

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/project-types/flutter/PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml
git commit -m "Flutter 앱빌드 댓글 트리거에 특정 브랜치명 인자 지원 : feat : 빌드 타입 판별 스텝에서 정규식으로 customBranch 캡처 https://github.com/Cassiiopeia/projectops/issues/349"
```

---

## Task 3: "PR/이슈 정보 확인 및 추출" 스텝에 customBranch 우선 적용

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml` (현재 101~197행 `source_info` 스텝)

**배경:** 이 스텝은 `build_type` 스텝의 출력을 직접 참조하지 않으므로, 먼저 `customBranch`를 script 안으로 끌어와야 한다. github-script에서는 이전 스텝 출력을 `${{ steps.build_type.outputs.customBranch }}`로 주입한다.

- [ ] **Step 1: script 시작부에 customBranch 주입**

현재 106~112행:

```javascript
            const issueNumber = context.payload.issue.number;
            let sourceType = '';
            let sourceNumber = '';
            let branchName = '';
            let headSha = '';
            let relatedIssueNumber = '';
```

다음으로 교체 (맨 앞에 customBranch 상수 추가):

```javascript
            const customBranch = `${{ steps.build_type.outputs.customBranch }}`.trim();
            const issueNumber = context.payload.issue.number;
            let sourceType = '';
            let sourceNumber = '';
            let branchName = '';
            let headSha = '';
            let relatedIssueNumber = '';
```

- [ ] **Step 2: PR 분기에서 customBranch 우선 적용**

현재 122~124행 (PR 확인 직후 branchName 할당부):

```javascript
              sourceType = 'PR';
              sourceNumber = pr.data.number.toString();
              branchName = pr.data.head.ref;
              headSha = pr.data.head.sha;
```

다음으로 교체:

```javascript
              sourceType = 'PR';
              sourceNumber = pr.data.number.toString();
              branchName = customBranch || pr.data.head.ref;
              headSha = pr.data.head.sha;

              if (customBranch) {
                console.log(`🌿 댓글 지정 브랜치 우선 적용: ${customBranch} (PR head=${pr.data.head.ref})`);
              }
```

> `#숫자` 추출(현재 131~133행)은 이미 `branchName`을 입력으로 쓰므로, customBranch가 적용된 branchName에서 자동으로 관련 이슈 번호를 뽑는다. 추가 수정 없음.

- [ ] **Step 3: 이슈 분기에서 customBranch 우선 적용**

이슈 분기는 `Guide by SUH-LAB` 댓글에서 브랜치를 파싱한다(현재 147~188행). customBranch가 있으면 **Guide 댓글 탐색 자체를 건너뛰고** customBranch를 쓰도록 분기 맨 앞에 가드를 추가한다.

현재 142~147행 (catch 블록에서 이슈로 처리 시작):

```javascript
            } catch (error) {
              console.log('ℹ️ PR이 아닙니다. 이슈에서 브랜치 정보를 찾습니다...');

              // 2. PR이 아니면 이슈에서 "Guide by SUH-LAB" 댓글 찾기
              sourceType = 'ISSUE';
              sourceNumber = issueNumber.toString();
              relatedIssueNumber = issueNumber.toString();

              try {
```

다음으로 교체 (sourceType/번호 설정 후, Guide 탐색 전에 customBranch 가드 삽입):

```javascript
            } catch (error) {
              console.log('ℹ️ PR이 아닙니다. 이슈에서 브랜치 정보를 찾습니다...');

              // 2. PR이 아니면 이슈에서 "Guide by SUH-LAB" 댓글 찾기
              sourceType = 'ISSUE';
              sourceNumber = issueNumber.toString();
              relatedIssueNumber = issueNumber.toString();

              // 댓글에서 브랜치를 직접 지정한 경우 Guide 댓글 탐색을 건너뛴다
              if (customBranch) {
                branchName = customBranch;
                const issueMatch = branchName.match(/#(\d+)/);
                if (issueMatch) {
                  relatedIssueNumber = issueMatch[1];
                }
                console.log(`🌿 댓글 지정 브랜치 사용 (Guide 댓글 건너뜀): ${branchName}`);
                console.log(`📌 관련 이슈 번호: #${relatedIssueNumber}`);

                core.setOutput('found', 'true');
                core.setOutput('sourceType', sourceType);
                core.setOutput('sourceNumber', sourceNumber);
                core.setOutput('branchName', branchName);
                core.setOutput('headSha', headSha);
                core.setOutput('relatedIssueNumber', relatedIssueNumber);
                return;
              }

              try {
```

> 위 `return`은 github-script가 감싸는 async 함수 본문에서 조기 종료한다(actions/github-script는 script를 async 함수 body로 실행하므로 top-level `return` 허용). 이슈 분기에서 customBranch가 있으면 이 지점에서 출력까지 마치고 끝낸다.

- [ ] **Step 4: 최종 출력부가 PR/Guide 경로에서만 실행되는지 확인**

현재 191~197행의 최종 `core.setOutput(...)` 블록은 그대로 둔다. customBranch 이슈 분기는 Step 3에서 이미 출력 후 `return` 했고, PR 분기와 Guide 분기는 이 최종 블록으로 흘러온다. 중복 출력 없음.

- [ ] **Step 5: 워크플로우 YAML 문법 검증**

Run:
```bash
python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/project-types/flutter/PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml', encoding='utf-8')); print('YAML OK')"
```
Expected: `YAML OK` (파싱 에러 없음)

> `${{ ... }}`는 YAML 문자열 안(스칼라 블록 `script: |`)에 있으므로 yaml.safe_load는 정상 파싱한다.

- [ ] **Step 6: 커밋**

```bash
git add .github/workflows/project-types/flutter/PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml
git commit -m "Flutter 앱빌드 댓글 트리거에 특정 브랜치명 인자 지원 : feat : source_info 스텝에서 customBranch를 PR head/이슈 Guide보다 우선 적용 https://github.com/Cassiiopeia/projectops/issues/349"
```

---

## Task 4: 하위 빌드 워크플로우 호환 확인 + 임시 파일 정리

**Files:**
- 확인만: `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`, `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`
- Delete: `scripts/_parse_test.js`

- [ ] **Step 1: 하위 워크플로우가 branch_name을 받아 checkout하는지 확인**

Run:
```bash
grep -n "branch_name\|client_payload" .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml .github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml
```
Expected: 두 파일 모두 `client_payload.branch_name`(또는 동등 표현)을 ref로 사용하는 라인이 존재. 없으면 STOP하고 사용자에게 보고(설계 가정이 깨진 것).

- [ ] **Step 2: 임시 검증 스크립트 삭제**

Run: `rm scripts/_parse_test.js`

- [ ] **Step 3: 작업 트리 정리 상태 확인**

Run: `git status --porcelain`
Expected: `scripts/_parse_test.js` 가 목록에 없음(추적 안 됐거나 삭제됨). 워크플로우 변경은 이미 Task 2·3에서 커밋됨.

---

## Self-Review 결과

- **Spec 커버리지:**
  - 명령어 문법 3종 + 옵셔널 브랜치 → Task 2 정규식.
  - 브랜치 우선순위(명시>PR head>Guide) → Task 3 Step 2·3.
  - 빌드 추적 = 댓글 컨텍스트 유지(소스 번호 불변) → source_info에서 sourceNumber를 PR/이슈 번호로 유지(미수정), 빌드 번호 스텝 무수정으로 보장.
  - 관련 이슈 번호 = 명시 브랜치명의 `#숫자` → Task 3 Step 2 주석 + Step 3 가드.
  - 명시 브랜치 미존재 시 기존 에러 댓글 재사용 → 브랜치 존재 확인 스텝(226~293행) 무수정으로 자동 적용.
  - 하위 워크플로우 무수정 → Task 4 Step 1에서 검증.
- **Placeholder 스캔:** 모든 코드 스텝에 실제 코드/명령/기대출력 포함. placeholder 없음.
- **타입 일관성:** `customBranch` 출력명이 Task 2(`core.setOutput('customBranch', ...)`)와 Task 3(`steps.build_type.outputs.customBranch`)에서 일치. `branchName` 변수 일관 사용.
