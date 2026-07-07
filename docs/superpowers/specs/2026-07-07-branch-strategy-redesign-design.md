# 브랜치 전략 전면 전환 설계 — deploy 폐기, develop/main 표준 구조

- 날짜: 2026-07-07
- 이슈: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/425
- 상태: 설계 확정 (사용자 승인 대기 → writing-plans로 전환 예정)

## 1. 배경과 목표

현재 템플릿은 main(default)을 일상 개발 브랜치로, `deploy` 브랜치를 프로덕션으로 사용한다. 기능적으로는 Git Flow와 등가지만 네이밍이 반대라(일반 관례: default 브랜치 = 프로덕션) 직관적이지 않다. 이를 **develop(개발 통합) / main(default=프로덕션)** 표준 구조로 전면 전환하고 deploy 브랜치를 폐기한다.

GitHub Actions의 `on:` 트리거 블록은 expression 평가가 불가능하므로 브랜치명 변수화는 트리거 수준에서 원천 불가하다. 스텝 내부 로직은 `github.event.repository.default_branch` 변수를 유지·확대하되, 트리거는 표준 브랜치명(main/develop) 하드코딩으로 재편한다.

## 2. 확정된 결정 사항 (논의 이력)

| 결정 | 선택 | 근거 |
|------|------|------|
| 전환 방식 | **B안: 전면 전환 (breaking)** | 브랜치명 설정화(A안)보다 단순. 기존 레포는 breaking-changes로 안내 |
| 개발 브랜치명 | `develop` | Git Flow 표준. main은 default 유지하며 프로덕션으로 역할 변경 |
| 버전 의미 | **릴리스당 +1** (push당 +1 아님) | 버전 = 릴리스 횟수 |
| 버전 증가 위치 | **A-2: 릴리스 PR 파이프라인 안에서 bump** (머지 직전, develop에 커밋) | "+1 예측·workflow_run 체이닝·develop 백싱크" 3종 복잡성을 원천 제거. 버전이 먼저 확정되고 소비자는 읽기만 하는 기존 불변식 유지 |
| main 직접 push 처리 | **(ii): 가드 달린 VERSION-CONTROL 안전망 유지** | main은 PR 전용 운영이 원칙(현재 deploy와 동일 규율). 실수 직접 push 시 버전 이력 자가 치유 |
| 기존 레포 마이그레이션 | **breaking-changes.json critical 등록만** | 가이드 문서·자동화 없음. 기존 레포 사용자는 integrator를 반복 실행하지 않는 경향 |

## 3. 브랜치 모델

| 브랜치 | 역할 | 비고 |
|--------|------|------|
| `develop` | 일상 개발/통합. feature 브랜치 PR 대상. CI는 develop 기준 실행, 버전 증가 없음(버전은 릴리스 시 확정) | 신규 생성 |
| `main` | 프로덕션. **default 유지**. develop→main PR 머지 = 배포 | 역할 변경 |
| `deploy` | 폐기(삭제) | |

- main에 push하는 주체는 AUTO-CHANGELOG-CONTROL의 automerge뿐 (현재 deploy와 동일). 직접 push는 비권장이며 안전망(§7)이 버전 정합만 보전한다.
- 핫픽스도 develop에 커밋 후 develop→main PR로 릴리스한다 (automerge라 수 분 내 완료).

## 4. 릴리스 파이프라인 (버전 불변식)

핵심 불변식: **"버전은 main에 닿기 전에 확정된다. main push 시점의 소비자(배포·README·플러그인 동기화)는 읽기만 한다."** — 기존 구조(main push 시 즉시 +1 → deploy PR은 읽기만)와 동일한 성질을 새 구조에서 유지한다.

```
develop push (일상 개발 — 버전 변동 없음)
   ↓ 릴리스
PR develop→main [AUTO-CHANGELOG-CONTROL]
   ① head 가드: PR head ≠ develop이면 즉시 종료
      (main이 default가 되면 GitHub UI가 feature PR base를 main으로 기본 제안
       → 실수 PR이 automerge 파이프라인을 타는 사고 방지)
   ② CodeRabbit Summary 확보 (기존 로직 유지: 폴링 + 커밋분석 폴백)
   ③ Summary 확보 후: develop 체크아웃 → version_manager.sh increment (+1)
      → 버전 파일 동기화 커밋을 develop에 push (버전 확정)
   ④ 확정 버전으로 CHANGELOG.json/md 스탬프 → develop에 커밋
   ⑤ PR 제목을 확정 버전으로 갱신 (🚀 Deploy {날짜}-v{확정버전})
   ⑥ merge develop→main → git tag v{확정버전} (main 머지 커밋에)
   ↓ main push (버전 이미 확정)
README-VERSION-UPDATE · PLUGIN-VERSION-SYNC · CICD 배포
   — push main 트리거로 단순 교체, 확정 버전을 읽고 실행 (기존 deploy push와 동일 패턴)
```

