# Firebase App Distribution Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `.github/util/flutter/firebase-wizard/` 디렉터리에 정적 HTML 마법사(`firebase-wizard.html` + `firebase-wizard.js`)와 워크플로우 placeholder 안전 치환 setup 스크립트(`firebase-wizard-setup.sh` + `firebase-wizard-setup.ps1`), version 메타파일(`version.json` + `version-sync.sh`)을 추가하여 Flutter Android 프로젝트의 Firebase App Distribution 설정 5단계를 자동화한다.

**Architecture:** 정적 HTML/JS 단일 페이지 마법사(GitHub API 직접 호출 안 함). 사용자 입력 → JS state(+localStorage) → 산출물 생성(JSON/TXT/ZIP 다운로드 + 복사 버튼) + setup 스크립트 호출 명령 표시. setup 스크립트는 라인 단위 정규식으로 `.github/workflows/*.{yaml,yml}` 안의 `FIREBASE_APP_ID`/`FIREBASE_TESTER_GROUP` 키를 단어 경계 매칭으로 안전하게 치환(placeholder/같은 값/충돌 분기, 백업 자동, dry-run, non-interactive 지원).

**Tech Stack:** HTML5, Tailwind CDN, JSZip CDN, Pretendard font CDN, Vanilla JS (ES2020), bash 4+, PowerShell 5.1+. 외부 라이브러리 npm 의존 없음, 신규 빌드 도구 없음. PlayStore/TestFlight wizard와 동일 정적 자산 배포 모델.

