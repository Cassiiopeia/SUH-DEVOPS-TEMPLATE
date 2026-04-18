import sys
from pathlib import Path
from datetime import date
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.paths import get_next_seq, build_output_path


def test_get_next_seq_empty_dir(tmp_path):
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = date.today().strftime("%Y%m%d")
    assert get_next_seq(skill_dir, today) == "001"


def test_get_next_seq_existing_files(tmp_path):
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = date.today().strftime("%Y%m%d")
    (skill_dir / f"{today}_001_test.md").touch()
    (skill_dir / f"{today}_002_test.md").touch()
    assert get_next_seq(skill_dir, today) == "003"


def test_get_next_seq_other_date_ignored(tmp_path):
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = date.today().strftime("%Y%m%d")
    (skill_dir / "20200101_001_old.md").touch()
    assert get_next_seq(skill_dir, today) == "001"


def test_build_output_path_with_issue(tmp_path):
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = "20260418"
    path = build_output_path(
        base_dir=tmp_path,
        skill_id="plan",
        today=today,
        number="427",
        title="드롭다운_디자인_변경",
    )
    assert str(path) == str(tmp_path / "plan" / "20260418_427_드롭다운_디자인_변경.md")


def test_build_output_path_with_seq(tmp_path):
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = "20260418"
    path = build_output_path(
        base_dir=tmp_path,
        skill_id="plan",
        today=today,
        number="001",
        title="분석_결과",
    )
    assert str(path) == str(tmp_path / "plan" / "20260418_001_분석_결과.md")
