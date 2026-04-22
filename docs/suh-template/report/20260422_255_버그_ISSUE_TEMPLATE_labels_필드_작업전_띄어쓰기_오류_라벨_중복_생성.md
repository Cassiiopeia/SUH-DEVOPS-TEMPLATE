# 구현 완료 보고 — #255 ISSUE_TEMPLATE labels 필드 '작업 전' 띄어쓰기 오류 수정

## 개요

`.github/ISSUE_TEMPLATE/` 내 모든 템플릿 파일의 `labels` 필드에서
'작업 전'(띄어쓰기 있음)을 '작업전'(띄어쓰기 없음)으로 통일하여 GitHub 라벨 중복 생성 문제를 해결했다.

## 변경 파일

- `.github/ISSUE_TEMPLATE/bug_report.md` — labels 필드 `작업전`으로 수정
- `.github/ISSUE_TEMPLATE/feature_request.md` — labels 필드 `작업전`으로 수정
- `.github/ISSUE_TEMPLATE/design_request.md` — labels 필드 `작업전`으로 수정
- `.github/ISSUE_TEMPLATE/qa_request.md` — labels 필드 `작업전`으로 수정
- `skills/issue/SKILL.md` — 라벨 임의 변경 금지 규칙 추가

## 구현 내용

**문제**

ISSUE_TEMPLATE의 `labels` 필드에 '작업 전'(띄어쓰기 포함)이 사용되어
GitHub에서 '작업전'과 '작업 전' 두 개의 라벨이 중복 생성되는 문제가 있었다.

**해결**

모든 ISSUE_TEMPLATE 파일의 labels 필드를 `[작업전]`으로 통일했다.
아울러 issue 스킬 SKILL.md에 라벨을 임의로 변경하지 않도록 명시적 규칙을 추가했다.

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/255
