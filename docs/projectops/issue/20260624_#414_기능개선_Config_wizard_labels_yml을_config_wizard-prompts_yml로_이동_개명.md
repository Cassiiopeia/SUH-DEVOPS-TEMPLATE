📝 현재 문제점
---

- `.github/wizard/labels.yml`은 이름과 다르게 GitHub 이슈 라벨과 무관하며, 마법사의 `env` 질문 문구 사전을 담고 있어 개발자에게 혼동을 줍니다.
- 이 파일만 `.github/wizard/`에 따로 분산되어 있어, `.github/config/`에 있는 다른 설정 파일들(`breaking-changes.json`, `issue-labels.yml` 등)과의 일관성이 떨어집니다.
- 만약 이 파일을 단순히 `config/` 하위로 이동하기만 하면 `issue-labels.yml`과 이름이 겹쳐 혼동이 발생하므로 명확한 구분이 필요합니다.

🛠️ 해결 방안 / 제안 기능
---

- `.github/wizard/labels.yml` 파일을 `.github/config/wizard-prompts.yml`로 이동 및 개명합니다.
- `template_integrator.sh` 및 `template_integrator.ps1`에서 기존 `wizard/labels.yml` 경로를 참조하던 부분을 새 경로로 업데이트합니다.
- 기존의 전용 복사 함수(`copy_wizard_labels` / `Copy-WizardLabels`)를 삭제하고, `config/` 폴더를 통째로 복사하는 기존 공통 복사 함수(`copy_config_folder` / `Copy-ConfigFolder`)로 복사 로직을 통합합니다.

⚙️ 작업 내용
---
- [x] `.github/wizard/labels.yml`을 `.github/config/wizard-prompts.yml`로 이동 (git mv)
- [x] `template_integrator.sh` 내 참조 경로 수정 및 `copy_wizard_labels` 함수 삭제
- [x] `template_integrator.ps1` 내 참조 경로 수정 및 `Copy-WizardLabels` 함수 삭제
- [x] 수정 사항에 대한 쉘/파워쉘 문법 검증 및 동작 검증 수행

🙋‍♂️ 담당자
---

- 담당자: Cassiiopeia
