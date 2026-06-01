"""common.emit 단위 테스트."""
import json
import subprocess
import sys
from pathlib import Path

_PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_PROJECT_ROOT / "scripts"))

from common.emit import emit  # noqa: E402


def test_emit_success_default_fields(capsys):
    rc = emit({"data": "hello"})
    out = capsys.readouterr().out
    parsed = json.loads(out)
    assert rc == 0
    assert parsed["ok"] is True
    assert parsed["code"] == "ok"
    assert parsed["summary"] is None
    assert parsed["next"] is None
    assert parsed["data"] == "hello"


def test_emit_error_returns_nonzero(capsys):
    rc = emit({"ok": False, "code": "missing_pat", "error": "no PAT"})
    out = capsys.readouterr().out
    parsed = json.loads(out)
    assert rc == 1
    assert parsed["ok"] is False
    assert parsed["code"] == "missing_pat"
    assert parsed["error"] == "no PAT"


def test_emit_preserves_custom_summary_and_next(capsys):
    emit({"summary": "PR #123 생성", "next": "deploy-status owner repo --pr 123"})
    out = capsys.readouterr().out
    parsed = json.loads(out)
    assert parsed["summary"] == "PR #123 생성"
    assert parsed["next"] == "deploy-status owner repo --pr 123"


def test_emit_handles_korean_no_ascii_escape(capsys):
    emit({"summary": "한글 메시지"})
    out = capsys.readouterr().out
    assert "한글 메시지" in out
    assert "\\u" not in out
