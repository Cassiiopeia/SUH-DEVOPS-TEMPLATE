"""
get_pat — config.json에서 GitHub PAT를 한 줄로 꺼내 stdout에 출력한다.

curl로 GitHub API를 직접 호출하는 스킬(suh-github의 explore·secret 등)이
PAT를 즉흥 Python으로 추출하다 `config["github"]["global_pat"]` 네임스페이스를
빠뜨리는 사고를 막기 위한 표준 추출기다.

사용법:
    python suh_template/get_pat.py [owner] [repo]

동작:
    1. GITHUB_PAT 환경변수가 있으면 그것을 출력
    2. 없으면 config.json에서 자동 로드
       (owner/repo 일치하는 repos[].pat(non-null) 우선, 없으면 global_pat)
    PAT를 못 찾으면 빈 문자열을 출력(stderr에 안내) → 호출 측에서 빈 값 검사.
"""

import os
import sys
from pathlib import Path

# 패키지 루트를 sys.path에 추가 (직접 실행 대비)
_HERE = Path(__file__).parent.parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from suh_template import config as _config


def main() -> int:
    owner = sys.argv[1] if len(sys.argv) > 1 else None
    repo = sys.argv[2] if len(sys.argv) > 2 else None

    pat = os.environ.get("GITHUB_PAT")
    if not pat:
        pat = _config.get_github_pat(owner, repo)

    if not pat:
        print("[ERROR] get_pat: GITHUB_PAT 환경변수도 config.json도 없습니다. (missing_pat)",
              file=sys.stderr)
        return 1

    # 개행 없이 출력 — $(...) 캡처 시 그대로 변수에 담긴다
    sys.stdout.write(pat)
    return 0


if __name__ == "__main__":
    sys.exit(main())
