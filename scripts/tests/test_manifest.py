import sys
import json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.manifest import read, write, MANIFEST_PATH


def test_read_existing_manifest(tmp_path):
    manifest_dir = tmp_path / ".cursor" / "skills"
    manifest_dir.mkdir(parents=True)
    data = {"plugin_version": "2.9.9", "skills": []}
    (manifest_dir / "MANIFEST.json").write_text(json.dumps(data))
    result = read(tmp_path)
    assert result["plugin_version"] == "2.9.9"


def test_read_missing_manifest(tmp_path):
    assert read(tmp_path) is None


def test_write_creates_manifest(tmp_path):
    manifest_dir = tmp_path / ".cursor" / "skills"
    manifest_dir.mkdir(parents=True)
    data = {"plugin_version": "3.0.0", "skills": []}
    write(tmp_path, data)
    result = json.loads((manifest_dir / "MANIFEST.json").read_text())
    assert result["plugin_version"] == "3.0.0"


def test_manifest_path_constant():
    assert MANIFEST_PATH == Path(".cursor") / "skills" / "MANIFEST.json"
