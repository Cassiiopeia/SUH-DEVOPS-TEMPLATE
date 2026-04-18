# Skill System 전면 업그레이드 — 마스터 로드맵

**작성일**: 2026-04-18
**작성자**: Claude (with @Cassiiopeia)
**상태**: 진행 중

---

## 배경

현재 `cassiiopeia` 플러그인의 skill 시스템은 다음 한계가 있다:

1. **산출물 경로가 일관되지 않음** — 각 skill이 md 파일을 어디에 만드는지 정해진 규칙이 없어서, 시간순 추적과 카테고리 정리가 어려움
2. **Skill별 사용자 설정을 담을 곳이 없음** — `issue` skill의 GitHub repo URL, `synology-expose`의 NAS 주소 등 민감/환경 의존 정보를 보관할 표준 위치가 없음
3. **Cursor용 skill 버전 관리 부재** — Claude Code는 플러그인 마켓플레이스로 자동 관리되지만, Cursor는 단순 파일 복사라 사용자가 어떤 버전을 쓰고 있는지 모름
4. **공통 로직 중복** — 8개 이상의 skill이 비슷한 보일러플레이트(경로 계산, 날짜 처리, 파일 카운트 등)를 각자 처리
5. **설치 스코프 안내 부족** — Claude Code 플러그인을 user/local/repo 어디에 설치할지에 대한 가이드와 자동화가 부족

이 문서는 위 문제들을 5개의 독립적인 sub-project로 분해하고, 각각을 순서대로 brainstorm → spec → plan → 구현 사이클로 처리하기 위한 **마스터 로드맵**이다.

---

## Sub-project 분해

각 sub-project는 자체 spec 문서와 구현 plan을 가진다.

### #1 공통 Python 헬퍼 인프라

**목적**: 모든 skill이 공통으로 사용할 크로스 플랫폼 헬퍼 모듈을 Python으로 구축

**다룰 내용**:
- 경로 계산 (산출물 디렉토리, config 디렉토리)
- 이슈 번호 추출 (worktree 폴더명, git 브랜치명)
- 그날 누적순번 계산
- 제목 정규화 (특수문자 제거, 공백 처리)
- Config 로딩 (json/yaml)
- 매니페스트 읽기/쓰기

**의존성**: 없음 (가장 먼저 작업)

**Spec**: `docs/superpowers/specs/YYYYMMDD-subproject-1-python-helper.md`

---

### #2 산출물 경로 표준화 (`/docs/suh-template/`)

**목적**: 8개 "분석/보고" 계열 skill의 md 산출물을 표준 경로 규칙으로 통일

**다룰 내용**:
- 디렉토리 구조: `docs/suh-template/{skill_id}/`
- 파일명 규칙: `YYYYMMDD_{번호}_{제목}.md`
  - 번호: worktree/브랜치에서 이슈번호 추출 → 없으면 그날 누적순번(3자리)
  - 제목: worktree 폴더명에서 추출 → 없으면 AI 생성 → 애매하면 사용자 확인
- 적용 대상 skill (8개): `analyze`, `plan`, `design-analyze`, `refactor-analyze`, `troubleshoot`, `report`, `ppt`, `review`
- 공통 reference 문서: `skills/references/doc-output-path.md`

**의존성**: #1 (Python 헬퍼 사용)

**Spec**: `docs/superpowers/specs/YYYYMMDD-subproject-2-output-path.md`

---

### #3 Skill별 Config 시스템 (.example 패턴)

**목적**: 각 skill이 필요로 하는 사용자/레포별 설정을 안전하게 보관할 표준 메커니즘 도입

**다룰 내용**:
- 디렉토리 구조 (예시):
  - `.suh-template/config/{skill_id}.config.json` — 실제 값 (gitignore)
  - `.suh-template.example/config/{skill_id}.config.example.json` — 템플릿 (커밋)