**Reference Spec:** `docs/superpowers/specs/2026-05-14-firebase-wizard-design.md` (이슈 #295)

**Reference Implementation (재활용 베이스):**
- `.github/util/flutter/playstore-wizard/playstore-wizard.html` (UI 패턴, Tailwind 다크모드, step 카드)
- `.github/util/flutter/playstore-wizard/playstore-wizard.js` (state, localStorage, file upload, base64, JSON/TXT/ZIP export, custom secrets, toast, copy)
- `.github/util/flutter/playstore-wizard/version.json`, `version-sync.sh` (버전 메타데이터 + HTML 동기화)
- `.github/util/flutter/testflight-wizard/testflight-wizard.html` (CSS UI 시뮬레이션 패턴 — 키체인 화면 흉내)

---

## File Structure

| 파일 | 라인 추정 | 책임 |
|---|---|---|
| `.github/util/flutter/firebase-wizard/firebase-wizard.html` | ~1500 | 5단계 마법사 UI (헤더, step 카드, 외부 링크, 가이드 박스, 폼 필드, 다운로드 버튼) |
| `.github/util/flutter/firebase-wizard/firebase-wizard.js` | ~2000 | state 관리, localStorage, 파일 업로드, base64 변환, custom secrets, JSON/TXT/ZIP 산출물, OS detect, copy/toast, step navigation |
| `.github/util/flutter/firebase-wizard/firebase-wizard-setup.sh` | ~400 | 워크플로우 파일 라인 단위 안전 치환 (bash) |
| `.github/util/flutter/firebase-wizard/firebase-wizard-setup.ps1` | ~400 | 동일 동작 (PowerShell) |
| `.github/util/flutter/firebase-wizard/version.json` | ~50 | 버전 메타데이터 + changelog + compatibility |
| `.github/util/flutter/firebase-wizard/version-sync.sh` | ~55 | `version.json` → HTML `<script id="versionJson">` 블록에 주입 |
| `.github/util/flutter/firebase-wizard/test/setup-script-test.sh` | ~250 | bash setup 스크립트 시나리오 자동화 테스트 |
| `.github/util/flutter/firebase-wizard/test/setup-script-test.ps1` | ~250 | PowerShell setup 스크립트 시나리오 자동화 테스트 |
| `.github/util/flutter/firebase-wizard/test/fixtures/` | - | 테스트용 워크플로우 fixture YAML들 |

테스트 fixture는 작업 진행 중 필요 시 추가한다.

---

## Task 정의 순서 (TDD 우선순위)

1. **Task 1**: `version.json` + `version-sync.sh` 스캐폴드 (가장 단순, 다른 작업 의존성 0)
2. **Task 2**: setup 스크립트 (bash) — TDD: 테스트 fixture 먼저, 시나리오별 검증
3. **Task 3**: setup 스크립트 (PowerShell) — bash 테스트 케이스를 PS5.1 호환 포맷으로 포팅
4. **Task 4**: HTML 스캐폴드 — 헤더, 5단계 빈 카드, navigation, Tailwind 설정
5. **Task 5**: JS 기반 인프라 — state, localStorage, OS detect, toast, copy 유틸
6. **Task 6**: Step 1 UI — Firebase Console 가이드 (정적 콘텐츠)
7. **Task 7**: Step 2 UI — Service Account + IAM 가이드 (정적 콘텐츠)
8. **Task 8**: Step 3 UI + 로직 — APP_ID/TESTER_GROUP 입력 + setup 명령 표시 (OS별 탭)
9. **Task 9**: Step 4 UI + 로직 — 파일 업로드 (SA JSON, google-services.json) + base64 변환
10. **Task 10**: Step 4 확장 — Custom Secrets 섹션 (PlayStore wizard v1.2.0 패턴 차용)
11. **Task 11**: Step 5 UI + 로직 — Secret 키 매핑표, 복사 버튼, JSON/TXT/ZIP 다운로드
12. **Task 12**: 통합 검증 — wizard 전체 흐름, ZIP 안에 setup 스크립트 포함 확인
13. **Task 13**: 문서 업데이트 — `CLAUDE.md` Skills 표, README, 워크플로우 헤더 주석에 wizard URL 안내

---

## Task 1: version.json + version-sync.sh

**Files:**
- Create: `.github/util/flutter/firebase-wizard/version.json`
- Create: `.github/util/flutter/firebase-wizard/version-sync.sh`

- [ ] **Step 1: `version.json` 작성**

```json
{
  "name": "Firebase App Distribution Setup Wizard",
  "version": "1.0.0",
  "description": "Flutter Android 앱을 Firebase App Distribution에 배포하기 위한 설정 마법사",
  "lastUpdated": "2026-05-14",
  "changelog": [
    {
      "version": "1.0.0",
      "date": "2026-05-14",
      "changes": [
        "초기 릴리즈",
        "5단계 마법사 (Console 가이드 → SA 발급 → 앱 정보 → 파일 업로드 → Secrets 등록)",
        "Service Account JSON base64 자동 변환",
        "Custom Secrets 섹션 (사용자 정의 secret 동적 추가)",
        "JSON/TXT/ZIP 산출물 다운로드",
        "워크플로우 placeholder 안전 치환 setup 스크립트 (bash/PowerShell)"
      ]
    }
  ],
  "compatibility": {
    "flutter": ">=3.0.0",
    "android_sdk": ">=33",
    "firebase_app_distribution": "GA"
  },
  "repository": "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
}
```

- [ ] **Step 2: `version-sync.sh` 작성** (PlayStore의 동일 스크립트를 그대로 차용, 파일명만 교체)

```bash
#!/bin/bash
# ============================================
# version.json → firebase-wizard.html 동기화 스크립트
# 사용법: ./version-sync.sh
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/version.json"
INDEX_FILE="$SCRIPT_DIR/firebase-wizard.html"

if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ version.json 파일을 찾을 수 없습니다: $VERSION_FILE"
    exit 1
fi

if [ ! -f "$INDEX_FILE" ]; then
    echo "❌ firebase-wizard.html 파일을 찾을 수 없습니다: $INDEX_FILE"
    exit 1
fi

CURRENT_VERSION=$(grep '"version"' "$VERSION_FILE" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
echo "📦 동기화할 버전: v$CURRENT_VERSION"

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then
    echo "❌ Python을 찾을 수 없습니다."
    exit 1
fi

$PYTHON - "$VERSION_FILE" "$INDEX_FILE" << 'EOF'
import sys
import re

version_file = sys.argv[1]
index_file = sys.argv[2]

with open(version_file, 'r', encoding='utf-8') as f:
    version_content = f.read()

with open(index_file, 'r', encoding='utf-8') as f:
    index_content = f.read()

pattern = r'(<script type="application/json" id="versionJson">)[\s\S]*?(</script>)'
replacement = r'\1\n' + version_content + r'\n    \2'

new_content = re.sub(pattern, replacement, index_content, count=1)

with open(index_file, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("✅ 버전 정보 동기화 완료!")
print("   - version.json → firebase-wizard.html")
EOF
```

- [ ] **Step 3: 실행 권한 부여 + 동작 검증 (HTML 미존재 상태에서는 에러 정상)**

```bash
chmod +x .github/util/flutter/firebase-wizard/version-sync.sh
.github/util/flutter/firebase-wizard/version-sync.sh
```

Expected: `❌ firebase-wizard.html 파일을 찾을 수 없습니다: ...` (HTML 미작성 단계라 정상). Task 4 완료 후 다시 실행해 OK 메시지 확인.

- [ ] **Step 4: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/version.json .github/util/flutter/firebase-wizard/version-sync.sh
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : version.json + version-sync.sh 스캐폴드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 2: setup 스크립트 (bash) — TDD

**Files:**
- Create: `.github/util/flutter/firebase-wizard/firebase-wizard-setup.sh`
- Create: `.github/util/flutter/firebase-wizard/test/setup-script-test.sh`
- Create: `.github/util/flutter/firebase-wizard/test/fixtures/workflow-with-placeholders.yaml`
- Create: `.github/util/flutter/firebase-wizard/test/fixtures/workflow-with-real-values.yaml`
- Create: `.github/util/flutter/firebase-wizard/test/fixtures/workflow-without-keys.yaml`
- Create: `.github/util/flutter/firebase-wizard/test/fixtures/workflow-mixed.yaml`

### Subtask 2A: 테스트 fixture 작성

- [ ] **Step 1: placeholder 상태 fixture**

`.github/util/flutter/firebase-wizard/test/fixtures/workflow-with-placeholders.yaml`:

```yaml
name: TEST-WORKFLOW
on:
  workflow_dispatch:
env:
  FLUTTER_VERSION: "3.35.5"
  FIREBASE_APP_ID: "{FIREBASE_APP_ID}"
  FIREBASE_TESTER_GROUP: "{TESTER_GROUP}"
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
```

- [ ] **Step 2: 이미 실제 값 들어 있는 fixture**

`.github/util/flutter/firebase-wizard/test/fixtures/workflow-with-real-values.yaml`:

```yaml
name: TEST-WORKFLOW
on:
  workflow_dispatch:
env:
  FLUTTER_VERSION: "3.35.5"
  FIREBASE_APP_ID: "1:111111111111:android:aaaaaaaaaaaaaaaaaaaaaa"
  FIREBASE_TESTER_GROUP: "old-group"
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
```

- [ ] **Step 3: 키가 아예 없는 fixture**

`.github/util/flutter/firebase-wizard/test/fixtures/workflow-without-keys.yaml`:

```yaml
name: TEST-WORKFLOW
on:
  workflow_dispatch:
env:
  FLUTTER_VERSION: "3.35.5"
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
```

- [ ] **Step 4: 혼합 fixture (한 키만 placeholder, 다른 키는 같은 값)**

`.github/util/flutter/firebase-wizard/test/fixtures/workflow-mixed.yaml`:

```yaml
name: TEST-WORKFLOW
on:
  workflow_dispatch:
env:
  FLUTTER_VERSION: "3.35.5"
  FIREBASE_APP_ID: "{FIREBASE_APP_ID}"
  FIREBASE_TESTER_GROUP: "romrom"
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
```

### Subtask 2B: 테스트 스크립트 작성 (실패 상태로)

- [ ] **Step 5: 테스트 러너 작성** (실제 setup 스크립트 호출, 결과 검증)

`.github/util/flutter/firebase-wizard/test/setup-script-test.sh`:

```bash
#!/bin/bash
# Firebase wizard setup script - bash 시나리오 테스트
# 사용법: ./setup-script-test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIZARD_DIR="$(dirname "$SCRIPT_DIR")"
SETUP="$WIZARD_DIR/firebase-wizard-setup.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
FAIL_LOG=()

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local label="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        PASS=$((PASS + 1))
        echo "  ✅ $label"
    else
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$label — 기대 문자열 '$needle' 누락")
        echo "  ❌ $label"
    fi
}

assert_file_unchanged() {
    local original="$1"
    local actual="$2"
    local label="$3"
    if diff -q "$original" "$actual" > /dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo "  ✅ $label"
    else
        FAIL=$((FAIL + 1))
        FAIL_LOG+=("$label — 파일이 변경됨")
        echo "  ❌ $label"
    fi
}

setup_workspace() {
    local ws=$(mktemp -d)
    mkdir -p "$ws/.github/workflows"
    cp "$FIXTURES"/*.yaml "$ws/.github/workflows/"
    echo "$ws"
}

cleanup_workspace() {
    rm -rf "$1"
}

NEW_APP_ID="1:905325245238:android:86db75164e0df29a1f3997"
NEW_TESTER="romrom"

echo "=== 시나리오 1: placeholder → 새 값 치환 ==="
WS=$(setup_workspace)
OUT=$("$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup 2>&1)
assert_contains "$NEW_APP_ID" "$(cat $WS/.github/workflows/workflow-with-placeholders.yaml)" "placeholder fixture에 새 APP_ID 적용"
assert_contains "$NEW_TESTER" "$(cat $WS/.github/workflows/workflow-with-placeholders.yaml)" "placeholder fixture에 새 TESTER 적용"
cleanup_workspace "$WS"

echo "=== 시나리오 2: 키 없는 파일은 변경되지 않음 ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup > /dev/null 2>&1
assert_file_unchanged "$FIXTURES/workflow-without-keys.yaml" "$WS/.github/workflows/workflow-without-keys.yaml" "키 없는 fixture 변경 없음"
cleanup_workspace "$WS"

echo "=== 시나리오 3: 이미 같은 값은 SKIP ==="
WS=$(setup_workspace)
# mixed fixture의 TESTER_GROUP은 이미 "romrom"
OUT=$("$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup 2>&1)
assert_contains "이미" "$OUT" "같은 값 SKIP 메시지 출력"
assert_contains "$NEW_APP_ID" "$(cat $WS/.github/workflows/workflow-mixed.yaml)" "mixed fixture APP_ID는 치환됨"
cleanup_workspace "$WS"

echo "=== 시나리오 4: 다른 값 + non-interactive → SKIP ==="
WS=$(setup_workspace)
OUT=$("$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup 2>&1)
# real-values fixture는 다른 값들을 가지고 있음 → SKIP
ORIGINAL_APP_ID="1:111111111111:android:aaaaaaaaaaaaaaaaaaaaaa"
assert_contains "$ORIGINAL_APP_ID" "$(cat $WS/.github/workflows/workflow-with-real-values.yaml)" "real-values fixture APP_ID는 SKIP되어 보존"
assert_contains "old-group" "$(cat $WS/.github/workflows/workflow-with-real-values.yaml)" "real-values fixture TESTER_GROUP는 SKIP되어 보존"
cleanup_workspace "$WS"

echo "=== 시나리오 5: --dry-run 시 파일 변경 없음 ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup --dry-run > /dev/null 2>&1
assert_file_unchanged "$FIXTURES/workflow-with-placeholders.yaml" "$WS/.github/workflows/workflow-with-placeholders.yaml" "dry-run 시 placeholder fixture 변경 없음"
cleanup_workspace "$WS"

echo "=== 시나리오 6: 백업 파일 생성 ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive > /dev/null 2>&1
BAK_COUNT=$(ls "$WS/.github/workflows/"*.bak.* 2>/dev/null | wc -l)
if [ "$BAK_COUNT" -ge 2 ]; then
    PASS=$((PASS + 1))
    echo "  ✅ 백업 파일 자동 생성됨 ($BAK_COUNT개)"
else
    FAIL=$((FAIL + 1))
    FAIL_LOG+=("백업 파일이 충분히 생성되지 않음 ($BAK_COUNT개)")
    echo "  ❌ 백업 파일 자동 생성"
fi
cleanup_workspace "$WS"

echo "=== 시나리오 7: --no-backup 시 백업 파일 미생성 ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup > /dev/null 2>&1
BAK_COUNT=$(ls "$WS/.github/workflows/"*.bak.* 2>/dev/null | wc -l)
if [ "$BAK_COUNT" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  ✅ --no-backup 시 백업 미생성"
else
    FAIL=$((FAIL + 1))
    FAIL_LOG+=("--no-backup인데 백업 파일이 생성됨 ($BAK_COUNT개)")
    echo "  ❌ --no-backup"
fi
cleanup_workspace "$WS"

echo "=== 시나리오 8: .github/workflows 폴더 없을 때 abort ==="
WS=$(mktemp -d)
OUT=$("$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup 2>&1) || true
assert_contains "workflows" "$OUT" "workflows 폴더 없음 에러 메시지"
cleanup_workspace "$WS"

echo "=== 시나리오 9: 들여쓰기 보존 (라인 단위 처리 검증) ==="
WS=$(setup_workspace)
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup > /dev/null 2>&1
LINE=$(grep "FIREBASE_APP_ID" "$WS/.github/workflows/workflow-with-placeholders.yaml")
# 원본 들여쓰기는 2칸 (env: 하위)
assert_contains "  FIREBASE_APP_ID" "$LINE" "들여쓰기 2칸 보존"
cleanup_workspace "$WS"

echo "=== 시나리오 10: 단어 경계 (FIREBASE_APP_ID_DEV 같은 비슷한 키 보호) ==="
WS=$(mktemp -d)
mkdir -p "$WS/.github/workflows"
cat > "$WS/.github/workflows/edge.yaml" <<'EOF'
env:
  FIREBASE_APP_ID: "{FIREBASE_APP_ID}"
  FIREBASE_APP_ID_DEV: "{FIREBASE_APP_ID}"
EOF
"$SETUP" --project-path "$WS" --app-id "$NEW_APP_ID" --tester-group "$NEW_TESTER" --non-interactive --no-backup > /dev/null 2>&1
ID_DEV_LINE=$(grep "FIREBASE_APP_ID_DEV" "$WS/.github/workflows/edge.yaml")
assert_contains "{FIREBASE_APP_ID}" "$ID_DEV_LINE" "FIREBASE_APP_ID_DEV는 단어 경계 매칭으로 변경되지 않음"
cleanup_workspace "$WS"

echo
echo "===================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo
    echo "실패 항목:"
    for msg in "${FAIL_LOG[@]}"; do
        echo "  - $msg"
    done
    exit 1
fi
exit 0
```

- [ ] **Step 6: 실행 권한 + 테스트 실행 → 모두 실패 확인**

```bash
chmod +x .github/util/flutter/firebase-wizard/test/setup-script-test.sh
.github/util/flutter/firebase-wizard/test/setup-script-test.sh
```

Expected: `firebase-wizard-setup.sh` 미존재 → 모든 시나리오 FAIL.

### Subtask 2C: setup 스크립트 구현

- [ ] **Step 7: setup 스크립트 본문 작성**

`.github/util/flutter/firebase-wizard/firebase-wizard-setup.sh`:

```bash
#!/bin/bash
# ===================================================================
# Firebase App Distribution Wizard - Setup Script (bash)
# ===================================================================
# 워크플로우 파일들의 FIREBASE_APP_ID, FIREBASE_TESTER_GROUP 키를
# 라인 단위로 안전하게 치환합니다.
#
# 사용법:
#   ./firebase-wizard-setup.sh \
#     --project-path /path/to/project \
#     --app-id "1:905325245238:android:86db..." \
#     --tester-group "romrom" \
#     [--dry-run] [--non-interactive] [--no-backup]
# ===================================================================
set -u

# ---- Color ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---- Flags & args ----
PROJECT_PATH=""
APP_ID=""
TESTER_GROUP=""
DRY_RUN=0
NON_INTERACTIVE=0
NO_BACKUP=0

print_usage() {
    cat <<EOF
사용법: $0 --project-path <path> --app-id <id> --tester-group <group> [옵션]

옵션:
  --dry-run             실제 파일 수정 없이 변경 미리보기
  --non-interactive     충돌 시 자동 SKIP (프롬프트 안 띄움)
  --no-backup           백업 파일 자동 생성 비활성화
  -h, --help            이 도움말 출력
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --project-path) PROJECT_PATH="$2"; shift 2 ;;
        --app-id) APP_ID="$2"; shift 2 ;;
        --tester-group) TESTER_GROUP="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --non-interactive) NON_INTERACTIVE=1; shift ;;
        --no-backup) NO_BACKUP=1; shift ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo -e "${RED}❌ 알 수 없는 인자: $1${NC}"; print_usage; exit 2 ;;
    esac
done

# ---- 인자 검증 ----
if [ -z "$PROJECT_PATH" ] || [ -z "$APP_ID" ] || [ -z "$TESTER_GROUP" ]; then
    echo -e "${RED}❌ --project-path, --app-id, --tester-group 모두 필요합니다${NC}"
    print_usage
    exit 2
fi

if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ project-path 디렉터리가 존재하지 않음: $PROJECT_PATH${NC}"
    exit 2
fi

WORKFLOWS_DIR="$PROJECT_PATH/.github/workflows"
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo -e "${RED}❌ .github/workflows 폴더가 없음. 템플릿이 적용되지 않은 프로젝트입니다.${NC}"
    echo -e "${YELLOW}   확인 경로: $WORKFLOWS_DIR${NC}"
    exit 3
fi

# ---- 대상 파일 탐지 ----
mapfile -t YAML_FILES < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) | sort)

if [ "${#YAML_FILES[@]}" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ workflows 폴더에 yaml/yml 파일이 없음${NC}"
    exit 0
fi

TIMESTAMP=$(date +%s)
TOTAL_REPLACED=0
TOTAL_SKIPPED=0
TOTAL_CONFLICTS=0
SUMMARY=()

# ---- regex 매칭용 키 목록 ----
KEYS_PATTERN='FIREBASE_APP_ID|FIREBASE_TESTER_GROUP'

# ---- 파일별 처리 ----
process_file() {
    local file="$1"
    local rel="${file#$PROJECT_PATH/}"
    local file_replaced=0
    local file_skipped=0
    local file_conflicts=0
    local has_target_key=0

    # 키 존재 여부 사전 확인
    if ! grep -E "^[[:space:]]*($KEYS_PATTERN)[[:space:]]*:" "$file" > /dev/null 2>&1; then
        SUMMARY+=("⏭  $rel — 대상 키 없음, SKIP")
        return 0
    fi
    has_target_key=1

    # 백업
    if [ "$NO_BACKUP" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
        cp "$file" "$file.bak.$TIMESTAMP"
    fi

    local tmp
    tmp=$(mktemp)
    local IFS=
    while read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^([[:space:]]*)(FIREBASE_APP_ID|FIREBASE_TESTER_GROUP)([[:space:]]*:[[:space:]]*)(.*)$ ]]; then
            local indent="${BASH_REMATCH[1]}"
            local key="${BASH_REMATCH[2]}"
            local sep="${BASH_REMATCH[3]}"
            local raw_value="${BASH_REMATCH[4]}"
            # 따옴표·공백 제거
            local stripped="$raw_value"
            stripped="${stripped#\"}"; stripped="${stripped%\"}"
            stripped="${stripped#\'}"; stripped="${stripped%\'}"
            stripped="$(echo "$stripped" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

            local new_value=""
            local placeholder=""
            if [ "$key" = "FIREBASE_APP_ID" ]; then
                new_value="$APP_ID"
                placeholder="{FIREBASE_APP_ID}"
            else
                new_value="$TESTER_GROUP"
                placeholder="{TESTER_GROUP}"
            fi

            if [ "$stripped" = "$placeholder" ]; then
                echo "${indent}${key}${sep}\"${new_value}\"" >> "$tmp"
                file_replaced=$((file_replaced + 1))
                echo -e "  ${GREEN}✓${NC} $rel — $key: placeholder → $new_value"
            elif [ "$stripped" = "$new_value" ]; then
                echo "$line" >> "$tmp"
                file_skipped=$((file_skipped + 1))
                echo -e "  ${BLUE}ℹ${NC} $rel — $key: 이미 같은 값, SKIP"
            else
                if [ "$NON_INTERACTIVE" -eq 1 ]; then
                    echo "$line" >> "$tmp"
                    file_skipped=$((file_skipped + 1))
                    file_conflicts=$((file_conflicts + 1))
                    echo -e "  ${YELLOW}⚠${NC} $rel — $key: 다른 값 ('$stripped'), 비대화형 SKIP"
                else
                    echo
                    echo -e "${YELLOW}⚠ 충돌 감지: $rel${NC}"
                    echo "  키: $key"
                    echo "  현재값: $stripped"
                    echo "  새 값:  $new_value"
                    read -r -p "  덮어쓸까? (y/n/abort): " choice
                    case "$choice" in
                        y|Y)
                            echo "${indent}${key}${sep}\"${new_value}\"" >> "$tmp"
                            file_replaced=$((file_replaced + 1))
                            echo -e "  ${GREEN}✓${NC} 덮어씀"
                            ;;
                        n|N)
                            echo "$line" >> "$tmp"
                            file_skipped=$((file_skipped + 1))
                            echo -e "  ${BLUE}ℹ${NC} SKIP"
                            ;;
                        abort|A|a*)
                            echo -e "${RED}❌ 사용자 abort 요청${NC}"
                            rm -f "$tmp"
                            if [ "$NO_BACKUP" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
                                mv "$file.bak.$TIMESTAMP" "$file"
                            fi
                            return 99
                            ;;
                        *)
                            echo "$line" >> "$tmp"
                            file_skipped=$((file_skipped + 1))
                            echo -e "  ${BLUE}ℹ${NC} 알 수 없는 입력 → SKIP"
                            ;;
                    esac
                fi
            fi
        else
            echo "$line" >> "$tmp"
        fi
    done < "$file"

    if [ "$DRY_RUN" -eq 0 ]; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
    fi

    TOTAL_REPLACED=$((TOTAL_REPLACED + file_replaced))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + file_skipped))
    TOTAL_CONFLICTS=$((TOTAL_CONFLICTS + file_conflicts))
    SUMMARY+=("📝 $rel — 치환 $file_replaced, SKIP $file_skipped, 충돌 $file_conflicts")
}

echo -e "${CYAN}▶ Firebase Wizard Setup${NC}"
echo "  project-path: $PROJECT_PATH"
echo "  app-id:       $APP_ID"
echo "  tester-group: $TESTER_GROUP"
echo "  dry-run:      $DRY_RUN | non-interactive: $NON_INTERACTIVE | no-backup: $NO_BACKUP"
echo

ABORTED=0
for f in "${YAML_FILES[@]}"; do
    process_file "$f"
    rc=$?
    if [ "$rc" -eq 99 ]; then
        ABORTED=1
        break
    fi
done

echo
echo -e "${CYAN}===== Summary =====${NC}"
for line in "${SUMMARY[@]}"; do
    echo "  $line"
done
echo
echo "총 치환: $TOTAL_REPLACED | SKIP: $TOTAL_SKIPPED | 충돌(SKIP): $TOTAL_CONFLICTS"

if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${YELLOW}※ --dry-run: 실제 파일은 수정되지 않았습니다${NC}"
fi

if [ "$ABORTED" -eq 1 ]; then
    echo -e "${RED}❌ 사용자 abort로 중단됨${NC}"
    exit 4
fi
exit 0
```

- [ ] **Step 8: 실행 권한 + 테스트 실행 → 모두 PASS 확인**

```bash
chmod +x .github/util/flutter/firebase-wizard/firebase-wizard-setup.sh
.github/util/flutter/firebase-wizard/test/setup-script-test.sh
```

Expected: `PASS: 11+, FAIL: 0` (시나리오 10개 + 백업 검증 등). FAIL 발생 시 setup 스크립트 디버그 후 재실행.

- [ ] **Step 9: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard-setup.sh \
        .github/util/flutter/firebase-wizard/test/setup-script-test.sh \
        .github/util/flutter/firebase-wizard/test/fixtures/
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : bash setup 스크립트 + 시나리오 테스트 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 3: setup 스크립트 (PowerShell) — TDD

**Files:**
- Create: `.github/util/flutter/firebase-wizard/firebase-wizard-setup.ps1`
- Create: `.github/util/flutter/firebase-wizard/test/setup-script-test.ps1`

### Subtask 3A: 테스트 스크립트 작성 (실패 상태로)

- [ ] **Step 1: PowerShell 테스트 러너 작성**

`.github/util/flutter/firebase-wizard/test/setup-script-test.ps1`:

```powershell
# Firebase wizard setup script - PowerShell 시나리오 테스트
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WizardDir = Split-Path -Parent $ScriptDir
$Setup = Join-Path $WizardDir "firebase-wizard-setup.ps1"
$Fixtures = Join-Path $ScriptDir "fixtures"

$Pass = 0
$Fail = 0
$FailLog = @()

function Assert-Contains {
    param($Needle, $Haystack, $Label)
    if ($Haystack -like "*$Needle*") {
        $script:Pass++
        Write-Host "  [OK] $Label" -ForegroundColor Green
    } else {
        $script:Fail++
        $script:FailLog += "$Label -- 기대 문자열 '$Needle' 누락"
        Write-Host "  [FAIL] $Label" -ForegroundColor Red
    }
}

function Setup-Workspace {
    $ws = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path "$ws\.github\workflows" -Force | Out-Null
    Copy-Item "$Fixtures\*.yaml" -Destination "$ws\.github\workflows\"
    return $ws
}

function Cleanup-Workspace { param($ws); Remove-Item -Recurse -Force $ws -ErrorAction SilentlyContinue }

$NewAppId = "1:905325245238:android:86db75164e0df29a1f3997"
$NewTester = "romrom"

Write-Host "=== 시나리오 1: placeholder -> 새 값 치환 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$content = Get-Content "$ws\.github\workflows\workflow-with-placeholders.yaml" -Raw
Assert-Contains $NewAppId $content "placeholder fixture에 새 APP_ID 적용"
Assert-Contains $NewTester $content "placeholder fixture에 새 TESTER 적용"
Cleanup-Workspace $ws

Write-Host "=== 시나리오 2: 키 없는 파일 변경 없음 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$origHash = (Get-FileHash "$Fixtures\workflow-without-keys.yaml").Hash
$newHash = (Get-FileHash "$ws\.github\workflows\workflow-without-keys.yaml").Hash
if ($origHash -eq $newHash) {
    $Pass++; Write-Host "  [OK] 키 없는 fixture 변경 없음" -ForegroundColor Green
} else {
    $Fail++; $FailLog += "키 없는 fixture가 변경됨"
    Write-Host "  [FAIL] 키 없는 fixture 변경 없음" -ForegroundColor Red
}
Cleanup-Workspace $ws

Write-Host "=== 시나리오 3: 같은 값 SKIP ==="
$ws = Setup-Workspace
$out = & $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup *>&1 | Out-String
Assert-Contains "이미" $out "같은 값 SKIP 메시지"
Cleanup-Workspace $ws

Write-Host "=== 시나리오 4: 다른 값 + non-interactive SKIP ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$content = Get-Content "$ws\.github\workflows\workflow-with-real-values.yaml" -Raw
Assert-Contains "1:111111111111:android:aaaaaaaaaaaaaaaaaaaaaa" $content "real-values APP_ID SKIP 보존"
Assert-Contains "old-group" $content "real-values TESTER_GROUP SKIP 보존"
Cleanup-Workspace $ws

Write-Host "=== 시나리오 5: --dry-run 시 변경 없음 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup -DryRun | Out-Null
$origHash = (Get-FileHash "$Fixtures\workflow-with-placeholders.yaml").Hash
$newHash = (Get-FileHash "$ws\.github\workflows\workflow-with-placeholders.yaml").Hash
if ($origHash -eq $newHash) {
    $Pass++; Write-Host "  [OK] dry-run 시 변경 없음" -ForegroundColor Green
} else {
    $Fail++; $FailLog += "dry-run인데 파일이 변경됨"
    Write-Host "  [FAIL] dry-run" -ForegroundColor Red
}
Cleanup-Workspace $ws

Write-Host "=== 시나리오 6: 백업 생성 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive | Out-Null
$bakCount = (Get-ChildItem "$ws\.github\workflows\*.bak.*" -ErrorAction SilentlyContinue).Count
if ($bakCount -ge 2) {
    $Pass++; Write-Host "  [OK] 백업 자동 생성 ($bakCount개)" -ForegroundColor Green
} else {
    $Fail++; $FailLog += "백업 부족 ($bakCount개)"
    Write-Host "  [FAIL] 백업" -ForegroundColor Red
}
Cleanup-Workspace $ws

Write-Host "=== 시나리오 7: --no-backup 시 백업 미생성 ==="
$ws = Setup-Workspace
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$bakCount = (Get-ChildItem "$ws\.github\workflows\*.bak.*" -ErrorAction SilentlyContinue).Count
if ($bakCount -eq 0) {
    $Pass++; Write-Host "  [OK] --no-backup 시 백업 미생성" -ForegroundColor Green
} else {
    $Fail++; $FailLog += "--no-backup인데 백업 생성됨 ($bakCount개)"
    Write-Host "  [FAIL] --no-backup" -ForegroundColor Red
}
Cleanup-Workspace $ws

Write-Host "=== 시나리오 8: workflows 폴더 없음 abort ==="
$ws = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $ws -Force | Out-Null
$out = & $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup *>&1 | Out-String
Assert-Contains "workflows" $out "workflows 폴더 없음 에러"
Cleanup-Workspace $ws

Write-Host "=== 시나리오 9: 단어 경계 (FIREBASE_APP_ID_DEV 보호) ==="
$ws = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path "$ws\.github\workflows" -Force | Out-Null
@'
env:
  FIREBASE_APP_ID: "{FIREBASE_APP_ID}"
  FIREBASE_APP_ID_DEV: "{FIREBASE_APP_ID}"
'@ | Out-File -Encoding utf8 "$ws\.github\workflows\edge.yaml"
& $Setup -ProjectPath $ws -AppId $NewAppId -TesterGroup $NewTester -NonInteractive -NoBackup | Out-Null
$line = (Select-String -Path "$ws\.github\workflows\edge.yaml" -Pattern "FIREBASE_APP_ID_DEV").Line
Assert-Contains "{FIREBASE_APP_ID}" $line "FIREBASE_APP_ID_DEV는 단어 경계 매칭으로 변경되지 않음"
Cleanup-Workspace $ws

Write-Host ""
Write-Host "===================="
Write-Host "PASS: $Pass"
Write-Host "FAIL: $Fail"
if ($Fail -gt 0) {
    Write-Host ""
    Write-Host "실패 항목:"
    foreach ($m in $FailLog) { Write-Host "  - $m" }
    exit 1
}
exit 0
```

- [ ] **Step 2: 테스트 실행 → 모두 실패 확인**

```powershell
powershell -ExecutionPolicy Bypass -File .github/util/flutter/firebase-wizard/test/setup-script-test.ps1
```

Expected: `firebase-wizard-setup.ps1` 미존재 → 모든 시나리오 FAIL.

### Subtask 3B: PowerShell setup 스크립트 구현

- [ ] **Step 3: PowerShell setup 스크립트 본문 작성**

`.github/util/flutter/firebase-wizard/firebase-wizard-setup.ps1`:

```powershell
<#
.SYNOPSIS
  Firebase App Distribution Wizard - Setup Script (PowerShell)

.DESCRIPTION
  워크플로우 파일들의 FIREBASE_APP_ID, FIREBASE_TESTER_GROUP 키를
  라인 단위로 안전하게 치환합니다.

.EXAMPLE
  .\firebase-wizard-setup.ps1 -ProjectPath . -AppId "1:905..." -TesterGroup "romrom"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ProjectPath,
    [Parameter(Mandatory)] [string]$AppId,
    [Parameter(Mandatory)] [string]$TesterGroup,
    [switch]$DryRun,
    [switch]$NonInteractive,
    [switch]$NoBackup
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path -PathType Container $ProjectPath)) {
    Write-Host "[ERROR] project-path 디렉터리가 존재하지 않음: $ProjectPath" -ForegroundColor Red
    exit 2
}

$WorkflowsDir = Join-Path $ProjectPath ".github\workflows"
if (-not (Test-Path -PathType Container $WorkflowsDir)) {
    Write-Host "[ERROR] .github/workflows 폴더가 없음. 템플릿 미적용 프로젝트입니다." -ForegroundColor Red
    Write-Host "        확인 경로: $WorkflowsDir" -ForegroundColor Yellow
    exit 3
}

$YamlFiles = Get-ChildItem -Path $WorkflowsDir -File -Include "*.yaml","*.yml" |
    Where-Object { -not $_.PSIsContainer } | Sort-Object Name

if ($YamlFiles.Count -eq 0) {
    Write-Host "[WARN] workflows 폴더에 yaml/yml 파일이 없음" -ForegroundColor Yellow
    exit 0
}

$Timestamp = [int][double]::Parse((Get-Date -UFormat %s))
$TotalReplaced = 0
$TotalSkipped = 0
$TotalConflicts = 0
$Summary = @()
$Aborted = $false

# regex: indent + key + sep + value (단어 경계 보장 — \s*: 직후가 비-단어 문자)
$KeyPattern = '^(?<indent>\s*)(?<key>FIREBASE_APP_ID|FIREBASE_TESTER_GROUP)(?<sep>\s*:\s*)(?<value>.*)$'

function Strip-Quotes {
    param([string]$Raw)
    $v = $Raw.Trim()
    if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
        $v = $v.Substring(1, $v.Length - 2)
    }
    return $v.Trim()
}

function Process-File {
    param([string]$FilePath)
    $rel = $FilePath.Substring($ProjectPath.Length).TrimStart('\','/')
    $fileReplaced = 0
    $fileSkipped = 0
    $fileConflicts = 0

    $lines = Get-Content -LiteralPath $FilePath -Encoding UTF8
    $hasTargetKey = $false
    foreach ($l in $lines) {
        if ($l -match $KeyPattern) { $hasTargetKey = $true; break }
    }
    if (-not $hasTargetKey) {
        $script:Summary += "[SKIP] $rel -- 대상 키 없음"
        return $false
    }

    if (-not $NoBackup -and -not $DryRun) {
        Copy-Item -LiteralPath $FilePath -Destination "$FilePath.bak.$Timestamp" -Force
    }

    $newLines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -match $KeyPattern) {
            $indent = $Matches['indent']
            $key = $Matches['key']
            $sep = $Matches['sep']
            $rawValue = $Matches['value']
            $stripped = Strip-Quotes $rawValue

            $newValue = if ($key -eq 'FIREBASE_APP_ID') { $AppId } else { $TesterGroup }
            $placeholder = if ($key -eq 'FIREBASE_APP_ID') { '{FIREBASE_APP_ID}' } else { '{TESTER_GROUP}' }

            if ($stripped -eq $placeholder) {
                $newLines.Add("$indent$key$sep`"$newValue`"")
                $fileReplaced++
                Write-Host "  [OK] $rel -- ${key}: placeholder -> $newValue" -ForegroundColor Green
            } elseif ($stripped -eq $newValue) {
                $newLines.Add($line)
                $fileSkipped++
                Write-Host "  [INFO] $rel -- ${key}: 이미 같은 값, SKIP" -ForegroundColor Cyan
            } else {
                if ($NonInteractive) {
                    $newLines.Add($line)
                    $fileSkipped++
                    $fileConflicts++
                    Write-Host "  [WARN] $rel -- ${key}: 다른 값 ('$stripped'), 비대화형 SKIP" -ForegroundColor Yellow
                } else {
                    Write-Host ""
                    Write-Host "[!] 충돌 감지: $rel" -ForegroundColor Yellow
                    Write-Host "    키:    $key"
                    Write-Host "    현재값: $stripped"
                    Write-Host "    새 값: $newValue"
                    $choice = Read-Host "    덮어쓸까? (y/n/abort)"
                    switch -Regex ($choice) {
                        '^[yY]' {
                            $newLines.Add("$indent$key$sep`"$newValue`"")
                            $fileReplaced++
                            Write-Host "    [OK] 덮어씀" -ForegroundColor Green
                        }
                        '^[nN]' {
                            $newLines.Add($line)
                            $fileSkipped++
                            Write-Host "    [INFO] SKIP" -ForegroundColor Cyan
                        }
                        '^[aA]' {
                            Write-Host "[ERROR] 사용자 abort" -ForegroundColor Red
                            if (-not $NoBackup -and -not $DryRun) {
                                Move-Item -Force "$FilePath.bak.$Timestamp" $FilePath
                            }
                            $script:Aborted = $true
                            return $true
                        }
                        default {
                            $newLines.Add($line)
                            $fileSkipped++
                            Write-Host "    [INFO] 알 수 없는 입력 -> SKIP" -ForegroundColor Cyan
                        }
                    }
                }
            }
        } else {
            $newLines.Add($line)
        }
    }

    if (-not $DryRun) {
        $newLines -join [Environment]::NewLine | Set-Content -LiteralPath $FilePath -Encoding UTF8
    }

    $script:TotalReplaced += $fileReplaced
    $script:TotalSkipped += $fileSkipped
    $script:TotalConflicts += $fileConflicts
    $script:Summary += "[FILE] $rel -- 치환 $fileReplaced, SKIP $fileSkipped, 충돌 $fileConflicts"
    return $false
}

Write-Host "[Firebase Wizard Setup]" -ForegroundColor Cyan
Write-Host "  project-path: $ProjectPath"
Write-Host "  app-id:       $AppId"
Write-Host "  tester-group: $TesterGroup"
Write-Host "  dry-run: $DryRun | non-interactive: $NonInteractive | no-backup: $NoBackup"
Write-Host ""

foreach ($f in $YamlFiles) {
    $abort = Process-File $f.FullName
    if ($abort) { break }
}

Write-Host ""
Write-Host "===== Summary =====" -ForegroundColor Cyan
foreach ($s in $Summary) { Write-Host "  $s" }
Write-Host ""
Write-Host "총 치환: $TotalReplaced | SKIP: $TotalSkipped | 충돌(SKIP): $TotalConflicts"

if ($DryRun) {
    Write-Host "[!] --DryRun: 실제 파일은 수정되지 않았습니다" -ForegroundColor Yellow
}
if ($Aborted) {
    Write-Host "[ERROR] 사용자 abort로 중단됨" -ForegroundColor Red
    exit 4
}
exit 0
```

- [ ] **Step 4: 테스트 실행 → 모두 PASS 확인**

```powershell
powershell -ExecutionPolicy Bypass -File .github/util/flutter/firebase-wizard/test/setup-script-test.ps1
```

Expected: `PASS: 11+, FAIL: 0`. FAIL 시 디버그 후 재실행.

- [ ] **Step 5: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard-setup.ps1 \
        .github/util/flutter/firebase-wizard/test/setup-script-test.ps1
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : PowerShell setup 스크립트 + 시나리오 테스트 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 4: HTML 스캐폴드 (헤더 + 5단계 빈 카드 + navigation)

**Files:**
- Create: `.github/util/flutter/firebase-wizard/firebase-wizard.html`

PlayStore wizard html에서 다음을 차용:
- `<head>` 영역 (Tailwind config, Pretendard font, JSZip CDN, dark theme)
- step indicator 마크업 (총 5단계)
- step-content 카드 패턴
- 보안 경고 모달
- 푸터 영역

PlayStore와 다른 부분:
- `<title>`: "Firebase App Distribution 배포 마법사"
- 단계 5개로 축소 (1=Console, 2=SA발급, 3=앱정보, 4=파일업로드, 5=Secrets)
- 색상 테마: Firebase 오렌지(`#FFA000`)/노랑 강조

- [ ] **Step 1: HTML 스캐폴드 작성** (Step 본문은 비워둔 채 카드 구조만)

`.github/util/flutter/firebase-wizard/firebase-wizard.html`:

```html
<!DOCTYPE html>
<html lang="ko" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Firebase App Distribution 배포 마법사</title>
    <script type="application/json" id="versionJson">
{
  "name": "Firebase App Distribution Setup Wizard",
  "version": "1.0.0"
}
    </script>
    <link rel="stylesheet" as="style" crossorigin href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable.min.css" />
    <script src="https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js"></script>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Pretendard Variable', 'Pretendard', '-apple-system', 'BlinkMacSystemFont', 'system-ui', 'Roboto', 'Helvetica Neue', 'Segoe UI', 'Apple SD Gothic Neo', 'Noto Sans KR', 'Malgun Gothic', 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'sans-serif']
                    },
                    colors: {
                        firebase: {
                            primary: '#FFA000',
                            accent: '#FFCA28',
                            dark: '#FF6F00'
                        },
                        dark: {
                            bg: '#0f172a',
                            card: '#1e293b',
                            border: '#334155',
                            text: '#e2e8f0',
                            muted: '#94a3b8'
                        }
                    }
                }
            }
        }
    </script>
    <style>
        body { background: #0f172a; color: #e2e8f0; font-family: 'Pretendard Variable', sans-serif; }
        .file-upload { border: 2px dashed #475569; border-radius: 0.75rem; padding: 1.5rem; text-align: center; cursor: pointer; transition: all 0.2s; }
        .file-upload:hover { border-color: #FFA000; background: rgba(255, 160, 0, 0.05); }
        .file-upload.dragover { border-color: #FFA000; background: rgba(255, 160, 0, 0.1); }
        .file-upload .icon { font-size: 2rem; margin-bottom: 0.5rem; }
        .step-indicator { display: flex; align-items: center; justify-content: center; gap: 0.5rem; margin-bottom: 2rem; }
        .step-dot { width: 2.25rem; height: 2.25rem; border-radius: 9999px; display: flex; align-items: center; justify-content: center; font-weight: 700; cursor: pointer; transition: all 0.2s; }
        .step-dot.active { background: #FFA000; color: #0f172a; }
        .step-dot.completed { background: #22c55e; color: #0f172a; }
        .step-dot.pending { background: #1e293b; color: #94a3b8; border: 1px solid #334155; }
        .step-line { width: 2rem; height: 2px; background: #334155; }
        .step-line.completed { background: #22c55e; }
        .skip-btn { color: #94a3b8; font-size: 0.875rem; cursor: pointer; padding: 0.5rem 1rem; }
        .skip-btn:hover { color: #FFA000; }
        .fade-in { animation: fadeIn 0.3s ease; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
        .toast { position: fixed; bottom: 2rem; left: 50%; transform: translateX(-50%); background: #1e293b; border: 1px solid #334155; padding: 0.75rem 1.5rem; border-radius: 0.5rem; box-shadow: 0 10px 25px rgba(0,0,0,0.3); z-index: 1000; opacity: 0; pointer-events: none; transition: opacity 0.2s; }
        .toast.show { opacity: 1; }
    </style>
</head>
<body class="min-h-screen p-4 md:p-8">
    <div class="max-w-4xl mx-auto">
        <!-- 헤더 -->
        <header class="mb-8 text-center">
            <h1 class="text-3xl md:text-4xl font-bold mb-3">
                🔥 <span class="bg-gradient-to-r from-firebase-primary to-firebase-accent bg-clip-text text-transparent">Firebase App Distribution 배포 마법사</span>
            </h1>
            <p class="text-slate-400 mb-3">Flutter Android 테스트 빌드를 Firebase로 자동 배포하는 5단계 설정</p>
            <a href="https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE" target="_blank" rel="noopener"
               class="text-xs text-slate-500 hover:text-slate-300">
               SUH-DEVOPS-TEMPLATE GitHub →
            </a>
        </header>

        <!-- Step Indicator -->
        <div class="step-indicator" id="stepIndicator">
            <div class="step-dot active" data-step="1" onclick="goToStep(1)">1</div>
            <div class="step-line"></div>
            <div class="step-dot pending" data-step="2" onclick="goToStep(2)">2</div>
            <div class="step-line"></div>
            <div class="step-dot pending" data-step="3" onclick="goToStep(3)">3</div>
            <div class="step-line"></div>
            <div class="step-dot pending" data-step="4" onclick="goToStep(4)">4</div>
            <div class="step-line"></div>
            <div class="step-dot pending" data-step="5" onclick="goToStep(5)">5</div>
        </div>

        <!-- ========================================== -->
        <!-- Step 1: Firebase Console 가이드 -->
        <!-- ========================================== -->
        <div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content fade-in" data-step="1">
            <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
                <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">1</span>
                Firebase Console 설정
            </h2>
            <p class="text-sm text-slate-400 mb-6">[Step 1 본문 — Task 6에서 작성]</p>
            <div class="flex justify-end mt-8">
                <button class="px-6 py-2.5 bg-gradient-to-r from-firebase-primary to-firebase-accent text-slate-900 hover:opacity-90 rounded-lg font-medium transition" onclick="nextStep()">
                    다음: Service Account →
                </button>
            </div>
        </div>

        <!-- Step 2 -->
        <div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="2">
            <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
                <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">2</span>
                Service Account 발급 + 권한 부여
            </h2>
            <p class="text-sm text-slate-400 mb-6">[Step 2 본문 — Task 7에서 작성]</p>
            <div class="flex justify-between mt-8">
                <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
                <button class="px-6 py-2.5 bg-gradient-to-r from-firebase-primary to-firebase-accent text-slate-900 hover:opacity-90 rounded-lg font-medium transition" onclick="nextStep()">다음: 앱 정보 →</button>
            </div>
        </div>

        <!-- Step 3 -->
        <div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="3">
            <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
                <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">3</span>
                앱 정보 입력
            </h2>
            <p class="text-sm text-slate-400 mb-6">[Step 3 본문 — Task 8에서 작성]</p>
            <div class="flex justify-between mt-8">
                <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
                <button class="px-6 py-2.5 bg-gradient-to-r from-firebase-primary to-firebase-accent text-slate-900 hover:opacity-90 rounded-lg font-medium transition" onclick="nextStep()">다음: 파일 업로드 →</button>
            </div>
        </div>

        <!-- Step 4 -->
        <div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="4">
            <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
                <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">4</span>
                파일 업로드 + 변환
            </h2>
            <p class="text-sm text-slate-400 mb-6">[Step 4 본문 — Task 9, Task 10에서 작성]</p>
            <div class="flex justify-between mt-8">
                <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
                <button class="px-6 py-2.5 bg-gradient-to-r from-firebase-primary to-firebase-accent text-slate-900 hover:opacity-90 rounded-lg font-medium transition" onclick="nextStep()">다음: Secrets 등록 →</button>
            </div>
        </div>

        <!-- Step 5 -->
        <div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="5">
            <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
                <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">5</span>
                GitHub Secrets 등록 + 다운로드
            </h2>
            <p class="text-sm text-slate-400 mb-6">[Step 5 본문 — Task 11에서 작성]</p>
            <div class="flex justify-between mt-8">
                <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
                <button class="px-6 py-2.5 bg-green-600 hover:bg-green-700 rounded-lg font-medium transition" onclick="resetWizard()">처음부터 다시</button>
            </div>
        </div>

        <footer class="text-center text-xs text-slate-500 mt-8">
            Made with 🔥 Firebase | <a href="https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE" target="_blank" class="hover:text-slate-300">View on GitHub →</a>
        </footer>
    </div>

    <!-- Toast -->
    <div id="toast" class="toast"></div>

    <!-- JS -->
    <script src="firebase-wizard.js"></script>
</body>
</html>
```

- [ ] **Step 2: 브라우저로 열어 시각 확인**

Windows: `start .github/util/flutter/firebase-wizard/firebase-wizard.html`
macOS: `open .github/util/flutter/firebase-wizard/firebase-wizard.html`
Linux: `xdg-open .github/util/flutter/firebase-wizard/firebase-wizard.html`

Expected: 다크 테마, 5개 step indicator, Step 1 카드만 표시. nextStep 클릭은 JS 미작성 상태라 작동 안 함 (정상).

- [ ] **Step 3: version-sync.sh 동작 검증**

```bash
.github/util/flutter/firebase-wizard/version-sync.sh
```

Expected: `✅ 버전 정보 동기화 완료!`

- [ ] **Step 4: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard.html
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : HTML 스캐폴드 5단계 카드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 5: JS 기반 인프라 (state, localStorage, OS detect, toast, copy, navigation)

**Files:**
- Create: `.github/util/flutter/firebase-wizard/firebase-wizard.js`

PlayStore wizard JS의 다음 함수들을 그대로 차용 (Firebase 맞춤 수정):
- `detectOS()` (그대로)
- `state` (Firebase 필드만 포함)
- `saveState()`, `loadState()`, `clearState()` (STORAGE_KEY만 변경)
- `$()`, `$$()`, `getInputValue()`, `setElementText()`, `setElementHtml()` (그대로)
- `fileToBase64()` (그대로)
- `copyToClipboard()`, `copyCode()`, `copySecret()`, `showToast()` (그대로)
- `updateProgress()`, `showStep()`, `nextStep()`, `prevStep()`, `goToStep()`, `resetWizard()` (totalSteps=5로 조정)

- [ ] **Step 1: JS 본문 작성**

`.github/util/flutter/firebase-wizard/firebase-wizard.js`:

```javascript
/**
 * Firebase App Distribution Wizard
 * 정적 HTML/JS 마법사 - GitHub API 호출 안 함
 */

// ============================================
// OS Detection
// ============================================
let detectedOS = 'mac';
function detectOS() {
    const ua = navigator.userAgent || navigator.appVersion || navigator.platform;
    if (/Win/i.test(ua)) return 'windows';
    if (/Mac/i.test(ua)) return 'mac';
    if (/Linux/i.test(ua)) return 'linux';
    return 'mac';
}

// ============================================
// State
// ============================================
const state = {
    currentStep: 1,
    maxReachedStep: 1,
    totalSteps: 5,
    detectedOS: 'mac',
    // Step 3
    firebaseAppId: '',
    firebaseTesterGroup: '',
    projectPath: '.',
    // Step 4
    serviceAccountBase64: '',
    serviceAccountFileName: '',
    googleServicesJson: '',
    googleServicesFileName: '',
    // Step 5
    repoOwner: '',
    repoName: '',
    // Custom Secrets
    customSecrets: []
};

const STORAGE_KEY = 'firebase_wizard_state';

function saveState() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }
    catch (e) { console.warn('localStorage save failed:', e); }
}

function loadState() {
    try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
            const s = JSON.parse(saved);
            const total = state.totalSteps;
            Object.assign(state, s);
            state.totalSteps = total;
            state.detectedOS = detectOS();
            if (state.currentStep > state.totalSteps) state.currentStep = state.totalSteps;
            if (!state.maxReachedStep || state.maxReachedStep < state.currentStep) state.maxReachedStep = state.currentStep;
            if (state.maxReachedStep > state.totalSteps) state.maxReachedStep = state.totalSteps;
            return true;
        }
    } catch (e) { console.warn('localStorage load failed:', e); }
    return false;
}

function clearState() {
    try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
}

// ============================================
// Helpers
// ============================================
function $(sel) { return document.querySelector(sel); }
function $$(sel) { return document.querySelectorAll(sel); }
function getInputValue(id) { const el = document.getElementById(id); return el ? el.value : ''; }

function fileToBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
            const r = reader.result;
            const b64 = r.includes(',') ? r.split(',')[1] : r;
            resolve(b64);
        };
        reader.onerror = (e) => reject(e);
        reader.readAsDataURL(file);
    });
}

async function fileToText(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = (e) => reject(e);
        reader.readAsText(file, 'utf-8');
    });
}

// ============================================
// Toast / Copy
// ============================================
function showToast(message) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 2500);
}

async function copyToClipboard(text) {
    try {
        await navigator.clipboard.writeText(text);
        showToast('✅ 복사되었습니다');
    } catch (e) {
        const ta = document.createElement('textarea');
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        showToast('✅ 복사되었습니다');
    }
}

function copyCode(button) {
    const target = button.previousElementSibling;
    const text = target ? target.textContent : '';
    if (!text) { showToast('⚠️ 복사할 내용이 없습니다'); return; }
    copyToClipboard(text);
}

function copySecret(name) {
    const map = {
        'FIREBASE_SERVICE_ACCOUNT_JSON_BASE64': state.serviceAccountBase64,
        'GOOGLE_SERVICES_JSON': state.googleServicesJson
    };
    const value = map[name] || '';
    if (!value) { showToast(`⚠️ ${name} 값이 비어있습니다`); return; }
    copyToClipboard(value);
}

// ============================================
// Navigation
// ============================================
function updateStepIndicator() {
    const dots = $$('.step-dot');
    dots.forEach(dot => {
        const step = parseInt(dot.dataset.step);
        dot.classList.remove('active', 'completed', 'pending');
        if (step === state.currentStep) dot.classList.add('active');
        else if (step < state.currentStep) dot.classList.add('completed');
        else dot.classList.add('pending');
    });
    const lines = $$('.step-line');
    lines.forEach((line, i) => {
        if (i + 1 < state.currentStep) line.classList.add('completed');
        else line.classList.remove('completed');
    });
}

function showStep(step) {
    state.currentStep = step;
    if (step > state.maxReachedStep) state.maxReachedStep = step;
    $$('.step-content').forEach(el => {
        el.classList.toggle('hidden', parseInt(el.dataset.step) !== step);
        el.classList.add('fade-in');
    });
    updateStepIndicator();
    saveState();
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function nextStep() {
    if (state.currentStep < state.totalSteps) showStep(state.currentStep + 1);
}

function prevStep() {
    if (state.currentStep > 1) showStep(state.currentStep - 1);
}

function goToStep(step) {
    if (step <= state.maxReachedStep) showStep(step);
    else showToast('⚠️ 이전 단계를 먼저 완료해주세요');
}

function resetWizard() {
    if (!confirm('모든 입력 정보를 초기화할까요?')) return;
    clearState();
    Object.assign(state, {
        currentStep: 1, maxReachedStep: 1, totalSteps: 5, detectedOS: detectOS(),
        firebaseAppId: '', firebaseTesterGroup: '', projectPath: '.',
        serviceAccountBase64: '', serviceAccountFileName: '',
        googleServicesJson: '', googleServicesFileName: '',
        repoOwner: '', repoName: '', customSecrets: []
    });
    showStep(1);
    showToast('🔄 초기화되었습니다');
}

// ============================================
// Init
// ============================================
window.addEventListener('DOMContentLoaded', () => {
    state.detectedOS = detectOS();
    detectedOS = state.detectedOS;
    loadState();
    showStep(state.currentStep);
});
```

- [ ] **Step 2: 브라우저로 열어 navigation 동작 확인**

Expected: Step 1 → 2 → 3 → 4 → 5 순방향 이동, 이전 버튼 정상 동작, step indicator 색 변화, localStorage에 상태 저장.

- [ ] **Step 3: 새로고침 후 상태 복원 확인**

Expected: Step 3에서 새로고침 → Step 3 그대로 유지.

- [ ] **Step 4: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard.js
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : JS 기반 인프라 state·navigation·toast·copy https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 6: Step 1 UI — Firebase Console 가이드

**Files:**
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.html` (Step 1 카드 본문)

- [ ] **Step 1: Step 1 본문 작성** (HTML의 `<div class="card ... data-step="1">` 내부 placeholder 부분 교체)

`.github/util/flutter/firebase-wizard/firebase-wizard.html`의 Step 1 카드를 아래로 교체:

```html
<div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content fade-in" data-step="1">
    <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
        <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">1</span>
        Firebase Console 설정
    </h2>

    <div class="bg-firebase-primary/10 border border-firebase-primary/30 rounded-lg p-4 mb-6">
        <p class="text-sm text-firebase-accent">
            🔥 <strong>이 단계의 목표:</strong> Firebase 프로젝트에 Android 앱을 등록하고 App Distribution을 활성화한 뒤, 테스터 그룹을 만들어 둡니다.
        </p>
    </div>

    <div class="mb-4">
        <a href="https://console.firebase.google.com" target="_blank" rel="noopener"
           class="inline-flex items-center gap-2 px-4 py-2 bg-firebase-primary hover:bg-firebase-dark text-slate-900 rounded-lg text-sm font-medium transition">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
            </svg>
            Firebase Console 열기
        </a>
    </div>

    <div class="space-y-4">
        <div class="bg-slate-700/50 border border-slate-600 rounded-lg p-4">
            <p class="text-sm font-medium text-firebase-accent mb-2">1) 프로젝트 생성 또는 선택</p>
            <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                <li>"프로젝트 추가" 또는 기존 프로젝트 선택</li>
                <li>프로젝트 이름 입력 → 약관 동의 → "계속"</li>
                <li>Google Analytics는 선택 사항 (켜도 무방)</li>
            </ol>
        </div>

        <div class="bg-slate-700/50 border border-slate-600 rounded-lg p-4">
            <p class="text-sm font-medium text-firebase-accent mb-2">2) Android 앱 등록</p>
            <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                <li>프로젝트 개요 → Android 아이콘 클릭</li>
                <li>Android 패키지 이름 (예: <code class="text-yellow-400">com.example.app</code>)</li>
                <li>SHA-1 인증서 지문 입력 (선택)</li>
                <li><strong class="text-green-400">google-services.json</strong> 다운로드 → Step 4에서 업로드</li>
                <li>등록 후 좌측 하단 "톱니바퀴 → 프로젝트 설정"에서 <strong class="text-yellow-400">앱 ID</strong> (예: <code>1:905...:android:abc</code>) 복사 → Step 3에서 사용</li>
            </ol>
        </div>

        <div class="bg-slate-700/50 border border-slate-600 rounded-lg p-4">
            <p class="text-sm font-medium text-firebase-accent mb-2">3) App Distribution 활성화</p>
            <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                <li>좌측 메뉴 → "출시 및 모니터링" → "App Distribution"</li>
                <li>"시작하기" 클릭 → 활성화 완료</li>
            </ol>
        </div>

        <div class="bg-slate-700/50 border border-slate-600 rounded-lg p-4">
            <p class="text-sm font-medium text-firebase-accent mb-2">4) 테스터 그룹 생성</p>
            <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                <li>App Distribution → 상단 탭 "테스터 및 그룹"</li>
                <li>"새 그룹" 클릭 → 그룹명 입력 (예: <code class="text-yellow-400">romrom</code>) → Step 3에서 사용</li>
                <li>그룹에 테스터 이메일 추가</li>
            </ol>
        </div>
    </div>

    <div class="flex justify-between items-center mt-8">
        <span class="skip-btn" onclick="nextStep()">이미 다 했어요 →</span>
        <button class="px-6 py-2.5 bg-gradient-to-r from-firebase-primary to-firebase-accent text-slate-900 hover:opacity-90 rounded-lg font-medium transition" onclick="nextStep()">
            다음: Service Account →
        </button>
    </div>
</div>
```

- [ ] **Step 2: 브라우저 시각 확인**

Expected: Step 1에서 4개 sub 작업 카드가 명확히 표시되고 외부 링크 클릭 시 새 탭으로 Firebase Console 열림.

- [ ] **Step 3: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard.html
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : Step 1 UI Firebase Console 가이드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 7: Step 2 UI — Service Account 발급 + IAM 권한 부여

**Files:**
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.html` (Step 2 카드)

- [ ] **Step 1: Step 2 본문 작성** (Step 2 placeholder 부분 교체)

```html
<div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="2">
    <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
        <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">2</span>
        Service Account 발급 + 권한 부여
        <span class="text-xs font-normal text-firebase-accent bg-firebase-primary/20 px-2 py-1 rounded">중요</span>
    </h2>

    <div class="bg-firebase-primary/10 border border-firebase-primary/30 rounded-lg p-4 mb-6">
        <p class="text-sm text-firebase-accent">
            🔑 <strong>왜 필요한가?</strong> GitHub Actions가 Firebase에 빌드를 업로드하려면 인증이 필요합니다. Service Account JSON 키가 그 역할을 합니다.
        </p>
    </div>

    <div class="mb-4 flex flex-wrap gap-2">
        <a href="https://console.cloud.google.com/iam-admin/serviceaccounts" target="_blank" rel="noopener"
           class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-sm font-medium transition">
            Cloud Console — Service Accounts 열기
        </a>
        <a href="https://console.cloud.google.com/iam-admin/iam" target="_blank" rel="noopener"
           class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-sm font-medium transition">
            Cloud Console — IAM 열기
        </a>
    </div>

    <div class="space-y-4">
        <div class="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4">
            <p class="text-sm text-yellow-200 font-medium mb-2">1) Service Account 생성</p>
            <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                <li>위 "Service Accounts" 버튼 클릭</li>
                <li>상단 프로젝트 선택 → Firebase 프로젝트와 동일한 프로젝트인지 확인</li>
                <li>"+ 서비스 계정 만들기" 클릭</li>
                <li>이름: <code class="text-yellow-400">firebase-app-distribution-uploader</code> (예시)</li>
                <li>"만들고 계속하기" → 역할은 일단 비워도 OK → "완료"</li>
            </ol>
        </div>

        <div class="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4">
            <p class="text-sm text-yellow-200 font-medium mb-2">2) JSON 키 발급</p>
            <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                <li>방금 만든 Service Account 행 클릭</li>
                <li>상단 탭 "키" → "키 추가" → "새 키 만들기" → JSON 선택 → "만들기"</li>
                <li><strong class="text-green-400">JSON 파일이 자동 다운로드됨</strong> (Step 4에서 업로드)</li>
                <li class="pl-4 mt-2">
                    <div class="p-2 bg-slate-800/50 rounded border-l-4 border-red-500 text-red-300 text-[11px]">
                        ⚠️ 다운로드된 JSON은 <strong>매우 민감</strong>합니다. Git에 커밋하지 마세요. 저장 위치를 잘 기억해두세요.
                    </div>
                </li>
            </ol>
        </div>

        <div class="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4">
            <p class="text-sm text-yellow-200 font-medium mb-2">3) IAM 권한 부여</p>
            <ol class="text-xs text-slate-300 list-decimal list-inside space-y-1">
                <li>위 "IAM" 버튼 클릭</li>
                <li>방금 만든 Service Account 이메일 (<code>...@PROJECT.iam.gserviceaccount.com</code>) 행 우측 연필 아이콘 클릭</li>
                <li>"+ 다른 역할 추가" → 역할 검색 → <strong class="text-green-400">"Firebase App Distribution Admin"</strong> 선택</li>
                <li>"저장" → 권한 부여 완료</li>
            </ol>
        </div>

        <div class="bg-slate-700/50 border border-slate-600 rounded-lg p-4">
            <p class="text-sm font-medium text-blue-400 mb-2">✅ 검증 체크리스트</p>
            <div class="text-xs text-slate-300 space-y-1">
                <label class="flex items-center gap-2"><input type="checkbox" class="accent-firebase-primary"> Service Account 생성 완료</label>
                <label class="flex items-center gap-2"><input type="checkbox" class="accent-firebase-primary"> JSON 키 다운로드 완료 (저장 위치 확인)</label>
                <label class="flex items-center gap-2"><input type="checkbox" class="accent-firebase-primary"> "Firebase App Distribution Admin" 역할 부여 완료</label>
            </div>
        </div>
    </div>

    <div class="flex justify-between mt-8">
        <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
        <button class="px-6 py-2.5 bg-gradient-to-r from-firebase-primary to-firebase-accent text-slate-900 hover:opacity-90 rounded-lg font-medium transition" onclick="nextStep()">다음: 앱 정보 →</button>
    </div>
</div>
```

- [ ] **Step 2: 브라우저 시각 확인**
- [ ] **Step 3: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard.html
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : Step 2 UI Service Account 발급 + IAM 권한 가이드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 8: Step 3 UI + 로직 — APP_ID/TESTER_GROUP 입력 + setup 명령 OS별 탭

**Files:**
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.html` (Step 3 카드)
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.js` (Step 3 로직 추가)

- [ ] **Step 1: Step 3 본문 작성**

```html
<div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="3">
    <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
        <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">3</span>
        앱 정보 입력
    </h2>

    <div class="bg-firebase-primary/10 border border-firebase-primary/30 rounded-lg p-4 mb-6">
        <p class="text-sm text-firebase-accent">
            📋 Step 1에서 확인한 <strong>앱 ID</strong>와 <strong>테스터 그룹명</strong>을 입력하세요. 이 값들로 워크플로우 파일의 placeholder를 자동 치환합니다.
        </p>
    </div>

    <div class="space-y-4 mb-6">
        <div>
            <label class="block text-sm font-medium mb-2 text-slate-300">FIREBASE_APP_ID <span class="text-red-400">*</span></label>
            <input type="text" id="firebaseAppIdInput" placeholder="예: 1:905325245238:android:86db75164e0df29a1f3997"
                class="w-full bg-slate-900 border border-slate-600 rounded-lg px-4 py-2.5 text-sm font-mono focus:border-firebase-primary outline-none"
                oninput="onFirebaseAppIdChange(this.value)">
            <p class="text-xs text-slate-500 mt-1">Firebase Console → 프로젝트 설정 → 내 앱 → 앱 ID</p>
        </div>
        <div>
            <label class="block text-sm font-medium mb-2 text-slate-300">FIREBASE_TESTER_GROUP <span class="text-red-400">*</span></label>
            <input type="text" id="firebaseTesterGroupInput" placeholder="예: romrom"
                class="w-full bg-slate-900 border border-slate-600 rounded-lg px-4 py-2.5 text-sm font-mono focus:border-firebase-primary outline-none"
                oninput="onFirebaseTesterGroupChange(this.value)">
            <p class="text-xs text-slate-500 mt-1">App Distribution → 테스터 및 그룹 → 그룹명</p>
        </div>
        <div>
            <label class="block text-sm font-medium mb-2 text-slate-300">프로젝트 경로 (setup 스크립트 실행 위치)</label>
            <input type="text" id="projectPathInput" value="." placeholder="예: . 또는 /path/to/project"
                class="w-full bg-slate-900 border border-slate-600 rounded-lg px-4 py-2.5 text-sm font-mono focus:border-firebase-primary outline-none"
                oninput="onProjectPathChange(this.value)">
        </div>
    </div>

    <div class="bg-slate-700/50 border border-slate-600 rounded-lg p-4 mb-6">
        <p class="text-sm font-medium text-blue-400 mb-3">⚙️ 워크플로우 placeholder 자동 치환 명령</p>
        <p class="text-xs text-slate-400 mb-3">아래 명령을 OS에 맞게 복사 → 프로젝트 루트에서 실행하세요. setup 스크립트는 Step 5의 ZIP에 포함됩니다.</p>

        <div class="flex gap-2 mb-3">
            <button id="osTabBash" class="px-4 py-1.5 rounded text-xs font-medium bg-slate-900 border border-slate-600 hover:border-firebase-primary" onclick="selectOsTab('bash')">macOS / Linux</button>
            <button id="osTabPs" class="px-4 py-1.5 rounded text-xs font-medium bg-slate-900 border border-slate-600 hover:border-firebase-primary" onclick="selectOsTab('ps')">Windows</button>
        </div>

        <div id="osCmdBash" class="hidden">
            <pre class="bg-slate-900 rounded p-3 text-xs font-mono text-green-400 overflow-x-auto" id="cmdBashCode">./firebase-wizard-setup.sh --project-path . --app-id "" --tester-group ""</pre>
            <button class="mt-2 px-3 py-1 bg-firebase-primary text-slate-900 rounded text-xs hover:opacity-90" onclick="copyCode(this); this.previousElementSibling;">복사</button>
        </div>

        <div id="osCmdPs" class="hidden">
            <pre class="bg-slate-900 rounded p-3 text-xs font-mono text-green-400 overflow-x-auto" id="cmdPsCode">.\firebase-wizard-setup.ps1 -ProjectPath . -AppId "" -TesterGroup ""</pre>
            <button class="mt-2 px-3 py-1 bg-firebase-primary text-slate-900 rounded text-xs hover:opacity-90" onclick="copyCode(this); this.previousElementSibling;">복사</button>
        </div>
    </div>

    <div class="flex justify-between mt-8">
        <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
        <button class="px-6 py-2.5 bg-gradient-to-r from-firebase-primary to-firebase-accent text-slate-900 hover:opacity-90 rounded-lg font-medium transition" onclick="onStep3Next()">다음: 파일 업로드 →</button>
    </div>
</div>
```

- [ ] **Step 2: JS에 Step 3 로직 추가** (`firebase-wizard.js` 끝부분에 추가)

```javascript
// ============================================
// Step 3: APP_ID / TESTER_GROUP / OS Tab
// ============================================
function shellEscape(s) {
    return (s || '').replace(/"/g, '\\"');
}

function updateSetupCommands() {
    const path = state.projectPath || '.';
    const appId = shellEscape(state.firebaseAppId);
    const tester = shellEscape(state.firebaseTesterGroup);

    const bashCmd = `./firebase-wizard-setup.sh --project-path ${path} --app-id "${appId}" --tester-group "${tester}"`;
    const psPath = (path === '.') ? '.' : path.replace(/\//g, '\\');
    const psCmd = `.\\firebase-wizard-setup.ps1 -ProjectPath ${psPath} -AppId "${appId}" -TesterGroup "${tester}"`;

    const bashEl = document.getElementById('cmdBashCode');
    const psEl = document.getElementById('cmdPsCode');
    if (bashEl) bashEl.textContent = bashCmd;
    if (psEl) psEl.textContent = psCmd;
}

function selectOsTab(which) {
    const bash = document.getElementById('osCmdBash');
    const ps = document.getElementById('osCmdPs');
    const tabBash = document.getElementById('osTabBash');
    const tabPs = document.getElementById('osTabPs');
    if (which === 'bash') {
        bash.classList.remove('hidden');
        ps.classList.add('hidden');
        tabBash.classList.add('bg-firebase-primary', 'text-slate-900');
        tabPs.classList.remove('bg-firebase-primary', 'text-slate-900');
    } else {
        ps.classList.remove('hidden');
        bash.classList.add('hidden');
        tabPs.classList.add('bg-firebase-primary', 'text-slate-900');
        tabBash.classList.remove('bg-firebase-primary', 'text-slate-900');
    }
}

function onFirebaseAppIdChange(v) { state.firebaseAppId = v.trim(); updateSetupCommands(); saveState(); }
function onFirebaseTesterGroupChange(v) { state.firebaseTesterGroup = v.trim(); updateSetupCommands(); saveState(); }
function onProjectPathChange(v) { state.projectPath = v.trim() || '.'; updateSetupCommands(); saveState(); }

function onStep3Next() {
    if (!state.firebaseAppId) { showToast('⚠️ FIREBASE_APP_ID를 입력해주세요'); return; }
    if (!state.firebaseTesterGroup) { showToast('⚠️ FIREBASE_TESTER_GROUP을 입력해주세요'); return; }
    nextStep();
}

// Step 진입 시 OS 탭 자동 선택
const _origShowStep = showStep;
showStep = function (step) {
    _origShowStep(step);
    if (step === 3) {
        const inputs = {
            firebaseAppIdInput: state.firebaseAppId,
            firebaseTesterGroupInput: state.firebaseTesterGroup,
            projectPathInput: state.projectPath || '.'
        };
        Object.keys(inputs).forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = inputs[id];
        });
        updateSetupCommands();
        selectOsTab(state.detectedOS === 'windows' ? 'ps' : 'bash');
    }
};
```

- [ ] **Step 3: 브라우저 시각 확인**

Expected: Step 3에서 입력 시 명령 라인에 값이 즉시 반영, OS 탭 전환 정상, 새로고침해도 입력값 유지.

- [ ] **Step 4: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard.html .github/util/flutter/firebase-wizard/firebase-wizard.js
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : Step 3 UI 앱 정보 입력 + OS별 setup 명령 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 9: Step 4 UI + 로직 — 파일 업로드 (SA JSON, google-services.json)

**Files:**
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.html` (Step 4 카드)
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.js` (파일 업로드 로직 추가)

- [ ] **Step 1: Step 4 본문 작성** (Custom Secrets 섹션은 Task 10에서 추가)

```html
<div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="4">
    <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
        <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">4</span>
        파일 업로드 + 변환
    </h2>

    <div class="bg-firebase-primary/10 border border-firebase-primary/30 rounded-lg p-4 mb-6">
        <p class="text-sm text-firebase-accent">
            📦 Step 2에서 다운받은 <strong>Service Account JSON</strong>과 (선택) Step 1에서 받은 <strong>google-services.json</strong>을 업로드하세요. 모든 변환은 브라우저 내에서 수행되며 외부 서버로 전송되지 않습니다.
        </p>
    </div>

    <!-- Service Account JSON -->
    <div class="mb-6">
        <h3 class="text-base font-semibold mb-3 text-slate-200">🔑 Service Account JSON <span class="text-red-400">*</span></h3>
        <div class="file-upload" id="saUpload" onclick="document.getElementById('saInput').click()">
            <div class="icon">📄</div>
            <div class="text-slate-300" id="saUploadText">.json 파일을 드래그하거나 클릭하세요</div>
            <input type="file" id="saInput" accept=".json" class="hidden" onchange="handleServiceAccountUpload(event)">
            <div class="text-xs text-slate-500 mt-2" id="saInfo" style="display:none"></div>
        </div>
        <div id="saPreview" class="mt-3 hidden">
            <p class="text-xs text-slate-400 mb-1">base64 인코딩 결과 (앞 100자)</p>
            <pre class="bg-slate-900 rounded p-2 text-xs font-mono text-green-400 overflow-x-auto" id="saPreviewText"></pre>
        </div>
    </div>

    <!-- google-services.json -->
    <div class="mb-6">
        <h3 class="text-base font-semibold mb-3 text-slate-200">📱 google-services.json <span class="text-slate-500 text-sm font-normal">(선택)</span></h3>
        <div class="file-upload" id="gsUpload" onclick="document.getElementById('gsInput').click()">
            <div class="icon">📄</div>
            <div class="text-slate-300" id="gsUploadText">.json 파일을 드래그하거나 클릭하세요</div>
            <input type="file" id="gsInput" accept=".json" class="hidden" onchange="handleGoogleServicesUpload(event)">
            <div class="text-xs text-slate-500 mt-2" id="gsInfo" style="display:none"></div>
        </div>
    </div>

    <!-- Custom Secrets (Task 10에서 추가) -->
    <div id="customSecretsSection"></div>

    <div class="flex justify-between mt-8">
        <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
        <button class="px-6 py-2.5 bg-gradient-to-r from-firebase-primary to-firebase-accent text-slate-900 hover:opacity-90 rounded-lg font-medium transition" onclick="onStep4Next()">다음: Secrets 등록 →</button>
    </div>
</div>
```

- [ ] **Step 2: JS에 파일 업로드 로직 추가** (`firebase-wizard.js` 끝부분)

```javascript
// ============================================
// Step 4: File uploads
// ============================================
async function handleServiceAccountUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (!file.name.endsWith('.json')) {
        showToast('⚠️ .json 파일만 업로드 가능합니다');
        return;
    }
    try {
        const text = await fileToText(file);
        const parsed = JSON.parse(text);
        if (!parsed.client_email || !parsed.private_key) {
            showToast('⚠️ Service Account JSON 형식이 아닐 수 있습니다 (client_email/private_key 누락)');
        }
        const b64 = btoa(unescape(encodeURIComponent(text)));
        state.serviceAccountBase64 = b64;
        state.serviceAccountFileName = file.name;

        document.getElementById('saUploadText').textContent = `✅ ${file.name} (${(file.size/1024).toFixed(1)}KB)`;
        const info = document.getElementById('saInfo');
        info.style.display = 'block';
        info.textContent = `client_email: ${parsed.client_email || '(누락)'}`;
        const preview = document.getElementById('saPreview');
        preview.classList.remove('hidden');
        document.getElementById('saPreviewText').textContent = b64.substring(0, 100) + '...';
        saveState();
        showToast('✅ Service Account 업로드 완료');
    } catch (e) {
        showToast('❌ JSON 파싱 실패: ' + e.message);
    }
}

async function handleGoogleServicesUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (!file.name.endsWith('.json')) {
        showToast('⚠️ .json 파일만 업로드 가능합니다');
        return;
    }
    try {
        const text = await fileToText(file);
        JSON.parse(text); // 형식 검증
        state.googleServicesJson = text;
        state.googleServicesFileName = file.name;
        document.getElementById('gsUploadText').textContent = `✅ ${file.name} (${(file.size/1024).toFixed(1)}KB)`;
        const info = document.getElementById('gsInfo');
        info.style.display = 'block';
        info.textContent = `${file.size} bytes`;
        saveState();
        showToast('✅ google-services.json 업로드 완료');
    } catch (e) {
        showToast('❌ JSON 파싱 실패: ' + e.message);
    }
}

