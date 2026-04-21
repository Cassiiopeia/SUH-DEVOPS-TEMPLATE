# 📚 [문서][Skills] Claude Code Skills 상세 문서화 및 README 개편

## 📝 현재 문제점

현재 레포의 문서에는 다음과 같은 문제가 있습니다:

1. **README.md 상단 소개에 Claude Code Skill 플러그인 언급 없음**
   - 단순히 "GitHub 프로젝트 관리 템플릿"이라고만 쓰여 있어, 이 레포가 **Claude Code용 Skill 플러그인 마켓플레이스**이기도 하다는 점을 처음 방문자가 전혀 인지하지 못함.
   - Claude Code skills는 이 레포의 핵심 기능 중 하나인데 상단 설명에서 누락됨.

2. **README의 Skills 표가 일부만 나열되고 나머지는 애매하게 처리됨**
   - 실제 skills 폴더에는 **20개**의 Skill이 있지만, README 표에는 10개만 나열됨.
   - 나머지 10개는 `> 이 외 build, design, design-analyze, figma, ppt, refactor-analyze, testcase, suh-spring-test, init-worktree, review 스킬도 포함`이라는 한 줄로 애매하게 처리되어 있음.
   - 각 Skill이 무엇을 하는지, 언제 쓰는지 알 수 없음.

3. **docs/ 폴더에 Skills 전용 문서가 없음**
   - `docs/` 폴더에는 PR-PREVIEW.md, VERSION-CONTROL.md 등 워크플로우 관련 문서만 있고, **20개 Skill을 설명하는 전용 문서가 존재하지 않음**.
   - 사용자가 각 Skill의 정확한 용도와 사용 시나리오를 파악할 방법이 없음.

## 🛠️ 해결 방안/제안 기능

### 1. README.md 상단 개편
- 메인 타이틀 하단 설명에 **"+ Claude Code Skill 플러그인"** 문구 추가
- 서브 설명에 "GitHub Actions 자동화와 Claude Code용 DevOps Skill 20종을 한 레포에서 제공합니다" 추가

### 2. README.md Skills 섹션 전면 개편
- 10개만 나열하고 나머지를 숨기던 기존 방식 제거
- **20개 전부를 용도별 3그룹(분석형 / 구현형 / 문서·산출물 생성형)으로 분류**하여 표로 노출
- 애매한 "> 이 외..." 문구 완전 제거
- 각 Skill마다 한 줄 기능 설명 포함
- 상세 내용은 docs/SKILLS.md로 링크

### 3. docs/SKILLS.md 신설
20개 Skill 각각에 대해 **사용자 관점**에서 다음 정보를 담는 상세 가이드 작성:
- **무엇을 하나요?** (기능적 설명, 내부 로직 X)
- **수정되는 것** (파일이 수정되는지, 문서만 생성되는지 명확히)
- **돌려주는 것** (결과물이 무엇인지)
- **언제 쓰나요?** (실제 사용 시나리오)

추가로 다음 항목 포함:
- "Skill이 뭔가요?" 도입부 설명
- 설치 명령어
- 3그룹 분류 (분석형 / 구현형 / 문서·산출물 생성형)
- "어떤 Skill을 언제 쓸까?" 상황별 흐름 추천 테이블
- 플러그인 소스 및 버전 동기화 메타 정보

### 4. docs 테이블에 SKILLS.md 링크 추가
README.md의 문서 테이블에 `[Claude Code Skills 가이드](docs/SKILLS.md)` 항목 추가.

## ⚙️ 작업 내용

- [x] README.md 상단 메인/서브 설명에 Claude Code Skill 플러그인 언급 추가
- [x] README.md "Claude Code 플러그인" 섹션을 "Claude Code Skill 플러그인"으로 변경
- [x] README.md Skills 표를 3그룹(분석형/구현형/문서형)으로 재구성하여 20개 전부 나열
- [x] 기존 "> 이 외 ... 스킬도 포함" 애매한 문구 제거
- [x] docs/SKILLS.md 신규 작성 (사용자 관점 기능 설명)
- [x] README.md 문서 테이블에 docs/SKILLS.md 링크 추가

## 📌 작성된 Skill 분류 (20개)

**분석형 (6개)**: analyze, plan, design-analyze, refactor-analyze, review, troubleshoot
**구현형 (7개)**: implement, design, refactor, test, figma, build, init-worktree
**문서·산출물 생성형 (7개)**: document, issue, report, testcase, ppt, suh-spring-test, synology-expose

## 🙋‍담당자

- **문서화**:
