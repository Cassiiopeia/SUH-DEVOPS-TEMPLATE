# 구현 완료 보고 — #269 common-rules Git 컨텍스트 확인 프로토콜 추가

## 개요

`skills/references/common-rules.md`의 작업 시작 프로토콜에 Git 컨텍스트 확인 단계를 추가했다.
코드 수정이 수반되는 작업 전 현재 브랜치 상태를 점검하고 main 브랜치에서의 직접 작업을 방지한다.

## 변경 파일

- `skills/references/common-rules.md` — Git 컨텍스트 확인 프로토콜 섹션 신규 추가

## 구현 내용

**작업 시작 프로토콜 4단계에 Git 컨텍스트 확인 추가 (`skills/references/common-rules.md`)**

작업 시작 전 반드시 거쳐야 하는 단계로 §86에 추가했다:

```
4. Git 컨텍스트 확인 (코드 수정이 수반되는 작업 시 필수) — 아래 §Git 컨텍스트 확인 프로토콜 수행
```

**§ Git 컨텍스트 확인 프로토콜 (신규 섹션)**

1단계: 현재 브랜치 확인
- 현재 브랜치가 main(또는 master 등 default branch)이면 즉시 멈추고 사용자에게 확인
- 이슈 연결 여부, 새 이슈 생성 필요 여부를 묻는 대화 흐름 추가

2단계: 브랜치명 형식 확인
- `YYYYMMDD_#번호_제목` 형식인지 검증
- 형식에 맞지 않으면 사용자에게 확인 요청

3단계: worktree 여부 확인
- feature 브랜치가 확정되면 worktree로 격리할지 현재 디렉토리에서 브랜치만 생성할지 선택

**제외 대상 명시**

분석·계획 전용 스킬(`/plan`, `/analyze`, `/design-analyze`, `/refactor-analyze`)은 이 프로토콜 대상에서 제외됨을 명시했다.

## 효과

- main 브랜치에서 코드를 직접 수정하는 사고 방지
- 이슈 번호가 없는 브랜치에서의 미확인 작업 진행 방지
- worktree 사용 여부 선택 기회 제공으로 작업 격리 수준 향상

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/269