function setupDragAndDrop() {
    const targets = [
        { drop: 'saUpload', input: 'saInput', handler: handleServiceAccountUpload },
        { drop: 'gsUpload', input: 'gsInput', handler: handleGoogleServicesUpload }
    ];
    targets.forEach(({ drop, input, handler }) => {
        const el = document.getElementById(drop);
        if (!el) return;
        ['dragenter', 'dragover'].forEach(evt => el.addEventListener(evt, e => { e.preventDefault(); el.classList.add('dragover'); }));
        ['dragleave', 'drop'].forEach(evt => el.addEventListener(evt, e => { e.preventDefault(); el.classList.remove('dragover'); }));
        el.addEventListener('drop', e => {
            const file = e.dataTransfer.files[0];
            if (file) {
                const inp = document.getElementById(input);
                const dt = new DataTransfer();
                dt.items.add(file);
                inp.files = dt.files;
                handler({ target: inp });
            }
        });
    });
}

function onStep4Next() {
    if (!state.serviceAccountBase64) {
        showToast('⚠️ Service Account JSON을 업로드해주세요');
        return;
    }
    nextStep();
}

// Step 4 진입 시 setup
const _showStepStep4 = showStep;
showStep = function (step) {
    _showStepStep4(step);
    if (step === 4) {
        // 파일 정보 복원
        if (state.serviceAccountFileName) {
            const t = document.getElementById('saUploadText');
            if (t) t.textContent = `✅ ${state.serviceAccountFileName} (복원됨)`;
            const preview = document.getElementById('saPreview');
            if (preview) {
                preview.classList.remove('hidden');
                document.getElementById('saPreviewText').textContent = state.serviceAccountBase64.substring(0, 100) + '...';
            }
        }
        if (state.googleServicesFileName) {
            const t = document.getElementById('gsUploadText');
            if (t) t.textContent = `✅ ${state.googleServicesFileName} (복원됨)`;
        }
        setupDragAndDrop();
    }
};
```

- [ ] **Step 3: 브라우저 시각 확인**

Expected: Step 4에서 SA JSON 업로드 시 base64 변환 + 미리보기 표시, google-services 업로드 OK, 드래그 앤 드롭 동작.

- [ ] **Step 4: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard.html .github/util/flutter/firebase-wizard/firebase-wizard.js
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : Step 4 파일 업로드 + base64 변환 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 10: Step 4 확장 — Custom Secrets 섹션

**Files:**
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.js` (Custom Secrets 로직)
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.html` (Custom Secrets 섹션 마크업 — `customSecretsSection` 안에 동적 렌더)

PlayStore wizard JS의 custom secrets 관련 함수 차용:
- `addCustomSecret()`, `removeCustomSecret()`, `renderCustomSecrets()`, `handleCustomSecretFile()`
- 파일 타입 자동 판별 (텍스트 vs 바이너리), 바이너리는 `_BASE64` 접미사 자동 추가

- [ ] **Step 1: JS에 Custom Secrets 로직 추가** (`firebase-wizard.js` 끝부분)

```javascript
// ============================================
// Custom Secrets
// ============================================
const TEXT_EXTS = ['.txt', '.env', '.json', '.yaml', '.yml', '.md', '.properties', '.xml', '.ini', '.conf', '.cfg'];

