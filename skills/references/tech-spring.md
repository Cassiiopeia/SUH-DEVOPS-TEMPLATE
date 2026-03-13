# Spring Boot 기술 가이드

## 아키텍처 분석 체크리스트

- [ ] 레이어 구조: Controller → Service → Repository
- [ ] DTO ↔ Entity 변환 위치 및 방식
- [ ] 비즈니스 로직 위치 (Service vs Domain Model)
- [ ] 예외 처리 전략 (@ControllerAdvice, Custom Exception)
- [ ] 패키지 구조: 레이어별 vs 기능별

## 데이터베이스 & JPA

- [ ] Entity 설계 (연관관계, Fetch 전략)
- [ ] N+1 쿼리 문제 가능성
- [ ] @Transactional 위치 및 속성 (readOnly, propagation)
- [ ] LazyInitializationException 가능성
- [ ] 벌크 연산 필요 여부

## API 설계

- [ ] RESTful 원칙 준수 (GET/POST/PUT/DELETE)
- [ ] URL 네이밍 일관성 (복수형, kebab-case)
- [ ] HTTP 상태 코드 적절성
- [ ] 페이징 처리 (Page vs Slice)
- [ ] 에러 응답 구조 일관성

## 보안

- [ ] @PreAuthorize / @Secured 권한 체크
- [ ] SQL Injection 방어 (Prepared Statement)
- [ ] 입력 검증 (@Valid, @Validated)
- [ ] 민감 정보 로깅 여부
- [ ] CORS 설정

## 구현 체크리스트

### Controller
- [ ] @RestController 또는 @Controller (기존 패턴)
- [ ] @RequestMapping 경로 일관성
- [ ] DTO 검증 (@Valid, @Validated)
- [ ] 응답 형식: ResponseEntity vs 직접 반환

### Service
- [ ] 인터페이스 분리 여부 (기존 패턴)
- [ ] @Transactional 위치 및 속성
- [ ] DTO ↔ Entity 변환 위치

### Repository
- [ ] JPA Repository 메서드 네이밍 (find vs get)
- [ ] 쿼리 메서드 vs @Query
- [ ] Fetch Join 필요 여부

### DTO/Entity
- [ ] Lombok 어노테이션 패턴
- [ ] Builder 패턴 사용 여부
- [ ] 검증 어노테이션 (@NotNull, @Size 등)

## 테스트 패턴

| 테스트 유형 | 어노테이션 | 용도 |
|------------|-----------|------|
| 단위 테스트 | `@ExtendWith(MockitoExtension.class)` | Service 로직 |
| Controller 테스트 | `@WebMvcTest` | API 엔드포인트 |
| Repository 테스트 | `@DataJpaTest` | JPA 쿼리 |
| 통합 테스트 | `@SpringBootTest` | 전체 플로우 |

## 리팩토링 포인트

- **God Service** → 책임별 Service 분리
- **Controller 내 변환** → Mapper 클래스로 분리
- **복잡한 쿼리 메서드명** → Specification 또는 QueryDSL
- **긴 파라미터** → Request DTO로 통합
