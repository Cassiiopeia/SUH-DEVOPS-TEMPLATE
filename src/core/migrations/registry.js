// 레거시 마이그레이션 단일 레지스트리 (#470) — 유일한 관리 지점.
//
// ⚠️ 템플릿에서 워크플로우/루트 파일을 리네임·폐기하면 반드시 여기에 구 이름을 한 줄 추가한다.
//    (test/migrations.test.js가 "레지스트리 항목이 현행 배포 세트와 겹치지 않는지" 자동 검증)
//
// 항목 스키마:
//   id         - 고유 식별자 (kebab-case)
//   category   - "workflow" | "root-file" | "legacy-dir"  (rules/ 폴더의 구현이 detect/apply 담당)
//   tier       - "safe"    : 신형이 같은 기능을 대체(순수 리네임). 공존 시 이중 트리거 실해
//                            → 확인 1회 후 자동 무해화(.bak) / 삭제
//                "confirm" : 배포 파이프라인일 수 있음(그 레포의 유일한 현역 배포 가능성)
//                            → 자동으로 건드리지 않고 안내만. --force에서도 불변
//                "ask"     : 사용자 콘텐츠가 담긴 폴더 등 — 손실 없는 이동이지만 사용자 소유물 (#476)
//                            → 대화형: 확인 후 이동 / 비대화형: 자동 조치 없이 안내만
//   file       - 정확한 파일명 (글롭 금지 — 사용자 커스텀 보호의 핵심)
//   replacedBy - 대체 신형 파일명 (없으면 null)
//   since      - 구 파일이 폐기된 템플릿 버전(참고용)
//   reason     - 계획 카드에 표시할 사유
//   contentMarker - (선택) 파일명이 범용적일 때 오탐 방지용 내용 마커 — 이 문자열이
//                   파일 내용에 있을 때만 템플릿 소유로 판정
//
// 데이터 출처: git 히스토리 삭제/리네임 전수 + 실제 통합 레포 14개 스캔 (2026-07-11, 설계 문서 참조)
export const MIGRATIONS = [
  // ── workflow / safe — 순수 리네임·대체 (공존 시 중복 실행 실해) ──────────────
  { id: "wf-version-control", category: "workflow", tier: "safe",
    file: "PROJECT-VERSION-CONTROL.yaml", replacedBy: "PROJECT-COMMON-VERSION-CONTROL.yaml",
    since: "2.x", reason: "1세대 리네임 — 공존 시 버전 이중 증가" },
  { id: "wf-readme-version-update", category: "workflow", tier: "safe",
    file: "PROJECT-README-VERSION-UPDATE.yaml", replacedBy: "PROJECT-COMMON-README-VERSION-UPDATE.yaml",
    since: "2.x", reason: "1세대 리네임 — 공존 시 README 이중 커밋" },
  { id: "wf-sync-issue-labels-v1", category: "workflow", tier: "safe",
    file: "PROJECT-SYNC-ISSUE-LABELS.yaml", replacedBy: "PROJECT-COMMON-SYNC-ISSUE-LABELS.yaml",
    since: "2.x", reason: "1세대 리네임 — 공존 시 라벨 동기화 중복" },
  { id: "wf-sync-issue-labels-v0", category: "workflow", tier: "safe",
    file: "sync-issue-labels.yaml", replacedBy: "PROJECT-COMMON-SYNC-ISSUE-LABELS.yaml",
    since: "2.x", reason: "0세대 리네임 — 공존 시 라벨 동기화 중복" },
  { id: "wf-issue-comment-v1", category: "workflow", tier: "safe",
    file: "PROJECT-ISSUE-COMMENT.yaml", replacedBy: "PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml",
    since: "2.x", reason: "이슈 헬퍼 1세대 — 공존 시 이슈 댓글 중복" },
  { id: "wf-issue-comment-v2", category: "workflow", tier: "safe",
    file: "PROJECT-COMMON-ISSUE-COMMENT.yaml", replacedBy: "PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml",
    since: "2.x", reason: "이슈 헬퍼 2세대 — 공존 시 이슈 댓글 중복" },
  { id: "wf-auto-changelog-v1", category: "workflow", tier: "safe",
    file: "PROJECT-AUTO-CHANGELOG-CONTROL.yaml", replacedBy: "PROJECT-COMMON-RELEASE-CHANGELOG.yaml",
    since: "2.x", reason: "릴리스 워크플로우 1세대 — 공존 시 릴리스 PR 이중 처리" },
  { id: "wf-auto-changelog-v2", category: "workflow", tier: "safe",
    file: "PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml", replacedBy: "PROJECT-COMMON-RELEASE-CHANGELOG.yaml",
    since: "4.3.0", reason: "RELEASE-CHANGELOG로 리네임 — 공존 시 릴리스 PR 이중 처리" },
  { id: "wf-comqa-bot", category: "workflow", tier: "safe",
    file: "COMQA-ISSUE-CREATION-BOT.yaml", replacedBy: "PROJECT-COMMON-QA-ISSUE-CREATION-BOT.yaml",
    since: "2.x", reason: "QA 봇 구명칭 — 공존 시 QA 이슈 중복 생성" },
  { id: "wf-template-util-sync", category: "workflow", tier: "safe",
    file: "TEMPLATE-UTIL-VERSION-SYNC.yml", replacedBy: "PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml",
    since: "2.x", reason: "구명칭 — 공존 시 util 버전 동기화 중복" },
  { id: "wf-backlog-manager", category: "workflow", tier: "safe",
    file: "PROJECT-COMMON-PROJECT-BACKLOG-MANAGER.yaml", replacedBy: "PROJECT-COMMON-PROJECTS-SYNC-MANAGER.yaml",
    since: "3.x", reason: "Projects 동기화로 대체 — 공존 시 보드 상태 중복 갱신" },
  { id: "wf-suh-lab-build-trigger", category: "workflow", tier: "safe",
    file: "PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER.yaml", replacedBy: "PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml",
    since: "4.3.0", reason: "리브랜딩 리네임 — 공존 시 빌드 트리거 중복" },
  { id: "wf-next-ci", category: "workflow", tier: "safe",
    file: "PROJECT-NEXT-CI.yaml", replacedBy: "PROJECT-REACT-CI.yaml",
    since: "4.1.0", reason: "next 타입 폐지 (react 흡수)" },
  { id: "wf-next-cicd", category: "workflow", tier: "safe",
    file: "PROJECT-NEXT-CICD.yaml", replacedBy: "PROJECT-REACT-CICD.yaml",
    since: "4.1.0", reason: "next 타입 폐지 (react 흡수)" },
  { id: "wf-flutter-ci-yml-ext", category: "workflow", tier: "safe",
    file: "PROJECT-FLUTTER-CI.yml", replacedBy: "PROJECT-FLUTTER-CI.yaml",
    since: "2.x", reason: "구 확장자(.yml) — 현행 .yaml과 공존 시 CI 중복 실행" },
  { id: "wf-flutter-android-pr-ci", category: "workflow", tier: "safe",
    file: "PROJECT-FLUTTER-ANDROID-PR-CI.yaml", replacedBy: "PROJECT-FLUTTER-CI.yaml",
    since: "3.x", reason: "통합 CI로 흡수 — 공존 시 PR CI 중복 실행" },

  // ── workflow / confirm — 배포/업로드 계열 (현역 배포일 수 있어 자동 조치 금지) ──
  { id: "wf-syn-spring-simple", category: "workflow", tier: "confirm",
    file: "PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml", replacedBy: "PROJECT-SPRING-SIMPLE-CICD.yaml",
    since: "3.0.137", reason: "SYNOLOGY 폐기 — SSH+Docker 엔진으로 대체됨" },
  { id: "wf-syn-spring-nonstop", category: "workflow", tier: "confirm",
    file: "PROJECT-SPRING-SYNOLOGY-NONSTOP-CICD.yaml", replacedBy: "PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml",
    since: "3.0.137", reason: "SYNOLOGY 폐기 — 무중단 배포는 NGINX/TRAEFIK 버전으로 대체됨" },
  { id: "wf-syn-spring-preview", category: "workflow", tier: "confirm",
    file: "PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml", replacedBy: "PROJECT-SPRING-PR-PREVIEW.yaml",
    since: "3.0.137", reason: "SYNOLOGY 폐기" },
  { id: "wf-syn-flutter-android", category: "workflow", tier: "confirm",
    file: "PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml", replacedBy: "PROJECT-FLUTTER-ANDROID-SELFHOSTED-CICD.yaml",
    since: "3.0.137", reason: "SYNOLOGY 폐기 — SELFHOSTED(SMB)로 대체됨" },
  { id: "wf-syn-python-cicd", category: "workflow", tier: "confirm",
    file: "PROJECT-PYTHON-SYNOLOGY-CICD.yaml", replacedBy: "PROJECT-PYTHON-SIMPLE-CICD.yaml",
    since: "3.0.137", reason: "SYNOLOGY 폐기" },
  { id: "wf-syn-python-preview", category: "workflow", tier: "confirm",
    file: "PROJECT-PYTHON-SYNOLOGY-PR-PREVIEW.yaml", replacedBy: "PROJECT-PYTHON-PR-PREVIEW.yaml",
    since: "3.0.137", reason: "SYNOLOGY 폐기" },
  { id: "wf-syn-secret-upload", category: "workflow", tier: "confirm",
    file: "PROJECT-COMMON-SYNOLOGY-SECRET-FILE-UPLOAD.yaml", replacedBy: "PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml",
    since: "3.0.137", reason: "SYNOLOGY 폐기 — 공통 Secret 업로드로 대체됨" },
  { id: "wf-spring-ci-v1", category: "workflow", tier: "confirm",
    file: "PROJECT-SPRING-CI.yaml", replacedBy: null,
    since: "2.x", reason: "1세대 Spring CI — 현행 대체본 없음(CICD에 통합)" },
  { id: "wf-spring-cicd-v1", category: "workflow", tier: "confirm",
    file: "PROJECT-SPRING-CICD.yaml", replacedBy: "PROJECT-SPRING-SIMPLE-CICD.yaml",
    since: "2.x", reason: "1세대 Spring 배포 — 현역 배포일 수 있음" },
  { id: "wf-python-cicd-v1", category: "workflow", tier: "confirm",
    file: "PROJECT-PYTHON-CICD.yaml", replacedBy: "PROJECT-PYTHON-SIMPLE-CICD.yaml",
    since: "3.x", reason: "구 Python 배포 — 현역 배포일 수 있음" },
  { id: "wf-android-cicd-v1", category: "workflow", tier: "confirm",
    file: "PROJECT-ANDROID-CICD.yaml", replacedBy: "PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml",
    since: "2.x", reason: "1세대 Android 배포 — 현역 배포일 수 있음" },
  { id: "wf-ios-testflight-v1", category: "workflow", tier: "confirm",
    file: "PROJECT-IOS-TESTFLIGHT-CICD.yml", replacedBy: "PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml",
    since: "2.x", reason: "1세대 iOS 배포 — 현역 배포일 수 있음" },
  { id: "wf-flutter-ios-cicd", category: "workflow", tier: "confirm",
    file: "PROJECT-FLUTTER-IOS-CICD.yaml", replacedBy: "PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml",
    since: "3.x", reason: "TESTFLIGHT 워크플로우로 대체 — 현역 배포일 수 있음" },
  { id: "wf-file-upload-spring", category: "workflow", tier: "confirm",
    file: "PROJECT-SPRING-AUTO-FILE-UPLOAD.yaml", replacedBy: "PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml",
    since: "3.x", reason: "공통 Secret 업로드로 대체 — 운영 업로드 경로일 수 있음" },
  { id: "wf-file-upload-flutter", category: "workflow", tier: "confirm",
    file: "PROJECT-FLUTTER-AUTO-FILE-UPLOAD.yaml", replacedBy: "PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml",
    since: "3.x", reason: "공통 Secret 업로드로 대체 — 운영 업로드 경로일 수 있음" },
  { id: "wf-file-upload-python", category: "workflow", tier: "confirm",
    file: "PROJECT-PYTHON-AUTO-FILE-UPLOAD.yaml", replacedBy: "PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml",
    since: "3.x", reason: "공통 Secret 업로드로 대체 — 운영 업로드 경로일 수 있음" },
  { id: "wf-file-upload-v1", category: "workflow", tier: "confirm",
    file: "PROJECT-FILE-AUTO-UPLOAD.yaml", replacedBy: "PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml",
    since: "2.x", reason: "공통 Secret 업로드로 대체 — 운영 업로드 경로일 수 있음" },
  { id: "wf-nexus-publish-v1", category: "workflow", tier: "confirm",
    file: "PROJECT-NEXUS-PUBLISH.yml", replacedBy: "PROJECT-SPRING-NEXUS-PUBLISH.yml",
    since: "2.x", reason: "구 Nexus 배포 — 현역 라이브러리 배포일 수 있음" },
  { id: "wf-nexus-ci-v1", category: "workflow", tier: "confirm",
    file: "PROJECT-NEXUS-MODULE-CI-BUILD-CHECK.yml", replacedBy: "PROJECT-SPRING-NEXUS-CI.yml",
    since: "2.x", reason: "구 Nexus CI" },
  { id: "wf-ci-build-check-v0", category: "workflow", tier: "confirm",
    file: "PROJECT-CI-BUILD-CHECK.yml", replacedBy: "PROJECT-SPRING-NEXUS-CI.yml",
    since: "2.x", reason: "0세대 라이브러리 CI" },
  { id: "wf-publish-v0", category: "workflow", tier: "confirm",
    file: "PROJECT-PUBLISH.yml", replacedBy: "PROJECT-SPRING-NEXUS-PUBLISH.yml",
    since: "2.x", reason: "0세대 라이브러리 배포 — 현역 배포일 수 있음" },
  { id: "wf-deploy-trigger", category: "workflow", tier: "confirm",
    file: "PROJECT-DEPLOY-TRIGGER.yaml", replacedBy: null,
    since: "3.x", reason: "폐기된 배포 트리거" },

  // ── root-file / safe — 구 설치 가이드 (사용자가 매번 수동 삭제하던 것) ─────────
  { id: "root-setup-guide-v2", category: "root-file", tier: "safe",
    file: "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md", replacedBy: "PROJECTOPS-SETUP-GUIDE.md",
    since: "4.3.0", reason: "리브랜딩으로 구 가이드 대체 — 잔재 문서" },
  { id: "root-setup-guide-v1", category: "root-file", tier: "safe",
    file: "SETUP-GUIDE.md", replacedBy: "PROJECTOPS-SETUP-GUIDE.md",
    since: "2.x", reason: "구 가이드 문서 — 잔재",
    contentMarker: "SUH" }, // 범용 파일명이라 내용에 템플릿 마커가 있을 때만 소유 판정

  // ── legacy-dir / ask — 구명칭 산출물 폴더 (사용자 문서 보존 이동, #476) ────────
  { id: "dir-docs-suh-template", category: "legacy-dir", tier: "ask",
    file: "docs/suh-template", replacedBy: "docs/projectops",
    since: "4.2.9", reason: "리브랜딩 — 스킬 산출물(이슈·보고서) 폴더 구명칭. 신 스킬은 docs/projectops/에 저장" },
];
