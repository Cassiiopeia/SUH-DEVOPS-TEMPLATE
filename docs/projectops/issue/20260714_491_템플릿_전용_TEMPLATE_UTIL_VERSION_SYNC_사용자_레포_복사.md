📝 현재 문제점
---

- `PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml`은 파일 헤더에 "이 워크플로우는 SUH-DEVOPS-TEMPLATE 전용"이라고 명시된 **템플릿 레포 내부용** 워크플로우입니다 (`.github/util/*/version.json` 변경 시 util HTML 버전 동기화).
- 그런데 이 파일이 `project-types/common/`에 들어 있어, 마법사 통합 시 **모든 사용자 프로젝트에 복사**됩니다.
- 사용자 레포에는 `.github/util/` 폴더 자체가 없어 트리거가 영원히 발동하지 않는 무해한 no-op이지만, 템플릿 내부 전용 파일이 사용자 레포를 오염시키는 것은 맞습니다.

- v4.2.15 실측: spring 단독 레포(suh-project-utility)에 `.github/util/` 없이 이 워크플로우가 설치됨. 완료 요약의 "새로 설치·갱신됨" 목록에도 노출되어 사용자가 정체 모를 파일을 받게 됨.

🛠️ 해결 방안 / 제안 기능
---

- 통합(복사) 대상에서 `PROJECT-COMMON-TEMPLATE-UTIL-VERSION-SYNC.yml`을 제외한다. 다만 이 레포(projectops) 자신의 `.github/workflows/` 루트 복사본은 유지한다 (실제로 util HTML 동기화에 사용 중).
- 기존 사용자 레포에 이미 복사된 파일은 마법사의 레거시 정리 흐름(신형 대체 안내 또는 고아 정리)에서 제거 후보로 안내하는 것을 검토한다.
- 향후 유사 사고 방지: "템플릿 레포 전용 워크플로우"는 `project-types/common/`이 아닌 별도 위치에 두거나 복사 제외 목록으로 관리한다.

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
