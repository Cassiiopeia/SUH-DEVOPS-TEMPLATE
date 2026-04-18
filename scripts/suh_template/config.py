"""skill별 사용자 config를 .suh-template/config/ 에서 로딩한다."""

import json
from pathlib import Path
from typing import Any, Optional


def _config_path(project_root: Path, skill_id: str) -> Path:
    """config 파일의 경로를 반환한다."""
    return project_root / ".suh-template" / "config" / f"{skill_id}.config.json"


def load(project_root: Any, skill_id: str) -> Optional[dict]:
    """
    .suh-template/config/{skill_id}.config.json 을 읽어 dict로 반환한다.
    파일이 없으면 None을 반환한다.
    """
    path = _config_path(Path(project_root), skill_id)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def get_value(project_root: Any, skill_id: str, key: str) -> Optional[str]:
    """config에서 특정 키의 값을 반환한다. config 없거나 키 없으면 None."""
    data = load(project_root, skill_id)
    if data is None:
        return None
    return data.get(key)
