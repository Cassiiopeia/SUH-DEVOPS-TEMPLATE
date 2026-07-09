📝 현재 문제점
---

- 여러 GitHub 계열 스킬(issue·github·report·commit·changelog-deploy 등)이 config 위치를 `references/config-rules.md` 참조로만 안내한다.
- 같은 SKILL.md 안에서 스크립트(`*_cli.py`) 위치를 찾을 때 `ls ~/.claude/plugins/cache/...` 패턴을 반복 사용한다.
- 이 때문에 에이전트가 "캐시를 ls로 뒤지는" 사고방식을 config 찾기에까지 전이시켜, 고정 경로(`~/.suh-template/config/config.json`)를 바로 읽지 않고 플러그인 캐시 안을 탐색하는 사례가 발생했다.
- 그 결과 이미 등록된 PAT가 있는데도 "config 없음"으로 오판해 사용자에게 PAT를 다시 묻는 일이 반복됐다 (실제 발생).
- `config-rules.md §3`에 "탐색 금지" 규칙이 있었으나 약하게 묻혀 있어 에이전트가 건너뛰었다.

🛠️ 해결 방안 / 제안 기능
---

- 단일 진실 원천인 `config-rules.md §3`의 "config 탐색 금지" 규칙을 눈에 띄는 경고 블록으로 격상한다.
- "스크립트는 캐시에서 찾고, config는 홈의 고정 경로에서 바로 읽는다 — 두 경로를 절대 섞지 않는다"는 원칙을 명확히 한다.
- config를 다루는 각 스킬 문서에 짧은 인라인 방어 안내를 추가해, 참조 문서를 읽지 않고 시작해도 캐시 탐색 실수가 막히도록 이중 방어한다.
- 사용자가 PAT 재등록을 다시 요구받는 불편을 제거한다.

⚙️ 작업 내용
---

- `config-rules.md §3` 경고 블록 격상 (단일 진실 원천 강화)
- 7개 스킬 문서에 config 고정 경로·캐시 탐색 금지 인라인 방어 표기 추가
  - issue / github / report / commit / changelog-deploy / ssh / synology-expose
- 스크립트 탐색용 캐시 `ls` 실행 로직은 변경하지 않음 (설명 텍스트만 추가)
