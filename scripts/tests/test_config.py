import sys
import json
import importlib
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import suh_template.config as cfg


def _write_config(home: Path, data: dict) -> Path:
    """home/.suh-template/config/config.json 에 config를 쓴다."""
    config_dir = home / ".suh-template" / "config"
    config_dir.mkdir(parents=True, exist_ok=True)
    path = config_dir / "config.json"
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return path


def test_load_existing_config(tmp_path, monkeypatch):
    _write_config(tmp_path, {"github": {"global_pat": "ghp_x"}})
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    assert cfg.load() == {"github": {"global_pat": "ghp_x"}}


def test_load_missing_config(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    assert cfg.load() is None


def test_get_section(tmp_path, monkeypatch):
    _write_config(tmp_path, {"github": {"global_pat": "ghp_x"}, "ssh": {"instances": []}})
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    assert cfg.get_section("github") == {"global_pat": "ghp_x"}
    assert cfg.get_section("ssh") == {"instances": []}
    assert cfg.get_section("nonexistent") is None


def test_get_github_pat_global(tmp_path, monkeypatch):
    """owner/repo 미지정 시 global_pat을 반환한다."""
    _write_config(tmp_path, {"github": {"global_pat": "ghp_global", "repos": []}})
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    assert cfg.get_github_pat() == "ghp_global"


def test_get_github_pat_repo_specific(tmp_path, monkeypatch):
    """일치하는 repo의 pat(non-null)이 global_pat보다 우선한다."""
    _write_config(tmp_path, {"github": {
        "global_pat": "ghp_global",
        "repos": [
            {"owner": "me", "repo": "a", "pat": "ghp_repo_a"},
            {"owner": "me", "repo": "b", "pat": None},
        ],
    }})
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    # repo a는 개별 pat 사용
    assert cfg.get_github_pat("me", "a") == "ghp_repo_a"
    # repo b는 pat이 null이므로 global_pat 폴백
    assert cfg.get_github_pat("me", "b") == "ghp_global"
    # 등록되지 않은 repo도 global_pat 폴백
    assert cfg.get_github_pat("me", "unknown") == "ghp_global"


def test_get_github_pat_no_config(tmp_path, monkeypatch):
    """config 자체가 없으면 None."""
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    assert cfg.get_github_pat() is None


def test_get_github_pat_no_github_section(tmp_path, monkeypatch):
    """github 섹션이 없으면 None."""
    _write_config(tmp_path, {"ssh": {"instances": []}})
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    assert cfg.get_github_pat() is None


def test_save_roundtrip(tmp_path, monkeypatch):
    """save 후 load로 동일 데이터를 읽을 수 있다."""
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    data = {"github": {"global_pat": "ghp_save", "repos": []}}
    path = cfg.save(data)
    assert path == tmp_path / ".suh-template" / "config" / "config.json"
    assert cfg.load() == data


def test_load_corrupted_config(tmp_path, monkeypatch):
    """깨진 JSON이면 None을 반환하고 예외를 던지지 않는다."""
    config_dir = tmp_path / ".suh-template" / "config"
    config_dir.mkdir(parents=True)
    (config_dir / "config.json").write_text("{ broken json", encoding="utf-8")
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    importlib.reload(cfg)
    assert cfg.load() is None
