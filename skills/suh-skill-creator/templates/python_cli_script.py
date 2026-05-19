#!/usr/bin/env python3
"""
Somansa 표준 Python CLI 스크립트 뼈대.

왜 이 템플릿이 필요한가:
- 사내망은 외부 의존성 설치가 막히는 경우가 많음 → stdlib만 사용.
- 사내 자체 서명 SSL 인증서 → verify_ssl opt-out 옵션 필요.
- Windows cp949 콘솔 → 한글 출력 깨짐 방지 UTF-8 강제.
- HTTP 에러는 구조화된 dict + 다음 액션 힌트로 파싱해 agent가 소비하기 쉽게.

사용법:
  1. 이 파일을 scripts/<skill-name>_api.py 로 복사.
  2. {PLACEHOLDER} 부분을 실제 로직으로 교체.
  3. main()의 action 분기에 명령 추가.
"""

from __future__ import annotations

import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

# Windows 콘솔 UTF-8 강제 (Python 3.7+)
try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    sys.stderr.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass


SKILL_DIR = Path(__file__).resolve().parent.parent
CONFIG_CANDIDATES = [
    SKILL_DIR / "config.json",
    Path.home() / ".config" / "somansa" / f"{SKILL_DIR.name}.json",
]


def _load_config() -> dict[str, Any]:
    for path in CONFIG_CANDIDATES:
        if path.exists():
            with path.open("r", encoding="utf-8") as f:
                return json.load(f)
    raise SystemExit(
        "config.json not found. Copy config.json.example to config.json and fill in required fields."
    )


def _ssl_context(cfg: dict[str, Any]) -> ssl.SSLContext | None:
    """사내 자체 서명 인증서 대응. verify_ssl=false 또는 env INSECURE=1 이면 검증 OFF."""
    service = cfg.get("service", {})
    verify = service.get("verify_ssl", True)
    if os.environ.get("INSECURE") == "1":
        verify = False
    if verify:
        return None
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def _request(cfg: dict[str, Any], method: str, path: str,
             query: dict | None = None, body: dict | None = None) -> Any:
    base = cfg["service"]["url"].rstrip("/")
    url = f"{base}{path}"
    if query:
        url += "?" + urllib.parse.urlencode({k: v for k, v in query.items() if v is not None})
    headers = {"Accept": "application/json"}
    # TODO: 인증 헤더 추가 (PAT 또는 Basic 등)
    token = cfg.get("service", {}).get("token")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode("utf-8") if body is not None else None
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    ctx = _ssl_context(cfg)
    try:
        with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
            raw = resp.read()
            if not raw:
                return None
            ctype = resp.headers.get("Content-Type", "")
            if "application/json" in ctype:
                return json.loads(raw.decode("utf-8"))
            return raw.decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        # 구조화된 에러 — agent가 소비하기 쉽게 next_actions 포함
        err = {
            "error": f"http_{e.code}",
            "http_status": e.code,
            "reason": e.reason,
            "url": url,
            "raw_response": (json.loads(body_text)
                             if body_text.strip().startswith("{") else body_text),
            "next_actions": [],  # TODO: 특정 코드(409 등)에서 친절한 힌트 추가
        }
        raise SystemExit(json.dumps(err, ensure_ascii=False, indent=2))
    except urllib.error.URLError as e:
        raise SystemExit(f"Connection failed: {e.reason} ({url})")


def _print(obj: Any) -> None:
    if isinstance(obj, (dict, list)):
        print(json.dumps(obj, ensure_ascii=False, indent=2))
    else:
        print(obj)


# ---------- Actions ----------

def action_ping(cfg: dict[str, Any]) -> Any:
    """TODO: 실제 상태 체크 API로 교체."""
    return {"ok": True, "config_path": str(CONFIG_CANDIDATES[0])}


# ---------- CLI ----------

def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    action = sys.argv[1]
    args = sys.argv[2:]

    cfg = _load_config()

    if action == "ping":
        _print(action_ping(cfg))
        return

    # TODO: 추가 action 분기

    print(f"Unknown action: {action}")
    print(__doc__)
    sys.exit(1)


if __name__ == "__main__":
    main()
