### 📌 작업 개요

`template_integrator`의 `--mode commands` 실행 시 대화형 메뉴(1~4번 선택)를 거치지 않고 `--target` 옵션으로 설치 대상을 CLI에서 직접 지정할 수 있는 기능 추가. `template_integrator.sh`(Linux/macOS)와 `template_integrator.ps1`(Windows) 양쪽에 동일하게 적용. 추가로 worktree 커스텀 커맨드의 오타 수정 포함.

### 🎯 구현 목표

- `--target` 옵션으로 `cursor`, `claude`, `all` 중 설치 대상을 CLI에서 직접 지정
- `--force`와 함께 사용 시 확인 절차 없이 바로 설치
- CI/CD 환경이나 빠른 설치가 필요한 경우 대화형 메뉴 없이 실행 가능

### ✅ 구현 내용

#### 1. `--target` CLI 옵션 추가 (Bash)
- **파일**: `template_integrator.sh`
- **변경 내용**:
  - `COMMAND_TARGET` 변수 및 `--target` 파라미터 파싱 로직 추가 (라인 415, 447~450)
  - `commands` 모드 실행 시 `COMMAND_TARGET`이 설정되어 있으면 대화형 메뉴 대신 `copy_custom_commands`에 직접 전달 (라인 2426~2427)
  - 도움말에 `--target TARGET` 옵션 설명 추가 (라인 333)
  - 사용 예시에 `--mode commands --target all --force` 추가 (라인 380)

#### 2. `-Target` CLI 옵션 추가 (PowerShell)
- **파일**: `template_integrator.ps1`
- **변경 내용**:
  - `param()` 블록에 `[string]$Target = ""` 파라미터 추가 (라인 81)
  - `commands` 모드 실행 시 `$Target`이 비어있지 않으면 `Copy-CustomCommands -Target $Target` 직접 호출 (라인 2330~2331)
  - 도움말에 `-Target <TARGET>` 옵션 설명 추가 (라인 326)
  - 사용 예시에 `-Mode commands -Target all -Force` 추가 (라인 370)

#### 3. worktree 커스텀 커맨드 오타 수정
- **파일**: `.claude/scripts/worktree_manager.py`, `.cursor/scripts/worktree_manager.py`
- **변경 내용**: 주석에서 `init-workflow` → `init-worktree`로 오타 수정 (라인 100)

#### 4. worktree 커스텀 커맨드 신규 추가
- **파일**: `.claude/commands/init-worktree.md`, `.cursor/commands/init-worktree.md`
- **변경 내용**: Git worktree 자동 생성 커맨드 파일 신규 추가 (165줄)
  - 브랜치명 입력 → worktree 생성 → 설정 파일 자동 복사 프로세스 정의
  - Windows/macOS/Linux 플랫폼 독립적 실행 지원

#### 5. Cursor scripts README 오타 수정
- **파일**: `.cursor/scripts/README.md`
- **변경 내용**: 사용 예시에서 `/init-workflow` → `/init-worktree`로 오타 수정

### 🔧 주요 변경사항 상세

#### `--target` 옵션 동작 흐름

```
--mode commands 실행
    ├─ --target 지정됨 → copy_custom_commands("cursor"|"claude"|"all") 직접 호출
    │   └─ --force 지정됨 → 확인 절차 없이 바로 설치
    └─ --target 미지정 → 기존 대화형 메뉴 (1~4번 선택) 표시
```

**지원 값**:
| `--target` 값 | 설치 대상 |
|---------------|----------|
| `cursor` | `.cursor` 폴더만 설치 |
| `claude` | `.claude` 폴더만 설치 |
| `all` | `.cursor` + `.claude` 모두 설치 |

**사용 예시**:
```bash
# Linux/macOS - Custom Command 모두 설치 (확인 없이)
./template_integrator.sh --mode commands --target all --force

# Windows PowerShell - Claude Code만 설치
.\template_integrator.ps1 -Mode commands -Target claude
```

### 🧪 테스트 및 검증

- `--target cursor` / `--target claude` / `--target all` 각각 실행하여 올바른 대상만 설치되는지 확인
- `--target all --force` 실행 시 확인 절차 없이 즉시 설치되는지 확인
- `--target` 미지정 시 기존 대화형 메뉴가 정상 동작하는지 확인 (하위 호환성)
- PowerShell(`-Target`)과 Bash(`--target`) 양쪽 동일하게 동작하는지 확인

### 📌 참고사항

- `--target` 옵션은 `--mode commands`에서만 유효. 다른 모드에서는 무시됨
- 기존 대화형 메뉴 방식은 그대로 유지되어 하위 호환성 보장
- `init-worktree` 커맨드는 `.claude/commands/`와 `.cursor/commands/`에 동일한 내용으로 추가됨
