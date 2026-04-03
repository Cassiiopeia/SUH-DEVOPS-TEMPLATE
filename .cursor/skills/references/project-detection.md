# 프로젝트 타입 자동 감지

프로젝트 루트의 파일 존재 여부로 타입을 판별한다.

## 감지 규칙

| 타입 | 필수 파일 | 보조 확인 |
|------|----------|----------|
| **Spring Boot** | `pom.xml` 또는 `build.gradle` / `build.gradle.kts` | `src/main/java/`, Spring 의존성 |
| **React** | `package.json` + `react` 의존성 | `src/` 또는 `app/`, `tsconfig.json` |
| **React Native** | `package.json` + `react-native` 의존성 | `android/`, `ios/` 디렉토리 |
| **React Native Expo** | `package.json` + `expo` 의존성 | `app.json`의 `expo` 키, `android/`·`ios/` 없을 수 있음 |
| **Flutter** | `pubspec.yaml` | `lib/` 디렉토리 |
| **Next.js** | `package.json` + `next` 의존성 | `next.config.js` |
| **Node.js** | `package.json` (프레임워크 없음) | `express`, `fastify` 등 |
| **Python** | `pyproject.toml` 또는 `requirements.txt` | `manage.py` (Django), `main.py` (FastAPI) |
| **basic** | 위 어떤 타입에도 해당하지 않음 | `version.yml`만 존재 |

## 감지 순서

> **React Native vs Expo 구분**: `expo` 의존성이 있으면 Expo, `react-native`만 있으면 React Native CLI

1. 루트 파일 확인 → 타입 판별
2. 의존성/설정 파일에서 프레임워크 버전 확인
3. 디렉토리 구조로 아키텍처 패턴 파악

## 감지 실패 시

어떤 타입에도 맞지 않으면 `basic` 타입으로 간주하고 범용 규칙을 적용한다.

## 감지 후 출력

```
**감지된 프로젝트 타입**: [타입명]
**주요 기술 스택**: [프레임워크 버전, 언어 버전 등]
```
