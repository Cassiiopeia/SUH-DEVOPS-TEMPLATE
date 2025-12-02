/**
 * Flutter iOS TestFlight 설정 마법사
 * TypeScript로 작성된 Step-by-Step 가이드
 */

// ============================================
// Type Definitions
// ============================================

interface WizardState {
    currentStep: number;
    totalSteps: number;
    projectPath: string;
    bundleId: string;
    teamId: string;
    profileName: string;
    appName: string;
}

interface SecretGuide {
    title: string;
    steps: string[];
    commands?: string[];
}

// ============================================
// State Management
// ============================================

const state: WizardState = {
    currentStep: 1,
    totalSteps: 5,
    projectPath: '',
    bundleId: '',
    teamId: '',
    profileName: '',
    appName: ''
};

// ============================================
// Secret Generation Guides
// ============================================

const secretGuides: Record<string, SecretGuide> = {
    certificate: {
        title: '📜 배포 인증서 (.p12) 생성 가이드',
        steps: [
            '1. Mac에서 "키체인 접근" 앱을 엽니다.',
            '2. "로그인" 키체인에서 "Apple Distribution" 인증서를 찾습니다.',
            '3. 인증서를 우클릭 → "내보내기"를 선택합니다.',
            '4. 파일 형식을 ".p12"로 선택합니다.',
            '5. 안전한 비밀번호를 설정합니다 (이 비밀번호가 APPLE_CERTIFICATE_PASSWORD)',
            '6. 아래 명령어로 Base64 인코딩합니다:'
        ],
        commands: [
            'base64 -i ~/Desktop/Certificates.p12 | pbcopy',
            '# 클립보드에 복사됨 → GitHub Secret에 붙여넣기'
        ]
    },
    profile: {
        title: '📋 프로비저닝 프로파일 생성 가이드',
        steps: [
            '1. Apple Developer Console (https://developer.apple.com) 접속',
            '2. Certificates, Identifiers & Profiles → Profiles',
            '3. "+" 버튼으로 새 프로파일 생성 또는 기존 프로파일 선택',
            '4. "App Store" Distribution 타입 선택',
            '5. 앱의 Bundle ID 선택',
            '6. Distribution Certificate 선택',
            '7. 프로파일 다운로드 (.mobileprovision 파일)',
            '8. 아래 명령어로 Base64 인코딩:'
        ],
        commands: [
            'base64 -i ~/Downloads/YourProfile.mobileprovision | pbcopy',
            '# 클립보드에 복사됨 → GitHub Secret에 붙여넣기'
        ]
    },
    apikey: {
        title: '🔑 App Store Connect API Key 생성 가이드',
        steps: [
            '1. App Store Connect (https://appstoreconnect.apple.com) 접속',
            '2. Users and Access → Keys 탭',
            '3. "+" 버튼으로 새 API Key 생성',
            '4. 이름 입력, Access: "App Manager" 또는 "Admin" 선택',
            '5. Key ID 복사 → APP_STORE_CONNECT_API_KEY_ID',
            '6. Issuer ID 복사 (상단에 표시됨) → APP_STORE_CONNECT_ISSUER_ID',
            '7. API Key 다운로드 (.p8 파일, 한 번만 다운로드 가능!)',
            '8. 아래 명령어로 Base64 인코딩:'
        ],
        commands: [
            'base64 -i ~/Downloads/AuthKey_XXXXXX.p8 | pbcopy',
            '# 클립보드에 복사됨 → GitHub Secret에 붙여넣기'
        ]
    }
};

// ============================================
// DOM Utility Functions
// ============================================

function $(selector: string): HTMLElement | null {
    return document.querySelector(selector);
}

function $$(selector: string): NodeListOf<HTMLElement> {
    return document.querySelectorAll(selector);
}

function getInputValue(id: string): string {
    const element = document.getElementById(id) as HTMLInputElement;
    return element?.value?.trim() || '';
}

function setElementText(id: string, text: string): void {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = text;
    }
}

function setElementHtml(id: string, html: string): void {
    const element = document.getElementById(id);
    if (element) {
        element.innerHTML = html;
    }
}

