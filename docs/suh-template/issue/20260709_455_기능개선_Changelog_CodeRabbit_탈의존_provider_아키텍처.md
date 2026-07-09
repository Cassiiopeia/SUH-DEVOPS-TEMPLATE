📝 현재 문제점
---

- `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` 워크플로우가 CodeRabbit을 1급 시민으로 하드코딩하고 있습니다. 릴리스 PR이 열리면 항상 `@coderabbitai summary`를 요청하고 최대 10분간 폴링한 뒤에야 폴백으로 넘어갑니다.
- CodeRabbit이 느리거나 아예 사용하지 않는 레포도 무의미하게 10분을 대기합니다. 또 CodeRabbit은 default 브랜치가 아니면 `@coderabbitai summary`에 응답하지 않는 제약도 있습니다.
- 이 CodeRabbit 하드 커플링은 신규 사용자의 **온보딩 장벽**입니다. 템플릿을 깔면 PAT + CodeRabbit 계정 연동까지 해야 첫 changelog가 나옵니다. "깔면 바로 작동"이 안 됩니다.
- 워크플로우 파일명 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL`도 길고 "CONTROL"이 모호해 직관적이지 않습니다.
- 이 이슈는 전체 최적화 로드맵의 **축(1순위)** 입니다.

🛠️ 해결 방안 / 제안 기능
---

> 상세 설계: `docs/superpowers/specs/2026-07-09-release-changelog-provider-design.md` (사용자와 브레인스토밍으로 확정)

**1. 파일명 변경**: `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` → **`PROJECT-COMMON-RELEASE-CHANGELOG.yaml`** (접두사 유지, 루트+common 원본 양쪽).

**2. 마법사 두 독립 질문** (CodeRabbit의 코드리뷰와 changelog 생성은 별개 기능):
- 질문① "CodeRabbit AI 코드 리뷰를 쓸까요?" — PR 코드 리뷰용 (changelog와 무관)
- 질문② "changelog는 뭘로 만들까요?" — **기본 커서 = GitHub AI**

**3. changelog 생성기 폴백 사다리**:
```
[기본] CodeRabbit 안 씀:  github-ai → openai-compatible → commit(안전망)
[선택] CodeRabbit 씀:     coderabbit → github-ai → openai-compatible → commit(안전망)
```
- 각 단계 실패(응답없음·rate limit·에러·default 브랜치 제약 등) → 다음으로 자동 폴백
- `commit`은 AI·네트워크 무의존이라 항상 완주하는 최후 보루
- **폴백 발생 시 PR 댓글/로그로 "○○ 실패 → △△ 전환" 알림**

**4. 기본값 = GitHub AI** (`actions/ai-inference@v1`): `permissions: models: read` 한 줄로 **API 키 없이** 러너 안에서 동작 → 깔면 즉시 작동. rate limit·8K 입력 토큰 제약은 mini 모델+prefix 필터로 대응, 안 되면 사다리로 폴백. (현재 한도는 구현 직전 공식 문서 재확인.)

**5. 설정 3층 분리**:
- `version.yml`: 비민감 선택값만 (`changelog.provider`, ollama일 때 `base_url`). **`model`·`api_key_secret` 키 없음** — provider별 기본값을 workflow가 자동 지정.
- `workflow.yaml`: 실행 + `${{ secrets.MODEL_API_KEY }}` 참조. secret 이름은 여기 고정.
- `GitHub Secret`: API 키 값은 **사용자가 직접 등록**. 마법사는 가이드만(값 안 받음).

**6. provider 무관 계약**: 어떤 provider든 `Summary by CodeRabbit` 형식 `pr_body.md` 산출 → 기존 `changelog_manager.py` 파싱·CHANGELOG.json·automerge 무수정 재사용. `parse_method`에 출처 기록.

⚙️ 작업 내용
---

- 워크플로우 리네임 (루트 + `project-types/common/` 양쪽)
- `version.yml`에 `options.code_review.coderabbit` + `options.changelog.provider`(+ollama base_url) 추가
- `.github/scripts/changelog_providers/`: `commit.sh`(안전망), `coderabbit.sh`, `openai_compatible.sh`
- github-ai는 `actions/ai-inference@v1` step(+`permissions: models: read`)
- 워크플로우 본체를 폴백 사다리 구조로 개편, 폴백 시 PR 댓글 알림
- 마법사(`src/core/options-ask.js`)에 질문 2개 추가 (기존 io.confirm/io.select 패턴 재사용, `test/options-ask.test.js` 패턴 따라 테스트)

🔗 로드맵 / 의존성
---

- 상세 지도: `docs/superpowers/specs/2026-07-09-optimization-roadmap.md`
- 상세 설계: `docs/superpowers/specs/2026-07-09-release-changelog-provider-design.md`
- 순서: **A(이 이슈) → B·C(병렬) → D**. 마법사 질문 UI 상세는 C(#457), 스킬 연동은 B(#456)
- 로컬 AI(개발자 머신)는 러너가 못 닿으므로 `suh-changelog-deploy` 스킬(로컬) 담당으로 분리

🙋‍♂️ 담당자
---

- Cassiiopeia
