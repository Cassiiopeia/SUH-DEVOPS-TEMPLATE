# 🚀[기능개선][Skills] github 스킬 Actions Secret 업데이트 기능 추가

- 라벨: 작업전
- 담당자: Cassiiopeia

---

📝 현재 문제점
---

- `cassiiopeia:github` 스킬에 GitHub Actions Secret 업데이트 기능이 없어, 매번 임시 Python 파일을 직접 생성해서 처리해야 함
- PyNaCl public key 암호화 로직을 매 작업마다 새로 작성 → 토큰 낭비 및 실수 유발

🛠️ 해결 방안 / 제안 기능
---

- `cassiiopeia:github` 스킬에 `## GitHub Actions Secret 관리` 섹션 추가
- secret 이름·값 미지정 시 자동 탐색 (secrets 목록 조회 → `.env` 파일 탐색 → 사용자 확인)
- PyNaCl sealed box 암호화 + GitHub secrets PUT API 표준 코드 내장
- PyNaCl 미설치 시 자동 pip install 후 재시도
- description에 트리거 키워드 추가 ("secret 업데이트해줘", "Actions secret 등록해줘" 등)

⚙️ 작업 내용
---

- `skills/github/SKILL.md`에 GitHub Actions Secret 관리 섹션 추가
- secrets 목록 조회 → `.env` 자동 탐색 → 암호화 → PUT 흐름 표준화
- 오류 대응 표 (403/404/nacl 오류/특수문자) 추가
- description 트리거 키워드 업데이트

🙋‍♂️ 담당자
---

- 개발: Cassiiopeia
