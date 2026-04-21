### 📌 작업 개요
Template Integrator에 Custom Command 기능 추가. Cursor IDE(.cursor)와 Claude Code(.claude) 설정 폴더를 선택적으로 설치할 수 있는 새로운 통합 옵션 구현

**보고서 파일**: `.report/20260102_#127_Custom_Command_기능_추가.md`

### 🎯 구현 목표
- 대화형 메뉴에 5번 옵션 "Custom Command만 (Cursor/Claude 설정)" 추가
- Cursor IDE, Claude Code, 또는 둘 다 선택 가능한 서브메뉴 제공
- 기존 폴더는 백업 없이 덮어쓰기 (사용자 요청사항)
- CLI 모드에서 `--mode commands` 옵션 지원

### ✅ 구현 내용

#### 1. PowerShell 스크립트 (template_integrator.ps1)

**새로운 함수 3개 추가** (1347-1454번 라인):
- **`Install-CustomCommand`**: 개별 폴더 설치 (기존 폴더 삭제 후 복사)
- **`Copy-CustomCommands`**: 경고 메시지 표시 후 타겟에 따라 설치 진행
- **`Show-CustomCommandMenu`**: 4개 옵션 서브메뉴 (Cursor/Claude/모두/취소)

**메인 메뉴 변경** (1628-1659번 라인):
- 기존 5개 → 6개 옵션으로 확장
- 5번: Custom Command, 6번: 취소

**CLI 모드 지원**:
- `Start-Integration` switch 문에 `commands` case 추가
- help 텍스트 및 파라미터 검증에 `commands` 추가

#### 2. Bash 스크립트 (template_integrator.sh)

**새로운 함수 3개 추가** (1376-1494번 라인):
- **`install_custom_command`**: 개별 폴더 설치 (rm -rf 후 cp -r)
- **`copy_custom_commands`**: 경고 메시지 + 사용자 확인 후 설치
- **`show_custom_command_menu`**: safe_read 기반 4개 옵션 서브메뉴

**메인 메뉴 변경**:
- `interactive_mode` 함수에서 6개 옵션으로 확장
- `execute_integration`에 `commands` case 추가

#### 3. README.md 업데이트

**기능 선택 목록** (93-98번 라인):
- `[ ] Custom Command만 (Cursor/Claude 설정)` 항목 추가

**문서 가이드 테이블**:
- `docs/TEMPLATE-INTEGRATOR.md` 링크 추가

#### 4. 상세 문서 생성 (docs/TEMPLATE-INTEGRATOR.md)

새로운 문서 파일 생성:
- 개요 및 설치 방법
- 모든 통합 모드 설명 (full, version, workflows, issues, commands)
- CLI 옵션 전체 참조표
- 프로젝트 타입 목록
- 각 모드별 사용 예시 (macOS/Linux, Windows)
- Custom Command 모드 상세 설명
- 문제 해결 가이드

### 🔧 주요 변경사항 상세

#### Install-CustomCommand / install_custom_command
기존 폴더를 완전히 삭제(`Remove-Item -Recurse -Force` / `rm -rf`)한 후 템플릿에서 새로 복사. 백업 파일 생성하지 않음 (사용자 요청사항 반영)

#### Copy-CustomCommands / copy_custom_commands
설치 전 경고 메시지 표시: "⚠️ 기존 설정이 완전히 삭제되고 새로운 설정으로 대체됩니다!"
Force 모드가 아닐 경우 사용자 확인 후 진행

#### 메뉴 구조 변경
```
기존:                          변경 후:
1) 전체 통합                   1) 전체 통합
2) 버전 관리 시스템만           2) 버전 관리 시스템만
3) GitHub Actions 워크플로우만  3) GitHub Actions 워크플로우만
4) 이슈/PR 템플릿만             4) 이슈/PR 템플릿만
5) 취소                        5) Custom Command만 (신규)
                               6) 취소
```

**특이사항**:
- 서브메뉴에서 Cursor만, Claude만, 둘 다 선택 가능
- 입력 검증 루프로 잘못된 입력 처리

### 📦 의존성 변경
- 없음 (기존 함수 및 유틸리티만 사용)

### 🧪 테스트 및 검증
- 대화형 모드에서 5번 선택 → 서브메뉴 표시 확인
- 각 서브메뉴 옵션(1-4) 선택 시 정상 동작 확인
- CLI 모드: `--mode commands --force` 옵션으로 자동 실행 확인
- 기존 폴더 있을 때 삭제 후 새로 복사되는지 확인

### 📌 참고사항
- `.cursor`, `.claude` 폴더는 프로젝트별 IDE 설정이므로 Git 추적 여부는 프로젝트마다 다름
- 기존 설정이 중요할 경우 사용자가 미리 백업 필요
- 문서 업데이트로 사용자 가이드 제공 완료
