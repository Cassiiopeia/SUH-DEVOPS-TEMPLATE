📝 현재 문제점
---

- SUH-DEVOPS-TEMPLATE는 Claude Code · Cursor · Gemini CLI · Codex CLI 4개 AI 에이전트에만 스킬을 배포해왔습니다.
- 최근 사용 환경에 PI(pi-coding-agent)가 추가되면서, 동일한 DevOps 스킬을 PI에서도 호출할 수 있어야 합니다.
- 또한 PI에는 다른 에이전트에 없는 고유 개념인 **Persona Harness**(대화 시작 시 전문가 페르소나와 SDLC 워크플로우를 시스템 프롬프트에 자동 주입)가 있어, 이를 함께 지원해 답변 품질을 끌어올릴 필요가 있습니다. harness는 skill과 독립적이므로, 설치 시 활성화 여부를 묻고 제거 시 함께 해제되어야 합니다.
- 현재 `template_integrator`(기존 프로젝트 통합 마법사)와 `template_initializer`(템플릿으로 새 프로젝트 생성 시 초기화)에는 PI 설치/관리 경로가 전혀 없습니다.

🛠️ 해결 방안 / 제안 기능
---

- PI를 5번째 배포 대상 AI 에이전트로 추가하고, 기존 4개 에이전트와 **동일한 화살표+Enter 메뉴 UX**로 설치/업데이트/제거할 수 있게 합니다.
- PI 고유의 **Persona Harness**는 설치 직후 활성화 여부만 묻고(이미 켜져 있으면 유지), 제거 흐름에서 PI를 고르면 함께 자동 해제되게 합니다. 활성화 제안 시 페르소나·워크플로우가 무엇인지 간단한 설명을 함께 노출합니다.
- skill은 그대로 두고 **harness만 단독으로 켜고/끌 수 있도록**, IDE 선택 메뉴에 `PI Persona Harness` 항목을 별도로 제공합니다(설치/업데이트에서 고르면 토글, 제거에서 고르면 harness만 해제).
- 레포가 가진 두 정체성(① GitHub 템플릿 ② 마법사 배포원)에 맞춰, PI 전용 파일이 **새 프로젝트로 오염되지 않도록** 초기화/통합 양쪽 제외 경로를 정합합니다.
- macOS · Windows 양쪽에서 동일하게 동작하도록 보장합니다.

⚙️ 작업 내용
---

- **레포 내 PI 패키지 인프라 신규 추가**
  - `package.json` — PI가 패키지로 인식하기 위한 매니페스트(`pi.skills` → `./skills`)
  - `harness/` — `harness-loader.ts`(loader) + `PERSONA.md`(전문가 페르소나) + `WORKFLOW.md`(SDLC 워크플로우)
- **`template_integrator.sh` / `template_integrator.ps1` 양쪽에 PI 지원 추가**
  - 상태 표시(`PI : skill 설치됨/미설치`), 2단계 라우터의 IDE 후보·preselect·설치/제거 분기·FORCE 흐름에 PI 합류
  - `pi install/update/remove`로 설치/업데이트/제거, `pi list` 출력으로 설치 검증
  - Persona Harness 처리(`~/.pi/agent/settings.json`의 `extensions` 등록/해제): **설치 시** 꺼져 있으면 활성화 여부를 묻고(이미 켜져 있으면 유지), 개념 설명 문구 포함 / **제거 시** PI를 고르면 패키지 제거와 함께 harness 등록도 자동 해제
  - IDE 선택 메뉴에 `PI Persona Harness` 별도 항목 추가 — skill은 보존한 채 harness만 토글(설치/업데이트) 또는 해제(제거). 상태 표시줄에 harness 활성/비활성도 노출
  - 입력 UX는 기존 메뉴 함수(`choose_menu`/`Invoke-ChooseMenu`, `ask_yes_no`/`Ask-YesNo`)를 그대로 재사용하여 다른 에이전트와 조작감 동일
- **OS 호환성**
  - Windows의 `python3` Microsoft Store stub(Exit code 49) 회피용 실제 실행 기반 python 탐색 헬퍼 추가
  - `settings.json` 조작은 표준 라이브러리만 사용하여 내부망/폐쇄망에서도 동작, 기존 등록 항목·다른 패키지 보존
- **두 정체성 정합 (마켓플레이스 전용 파일 제외)**
  - `template_initializer.sh`(템플릿 초기화 시): `package.json`·`harness/` 삭제 목록에 추가
  - `template_integrator`(기존 프로젝트 통합 시): `package.json`·`harness/` 복사 제외 목록에 추가
- **버전 동기화**
  - `PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC` 워크플로우에 `package.json` 버전 동기화 스텝과 커밋 대상 추가

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
