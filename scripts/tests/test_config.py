import sys
import json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.config import load, get_value


def test_load_existing_config(tmp_path):
    config_dir = tmp_path / ".suh-template" / "config"
    config_dir.mkdir(parents=True)
    config_file = config_dir / "issue.config.json"
    config_file.write_text(json.dumps({"github_repo": "https://github.com/test/repo"}))
    result = load(tmp_path, "issue")
    assert result == {"github_repo": "https://github.com/test/repo"}


def test_load_missing_config(tmp_path):
    assert load(tmp_path, "issue") is None


def test_get_value_existing_key(tmp_path):
    config_dir = tmp_path / ".suh-template" / "config"
    config_dir.mkdir(parents=True)
    (config_dir / "issue.config.json").write_text(
        json.dumps({"github_repo": "https://github.com/test/repo"})
    )
    assert get_value(tmp_path, "issue", "github_repo") == "https://github.com/test/repo"


def test_get_value_missing_key(tmp_path):
    config_dir = tmp_path / ".suh-template" / "config"
    config_dir.mkdir(parents=True)
    (config_dir / "issue.config.json").write_text(json.dumps({}))
    assert get_value(tmp_path, "issue", "nonexistent") is None


def test_get_value_no_config(tmp_path):
    assert get_value(tmp_path, "issue", "github_repo") is None


def test_load_global_fallback(tmp_path, monkeypatch):
    """로컬 config 없을 때 글로벌 fallback을 사용한다."""
    home = tmp_path / "home"
    global_dir = home / ".suh-template" / "config"
    global_dir.mkdir(parents=True)
    (global_dir / "issue.config.json").write_text(
        json.dumps({"github_pat": "ghp_global"})
    )
    monkeypatch.setenv("HOME", str(home))
    import importlib, suh_template.config as cfg
    importlib.reload(cfg)
    result = cfg.load(tmp_path, "issue")  # tmp_path에는 로컬 config 없음
    assert result == {"github_pat": "ghp_global"}
    importlib.reload(cfg)  # 원복


def test_load_local_overrides_global(tmp_path, monkeypatch):
    """로컬 config가 글로벌보다 우선한다."""
    home = tmp_path / "home"
    global_dir = home / ".suh-template" / "config"
    global_dir.mkdir(parents=True)
    (global_dir / "issue.config.json").write_text(
        json.dumps({"github_pat": "ghp_global"})
    )
    local_dir = tmp_path / ".suh-template" / "config"
    local_dir.mkdir(parents=True)
    (local_dir / "issue.config.json").write_text(
        json.dumps({"github_pat": "ghp_local"})
    )
    monkeypatch.setenv("HOME", str(home))
    import importlib, suh_template.config as cfg
    importlib.reload(cfg)
    result = cfg.load(tmp_path, "issue")
    assert result == {"github_pat": "ghp_local"}
    importlib.reload(cfg)


def test_save_local(tmp_path):
    """save(scope='local')는 프로젝트 로컬에 저장하고 경로를 반환한다."""
    from suh_template.config import save
    data = {"github_pat": "ghp_test", "github_repos": []}
    path = save(tmp_path, "issue", data, scope="local")
    assert path == tmp_path / ".suh-template" / "config" / "issue.config.json"
    assert json.loads(path.read_text(encoding="utf-8")) == data


def test_save_global(tmp_path, monkeypatch):
    """save(scope='global')는 ~/.suh-template/config/ 에 저장한다."""
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("HOME", str(home))
    import importlib, suh_template.config as cfg
    importlib.reload(cfg)
    data = {"github_pat": "ghp_global"}
    path = cfg.save(tmp_path, "issue", data, scope="global")
    assert path == home / ".suh-template" / "config" / "issue.config.json"
    assert json.loads(path.read_text(encoding="utf-8")) == data
    importlib.reload(cfg)


def test_ensure_gitignore_creates_entry(tmp_path):
    """ensure_gitignore는 .gitignore에 .suh-template/config/ 항목을 추가한다."""
    from suh_template.config import ensure_gitignore
    ensure_gitignore(tmp_path)
    gitignore = tmp_path / ".gitignore"
    assert gitignore.exists()
    assert ".suh-template/config/" in gitignore.read_text(encoding="utf-8")


def test_ensure_gitignore_no_duplicate(tmp_path):
    """ensure_gitignore는 이미 항목이 있으면 중복 추가하지 않는다."""
    from suh_template.config import ensure_gitignore
    gitignore = tmp_path / ".gitignore"
    gitignore.write_text(".suh-template/config/\n", encoding="utf-8")
    ensure_gitignore(tmp_path)
    content = gitignore.read_text(encoding="utf-8")
    assert content.count(".suh-template/config/") == 1


def test_save_local_registers_gitignore(tmp_path):
    """save(scope='local')는 .gitignore에 자동으로 항목을 등록한다."""
    from suh_template.config import save
    save(tmp_path, "issue", {"github_pat": "ghp_test"}, scope="local")
    gitignore = tmp_path / ".gitignore"
    assert gitignore.exists()
    assert ".suh-template/config/" in gitignore.read_text(encoding="utf-8")
