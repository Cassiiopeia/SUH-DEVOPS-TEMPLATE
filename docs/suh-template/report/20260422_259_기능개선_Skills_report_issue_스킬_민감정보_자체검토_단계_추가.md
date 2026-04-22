# 구현 완료 보고 — #259 report·issue 스킬 파일 저장 직전 민감정보 자체검토 단계 추가

## 개요

report·issue 스킬이 파일을 저장하기 전에 민감정보(PAT, 비밀번호, 개인정보 등)가 포함되어 있는지
자동으로 검토하는 단계를 추가했다.

## 변경 파일

- `skills/references/common-rules.md` — 민감정보 자체검토 프로토콜 추가
- `skills/issue/SKILL.md` — 파일 저장 직전 자체검토 단계 삽입
- `skills/report/SKILL.md` — 파일 저장 직전 자체검토 단계 삽입

## 구현 내용

**민감정보 자체검토 프로토콜 (`skills/references/common-rules.md`)**

파일 저장 전 아래 항목을 점검하는 프로토콜을 공통 규칙에 추가했다:
- GitHub PAT (`ghp_`, `github_pat` 등)
- 비밀번호, 시크릿 키
- 개인 이메일, 전화번호
- 내부 도메인/IP 직접 노출

**issue·report 스킬 저장 전 체크 단계**

파일을 Write 도구로 저장하기 직전에 common-rules의 자체검토 프로토콜을 실행하고,
민감정보 발견 시 사용자에게 알린 후 마스킹 처리하거나 저장을 중단하는 흐름을 추가했다.

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/259
