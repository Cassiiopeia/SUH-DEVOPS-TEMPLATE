---
title: "❗[버그][Skills] github 스킬 Windows Python 파이프 Exit code 49 오류"
labels: [작업전]
assignees: [Cassiiopeia]
---

🗒️ 설명
---

- `curl ... | python3 -c "..."` 파이프라인 실행 시 `Exit code 49` 오류 발생
- Python이 정상 설치된 Windows 환경에서도 Git Bash 내 파이프에서 python3 경로 인식 실패
- GitHub API JSON 응답 파싱이 불가능해 스킬 전체가 중단됨

🔄 재현 방법
---

1. Windows 환경 Git Bash에서 `cassiiopeia:github` 스킬 실행
2. 이슈 조회 등 curl + python3 파이프 조합 실행 시도
3. `Exit code 49 / Python` 오류 발생

📸 참고 자료
---

- Windows Git Bash에서 `python3` 명령이 Windows Store python stub을 가리키거나 파이프 stdin 처리 방식 차이로 발생
- 동일 명령이 macOS/Linux에서는 정상 작동

✅ 예상 동작
---

- Windows 환경에서는 PowerShell `Invoke-RestMethod`를 사용하도록 분기 처리
- 또는 `curl ... -o /tmp/out.json` 파일 저장 후 별도 파싱으로 파이프 의존성 제거
- `skills/github/SKILL.md`에 Windows 대응 PowerShell 코드블록 추가

⚙️ 환경 정보
---

- **OS**: Windows 11
- **Python**: 3.12 (Windows Store 또는 직접 설치)
- **Shell**: Git Bash

🙋‍♂️ 담당자
---

- 백엔드: 이름
- 프론트엔드: 이름
- 디자인: 이름
