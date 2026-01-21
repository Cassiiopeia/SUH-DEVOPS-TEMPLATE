/**
 * GitHub Projects Sync Wizard - Client Logic
 *
 * 7단계 마법사 UI를 관리하고 Cloudflare Worker 파일을 생성합니다.
 */

// ============================================
// 상수 정의
// ============================================

const STORAGE_KEY = 'github-projects-sync-wizard';
const DEFAULT_LABELS = ['작업 전', '작업 중', '확인 대기', '피드백', '작업 완료', '취소'];
const TOTAL_STEPS = 7;

// Worker 템플릿 (빌드 시 포함됨)
const TEMPLATES = {
    'wrangler.toml': `name = "github-projects-sync-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[vars]
PROJECT_NUMBER = "{{PROJECT_NUMBER}}"
STATUS_FIELD = "Status"
STATUS_LABELS = '{{STATUS_LABELS}}'
ORG_NAME = "{{ORG_NAME}}"
`,

    'package.json': `{
  "name": "github-projects-sync-worker",
  "version": "1.0.0",
  "description": "GitHub Projects Status를 Issue Label로 실시간 동기화하는 Cloudflare Worker",
  "main": "src/index.ts",
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "tail": "wrangler tail"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20241218.0",
    "typescript": "^5.3.3",
    "wrangler": "^3.99.0"
  }
}
`,

    'tsconfig.json': `{
  "compilerOptions": {
    "target": "ES2021",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2021"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
`,

    'src/index.ts': `/**
 * GitHub Projects Sync Worker
 *
 * GitHub Projects의 Status가 변경되면 Issue Label을 자동으로 동기화합니다.
 */

export interface Env {
  GITHUB_TOKEN: string;
  WEBHOOK_SECRET: string;
  PROJECT_NUMBER: string;
  STATUS_FIELD: string;
  STATUS_LABELS: string;
  ORG_NAME: string;
}

interface WebhookPayload {
  action: string;
  projects_v2_item?: {
    id: number;
    node_id: string;
    project_node_id: string;
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
  sender?: {
    login: string;
  };
}

interface ProjectItemResponse {
  data?: {
    node?: {
      content?: {
        number: number;
        title: string;
        labels: {
          nodes: Array<{ name: string }>;
        };
        repository: {
          name: string;
          owner: {
            login: string;
          };
        };
      };
      fieldValueByName?: {
        name?: string;
      };
    };
  };
  errors?: Array<{ message: string }>;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    const signature = request.headers.get('X-Hub-Signature-256');
    if (!signature) {
      console.log('❌ Missing signature header');
      return new Response('Missing signature', { status: 401 });
    }

    const body = await request.text();
    const isValid = await verifySignature(body, signature, env.WEBHOOK_SECRET);
    if (!isValid) {
      console.log('❌ Invalid signature');
      return new Response('Invalid signature', { status: 401 });
    }

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🔄 GitHub Projects Sync Worker');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Webhook signature verified');

    const event = request.headers.get('X-GitHub-Event');
    console.log(\`📌 Event type: \${event}\`);

    if (event !== 'projects_v2_item') {
      console.log('⏭️ Skipping non-projects_v2_item event');
      return new Response('OK - Event ignored', { status: 200 });
    }

    const payload: WebhookPayload = JSON.parse(body);
    console.log(\`📌 Action: \${payload.action}\`);

    if (payload.action !== 'edited') {
      console.log('⏭️ Skipping non-edited action');
      return new Response('OK - Action ignored', { status: 200 });
    }

    if (!payload.changes?.field_value) {
      console.log('⏭️ No field value change detected');
      return new Response('OK - No field change', { status: 200 });
    }

    const itemNodeId = payload.projects_v2_item?.node_id;
    if (!itemNodeId) {
      console.log('❌ No item node ID found');
      return new Response('OK - No item ID', { status: 200 });
    }

    console.log(\`📌 Processing item: \${itemNodeId}\`);

    try {
      const itemInfo = await getProjectItemInfo(itemNodeId, env);

      if (!itemInfo?.data?.node?.content) {
        console.log('❌ Could not get item content');
        return new Response('OK - No content', { status: 200 });
      }

      const content = itemInfo.data.node.content;
      const currentStatus = itemInfo.data.node.fieldValueByName?.name;
      const issueNumber = content.number;
      const repoName = content.repository.name;
      const repoOwner = content.repository.owner.login;
      const currentLabels = content.labels.nodes.map(l => l.name);

      console.log(\`📌 Issue: \${repoOwner}/\${repoName}#\${issueNumber}\`);
      console.log(\`📌 Current Labels: \${currentLabels.join(', ')}\`);
      console.log(\`📌 New Status: "\${currentStatus}"\`);

      if (!currentStatus) {
        console.log('⏭️ No status value');
        return new Response('OK - No status', { status: 200 });
      }

      const statusLabels: string[] = JSON.parse(env.STATUS_LABELS);

      const labelsToRemove = currentLabels.filter(label =>
        statusLabels.includes(label) && label !== currentStatus
      );

      console.log(\`🗑️ Labels to remove: \${labelsToRemove.join(', ') || 'none'}\`);

      if (currentLabels.includes(currentStatus) && labelsToRemove.length === 0) {
        console.log('⏭️ Label already synced, skipping');
        return new Response('OK - Already synced', { status: 200 });
      }

      for (const label of labelsToRemove) {
        await removeLabel(repoOwner, repoName, issueNumber, label, env);
        console.log(\`  ✅ Label "\${label}" 제거됨\`);
      }

      if (statusLabels.includes(currentStatus) && !currentLabels.includes(currentStatus)) {
        console.log(\`➕ Adding label: "\${currentStatus}"\`);
        await addLabel(repoOwner, repoName, issueNumber, currentStatus, env);
        console.log(\`  ✅ Label "\${currentStatus}" 추가됨\`);
      }

      console.log('🎉 Label sync completed!');
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return new Response('OK - Synced', { status: 200 });

    } catch (error) {
      console.error('❌ Error:', error);
      return new Response('Internal Server Error', { status: 500 });
    }
  }
};

async function verifySignature(payload: string, signature: string, secret: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signatureBytes = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(payload)
  );

  const expectedSignature = 'sha256=' + Array.from(new Uint8Array(signatureBytes))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  if (signature.length !== expectedSignature.length) {
    return false;
  }

  let result = 0;
  for (let i = 0; i < signature.length; i++) {
    result |= signature.charCodeAt(i) ^ expectedSignature.charCodeAt(i);
  }
  return result === 0;
}

async function getProjectItemInfo(nodeId: string, env: Env): Promise<ProjectItemResponse> {
  const query = \`
    query($nodeId: ID!, $statusField: String!) {
      node(id: $nodeId) {
        ... on ProjectV2Item {
          content {
            ... on Issue {
              number
              title
              labels(first: 20) {
                nodes {
                  name
                }
              }
              repository {
                name
                owner {
                  login
                }
              }
            }
            ... on PullRequest {
              number
              title
              labels(first: 20) {
                nodes {
                  name
                }
              }
              repository {
                name
                owner {
                  login
                }
              }
            }
          }
          fieldValueByName(name: $statusField) {
            ... on ProjectV2ItemFieldSingleSelectValue {
              name
            }
          }
        }
      }
    }
  \`;

  const response = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: {
      'Authorization': \`Bearer \${env.GITHUB_TOKEN}\`,
      'Content-Type': 'application/json',
      'User-Agent': 'GitHub-Projects-Sync-Worker'
    },
    body: JSON.stringify({
      query,
      variables: {
        nodeId,
        statusField: env.STATUS_FIELD || 'Status'
      }
    })
  });

  return response.json();
}

async function addLabel(owner: string, repo: string, issueNumber: number, label: string, env: Env): Promise<void> {
  const response = await fetch(
    \`https://api.github.com/repos/\${owner}/\${repo}/issues/\${issueNumber}/labels\`,
    {
      method: 'POST',
      headers: {
        'Authorization': \`Bearer \${env.GITHUB_TOKEN}\`,
        'Content-Type': 'application/json',
        'User-Agent': 'GitHub-Projects-Sync-Worker'
      },
      body: JSON.stringify({ labels: [label] })
    }
  );

  if (!response.ok) {
    const error = await response.text();
    console.error(\`Failed to add label: \${error}\`);
  }
}

async function removeLabel(owner: string, repo: string, issueNumber: number, label: string, env: Env): Promise<void> {
  const encodedLabel = encodeURIComponent(label);
  const response = await fetch(
    \`https://api.github.com/repos/\${owner}/\${repo}/issues/\${issueNumber}/labels/\${encodedLabel}\`,
    {
      method: 'DELETE',
      headers: {
        'Authorization': \`Bearer \${env.GITHUB_TOKEN}\`,
        'User-Agent': 'GitHub-Projects-Sync-Worker'
      }
    }
  );

  if (!response.ok && response.status !== 404) {
    const error = await response.text();
    console.error(\`Failed to remove label: \${error}\`);
  }
}
`
};

