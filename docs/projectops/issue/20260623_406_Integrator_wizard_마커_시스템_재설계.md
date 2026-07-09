📝 현재 문제점
---

`template_integrator`(`.sh`/`.ps1`)의 워크플로우 env 자동 채움에 쓰이는 `@wizard` 마커 시스템이 구조적으로 복잡하고 분산돼 있어 유지보수가 어렵다.

- **주석 한 줄에 action·한글 설명·기본값을 한꺼번에** 욱여넣어(`# @wizard ask: 프로젝트 이름 [기본: 레포명]`), YAML 값 따옴표와 한글·따옴표가 섞여 sed 정규식이 깨지기 쉽다.
- **마커 종류마다 동작이 1:1 하드코딩**: `auto`=PROJECT_NAME, `auto-find`=application.yml 탐색. 새 값이 생길 때마다 분기를 추가해야 한다.
- **기본값이 3곳에 분산**: 마커의 `[기본: ...]` 리터럴 / `default_for_type_key()` 하드코딩 표(.sh·.ps1 양쪽) / `version.yml deploy` 블록.
- **문법 불일치**: `ask:`/`auto-find:`/`paths-anchor`가 제각각이라 파서가 케이스별로 복잡하다.
- **로직·기본값 표가 `.sh`/`.ps1`에 두 벌**이라 한쪽만 고치면 동작이 어긋난다.

🛠️ 해결 방안 / 제안 기능
---

마커 시스템을 **단일 문법 + 문구 분리 + resolver 레지스트리** 구조로 전면 교체한다. (하위호환 미고려 — 기존 마커 전량 마이그레이션)

- **① 마커는 `ask:<기본값>` / `auto:<resolver>` 단일 문법만** — 주석에 한글·따옴표를 넣지 않아 YAML 값 따옴표와 충돌하지 않는다. 정규식 1개(`@wizard (ask|auto):(.*)`)로 파싱.
  - `ask:<기본값>` — 사용자에게 물음(엔터 시 기본값). 기본값은 리터럴(`17`) 또는 `@<resolver>`(동적).
  - `auto:<resolver>` — 묻지 않고 resolver 실행값으로 채움.
- **② 한글 질문 문구만 `.github/wizard/labels.yml`로 분리** — `KEY: "문구"` 맵. 키가 없거나 파일 자체가 없으면 env 키명으로 폴백(가벼운 선택적 의존).
- **③ 타입별 기본값·동적값은 resolver 함수로 흡수** — `default_for_type_key` 하드코딩 표를 제거하고 `resolve_repo`/`resolve_spring_app_yml_dir`/`resolve_spring_app_yml_path` 등 resolver로 대체. `.sh`/`.ps1` 동일 이름·동일 반환.
- **④ 치환 후 `# @wizard` 주석 줄째 삭제** — 결과 워크플로우엔 값만 남는다.
- `paths-anchor` 마커(on.push.paths 주입)는 env 채움과 별개라 그대로 유지.

⚙️ 작업 내용
---

- 워크플로우 17개의 `@wizard` 마커를 새 문법(`ask:기본값` / `auto:resolver`)으로 마이그레이션
- `.github/wizard/labels.yml` 신규 생성(한글 질문 문구 사전)
- `template_integrator.sh`의 `configure_workflow_env` 마커 엔진을 resolver 디스패처 + 새 문법 파서로 재작성, `default_for_type_key` 제거
- `template_integrator.ps1`을 `.sh`와 1:1 동등하게 교체(`Configure-WorkflowEnv`, `Resolve-*`)
- `auto:` 빈값 반환 시 이전 이터레이션 값 오염 버그 수정
- 통합 흐름에 `labels.yml` 복사 추가(통합 프로젝트에서도 한글 질문 노출) — 별도 버그로 #405에서 처리
- 검증: `bash -n`, ps1 파서(`Parser::ParseFile`), expect TTY

> 관련: 본 작업은 #399(Flutter 스토어 심사 자동화 포팅)의 **선행 작업**이다. Flutter의 `FLUTTER_ROOT`는 여기서 만든 resolver 레지스트리 위에 `auto:flutter-root`로 올린다.

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
- 프론트엔드:
- 디자인:
