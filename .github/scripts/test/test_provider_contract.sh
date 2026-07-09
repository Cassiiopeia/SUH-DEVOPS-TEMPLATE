#!/bin/bash
# provider 계약 통합 테스트 (#455) — 어떤 provider가 만든 pr_body.md든
# changelog_manager.py update-from-summary가 파싱해 CHANGELOG.json을 갱신함을 검증한다.
# 이 계약이 지켜지면 워크플로우 본체는 provider를 몰라도 되고 automerge 파이프라인이 무손상.
#
# macOS bash 3.2 호환. /bin/bash로 실행.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
COMMIT_SH="$HERE/../changelog_providers/commit.sh"
MANAGER="$ROOT/.github/scripts/changelog_manager.py"
PYTHON=$(command -v python3 || command -v python)

FAIL=0
TMP=$(mktemp -d)
cd "$TMP" || exit 1

# 1) commit provider로 pr_body.md 생성 (git 레포 구성)
git init -q && git config user.email t@t && git config user.name t
git commit -q --allow-empty -m "feat: 신규 기능 추가"
git commit -q --allow-empty -m "fix: 버그 수정 #99"
git branch -M main
git checkout -q -b develop
git commit -q --allow-empty -m "docs: 문서 갱신"

COMMIT_RANGE="origin/nonexistent..HEAD" bash "$COMMIT_SH" > /dev/null \
  || { echo "FAIL: commit.sh 실행 실패"; FAIL=1; }
[ -f pr_body.md ] || { echo "FAIL: pr_body.md 미생성"; FAIL=1; }

# 2) changelog_manager가 이 pr_body.md를 파싱해 CHANGELOG.json을 갱신하는지
#    (VERSION 등 필수 환경변수 주입 — 실제 워크플로우와 동일 계약)
#    실제 스키마: {"metadata": {...}, "releases": [...]}
echo '{"metadata": {}, "releases": []}' > CHANGELOG.json
VERSION="9.9.9" PROJECT_TYPE="basic" PROJECT_TYPES="basic" \
  TODAY="20260709" PR_NUMBER="1" TIMESTAMP="2026-07-09 00:00:00" \
  PYTHONIOENCODING=utf-8 "$PYTHON" "$MANAGER" update-from-summary > /tmp/_pc_out.txt 2>&1 \
  || { echo "FAIL: update-from-summary 실패"; cat /tmp/_pc_out.txt; FAIL=1; }

# 3) CHANGELOG.json releases에 9.9.9가 parsed_changes와 함께 들어갔는지
"$PYTHON" - <<PYEOF || { echo "FAIL: CHANGELOG.json 검증 실패"; FAIL=1; }
import json, sys
d = json.load(open("CHANGELOG.json"))
rs = d.get("releases", [])
hit = [v for v in rs if v.get("version") == "9.9.9"]
if not hit:
    print("  9.9.9 릴리스 미기록"); sys.exit(1)
pc = hit[0].get("parsed_changes") or hit[0].get("changes")
if not pc:
    print("  parsed_changes 비어있음"); sys.exit(1)
sys.exit(0)
PYEOF

cd / && rm -rf "$TMP" /tmp/_pc_out.txt
[ "$FAIL" -eq 0 ] && echo "PASS" || { echo "FAILED"; exit 1; }
