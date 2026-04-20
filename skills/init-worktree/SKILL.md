---
name: init-worktree
description: "Git Worktree 자동 생성 도구. 브랜치명을 입력받아 worktree를 생성하고 민감 파일을 자동 복사한다. worktree 생성, 브랜치 분리 작업, 독립 작업 환경 구성이 필요할 때 사용. /init-worktree 호출 시 사용."
---

# Git Worktree 자동 생성

브랜치명을 입력받아 **Git worktree를 자동 생성하고 민감 파일을 복사**하라.

## 사용자 입력

$ARGUMENTS

## 입력 없는 경우

사용법을 안내하라:
```
/init-worktree
20260120_#163_Github_Projects_에_대한_템플릿_개발_필요
```

## 실행 프로세스

### 1단계: 브랜치명 추출
- 사용자 입력에서 브랜치명 추출 (`#` 문자 포함 원본 유지)
- 브랜치명이 없으면 사용법 안내 후 종료

### 2단계: 환경 준비
```bash
# 프로젝트 루트로 이동
cd [프로젝트_루트]

# Git 긴 경로 지원 (Windows, 최초 1회)
git config --global core.longpaths true
```

### 3단계: 임시 Python 스크립트 생성 및 실행

**인코딩 문제 해결을 위해 브랜치명을 코드에 직접 포함**시킨 임시 파일을 생성한다.

파일명: `init_worktree_temp_{timestamp}.py`

```python
# -*- coding: utf-8 -*-
import sys, os, shutil, glob

os.chdir('프로젝트_루트_경로')

branch_name = '브랜치명_원본_그대로'

# worktree_manager 실행
sys.path.insert(0, 'scripts')  # 플러그인 루트 scripts/
import worktree_manager
os.environ['GIT_BRANCH_NAME'] = branch_name
os.environ['PYTHONIOENCODING'] = 'utf-8'
sys.argv = ['worktree_manager.py']
exit_code = worktree_manager.main()

if exit_code == 0:
    import subprocess
    result = subprocess.run(['git', 'worktree', 'list', '--porcelain'],
                            capture_output=True, text=True, encoding='utf-8')
    lines = result.stdout.split('\n')
    worktree_path = None
    for i, line in enumerate(lines):
        if line.startswith(f'branch refs/heads/{branch_name}'):
            worktree_path = lines[i-1].replace('worktree ', '')
            break
    if worktree_path:
        print(f'WORKTREE_PATH={worktree_path}')

sys.exit(exit_code)
```

**실행** (Windows에서는 `-X utf8` 필수):
```bash
python -X utf8 init_worktree_temp_{timestamp}.py
```

실행 후 임시 파일 삭제.

### 4단계: 민감 파일 복사

Worktree 생성 성공 후 `.gitignore`를 분석하여 민감 파일을 동적으로 복사한다.

**복사 대상 식별** (`.gitignore`에서):

| 카테고리 | 패턴 |
|---------|------|
| Firebase | `google-services.json`, `GoogleService-Info.plist` |
| 서명 키 | `key.properties`, `*.jks`, `*.p12`, `*.p8`, `*.mobileprovision` |
| 빌드 설정 | `Secrets.xcconfig`, 민감한 `*.xcconfig` |
| 환경 변수 | `*.env` |
| IDE 로컬 | `settings.local.json` |

**복사 규칙**:
- 실제 존재하는 파일만 복사
- 디렉토리 구조 유지 (`android/app/google-services.json` → `worktree/android/app/google-services.json`)

**절대 복사 금지**:
- `build/`, `target/`, `.gradle/` (빌드 산출물)
- `node_modules/`, `Pods/`, `.dart_tool/` (의존성)
- `.report/`, `.run/`, `.idea/` (캐시)
- `*.log`, `*.class`, `*.pyc` (임시 파일)

### 5단계: 이슈 컨텍스트 저장

브랜치명에서 이슈 번호를 추출하고, 이슈 컨텍스트를 저장한다.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
BRANCH_NAME="{브랜치명}"

# 브랜치명에서 이슈 번호 추출 (YYYYMMDD_#123_제목 형식)
ISSUE_NUMBER=$(echo "$BRANCH_NAME" | grep -oP '(?<=#)\d+' || echo "")

if [ -n "$ISSUE_NUMBER" ]; then
  mkdir -p "$PROJECT_ROOT/.suh-template/context"
  # 이슈 정보 조회 (config가 있는 경우)
  COMMIT_TEMPLATE=$(PYTHONPATH="$PROJECT_ROOT/scripts" $PYTHON -m suh_template.cli get-commit-template "$BRANCH_NAME" "" 2>/dev/null || echo "$BRANCH_NAME : feat : {설명}")
  cat > "$PROJECT_ROOT/.suh-template/context/current-issue.json" << CTXEOF
{
  "issue_number": $ISSUE_NUMBER,
  "issue_title": "$BRANCH_NAME",
  "branch_name": "$BRANCH_NAME",
  "commit_template": "$BRANCH_NAME : feat : {설명}"
}
CTXEOF
fi
```

> 이슈 URL이 없는 경우(직접 브랜치명 입력) commit_template에 URL을 생략한다.

### 6단계: 결과 출력

```
✅ Worktree 생성 완료!
📍 경로: [worktree_path]
📋 복사된 파일:
  ✅ android/app/google-services.json
  ✅ ios/Runner/GoogleService-Info.plist

📝 커밋 메시지 템플릿:
{브랜치명} : feat : {변경사항 설명}
(작업 완료 후 /commit 으로 자동 커밋하세요)
```

## 브랜치명 처리 규칙

- `#` 문자: Git 브랜치명에서는 **원본 유지**, 폴더명에서만 `_`로 변환
- 특수문자: 폴더명 생성 시 `_`로 변환
- Worktree 위치: `{프로젝트명}-Worktree/` 폴더 (예: `RomRom-FE-Worktree`)

## 스크립트 위치

`worktree_manager.py`를 다음 순서로 탐색:
1. `scripts/worktree_manager.py`