// ============================================
// Clipboard Functions
// ============================================

async function copyToClipboard(elementId: string): Promise<void> {
    const element = document.getElementById(elementId);
    if (!element) return;

    const text = element.textContent || '';

    try {
        await navigator.clipboard.writeText(text);
        showToast('클립보드에 복사되었습니다!');
    } catch (err) {
        // Fallback for older browsers
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast('클립보드에 복사되었습니다!');
    }
}

function showToast(message: string): void {
    // 기존 토스트 제거
    const existingToast = document.querySelector('.toast');
    if (existingToast) {
        existingToast.remove();
    }

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    document.body.appendChild(toast);

    setTimeout(() => {
        toast.classList.add('show');
    }, 10);

    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 300);
    }, 2000);
}

// ============================================
// Navigation Functions
// ============================================

function updateProgress(): void {
    const progressFill = $('#progressFill');
    const percentage = ((state.currentStep - 1) / (state.totalSteps - 1)) * 100;

    if (progressFill) {
        (progressFill as HTMLElement).style.width = `${percentage}%`;
    }

    // Step dots 업데이트
    $$('.step-dot').forEach((dot, index) => {
        if (index + 1 <= state.currentStep) {
            dot.classList.add('active');
        } else {
            dot.classList.remove('active');
        }
    });
}

function showStep(stepNumber: number): void {
    // 모든 스텝 숨기기
    $$('.step').forEach(step => {
        step.classList.add('hidden');
    });

    // 현재 스텝 표시
    const currentStepElement = $(`#step${stepNumber}`);
    if (currentStepElement) {
        currentStepElement.classList.remove('hidden');
    }

    // 버튼 상태 업데이트
    const prevBtn = $('#prevBtn') as HTMLButtonElement;
    const nextBtn = $('#nextBtn') as HTMLButtonElement;

    if (prevBtn) {
        prevBtn.disabled = stepNumber === 1;
    }

    if (nextBtn) {
        nextBtn.textContent = stepNumber === state.totalSteps ? '완료' : '다음 →';
    }

    // 스텝별 초기화
    initializeStep(stepNumber);
}

function initializeStep(stepNumber: number): void {
    switch (stepNumber) {
        case 1:
            updatePathCheckCommand();
            break;
        case 2:
            // 이전 값들 유지
            break;
        case 3:
            generateInitCommand();
            break;
        case 4:
            updateSecretsPreview();
            break;
        case 5:
            generateSummary();
            break;
    }
}

function nextStep(): void {
    if (!validateCurrentStep()) {
        return;
    }

    saveCurrentStepData();

    if (state.currentStep < state.totalSteps) {
        state.currentStep++;
        showStep(state.currentStep);
        updateProgress();
    } else {
        // 완료
        showToast('설정이 완료되었습니다!');
    }
}

function prevStep(): void {
    if (state.currentStep > 1) {
        state.currentStep--;
        showStep(state.currentStep);
        updateProgress();
    }
}

// ============================================
// Validation Functions
// ============================================

function validateCurrentStep(): boolean {
    const validationElement = $(`#step${state.currentStep}Validation`);

    switch (state.currentStep) {
        case 1:
            const projectPath = getInputValue('projectPath');
            if (!projectPath) {
                showValidationError(validationElement, '프로젝트 경로를 입력해주세요.');
                return false;
            }
            if (!projectPath.startsWith('/')) {
                showValidationError(validationElement, '절대 경로를 입력해주세요. (예: /Users/...)');
                return false;
            }
            clearValidation(validationElement);
            return true;

        case 2:
            const bundleId = getInputValue('bundleId');
            const teamId = getInputValue('teamId');
            const profileName = getInputValue('profileName');

            if (!bundleId) {
                showValidationError(validationElement, 'Bundle ID를 입력해주세요.');
                return false;
            }
            if (!bundleId.includes('.')) {
                showValidationError(validationElement, 'Bundle ID 형식이 올바르지 않습니다. (예: com.example.app)');
                return false;
            }
            if (!teamId) {
                showValidationError(validationElement, 'Team ID를 입력해주세요.');
                return false;
            }
            if (teamId.length !== 10) {
                showValidationError(validationElement, 'Team ID는 10자리여야 합니다.');
                return false;
            }
            if (!profileName) {
                showValidationError(validationElement, 'Provisioning Profile 이름을 입력해주세요.');
                return false;
            }
            clearValidation(validationElement);
            return true;

        default:
            return true;
    }
}