function detectSecretType(filename) {
    const lower = (filename || '').toLowerCase();
    return TEXT_EXTS.some(ext => lower.endsWith(ext)) ? 'text' : 'binary';
}

function suggestSecretKey(filename, type) {
    const base = (filename || '').replace(/\.[^.]+$/, '').toUpperCase().replace(/[^A-Z0-9]/g, '_');
    return type === 'binary' ? `${base}_BASE64` : base;
}

function addCustomSecret() {
    state.customSecrets.push({ key: '', value: '', fileName: '', type: 'text' });
    saveState();
    renderCustomSecrets();
}

function removeCustomSecret(index) {
    state.customSecrets.splice(index, 1);
    saveState();
    renderCustomSecrets();
}

function updateCustomSecretKey(index, value) {
    state.customSecrets[index].key = value;
    saveState();
}

function updateCustomSecretValue(index, value) {
    state.customSecrets[index].value = value;
    state.customSecrets[index].type = 'text';
    state.customSecrets[index].fileName = '';
    saveState();
}

async function handleCustomSecretFile(index, event) {
    const file = event.target.files[0];
    if (!file) return;
    const type = detectSecretType(file.name);
    let value;
    if (type === 'text') {
        value = await fileToText(file);
    } else {
        value = await fileToBase64(file);
    }
    state.customSecrets[index].value = value;
    state.customSecrets[index].fileName = file.name;
    state.customSecrets[index].type = type;
    if (!state.customSecrets[index].key) {
        state.customSecrets[index].key = suggestSecretKey(file.name, type);
    }
    saveState();
    renderCustomSecrets();
    showToast(`✅ ${file.name} (${type})`);
}

