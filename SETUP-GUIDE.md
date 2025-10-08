# 📋 상세 설정 가이드

이 문서는 GitHub 스마트 자동화 템플릿을 프로젝트에 적용하기 위한 **단계별 상세 가이드**입니다.

---

## 🎯 빠른 체크리스트

### ✅ 준비 사항
- [ ] GitHub Personal Access Token (Classic) 생성
- [ ] `_GITHUB_PAT_TOKEN` Secret 등록
- [ ] `deploy` 브랜치 생성
- [ ] 필수 3개 파일 복사 완료

### ✅ 설정 완료 확인
- [ ] `version.yml` 프로젝트 타입 설정
- [ ] README 버전 표시 영역 추가
- [ ] 첫 번째 테스트 커밋 성공
- [ ] 자동화 워크플로우 실행 확인

---

## 📁 파일별 상세 복사 가이드

### 1. 🔥 필수 파일들

#### `.github/` 폴더 (전체 복사)
```
📁 .github/
├── 📁 workflows/                    # GitHub Actions 워크플로우
│   ├── PROJECT-VERSION-CONTROL.yaml          # 🏷️ 버전 자동 관리
│   ├── PROJECT-AUTO-CHANGELOG-CONTROL.yaml   # 📝 AI 체인지로그 생성
│   ├── PROJECT-README-VERSION-UPDATE.yaml    # 📊 README 버전 업데이트
│   ├── PROJECT-SAMPLE-CICD.yaml             # 🏗️ 멀티플랫폼 빌드
│   ├── PROJECT-ISSUE-COMMENT.yaml           # 🎯 이슈 자동화
│   ├── PROJECT-SYNC-ISSUE-LABELS.yaml       # 🏷️ 라벨 동기화
│   ├── PROJECT-SAMPLE-NEXUS-PUBLISH.yml     # 📦 Nexus 배포 (샘플)
│   └── PROJECT-SAMPLE-NEXUS-MODULE-CI-BUILD-CHECK.yml # ✅ CI 빌드 체크 (샘플)
├── 📁 scripts/                     # 자동화 스크립트
│   ├── version_manager.sh          # 🚀 버전 관리 스크립트 v2.0
│   └── changelog_manager.py        # 🤖 AI 체인지로그 관리 스크립트
└── 📁 ISSUE_TEMPLATE/              # 이슈 템플릿 (선택사항)
```

**복사 명령:**
```bash
# 템플릿 저장소에서 복사
cp -r suh-github-template/.github ./

# 실행 권한 설정
chmod +x .github/scripts/version_manager.sh
chmod +x .github/scripts/changelog_manager.py
```

#### `version.yml` (프로젝트 루트)
```yaml
# 프로젝트 버전 설정
version: "1.0.0"              # 🎯 시작 버전 (프로젝트에 맞게 수정)
project_type: "spring"        # 🎯 프로젝트 타입 (아래 타입 중 선택)

# 지원하는 project_type:
# - spring          : Spring Boot / Java / Gradle
# - flutter         : Flutter / Dart
# - react           : React.js / Next.js
# - react-native    : React Native (iOS + Android)
# - react-native-expo : Expo 기반 React Native
# - node            : Node.js / Express
# - python          : Python / FastAPI / Django
# - basic           : 기본 타입 (version.yml만 사용)
```

#### `.coderabbit.yaml` (프로젝트 루트, 선택사항)
```yaml
# CodeRabbit AI 설정
language: ko
reviews:
  profile: chill
  request_changes_workflow: false
  high_level_summary: true
  poem: true
  review_status: true
  collapse_ellipsis: false
  auto_review:
    enabled: true
    ignore_title_keywords:
      - WIP
      - DO NOT MERGE
chat:
  auto_reply: true
```

---

## 🔧 단계별 설정 프로세스

### 1단계: GitHub 토큰 설정

#### Personal Access Token 생성
1. **GitHub** → **Settings** → **Developer settings**
2. **Personal access tokens** → **Tokens (classic)** 클릭
3. **Generate new token (classic)** 클릭
4. 토큰 설정:
   ```
   Name: _GITHUB_PAT_TOKEN
   Expiration: 90 days (또는 조직 정책에 따라)
   Scopes:
   ✅ repo (Full control of private repositories)
   ✅ workflow (Update GitHub Action workflows)
   ```
5. **Generate token** 클릭 후 토큰 복사

