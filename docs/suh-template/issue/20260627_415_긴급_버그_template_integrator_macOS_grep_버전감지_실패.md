🗒️ 설명
---

`template_integrator.sh`를 macOS 기본 grep(BSD grep)을 쓰는 환경에서 실행하면 **버전 자동 감지가 실패**한다.

`detect_version()` 함수가 버전 추출에 GNU grep 전용 문법인 `grep -oP`(PCRE 옵션)와 `\K`(match reset)를 사용하는데, macOS에 기본 탑재된 `/usr/bin/grep`은 BSD grep이라 `-P` 옵션을 지원하지 않는다. 그 결과 `grep: invalid option -- P` 에러가 출력되고 버전을 읽지 못해 기본값 `0.0.1`로 폴백된다. Flutter 프로젝트의 `pubspec.yaml`에 정상 버전이 있어도 감지하지 못한다.

추가로, 스크립트에 임시 폴더 정리용 `trap ... EXIT`가 없어, 위 에러를 보고 사용자가 중간에 종료하거나 다른 에러로 중단되면 다운로드 임시 폴더 `.template_download_temp/`가 프로젝트에 그대로 남는다. (사용자가 "통합 결과물이 폴더 안에 생성됐다"고 오해한 원인)

**영향 범위**:
- macOS 기본 grep 환경(Homebrew GNU grep 미설치)의 모든 사용자
- Windows(`template_integrator.ps1`)는 PowerShell `-match`(.NET 정규식)를 사용해 외부 grep에 의존하지 않으므로 **정상**. 이 버그는 `.sh`에만 존재.

**문제 위치** (`template_integrator.sh`):
- `detect_version()` 내 `grep -oP` 3곳
  - build.gradle (Spring)
  - pubspec.yaml (Flutter)
  - pyproject.toml (Python)
- 임시 폴더 정리용 `trap EXIT` 부재

> 같은 스크립트의 다른 함수에는 이미 `# macOS 호환: grep -P 대신 sed 사용 (BSD grep은 -P 미지원)` 주석과 함께 BSD 호환 패턴이 적용돼 있으나, `detect_version()` 3곳은 누락됐다.

🔄 재현 방법
---

1. macOS(Homebrew GNU grep 미설치, 기본 `/usr/bin/grep`)에서 Flutter 프로젝트 루트로 이동
2. 아래 원격 실행 명령으로 마법사 실행
   ```
   bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh")
   ```
3. 전체 설치 모드 선택 후 진행
4. "버전 정보 자동 감지" 단계에서 `grep: invalid option -- P` 에러 발생 → "버전을 감지하지 못했습니다. 기본값 0.0.1로 설정합니다." 출력
5. (정상 버전이 있는데도) 버전이 0.0.1로 잘못 설정됨
6. 이 시점에 종료하면 `.template_download_temp/` 폴더가 프로젝트에 남음

📸 참고 자료
---

```
🔅 버전 정보 자동 감지 중...
grep: invalid option -- P
usage: grep [-abcdDEFGHhIiJLlMmnOopqRSsUVvwXxZz] [-A num] [-B num] [-C[num]]
        [-e pattern] [-f file] [--binary-files=value] [--color=when]
        [--context[=num]] [--directories=action] [--label] [--line-buffered]
        [--null] [pattern] [file ...]
⚠️ 버전을 감지하지 못했습니다. 기본값 0.0.1로 설정합니다.
```

재현 검증(macOS 기본 grep):
```
$ /usr/bin/grep -oP "version:\s*\K[0-9]+\.[0-9]+\.[0-9]+" pubspec.yaml
grep: invalid option -- P
```

✅ 예상 동작
---

- macOS 기본 grep 환경에서도 `pubspec.yaml`/`build.gradle`/`pyproject.toml`의 버전을 정상 감지해야 한다 (예: Flutter 프로젝트면 pubspec.yaml의 실제 버전).
- `grep -oP` 대신 BSD/GNU 모두 호환되는 방식(`grep -E ... | sed -E`)으로 버전을 추출해야 한다.
- 마법사가 중단·에러로 종료되더라도 `.template_download_temp/` 임시 폴더가 항상 정리돼야 한다 (`trap EXIT`).

⚙️ 환경 정보
---

- **OS**: macOS (Homebrew GNU grep 미설치, 기본 BSD `/usr/bin/grep`)
- **브라우저**: 해당 없음 (CLI)
- **기기**: 해당 없음

🙋‍♂️ 담당자
---

- **백엔드**: Cassiiopeia
- **프론트엔드**: 이름
- **디자인**: 이름
