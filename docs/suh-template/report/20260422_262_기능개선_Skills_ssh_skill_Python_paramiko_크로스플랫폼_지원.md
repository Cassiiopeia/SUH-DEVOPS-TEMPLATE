# 구현 완료 보고 — #262 ssh skill Python paramiko 기반 크로스플랫폼 지원

## 개요

sshpass 의존성을 제거하고 범용 SSH 접속 스킬(`cassiiopeia:ssh`)을 신규 추가했다.
macOS/Linux/Windows 모두 지원하며 비밀번호·PEM 키 인증을 모두 지원한다.

## 변경 파일

- `skills/ssh/SKILL.md` — 신규 생성
- `skills/ssh/config.example.json` — 신규 생성
- `CLAUDE.md` — skill routing에 `cassiiopeia:ssh` 추가
- `README.md` — Skills 목록 24종 → 25종, ssh 스킬 항목 추가
- `docs/SKILLS.md` — ssh 스킬 상세 설명 추가

## 구현 내용

**범용 SSH 접속 스킬 (`skills/ssh/SKILL.md`)**

- AWS EC2, 시놀로지 NAS, 일반 Linux 서버 등 SSH 접근 가능한 모든 서버 지원
- 인증 방식 2가지: `auth: "password"` (sshpass) / `auth: "key"` (PEM 키)
- 서버 정보를 `~/.suh-template/config/ssh.config.json`에 저장, 플러그인 업데이트와 무관하게 영구 보존
- `instances` 배열로 여러 서버 등록 후 이름으로 선택 가능
- 시놀로지 NAS 특이사항 별도 섹션으로 분리 (docker 경로, wget 대체, sudo 제한 등)
- 자주 만나는 함정 표 포함 (Permission denied, command not found, Connection refused 등)

**config 스키마 (`skills/ssh/config.example.json`)**

```json
{
  "instances": [
    {
      "name": "집 NAS",
      "host": "your-nas.synology.me",
      "port": 2022,
      "user": "your-username",
      "auth": "password",
      "password": "your-password",
      "key_path": null,
      "default": true
    }
  ]
}
```

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/262
