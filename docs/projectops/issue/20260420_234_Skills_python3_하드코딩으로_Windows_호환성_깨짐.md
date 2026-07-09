# ❗[버그][Skills] python3 하드코딩으로 Windows 호환성 깨짐

- **라벨**: 작업전
- **담당자**: Cassiiopeia

---

🗒️ 설명
---

`skills/` 하위 전체 SKILL.md 파일에서 `python3` 명령어가 하드코딩되어 있어, Windows 환경에서 `python3`가 Windows Store 링크로 연결되는 경우 실행이 실패함.

macOS/Linux에서는 `python3`가 정상 동작하지만, Windows에서는 `python`을 사용해야 하는 경우가 많아 크로스 플랫폼 호환성이 깨짐.

```bash
# 현재 (macOS/Linux 전용)
PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli config-get issue github_pat

# Windows bash에서 python3 → Windows Store 링크 → 실행 실패
```

🔄 재현 방법
---

1. Windows 환경에서 bash(Git Bash 등)로 `python3` 실행
2. Windows Store 앱으로 연결되거나 exit code 49로 실패
3. skills 내 모든 `python3` 호출 동작 불가

📸 참고 자료
---

영향받는 파일 (`python3` 하드코딩):
- `skills/issue/SKILL.md`
- `skills/commit/SKILL.md`
- `skills/github/SKILL.md`
- `skills/deploy/SKILL.md`
- `skills/changelogfix/SKILL.md`
- `skills/analyze/SKILL.md`
- `skills/design-analyze/SKILL.md`
- 기타 `python3` 참조 SKILL.md 전체

✅ 예상 동작
---

- macOS, Linux, Windows 어느 환경에서도 동일하게 동작
- `python3` → `python3 || python` 폴백 또는 `PYTHON` 환경변수 사용 등 크로스 플랫폼 호환 방식 적용

⚙️ 환경 정보
---

- **OS**: Windows 11 (Git Bash)
- **현상**: `python3` 호출 시 exit code 49 반환, Windows Store 앱으로 연결됨
- **영향 범위**: `skills/` 하위 `python3` 호출 포함한 모든 SKILL.md

🙋‍♂️ 담당자
---

- **담당자**: Cassiiopeia
