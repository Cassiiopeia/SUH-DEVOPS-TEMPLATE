# Issue #147: 프로젝트 Initializer docs 폴더 삭제 문제 수정

## 📌 작업 개요

GitHub 템플릿으로 새 프로젝트 생성 시 Initializer가 `/docs` 폴더를 삭제하지 않던 문제 수정.
`/docs` 폴더는 SUH-DEVOPS-TEMPLATE 자체에 대한 설명 문서로, 외부 프로젝트에는 불필요한 파일임.

**관련 이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/147

---

## 🔍 문제 분석

### 문제 상황
- **Initializer**: 새 프로젝트 생성 시 `/docs` 폴더가 삭제되지 않고 남아있음
- **Integrator**: 기존 프로젝트 통합 시 `/docs` 폴더를 복사하지 않음 (정상 동작)

### 원인
`template_initializer.sh`의 `cleanup_template_files()` 함수에서 삭제 대상에 `docs` 폴더가 누락되어 있었음.

기존 삭제 대상:
- CHANGELOG.md, CHANGELOG.json
- template_integrator.sh, template_integrator.ps1
- LICENSE, CONTRIBUTING.md, CLAUDE.md
- .github/scripts/test/, .github/workflows/test/

---

## ✅ 구현 내용

### 1. template_initializer.sh 수정
- **파일**: `.github/scripts/template_initializer.sh`
- **위치**: `cleanup_template_files()` 함수 (라인 392-396)
- **변경 내용**: docs 폴더 삭제 로직 추가

```bash
# docs 폴더 삭제 (템플릿 전용 문서)
if [ -d "docs" ]; then
    rm -rf docs
    echo "  ✓ docs 폴더 삭제"
fi
```

### 2. CLAUDE.md 문서 업데이트
- **파일**: `CLAUDE.md`
- **위치**: 라인 219
- **변경 내용**: "초기화 시 삭제되는 템플릿 전용 파일" 목록에 `docs/` 추가

---

## 🔧 주요 변경사항 상세

### cleanup_template_files() 함수

기존 테스트 폴더 삭제 로직(`cleanup_template_files()` 함수)과 동일한 패턴으로 구현:
1. `if [ -d "docs" ]` - docs 폴더 존재 여부 확인
2. `rm -rf docs` - 폴더 및 하위 파일 전체 삭제
3. `echo "  ✓ docs 폴더 삭제"` - 삭제 완료 메시지 출력

**특이사항**:
- Integrator는 별도 수정 불필요 (이미 docs를 복사하지 않음)
- 기존 패턴을 따라 일관성 있게 구현

---

## 📦 영향 범위

| 구분 | 영향 |
|------|------|
| **Initializer** | 새 프로젝트 생성 시 docs 폴더 자동 삭제 |
| **Integrator** | 변경 없음 (기존대로 docs 복사 안 함) |
| **기존 프로젝트** | 영향 없음 |

---

## 🧪 테스트 및 검증

1. `template_initializer.sh` 스크립트 문법 오류 없음 확인
2. 새 프로젝트 생성 시 docs 폴더 삭제 동작 확인
3. 기존 삭제 대상(CHANGELOG, LICENSE 등) 정상 삭제 확인

---

## 📌 참고사항

- docs 폴더에 포함된 파일들:
  - FLUTTER-CICD-OVERVIEW.md
  - FLUTTER-PLAYSTORE-WIZARD.md
  - FLUTTER-TESTFLIGHT-WIZARD.md
  - FLUTTER-TEST-BUILD-TRIGGER.md
  - SYNOLOGY-DEPLOYMENT-GUIDE.md
  - TEMPLATE-INTEGRATOR.md

- 이 파일들은 SUH-DEVOPS-TEMPLATE 사용 방법 문서로, 개별 프로젝트에서는 필요하지 않음
