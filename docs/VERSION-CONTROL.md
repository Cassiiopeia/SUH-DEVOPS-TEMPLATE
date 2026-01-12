# 버전 관리 시스템

main 브랜치에 푸시하면 patch 버전이 자동으로 증가합니다.

---

## 개요

| 기능 | 설명 |
|------|------|
| **자동 증가** | main 푸시 시 patch 버전 +1 (1.0.0 → 1.0.1) |
| **멀티 파일 동기화** | version.yml ↔ 프로젝트 파일 양방향 동기화 |
| **충돌 해결** | 버전 불일치 시 "높은 버전 우선" 정책 |
| **Git 태그** | 버전 변경 시 자동 태그 생성 |

---

## version.yml

모든 프로젝트의 버전 정보는 `version.yml`에서 중앙 관리됩니다.

```yaml
version: "2.4.3"              # 버전 (자동 관리)
version_code: 94              # 빌드 번호 (자동 증가)
project_type: "spring"        # 프로젝트 타입

metadata:
  last_updated: "2026-01-06 08:23:20"
  last_updated_by: "username"
```

---

## 프로젝트 타입별 버전 파일

| 타입 | 버전 파일 | 버전 위치 |
|------|----------|----------|
| `spring` | `build.gradle` | `version = '1.0.0'` |
| `flutter` | `pubspec.yaml` | `version: 1.0.0+1` |
| `react` | `package.json` | `"version": "1.0.0"` |
| `next` | `package.json` | `"version": "1.0.0"` |
| `node` | `package.json` | `"version": "1.0.0"` |
| `python` | `pyproject.toml` | `version = "1.0.0"` |
| `react-native` | `Info.plist` + `build.gradle` | iOS/Android 분리 |
| `react-native-expo` | `app.json` | `"version": "1.0.0"` |
| `basic` | `version.yml` 만 | - |

---

## version_manager.sh 사용법

### 기본 명령어

```bash
# 현재 버전 확인
.github/scripts/version_manager.sh get

# patch 버전 증가 (1.0.0 → 1.0.1)
.github/scripts/version_manager.sh increment

# 특정 버전으로 설정
.github/scripts/version_manager.sh set 2.0.0

# 버전 동기화 (충돌 해결)
.github/scripts/version_manager.sh sync

# 버전 형식 검증
.github/scripts/version_manager.sh validate 1.2.3
```

### version_code 관리

```bash
# 현재 빌드 번호 확인
.github/scripts/version_manager.sh get-code

# 빌드 번호 증가
.github/scripts/version_manager.sh increment-code
```

---

## 자동화 흐름

```
main 푸시
    │
    ▼
VERSION-CONTROL 워크플로우
    │
    ├─ version.yml 버전 읽기
    ├─ patch 버전 +1
    ├─ 프로젝트 파일 동기화
    ├─ Git 태그 생성 (v1.0.1)
    └─ 커밋 & 푸시
```

---

## 버전 증가 규칙

| 버전 | 변경 방법 | 예시 |
|------|----------|------|
| **patch** | 자동 (main 푸시) | 1.0.0 → 1.0.1 |
| **minor** | 수동 (version.yml 직접 수정) | 1.0.1 → 1.1.0 |
| **major** | 수동 (version.yml 직접 수정) | 1.1.0 → 2.0.0 |

### 수동 버전 변경

```bash
# 1. version.yml 직접 수정
version: "2.0.0"

# 2. 커밋 & 푸시 (자동 동기화됨)
git add version.yml
git commit -m "feat: v2.0.0 major release"
git push
```

---

## 동기화 정책

### 충돌 해결

여러 파일에서 버전이 다를 경우:

```
version.yml: 1.0.5
build.gradle: 1.0.3
```

→ **높은 버전 우선**: 모두 `1.0.5`로 동기화

### 동기화 방향

```
version.yml ←→ 프로젝트 파일
              (양방향)
```

- version.yml 변경 → 프로젝트 파일 업데이트
- 프로젝트 파일 변경 → version.yml 업데이트

---

## 워크플로우

### PROJECT-COMMON-VERSION-CONTROL.yaml

```yaml
on:
  push:
    branches: [main]
    paths-ignore:
      - 'CHANGELOG.md'
      - 'README.md'
```

**트리거 조건**:
- main 브랜치 푸시
- CHANGELOG, README 변경은 제외

**실행 내용**:
1. 현재 버전 확인
2. patch 버전 증가
3. 프로젝트 파일 동기화
4. Git 태그 생성
5. deploy PR 생성

---

## 트러블슈팅

### 버전 동기화 실패

**증상**: 여러 파일의 버전이 불일치

**해결**:
```bash
# 수동 동기화 실행
.github/scripts/version_manager.sh sync
```

### Git 태그 중복

**증상**: 태그가 이미 존재합니다 에러

**해결**:
```bash
# 원격 태그 삭제 후 재생성
git push origin :refs/tags/v1.0.0
git tag -d v1.0.0
```

### 스크립트 권한 오류

**증상**: permission denied

**해결**:
```bash
chmod +x .github/scripts/version_manager.sh
```

---

## 관련 문서

- [체인지로그 자동화](CHANGELOG-AUTOMATION.md)
- [트러블슈팅](TROUBLESHOOTING.md)
