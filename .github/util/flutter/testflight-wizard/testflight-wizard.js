/**
 * Flutter iOS TestFlight 통합 마법사
 * 파일 업로드, Base64 변환, localStorage 진행률 저장 포함
 */

// ============================================
// State Management
// ============================================

const state = {
    currentStep: 1,
    totalSteps: 9,
    projectPath: '',
    bundleId: '',
    teamId: '',
    profileName: '',
    appName: '',
    encryptionType: 'none',
    // 파일 데이터 (Base64)
    p12Base64: '',
    p12Password: '',
    provisionBase64: '',
    p8Base64: '',
    apiKeyId: '',
    issuerId: ''
};

// ============================================
// LocalStorage Functions
// ============================================

const STORAGE_KEY = 'flutter_ios_wizard_state';
const STORAGE_WARNING_KEY = 'flutter_ios_wizard_security_warning_dismissed';

function saveState() {
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
        console.warn('localStorage 저장 실패:', e);
    }
}

function loadState() {
    try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
            const savedState = JSON.parse(saved);
            // 현재 코드의 totalSteps 보존 (버전 업그레이드 시 캐시된 값 무시)
            const currentTotalSteps = state.totalSteps;
            Object.assign(state, savedState);
            state.totalSteps = currentTotalSteps; // 항상 현재 코드 기준으로 설정

            // currentStep이 totalSteps를 초과하면 보정
            if (state.currentStep > state.totalSteps) {
                state.currentStep = state.totalSteps;
            }

            restoreUIFromState();
            return true;
        }
    } catch (e) {
        console.warn('localStorage 로드 실패:', e);
    }
    return false;
}

function clearState() {
    try {
        localStorage.removeItem(STORAGE_KEY);
    } catch (e) {
        console.warn('localStorage 삭제 실패:', e);
    }
}

function restoreUIFromState() {
    // 입력 필드 복원
    const inputs = {
        'projectPath': state.projectPath,
        'bundleId': state.bundleId,
        'bundleId-confirm': state.bundleId,
        'teamId': state.teamId,
        'profileName': state.profileName,
        'profileName-confirm': state.profileName,
        'appName': state.appName,
        'p12-password': state.p12Password,
        'api-key-id': state.apiKeyId,
        'issuer-id': state.issuerId
    };

    Object.entries(inputs).forEach(([id, value]) => {
        const el = document.getElementById(id);
        if (el && value) el.value = value;
    });

    // Step 5 display 요소 업데이트
    if (state.bundleId) {
        const displayBundleId = document.getElementById('display-bundle-id');
        if (displayBundleId) displayBundleId.textContent = state.bundleId;
    }
    if (state.profileName) {
        const displayProfileName = document.getElementById('display-profile-name');
        if (displayProfileName) displayProfileName.textContent = state.profileName;
    }

    // 암호화 설정 복원
    if (state.encryptionType) {
        const radio = document.querySelector(`input[name="encryptionType"][value="${state.encryptionType}"]`);
        if (radio) radio.checked = true;
    }

    // 파일 업로드 상태 복원
    if (state.p12Base64) {
        document.getElementById('p12-upload').classList.add('has-file');
        const info = document.getElementById('p12-info');
        if (info) {
            info.style.display = 'block';
            info.textContent = '✅ 인증서 파일 로드됨';
        }
    }

    if (state.provisionBase64) {
        document.getElementById('provision-upload').classList.add('has-file');
        const info = document.getElementById('provision-info');
        if (info) {
            info.style.display = 'block';
            info.textContent = '✅ 프로비저닝 프로파일 로드됨';
        }
    }

    if (state.p8Base64) {
        document.getElementById('p8-upload').classList.add('has-file');
        const info = document.getElementById('p8-info');
        if (info) {
            info.style.display = 'block';
            info.textContent = '✅ API Key 파일 로드됨';
        }
    }
}

// ============================================
// Security Warning
// ============================================

function showSecurityWarning() {
    const dismissed = localStorage.getItem(STORAGE_WARNING_KEY);
    if (!dismissed) {
        const warning = document.getElementById('securityWarning');
        if (warning) {
            warning.classList.remove('hidden');
        }
    }
}

