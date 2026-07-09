# changelog-deploy 앱 심사 인지(App-Release Awareness) 설계

- 날짜: 2026-06-20
- 대상 스킬: `skills/changelog-deploy`
- 관련 경험: RomRom-FE에서 iOS App Store 심사 자동 제출(deliver)을 켠 뒤, `deploy`의 의미가 "내부 배포"에서 "사용자 대면 출시"로 바뀌어 릴리스 노트가 곧 심사 제출물이 된 사례

---

## 1. 배경 / 문제

`changelog-deploy`는 모든 레포를 **동일하게** 취급한다. 하지만 실제로는 레포 성격에 따라 릴리스 노트의 무게가 다르다.

- **백엔드 레포**(spring/python): deploy = 서버 반영. 릴리스 노트가 사용자에게 직접 노출되지 않는다. → 지금처럼 가볍게 처리해도 됨.
- **앱 레포**(flutter 등) + **스토어 심사 워크플로우**(PLAYSTORE/TESTFLIGHT/APPSTORE): deploy = 앱스토어/플레이스토어 심사 제출. 릴리스 노트가 **그대로 스토어 "이번 업데이트" 출시노트**가 되어 심사에 들어간다. 특히 심사 자동 제출이 켜지면 CICD·내부 개선·테스트 문구가 실수로 들어가면 즉시 심사로 간다.

현재 스킬은 "기술 prefix 금지·내부구현 금지·사용자 관점" 릴리스 노트 규칙(5단계)과 사용자 승인 게이트(5.5단계)를 이미 갖고 있다. **빠진 것은 "이 레포가 앱 심사에 직결되는 레포인가"를 인지하는 단계**다. 이 인지가 없어서, 앱 레포에서도 백엔드와 같은 긴장도로 릴리스 노트를 쓰게 된다.

## 2. 목표

1. **앱 심사 연관 레포를 자동 감지**하고, 그럴 때만 릴리스 노트를 더 신중히 쓰도록 **에이전트에게 경고**한다.
2. 백엔드 레포는 **아무 영향 없이** 기존 흐름 그대로 통과한다.
3. 판단·대화·config 갱신은 **에이전트가** 하고, **사용자는 config를 직접 만지지 않는다**. 애매하면 에이전트가 자연어로 물어보고 대신 저장한다.
4. 사용자 경험 최우선: 명확하면 조용히 지나가고, 앱 심사로 처음 감지될 때만 한 번 확인한 뒤 결과를 기억해 **다음부터는 묻지 않는다**.

### 비목표 (YAGNI)

- auto_approve를 강제로 차단하는 무거운 강제 (기존 승인 게이트로 충분 — "경고만" 수준으로 결정됨)
- App Store Connect / Play Console 심사 메타(스크린샷·설명) 준비 여부 체크 (스토어 API 연동 필요 — 범위 밖)
- 백엔드/앱 외 타입에 대한 정교한 분류 (현재 신호로 충분)

## 3. 역할 분담 (스킬 철학 그대로)

스킬의 기존 원칙 — **"입력 해석·판단은 agent, 사실 수집·실행은 py"** — 을 그대로 따른다.

- **py = 신호 수집기**: version.yml·워크플로우 파일을 스캔해 **사실(signals)만** JSON으로 반환. "이게 앱 심사 레포냐"의 최종 판단은 하지 않는다. 약한 `hint`만 준다.
- **agent = 판단·대화·config 갱신**: 신호를 해석해 앱 심사 레포인지 판단하고, 애매하거나 처음이면 자연어로 물어보고, 결과를 config에 대신 저장한다.

## 4. py 서브커맨드: `detect-release-context`

`skills/changelog-deploy/scripts/changelog_cli.py`에 서브커맨드 추가.

### 입력

```
detect-release-context --project-root <레포 루트 절대경로>
```

owner/repo는 불필요(로컬 파일 스캔이므로). `--project-root`가 없으면 cwd 기준.

### 동작

1. `<project-root>/version.yml`을 읽어 `project_types` 배열 추출 (없으면 빈 배열).
2. `<project-root>/.github/workflows/` 디렉토리의 파일명을 스캔해 스토어 심사 워크플로우를 찾는다. 매칭 패턴(파일명에 대소문자 무시하고 포함):
   - `PLAYSTORE`, `TESTFLIGHT`, `APPSTORE`, `APP-STORE`
   - (확장 지점: 새 스토어/플랫폼이 생기면 이 목록에 한 줄 추가)
3. 신호를 종합해 약한 `hint`를 만든다.

