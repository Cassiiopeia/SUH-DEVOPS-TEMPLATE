# 구현 보고서 — #234 python3 하드코딩으로 Windows 호환성 깨짐

**이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/234
**작업일**: 2026-04-20
**커밋**: `3725051`

---

## 문제 요약

모든 스킬에서 `python3`를 하드코딩하여 사용하고 있어, Windows Git Bash 환경에서 `python3`가 Windows Store 링크로 연결되어 실행이 실패하는 문제 발생.

## 수정 내용

### PYTHON 변수 폴백 패턴 도입

`python3` 하드코딩 대신 크로스 플랫폼 호환 PYTHON 변수를 사용하도록 전체 스킬 수정.

```bash
# 기존 (문제)
python3 -m suh_template.cli ...

# 수정 후 (크로스 플랫폼)
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
$PYTHON -m suh_template.cli ...
```

### 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `skills/references/common-rules.md` | PYTHON 변수 설정 가이드 명시 |
| `skills/issue/SKILL.md` 외 16개 스킬 | `python3` 하드코딩 → `$PYTHON` 변수 사용으로 교체 |

## 검증

- macOS/Linux: `python3` 경로로 정상 실행
- Windows Git Bash: `python` 폴백으로 정상 실행
