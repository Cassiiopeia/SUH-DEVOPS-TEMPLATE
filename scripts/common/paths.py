"""산출물 md 파일 경로를 계산한다."""

from pathlib import Path
from typing import Union


def get_next_seq(skill_dir: Path, today: str, strict: bool = False) -> str:
    """
    skill_dir 내에서 오늘 날짜(today)로 시작하는 파일 개수 + 1을 3자리로 반환한다.

    strict=True이면 skill_dir이 존재하지 않을 때 FileNotFoundError를 던진다.
    CLI 레이어가 잘못된 skill_id를 명시적으로 거부할 때 사용한다.
    """
    if not skill_dir.exists():
        if strict:
            raise FileNotFoundError(f"skill_dir does not exist: {skill_dir}")
        return "001"
    count = sum(1 for f in skill_dir.iterdir() if f.name.startswith(today))
    return f"{count + 1:03d}"


def build_output_path(
    base_dir: Union[str, Path],
    skill_id: str,
    today: str,
    number: str,
    title: str,
) -> Path:
    """최종 산출물 경로를 반환한다."""
    return Path(base_dir) / skill_id / f"{today}_{number}_{title}.md"