function closeSecurityWarning() {
    const warning = document.getElementById('securityWarning');
    if (warning) {
        warning.classList.add('hidden');
        localStorage.setItem(STORAGE_WARNING_KEY, 'true');
    }
}

// ============================================
// DOM Utility Functions
// ============================================

function $(selector) {
    return document.querySelector(selector);
}

function $$(selector) {
    return document.querySelectorAll(selector);
}

function getInputValue(id) {
    const element = document.getElementById(id);
    return element?.value?.trim() || '';
}

function setElementText(id, text) {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = text;
    }
}

function setElementHtml(id, html) {
    const element = document.getElementById(id);
    if (element) {
        element.innerHTML = html;
    }
}

// ============================================
// File Upload & Base64 Conversion
// ============================================

function fileToBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            resolve(base64);
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
    });
}

// .p12 파일 업로드
async function handleP12Upload(event) {
    const file = event.target.files[0];
    if (file) await handleP12File(file);
}

async function handleP12File(file) {
    if (!file.name.endsWith('.p12')) {
        showToast('⚠️ .p12 파일만 업로드 가능합니다');
        return;
    }

    try {
        state.p12Base64 = await fileToBase64(file);
        document.getElementById('p12-upload').classList.add('has-file');
        const info = document.getElementById('p12-info');
        info.style.display = 'block';
        info.textContent = `✅ ${file.name} (${(file.size/1024).toFixed(1)}KB)`;
        saveState();
        showToast('✅ 인증서 파일 업로드 완료');
    } catch (error) {
        showToast('❌ 파일 읽기 실패: ' + error.message);
    }
}

// .mobileprovision 파일 업로드
async function handleProvisionUpload(event) {
    const file = event.target.files[0];
    if (file) await handleProvisionFile(file);
}

async function handleProvisionFile(file) {
    if (!file.name.endsWith('.mobileprovision')) {
        showToast('⚠️ .mobileprovision 파일만 업로드 가능합니다');
        return;
    }

    try {
        state.provisionBase64 = await fileToBase64(file);
        document.getElementById('provision-upload').classList.add('has-file');
        const info = document.getElementById('provision-info');
        info.style.display = 'block';
        info.textContent = `✅ ${file.name} (${(file.size/1024).toFixed(1)}KB)`;
        saveState();
        showToast('✅ 프로비저닝 프로파일 업로드 완료');
    } catch (error) {
        showToast('❌ 파일 읽기 실패: ' + error.message);
    }
}

// .p8 파일 업로드
async function handleP8Upload(event) {
    const file = event.target.files[0];
    if (file) await handleP8File(file);
}

async function handleP8File(file) {
    if (!file.name.endsWith('.p8')) {
        showToast('⚠️ .p8 파일만 업로드 가능합니다');
        return;
    }

    try {
        state.p8Base64 = await fileToBase64(file);
        document.getElementById('p8-upload').classList.add('has-file');
        const info = document.getElementById('p8-info');
        info.style.display = 'block';
        info.textContent = `✅ ${file.name}`;

        // 파일명에서 Key ID 자동 추출
        const match = file.name.match(/AuthKey_(\w+)\.p8/);
        if (match) {
            state.apiKeyId = match[1];
            document.getElementById('api-key-id').value = match[1];
        }

        saveState();
        showToast('✅ API Key 파일 업로드 완료');
    } catch (error) {
        showToast('❌ 파일 읽기 실패: ' + error.message);
    }
}

// Drag & Drop 설정
function setupDragAndDrop() {
    document.querySelectorAll('.file-upload').forEach(el => {
        el.addEventListener('dragover', (e) => {
            e.preventDefault();
            el.classList.add('dragover');
        });

        el.addEventListener('dragleave', () => {
            el.classList.remove('dragover');
        });

        el.addEventListener('drop', (e) => {
            e.preventDefault();
            el.classList.remove('dragover');
            const file = e.dataTransfer.files[0];

            if (el.id === 'p12-upload') handleP12File(file);
            if (el.id === 'provision-upload') handleProvisionFile(file);
            if (el.id === 'p8-upload') handleP8File(file);
        });
    });
}

// ============================================
// Folder Selection (File System Access API)
// ============================================

