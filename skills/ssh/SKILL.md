---
name: ssh
description: "원격 서버에 SSH로 접속해 명령을 실행하고 결과를 확인하는 skill. AWS EC2, 시놀로지 NAS, 일반 Linux 서버 등 모든 SSH 접근 가능한 서버에 사용한다. 사용자가 '서버 확인해줘', '로그 봐줘', 'EC2 접속해', '시놀로지 접속해', 'prod 검수해줘', '서버 상태 확인', '배포 됐는지 확인해줘', '서버에서 ~해줘' 등을 언급하면 이 skill을 사용한다."
version: 1.0.0
---

# SSH — 원격 서버 SSH 접근

AWS EC2, 시놀로지 NAS, 일반 Linux 서버 등 SSH 접근 가능한 모든 서버에 접속해 명령을 실행하고 결과를 보고한다.

---

## 언제 사용하는가

- 서버 상태 확인, 로그 조회, 파일 확인 등 SSH로 할 수 있는 모든 작업
- CI/CD 배포 후 서버 검수
- "서버 들어가서 ~해줘" 류의 요청

**이때는 쓰지 않는다**: 시놀로지 DSM 역방향 프록시·도메인 설정 변경 → `cassiiopeia:synology-expose` 사용.

---

## 사용 전 준비

Config 파일 경로: `{HOME}/.suh-template/config/ssh.config.json`

파일이 없으면 아래 "Config 초기 설정" 절차로 대화형 수집 후 생성한다.

---

## Config 스키마

```json
{
  "instances": [
    {
      "name": "서버 식별 이름 (예: prod-api)",
      "host": "your-server.example.com",
      "port": 22,
      "user": "your-username",
      "auth": "password",
      "password": "your-password",
      "key_path": null,
      "default": true
    }
  ]
}
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `name` | ✅ | 서버 식별 이름 |
| `host` | ✅ | 호스트명 또는 IP |
| `port` | ✅ | SSH 포트 (기본: 22) |
| `user` | ✅ | SSH 사용자명 |
| `auth` | ✅ | 인증 방식: `"password"` 또는 `"key"` |
| `password` | auth=password 시 ✅ | SSH 비밀번호 |
| `key_path` | auth=key 시 ✅ | PEM 키 파일 절대 경로 (예: `~/.ssh/my-key.pem`) |
| `default` | — | 여러 인스턴스 중 기본 선택 여부 |

---

## Config 초기 설정

파일이 없으면 아래 순서로 하나씩 수집한다 (한 메시지 = 한 항목):

1. 호스트명 또는 IP (`host`)
2. SSH 포트 (`port`, 모르면 22 제안)
3. 사용자명 (`user`)
4. 인증 방식 선택:
   - 1) 비밀번호 (`password`)
   - 2) PEM 키 (`key`)
5. 선택에 따라 비밀번호 또는 키 경로 수집

수집 완료 후 `Write` 도구로 저장.

---

## 작업 흐름

### Phase 0 — Config 로드

1. `Read` 도구로 `{HOME}/.suh-template/config/ssh.config.json` 읽기
2. instances가 1개면 자동 선택. 여러 개면 번호 매겨 선택하게 한다.
3. 파일 없으면 "Config 초기 설정" 진행.

### Phase 1 — SSH 명령 실행

**비밀번호 인증 (auth=password):**

sshpass: 비밀번호 방식 SSH를 스크립트에서 자동으로 실행하기 위한 도구.

```bash
# sshpass 없으면: brew install hudochenkov/sshpass/sshpass (macOS) / sudo apt-get install sshpass (Linux)
sshpass -p '{password}' ssh \
  -o StrictHostKeyChecking=no \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -p {port} \
  {user}@{host} \
  "{command}"
```

**PEM 키 인증 (auth=key, AWS EC2 등):**

```bash
ssh -i {key_path} \
  -o StrictHostKeyChecking=no \
  -p {port} \
  {user}@{host} \
  "{command}"
```

사용자가 실행할 명령을 명시하지 않았으면 목적에 맞는 명령을 agent가 판단해 실행한다.

### Phase 2 — 결과 보고

실행 결과를 사용자에게 요약해 보고한다. 에러가 있으면 원인과 해결 방법도 함께 제시한다.

---

## 시놀로지 NAS 특이사항

시놀로지 NAS는 일반 Linux 서버와 환경이 다르다.

| 항목 | 일반 서버 | 시놀로지 NAS |
|------|-----------|--------------|
| Docker 경로 | `docker` | `/var/packages/ContainerManager/target/usr/bin/docker` |
| 컨테이너 내 curl | 대부분 있음 | 없는 경우 많음 → `wget`으로 대체 |
| sudo | 일반적으로 가능 | SSH 비대화형에서 제한됨 |
| SSH 기본 포트 | 22 | 커스텀 포트 사용 가능 (예: 2022) |

**시놀로지에서 HTTP 확인 (curl 대신 wget):**
```bash
wget -q -O - --server-response http://localhost:{port}/{path} 2>&1 | head -5
```

---

## 자주 만나는 함정

| 증상 | 원인 | 해결 |
|------|------|------|
| `Permission denied, please try again` | sshpass 비밀번호 전달 실패 | `-o PreferredAuthentications=password -o PubkeyAuthentication=no` 옵션 확인 |
| `command not found` | PATH 미등록 바이너리 | 절대 경로로 실행 (`which`로 먼저 경로 확인) |
| `Connection refused` | 포트 오류 또는 서비스 미기동 | config `port` 확인 후 재시도 |
| `sudo: a terminal is required` | 비대화형 SSH에서 sudo 불가 | `echo '{password}' \| sudo -S {command}` 패턴 사용 |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | PEM 키 권한 문제 | `chmod 400 {key_path}` 실행 후 재시도 |
