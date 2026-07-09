# 코드 리뷰: ⚙️[기능개선][Scripts] template_integrator plugin 설치/버전확인/삭제/scope 관리 개선

**대상 파일**: `template_integrator.sh`, `template_integrator.ps1`
**이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/230
**변경 규모**: +734 / -327 (15개 파일)

---

## 🔒 보안 (Security)

없음 — 외부 입력은 사용자 인터랙션 변수로만 사용되며 eval/exec 미사용.

---

## ⚡ 성능 (Performance)

### 💡 Minor

**`template_integrator.sh:2349~2370`** — 상태 표시와 Cursor 섹션에서 `TEMPLATE_VERSION` 비교 블록이 4회 중복됨.
- 현재: `[ -n "$TEMPLATE_VERSION" ] && [ "$X" = "$TEMPLATE_VERSION" ] && tag=" ✓ 최신버전"` 패턴 반복
- 제안: `_build_version_tag()` 헬퍼 1개로 통합
- 이유: 조건 4회 반복은 유지보수 시 누락 가능성

```bash
_build_version_tag() {
    local current="$1"
    [ -z "$TEMPLATE_VERSION" ] && return
    if [ "$current" = "$TEMPLATE_VERSION" ]; then echo " ✓ 최신버전"
    else echo " → 업데이트 가능: v${TEMPLATE_VERSION}"
    fi
}
```

---

## 🐛 버그 및 로직

### ⚠️ Major

**`template_integrator.sh:2395~2410`** — `_ask_cursor_scope` 호출 시 업데이트 메뉴(선택지 1)는 이미 설치된 scope로만 업데이트하는 것이 UX상 자연스러움. 현재는 업데이트 시에도 scope를 다시 묻는데, 사용자가 다른 scope를 선택하면 기존 scope의 파일은 그대로 남음.

- 현재: 업데이트(1) 선택 → scope 재선택 가능 → 기존 파일 잔존
- 제안: 업데이트(1)는 기존 설치된 scope 유지, scope 변경은 신규 설치(2)로만 가능하도록 분리
- 이유: `_ask_cursor_delete`가 따로 있으므로 업데이트에서 scope 변경은 불필요한 복잡도

**`template_integrator.sh:2471~2500` / `template_integrator.ps1:Invoke-CursorDelete`** — `_ask_cursor_delete` 선택지 3(모두 삭제)은 `user_ver`와 `proj_ver` 모두 있을 때만 표시하나, 메뉴 번호 3이 조건부 표시되어 입력 번호와 실제 줄이 매핑이 헷갈릴 수 있음.

- 제안: 선택지를 "u/p/a/0" 영문자로 교체하거나, 항상 3개 고정 표시(없는 항목은 회색 처리 텍스트)

### 💡 Minor

**`template_integrator.sh:2342~2345`** — 상태 표시 블록에서 `installed_scope`가 항상 `user`로 표시됨. `claude plugin list --json`에서 실제 scope를 읽지만, 상태 표시 레이블을 `user`로 하드코딩.
- 현재: `print_info "Claude Code  user   v${installed_version}..."`
- 제안: `print_info "Claude Code  ${installed_scope}   v${installed_version}..."` (실제 scope 사용)

---

## 📐 코드 품질

### ⚠️ Major

**`template_integrator.ps1:Write-CursorSkillsMeta`** — 함수 상단 중복 주석:
```powershell
# .cursor\skills\cursor-skills-meta.json 생성/갱신
# 템플릿 버전·설치 경로를 기록해두어 이후 업데이트·삭제에 활용한다.
# cursor-skills-meta.json 생성/갱신                          ← 중복
# 인자: $Scope(user|project), $DestDir(설치 경로)
```
이전 주석과 신규 주석이 병존함. 이전 주석 2줄 제거 필요.

### 💡 Minor

**`template_integrator.sh:2541~2607`** — `_ask_cursor_delete`에서 옵션 3은 `user_ver`와 `proj_ver`가 모두 있을 때만 case 분기에 진입하는데, 선택지를 조건부로 출력하는 로직과 case 내부 조건 검사가 이중 존재. case 내부 조건 제거 가능.

---

## 🏗️ 아키텍처

### ✅ 잘된 구조

- `_do_cursor_skills_copy` / `Invoke-CursorSkillsCopy`로 복사 로직을 단일 함수로 집중 — DRY 원칙 잘 적용
- `_write_cursor_skills_meta($scope, $dest)` / `Write-CursorSkillsMeta` 파라미터화로 user/project 양쪽 지원 — 재사용성 높음
- `_ask_cursor_skills_src` 단방향 분기(양쪽 없으면 빈 문자열 즉시 반환) — 간결하고 예측 가능

### 💡 Minor

**Synology 버그 수정 위치**: `interactive_mode()` 끝부분에 Synology 질문 추가는 올바른 수정. 다만 `download_template` 주석이 "Synology 질문에서 사용"이라고 명시했으나, 이미 CLI 모드에서도 별도로 `download_template`를 호출하므로 interactive 모드의 `download_template` 목적 주석을 "모드 선택 전 TEMP_DIR 확보"로 변경 권장.

---

## 🧪 테스트

테스트 파일 부재 (기존 프로젝트 스타일 동일) — 이슈 범위 외.

---

## 📊 리뷰 요약

**전체 평가**: Comment (선택적 개선)
**이슈 통계**: Critical 0개 / Major 3개 / Minor 5개

### 핵심 개선 사항

1. **[Major] 업데이트 시 scope 재선택 UX 정리** — 업데이트(1)에서 기존 scope 유지, scope 변경은 신규 설치(2)로만 가능하도록 의미 분리
2. **[Major] PS1 중복 주석 제거** — `Write-CursorSkillsMeta` 상단 이전 주석 2줄 제거
3. **[Minor] Claude Code 상태 표시 scope 하드코딩** — `user` 하드코딩 → `${installed_scope}` 변수 사용

> Major 3개 모두 UX 및 코드 품질 수준이며 기능 오작동은 아님. 배포 전 수정 권장이나 blocking 아님.
