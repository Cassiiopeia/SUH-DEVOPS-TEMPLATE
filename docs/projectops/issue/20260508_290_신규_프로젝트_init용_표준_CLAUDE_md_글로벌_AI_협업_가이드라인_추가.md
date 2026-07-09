📝 현재 문제점
---

SUH-DEVOPS-TEMPLATE은 신규/통합 프로젝트에 워크플로우·이슈 템플릿·skill 등 다양한 자산을 배포하지만, **AI 협업 가이드라인(CLAUDE.md)은 의도적으로 제외**되어 있다.

- `.github/scripts/template_initializer.sh` L391~395: 신규 프로젝트 init 시 루트 `CLAUDE.md` 삭제
- `template_integrator.sh` L869~880 / `template_integrator.ps1` L738~750: 통합 시 `docs_to_remove`로 제외

이유: 현재 SUH-DEVOPS-TEMPLATE 루트 `CLAUDE.md`(419줄)는 **템플릿 자체 운영 가이드**(skill 라우팅 표, 워크플로우 추가 규칙 등)이라 신규 프로젝트엔 부적절하기 때문.

결과적으로 SUH-DEVOPS-TEMPLATE으로 시작한 모든 신규 프로젝트는 AI 협업에 관한 표준 원칙(Truthfulness/Simplicity/Verification 등)을 별도로 마련해야 한다. 표준이 없어 프로젝트별로 품질 편차 발생.

🛠️ 해결 방안 / 제안 기능
---

**의존성 0 (skill·workflow·플러그인·외부 경로 참조 전무)인 글로벌 AI 협업 가이드라인**을 별도 템플릿 파일로 관리하고, 신규/통합 시 자동 배포한다.

### 설계 결정 (브레인스토밍 결과)

| 항목 | 결정 | 비고 |
|------|------|------|
| 템플릿 파일 위치 | `.github/templates/CLAUDE.md` (신규 폴더) | 목적 명확. `project-types/common/`은 워크플로우 원본 보관소라 성격 다름 |
| 통합 시 기존 CLAUDE.md 처리 | **사용자에게 물어보기** (1. 덮어쓰기 / 2. `CLAUDE.md.template-suggested`로 별도 저장 / 3. skip) | 자동 머지·덮어쓰기 금지 — 기존 커스텀 손실 위험 |
| 가이드라인 본문 | 외부 65줄 원본에서 **`SuperClaude Reference`·`@RTK.md` 두 섹션 제거** 후 약 55줄 | 두 섹션은 사용자 본인 환경(`~/.claude/reference/superclaude/`, `~/.claude/RTK.md`) 의존. 신규 프로젝트엔 죽은 참조 |

### 가이드라인 본문 구성 (의존성 0 검증 완료)

- Hard Rules — Co-Authored-By 태그 금지
- Core Discipline — 우선순위 5단계 (Truthfulness > Correctness > Simplicity > Surgical scope > Elegance)
- §1 Pre-Execution — Ask vs Act, Plan Mode 트리거, Subagent 위임 기준
- §2 Execution — Simplicity First, Surgical Changes, Elegance Check
- §3 Verification — Define Success Before Starting, Verify Before Marking Done
- §4 Learning — Self-Improvement Loop
- Quick Reference — 5단계 자가 점검 표

skill·workflow·플러그인·외부 path 참조 0건. 어떤 프로젝트에도 즉시 적용 가능.

### 영향받는 파일 (총 4개)

| 파일 | 변경 종류 | 변경 줄 수 |
|------|---------|---------|
| `.github/templates/CLAUDE.md` | **신규 추가** | +55줄 |
| `.github/scripts/template_initializer.sh` | L391~395 — 삭제 → 교체 (글로벌 가이드 복사) | ~10줄 |
| `template_integrator.sh` | L869~880 — `docs_to_remove`에서 글로벌 가이드 path 제외 + 머지 정책 함수 호출 | ~30줄 |
| `template_integrator.ps1` | PowerShell 5.1 호환으로 동등 변경 | ~30줄 |
| `CLAUDE.md` (루트, 운영 가이드) | L153 "복사되지 않는 템플릿 전용 파일" 표 갱신 | 1~3줄 |

### 머지 정책 상세 (통합 모드)

`template_integrator.sh`/`ps1`에서 기존 프로젝트에 글로벌 가이드 배포 시:

```
기존 CLAUDE.md 발견됨. 다음 중 선택:

1. 덮어쓰기 (기존 내용 백업: CLAUDE.md.bak)
2. 별도 저장 (CLAUDE.md.template-suggested로 저장, 사용자가 직접 머지)
3. 건너뛰기 (배포 안 함)
```

기본값 없음. 명시 선택 필수. CI 환경에서는 옵션 2 자동 선택.

### 영향도 종합

- **워크플로우**: 0건 — 어떤 워크플로우도 CLAUDE.md를 읽지 않음
- **skill**: 0건 — skill들은 자기 폴더 내 references/만 참조
- **버전 동기화**: 0건 — version.yml에 CLAUDE.md 항목 없음
- **CHANGELOG/릴리스**: patch bump 자동 처리

📸 참고 자료
---

- 원본 영감: 외부 가이드라인 65줄 (Truthfulness/Simplicity/Surgical scope 5단계 우선순위)
- 의존성 충돌 분석 완료: SuperClaude·RTK 두 섹션 외 충돌 0건
- 관련 스크립트:
  - `.github/scripts/template_initializer.sh` L391~395
  - `template_integrator.sh` L869~880
  - `template_integrator.ps1` L738~750

✅ 예상 동작
---

**신규 프로젝트 (GitHub Template으로 생성 → `template_initializer.sh` 실행)**:
- 루트 `CLAUDE.md`(템플릿 운영 가이드) 삭제 → 동시에 `.github/templates/CLAUDE.md` (글로벌 가이드) 복사
- 결과: 신규 프로젝트 루트에 의존성 0인 AI 협업 가이드라인 자동 배치

**기존 프로젝트 통합 (`template_integrator.sh` 또는 `.ps1` 실행)**:
- 기존 `CLAUDE.md` 없으면 → 글로벌 가이드 그대로 복사
- 기존 `CLAUDE.md` 있으면 → 사용자 선택 (덮/별도/skip)

**SUH-DEVOPS-TEMPLATE 자체 repo**:
- 루트 `CLAUDE.md`(419줄 운영 가이드) 그대로 유지 — 변경 없음

⚙️ 환경 정보
---

- **OS**: 모든 OS (Windows/macOS/Linux 공통)
- **셸**: bash, PowerShell 5.1 호환 필요
- **종속성**: 없음 — 표준 셸 명령만 사용

🙋‍♂️ 담당자
---

- **백엔드**: -
- **프론트엔드**: -
- **디자인**: -
