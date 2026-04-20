# 구현 보고서 — #232 플러그인 업데이트 시 config.json 소실

**이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/232
**작업일**: 2026-04-20
**커밋**: `cba7cf4`

---

## 문제 요약

플러그인 업데이트(`claude plugin update`) 시 새 버전 캐시로 교체되면서 이전 버전 캐시에 저장된 `config.json`(GitHub PAT, repo 설정 등)이 소실되는 문제 발생.

## 수정 내용

### `template_integrator.ps1`

플러그인 업데이트 후 이전 버전 캐시에서 `config.json`을 자동으로 마이그레이션하는 로직 추가 (40줄 추가).

**핵심 동작 흐름**:
1. 업데이트 전 현재 버전의 캐시 경로 기록
2. 업데이트 완료 후 새 버전 캐시 경로 확인
3. 이전 캐시의 `config/` 폴더에서 `*.json` 파일을 새 캐시로 복사
4. 마이그레이션 완료 안내 메시지 출력

```powershell
# 이전 버전 캐시에서 config.json 자동 마이그레이션
if (Test-Path "$oldCachePath\config") {
    $configFiles = Get-ChildItem "$oldCachePath\config" -Filter "*.json"
    foreach ($file in $configFiles) {
        Copy-Item $file.FullName "$newCachePath\config\" -Force
    }
    Write-Host "✅ config.json 마이그레이션 완료"
}
```

### 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `template_integrator.ps1` | 플러그인 업데이트 후 이전 버전 캐시에서 config.json 자동 마이그레이션 로직 추가 (40줄) |

## 검증

- 업데이트 전후 `config.json` 유지 확인
- PAT, repo 설정이 새 버전에서도 그대로 사용 가능
