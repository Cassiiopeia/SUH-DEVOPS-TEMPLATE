📝 현재 문제점
---

- `.github/util/flutter/` 마법사의 로컬 실행 스크립트가 bash(.sh)와 PowerShell(.ps1) 두 벌로 중복 관리되고 있습니다.
  - playstore-wizard: setup(829줄/817줄), apply, detect-application-id 각 2벌 + patch-build-gradle.py = 7파일
  - firebase-wizard: setup 2벌 + test 스크립트 2벌 = 4파일
  - testflight-wizard: setup.sh 1파일
- 같은 로직을 두 언어로 유지하다 보니 한쪽만 수정되는 버그가 반복되고, macOS bash 3.2 제약과 PowerShell 5.1 제약까지 겹쳐 디버깅 비용이 큽니다.
- Python은 이미 필수 의존성입니다 (playstore setup이 patch-build-gradle.py를 호출하며 python3/python 탐지 로직 내장). 굳이 sh/ps1 이중화를 유지할 이유가 없습니다.

🛠️ 해결 방안 / 제안 기능
---

- 마법사별로 **단일 Python 파일 + argparse 서브커맨드**로 통합합니다. 로직은 기존과 100% 동일하게 보존합니다 (동일 입력, 동일 산출물, 동일 종료 코드).
  - `playstore-wizard.py` : `setup` / `apply` / `detect-app-id` 서브커맨드, patch-build-gradle.py 로직 내부 흡수 (7파일 -> 1파일)
  - `firebase-wizard.py` : `setup` 서브커맨드, 테스트는 `test/setup-script-test.py`로 통합 (4파일 -> 2파일)
  - `testflight-wizard.py` : `setup` 서브커맨드 (mac 전용, python3는 Xcode CLT 동반 설치)
- HTML/JS가 안내하는 복사용 명령을 OS별 python 실행 명령으로 교체합니다 (Windows: `python`, macOS: `python3`). firebase ZIP 다운로드 동봉 파일도 .py로 교체합니다.
- `version-sync.sh` 3종은 GitHub Actions(ubuntu) 내부에서만 실행되므로 유지합니다.

⚙️ 작업 내용
---

- [ ] playstore-wizard.py 작성 (setup/apply/detect-app-id, patch-build-gradle 흡수) 및 구 sh/ps1/py 7파일 삭제
- [ ] firebase-wizard.py, test/setup-script-test.py 작성 및 구 4파일 삭제 (fixtures 유지)
- [ ] testflight-wizard.py 작성 및 setup.sh 삭제
- [ ] 각 마법사 HTML/JS 명령 안내와 ZIP 동봉을 python 기준으로 갱신
- [ ] `src/core/copy/util.js` copyUtilModules를 mirror 복사(삭제 후 복사)로 변경: 기존 통합 레포 업데이트 시 구 sh/ps1 자동 정리 (마이그레이션)
- [ ] 각 마법사 version.json minor 버전 증가 + changelog 기록
- [ ] docs/FLUTTER-PLAYSTORE-WIZARD.md 등 문서의 실행 명령 예시 갱신
- [ ] 검증: py_compile 전체, firebase 테스트(fixtures 4종) 통과, npm test 통과, 구 파일명 참조 잔존 0건

🙋‍♂️ 담당자
---

- 담당: Cassiiopeia
