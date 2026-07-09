# 버전 증가 후 git push 전 Race Condition 오류 수정

## 📌 작업 개요

버전 증가 워크플로우에서 `git push` 시도 전 다른 커밋이 `main` 브랜치에 푸시되면 `remote rejected` 오류가 발생하는 문제 수정. Pull-Rebase + Retry 로직 추가로 Race Condition 해결.

**이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/136

---

## 🔍 문제 분석

### 발생 오류
```
! [remote rejected] main -> main (cannot lock ref 'refs/heads/main': is at 9fd9b27... but expected c8c4c8b...)
error: failed to push some refs to 'https://github.com/TEAM-ROMROM/RomRom-FE'
```

### 원인
1. 워크플로우가 `c8c4c8b` 커밋에서 체크아웃
2. 버전을 `1.8.16` → `1.8.17`로 업데이트하고 로컬 커밋 생성 (`9fd9b27`)
3. **그 사이에 다른 워크플로우나 푸시가 먼저 main 브랜치를 업데이트**
4. `git push` 시도 시 remote의 `main`이 이미 변경되어 push 거부됨

### 기존 `concurrency` 설정의 한계
```yaml
concurrency:
  group: version-increment
  cancel-in-progress: false
```
- 동일 워크플로우 내에서만 동시 실행 방지
- 다른 PR 머지, 다른 워크플로우 푸시는 방지하지 못함

---

## ✅ 구현 내용

### 워크플로우 버전 업데이트
- **파일**: `.github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml`
- **변경 내용**: v2.0 → v2.1 버전 업데이트, Race Condition 방지 로직 추가
- **이유**: 헤더에 변경 이력 명시

### Pull-Rebase + Retry 로직 추가
- **파일**: `.github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml` (라인 117-147)
- **변경 내용**: 기존 단순 `git push`를 최대 3회 재시도하는 로직으로 변경
- **이유**: push 실패 시 remote 변경사항을 rebase하여 충돌 없이 재시도

---

## 🔧 주요 변경사항 상세

### 변경 전 (기존 코드)
```bash
if git commit -m "$COMMIT_MSG"; then
  git push
  echo "✅ 버전 업데이트 커밋 완료"
else
  echo "❌ 커밋 실패"
  exit 1
fi
```

### 변경 후 (개선된 코드)
```bash
if git commit -m "$COMMIT_MSG"; then
  # Race Condition 방지: pull-rebase 후 push (최대 3회 재시도)
  MAX_RETRIES=3
  RETRY_COUNT=0
  PUSH_SUCCESS=false

  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "🔄 Push 시도 $RETRY_COUNT/$MAX_RETRIES..."

    if git push; then
      PUSH_SUCCESS=true
      echo "✅ 버전 업데이트 커밋 완료"
      break
    else
      echo "⚠️ Push 실패, remote 변경사항 동기화 중..."

      # remote에서 최신 변경사항 가져와서 rebase
      if git pull --rebase origin main; then
        echo "✅ Rebase 성공, 다시 push 시도..."
      else
        echo "❌ Rebase 실패, 충돌 해결 필요"
        git rebase --abort 2>/dev/null || true
        exit 1
      fi
    fi
  done

  if [ "$PUSH_SUCCESS" = false ]; then
    echo "❌ $MAX_RETRIES회 시도 후에도 push 실패"
    exit 1
  fi
else
  echo "❌ 커밋 실패"
  exit 1
fi
```

### 로직 흐름

```
1. git push 시도
   ↓ (성공 시) → 완료
   ↓ (실패 시)
2. git pull --rebase origin main
   ↓ (성공 시)
3. git push 재시도
   ↓ (최대 3회 반복)
4. 3회 모두 실패 시 워크플로우 실패 처리
```

---

## 📌 특이사항

### Rebase 실패 시 안전 처리
```bash
git rebase --abort 2>/dev/null || true
```
- rebase 중 충돌이 발생하면 `rebase --abort`로 안전하게 롤백
- 오류 출력 억제 및 실패해도 계속 진행되도록 처리

### 동적 브랜치 참조
```bash
git pull --rebase origin ${{ github.event.repository.default_branch || 'main' }}
```
- 기본 브랜치가 `main`이 아닌 경우에도 동작하도록 동적 참조

---

## 🧪 테스트 및 검증

- [ ] 정상 케이스: push 1회차에 성공하는 경우
- [ ] Race Condition 케이스: push 실패 후 rebase + 재시도로 성공
- [ ] 최악 케이스: 3회 모두 실패 시 워크플로우 실패 처리

---

## 📌 참고사항

### 적용 범위
- **템플릿 저장소 (SUH-DEVOPS-TEMPLATE)**: 이번 수정으로 적용됨
- **기존 프로젝트 (RomRom-FE 등)**: 별도로 워크플로우 파일 업데이트 필요

### 향후 개선 고려사항
- retry 횟수를 환경 변수로 설정 가능하도록 개선
- 실패 시 Slack/Discord 알림 연동 고려
