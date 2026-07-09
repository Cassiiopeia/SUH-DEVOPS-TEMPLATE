# Issue #144: ENV/ENV_FILE GitHub Secret 키 통일화 및 Fallback 지원

## 📌 작업 개요

GitHub Actions 워크플로우에서 환경변수 파일 생성 시 사용하는 Secret 키 (`secrets.ENV`, `secrets.ENV_FILE`)를 통일화하고, 하위 호환성을 위해 양쪽 모두 지원하는 fallback 로직 적용

**보고서 파일**: `.report/20260112_#144_ENV_ENV_FILE_통일화_fallback_지원.md`

---

## 🎯 구현 목표

- 기존 `secrets.ENV` 사용 프로젝트와 `secrets.ENV_FILE` 사용 프로젝트 모두 정상 동작하도록 지원
- 새 프로젝트는 `ENV_FILE`을 권장하되, 기존 `ENV` 사용 프로젝트도 마이그레이션 없이 동작
- GitHub Actions 표현식의 `||` 연산자를 활용한 fallback 패턴 적용

---

## ✅ 구현 내용

### 변경 패턴

**Before:**
```yaml
${{ secrets.ENV_FILE }}
```

**After:**
```yaml
${{ secrets.ENV_FILE || secrets.ENV }}
```

**동작 방식:**
- `ENV_FILE` Secret이 있으면 → `ENV_FILE` 사용
- `ENV_FILE` Secret이 없으면 → `ENV` 사용 (fallback)
- 둘 다 없으면 → 빈 값

---

### 수정된 워크플로우 파일 (7개)

#### 1. React CI 워크플로우
- **파일**: `.github/workflows/project-types/react/PROJECT-REACT-CI.yaml`
- **변경 내용**:
  - 주석: `ENV_FILE` → `ENV_FILE (또는 ENV)`
  - 코드: `secrets.ENV_FILE` → `secrets.ENV_FILE || secrets.ENV`
- **위치**: 라인 15 (주석), 라인 48 (코드)

#### 2. React CICD 워크플로우
- **파일**: `.github/workflows/project-types/react/PROJECT-REACT-CICD.yaml`
- **변경 내용**:
  - 주석: `ENV_FILE` → `ENV_FILE (또는 ENV)`
  - 코드: `secrets.ENV_FILE` → `secrets.ENV_FILE || secrets.ENV`
- **위치**: 라인 15 (주석), 라인 63 (코드)

#### 3. Next.js CI 워크플로우
- **파일**: `.github/workflows/project-types/next/PROJECT-NEXT-CI.yaml`
- **변경 내용**:
  - 주석: `ENV_FILE` → `ENV_FILE (또는 ENV)`
  - 코드: `secrets.ENV_FILE` → `secrets.ENV_FILE || secrets.ENV`
- **위치**: 라인 20 (주석), 라인 53 (코드)

#### 4. Next.js CICD 워크플로우
- **파일**: `.github/workflows/project-types/next/PROJECT-NEXT-CICD.yaml`
- **변경 내용**:
  - 주석: `ENV_FILE` → `ENV_FILE (또는 ENV)`
  - 코드: `secrets.ENV_FILE` → `secrets.ENV_FILE || secrets.ENV`
- **위치**: 라인 23 (주석), 라인 71 (코드)

#### 5. Flutter Android 테스트 APK 워크플로우
- **파일**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`
- **변경 내용**:
  - 주석: `ENV_FILE` → `ENV_FILE (또는 ENV)`
  - 코드: `secrets.ENV_FILE` → `secrets.ENV_FILE || secrets.ENV`
- **위치**: 라인 28 (주석), 라인 194 (코드)

#### 6. Flutter iOS TestFlight 워크플로우
- **파일**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml`
- **변경 내용**:
  - 주석: `ENV_FILE` → `ENV_FILE (또는 ENV)`
  - 코드 2곳: `secrets.ENV_FILE` → `secrets.ENV_FILE || secrets.ENV`