function renderCustomSecrets() {
    const container = document.getElementById('customSecretsContent');
    if (!container) return;
    if (state.customSecrets.length === 0) {
        container.innerHTML = '<p class="text-xs text-slate-500 italic">추가된 항목이 없습니다.</p>';
        return;
    }
    container.innerHTML = state.customSecrets.map((s, i) => `
        <div class="bg-slate-900 border border-slate-700 rounded-lg p-3 mb-3">
            <div class="flex items-center gap-2 mb-2">
                <input type="text" placeholder="SECRET_KEY_NAME" value="${(s.key || '').replace(/"/g, '&quot;')}"
                    class="flex-1 bg-slate-950 border border-slate-700 rounded px-3 py-1.5 text-xs font-mono"
                    oninput="updateCustomSecretKey(${i}, this.value)">
                <span class="text-xs px-2 py-1 rounded ${s.type === 'binary' ? 'bg-purple-600/30 text-purple-300' : 'bg-blue-600/30 text-blue-300'}">${s.type}</span>
                <button class="text-red-400 hover:text-red-300 text-sm" onclick="removeCustomSecret(${i})">✕</button>
            </div>
            <div class="flex gap-2">
                <input type="file" id="csFile${i}" class="hidden" onchange="handleCustomSecretFile(${i}, event)">
                <button class="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 rounded text-xs" onclick="document.getElementById('csFile${i}').click()">
                    ${s.fileName ? `📎 ${s.fileName}` : '📁 파일 선택'}
                </button>
                <span class="text-xs text-slate-500 self-center">또는</span>
                <input type="text" placeholder="값 직접 입력" value="${s.fileName ? '' : (s.value || '').replace(/"/g, '&quot;').substring(0, 100)}"
                    class="flex-1 bg-slate-950 border border-slate-700 rounded px-3 py-1.5 text-xs font-mono"
                    oninput="updateCustomSecretValue(${i}, this.value)">
            </div>
        </div>
    `).join('');
}
```

- [ ] **Step 2: HTML에 Custom Secrets 섹션 렌더 컨테이너 정의** (`customSecretsSection` div 내부 채움)

`firebase-wizard.html`의 `<div id="customSecretsSection"></div>` 라인을 다음으로 교체:

```html
<div id="customSecretsSection" class="mb-6">
    <div class="flex items-center justify-between mb-3">
        <h3 class="text-base font-semibold text-slate-200">➕ 추가 Secrets <span class="text-slate-500 text-sm font-normal">(선택, 사용자 정의)</span></h3>
        <button class="px-3 py-1.5 bg-firebase-primary text-slate-900 rounded text-xs hover:opacity-90" onclick="addCustomSecret()">+ 항목 추가</button>
    </div>
    <p class="text-xs text-slate-500 mb-3">예: <code>ENV_FILE</code>, <code>FIREBASE_API_KEY</code> 등 워크플로우에서 참조하는 추가 secret. 텍스트 파일은 원본 그대로, 바이너리 파일은 자동 base64 변환됩니다.</p>
    <div id="customSecretsContent"></div>
