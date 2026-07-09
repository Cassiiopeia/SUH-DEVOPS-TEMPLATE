# 🚀[기능개선][Skills] ssh skill Python paramiko 기반 크로스플랫폼 지원

- **라벨**: 작업전
- **담당자**: Cassiiopeia

---

📝 현재 문제점
---

- 현재 `ssh` skill은 `sshpass` CLI 도구를 사용해 SSH 비밀번호 인증을 처리한다.
- `sshpass`는 macOS/Linux에서만 동작하며 Windows에서는 사용 불가하다.
- Windows PowerShell 5.x 하위 호환성이 없어 Windows 사용자가 skill을 사용할 수 없다.
- `python` / `python3` 명령어 호환성 처리가 없어 OS별로 실행 방법이 달라질 수 있다.

🛠️ 해결 방안 / 제안 기능
---

- `sshpass` 의존성을 제거하고 Python `paramiko` 라이브러리 기반 스크립트(`scripts/ssh_connect.py`)로 대체한다.
- `paramiko`는 macOS/Linux/Windows 모두 지원하는 순수 Python SSH 구현체다.
- 비밀번호 인증(`auth: "password"`)과 PEM 키 인증(`auth: "key"`) 둘 다 지원한다.
- Python 실행 시 `python3` → `python` 순서로 fallback하는 호환성 처리를 포함한다.
- Windows PowerShell 5.x(하위 호환) 환경에서도 동작하도록 인코딩·경로 처리를 고려한다.

⚙️ 작업 내용
---

- `skills/ssh/scripts/ssh_connect.py` 신규 작성 (paramiko 기반, 비밀번호/PEM 키 인증)
- `skills/ssh/SKILL.md` 수정 — sshpass 명령 패턴 → `ssh_connect.py` 호출 방식으로 변경
- Python 실행 명령어 호환성 처리 (`python3` / `python` fallback)
- Windows PowerShell 5.x 하위 호환성 고려 (UTF-8 출력, 경로 처리 등)
- `skills/ssh/config.example.json` 스키마 유지 (변경 없음)

🙋‍♂️ 담당자
---

- 담당자: Cassiiopeia
