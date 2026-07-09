### 📌 작업 개요

GitHub Secret에 저장된 설정 파일(.env, application-prod.yml 등)의 변경 이력을 추적하기 위해 Synology NAS에 자동 업로드하는 워크플로우를 SUH-DEVOPS-TEMPLATE에 템플릿화. SSH 방식(appleboy/ssh-action) 채택, `common/synology/` 폴더에 배치하여 `--synology` 옵션으로 조건부 포함되도록 구현.

### 🎯 구현 목표

- Synology NAS Secret 파일 업로드 워크플로우를 프로젝트 타입에 무관한 공통 템플릿으로 제공
- 기존 `template_integrator`의 `--synology` 옵션 인프라를 활용하여 `common/synology/` 경로 지원 추가
- AI 에이전트(Claude, Cursor 등)로 파일 목록을 쉽게 커스텀할 수 있는 프롬프트 가이드 내장

### ✅ 구현 내용

#### 1. 공통 Synology Secret 파일 업로드 워크플로우 생성
- **파일**: `.github/workflows/project-types/common/synology/PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml`
- **변경 내용**: SSH 방식으로 GitHub Secrets 파일을 Synology NAS에 업로드하는 워크플로우 신규 작성
- **이유**: RomRom-BE/FE 등 개별 프로젝트에서 하드코딩하던 패턴을 범용 템플릿으로 추출

#### 2. template_integrator.sh에 common/synology 지원 추가
- **파일**: `template_integrator.sh` (+71줄)
- **변경 내용**: `ask_synology_option()` 함수에서 `common/synology/` 디렉토리도 감지하도록 수정, 파일 카운트 및 목록 표시에 "(공통)" 접미사 추가, 워크플로우 복사 로직에 "4. Common Synology 워크플로우 처리" 블록 추가
- **이유**: 기존에는 타입별 synology(`spring/synology/`, `flutter/synology/`)만 지원했고 `common/synology/`는 완전히 미지원

#### 3. template_integrator.ps1에 common/synology 지원 추가
- **파일**: `template_integrator.ps1` (+73줄)
- **변경 내용**: `Ask-SynologyOption` 함수에 `$commonSynologyDir` 변수 추가, `Copy-Workflows` 함수에 Common Synology 복사 블록 추가
- **이유**: PowerShell 버전도 동일한 기능 제공. PowerShell 5.1 호환성을 위해 `Join-Path`에 2인자만 사용 (`"common\synology"` 패턴)

#### 4. CLAUDE.md 문서 업데이트
- **파일**: `CLAUDE.md` (+15줄)
- **변경 내용**: 폴더 구조에 `common/synology/` 추가, "공통 Synology (선택적)" 서브섹션 신설, `--synology` 옵션 설명 확장, "Synology Secret 파일 업로드" Secrets 섹션 추가 (`SYNOLOGY_HOST/USERNAME/PASSWORD`)
- **이유**: 새 워크플로우와 Secret 이름을 프로젝트 문서에 반영

#### 5. 워크플로우 주석 가이드 문서 업데이트
- **파일**: `docs/WORKFLOW-COMMENT-GUIDELINES.md` (+1줄)
- **변경 내용**: `project-types/common/` 테이블에 `SYNOLOGY-SECRET-FILE-UPLOAD | D | ✅` 행 추가
- **이유**: 주석 타입 분류 현황 유지

### 🔧 주요 변경사항 상세

#### PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml

Type D 주석 표준 + AI 에이전트 커스텀 프롬프트 가이드 포함. 주요 설계 결정:

- **SSH 방식 채택**: SMB 대비 설정 간단(3개 Secret), 추가 패키지 불필요, `mkdir -p` 직접 지원
- **Secret 빈 값 감지**: `cat << 'SECRETEOF' > /tmp/_secret_check` + `if [ -s ]` 패턴으로 단일 인용부호 포함 Secret도 안전 처리
- **타임스탬프 백업**: `${BASE_DIR}/${TIMESTAMP}/` 디렉토리에 이력 보존, 루트에 최신 파일 덮어쓰기
- **메타데이터**: `cicd-gitignore-file.json`(빌드 정보+파일 목록)과 `timestamp_index.json`(마지막 업로드 상태) 자동 생성
- **Secret 네이밍**: 기존 Spring/Docker 패턴과 통일하여 `SYNOLOGY_HOST/USERNAME/PASSWORD` 사용

**특이사항**:
- `checkout` 스텝 불필요 (Secret 파일만 다루므로 코드 체크아웃 제거)
- 기본 예시로 `ENV_FILE → .env`, `APPLICATION_PROD_YML → application-prod.yml` 2개 포함
- AI 에이전트 프롬프트에서 프로젝트별 파일 추가/수정 방법을 상세 안내

#### template_integrator common/synology 지원

`ask_synology_option()` 함수의 가드 조건을 `common/synology/` 존재 여부까지 확장. `basic` 프로젝트 타입처럼 타입별 synology가 없지만 common synology는 있는 경우에도 정상 프롬프트 표시.

**특이사항**:
- PowerShell 5.1에서 `Join-Path`가 3인자를 지원하지 않아 `Join-Path $base "common\synology"` 형태로 구현
- 파일 목록 표시 시 타입별은 그대로, 공통은 "(공통)" 접미사로 구분

### 🧪 테스트 및 검증

- 워크플로우 YAML 문법 유효성 확인
- `cat << 'SECRETEOF'` heredoc으로 단일 인용부호 포함 Secret 안전 처리 검증
- PowerShell 5.1 호환 `Join-Path` 패턴 확인
- CLAUDE.md 공통 Synology 섹션 배치 위치 적절성 확인 (루트 공통 테이블이 아닌 별도 서브섹션)

### 📌 참고사항

- 이 워크플로우는 `--synology` 옵션 선택 시에만 프로젝트에 포함됨 (기본 제외)
- Secret이 미설정된 파일은 자동 스킵되므로, 템플릿에 여러 파일을 미리 정의해두어도 안전
- AI 에이전트 프롬프트를 통해 프로젝트별 파일 목록 커스터마이징 권장
- 설계 문서: `docs/superpowers/specs/2026-03-10-synology-secret-file-upload-design.md`
- 구현 계획: `docs/superpowers/plans/2026-03-10-synology-secret-file-upload.md`
