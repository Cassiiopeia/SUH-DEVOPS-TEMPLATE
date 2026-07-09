🗒️ 설명
---

`template_integrator.sh`의 대화형 입력(서비스 식별자·도메인·JDK 버전 등)에서, 입력한 **첫 글자가 화면에 중복으로 박히고 backspace로 지워지지 않는** 버그가 있습니다.

- `suh-logger`를 입력하면 화면에 `ssuh-logger`로 표시되고, 첫 's'를 backspace로 지울 수 없습니다.
- JDK 버전에 `21`을 입력하면 첫 글자 `2`가 지워지지 않고 남습니다.
- 사용자가 첫 글자를 지우려고 backspace를 눌러도 전혀 반응하지 않습니다.

원인은 입력 함수 `safe_read`가 ESC(취소) 키를 감지하기 위해 입력을 **첫 1바이트 raw 읽기(`read -rsn1`) + 나머지 라인(`read -r`)** 으로 쪼갠 데 있습니다. 첫 글자는 silent로 읽은 뒤 수동으로 화면에 출력하는데, 이 글자가 두 번째 `read`의 라인 편집 버퍼 **바깥**에 있어 backspace가 닿지 못하고, 두 read의 echo가 겹쳐 화면에 중복으로 보입니다.

🔄 재현 방법
---

1. `template_integrator.sh`를 macOS(`/bin/bash` 3.2)에서 실행
2. 배포 워크플로우 환경설정 단계의 "서비스 식별자" 입력 필드로 이동
3. `suh-logger`를 입력 → 화면에 `ssuh-logger`로 표시됨
4. 첫 글자를 backspace로 지우려 해도 지워지지 않음

📸 참고 자료
---

해당 코드 (`template_integrator.sh` 약 273~277행, `safe_read` 라인 입력 분기):

- 첫 글자를 `read -rsn1`(silent)로 읽고 `printf`로 수동 echo
- 나머지를 `read -r`로 별도로 읽어 합침
- → 첫 글자가 라인 편집 버퍼 밖이라 backspace 불가

실측 검증 환경: `/bin/bash` 3.2.57 (macOS).

✅ 예상 동작
---

- 입력한 첫 글자가 화면에 한 번만 표시되어야 함 (`suh-logger` 입력 시 `suh-logger`로 표시)
- backspace로 첫 글자를 포함한 모든 글자를 정상적으로 지울 수 있어야 함
- 방향키·Home/End·한글 입력도 정상 동작해야 함

⚙️ 환경 정보
---

- **OS**: macOS (Darwin), `/bin/bash` 3.2.57
- **브라우저**: 해당 없음 (CLI)
- **기기**: 해당 없음

🙋‍♂️ 담당자
---

- **백엔드**: Cassiiopeia
- **프론트엔드**: -
- **디자인**: -