// ============================================
// 상태 관리
// ============================================

let state = {
    currentStep: 1,
    maxReachedStep: 1,
    projectUrl: '',
    orgName: '',
    projectNumber: '',
    subdomain: '',
    labels: [...DEFAULT_LABELS],
    workerUrl: '',
    webhookSecret: '',
    githubToken: ''
};

// ============================================
// 초기화
// ============================================

document.addEventListener('DOMContentLoaded', () => {
    loadState();
    initDarkMode();
    renderStepIndicators();
    renderLabels();
    showStep(state.currentStep);
    updateNavigationButtons();

    // 버전 표시
    try {
        const versionJson = JSON.parse(document.getElementById('versionJson').textContent);
        document.getElementById('versionDisplay').textContent = `v${versionJson.version}`;
    } catch (e) {
        console.error('Failed to parse version info:', e);
    }

    // 입력 필드 이벤트
    document.getElementById('projectUrl').value = state.projectUrl;
    document.getElementById('orgName').value = state.orgName;
    document.getElementById('projectNumber').value = state.projectNumber;
    document.getElementById('subdomain').value = state.subdomain;
    document.getElementById('workerUrl').value = state.workerUrl;
    document.getElementById('webhookSecret').value = state.webhookSecret;
});

// ============================================
// 상태 저장/불러오기
// ============================================