### 출력 JSON

```json
{
  "ok": true,
  "signals": {
    "project_types": ["flutter"],
    "store_workflows": [
      "PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml",
      "PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml"
    ],
    "has_store_workflow": true,
    "has_app_type": true
  },
  "hint": "app_release_likely",
  "next": "agent가 hint·signals로 판단 후, config에 app_release 기록 없으면 사용자에게 한 번 확인"
}
```

### `hint` 값 (약한 힌트 — agent가 최종 판단)

| hint | 판정 근거 |
|------|-----------|
| `strong_app` | 앱 타입(flutter 등) **AND** 스토어 워크플로우 존재 → 앱 심사 거의 확실 |
| `app_release_likely` | 스토어 워크플로우는 있으나 타입 신호가 약함(예: type은 basic인데 워크플로우만 있음) |
| `backend_only` | 앱 타입 없음 **AND** 스토어 워크플로우 없음 (spring/python 등) → 백엔드로 간주 |
| `unknown` | version.yml/workflows를 못 읽었거나 신호가 충돌 |

### 오류 처리

- version.yml 없음 / workflows 디렉토리 없음 → 오류가 아니라 빈 신호로 처리하고 `hint: backend_only` 또는 `unknown`. py는 절대 throw하지 않고 항상 JSON을 반환한다.
- 표준 라이브러리만 사용(파일 읽기·os.listdir). version.yml 파싱은 yaml 의존성 없이 `project_types:` 라인을 정규식/문자열로 추출(스킬의 표준 라이브러리 우선 원칙). 폐쇄망 대응.

## 5. SKILL.md 새 단계 — `1.5단계: 릴리스 컨텍스트 인지`

deploy 모드 1단계(커밋 상태 확인)와 4단계(커밋 분석) 사이, **PR 생성 훨씬 전에** 배치한다. (fix 모드는 fix 3단계 커밋 분석 전에 동일 로직 재사용.)

### agent 동작 흐름

1. `detect-release-context --project-root <PROJECT_ROOT>` 호출 → `signals`·`hint` 획득.
2. [시작 전 §3]에서 이미 읽은 config에서 현 OWNER/REPO 항목의 `changelog_deploy.app_release` 값을 확인한다.
3. 아래 분기 테이블대로 동작.

### 분기 테이블 (설계 핵심)

| 상황 | agent 동작 |
|------|-----------|
| `hint == backend_only` | **조용히 통과.** 기존 흐름 그대로, 경고·질문 없음. (config도 안 건드림 — 백엔드는 기록할 필요 없음) |
| 앱 심사 감지(`strong_app`/`app_release_likely`) **AND** config에 `app_release` 키 **없음**(첫 실행) | **한 번 확인**한다(아래 [확인 메시지]). 사용자 답을 `app_release: true/false`로 config에 저장. |
| config `app_release == true` (이미 앱 심사로 확정됨) | **묻지 않고**, 5단계 릴리스 노트 작성 + 5.5단계 승인 게이트에 **심사 경고 배너**를 결합해 표시. |
| config `app_release == false` (사용자가 "아니다" 했음) | **묻지 않고**, 경고 없이 기존 흐름 통과. |
| `hint == unknown` 또는 신호 충돌 | config에 키 없으면 한 번만 자연어로 확인하고 결과를 저장. 있으면 저장값 사용. |

> 핵심 UX: **앱 심사 감지 시 "항상 한 번은 확인"**하되, 그 결과를 config에 기억해 **다음 배포부터는 묻지 않는다.** (스킬의 기존 `CONFIG_HAS_KEY` 첫 실행 패턴과 동일 철학.)

### 확인 메시지 (자연어만, config 키·경로 노출 금지)

```
📱 이 저장소는 앱스토어/플레이스토어 심사로 이어지는 배포로 보입니다.
   그렇다면 지금 작성하는 릴리스 노트가 그대로 스토어 "이번 업데이트"
   출시노트가 되어 심사에 들어갑니다.

이 저장소를 앞으로 "앱 심사 배포"로 보고, 릴리스 노트를 더 신중히 다룰까요?
1. 네 (앱 심사 배포가 맞습니다)
2. 아니요 (일반 배포입니다)
```

- **1 선택** → agent가 Read/Write로 config의 현 OWNER/REPO repos 항목에 `changelog_deploy.app_release: true` 저장. 이후 이 배포의 릴리스 노트 단계에 심사 경고 배너 적용.
- **2 선택** → `changelog_deploy.app_release: false` 저장. 경고 없이 통과. 다음부터 안 물음.

