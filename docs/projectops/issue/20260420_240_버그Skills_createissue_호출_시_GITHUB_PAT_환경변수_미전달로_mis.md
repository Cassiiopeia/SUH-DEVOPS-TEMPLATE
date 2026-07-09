# ❗[버그][Skills] create-issue 호출 시 GITHUB_PAT 환경변수 미전달로 missing_pat 에러

- **라벨**: 작업전
- **담당자**: 

---

🗒️ 설명
---

`/cassiiopeia:issue` 스킬 실행 시 AI가 `create-issue` CLI를 호출할 때 `GITHUB_PAT=...` 환경변수를 앞에 붙이지 않아 `missing_pat` 에러가 발생합니다.

스킬 문서에는 `GITHUB_PAT=$(...)` 로 PAT를 변수에 저장하도록 안내되어 있으나, 실제 CLI 호출 시 `GITHUB_PAT=$GITHUB_PAT` 전달을 AI가 누락하는 케이스가 반복 발생합니다.

🔄 재현 방법
---

1. `/cassiiopeia:issue` 실행 후 이슈 등록 승인
2. AI가 아래처럼 GITHUB_PAT 없이 호출:
   ```bash
   PYTHONPATH="$SCRIPTS_PATH" $PYTHON -m suh_template.cli create-issue ...
   ```
3. 에러 발생:
   ```
   [ERROR] create-issue: 환경변수 GITHUB_PAT가 설정되지 않았습니다. (missing_pat)
   ```

📸 참고 자료
---

올바른 호출 형태:
```bash
GITHUB_PAT=$GITHUB_PAT PYTHONPATH="$SCRIPTS_PATH" $PYTHON -m suh_template.cli create-issue ...
```

✅ 예상 동작
---

- 스킬 문서의 5단계 예시 코드를 더 명확하게 작성하여 AI가 GITHUB_PAT 전달을 빠뜨리지 않도록 가이드 강화
- 또는 `cli.py`에서 GITHUB_PAT 환경변수 외에 config 파일에서도 PAT를 자동 로드하도록 개선

⚙️ 환경 정보
---

- **OS**: macOS 14.x (Darwin 24.1.0)
- **Claude Code**: v2.1.114
- **플러그인 버전**: cassiiopeia 2.9.22

🙋‍♂️ 담당자
---

- **백엔드**: 이름
- **프론트엔드**: 이름
- **디자인**: 이름
