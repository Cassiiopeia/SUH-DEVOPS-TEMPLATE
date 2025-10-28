# -*- coding: utf-8 -*-
"""
Cursor Scripts - Windows 전용 공통 유틸리티 v1.0.0

⚠️ 중요: Windows 환경 전용
이 스크립트는 Windows 환경에서 Cursor의 PowerShell 한글 인코딩 문제를 해결하기 위한 것입니다.

문제 배경:
- Windows + Cursor + PowerShell: 한글 경로 처리 시 인코딩 오류 발생
- macOS/Linux: 문제 없음 (UTF-8 네이티브 지원)
- Cursor 내부 동작: PowerShell 명령어를 임시 .ps1 파일로 저장 후 실행 → 한글이 ANSI로 깨짐

사용 목적:
Cursor command에서 PowerShell 명령어 실행 시 오류가 발생하면, 이 Python 스크립트를 참조하여:
1. 자동으로 문제 파악
2. Python 스크립트 생성
3. 실행 및 검증
4. 필요 시 수정

즉, PowerShell 대신 Python을 사용하여 한글 경로 문제를 우회합니다.

Author: Cassiiopeia
Repository: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE
Issue: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/81
"""

import os
import shutil
import sys
from pathlib import Path
from typing import Dict, List, Optional, Union
import re
import datetime


# ===================================================================
# 상수 정의
# ===================================================================

VERSION = "1.0.0"

# Windows 금지 문자
WINDOWS_FORBIDDEN_CHARS = r'<>:"|?*'

# 안전 삭제 모드에서 보호할 경로 (대소문자 무시)
PROTECTED_PATHS = [
    "c:\\",
    "c:\\windows",
    "c:\\program files",
    "c:\\program files (x86)",
    "c:\\users",
    "c:\\programdata",
    "/",
    "/usr",
    "/bin",
    "/sbin",
    "/etc",
    "/var",
    "/home",
]


# ===================================================================
# 유틸리티 함수
# ===================================================================

def _normalize_path(path: Union[str, Path]) -> Path:
    """
    경로를 정규화하여 Path 객체로 반환합니다.
    
    Args:
        path: 정규화할 경로 (문자열 또는 Path 객체)
        
    Returns:
        Path: 절대 경로로 변환된 Path 객체
    """
    return Path(path).resolve()


def _is_protected_path(path: Union[str, Path]) -> bool:
    """
    경로가 보호된 시스템 경로인지 확인합니다.
    
    Args:
        path: 확인할 경로
        
    Returns:
        bool: 보호된 경로면 True, 아니면 False
    """
    path_str = str(_normalize_path(path)).lower()
    
    for protected in PROTECTED_PATHS:
        if path_str == protected.lower() or path_str.startswith(protected.lower() + os.sep):
            return True
    
    return False


def _count_files(directory: Path, recursive: bool = True) -> int:
    """
    디렉토리 내 파일 개수를 계산합니다.
    
    Args:
        directory: 파일 개수를 셀 디렉토리
        recursive: 재귀적으로 하위 디렉토리도 포함할지 여부
        
    Returns:
        int: 파일 개수 (디렉토리는 제외)
    """
    count = 0
    
    if recursive:
        for root, dirs, files in os.walk(directory):
            count += len(files)
    else:
        if directory.exists() and directory.is_dir():
            count = sum(1 for item in directory.iterdir() if item.is_file())
    
    return count


# ===================================================================
# 주요 기능 함수
# ===================================================================

