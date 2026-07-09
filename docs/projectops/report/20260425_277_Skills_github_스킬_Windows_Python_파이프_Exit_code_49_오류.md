# 구현 완료 보고 — #277 github 스킬 Windows Python 파이프 Exit code 49 오류

## 개요

Windows Git Bash 환경에서 `curl | python3 -c` 파이프 실행 시 발생하던 `Exit code 49` 오류를
curl 응답을 파일로 저장한 뒤 파싱하는 방식으로 교체했다.
추가로 config 파일 탐색 시 Search/find 대신 Read tool을 직접 사용하도록 원칙을 강화했다.

## 변경 사항

### Skills
- `skills/github/SKILL.md` — 이슈 조회 curl 파이프를 파일 저장(`-o /tmp/issue_result.json`) 후 파싱 방식으로 전환
- `skills/references/config-rules.md` — config 파일 접근 시 Search·find 탐색 금지, Read tool 직접 사용 원칙 최상단 명시

### 문서
- `docs/suh-template/issue/20260425_#277_...md` — 이슈 파일 등록

## 주요 구현 내용

**파이프 의존성 제거 (`skills/github/SKILL.md`)**

기존 방식:
```bash
curl -s ... | python3 -c "import json,sys; d=json.load(sys.stdin); ..."
```

변경 방식:
```bash
curl -s ... -o /tmp/issue_result.json
$PYTHON - <<'EOF'
import json
d = json.load(open("/tmp/issue_result.json", encoding="utf-8"))
...
EOF
```

파이프(stdin) 의존성을 제거하고 파일 저장 후 파싱으로 교체해
Windows Git Bash의 파이프 처리 방식 차이로 인한 오류를 근원적으로 차단했다.

**config-rules.md 접근 순서 규칙 강화**

config 파일을 Search/find로 탐색하면 플러그인 캐시 경로가 오탐될 수 있어
최상단에 "Read tool로 직접 읽기" 원칙을 명시했다.

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/277
