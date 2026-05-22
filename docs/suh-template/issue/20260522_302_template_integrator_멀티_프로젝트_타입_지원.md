# ⚙️[기능추가][template_integrator] 단일 레포에 여러 프로젝트 타입이 공존하는 경우 지원

- 라벨: 작업전
- 담당자: Cassiiopeia

---

📝 현재 문제점
---

- `template_integrator.sh` / `template_integrator.ps1` 는 **단일 `PROJECT_TYPE` 변수**로만 동작
- `--type TYPE` 옵션이 하나의 값만 받고, `detect_project_type()` 함수도 첫 일치 타입만 반환
- 하나의 레포에 **Spring + React + Python (AI 모듈)** 등 여러 타입이 공존하는 경우, 한 타입의 워크플로우만 배포되어 나머지 타입은 수동으로 추가해야 함
- 실제로 모노레포·다중 모듈 구조 (백엔드 + 프론트 + ML 파이프라인) 가 흔한데 본 템플릿은 이를 가정하지 않음

🛠️ 해결 방안 / 제안 기능
---

### 핵심 변경

| 항목 | 현재 | 변경 후 |
|------|------|--------|
| `--type` 옵션 | 단일 값 (`--type spring`) | 다중 값 (`--type spring,react,python`) |
| 자동 감지 | 첫 일치 타입만 | **모든 일치 타입 배열 반환** |
| 메뉴 | 단일 선택 | 다중 선택 (체크박스 형식 또는 콤마 입력) |
| `version.yml` | `metadata.template.type: spring` | `metadata.template.types: [spring, react, python]` (배열) |
| 워크플로우 복사 | 한 타입 폴더만 | 선택된 모든 타입 폴더의 yaml 머지 |
| 파일명 충돌 | (없음) | 동일 파일명 시 기존 yaml.template.yaml 처리 로직 재사용 |
| 하위 호환성 | — | 기존 `metadata.template.type` (단수) 도 계속 읽기 지원 |

### 변경 범위 (예상)

- `template_integrator.sh`:
  - `PROJECT_TYPE` → `PROJECT_TYPES` (배열)
  - `VALID_TYPES` 검증 시 다중 값 파싱
  - `detect_project_type()` → `detect_project_types()` (전체 일치 반환)
  - `show_project_type_menu()` 다중 선택 UI
  - `copy_workflows()` 루프 타입별 반복
  - `update_version_yml()` `types:` 배열 직렬화
- `template_integrator.ps1`:
  - sh 와 동일 로직을 PowerShell 5.1 호환 문법으로 포팅 (배열 처리, `-contains` 활용)
- `docs/`:
  - `SYNOLOGY-DEPLOYMENT-GUIDE.md`, `TEMPLATE-INTEGRATOR.md` 멀티 타입 사용 예시 추가
- 테스트:
  - 단일 타입 모드 회귀 확인 (`--type spring` 동작 유지)
  - 다중 타입 모드 검증 (`--type spring,react,python`)
  - 자동 감지 — Spring + Node 공존 레포에서 두 타입 모두 감지

### 사용 시나리오

```bash
# 자동 감지 — 여러 타입이 동시에 감지되면 모두 포함 (사용자 확인)
./template_integrator.sh

# 명시 지정
./template_integrator.sh --mode full --type spring,react,python --version 1.0.0

# 비대화형
./template_integrator.sh --mode full --type spring,react --no-synology --version 1.0.0
```

⚙️ 작업 내용
---

- `template_integrator.sh` / `.ps1` 멀티 타입 처리 로직 개편
- `version.yml` 스키마 확장 (`type` → `types`, 하위 호환 유지)
- `copy_workflows()` 다중 타입 머지 + 파일명 충돌 처리
- 메뉴 UI 다중 선택 지원
- 가이드 문서 (`TEMPLATE-INTEGRATOR.md`) 멀티 타입 예시 추가
- 회귀 테스트 케이스 추가

🙋‍♂️ 담당자
---

- 개발: Cassiiopeia
