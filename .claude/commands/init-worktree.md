# init-worktree

Git worktree를 자동으로 생성하는 커맨드입니다.

브랜치명을 입력받아 자동으로:
1. 브랜치명에서 `#` 문자 제거 (Git 브랜치명으로 사용)
2. 브랜치가 없으면 리모트(origin) 확인 → 있으면 tracking 브랜치로 가져오기, 없으면 현재 브랜치에서 새로 생성
3. 브랜치명의 특수문자를 `_`로 변환하여 폴더명 생성
4. `{프로젝트명}-Worktree` 폴더에 worktree 생성 (예: `RomRom-FE-Worktree`)
5. 설정 파일 자동 복사 (Firebase, iOS, Android 키 등)
6. 이미 존재하면 경로만 출력

## 사용법

```
/init-worktree

20260120_#163_Github_Projects_에_대한_템플릿_개발_필요_및_관련_Sync_워크플로우_개발_필요
```

## 실행 로직

1. 사용자 입력에서 두 번째 줄의 브랜치명 추출
2. 브랜치명에서 `#` 문자 제거
3. 임시 Python 스크립트 파일 생성 (인코딩 문제 해결)
4. Python 스크립트 실행 (worktree 생성 + 설정 파일 복사)
5. 임시 파일 자동 삭제
6. 결과 출력

---

사용자 입력에서 두 번째 줄을 추출하여 브랜치명으로 사용하세요.

브랜치명이 제공되지 않은 경우:
- 사용법을 안내하세요.

브랜치명이 제공된 경우:
1. 프로젝트 루트로 이동
2. Git 긴 경로 지원 활성화: `git config --global core.longpaths true` (최초 1회만 실행)
3. 임시 Python 스크립트 파일 생성:
    - 파일명: `init_worktree_temp_{timestamp}.py`
    - 브랜치명을 코드에 직접 포함 (인코딩 문제 해결, `#` 문자 유지)
    - worktree 생성 로직 포함
4. **Python 스크립트 실행** (Windows에서는 `-X utf8` 플래그 필수):
   ```bash
   python -X utf8 init_worktree_temp_{timestamp}.py
   ```
5. 임시 파일 삭제
6. 결과 출력
7. 에이전트가 `.gitignore` 분석 후 민감 파일 복사

**중요**:
- **브랜치명 처리**: 브랜치명은 `#` 문자를 포함하여 **원본 그대로** 전달됩니다. `#`은 **폴더명 생성 시에만** `_`로 변환됩니다.
- **인코딩 문제 해결**: Python 스크립트 파일에 브랜치명을 직접 포함시켜 Windows PowerShell 인코딩 문제 회피
- **Windows UTF-8 모드**: Python 실행 시 `-X utf8` 플래그 사용 필수
- **설정 파일 자동 복사**: worktree 생성 후 에이전트가 동적으로 파일 복사
- **플랫폼 독립성**: Windows/macOS/Linux 모두 동일한 방식으로 처리

**실행 예시**:
```powershell
# Windows PowerShell
cd d:\0-suh\project\RomRom-FE
git config --global core.longpaths true

# Python UTF-8 모드로 실행 (Windows 한글 인코딩 문제 해결)
python -X utf8 init_worktree_temp.py

# 브랜치명: 20260116_#432_UX_개선_및_페이지_디자인_수정
# → Git 브랜치: 20260116_#432_UX_개선_및_페이지_디자인_수정 (# 유지)
# → 폴더명: 20260116_432_UX_개선_및_페이지_디자인_수정 (# → _ 변환)
```

**Python 스크립트 구조**:
```python
# -*- coding: utf-8 -*-
import sys
import os
import shutil
import glob

# 프로젝트 루트로 이동
os.chdir('프로젝트_루트_경로')

# 브랜치명 (원본 그대로, # 유지)
branch_name = '20260116_#432_UX_개선_및_페이지_디자인_수정'

# worktree_manager 실행
sys.path.insert(0, '.cursor/scripts')
import worktree_manager
os.environ['GIT_BRANCH_NAME'] = branch_name
os.environ['PYTHONIOENCODING'] = 'utf-8'
sys.argv = ['worktree_manager.py']
exit_code = worktree_manager.main()

# worktree 경로를 환경변수로 설정 (에이전트가 파일 복사에 사용)
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
    print(f'📍 WORKTREE_PATH={worktree_path}')

sys.exit(exit_code)
```

## 설정 파일 복사 (에이전트 동적 판단)

Worktree 생성 성공 후, **에이전트가 `.gitignore`를 분석하여 민감 파일을 동적으로 판단**하고 복사합니다.

### Step 1: .gitignore 분석

프로젝트 `.gitignore` 파일을 읽고 다음 카테고리의 민감 파일 패턴을 식별합니다:

| 카테고리 | 식별 패턴 | 설명 |
|---------|----------|------|
| Firebase 설정 | `google-services.json`, `GoogleService-Info.plist` | Firebase 연동 설정 |
| 서명 키/인증서 | `key.properties`, `*.jks`, `*.p12`, `*.p8`, `*.mobileprovision` | 앱 서명 인증서 |
| 빌드 설정 | `Secrets.xcconfig`, 민감한 `*.xcconfig` | iOS 빌드 비밀 설정 |
| 환경 변수 | `*.env` | 환경별 설정 파일 |
| IDE 로컬 설정 | `settings.local.json` | Claude/Cursor 로컬 설정 |

### Step 2: 실제 파일 확인 및 복사

1. `.gitignore`에 명시된 패턴 중 **실제 존재하는 파일** 확인
2. 존재하는 파일만 worktree 경로로 복사
3. 디렉토리 구조 유지 (예: `android/app/google-services.json` → `worktree/android/app/google-services.json`)

**복사 명령 예시**:
```bash
# Python shutil 사용
import shutil
shutil.copy2('원본경로', 'worktree경로/원본경로')
```

### Step 3: 복사 제외 대상 (절대 복사 금지)

다음은 민감 파일이더라도 **절대 복사하지 않습니다**:

| 경로/패턴 | 이유 |
|----------|------|
| `build/`, `target/`, `.gradle/` | 빌드 산출물 (새로 빌드 필요) |
| `node_modules/`, `Pods/`, `.dart_tool/` | 의존성 (새로 설치 필요) |
| `.report/`, `.run/` | 보고서 (worktree별로 별도 생성) |
| `.idea/` | IDE 캐시 전체 |
| `*.log`, `*.class`, `*.pyc` | 임시/컴파일 파일 |

### Step 4: 결과 출력

복사된 파일 목록을 ✅ 이모지와 함께 출력합니다:
```
✅ android/app/google-services.json 복사 완료
✅ ios/Runner/GoogleService-Info.plist 복사 완료
✅ android/key.properties 복사 완료
```

**참고**:
- 파일이 존재하지 않으면 해당 복사는 자동으로 건너뜁니다.
- 에이전트가 `.gitignore`를 분석하여 복사 대상을 동적으로 결정합니다.
