<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

## Summary by CodeRabbit

## 릴리스 노트

* **새 기능**
  * GitHub 연동 CLI 도구(`github_cli`) 상에 누락되어 있던 Actions 빌드/오류 실시간 조회(`actions`) 서브커맨드 구현 완비

* **버그 수정**
  * 보고서 결과 댓글 상에서 특수 기호 혼용으로 인해 터지던 Mermaid 그래프 문법 오류 긴급 패치 완료

* **개선**
  * 뷰포트 크기에 따른 가독성 저하를 예방하기 위해 가로형 흐름도(`flowchart LR`) 금지 및 수직 하강형(`flowchart TD`) 명세 완전 강제화
  * Mermaid 파싱 실패를 유발하는 `subgraph` 명세 내 특수 문자 및 한글 혼용 전면 제한 및 가이드 문서화 수칙 공인

* **문서**
  * 이슈 본문 누락 방지 설계 및 완결 결과 정식 보고서 산출물 기록 보관

<!-- end of auto-generated comment: release notes by coderabbit.ai -->