async function selectProjectFolder() {
    if ('showDirectoryPicker' in window) {
        try {
            const dirHandle = await window.showDirectoryPicker();
            const projectPath = dirHandle.name;

            const input = document.getElementById('projectPath');
            if (input) {
                input.value = `선택된 폴더: ${projectPath} (터미널에서 실제 경로를 사용하세요)`;
                input.placeholder = '선택된 폴더를 확인하고 실제 경로를 입력하세요';
            }

            showToast(`폴더 "${projectPath}" 선택됨`);
        } catch (err) {
            if (err.name !== 'AbortError') {
                console.error('폴더 선택 오류:', err);
                showToast('폴더 선택에 실패했습니다. 경로를 직접 입력해주세요.');
            }
        }
    } else {
        showToast('이 브라우저는 폴더 선택을 지원하지 않습니다.');
        const input = document.getElementById('projectPath');
        if (input) input.focus();
    }
}

// ============================================
// Clipboard Functions
// ============================================

async function copyToClipboard(text) {
    try {
        await navigator.clipboard.writeText(text);
        showToast('클립보드에 복사되었습니다!');
        return true;
    } catch (err) {
        // Fallback
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast('클립보드에 복사되었습니다!');
        return true;
    }
}

function copyCode(button) {
    const codeBlock = button.closest('.code-block');
    const pre = codeBlock?.querySelector('pre');
    if (!pre) return;

    const text = pre.textContent || '';

    navigator.clipboard.writeText(text).then(() => {
        const originalText = button.textContent;
        button.textContent = '복사됨!';
        button.classList.add('bg-green-600');
        setTimeout(() => {
            button.textContent = originalText;
            button.classList.remove('bg-green-600');
        }, 2000);
    }).catch(() => {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast('복사되었습니다!');
    });
}

function showToast(message) {
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
    }, 3000);
}

// ============================================
// Navigation Functions
// ============================================

function updateProgress() {
    $$('.step-indicator').forEach((indicator, index) => {
        const stepNum = index + 1;
        const circle = indicator.querySelector('.step-circle');
        const label = indicator.querySelector('span');

        if (stepNum < state.currentStep) {
            // 완료된 스텝
            circle.className = 'step-circle w-10 h-10 rounded-full bg-green-500 text-white flex items-center justify-center font-bold text-sm z-10 shadow-lg';
            circle.innerHTML = '✓';
            if (label) label.className = 'text-xs mt-2 text-green-400 text-center hidden md:block';
        } else if (stepNum === state.currentStep) {
            // 현재 스텝 - 파랑-보라 그라데이션
            circle.className = 'step-circle w-10 h-10 rounded-full bg-gradient-to-r from-blue-500 to-purple-500 text-white flex items-center justify-center font-bold text-sm z-10 shadow-lg shadow-blue-500/30';
            circle.innerHTML = stepNum;
            if (label) label.className = 'text-xs mt-2 text-blue-400 text-center hidden md:block';
        } else {
            // 아직 안 한 스텝
            circle.className = 'step-circle w-10 h-10 rounded-full bg-slate-700 text-slate-400 flex items-center justify-center font-bold text-sm z-10';
            circle.innerHTML = stepNum;
            if (label) label.className = 'text-xs mt-2 text-slate-500 text-center hidden md:block';
        }
    });
}

function showStep(stepNumber) {
    $$('.step-content').forEach(step => {
        step.classList.add('hidden');
        step.classList.remove('fade-in');
    });

    const currentStepElement = $(`.step-content[data-step="${stepNumber}"]`);
    if (currentStepElement) {
        currentStepElement.classList.remove('hidden');
        currentStepElement.classList.add('fade-in');
    }

    initializeStep(stepNumber);
}

function initializeStep(stepNumber) {
    switch (stepNumber) {
        case 2:
            // Step 2: Distribution 인증서
            restoreInputValues();
            break;
        case 3:
            // Step 3: App ID (Bundle ID) - bundleId 입력
            restoreInputValues();
            break;
        case 4:
            // Step 4: Provisioning Profile - profileName 입력
            restoreInputValues();
            break;
        case 5:
            // Step 5: App Store Connect 앱 등록 (신규!)
            syncStep5ASCValues();
            break;
        case 6:
            // Step 6: 앱 정보 확인 - 이전 단계에서 입력한 값 표시
            syncStep6Values();
            restoreInputValues();
            break;
        case 7:
            // Step 7: API Key
            restoreInputValues();
            break;
        case 8:
            // Step 8: Fastlane 설정
            generateInitCommand();
            break;
        case 9:
            // Step 9: 완료
            generateResults();
            break;
    }
}

