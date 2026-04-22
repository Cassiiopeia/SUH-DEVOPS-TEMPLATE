# 구현 완료 보고 — #257 issue 스킬 git remote URL 기반 레포 자동 매칭

## 개요

issue 스킬 실행 시 `git remote get-url origin`으로 현재 레포를 자동 감지해
config의 `repos` 배열에서 일치하는 항목을 자동 선택하는 로직을 추가했다.

## 변경 파일

- `skills/issue/SKILL.md` — git remote URL 기반 레포 자동 매칭 로직 추가
- `skills/references/config-rules.md` — 레포 자동 매칭 규칙 문서화
- `docs/suh-template/issue/20260422_#257_...md` — 이슈 파일 등록

## 구현 내용

**git remote URL 기반 자동 매칭 (`skills/issue/SKILL.md`)**

Config 로드 후 바로 아래 절차를 실행한다:

1. `git remote get-url origin` 으로 remote URL 추출
2. `https://github.com/owner/repo` 또는 `git@github.com:owner/repo.git` 패턴에서 `owner`, `repo` 파싱
3. config의 `repos` 배열과 비교해 `owner`+`repo` 모두 일치하는 항목 자동 선택
4. 매칭 실패 시 `default: true` 항목 fallback
5. 위 둘 다 없으면 번호 매겨 사용자에게 선택

**config-rules.md 레포 매칭 규칙 추가**

레포 선택 우선순위를 config-rules에 명시해 다른 스킬에서도 동일한 로직을 참조할 수 있도록 문서화했다.

## 효과

여러 레포를 config에 등록해도 현재 작업 중인 레포를 자동으로 인식하여
매번 레포를 수동으로 선택하지 않아도 된다.

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/257
