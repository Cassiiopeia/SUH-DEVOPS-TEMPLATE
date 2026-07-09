# scripts/tests/test_config.py
"""config 경로·PAT·이주 마이그레이션 단위 테스트 (#459 네임스페이스 중립화)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from common import config  # noqa: E402


def test_config_path_is_projectops(monkeypatch, tmp_path):
    """신 경로는 ~/.projectops/config/config.json 이다 (구 .suh-template 아님)."""
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path))
    p = config.config_path()
    assert p == tmp_path / ".projectops" / "config" / "config.json"


def test_config_path_migrates_from_suh_template(monkeypatch, tmp_path):
    """신 경로가 없고 구 ~/.suh-template config가 있으면 자동 이주(복사)한다 — 기존 사용자 무손실."""
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path))
    old = tmp_path / ".suh-template" / "config" / "config.json"
    old.parent.mkdir(parents=True, exist_ok=True)
    old.write_text(json.dumps({"github": {"global_pat": "ghp_x"}}), encoding="utf-8")

    p = config.config_path()

    # 신 경로로 복사됐고, 구 파일은 롤백 대비 남아 있다.
    assert p.exists()
    assert json.loads(p.read_text(encoding="utf-8"))["github"]["global_pat"] == "ghp_x"
    assert old.exists()


def test_config_path_no_overwrite_when_new_exists(monkeypatch, tmp_path):
    """신 경로가 이미 있으면 구 경로 내용으로 덮어쓰지 않는다."""
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path))
    new = tmp_path / ".projectops" / "config" / "config.json"
    new.parent.mkdir(parents=True, exist_ok=True)
    new.write_text(json.dumps({"github": {"global_pat": "NEW"}}), encoding="utf-8")
    old = tmp_path / ".suh-template" / "config" / "config.json"
    old.parent.mkdir(parents=True, exist_ok=True)
    old.write_text(json.dumps({"github": {"global_pat": "OLD"}}), encoding="utf-8")

    p = config.config_path()

    assert json.loads(p.read_text(encoding="utf-8"))["github"]["global_pat"] == "NEW"


def test_load_and_get_github_pat(monkeypatch, tmp_path):
    """load + get_github_pat 기본 동작 (global_pat 폴백, repo별 우선)."""
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path))
    new = tmp_path / ".projectops" / "config" / "config.json"
    new.parent.mkdir(parents=True, exist_ok=True)
    new.write_text(json.dumps({
        "github": {
            "global_pat": "ghp_global",
            "repos": [{"owner": "o", "repo": "r", "pat": "ghp_repo"}],
        }
    }), encoding="utf-8")

    assert config.get_github_pat() == "ghp_global"
    assert config.get_github_pat("o", "r") == "ghp_repo"
    assert config.get_github_pat("x", "y") == "ghp_global"


def test_load_none_when_missing(monkeypatch, tmp_path):
    """config 파일이 없으면 load()는 None."""
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path))
    assert config.load() is None
