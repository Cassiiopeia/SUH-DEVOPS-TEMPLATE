# Android Test 빌드 시 PlayStore 빌드 방식과 동일한 키스토어 사용

**이슈**: [#186](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/186)

---

### 📌 작업 개요

Android Test APK 빌드 시 별도의 DEBUG_KEYSTORE를 사용하던 방식을 제거하고, Play Store 배포와 동일한 RELEASE_KEYSTORE를 사용하도록 변경. 관리 포인트 감소 및 빌드 일관성 확보.

---

### 🔍 문제 분석

**기존 방식의 문제점**:
- DEBUG_KEYSTORE와 RELEASE_KEYSTORE 두 가지 키스토어 관리 필요
- 조건 분기 로직으로 코드 복잡성 증가
- Play Store 워크플로우와 패턴 불일치
- ROMROM 프로젝트에는 최신 로직이 적용되어 있었으나 템플릿에는 미적용 상태

---

### ✅ 구현 내용

#### 1. 키스토어 설정 단순화

**파일**: `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml`

**변경 전** (복잡한 조건 로직):
```yaml
- name: Setup Debug Keystore
  run: |
    mkdir -p ~/.android
    if [ -n "${{ secrets.DEBUG_KEYSTORE }}" ]; then
      echo "${{ secrets.DEBUG_KEYSTORE }}" | base64 -d > ~/.android/debug.keystore
    fi

- name: Setup Keystore and key.properties
  run: |
    mkdir -p android/app/keystore
    if [ -n "${{ secrets.DEBUG_KEYSTORE }}" ]; then
      echo "${{ secrets.DEBUG_KEYSTORE }}" | base64 -d > android/app/keystore/key.jks
      echo "storePassword=android" >> android/key.properties
      echo "keyAlias=androiddebugkey" >> android/key.properties
    fi
```

**변경 후** (Play Store 패턴과 동일):
```yaml
- name: Setup Release Keystore
  run: |
    mkdir -p android/keystore
    echo "${{ secrets.RELEASE_KEYSTORE_BASE64 }}" | base64 -d > android/keystore/key.jks
    echo "✅ Release Keystore 생성 완료"
    ls -la android/keystore/

- name: Create key.properties
  run: |
    cat > android/key.properties << EOF
    storeFile=keystore/key.jks
    storePassword=${{ secrets.RELEASE_KEYSTORE_PASSWORD }}
    keyAlias=${{ secrets.RELEASE_KEY_ALIAS }}
    keyPassword=${{ secrets.RELEASE_KEY_PASSWORD }}
    EOF
    echo "✅ key.properties 생성 완료"
```

---

### 🔧 주요 변경사항 상세

#### 제거된 항목
| 항목 | 설명 |
|------|------|
| `Setup Debug Keystore` 스텝 | `~/.android/debug.keystore` 생성 로직 전체 제거 |
| `DEBUG_KEYSTORE` 조건 분기 | if문 조건 처리 로직 제거 |
| debug keystore 관련 key.properties | `storePassword=android`, `keyAlias=androiddebugkey` 등 |

#### 추가된 항목
| 항목 | 설명 |
|------|------|
| `Setup Release Keystore` 스텝 | `android/keystore/key.jks`에 release 키스토어 생성 |
| `Create key.properties` 스텝 | Play Store 워크플로우와 동일한 패턴 |

#### 사용 Secrets 변경
| 변경 전 | 변경 후 |
|---------|---------|
| `DEBUG_KEYSTORE` | `RELEASE_KEYSTORE_BASE64` |
| 하드코딩된 `android` 비밀번호 | `RELEASE_KEYSTORE_PASSWORD` |
| 하드코딩된 `androiddebugkey` alias | `RELEASE_KEY_ALIAS` |
| - | `RELEASE_KEY_PASSWORD` |

---

### 📌 참고사항

- Play Store 워크플로우(`PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml`)와 동일한 패턴 사용
- playstore-wizard에서 생성하는 Secrets와 완전히 호환
- 테스트 APK도 정식 배포용과 동일한 서명으로 빌드되어 일관성 유지
- 기존 `DEBUG_KEYSTORE` Secret은 더 이상 사용하지 않음

---

### 🧪 테스트 및 검증

1. PR에서 `@suh-lab apk build` 댓글로 Android 빌드 트리거
2. RELEASE_KEYSTORE로 정상 서명되는지 확인
3. 빌드된 APK 설치 테스트

---

### 📁 변경된 파일 목록

```
.github/workflows/project-types/flutter/
└── PROJECT-FLUTTER-ANDROID-TEST-APK.yaml  # 키스토어 설정 단순화
```