- Config 스키마 정의 (skill별)
- Config 로딩 헬퍼 (#1에서 제공)
- 최초 설정 시 .example → 실제 파일 자동 복사 마법사
- `.gitignore` 자동 등록

**의존성**: #1 (Config 로딩 헬퍼)

**Spec**: `docs/superpowers/specs/YYYYMMDD-subproject-3-config-system.md`

---

### #4 Cursor용 매니페스트 (버전 관리)

**목적**: Cursor 사용자가 자기 `.cursor/skills/`의 버전을 알 수 있고, 업데이트 여부를 확인/실행할 수 있도록 함

**다룰 내용**:
- `.cursor/skills/MANIFEST.json` 도입
  - `plugin_version` (전체 버전)
  - `synced_at` (마지막 동기화 시각)
  - `source` (원본 저장소 URL)
  - skill 목록과 각각의 버전(전체 버전 추종)
- 자동 동기화 워크플로우 확장
  - 기존 `PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC`에 MANIFEST.json 갱신 추가
- 버전 확인/업데이트 명령
  - `template_integrator.sh --check-cursor-skills`
  - `template_integrator.sh --update-cursor-skills`

**의존성**: 없음 (#1~#3과 독립적이지만, #2/#3 변경사항을 cursor 사용자에게 전달하려면 결과적으로 필요)

**Spec**: `docs/superpowers/specs/YYYYMMDD-subproject-4-cursor-manifest.md`

---

### #5 Claude Code 설치 스코프 정리

**목적**: Claude Code 플러그인 설치 시 user/local/repo 스코프 선택과 관련 자동화 강화

**다룰 내용**:
- 설치 스코프 가이드 문서화
- `template_integrator` 통합 후 마법사 흐름 정리
  - "이 레포에만 설치" vs "전역(user) 설치" 선택 UI
- 스코프별 트레이드오프 안내
- 기존 안내 메시지 재정비

**의존성**: #1~#4가 안정화된 후 마지막 정리

**Spec**: `docs/superpowers/specs/YYYYMMDD-subproject-5-install-scope.md`

---

## 진행 순서와 체크포인트

```
#1 Python 헬퍼 ──┬── #2 산출물 경로 표준화
                 │
                 └── #3 Config 시스템

#4 Cursor 매니페스트 (#2/#3 결과를 반영하도록 마지막에)

#5 설치 스코프 (#1~#4 안정화 후 최종 정리)
```

각 sub-project는 다음 사이클을 완전히 끝낸 뒤 다음으로 넘어간다:

1. `superpowers:brainstorming` — 사용자와 명확화
2. 자체 spec 문서 작성 (`docs/superpowers/specs/YYYYMMDD-subproject-N-*.md`)
3. spec 사용자 리뷰 승인
4. `superpowers:writing-plans` — 구현 계획 작성
5. `superpowers:executing-plans` — 구현
6. 검증 후 다음 sub-project로

---

## 결정 사항 (지금까지 brainstorm에서 합의된 내용)

| 항목 | 결정 |
|------|------|
| 산출물 prefix | `docs/suh-template/{skill_id}/` |
| 파일명 형식 | `YYYYMMDD_{번호}_{제목}.md` |
| 번호 (이슈 있을 때) | worktree 폴더명 → git 브랜치명 → 사용자 확인 |
| 번호 (이슈 없을 때) | 그날 누적순번 (3자리, `001`) |
| 제목 결정 | worktree 폴더명 우선 → AI 생성 → 애매하면 사용자 확인 |
| 적용 skill (8개) | `analyze`, `plan`, `design-analyze`, `refactor-analyze`, `troubleshoot`, `report`, `ppt`, `review` |
| 공통 로직 위치 | Python 헬퍼 모듈 (크로스 플랫폼) |
| 공통 reference | `skills/references/doc-output-path.md` |
| Config 디렉토리 | `.suh-template/config/` (gitignore) + `.suh-template.example/config/` (커밋) |
| Cursor 버전 관리 | `.cursor/skills/MANIFEST.json` 단일 매니페스트 |
| 개별 skill 버전 | 플러그인 전체 버전 추종 (개별 관리 안 함) |

---

## 참고

- 이 로드맵 자체는 진행하면서 업데이트될 수 있다. 새로운 의존성이나 스코프 변경이 발견되면 이 문서를 먼저 갱신한 뒤 진행한다.
- 각 sub-project의 spec 문서가 작성되면 이 로드맵에 링크를 추가한다.
