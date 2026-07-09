# PLUGIN-VERSION-SYNC가 자동 트리거되지 않아 플러그인 버전이 동기화되지 않음

## 개요

`PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC` 워크플로우가 VERSION-CONTROL 이후 자동 트리거되지 않아 `plugin.json`과 `marketplace.json`의 버전이 `version.yml`(2.9.3)과 동기화되지 않고 2.9.0에 멈춰 있던 버그를 수정했다. 근본 원인은 GitHub Actions의 `GITHUB_TOKEN` 정책으로 인해 후속 워크플로우가 트리거되지 않는 것이었으며, 트리거 조건을 `deploy push`로 변경하여 해결했다.

## 변경 사항

### 워크플로우 수정
- `.github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml`: 트리거 조건 변경 및 버전 추출 방식 통일

## 주요 구현 내용

### 1. 트리거 조건 변경

기존에는 `main` 브랜치 push 시 `version.yml` 파일 변경을 감지하여 트리거했다. 그러나 `PROJECT-COMMON-VERSION-CONTROL`이 `GITHUB_TOKEN`으로 version.yml을 변경 & 푸시하기 때문에, GitHub의 무한 루프 방지 정책에 의해 후속 워크플로우가 트리거되지 않았다.

VERSION-CONTROL은 공통 워크플로우로 PAT 토큰으로 변경할 수 없으므로, PLUGIN-VERSION-SYNC의 트리거를 `deploy` 브랜치 push로 변경했다. deploy 푸시는 사용자/auto-merge에 의한 것이므로 `GITHUB_TOKEN` 트리거 제한에 해당하지 않는다.

```yaml
# Before
on:
  push:
    branches: ["main"]
    paths:
      - 'version.yml'

# After
on:
  push:
    branches: ["deploy"]
```

### 2. 버전 추출 방식 통일

기존에는 `grep + sed`로 version.yml에서 버전을 직접 파싱했으나, 다른 모든 워크플로우가 사용하는 `version_manager.sh get` 패턴으로 통일했다.

```bash
# Before
VERSION=$(grep -E '^version:' version.yml | sed 's/version:[[:space:]]*...')

# After
chmod +x .github/scripts/version_manager.sh
VERSION=$(./.github/scripts/version_manager.sh get | tail -n 1)
```

## 주의사항

- 이 워크플로우는 `deploy` 브랜치 push를 트리거로 사용하므로, deploy 머지가 정상적으로 이루어져야 plugin 버전이 동기화된다
- 체크아웃은 `ref: main`으로 하여 version.yml의 최신 버전을 읽고, 커밋도 main에 푸시한다
- 첫 deploy 푸시 시 기존 밀린 버전(2.9.0 → 현재 버전)이 한 번에 동기화될 예정
