# 트리거 발화 최적화 (선택)

CREATE 모드 Phase 5의 간이 검증이 통과했지만 실제로 호출이 잘 안 되는 느낌이 들 때 사용. 대부분은 간이 검증(5개 샘플)으로 충분하다.

## 왜 description이 중요한가

Claude가 "이 skill을 호출할까?"를 판단하는 거의 유일한 신호가 SKILL.md frontmatter의 `description`. 본문이 아무리 훌륭해도 description이 애매하면 호출 자체가 안 된다.

## 간이 검증 (Phase 5 기본)

1. **Should-trigger 3개**: 실제로 호출되어야 할 발화. "skill 이름"을 직접 부르지 않는 자연스러운 표현.
2. **Should-not-trigger 2개**: 근처 주제지만 호출되면 안 되는 경우.
3. agent가 스스로 "지금 description만 보고 이 skill을 떠올릴까?"를 자문.

5/5 이면 OK. 하나라도 미스면 description 수정 후 재검증.

## 공식 `run_loop.py` 기반 정량 최적화 (고급)

공식 skill-creator에는 description을 자동으로 개선하는 루프가 있다. 필요한 조건:
- `claude` CLI 사용 가능 (Claude Code 환경)
- 20개 정도의 eval query 준비 (should-trigger / should-not-trigger 혼합)

### 실행

```bash
python -m scripts.run_loop \
  --eval-set <trigger-eval.json> \
  --skill-path <skill-dir> \
  --model <model-id> \
  --max-iterations 5 \
  --verbose
```

- 60% train / 40% test 분할
- 각 query 3회 실행해 안정적 trigger rate 산출
- extended thinking으로 description 개선안 제안 → 재평가 → 반복 (최대 5회)
- test score 기준으로 best_description 선택 (train overfit 방지)

### eval query 작성 팁

- **Bad**: "Format this data", "Extract text from PDF" — 너무 추상적
- **Good**: 실제 사용자가 칠 법한 맥락 포함한 발화. 파일 경로, 업무 배경, 약간의 잡담

예:
> "우리 팀 gitlab.example.com에 있는 api-server 레포의 !347 MR에서 변경 파일만 좀 보고 싶은데"

### 사내망 제한

사내망에서 `claude -p`가 막혀 있으면 이 루프는 돌지 않는다. 간이 검증(Phase 5 기본)으로 대체.

## Description 작성 팁 (정량 최적화 없이)

1. **트리거 예시 발화를 직접 따옴표로 인용** — "MR 변경파일 알려줘", "skill 만들어줘"
2. **한국어와 영어를 섞어서** — 사내는 한글이 많지만 기술용어는 영어
3. **구체적인 주제/프로젝트 alias 포함** — CM, 쿼리서버, systemdashboard 등
4. **"pushy" 표현 사용** — "반드시 호출", "when the user mentions X, Y, or Z". 너무 겸손하면 호출 안 됨.
5. **너무 길지 않게** — ~200~300자. 너무 길면 신호 대 잡음 저하.