</div>
```

- [ ] **Step 3: Step 4 진입 시 custom secrets 렌더 호출** (`showStep` step===4 분기에 `renderCustomSecrets()` 추가)

`firebase-wizard.js`의 Step 4 진입 분기에 다음 한 줄 추가 (이미 있는 `setupDragAndDrop()` 호출 직전):

```javascript
        renderCustomSecrets();
```

- [ ] **Step 4: 브라우저 시각 확인**

Expected: "+ 항목 추가" 클릭 시 카드 동적 추가, 파일 업로드 시 자동 key 제안, 텍스트/바이너리 자동 분류, 새로고침 시 복원.

- [ ] **Step 5: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard.html .github/util/flutter/firebase-wizard/firebase-wizard.js
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : Step 4 Custom Secrets 섹션 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 11: Step 5 UI + 로직 — Secret 키 매핑표, 복사, JSON/TXT/ZIP 다운로드

**Files:**
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.html` (Step 5 카드)
- Modify: `.github/util/flutter/firebase-wizard/firebase-wizard.js` (Secrets 렌더 + export 함수)

- [ ] **Step 1: Step 5 본문 작성**

```html
<div class="card bg-slate-800 rounded-xl shadow-xl p-6 mb-6 step-content hidden" data-step="5">
    <h2 class="text-xl font-bold mb-6 flex items-center gap-3">
        <span class="w-8 h-8 bg-firebase-primary rounded-lg flex items-center justify-center text-sm text-slate-900">5</span>
        GitHub Secrets 등록 + 다운로드
    </h2>

    <div class="bg-firebase-primary/10 border border-firebase-primary/30 rounded-lg p-4 mb-6">
        <p class="text-sm text-firebase-accent">
            🚀 <strong>거의 다 왔습니다!</strong> 아래 Secret들을 GitHub Repository Secrets에 등록하고, Step 3의 setup 명령을 실행하면 끝입니다.
        </p>
    </div>

    <!-- Repo 정보 입력 (선택) -->
    <div class="grid grid-cols-2 gap-3 mb-4">
        <input type="text" id="repoOwnerInput" placeholder="GitHub owner (예: Cassiiopeia)" value=""
            class="bg-slate-900 border border-slate-600 rounded-lg px-4 py-2 text-sm font-mono"
            oninput="onRepoOwnerChange(this.value)">
        <input type="text" id="repoNameInput" placeholder="레포 이름 (예: my-flutter-app)" value=""
            class="bg-slate-900 border border-slate-600 rounded-lg px-4 py-2 text-sm font-mono"
            oninput="onRepoNameChange(this.value)">
    </div>
    <div class="mb-6">
        <a id="secretsPageLink" href="https://github.com" target="_blank" rel="noopener"
           class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-sm font-medium transition">
            🔐 GitHub Secrets 페이지 열기
        </a>
        <p class="text-xs text-slate-500 mt-1">owner/repo를 입력하면 정확한 Secrets 페이지로 이동합니다. 입력값은 어디에도 저장·전송되지 않습니다.</p>
    </div>

    <!-- Secrets 매핑표 -->
    <div class="mb-6">
        <h3 class="text-base font-semibold mb-3 text-slate-200">🔑 등록할 GitHub Secrets</h3>
        <table class="w-full text-xs">
            <thead>
                <tr class="border-b border-slate-700 text-slate-400">
                    <th class="text-left py-2 px-2">Secret 이름</th>
                    <th class="text-left py-2 px-2">출처</th>
                    <th class="text-left py-2 px-2">크기</th>
                    <th class="text-right py-2 px-2">동작</th>
                </tr>
            </thead>
            <tbody id="secretsTableBody"></tbody>
        </table>
    </div>

    <!-- 다운로드 버튼 -->
    <div class="bg-slate-700/50 border border-slate-600 rounded-lg p-4 mb-6">
        <p class="text-sm font-medium text-blue-400 mb-3">📥 산출물 다운로드</p>
        <div class="flex flex-wrap gap-2">
            <button class="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded text-xs" onclick="exportJson()">📋 JSON</button>
            <button class="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded text-xs" onclick="exportTxt()">📝 TXT</button>
            <button class="px-4 py-2 bg-firebase-primary text-slate-900 hover:opacity-90 rounded text-xs font-bold" onclick="exportZip()">📦 ZIP (setup 스크립트 포함, 권장)</button>
        </div>
    </div>

    <div class="flex justify-between mt-8">
        <button class="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition" onclick="prevStep()">← 이전</button>
        <button class="px-6 py-2.5 bg-green-600 hover:bg-green-700 rounded-lg font-medium transition" onclick="resetWizard()">처음부터 다시</button>
    </div>
</div>
```

