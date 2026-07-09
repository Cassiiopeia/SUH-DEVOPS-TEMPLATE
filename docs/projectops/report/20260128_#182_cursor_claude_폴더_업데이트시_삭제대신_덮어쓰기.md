### 📌 작업 개요

`--mode commands` 실행 시 `.cursor`, `.claude` 폴더를 삭제 후 복사하던 방식에서 **기존 파일 보존 + 덮어쓰기** 방식으로 변경

**이슈**: [#182](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/182)

---

### 🔍 문제 분석

기존 `Install-CustomCommand` / `install_custom_command` 함수에서 폴더 전체를 삭제(`rm -rf`, `Remove-Item -Recurse`) 후 새로 복사하는 방식 사용

```bash
# 기존 코드 (문제)
if [ -d "$folder_name" ]; then
    rm -rf "$folder_name"
    print_info "기존 $folder_name 폴더 삭제됨"  # ← 이 로그!
fi
```

사용자가 직접 추가한 커스텀 명령어 파일이 삭제되는 문제 발생

---

### ✅ 구현 내용

#### 1. 폴더 삭제 로직 제거 (PS1)
- **파일**: `template_integrator.ps1`
- **위치**: `Install-CustomCommand` 함수 (1920-1927줄)
- **변경 내용**: `Remove-Item -Recurse -Force` 삭제, 로그 메시지 변경
- **이유**: 기존 커스텀 명령어 파일 보존 필요

#### 2. 폴더 삭제 로직 제거 (SH)
- **파일**: `template_integrator.sh`
- **위치**: `install_custom_command` 함수 (1950-1957줄)
- **변경 내용**: `rm -rf` 삭제, 로그 메시지 변경
- **이유**: 기존 커스텀 명령어 파일 보존 필요

#### 3. 경고 메시지 수정 (PS1/SH)
- **파일**: `template_integrator.ps1`, `template_integrator.sh`
- **위치**: `Copy-CustomCommands` / `copy_custom_commands` 함수
- **변경 내용**: 경고 문구 수정
  - 이전: "기존 설정이 완전히 삭제되고 새로운 설정으로 대체됩니다!"
  - 이후: "기존 설정 파일이 덮어쓰기됩니다! (기존에 추가한 파일은 보존됨)"

---

### 🔧 주요 변경사항 상세

#### Install-CustomCommand (PowerShell)

**변경 전**:
```powershell
if (Test-Path $FolderName) {
    Remove-Item -Path $FolderName -Recurse -Force
    Print-Info "기존 $FolderName 폴더 삭제됨"
}
New-Item -Path $FolderName -ItemType Directory -Force | Out-Null
```

**변경 후**:
```powershell
if (Test-Path $FolderName) {
    Print-Info "기존 $FolderName 폴더에 덮어쓰기"
} else {
    New-Item -Path $FolderName -ItemType Directory -Force | Out-Null
}
```

#### install_custom_command (Bash)

**변경 전**:
```bash
if [ -d "$folder_name" ]; then
    rm -rf "$folder_name"
    print_info "기존 $folder_name 폴더 삭제됨"
fi
mkdir -p "$folder_name"
```

**변경 후**:
```bash
if [ -d "$folder_name" ]; then
    print_info "기존 $folder_name 폴더에 덮어쓰기"
else
    mkdir -p "$folder_name"
fi
```

**특이사항**:
- `Copy-Item -Recurse -Force` / `cp -r` 명령어는 기존 파일을 덮어쓰되, 템플릿에 없는 파일은 그대로 보존
- 사용자가 추가한 커스텀 명령어 파일(예: `my-custom.md`)은 삭제되지 않음

---

### 🧪 테스트 및 검증

1. 테스트용 프로젝트에 `.claude/commands/my-custom.md` 파일 생성
2. `--mode commands` 실행
3. `my-custom.md` 파일이 삭제되지 않고 보존되는지 확인
4. 템플릿의 md 파일이 정상 복사되는지 확인

---

### 📌 참고사항

| 모드 | 동작 | 기존 파일 |
|------|------|----------|
| `full` / `interactive` | 덮어쓰기 (merge) | 보존 ✅ |
| `commands` | ~~삭제 후 복사~~ → 덮어쓰기 | 보존 ✅ |

- 일반 통합 모드(`Copy-ClaudeFolder`)는 기존부터 덮어쓰기 방식
- `commands` 모드만 삭제 후 복사 방식이었으며, 이번 수정으로 동일하게 덮어쓰기 방식으로 통일