function showValidationError(element: HTMLElement | null, message: string): void {
    if (element) {
        element.innerHTML = `<div class="error">❌ ${message}</div>`;
        element.classList.add('show');
    }
}

function showValidationSuccess(element: HTMLElement | null, message: string): void {
    if (element) {
        element.innerHTML = `<div class="success">✅ ${message}</div>`;
        element.classList.add('show');
    }
}

function clearValidation(element: HTMLElement | null): void {
    if (element) {
        element.innerHTML = '';
        element.classList.remove('show');
    }
}

// ============================================
// Data Management Functions
// ============================================

function saveCurrentStepData(): void {
    switch (state.currentStep) {
        case 1:
            state.projectPath = getInputValue('projectPath');
            break;
        case 2:
            state.bundleId = getInputValue('bundleId');
            state.teamId = getInputValue('teamId');
            state.profileName = getInputValue('profileName');
            state.appName = getInputValue('appName');
            break;
    }

    // LocalStorage에 저장 (새로고침 시 복원용)
    localStorage.setItem('wizardState', JSON.stringify(state));
}

function loadSavedState(): void {
    const saved = localStorage.getItem('wizardState');
    if (saved) {
        try {
            const savedState = JSON.parse(saved) as Partial<WizardState>;
            Object.assign(state, savedState);

            // 입력 필드에 값 복원
            const projectPathInput = document.getElementById('projectPath') as HTMLInputElement;
            const bundleIdInput = document.getElementById('bundleId') as HTMLInputElement;
            const teamIdInput = document.getElementById('teamId') as HTMLInputElement;
            const profileNameInput = document.getElementById('profileName') as HTMLInputElement;
            const appNameInput = document.getElementById('appName') as HTMLInputElement;

            if (projectPathInput) projectPathInput.value = state.projectPath;
            if (bundleIdInput) bundleIdInput.value = state.bundleId;
            if (teamIdInput) teamIdInput.value = state.teamId;
            if (profileNameInput) profileNameInput.value = state.profileName;
            if (appNameInput) appNameInput.value = state.appName;
        } catch (e) {
            console.error('Failed to load saved state:', e);
        }
    }
}

// ============================================
// Command Generation Functions
// ============================================

function updatePathCheckCommand(): void {
    const projectPath = getInputValue('projectPath') || '/path/to/project';
    const cmd = `cd "${projectPath}" && ls pubspec.yaml ios/`;
    setElementText('pathCheckCmd', cmd);
}

function generateInitCommand(): void {
    const scriptPath = getScriptPath();
    const cmd = `cd "${state.projectPath}" && bash "${scriptPath}/init.sh" "${state.projectPath}" "${state.bundleId}" "${state.teamId}" "${state.profileName}"`;
    setElementText('initCmd', cmd);

    const verifyCmd = `ls -la "${state.projectPath}/ios/Gemfile" "${state.projectPath}/ios/fastlane/"`;
    setElementText('verifyCmd', verifyCmd);
}

function getScriptPath(): string {
    // 상대 경로로 스크립트 위치 추정
    return `${state.projectPath}/.github/util/flutter-ios-testflight-init`;
}

function updateSecretsPreview(): void {
    setElementText('teamIdPreview', state.teamId || '-');
    setElementText('bundleIdPreview', state.bundleId || '-');
    setElementText('profileNamePreview', state.profileName || '-');
}

