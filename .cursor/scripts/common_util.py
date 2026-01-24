"""
Cursor Commands Common Utility Module

이 모듈은 모든 Cursor command에서 공통으로 사용할 수 있는 유틸리티 함수를 제공합니다.
특히 한글 경로 처리 등 인코딩 문제를 해결합니다.

작성자: Cursor AI Assistant
버전: 1.0.0
생성일: 2025-10-13
"""

import shutil
import os
from typing import Optional, List, Dict
from pathlib import Path


def copy_folder(
    source: str,
    destination: str,
    overwrite: bool = True,
    verify: bool = True
) -> Dict[str, any]:
    """
    폴더를 안전하게 복사합니다 (한글 경로 지원).
    
    Args:
        source (str): 원본 폴더 경로 (절대 경로 또는 상대 경로)
        destination (str): 대상 폴더 경로 (절대 경로 또는 상대 경로)
        overwrite (bool): 기존 폴더가 있으면 삭제 후 복사 (기본값: True)
        verify (bool): 복사 후 파일 개수 검증 (기본값: True)
    
    Returns:
        Dict[str, any]: 복사 결과 정보
            - success: 성공 여부 (bool)
            - source_path: 원본 경로 (str)
            - dest_path: 대상 경로 (str)
            - file_count: 복사된 파일 개수 (int)
            - error: 에러 메시지 (str, 에러 발생 시)
    
    Raises:
        FileNotFoundError: 원본 폴더가 존재하지 않을 때
        PermissionError: 권한이 없을 때
        OSError: 기타 시스템 에러
    
    Examples:
        >>> result = copy_folder(
        ...     r"d:\\source\\폴더",
        ...     r"d:\\dest\\새로운_폴더"
        ... )
        >>> print(f"복사 완료: {result['file_count']}개 파일")
    """
    result = {
        "success": False,
        "source_path": source,
        "dest_path": destination,
        "file_count": 0,
        "error": None
    }
    
    try:
        # 원본 폴더 존재 확인
        if not os.path.exists(source):
            raise FileNotFoundError(f"원본 폴더를 찾을 수 없습니다: {source}")
        
        if not os.path.isdir(source):
            raise ValueError(f"원본 경로가 폴더가 아닙니다: {source}")
        
        # 대상 폴더가 이미 존재하는 경우
        if os.path.exists(destination):
            if overwrite:
                shutil.rmtree(destination)
            else:
                raise FileExistsError(f"대상 폴더가 이미 존재합니다: {destination}")
        
        # 폴더 복사
        shutil.copytree(source, destination)
        
        # 검증
        if verify:
            source_files = list(Path(source).rglob("*"))
            dest_files = list(Path(destination).rglob("*"))
            result["file_count"] = len(dest_files)
            
            if len(source_files) != len(dest_files):
                result["error"] = f"파일 개수 불일치: 원본 {len(source_files)}, 대상 {len(dest_files)}"
                return result
        else:
            # 빠른 카운트 (최상위만)
            result["file_count"] = len(os.listdir(destination))
        
        result["success"] = True
        return result
        
    except Exception as e:
        result["error"] = str(e)
        raise


def delete_folder(path: str, safe: bool = True) -> bool:
    """
    폴더를 안전하게 삭제합니다.
    
    Args:
        path (str): 삭제할 폴더 경로
        safe (bool): 안전 모드 (중요 경로 삭제 방지, 기본값: True)
    
    Returns:
        bool: 삭제 성공 여부
    
    Examples:
        >>> delete_folder(r"d:\\temp\\test_folder")
        True
    """
    # 안전 모드: 중요 경로 삭제 방지
    if safe:
        dangerous_paths = [
            "C:\\Windows",
            "C:\\Program Files",
            "C:\\Users",
            os.path.expanduser("~"),  # 홈 디렉토리
        ]
        abs_path = os.path.abspath(path)
        for dangerous in dangerous_paths:
            if abs_path.lower().startswith(dangerous.lower()):
                raise PermissionError(f"안전 모드: 중요 경로는 삭제할 수 없습니다: {path}")
    
    if os.path.exists(path):
        shutil.rmtree(path)
        return True
    return False


def ensure_dir(path: str) -> str:
    """
    디렉토리가 존재하지 않으면 생성합니다.
    
    Args:
        path (str): 생성할 디렉토리 경로
    
    Returns:
        str: 생성된 디렉토리의 절대 경로
    
    Examples:
        >>> ensure_dir(r"d:\\temp\\new_folder")
        'd:\\\\temp\\\\new_folder'
    """
    os.makedirs(path, exist_ok=True)
    return os.path.abspath(path)


def list_files(
    path: str,
    pattern: str = "*",
    recursive: bool = False
) -> List[str]:
    """
    폴더 내 파일 목록을 반환합니다.
    
    Args:
        path (str): 검색할 폴더 경로
        pattern (str): 파일 패턴 (기본값: "*")
        recursive (bool): 하위 폴더 포함 여부 (기본값: False)
    
    Returns:
        List[str]: 파일 경로 리스트
    
    Examples:
        >>> files = list_files(r"d:\\folder", "*.txt", recursive=True)
        >>> print(f"{len(files)}개 파일 발견")
    """
    path_obj = Path(path)
    
    if recursive:
        return [str(p) for p in path_obj.rglob(pattern) if p.is_file()]
    else:
        return [str(p) for p in path_obj.glob(pattern) if p.is_file()]


def get_file_info(path: str) -> Dict[str, any]:
    """
    파일 또는 폴더의 상세 정보를 반환합니다.
    
    Args:
        path (str): 파일/폴더 경로
    
    Returns:
        Dict[str, any]: 파일 정보
            - exists: 존재 여부
            - is_file: 파일 여부
            - is_dir: 폴더 여부
            - size: 크기 (bytes)
            - name: 이름
            - parent: 부모 경로
    
    Examples:
        >>> info = get_file_info(r"d:\\file.txt")
        >>> print(f"크기: {info['size']} bytes")
    """
    path_obj = Path(path)
    
    return {
        "exists": path_obj.exists(),
        "is_file": path_obj.is_file(),
        "is_dir": path_obj.is_dir(),
        "size": path_obj.stat().st_size if path_obj.exists() else 0,
        "name": path_obj.name,
        "parent": str(path_obj.parent),
        "absolute": str(path_obj.absolute())
    }


def safe_file_name(name: str, replace_char: str = "_") -> str:
    """
    파일명에서 사용할 수 없는 문자를 제거/변환합니다.
    
    Args:
        name (str): 원본 파일명
        replace_char (str): 대체 문자 (기본값: "_")
    
    Returns:
        str: 안전한 파일명
    
    Examples:
        >>> safe_file_name("파일명: 테스트?.txt")
        '파일명_ 테스트_.txt'
    """
    invalid_chars = '<>:"/\\|?*'
    for char in invalid_chars:
        name = name.replace(char, replace_char)
    return name


# 버전 정보
__version__ = "1.0.0"
__author__ = "Cursor AI Assistant"
__all__ = [
    "copy_folder",
    "delete_folder",
    "ensure_dir",
    "list_files",
    "get_file_info",
    "safe_file_name"
]


if __name__ == "__main__":
    # 테스트 코드
    print(f"Common Util v{__version__}")
    print(f"Available functions: {', '.join(__all__)}")

