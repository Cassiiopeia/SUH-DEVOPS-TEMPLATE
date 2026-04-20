# ❗[버그][Skills] issue 스킬 scripts 경로 하드코딩으로 플러그인 설치 프로젝트에서 ModuleNotFoundError 발생

- **라벨**: 작업전
- **담당자**: 

---

🗒️ 설명
---

플러그인으로 설치된 프로젝트(RomRom-FE 등)에서 `/cassiiopeia:issue` 스킬 실행 시 `ModuleNotFoundError: No module named 'suh_template'` 에러가 발생합니다.

원인: `skills/issue/SKILL.md`의 "시작 전" 섹션에서 `PYTHONPATH="$PROJECT_ROOT/scripts"`로 하드코딩되어 있어, 플러그인을 사용하는 타 프로젝트에 `scripts/` 폴더가 없으면 모듈을 찾지 못합니다.

🔄 재현 방법
---

1. `claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user`로 플러그인 설치
2. SUH-DEVOPS-TEMPLATE이 아닌 다른 프로젝트(예: RomRom-FE)에서 Claude Code 실행
3. `/cassiiopeia:issue` 호출
4. 아래 에러 발생:
   ```
   ModuleNotFoundError: No module named 'suh_template'
   ```

📸 참고 자료
---

에러 로그:
```
/opt/homebrew/opt/python@3.14/bin/python3.14: Error while finding module specification for 'suh_template.cli' 
(ModuleNotFoundError: No module named 'suh_template')
```

스킬 내 문제 코드 (`skills/issue/SKILL.md` 시작 전 섹션):
```bash
# 잘못된 코드 - PROJECT_ROOT에 scripts/가 없으면 실패
PYTHONPATH="$PROJECT_ROOT/scripts" $PYTHON -m suh_template.cli config-get issue github_pat
```

올바른 동작:
```bash
# 플러그인 캐시 경로를 PYTHONPATH로 사용해야 함
SCRIPTS_PATH="/Users/suhsaechan/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia/{version}/scripts"
PYTHONPATH="$SCRIPTS_PATH" $PYTHON -m suh_template.cli config-get issue github_pat
```

✅ 예상 동작
---

- 플러그인으로 설치한 프로젝트라면 `scripts/` 폴더가 없어도 `suh_template.cli` 모듈을 찾을 수 있어야 함
- 스킬 내 PYTHONPATH 설정이 플러그인 캐시 경로(`~/.claude/plugins/cache/.../scripts`)를 자동으로 사용해야 함

⚙️ 환경 정보
---

- **OS**: macOS 14.x (Darwin 24.1.0)
- **Claude Code**: v2.1.114
- **플러그인 버전**: cassiiopeia 2.9.19
- **Python**: /opt/homebrew/bin/python3 (python@3.14)

🙋‍♂️ 담당자
---

- **백엔드**: 이름
- **프론트엔드**: 이름
- **디자인**: 이름
