### 📌 작업 개요
Synology PR/Issue Preview 시스템에 **특정 브랜치를 명시적으로 지정**하여 build/destroy/status 명령을 실행할 수 있는 기능 추가. 기존에는 현재 Issue/PR의 브랜치만 제어 가능했으나, 이제 어떤 Issue/PR에서든 다른 브랜치의 Preview 환경을 제어할 수 있음.

**이슈**: [#181](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/181)

### 🎯 구현 목표
- 기존 traefik에 올라가 있는 컨테이너를 다른 Issue/PR에서 삭제 가능하도록 개선
- 브랜치 댓글이 수정되거나 잘못된 경우 별도 제어 가능하도록 구현
- 기존 명령어와의 하위 호환성 100% 유지

### ✅ 구현 내용

#### 1. 명령어 형식 확장
- **기존 명령어** (변경 없음): `@suh-lab server build/destroy/status`
- **새 명령어** (브랜치 지정): `@suh-lab server build/destroy/status <브랜치명>`

사용 예시:
```
@suh-lab server build 20260127_#16_AI서버_장소추출
@suh-lab server destroy feature/my-branch
@suh-lab server status main
```

#### 2. check-command Job 확장
- **파일**: `PROJECT-PYTHON-SYNOLOGY-PR-PREVIEW.yaml`, `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml`
- **변경 내용**: 명령어 파싱 로직에 브랜치 파라미터 추출 기능 추가
- **새 output**: `custom_branch`, `is_custom_branch`

정규식 패턴:
```bash
@suh-lab[[:space:]]+server[[:space:]]+build([[:space:]]+([^[:space:]]+))?
```

#### 3. 브랜치명 → 컨테이너 네이밍 로직
브랜치명에서 `#번호` 패턴을 추출하여 기존 네이밍 규칙과 동일하게 처리:

| 조건 | 컨테이너명 | 도메인 |
|------|-----------|--------|
| `#번호` 패턴 있음 | `{PROJECT}-pr-{번호}` | `{PROJECT}-pr-{번호}.pr.suhsaechan.kr` |
| `#번호` 패턴 없음 | `{PROJECT}-custom-{hash}` | `{PROJECT}-custom-{hash}.pr.suhsaechan.kr` |

해시 생성 로직 (JavaScript):
```javascript
let hash = 0;
for (let i = 0; i < branchName.length; i++) {
  hash = ((hash << 5) - hash) + branchName.charCodeAt(i);
  hash = hash & hash;
}
const hashStr = Math.abs(hash).toString(16).slice(-6).padStart(6, '0');
```

#### 4. 새 Job 3개 추가 (Python, Spring 각각)
- **build-preview-custom-branch**: 커스텀 브랜치 빌드 및 배포
- **destroy-preview-custom-branch**: 커스텀 브랜치 Preview 삭제
- **check-status-custom-branch**: 커스텀 브랜치 상태 확인

각 Job의 핵심 로직:
1. 브랜치명에서 Issue 번호 또는 해시 추출
2. GitHub API로 브랜치 존재 여부 확인
3. 브랜치 없으면 에러 댓글 생성 후 종료
4. 브랜치 있으면 빌드/삭제/상태 확인 진행

#### 5. 기존 Job 조건 수정
- `build-preview-pr`, `build-preview-issue`, `get-branch-from-issue` 등에 `is_custom_branch != 'true'` 조건 추가
- 커스텀 브랜치 명령어 실행 시 기존 Job이 실행되지 않도록 분기 처리

#### 6. 배포 완료 댓글 UI 업데이트
모든 배포 완료 댓글에 "고급 명령어" 섹션 추가 (접힌 상태):

```markdown
<details>
<summary>🔧 고급 명령어 (다른 Issue/PR에서 제어)</summary>

@suh-lab server build ${branchName}
@suh-lab server destroy ${branchName}
@suh-lab server status ${branchName}

</details>
```

### 🔧 주요 변경사항 상세

#### PROJECT-PYTHON-SYNOLOGY-PR-PREVIEW.yaml
- check-command Job outputs에 `custom_branch`, `is_custom_branch` 추가
- 명령어 파싱 정규식 확장 (공백으로 구분된 브랜치명 추출)
- 기존 Job들에 `is_custom_branch != 'true'` 조건 추가
- Custom Branch Job 3개 추가 (~400줄)
- PR/Issue Preview 완료 댓글에 고급 명령어 섹션 추가

#### PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml
- Python 워크플로우와 동일한 변경사항 적용
- Spring 빌드 로직 (Gradle) 유지하면서 커스텀 브랜치 지원 추가

**특이사항**:
- 브랜치가 존재하지 않을 경우 명확한 에러 메시지와 확인 사항을 댓글로 안내
- 기존 명령어는 100% 하위 호환성 유지 (파라미터 없으면 현재 Issue/PR 브랜치 사용)

### 📦 수정 파일 목록

| 파일 | 변경 내용 |
|------|----------|
| `.github/workflows/project-types/python/synology/PROJECT-PYTHON-SYNOLOGY-PR-PREVIEW.yaml` | 명령어 파싱 확장, 새 Job 3개 추가, 댓글 UI 업데이트 |
| `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml` | 동일한 변경사항 적용 |

### 🧪 테스트 시나리오

1. **기존 명령어 호환성 테스트**
   - `@suh-lab server build` → 현재 Issue/PR 브랜치로 정상 동작
   - `@suh-lab server destroy` → 현재 Issue/PR 브랜치 삭제
   - `@suh-lab server status` → 현재 Issue/PR 상태 확인

2. **새 명령어 테스트 (#번호 패턴 있는 브랜치)**
   - `@suh-lab server build 20260127_#16_test` → 컨테이너명 `{PROJECT}-pr-16`
   - 도메인: `{PROJECT}-pr-16.pr.suhsaechan.kr`

3. **새 명령어 테스트 (#번호 패턴 없는 브랜치)**
   - `@suh-lab server build feature/my-branch` → 컨테이너명 `{PROJECT}-custom-{hash}`

4. **에러 처리 테스트**
   - 존재하지 않는 브랜치 지정 시 에러 댓글 생성 확인

### 📌 참고사항
- 동일한 `#번호`를 가진 브랜치는 같은 컨테이너를 덮어씀 (의도된 동작)
- 해시 기반 컨테이너는 브랜치명이 완전히 같아야 동일 해시 생성
- 커스텀 브랜치 배포 완료 댓글에는 해당 브랜치 전용 명령어가 표시됨
