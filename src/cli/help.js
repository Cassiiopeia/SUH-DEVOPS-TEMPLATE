// --help 텍스트 (.sh show_help 요약 이식).
export const HELP_TEXT = `projectops — GitHub 프로젝트 자동화 템플릿 통합 CLI

사용법:
  npx projectops [옵션]

옵션:
  -m, --mode MODE          통합 모드 (full | version | workflows | issues | skills)
                           기본: interactive (대화형)
  -t, --type CSV           프로젝트 타입 csv (예: spring,react,python)
                           지원: spring flutter react react-native
                                 react-native-expo node python basic
                           (next는 react로 흡수됨 — Next.js 프로젝트는 react 사용)
      --project-version V  통합 대상의 초기 버전 (예: 1.0.0). 미지정 시 자동 감지
      --paths "t=p,..."    타입별 프로젝트 경로 (모노레포). 예: flutter=app,react=client
      --nexus / --no-nexus            Nexus 라이브러리 publish 워크플로우 포함/제외
      --secret-backup / --no-secret-backup   Secret 백업 워크플로우 포함/제외
      --force              모든 확인 생략, 비대화형 기본값 사용
  -v, --version            projectops 버전 출력
  -h, --help               이 도움말 표시

예시:
  npx projectops --mode full --force --type spring,react
  npx projectops --mode workflows --type flutter --paths "flutter=app"
`;
