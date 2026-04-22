---
title: ❗[버그][ISSUE_TEMPLATE] labels 필드 '작업 전' 띄어쓰기 오류로 GitHub 라벨 중복 생성
labels: [작업전]
assignees: [Cassiiopeia]
---

🗒️ 설명
---

`.github/ISSUE_TEMPLATE/` 하위 4개 파일의 `labels` 필드가 `작업전`이 아닌 `작업 전`(띄어쓰기 포함)으로 잘못 설정되어 있다.  
GitHub 웹 UI 또는 API로 이슈를 생성할 때 해당 라벨명이 저장소에 존재하지 않으면, GitHub이 자동으로 없는 이름의 라벨을 신규 생성해버려 중복 라벨 문제가 발생한다.

🔄 재현 방법
---

1. `ISSUE_TEMPLATE`의 템플릿을 사용하여 GitHub 웹 UI에서 이슈 생성
2. 이슈가 생성되면 `작업 전` (띄어쓰기 있음) 라벨이 자동으로 신규 생성됨
3. 저장소 라벨 목록에 `작업전`과 `작업 전` 두 개가 공존하는 상태가 됨

📸 참고 자료
---

영향받는 파일 4개:

| 파일 | 잘못된 값 | 올바른 값 |
|------|-----------|-----------|
| `.github/ISSUE_TEMPLATE/bug_report.md` | `labels: [작업 전]` | `labels: [작업전]` |
| `.github/ISSUE_TEMPLATE/feature_request.md` | `labels: [작업 전]` | `labels: [작업전]` |
| `.github/ISSUE_TEMPLATE/design_request.md` | `labels: [작업 전]` | `labels: [작업전]` |
| `.github/ISSUE_TEMPLATE/qa_request.md` | `labels: [작업 전]` | `labels: [작업전]` |

✅ 예상 동작
---

- 이슈 생성 시 기존에 정의된 `작업전` 라벨이 정상적으로 적용되어야 함
- 중복 라벨이 자동 생성되지 않아야 함

⚙️ 환경 정보
---

- **영향 범위**: SUH-DEVOPS-TEMPLATE을 사용하는 모든 프로젝트
- **발생 조건**: GitHub 웹 UI 또는 API로 이슈 템플릿 사용 시

🙋‍♂️ 담당자
---

- **담당자**: Cassiiopeia
