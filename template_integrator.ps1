# ===================================================================
# ⚠️ template_integrator.ps1 지원 종료 (EOF) — #458
# ===================================================================
#
# projectops 통합은 npx 단일 경로로 전환되었습니다.
# 이 파일은 안내용 shim이며 다음 minor 버전에서 제거됩니다.
#
# 대체 경로:
#   npx projectops           # 대화형 마법사 (통합/업데이트/스킬 설치 전부)
#   npx projectops --help    # 전체 옵션
# ===================================================================
Write-Host ""
Write-Host "⚠️  template_integrator.ps1 은 지원이 종료되었습니다 (#458)." -ForegroundColor Yellow
Write-Host ""
Write-Host "   projectops 통합은 이제 npx 한 가지 경로만 지원합니다:"
Write-Host ""
Write-Host "     npx projectops           # 대화형 마법사" -ForegroundColor Cyan
Write-Host "     npx projectops --help    # 전체 옵션 (비대화형 포함)" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Node.js 20.12 이상이 필요합니다 → https://nodejs.org"
Write-Host "   자세한 안내: https://github.com/Cassiiopeia/projectops#readme"
Write-Host ""
# 파일로 직접 실행된 경우만 비-0 종료 (iex 원격 실행에서 exit는 사용자 셸을 닫으므로 회피)
if ($MyInvocation.MyCommand.Path) { exit 1 }
