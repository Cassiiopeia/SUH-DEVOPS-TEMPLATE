# ❗[버그][Skills] issue 스킬 GitHub 이슈 본문 줄바꿈 깨짐

## 개요

`/issue` 스킬로 GitHub 이슈를 등록할 때 본문의 줄바꿈이 `\n` 이스케이프 문자 그대로 렌더링되는 버그를 수정했다. curl 인라인 `-d` 방식에서 `python3 json.dumps` + `--data-binary @파일` 방식으로 변경하여 멀티라인 본문이 정상적으로 GitHub에 전달되도록 했다.

## 변경 사항

### Skills
- `skills/issue/SKILL.md`: 5단계 GitHub 이슈 생성 curl 명령어 수정 — 인라인 `-d "..."` 방식 제거, `python3 json.dumps`로 payload JSON 파일 생성 후 `--data-binary @파일` 방식으로 전송

### 문서
- `docs/suh-template/issue/20260422_256_버그_Skills_issue_스킬_GitHub_이슈_본문_줄바꿈_깨짐.md`: 이슈 등록 파일

## 주요 구현 내용

**기존 방식 (버그)**:
```bash
curl -d "{\"body\": \"{본문}\"}"
```
shell 문자열 내에서 멀티라인 본문을 직접 삽입하면 개행이 `\n` 텍스트로 GitHub API에 전달됨.

**수정 방식**:
```bash
python3 -c "
import json
payload = {'title': '...', 'body': '''...''', ...}
print(json.dumps(payload))
" > /tmp/issue_payload.json

curl --data-binary @/tmp/issue_payload.json ...
```
`json.dumps()`가 개행을 `\n`으로 올바르게 직렬화하고, 파일로 전송하여 shell 이스케이프 문제를 원천 차단한다.

## 주의사항

- `report` 스킬의 GitHub 댓글 포스팅도 동일한 인라인 `-d` 방식을 사용하고 있어 같은 문제가 잠재적으로 존재함 — 추후 동일하게 수정 필요
