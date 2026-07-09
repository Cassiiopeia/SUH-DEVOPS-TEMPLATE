# scripts/tests/test_changelog_resolve_body_file.py
"""_resolve_body_file 경로 해석 단위 테스트 — 홈 tmp 후보 추가 검증."""
import importlib.util
import sys
from pathlib import Path

# 이 파일: <root>/scripts/tests/ → parents[2] == <root>
# changelog_cli.py: <root>/skills/changelog-deploy/scripts/changelog_cli.py
_ROOT = Path(__file__).resolve().parents[2]
_CLI_PATH = _ROOT / "skills" / "changelog-deploy" / "scripts" / "changelog_cli.py"
_spec = importlib.util.spec_from_file_location("changelog_cli", _CLI_PATH)
changelog_cli = importlib.util.module_from_spec(_spec)
sys.modules["changelog_cli"] = changelog_cli
_spec.loader.exec_module(changelog_cli)

_resolve = changelog_cli._resolve_body_file


def test_absolute_path_returned_as_is(tmp_path):
    f = tmp_path / "owner__repo__release_notes.md"
    f.write_text("note", encoding="utf-8")
    assert _resolve(str(f)) == f


def test_absolute_path_missing_returns_none(tmp_path):
    f = tmp_path / "nope.md"
    assert _resolve(str(f)) is None


def test_relative_name_found_in_home_tmp(monkeypatch, tmp_path):
    # HOME을 tmp_path로 바꿔 ~/.projectops/tmp/ 를 격리 검증 (신 경로 — #459 이주)
    fake_home = tmp_path
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: fake_home))
    notes_dir = fake_home / ".projectops" / "tmp"
    notes_dir.mkdir(parents=True)
    target = notes_dir / "owner__repo__release_notes.md"
    target.write_text("note", encoding="utf-8")
    # 상대경로(파일명만) 입력 → 홈 tmp에서 발견되어야 함
    assert _resolve("owner__repo__release_notes.md") == target


def test_relative_name_found_in_legacy_suh_template_tmp(monkeypatch, tmp_path):
    # 구 ~/.suh-template/tmp/ 도 과도기 폴백 후보로 여전히 발견되어야 함 (#459)
    fake_home = tmp_path
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: fake_home))
    notes_dir = fake_home / ".suh-template" / "tmp"
    notes_dir.mkdir(parents=True)
    target = notes_dir / "owner__repo__release_notes.md"
    target.write_text("note", encoding="utf-8")
    assert _resolve("owner__repo__release_notes.md") == target


def test_none_input_returns_none():
    assert _resolve(None) is None
    assert _resolve("") is None
