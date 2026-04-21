# 구현 보고서

## 📌 작업 개요

Deploy 브랜치로 PR 생성 시 자동 머지 워크플로우에서 발생하는 race condition 문제 수정. 워크플로우 실행 중 main 브랜치에 새로운 커밋이 push되면 `git push origin HEAD` 실패하는 현상 해결.

**이슈**: [#133](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/133)
**관련 프로젝트**: RomRom-BE (TEAM-ROMROM)

---

## 🔍 문제 분석

### 증상
```
Your branch is behind 'origin/main' by 1 commit, and can be fast-forwarded.
error: failed to push some refs to 'https://github.com/TEAM-ROMROM/RomRom-BE'
hint: Updates were rejected because the tip of your current branch is behind
```

### 원인
1. `actions/checkout@v4`에서 main 브랜치 체크아웃 (커밋 `6f145b9`)
2. 워크플로우 실행 중 다른 프로세스가 main에 새 커밋 push (`26a8f40`)
3. 로컬 main이 `origin/main`보다 1커밋 뒤처짐
4. deploy 브랜치 머지 후 push 시도 → **non-fast-forward 오류 발생**

### 근본 원인
- 워크플로우가 **main 브랜치를 수정하고 push**하려는 설계
- main 브랜치는 지속적으로 변경될 수 있어 **race condition에 취약**
- 현재 템플릿은 이미 수정된 상태지만, **머지 직전 최신화가 누락**되어 있었음

---

## ✅ 구현 내용

### 변경 파일 (2개)
| 파일 | 변경 내용 |
|------|----------|
| `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` | 머지 직전 `git fetch` 추가 |
| `.github/workflows/project-types/common/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` | 동일한 수정 |

---

## 🔧 주요 변경사항 상세

### PR 브랜치 최신화 스텝 개선

**변경 전:**
```yaml
git checkout $PR_BASE
git pull origin $PR_BASE

# HEAD 브랜치(main)의 변경사항을 BASE(deploy)에 머지
git merge --no-edit origin/$PR_HEAD
```

**변경 후:**
```yaml
git checkout $PR_BASE
git pull origin $PR_BASE

# HEAD 브랜치(main)의 최신 변경사항 다시 가져오기 (race condition 방지)
echo "🔄 $PR_HEAD 브랜치의 최신 변경사항 가져오는 중..."
git fetch origin $PR_HEAD

# HEAD 브랜치(main)의 변경사항을 BASE(deploy)에 머지
git merge --no-edit origin/$PR_HEAD
```

### 변경 이유
- `git pull origin $PR_BASE` 이후 시간이 경과하면 `origin/$PR_HEAD`가 변경될 수 있음
- 머지 직전에 `git fetch origin $PR_HEAD`를 다시 수행하여 **최신 상태 보장**
- deploy 브랜치에 push하므로 main 브랜치의 race condition 영향 없음

---

## 📊 해결되는 시나리오

```
시간순서 (수정 후):
1. actions/checkout@v4 → 저장소 체크아웃
2. git fetch origin main → main 브랜치 정보 가져오기 (커밋 6f145b9)
3. git checkout deploy → deploy 브랜치로 체크아웃
4. git pull origin deploy → deploy 최신화
5. [다른 프로세스가 main에 새 커밋 push: 26a8f40]
6. git fetch origin main → 최신 main 다시 가져오기 (커밋 26a8f40) ← 추가됨!
7. git merge origin/main → 최신 main을 deploy에 머지 ✅
8. git push origin deploy → deploy에 푸시 ✅ (race condition 없음!)
```

---

## ⚠️ 참고사항

### RomRom-BE 프로젝트 적용 필요

이슈에서 보고된 로그는 **이전 버전의 워크플로우**를 사용하고 있음:
```bash
# 이전 버전 (문제 있는 코드)
git checkout $PR_HEAD  # main으로 체크아웃
git merge --no-edit origin/$PR_BASE  # deploy를 main에 머지
git push origin HEAD  # main에 푸시 → race condition!
```

**해결 방법**: RomRom-BE 프로젝트의 `.github/workflows/PROJECT-AUTO-CHANGELOG-CONTROL.yaml` 파일을 이 템플릿의 최신 버전으로 업데이트 필요.

### 워크플로우 설계 차이

| 항목 | 이전 버전 (문제) | 현재 템플릿 (정상) |
|------|-----------------|------------------|
| 체크아웃 대상 | `$PR_HEAD` (main) | `$PR_BASE` (deploy) |
| 머지 방향 | deploy → main | main → deploy |
| push 대상 | `HEAD` (main) | `$PR_BASE` (deploy) |
| race condition | 발생 가능 | 발생 안 함 |

---

## 🧪 테스트 방법

1. main → deploy PR 생성
2. PR 생성 후 main 브랜치에 새 커밋 push
3. 자동 머지 워크플로우가 정상적으로 완료되는지 확인
4. deploy 브랜치에 최신 main 변경사항이 포함되었는지 확인

---

## 📌 다음 단계

1. **이 템플릿 커밋**: 변경사항 커밋 및 푸시
2. **RomRom-BE 업데이트**: 해당 프로젝트에서 템플릿 최신화
3. **테스트**: main → deploy PR 생성하여 동작 확인
