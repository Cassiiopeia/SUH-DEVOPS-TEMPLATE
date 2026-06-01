"""MCP-style JSON 출력 헬퍼.

모든 _cli.py 서브커맨드 출력은 이 emit() 통해 stdout으로 나간다.
4필드(ok/code/summary/next) 기본값 자동 보장.

성공: emit({"data": ...})                        → rc=0, ok=true, code="ok"
에러: emit({"ok": False, "code": "...", ...})    → rc=1
"""
import json
import sys


def emit(payload: dict) -> int:
    """JSON을 stdout에 출력하고 ok 값에 따라 rc 반환.

    payload에 ok/code/summary/next가 없으면 기본값을 채워 4필드를 강제한다.
    한글은 ensure_ascii=False로 그대로 출력.
    """
    payload.setdefault("ok", True)
    if payload["ok"] and "code" not in payload:
        payload["code"] = "ok"
    elif not payload["ok"] and "code" not in payload:
        payload["code"] = "error"
    payload.setdefault("summary", None)
    payload.setdefault("next", None)
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()
    return 0 if payload["ok"] else 1
