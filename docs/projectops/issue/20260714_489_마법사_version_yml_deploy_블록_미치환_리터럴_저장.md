🗒️ 설명
---

- 마법사(npx projectops) 통합 시 워크플로우 파일에는 `__PROJECT_NAME__` 토큰이 레포명으로 정상 치환되는데, 같은 값을 "기억"하는 `version.yml`의 `deploy.<type>` 블록에는 **치환 전 리터럴이 그대로 저장**됩니다.
- 결과적으로 실제 설치된 워크플로우와 version.yml의 기억값이 영구히 불일치합니다.
- 같은 원인으로, env 입력 단계의 안내 카드에도 기본값이 `/volume1/projects/__PROJECT_NAME__` 처럼 리터럴로 노출되어 사용자가 "이 이상한 값이 그대로 박히나?" 오해하게 됩니다 (실제로는 파일 복사 시 치환됨).

🔄 재현 방법
---

1. spring 레포(예: suh-project-utility)에서 `npx projectops@latest` 실행, 전체 설치 진행
2. env 설정 단계에서 "호스트(NAS) 볼륨 경로"를 기본값 그대로 Enter (카드에 `/volume1/projects/__PROJECT_NAME__` 리터럴이 노출됨)
3. 통합 완료 후 두 파일을 비교:
   - `.github/workflows/PROJECT-SPRING-SIMPLE-CICD.yaml` → `VOLUME_HOST_PATH: "/volume1/projects/suh-project-utility"` (정상 치환)
   - `version.yml` → `deploy.spring.VOLUME_HOST_PATH: "/volume1/projects/__PROJECT_NAME__"` (미치환 리터럴)

📸 참고 자료
---

- v4.2.15 실측 결과 (suh-project-utility 레포):

```yaml
# version.yml (실측)
deploy:
  spring:
    PROJECT_NAME: "suh-project-utility"
    VOLUME_HOST_PATH: "/volume1/projects/__PROJECT_NAME__"   # 미치환
    VOLUME_CONTAINER_PATH: "/mnt/__PROJECT_NAME__"           # 미치환
```

- 원인 위치: `src/core/wizard-env.js` — ask 값 수집(collectAsks)이 `__PROJECT_NAME__` 전역 치환보다 먼저 수행되어 치환 전 값이 deploy 블록에 담김. env 카드(`src/ui/env-plan.js`)도 동일하게 resolve 전 기본값을 표시.

✅ 예상 동작
---

- `version.yml`의 `deploy.<type>` 블록에는 워크플로우 파일에 실제로 써진 값과 동일한(치환 완료된) 값이 저장되어야 함
- env 입력 카드의 기본값도 `/volume1/projects/suh-project-utility` 처럼 resolve된 값으로 표시되어야 함
- 다음 실행(업데이트 모드)에서 기억값을 default로 재사용할 때도 치환된 실제 경로가 나와야 함

⚙️ 환경 정보
---

- **OS**: Windows 11 (재현은 OS 무관)
- **버전**: projectops v4.2.15 (npm), origin/develop 최신에서도 동일 확인
