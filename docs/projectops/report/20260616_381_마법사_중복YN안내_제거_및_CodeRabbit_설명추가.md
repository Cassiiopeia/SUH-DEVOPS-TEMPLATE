# template_integrator 마법사 중복 Y/N 안내 제거 및 CodeRabbit 설명 추가

## 개요

`template_integrator` 마법사가 화살표 메뉴(예/아니오 2지선다)를 이미 보여주는데도, 그 위에 `Y/y - 예`, `N/n - 아니오` 같은 텍스트 안내를 또 출력해 화면이 중복되고 지저분했다. 이번 작업으로 화살표 메뉴와 겹치던 중복 Y/N 안내를 제거하고, 맥락 없이 "선택"만 표시되던 프롬프트를 실제 질문 문장으로 교체했다. 더불어 `.coderabbit.yaml`을 적용하기 직전 CodeRabbit이 무엇이고 어떤 설정으로 동작하며 어떻게 활성화하는지 안내하는 설명을 추가했다. 같은 이슈로 묶인 UX 개선 — 예/아니오 선택지 순서를 항상 1)예 2)아니오로 통일, `.coderabbit.yaml` 덮어쓰기 확인을 덮어쓰기/건너뛰기 2지선다로 변경, Synology 질문 부가 설명 추가, 확인 화면 수정 메뉴에 Synology 포함 여부 항목 추가 — 도 함께 반영했다. 모든 변경은 `template_integrator.ps1`과 `template_integrator.sh` 양쪽에 대칭으로 적용했다.

## 변경 사항

### 중복 Y/N 안내 정리
- `template_integrator.ps1`: 화살표 메뉴와 겹치던 `Y/y`·`N/n`(또는 `Y 업데이트`·`N 취소`) 안내 두 줄을 5곳에서 제거 — version.yml 업데이트 확인(`Create-VersionYml`), 호환성 변경 확인(`Test-BreakingChanges`), Synology 포함 확인(`Ask-SynologyOption`), 유틸리티 모듈 다운로드 확인(`Copy-UtilModules`), Codex native skills fallback 설치 확인(`Invoke-CodexNativeSkillsFallback`).
- `template_integrator.ps1`·`template_integrator.sh`: 맥락 없이 `"선택"`만 넘기던 프롬프트를 실제 질문 문장으로 교체(예: `"Synology 워크플로우를 포함할까요?"`, `"이 유틸리티 모듈을 다운로드할까요?"`, `"Codex native skills fallback을 설치/업데이트할까요?"`).
- `template_integrator.sh`: version.yml 업데이트 박스의 `Y 업데이트하고 계속`·`N 통합 취소` 안내 두 줄 제거.

### CodeRabbit 안내 추가
- `template_integrator.ps1`: `Show-CodeRabbitIntro` 함수 신설. `Copy-CodeRabbitConfig`에서 `.coderabbit.yaml` 적용 직전(덮어쓰기·신규 공통) 호출.
- `template_integrator.sh`: `show_coderabbit_intro` 함수 신설. `copy_coderabbit_config`에서 동일 위치 호출.
- 안내 내용: CodeRabbit 소개(PR에 AI가 자동 리뷰 코멘트), 이 파일에 들어가는 설정 요약(리뷰 언어 한국어, 자동 리뷰 켜짐, chill 성향, PR 채팅 자동응답), 그리고 파일만으로는 끝이 아니라 coderabbit.ai에서 저장소를 한 번 연결(Authorize/Enable)해야 리뷰가 달린다는 활성화 안내.

### 예/아니오 선택지 순서 통일
- `template_integrator.ps1`: `Invoke-ArrowMenu`에 `-InitialIndex` 파라미터 추가(커서 초기 위치 지정, 범위 벗어나면 0). `Ask-YesNo`가 기본값에 따라 항목 순서를 뒤집던 로직을 제거하고, 항목은 항상 `1) 예  2) 아니오`로 고정한 뒤 기본값은 `-InitialIndex`(기본 Y→0, 기본 N→1)로만 표현하도록 변경.
- `template_integrator.sh`: `interactive_menu`에 `--initial-index=N` 옵션 추가(단일 선택 커서 초기 위치). `legacy_numeric_menu`는 해당 옵션을 파싱만 하고 무시(텍스트 메뉴엔 커서 개념 없음). `ask_yes_no`도 순서 고정 + `--initial-index`로 기본값 표현하도록 변경.

### .coderabbit.yaml 덮어쓰기 선택지 통일
- `template_integrator.ps1`: 기존 `.coderabbit.yaml` 덮어쓰기 확인을 단순 예/아니오 대신 `Invoke-ChooseMenu` 2지선다(`덮어쓰기 — .bak 백업 후 교체(권장)` / `건너뛰기 — 기존 파일만 유지`)로 변경. ESC(`$null`) 또는 건너뛰기 선택 시 기존 유지.
- `template_integrator.sh`: 동일하게 `choose_menu` 2지선다로 변경. 워크플로우 충돌 메뉴와 표현을 통일해 "건너뛰기" 의도를 명확히 노출.