- ③을 Summary 확보 **이후**에 두는 이유: Summary 실패로 릴리스가 중단됐을 때 develop에 고아 bump 커밋이 남는 것을 최소화.
- 태그 생성은 릴리스 경로에서는 AUTO-CHANGELOG(⑥)가, 핫픽스 경로에서는 안전망 VERSION-CONTROL(§7)이 각자 자기 bump에 대해 수행한다.

## 5. 워크플로우 트리거 재배치

| 워크플로우 | 현재 | 신규 |
|-----------|------|------|
| AUTO-CHANGELOG-CONTROL | `pull_request_target` → deploy | `pull_request_target` → main + head=develop 가드 |
| VERSION-CONTROL | push main (개발 push마다 +1) | push main 유지 — **안전망으로 역할 변경** (§7 가드) |
| README-VERSION-UPDATE | push deploy | push main |
| PLUGIN-VERSION-SYNC (템플릿 전용) | push deploy | push main |
| CICD 배포 11종 (Flutter 4·React·Next·Python·Spring SIMPLE·PACKAGES/NEXUS PUBLISH) | push deploy (+ workflow_run) | push main (+ workflow_run 참조 브랜치 검증, §12) |
| CI (FLUTTER/REACT/NEXT/PYTHON/NEXUS-CI) | push/PR main | push/PR develop |
| SECRET-FILE-UPLOAD | push main | push develop |
| TEMPLATE-UTIL-VERSION-SYNC | push main | push develop |
| NONSTOP-TRAEFIK/NGINX-CICD | (deploy 트리거 주석 상태) | 주석 내 브랜치명만 main으로 정리 |

- 공통 워크플로우는 `project-types/common/` 원본과 `.github/workflows/` 루트 복사본 **두 곳 동일** 수정.
- 트리거 외 실행 로직(run 스크립트, heredoc 등)은 브랜치명 참조 외 한 줄도 변경하지 않으며, `git diff`로 자가검증한다 (CLAUDE.md 워크플로우 검증 원칙).

## 6. AUTO-CHANGELOG-CONTROL 상세 변경

- 트리거: `branches: ["deploy"]` → `["main"]`.
- head 가드: 첫 job 최상단에서 `github.event.pull_request.head.ref != 'develop'`이면 전 job 스킵 (job-level `if`).
- **기존 `default_branch` 참조 5곳(체크아웃 ref, git pull, push 대상)은 "PR head(개발측)"을 의미했으므로 전부 `github.event.pull_request.head.ref`(develop)로 교체.** default_branch 변수를 그대로 두면 base(main)를 가리켜 오동작한다.
- fallback-summary의 커밋 수집: `origin/deploy..HEAD` → `origin/main..HEAD` (HEAD = develop 체크아웃).
- update-changelog job: develop 체크아웃 → increment → CHANGELOG 스탬프 → develop push. CHANGELOG 커밋 메시지는 기존 형식 유지. bump 직후 PR 제목을 확정 버전으로 갱신한다 (detect-and-parse의 기존 제목 스텝은 bump 전 버전이므로 이 시점에 재갱신).
- merge-and-deploy job: 기존 로직 그대로 (PR head/base를 gh CLI로 동적 조회하므로 브랜치명 하드코딩 없음). 머지 성공 후 태그 스텝 추가.
- PR 본문 초기화·Summary 폴링·automerge 재시도 로직은 무수정.

## 7. VERSION-CONTROL 안전망 (main 직접 push 대비)

- 트리거 유지: push main (paths-ignore 유지).
- **가드 스텝 추가**: push 커밋 범위(`github.event.before`..`github.sha`)에 `version.yml` 변경이 포함돼 있으면 = 릴리스 머지 → 이후 스텝 전부 skip (중복 +1 방지). 포함돼 있지 않으면 = 직접 push(핫픽스) → 기존 로직대로 +1, [skip ci] 커밋, 태그.
- 한계(문서화): 직접 push로 이미 시작된 CICD는 bump 전 버전으로 빌드된다. 직접 push는 지원 경로가 아니며, 안전망은 버전 이력의 단조 증가만 보전한다.

## 8. 스킬 · CLI 변경

