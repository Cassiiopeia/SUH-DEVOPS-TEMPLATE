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