function saveState() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function loadState() {
    try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
            const parsed = JSON.parse(saved);
            state = { ...state, ...parsed };
        }
    } catch (e) {
        console.error('Failed to load state:', e);
    }
}

// ============================================
// 다크 모드
// ============================================

function initDarkMode() {
    const isDark = localStorage.getItem('darkMode') === 'true' ||
        (!localStorage.getItem('darkMode') && window.matchMedia('(prefers-color-scheme: dark)').matches);

    if (isDark) {
        document.documentElement.classList.add('dark');
    }
}

function toggleDarkMode() {
    document.documentElement.classList.toggle('dark');
    localStorage.setItem('darkMode', document.documentElement.classList.contains('dark'));
}

// ============================================
// Step Indicator
// ============================================

function renderStepIndicators() {
    const container = document.getElementById('stepIndicators');
    const steps = [
        '프로젝트 설정',
        'Status Labels',
        'Cloudflare 설정',
        '파일 생성',
        'Worker 배포',
        'Webhook 설정',
        '완료'
    ];

    container.innerHTML = steps.map((title, index) => {
        const stepNum = index + 1;
        return `
            <div class="step-indicator flex flex-col items-center cursor-pointer" onclick="goToStep(${stepNum})">
                <div id="stepCircle${stepNum}" class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium transition-all ${getStepClass(stepNum)}">
                    ${stepNum <= state.maxReachedStep && stepNum < state.currentStep ?
                        '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>' :
                        stepNum}
                </div>
                <span class="text-xs mt-1 text-gray-500 dark:text-gray-400 hidden md:block">${title}</span>
            </div>
            ${index < steps.length - 1 ? '<div class="flex-1 h-0.5 bg-gray-200 dark:bg-gray-700 mx-2 hidden md:block"></div>' : ''}
        `;
    }).join('');
}

function getStepClass(stepNum) {
    if (stepNum < state.currentStep && stepNum <= state.maxReachedStep) {
        return 'bg-green-500 text-white';
    } else if (stepNum === state.currentStep) {
        return 'bg-gradient-to-r from-blue-500 to-purple-600 text-white';
    } else if (stepNum <= state.maxReachedStep) {
        return 'bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300';
    } else {
        return 'bg-gray-200 dark:bg-gray-700 text-gray-400 dark:text-gray-500';
    }
}

function goToStep(step) {
    if (step <= state.maxReachedStep) {
        state.currentStep = step;
        showStep(step);
        renderStepIndicators();
        updateNavigationButtons();
        saveState();
    }
}

// ============================================
// Step 관리
// ============================================