def copy_folder(
    src: Union[str, Path],
    dest: Union[str, Path],
    overwrite: bool = True,
    verify: bool = True
) -> Dict[str, Union[bool, int, str]]:
    """
    폴더를 안전하게 복사합니다. (한글 경로 지원)
    
    이 함수는 Windows 환경에서 Cursor의 PowerShell 한글 인코딩 문제를 우회하여
    한글이 포함된 경로의 폴더를 안전하게 복사합니다.
    
    Args:
        src (str | Path): 원본 폴더 경로
        dest (str | Path): 대상 폴더 경로
        overwrite (bool): 대상이 이미 존재할 경우 덮어쓸지 여부 (기본값: True)
        verify (bool): 복사 후 파일 개수를 검증할지 여부 (기본값: True)
        
    Returns:
        Dict: 복사 결과 정보
            - success (bool): 성공 여부
            - source_files (int): 원본 파일 개수
            - copied_files (int): 복사된 파일 개수
            - message (str): 결과 메시지
            - error (str, optional): 에러 메시지 (실패 시)
            
    Raises:
        FileNotFoundError: 원본 폴더가 존재하지 않을 때
        PermissionError: 권한이 부족할 때
        
    Example:
        >>> result = copy_folder("C:/원본폴더", "D:/대상폴더")
        >>> print(result)
        {
            'success': True,
            'source_files': 15,
            'copied_files': 15,
            'message': '폴더 복사 완료: 15개 파일'
        }
        
        >>> # 덮어쓰기 금지
        >>> result = copy_folder("./src", "./backup", overwrite=False)
    """
    try:
        src_path = _normalize_path(src)
        dest_path = _normalize_path(dest)
        
        # 원본 폴더 존재 확인
        if not src_path.exists():
            raise FileNotFoundError(f"원본 폴더를 찾을 수 없습니다: {src_path}")
        
        if not src_path.is_dir():
            raise NotADirectoryError(f"원본이 폴더가 아닙니다: {src_path}")
        
        # 원본 파일 개수 확인
        source_file_count = _count_files(src_path) if verify else 0
        
        # 대상 폴더 존재 시 처리
        if dest_path.exists():
            if not overwrite:
                return {
                    "success": False,
                    "source_files": source_file_count,
                    "copied_files": 0,
                    "message": f"대상 폴더가 이미 존재합니다: {dest_path}",
                    "error": "Destination already exists (overwrite=False)"
                }
            
            # 기존 폴더 삭제
            shutil.rmtree(dest_path)
        
        # 폴더 복사
        shutil.copytree(src_path, dest_path)
        
        # 복사 검증
        copied_file_count = _count_files(dest_path) if verify else 0
        
        if verify and source_file_count != copied_file_count:
            return {
                "success": False,
                "source_files": source_file_count,
                "copied_files": copied_file_count,
                "message": f"파일 개수 불일치: 원본 {source_file_count}개, 복사됨 {copied_file_count}개",
                "error": "File count mismatch"
            }
        
        return {
            "success": True,
            "source_files": source_file_count,
            "copied_files": copied_file_count,
            "message": f"폴더 복사 완료: {copied_file_count}개 파일"
        }
        
    except Exception as e:
        return {
            "success": False,
            "source_files": 0,
            "copied_files": 0,
            "message": f"폴더 복사 실패: {str(e)}",
            "error": str(e)
        }


def delete_folder(
    path: Union[str, Path],
    safe: bool = True
) -> bool:
    """
    폴더를 안전하게 삭제합니다.
    
    Args:
        path (str | Path): 삭제할 폴더 경로
        safe (bool): 안전 모드 (시스템 중요 경로 삭제 방지, 기본값: True)
        
    Returns:
        bool: 삭제 성공 시 True, 실패 시 False
        
    Raises:
        FileNotFoundError: 폴더가 존재하지 않을 때
        PermissionError: 삭제 권한이 없거나 안전 모드에서 보호된 경로일 때
        
    Example:
        >>> # 일반 폴더 삭제
        >>> delete_folder("./temp")
        True
        
        >>> # 시스템 경로는 안전 모드에서 삭제 불가
        >>> delete_folder("C:/Windows", safe=True)
        PermissionError: 보호된 시스템 경로는 삭제할 수 없습니다
        
        >>> # 강제 삭제 (주의!)
        >>> delete_folder("./old_data", safe=False)
        True
    """
    folder_path = _normalize_path(path)
    
    # 폴더 존재 확인
    if not folder_path.exists():
        raise FileNotFoundError(f"폴더를 찾을 수 없습니다: {folder_path}")
    
    if not folder_path.is_dir():
        raise NotADirectoryError(f"대상이 폴더가 아닙니다: {folder_path}")
    
    # 안전 모드: 보호된 경로 확인
    if safe and _is_protected_path(folder_path):
        raise PermissionError(
            f"보호된 시스템 경로는 삭제할 수 없습니다: {folder_path}\n"
            "강제 삭제하려면 safe=False 옵션을 사용하세요 (매우 위험!)"
        )
    
    try:
        shutil.rmtree(folder_path)
        return True
    except Exception as e:
        raise PermissionError(f"폴더 삭제 실패: {str(e)}")


