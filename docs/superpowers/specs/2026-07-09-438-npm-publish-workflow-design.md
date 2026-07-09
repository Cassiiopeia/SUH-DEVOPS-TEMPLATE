# npm publish 워크플로우 템플릿 추가 (--npm-publish) — 설계

> **관련 이슈**: [#438](https://github.com/Cassiiopeia/projectops/issues/438)

## 결정 사항 (이슈 확정안 그대로)

**이 레포 전용 `PROJECT-TEMPLATE-NPM-PUBLISH` 로직을 사용자 프로젝트용으로 승격, `--npm-publish` opt-in.**

- 새 워크플로우: `project-types/node/npm-publish/PROJECT-NODE-NPM-PUBLISH.yaml`
- 트리거 main push + workflow_dispatch, `version_manager.sh get` 버전 주입, `npm view` 멱등, `npm publish --provenance --access public`, Secret `NPM_TOKEN`
- 전용 원본 대비: 헤더 일반화, `checkout ref: main` 제거, 요약 메시지 패키지명 변수화(`npm pkg get name`)
- Spring `nexus/` 패턴 미러: `node/npm-publish/` 하위 폴더 — 이후 node CI/CICD가 생겨도 자리 유지

## 구현 내역 (3중 구현 + Node CLI)

| 레이어 | 변경 |
|---|---|
| `.sh` | `--npm-publish`/`--no-npm-publish` 파싱, `INCLUDE_NPM_PUBLISH`, npm-publish/ 복사 블록(nexus 미러), env 치환 srcDir 추가, read/save_template_options `npm_publish`, 분석 카드·수정 메뉴, ask_all_optional_workflows 질문 |
| `.ps1` | `-NpmPublish`/`-NoNpmPublish`, `$script:IncludeNpmPublish`, 동일 미러 |
| Node CLI | `args.js` 플래그, `context.js`, `index.js`(CLI→저장값→false), `options-ask.js` 질문+저장값 재사용, `version-yml.js` parse/serialize, `copy/workflows.js` 복사+env 치환, `interactive.js` 상태·수정 메뉴·summarize, `prompts.js`·`status-cards.js` UI |
| 문서 | CLAUDE.md (Node 표·integrator 옵션·폴더 구조) |
| 테스트 | options-ask: npm-publish 질문/파싱 케이스 2종 추가, 기존 기대값에 npmPublish 키 반영 (155/155 green) |

## 유지 (의도적)
- `PROJECT-TEMPLATE-NPM-PUBLISH.yaml`(레포 전용)은 그대로 — 이 레포 자신의 npm 배포용. initializer 삭제·integrator 제외 목록도 무변경 (신규 파일은 project-types/ 하위라 자동 커버)
- 배포/publish 타겟 축 일반화는 #439에서 별도 설계

## 검증
- `bash -n` + PowerShell `Parser::ParseFile` + `npm test` 155/155
