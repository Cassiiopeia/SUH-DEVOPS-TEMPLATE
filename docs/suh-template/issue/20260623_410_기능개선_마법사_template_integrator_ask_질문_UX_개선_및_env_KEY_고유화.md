📝 현재 문제점
---

`template_integrator`(마법사)가 워크플로우 env 토큰을 채울 때, "하나씩" 모드에서 사용자에게 KEY 라벨 한 단어만 보여준다.

```
PROJECT_NAME (기본: passQL): passQL
DOMAIN_NAME (기본: example.com):
```

이 때문에 실제 통합 중 **"이게 백엔드 도메인인지 프론트 도메인인지, 무슨 값을 넣으라는 건지 모르겠다"** 는 혼란이 발생했다.

근본 원인:

- **설명 부재** — `.github/wizard/labels.yml`이 `KEY: "한 줄 라벨"` 평면 매핑만 담아, "무엇에 쓰는 값인지" 설명·예시를 줄 수 없다.
- **라벨 비고유** — `DOMAIN_NAME`과 `PRODUCTION_DOMAIN`이 둘 다 "서비스 도메인"으로 표시돼 구별 불가.
- **같은 KEY, 다른 의미** — `PROJECT_NAME`이 spring/python/react/next에서는 "배포 슬러그(컨테이너·이미지·도메인 prefix)"지만, flutter에서는 "APK·아티팩트 파일명"이다. 같은 질문이 타입마다 다른 의미를 가져 헷갈린다.

🛠️ 해결 방안 / 제안 기능
---

- **`labels.yml` 스키마 확장 (하위호환 유지)** — 기존 `KEY: "문자열"` 형식을 계속 지원하면서, `label` / `help` / `example` 3필드 블록 형식과 `{type}.{KEY}` 타입 네임스페이스를 추가한다. 조회 우선순위는 `{type}.{KEY}` → `{KEY}` → 구형 → 폴백.

- **마법사 출력 개선** — "하나씩" 모드에서 ask 직전에 라벨 + 한 줄 설명 + 예시를 보여준다.

  ```
    ▸ 서비스 식별자 (영문 슬러그)
      Docker 컨테이너명·이미지명·배포 도메인 prefix에 그대로 사용됩니다.
      예) my-service
    값 입력 [기본: passql]:
  ```

- **의미가 다른 env KEY 분리 (고유화)** — 의미가 다르거나 중복인 KEY만 분리한다. 운영에 쓴 사용자가 아직 없어 안전하게 리네이밍 가능.

  | 현재 KEY | 위치 | 새 KEY |
  |---------|------|--------|
  | `PROJECT_NAME` | flutter (selfhosted·playstore·firebase) | `APP_ARTIFACT_NAME` |
  | `DOMAIN_NAME` | spring nginx | `SERVICE_DOMAIN` |
  | `PRODUCTION_DOMAIN` | spring traefik | `SERVICE_DOMAIN` |

  > spring/python/react/next의 `PROJECT_NAME`(동일 의미 = 배포 슬러그)은 유지한다.

- **example 톤** — common 템플릿이므로 특정 프로젝트에 안 치우친 일반명사형(`my-service`, `api.example.com`, `8080` 등)으로 작성한다.

⚙️ 작업 내용
---

- `.github/wizard/labels.yml` 스키마 확장 + 신규 라벨 전체 작성
- `template_integrator.sh` — `wf_label` → `wf_field` 확장, ask 분기 도움말 출력, 재귀 토큰 치환에 `__APP_ARTIFACT_NAME__` 추가
- `template_integrator.ps1` — `.sh`와 1:1 동일 동작으로 동일 변경
- 워크플로우 KEY 리네이밍 (선언부 + `${{ env.* }}` 참조 + SSH `envs:` 전달 목록 + 셸 본문 + 주석 전부 동기화)
  - flutter `PROJECT_NAME` → `APP_ARTIFACT_NAME` (selfhosted·playstore·firebase)
  - spring nginx `DOMAIN_NAME` → `SERVICE_DOMAIN`
  - spring traefik `PRODUCTION_DOMAIN` → `SERVICE_DOMAIN`
- 검증 — labels.yml 파서, 마법사 출력, KEY 잔존 0건, 실행 로직 무손상(`git diff` 자가검증), 문법(`bash -n` / PowerShell `Parser::ParseFile`)

> 설계 스펙: `docs/superpowers/specs/2026-06-23-wizard-ask-ux-and-unique-keys-design.md`