def ensure_dir(path: Union[str, Path]) -> str:
    """
    디렉토리가 존재하지 않으면 생성합니다. (중첩 디렉토리 지원)
    
    Args:
        path (str | Path): 생성할 디렉토리 경로
        
    Returns:
        str: 생성된 디렉토리의 절대 경로
        
    Example:
        >>> # 단일 디렉토리 생성
        >>> ensure_dir("./output")
        'C:/project/output'
        
        >>> # 중첩 디렉토리 생성
        >>> ensure_dir("./output/data/2024")
        'C:/project/output/data/2024'
        
        >>> # 이미 존재하는 경로 (에러 없이 통과)
        >>> ensure_dir("./existing_folder")
        'C:/project/existing_folder'
    """
    dir_path = _normalize_path(path)
    dir_path.mkdir(parents=True, exist_ok=True)
    return str(dir_path)


def list_files(
    path: Union[str, Path],
    pattern: str = "*",
    recursive: bool = False
) -> List[str]:
    """
    지정된 경로에서 파일 목록을 조회합니다.
    
    Args:
        path (str | Path): 검색할 디렉토리 경로
        pattern (str): 파일명 패턴 (glob 형식, 기본값: "*")
        recursive (bool): 하위 디렉토리 포함 여부 (기본값: False)
        
    Returns:
        List[str]: 파일 경로 목록 (절대 경로)
        
    Raises:
        FileNotFoundError: 경로가 존재하지 않을 때
        NotADirectoryError: 경로가 디렉토리가 아닐 때
        
    Example:
        >>> # 현재 디렉토리의 모든 파일
        >>> list_files(".")
        ['C:/project/file1.txt', 'C:/project/file2.txt']
        
        >>> # Python 파일만 검색
        >>> list_files("./src", pattern="*.py")
        ['C:/project/src/main.py', 'C:/project/src/util.py']
        
        >>> # 재귀적 검색 (하위 디렉토리 포함)
        >>> list_files("./src", pattern="*.py", recursive=True)
        ['C:/project/src/main.py', 'C:/project/src/utils/helper.py']
    """
    dir_path = _normalize_path(path)
    
    if not dir_path.exists():
        raise FileNotFoundError(f"경로를 찾을 수 없습니다: {dir_path}")
    
    if not dir_path.is_dir():
        raise NotADirectoryError(f"경로가 디렉토리가 아닙니다: {dir_path}")
    
    files = []
    
    if recursive:
        # 재귀적 검색
        for file_path in dir_path.rglob(pattern):
            if file_path.is_file():
                files.append(str(file_path))
    else:
        # 현재 디렉토리만 검색
        for file_path in dir_path.glob(pattern):
            if file_path.is_file():
                files.append(str(file_path))
    
    return sorted(files)


def get_file_info(path: Union[str, Path]) -> Dict[str, Union[str, int, float]]:
    """
    파일 정보를 조회합니다.
    
    Args:
        path (str | Path): 파일 경로
        
    Returns:
        Dict: 파일 정보
            - path (str): 절대 경로
            - name (str): 파일명
            - extension (str): 확장자
            - size (int): 파일 크기 (바이트)
            - size_mb (float): 파일 크기 (MB, 소수점 2자리)
            - created (str): 생성 시간 (ISO 8601 형식)
            - modified (str): 수정 시간 (ISO 8601 형식)
            - exists (bool): 파일 존재 여부
            
    Raises:
        FileNotFoundError: 파일이 존재하지 않을 때
        
    Example:
        >>> info = get_file_info("./document.txt")
        >>> print(info)
        {
            'path': 'C:/project/document.txt',
            'name': 'document.txt',
            'extension': '.txt',
            'size': 1024,
            'size_mb': 0.00,
            'created': '2024-10-13T10:30:00',
            'modified': '2024-10-13T14:20:00',
            'exists': True
        }
    """
    file_path = _normalize_path(path)
    
    if not file_path.exists():
        raise FileNotFoundError(f"파일을 찾을 수 없습니다: {file_path}")
    
    stat = file_path.stat()
    
    return {
        "path": str(file_path),
        "name": file_path.name,
        "extension": file_path.suffix,
        "size": stat.st_size,
        "size_mb": round(stat.st_size / (1024 * 1024), 2),
        "created": datetime.datetime.fromtimestamp(stat.st_ctime).isoformat(),
        "modified": datetime.datetime.fromtimestamp(stat.st_mtime).isoformat(),
        "exists": True
    }


