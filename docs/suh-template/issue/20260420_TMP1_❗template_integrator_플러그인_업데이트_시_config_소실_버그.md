# ❗[버그][template_integrator] 플러그인 업데이트 시 config.json 소실

- **라벨**: 작업전
- **담당자**: Cassiiopeia

---

🗒️ 설명
---

`template_integrator.ps1`에서 플러그인 업데이트(`claude plugin update`) 또는 Claude Code UI "Update Now" 버튼으로 업데이트 시, 새 버전 캐시 폴더에 기존 `config.json`이 복사되지 않아 API 키 등 설정값이 초기화되는 문제.

캐시 구조상 업데이트 시 신규 버전 폴더가 생성되므로 기존 설정이 자동 이관되지 않음:

```
~/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia/
  ├── 2.9.18/skills/{skill}/config.json   ← 기존 설정 (API 토큰 등)
  └── 2.9.19/skills/{skill}/              ← 업데이트 후 config.json 없음 → 오류
```

두 경로 모두 config 소실이 발생:
- `template_integrator.ps1`에서 업데이트하는 경우
- Claude Code UI에서 "Update Now" 버튼으로 업데이트하는 경우

🔄 재현 방법
---

1. cassiiopeia 플러그인 설치 후 특정 skill의 `config.json`에 API 키 등 설정 저장
2. `template_integrator.ps1` 실행 → "업데이트" 선택 또는 Claude Code UI "Update Now" 클릭
3. 업데이트 완료 후 해당 skill 실행 시 config not found 오류 발생

📸 참고 자료
---

유사 구현 참고 (`somansa-claude-code` 레포):
- `install.ps1`: `Invoke-ConfigMigration` 함수 — 설치 완료 후 이전 버전 캐시에서 `config.json` 복사
- `common/config_migrate.py`: 런타임 마이그레이션 — skill 실행 시 `config.json` 없으면 이전 버전에서 탐색·복사
- 각 skill `load_config()` 시점에 `migrate_config_if_needed()` 호출

관련 파일:
- `template_integrator.ps1` (플러그인 업데이트 섹션 ~line 2356)

✅ 예상 동작
---

- 플러그인 업데이트 후에도 기존 `config.json` 설정값이 새 버전 폴더로 자동 이관됨
- `template_integrator.ps1` 업데이트 플로우 및 Claude Code UI "Update Now" 경로 양쪽 모두 커버

⚙️ 환경 정보
---

- **OS**: Windows 11
- **대상 파일**: `template_integrator.ps1`
- **캐시 경로**: `~/.claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia/{version}/skills/`

🙋‍♂️ 담당자
---

- **담당자**: Cassiiopeia
