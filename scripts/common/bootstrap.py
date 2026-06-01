"""sys.path 부트스트랩 헬퍼.

각 _cli.py 첫 줄에서 직접 sys.path 조작 패턴을 사용하므로
이 모듈은 테스트·디버깅 보조 용도다.
"""
from pathlib import Path
from typing import Optional


def find_scripts_root(start: Path) -> Optional[Path]:
    """start에서 위로 올라가며 'scripts/common/__init__.py'를 찾는다.

    찾으면 'scripts/' 경로 반환. 없으면 None.
    """
    cur = start.resolve()
    for _ in range(10):
        candidate = cur / "scripts" / "common" / "__init__.py"
        if candidate.exists():
            return cur / "scripts"
        if cur.parent == cur:
            return None
        cur = cur.parent
    return None
