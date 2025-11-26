# Cursor Scripts

## ⚠️ 중요: Windows 환경 전용

**이 스크립트는 Windows 환경에서 Cursor의 PowerShell 한글 인코딩 문제를 해결하기 위한 것입니다.**

### 문제 배경
- **Windows + Cursor + PowerShell**: 한글 경로 처리 시 인코딩 오류 발생
- **macOS/Linux**: 문제 없음 (UTF-8 네이티브 지원)
- **Cursor 내부 동작**: PowerShell 명령어를 임시 `.ps1` 파일로 저장 후 실행 → 한글이 ANSI로 깨짐

### 사용 목적
Cursor command에서 PowerShell 명령어 실행 시 오류가 발생하면, 이 Python 스크립트를 참조하여:
1. 자동으로 문제 파악
2. Python 스크립트 생성
3. 실행 및 검증
4. 필요 시 수정

**즉, PowerShell 대신 Python을 사용하여 한글 경로 문제를 우회합니다.**

---

이 디렉토리는 Cursor command에서 공통으로 사용할 수 있는 Python 유틸리티 스크립트를 포함합니다.

## 📦 포함된 모듈

### `common_util.py` (v1.0.0)

한글 경로 처리 등 공통 기능을 제공하는 유틸리티 모듈입니다.

#### 주요 함수

| 함수 | 설명 | 파라미터 | 반환값 |
|------|------|---------|--------|
| `copy_folder(src, dest)` | 폴더 안전 복사 | source, destination, overwrite, verify | Dict (성공 여부, 파일 개수) |
| `delete_folder(path)` | 폴더 안전 삭제 | path, safe | bool |
| `ensure_dir(path)` | 디렉토리 생성 | path | str (절대 경로) |
| `list_files(path, pattern)` | 파일 목록 조회 | path, pattern, recursive | List[str] |
| `get_file_info(path)` | 파일 정보 조회 | path | Dict |
| `safe_file_name(name)` | 안전한 파일명 생성 | name, replace_char | str |

## ✅ 장점

- 🪟 **Windows 전용 솔루션**: PowerShell 인코딩 문제 완벽 해결
- 🌏 **한글 경로 완벽 지원**: UTF-8 인코딩으로 저장되어 안전
- 🔄 **재사용 가능**: 모든 Cursor command에서 사용 가능
- 📝 **영구 보관**: 삭제되지 않고 계속 사용 가능
- ✔️ **검증 기능 포함**: 자동 파일 개수 확인
- 🛡️ **안전 기능**: 중요 경로 삭제 방지
- 🤖 **Cursor 자동 참조**: PowerShell 오류 시 자동으로 참조 및 실행
- 📚 **문서화**: 모든 함수에 docstring 포함

### macOS/Linux 사용자 참고
macOS와 Linux는 기본적으로 UTF-8을 사용하므로 이 스크립트가 필요하지 않습니다.
Cursor에서 PowerShell/Bash 명령어가 정상 작동합니다.

### Cursor에서 자동 참조 방식
1. PowerShell 명령어 실패 감지
2. `.cursor/scripts/common_util.py` 자동 참조
3. 적절한 Python 함수 선택
4. 임시 스크립트 생성 및 실행
5. 결과 검증 후 임시 파일 삭제

