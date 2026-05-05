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

Worktree 생성 성공 후 **Claude가 직접** 아래 절차를 실행하여 민감 파일을 복사한다.

#### 4-1. 소스/대상 경로 확정

- **소스(원본) 루트**: 현재 작업 중인 프로젝트 루트 (`git rev-parse --show-toplevel`로 확인)
- **대상(워크트리) 루트**: 3단계에서 확인한 `WORKTREE_PATH`

#### 4-2. .gitignore에서 복사 후보 추출

소스 루트의 `.gitignore`를 읽어 **"단순 경로/파일명"** 패턴만 후보로 추린다.

**포함 기준** (아래 조건을 모두 만족):
- `!`(negation) 접두어 없음
- 주석(`#`) 라인 아님
- 빈 줄 아님
- 패턴이 `**` glob을 포함하지 않는 단순 경로 또는 단순 확장자(`*.yml` 수준)

**즉시 제외 키워드** (패턴에 아래 문자열이 포함되면 스킵):
```
build/  target/  .gradle  node_modules  Pods/  .dart_tool
Generated  generate  .last_build_id  .framework  .flx  .zip
DerivedData  XCBuildData  .class  .pyc  .log  .symbols  .map.json
.pub-cache  .pub/  migrate_working_dir  .history  .svn  .swiftpm
bin/  out/  dist/  nbproject  .sts4-cache  .springBeans
```

#### 4-3. 실제 존재 파일 탐색

후보 패턴 각각에 대해 소스 루트에서 실제 파일 존재 여부 확인:

```bash
# 단순 경로 패턴 (예: android/key.properties)
ls [소스_루트]/[패턴]

# 와일드카드 패턴 (예: *.env, src/main/resources/application-*.yml)
find [소스_루트] -name "[패턴파일명부분]" \
  -not -path "*/build/*" \
  -not -path "*/target/*" \
  -not -path "*/.gradle/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/Pods/*" \
  -not -path "*/.dart_tool/*" \
  -not -path "*/*-Worktree/*" \
  -type f -size -1M
```

> `-size -1M`: 1MB 초과 파일은 민감 설정 파일이 아닐 가능성 높으므로 제외

#### 4-4. 경로 계산 및 복사 실행

탐색된 각 파일에 대해:

1. **상대 경로 계산**: `절대경로` → 소스 루트 기준 상대경로
2. **대상 경로** = `대상_루트` + `상대경로`
3. **복사**:
```bash
mkdir -p [대상_파일의_부모_디렉토리]
cp [소스_절대경로] [대상_절대경로]
```

#### 4-5. 복사 결과 검증

각 파일 복사 후 대상 경로 존재 확인. 결과를 `✅` / `❌`로 표시.

### 5단계: 결과 출력

```
✅ Worktree 생성 완료!
📍 경로: [worktree_path]
📋 복사된 파일:
  ✅ android/app/google-services.json
  ✅ ios/Runner/GoogleService-Info.plist

📝 커밋 메시지 템플릿:
{브랜치명에서 날짜·이슈번호·이모지·태그 제거한 순수 제목} : feat : {변경사항 설명} {이슈URL}
(작업 완료 후 /commit 으로 자동 커밋하세요)
```

## 브랜치명 처리 규칙

- `#` 문자: Git 브랜치명에서는 **원본 유지**, 폴더명에서만 `_`로 변환
- 특수문자: 폴더명 생성 시 `_`로 변환
- Worktree 위치: `{프로젝트명}-Worktree/` 폴더 (예: `RomRom-FE-Worktree`)

## 스크립트 위치

`worktree_manager.py`를 다음 순서로 탐색:
1. `scripts/worktree_manager.py`