- **위치**: 라인 35 (주석), 라인 115, 243 (코드)

#### 7. Flutter iOS 테스트 TestFlight 워크플로우
- **파일**: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`
- **변경 내용**:
  - 주석: `ENV_FILE` → `ENV_FILE (또는 ENV)`
  - 코드 2곳: `secrets.ENV_FILE` → `secrets.ENV_FILE || secrets.ENV`
- **위치**: 라인 42 (주석), 라인 94, 269 (코드)

---

### 수정된 문서 파일 (1개)

#### Flutter 테스트 빌드 트리거 가이드
- **파일**: `docs/FLUTTER-TEST-BUILD-TRIGGER.md`
- **변경 내용**:
  - Android 빌드용: `ENV_FILE (선택)` → `ENV_FILE 또는 ENV (선택)`
  - iOS 빌드용: `ENV_FILE (선택)` → `ENV_FILE 또는 ENV (선택)`
- **위치**: 라인 217, 227

---

## 🔧 주요 변경사항 상세

### Fallback 패턴 적용

GitHub Actions 표현식에서 `||` 연산자를 사용하여 fallback 구현:

```yaml
# echo 방식 (React CI, Next.js CI)
echo -e "${{ secrets.ENV_FILE || secrets.ENV }}" > ${{ env.ENV_FILE }}

# cat EOF 방식 (React CICD, Next.js CICD, Flutter)
cat << 'EOF' > ${{ env.ENV_FILE_PATH }}
${{ secrets.ENV_FILE || secrets.ENV }}
EOF
```

**특이사항**:
- `||` 연산자는 앞의 값이 비어있거나 undefined일 때 뒤의 값을 사용
- 두 가지 환경변수 파일 생성 방식(echo, cat EOF) 모두에 동일하게 적용

### 변경되지 않은 파일 (이미 ENV_FILE 사용 중)

다음 파일들은 이미 `ENV_FILE`을 사용하고 있어 변경 불필요:
- `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`
- `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml`

---

## 📊 검증 결과

### Fallback 패턴 적용 확인
```
secrets.ENV_FILE || secrets.ENV 사용 위치: 9곳
- React CI: 1곳
- React CICD: 1곳
- Next.js CI: 1곳
- Next.js CICD: 1곳
- Flutter Android Test APK: 1곳
- Flutter iOS TestFlight: 2곳
- Flutter iOS Test TestFlight: 2곳
```

### 단독 secrets.ENV 사용
```
단독 secrets.ENV 사용: 0곳 (모두 fallback 패턴 내에서만 사용)
```

---

## 🧪 테스트 시나리오

| 시나리오 | ENV_FILE | ENV | 결과 |
|---------|----------|-----|------|
| 1. 신규 프로젝트 | ✅ 설정 | ❌ 없음 | ENV_FILE 사용 |
| 2. 기존 프로젝트 | ❌ 없음 | ✅ 설정 | ENV 사용 (fallback) |
| 3. 둘 다 설정 | ✅ 설정 | ✅ 설정 | ENV_FILE 우선 사용 |
| 4. 둘 다 없음 | ❌ 없음 | ❌ 없음 | 빈 .env 파일 생성 |

---

## 📌 참고사항

### 사용자 가이드
- **신규 프로젝트**: `ENV_FILE` Secret 사용 권장
- **기존 프로젝트**: 기존 `ENV` Secret 그대로 사용 가능 (마이그레이션 불필요)
- **마이그레이션 희망 시**: GitHub Repository Settings → Secrets에서 `ENV`를 `ENV_FILE`로 변경

### 영향 범위
- 워크플로우 파일: 7개 수정
- 문서 파일: 1개 수정
- 총 변경 파일: 8개
- 하위 호환성: 100% 유지

---

## 📝 커밋 메시지 제안

```
ENV, ENV_FILE 에 대한 github secret 키 통일화 필요 : feat : ENV_FILE || ENV fallback 패턴 적용으로 양쪽 모두 지원 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/144
```
