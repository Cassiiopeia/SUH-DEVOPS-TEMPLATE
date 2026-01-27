# -*- coding: utf-8 -*-
"""
Git Worktree Manager v1.0.2

Git worktree를 자동으로 생성하고 관리하는 스크립트입니다.
브랜치가 없으면 자동으로 생성하고, 브랜치명의 특수문자를 안전하게 처리합니다.

사용법:
    python worktree_manager.py <branch_name>

예시:
    python worktree_manager.py "20260120_#163_Github_Projects_에_대한_템플릿_개발_필요"

Author: Cursor AI Assistant
Version: 1.0.1
"""

import os
import sys
import subprocess
import re
from pathlib import Path
from typing import Dict, Optional, Tuple


# ===================================================================
# 상수 정의
# ===================================================================

VERSION = "1.0.2"

# 폴더명에서 제거할 특수문자 (파일시스템에서 안전하지 않은 문자)
SPECIAL_CHARS_PATTERN = r'[#/\\:*?"<>|]'

# Worktree 루트 폴더명 (동적으로 설정됨)
# 예: RomRom-FE → RomRom-FE-Worktree
WORKTREE_ROOT_NAME = None  # get_worktree_root()에서 동적으로 설정


# ===================================================================
# 유틸리티 함수
# ===================================================================

def print_header():
  """헤더 출력"""
  print("━" * 60)
  print(f"🌿 Git Worktree Manager v{VERSION}")
  print("━" * 60)
  print()


def print_step(emoji: str, message: str):
  """단계별 메시지 출력"""
  print(f"{emoji} {message}")


def print_error(message: str):
  """에러 메시지 출력"""
  print(f"❌ 에러: {message}", file=sys.stderr)


def print_success(message: str):
  """성공 메시지 출력"""
  print(f"✅ {message}")


def print_info(message: str):
  """정보 메시지 출력"""
  print(f"ℹ️  {message}")


def print_warning(message: str):
  """경고 메시지 출력"""
  print(f"⚠️  {message}")


# ===================================================================
# Git 관련 함수
# ===================================================================

def run_git_command(args: list, check: bool = True) -> Tuple[bool, str, str]:
  """
  Git 명령어 실행

  Args:
      args: Git 명령어 인자 리스트 (예: ['branch', '--list'])
      check: 에러 발생 시 예외를 발생시킬지 여부

  Returns:
      Tuple[bool, str, str]: (성공 여부, stdout, stderr)
  """
  try:
    result = subprocess.run(
      ['git'] + args,
      capture_output=True,
      text=True,
      encoding='utf-8',
      check=check
    )
    return True, result.stdout.strip(), result.stderr.strip()
  except subprocess.CalledProcessError as e:
    return False, e.stdout.strip() if e.stdout else "", e.stderr.strip() if e.stderr else ""
  except Exception as e:
    return False, "", str(e)


def is_git_repository() -> bool:
  """현재 디렉토리가 Git 저장소인지 확인"""
  success, _, _ = run_git_command(['rev-parse', '--git-dir'], check=False)
  return success


def get_git_root() -> Optional[Path]:
  """Git 저장소 루트 경로 반환"""
  success, stdout, _ = run_git_command(['rev-parse', '--show-toplevel'], check=False)
  if success and stdout:
    return Path(stdout)
  return None


def get_current_branch() -> Optional[str]:
  """현재 체크아웃된 브랜치명 반환"""
  success, stdout, _ = run_git_command(['branch', '--show-current'], check=False)
  if success and stdout:
    return stdout
  return None


def branch_exists(branch_name: str) -> bool:
  """
  브랜치 존재 여부 확인

  Args:
      branch_name: 확인할 브랜치명

  Returns:
      bool: 브랜치가 존재하면 True
  """
  success, stdout, _ = run_git_command(['branch', '--list', branch_name], check=False)
  if success and stdout:
    # 출력 형식: "  branch_name" 또는 "* branch_name"
    branches = [line.strip().lstrip('* ') for line in stdout.split('\n')]
    return branch_name in branches
  return False


def create_branch(branch_name: str) -> bool:
  """
  현재 브랜치에서 새 브랜치 생성

  Args:
      branch_name: 생성할 브랜치명

  Returns:
      bool: 성공 여부
  """
  success, _, stderr = run_git_command(['branch', branch_name], check=False)
  if not success:
    print_error(f"브랜치 생성 실패: {stderr}")
  return success