- [ ] **Step 2: JS에 Secrets 렌더 + export 함수 추가**

```javascript
// ============================================
// Step 5: Secrets table + Export
// ============================================
function getDateString() {
    const d = new Date();
    return `${d.getFullYear()}${String(d.getMonth()+1).padStart(2,'0')}${String(d.getDate()).padStart(2,'0')}`;
}

function buildSecretsArray() {
    const list = [];
    if (state.serviceAccountBase64) {
        list.push({ key: 'FIREBASE_SERVICE_ACCOUNT_JSON_BASE64', value: state.serviceAccountBase64, source: 'Service Account JSON', type: 'binary' });
    }
    if (state.googleServicesJson) {
        list.push({ key: 'GOOGLE_SERVICES_JSON', value: state.googleServicesJson, source: 'google-services.json', type: 'text' });
    }
    state.customSecrets.forEach(s => {
        if (s.key && s.value) {
            list.push({ key: s.key, value: s.value, source: s.fileName || '직접 입력', type: s.type });
        }
    });
    return list;
}

function renderSecretsTable() {
    const tbody = document.getElementById('secretsTableBody');
    if (!tbody) return;
    const list = buildSecretsArray();
    if (list.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" class="py-3 text-center text-slate-500 italic">등록할 Secret이 없습니다. Step 4를 먼저 완료해주세요.</td></tr>';
        return;
    }
    tbody.innerHTML = list.map(s => `
        <tr class="border-b border-slate-700/50 hover:bg-slate-700/30">
            <td class="py-2 px-2 font-mono text-yellow-400">${s.key}</td>
            <td class="py-2 px-2 text-slate-400">${s.source}</td>
            <td class="py-2 px-2 text-slate-400">${(s.value.length / 1024).toFixed(1)} KB</td>
            <td class="py-2 px-2 text-right">
                <button class="px-3 py-1 bg-firebase-primary text-slate-900 rounded text-xs hover:opacity-90" onclick="copySecretValue('${s.key.replace(/'/g, "\\'")}')">복사</button>
            </td>
        </tr>
    `).join('');
}

function copySecretValue(key) {
    const list = buildSecretsArray();
    const item = list.find(x => x.key === key);
    if (!item) { showToast('⚠️ 항목을 찾을 수 없습니다'); return; }
    copyToClipboard(item.value);
    showToast(`✅ ${key} 복사됨`);
}

function onRepoOwnerChange(v) {
    state.repoOwner = v.trim();
    saveState();
    updateSecretsPageLink();
}

function onRepoNameChange(v) {
    state.repoName = v.trim();
    saveState();
    updateSecretsPageLink();
}

function updateSecretsPageLink() {
    const link = document.getElementById('secretsPageLink');
    if (!link) return;
    if (state.repoOwner && state.repoName) {
        link.href = `https://github.com/${state.repoOwner}/${state.repoName}/settings/secrets/actions`;
    } else {
        link.href = 'https://github.com';
    }
}

function exportJson() {
    const list = buildSecretsArray();
    if (list.length === 0) { showToast('⚠️ 등록할 Secret이 없습니다'); return; }
    const out = {};
    list.forEach(s => { out[s.key] = s.value; });
    const blob = new Blob([JSON.stringify(out, null, 2)], { type: 'application/json' });
    triggerDownload(blob, `firebase-secrets-${state.firebaseAppId.slice(0,12) || 'app'}-${getDateString()}.json`);
    showToast('✅ JSON 다운로드');
}

