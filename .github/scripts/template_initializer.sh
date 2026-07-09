#!/bin/bash
# ===================================================================
# template_initializer.sh — Python 위임 shim (v4.2, 이슈 #448)
# ===================================================================
#
# 로직은 template_initializer.py(크로스 플랫폼, stdlib 전용)로 이전되었다.
# 이 파일은 기존 워크플로우(PROJECT-TEMPLATE-INITIALIZER)의 호출 계약을
# 보존하는 위임 shim이다:
#   ./.github/scripts/template_initializer.sh --version 1.0.0 --type spring
# ===================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON_BIN=""
for _py in python3 python; do
    _path=$(command -v "$_py" 2>/dev/null) || continue
    if "$_path" -c "import sys; sys.exit(0)" 2>/dev/null; then
        PYTHON_BIN="$_path"
        break
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo "❌ Python(3.x)이 필요합니다. template_initializer는 v4.2부터 Python으로 동작합니다." >&2
    echo "   GitHub Actions ubuntu-latest에는 기본 설치되어 있습니다." >&2
    exit 1
fi

PYTHONIOENCODING=utf-8 exec "$PYTHON_BIN" "$SCRIPT_DIR/template_initializer.py" "$@"
