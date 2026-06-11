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

## 2. 해결: 레포별 고유 파일명 + 단일 절대경로

임시파일을 레포 **밖** `~/.suh-template/tmp/` 폴더로 옮기되, 파일명에 `{owner}__{repo}`
prefix를 붙여 레포마다 다른 파일을 쓰게 한다.
config(`~/.suh-template/config/config.json`)가 사는 홈 디렉토리와 동일 컨벤션이다.

```
이전:  $PROJECT_ROOT/scripts/_release_notes.md                 (레포 내부, cwd 의존, 고정명)
이후:  ~/.suh-template/tmp/{owner}__{repo}__release_notes.md    (홈, 절대경로, 레포별 고유)
```

예시 (여러 레포가 동시에 deploy를 돌려도 충돌 없음):
```
~/.suh-template/tmp/
├── Cassiiopeia__SUH-DEVOPS-TEMPLATE__release_notes.md
├── TEAM-ROMROM__RomRom-FE__release_notes.md
└── PickerPicker__PickerPicker__release_notes.md
```

### 2.0 왜 레포별 고유 파일명인가 (동시성 격리)

이 임시파일은 config(읽기 전용)와 달리 **쓰고·읽고·지우는 가변 파일**이다. 사용자가 여러
에이전트(또는 여러 레포)에서 동시에 deploy를 돌리면, 고정 파일명 하나는 서로 덮어쓴다:

```
에이전트 A (repo X)  → tmp/_release_notes.md 작성
에이전트 B (repo Y)  → 같은 파일 덮어씀        ← A의 노트 소실
에이전트 A           → PR 본문에 B의 노트 주입   ← 오염
에이전트 B           → rm 으로 삭제             ← A가 읽기 전 사라짐
```

옛 `scripts/` 방식은 (우연히) 레포별로 폴더가 달라 레포 간 충돌이 없었는데, 홈 단일 위치로
모으면서 그 격리가 사라진다. 따라서 **파일명에 `{owner}__{repo}`를 박아 격리를 복원**한다.

- 폴더는 `~/.suh-template/tmp/` **하나만** 둔다 (레포별 하위폴더를 만들지 않는다 — 폴더 난립 방지).
  레포별 구분은 파일명 prefix로만 한다.
- **결정적 이름**: agent가 이미 [시작 전]에서 구한 OWNER·REPO로 파일명을 만들므로,
  Write(agent)와 cli 인자가 같은 이름을 공유하기 쉽고, 같은 레포 재실행 시 자연스럽게
  덮어쓰며 찌꺼기가 쌓이지 않는다 (타임스탬프/랜덤 방식의 고아 파일 누적 문제가 없다).
- **파일명 안전성**: GitHub owner·repo는 영숫자·하이픈(`-`)·언더스코어(`_`)·점(`.`)만
  허용하고 `/`·공백·특수문자가 없다. 구분자로 `__`(언더스코어 2개)를 써서 owner/repo
  경계를 명확히 한다. (owner나 repo 자체에 `__`가 들어가도 파일 경로로는 문제없다.)

- 만들기·읽기·지우기가 **모두 같은 절대경로**(레포별 고유)를 가리키므로 cwd 불일치가
  원천 차단되고, 다른 레포·에이전트와도 충돌하지 않는다.
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
| 파일 생성 | Write 도구 | `C:\Users\<>\.suh-template\tmp\{owner}__{repo}__release_notes.md` | `~/.suh-template/tmp/{owner}__{repo}__release_notes.md` | agent의 Write 도구가 OS 네이티브 경로를 자동 처리 |
| bash 경로 | `$HOME/.suh-template/tmp/${OWNER}__${REPO}__release_notes.md` | `/c/Users/<>` 로 해석 | `/Users/<>` 로 해석 | `$HOME`은 Git Bash·macOS 양쪽 동일 동작 — OS 분기 불필요 |
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

[시작 전] 단계에서 agent가 OWNER·REPO를 이미 구한다. 이를 파일명에 박는다.

1. **5단계 저장 위치 안내** (현재 "Write tool로 `$PROJECT_ROOT/scripts/_release_notes.md`에 저장"):
   → `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`에 저장으로 변경.
   Windows는 `C:\Users\<사용자>\.suh-template\tmp\{OWNER}__{REPO}__release_notes.md`,
   macOS/Linux는 `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`.
   `{OWNER}`·`{REPO}`는 [시작 전]에서 구한 실제 값으로 치환한다.
   **tmp 폴더가 없으면 Write 전에 생성**하라는 지시 추가.

2. **deploy 6단계 bash 블록**: 블록 상단에 변수 도입 (OWNER·REPO는 이미 인라인 prefix됨)
   ```bash
   NOTES_FILE="$HOME/.suh-template/tmp/${OWNER}__${REPO}__release_notes.md"
   ```
   - `create-pr`/`update-pr`의 body_file 인자: `"_release_notes.md"` → `"$NOTES_FILE"`
   - 삭제: `rm -f _release_notes.md` → `rm -f "$NOTES_FILE"`

