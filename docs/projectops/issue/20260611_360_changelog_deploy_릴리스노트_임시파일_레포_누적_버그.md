🗒️ 설명
---

`suh-changelog-deploy` 스킬이 deploy PR을 만들 때 릴리스 노트를 임시파일에 쓰고, PR 본문에 넣은 뒤 삭제한다. 그런데 **만드는 경로와 지우는 경로가 달라** 임시파일이 레포에 계속 남는다.

- **만들기**: 릴리스 노트를 레포 내부 `scripts/_release_notes.md`(git이 추적하는 폴더)에 작성
- **지우기**: `skills/suh-changelog-deploy/scripts`로 이동한 상태에서 `rm -f _release_notes.md` 실행 → 실제로는 다른 폴더의 파일을 지우려다 헛발질
- `rm -f`의 `-f` 옵션 때문에 "파일 없음" 에러도 나지 않고 조용히 통과
- 결과: `scripts/_release_notes.md`가 레포에 untracked로 남아 `git status`를 오염시키고, deploy를 돌릴 때마다 누적된다

추가로, 임시파일 이름이 **고정**이라 여러 에이전트나 여러 레포에서 동시에 deploy를 돌리면 같은 파일 하나를 서로 덮어써 릴리스 노트가 오염될 수 있다.

🔄 재현 방법
---

1. `suh-changelog-deploy` 스킬로 deploy를 실행한다
2. PR이 생성된 뒤 `git status`를 확인한다
3. `scripts/_release_notes.md`가 untracked 파일로 남아 있는 것을 확인 (이전 작업의 릴리스 노트 내용이 그대로 들어 있음)

📸 참고 자료
---

```
$ git status --short
?? scripts/_release_notes.md     ← 삭제되지 않고 남은 찌꺼기
```

✅ 예상 동작
---

- deploy 완료 후 임시 릴리스 노트 파일이 흔적 없이 정리되어야 한다
- 레포(작업 디렉토리)에는 어떤 임시파일도 남지 않아야 한다 (`git status` 깨끗)
- 여러 에이전트·레포에서 동시에 deploy해도 서로의 릴리스 노트를 덮어쓰지 않아야 한다
- Windows와 macOS 양쪽에서 동일하게 동작해야 한다

⚙️ 환경 정보
---

- **OS**: Windows (Git Bash) / macOS 공통
- **대상 스킬**: `suh-changelog-deploy` (`SKILL.md`, `scripts/changelog_cli.py`)

🙋‍♂️ 담당자
---

- **백엔드**: Cassiiopeia
