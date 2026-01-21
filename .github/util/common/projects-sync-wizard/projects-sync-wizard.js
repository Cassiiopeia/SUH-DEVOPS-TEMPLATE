/**
 * GitHub Projects Sync Wizard v2.0.0
 *
 * 4단계 간소화 버전:
 * 1. 프로젝트 정보 입력 (URL, Worker 이름, Labels, Webhook Secret) → ZIP 다운로드
 * 2. Worker 배포 (스크립트 실행)
 * 3. GitHub Webhook 설정
 * 4. 완료
 */

// ============================================
// 상태 관리
// ============================================

const TOTAL_STEPS = 4;

// issue-label.yml 기본 Status Labels
const DEFAULT_STATUS_LABELS = [
    '작업 전',
    '작업 중',
    '확인 대기',
    '피드백',
    '작업 완료',
    '취소'
];

let state = {
    currentStep: 1,
    projectUrl: '',
    projectType: '',       // 'org' | 'user'
    ownerName: '',         // Organization 또는 User 이름
    orgName: '',           // 하위 호환성 유지
    projectNumber: '',
    workerName: 'github-projects-sync-worker',
    statusLabels: [...DEFAULT_STATUS_LABELS],
    webhookSecret: '',
    workerUrl: '',
    repositoryUrl: '',     // User 타입일 때 Webhook 설정용 저장소 URL
    skipProjectsGuide: false  // Projects 생성 가이드 건너뛰기
};

// ============================================
// 초기화
// ============================================

document.addEventListener('DOMContentLoaded', () => {
    // 버전 정보 표시
    displayVersion();

    // 다크 모드 초기화
    initDarkMode();

    // 저장된 상태 복원
    loadState();

    // Webhook Secret 자동 생성 (없는 경우)
    if (!state.webhookSecret) {
        generateWebhookSecret();
    }

    // Step Indicator 생성
    renderStepIndicators();

    // Labels 렌더링
    renderLabels();

    // UI 초기화
    showStep(state.currentStep);
    updateNavigationButtons();

    // Worker URL 입력 이벤트
    document.getElementById('workerUrl').addEventListener('input', (e) => {
        state.workerUrl = e.target.value;
        updateWebhookPayloadUrl();
        saveState();
    });

    // Worker 이름 입력 이벤트 - 명령어 자동 업데이트
    document.getElementById('workerName').addEventListener('input', (e) => {
        state.workerName = e.target.value.trim() || 'github-projects-sync-worker';
        saveState();
        scheduleCommandUpdate();
    });

    // Webhook Secret 변경 이벤트 - 명령어 자동 업데이트
    document.getElementById('webhookSecret').addEventListener('input', () => {
        scheduleCommandUpdate();
    });

    // 초기 명령어 표시
    updateInstallCommands();
});

// ============================================
// 버전 정보
// ============================================

function displayVersion() {
    try {
        const versionJson = JSON.parse(document.getElementById('versionJson').textContent);
        document.getElementById('versionDisplay').textContent = `v${versionJson.version}`;
    } catch (e) {
        console.error('버전 정보 로드 실패:', e);
    }
}

// ============================================
// 다크 모드
// ============================================

