# Flutter 기술 가이드

## Widget 설계 체크리스트

- [ ] StatelessWidget vs StatefulWidget 적절성
- [ ] Widget 트리 깊이 (성능)
- [ ] const 생성자 사용 (rebuild 최적화)
- [ ] BuildContext 올바른 사용
- [ ] Key 사용 여부

## 상태 관리

- [ ] State 관리 패턴 일관성 (Provider/Riverpod/Bloc)
- [ ] 상태 범위 적절성 (전역 vs 로컬)
- [ ] dispose 처리 (메모리 누수)
- [ ] 불필요한 rebuild

## 성능

- [ ] ListView.builder 사용 (대량 데이터)
- [ ] 이미지 캐싱 (cached_network_image)
- [ ] 불필요한 setState 호출
- [ ] Heavy computation을 isolate로

## 코드 스타일

- [ ] Dart 네이밍 규칙 (lowerCamelCase, UpperCamelCase)
- [ ] 파일명 snake_case
- [ ] analysis_options.yaml 린트 룰 준수

## 레이아웃

- [ ] Flexible / Expanded 적절한 사용
- [ ] Padding / Margin 일관성
- [ ] SafeArea 처리
- [ ] MediaQuery 반응형 처리

## 테스트 패턴

| 테스트 유형 | 함수 | 용도 |
|------------|------|------|
| 단위 테스트 | `test()` | 로직 검증 |
| Widget 테스트 | `testWidgets()` | UI 렌더링 |
| 통합 테스트 | `integration_test` | 전체 플로우 |

## 리팩토링 포인트

- **큰 Widget** → private Widget 클래스로 분리 (`_ProfileHeader`)
- **긴 생성자** → Named parameters + copyWith
- **인라인 스타일** → Theme/Extension으로 추출

## 프로젝트 구조 (Clean Architecture)

```
lib/
├── core/           # 상수, 테마, 유틸
├── data/           # 모델, 리포지토리 구현, 데이터소스
├── domain/         # 엔티티, 리포지토리 인터페이스, 유스케이스
├── presentation/   # 화면, 위젯, 프로바이더
└── main.dart
```

## 반응형 크기 변환 (Figma → Flutter)

```dart
// 디자인 기준
const double DESIGN_WIDTH = 375.0;

// Extension 패턴
extension ResponsiveSize on num {
  double get w => (SizeConfig.screenWidth / DESIGN_WIDTH) * this;
  double get h => (SizeConfig.screenHeight / DESIGN_HEIGHT) * this;
  double get sp => (SizeConfig.screenWidth / DESIGN_WIDTH) * this;
}
```
