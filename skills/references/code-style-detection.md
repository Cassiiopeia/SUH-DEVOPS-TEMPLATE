# 코드 스타일 자동 감지

기존 코드 3-5개를 샘플링하여 프로젝트의 스타일 패턴을 파악한다.
감지된 스타일을 100% 준수하며, 새로운 "더 나은" 방식을 제안하지 않는다.

## Spring Boot

| 항목 | 확인 사항 |
|------|----------|
| **네이밍** | `UserDto` vs `UserDTO` vs `UserRequest`/`UserResponse` |
| **서비스** | 인터페이스+구현체 vs 클래스만 |
| **DI** | `@Autowired` vs `@RequiredArgsConstructor` |
| **Lombok** | `@Data` vs 개별 `@Getter/@Setter` |
| **메서드명** | `getUser` vs `findUser` vs `retrieveUser` |
| **패키지** | 레이어별 (`controller/service`) vs 기능별 (`user/order`) |
| **반환 타입** | `ResponseEntity` vs 직접 반환 |
| **예외 처리** | `@ControllerAdvice` + 커스텀 예외 패턴 |
| **빌더** | Builder 패턴 사용 여부 |

## React / React Native

| 항목 | 확인 사항 |
|------|----------|
| **컴포넌트** | `function Component()` vs `const Component = () => {}` |
| **Props 타입** | `interface` vs `type` |
| **Export** | `export default` vs named export |
| **파일명** | `PascalCase.tsx` vs `kebab-case.tsx` |
| **Import 순서** | 그룹화 패턴 |
| **Hook 네이밍** | `use-` prefix 규칙 |
| **스타일링** | CSS Modules / Styled Components / Tailwind / Emotion |
| **State 관리** | Context / Redux / Zustand / Recoil |
| **린터** | `.eslintrc`, `.prettierrc` 룰 |

### React Native 추가

| 항목 | 확인 사항 |
|------|----------|
| **StyleSheet** | `StyleSheet.create` 사용 패턴 |
| **Platform** | Platform-specific 코드 분기 방식 |
| **FlatList** | keyExtractor, getItemLayout 패턴 |

### React Native Expo 추가

| 항목 | 확인 사항 |
|------|----------|
| **라우팅** | `expo-router` vs `react-navigation` |
| **설정** | `app.json` / `app.config.js` 패턴 |
| **SDK** | Expo SDK 버전별 API 사용 패턴 |

## Flutter

| 항목 | 확인 사항 |
|------|----------|
| **파일명** | snake_case 확인 |
| **Widget** | StatelessWidget vs StatefulWidget 패턴 |
| **State 관리** | Provider / Riverpod / Bloc / GetX |
| **const** | const 생성자 사용 여부 |
| **구조** | feature-first vs layer-first |
| **린트** | `analysis_options.yaml` 룰 |

## Next.js

위 **React / React Native** 섹션의 모든 항목 포함 + 추가:

| 항목 | 확인 사항 |
|------|----------|
| **라우팅** | App Router vs Pages Router |
| **데이터 패칭** | Server Component / `getServerSideProps` / `fetch` 캐시 |
| **레이아웃** | `layout.tsx` 중첩 패턴 |

## Node.js / Python

| 항목 | 확인 사항 |
|------|----------|
| **프로젝트 구조** | 레이어별 vs 기능별 |
| **네이밍** | camelCase(Node) / snake_case(Python) |
| **에러 처리** | 미들웨어 / Exception handler 패턴 |
| **린터** | ESLint(Node) / ruff, black(Python) |

## 스타일 적용 원칙

1. **일관성 > 베스트 프랙티스** — 팀 컨벤션이 최우선
2. **감지된 패턴 100% 준수** — 변수명, 메서드명, import 순서까지 동일하게
3. **새 방식 제안 금지** — 명시적 요청 시에만 대안 제시