function initDarkMode() {
    if (localStorage.getItem('darkMode') === 'true' ||
        (!localStorage.getItem('darkMode') && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
        document.documentElement.classList.add('dark');
    }
}

function toggleDarkMode() {
    document.documentElement.classList.toggle('dark');
    localStorage.setItem('darkMode', document.documentElement.classList.contains('dark'));
}

// ============================================
// 상태 저장/복원
// ============================================

function saveState() {
    localStorage.setItem('projectsSyncWizardState', JSON.stringify(state));
}

function loadState() {
    try {
        const saved = localStorage.getItem('projectsSyncWizardState');
        if (saved) {
            const parsed = JSON.parse(saved);
            state = { ...state, ...parsed };

            // UI에 상태 반영
            document.getElementById('projectUrl').value = state.projectUrl || '';
            document.getElementById('ownerName').value = state.ownerName || state.orgName || '';
            document.getElementById('orgName').value = state.orgName || '';
            document.getElementById('projectNumber').value = state.projectNumber || '';
            document.getElementById('workerName').value = state.workerName || 'github-projects-sync-worker';
            document.getElementById('webhookSecret').value = state.webhookSecret || '';
            document.getElementById('workerUrl').value = state.workerUrl || '';

            // 저장소 URL (User 타입용) - 인라인 위치
            const repoUrlInput = document.getElementById('repositoryUrl');
            if (repoUrlInput) {
                repoUrlInput.value = state.repositoryUrl || '';
            }

            // Projects 가이드 건너뛰기 체크박스
            const skipGuideCheckbox = document.getElementById('skipProjectsGuide');
            if (skipGuideCheckbox) {
                skipGuideCheckbox.checked = state.skipProjectsGuide || false;
                toggleProjectsGuide();
            }

            // 타입에 따른 UI 업데이트
            updateUIForProjectType();

            // 명령어가 이미 생성되어 있으면 표시
            updateInstallCommandDisplay();
        }
    } catch (e) {
        console.error('상태 복원 실패:', e);
    }
}

function resetWizard() {
    if (confirm('모든 설정을 초기화하시겠습니까?')) {
        localStorage.removeItem('projectsSyncWizardState');
        state = {
            currentStep: 1,
            projectUrl: '',
            projectType: '',
            ownerName: '',
            orgName: '',
            projectNumber: '',
            workerName: 'github-projects-sync-worker',
            statusLabels: [...DEFAULT_STATUS_LABELS],
            webhookSecret: '',
            workerUrl: '',
            repositoryUrl: '',
            skipProjectsGuide: false
        };
        generateWebhookSecret();
        renderLabels();
        showStep(1);
        updateNavigationButtons();

        // 입력 필드 초기화
        document.getElementById('projectUrl').value = '';
        document.getElementById('ownerName').value = '';
        document.getElementById('orgName').value = '';
        document.getElementById('projectNumber').value = '';
        document.getElementById('workerName').value = 'github-projects-sync-worker';
        document.getElementById('workerUrl').value = '';

        // 저장소 URL 초기화
        const repoUrlInput = document.getElementById('repositoryUrl');
        if (repoUrlInput) {
            repoUrlInput.value = '';
        }

        // Projects 가이드 체크박스 초기화
        const skipGuideCheckbox = document.getElementById('skipProjectsGuide');
        if (skipGuideCheckbox) {
            skipGuideCheckbox.checked = false;
        }

        // UI 초기화
        updateUIForProjectType();
        toggleProjectsGuide();

        showToast('설정이 초기화되었습니다.');
    }
}

// ============================================
// Step Indicator
// ============================================

function renderStepIndicators() {
    const container = document.getElementById('stepIndicators');
    const steps = [
        { num: 1, title: '정보 입력' },
        { num: 2, title: 'Worker 배포' },
        { num: 3, title: 'Webhook 설정' },
        { num: 4, title: '완료' }
    ];

    container.innerHTML = steps.map((step, index) => `
        <div class="flex items-center">
            <div class="step-indicator flex items-center cursor-pointer" onclick="goToStep(${step.num})">
                <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium transition-colors
                    ${state.currentStep === step.num
                        ? 'bg-blue-500 text-white'
                        : state.currentStep > step.num
                            ? 'bg-green-500 text-white'
                            : 'bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                    }">
                    ${state.currentStep > step.num
                        ? '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>'
                        : step.num
                    }
                </div>
                <span class="ml-2 text-sm font-medium ${state.currentStep === step.num ? 'text-blue-600 dark:text-blue-400' : 'text-gray-500 dark:text-gray-400'}">${step.title}</span>
            </div>
            ${index < steps.length - 1 ? '<div class="flex-1 h-0.5 mx-4 bg-gray-200 dark:bg-gray-700"></div>' : ''}
        </div>
    `).join('');
}

// ============================================
// Step 네비게이션
// ============================================

function showStep(stepNum) {
    // 모든 step 숨기기
    document.querySelectorAll('.step-content').forEach(el => el.classList.add('hidden'));

    // 현재 step 표시
    const currentSection = document.getElementById(`step${stepNum}`);
    if (currentSection) {
        currentSection.classList.remove('hidden');
    }

    state.currentStep = stepNum;
    saveState();
    renderStepIndicators();

    // Step별 추가 처리
    if (stepNum === 3) {
        updateWebhookDisplay();
    } else if (stepNum === 4) {
        updateSummary();
    }
}

function goToStep(stepNum) {
    if (stepNum >= 1 && stepNum <= TOTAL_STEPS) {
        showStep(stepNum);
        updateNavigationButtons();
    }
}

function nextStep() {
    if (state.currentStep < TOTAL_STEPS) {
        // Step 1 유효성 검사
        if (state.currentStep === 1) {
            const ownerName = state.ownerName || document.getElementById('ownerName')?.value.trim() || '';
            const projectNumber = state.projectNumber || document.getElementById('projectNumber')?.value.trim() || '';

            if (!ownerName || !projectNumber) {
                showToast('Projects URL을 입력하거나 Owner Name과 Project Number를 입력하세요.', 'error');
                return;
            }

            // User 타입인데 저장소 URL이 없는 경우 경고 (필수는 아님)
            if (state.projectType === 'user' && !state.repositoryUrl) {
                const proceed = confirm('User Projects의 경우 Webhook 설정을 위해 저장소 URL이 필요합니다.\n\n나중에 입력하시겠습니까?');
                if (!proceed) return;
            }

            state.ownerName = ownerName;
            state.orgName = ownerName; // 하위 호환성
            state.projectNumber = projectNumber;
            state.workerName = document.getElementById('workerName').value.trim() || 'github-projects-sync-worker';
            saveState();
        }

        showStep(state.currentStep + 1);
        updateNavigationButtons();
    }
}

function prevStep() {
    if (state.currentStep > 1) {
        showStep(state.currentStep - 1);
        updateNavigationButtons();
    }
}

function updateNavigationButtons() {
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');

    // 이전 버튼
    prevBtn.classList.toggle('hidden', state.currentStep === 1);

    // 다음 버튼
    if (state.currentStep === TOTAL_STEPS) {
        nextBtn.classList.add('hidden');
    } else {
        nextBtn.classList.remove('hidden');
        nextBtn.textContent = '다음';
    }
}

// ============================================
// Project URL 파싱
// ============================================

function parseProjectUrl() {
    const url = document.getElementById('projectUrl').value.trim();
    state.projectUrl = url;

    // Organization Projects URL 파싱
    // https://github.com/orgs/ORG-NAME/projects/NUMBER[/views/VIEW_ID]
    const orgMatch = url.match(/github\.com\/orgs\/([^\/]+)\/projects\/(\d+)(?:\/views\/\d+)?/);

    if (orgMatch) {
        state.projectType = 'org';
        state.ownerName = orgMatch[1];
        state.orgName = orgMatch[1]; // 하위 호환성
        state.projectNumber = orgMatch[2];
        updateUIForProjectType();
        saveState();
        scheduleCommandUpdate();
        return;
    }

    // User Projects URL 파싱
    // https://github.com/users/USERNAME/projects/NUMBER[/views/VIEW_ID]
    const userMatch = url.match(/github\.com\/users\/([^\/]+)\/projects\/(\d+)(?:\/views\/\d+)?/);

    if (userMatch) {
        state.projectType = 'user';
        state.ownerName = userMatch[1];
        state.orgName = userMatch[1]; // 하위 호환성
        state.projectNumber = userMatch[2];
        updateUIForProjectType();
        saveState();
        scheduleCommandUpdate();
        return;
    }

    // 매칭 실패 - 초기화
    state.projectType = '';
    state.ownerName = '';
    state.orgName = '';
    state.projectNumber = '';
    updateUIForProjectType();
    saveState();
    scheduleCommandUpdate();
}

// 프로젝트 타입에 따른 UI 업데이트
function updateUIForProjectType() {
    const ownerNameInput = document.getElementById('ownerName');
    const projectNumberInput = document.getElementById('projectNumber');
    const projectTypeBadge = document.getElementById('projectTypeBadge');
    const repositoryUrlInline = document.getElementById('repositoryUrlInline');
    const parseResultSection = document.getElementById('parseResult');

    // 파싱 결과 입력란 업데이트
    if (ownerNameInput) {
        ownerNameInput.value = state.ownerName || '';
    }
    if (projectNumberInput) {
        projectNumberInput.value = state.projectNumber || '';
    }

    // 파싱 결과 섹션 표시/숨김
    if (parseResultSection) {
        if (state.projectType && state.ownerName && state.projectNumber) {
            parseResultSection.classList.remove('hidden');
        } else {
            parseResultSection.classList.add('hidden');
        }
    }

    // 프로젝트 타입 뱃지 업데이트
    if (projectTypeBadge) {
        if (state.projectType === 'org') {
            projectTypeBadge.textContent = 'Organization';
            projectTypeBadge.className = 'px-3 py-1 rounded-full text-sm font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 border border-blue-200 dark:border-blue-800';
        } else if (state.projectType === 'user') {
            projectTypeBadge.textContent = 'User';
            projectTypeBadge.className = 'px-3 py-1 rounded-full text-sm font-medium bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 border border-green-200 dark:border-green-800';
        } else {
            projectTypeBadge.textContent = '-';
            projectTypeBadge.className = 'px-3 py-1 rounded-full text-sm font-medium bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400';
        }
    }

    // User 타입일 때만 인라인 저장소 URL 섹션 표시 (Projects URL 바로 아래)
    if (repositoryUrlInline) {
        if (state.projectType === 'user') {
            repositoryUrlInline.classList.remove('hidden');
        } else {
            repositoryUrlInline.classList.add('hidden');
        }
    }

    // 하위 호환성을 위해 orgName 필드도 업데이트
    const orgNameInput = document.getElementById('orgName');
    if (orgNameInput) {
        orgNameInput.value = state.orgName || '';
    }
}

// Projects 가이드 토글
function toggleProjectsGuide() {
    const checkbox = document.getElementById('skipProjectsGuide');
    const guideContent = document.getElementById('projectsGuideContent');

    if (checkbox && guideContent) {
        state.skipProjectsGuide = checkbox.checked;
        if (checkbox.checked) {
            guideContent.classList.add('hidden');
        } else {
            guideContent.classList.remove('hidden');
        }
        saveState();
    }
}

// 저장소 URL 정규화 (다양한 형식 지원)
function normalizeRepoUrl(url) {
    if (!url) return '';

    // github.com/{owner}/{repo} 추출 후 나머지 제거
    // 지원 형식:
    // - https://github.com/user/repo
    // - https://github.com/user/repo/
    // - https://github.com/user/repo.git
    // - https://github.com/user/repo/tree/main
    // - https://github.com/user/repo/tree/main/path/to/file
    // - https://github.com/user/repo/blob/main/file.js
    // - https://github.com/user/repo/issues/123
    const match = url.match(/github\.com\/([^\/]+)\/([^\/\?\#]+)/);
    if (match) {
        const owner = match[1];
        // .git 확장자 제거
        const repo = match[2].replace(/\.git$/, '');
        return `https://github.com/${owner}/${repo}`;
    }
    return url;
}

// 저장소 URL 파싱
function parseRepositoryUrl() {
    const rawUrl = document.getElementById('repositoryUrl').value.trim();
    // 정규화된 URL 저장
    state.repositoryUrl = normalizeRepoUrl(rawUrl);
    saveState();
    scheduleCommandUpdate();
}

// ============================================
// Labels 관리
// ============================================

function renderLabels() {
    const container = document.getElementById('labelsContainer');
    container.innerHTML = state.statusLabels.map((label, index) => `
        <div class="label-item flex items-center gap-2">
            <input type="text" value="${escapeHtml(label)}"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-sm"
                onchange="updateLabel(${index}, this.value)">
            <button onclick="removeLabel(${index})" class="p-2 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
            </button>
        </div>
    `).join('');
}

function addLabel() {
    state.statusLabels.push('새 Label');
    renderLabels();
    saveState();
    scheduleCommandUpdate();
}

function updateLabel(index, value) {
    state.statusLabels[index] = value;
    saveState();
    scheduleCommandUpdate();
}

function removeLabel(index) {
    if (state.statusLabels.length > 1) {
        state.statusLabels.splice(index, 1);
        renderLabels();
        saveState();
        scheduleCommandUpdate();
    } else {
        showToast('최소 1개의 Label이 필요합니다.', 'error');
    }
}

function resetLabels() {
    state.statusLabels = [...DEFAULT_STATUS_LABELS];
    renderLabels();
    saveState();
    scheduleCommandUpdate();
    showToast('기본값으로 복원되었습니다.');
}

// ============================================
// Webhook Secret 생성
// ============================================

function generateWebhookSecret() {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    state.webhookSecret = Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
    document.getElementById('webhookSecret').value = state.webhookSecret;
    saveState();
    scheduleCommandUpdate();
}

// ============================================
// Webhook 정보 업데이트
// ============================================

function updateWebhookDisplay() {
    const webhookSettingsLink = document.getElementById('webhookSettingsLink');
    const webhookTargetLabel = document.getElementById('webhookTargetLabel');
    const webhookTargetDescription = document.getElementById('webhookTargetDescription');

    // 프로젝트 타입에 따른 Webhook URL 생성
    if (state.projectType === 'org') {
        // Organization: github.com/organizations/{org}/settings/hooks
        const webhookUrl = `https://github.com/organizations/${state.ownerName}/settings/hooks`;
        if (webhookSettingsLink) {
            webhookSettingsLink.href = webhookUrl;
            webhookSettingsLink.textContent = webhookUrl;
        }
        if (webhookTargetLabel) {
            webhookTargetLabel.textContent = 'Organization Webhook';
        }
        if (webhookTargetDescription) {
            webhookTargetDescription.textContent = `${state.ownerName} Organization의 모든 저장소에서 Projects 이벤트를 수신합니다.`;
        }
    } else if (state.projectType === 'user') {
        // User: github.com/{owner}/{repo}/settings/hooks
        if (state.repositoryUrl) {
            const repoMatch = state.repositoryUrl.match(/github\.com\/([^\/]+)\/([^\/\?#]+)/);
            if (repoMatch) {
                const owner = repoMatch[1];
                const repo = repoMatch[2].replace(/\.git$/, '');
                const webhookUrl = `https://github.com/${owner}/${repo}/settings/hooks`;
                if (webhookSettingsLink) {
                    webhookSettingsLink.href = webhookUrl;
                    webhookSettingsLink.textContent = webhookUrl;
                }
                if (webhookTargetLabel) {
                    webhookTargetLabel.textContent = 'Repository Webhook';
                }
                if (webhookTargetDescription) {
                    webhookTargetDescription.textContent = `${owner}/${repo} 저장소의 Projects 이벤트를 수신합니다.`;
                }
            } else {
                if (webhookSettingsLink) {
                    webhookSettingsLink.href = '#';
                    webhookSettingsLink.textContent = 'Step 1에서 저장소 URL을 입력하세요';
                }
            }
        } else {
            if (webhookSettingsLink) {
                webhookSettingsLink.href = '#';
                webhookSettingsLink.textContent = 'Step 1에서 저장소 URL을 입력하세요';
            }
            if (webhookTargetLabel) {
                webhookTargetLabel.textContent = 'Repository Webhook';
            }
            if (webhookTargetDescription) {
                webhookTargetDescription.textContent = 'User Projects는 저장소 단위로 Webhook을 설정해야 합니다.';
            }
        }
    } else {
        // 타입 미지정
        if (webhookSettingsLink) {
            webhookSettingsLink.href = '#';
            webhookSettingsLink.textContent = 'Step 1에서 Projects URL을 입력하세요';
        }
    }

    // Webhook Secret 표시
    const webhookSecretDisplay = document.getElementById('webhookSecretDisplay');
    if (webhookSecretDisplay) {
        webhookSecretDisplay.textContent = state.webhookSecret || '-';
    }

    // Payload URL 표시
    updateWebhookPayloadUrl();
}

function updateWebhookPayloadUrl() {
    const webhookPayloadUrl = document.getElementById('webhookPayloadUrl');
    if (webhookPayloadUrl) {
        webhookPayloadUrl.textContent = state.workerUrl || 'Worker URL을 Step 2에서 입력하세요';
    }
}

// ============================================
// Summary 업데이트
// ============================================

function updateSummary() {
    document.getElementById('summaryOrg').textContent = state.orgName || '-';
    document.getElementById('summaryProject').textContent = state.projectNumber || '-';
    document.getElementById('summaryWorker').textContent = state.workerName || '-';
    document.getElementById('summaryLabels').textContent = state.statusLabels.join(', ') || '-';
}

// ============================================
// 파일 생성 템플릿
// ============================================

function generateWranglerToml() {
    return `# ============================================
# Cloudflare Worker 설정
# GitHub Projects Sync Worker
# ============================================

name = "${state.workerName}"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[vars]
PROJECT_NUMBER = "${state.projectNumber}"
STATUS_FIELD = "Status"
STATUS_LABELS = '${JSON.stringify(state.statusLabels)}'
ORG_NAME = "${state.orgName}"
`;
}

function generatePackageJson() {
    return JSON.stringify({
        name: state.workerName,
        version: "1.0.0",
        private: true,
        scripts: {
            deploy: "wrangler deploy",
            dev: "wrangler dev",
            tail: "wrangler tail"
        },
        devDependencies: {
            "@cloudflare/workers-types": "^4.20240117.0",
            "typescript": "^5.3.3",
            "wrangler": "^3.22.1"
        }
    }, null, 2);
}

function generateTsconfig() {
    return JSON.stringify({
        compilerOptions: {
            target: "ES2021",
            module: "ESNext",
            moduleResolution: "node",
            lib: ["ES2021"],
            types: ["@cloudflare/workers-types"],
            strict: true,
            noEmit: true,
            skipLibCheck: true
        },
        include: ["src/**/*"]
    }, null, 2);
}

function generateWorkerCode() {
    return `/**
 * GitHub Projects Sync Worker
 * Projects Status → Issue Label 동기화
 *
 * Generated by GitHub Projects Sync Wizard
 */

export interface Env {
  GITHUB_TOKEN: string;
  WEBHOOK_SECRET: string;
  PROJECT_NUMBER: string;
  STATUS_FIELD: string;
  STATUS_LABELS: string;
  ORG_NAME: string;
}

interface GitHubWebhookPayload {
  action: string;
  projects_v2_item?: {
    id: number;
    node_id: string;
    content_node_id: string;
    content_type: string;
  };
  changes?: {
    field_value?: {
      field_node_id: string;
      field_type: string;
    };
  };
  organization?: {
    login: string;
  };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Health check
    if (request.method === 'GET') {
      return new Response(JSON.stringify({
        status: 'ok',
        message: 'GitHub Projects Sync Worker is running',
        org: env.ORG_NAME,
        project: env.PROJECT_NUMBER
      }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // POST만 처리
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    try {
      // Webhook 서명 검증
      const signature = request.headers.get('X-Hub-Signature-256');
      const body = await request.text();

      if (!await verifySignature(body, signature, env.WEBHOOK_SECRET)) {
        console.log('Invalid signature');
        return new Response('Unauthorized', { status: 401 });
      }

      const payload: GitHubWebhookPayload = JSON.parse(body);

      // projects_v2_item + edited 이벤트만 처리
      if (payload.action !== 'edited' || !payload.projects_v2_item) {
        return new Response('Ignored', { status: 200 });
      }

      // Issue/PR만 처리 (Draft 제외)
      if (payload.projects_v2_item.content_type !== 'Issue' &&
          payload.projects_v2_item.content_type !== 'PullRequest') {
        return new Response('Not an Issue or PR', { status: 200 });
      }

      const contentNodeId = payload.projects_v2_item.content_node_id;
      const statusLabels: string[] = JSON.parse(env.STATUS_LABELS);

      // GraphQL로 현재 Status 조회
      const status = await getCurrentStatus(
        contentNodeId,
        parseInt(env.PROJECT_NUMBER),
        env.STATUS_FIELD,
        env.GITHUB_TOKEN
      );

      if (!status) {
        console.log('Status not found');
        return new Response('Status not found', { status: 200 });
      }

      console.log(\`Current status: \${status}\`);

      // Status가 Label 목록에 있는지 확인
      if (!statusLabels.includes(status)) {
        console.log(\`Status "\${status}" not in label list\`);
        return new Response('Status not in label list', { status: 200 });
      }

      // Issue/PR 정보 조회 및 Label 동기화
      await syncLabel(contentNodeId, status, statusLabels, env.GITHUB_TOKEN);

      return new Response('OK', { status: 200 });
    } catch (error) {
      console.error('Error:', error);
      return new Response(\`Error: \${error}\`, { status: 500 });
    }
  }
};

// ============================================
// Webhook 서명 검증
// ============================================

async function verifySignature(
  payload: string,
  signature: string | null,
  secret: string
): Promise<boolean> {
  if (!signature) return false;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signatureBuffer = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(payload)
  );

  const expectedSignature = 'sha256=' + Array.from(new Uint8Array(signatureBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  return signature === expectedSignature;
}

// ============================================
// GraphQL: 현재 Status 조회
// ============================================

async function getCurrentStatus(
  contentNodeId: string,
  projectNumber: number,
  statusField: string,
  token: string
): Promise<string | null> {
  const query = \`
    query($nodeId: ID!) {
      node(id: $nodeId) {
        ... on Issue {
          projectItems(first: 10) {
            nodes {
              project {
                number
              }
              fieldValueByName(name: "\${statusField}") {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                }
              }
            }
          }
        }
        ... on PullRequest {
          projectItems(first: 10) {
            nodes {
              project {
                number
              }
              fieldValueByName(name: "\${statusField}") {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                }
              }
            }
          }
        }
      }
    }
  \`;

  const response = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: {
      'Authorization': \`Bearer \${token}\`,
      'Content-Type': 'application/json',
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    },
    body: JSON.stringify({ query, variables: { nodeId: contentNodeId } })
  });

  const data = await response.json() as any;

  const items = data.data?.node?.projectItems?.nodes || [];
  const targetItem = items.find((item: any) => item.project?.number === projectNumber);

  return targetItem?.fieldValueByName?.name || null;
}

// ============================================
// Label 동기화
// ============================================

async function syncLabel(
  contentNodeId: string,
  newStatus: string,
  statusLabels: string[],
  token: string
): Promise<void> {
  // Issue/PR 정보 조회
  const infoQuery = \`
    query($nodeId: ID!) {
      node(id: $nodeId) {
        ... on Issue {
          number
          repository {
            owner { login }
            name
          }
          labels(first: 100) {
            nodes { name }
          }
        }
        ... on PullRequest {
          number
          repository {
            owner { login }
            name
          }
          labels(first: 100) {
            nodes { name }
          }
        }
      }
    }
  \`;

  const infoResponse = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: {
      'Authorization': \`Bearer \${token}\`,
      'Content-Type': 'application/json',
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    },
    body: JSON.stringify({ query: infoQuery, variables: { nodeId: contentNodeId } })
  });

  const infoData = await infoResponse.json() as any;
  const node = infoData.data?.node;

  if (!node) {
    console.log('Node not found');
    return;
  }

  const owner = node.repository.owner.login;
  const repo = node.repository.name;
  const issueNumber = node.number;
  const currentLabels = node.labels.nodes.map((l: any) => l.name);

  console.log(\`Issue: \${owner}/\${repo}#\${issueNumber}\`);
  console.log(\`Current labels: \${currentLabels.join(', ')}\`);

  // 현재 Status Label 확인
  const currentStatusLabel = currentLabels.find((l: string) => statusLabels.includes(l));

  // 이미 동일한 Label이면 스킵 (무한 루프 방지)
  if (currentStatusLabel === newStatus) {
    console.log(\`Label already set to "\${newStatus}", skipping\`);
    return;
  }

  // 기존 Status Label 제거
  if (currentStatusLabel) {
    await removeLabel(owner, repo, issueNumber, currentStatusLabel, token);
  }

  // 새 Status Label 추가
  await addLabel(owner, repo, issueNumber, newStatus, token);

  console.log(\`Label updated to "\${newStatus}"\`);
}

async function removeLabel(
  owner: string,
  repo: string,
  issueNumber: number,
  label: string,
  token: string
): Promise<void> {
  const url = \`https://api.github.com/repos/\${owner}/\${repo}/issues/\${issueNumber}/labels/\${encodeURIComponent(label)}\`;

  await fetch(url, {
    method: 'DELETE',
    headers: {
      'Authorization': \`Bearer \${token}\`,
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    }
  });
}

async function addLabel(
  owner: string,
  repo: string,
  issueNumber: number,
  label: string,
  token: string
): Promise<void> {
  const url = \`https://api.github.com/repos/\${owner}/\${repo}/issues/\${issueNumber}/labels\`;

  await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': \`Bearer \${token}\`,
      'Content-Type': 'application/json',
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    },
    body: JSON.stringify({ labels: [label] })
  });
}
`;
}

function generateConfigJson() {
    return JSON.stringify({
        orgName: state.orgName,
        projectNumber: state.projectNumber,
        workerName: state.workerName,
        webhookSecret: state.webhookSecret,
        statusLabels: state.statusLabels
    }, null, 2);
}

function generateReadme() {
    return `# GitHub Projects Sync Worker

GitHub Projects Status → Issue Label 자동 동기화 Worker

## 설정 정보

- **Organization:** ${state.orgName}
- **Project Number:** ${state.projectNumber}
- **Worker Name:** ${state.workerName}

## 설치 방법

### 1. 스크립트 실행 (권장)

\`\`\`bash
# Mac/Linux
./projects-sync-worker-setup.sh

# Windows PowerShell
.\\projects-sync-worker-setup.ps1
\`\`\`

스크립트가 자동으로:
1. npm 의존성 설치
2. Cloudflare 로그인
3. Worker 배포
4. Secrets 설정

### 2. 수동 설치

\`\`\`bash
# 의존성 설치
npm config set strict-ssl false
npm install
npm config set strict-ssl true

# Cloudflare 로그인
export NODE_TLS_REJECT_UNAUTHORIZED=0  # Mac/Linux
# $env:NODE_TLS_REJECT_UNAUTHORIZED=0  # Windows PowerShell
npx wrangler login

# Worker 배포
npx wrangler deploy

# Secrets 설정
npx wrangler secret put GITHUB_TOKEN
npx wrangler secret put WEBHOOK_SECRET
\`\`\`

## GitHub Webhook 설정

1. https://github.com/organizations/${state.orgName}/settings/hooks 이동
2. "Add webhook" 클릭
3. 설정:
   - **Payload URL:** Worker URL
   - **Content type:** application/json
   - **Secret:** config.json의 webhookSecret 값
   - **Events:** "Project v2 items" 선택

## 테스트

1. Projects Board에서 Issue 카드 이동
2. Issue Label 자동 변경 확인
3. 문제 시 로그 확인: \`npx wrangler tail\`

## Secrets

| Secret | 설명 |
|--------|------|
| GITHUB_TOKEN | GitHub PAT (repo, project 권한) |
| WEBHOOK_SECRET | config.json의 webhookSecret 값 |

---

Generated by GitHub Projects Sync Wizard v2.0.0
`;
}

function generateSetupScriptSh() {
    return `#!/bin/bash
# ============================================
# GitHub Projects Sync Worker 설치 스크립트
#
# 사용법: ./projects-sync-worker-setup.sh
# ============================================

set -e

RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
CYAN='\\033[0;36m'
NC='\\033[0m'

echo ""
echo -e "\${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"
echo -e "\${CYAN}   🔄 GitHub Projects Sync Worker 설치 스크립트\${NC}"
echo -e "\${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"
echo ""

if [ ! -f "config.json" ]; then
    echo -e "\${RED}❌ config.json 파일을 찾을 수 없습니다.\${NC}"
    exit 1
fi

ORG_NAME=$(cat config.json | grep -o '"orgName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
WORKER_NAME=$(cat config.json | grep -o '"workerName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
WEBHOOK_SECRET=$(cat config.json | grep -o '"webhookSecret"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)

echo -e "\${BLUE}📋 설정 정보:\${NC}"
echo -e "   Organization: \${GREEN}$ORG_NAME\${NC}"
echo -e "   Worker 이름: \${GREEN}$WORKER_NAME\${NC}"
echo ""

echo -e "\${YELLOW}[1/4]\${NC} 📦 의존성 설치 중..."
npm config set strict-ssl false 2>/dev/null || true
npm install && echo -e "\${GREEN}✅ 의존성 설치 완료\${NC}" || { echo -e "\${RED}❌ npm install 실패\${NC}"; exit 1; }
npm config set strict-ssl true 2>/dev/null || true
echo ""

echo -e "\${YELLOW}[2/4]\${NC} 🔐 Cloudflare 로그인 중..."
export NODE_TLS_REJECT_UNAUTHORIZED=0
npx wrangler login && echo -e "\${GREEN}✅ Cloudflare 로그인 완료\${NC}" || { echo -e "\${RED}❌ 로그인 실패\${NC}"; exit 1; }
echo ""

echo -e "\${YELLOW}[3/4]\${NC} 🚀 Worker 배포 중..."
DEPLOY_SUCCESS=false
WORKER_URL=""

while [ "$DEPLOY_SUCCESS" = false ]; do
    DEPLOY_OUTPUT=$(npx wrangler deploy 2>&1) || true
    if echo "$DEPLOY_OUTPUT" | grep -q "https://.*workers.dev"; then
        WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -o 'https://[^[:space:]]*workers.dev' | head -1)
        DEPLOY_SUCCESS=true
        echo -e "\${GREEN}✅ Worker 배포 완료\${NC}"
        echo -e "   URL: \${CYAN}$WORKER_URL\${NC}"
    else
        echo -e "\${RED}❌ Worker 배포 실패\${NC}"
        echo "$DEPLOY_OUTPUT" | tail -5
        echo ""
        echo -e "새 Worker 이름을 입력하세요 (q로 종료):"
        read -r NEW_NAME
        [ "$NEW_NAME" = "q" ] && exit 1
        [ -n "$NEW_NAME" ] && sed -i.bak "s/^name = \\".*\\"/name = \\"$NEW_NAME\\"/" wrangler.toml && rm -f wrangler.toml.bak
    fi
done
echo ""

echo -e "\${YELLOW}[4/4]\${NC} 🔑 Secrets 설정 중..."
echo -e "\${CYAN}GitHub PAT을 입력하세요 (repo, project 권한):\${NC}"
npx wrangler secret put GITHUB_TOKEN
echo "$WEBHOOK_SECRET" | npx wrangler secret put WEBHOOK_SECRET 2>/dev/null || npx wrangler secret put WEBHOOK_SECRET
echo ""

echo -e "\${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"
echo -e "\${GREEN}🎉 설치 완료!\${NC}"
echo -e "📌 Worker URL: \${CYAN}$WORKER_URL\${NC}"
echo ""
echo -e "\${BLUE}📋 다음 단계: GitHub Webhook 설정\${NC}"
echo -e "   https://github.com/organizations/$ORG_NAME/settings/hooks"
echo -e "   Payload URL: $WORKER_URL"
echo -e "   Secret: config.json 참조"
echo -e "   Event: 'Project v2 items' 선택"
echo -e "\${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"
`;
}

function generateSetupScriptPs1() {
    return `# GitHub Projects Sync Worker 설치 스크립트 (Windows)
$ErrorActionPreference = "Stop"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "   🔄 GitHub Projects Sync Worker 설치" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if (-not (Test-Path "config.json")) { Write-Host "❌ config.json 없음" -ForegroundColor Red; exit 1 }

$config = Get-Content "config.json" -Raw | ConvertFrom-Json

Write-Host "[1/4] 📦 의존성 설치..." -ForegroundColor Yellow
npm config set strict-ssl false 2>$null
npm install
npm config set strict-ssl true 2>$null

Write-Host "[2/4] 🔐 Cloudflare 로그인..." -ForegroundColor Yellow
$env:NODE_TLS_REJECT_UNAUTHORIZED = "0"
npx wrangler login

Write-Host "[3/4] 🚀 Worker 배포..." -ForegroundColor Yellow
$success = $false
while (-not $success) {
    $output = npx wrangler deploy 2>&1 | Out-String
    if ($output -match "https://[^\\s]*workers\\.dev") {
        $url = $Matches[0]
        $success = $true
        Write-Host "✅ 배포 완료: $url" -ForegroundColor Green
    } else {
        Write-Host "❌ 배포 실패" -ForegroundColor Red
        $new = Read-Host "새 Worker 이름 (q로 종료)"
        if ($new -eq "q") { exit 1 }
        if ($new) { (Get-Content wrangler.toml) -replace 'name = "[^"]*"', "name = \`"$new\`"" | Set-Content wrangler.toml }
    }
}

Write-Host "[4/4] 🔑 Secrets 설정..." -ForegroundColor Yellow
npx wrangler secret put GITHUB_TOKEN
$config.webhookSecret | npx wrangler secret put WEBHOOK_SECRET

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🎉 설치 완료!" -ForegroundColor Green
Write-Host "Worker URL: $url" -ForegroundColor Cyan
Write-Host "다음: GitHub Webhook 설정" -ForegroundColor Blue
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
`;
}

// ============================================
// ZIP 다운로드
// ============================================

async function downloadAllAsZip() {
    // 유효성 검사
    const orgName = document.getElementById('orgName').value.trim();
    const projectNumber = document.getElementById('projectNumber').value.trim();

    if (!orgName || !projectNumber) {
        showToast('Organization Name과 Project Number를 입력하세요.', 'error');
        return;
    }

    // 상태 업데이트
    state.orgName = orgName;
    state.projectNumber = projectNumber;
    state.workerName = document.getElementById('workerName').value.trim() || 'github-projects-sync-worker';
    saveState();

    try {
        const zip = new JSZip();
        const folderName = 'github-projects-sync-worker';

        // 파일 추가
        zip.file(`${folderName}/wrangler.toml`, generateWranglerToml());
        zip.file(`${folderName}/package.json`, generatePackageJson());
        zip.file(`${folderName}/tsconfig.json`, generateTsconfig());
        zip.file(`${folderName}/src/index.ts`, generateWorkerCode());
        zip.file(`${folderName}/config.json`, generateConfigJson());
        zip.file(`${folderName}/README.md`, generateReadme());
        zip.file(`${folderName}/projects-sync-worker-setup.sh`, generateSetupScriptSh());
        zip.file(`${folderName}/projects-sync-worker-setup.ps1`, generateSetupScriptPs1());

        // ZIP 생성 및 다운로드
        const content = await zip.generateAsync({ type: 'blob' });
        const url = URL.createObjectURL(content);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${folderName}.zip`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        showToast('ZIP 파일이 다운로드되었습니다.');
    } catch (error) {
        console.error('ZIP 생성 실패:', error);
        showToast('ZIP 생성에 실패했습니다.', 'error');
    }
}

// ============================================
// 유틸리티 함수
// ============================================

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        showToast('클립보드에 복사되었습니다.');
    }).catch(() => {
        showToast('복사에 실패했습니다.', 'error');
    });
}

function copyCommand(command) {
    copyToClipboard(command);
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toastMessage');

    toastMessage.textContent = message;

    if (type === 'error') {
        toast.classList.remove('bg-gray-800');
        toast.classList.add('bg-red-600');
    } else {
        toast.classList.remove('bg-red-600');
        toast.classList.add('bg-gray-800');
    }

    toast.classList.remove('translate-y-full', 'opacity-0');
    toast.classList.add('translate-y-0', 'opacity-100');

    setTimeout(() => {
        toast.classList.remove('translate-y-0', 'opacity-100');
        toast.classList.add('translate-y-full', 'opacity-0');
    }, 3000);
}

// ============================================
// 설치 명령어 자동 생성 (OS별)
// ============================================

// 명령어 자동 업데이트 (debounce 적용)
let commandUpdateTimer = null;

function scheduleCommandUpdate() {
    if (commandUpdateTimer) {
        clearTimeout(commandUpdateTimer);
    }
    commandUpdateTimer = setTimeout(() => {
        updateInstallCommands();
    }, 300);
}

function updateInstallCommands() {
    const commandSection = document.getElementById('installCommandSection');
    const waitingMessage = document.getElementById('commandWaitingMessage');
    const bashCommandCode = document.getElementById('bashCommandCode');
    const powershellCommandCode = document.getElementById('powershellCommandCode');

    if (!commandSection || !waitingMessage) return;

    // 필수 필드 확인
    const ownerName = state.ownerName || '';
    const projectNumber = state.projectNumber || '';
    const webhookSecret = state.webhookSecret || '';

    // User 타입인데 저장소 URL이 없으면 명령어 생성 안함
    const needsRepoUrl = state.projectType === 'user' && !state.repositoryUrl;

    if (!ownerName || !projectNumber || !webhookSecret || needsRepoUrl) {
        // 입력 대기 메시지 표시
        waitingMessage.classList.remove('hidden');
        commandSection.classList.add('hidden');
        return;
    }

    // 명령어 생성 및 표시
    waitingMessage.classList.add('hidden');
    commandSection.classList.remove('hidden');

    if (bashCommandCode) {
        bashCommandCode.textContent = buildBashCommand();
    }
    if (powershellCommandCode) {
        powershellCommandCode.textContent = buildPowerShellCommand();
    }
}

function buildBashCommand() {
    // Mac/Linux bash 스크립트 URL
    const scriptUrl = 'https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/.github/util/common/projects-sync-wizard/projects-sync-wizard-setup.sh';

    // 인자 구성
    const args = [];
    args.push(`--type "${state.projectType || 'org'}"`);
    args.push(`--owner "${state.ownerName}"`);
    args.push(`--project "${state.projectNumber}"`);
    args.push(`--worker-name "${state.workerName}"`);
    args.push(`--webhook-secret "${state.webhookSecret}"`);
    args.push(`--labels "${state.statusLabels.join(',')}"`);

    // User 타입인 경우 저장소 정보 추가
    if (state.projectType === 'user' && state.repositoryUrl) {
        const repoMatch = state.repositoryUrl.match(/github\.com\/([^\/]+)\/([^\/\?\#]+)/);
        if (repoMatch) {
            const repoOwner = repoMatch[1];
            const repoName = repoMatch[2].replace(/\.git$/, '');
            args.push(`--repo-owner "${repoOwner}"`);
            args.push(`--repo-name "${repoName}"`);
        }
    }

    // curl 명령어 생성
    return `curl -fsSL ${scriptUrl} | bash -s -- \\
  ${args.join(' \\\n  ')}`;
}

function buildPowerShellCommand() {
    // 환경변수 설정
    const envVars = [];
    envVars.push(`$env:WIZARD_TYPE='${state.projectType || 'org'}'`);
    envVars.push(`$env:WIZARD_OWNER='${state.ownerName}'`);
    envVars.push(`$env:WIZARD_PROJECT='${state.projectNumber}'`);
    envVars.push(`$env:WIZARD_WORKER_NAME='${state.workerName}'`);
    envVars.push(`$env:WIZARD_WEBHOOK_SECRET='${state.webhookSecret}'`);
    envVars.push(`$env:WIZARD_LABELS='${state.statusLabels.join(',')}'`);

    // User 타입인 경우 저장소 정보 추가
    if (state.projectType === 'user' && state.repositoryUrl) {
        const repoMatch = state.repositoryUrl.match(/github\.com\/([^\/]+)\/([^\/\?\#]+)/);
        if (repoMatch) {
            const repoOwner = repoMatch[1];
            const repoName = repoMatch[2].replace(/\.git$/, '');
            envVars.push(`$env:WIZARD_REPO_OWNER='${repoOwner}'`);
            envVars.push(`$env:WIZARD_REPO_NAME='${repoName}'`);
        }
    }

    // PowerShell 스크립트 URL
    const scriptUrl = 'https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/.github/util/common/projects-sync-wizard/projects-sync-wizard-setup.ps1';

    // PowerShell 명령어 생성
    return `${envVars.join('; ')}; irm '${scriptUrl}' | iex`;
}

function copyCommand(type) {
    let command = '';
    if (type === 'bash') {
        command = buildBashCommand();
    } else if (type === 'powershell') {
        command = buildPowerShellCommand();
    }
    copyToClipboard(command);
}
