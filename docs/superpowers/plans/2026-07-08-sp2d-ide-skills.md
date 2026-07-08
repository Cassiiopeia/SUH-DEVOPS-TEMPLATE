# SP2-D — IDE Skills 설치 (Node 포팅)

`.sh` `offer_ide_tools_install` + 25개 헬퍼(4575~5435행)를 Node로 등가 포팅.
Claude Code / Cursor / Gemini CLI / Codex CLI / PI + PI Persona Harness 를 설치·업데이트·제거한다.

## 핵심 성격 (SP2-A~C와 다른 점)

- **외부 CLI 호출이 본질** — `claude plugin ...`, `gemini extensions ...`, `codex plugin ...`, `pi install ...`.
  파일 복사(SP2-B)와 달리 **골든 바이트 비교 불가**. 대신:
  - **runner 주입**: 모든 CLI 실행을 `run(cmd, args) → {code, stdout, stderr}` 형태의 주입 가능한 함수로 감싼다. 테스트는 stub runner로 호출 시퀀스·분기를 검증.
  - **env 주입**: `command -v` 감지도 `which(cmd)` 주입기로. HOME 경로도 주입.
- Cursor만 파일 복사(마켓플레이스 없음) → SP2-B의 copyDir 재사용, `cursor-skills-meta.json` 버전 manifest 기록.
- PI harness는 `settings.json`의 `extensions` 배열 편집 — Node fs+JSON으로 직접 (`.sh`는 python heredoc).

## 모듈 구조

```
src/core/ide/
  runner.js       # which(cmd), run(cmd,args,opts) → {code,stdout,stderr}. 주입 가능
  claude.js       # detect/install/update/remove + plugin data 삭제 + config 마이그레이션
  cursor.js       # meta 읽기/쓰기 + skills/ 복사 + 제거
  gemini.js       # extensions install/update/uninstall
  codex.js        # marketplace register/upgrade + native symlink fallback + 제거
  pi.js           # install/update/remove + is_installed + harness(enable/disable/status)
  skills-detect.js# 5개 IDE 현재 상태 한 번에 수집 → 표시용 구조체
src/commands/skills.js  # offer_ide_tools_install 등가 오케스트레이터 (라우터: apply/remove/skip)
src/ui/skills-prompts.js# 동작 선택·IDE 멀티셀렉트·harness 확인 (clack)
```

## 라우터 흐름 (.sh 4668~4748 등가)

1. 상태 수집(skills-detect) → 표시
2. TTY+대화형이면: 동작 선택(설치·업데이트/제거/그대로) → IDE 멀티셀렉트 → 선택 IDE만 실행
3. FORCE/비TTY면: 5개 IDE 순차 install/update (자동)

## 태스크 분해 (커밋 단위)

- **D1**: runner + claude.js + 테스트 (감지·설치·업데이트·제거·config 마이그레이션 stub 검증)
- **D2**: cursor.js + gemini.js + codex.js + 테스트
- **D3**: pi.js (+harness) + skills-detect.js + 테스트
- **D4**: commands/skills.js 오케스트레이터 + ui/skills-prompts.js + index.js 라우팅(skills 모드 실동작) + 대화형 skills 분기 연결 + 테스트

## 검증 전략

- CLI는 실제로 안 부른다(테스트 환경에 claude/gemini/codex/pi 없음). stub runner로:
  - 미설치 감지 시 install 경로 호출
  - 설치 감지 시 update 경로 호출
  - remove 시 uninstall 호출
  - which=false면 수동 안내만(no-op)
- Cursor 복사는 실제 tmp에 수행해 파일·meta.json 존재 검증(SP2-B와 동일 방식).
- PI harness는 실제 tmp settings.json에 extensions 배열 add/remove 검증.
- 비대화형 `npx projectops --mode skills --force`가 exit 0 (5 IDE 순차, 미설치는 안내 no-op)로 완주.