function syncStep5ASCValues() {
    // Step 3에서 입력한 Bundle ID를 Step 5 App Store Connect 가이드에 표시
    const bundleIdValue = state.bundleId || getInputValue('bundleId');
    const displayBundleIdAsc = document.getElementById('display-bundle-id-asc');
    if (displayBundleIdAsc && bundleIdValue) {
        displayBundleIdAsc.textContent = bundleIdValue;
    }
}

function syncStep6Values() {
    // Step 3에서 입력한 Bundle ID를 Step 6에 표시
    const bundleIdValue = state.bundleId || getInputValue('bundleId');
    const displayBundleId = document.getElementById('display-bundle-id');
    if (displayBundleId && bundleIdValue) {
        displayBundleId.textContent = bundleIdValue;
    }

    // Step 4에서 입력한 Profile Name을 Step 6에 표시
    const profileNameValue = state.profileName || getInputValue('profileName');
    const displayProfileName = document.getElementById('display-profile-name');
    if (displayProfileName && profileNameValue) {
        displayProfileName.textContent = profileNameValue;
    }

    // 확인용 입력 필드에도 값 설정 (readonly)
    const bundleIdConfirm = document.getElementById('bundleId-confirm');
    if (bundleIdConfirm && bundleIdValue) {
        bundleIdConfirm.value = bundleIdValue;
    }

    const profileNameConfirm = document.getElementById('profileName-confirm');
    if (profileNameConfirm && profileNameValue) {
        profileNameConfirm.value = profileNameValue;
    }
}

function restoreInputValues() {
    const inputs = {
        'bundleId': state.bundleId,
        'bundleId-confirm': state.bundleId,
        'teamId': state.teamId,
        'profileName': state.profileName,
        'profileName-confirm': state.profileName,
        'appName': state.appName,
        'p12-password': state.p12Password,
        'api-key-id': state.apiKeyId,
        'issuer-id': state.issuerId
    };

    Object.entries(inputs).forEach(([id, value]) => {
        const el = document.getElementById(id);
        if (el && value) el.value = value;
    });
}

