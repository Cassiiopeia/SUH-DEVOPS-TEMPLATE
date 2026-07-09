🗒️ 설명
---

`template_integrator`(`.sh`/`.ps1`)로 기존 프로젝트에 템플릿을 **통합**할 때, 워크플로우 파일은 복사하면서 **`.github/wizard/labels.yml`은 복사하지 않아**, 통합된 프로젝트에서 마법사를 다시 돌릴 때 `@wizard ask:` 마커를 쓰는 워크플로우들의 **한글 질문 문구가 표시되지 않는** 문제.

- 마커 엔진 재설계 때 워크플로우의 한글 질문 문구를 `@wizard` 마커 본문에서 분리해 `.github/wizard/labels.yml`로 옮겼는데, 통합 흐름(`full`·`workflows` 모드)에 이 파일을 복사하는 단계가 빠져 있었다.
- 그 결과 통합 대상 프로젝트에는 워크플로우(`@wizard ask:` 마커 사용 16개)만 들어가고 질문 문구 원본(`labels.yml`)은 누락되어, '하나씩 입력' 모드에서 빈 질문/영문 키만 노출된다.

🔄 재현 방법
---

1. `labels.yml`을 사용하는 템플릿 버전으로 기존 프로젝트에 `template_integrator`를 `full` 또는 `워크플로우만` 모드로 통합한다.
2. 통합된 프로젝트에서 워크플로우 설정 마법사('하나씩 입력' 경로)를 실행한다.
3. `@wizard ask:` 마커가 있는 워크플로우의 질문 단계에서 한글 안내 문구가 뜨지 않는 것을 확인한다.

📸 참고 자료
---

- 영향 범위: `@wizard ask:` 마커 사용 워크플로우 16개
- 원본 파일: `.github/wizard/labels.yml`
- 관련 함수: `template_integrator.sh`의 `copy_config_folder`(인접 복사 단계), `template_integrator.ps1`의 `Copy-ConfigFolder`

✅ 예상 동작
---

- 통합 시 워크플로우와 함께 `.github/wizard/labels.yml`도 사용자 프로젝트로 복사되어야 한다.
- 통합된 프로젝트에서 마법사의 '하나씩 입력' 모드를 실행하면 워크플로우별 한글 질문 문구가 정상 노출되어야 한다.
- 템플릿 원본에 `.github/wizard` 폴더가 없을 경우(구버전 등)에는 오류 없이 안전하게 건너뛰어야 한다.
- `.sh`와 `.ps1` 동작이 동등해야 한다.

⚙️ 환경 정보
---

- **OS**: Windows / macOS / Linux (통합 스크립트 공통)
- **대상**: `template_integrator.sh`, `template_integrator.ps1`
- **모드**: 전체 설치(`full`) / 워크플로우만(`workflows`)

🙋‍♂️ 담당자
---

- **백엔드**: Cassiiopeia
- **프론트엔드**:
- **디자인**:
