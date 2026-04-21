# Issue에서 라벨 제거 시 무한 루프 버그 수정

**이슈**: [#178](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/178)

---

### 📌 작업 개요

Issue에서 Status 라벨(예: "작업중")을 제거해도 Cloudflare Worker가 다시 라벨을 추가하는 무한 루프 버그 수정. 양방향 동기화(GitHub Actions ↔ Cloudflare Worker) 충돌 문제 해결.

---

### 🔍 문제 분석

#### 근본 원인 1: Worker가 모든 edited 이벤트에 반응
- Cloudflare Worker가 `projects_v2_item edited` 이벤트를 받으면 무조건 동기화 실행
- Status 필드가 아닌 다른 필드(Iteration, Priority 등) 변경에도 반응
- "현재 Status와 Label이 다르네? → 동기화!" 하고 라벨 추가

#### 근본 원인 2: 워크플로우 중복 실행 (3회)
```
라벨 A 제거 + 라벨 B 추가 시:
1. unlabeled (라벨 A 제거) → 워크플로우 실행
2. labeled (라벨 B 추가) → 워크플로우 실행
3. Worker가 라벨 추가 → labeled → 워크플로우 또 실행
```

#### 무한 루프 발생 과정
```
[사용자: 라벨 제거]
       ↓
[GitHub Actions unlabeled 트리거]
       ↓
[Cloudflare Worker: Status가 아직 "작업중"이므로 라벨 다시 추가]
       ↓
[GitHub Actions labeled 트리거]
       ↓
[무한 반복...]
```

---

### ✅ 구현 내용

#### 1. Worker에 Status 필드 ID 필터 추가
- **파일**: `.github/util/common/github-projects-sync-worker/src/index.ts`
- **변경 내용**:
  - 인메모리 캐시 변수 추가 (`cachedStatusFieldId`, `cacheTimestamp`, `CACHE_TTL`)
  - `getStatusFieldId()` 함수 추가 (Organization/User 프로젝트 모두 지원)
  - Webhook payload의 `changes.field_value.field_node_id`와 Status 필드 ID 비교
- **이유**: Status 필드 변경이 아닌 이벤트는 무시하여 불필요한 동기화 방지

#### 2. 워크플로우 트리거에서 unlabeled 제거
- **파일**: `.github/workflows/PROJECT-COMMON-PROJECTS-SYNC-MANAGER.yaml`
- **파일**: `.github/workflows/project-types/common/PROJECT-COMMON-PROJECTS-SYNC-MANAGER.yaml`
- **변경 내용**: `types: [labeled, unlabeled]` → `types: [labeled]`
- **이유**: 라벨 제거 시 Projects Status 변경 불필요, 라벨 추가 시에만 동기화하면 충분

---

### 🔧 주요 변경사항 상세

#### index.ts - 인메모리 캐시

```typescript
// Status 필드 ID 인메모리 캐시
let cachedStatusFieldId: string | null = null;
let cacheTimestamp = 0;
const CACHE_TTL = 3600000; // 1시간
```

- 1시간 TTL로 불필요한 API 호출 최소화
- 시간당 1회만 GraphQL 쿼리 실행

#### index.ts - getStatusFieldId() 함수

- Organization 프로젝트와 User 프로젝트 모두 지원
- Organization 프로젝트 먼저 시도, 실패 시 User 프로젝트로 시도
- 조회된 필드 ID는 캐시하여 재사용

#### index.ts - Status 필드 변경 필터

```typescript
// 7. Status 필드 변경인지 확인
if (payload.changes?.field_value) {
  const changedFieldId = payload.changes.field_value.field_node_id;
  const statusFieldId = await getStatusFieldId(env);

  if (statusFieldId && changedFieldId !== statusFieldId) {
    console.log(`ℹ️ Status 필드 변경이 아님. 건너뜀`);
    return new Response('Ignored: not status field change', { status: 200 });
  }
} else {
  console.log(`ℹ️ field_value 변경 정보 없음, 동기화 진행`);
}
```

**특이사항**:
- `field_value`가 없는 경우에도 로깅 추가하여 디버깅 용이
- Status 필드가 아닌 변경은 조기 반환으로 동기화 생략

---

### 📊 비용 분석

| 항목 | 추가 사용량 | 무료 한도 | 영향 |
|------|-------------|-----------|------|
| GitHub API | +1 요청/시간 (캐시) | 5,000/시간 | 무시할 수준 |
| KV Storage | 0 (사용 안함) | 1GB | 불필요 |
| Worker CPU | +5ms 정도 | 10ms/요청 | 여유 있음 |

이슈 10,000개까지 완전 무료로 운영 가능.

---

### 🧪 테스트 및 검증

#### 배포 방법
```bash
cd .github/util/common/github-projects-sync-worker
wrangler deploy
```

#### 로그 모니터링
```bash
wrangler tail
```

#### 테스트 케이스

| 테스트 | 예상 결과 |
|--------|-----------|
| Issue에서 라벨 제거 | Worker: "Status 필드 변경이 아님. 건너뜀" 출력, 라벨 다시 추가 안됨 |
| Projects에서 Status 변경 | Worker 정상 동기화, Actions 1회만 실행 |
| Issue에서 라벨 변경 | Actions 1회만 실행 (기존 3회 → 1회) |

---

### 📌 참고사항

- Worker 변경사항은 `wrangler deploy`로 별도 배포 필요
- 워크플로우 변경사항은 Git 커밋/푸시로 자동 적용
- 두 워크플로우 파일(루트, project-types)은 CLAUDE.md 규칙에 따라 동일하게 유지