def safe_file_name(name: str, replace_char: str = "_") -> str:
    """
    안전한 파일명을 생성합니다. (Windows 금지 문자 제거)
    
    Windows에서 파일명에 사용할 수 없는 문자를 제거하거나 대체합니다.
    
    Args:
        name (str): 원본 파일명
        replace_char (str): 금지 문자를 대체할 문자 (기본값: "_")
        
    Returns:
        str: 안전한 파일명
        
    Example:
        >>> # Windows 금지 문자 제거
        >>> safe_file_name('파일명: 2024.txt')
        '파일명_ 2024.txt'
        
        >>> # 특수문자를 하이픈으로 대체
        >>> safe_file_name('보고서|최종.docx', replace_char='-')
        '보고서-최종.docx'
        
        >>> # 여러 금지 문자 처리
        >>> safe_file_name('데이터<2024>|최종.xlsx')
        '데이터_2024__최종.xlsx'
    """
    # Windows 금지 문자를 정규식으로 대체
    safe_name = re.sub(f"[{re.escape(WINDOWS_FORBIDDEN_CHARS)}]", replace_char, name)
    
    # 파일명 앞뒤 공백 제거
    safe_name = safe_name.strip()
    
    return safe_name


# ===================================================================
# CLI 인터페이스 (직접 실행 시)
# ===================================================================

def print_usage():
    """사용법 출력"""
    print(f"""
Cursor PowerShell 공통 유틸리티 v{VERSION}
Windows 환경에서 한글 경로 처리를 위한 Python 스크립트

사용법:
  python powershell_common_util.py <command> [args...]

명령어:
  copy <src> <dest>         폴더 복사
  delete <path>             폴더 삭제 (안전 모드)
  mkdir <path>              디렉토리 생성
  list <path> [pattern]     파일 목록 조회
  info <path>               파일 정보 조회
  safe-name <name>          안전한 파일명 생성

예제:
  python powershell_common_util.py copy "C:/원본폴더" "D:/대상폴더"
  python powershell_common_util.py delete "./temp"
  python powershell_common_util.py list "./src" "*.py"
  python powershell_common_util.py info "./document.txt"

자세한 정보:
  https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/81
""")


def main():
    """CLI 메인 함수"""
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    try:
        if command == "copy":
            if len(sys.argv) < 4:
                print("❌ 사용법: copy <src> <dest>")
                sys.exit(1)
            result = copy_folder(sys.argv[2], sys.argv[3])
            if result["success"]:
                print(f"✅ {result['message']}")
            else:
                print(f"❌ {result['message']}")
                sys.exit(1)
        
        elif command == "delete":
            if len(sys.argv) < 3:
                print("❌ 사용법: delete <path>")
                sys.exit(1)
            if delete_folder(sys.argv[2]):
                print(f"✅ 폴더 삭제 완료: {sys.argv[2]}")
        
        elif command == "mkdir":
            if len(sys.argv) < 3:
                print("❌ 사용법: mkdir <path>")
                sys.exit(1)
            path = ensure_dir(sys.argv[2])
            print(f"✅ 디렉토리 생성 완료: {path}")
        
        elif command == "list":
            if len(sys.argv) < 3:
                print("❌ 사용법: list <path> [pattern]")
                sys.exit(1)
            pattern = sys.argv[3] if len(sys.argv) > 3 else "*"
            files = list_files(sys.argv[2], pattern=pattern)
            print(f"📁 파일 개수: {len(files)}")
            for file in files:
                print(f"  - {file}")
        
        elif command == "info":
            if len(sys.argv) < 3:
                print("❌ 사용법: info <path>")
                sys.exit(1)
            info = get_file_info(sys.argv[2])
            print(f"📄 파일 정보:")
            for key, value in info.items():
                print(f"  - {key}: {value}")
        
        elif command == "safe-name":
            if len(sys.argv) < 3:
                print("❌ 사용법: safe-name <name>")
                sys.exit(1)
            safe_name = safe_file_name(sys.argv[2])
            print(f"✅ 안전한 파일명: {safe_name}")
        
        else:
            print(f"❌ 알 수 없는 명령어: {command}")
            print_usage()
            sys.exit(1)
    
    except Exception as e:
        print(f"❌ 오류 발생: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()