#### Repository Secret 등록
1. **프로젝트 저장소** → **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret** 클릭
3. 설정:
   ```
   Name: _GITHUB_PAT_TOKEN
   Secret: [위에서 복사한 토큰 값]
   ```
4. **Add secret** 클릭

### 2단계: 브랜치 구조 설정

#### Deploy 브랜치 생성
```bash
# 현재 브랜치 확인
git branch -a

# main 브랜치에 있는지 확인
git checkout main

# deploy 브랜치 생성 및 전환
git checkout -b deploy

# 첫 번째 푸시 (모든 파일 포함)
git push -u origin deploy

# main 브랜치로 돌아가기
git checkout main
```

#### 브랜치 보호 규칙 설정 (권장)
1. **Repository** → **Settings** → **Branches**
2. **Add branch protection rule** 클릭
3. **Branch name pattern**: `main`
4. 권장 설정:
   ```
   ✅ Require a pull request before merging
   ✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging
   ✅ Include administrators
   ```
5. `deploy` 브랜치에도 동일한 규칙 적용

### 3단계: 프로젝트별 버전 동기화

#### Spring Boot 프로젝트
```bash
# build.gradle 확인
cat build.gradle | grep version

# version.yml과 동일한 버전으로 설정
# build.gradle:
version = '1.0.0'
```

#### Flutter 프로젝트
```bash
# pubspec.yaml 확인
cat pubspec.yaml | grep version

# version.yml과 동일한 버전으로 설정
# pubspec.yaml:
version: 1.0.0+1
```

#### React/Node.js 프로젝트
```bash
# package.json 확인
cat package.json | grep version

# version.yml과 동일한 버전으로 설정
# package.json:
"version": "1.0.0"
```

#### React Native 프로젝트
```bash
# package.json, iOS, Android 버전 모두 확인
cat package.json | grep version
cat ios/*/Info.plist | grep -A1 CFBundleShortVersionString
cat android/app/build.gradle | grep versionName

# 모든 파일의 버전을 동일하게 설정
```

#### Python 프로젝트
```bash
# pyproject.toml 확인
cat pyproject.toml | grep version

# version.yml과 동일한 버전으로 설정
# pyproject.toml:
version = "1.0.0"
```

### 4단계: README 버전 표시 설정

README.md 파일 상단에 다음 형식을 **정확히** 추가:

```markdown
# 프로젝트 제목

<!-- 수정하지마세요 자동으로 동기화 됩니다 -->
## 최신 버전 : v1.0.0 (2025-01-01)

[나머지 README 내용...]
```

**⚠️ 주의사항:**
- 주석 `<!-- 수정하지마세요 자동으로 동기화 됩니다 -->` 필수
- `최신 버전 : v` 형식 정확히 지켜야 함
- 날짜는 `(YYYY-MM-DD)` 형식

---

## 🏢 Organization 설정 가이드

### Organization 저장소 필수 설정

Organization 저장소에서는 추가 설정이 필요합니다:

#### 1. Actions 설정
```
Organization Settings → Actions → General
├── ✅ Allow GitHub Actions to create and approve pull requests
├── ✅ Allow GitHub Actions to merge pull requests
└── ✅ Allow auto-merge
```

#### 2. Repository 설정
```
Repository Settings → General → Pull Requests
├── ✅ Allow auto-merge
├── ✅ Allow squash merging
├── ✅ Automatically delete head branches
└── ✅ Allow merge commits (선택사항)
```

#### 3. Member 권한 확인
```
Organization Settings → Member privileges
├── 🔧 Personal access token expiration policy: 조직 정책에 맞게 설정
├── ✅ Base permissions: Read (최소)
└── 📝 Third-party application access policy: 필요시 설정
```

---

## 🧪 테스트 및 검증

### 첫 번째 자동화 테스트

#### 1. 버전 자동 증가 테스트
```bash
# main 브랜치에 간단한 변경사항 커밋
echo "# 테스트" >> TEST.md
git add TEST.md
git commit -m "test: 자동화 테스트"
git push origin main
```

**예상 결과:**
- GitHub Actions에서 `PROJECT-VERSION-CONTROL` 워크플로우 실행
- 버전이 1.0.0 → 1.0.1로 자동 증가
- Git 태그 `v1.0.1` 자동 생성