function generateSummary(): void {
    const summaryHtml = `
        <table class="summary-table">
            <tr><td><strong>프로젝트 경로:</strong></td><td><code>${state.projectPath}</code></td></tr>
            <tr><td><strong>Bundle ID:</strong></td><td><code>${state.bundleId}</code></td></tr>
            <tr><td><strong>Team ID:</strong></td><td><code>${state.teamId}</code></td></tr>
            <tr><td><strong>Provisioning Profile:</strong></td><td><code>${state.profileName}</code></td></tr>
            ${state.appName ? `<tr><td><strong>앱 이름:</strong></td><td><code>${state.appName}</code></td></tr>` : ''}
        </table>
    `;
    setElementHtml('summaryContent', summaryHtml);

    // 커밋 명령어 업데이트
    const commitCmd = `cd "${state.projectPath}" && git add ios/Gemfile ios/fastlane/ && git commit -m "chore: iOS Fastlane 설정 추가"`;
    setElementText('commitCmd', commitCmd);
}

// ============================================
// Secret Guide Modal Functions
// ============================================

function showSecretGuide(type: string): void {
    const guide = secretGuides[type];
    if (!guide) return;

    const modal = $('#guideModal');
    const content = $('#guideContent');

    if (!modal || !content) return;

    let html = `<h3>${guide.title}</h3><ol>`;
    guide.steps.forEach(step => {
        html += `<li>${step}</li>`;
    });
    html += '</ol>';

    if (guide.commands && guide.commands.length > 0) {
        html += '<div class="guide-commands">';
        guide.commands.forEach(cmd => {
            html += `<div class="code-block"><code>${cmd}</code></div>`;
        });
        html += '</div>';
    }

    content.innerHTML = html;
    modal.classList.remove('hidden');
}

function closeGuideModal(): void {
    const modal = $('#guideModal');
    if (modal) {
        modal.classList.add('hidden');
    }
}

// ============================================
// GitHub Integration
// ============================================

function openGitHubSecrets(): void {
    // 프로젝트 경로에서 GitHub 레포지토리 URL 추출 시도
    // 로컬에서는 직접 열 수 없으므로 안내 메시지 표시
    const repoUrl = prompt(
        'GitHub Repository URL을 입력하세요:\n(예: https://github.com/username/repo)',
        'https://github.com/'
    );

    if (repoUrl && repoUrl !== 'https://github.com/') {
        const secretsUrl = `${repoUrl}/settings/secrets/actions`;
        window.open(secretsUrl, '_blank');
    }
}

// ============================================
// Input Event Handlers
// ============================================

function setupInputHandlers(): void {
    // 프로젝트 경로 입력 시 명령어 업데이트
    const projectPathInput = document.getElementById('projectPath');
    if (projectPathInput) {
        projectPathInput.addEventListener('input', () => {
            updatePathCheckCommand();
        });
    }

    // Team ID 대문자 자동 변환
    const teamIdInput = document.getElementById('teamId');
    if (teamIdInput) {
        teamIdInput.addEventListener('input', (e) => {
            const input = e.target as HTMLInputElement;
            input.value = input.value.toUpperCase();
        });
    }

    // 모달 외부 클릭 시 닫기
    const modal = $('#guideModal');
    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                closeGuideModal();
            }
        });
    }

    // ESC 키로 모달 닫기
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeGuideModal();
        }
    });
}

// ============================================
// Initialization
// ============================================

function initialize(): void {
    loadSavedState();
    setupInputHandlers();
    showStep(state.currentStep);
    updateProgress();
}

// DOM 로드 완료 시 초기화
document.addEventListener('DOMContentLoaded', initialize);

// ============================================
// Global Exports (for HTML onclick handlers)
// ============================================

// TypeScript에서 window 객체에 함수 노출
declare global {
    interface Window {
        copyToClipboard: typeof copyToClipboard;
        nextStep: typeof nextStep;
        prevStep: typeof prevStep;
        showSecretGuide: typeof showSecretGuide;
        closeGuideModal: typeof closeGuideModal;
        openGitHubSecrets: typeof openGitHubSecrets;
    }
}

window.copyToClipboard = copyToClipboard;
window.nextStep = nextStep;
window.prevStep = prevStep;
window.showSecretGuide = showSecretGuide;
window.closeGuideModal = closeGuideModal;
window.openGitHubSecrets = openGitHubSecrets;
