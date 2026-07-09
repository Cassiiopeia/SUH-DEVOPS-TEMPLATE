📝 현재 문제점
---

- `changelog-deploy` 스킬은 모든 저장소를 동일하게 취급하여 릴리스 노트를 작성한다.
- 그러나 저장소 성격에 따라 릴리스 노트의 무게가 다르다.
  - 백엔드 저장소(spring/python): 배포 = 서버 반영. 릴리스 노트가 사용자에게 직접 노출되지 않는다.
  - 앱 저장소(flutter 등) + 스토어 심사 워크플로우(PLAYSTORE/TESTFLIGHT/APPSTORE): 배포 = 앱스토어/플레이스토어 심사 제출. 릴리스 노트가 그대로 스토어 "이번 업데이트" 출시노트가 되어 심사에 들어간다.
- 특히 심사 자동 제출이 켜진 저장소에서는 CICD·내부 개선·테스트 문구가 실수로 릴리스 노트에 들어가면 즉시 심사로 넘어간다.
- 현재 스킬에는 "이 저장소가 앱 심사에 직결되는 저장소인가"를 인지하는 단계가 없어, 앱 저장소에서도 백엔드와 같은 긴장도로 릴리스 노트를 쓰게 된다.

🛠️ 해결 방안 / 제안 기능
---

- 앱 심사 연관 저장소를 자동 감지하고, 그럴 때만 릴리스 노트를 더 신중히 쓰도록 경고를 표시한다.
- 백엔드 저장소는 아무 영향 없이 기존 흐름 그대로 통과한다.
- 판단·대화·설정 갱신은 에이전트가 수행하고, 사용자는 설정을 직접 만지지 않는다. 애매하면 에이전트가 자연어로 물어보고 대신 저장한다.
- 앱 심사로 처음 감지될 때 한 번만 확인하고, 그 결과를 기억해 다음 배포부터는 묻지 않는다.

⚙️ 작업 내용
---

- (1) `changelog_cli.py`에 `detect-release-context` 서브커맨드 추가
  - `version.yml`의 `project_types`와 `.github/workflows`의 스토어 워크플로우(PLAYSTORE/TESTFLIGHT/APPSTORE)를 스캔
  - signals(사실)와 약한 hint만 JSON으로 반환 (앱 심사 여부 최종 판단은 에이전트가 수행)
- (2) `SKILL.md`에 "1.5단계: 릴리스 컨텍스트 인지" 추가
  - 앱 심사 감지 시 한 번 확인 후 설정의 `changelog_deploy.app_release`에 기억
  - 백엔드 저장소는 질문·경고 없이 조용히 통과
- (3) 심사 경고 배너를 릴리스 노트 승인 게이트(5.5단계 / fix 4.5단계)에 결합
- (4) `config.json.example` / `references/config-rules.md`에 `app_release` 키 문서화
- 설계문서: `docs/superpowers/specs/2026-06-20-changelog-deploy-app-release-awareness-design.md`

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
