# Play Store "AAB만 올라가고 심사 제출 안 됨" 근본 원인 진단

- 작성일: 2026-06-19
- 관련: 이슈 #399, RomRom-FE #322/#658
- 증상 증언(사용자): "AAB는 올라가서 어딘가 저장됐는데 심사까지는 안 갔고, 내가 콘솔에서 '새 버전 만들기' 눌러 수동으로 출시했다."

## 결론 (fastlane 공식 소스코드로 확정)

RomRom의 Play Store 배포는 **워크플로우가 success로 끝나지만 실제로는 production 심사가 제출되지 않는 "거짓 성공"** 상태였다. 원인은 fastlane supply의 **자동 rescue 동작**이다.

### 메커니즘

1. `deploy_internal` lane이 internal(completed) 업로드 후 `promote_internal_to_production` 호출.
2. Google Play Android Publisher API의 `edits.commit`이 특정 조건에서 에러 반환:
   `"Changes cannot be sent for review automatically. Please set the query parameter changesNotSentForReview to true"`
3. fastlane supply는 옵션 `rescue_changes_not_sent_for_review`(**기본값 `true`**) 때문에 이 에러를 **잡아서 자동 재시도**.
4. 재시도는 `commit_edit(..., changes_not_sent_for_review: true)`로 커밋 = **"변경을 심사에 보내지 않고 저장만"**.
5. fastlane은 성공 반환 → 워크플로우 **success**. 그러나 실제로는 **심사 미제출**.

### 1차 출처 (fastlane master 소스코드)

`supply/lib/supply/options.rb`:
- `release_status` default = `Supply::ReleaseStatus::COMPLETED`
- `track_promote_release_status` default = `Supply::ReleaseStatus::COMPLETED`
- `changes_not_sent_for_review` default = `false` ("changes will not be reviewed until explicitly sent for review from the Google Play Console UI")
- `rescue_changes_not_sent_for_review` default = `true` ("Catches changes_not_sent_for_review errors when an edit is committed and retries with the configuration that the error message recommended")

`supply/lib/supply/client.rb` (commit 로직):
- 에러 문자열 rescue: `"Please set the query parameter changesNotSentForReview to true"`
- rescue true일 때 재시도: `client.commit_edit(..., changes_not_sent_for_review: true)`
  → "changes are NOT sent for review—they remain in draft/internal state despite being committed"

### 기각된 가설 (중요 — 헛다리 방지)

- ❌ "promote lane에 `release_status`가 없어서 draft로 남았다" → `track_promote_release_status` 기본값이 `completed`라 **draft 아님**.
- ❌ "권한(Service Account) 부족" → 권한 문제면 commit 자체가 다른 에러로 실패했을 것. 여기선 rescue가 작동해 success로 끝났으므로 권한은 충분.

## 수정 방향 (확정)

목표: **(A) 거짓 성공 제거 + (B) 실제 심사 제출.**

1. **거짓 성공 차단**: production 심사 제출 호출에 `rescue_changes_not_sent_for_review: false` 명시.
   → "심사 자동 제출 불가" 에러가 더 이상 조용히 삼켜지지 않고 **워크플로우가 실패로 표면화**된다. (success인데 안 됨 → 실패로 정직하게 드러남)
2. **`changes_not_sent_for_review: false` 명시** (기본값이지만 의도를 코드에 박아 둠).
   → 변경을 심사로 보내겠다는 의도 명시.
3. **2단계 구조 재검토**: internal(completed) 업로드 후 별도 호출로 production promote 하는 방식이 위 에러를 유발하는지 실측으로 확인. 필요 시 "production 트랙에 직접 1단계 업로드" 또는 promote 순서 조정.

> ⚠️ **이 진단은 1차 출처(소스코드)로 메커니즘은 확정됐으나, "RomRom 실제 배포에서 그 rescue가 발동했다"는 살아있는 로그로 최종 실측해야 한다.** 과거 로그(6월)는 90일 만료(410)되어 확인 불가. 따라서:
> 1. 수정안을 RomRom에 적용
> 2. 사용자가 실제 배포 1회 실행
> 3. **살아있는 Actions 로그에서 `changesNotSentForReview` rescue 문구가 사라졌는지 + Play Console production 트랙에 "검토 중"으로 실제 진입했는지** 확인
> 4. 검증된 형태를 템플릿(suh-github-template)에 이식

이 4단계가 "매번 당한" 거짓 성공을 끝내는 유일한 실측 경로다.
