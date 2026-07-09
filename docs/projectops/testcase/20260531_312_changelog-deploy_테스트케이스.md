# QA 테스트케이스 — changelog-deploy 릴리스 노트 레이스컨디션

대상 이슈: #312
대상 파일: `skills/suh-changelog-deploy/SKILL.md`

## TC-01: 신규 deploy PR 생성 시 릴리스 노트 본문 포함

- **전제**: open된 deploy PR이 없는 상태, main에 deploy 미반영 커밋 존재
- **절차**: `/suh-changelog-deploy` 실행 → push → 커밋 분석 → 릴리스 노트 작성 → PR 생성
- **기대 결과**: 생성된 deploy PR의 본문에 `## Summary by CodeRabbit` 과 `## 릴리스 노트` 가 처음부터 포함되어 있다
- **확인 방법**: PR 생성 직후 본문 조회 시 릴리스 노트가 존재

## TC-02: 워크플로우 본문 초기화 건너뜀

- **전제**: TC-01로 릴리스 노트를 담은 PR이 생성됨
- **절차**: PR `opened` 트리거로 AUTO-CHANGELOG-CONTROL 워크플로우 실행
- **기대 결과**: 워크플로우 로그에 `이미 'Summary by CodeRabbit' 감지 — 본문 초기화 건너뜀` 출력, 본문이 유지됨
- **확인 방법**: Actions 로그의 `PR 본문 초기화` step 출력 + 워크플로우 종료 후 PR 본문 잔존 확인

## TC-03: 10분 대기 없이 automerge 진행

- **전제**: TC-02에서 본문 유지됨
- **절차**: 워크플로우의 Summary 감지 폴링 단계 진입
- **기대 결과**: 폴링 생략(`초기화 단계에서 이미 Summary 감지 — 폴링 생략`) 후 CHANGELOG 업데이트 → automerge로 즉시 진행, 10분 대기 미발생
- **확인 방법**: Actions 로그에서 폴링 횟수 확인 (1회 이내), deploy 브랜치 머지 완료

## TC-04: 기존 open PR 재사용 (update-pr 경로)

- **전제**: 이미 open된 deploy PR이 존재
- **절차**: `/suh-changelog-deploy` 재실행
- **기대 결과**: 새 PR을 만들지 않고 기존 PR 번호 재사용, `update-pr`로 본문만 갱신
- **확인 방법**: 출력에 `기존 deploy PR #NNN 재사용 → 본문 업데이트`, PR 개수 증가 없음

## TC-05: fix 모드 — 본문 담아 새 PR 생성

- **전제**: automerge 실패로 fix 모드 실행, 사용자가 기존 PR 닫기 승인
- **절차**: fix 1~2단계(기존 PR 닫기) → fix 3단계(커밋 분석) → fix 4단계(릴리스 노트 작성) → fix 5단계(PR 생성)
- **기대 결과**: 새로 생성된 재시도 PR도 본문에 릴리스 노트를 처음부터 포함
- **확인 방법**: 재시도 PR 본문에 `## Summary by CodeRabbit` 존재, 워크플로우 본문 초기화 건너뜀

## TC-06: 임시 노트 파일 정리

- **전제**: TC-01 또는 TC-05 수행
- **절차**: PR 생성 완료 후
- **기대 결과**: `scripts/_release_notes.md` 임시 파일이 삭제됨 (저장소에 커밋되지 않음)
- **확인 방법**: `git status`에 `_release_notes.md` 미존재
