# next 타입 완전 제거 — react로 흡수 — 설계

> **관련 이슈**: [#437](https://github.com/Cassiiopeia/projectops/issues/437)
> **Breaking**: v4.1.0 (breaking-changes.json 4.1.0 항목에 #436 SSOT와 병합 등록)

## 결정 사항

**`next` 타입을 완전히 제거하고 `react`로 흡수한다. alias 하위호환 없음.** (이슈 본문 확정안 그대로)

- 감지: package.json에 `"react"` 또는 `"next"`가 있으면 `react`로 판정. next 우선 분기 삭제.
- react CICD가 next의 SSR 옵션(`NODE_ENV=production`, `--restart unless-stopped`)을 흡수 — Next.js 컨테이너도 그대로 동작.
- react CI는 이미 `.next/cache` 캐싱 수행 (변경 불필요).

## 변경 내역

| 영역 | 변경 |
|---|---|
| 워크플로우 | `project-types/next/` 폴더 삭제 (NEXT-CI·NEXT-CICD). `react/PROJECT-REACT-CICD.yaml` docker run에 SSR 옵션 2종 흡수 |
| Node CLI | `context.js` VALID_TYPES에서 제거, `detect.js` react 분기에 `"next"` 흡수, `paths-resolve.js`·`prompts.js`(메뉴)·`help.js` 정리 |
| `.sh` | VALID_TYPES, `detect_project_type`·`classify_package_json`·`detect_project_types`(react 분기에 흡수), `_order`, `marker_for_type`, `find_type_path_candidates`, 타입 메뉴(`react — React / Next.js 웹 앱`), help 텍스트 |
| `.ps1` | `$ValidTypes`, `Get-PackageJsonType`·감지 함수 동일 흡수, `$order`, `Get-MarkerForType`, `Find-TypePathCandidates`, 메뉴, help |
| `version_manager.sh` | case 패턴에서 `"next"` 제거 (5곳) |
| `template_initializer.sh` | VALID_TYPES·help·헤더 주석 |
| breaking-changes.json | 4.1.0 항목에 병합: 전환 절차(`project_types`의 `next`→`react` 변경 + 재통합) + 컨테이너명 변경(`-nextjs-deploy`→`-front-deploy`) 수동 정리 안내 |
| 문서 | CLAUDE.md(타입 표·폴더 구조·네이밍·React/Next 표), README.md, docs/VERSION-CONTROL.md, docs/WORKFLOW-COMMENT-GUIDELINES.md, version.yml 헤더 |
| 테스트 | `detect.test.js`(next→react 흡수 판정), `context.test.js`(VALID_TYPES 8개) |

## 유지 (의도적)

- CHANGELOG.json 과거 릴리스의 `project_type: "next"` 이력 — 생성 산출물 히스토리
- 과거 스펙/리포트/이슈 문서의 next 언급

## 검증

- `bash -n` 3종 + PowerShell `Parser::ParseFile` OK
- `npm test` 153/153 green
