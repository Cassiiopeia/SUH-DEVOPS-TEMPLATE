# projectops npx 전환 — 세션 핸드오프

> **이 문서 목적**: 새 세션이 "지금 어디까지 됐고, 당장 뭘 이어서 하면 되는지"를 30초 안에 파악하기 위한 인덱스.
> 상세 히스토리·검증법·함정은 각 SP 문서와 메모리(`~/.claude/projects/.../memory/projectops-migration-status.md`)에 있으니 **중복 서술하지 않고 가리키기만** 한다.

---

## 한 줄 요약

`template_integrator.sh`(5,660줄)+`.ps1`(5,127줄) 마법사를 `npx projectops` 단일 Node CLI로 전환 중. **SP1·SP3·SP2-A·B·C·D 완료. 다음은 SP2-E(마무리).**

- 추적 이슈: https://github.com/Cassiiopeia/projectops/issues/424
- 작업 브랜치: **develop** (main 직접 push 금지, 릴리스는 develop→main PR)
- 현재 main 확정 버전: **v3.0.195** (SP2-D 배포 완료. 배포마다 PLUGIN-SYNC가 올림 — 로컬에서 리셋 금지)

---

## 진행 현황

| 단계 | 상태 | 내용 |
|------|------|------|
| SP1 | ✅ | package.json = projectops npm 매니페스트, bin/projectops.js |
| SP3 | ✅ | 레포 rename(projectops) + 전방위 리브랜딩 |
| #425 | ✅ | deploy 브랜치 폐기 → develop/main 전환, NPM-PUBLISH를 `push: main` 트리거로 |
| SP2-A | ✅ | core 모듈(context·exclusions·breaking·detect·wizard-env·version-yml) |
| SP2-B | ✅ | 복사 엔진(assets·copy/*·full 오케스트레이터) — 골든 바이트 검증 |
| SP2-C | ✅ | CLI 배선(args·index·commands) + **대화형 마법사**(clack) |
| SP2-D | ✅ | **IDE Skills 설치** — 어댑터 레지스트리 패턴 (claude·cursor·gemini·codex·pi·pi-harness) |
| **SP2-E** | ⬜ | **다음 할 일 (아래)** |

**릴리스 [skip ci] 버그(#433)**: 수정·검증 완료 (버전 확정 커밋에서 [skip ci] 제거). 이제 develop→main 머지 시 npm 자동 게시됨.

**테스트**: `node --test` → 91 pass (골든 검증 + stub io 검증).

---

## 배포 완료 상태 (✅ 검증됨)

- SP2-D 커밋 2개 develop push 완료.
- **deploy PR #442 머지 완료** → **origin/main = v3.0.195 확정**. PLUGIN-SYNC·README 업데이트 커밋까지 main에 반영됨.
  - `origin/main..origin/develop` 비어있음 = SP2-D 작업이 main에 100% 반영, develop version.yml도 `3.0.195`로 동기화 완료.
  - npm 게시는 main push 시 NPM-PUBLISH 워크플로우가 수행(로컬 내부망에선 게시 버전 조회 불가 — GitHub Actions run으로만 확인).

> ⚠️ **다음 세션 시작 시 필수**: 로컬 develop이 origin보다 뒤처져 있다(릴리스 버전 확정 커밋 미수신). SP2-E 작업·커밋 전에 **반드시 먼저** 실행:
> ```bash
> git checkout develop && git pull --rebase origin develop
> ```

---

## 다음 할 일 — SP2-E (마무리·컷오버)

새 세션은 여기서부터 시작한다. 순서 무관, 독립적:

1. **OS 매트릭스 CI** — GitHub Actions에서 ubuntu·windows·macos 3-OS로 `node --test` 돌리는 워크플로우 추가. Node CLI가 3 OS에서 다 도는지 자동 검증.
   - 참고: 지금까지 windows(개발기)에서만 실행함. mac/linux 미검증.
2. **`.sh`/`.ps1` deprecated 컷오버** — 기존 마법사를 어떻게 정리할지 결정.
   - 옵션: (a) 즉시 삭제, (b) deprecated 안내 후 npx로 리다이렉트, (c) 당분간 병존.
   - ⚠️ `.sh`/`.ps1`은 아직 **README/docs에서 참조**될 수 있으니 함께 정리.
3. **spring deploy 블록 키 순서 정밀화** (낮은 우선순위) — Node가 만드는 version.yml의 spring deploy 블록 키 순서가 `.sh`와 다름(값·개수는 동일, 재통합 힌트 메타라 기능 무영향). SP2-B에서 미룬 항목.

> **SP2-E 시작 전 필독**: 이건 새 기능이 아니라 마무리라 brainstorming 없이 바로 writing-plans로 가도 된다. 단 "컷오버 방식(위 2번 옵션)"은 사용자에게 먼저 물어라 — 되돌리기 어려운 결정.

---

## 참고 문서 (상세는 여기 — 중복 서술 안 함)

- 마스터 설계: `docs/superpowers/specs/2026-07-08-sp2-node-cli-porting-design.md`
- 분석: `docs/superpowers/plans/2026-07-08-sp2-{structure-map,behavior-spec}.md`
- 단계별 계획: `docs/superpowers/plans/2026-07-08-sp2{a,b,c-cli-commands-wiring,c-interactive,d-ide-skills}.md`
- **메모리(가장 최신 상태·함정 정리)**: `~/.claude/projects/D--0-suh-project-suh-github-template/memory/projectops-migration-status.md`

---

## 핵심 규칙 (새 세션도 반드시 지킴)

- **커밋 컨벤션**: 이모지·태그 프리픽스 금지. `내용 : feat/fix/docs : 설명 URL` 형식. 커밋/PR 본문에 **Claude/AI 흔적 절대 금지**(Co-Authored-By, Generated with 등).
- **push는 사용자 명시 요청 시에만.** develop push 전 항상 `git pull --rebase origin develop`.
- **내부망**: npm install/build·mvn OK(사내 미러). npm 게시는 GitHub Actions에서만(로컬 내부망 X).
- **확장성 원칙(SP2-D에서 사용자 명시)**: 하드코딩 최소화·분리. 새 IDE는 어댑터 파일 하나 + registry 한 줄로 확장되게 만들어둠 — SP2-E 이후 확장도 이 패턴 유지.
- **언어**: JS(ESM) 확정. TS 안 씀(npx 무빌드 실행 정체성). 타입은 JSDoc만.

---

## 명령 힌트 (자주 씀)

```bash
# skill scripts 경로 (Bash stateless — 매 블록 앞에 재선언)
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/cassiiopeia/*/skills/suh-changelog-deploy/scripts 2>/dev/null | sort -V | tail -1)
PYTHON="/c/Users/USER/AppData/Local/Programs/Python/Python313/python"

# 배포 상태 확인
GITHUB_PAT=... PYTHONIOENCODING=utf-8 "$PYTHON" "$SCRIPTS/changelog_cli.py" deploy-status Cassiiopeia projectops --pr 442

# 테스트
node --test 2>&1 | grep -E "^ℹ (tests|pass|fail)"

# npm 게시 확인
npm view projectops version
```
