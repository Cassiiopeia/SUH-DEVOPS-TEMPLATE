# 구현 보고서 — #230 template_integrator plugin 설치/버전확인/삭제/scope 관리 개선

**이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/230
**작업일**: 2026-04-20
**커밋**: `f0c3ace`

---

## 구현 요약

`template_integrator.sh`와 `template_integrator.ps1`의 플러그인 관련 기능을 전면 개선. 통합 상태 표시, Cursor user/project scope 분리, 시놀로지 재질문 버그 수정 등 다수 개선.

## 수정 내용

### 1. 통합 상태 표시

플러그인 설치 상태를 한눈에 확인할 수 있는 대시보드 출력 추가.

```
📦 플러그인 상태
  Claude Code: cassiiopeia v2.9.19 (user scope) ✅
  Cursor:      cassiiopeia v2.9.19 (project scope) ✅
```

### 2. Cursor user/project scope 분리

Cursor 플러그인 설치 시 user scope와 project scope를 명확히 분리하여 선택 가능하도록 개선.

| 기존 | 수정 |
|------|------|
| project scope만 지원 | user/project scope 선택 가능 |
| scope 표시 없음 | 현재 설치된 scope 명시 표시 |

### 3. 시놀로지 재질문 버그 수정

업데이트 모드에서 Synology 옵션을 이미 선택했음에도 재질문이 발생하는 버그 수정. `version.yml`의 `metadata.template.options.synology` 값을 읽어 기존 선택을 자동으로 유지.

### 4. .cursor/skills commit 스킬 추가

Cursor IDE용 commit 스킬 신규 추가 (142줄).

### 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `template_integrator.sh` | 통합 상태 표시, scope 분리, 시놀로지 버그 수정 (454줄 → 대폭 개편) |
| `template_integrator.ps1` | 동일 개선 사항 Windows 버전 반영 |
| `.cursor/skills/commit/SKILL.md` | commit 스킬 신규 추가 |
| `.cursor/skills/github/SKILL.md` 외 다수 | 기존 스킬 개선 사항 반영 |

## 검증

- macOS/Linux: `template_integrator.sh` 통합 상태 표시 정상 동작
- Windows: `template_integrator.ps1` scope 선택 정상 동작
- 시놀로지 재질문 미발생 확인