function exportTxt() {
    const list = buildSecretsArray();
    if (list.length === 0) { showToast('⚠️ 등록할 Secret이 없습니다'); return; }
    const lines = list.map(s => `=== ${s.key} ===\n${s.value}\n`);
    const blob = new Blob([lines.join('\n')], { type: 'text/plain' });
    triggerDownload(blob, `firebase-secrets-${state.firebaseAppId.slice(0,12) || 'app'}-${getDateString()}.txt`);
    showToast('✅ TXT 다운로드');
}

async function exportZip() {
    const list = buildSecretsArray();
    if (list.length === 0) { showToast('⚠️ 등록할 Secret이 없습니다'); return; }
    if (typeof JSZip === 'undefined') { showToast('❌ JSZip 라이브러리 로드 실패'); return; }

    const zip = new JSZip();
    const folder = zip.folder('github-secrets');
    list.forEach(s => folder.file(`${s.key}.txt`, s.value));

    // setup 스크립트 (CDN 직접 fetch 시도, 실패 시 안내 README만)
    const wizardBaseUrl = 'https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/.github/util/flutter/firebase-wizard';
    try {
        const [shResp, ps1Resp] = await Promise.all([
            fetch(`${wizardBaseUrl}/firebase-wizard-setup.sh`).then(r => r.ok ? r.text() : null),
            fetch(`${wizardBaseUrl}/firebase-wizard-setup.ps1`).then(r => r.ok ? r.text() : null)
        ]);
        if (shResp) zip.file('firebase-wizard-setup.sh', shResp);
        if (ps1Resp) zip.file('firebase-wizard-setup.ps1', ps1Resp);
    } catch (e) {
        console.warn('setup 스크립트 fetch 실패:', e);
    }

    const readme = `# Firebase App Distribution Secrets 패키지

생성 시각: ${new Date().toISOString()}
앱 ID: ${state.firebaseAppId || '(미입력)'}
테스터 그룹: ${state.firebaseTesterGroup || '(미입력)'}

## 폴더 구조

- github-secrets/         GitHub Repository Secrets에 등록할 값 파일들
- firebase-wizard-setup.sh   워크플로우 placeholder 안전 치환 (bash)
- firebase-wizard-setup.ps1  동일 동작 (PowerShell)

## 등록 절차

1. https://github.com/<owner>/<repo>/settings/secrets/actions 접속
2. github-secrets/ 폴더의 각 파일명을 Secret 이름으로 사용
3. 파일 내용을 Secret 값으로 붙여넣기

## setup 스크립트 실행 (워크플로우 placeholder 치환)

### macOS / Linux
\`\`\`bash
chmod +x firebase-wizard-setup.sh
./firebase-wizard-setup.sh \\
  --project-path /path/to/project \\
  --app-id "${state.firebaseAppId}" \\
  --tester-group "${state.firebaseTesterGroup}"
\`\`\`

### Windows (PowerShell)
\`\`\`powershell
.\\firebase-wizard-setup.ps1 \`
  -ProjectPath C:\\path\\to\\project \`
  -AppId "${state.firebaseAppId}" \`
  -TesterGroup "${state.firebaseTesterGroup}"
\`\`\`

## 옵션

- --dry-run / -DryRun           실제 변경 없이 미리보기
- --non-interactive / -NonInteractive  충돌 시 자동 SKIP
- --no-backup / -NoBackup       백업 파일 생성 비활성화
`;
    zip.file('README.md', readme);

    const blob = await zip.generateAsync({ type: 'blob' });
    triggerDownload(blob, `firebase-setup-${state.firebaseAppId.slice(0,12) || 'app'}-${getDateString()}.zip`);
    showToast('✅ ZIP 다운로드');
}

function triggerDownload(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

// Step 5 진입 시 렌더
const _showStepStep5 = showStep;
showStep = function (step) {
    _showStepStep5(step);
    if (step === 5) {
        const r1 = document.getElementById('repoOwnerInput'); if (r1) r1.value = state.repoOwner || '';
        const r2 = document.getElementById('repoNameInput'); if (r2) r2.value = state.repoName || '';
        renderSecretsTable();
        updateSecretsPageLink();
    }
};
```

- [ ] **Step 3: 브라우저 검증**

Expected:
- Step 5에서 secrets 표 정상 표시
- "복사" 버튼으로 각 Secret 값 클립보드 복사
- JSON/TXT 다운로드 정상
- ZIP 다운로드 시 setup 스크립트 fetch 시도 (origin 다르면 CORS 실패 가능 — 로컬에서는 README만 포함됨)
- owner/repo 입력 시 GitHub Secrets 페이지 링크 동적 갱신

- [ ] **Step 4: 커밋**

```bash
git add .github/util/flutter/firebase-wizard/firebase-wizard.html .github/util/flutter/firebase-wizard/firebase-wizard.js
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : feat : Step 5 Secrets 매핑표 + JSON/TXT/ZIP 다운로드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

---

## Task 12: 통합 검증 — 전체 흐름 + ZIP 안의 setup 스크립트 동작 확인

**Files:** (변경 없음, 통합 테스트만)

- [ ] **Step 1: 브라우저에서 5단계 전체 통과 시나리오**

1. Step 1 → "이미 다 했어요" 또는 "다음"
2. Step 2 → "다음"
3. Step 3 → APP_ID `1:111:android:test`, TESTER `qa`, projectPath `.` 입력 → "다음"
4. Step 4 → 임의의 SA JSON 파일(테스트용 가짜 JSON `{"client_email":"x","private_key":"y"}` 작성)과 google-services.json 업로드 → Custom Secret 1개 추가 (key=`ENV_FILE`, 텍스트 `KEY=VAL`) → "다음"
5. Step 5 → owner/repo 입력 (Cassiiopeia/SUH-DEVOPS-TEMPLATE) → 링크 갱신 확인 → JSON 다운로드 → TXT 다운로드 → ZIP 다운로드

Expected: 다운로드 3개 모두 정상, ZIP 안에 `github-secrets/`, `README.md`, (CORS 허용 시) setup 스크립트 포함.

- [ ] **Step 2: bash 테스트 재실행 (regression check)**

```bash
.github/util/flutter/firebase-wizard/test/setup-script-test.sh
```

Expected: PASS 11+, FAIL 0.

- [ ] **Step 3: PowerShell 테스트 재실행**

```powershell
powershell -ExecutionPolicy Bypass -File .github/util/flutter/firebase-wizard/test/setup-script-test.ps1
```

Expected: PASS 11+, FAIL 0.

- [ ] **Step 4: localStorage 초기화 후 신규 사용자 시뮬레이션**

브라우저 개발자도구 → Application → Local Storage → `firebase_wizard_state` 삭제 → 페이지 새로고침 → Step 1부터 다시 시작 가능 확인.

- [ ] **Step 5: version-sync.sh 최종 동작 확인**

```bash
.github/util/flutter/firebase-wizard/version-sync.sh
git diff .github/util/flutter/firebase-wizard/firebase-wizard.html | head -30
```

Expected: `<script id="versionJson">` 블록만 변경 (혹은 변경 없음).

- [ ] **Step 6: 커밋 (변경이 있을 경우)**

```bash
git add -A .github/util/flutter/firebase-wizard/
git diff --cached --stat
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : test : 통합 검증 회귀 테스트 통과 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295" || echo "변경 없음"
```

---

## Task 13: 문서 업데이트 (CLAUDE.md, README, 워크플로우 헤더 주석)

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` (헤더 주석에 wizard 안내)
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` (헤더 주석에 wizard 안내)

- [ ] **Step 1: `CLAUDE.md`의 `.github/util/flutter/` 섹션에 wizard 추가**

`CLAUDE.md`의 폴더 구조 섹션을 찾아 다음과 같이 보강:

```markdown
│   ├── util/flutter/
│   │   ├── playstore-wizard/
│   │   ├── testflight-wizard/
│   │   └── firebase-wizard/        ← 추가
```

- [ ] **Step 2: `README.md`에 wizard 섹션 추가** (PlayStore/TestFlight wizard 옆)

`README.md`에서 wizard 관련 섹션을 찾아 firebase-wizard 한 줄 추가:

```markdown
| 마법사 | 용도 | 위치 |
|---|---|---|
| Play Store | Play Store 자동 배포 설정 | `.github/util/flutter/playstore-wizard/playstore-wizard.html` |
| TestFlight | TestFlight 자동 배포 설정 | `.github/util/flutter/testflight-wizard/testflight-wizard.html` |
| Firebase App Distribution | Android 테스트 빌드 자동 배포 설정 | `.github/util/flutter/firebase-wizard/firebase-wizard.html` |
```

- [ ] **Step 3: `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` 헤더 주석에 wizard 안내**

```yaml
# 🪄 빠른 설정: .github/util/flutter/firebase-wizard/firebase-wizard.html을
#    브라우저에서 열어 5단계 마법사로 Firebase 배포를 자동 설정할 수 있습니다.
```

위 라인을 `# Firebase App Distribution 연동` 주석 직후에 추가.

- [ ] **Step 4: `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` 헤더 주석에 동일 안내 추가**

- [ ] **Step 5: 커밋**

```bash
git add CLAUDE.md README.md .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml .github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml
git commit -m "Firebase App Distribution 설정 마법사 firebase-wizard 추가 : docs : CLAUDE.md/README/워크플로우 헤더에 wizard 안내 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295"
```

- [ ] **Step 6: 이슈 #295 댓글 + 라벨 작업완료 변경**

```powershell
$h = @{ Authorization = "token <PAT>"; "User-Agent" = "claude-code"; "Content-Type" = "application/json; charset=utf-8" }
$comment = "## 작업 완료`n`n5단계 마법사 + bash/PowerShell setup 스크립트 + 통합 테스트 완료.`n- HTML/JS 마법사: ``.github/util/flutter/firebase-wizard/firebase-wizard.html```n- 안전 치환 setup: bash/PowerShell 양쪽 지원, 시나리오 11개 PASS`n- 문서: CLAUDE.md/README/워크플로우 헤더에 wizard 안내 추가"
$payload = @{ body = $comment } | ConvertTo-Json
Invoke-RestMethod -Uri "https://api.github.com/repos/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295/comments" -Headers $h -Method POST -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))

$labelPayload = @{ labels = @("작업완료") } | ConvertTo-Json
Invoke-RestMethod -Uri "https://api.github.com/repos/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/295" -Headers $h -Method PATCH -Body ([System.Text.Encoding]::UTF8.GetBytes($labelPayload))
```

(PAT는 `~/.suh-template/config/config.json`의 `global_pat` 사용)

---

## Self-Review

### 1. Spec Coverage Check

Spec 섹션별 task 매핑:

| Spec 섹션 | 구현 task |
|---|---|
| §4.1 파일 구조 | Task 1, 2, 3, 4, 5 (모든 파일 작성) |
| §4.2 컴포넌트 책임 | Task 4(HTML), 5(JS 인프라), 2/3(setup), 1(version) |
| §4.3 데이터 흐름 | Task 8 (state→setup cmd), 11 (state→download) |
| §5 Step 1 (Console 가이드) | Task 6 |
| §5 Step 2 (SA + IAM) | Task 7 |
| §5 Step 3 (앱 정보 + setup 명령 OS탭) | Task 8 |
| §5 Step 4 (파일 업로드 + base64 + custom secrets) | Task 9, 10 |
| §5 Step 5 (Secrets 매핑표 + JSON/TXT/ZIP) | Task 11 |
| §6.1 setup 스크립트 인터페이스 | Task 2 (bash), Task 3 (ps1) |
| §6.2 처리 흐름 (라인 단위, placeholder/같은값/충돌 분기) | Task 2 (구현), 시나리오 1~10 (테스트) |
| §6.3 안전장치 (들여쓰기·BOM·백업·dry-run·non-interactive) | Task 2 (시나리오 5,6,7,9,10) |
| §7 version.json 스키마 | Task 1 |
| §8 에러 처리 | Task 2 (workflows 폴더 없음, 권한 등), Task 9 (JSON 파싱 실패) |
| §9.1 setup 스크립트 테스트 | Task 2/3 시나리오 11개 |
| §9.2 HTML 수동 테스트 | Task 12 |
| §9.3 통합 테스트 | Task 12 |
| §10 마이그레이션·호환성 | (코드 변경 없음, spec 결정) |
| §12 결정 기록 | (구현 task로 모두 반영됨) |

**누락 없음.**

### 2. Placeholder Scan

- "TBD/TODO/implement later": 0개 (Task 4의 "Step N에서 작성" 메모는 후속 task 참조 — 의도된 marker)
- "Add appropriate error handling": 없음 (모든 에러 처리는 구체적 시나리오로 명시)
- "Similar to Task N": 없음 (각 task에서 코드 전체 표기)

### 3. Type/Naming Consistency

- `state.firebaseAppId`, `state.firebaseTesterGroup`, `state.serviceAccountBase64` — 모든 task에서 동일 명명
- 함수명: `nextStep`, `prevStep`, `goToStep`, `showStep`, `resetWizard`, `saveState`, `loadState`, `clearState`, `showToast`, `copyToClipboard`, `copyCode`, `copySecret`, `copySecretValue` — 일관됨
- setup 스크립트 인자: `--project-path`, `--app-id`, `--tester-group`, `--dry-run`, `--non-interactive`, `--no-backup` (bash) / `-ProjectPath`, `-AppId`, `-TesterGroup`, `-DryRun`, `-NonInteractive`, `-NoBackup` (PS) — 일관됨
- DOM ID: `firebaseAppIdInput`, `firebaseTesterGroupInput`, `projectPathInput`, `repoOwnerInput`, `repoNameInput`, `saInput`, `gsInput`, `osCmdBash`, `osCmdPs`, `cmdBashCode`, `cmdPsCode`, `secretsTableBody`, `customSecretsContent`, `customSecretsSection` — 모두 일치

**불일치 없음.**

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-14-firebase-wizard.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - 매 task마다 새 subagent 디스패치, task 사이 리뷰. 빠른 반복.
**2. Inline Execution** - 현재 세션에서 실행, 체크포인트로 일괄 진행.

**Which approach?**
