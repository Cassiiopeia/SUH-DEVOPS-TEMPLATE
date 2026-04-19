import os
import sys
import subprocess
import json
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent


def run_cli(*args, cwd=None):
    """CLI를 서브프로세스로 실행하고 (stdout, stderr, returncode) 반환."""
    # cwd가 변경되어도 suh_template 패키지를 찾을 수 있도록 PYTHONPATH 설정
    # os.pathsep 사용으로 Windows(:) / macOS/Linux(;) 모두 호환
    env = os.environ.copy()
    existing = env.get("PYTHONPATH", "")
    sep = os.pathsep
    env["PYTHONPATH"] = f"{SCRIPTS_DIR}{sep}{existing}" if existing else str(SCRIPTS_DIR)
    result = subprocess.run(
        [sys.executable, "-m", "suh_template.cli", *args],
        capture_output=True,
        text=True,
        cwd=str(cwd or SCRIPTS_DIR),
        env=env,
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def test_normalize_title():
    stdout, stderr, code = run_cli("normalize-title", "드롭다운 디자인 변경")
    assert code == 0
    assert stdout == "드롭다운_디자인_변경"
    assert stderr == ""


def test_normalize_title_special_chars():
    stdout, stderr, code = run_cli("normalize-title", "fix: 버그#1 수정!")
    assert code == 0
    # title.py normalize: 비허용 문자 제거 후 연속 언더스코어 병합
    assert stdout == "fix_버그1_수정"


def test_get_issue_number_no_git(tmp_path):
    stdout, stderr, code = run_cli("get-issue-number", cwd=tmp_path)
    assert code == 0
    assert stdout == ""


def test_get_next_seq_empty(tmp_path):
    # git 저장소가 아닌 경로에서는 git_not_found 에러로 exit 1 반환
    stdout, stderr, code = run_cli("get-next-seq", "plan", cwd=tmp_path)
    assert code == 1
    assert "git_not_found" in stderr


def test_invalid_command():
    stdout, stderr, code = run_cli("nonexistent-command")
    assert code == 1
    assert "ERROR" in stderr


def test_skill_id_invalid():
    stdout, stderr, code = run_cli("get-next-seq", "invalid-skill")
    assert code == 1
    assert "skill_id_invalid" in stderr


def test_init_config_returns_example_path(tmp_path):
    """init-config는 .example 파일 경로를 stdout에 출력한다."""
    # tmp_path를 git 저장소로 초기화
    subprocess.run(["git", "init"], cwd=tmp_path, capture_output=True, check=True)

    example_dir = tmp_path / ".suh-template.example" / "config"
    example_dir.mkdir(parents=True)
    (example_dir / "analyze.config.example.json").write_text(
        json.dumps({"github_pat": "", "github_repos": []}), encoding="utf-8"
    )
    stdout, stderr, code = run_cli("init-config", "analyze", cwd=tmp_path)
    assert code == 0
    expected = str(tmp_path / ".suh-template.example" / "config" / "analyze.config.example.json")
    assert stdout == expected


def test_init_config_missing_example_file(tmp_path):
    """init-config는 .example 파일이 없으면 ERROR + exit 1."""
    # tmp_path를 git 저장소로 초기화
    subprocess.run(["git", "init"], cwd=tmp_path, capture_output=True, check=True)

    stdout, stderr, code = run_cli("init-config", "analyze", cwd=tmp_path)
    assert code == 1
    assert "example_not_found" in stderr


def test_init_config_invalid_skill_id(tmp_path):
    """init-config는 잘못된 skill_id이면 ERROR + exit 1."""
    # tmp_path를 git 저장소로 초기화
    subprocess.run(["git", "init"], cwd=tmp_path, capture_output=True, check=True)

    stdout, stderr, code = run_cli("init-config", "nonexistent", cwd=tmp_path)
    assert code == 1
    assert "skill_id_invalid" in stderr
