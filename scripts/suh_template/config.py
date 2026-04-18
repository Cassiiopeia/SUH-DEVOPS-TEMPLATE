"""skill별 사용자 config를 .suh-template/config/ 에서 로딩한다."""

import json
from pathlib import Path
from typing import Any, Optional

_GITIGNORE_ENTRY = ".suh-template/config/"


def _local_config_path(project_root: Path, skill_id: str) -> Path:
	"""로컬 config 파일 경로를 반환한다."""
	return project_root / ".suh-template" / "config" / f"{skill_id}.config.json"


def _global_config_path(skill_id: str) -> Path:
	"""글로벌 config 파일 경로를 반환한다."""
	return Path.home() / ".suh-template" / "config" / f"{skill_id}.config.json"


def load(project_root: Any, skill_id: str) -> Optional[dict]:
	"""
	config를 두 단계로 탐색한다:
	1. {project_root}/.suh-template/config/{skill_id}.config.json
	2. ~/.suh-template/config/{skill_id}.config.json
	둘 다 없으면 None을 반환한다.
	"""
	local = _local_config_path(Path(project_root), skill_id)
	if local.exists():
		return json.loads(local.read_text(encoding="utf-8"))
	global_ = _global_config_path(skill_id)
	if global_.exists():
		return json.loads(global_.read_text(encoding="utf-8"))
	return None


def get_value(project_root: Any, skill_id: str, key: str) -> Optional[str]:
	"""config에서 특정 키의 값을 반환한다. config 없거나 키 없으면 None."""
	data = load(project_root, skill_id)
	if data is None:
		return None
	return data.get(key)


def save(project_root: Any, skill_id: str, data: dict, scope: str = "local") -> Path:
	"""
	config를 저장하고 저장된 경로를 반환한다.
	scope='local': {project_root}/.suh-template/config/ — .gitignore 자동 등록
	scope='global': ~/.suh-template/config/
	"""
	if scope == "global":
		path = _global_config_path(skill_id)
	else:
		path = _local_config_path(Path(project_root), skill_id)
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
	if scope == "local":
		ensure_gitignore(Path(project_root))
	return path


def ensure_gitignore(project_root: Any) -> None:
	"""{project_root}/.gitignore에 .suh-template/config/ 항목이 없으면 추가한다."""
	gitignore = Path(project_root) / ".gitignore"
	if gitignore.exists():
		content = gitignore.read_text(encoding="utf-8")
		if _GITIGNORE_ENTRY in content:
			return
		if content and not content.endswith("\n"):
			content += "\n"
		content += f"{_GITIGNORE_ENTRY}\n"
		gitignore.write_text(content, encoding="utf-8")
	else:
		gitignore.write_text(f"{_GITIGNORE_ENTRY}\n", encoding="utf-8")
