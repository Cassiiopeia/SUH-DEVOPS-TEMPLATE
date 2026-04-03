# React / React Native 기술 가이드

## 컴포넌트 설계 체크리스트

- [ ] 단일 책임 원칙 (컴포넌트가 한 가지만)
- [ ] Props drilling 문제 (Context API 고려)
- [ ] 재사용 가능성
- [ ] Container vs Presentational 분리

## 상태 관리

- [ ] Local state vs Global state 구분
- [ ] 불필요한 전역 상태
- [ ] 상태 업데이트 불변성 유지
- [ ] useEffect 의존성 배열 올바름
- [ ] 메모리 누수 (cleanup 함수)

## 성능

- [ ] 불필요한 리렌더링 (React.memo, useMemo, useCallback)
- [ ] key prop 올바른 사용 (index 사용 지양)
- [ ] 큰 리스트 가상화 (react-window)
- [ ] 이미지 최적화 (lazy loading, WebP)
- [ ] 번들 크기 (코드 분할)

## 타입 안정성 (TypeScript)

- [ ] any 타입 남발 금지
- [ ] Props 타입 정의
- [ ] Optional chaining / Nullish coalescing 활용
- [ ] 타입 가드 사용

## Hooks

- [ ] 훅 규칙 준수 (최상위에서만 호출)
- [ ] 커스텀 훅 적절성
- [ ] useEffect cleanup 함수
- [ ] useCallback/useMemo 과다 사용 주의

## 테스트 패턴

| 테스트 유형 | 도구 | 용도 |
|------------|------|------|
| 컴포넌트 테스트 | Testing Library | UI 렌더링/인터랙션 |
| Hook 테스트 | renderHook | 커스텀 훅 |
| 비동기 테스트 | waitFor | API 호출 |
| 스냅샷 테스트 | Jest snapshot | UI 변경 감지 |

## React Native 추가

- [ ] Platform-specific 코드 처리
- [ ] FlatList 최적화 (keyExtractor, getItemLayout)
- [ ] 이미지 캐싱
- [ ] Native 모듈 사용 패턴
- [ ] Dimensions 기반 반응형

## 리팩토링 포인트

- **God Component** → 작은 컴포넌트로 분리
- **인라인 로직** → 커스텀 Hook 추출
- **복잡한 삼항** → Early Return 패턴
- **Props drilling** → Context 또는 상태 관리 라이브러리

## 프로젝트 구조 (일반적)

```
src/
├── components/    # 재사용 컴포넌트
├── pages/         # 페이지 컴포넌트
├── hooks/         # 커스텀 훅
├── api/           # API 호출
├── store/         # 상태 관리
├── utils/         # 유틸리티
└── types/         # TypeScript 타입
```