- `skills/suh-changelog-deploy/SKILL.md` 전면 개정 (deploy 브랜치 언급 약 80곳): 흐름 = "develop push → PR develop→main". `git log origin/deploy..HEAD` → `origin/main..HEAD`, 커밋 분석 base `origin/deploy..origin/main` → `origin/main..origin/develop`, create-pr `head=develop, base=main`, deploy-status `--base main`. 스킬이 릴리스 노트를 본문에 담아 PR을 만드는 구조(레이스 방지)는 유지.
- `skills/suh-changelog-deploy/scripts/changelog_cli.py`: `deploy-status --base` 기본값 `deploy`→`main`, `create-pr` 기본 head/base 교체.
- `skills/references/config-rules.md`(9곳)·`common-rules.md`(2곳)·`mcp-subcommand-rules.md`(3곳)·`skills/suh-github/SKILL.md`(5곳)의 deploy 브랜치 서술 갱신.
- 이 레포 `CLAUDE.md`: "main에서 직접 작업" 규칙 → "develop에서 직접 작업, 릴리스는 develop→main PR"로 개정. 브랜치 기반 트리거 표 갱신.

## 9. 초기화·통합·호환성

- `PROJECT-TEMPLATE-INITIALIZER`: 신규 프로젝트 초기화 시 **develop 브랜치 자동 생성** 스텝 추가 (deploy는 현재도 자동 생성하지 않으므로 삭제 로직 불필요).
- `template_integrator.sh` / `.ps1`: 통합 안내 문구의 브랜치 서술 갱신 (deploy 언급은 대부분 server-deploy 폴더 의미라 실변경 최소).
- `.github/config/breaking-changes.json`에 **critical** 등록. message에 수동 전환 절차 요약: ① `git branch develop main && git push origin develop` ② 템플릿 재통합(integrator) ③ deploy 브랜치 삭제 ④ 이후 개발은 develop, 릴리스는 develop→main PR. 별도 가이드 문서·자동 마이그레이션은 제공하지 않음.
- README·CONTRIBUTING·docs/ 의 브랜치 흐름 설명 갱신.

## 10. 템플릿 레포 자체 전환 절차

1. 모든 파일 변경(워크플로우·스킬·문서·breaking-changes)을 전환 커밋으로 main에 push — 구 VERSION-CONTROL이 마지막으로 구 의미(+1)로 동작하고 종료
2. `develop` 브랜치를 main에서 생성·push
3. `deploy` 브랜치 삭제
4. 이후 작업은 develop에서, 릴리스는 develop→main PR

## 11. 비범위

- 기존 레포(RomRom 등) 자동 마이그레이션·가이드 문서 (breaking-changes 안내로 갈음)
- 브랜치명 설정화 (develop/main 고정)
- `master` 트리거 지원 (내부 로직의 default_branch 변수만 main/master 무관 커버)
- CICD 워크플로우 내부 배포 로직 변경 (트리거·브랜치 참조 외 무변경)

## 12. 구현 시 실측 검증 항목

- Flutter CICD 등의 `workflow_run` 트리거 `branches:` 필터는 트리거한 워크플로우 run의 head 브랜치 기준 — 현재 `[main]`(PR head가 main이었으므로)에서 `[develop]`로 변경이 필요할 가능성이 높음. 실측으로 확인 후 적용.
- `workflow_run`이 참조하는 워크플로우 `name:` 문자열("CHANGELOG 자동 업데이트" 등)이 실제 워크플로우의 name과 일치하는지 대조 (기존 불일치 여부 포함).
- AUTO-CHANGELOG의 `pull_request_target` 컨텍스트에서 head(develop) 체크아웃·push 권한 동작 확인.
- 전환 후 첫 릴리스를 이 레포에서 실측: increment → CHANGELOG → automerge → main push 트리거 연쇄 → 태그.

## 13. 리스크와 잔여 한계

| 항목 | 내용 | 대응 |
|------|------|------|
| 릴리스 실패 시 고아 bump | Summary 확보 후 increment하므로 창은 좁지만, 머지 실패 시 develop에 bump 커밋이 남을 수 있음 | 다음 릴리스가 그 버전을 그대로 사용(+1 안 함이 아니라 이미 +1된 상태로 릴리스) — 버전 공백 없음. 문서화 |
| 직접 push 배포의 버전 | bump 전 버전으로 빌드됨 | 지원 경로 아님을 문서화, 안전망은 이력만 보전 |
| 기존 레포 breaking | 템플릿 업데이트 수용 시 브랜치 재편 필수 | breaking-changes.json critical |
| workflow_run name 결합 | name 변경 시 연쇄 트리거 무음 단절 | §12 대조 검증 |
