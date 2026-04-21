### 📌 작업 개요
시놀로지 NAS에 웹 서비스를 외부 도메인으로 노출할 때 반복되는 3단계 작업(DNS 레코드 추가, 역방향 프록시 설정, 인증서 발급)을 자동 안내하는 `synology-expose` skill 추가

---

### 🎯 구현 목표
- 시놀로지 서비스 외부 노출 절차를 skill로 템플릿화
- 설정 파일 기반으로 사용자 환경 정보 관리 (다중 도메인 지원)
- DNS 제공자별 분기 안내 (Cloudflare, Route53, 기타)
- 웹소켓 서비스 추가 설정 지원

---

### ✅ 구현 내용

#### Skill 본체 작성
- **파일**: `skills/synology-expose/SKILL.md`
- **변경 내용**: 시놀로지 서비스 외부 노출 3단계 가이드 skill 작성
- **트리거 키워드**: 서비스 외부 노출, 도메인 연결, 역방향 프록시 추가, 서브도메인 설정, HTTPS 설정, 인증서 발급, 웹소켓 프록시 등

#### 설정 파일 스키마 정의 (`.synology-expose.json`)
- **저장 위치**: 홈 디렉토리(`~/.synology-expose.json`) 또는 프로젝트 루트
- **구조**: 다중 도메인 지원을 위한 배열 형태

```json
{
  "domains": [
    {
      "domain": "example.com",
      "ddnsAddress": "my-nas.synology.me",
      "dnsProvider": "cloudflare",
      "dnsRecordType": "CNAME",
      "dnsProxyStatus": "DNS only"
    }
  ],
  "email": "user@example.com"
}
```

---

### 🔧 주요 기능 상세

#### 초기 설정 (설정 파일 없는 경우)
설정 파일이 없으면 대화형으로 하나씩 질문하며 설정 정보 수집. 질문 개수를 고정하지 않고 응답에 따라 후속 질문 결정

수집 항목: 도메인명, 시놀로지 DDNS 주소, DNS 제공자, 이메일, 저장 위치
- DNS 레코드 타입은 DDNS 주소/고정 IP 입력값에서 자동 판단 (별도 질문 안 함)
- Cloudflare인 경우 Proxy status 추가 질문
- 전문 용어(CNAME, Let's Encrypt 등)는 모르는 사람도 있다고 가정하고 설명 포함

#### Step 1: DNS 레코드 추가
DNS 제공자별 분기 안내:
- **Cloudflare**: Dashboard > DNS > Records에서 CNAME/A 레코드 추가. 서브도메인에 점(.)이 포함된 경우 Proxied 사용 불가 안내
- **Route53**: AWS Console > Route 53 > Hosted zones에서 레코드 생성
- **기타** (gabia, 직접관리 등): 범용 DNS 레코드 추가 안내

#### Step 2: 시놀로지 역방향 프록시 설정
DSM > 제어판 > 로그인 포털 > 고급 > 역방향 프록시에서 2개 항목 생성:
- **항목 1**: HTTPS 프록시 (443 → 로컬포트, HSTS 활성화)
- **항목 2**: HTTP → HTTPS 리다이렉트 (80 → 443)

**웹소켓 서비스 추가 설정** (조건부):
- 사용자 지정 머리글 9개 추가 (Upgrade, Connection, Sec-WebSocket-*, X-Forwarded-*, Authorization)
- 고급 설정: 타임아웃 조정 (기본 60초, 필요시 증가), HTTP 1.1, 오류 페이지 재발송

#### Step 3: Let's Encrypt 인증서 발급 및 연결
- DSM > 제어판 > 보안 > 인증서에서 Let's Encrypt 인증서 발급
- 인증서 설정에서 해당 서비스에 발급된 인증서 연결

#### 서비스 정보 자동 추론
사용자가 제공한 정보에서 서비스명, 서브도메인, 포트, 웹소켓 여부를 최대한 자동 추론. 확실히 판단 가능한 건 물어보지 않고 애매한 것만 추가 질문

---

### 🧪 테스트 및 검증
- **기본 케이스**: 일반 서비스(Mongo-Express, 포트 8081) 외부 노출 시뮬레이션 → 3단계 안내 정상 출력 확인
- **웹소켓 케이스**: 웹소켓 사용 서비스(채팅 서버, 포트 8080) → 사용자 지정 머리글 + 고급 설정 포함 확인
- **신규 사용자 케이스**: 설정 파일 없는 상태에서 초기 설정 → 단계별 질문 흐름 정상 동작 확인

---

### 📌 참고사항
- skill은 `cassiiopeia` 플러그인의 일부로 배포. `suh-github-template` repo에 커밋/푸시 후 플러그인 업데이트하면 `cassiiopeia:synology-expose`로 호출 가능
- 설정 파일에 개인 정보(도메인, 이메일 등)가 포함되므로 `.gitignore`에 `.synology-expose.json` 추가 권장
- skill 본문에는 하드코딩된 개인 정보 없음. 모든 예시는 `{도메인}`, `example.com` 등 범용 플레이스홀더 사용