function nextStep() {
    saveCurrentStepData();

    if (state.currentStep < state.totalSteps) {
        state.currentStep++;
        showStep(state.currentStep);
        updateProgress();
        saveState();
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

function prevStep() {
    if (state.currentStep > 1) {
        saveCurrentStepData();
        state.currentStep--;
        showStep(state.currentStep);
        updateProgress();
        saveState();
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

function skipStep(stepNumber) {
    if (stepNumber < state.totalSteps) {
        saveCurrentStepData();
        state.currentStep = stepNumber + 1;
        showStep(state.currentStep);
        updateProgress();
        saveState();
        window.scrollTo({ top: 0, behavior: 'smooth' });
        showToast(`Step ${stepNumber} 건너뛰기`);
    }
}

function goToStep(targetStep) {
    // 유효 범위 체크
    if (targetStep < 1 || targetStep > state.totalSteps) return;

    // 현재 스텝이면 무시
    if (targetStep === state.currentStep) return;

    // 현재 데이터 저장
    saveCurrentStepData();

    // 스텝 이동
    state.currentStep = targetStep;
    showStep(state.currentStep);
    updateProgress();
    saveState();
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function setupStepClickHandlers() {
    $$('.step-indicator').forEach((indicator) => {
        indicator.style.cursor = 'pointer';
        indicator.addEventListener('click', () => {
            const targetStep = parseInt(indicator.dataset.step, 10);
            goToStep(targetStep);
        });
    });
}

function resetWizard() {
    if (confirm('모든 데이터를 초기화하시겠습니까?')) {
        state.currentStep = 1;
        state.projectPath = '';
        state.bundleId = '';
        state.teamId = '';
        state.profileName = '';
        state.appName = '';
        state.encryptionType = 'none';
        state.p12Base64 = '';
        state.p12Password = '';
        state.provisionBase64 = '';
        state.p8Base64 = '';
        state.apiKeyId = '';
        state.issuerId = '';

        clearState();

        // UI 초기화
        const inputs = ['projectPath', 'bundleId', 'bundleId-confirm', 'teamId', 'profileName', 'profileName-confirm', 'appName', 'p12-password', 'api-key-id', 'issuer-id'];
        inputs.forEach(id => {
            const input = document.getElementById(id);
            if (input) input.value = '';
        });

        // Display 요소 초기화
        const displayBundleId = document.getElementById('display-bundle-id');
        if (displayBundleId) displayBundleId.textContent = '(미입력)';
        const displayProfileName = document.getElementById('display-profile-name');
        if (displayProfileName) displayProfileName.textContent = '(미입력)';

        // 파일 업로드 상태 초기화
        document.querySelectorAll('.file-upload').forEach(el => {
            el.classList.remove('has-file');
        });
        document.querySelectorAll('.file-info').forEach(el => {
            el.style.display = 'none';
        });

        showStep(1);
        updateProgress();
        showToast('마법사가 초기화되었습니다.');
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

// ============================================
// Data Management Functions
// ============================================

function saveCurrentStepData() {
    switch (state.currentStep) {
        case 1:
            // Step 1: 시작하기 - 프로젝트 경로
            state.projectPath = getInputValue('projectPath');
            if (state.projectPath.startsWith('선택된 폴더:')) {
                state.projectPath = '';
            }
            break;
        case 2:
            // Step 2: Distribution 인증서 - .p12 파일 및 비밀번호
            state.p12Password = getInputValue('p12-password');
            break;
        case 3:
            // Step 3: App ID (Bundle ID) - bundleId 입력
            state.bundleId = getInputValue('bundleId');
            break;
        case 4:
            // Step 4: Provisioning Profile - profileName 입력
            state.profileName = getInputValue('profileName');
            break;
        case 5:
            // Step 5: App Store Connect 앱 등록 - 별도 저장 없음 (확인 단계)
            break;
        case 6:
            // Step 6: 앱 정보 확인 - Team ID, App Name, 암호화 설정
            state.teamId = getInputValue('teamId').toUpperCase();
            state.appName = getInputValue('appName');
            const encryptionRadio = document.querySelector('input[name="encryptionType"]:checked');
            state.encryptionType = encryptionRadio ? encryptionRadio.value : 'none';
            break;
        case 7:
            // Step 7: API Key - apiKeyId, issuerId
            state.apiKeyId = getInputValue('api-key-id');
            state.issuerId = getInputValue('issuer-id');
            break;
        case 8:
            // Step 8: Fastlane 설정 - 별도 저장 없음
            break;
        case 9:
            // Step 9: 완료 - 별도 저장 없음
            break;
    }

    saveState();
}

// ============================================
// Command Generation Functions
// ============================================

function generateInitCommand() {
    const projectPath = state.projectPath || '/path/to/project';
    const bundleId = state.bundleId || 'com.example.app';
    const teamId = state.teamId || 'TEAM_ID';
    const profileName = state.profileName || 'Profile Name';
    const usesNonExemptEncryption = state.encryptionType === 'standard' ? 'true' : 'false';

    const cmd = `cd "${projectPath}" && bash ".github/util/flutter/testflight-wizard/testflight-wizard-setup.sh" "${projectPath}" "${bundleId}" "${teamId}" "${profileName}" "${usesNonExemptEncryption}"`;
    setElementText('initCmd', cmd);
}

function generateResults() {
    const secrets = [
        { key: 'APPLE_CERTIFICATE_BASE64', value: state.p12Base64, desc: 'Distribution 인증서 (.p12)' },
        { key: 'APPLE_CERTIFICATE_PASSWORD', value: state.p12Password, desc: '인증서 비밀번호' },
        { key: 'APPLE_PROVISIONING_PROFILE_BASE64', value: state.provisionBase64, desc: 'Provisioning Profile' },
        { key: 'IOS_PROVISIONING_PROFILE_NAME', value: state.profileName, desc: '프로파일 이름' },
        { key: 'APP_STORE_CONNECT_API_KEY_BASE64', value: state.p8Base64, desc: 'API Key (.p8)' },
        { key: 'APP_STORE_CONNECT_API_KEY_ID', value: state.apiKeyId, desc: 'API Key ID' },
        { key: 'APP_STORE_CONNECT_ISSUER_ID', value: state.issuerId, desc: 'Issuer ID' },
        { key: 'APPLE_TEAM_ID', value: state.teamId, desc: 'Apple Team ID' },
        { key: 'IOS_BUNDLE_ID', value: state.bundleId, desc: 'Bundle ID' }
    ];

    const container = document.getElementById('results-container');
    container.innerHTML = secrets.map(s => `
        <div class="result-item">
            <div class="key">
                <span>${s.key} <small style="color:#71717a">(${s.desc})</small></span>
                <button class="copy-btn-small" onclick="copyValue(this, '${s.key}')">복사</button>
            </div>
            <div class="value" id="value-${s.key}">${s.value || '(비어있음)'}</div>
        </div>
    `).join('');
}

function copyValue(btn, key) {
    const value = document.getElementById(`value-${key}`).textContent;
    if (value === '(비어있음)') {
        showToast('⚠️ 값이 비어있습니다');
        return;
    }

    navigator.clipboard.writeText(value).then(() => {
        btn.textContent = '복사됨!';
        btn.classList.add('copied');
        setTimeout(() => {
            btn.textContent = '복사';
            btn.classList.remove('copied');
        }, 2000);
    });
}

function downloadAsJson() {
    const secrets = {
        APPLE_CERTIFICATE_BASE64: state.p12Base64,
        APPLE_CERTIFICATE_PASSWORD: state.p12Password,
        APPLE_PROVISIONING_PROFILE_BASE64: state.provisionBase64,
        IOS_PROVISIONING_PROFILE_NAME: state.profileName,
        APP_STORE_CONNECT_API_KEY_BASE64: state.p8Base64,
        APP_STORE_CONNECT_API_KEY_ID: state.apiKeyId,
        APP_STORE_CONNECT_ISSUER_ID: state.issuerId,
        APPLE_TEAM_ID: state.teamId,
        IOS_BUNDLE_ID: state.bundleId
    };

    const jsonStr = JSON.stringify(secrets, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-secrets.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ JSON 파일 다운로드 완료!');
}

function downloadAsTxt() {
    const lines = [
        '# GitHub Secrets for iOS TestFlight Deployment',
        '# 생성일: ' + new Date().toLocaleString('ko-KR'),
        '',
        '===== GitHub Repository Secrets =====',
        '',
        'APPLE_CERTIFICATE_BASE64:',
        state.p12Base64 || '(미입력)',
        '',
        'APPLE_CERTIFICATE_PASSWORD:',
        state.p12Password || '(미입력)',
        '',
        'APPLE_PROVISIONING_PROFILE_BASE64:',
        state.provisionBase64 || '(미입력)',
        '',
        'IOS_PROVISIONING_PROFILE_NAME:',
        state.profileName || '(미입력)',
        '',
        'APP_STORE_CONNECT_API_KEY_BASE64:',
        state.p8Base64 || '(미입력)',
        '',
        'APP_STORE_CONNECT_API_KEY_ID:',
        state.apiKeyId || '(미입력)',
        '',
        'APP_STORE_CONNECT_ISSUER_ID:',
        state.issuerId || '(미입력)',
        '',
        'APPLE_TEAM_ID:',
        state.teamId || '(미입력)',
        '',
        'IOS_BUNDLE_ID:',
        state.bundleId || '(미입력)',
        '',
        '====================================='
    ];

    const txtStr = lines.join('\n');
    const blob = new Blob([txtStr], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-secrets.txt';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ TXT 파일 다운로드 완료!');
}

// ============================================
// Secret Guide Modal Functions
// ============================================

const secretGuides = {
    certificate: {
        title: '📜 배포 인증서 (.p12) 생성 가이드',
        steps: [
            '1. Mac에서 "키체인 접근" 앱을 엽니다.',
            '2. "로그인" 키체인에서 "Apple Distribution" 인증서를 찾습니다.',
            '3. 인증서를 우클릭 → "내보내기"를 선택합니다.',
            '4. 파일 형식을 ".p12"로 선택합니다.',
            '5. 안전한 비밀번호를 설정합니다.',
            '6. 아래 명령어로 Base64 인코딩합니다:'
        ],
        commands: [
            'base64 -i ~/Desktop/Certificates.p12 | pbcopy',
            '# 클립보드에 복사됨'
        ]
    },
    profile: {
        title: '📋 프로비저닝 프로파일 생성 가이드',
        steps: [
            '1. Apple Developer Console 접속',
            '2. Certificates, Identifiers & Profiles → Profiles',
            '3. "App Store" Distribution 타입 선택',
            '4. 앱의 Bundle ID 선택',
            '5. Distribution Certificate 선택',
            '6. 프로파일 다운로드',
            '7. 아래 명령어로 Base64 인코딩:'
        ],
        commands: [
            'base64 -i ~/Downloads/YourProfile.mobileprovision | pbcopy'
        ]
    },
    apikey: {
        title: '🔑 App Store Connect API Key 생성 가이드',
        steps: [
            '1. App Store Connect 접속',
            '2. Users and Access → Keys 탭',
            '3. "+" 버튼으로 새 API Key 생성',
            '4. Access: "App Manager" 또는 "Admin" 선택',
            '5. Key ID 복사',
            '6. Issuer ID 복사 (상단에 표시됨)',
            '7. API Key 다운로드 (.p8 파일)',
            '8. 아래 명령어로 Base64 인코딩:'
        ],
        commands: [
            'base64 -i ~/Downloads/AuthKey_XXXXXX.p8 | pbcopy'
        ]
    }
};

function showSecretGuide(type) {
    const guide = secretGuides[type];
    if (!guide) return;

    const modal = document.getElementById('guideModal');
    const titleEl = document.getElementById('guideTitle');
    const content = document.getElementById('guideContent');

    if (!modal || !content) return;

    if (titleEl) {
        titleEl.textContent = guide.title;
    }

    let html = '<ol class="list-decimal list-inside space-y-2 mb-4">';
    guide.steps.forEach(step => {
        html += `<li class="text-slate-300 text-sm">${step}</li>`;
    });
    html += '</ol>';

    if (guide.commands && guide.commands.length > 0) {
        html += '<div class="space-y-2">';
        guide.commands.forEach(cmd => {
            html += `
                <div class="code-block">
                    <button class="copy-btn absolute top-2 right-2 px-3 py-1 bg-slate-700 hover:bg-slate-600 rounded text-xs text-slate-300 transition" onclick="copyCode(this)">복사</button>
                    <pre>${cmd}</pre>
                </div>
            `;
        });
        html += '</div>';
    }

    content.innerHTML = html;
    modal.classList.remove('hidden');
}

function closeGuideModal(event) {
    if (event && event.target !== event.currentTarget) {
        return;
    }

    const modal = document.getElementById('guideModal');
    if (modal) {
        modal.classList.add('hidden');
    }
}

// ============================================
// Input Event Handlers
// ============================================

function setupInputHandlers() {
    // Team ID 대문자 자동 변환
    const teamIdInput = document.getElementById('teamId');
    if (teamIdInput) {
        teamIdInput.addEventListener('input', (e) => {
            e.target.value = e.target.value.toUpperCase();
        });
    }

    // ESC 키로 모달 닫기
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeGuideModal();
        }
    });

    // 입력 필드 변경 시 저장
    const inputIds = ['projectPath', 'bundleId', 'bundleId-confirm', 'teamId', 'profileName', 'profileName-confirm', 'appName', 'p12-password', 'api-key-id', 'issuer-id'];
    inputIds.forEach(id => {
        const input = document.getElementById(id);
        if (input) {
            input.addEventListener('change', saveState);
            input.addEventListener('blur', saveState);
        }
    });

    // Bundle ID 입력 시 실시간 동기화
    const bundleIdInput = document.getElementById('bundleId');
    if (bundleIdInput) {
        bundleIdInput.addEventListener('input', (e) => {
            state.bundleId = e.target.value.trim();
            const displayEl = document.getElementById('display-bundle-id');
            if (displayEl) displayEl.textContent = e.target.value.trim() || '(미입력)';
        });
    }

    // Profile Name 입력 시 실시간 동기화
    const profileNameInput = document.getElementById('profileName');
    if (profileNameInput) {
        profileNameInput.addEventListener('input', (e) => {
            state.profileName = e.target.value.trim();
            const displayEl = document.getElementById('display-profile-name');
            if (displayEl) displayEl.textContent = e.target.value.trim() || '(미입력)';
        });
    }

    // 암호화 설정 변경 시 저장
    document.querySelectorAll('input[name="encryptionType"]').forEach(radio => {
        radio.addEventListener('change', saveState);
    });
}

// ============================================
// Initialization
// ============================================

function initialize() {
    // 저장된 상태 로드
    const hasState = loadState();

    if (hasState) {
        showStep(state.currentStep);
        updateProgress();
        showToast('이전 진행 상태를 복원했습니다');
    } else {
        showStep(1);
        updateProgress();
    }

    setupInputHandlers();
    setupDragAndDrop();
    setupStepClickHandlers();
    showSecurityWarning();
}

// DOM 로드 완료 시 초기화
document.addEventListener('DOMContentLoaded', initialize);

// 페이지 언로드 시 경고 (데이터 손실 방지)
window.addEventListener('beforeunload', (e) => {
    if (state.currentStep > 1 || state.bundleId || state.p12Base64) {
        e.preventDefault();
        e.returnValue = '입력한 데이터가 사라질 수 있습니다. 정말 나가시겠습니까?';
    }
});

// ============================================
// Changelog Modal Functions
// ============================================

// 버전 정보는 index.html의 <script id="versionJson"> 에서 로드
function getVersionData() {
    const scriptEl = document.getElementById('versionJson');
    if (scriptEl) {
        try {
            return JSON.parse(scriptEl.textContent);
        } catch (e) {
            console.error('버전 정보 파싱 실패:', e);
        }
    }
    return null;
}

function openChangelogModal() {
    const modal = document.getElementById('changelogModal');
    const content = document.getElementById('changelogContent');
    const lastUpdated = document.getElementById('changelogLastUpdated');

    const data = getVersionData();
    if (!data) {
        content.innerHTML = '<div class="text-center text-red-400 py-4">버전 정보를 불러올 수 없습니다.</div>';
        modal.classList.remove('hidden');
        document.body.style.overflow = 'hidden';
        return;
    }

    // Build changelog HTML (simple timeline without color dots)
    let html = '';
    data.changelog.forEach((release, index) => {
        const isLatest = index === 0;

        html += `
            <div class="pb-4 ${index < data.changelog.length - 1 ? 'border-b border-slate-700 mb-4' : ''}">
                <div class="flex items-center gap-2 mb-2">
                    <span class="text-white font-semibold">v${release.version}</span>
                    ${isLatest ? '<span class="px-2 py-0.5 text-xs bg-blue-500/20 text-blue-400 rounded-full">Latest</span>' : ''}
                    <span class="text-slate-500 text-xs">${release.date}</span>
                </div>
                <ul class="space-y-1.5 pl-2">
                    ${release.changes.map(change => `
                        <li class="text-sm text-slate-400 flex items-start gap-2">
                            <span class="text-slate-600 mt-1">•</span>
                            <span>${change}</span>
                        </li>
                    `).join('')}
                </ul>
            </div>
        `;
    });

    content.innerHTML = html;
    lastUpdated.textContent = `Last updated: ${data.lastUpdated}`;

    modal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
}

function closeChangelogModal(event) {
    if (event && event.target !== event.currentTarget) return;
    const modal = document.getElementById('changelogModal');
    modal.classList.add('hidden');
    document.body.style.overflow = '';
}

// ESC 키로 changelog 모달도 닫기
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeChangelogModal();
    }
});

// 페이지 로드 시 버전 배지 업데이트
document.addEventListener('DOMContentLoaded', () => {
    const data = getVersionData();
    if (data && data.version) {
        const versionBadge = document.getElementById('versionBadge');
        if (versionBadge) {
            versionBadge.textContent = `v${data.version}`;
        }
    }
});
