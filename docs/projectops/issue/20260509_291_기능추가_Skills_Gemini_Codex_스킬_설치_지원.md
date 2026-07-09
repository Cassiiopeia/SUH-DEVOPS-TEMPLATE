---
title: "⚙️[기능추가][Skills] Gemini CLI 및 Codex CLI 스킬 설치 지원"
labels: [작업전]
assignees: [Cassiiopeia]
---

📝 현재 문제점
---

- 현재 스킬 배포 구조는 Claude Code 플러그인과 Cursor skills 복사 흐름을 중심으로 구성되어 있음
- Gemini CLI와 Codex CLI 사용자는 이 레포의 `skills/`를 일관된 방식으로 설치하고 호출하기 어려움
- Codex는 공식 플러그인 마켓플레이스 등록을 전제로 하기 어려워, 별도 native skills 설치 경로가 필요함
- 이 레포는 프로젝트 템플릿 역할도 함께 수행하므로, agent skill 배포 파일과 템플릿 생성 산출물의 경계를 명확히 해야 함

🛠️ 해결 방안 / 제안 기능
---

- Gemini CLI extension 설치를 지원할 수 있도록 루트 manifest와 Gemini bootstrap 문서를 추가
- Codex CLI는 공식 marketplace 전제 없이 native skills discovery 기반 설치 방식을 지원
- Codex plugin metadata는 미래 호환용으로만 두고, 실제 설치 안내는 native skills 설치 방식을 우선 사용
- `template_integrator`의 skills 모드를 Claude, Cursor, Gemini, Codex 설치 흐름으로 확장
- `template_initializer`가 템플릿으로 생성된 일반 프로젝트에서 agent skill 배포 파일을 제거하도록 정리
- 플러그인 및 extension metadata의 버전이 `version.yml`과 함께 동기화되도록 워크플로우 범위를 확장
- 설치 및 사용 문서는 별도 Codex/Gemini 전용 문서를 만들지 않고 `README.md`와 `docs/SKILLS.md`에 통합

⚙️ 작업 내용
---

- 루트 agent bootstrap 및 manifest 파일 추가
- Gemini CLI extension 설치 경로 문서화
- Codex native skills 설치 경로 문서화
- macOS/Linux 및 Windows 설치 흐름 반영
- template initializer의 제거 대상 확장
- template integrator의 skills 모드 확장
- plugin version sync workflow 대상 확장
- README 및 Skills 문서 업데이트

🙋‍♂️ 담당자
---

- 백엔드: 이름
- 프론트엔드: 이름
- 디자인: 이름
