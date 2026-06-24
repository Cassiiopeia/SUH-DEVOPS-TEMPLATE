# 배포 env 반응형 세로 블록 UX 개선 설계 명세서 (Responsive Block Card Layout)

## 1. 개요
배포 워크플로우 통합 마법사(`template_integrator`)가 수집한 배포 env 설정들을 사용자에게 일괄 승인받기 전 보여주는 화면에서, 터미널 가로 너비에 상관없이 항상 최상의 가독성을 보장하고 가로 깨짐을 원천 차단하기 위해 **반응형 세로 블록 카드 레이아웃(Responsive Block Card Layout)**을 도입한다.

## 2. 핵심 설계 방향
- **너비 동적 감지**: 스크립트 실행 시 현재 터미널 가로 너비(Columns)를 감지한다.
- **임계값(Threshold) 분기**: 감지된 가로 너비가 **110자** 기준 미만으로 좁아지면 가로 표 출력을 해제하고, 세로형 카드 블록 형식으로 전환한다.
- **최소 코드 복잡도 (YAGNI)**: 격자선 그리기나 한글 실제 표시 폭 계산을 위해 대규모 헬퍼를 추가하지 않으므로, 단일 파일의 극도적인 가벼움과 안정성(버그 제로)을 보장한다.
- **1:1 일관성**: `.sh`(Bash)와 `.ps1`(PowerShell) 버전에 완전히 1:1 대응하도록 구현한다.

---

## 3. 화면 설계 사양 (터미널 가로 폭 < 110자 시나리오)

```text
🔅 배포 워크플로우 환경설정을 채웁니다

   ▸ 서비스 식별자 (영문 슬러그)  [spring·react·python]
     기본값: passQL

   ▸ 서비스 도메인  [spring 무중단배포(Nginx)·무중단배포(Traefik)]
     기본값: example.com

   ▸ 빌드 JDK 버전  [spring·flutter]
     기본값: 21
```

---

## 4. 언어별 세부 구현 명세

### 4.1. Bash (.sh) 명세
`wf_prompt_env_plan` 함수 내에서 너비를 감지하여 조건부 렌더러 루프를 탄다.

- **너비 감지 로직**:
  ```bash
  local _cols
  _cols=$(tput cols 2>/dev/null || echo 80)
  ```

- **렌더링 제어**:
  ```bash
  if [ "$_cols" -lt 110 ]; then
      # 좁은 화면: 세로형 반응형 블록 카드 출력
      local _k _label _scope
      for _k in "${WF_ASK_KEYS[@]}"; do
          _label=$(wf_field "$(_wf_first_type_for "$_k")" "$_k" "label")
          _scope="${WF_ASK_SCOPE[$_k]:-}"
          print_to_user "   ▸ ${_label}  [${_scope}]"
          print_to_user "     기본값: ${WF_ASK_DEFAULT[$_k]}"
          print_to_user ""
      done
  else
     # 넓은 화면: 표 형식 출력 (기존 정렬 그대로 유지)
      local _k _label
      for _k in "${WF_ASK_KEYS[@]}"; do
          _label=$(wf_field "$(_wf_first_type_for "$_k")" "$_k" "label")
          printf '   %-26s %-18s %s\n' "$_label" "${WF_ASK_DEFAULT[$_k]}" "${WF_ASK_SCOPE[$_k]}" >&2
      done
  fi
  ```

### 4.2. PowerShell (.ps1) 명세
`Invoke-WfEnvPlan` 함수 내에서 너비를 감지하여 제어한다.

- **너비 감지 로직**:
  ```powershell
  $cols = 80
  try {
      if ($Host.UI.RawUI.WindowSize.Width) { $cols = $Host.UI.RawUI.WindowSize.Width }
  } catch {}
  ```

- **렌더링 제어**:
  ```powershell
  if ($cols -lt 110) {
      # 좁은 화면: 세로형 반응형 블록 카드 출력
      foreach ($k in $script:WfAskTable.Keys) {
          $t = Get-WfFirstTypeFor $k
          $lbl = Get-WfField $t $k "label"
          $def = $script:WfAskTable[$k].Default
          $scope = $script:WfAskTable[$k].Scope
          
          Write-Host "   ▸ $lbl  [$scope]" -ForegroundColor Cyan
          Write-Host "     기본값: $def"
          Write-Host ""
      }
  } else {
      # 넓은 화면: 표 형식 출력 (기존 정렬 그대로 유지)
      foreach ($k in $script:WfAskTable.Keys) {
          $t = Get-WfFirstTypeFor $k
          $lbl = Get-WfField $t $k "label"
          $def = $script:WfAskTable[$k].Default
          $scope = $script:WfAskTable[$k].Scope
          
          Write-Host ("   {0,-26} {1,-18} {2}" -f $lbl, $def, $scope)
      }
  }
  ```

---

## 5. 검증 기준 (Definition of Done)
- **가로 폭에 따른 분기 작동 확인**: 터미널 너비를 인위적으로 조절(tput cols 스텁 및 $cols 인라인 제어 등)하여 110자 이상과 미만일 때의 정상 출력 양상을 실측하고, 가로줄 깨짐이 80자 좁은 화면에서 전혀 발생하지 않음을 증명한다.
- **동작 정합성**: 출력 방식만 조건부 분기할 뿐, prefill 등 백그라운드의 기본값 대입 기능은 한 치도 손상되지 않아야 한다 (byte-identical 최종 검증 필수).
