# #328 changelog-deploy 릴리스 노트 사용자 승인 게이트 + 자동화 옵션 — 구현 보고서

이슈: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/328
관련 후속 이슈: #340 (3 스킬 통일)
관련 PR/커밋: #339 (게이트 도입), #341 (auto_approve 통일 마무리)

## 무엇을 / 왜 바꿨는가

기존 `suh-changelog-deploy`는 5단계에서 릴리스 노트 파일을 작성한 직후 6단계 PR 생성으로 즉시 진행해 사용자가 본문을 검토할 시점이 없었다. 자동 모드를 원하는 사용자도 있어 일률 강제가 부적절. **승인 게이트(5.5단계 / fix 4.5단계) + 자동/수동 토글 + 첫 실행 자동화 제안**을 도입했다.

## 변경 사항

### 1) deploy 5.5단계 / fix 4.5단계 신규

- **A. 자동 모드**: 릴리스 노트 본문 표시 후 즉시 6단계(PR 생성). 사용자 응답 대기 없음
- **B. 수동 모드(기본)**: 본문 표시 + 승인/수정 분기. 수정 요청 시 5단계로 되돌아가 노트 재작성 후 5.5단계 재진입
- **C. 첫 실행 자동화 제안**: 수동 승인 후 1회만 "이 레포 / 모든 레포 / 매번 확인" 선택. agent가 config 직접 갱신

### 2) 핵심 원칙 추가

- "릴리스 노트 본문은 PR 생성 전 사용자에게 보여준다" — 자동 모드라도 표시는 함
- "사용자에게 config 키 이름·파일 경로를 노출하지 않는다" — 자연어 토글만

### 3) Config 스키마

이슈 원안의 `changelog_deploy.auto_approve_release_notes`로 1차 도입, 이후 #340에서 3 스킬 통일을 위해 `changelog_deploy.auto_approve`로 rename(구 키는 명시적 break).

### 4) 레이스컨디션 보호

PR 생성 순서를 "커밋 분석 → 릴리스 노트 작성 → 본문 담아 PR 생성"으로 고정. AUTO-CHANGELOG-CONTROL 워크플로우가 빈 본문을 초기화하는 race 방지.

### 5) 자동 모드 사용자 응답 처리

A 분기 메시지 출력 후 "확인받게 해줘" / "수동으로 바꿔줘" 같은 자연어 응답을 받으면 PR 생성 전에 config를 `false`로 갱신하고 B 분기로 전환.

## 변경 파일

- `skills/suh-changelog-deploy/SKILL.md` — 5.5단계 / fix 4.5단계 신규, 핵심 원칙 갱신, 시작 전 §3 자동 승인 판정 추가
- `skills/references/config-rules.md` §7 — `changelog_deploy.auto_approve` 스키마·해석 우선순위 명시
- `skills/config.json.example` — 글로벌·레포별 토글 예시 추가
- 후속 #340으로 3 스킬 통일 패턴으로 마무리

## 검증

- PR #339·#341 모두 자동 모드 흐름으로 정상 머지 (실측 자동 머지 60초 내 완료)
- 본인 config에 `repos[SUH-DEVOPS-TEMPLATE].changelog_deploy.auto_approve: true`로 set됨
