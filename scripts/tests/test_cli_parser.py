# scripts/tests/test_cli_parser.py
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402


def _build_sample_parser():
    parser = JSONArgumentParser(prog="sample_cli")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("do-thing")
    p.add_argument("arg1")
    p.set_defaults(func=lambda args: 0)
    return parser


def test_unrecognized_arguments_emits_json(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, ["do-thing", "x", "extra1", "extra2"])
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "bad_args"
    assert "unrecognized" in out["error"].lower() or "extra" in out["error"].lower()
    assert "hint" in out
    assert "do-thing" in out["hint"]


def test_missing_required_argument_emits_json(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, ["do-thing"])
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "bad_args"
    assert "arg1" in out["error"]


def test_unknown_subcommand_emits_json(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, ["nonexistent-sub"])
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "bad_args"


def test_no_subcommand_emits_json(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, [])
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "bad_args"
    assert "available_subcommands" in out
    assert "do-thing" in out["available_subcommands"]


def test_help_flag_does_not_emit_failure_json(capsys):
    parser = _build_sample_parser()
    try:
        run_cli(parser, ["--help"])
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert "usage" in (captured.out + captured.err).lower()


def test_success_path_unaffected(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, ["do-thing", "value"])
    assert rc == 0
