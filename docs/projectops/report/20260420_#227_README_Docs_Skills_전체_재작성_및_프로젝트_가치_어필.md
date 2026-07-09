# 📄[문서][README/Docs] SUH-DEVOPS-TEMPLATE 전체 문서 개편 및 프로젝트 가치 재정의

## 개요

README.md가 단순 기능 나열 수준에 머물러 있어 프로젝트 가치를 전달하지 못하던 문제를 해결했다. README 전면 재작성, `/commit` 스킬 신규 추가, `docs/suh-template/` 공개 전환, commit 컨벤션·민감정보 마스킹 규칙 추가를 포함한 전체 문서 개편을 완료했다.

## 변경 사항

### 문서

- `README.md`: 전면 재작성. "개발자는 코드만 작성하세요" 철학 강조, GitHub Actions + Claude Code Skills 두 축 설명, Before/After 비교 테이블 확장(`/commit`, `/report` 추가), AI 개발 사이클 mermaid 다이어그램 업데이트, Skills 4개 카테고리로 재편(개발 사이클 자동화 4종 / 분석형 6종 / 구현형 6종 / 문서산출물 5종)
- `docs/SKILLS.md`: `/cassiiopeia:commit` 스킬 섹션 신규 추가. superpowers 원칙, 커밋 컨벤션, 블로커 처리 흐름 문서화. 표준 개발 플로우 mermaid 업데이트.

### 신규 스킬

- `skills/commit/SKILL.md`: 이슈 컨텍스트 기반 커밋 메시지 자동 완성 스킬. superpowers 원칙 준수(사용자 확인 없이 커밋 금지, git push 금지, staged 없으면 git add 대신 안 함). owner/repo 자동 추출(`git remote get-url origin` 파싱).

### 규칙 및 설정

- `skills/references/common-rules.md`: 커밋 메시지 컨벤션 추가(`이슈제목 : 타입 : 설명 이슈URL`), 민감정보 마스킹 규칙 추가
- `.gitignore`: `docs/suh-template/` 추적 제외 항목 삭제(공개 전환), `.suh-template/config/issue.config.json` PAT 보호 추가
- `template_initializer.sh`, `template_integrator.sh`, `template_integrator.ps1`: `docs/suh-template/` gitignore 관련 로직 제거

## 주요 구현 내용

**commit 스킬 핵심 설계**: `current-issue.json`의 `commit_template`을 기본값으로 사용하고 변경사항 설명만 채워 완성한다. staged 파일 없음 / 이슈 컨텍스트 없음 두 가지 블로커에서 즉시 멈추고 선택지를 제시한다. owner/repo는 `git remote get-url origin` sed 파싱으로 HTTPS/SSH 양식 모두 지원한다.

**docs/suh-template/ 공개 전환**: 이슈/보고서/플랜 산출물이 쌓이는 폴더를 공개로 전환해 팀 협업 가시성을 높였다. PAT가 포함된 `issue.config.json`은 gitignore로 보호.

## 주의사항

- `docs/SKILLS-OVERVIEW.md`, `docs/AUTOMATION-PHILOSOPHY.md` 신규 작성은 이번 작업 범위에서 제외 — 추후 별도 작업 필요
- README.md는 150줄 기준을 초과(246줄)했으나 스킬 카탈로그 포함 필요로 허용