def get_worktree_list() -> Dict[str, str]:
  """
  현재 등록된 worktree 목록 반환

  Returns:
      Dict[str, str]: {worktree_path: branch_name}
  """
  success, stdout, _ = run_git_command(['worktree', 'list', '--porcelain'], check=False)
  if not success:
    return {}

  worktrees = {}
  current_path = None

  for line in stdout.split('\n'):
    if line.startswith('worktree '):
      current_path = line.replace('worktree ', '')
    elif line.startswith('branch '):
      branch = line.replace('branch ', '').replace('refs/heads/', '')
      if current_path:
        worktrees[current_path] = branch
        current_path = None

  return worktrees


def prune_worktrees() -> bool:
  """
  유효하지 않은 worktree 정리 (git worktree prune)

  Returns:
      bool: 성공 여부
  """
  success, _, stderr = run_git_command(['worktree', 'prune'], check=False)
  if not success:
    print_warning(f"Worktree prune 실패: {stderr}")
  return success


def is_worktree_exists(worktree_path: Path) -> bool:
  """
  특정 경로에 worktree가 이미 존재하는지 확인

  Git worktree 목록과 실제 디렉토리 존재 여부를 모두 확인합니다.
  prunable 상태의 worktree는 자동으로 정리합니다.

  Args:
      worktree_path: 확인할 worktree 경로

  Returns:
      bool: worktree가 유효하게 존재하면 True
  """
  # 먼저 prunable worktree 정리
  prune_worktrees()

  worktrees = get_worktree_list()
  worktree_path_resolved = worktree_path.resolve()

  for path in worktrees.keys():
    if Path(path).resolve() == worktree_path_resolved:
      # Git 목록에 있으면 실제 디렉토리도 존재하는지 확인
      if Path(path).exists():
        return True
      else:
        # 디렉토리가 없으면 다시 prune 실행
        print_warning(f"Worktree 경로가 존재하지 않아 정리합니다: {path}")
        prune_worktrees()
        return False

  # 디렉토리만 존재하고 Git에 등록되지 않은 경우도 확인
  if worktree_path_resolved.exists():
    # .git 파일이 있는지 확인 (worktree의 특징)
    git_file = worktree_path_resolved / '.git'
    if git_file.exists():
      print_warning(f"디렉토리가 존재하지만 Git에 등록되지 않음: {worktree_path}")
      return True

  return False


def create_worktree(branch_name: str, worktree_path: Path) -> Dict:
  """
  Git worktree 생성

  Args:
      branch_name: 체크아웃할 브랜치명
      worktree_path: worktree를 생성할 경로

  Returns:
      Dict: {
          'success': bool,
          'path': str,
          'message': str,
          'is_existing': bool
      }
  """
  # 이미 존재하는지 확인
  if is_worktree_exists(worktree_path):
    return {
      'success': True,
      'path': str(worktree_path.resolve()),
      'message': 'Worktree가 이미 존재합니다.',
      'is_existing': True
    }

  # worktree 생성
  success, stdout, stderr = run_git_command(
    ['worktree', 'add', str(worktree_path), branch_name],
    check=False
  )

  if success:
    return {
      'success': True,
      'path': str(worktree_path.resolve()),
      'message': 'Worktree 생성 완료!',
      'is_existing': False
    }
  else:
    return {
      'success': False,
      'path': str(worktree_path.resolve()),
      'message': f'Worktree 생성 실패: {stderr}',
      'is_existing': False
    }


# ===================================================================
# 경로 관련 함수
# ===================================================================

def normalize_branch_name(branch_name: str) -> str:
  """
  브랜치명을 폴더명으로 안전하게 변환

  특수문자 (#, /, \\\\, :, *, ?, ", <, >, |)를 _ 로 변환하고,
  연속된 _를 하나로 통합하며, 앞뒤 _를 제거합니다.

  Args:
      branch_name: 원본 브랜치명

  Returns:
      str: 정규화된 폴더명

  Example:
      >>> normalize_branch_name("20260120_#163_Github_Projects")
      "20260120_163_Github_Projects"
  """
  # 특수문자를 _ 로 변환
  normalized = re.sub(SPECIAL_CHARS_PATTERN, '_', branch_name)

  # 연속된 _를 하나로 통합
  normalized = re.sub(r'_+', '_', normalized)

  # 앞뒤 _를 제거
  normalized = normalized.strip('_')

  return normalized


