# 구현 완료 보고 — #281 github 스킬 모드 기반 구조화 및 레포 탐색 기능 확장

## 개요

`cassiiopeia:github` 스킬을 `issue` · `pr` · `explore` 3가지 모드로 구조화하고
`explore` 모드를 신규 추가했다. 유저/Organization의 레포 목록 탐색, 레포 상세 정보 조회,
README 원문 및 언어 구성 조회, 최근 커밋 목록 조회 기능을 지원한다.

## 변경 사항

### Skills
- `skills/github/SKILL.md` — 모드 기반 구조화 및 `explore` 모드 전체 섹션 추가 (169줄 추가)

### 문서
- `docs/suh-template/issue/20260425_#281_...md` — 이슈 파일 등록

## 주요 구현 내용

**모드 기반 구조화**

기존 플랫 구조를 3개 모드로 명시적 분리했다:

| 모드 | 트리거 | 기능 |
|------|--------|------|
| `issue` | 이슈 조회/수정/댓글 | 기존 이슈 작업 |
| `pr` | PR 생성/조회/릴리스 노트 | 기존 PR 작업 |
| `explore` | 레포 탐색 | 신규 추가 |

**explore 모드 신규 추가**

GitHub API를 직접 호출하여 아래 탐색 기능을 제공한다:

- **레포 목록 조회**: `GET /users/{user}/repos` 또는 `GET /orgs/{org}/repos`
  - 이름, 설명, 언어, stars, 최근 업데이트, fork 여부 표시
  - 언어별 필터, fork 제외, stars 순 정렬 지원

- **레포 상세 조회**: `GET /repos/{owner}/{repo}`
  - 기본 정보 + 언어 구성 비율(`GET /repos/{owner}/{repo}/languages`)

- **README 조회**: `GET /repos/{owner}/{repo}/readme` (Base64 디코딩 처리)

- **최근 커밋 조회**: `GET /repos/{owner}/{repo}/commits?per_page=10`

**오류 처리 강화**

API 응답 실패 시 graceful fallback을 적용해 부분 실패가 전체 중단으로 이어지지 않도록 처리했다.

**description 트리거 추가 개선**

explore 모드 추가에 맞춰 "레포 탐색", "레포 목록", "README 조회", "커밋 조회" 등
새 트리거 키워드를 description에 추가했다.

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/281
