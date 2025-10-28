# Cursor Scripts - Windows 한글 경로 처리

## ⚠️ Windows 전용 (macOS/Linux 불필요)

**문제**: Windows Cursor + PowerShell 환경에서 한글 경로 처리 시 인코딩 오류  
**해결**: Python 스크립트로 우회 (UTF-8 지원)

---

## 📦 주요 함수

| 함수 | 설명 | 반환 |
|------|------|------|
| `copy_folder(src, dest)` | 폴더 복사 (한글 경로 지원) | Dict |
| `delete_folder(path, safe=True)` | 폴더 삭제 (시스템 경로 보호) | bool |
| `ensure_dir(path)` | 디렉토리 생성 (중첩 지원) | str |
| `list_files(path, pattern="*", recursive=False)` | 파일 목록 | List[str] |
| `get_file_info(path)` | 파일 정보 | Dict |
| `safe_file_name(name)` | 안전한 파일명 (Windows 금지 문자 제거) | str |

---

## 🚀 사용 예제

```python
import sys
sys.path.append('.cursor/scripts')
from powershell_common_util import copy_folder, delete_folder, ensure_dir

# 폴더 복사
result = copy_folder("C:/원본폴더", "D:/대상폴더")
print(result["message"])

# 디렉토리 생성
ensure_dir("./출력/데이터/2024")

# 안전 삭제
delete_folder("./temp", safe=True)
```

**CLI 사용**:
```bash
python .cursor/scripts/powershell_common_util.py copy "C:/원본" "D:/대상"
python .cursor/scripts/powershell_common_util.py delete "./temp"
python .cursor/scripts/powershell_common_util.py safe-name "파일:2024.txt"
```

---

## 📌 참고

- **이슈**: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/81
- **버전**: v1.0.0
- **Python**: 3.7+ 권장
