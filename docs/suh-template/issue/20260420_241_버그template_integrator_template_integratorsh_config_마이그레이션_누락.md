# ❗[버그][template_integrator] template_integrator.sh config.json 마이그레이션 누락

- **라벨**: 작업전
- **담당자**: 

---

🗒️ 설명
---

#232에서 플러그인 업데이트 시 config.json 소실 문제를 수정했으나, `template_integrator.ps1`(Windows)에만 마이그레이션 로직이 추가됐고 `template_integrator.sh`(macOS/Linux)에는 누락되었습니다.

macOS/Linux 환경에서 플러그인 업데이트 후 config.json(GitHub PAT, repo 설정 등)이 소실되어 `missing_pat` 에러가 반복 발생합니다.

🔄 재현 방법
---

1. macOS에서 플러그인 설치 후 config.json 설정 완료
2. `template_integrator.sh` 또는 `claude plugin update`로 업데이트
3. 새 버전 캐시로 교체되면서 config.json 소실
4. `/cassiiopeia:issue` 실행 시 config_not_found 에러 발생

📸 참고 자료
---

`template_integrator.ps1`에는 마이그레이션 로직이 있으나 `template_integrator.sh`에는 없음:

```bash
# template_integrator.sh — 누락된 부분
# 이전 버전 캐시에서 config 마이그레이션 로직 없음
```

✅ 예상 동작
---

`template_integrator.sh`의 플러그인 업데이트 구간에 `.ps1`과 동일한 마이그레이션 로직 추가:

```bash
# 이전 버전 캐시에서 config.json 자동 마이그레이션
if [ -d "$OLD_CACHE_PATH/config" ]; then
  cp "$OLD_CACHE_PATH/config/"*.json "$NEW_CACHE_PATH/config/" 2>/dev/null
  echo "✅ config.json 마이그레이션 완료"
fi
```

⚙️ 환경 정보
---

- **OS**: macOS 14.x (Darwin 24.1.0)
- **플러그인 버전**: cassiiopeia 2.9.22

🙋‍♂️ 담당자
---

- **백엔드**: 이름
- **프론트엔드**: 이름
- **디자인**: 이름
