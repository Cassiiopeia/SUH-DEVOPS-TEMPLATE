# suh-changelog-deploy 릴리스 노트 임시파일 위치 버그 수정 설계

- 날짜: 2026-06-11
- 상태: 설계 승인됨 (구현 전)
- 범위: `suh-changelog-deploy` 스킬의 릴리스 노트 임시파일 버그만 (다른 스킬·기능 변경 없음)

---

## 1. 문제 (근본 원인)

`suh-changelog-deploy` 스킬은 릴리스 노트를 임시파일에 쓰고, deploy PR 본문에 넣은 뒤
삭제한다. 그런데 **만드는 경로와 지우는 경로가 다르다.**

- **만들기**: agent가 Write 도구로 `$PROJECT_ROOT/scripts/_release_notes.md`
  (레포 내부, git이 추적하는 폴더)
- **지우기**: `cd "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts"` 한 cwd에서
  `rm -f _release_notes.md` → 실제로는 `skills/suh-changelog-deploy/scripts/_release_notes.md`를
  지우려다 헛발질 (그 위치엔 파일이 없음)
- `rm -f`의 `-f` 플래그 때문에 "파일 없음" 에러도 나지 않고 조용히 통과
- 결과: `scripts/_release_notes.md`가 레포에 계속 남아 `git status`에 untracked로 쌓임

PR 본문 주입 자체는 우연히 동작했다 — cli의 `_resolve_body_file`이 상대경로를
`cwd → PROJECT_ROOT/scripts` 순으로 탐색해 파일을 찾아내기 때문. 즉
**읽기는 방어 로직 덕에 성공, 삭제만 실패**하는 비대칭 구조다.

실측 (이번 세션):
```
$ git status --short
?? scripts/_release_notes.md       ← 이전 deploy 작업이 남긴 찌꺼기
```
내용은 무관한 과거 작업(Windows 설치 마법사 메뉴 수정)의 릴리스 노트였다.

## 2. 해결: 단일 절대경로로 통일

임시파일을 레포 **밖** `~/.suh-template/tmp/_release_notes.md`로 옮긴다.
config(`~/.suh-template/config/config.json`)가 사는 홈 디렉토리와 동일 컨벤션이다.

```
이전:  $PROJECT_ROOT/scripts/_release_notes.md   (레포 내부, cwd 의존)
이후:  ~/.suh-template/tmp/_release_notes.md      (홈, 절대경로 — cwd 무관)
```

- 만들기·읽기·지우기가 **모두 같은 절대경로**를 가리키므로 cwd 불일치가 원천 차단된다.
- 레포 내부에 아무것도 만들지 않으므로 추적 사고(`git status` 오염)가 사라진다 —
  `.gitignore` 등재조차 불필요.
- 이 프로젝트는 이미 `~/.suh-template/`을 config 용도로 쓰며, "Windows Git Bash의
  `$HOME`은 POSIX 경로라 네이티브 Python `open()`이 못 연다 → Read/Write 도구로 다룬다"는
  노하우가 SKILL.md에 정립돼 있어 홈 경로 처리 패턴이 검증돼 있다.
- OS 임시폴더(`%TEMP%`/`$TMPDIR`)는 Windows Git Bash의 `/tmp` 경로 깨짐 문제가 있어 피한다.

### 2.1 크로스플랫폼 동작 보장 (Windows + macOS 필수)

이 수정은 **Windows와 macOS 양쪽에서 동일하게 작동**해야 한다. 보장 방식:

