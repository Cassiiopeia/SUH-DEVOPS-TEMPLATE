# safe_read 라인 입력 backspace 버그 수정 설계

작성일: 2026-06-28

## 증상

`template_integrator.sh` 대화형 입력 필드(서비스 식별자, 도메인, JDK 버전 등)에서:

- 첫 글자가 화면에 중복으로 박힘 — `suh-logger` 입력 시 화면에 `ssuh-logger`, `21` 입력 시 `2`가 남음.
- 첫 글자를 backspace로 지울 수 없음. 이미 입력된 첫 글자가 영구히 남는다.

## 근본 원인 (실측 확정)

`safe_read()` 함수의 라인 입력 분기(약 273~277행):

```bash
# 일반 문자 → 첫 글자 echo 후 나머지 라인 읽어 합침
printf "%s" "$_first" > /dev/tty           # 첫 글자를 수동 echo
local _rest
IFS= read -r _rest < /dev/tty || _rest=""  # 나머지를 별도 read로 읽음
printf -v "$varname" '%s' "${_first}${_rest}"
```

ESC 키(취소) 감지를 위해 입력을 **첫 1바이트 raw peek(`read -rsn1`) + 나머지 라인(`read -r`)** 으로 쪼갰다.
첫 글자는 `read -rsn1`(silent)로 읽은 뒤 `printf`로 수동 echo하는데, 이 글자는 두 번째 `read -r`의
**라인 편집 버퍼 밖**에 있다. 따라서:

1. 터미널 라인 편집(backspace)은 두 번째 `read`의 버퍼(`_rest`)만 건드릴 수 있어 첫 글자를 못 지운다.
2. 수동 echo한 첫 글자 + `read`가 다시 echo하는 입력이 겹쳐 화면에 중복으로 보인다.

### bash 3.2 제약으로 간단 수정이 막힌 경위 (모두 macOS /bin/bash 3.2.57 실측)

- `read -e -i "$_first"` (첫 글자 prefill) → **bash 3.2 미지원**, rc=2로 실패.
- `read -e` + readline `bind`로 ESC 취소 → 동작 꼬임(신뢰 불가).
- 첫 키를 process substitution으로 prepend → readline 편집 비활성, `ssuh-logger` 재발.
- 결론: **첫 키 raw peek와 readline 라인 편집은 bash 3.2에서 양립 불가.**

## 해결

`safe_read`의 라인 입력 분기(`options=""`)를 **`IFS= read -e -r "$varname" < /dev/tty` 한 줄로 교체**한다.
readline이 backspace·방향키·Home/End·한글 입력을 모두 정상 처리한다.

`-n 1`(한 글자 y/n) 분기와 `$options` 분기는 그대로 유지한다.

### 트레이드오프: ESC 단독 취소(return 2) 제거

`read -e`에서는 ESC가 readline 메타 prefix로 소비되어 취소 신호로 쓸 수 없다(실측 확인).
ESC return 2를 분기 처리하는 호출부는 **2곳뿐**이며, 둘 다 이미 "빈 입력 Enter = 기존 값 유지"라는
동등 동작이 존재한다 → 기능 손실 없음.

- `version` 입력(약 2024행): 프롬프트 `ESC=뒤로` → `Enter=유지`로 변경, `_rc -eq 2` 분기를 빈 입력 처리로 통합.
- `branch` 입력(약 2048행): 동일.

부수 효과: 화살표 키로 시작하는 입력도 더 이상 ESC로 오인되지 않는다(개선).

## 영향 범위

| 위치 | 변경 |
|---|---|
| `safe_read` 라인 입력 분기 (273~277) | `read -e`로 교체 |
| 프롬프트/분기 (2024, 2048) | 문구 수정 + ESC 분기를 빈 입력 처리로 통합 |
| `safe_read` `-n 1` 분기 | 변경 없음 |
| `interactive_menu` raw 키 입력 | 변경 없음 (메뉴 네비게이션 — backspace 무관) |
| 메뉴 폴백 `read -r choice` (590, 593) | 변경 없음 (peek 없음, 정상) |
| `template_integrator.ps1` | 변경 없음 (`Read-Host`는 OS 라인 편집, 버그 없음) |

## 검증 (실측 4케이스, /bin/bash 3.2.57)

| 케이스 | 입력 | 기대 | 결과 |
|---|---|---|---|
| C1 | `s` → backspace → `suh-logger` | `suh-logger` | ✅ |
| C2 | 빈 Enter | 빈값, rc=0 | ✅ |
| C3 | `21` | `21` (첫글자 중복 없음) | ✅ |
| C4 | `abX` → backspace → `c` | `abc` | ✅ |

구현 후 동일 4케이스를 실제 스크립트에 대해 expect로 재검증한다.