### Synology 질문 부가 설명
- `template_integrator.ps1`·`template_integrator.sh`: Synology 워크플로우 포함 질문(`Ask-SynologyOption`/`ask_synology_option`)에 Synology(시놀로지)가 무엇인지(NAS 자체 서버), 포함/제외 판단 가이드(직접 배포 계획이면 포함, AWS·클라우드·미상이면 제외 권장), 나중에 `--synology` 옵션으로 추가 가능하다는 안내를 추가.

### 확인 화면 수정 메뉴에 Synology 항목 추가
- `template_integrator.ps1`: `Edit-ProjectInfo`의 수정 메뉴에 워크플로우를 설치하는 모드(`full`/`workflows`)일 때만 `Synology 포함 여부 (현재: 포함/제외)` 항목을 노출. 선택 시 `Ask-SynologyOption -ForceAsk` 호출. `Ask-SynologyOption`에 `-ForceAsk` 스위치 추가.
- `template_integrator.sh`: `handle_project_edit_menu`에 동일 항목 추가(동일 모드 조건). 선택 시 `ask_synology_option --force-ask` 호출. `ask_synology_option`에 `--force-ask` 인자 처리 추가.

## 주요 구현 내용

- **InitialIndex / --initial-index (기본값 표현 분리)**: 기존에는 기본값(Y/N)에 따라 메뉴 항목 순서 자체를 뒤집어 보여줘 일관성이 깨졌다. 이제 항목 순서는 항상 `1) 예  2) 아니오`로 고정하고, 기본값은 "어느 항목에 커서를 처음 올려둘지"(InitialIndex)로만 표현한다. `Invoke-ArrowMenu`(ps1)와 `interactive_menu`(sh)가 커서 초기 위치를 받아 처리하며, 범위를 벗어나거나 숫자가 아니면 0으로 폴백한다. sh의 `legacy_numeric_menu`는 커서 개념이 없어 옵션을 파싱만 하고 무시한다.
- **force-ask (재질문 강제)**: 기존 `Ask-SynologyOption`/`ask_synology_option`은 `IncludeSynology` 값이 이미 설정되어 있거나 version.yml 저장값이 있으면 곧바로 건너뛰어, 확인 화면에서 한 번 정한 뒤에는 다시 바꿀 수 없었다. `-ForceAsk`(ps1)/`--force-ask`(sh) 플래그를 추가해, 이 플래그가 켜지면 이미 설정된 값과 저장값 읽기를 모두 건너뛰고 무조건 다시 질문하도록 했다. 확인 화면 수정 메뉴가 이 플래그로 호출해 사용자가 명시적으로 다시 고를 수 있게 했다.
- **수정 메뉴의 모드 가드**: Synology 수정 항목은 워크플로우를 실제로 설치하는 `full`/`workflows` 모드에서만 노출한다. `version` 모드는 워크플로우를 깔지 않아 Synology와 무관하므로 메뉴에 보이지 않는다.
- **CodeRabbit 안내 함수 분리**: 덮어쓰기·신규 적용 양쪽에서 공통으로 보여줄 수 있도록 소개·설정 요약·활성화 안내를 별도 함수(`Show-CodeRabbitIntro`/`show_coderabbit_intro`)로 분리하고 `.coderabbit.yaml` 적용 직전에 호출한다.

## 주의사항

- **sh/ps1 대칭**: 모든 변경은 `template_integrator.sh`(bash)와 `template_integrator.ps1`(PowerShell) 양쪽에 동일하게 적용했다. 한쪽만 고치면 OS별로 마법사 동작이 갈리므로, 추후 수정 시에도 두 파일을 함께 유지해야 한다.
- **set -e 환경의 ESC 흡수(sh)**: `.coderabbit.yaml` 덮어쓰기 2지선다는 `choose_menu` 결과를 `|| true`로 흡수한다. `set -e` 환경에서 ESC(취소)가 비-0 종료코드를 반환하면 함수 전체가 통째로 종료되는 문제를 막기 위함이다. PowerShell은 `$ErrorActionPreference="Stop"`이 `throw`에만 작동하고 비-0 반환에는 반응하지 않아 동일한 방어가 필요 없다.
- **ESC = 안전한 취소/유지 의미 보존**: 2지선다 메뉴에서 ESC(`$null`)는 "건너뛰기/기존 유지"로 해석한다(`(-not $crChoice) -or ($crChoice -eq 'S')`). 사용자가 확신이 없을 때 ESC로 빠져나가도 기존 파일이 보존된다.
- **레거시 텍스트 메뉴 호환(sh)**: TTY가 없거나 화살표 메뉴를 지원하지 않는 환경에서 동작하는 `legacy_numeric_menu`는 `--initial-index` 옵션을 무시한다(커서 개념 부재). 따라서 비대화형/제한 환경에서도 인자 파싱이 깨지지 않는다.