> config 갱신은 `references/config-rules.md §4` 규칙대로 전체 파일 Read → 해당 키만 추가 → Write. PAT·다른 repos·auto_approve를 절대 날리지 않는다.

## 6. config 스키마

`github.repos[]` 항목의 기존 `changelog_deploy` 객체에 `app_release` 키를 **추가**한다. (auto_approve와 공존)

```json
{
  "name": "RomRom-FE",
  "owner": "TEAM-ROMROM",
  "repo": "RomRom-FE",
  "pat": null,
  "changelog_deploy": { "auto_approve": false, "app_release": true }
}
```

- 키 **없음** = 첫 실행 → 한 번 확인 후 저장 (앱 심사 감지된 경우만)
- `app_release: true` = 앱 심사 레포 → 심사 경고 배너 (묻지 않음)
- `app_release: false` = 일반 배포로 사용자가 확정 → 경고 없음 (묻지 않음)

`config.json.example`과 `references/config-rules.md`의 `changelog_deploy` 스키마 문서에 `app_release` 키를 추가한다.

## 7. 심사 경고 배너 (5.5단계 / fix 4.5단계 승인 게이트에 결합)

`app_release == true`로 확정된 경우, 릴리스 노트 본문을 사용자에게 보여줄 때 **본문 위에** 배너 한 줄을 덧붙인다. 자동 모드(auto_approve==true)여도 이 배너는 표시한다.

```
⚠️ 이 배포는 실제 앱스토어/플레이스토어 심사에 들어갑니다.
   아래 릴리스 노트가 그대로 스토어 "이번 업데이트" 출시노트가 됩니다.
   CICD·내부 개선·테스트 항목은 빼고, 사용자가 직접 느끼는 변경만 담겼는지 확인하세요.
```

추가로 5단계(릴리스 노트 작성 원칙)에 한 문장 보강:

> **앱 심사 레포(`app_release: true`)면 정제 기준을 한 단계 더 엄격히 적용한다.** 조금이라도 내부/CICD/테스트 성격이면 출시노트에서 제외한다.

## 8. 확장성

- **새 스토어/플랫폼**(react-native, expo 등) 추가 시: py의 매칭 패턴 목록에 워크플로우 파일명 키워드 한 줄 추가하면 끝. SKILL.md·분기 로직은 무수정.
- **다른 스킬 재사용**: `detect-release-context`는 owner/repo 없이 로컬 파일만 보므로, report 등 다른 스킬도 "이 레포 앱 심사냐"를 같은 방식으로 물을 수 있다.
- **단일 출처**: 판단 기준·경고 문구는 SKILL.md 안에 두되, 분기 테이블이 곧 명세이므로 유지보수 지점이 한 곳이다.

## 9. 영향 범위 / 변경 파일

| 파일 | 변경 |
|------|------|
| `skills/changelog-deploy/scripts/changelog_cli.py` | `detect-release-context` 서브커맨드 추가 (argparse + 신호 수집 + JSON) |
| `skills/changelog-deploy/SKILL.md` | 1.5단계(릴리스 컨텍스트 인지) 추가, 5단계 원칙 보강, 5.5/fix 4.5단계에 심사 경고 배너 결합, [시작 전 §3]에 `app_release` 판정 추가 |
| `skills/config.json.example` | `changelog_deploy`에 `app_release` 예시 키 추가 |
| `skills/references/config-rules.md` | `changelog_deploy` 스키마에 `app_release` 문서화 |

> ⚠️ 이 스킬 파일들은 **마켓플레이스 전용**이라 사용자 프로젝트로 흘러가지 않는다(`skills/`는 `plugin_items_to_remove`/`cleanup_template_files` 대상). 따라서 template_integrator·initializer는 수정 불필요. py 수정 후 `skills/changelog-deploy/scripts/` 테스트로 단독 검증.

## 10. 테스트 계획

- **py 단독**: 임시 디렉토리에 (a) flutter+PLAYSTORE 워크플로우 → `strong_app`, (b) spring만 → `backend_only`, (c) 워크플로우만 있고 type basic → `app_release_likely`, (d) version.yml 없음 → `unknown`/빈 신호 4케이스로 JSON 검증.
- **SKILL.md 흐름**: 분기 테이블 4행이 모두 자연어로 명확한지, config 키 노출 문구가 없는지 리뷰.
- **회귀**: 백엔드 레포(`backend_only`)에서 기존 deploy 흐름이 **한 글자도 안 바뀌는지**(질문·경고 0) 확인.
