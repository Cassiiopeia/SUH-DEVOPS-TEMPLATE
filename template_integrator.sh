#!/bin/bash
# ===================================================================
# ⚠️ template_integrator.sh 지원 종료 (EOF) — #458
# ===================================================================
#
# projectops 통합은 npx 단일 경로로 전환되었습니다.
# 이 파일은 안내용 shim이며 다음 minor 버전에서 제거됩니다.
#
# 대체 경로:
#   npx projectops           # 대화형 마법사 (통합/업데이트/스킬 설치 전부)
#   npx projectops --help    # 전체 옵션
#
# 구 플래그 대응: --mode full → 마법사에서 '전체 통합' 선택 (비대화형은 --help 참조)
# ===================================================================
echo ""
echo "⚠️  template_integrator.sh 는 지원이 종료되었습니다 (#458)."
echo ""
echo "   projectops 통합은 이제 npx 한 가지 경로만 지원합니다:"
echo ""
echo "     npx projectops           # 대화형 마법사"
echo "     npx projectops --help    # 전체 옵션 (비대화형 포함)"
echo ""
echo "   Node.js 20.12 이상이 필요합니다 → https://nodejs.org"
echo "   자세한 안내: https://github.com/Cassiiopeia/projectops#readme"
echo ""
exit 1
