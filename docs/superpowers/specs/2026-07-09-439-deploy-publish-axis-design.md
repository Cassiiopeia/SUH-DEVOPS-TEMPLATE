# 배포/publish 타겟 축 재설계 (타입 비종속) — 설계 스펙

> **관련 이슈**: [#439](https://github.com/Cassiiopeia/projectops/issues/439)
> **성격**: 설계 + **구현 완료** (v4.2.0). 미확정 3건은 아래 §9로 확정.
> **선행 완료**: #436(project_types SSOT), #437(next 제거), #438(npm publish opt-in)

## 9. 확정 사항 (구현 시 결정)

- **github-packages**: publish 축 값으로 승격 — `--publish github-packages` opt-in (기존 spring 기본 포함 → opt-in으로 breaking, breaking-changes.json 4.2.0에 등록)
- **Vercel 원본**: passQL-Lab/passQL의 `PROJECT-COMMON-VERCEL-DEPLOY.yml`을 편입 — 입력 계약 `VERCEL_TOKEN`·`VERCEL_ORG_ID`·`VERCEL_PROJECT_ID`, `PROJECT_PATH` env로 모노레포 서브폴더 지원
- **alias 유지 기간**: 1 minor — `--nexus`/`--npm-publish`(.ps1 `-Nexus`/`-NpmPublish`)는 경고 후 신 축 해석, 다음 major에서 제거

## 구현 내역 (v4.2.0)

| 레이어 | 변경 |
|--------|------|
| 폴더 | `spring/nexus`→`spring/publish/nexus`, `node/npm-publish`→`node/publish/npm`, `spring/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH`→`spring/publish/github-packages/`, 신규 `common/deploy/vercel/PROJECT-COMMON-VERCEL-DEPLOY.yaml` |
| `.sh` | `DEPLOY_TARGET`+`INCLUDE_{NEXUS,NPM_PUBLISH,GH_PACKAGES}`, `--deploy`/`--publish` 파싱, deprecated `--nexus`/`--npm-publish` alias, `ask_deploy_publish`(택1+다중선택), server-deploy는 docker-ssh만·common/deploy/<target> 복사·publish/<target> 복사, read/save_template_options 신 축+구 키 마이그레이션·제거, 분석카드·수정메뉴 |
| `.ps1` | `-Deploy`/`-Publish` 파라미터, `$DeployTarget`+3 publish 불리언, `Ask-DeployPublish`, `Get-PublishTargets{Json,Csv}`, 동일 복사·마이그레이션 |
| Node CLI | `args.js`(--deploy/--publish + alias), `context.js`, `index.js`, `options-ask.js`(deploy/publish 질문+구 키 마이그레이션), `version-yml.js`(parse/serialize 신 축+마이그레이션), `copy/workflows.js`(server-deploy 게이트·common/deploy·publish/<target>), `env-plan.js`(스캔 범위), `interactive.js`·`prompts.js`·`status-cards.js` UI |
| 문서/설정 | CLAUDE.md(배포/publish 축 표·폴더·옵션), breaking-changes.json 4.2.0(warning), version.yml 4.2.0 |
| 테스트 | cli-args(deploy/publish+alias), copy-workflows(vercel·publish 이동), options-ask(신 축+구 키 마이그레이션 재작성), env-plan·banner-cards 갱신 — **158/158 green** |

---
## (원 설계 — 참고용)

---

## 1. 문제 재정의

타입(무엇으로 만들었나)과 배포 방식(어디로 내보내나)은 독립 축인데, 현재 템플릿은 배포 방식을 타입에 하드코딩한다.

- react는 Docker+SSH로도, Vercel로도 배포된다 (실사례: passQL의 `PROJECT-COMMON-VERCEL-DEPLOY.yml`)
- nexus는 spring만의 것이 아니고, npm은 node만의 것이 아니다 (react 라이브러리도 npm publish)
- 파일 마커로는 "서버냐/라이브러리냐/Vercel 앱이냐"라는 **배포 의도**를 알 수 없다 → 마법사가 물어봐야 한다

## 2. 핵심 결정 — 두 축 분리

| 축 | 의미 | 다중성 | 값 |
|---|------|--------|-----|
| **`deploy`** | 실행물(서버/앱)을 어디에 올리나 | **택1** (상호배타) | `docker-ssh`(기본) · `vercel` · `none` |
| **`publish`** | 산출물(라이브러리/패키지)을 어느 레지스트리에 내나 | **0..n 공존** | `nexus` · `npm` · `github-packages` |

- 서버 배포와 라이브러리 publish는 **개념이 다르고 공존 가능**하다 (예: 모노레포 spring 서버 + npm SDK).
- `deploy: none`이 라이브러리 전용 프로젝트를 표현한다 — 현행 "nexus면 server-deploy 폴더째 제외" 임시 규칙을 대체.
- 두 값 모두 **마법사가 질문**해 확정한다 (파일 감지로 판단 불가라는 결론이 이 설계의 출발점).

## 3. version.yml 스키마

```yaml
metadata:
  template:
    options:
      deploy: "docker-ssh"        # docker-ssh | vercel | none — 택1
      publish: ["npm", "nexus"]   # 배열, 없으면 []
      secret_backup: false        # 배포축 아님 — 현행 유지
```

- 구 키 흡수: `nexus: true` → `publish: ["nexus"]` + (server-deploy 제외였으므로) `deploy: "none"`, `npm_publish: true` → `publish: ["npm"]`.
- **마이그레이션은 integrator가 통합(업데이트) 시 자동 변환** — 구 키를 읽어 새 축으로 기록하고 구 키는 더 쓰지 않는다. #436과 같은 SSOT 원칙: 이중 표기 유지 금지, breaking-changes에 등록.

## 4. 폴더 구조 (타입 비종속 표현)

```
project-types/
  common/
    deploy/
      vercel/PROJECT-COMMON-VERCEL-DEPLOY.yaml      # 신규 편입 (passQL 검증본 기반)
  <type>/
    server-deploy/                                  # deploy=docker-ssh일 때 (현행 유지)
    publish/
      nexus/PROJECT-SPRING-NEXUS-*.yml              # 구 spring/nexus/ 이동
      npm/PROJECT-NODE-NPM-PUBLISH.yaml             # 구 node/npm-publish/ 이동
      github-packages/PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH.yml
```

- **배포 타겟이 타입 비종속이면 `common/deploy/<target>/`** (Vercel — react든 node든 동일 파일).
- **publish 타겟은 빌드 도구가 타입에 묶이므로 `<type>/publish/<target>/`** 를 유지하되, integrator는 "선택된 publish 타겟 집합"으로 복사를 결정한다 — 타입은 파일 위치일 뿐 게이트가 아니다. (react 프로젝트가 `publish: ["npm"]`이면 node/publish/npm의 워크플로우를 받는다 — package.json 기반이라 타입 무관 동작.)
- integrator 복사 규칙: `deploy=docker-ssh` → server-deploy/ 포함, `deploy=vercel` → common/deploy/vercel/ 포함 + server-deploy/ 제외, `deploy=none` → 둘 다 제외. `publish` 배열의 각 타겟 → 해당 publish 폴더 포함.

## 5. 마법사 질문 흐름 (타입 확정 직후)

```
💫 이 프로젝트를 어떻게 내보내나요?
  1. 서버/호스팅에 배포합니다 (기본)
  2. 라이브러리/패키지로 publish합니다
  3. 둘 다 합니다
  4. 배포하지 않습니다 (CI만)

[1·3 선택 시] 배포 방식을 선택하세요 (택1)
  • Docker + SSH 서버 배포 (기본)
  • Vercel

[2·3 선택 시] publish 레지스트리를 선택하세요 (다중 선택)
  • npm (공개 npmjs)
  • Nexus (사내 Maven)
  • GitHub Packages
```

- 비대화형: `--deploy docker-ssh|vercel|none`, `--publish npm,nexus` (csv). `.ps1`은 `-Deploy`/`-Publish`.
- 재실행 시 version.yml 저장값을 기본값으로 제시 (현행 opt-in 재질문 생략 패턴 동일).

## 6. 기존 옵션 흡수 전략

| 구 옵션 | 처리 |
|---|---|
| `--nexus` / `options.nexus` | **1개 minor 동안 alias 유지 + deprecation 경고** (`--publish nexus` + `--deploy none`으로 자동 해석) → 다음 major에서 제거. CI 스크립트에 박힌 플래그 계약이므로 즉시 제거는 위험 |
| `--npm-publish` / `options.npm_publish` | 동일 (`--publish npm`으로 해석). #438 직후라 사용자가 적어 부담 낮음 |
| `--secret-backup` | 배포축과 무관 — 그대로 유지 |
| "nexus면 server-deploy 제외" 규칙 | `deploy: none`으로 일반화 — nexus여도 서버 배포가 필요한 케이스를 표현 가능해짐 |

## 7. 구현 분할 제안 (후속 이슈)

1. **W1 — 데이터모델·마이그레이션**: options 스키마(deploy/publish) + 구 키 자동 변환 + breaking 등록 (.sh/.ps1/js 3중)
2. **W2 — 폴더 재배치 + 복사 엔진**: publish/ 구조 이동, deploy 게이트 일반화 (server-deploy 제외 규칙 대체)
3. **W3 — 마법사 질문 흐름**: 위 §5 UI (.sh/.ps1/npx 3중) + `--deploy`/`--publish` 플래그 + 구 플래그 alias
4. **W4 — Vercel 워크플로우 템플릿화**: passQL 검증본 편입 (`common/deploy/vercel/`) + secret 문서화(VERCEL_TOKEN 등)

## 8. 미확정 (구현 전 사용자 확인 필요)

- github-packages를 publish 축 값으로 승격할지 (현재 spring 루트에 기본 포함 — opt-in으로 바꾸면 그것도 breaking)
- Vercel 워크플로우의 정확한 입력 계약 (passQL 원본 확인 필요 — VERCEL_TOKEN/ORG_ID/PROJECT_ID)
- alias 유지 기간 (제안: 1 minor)
