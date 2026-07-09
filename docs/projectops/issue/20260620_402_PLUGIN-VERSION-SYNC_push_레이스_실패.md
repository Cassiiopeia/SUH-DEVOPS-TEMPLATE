🗒️ 설명
---

- `PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC` 워크플로우가 push 전 rebase를 하지 않아 동시성 레이스로 계속 실패한다.
- 다른 버전 워크플로우(VERSION-CONTROL 등)가 동시에 main을 push하면, 이 워크플로우의 `git push`가 원격이 앞서 있어 `! [rejected] (fetch first)`로 거부되고 step이 exit 1로 실패한다.
- 결과로 플러그인 매니페스트 버전(`package.json`·`.claude-plugin/plugin.json` 등)이 `version.yml`보다 뒤처져 어긋난다. (예: `version.yml`은 3.0.146인데 매니페스트는 3.0.144)
- 추가로 발견된 문제: 이 워크플로우는 **마켓플레이스 전용**(플러그인 매니페스트 버전 동기화)인데, `template_initializer.sh`의 cleanup과 `template_integrator.sh`/`.ps1`의 복사 제외 목록에 빠져 있어 **사용자 프로젝트로 새어나간다**. 사용자 프로젝트엔 동기화 대상 매니페스트가 없어 무의미하게 돌거나 실패한다.

🔄 재현 방법
---

1. main에 push가 일어나 여러 버전 워크플로우(VERSION-CONTROL, PLUGIN-VERSION-SYNC 등)가 동시에 트리거된다.
2. `PLUGIN-VERSION-SYNC`가 매니페스트 버전을 커밋하고 `git push`를 시도한다.
3. 그 사이 다른 워크플로우가 먼저 main에 push하면, 이 push가 `! [rejected] (fetch first)`로 거부되어 "변경사항 커밋" step이 실패한다.

📸 참고 자료
---

```
[main 2f03bb7] 플러그인 매니페스트 버전 동기화: 3.0.146 [skip ci]
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to '...'
hint: Updates were rejected because the remote contains work that you do not
      have locally. ... another repository pushing to the same ref.
❌ Push 실패
##[error]Process completed with exit code 1.
```

- 2026-06-11부터 6/12·6/17·6/20까지 동일 워크플로우가 반복 실패함을 Actions 이력에서 확인.

✅ 예상 동작
---

- push가 원격 변경과 충돌하면 `git pull --rebase` 후 다시 push해서 자동 복구되어야 한다 (`VERSION-CONTROL` 워크플로우가 이미 쓰는 v2.1 pull-rebase + retry 패턴과 동일하게).
- 마켓플레이스 전용 워크플로우는 사용자 프로젝트 초기화/통합 시 제거되어야 한다.

⚙️ 환경 정보
---

- **OS**: GitHub Actions Ubuntu Runner
- **워크플로우**: `.github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml`

🙋‍♂️ 담당자
---

- **백엔드**: Cassiiopeia