function showStep(step) {
    // 모든 step 숨기기
    document.querySelectorAll('.step-content').forEach(el => {
        el.classList.add('hidden');
    });

    // 현재 step 표시
    const currentStepEl = document.getElementById(`step${step}`);
    if (currentStepEl) {
        currentStepEl.classList.remove('hidden');
    }

    // Step별 초기화
    if (step === 4) {
        updateSummary();
    } else if (step === 6) {
        updateWebhookInfo();
    } else if (step === 7) {
        renderSecretsList();
    }
}

function nextStep() {
    // 유효성 검사
    if (!validateCurrentStep()) {
        return;
    }

    // 상태 저장
    saveCurrentStepData();

    if (state.currentStep < TOTAL_STEPS) {
        state.currentStep++;
        state.maxReachedStep = Math.max(state.maxReachedStep, state.currentStep);
        showStep(state.currentStep);
        renderStepIndicators();
        updateNavigationButtons();
        saveState();

        // 스크롤 상단으로
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

function prevStep() {
    if (state.currentStep > 1) {
        state.currentStep--;
        showStep(state.currentStep);
        renderStepIndicators();
        updateNavigationButtons();
        saveState();

        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

function updateNavigationButtons() {
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');

    if (state.currentStep === 1) {
        prevBtn.classList.add('hidden');
    } else {
        prevBtn.classList.remove('hidden');
    }

    if (state.currentStep === TOTAL_STEPS) {
        nextBtn.classList.add('hidden');
    } else {
        nextBtn.classList.remove('hidden');
        nextBtn.textContent = '다음';
    }
}

function validateCurrentStep() {
    switch (state.currentStep) {
        case 1:
            const orgName = document.getElementById('orgName').value.trim();
            const projectNumber = document.getElementById('projectNumber').value.trim();
            if (!orgName || !projectNumber) {
                showToast('Organization Name과 Project Number를 입력하세요.');
                return false;
            }
            return true;
        case 2:
            if (state.labels.length === 0) {
                showToast('최소 하나의 Label이 필요합니다.');
                return false;
            }
            return true;
        case 5:
            // Worker URL은 선택사항 (나중에 입력 가능)
            return true;
        case 6:
            if (!state.webhookSecret) {
                generateWebhookSecret();
            }
            return true;
        default:
            return true;
    }
}

function saveCurrentStepData() {
    switch (state.currentStep) {
        case 1:
            state.projectUrl = document.getElementById('projectUrl').value.trim();
            state.orgName = document.getElementById('orgName').value.trim();
            state.projectNumber = document.getElementById('projectNumber').value.trim();
            break;
        case 3:
            state.subdomain = document.getElementById('subdomain').value.trim();
            break;
        case 5:
            state.workerUrl = document.getElementById('workerUrl').value.trim();
            break;
        case 6:
            state.webhookSecret = document.getElementById('webhookSecret').value.trim();
            break;
    }
}

// ============================================
// Step 1: Project URL 파싱
// ============================================

function parseProjectUrl() {
    const url = document.getElementById('projectUrl').value.trim();

    // URL 형식: https://github.com/orgs/ORG-NAME/projects/NUMBER
    const match = url.match(/github\.com\/orgs\/([^\/]+)\/projects\/(\d+)/);

    if (match) {
        document.getElementById('orgName').value = match[1];
        document.getElementById('projectNumber').value = match[2];
        state.orgName = match[1];
        state.projectNumber = match[2];
    }
}

// ============================================
// Step 2: Labels 관리
// ============================================

function renderLabels() {
    const container = document.getElementById('labelsContainer');
    container.innerHTML = state.labels.map((label, index) => `
        <div class="label-item flex items-center gap-2">
            <input type="text" value="${escapeHtml(label)}"
                onchange="updateLabel(${index}, this.value)"
                class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent">
            <button onclick="removeLabel(${index})" class="p-2 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
            </button>
        </div>
    `).join('');
}

function addLabel() {
    state.labels.push('새 Label');
    renderLabels();
    saveState();
}

function updateLabel(index, value) {
    state.labels[index] = value.trim();
    saveState();
}

function removeLabel(index) {
    state.labels.splice(index, 1);
    renderLabels();
    saveState();
}

function resetLabels() {
    state.labels = [...DEFAULT_LABELS];
    renderLabels();
    saveState();
    showToast('기본 Label로 복원되었습니다.');
}

// ============================================
// Step 4: 파일 생성
// ============================================

function updateSummary() {
    document.getElementById('summaryOrg').textContent = state.orgName || '-';
    document.getElementById('summaryProject').textContent = state.projectNumber || '-';
    document.getElementById('summaryLabels').textContent = state.labels.length > 0 ?
        state.labels.join(', ') : '-';
}

function generateFileContent(filename) {
    let content = TEMPLATES[filename] || '';

    if (filename === 'wrangler.toml') {
        content = content
            .replace('{{PROJECT_NUMBER}}', state.projectNumber)
            .replace('{{STATUS_LABELS}}', JSON.stringify(state.labels))
            .replace('{{ORG_NAME}}', state.orgName);
    }

    return content;
}

function downloadFile(filename) {
    const content = generateFileContent(filename);
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = filename.includes('/') ? filename.split('/').pop() : filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    showToast(`${filename} 다운로드 완료`);
}

async function downloadAllAsZip() {
    const zip = new JSZip();

    // 파일 추가
    zip.file('wrangler.toml', generateFileContent('wrangler.toml'));
    zip.file('package.json', generateFileContent('package.json'));
    zip.file('tsconfig.json', generateFileContent('tsconfig.json'));
    zip.folder('src').file('index.ts', generateFileContent('src/index.ts'));

    // README 추가
    const readme = `# GitHub Projects Sync Worker

이 Worker는 GitHub Projects의 Status 변경을 감지하여 Issue Label을 자동으로 동기화합니다.

## 설정 정보

- Organization: ${state.orgName}
- Project Number: ${state.projectNumber}
- Status Labels: ${state.labels.join(', ')}

## 배포 방법

1. 의존성 설치
   \`\`\`bash
   npm install
   \`\`\`

2. Cloudflare 로그인
   \`\`\`bash
   npx wrangler login
   \`\`\`

3. Worker 배포
   \`\`\`bash
   npx wrangler deploy
   \`\`\`

4. Secrets 설정
   \`\`\`bash
   npx wrangler secret put GITHUB_TOKEN
   npx wrangler secret put WEBHOOK_SECRET
   \`\`\`

## 생성일

${new Date().toLocaleString('ko-KR')}
`;
    zip.file('README.md', readme);

    // ZIP 생성 및 다운로드
    const blob = await zip.generateAsync({ type: 'blob' });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-projects-sync-worker.zip';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    showToast('ZIP 파일 다운로드 완료');
}

// ============================================
// Step 6: Webhook 설정
// ============================================

function updateWebhookInfo() {
    // Organization 이름 업데이트
    const orgNameEl = document.getElementById('webhookOrgName');
    const linkEl = document.getElementById('webhookSettingsLink');

    if (state.orgName) {
        orgNameEl.textContent = state.orgName;
        linkEl.href = `https://github.com/organizations/${state.orgName}/settings/hooks`;
    }

    // Worker URL 업데이트
    const payloadUrlEl = document.getElementById('webhookPayloadUrl');
    payloadUrlEl.textContent = state.workerUrl || '(Step 5에서 Worker URL을 입력하세요)';

    // Webhook Secret 업데이트
    const secretDisplayEl = document.getElementById('webhookSecretDisplay');
    secretDisplayEl.textContent = state.webhookSecret || '(자동 생성 버튼 클릭)';
}

function generateWebhookSecret() {
    // crypto.randomUUID() 사용
    const secret = crypto.randomUUID().replace(/-/g, '');
    state.webhookSecret = secret;
    document.getElementById('webhookSecret').value = secret;
    document.getElementById('webhookSecretDisplay').textContent = secret;
    saveState();
    showToast('Webhook Secret이 생성되었습니다.');
}

function updateWebhookSecret() {
    state.webhookSecret = document.getElementById('webhookSecret').value.trim();
    document.getElementById('webhookSecretDisplay').textContent = state.webhookSecret || '-';
    saveState();
}

// ============================================
// Step 7: 완료 및 내보내기
// ============================================

function renderSecretsList() {
    const container = document.getElementById('secretsList');

    const secrets = [
        {
            name: 'GITHUB_TOKEN',
            description: 'GitHub Personal Access Token (repo, project 권한)',
            value: state.githubToken || '(GitHub에서 생성 필요)',
            editable: true
        },
        {
            name: 'WEBHOOK_SECRET',
            description: 'Webhook 검증용 비밀키',
            value: state.webhookSecret || '(Step 6에서 생성)',
            editable: false
        }
    ];

    container.innerHTML = secrets.map(secret => `
        <div class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700/50 rounded-lg">
            <div class="flex-1">
                <div class="flex items-center gap-2">
                    <code class="font-medium text-gray-900 dark:text-white">${secret.name}</code>
                    ${secret.editable ? `
                        <button onclick="editSecret('${secret.name}')" class="text-xs text-blue-600 dark:text-blue-400 hover:underline">편집</button>
                    ` : ''}
                </div>
                <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">${secret.description}</p>
                <code class="text-xs text-gray-600 dark:text-gray-300 bg-gray-100 dark:bg-gray-700 px-2 py-1 rounded mt-2 block break-all">${escapeHtml(secret.value)}</code>
            </div>
            <button onclick="copyToClipboard('${escapeHtml(secret.name === 'GITHUB_TOKEN' ? (state.githubToken || '') : state.webhookSecret)}')"
                class="ml-4 p-2 text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
            </button>
        </div>
    `).join('');
}

function editSecret(name) {
    const newValue = prompt(`${name}을(를) 입력하세요:`);
    if (newValue !== null) {
        if (name === 'GITHUB_TOKEN') {
            state.githubToken = newValue;
        } else if (name === 'WEBHOOK_SECRET') {
            state.webhookSecret = newValue;
        }
        saveState();
        renderSecretsList();
    }
}

function downloadSecretsJson() {
    const secrets = {
        GITHUB_TOKEN: state.githubToken || '(GitHub에서 생성 필요)',
        WEBHOOK_SECRET: state.webhookSecret || '',
        _metadata: {
            orgName: state.orgName,
            projectNumber: state.projectNumber,
            statusLabels: state.labels,
            workerUrl: state.workerUrl,
            generatedAt: new Date().toISOString()
        }
    };

    const blob = new Blob([JSON.stringify(secrets, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-projects-sync-secrets.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    showToast('JSON 다운로드 완료');
}

function downloadSecretsTxt() {
    const content = `===== GitHub Projects Sync Secrets =====
생성일: ${new Date().toLocaleString('ko-KR')}
Organization: ${state.orgName}
Project Number: ${state.projectNumber}
Worker URL: ${state.workerUrl || '(미설정)'}

===== Cloudflare Worker Secrets =====

GITHUB_TOKEN=${state.githubToken || '(GitHub에서 생성 필요)'}

WEBHOOK_SECRET=${state.webhookSecret || '(미설정)'}

===== wrangler secret 명령어 =====

npx wrangler secret put GITHUB_TOKEN
# 프롬프트에 GITHUB_TOKEN 값 입력

npx wrangler secret put WEBHOOK_SECRET
# 프롬프트에 WEBHOOK_SECRET 값 입력

===== Status Labels =====
${state.labels.join('\n')}
`;

    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-projects-sync-secrets.txt';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    showToast('TXT 다운로드 완료');
}

function copyAllSecrets() {
    const content = `GITHUB_TOKEN=${state.githubToken || '(GitHub에서 생성 필요)'}
WEBHOOK_SECRET=${state.webhookSecret || ''}`;

    copyToClipboard(content);
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
    }).catch(err => {
        console.error('Failed to copy:', err);
        showToast('복사에 실패했습니다.');
    });
}

function copyCommand(command) {
    copyToClipboard(command);
}

function showToast(message) {
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toastMessage');

    toastMessage.textContent = message;
    toast.classList.remove('translate-y-full', 'opacity-0');

    setTimeout(() => {
        toast.classList.add('translate-y-full', 'opacity-0');
    }, 3000);
}

function resetWizard() {
    if (confirm('모든 설정을 초기화하시겠습니까?\n저장된 데이터가 모두 삭제됩니다.')) {
        localStorage.removeItem(STORAGE_KEY);
        state = {
            currentStep: 1,
            maxReachedStep: 1,
            projectUrl: '',
            orgName: '',
            projectNumber: '',
            subdomain: '',
            labels: [...DEFAULT_LABELS],
            workerUrl: '',
            webhookSecret: '',
            githubToken: ''
        };

        // UI 초기화
        document.getElementById('projectUrl').value = '';
        document.getElementById('orgName').value = '';
        document.getElementById('projectNumber').value = '';
        document.getElementById('subdomain').value = '';
        document.getElementById('workerUrl').value = '';
        document.getElementById('webhookSecret').value = '';

        renderLabels();
        showStep(1);
        renderStepIndicators();
        updateNavigationButtons();

        showToast('설정이 초기화되었습니다.');
    }
}