| 단계 | 사용 수단 | Windows | macOS | 안전 근거 |
|---|---|---|---|---|
| 파일 생성 | Write 도구 | `C:\Users\<>\.suh-template\tmp\` | `~/.suh-template/tmp/` | agent의 Write 도구가 OS 네이티브 경로를 자동 처리 |
| bash 경로 | `$HOME/.suh-template/tmp/...` | `/c/Users/<>` 로 해석 | `/Users/<>` 로 해석 | `$HOME`은 Git Bash·macOS 양쪽 동일 동작 — OS 분기 불필요 |
| cli 읽기 | `pathlib.Path.home()` | `\` 구분자 자동 | `/` 구분자 자동 | `pathlib`이 OS별 구분자 처리 |

- **bash 블록은 하드코딩 경로(`C:\...`)를 쓰지 않고 `$HOME`만 쓴다.** Windows Git Bash에서도
  `$HOME`은 `/c/Users/USER`로 정상 해석되므로 OS 분기 코드가 필요 없다.
- **cli는 `pathlib.Path.home()`을 쓴다.** SKILL.md가 경고하는 함정("Windows Git Bash의 `$HOME`은
  POSIX 경로라 네이티브 Python `open(문자열경로)`이 못 연다")은 문자열 경로를 직접 open할 때의
  문제이며, `pathlib.Path`는 이를 겪지 않는다(OS별 경로 객체로 정규화).
- 오히려 **버그가 났던 옛 방식이 더 취약했다** (cwd 의존 + 레포 내부 상대경로). 새 방식이 양쪽
  OS에서 더 견고하다.

## 3. 변경 단위

### 3.1 `skills/suh-changelog-deploy/SKILL.md` (3지점)

1. **5단계 저장 위치 안내** (현재 "Write tool로 `$PROJECT_ROOT/scripts/_release_notes.md`에 저장"):
   → `~/.suh-template/tmp/_release_notes.md`에 저장으로 변경.
   Windows는 `C:\Users\<사용자>\.suh-template\tmp\_release_notes.md`,
   macOS/Linux는 `~/.suh-template/tmp/_release_notes.md`.
   **tmp 폴더가 없으면 Write 전에 생성**하라는 지시 추가.

2. **deploy 6단계 bash 블록**: 블록 상단에 변수 도입
   ```bash
   NOTES_FILE="$HOME/.suh-template/tmp/_release_notes.md"
   ```
   - `create-pr`/`update-pr`의 body_file 인자: `"_release_notes.md"` → `"$NOTES_FILE"`
   - 삭제: `rm -f _release_notes.md` → `rm -f "$NOTES_FILE"`

3. **fix 4단계 저장 위치 + fix 5단계 bash 블록**: 위 1·2와 동일하게 적용.

### 3.2 `skills/suh-changelog-deploy/scripts/changelog_cli.py` (정합성)

`_resolve_body_file`의 탐색 후보 순서에 홈 tmp 경로를 추가한다 (방어용 — SKILL.md가
절대경로를 넘기므로 절대경로 분기가 1순위로 그대로 동작한다):

```python
for candidate in (
    raw,
    Path.home() / ".suh-template" / "tmp" / raw.name,   # 신규
    _PROJECT_ROOT / "scripts" / raw.name,               # 기존 (하위호환 유지)
    Path.cwd() / raw,
):
```

- 함수 docstring(현재 "SKILL.md 절차는 `$PROJECT_ROOT/scripts/_release_notes.md`에 저장하지만…")을
  새 위치(`~/.suh-template/tmp/`) 기준으로 갱신.
- 본문 파일 못 찾을 때의 에러 메시지에 홈 tmp 경로도 후보로 표기.

### 3.3 경계 (건드리지 않는 것)

- cli의 `raw.is_absolute()` 절대경로 분기: **수정 없음**. SKILL.md가 절대경로를 넘기므로
  그 경로가 그대로 1순위 처리된다. 후보 추가는 누군가 상대경로만 넘겼을 때의 방어용.
- 기존 `_PROJECT_ROOT / "scripts"` 후보: **유지**. 구버전 호출·하위호환을 위해 남긴다.
- `references/config-rules.md`에 "임시파일 표준" 섹션 신설: **이번 범위 아님** (다른 스킬에
  동일 패턴 없음을 grep으로 확인. 필요 시 별도 작업).

## 4. 에러 처리

- **tmp/ 폴더 부재**: SKILL.md가 Write 전 폴더 생성을 지시. cli는 파일을 읽기만 하므로
  폴더 생성 책임이 없다.
- **삭제 시 파일 없음**: `rm -f`라 무에러 (정상 동작).
- **cli가 파일 못 찾음**: 기존 `본문 파일을 찾을 수 없습니다` 에러 동작 유지(경로 표기만 갱신).

## 5. 검증

- **cli 경로 해석 단위 검증**: `~/.suh-template/tmp/_release_notes.md`에 더미 노트를 만들고,
  `_resolve_body_file`이 (a) 절대경로 입력, (b) 상대경로 `_release_notes.md` 입력 양쪽에서
  그 파일을 찾아내는지 확인 (실제 PR 생성 없이 경로 해석만). 더미는 검증 후 삭제.
- **회귀(텍스트 검토)**: SKILL.md에서 `$PROJECT_ROOT/scripts/_release_notes.md` 잔존 참조가
  없는지, 만들기·읽기·지우기 경로가 모두 `~/.suh-template/tmp/`로 일치하는지 확인.
- 실제 deploy 실행은 사용자가 직접 수행한다 (이 작업 범위 밖).

## 6. 변경 대상 파일

| 파일 | 작업 |
|---|---|
| `skills/suh-changelog-deploy/SKILL.md` | 5단계·6단계·fix4·fix5의 임시파일 경로를 `~/.suh-template/tmp/`로 통일 |
| `skills/suh-changelog-deploy/scripts/changelog_cli.py` | `_resolve_body_file` 후보에 홈 tmp 추가 + 주석·에러메시지 갱신 |

## 7. 후속 (이번 범위 아님)

- `references/config-rules.md`에 "스킬 임시 산출물은 `~/.suh-template/tmp/`에 둔다"는 공용
  규칙 신설 — 다른 스킬도 같은 컨벤션을 따르게 하려면. 현재는 이 스킬에만 해당.
