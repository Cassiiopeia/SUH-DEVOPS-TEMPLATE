📝 현재 문제점
---

- 이슈 생성 시 브랜치명/커밋 메시지를 댓글로 제안하는 `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml`이 외부 GitHub 액션(`Cassiiopeia/github-issue-helper@deploy`)에 의존하고 있어, 템플릿과 무관한 외부 레포의 빌드/배포 상태에 종속됨
- `PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml`은 이미 deprecated(비활성) 상태의 잔재 파일로 남아 있음
- 커스터마이징이 워크플로우 YAML의 `with:` 블록에 박혀 있어 마법사 업데이트 시 사용자 수정분이 충돌 대상이 되고, 설정 SSOT(version.yml) 원칙에도 어긋남
- 구 액션은 UTC 러너 시각으로 날짜를 계산해 한국 기준 새벽에 브랜치 날짜가 하루 어긋남
- 브랜치 규칙(`YYYYMMDD_#번호_제목`)에 의존하는 기능(플러터 빌드 3종, 커밋/보고서 스킬, worktree)이 있는데, 왜 이 브랜치명을 써야 하는지 사용자에게 안내되지 않음

🛠️ 해결 방안 / 제안 기능
---

- 외부 액션 로직을 `.github/scripts/issue_helper.py`(Python stdlib 전용, pip/yq 무의존)로 내재화하고 워크플로우를 `PROJECT-COMMON-SUH-ISSUE-HELPER.yaml`로 리네임 교체
- 설정은 `version.yml`의 `metadata.template.options.issue_helper`로 이동 (SSOT — 무설정 시 전부 기본값, 향후 마법사 설정 중앙관리 메뉴 편입 대비 플랫 스키마)
- 개선: 제목 태그 기반 커밋 타입 추론(`[버그]`→fix 등, 오버라이드 가능), 템플릿 변수 확장(`${commitType}`/`${labels}`/`${assignees}`), KST 타임존 기본값
- 불변 계약 유지: 브랜치 코어 `YYYYMMDD_#번호_제목` 고정 + 댓글의 `Guide by SUH-LAB`·`### 브랜치` 코드블록 구조 유지 (구버전 BUILD-TRIGGER 파서 하위호환)

⚙️ 작업 내용
---

- `PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml` 삭제 + migrations registry `safe` 등록
- `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml` → `PROJECT-COMMON-SUH-ISSUE-HELPER.yaml` 리네임 (루트+common 두 곳 동일 유지) + registry `safe` 등록
- `.github/scripts/issue_helper.py` + pytest 테스트 신규 작성 (정규화 패리티·커밋타입·계약 테스트)
- 자동 마이그레이션: registry `settingsExtractor` 훅 신설 — 구 워크플로우 `with:` 커스텀 값을 version.yml로 자동 이관 (기본값 제외, 기존 키 보존, 멱등)
- npx 복사 엔진(`src/core/copy/simple.js`)에 `issue_helper.py` 배선
- 브랜치 규칙 가이드 3층 표면화: 이슈 댓글 접이식 안내(레포에 실존하는 워크플로우 기반 동적 생성) + 의존 워크플로우 헤더 주석 + `docs/BRANCH-CONVENTION.md` 중앙 문서
- 설계 문서: `docs/superpowers/specs/2026-07-12-issue-helper-internalization-design.md`

🙋‍♂️ 담당자
---

- 템플릿/DevOps: Cassiiopeia