#### 2. 체인지로그 생성 테스트
```bash
# deploy 브랜치로 PR 생성
git checkout -b feature/test-changelog
echo "# 체인지로그 테스트" >> TEST2.md
git add TEST2.md
git commit -m "feat: 체인지로그 테스트 기능"
git push origin feature/test-changelog

# GitHub에서 deploy 브랜치로 PR 생성
```

**예상 결과:**
- `PROJECT-AUTO-CHANGELOG-CONTROL` 워크플로우 실행
- CodeRabbit AI 리뷰 후 CHANGELOG.json, CHANGELOG.md 자동 생성
- PR 자동 머지

#### 3. README 업데이트 테스트
```bash
# deploy 브랜치에 직접 푸시 (PR 머지 후)
git checkout deploy
git pull origin deploy
git push origin deploy
```

**예상 결과:**
- `PROJECT-README-VERSION-UPDATE` 워크플로우 실행
- README.md의 버전 정보 자동 업데이트
- main과 deploy 브랜치 모두 동기화

---

## 🚨 문제 해결 가이드

### 자주 발생하는 문제와 해결책

#### 1. 워크플로우가 실행되지 않음
**증상:**
```
Actions 탭에 워크플로우가 나타나지 않음
```

**해결 방법:**
```bash
# 1. deploy 브랜치에 워크플로우 파일 존재 확인
git checkout deploy
ls -la .github/workflows/

# 2. 파일이 없다면 복사
git checkout main
cp -r .github/ ./
git checkout deploy
cp -r .github/ ./
git add .github/
git commit -m "Add missing workflow files"
git push origin deploy
```

#### 2. 토큰 권한 오류
**증상:**
```
remote: Permission to ... denied to github-actions[bot]
```

**해결 방법:**
1. 토큰이 **Classic** 타입인지 확인
2. `repo`, `workflow` 권한 모두 체크 확인
3. Organization 설정에서 PAT 정책 확인
4. 토큰 만료 날짜 확인

#### 3. 버전 파일 동기화 실패
**증상:**
```
Version conflict detected between files
```

**해결 방법:**
```bash
# 현재 모든 버전 파일 상태 확인
.github/scripts/version_manager.sh get

# 수동으로 동기화 실행
.github/scripts/version_manager.sh sync

# 특정 버전으로 강제 설정
.github/scripts/version_manager.sh set 1.0.0
```

#### 4. CodeRabbit 연동 실패
**증상:**
```
CodeRabbit summary not found
```

**해결 방법:**
1. `.coderabbit.yaml` 파일 확인
2. CodeRabbit이 저장소에 액세스 권한이 있는지 확인
3. PR에 충분한 변경사항이 있는지 확인

---

## 📊 성공 지표

### 설정 완료 확인 체크리스트

#### ✅ 자동화 기능 정상 작동
- [ ] main 브랜치 푸시 시 버전 자동 증가
- [ ] deploy 브랜치 PR 생성 시 체인지로그 자동 생성
- [ ] README 버전 정보 자동 업데이트
- [ ] Git 태그 자동 생성

#### ✅ 스크립트 정상 실행
- [ ] `version_manager.sh get` 명령어 정상 실행
- [ ] `changelog_manager.py generate-md` 명령어 정상 실행
- [ ] 모든 스크립트 실행 권한 설정 완료

#### ✅ 문서화 완료
- [ ] README에 버전 표시 영역 추가
- [ ] 프로젝트별 설정 사항 문서화
- [ ] 팀원 공유 및 교육 완료

---

## 🎯 다음 단계

### 개발 워크플로우 최적화
1. **브랜치 전략 수립**: feature → main → deploy 플로우 확립
2. **코드 리뷰 프로세스**: CodeRabbit AI 리뷰 활용
3. **릴리즈 사이클**: 정기적인 deploy 브랜치 배포

### 고급 기능 활용
1. **수동 빌드 실행**: `workflow_dispatch` 트리거 활용
2. **멀티 환경 배포**: 환경별 설정 파일 관리
3. **모니터링 설정**: 배포 상태 추적 및 알림

### 팀 협업 강화
1. **이슈 템플릿**: 일관된 이슈 생성 프로세스
2. **라벨 시스템**: 체계적인 이슈 분류
3. **자동화 교육**: 팀원 대상 자동화 시스템 교육

---

**🎉 축하합니다! 이제 완전 자동화된 DevOps 환경이 구축되었습니다.**

추가 질문이나 문제가 있다면 [이슈](https://github.com/Cassiiopeia/suh-github-template/issues/new/choose)를 생성해 주세요.