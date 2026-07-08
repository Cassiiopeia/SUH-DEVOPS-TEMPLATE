# 🤝 기여 가이드라인

projectops(구 SUH-DEVOPS-TEMPLATE) 프로젝트에 기여해주셔서 감사합니다! 이 문서는 기여자들이 프로젝트에 효과적으로 참여할 수 있도록 안내합니다.

---

## 📋 목차

1. [시작하기 전에](#시작하기-전에)
2. [개발 환경 설정](#개발-환경-설정)
3. [코드 스타일 가이드](#코드-스타일-가이드)
4. [브랜치 전략](#브랜치-전략)
5. [커밋 메시지 규칙](#커밋-메시지-규칙)
6. [테스트 작성](#테스트-작성)
7. [Pull Request 프로세스](#pull-request-프로세스)
8. [이슈 생성 및 관리](#이슈-생성-및-관리)
9. [문서 작성](#문서-작성)
10. [릴리즈 프로세스](#릴리즈-프로세스)

---

## 시작하기 전에

### 기여하기 전 체크리스트
- [ ] [이슈 목록](https://github.com/Cassiiopeia/suh-github-template/issues)을 확인하여 중복된 이슈가 없는지 확인
- [ ] 새로운 기능을 제안하려면 먼저 이슈를 생성하여 논의
- [ ] 프로젝트 구조와 워크플로우를 이해
- [ ] 개발 환경 설정 완료

### 기여 가능한 영역
- 🐛 **버그 수정**: 발견한 버그를 수정하고 테스트 추가
- ✨ **새로운 기능**: 새로운 프로젝트 타입 지원, 워크플로우 개선
- 📝 **문서 개선**: 오타 수정, 예제 추가, 번역
- 🎨 **코드 개선**: 리팩토링, 성능 최적화
- 🧪 **테스트 추가**: 테스트 커버리지 향상

---

## 개발 환경 설정

### 필수 소프트웨어

#### 1. Git 설치
```bash
# macOS
brew install git

# Linux (Ubuntu/Debian)
sudo apt install git

# 설치 확인
git --version
# git version 2.40.0 이상 권장
```

#### 2. Bash Shell
```bash
# macOS / Linux (기본 설치됨)
bash --version
# GNU bash, version 4.0 이상 필요

# macOS에서 최신 bash 설치 (선택)
brew install bash
```

#### 3. Python 3
```bash
# macOS
brew install python3

# Linux (Ubuntu/Debian)
sudo apt install python3 python3-pip

# 설치 확인
python3 --version
# Python 3.6 이상 필요
```

#### 4. GitHub CLI (권장)
```bash
# macOS
brew install gh

# Linux
sudo apt install gh

# 인증
gh auth login

# 설치 확인
gh --version
```

---

### 프로젝트 클론 및 설정

```bash
# 1. 리포지토리 포크
# GitHub에서 Fork 버튼 클릭

# 2. 포크한 리포지토리 클론
git clone https://github.com/YOUR-USERNAME/suh-github-template.git
cd suh-github-template

# 3. 원본 리포지토리를 upstream으로 추가
git remote add upstream https://github.com/Cassiiopeia/suh-github-template.git

# 4. 리모트 확인
git remote -v
# origin    https://github.com/YOUR-USERNAME/suh-github-template.git (fetch)
# origin    https://github.com/YOUR-USERNAME/suh-github-template.git (push)
# upstream  https://github.com/Cassiiopeia/suh-github-template.git (fetch)
# upstream  https://github.com/Cassiiopeia/suh-github-template.git (push)

# 5. 스크립트 실행 권한 부여
chmod +x .github/scripts/*.sh
chmod +x template_initializer.sh

# 6. 최신 상태로 업데이트
git fetch upstream
git merge upstream/main
```

---

### 로컬 테스트 환경 구축

#### 테스트용 리포지토리 생성
```bash
# 1. GitHub에서 테스트용 빈 리포지토리 생성
# 예: test-suh-template

# 2. 로컬에 테스트 디렉토리 생성
mkdir -p ~/test-projects/test-suh-template
cd ~/test-projects/test-suh-template

# 3. Git 초기화
git init
git remote add origin https://github.com/YOUR-USERNAME/test-suh-template.git

# 4. 개발 중인 스크립트 복사
cp -r ~/suh-github-template/.github ./
cp ~/suh-github-template/template_initializer.sh ./

# 5. 테스트 실행
./template_initializer.sh -v 1.0.0 -t basic

# 6. 결과 확인
cat version.yml
```

---

## 코드 스타일 가이드

### Bash 스크립트 컨벤션

#### 파일 구조
```bash
#!/bin/bash

# ===================================================================
# 스크립트 제목 및 설명
# ===================================================================
#
# 상세 설명
#
# 사용법:
#   ./script.sh [옵션]
#
# 예시:
#   ./script.sh --version 1.0.0
# ===================================================================

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 출력 함수
print_step() {
    echo -e "${CYAN}▶${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}✓${NC} $1" >&2
}

# 메인 함수
main() {
    # 구현
}

# 스크립트 실행
main "$@"
```

#### 네이밍 규칙
```bash
# ✅ 좋은 예시
function_name() { ... }           # 함수: snake_case
CONSTANT_VALUE="value"            # 상수: UPPER_SNAKE_CASE
local_variable="value"            # 변수: snake_case

# ❌ 나쁜 예시
FunctionName() { ... }            # camelCase 사용 금지
constantValue="value"             # 상수는 대문자
LocalVariable="value"             # PascalCase 사용 금지
```

#### 주석 스타일
```bash
# 한 줄 주석: 코드 위에 작성

# 여러 줄 설명이 필요한 경우
# 각 줄마다 # 사용
# 문단 구분은 빈 줄로

# 함수 주석
# 설명: 버전을 증가시킵니다
# 파라미터: $1 - 현재 버전
# 반환값: 증가된 버전
increment_version() {
    local current=$1
    # 구현
}
```

#### 에러 처리
```bash
# ✅ 좋은 예시
validate_version() {
    local version=$1
    
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "잘못된 버전 형식: $version"
        print_error "올바른 형식: x.y.z (예: 1.0.0)"
        exit 1
    fi
}

# 파일 존재 확인
if [ ! -f "version.yml" ]; then
    print_error "version.yml 파일을 찾을 수 없습니다!"
    exit 1
fi

# 명령어 실행 결과 확인
if ! command -v gh >/dev/null 2>&1; then
    print_warning "GitHub CLI가 설치되지 않았습니다"
    # 대체 방법 시도
fi
```

---

### Python 스크립트 스타일

#### 기본 구조
```python
#!/usr/bin/env python3
"""
스크립트 제목

상세 설명

사용 예시:
    python3 script.py command --option value
"""

import sys
import json
from typing import Dict, List, Optional

# 상수
DEFAULT_VERSION = "0.0.0"
CHANGELOG_FILE = "CHANGELOG.json"

def main():
    """메인 함수"""
    pass

if __name__ == "__main__":
    main()
```

#### 함수 작성
```python
def parse_version(version_string: str) -> Dict[str, int]:
    """
    버전 문자열을 파싱하여 딕셔너리로 반환합니다.
    
    Args:
        version_string: "x.y.z" 형식의 버전 문자열
    
    Returns:
        {'major': x, 'minor': y, 'patch': z} 형태의 딕셔너리
    
    Raises:
        ValueError: 버전 형식이 올바르지 않은 경우
    
    Example:
        >>> parse_version("1.2.3")
        {'major': 1, 'minor': 2, 'patch': 3}
    """
    parts = version_string.split('.')
    if len(parts) != 3:
        raise ValueError(f"잘못된 버전 형식: {version_string}")
    
    return {
        'major': int(parts[0]),
        'minor': int(parts[1]),
        'patch': int(parts[2])
    }
```

---

### YAML 워크플로우 작성

#### 기본 구조
```yaml
# 워크플로우 이름
name: 워크플로우 제목

# 트리거 조건
on:
  push:
    branches: ["main"]
    paths-ignore:
      - '*.md'
      - 'docs/**'

# 환경 변수
env:
  VARIABLE_NAME: value

# 작업 정의
jobs:
  job-name:
    runs-on: ubuntu-latest
    
    steps:
      - name: 단계 이름
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: 스크립트 실행
        run: |
          echo "명령어 실행"
```

#### 네이밍 규칙
```yaml
# 워크플로우 파일명: PROJECT-FEATURE-NAME.yaml
# 예시:
# - PROJECT-VERSION-CONTROL.yaml
# - PROJECT-AUTO-CHANGELOG-CONTROL.yaml

# Job 이름: kebab-case
jobs:
  version-bump:        # ✅
  update-changelog:    # ✅
  VersionBump:         # ❌
  update_changelog:    # ❌
```

#### 멀티타입 지원

`version.yml`에 `project_types` 배열 키가 도입되어 단일 레포에 여러 타입이 공존할 수 있습니다. 워크플로우/스크립트를 추가·수정할 때 다음을 지킵니다.

- **배열 우선 읽기**: 타입에 따라 분기하는 새 코드는 단수 `project_type`이 아닌 `project_types` 배열을 우선 읽고 순회합니다.
- **자동 미러 유지**: 단수 `project_type` 키는 항상 `project_types[0]`으로 자동 미러되므로 직접 수정하지 않습니다.
- **하위 호환 보장**: 단수 키만 읽던 기존 코드도 그대로 동작해야 합니다 (`project_types`가 없으면 단수 키로 폴백).

---

## 브랜치 전략

### 브랜치 구조

```
main (기본·프로덕션 브랜치)
└── develop (개발 통합 브랜치)
    ├── feature/기능명        # 새로운 기능 개발
    ├── bugfix/버그명         # 버그 수정
    ├── hotfix/긴급수정명     # 긴급 버그 수정
    ├── docs/문서명           # 문서 작성/수정
    ├── refactor/리팩토링명   # 코드 리팩토링
    └── test/테스트명         # 테스트 추가
```

feature/bugfix 등 작업 브랜치는 `develop`으로 PR을 올려 통합하고, `develop`이 안정화되면 `develop → main` 릴리스 PR로 배포합니다.

### 브랜치 네이밍 규칙

```bash
# 기능 개발
feature/dynamic-branch-detection
feature/flutter-support

# 버그 수정
bugfix/version-sync-error
bugfix/workflow-trigger-issue

# 긴급 수정
hotfix/critical-security-fix
hotfix/production-crash

# 문서
docs/scripts-guide
docs/contributing-update

# 리팩토링
refactor/version-manager-cleanup
refactor/improve-error-handling

# 테스트
test/integration-tests
test/version-manager-unit-tests
```

### 브랜치 생성 및 작업 플로우

```bash
# 1. 최신 develop 브랜치로 업데이트
git checkout develop
git pull upstream develop

# 2. 새 브랜치 생성
git checkout -b feature/new-feature

# 3. 작업 진행 및 커밋
# ... 코드 수정 ...
git add .
git commit -m "feat: 새로운 기능 추가"

# 4. 원격 브랜치에 푸시
git push origin feature/new-feature

# 5. GitHub에서 develop 대상 Pull Request 생성

# 6. 리뷰 및 수정 반영
# ... 코드 수정 ...
git commit -m "fix: 리뷰 반영"
git push origin feature/new-feature

# 7. PR 승인 및 머지 후 브랜치 삭제
git checkout develop
git pull upstream develop
git branch -d feature/new-feature
```

> 릴리스는 `develop → main` Pull Request로만 진행합니다 (`/cassiiopeia:suh-changelog-deploy`). 버전 확정, AI 체인지로그 생성, automerge가 이 PR에서 자동 처리됩니다.

---

## 커밋 메시지 규칙

### Conventional Commits 사용

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 종류

| Type | 설명 | 예시 |
|------|------|------|
| `feat` | 새로운 기능 추가 | `feat: 동적 브랜치 감지 기능 추가` |
| `fix` | 버그 수정 | `fix: Flutter 버전 형식 오류 수정` |
| `docs` | 문서 수정 | `docs: SCRIPTS_GUIDE.md 작성` |
| `style` | 코드 포맷팅 (기능 변경 없음) | `style: 들여쓰기 수정` |
| `refactor` | 코드 리팩토링 | `refactor: 버전 동기화 로직 개선` |
| `test` | 테스트 추가/수정 | `test: version_manager 단위 테스트 추가` |
| `chore` | 빌드 프로세스, 도구 설정 등 | `chore: bump version to 1.3.0` |
| `perf` | 성능 개선 | `perf: 버전 파싱 속도 개선` |
| `ci` | CI/CD 설정 수정 | `ci: GitHub Actions 워크플로우 추가` |

### 커밋 메시지 예시

#### ✅ 좋은 예시
```bash
feat: 동적 브랜치 감지 시스템 추가

GitHub CLI, git 명령어를 활용한 3단계 폴백 메커니즘 구현.
main, master, develop 등 다양한 기본 브랜치 자동 감지.

Closes #69
```

```bash
fix: Flutter 버전 형식 오류 수정

pubspec.yaml에 version+buildNumber 형식으로 저장되도록 수정.
이전에는 version만 저장되어 빌드 번호가 누락되는 문제 있었음.

Related to #71
```

```bash
docs: SCRIPTS_GUIDE.md 통합 문서 작성

VERSION_MANAGER_README.md 내용 확장하여 통합 가이드 작성.
- version_manager.sh 상세 사용법
- template_initializer.sh v2.0 기능 설명
- changelog_manager.py 사용법 추가
```

#### ❌ 나쁜 예시
```bash
update  # type과 subject 구분 없음, 설명 불충분

fixed bug  # 어떤 버그인지 불명확

WIP  # 임시 커밋 메시지
```

### 커밋 메시지 작성 팁

1. **제목은 50자 이내**
2. **제목과 본문 사이 빈 줄**
3. **본문은 72자마다 줄바꿈**
4. **명령형 현재 시제 사용** ("추가함" ❌ → "추가" ✅)
5. **"무엇을" 보다 "왜" 에 집중**
6. **관련 이슈 번호 참조**

---

## 테스트 작성

### 단위 테스트

#### Bash 스크립트 테스트
```bash
# test_version_manager.sh

#!/bin/bash

# 테스트 프레임워크 (간단한 assert 함수)
assert_equals() {
    local expected=$1
    local actual=$2
    local message=$3
    
    if [ "$expected" == "$actual" ]; then
        echo "✅ PASS: $message"
        return 0
    else
        echo "❌ FAIL: $message"
        echo "   Expected: $expected"
        echo "   Actual:   $actual"
        return 1
    fi
}

# 테스트 케이스
test_increment_version() {
    # Setup
    echo 'version: "1.0.0"' > version.yml
    echo 'project_type: "basic"' >> version.yml
    
    # Execute
    result=$(./version_manager.sh increment)
    
    # Verify
    assert_equals "1.0.1" "$result" "Patch 버전 증가"
    
    # Cleanup
    rm version.yml
}

# 테스트 실행
test_increment_version
```

#### Python 스크립트 테스트
```python
# test_changelog_manager.py

import unittest
from changelog_manager import parse_version, increment_patch

class TestChangelogManager(unittest.TestCase):
    
    def test_parse_version(self):
        """버전 파싱 테스트"""
        result = parse_version("1.2.3")
        self.assertEqual(result['major'], 1)
        self.assertEqual(result['minor'], 2)
        self.assertEqual(result['patch'], 3)
    
    def test_increment_patch(self):
        """Patch 버전 증가 테스트"""
        result = increment_patch("1.2.3")
        self.assertEqual(result, "1.2.4")
    
    def test_invalid_version(self):
        """잘못된 버전 형식 테스트"""
        with self.assertRaises(ValueError):
            parse_version("1.2")

if __name__ == '__main__':
    unittest.main()
```

---

### 통합 테스트

#### 전체 워크플로우 테스트
```bash
# integration_test.sh

#!/bin/bash
set -e

echo "=== 통합 테스트 시작 ==="

# 1. 템플릿 초기화 테스트
echo "1. 템플릿 초기화..."
./template_initializer.sh -v 1.0.0 -t basic

# 2. version.yml 검증
if [ ! -f "version.yml" ]; then
    echo "❌ version.yml 생성 실패"
    exit 1
fi
echo "✅ version.yml 생성 성공"

# 3. 버전 증가 테스트
echo "2. 버전 증가..."
new_version=$(./version_manager.sh increment)
if [ "$new_version" != "1.0.1" ]; then
    echo "❌ 버전 증가 실패: $new_version"
    exit 1
fi
echo "✅ 버전 증가 성공"

# 4. 버전 동기화 테스트
echo "3. 버전 동기화..."
./version_manager.sh sync
echo "✅ 버전 동기화 성공"

echo "=== 통합 테스트 완료 ✅ ==="
```

---

### 테스트 실행 방법

```bash
# 단위 테스트 실행
bash test/test_version_manager.sh
python3 test/test_changelog_manager.py

# 통합 테스트 실행
bash test/integration_test.sh

# 모든 테스트 실행
bash test/run_all_tests.sh
```

---

### 테스트 작성 가이드

#### 테스트 네이밍
```bash
# 함수명: test_<테스트_대상>_<시나리오>
test_increment_version_patch()       # ✅
test_parse_version_invalid_format()  # ✅
testFunction()                        # ❌
```

#### 테스트 구조 (AAA 패턴)
```bash
test_example() {
    # Arrange (준비)
    local input="1.0.0"
    
    # Act (실행)
    local result=$(increment_version "$input")
    
    # Assert (검증)
    assert_equals "1.0.1" "$result" "버전 증가"
}
```

#### 테스트 데이터 정리
```bash
# Setup
setup() {
    mkdir -p test_dir
    cd test_dir
}

# Teardown
teardown() {
    cd ..
    rm -rf test_dir
}

# 테스트
test_example() {
    setup
    # 테스트 로직
    teardown
}
```

---

## Pull Request 프로세스

### PR 생성 전 체크리스트
- [ ] 최신 main 브랜치와 동기화
- [ ] 모든 테스트 통과
- [ ] 린터 경고 없음
- [ ] 커밋 메시지 규칙 준수
- [ ] 관련 문서 업데이트
- [ ] CHANGELOG.md 확인 (자동 생성)

### PR 제목 규칙

```
<type>: <간단한 설명>

예시:
feat: 동적 브랜치 감지 시스템 추가
fix: Flutter 버전 형식 오류 수정
docs: SCRIPTS_GUIDE.md 통합 문서 작성
```

### PR 템플릿

```markdown
## 📝 변경 사항 요약
<!-- 무엇을 변경했는지 간단히 설명 -->

## 🎯 변경 이유
<!-- 왜 이 변경이 필요한지 설명 -->

## 🔍 변경 내용 상세
<!-- 구체적인 변경 사항 나열 -->
- 변경사항 1
- 변경사항 2

## 🧪 테스트
<!-- 어떻게 테스트했는지 설명 -->
- [ ] 단위 테스트 추가/수정
- [ ] 통합 테스트 실행
- [ ] 수동 테스트 완료

## 📸 스크린샷 (해당시)
<!-- 이미지나 GIF 첨부 -->

## 📚 관련 이슈
Closes #이슈번호
Related to #이슈번호

## ✅ 체크리스트
- [ ] 코드 스타일 가이드 준수
- [ ] 모든 테스트 통과
- [ ] 문서 업데이트 완료
- [ ] 커밋 메시지 규칙 준수
```

### CodeRabbit AI 리뷰

PR을 생성하면 CodeRabbit AI가 자동으로 리뷰를 수행합니다:

1. **자동 리뷰**: 코드 분석 및 개선 제안
2. **체인지로그 생성**: 리뷰 내용 기반 CHANGELOG 자동 생성
3. **PR 제목 포맷팅**: 일관된 형식으로 자동 변경

### PR 머지 기준

✅ **머지 가능 조건**:
- 모든 CI 체크 통과
- 최소 1명의 승인 (maintainer)
- 충돌 없음
- CodeRabbit 리뷰 완료

❌ **머지 불가 조건**:
- 테스트 실패
- 린터 에러 존재
- 문서 누락
- 코드 스타일 불일치

---

## 이슈 생성 및 관리

### 이슈 템플릿

#### 버그 리포트
```markdown
---
name: 버그 리포트
about: 버그를 발견하셨나요? 자세한 내용을 알려주세요
title: '[BUG] '
labels: bug
assignees: ''
---

**버그 설명**
명확하고 간결한 버그 설명

**재현 방법**
1. '...'로 이동
2. '...'를 클릭
3. 아래로 스크롤
4. 에러 발생

**예상 동작**
예상했던 동작 설명

**실제 동작**
실제로 발생한 동작 설명

**스크린샷**
해당되는 경우 스크린샷 추가

**환경**
- OS: [예: macOS 14.0]
- 브라우저: [예: Chrome 120]
- 버전: [예: v1.3.0]

**추가 정보**
기타 추가 정보
```

#### 기능 제안
```markdown
---
name: 기능 제안
about: 새로운 기능을 제안합니다
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

**문제점**
현재 어떤 문제가 있나요?

**해결 방안**
어떤 기능을 원하시나요?

**대안**
고려한 대안이 있나요?

**추가 정보**
기타 추가 정보
```

### 이슈 라벨 시스템

| 라벨 | 설명 | 색상 |
|------|------|------|
| `bug` | 버그 | 🔴 Red |
| `enhancement` | 새로운 기능 | 🟢 Green |
| `documentation` | 문서 관련 | 🔵 Blue |
| `good first issue` | 처음 기여하기 좋은 이슈 | 🟣 Purple |
| `help wanted` | 도움 필요 | 🟡 Yellow |
| `question` | 질문 | 🟠 Orange |
| `wontfix` | 수정하지 않음 | ⚪ White |
| `duplicate` | 중복 이슈 | ⚫ Black |

---

## 문서 작성

### 문서화 대상

1. **코드 주석**: 모든 공개 함수/변수
2. **README.md**: 프로젝트 개요 및 빠른 시작
3. **가이드 문서**: 상세 사용법 (SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 등)
4. **아키텍처 문서**: 시스템 구조 설명

### 마크다운 스타일

#### 제목 계층
```markdown
# H1: 문서 제목 (페이지당 1개)
## H2: 주요 섹션
### H3: 하위 섹션
#### H4: 세부 항목
```

#### 코드 블록
```markdown
​```bash
# Bash 코드 (언어 명시 필수)
./script.sh --version 1.0.0
​```

​```python
# Python 코드
def hello():
    print("Hello, World!")
​```
```

#### 테이블
```markdown
| 열1 | 열2 | 열3 |
|-----|-----|-----|
| 값1 | 값2 | 값3 |
```

#### 이모지 사용
```markdown
✅ 성공
❌ 실패
⚠️ 경고
📝 문서
🔧 설정
🐛 버그
✨ 기능
```

---

## 릴리즈 프로세스

### 버전 번호 규칙 (Semantic Versioning)

```
MAJOR.MINOR.PATCH

예: 1.3.0

- MAJOR: 호환되지 않는 API 변경
- MINOR: 하위 호환되는 기능 추가
- PATCH: 하위 호환되는 버그 수정
```

### 릴리즈 절차

```bash
# 1. develop 브랜치에서 릴리즈 브랜치 생성
git checkout develop
git checkout -b release/v1.3.0

# 2. 버전 업데이트
./version_manager.sh set 1.3.0

# 3. CHANGELOG 확인 및 정리
# (자동 생성된 CHANGELOG.md 검토)

# 4. 커밋 및 푸시
git add .
git commit -m "chore: release v1.3.0"
git push origin release/v1.3.0

# 5. GitHub에서 PR 생성 (base: main)
# 6. 리뷰 및 승인
# 7. main 브랜치로 머지

# 8. main 브랜치에서 태그 생성
git checkout main
git pull origin main
git tag -a v1.3.0 -m "Release v1.3.0"
git push origin v1.3.0

# 9. GitHub에서 Release 생성
gh release create v1.3.0 \
  --title "v1.3.0" \
  --notes-file release_notes.md

# 10. develop 브랜치에 변경사항 머지
git checkout develop
git merge main
git push origin develop
```

---

## 질문이나 도움이 필요하신가요?

### 지원 채널

- 📧 **이메일**: chan4760@naver.com
- 🎫 **GitHub Issues**: [이슈 생성](https://github.com/Cassiiopeia/suh-github-template/issues)
- 💬 **Discussions**: [토론 참여](https://github.com/Cassiiopeia/suh-github-template/discussions)

### 응답 시간
평균 24시간 이내 응답을 목표로 합니다.

---

## 라이선스

이 프로젝트에 기여함으로써, 귀하는 귀하의 기여가 프로젝트의 MIT 라이센스 하에 배포됨에 동의합니다.

자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

---

## 감사 인사

이 프로젝트에 기여해주신 모든 분들께 감사드립니다! 🙏

<!-- ALL-CONTRIBUTORS-LIST:START -->
<!-- 기여자 목록은 all-contributors가 자동으로 업데이트합니다 -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

**📌 이 문서는 projectops(구 SUH-DEVOPS-TEMPLATE) v1.3.0 기준으로 작성되었습니다.**  
**📅 최종 업데이트: 2025년 10월 11일**  
**✍️ 작성자: projectops 팀**
