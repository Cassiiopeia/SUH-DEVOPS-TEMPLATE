# Suh Spring Test Generator

Spring Boot 프로젝트용 샘플 테스트 코드를 생성합니다.

## 사용법

```
/suh-spring-test                    # 현재 파일 기준 테스트 생성
/suh-spring-test UserService        # UserService에 대한 테스트 생성
/suh-spring-test @파일경로          # 특정 파일에 대한 테스트 생성
```

## 동작 방식

### 1단계: 의존성 확인

`build.gradle` 또는 `pom.xml`에서 다음을 확인:
- [ ] `me.suhsaechan:suh-logger` 의존성 존재 여부
- [ ] 멀티모듈 프로젝트 여부 (`settings.gradle`의 `include` 확인)
- [ ] `testImplementation project(':상위모듈')` 존재 여부

### 2단계: Application 클래스 탐색 (멀티모듈인 경우)

- [ ] `@SpringBootApplication` 어노테이션이 붙은 클래스 찾기
- [ ] 해당 클래스의 FQCN(Fully Qualified Class Name) 확인

### 3단계: 테스트 파일 생성

대상 클래스와 동일한 패키지 구조로 `src/test/java/` 하위에 테스트 파일 생성

---

## 템플릿

### 템플릿 A: suh-logger 의존성 있을 때

```java
package {{PACKAGE}};

import static me.suhsaechan.suhlogger.util.SuhLogger.lineLog;
import static me.suhsaechan.suhlogger.util.SuhLogger.superLog;
import static me.suhsaechan.suhlogger.util.SuhLogger.timeLog;

import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
{{ADDITIONAL_IMPORTS}}

@SpringBootTest{{BOOT_CLASS}}
@ActiveProfiles("dev")
@Slf4j
class {{CLASS_NAME}}Test {

  {{AUTOWIRED_FIELDS}}

  @Test
  public void mainTest() {
    lineLog("테스트시작");

    lineLog(null);
    timeLog(this::{{TEST_METHOD_NAME}}_테스트);
    lineLog(null);

    lineLog("테스트종료");
  }

  public void {{TEST_METHOD_NAME}}_테스트() {
    // TODO: 테스트 로직 작성
    lineLog("테스트 실행중");
  }
}
```

### 템플릿 B: suh-logger 의존성 없을 때

```java
package {{PACKAGE}};

import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
{{ADDITIONAL_IMPORTS}}

@SpringBootTest{{BOOT_CLASS}}
@ActiveProfiles("dev")
@Slf4j
class {{CLASS_NAME}}Test {

  {{AUTOWIRED_FIELDS}}

  @Test
  public void mainTest() {
    log.info("============ 테스트시작 ============");

    {{TEST_METHOD_NAME}}_테스트();

    log.info("============ 테스트종료 ============");
  }

  public void {{TEST_METHOD_NAME}}_테스트() {
    // TODO: 테스트 로직 작성
    log.info("테스트 실행중");
  }
}
```

---

## 플레이스홀더 설명

| 플레이스홀더 | 설명 | 예시 |
|-------------|------|------|
| `{{PACKAGE}}` | 테스트 클래스 패키지 | `com.example.service` |
| `{{CLASS_NAME}}` | 테스트 대상 클래스명 | `UserService` |
| `{{TEST_METHOD_NAME}}` | 테스트 메서드명 (소문자) | `userService` |
| `{{BOOT_CLASS}}` | 멀티모듈 시 Application 클래스 지정 | `(classes = MyApplication.class)` |
| `{{ADDITIONAL_IMPORTS}}` | 추가 import 문 | `import com.example.MyApplication;` |
| `{{AUTOWIRED_FIELDS}}` | 주입할 필드 | `@Autowired\n  UserService userService;` |

---

## 실행 체크리스트

실행 시 다음 순서로 진행:

1. **의존성 확인**
   - [ ] `build.gradle` 또는 `pom.xml` 읽기
   - [ ] `me.suhsaechan:suh-logger` 의존성 확인
   - [ ] 의존성 유무에 따라 템플릿 A 또는 B 선택

2. **프로젝트 구조 확인**
   - [ ] `settings.gradle` 확인하여 멀티모듈 여부 판단
   - [ ] 멀티모듈인 경우 `@SpringBootApplication` 클래스 위치 파악
   - [ ] 테스트 모듈에서 `testImplementation project(':상위모듈')` 확인

3. **테스트 대상 파악**
   - [ ] 인자로 전달된 클래스명 또는 파일 경로 분석
   - [ ] 대상 클래스의 패키지 구조 파악
   - [ ] 주입할 필드 결정

4. **테스트 파일 생성**
   - [ ] `src/test/java/{{패키지 경로}}/{{클래스명}}Test.java` 생성
   - [ ] 플레이스홀더 치환
   - [ ] 파일 작성

---

## 예시

### 입력
```
/suh-spring-test UserService
```

### suh-logger 있을 때 출력
```java
package com.example.service;

import static me.suhsaechan.suhlogger.util.SuhLogger.lineLog;
import static me.suhsaechan.suhlogger.util.SuhLogger.superLog;
import static me.suhsaechan.suhlogger.util.SuhLogger.timeLog;

import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("dev")
@Slf4j
class UserServiceTest {

  @Autowired
  UserService userService;

  @Test
  public void mainTest() {
    lineLog("테스트시작");

    lineLog(null);
    timeLog(this::userService_테스트);
    lineLog(null);

    lineLog("테스트종료");
  }

  public void userService_테스트() {
    // TODO: 테스트 로직 작성
    lineLog("테스트 실행중");
  }
}
```

### suh-logger 없을 때 출력
```java
package com.example.service;

import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("dev")
@Slf4j
class UserServiceTest {

  @Autowired
  UserService userService;

  @Test
  public void mainTest() {
    log.info("============ 테스트시작 ============");

    userService_테스트();

    log.info("============ 테스트종료 ============");
  }

  public void userService_테스트() {
    // TODO: 테스트 로직 작성
    log.info("테스트 실행중");
  }
}
```

### 멀티모듈 프로젝트 예시
```java
package com.tripgether.sns;

import static me.suhsaechan.suhlogger.util.SuhLogger.lineLog;
import static me.suhsaechan.suhlogger.util.SuhLogger.timeLog;

import com.tripgether.web.TripgetherApplication;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(classes = TripgetherApplication.class)
@ActiveProfiles("dev")
@Slf4j
class SnsServiceTest {

  @Autowired
  SnsService snsService;

  @Test
  public void mainTest() {
    lineLog("테스트시작");

    lineLog(null);
    timeLog(this::snsService_테스트);
    lineLog(null);

    lineLog("테스트종료");
  }

  public void snsService_테스트() {
    // TODO: 테스트 로직 작성
    lineLog("테스트 실행중");
  }
}
```

---

## 주의사항

- `application-dev.yml` 또는 `application-dev.properties`가 `src/test/resources/`에 필요
- dev 프로파일에 테스트용 설정 (DB, API 키 등) 구성 필요
- 멀티모듈 프로젝트에서는 상위 모듈 의존성 확인 필수

ARGUMENTS: $ARGUMENTS
