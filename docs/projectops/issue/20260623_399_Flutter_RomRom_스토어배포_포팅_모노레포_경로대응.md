📝 현재 문제점

Flutter 스토어 배포 워크플로우·마법사에 두 가지 구조적 문제가 있다.

(A) RomRom-FE에서 실측 검증된 배포 개선이 템플릿에 반영되지 않음
- iOS는 App Store 정식 심사 자동 제출이 없어 TestFlight 업로드까지만 된다(이후 수동 제출 필요).
- Android는 production 승급 시 fastlane supply 기본값(rescue_changes_not_sent_for_review: true)이 심사 미전송을 자동 rescue해 **저장만 하고 success를 반환하는 "거짓 성공"**이 발생한다.
- iOS Fastfile이 워크플로우 안 heredoc으로 동적 생성돼, 마법사가 깐 Fastfile과 중복·불일치된다(lane명도 deploy vs deploy_appstore로 다름). 마법사가 깐 파일은 실제 배포에서 무시된다.
- 배포 모드가 플랫폼마다 제각각이라 "어디까지 배포되는지"가 불명확하다.

(B) 모노레포에서 CICD가 전부 깨짐 (passQL로 실측)
- Flutter 루트가 레포 루트의 서브폴더(예: app/)인 모노레포에서, 마법사는 PROJECT_PATH 인자로 올바른 위치에 깔지만 CICD 워크플로우가 cd ios·working-directory: ios로 레포 루트 기준 하드코딩이라 빌드·배포 step이 전부 실패한다.

🛠️ 해결 방안 / 제안 기능

RomRom-FE(실측 success 운영본)에서 검증된 배포 로직을 템플릿에 포팅하고, 모노레포 경로를 대응한다.

(A) RomRom 검증 배포 로직 포팅
- iOS: deliver submit_for_review로 App Store 심사 자동 제출(메타·스크린샷 보호, What's New만 갱신).
- Android: rescue_changes_not_sent_for_review: false + track_promote_release_status로 거짓 성공 제거.
- 배포 모드 3단계 통일: store_only / store_prepare / store_submit (+ iOS 하위호환 별칭 testflight_only/appstore_*). 우선순위는 workflow_dispatch input → repo variable → 폴백.
- iOS Fastfile을 워크플로우 heredoc에서 Android와 동일한 파일 템플릿 방식(Fastfile.ios.template)으로 통일 → 배포 로직 일원화, 마법사·운영 일치.
- 마법사 완료 단계에 배포 모드·출시 로드맵 안내카드 추가.

(B) 모노레포 경로 대응
- 워크플로우 상단에 env: FLUTTER_ROOT를 두고, integrator 통합 시점에 project_paths.flutter 값으로 1회 치환(런타임 version.yml 읽기 없음).
- 빌드/배포 job에 defaults.run.working-directory: FLUTTER_ROOT를 두고, working-directory가 안 먹는 곳(artifact path·절대경로)만 개별 변수화.
- 선행 작업인 wizard 마커 재설계(#406, 완료) 위에 auto:flutter-root resolver 하나만 추가. 기본값 .이면 단일레포 동작 100% 보존.

⚙️ 작업 내용

- iOS Fastfile → Fastfile.ios.template 개명 + deploy 통합 lane(deliver·whatsNew·Notes 초기화) 작성
- Android Fastfile.playstore.template에 거짓 성공 제거 옵션 반영
- PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml heredoc 폐기 + 파일 템플릿 복사 + deploy_mode input + fastlane deploy 호출
- PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml deploy_mode input + DEPLOY_MODE env 전달
- testflight-wizard-setup.sh·playstore-wizard 마법사 안내카드·템플릿 참조 경로 동기화(.sh/.ps1 동등)
- template_integrator.sh/.ps1에 resolve_flutter_root/Resolve-FlutterRoot resolver + 워크플로우 FLUTTER_ROOT 마커
- 두 워크플로우 경로 변수화(iOS 23곳·Android 24곳)

---

▎ 범위 정리: 이 이슈는 기존 "심사 제출 자동화"(본 #399 좁은 범위)를 흡수해 더 넓은 포팅+모노레포 본체로 확장한 것이다.
▎ 선행 의존: #406(wizard 마커 재설계, 완료).
▎ 검증 기준 레포: RomRom-FE(실측 success). passQL은 템플릿 실험 프로젝트라 신뢰 기준이 아니다.
▎ 정본 설계 스펙: docs/superpowers/specs/2026-06-22-romrom-store-deploy-port-to-template-design.md
▎ 흡수 스펙: docs/superpowers/specs/2026-06-19-flutter-store-review-submit-automation-design.md (진부분집합, superseded)

🙋‍담당자

- 백엔드: Cassiiopeia
- 프론트엔드:
- 디자인:
