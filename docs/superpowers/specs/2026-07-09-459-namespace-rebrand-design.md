# #459 네임스페이스 전면 중립화 설계 (suh-* → projectops)

> 작성 2026-07-09. 사용자 확정: **플러그인명+스킬명+@suh-lab+config 경로까지 전면 중립화**("싹 다 지워줘").
> 큰 변경이므로 정확한 치환 매핑 + config 이주 마이그레이션 + TDD 검증을 포함한다.

## 목표

`suh-` / `cassiiopeia` / `@suh-lab` 브랜딩을 `projectops`로 전면 중립화한다. 단, **외부 실체(치환하면 물리적으로 깨지는 것)는 보존**한다.

## 1. 치환 매핑 (정확 규칙)

| # | From | To | 위치 |
|---|------|-----|------|
| 1 | 스킬 폴더 `skills/suh-<name>` | `skills/<name>` | 25개 폴더 리네임 |
| 2 | 커맨드 `cassiiopeia:suh-<name>` | `projectops:<name>` | 문서·SKILL.md 전체 |
| 3 | `/cassiiopeia:suh-<name>` | `/projectops:<name>` | 슬래시 커맨드 안내 |
| 4 | 플러그인명 `cassiiopeia` (plugin.json/marketplace.json name) | `projectops` | 매니페스트 |
| 5 | 스크립트 경로 `skills/suh-<name>/scripts` | `skills/<name>/scripts` | SKILL.md·py 참조 |
| 6 | 캐시 glob `cache/*/cassiiopeia/*/skills/suh-<name>` | `cache/*/projectops/*/skills/<name>` | 스크립트 탐색 패턴 |
| 7 | config 경로 `~/.suh-template` | `~/.projectops` | **config.py `config_path()` + 마이그레이션** |
| 8 | tmp 경로 `~/.suh-template/tmp` | `~/.projectops/tmp` | changelog_cli.py |
| 9 | docs 출력 `docs/suh-template` | `docs/projectops` | report/review/troubleshoot_cli.py |
| 10 | 트리거 `@suh-lab` | `@projectops` | 워크플로우 트리거 로직 + 문서 |
| 11 | User-Agent `"suh-template"` | `"projectops"` | gh_client.py |
| 12 | docs/ 과거 문서 내 스킬 참조 | 신 이름 | 일괄(스킬명만) |

## 2. 보존 (치환 금지 — 외부 실체)

| 문자열 | 정체 | 이유 |
|--------|------|------|
| `me.suhsaechan:suh-logger` / `suh-logger` | Maven 아티팩트 | 실제 배포된 외부 라이브러리. 바꾸면 존재하지 않는 의존성 |
| `suh-project-utility` | 실제 레포명 | 외부 레포 |
| `suhsaechan` / `me.suhsaechan` | GitHub 유저명·groupId·홈 경로 | 실제 계정·좌표 |

> `spring-test` 폴더는 `spring-test`로 리네임하되, 그 SKILL.md **본문의 `me.suhsaechan:suh-logger`는 보존**한다. (폴더명과 본문 의존성명을 구분 치환.)

## 3. config 경로 이주 마이그레이션 (핵심 안전장치)

`scripts/common/config.py`의 `config_path()`가 유일한 진실원. 다음처럼 개편:

```python
def config_path() -> Path:
    new = Path.home() / ".projectops" / "config" / "config.json"
    old = Path.home() / ".suh-template" / "config" / "config.json"
    # 신 경로에 없고 구 경로에 있으면 1회 이주(복사) — 기존 사용자 데이터 무손실
    if not new.exists() and old.exists():
        new.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(old, new)   # 구 파일은 남겨둠(롤백 대비)
    return new
```

- **기존 `~/.suh-template/config/config.json` 사용자는 첫 스킬 실행 시 자동으로 `~/.projectops`로 복사**된다. 구 파일은 삭제하지 않아 롤백 안전.
- tmp 경로도 동일 패턴(필요 시)이나, tmp는 휘발성이라 이주 없이 신 경로만 사용.
- config-rules.md·common-rules.md·각 SKILL.md의 경로 안내도 `~/.projectops`로 갱신.

## 4. @suh-lab 트리거

- 워크플로우가 `@suh-lab`을 grep/비교하는 **트리거 로직**과 문서 안내를 모두 `@projectops`로.
- 트리거 로직은 공통 워크플로우 동기화 규칙에 따라 `.github/workflows/` 루트 + `project-types/`가 있으면 양쪽.
- **하위호환 주의**: 기존 레포에서 `@suh-lab`을 쓰던 사용자는 새 트리거로 안 먹음 — CHANGELOG/문서에 명시.

## 5. 마법사·integrator 제외 목록 정합

