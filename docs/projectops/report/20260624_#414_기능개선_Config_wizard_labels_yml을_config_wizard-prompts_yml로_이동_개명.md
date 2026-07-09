# 🚀[기능개선][Config] wizard/labels.yml을 config/wizard-prompts.yml로 이동·개명

## 개요
기존에 `.github/wizard/labels.yml`에 흩어져 있던 마법사 env 질문 문구 사전을 `.github/config/` 폴더 하위로 통합하고, GitHub 이슈 라벨 정보인 `issue-labels.yml`과의 혼동을 막기 위해 `wizard-prompts.yml`로 개명하였습니다. 이와 더불어 `template_integrator` 스크립트에서 기존의 불필요해진 전용 복사 함수(`copy_wizard_labels` / `Copy-WizardLabels`)를 완전히 정리하고, 기존의 공통 설정 폴더 복사 함수(`copy_config_folder` / `Copy-ConfigFolder`)로 로직을 통합하였습니다.

## 변경 사항

### [설정 파일 이동 및 개명]
- `.github/wizard/labels.yml` ➔ `.github/config/wizard-prompts.yml` (git mv로 히스토리 보존 완료)

### [통합 스크립트 수정]
- `template_integrator.sh`:
  - `LABELS_FILE` 기본값을 `.github/config/wizard-prompts.yml`로 변경
  - `_wf_labels_path` 폴백 경로 및 주석 문구 새 위치 반영
  - 불필요해진 `copy_wizard_labels` 함수 제거 및 전체 실행 프로세스(`execute_integration`) 호출부 삭제
- `template_integrator.ps1`:
  - `Get-WfLabelsPath` 내 목적지($dst) 및 원본($src) 경로를 새 위치로 변경
  - 불필요해진 `Copy-WizardLabels` 함수 제거 및 `Start-Integration` 내 호출부 삭제

## 주요 구현 내용
- **기존 공통 함수 활용으로 코드 슬림화**: `.github/config/*`는 기존에 `copy_config_folder` / `Copy-ConfigFolder` 함수가 통째로 복사해주기 때문에, `wizard-prompts.yml`이 해당 디렉터리로 들어감으로써 전용 복사 함수를 안전하게 영구 삭제(순감소 -55라인)할 수 있었습니다.
- **폴백 메커니즘 유지**: 신규 통합 프로세스 도중 env 값을 묻는 시점에는 복사 함수들이 돌기 전이므로, 다운로드 원본(`$TEMP_DIR/.github/config/wizard-prompts.yml`)을 가리키는 기존 폴백 탐색 순서를 그대로 유지하여 오작동을 방지하였습니다.

## 주의사항
- **기존 사용자 프로젝트 하위 호환성**: 이전 버전의 integrator를 사용하던 기존 프로젝트가 새 integrator로 패키지 업데이트를 할 때, 새 파일인 `wizard-prompts.yml`이 정상 반영되나 기존 `wizard/labels.yml`은 자동으로 삭제되지 않고 고아 파일(死파일)로 남습니다. 동작에는 무해하며, 마법사 구동 시 새 경로를 우선 참조하므로 영향이 없습니다.