def get_worktree_root() -> Path:
  """
  Worktree 루트 경로 계산

  현재 Git 저장소의 부모 디렉토리에 {프로젝트명}-Worktree 폴더 생성

  Returns:
      Path: Worktree 루트 경로

  Example:
      현재: /Users/.../project/RomRom-FE
      반환: /Users/.../project/RomRom-FE-Worktree
  """
  git_root = get_git_root()
  if not git_root:
    raise RuntimeError("Git 저장소 루트를 찾을 수 없습니다.")

  # 현재 Git 저장소의 이름 추출 (예: RomRom-FE)
  project_name = git_root.name

  # 부모 디렉토리에 {프로젝트명}-Worktree 폴더 생성
  worktree_root_name = f"{project_name}-Worktree"
  worktree_root = git_root.parent / worktree_root_name

  return worktree_root


def get_worktree_path(branch_name: str) -> Path:
  """
  특정 브랜치의 worktree 전체 경로 반환

  Args:
      branch_name: 브랜치명 (정규화 전)

  Returns:
      Path: Worktree 경로

  Example:
      >>> get_worktree_path("20260120_#163_Github_Projects")
      Path("/Users/.../project/RomRom-FE-Worktree/20260120_163_Github_Projects")
  """
  worktree_root = get_worktree_root()
  folder_name = normalize_branch_name(branch_name)
  return worktree_root / folder_name


def ensure_directory(path: Path) -> bool:
  """
  디렉토리가 존재하지 않으면 생성

  Args:
      path: 생성할 디렉토리 경로

  Returns:
      bool: 성공 여부
  """
  try:
    path.mkdir(parents=True, exist_ok=True)
    return True
  except Exception as e:
    print_error(f"디렉토리 생성 실패: {e}")
    return False


# ===================================================================
# 메인 워크플로우
# ===================================================================

def main() -> int:
  """
  메인 워크플로우

  Returns:
      int: Exit code (0: 성공, 1: 실패)
  """
  print_header()

  # 1. 인자 확인
  if len(sys.argv) < 2:
    print_error("브랜치명이 제공되지 않았습니다.")
    print()
    print("사용법:")
    print(f"  python {sys.argv[0]} <branch_name>")
    print()
    print("예시:")
    print(f'  python {sys.argv[0]} "20260120_#163_Github_Projects_에_대한_템플릿_개발_필요"')
    return 1

  branch_name = sys.argv[1].strip()

  if not branch_name:
    print_error("브랜치명이 비어있습니다.")
    return 1

  print_step("📋", f"입력된 브랜치: {branch_name}")

  # 2. Git 저장소 확인
  if not is_git_repository():
    print_error("현재 디렉토리가 Git 저장소가 아닙니다.")
    return 1

  # 3. 브랜치명 정규화
  folder_name = normalize_branch_name(branch_name)
  print_step("📁", f"폴더명: {folder_name}")
  print()

  # 4. 브랜치 존재 확인
  print_step("🔍", "브랜치 확인 중...")

  if not branch_exists(branch_name):
    print_warning("브랜치가 존재하지 않습니다.")

    current_branch = get_current_branch()
    if current_branch:
      print_step("🔄", f"현재 브랜치({current_branch})에서 새 브랜치 생성 중...")
    else:
      print_step("🔄", "새 브랜치 생성 중...")

    if not create_branch(branch_name):
      print_error("브랜치 생성에 실패했습니다.")
      return 1

    print_success("브랜치 생성 완료!")
  else:
    print_success("브랜치가 이미 존재합니다.")

  print()

  # 5. Worktree 경로 계산
  try:
    worktree_path = get_worktree_path(branch_name)
  except RuntimeError as e:
    print_error(str(e))
    return 1

  print_step("📂", f"Worktree 경로: {worktree_path}")
  print()

  # 6. Worktree 존재 확인
  print_step("🔍", "Worktree 확인 중...")

  if is_worktree_exists(worktree_path):
    print_info("Worktree가 이미 존재합니다.")
    print()
    print_step("📍", f"경로: {worktree_path.resolve()}")
    return 0

  # 7. Worktree 루트 디렉토리 생성
  worktree_root = get_worktree_root()
  if not ensure_directory(worktree_root):
    return 1

  # 8. Worktree 생성
  print_step("🔄", "Worktree 생성 중...")

  result = create_worktree(branch_name, worktree_path)

  if result['success']:
    if result['is_existing']:
      print_info(result['message'])
    else:
      print_success(result['message'])

    print()
    print_step("📍", f"경로: {result['path']}")
    return 0
  else:
    print_error(result['message'])
    return 1


# ===================================================================
# 엔트리 포인트
# ===================================================================

if __name__ == "__main__":
  try:
    exit_code = main()
    sys.exit(exit_code)
  except KeyboardInterrupt:
    print()
    print_warning("사용자에 의해 중단되었습니다.")
    sys.exit(130)
  except Exception as e:
    print()
    print_error(f"예상치 못한 오류가 발생했습니다: {e}")
    sys.exit(1)