스킬 폴더 리네임이 아래와 어긋나지 않는지 확인:
- `template_initializer.sh` cleanup — `skills/` 통째 삭제이므로 개별 스킬명 무관(확인).
- `template_integrator.sh`·`.ps1` `plugin_items_to_remove` — `skills/` 통째 제외(확인).
- npx 제외 목록(`src/core/exclusions.js`) — `skills/` 통째(확인).

## 6. TDD 검증

1. **config 이주 테스트** (`scripts/tests/test_config.py` 신규/복원):
   - 신 경로 없고 구 경로 있으면 → `config_path()` 호출 시 신 경로로 복사되고 신 경로 반환 (HOME을 tmp로 격리).
   - 신 경로 이미 있으면 → 구 경로 무시하고 신 경로 반환(덮어쓰기 안 함).
   - 둘 다 없으면 → 신 경로 반환(생성은 save 시).
2. **changelog_cli tmp 경로 테스트**: `test_changelog_resolve_body_file.py`의 `.suh-template` → `.projectops` 갱신 후 통과.
3. **리네임 정합성 테스트** (`test/rename-consistency.test.js` 또는 py 신규):
   - `skills/` 아래 `suh-` 폴더 0건.
   - README·CLAUDE.md·docs/SKILLS.md에 `cassiiopeia:suh-` 0건.
   - 보존 대상(`suh-logger`·`suh-project-utility`)은 여전히 존재(과잉 치환 방지).
4. **전체 회귀**: `npm test`(174+) + `pytest`(36+) 전량 통과.

## 7. 대소문자 구분 (조사 확정 — 핵심)

- **`cassiiopeia`(소문자)** = 플러그인/네임스페이스명 → **치환 O** (`projectops`). 6개 매니페스트 + 6개 src/core/ide 어댑터 + JS 테스트.
- **`Cassiiopeia`(대문자)** = 실제 GitHub 조직명 → **보존** (`Cassiiopeia/projectops` repo URL·author).
- 커맨드 접두사 `/projectops:issue`는 폴더명이 아니라 **플러그인명**에서 파생 → 플러그인명 치환 + 폴더 리네임 둘 다 필요.

## 8. docs/suh-template 산출물 디렉토리

- `docs/suh-template/`(issue/report/analyze/... 실제 산출물) 존재. report/review/troubleshoot_cli.py가 `docs/suh-template`에 출력.
- **결정**: 코드 출력 경로는 `docs/projectops`로 바꾸되, **기존 `docs/suh-template/` 디렉토리는 git mv로 rename**(과거 산출물 보존). harness/WORKFLOW.md·PERSONA.md의 경로도 갱신.

## 9. 방출 코드 보존 (조사 확정 — 치환 시 사용자 빌드 파손)

- `skills/spring-test/SKILL.md`의 `me.suhsaechan:suh-logger`, `import static me.suhsaechan.suhlogger.util.SuhLogger.*` → **폴더는 spring-test로 rename하되 본문 이 라인들은 절대 보존**.
- `*.suhsaechan.kr` 도메인(PR-preview·AI base_url 예시), `suh-project-utility`(레포명), `kr.suhsaechan.*` bundle id → 보존.
- **일괄 sed 금지**: `suh-` prefix가 스킬명·로거·레포명·도메인에 공존 → **화이트리스트(25개 스킬명) 기반 정확 치환**만. negative match로 보존 목록 회피.

## 10. 실행 순서 (안전 — 조사 반영)

1. ✅ config.py 마이그레이션 + 테스트 (완료).
2. 파이썬 하드코딩 경로 치환: changelog_cli tmp(완료), report/review/troubleshoot_cli `docs/suh-template`→`docs/projectops`, gh_client User-Agent. + 테스트 갱신(test_changelog_resolve_body_file, test_config).
3. docs/suh-template 디렉토리 git mv → docs/projectops. harness 문서 경로 갱신.
4. 스킬 폴더 25개 git mv (`suh-<name>`→`<name>`) + 각 SKILL.md 내부 상호참조·스크립트 경로·캐시 glob 치환.
5. 파이썬 테스트의 스킬 폴더 하드코딩 경로 갱신(test_cli_signatures_doc_sync, test_skill_docs, test_cli_body_file, test_changelog_resolve_body_file).
6. 매니페스트 플러그인명 `cassiiopeia`→`projectops` (6개) + src/core/ide 어댑터(6개) + JS 테스트(ide.test.js).
7. @suh-lab 트리거 치환(워크플로우 로직 + 안내 문자열, 도메인 suhsaechan.kr 회피).
8. README·CLAUDE.md·docs 스킬 커맨드 표기 일괄 치환(보존 목록 제외).
9. 정합성 테스트 + 전체 회귀(pytest + npm test).

각 단계 후 `pytest`·`npm test`로 회귀 0 확인하며 진행. **단계마다 커밋**해 롤백 지점 확보.
