# init-workflow

Git worktree를 자동으로 생성하는 커맨드입니다.

브랜치명을 입력받아 자동으로:
1. 브랜치가 없으면 생성 (현재 브랜치에서 분기)
2. 브랜치명의 특수문자를 `_`로 변환하여 폴더명 생성
3. `{프로젝트명}-Worktree` 폴더에 worktree 생성 (예: `RomRom-FE-Worktree`)
4. 이미 존재하면 경로만 출력

## 사용법

```
/init-workflow

20260120_#163_Github_Projects_에_대한_템플릿_개발_필요_및_관련_Sync_워크플로우_개발_필요
```

## 실행 로직

1. 사용자 입력에서 두 번째 줄의 브랜치명 추출
2. Python 스크립트 실행: `.cursor/scripts/worktree_manager.py` 또는 `.claude/scripts/worktree_manager.py`
3. 스크립트 출력을 사용자에게 전달
4. 성공 시 worktree 경로 안내

---

사용자 입력에서 두 번째 줄을 추출하여 브랜치명으로 사용하세요.

브랜치명이 제공되지 않은 경우:
- 사용법을 안내하세요.

브랜치명이 제공된 경우:
1. 프로젝트 루트로 이동
2. `.cursor/scripts/worktree_manager.py` 또는 `.claude/scripts/worktree_manager.py` 스크립트 실행
3. 스크립트에 브랜치명을 인자로 전달
4. 스크립트의 출력을 사용자에게 그대로 전달
5. Exit code가 0이면 성공, 1이면 실패

**중요**: 
- 스크립트는 프로젝트 루트 디렉토리에서 실행되어야 합니다.
- 브랜치명에 공백이나 특수문자가 포함될 수 있으므로 따옴표로 감싸서 전달하세요.
- `.cursor/scripts/` 또는 `.claude/scripts/` 중 존재하는 경로를 사용하세요.
