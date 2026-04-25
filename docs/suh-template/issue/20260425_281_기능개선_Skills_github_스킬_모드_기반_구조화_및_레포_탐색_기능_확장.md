# 🚀[기능개선][Skills] github 스킬 모드 기반 구조화 및 레포 탐색 기능 확장

**이슈 번호**: #281
**이슈 URL**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/281
**라벨**: 작업전
**날짜**: 2026-04-25

---

## 📝 현재 문제점

기존 `github` 스킬은 이슈/PR 작업만 지원하며, 레포 목록 조회나 단일 레포 상세 정보(README, 언어 구성, 최근 커밋 등)를 가져오는 기능이 없다.
또한 모드 구조가 명시되지 않아 agent가 요청 유형에 따라 어떤 작업을 수행할지 판단하기 어렵다.

## 🛠️ 해결 방안

- 스킬을 3개 모드(issue / pr / explore)로 명시적 구조화
- `explore` 모드 신규 추가:
  - PAT 소유자 자동 감지 (`GET /user`)
  - User / Organization 판별 후 레포 목록 조회
  - 단일 레포 상세 조회 (메타정보, README, 언어 구성, 최근 커밋)
  - 필터링 (fork 제외, 언어별, stars 순) — API 재호출 없이 agent가 처리
- description 트리거 발화에 explore 관련 표현 추가
- Windows / macOS 크로스플랫폼 호환 처리

## 변경 파일

- `skills/github/SKILL.md`
