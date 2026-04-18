""".cursor/skills/MANIFEST.json 을 읽고 쓴다."""

import json
from pathlib import Path
from typing import Any, Optional

MANIFEST_PATH = Path(".cursor") / "skills" / "MANIFEST.json"


def read(project_root: Any) -> Optional[dict]:
    """MANIFEST.json을 읽어 dict로 반환한다. 없으면 None."""
    path = Path(project_root) / MANIFEST_PATH
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def write(project_root: Any, data: dict) -> None:
    """MANIFEST.json에 data를 저장한다."""
    path = Path(project_root) / MANIFEST_PATH
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
