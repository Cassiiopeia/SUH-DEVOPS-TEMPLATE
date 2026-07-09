# Skill Auto-Approve Unified Gate Design

작성일: 2026-06-02
대상 스킬: `commit`, `issue`, `changelog-deploy`

## 1. 배경

현재 3개 스킬은 사용자 확인 게이트를 각자 다른 방식으로 처리한다.

| 스킬 | 게이트 위치 | 토글 키 | 현재 상태 |
|------|------------|---------|----------|
| commit | 5단계 (4지선다) | `commit.auto_approve` | 막 추가됨 |
| issue | 4단계 (4지선다) + 4-1 (중복 재검사) | 없음 | 토글 부재 |
| changelog-deploy | 5.5단계 (본문 표시 후 승인) | `changelog_deploy.auto_approve_release_notes` | 적용됨 |

매번 사용자 확인이 떠서 같은 레포 반복 작업 시 마찰. 이미 changelog-deploy는 토글이 있지만 키 이름이 다르고, issue는 토글 자체가 없다.

## 2. 목표

- 3개 스킬의 토글 키 이름·구조·해석 우선순위를 **단일 패턴**으로 통일
- 사용자에게 config 키 이름·파일 경로를 노출하지 않는다 (자연어 토글만)
- 첫 실행 1회만 자동화 여부를 묻고 그 답을 config에 저장
- py(`commit_cli.py`, `issue_cli.py`, `changelog_cli.py`) 무변경 — 판정·갱신은 SKILL.md + agent 책임

## 3. config 스키마

```jsonc
{
  "github": {
    "global_pat": "...",
    "commit":            { "auto_approve": false },
    "issue":             { "auto_approve": false },
    "changelog_deploy":  { "auto_approve": false },
    "repos": [
      {
        "owner": "...", "repo": "...",
        "commit":            { "auto_approve": true },
        "issue":             { "auto_approve": true },
        "changelog_deploy":  { "auto_approve": true }
      }
    ]
  }
}
```

해석 우선순위 (3개 스킬 동일):
```
1. repos[i].{skill_id}.auto_approve   (현 owner/repo 매칭)
2. github.{skill_id}.auto_approve     (글로벌 기본값)
3. false                              (안전 default — 수동 승인)
```

`{skill_id}` = `commit` / `issue` / `changelog_deploy`

### 3.1 마이그레이션 정책

**명시적 break**. 구 키 `changelog_deploy.auto_approve_release_notes`는 인식하지 않는다. 본인 config에 `true`로 들어있어도 무시 — `false` default로 동작. 사용자가 자동 모드 원하면 1회 토글 발화하면 agent가 `auto_approve: true`로 새 키 저장.

## 4. SKILL.md 표준 게이트 구조

3개 스킬 모두 동일 단계 패턴.

### 4.1 시작 전 — 자동 승인 모드 판정

`Read` 도구로 config 읽기 → 두 값 추출:

- `AUTO_APPROVE` — boolean
- `CONFIG_HAS_KEY` — boolean (우선순위 1·2 중 어디에도 키가 없으면 `false`)

### 4.2 게이트 단계 A/B/C 분기

**A. 자동 모드 (`AUTO_APPROVE == true`)**

요약 표시 후 즉시 다음 단계.

```
🤖 이 레포는 확인 없이 바로 진행되도록 설정돼 있어 안내드리고 [커밋/등록/PR 생성]합니다.
   (다시 매번 확인받고 싶으시면 "확인받게 해줘"라고 말씀해주세요.)

📝 [요약]:
{요약 또는 본문}

[작업명]을 실행합니다.
```

이 메시지를 본 사용자가 "확인받게 해줘" 류로 응답하면 → config 갱신 후 B 분기로 전환.

**B. 수동 모드 (`AUTO_APPROVE == false`)**

기존 4지선다 수동 게이트 그대로 (스킬별 옵션 차이 있음).

승인 진행 + `CONFIG_HAS_KEY == false`(첫 실행)이면 → C 분기 1회.

**C. 첫 실행 자동화 제안**

```
💡 다음 [작업]부터 어떻게 진행할까요?

매번 [작업] 직전에 확인받는 방식이 기본입니다.
원하시면 이 확인 단계를 건너뛰고 곧바로 진행되도록 바꿀 수 있습니다.

1. 이 레포 [작업]은 앞으로 확인 없이 바로 진행해주세요
2. 모든 레포 [작업]을 앞으로 확인 없이 바로 진행해주세요
3. 지금처럼 매번 확인받겠습니다

(언제든 "다시 확인받게 해줘" / "자동으로 바꿔줘"라고 말씀하시면 바꿀 수 있습니다)
```

응답에 따라 agent가 Read/Write로 config 갱신:

- 1 → `github.repos[]`에서 현 owner/repo 매칭 항목에 `{skill_id}.auto_approve: true` 추가
- 2 → `github.{skill_id}.auto_approve: true` (객체 없으면 생성)
- 3 → `github.{skill_id}.auto_approve: false` (키는 남겨 다음부터 묻지 않음)

## 5. 스킬별 차이점

| 스킬 | A 분기 표시 내용 | 자동 모드라도 강제 게이트 |
|------|----------------|--------------------------|
| commit | 커밋 메시지 1줄 | 없음 |
| issue | 제목 + 라벨 + 로컬 md 파일 경로 | 중복 검사(2-1, 4-1) 무조건 실행. open 동일 이슈 발견 시 중단 |
| changelog-deploy | 릴리스 노트 본문 전체 | 없음 |

## 6. UX 원칙

- 메시지 어디서도 `auto_approve`, `config.json`, `commit 섹션`, `~/.suh-template/` 같은 단어 금지
- 자연어로만 토글:
  - "자동으로 진행해줘", "확인 없이 해줘" → `true`
  - "매번 확인받게 해줘", "수동으로 바꿔줘" → `false`
- agent가 Read/Write로 직접 config 갱신 — 사용자 손 안 댐
- 첫 실행 1회만 자동화 여부를 묻는다 (이후엔 키 존재로 판정)

## 7. py 변경 — 없음

- `commit_cli.py` / `issue_cli.py` / `changelog_cli.py` 모두 **무변경**
- 토글 판정·config 갱신은 SKILL.md + agent 책임
- py는 GitHub API/텍스트 정규화 데이터 추출만
- 일관성·테스트 보존·회귀 위험 0

## 8. 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `skills/references/config-rules.md` | §7 commit/issue/changelog_deploy 키 통일. 구 키 명시 break 안내. 공통 해석 규칙 1개로 통합 |
| `skills/config.json.example` | 3 스킬 `auto_approve` 예시 통일 |
| `skills/commit/SKILL.md` | A/B/C 분기 (이미 추가됨) 다듬기 |
| `skills/issue/SKILL.md` | 시작 전 §자동 승인 판정 + 4단계에 A/B/C 분기 삽입 |
| `skills/changelog-deploy/SKILL.md` | `auto_approve_release_notes` → `auto_approve` rename |

## 9. 비목표

- py 추가/수정
- 구 키 자동 마이그레이션 코드
- 자동 모드에서 issue 중복 검사 스킵
- 스킬별 세분화(이슈 타입별 토글 등)