3. **fix 4단계 저장 위치 + fix 5단계 bash 블록**: 위 1·2와 동일하게 적용.

> agent가 Write로 만드는 파일명과 bash `NOTES_FILE`이 **반드시 같은 이름**이어야 한다
> (둘 다 `{OWNER}__{REPO}__release_notes.md`). SKILL.md에 이 일치 요구를 명시한다.

### 3.2 `skills/suh-changelog-deploy/scripts/changelog_cli.py` (정합성)

`_resolve_body_file`의 탐색 후보 순서에 홈 tmp 폴더를 추가한다 (방어용 — SKILL.md가
절대경로를 넘기므로 절대경로 분기가 1순위로 그대로 동작한다). 파일명에 repo prefix가
붙으므로 `raw.name`(파일명 전체)을 그대로 tmp 폴더에서 찾으면 된다:

```python
for candidate in (
    raw,
    Path.home() / ".suh-template" / "tmp" / raw.name,   # 신규 — repo prefix 파일명 포함
    _PROJECT_ROOT / "scripts" / raw.name,               # 기존 (하위호환 유지)
    Path.cwd() / raw,
):
```

- 함수 docstring(현재 "SKILL.md 절차는 `$PROJECT_ROOT/scripts/_release_notes.md`에 저장하지만…")을
  새 위치(`~/.suh-template/tmp/{owner}__{repo}__release_notes.md`) 기준으로 갱신.
- 본문 파일 못 찾을 때의 에러 메시지에 홈 tmp 경로도 후보로 표기.

### 3.3 경계 (건드리지 않는 것)

- cli의 `raw.is_absolute()` 절대경로 분기: **수정 없음**. SKILL.md가 절대경로를 넘기므로
  그 경로가 그대로 1순위 처리된다. 후보 추가는 누군가 상대경로만 넘겼을 때의 방어용.
- 기존 `_PROJECT_ROOT / "scripts"` 후보: **유지**. 구버전 호출·하위호환을 위해 남긴다.
- 파일명 생성 로직을 cli로 옮기지 않는다. agent가 OWNER·REPO를 이미 알고 Write·bash 양쪽에
  같은 이름을 쓰므로, 이름 결정은 SKILL.md(agent) 책임으로 둔다 (cli는 받은 경로를 읽기만).
- `references/config-rules.md`에 "임시파일 표준" 섹션 신설: **이번 범위 아님** (다른 스킬에
  동일 패턴 없음을 grep으로 확인. 필요 시 별도 작업).

## 4. 에러 처리

- **tmp/ 폴더 부재**: SKILL.md가 Write 전 폴더 생성을 지시. cli는 파일을 읽기만 하므로
  폴더 생성 책임이 없다.
- **삭제 시 파일 없음**: `rm -f`라 무에러 (정상 동작).
- **cli가 파일 못 찾음**: 기존 `본문 파일을 찾을 수 없습니다` 에러 동작 유지(경로 표기만 갱신).

## 5. 검증

- **cli 경로 해석 단위 검증**: `~/.suh-template/tmp/testowner__testrepo__release_notes.md`에
  더미 노트를 만들고, `_resolve_body_file`이 (a) 절대경로 입력, (b) 상대경로
  `testowner__testrepo__release_notes.md` 입력 양쪽에서 그 파일을 찾아내는지 확인
  (실제 PR 생성 없이 경로 해석만). 더미는 검증 후 삭제.
- **회귀(텍스트 검토)**: SKILL.md에서 `$PROJECT_ROOT/scripts/_release_notes.md` 잔존 참조가
  없는지, 만들기·읽기·지우기 경로가 모두 `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`로
  일치하는지, Write 파일명과 bash `NOTES_FILE`이 동일 이름인지 확인.
- **동시성(논리 검토)**: 서로 다른 owner/repo 두 건이 같은 tmp 폴더에서 다른 파일명을 쓰는지
  스펙상 보장 확인 (실제 병렬 실행은 사용자 환경에서).
- 실제 deploy 실행은 사용자가 직접 수행한다 (이 작업 범위 밖).

## 6. 변경 대상 파일

| 파일 | 작업 |
|---|---|
| `skills/suh-changelog-deploy/SKILL.md` | 5단계·6단계·fix4·fix5의 임시파일 경로를 `~/.suh-template/tmp/`로 통일 |
| `skills/suh-changelog-deploy/scripts/changelog_cli.py` | `_resolve_body_file` 후보에 홈 tmp 추가 + 주석·에러메시지 갱신 |

## 7. 후속 (이번 범위 아님)

- `references/config-rules.md`에 "스킬 임시 산출물은 `~/.suh-template/tmp/`에 둔다"는 공용
  규칙 신설 — 다른 스킬도 같은 컨벤션을 따르게 하려면. 현재는 이 스킬에만 해당.
