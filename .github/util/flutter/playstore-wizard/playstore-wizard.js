/**
 * Flutter Android Play Store 통합 마법사
 * 파일 업로드, Base64 변환, localStorage 진행률 저장 포함
 */

// ============================================
// OS Detection
// ============================================

let detectedOS = 'mac'; // 기본값: Mac

function detectOS() {
    const userAgent = navigator.userAgent || navigator.appVersion || navigator.platform;
    
    if (/Win/i.test(userAgent)) {
        return 'windows';
    } else if (/Mac/i.test(userAgent)) {
        return 'mac';
    } else if (/Linux/i.test(userAgent)) {
        return 'linux';
    }
    return 'mac'; // 기본값: Mac
}

// ============================================
// State Management
// ============================================

const state = {
    currentStep: 1,
    maxReachedStep: 1, // 도달한 최대 단계 (이전 단계로 돌아가도 유지)
    totalSteps: 7, // Step 1~7 (프로젝트, Keystore, AAB 빌드, 앱 생성, AAB 업로드, Service Account, 완료)
    projectPath: '',
    detectedOS: 'mac', // OS 감지 결과
    // Project Info
    applicationId: '',
    versionName: '',
    versionCode: '',
    gradleType: 'kts',
    // Keystore
    keyAlias: '',
    storePassword: '',
    keyPassword: '',
    keystoreBase64: '',
    validityDays: '99999', // 기본값: 무제한
    // Certificate Info
    certCN: '',
    certO: '',
    certL: '',
    certC: 'KR',
    // Service Account
    serviceAccountBase64: '',
    // Optional
    googleServicesJson: '',
    envFileContent: ''
};

// ============================================
// LocalStorage Functions
// ============================================

const STORAGE_KEY = 'flutter_playstore_wizard_state';
const STORAGE_WARNING_KEY = 'flutter_playstore_wizard_security_warning_dismissed';

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
            state.totalSteps = currentTotalSteps;
            
            // OS는 항상 최신 값 사용 (저장된 값 무시)
            state.detectedOS = detectOS();

            // currentStep이 totalSteps를 초과하면 보정
            if (state.currentStep > state.totalSteps) {
                state.currentStep = state.totalSteps;
            }

            // maxReachedStep이 없거나 잘못된 경우 보정 (이전 버전 호환)
            if (!state.maxReachedStep || state.maxReachedStep < state.currentStep) {
                state.maxReachedStep = state.currentStep;
            }
            if (state.maxReachedStep > state.totalSteps) {
                state.maxReachedStep = state.totalSteps;
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
        'applicationId': state.applicationId,
        'keyAlias': state.keyAlias,
        'storePassword': state.storePassword,
        'keyPassword': state.keyPassword,
        'certCN': state.certCN,
        'certO': state.certO,
        'certL': state.certL,
        'certC': state.certC,
        'envFileContent': state.envFileContent
    };

    Object.entries(inputs).forEach(([id, value]) => {
        const el = document.getElementById(id);
        if (el && value) {
            el.value = value;
            // projectPath인 경우 검증 UI 업데이트
            if (id === 'projectPath') {
                updatePathValidation(value);
            }
        }
    });
    
    // Application ID 복원 (감지된 값 표시)
    if (state.applicationId) {
        const detectedContainer = document.getElementById('detectedApplicationIdContainer');
        const detectedValue = document.getElementById('detectedAppIdValue');
        if (detectedContainer && detectedValue) {
            detectedValue.textContent = state.applicationId;
            detectedContainer.classList.remove('hidden');
        }
    }
    
    // 유효기간 복원
    if (state.validityDays) {
        const validitySelect = document.getElementById('validityDays');
        const validityCustom = document.getElementById('validityDaysCustom');
        if (validitySelect) {
            // 저장된 값이 옵션에 있는지 확인
            const optionExists = Array.from(validitySelect.options).some(opt => opt.value === state.validityDays);
            if (optionExists) {
                validitySelect.value = state.validityDays;
            } else {
                // 사용자 지정 값인 경우
                validitySelect.value = 'custom';
                if (validityCustom) {
                    validityCustom.classList.remove('hidden');
                    validityCustom.value = state.validityDays;
                }
            }
        }
    }

    // 파일 업로드 상태 복원
    if (state.keystoreBase64) {
        const upload = document.getElementById('keystoreUpload');
        if (upload) {
            upload.classList.add('has-file');
            const p = upload.querySelector('p');
            if (p) p.textContent = '✅ Keystore 파일 로드됨';
        }
        const result = document.getElementById('keystoreBase64Result');
        if (result) {
            result.classList.remove('hidden');
            const pre = document.getElementById('keystoreBase64');
            if (pre) pre.textContent = state.keystoreBase64;
        }
    }

    if (state.serviceAccountBase64) {
        const upload = document.getElementById('serviceAccountUpload');
        if (upload) {
            upload.classList.add('has-file');
            const p = upload.querySelector('p');
            if (p) p.textContent = '✅ Service Account 파일 로드됨';
        }
    }

    // Project Info 복원
    if (state.applicationId) {
        const detected = document.getElementById('detectedInfo');
        if (detected) detected.classList.remove('hidden');
        setElementText('detectedAppId', state.applicationId);
        setElementText('detectedVersion', state.versionName);
        setElementText('detectedVersionCode', state.versionCode);
        setElementText('detectedGradleType', state.gradleType);
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

// Keystore 파일 업로드
async function handleKeystoreUpload(input) {
    const file = input.files[0];
    if (!file) return;

    if (!file.name.endsWith('.jks') && !file.name.endsWith('.keystore')) {
        showToast('⚠️ .jks 또는 .keystore 파일만 업로드 가능합니다');
        return;
    }

    try {
        state.keystoreBase64 = await fileToBase64(file);

        document.getElementById('keystoreBase64Result').classList.remove('hidden');
        document.getElementById('keystoreUpload').classList.add('has-file');
        document.getElementById('keystoreUpload').querySelector('p').textContent = `✅ ${file.name} (${(file.size/1024).toFixed(1)}KB)`;

        saveState();
        showToast('✅ Keystore 파일 업로드 완료');
    } catch (error) {
        showToast('❌ 파일 읽기 실패: ' + error.message);
    }
}

// Service Account JSON 업로드
async function handleServiceAccountUpload(input) {
    const file = input.files[0];
    if (!file) return;

    if (!file.name.endsWith('.json')) {
        showToast('⚠️ .json 파일만 업로드 가능합니다');
        return;
    }

    try {
        const reader = new FileReader();
        reader.onload = function(e) {
            state.serviceAccountBase64 = btoa(e.target.result);

            document.getElementById('serviceAccountUpload').classList.add('has-file');
            document.getElementById('serviceAccountUpload').querySelector('p').textContent = `✅ ${file.name}`;

            saveState();
            showToast('✅ Service Account 파일 업로드 완료');
        };
        reader.readAsText(file);
    } catch (error) {
        showToast('❌ 파일 읽기 실패: ' + error.message);
    }
}

// 서비스 계정 이메일 복사
function copyServiceAccountEmail() {
    const emailInput = document.getElementById('serviceAccountEmail');
    const email = emailInput ? emailInput.value : '';

    if (email) {
        navigator.clipboard.writeText(email).then(() => {
            showToast('📋 이메일이 복사되었습니다!');
        }).catch(() => {
            // Fallback for older browsers
            emailInput.select();
            document.execCommand('copy');
            showToast('📋 이메일이 복사되었습니다!');
        });
    } else {
        showToast('⚠️ 이메일을 먼저 입력하세요');
    }
}

// Step 3 이메일 입력 → Step 6 확인 팝업에 자동 반영
function updateStep6Email() {
    const emailInput = document.getElementById('serviceAccountEmail');
    const step6Display = document.getElementById('step6EmailDisplay');

    if (emailInput && step6Display) {
        const email = emailInput.value;
        if (email && email.length > 0) {
            // 이메일이 너무 길면 축약
            const displayEmail = email.length > 25 ? email.substring(0, 22) + '...' : email;
            step6Display.textContent = displayEmail;
        } else {
            step6Display.textContent = 'your-bot@project.iam...';
        }
    }
}

// Google Services JSON 업로드
function handleGoogleServicesUpload(input) {
    const file = input.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function(e) {
        state.googleServicesJson = e.target.result;
        document.getElementById('googleServicesResult').classList.remove('hidden');
        saveState();
        showToast('✅ google-services.json 업로드 완료');
    };
    reader.readAsText(file);
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
            const input = el.querySelector('input');
            if (input && e.dataTransfer.files.length > 0) {
                input.files = e.dataTransfer.files;
                input.dispatchEvent(new Event('change'));
            }
        });
    });
}

// ============================================
// Path Input & Validation
// ============================================

function copyPathCommand() {
    const os = state.detectedOS;
    let command = '';
    
    if (os === 'windows') {
        command = '(pwd).Path';
    } else {
        command = 'pwd';
    }
    
    navigator.clipboard.writeText(command).then(() => {
        showToast(`✅ "${command}" 명령어가 클립보드에 복사되었습니다!`);
    }).catch(() => {
        // Fallback
        const textarea = document.createElement('textarea');
        textarea.value = command;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast(`✅ "${command}" 명령어가 클립보드에 복사되었습니다!`);
    });
}

function validateProjectPath(path) {
    if (!path || path.trim() === '') {
        return { valid: false, message: '' };
    }
    
    // "선택된 폴더:"로 시작하는 경우 무시
    if (path.startsWith('선택된 폴더:')) {
        return { valid: false, message: '실제 절대 경로를 입력해주세요.' };
    }
    
    // 경로 형식 검증
    const isWindowsPath = /^[A-Za-z]:[\\/]/.test(path) || (path.includes('\\') && !path.startsWith('/'));
    const isUnixPath = path.startsWith('/');
    
    if (!isWindowsPath && !isUnixPath) {
        return { valid: false, message: '올바른 절대 경로 형식이 아닙니다. (예: /Users/... 또는 C:\\Users\\...)' };
    }
    
    return { valid: true, message: '' };
}

function updatePathValidation(path) {
    const validationDiv = document.getElementById('pathValidation');
    const validationMessage = document.getElementById('pathValidationMessage');
    
    if (!validationDiv || !validationMessage) return;
    
    const validation = validateProjectPath(path);
    
    if (!path || path.trim() === '') {
        validationDiv.classList.add('hidden');
        return;
    }
    
    validationDiv.classList.remove('hidden');
    
    if (validation.valid) {
        validationMessage.textContent = '✅ 올바른 경로 형식입니다.';
        validationMessage.className = 'text-xs text-green-400';
    } else {
        validationMessage.textContent = `⚠️ ${validation.message}`;
        validationMessage.className = 'text-xs text-yellow-400';
    }
}

function updateProjectCommands(path) {
    // 경로 저장 (유효한 경로만 저장)
    if (path && !path.startsWith('선택된 폴더:')) {
        const validation = validateProjectPath(path);
        if (validation.valid) {
            state.projectPath = path;

            // ✅ Application ID 자동 감지 명령어 생성
            generateApplicationIdDetectionCommand(path);
        }
    }

    // 경로 검증 UI 업데이트
    updatePathValidation(path);

    // OS에 맞는 명령어 업데이트
    updateCommandsForOS();
}

// ============================================
// OS별 명령어 업데이트
// ============================================

function updateCommandsForOS() {
    const os = state.detectedOS;
    let projectPath = state.projectPath || '/path/to/your/project';
    
    // 경로 정규화 (유효하지 않은 경로는 기본값 사용)
    if (!projectPath || projectPath.startsWith('선택된 폴더:')) {
        projectPath = '/path/to/your/project';
    }
    
    // 경로 검증
    const validation = validateProjectPath(projectPath);
    if (!validation.valid && projectPath !== '/path/to/your/project') {
        // 유효하지 않은 경로는 기본값 사용
        projectPath = '/path/to/your/project';
    }
    
    const macCommandEl = document.getElementById('macCommand');
    const windowsCommandEl = document.getElementById('windowsCommand');
    const macSection = macCommandEl?.closest('.mb-4');
    const windowsSection = windowsCommandEl?.closest('div:not(.mb-4)');
    
    if (os === 'windows') {
        // Windows만 표시
        if (macSection) macSection.style.display = 'none';
        if (windowsSection) windowsSection.style.display = 'block';
        
        // Windows 경로 변환
        let winPath = projectPath;
        if (!winPath.includes('\\') && !/^[A-Za-z]:/.test(winPath)) {
            // Unix 경로를 Windows 경로로 변환
            winPath = winPath.replace(/\//g, '\\');
            if (winPath.startsWith('\\')) {
                // /Users/... -> C:\Users\...
                winPath = 'C:' + winPath;
            }
        } else {
            // 이미 Windows 경로인 경우 정규화
            winPath = winPath.replace(/\//g, '\\');
        }
        
        if (windowsCommandEl) {
            windowsCommandEl.textContent = `cd "${winPath}"; powershell -ExecutionPolicy Bypass -File .github\\util\\flutter\\playstore-wizard\\playstore-wizard-setup.ps1`;
        }
        
        // Windows 사용자에게 관리자 권한 안내 표시
        const adminWarningEl = document.getElementById('adminWarningWindows');
        if (adminWarningEl) {
            adminWarningEl.classList.remove('hidden');
        }
    } else {
        // Mac/Linux에서는 관리자 권한 안내 숨김
        const adminWarningEl = document.getElementById('adminWarningWindows');
        if (adminWarningEl) {
            adminWarningEl.classList.add('hidden');
        }
        // Mac/Linux 표시
        if (macSection) macSection.style.display = 'block';
        if (windowsSection) windowsSection.style.display = 'none';
        
        // Unix 경로 변환 (Windows 경로가 입력된 경우)
        let unixPath = projectPath;
        if (unixPath.includes('\\') || /^[A-Za-z]:/.test(unixPath)) {
            // Windows 경로를 Unix 경로로 변환
            unixPath = unixPath.replace(/\\/g, '/').replace(/^([A-Za-z]):/, (_, drive) => '/' + drive.toLowerCase());
        }
        
        if (macCommandEl) {
            macCommandEl.textContent = `cd "${unixPath}" && bash .github/util/flutter/playstore-wizard/playstore-wizard-setup.sh`;
        }
    }
}

function updateOSBadge() {
    const osBadge = document.getElementById('osBadge');
    const osName = document.getElementById('osName');
    
    if (osBadge && osName) {
        const os = state.detectedOS;
        const osNames = {
            'windows': 'Windows',
            'mac': 'macOS',
            'linux': 'Linux'
        };
        const osColors = {
            'windows': 'text-blue-400',
            'mac': 'text-green-400',
            'linux': 'text-purple-400'
        };
        osName.textContent = osNames[os] || 'Unknown';
        osName.className = `font-bold ${osColors[os] || 'text-slate-400'}`;
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

function copySecret(name) {
    const value = state[name] || '';
    if (!value) {
        showToast('⚠️ 값이 비어있습니다');
        return;
    }

    navigator.clipboard.writeText(value).then(() => {
        showToast(`✅ ${name} 복사 완료!`);
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
        const label = indicator.querySelector('span:last-child');

        if (stepNum === state.currentStep) {
            // 현재 보고 있는 스텝 - 파랑-보라 그라데이션
            circle.className = 'step-circle w-8 h-8 rounded-full bg-gradient-to-r from-blue-500 to-purple-500 text-white flex items-center justify-center font-bold text-xs z-10 shadow-lg shadow-blue-500/30';
            circle.innerHTML = stepNum;
            if (label) label.className = 'text-[9px] mt-1 text-blue-400 text-center hidden md:block';
        } else if (stepNum <= state.maxReachedStep) {
            // 방문한 적 있는 스텝 - 초록 체크
            circle.className = 'step-circle w-8 h-8 rounded-full bg-green-500 text-white flex items-center justify-center font-bold text-xs z-10 shadow-lg';
            circle.innerHTML = '✓';
            if (label) label.className = 'text-[9px] mt-1 text-green-400 text-center hidden md:block';
        } else {
            // 아직 방문 안한 스텝 - 회색
            circle.className = 'step-circle w-8 h-8 rounded-full bg-slate-700 text-slate-400 flex items-center justify-center font-bold text-xs z-10';
            circle.innerHTML = stepNum;
            if (label) label.className = 'text-[9px] mt-1 text-slate-500 text-center hidden md:block';
        }

        // 클릭하여 해당 스텝으로 이동 가능
        indicator.style.cursor = 'pointer';
        indicator.onclick = () => goToStep(stepNum);
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
        case 1:
            // Step 1: 프로젝트 설정 (경로 + Application ID)
            // 프로젝트 경로 검증 UI 업데이트
            if (state.projectPath) {
                updatePathValidation(state.projectPath);
                // 프로젝트 경로가 있으면 자동으로 Application ID 감지 명령어 생성
                autoDetectApplicationIdOnPathInput();
            }

            // Application ID 복원
            if (state.applicationId) {
                const detectedContainer = document.getElementById('detectedApplicationIdContainer');
                const detectedValue = document.getElementById('detectedAppIdValue');
                if (detectedContainer && detectedValue) {
                    detectedValue.textContent = state.applicationId;
                    detectedContainer.classList.remove('hidden');
                }
                // 수동 입력 필드에도 채우기 (있는 경우)
                const applicationIdInput = document.getElementById('applicationId');
                if (applicationIdInput) {
                    applicationIdInput.value = state.applicationId;
                }
            }
            break;
        case 2:
            // Step 2: Keystore 생성
            restoreInputValues();
            // Application ID 기반으로 Key Alias 자동 생성
            if (state.applicationId && !state.keyAlias) {
                const suggestedAlias = state.applicationId.split('.').pop() + '-release-key';
                const aliasInput = document.getElementById('keyAlias');
                if (aliasInput && !aliasInput.value) {
                    aliasInput.value = suggestedAlias;
                    state.keyAlias = suggestedAlias;
                }
            }
            // 유효기간 드롭다운 초기화 확인
            const validitySelect = document.getElementById('validityDays');
            const validityCustom = document.getElementById('validityDaysCustom');
            if (validitySelect && !validitySelect.value) {
                validitySelect.value = '99999'; // 기본값: 무제한
            }
            if (validityCustom && validitySelect.value !== 'custom') {
                validityCustom.classList.add('hidden');
            }
            // Keystore 생성 명령어 자동 생성 (항상 실행)
            setTimeout(() => {
                generateKeystoreCreationCommand();
            }, 100);
            break;
        case 3:
            // Step 3: AAB 빌드
            // Windows 사용자에게 파일 잠금 안내 표시
            if (state.detectedOS === 'windows') {
                const fileLockErrorEl = document.getElementById('fileLockErrorWindows');
                if (fileLockErrorEl) {
                    fileLockErrorEl.classList.remove('hidden');
                }
            } else {
                const fileLockErrorEl = document.getElementById('fileLockErrorWindows');
                if (fileLockErrorEl) {
                    fileLockErrorEl.classList.add('hidden');
                }
            }
            
            // 프로젝트 경로 기반 AAB 빌드 명령어 생성
            if (state.projectPath) {
                const aabBuildCommand = document.getElementById('aabBuildCommandStep3');
                const aabOutputPath = document.getElementById('aabOutputPathStep3');
                const aabCheckCommand = document.getElementById('aabCheckCommand');
                const projectPath = state.projectPath;
                const os = state.detectedOS || 'mac';

                if (aabBuildCommand) {
                    if (os === 'windows') {
                        const winPath = projectPath.replace(/\//g, '\\');
                        // 각 명령어를 개별 라인으로 분리하여 순차 실행
                        // PowerShell에서 여러 줄 선택 후 실행 가능 (Shift+Enter 또는 선택 후 Enter)
                        // 각 명령어 전에 cd로 디렉토리 재설정하여 작업 디렉토리 보장
                        aabBuildCommand.textContent = `cd "${winPath}"
cd "${winPath}"; flutter clean
cd "${winPath}"; flutter pub get
cd "${winPath}"; flutter build appbundle --release`;
                    } else {
                        aabBuildCommand.textContent = `cd "${projectPath}" && flutter clean && flutter pub get && flutter build appbundle --release`;
                    }
                }
                if (aabOutputPath) {
                    if (os === 'windows') {
                        const winPath = projectPath.replace(/\//g, '\\');
                        aabOutputPath.textContent = `${winPath}\\build\\app\\outputs\\bundle\\release\\app-release.aab`;
                    } else {
                        aabOutputPath.textContent = `${projectPath}/build/app/outputs/bundle/release/app-release.aab`;
                    }
                }
                if (aabCheckCommand) {
                    if (os === 'windows') {
                        const winPath = projectPath.replace(/\//g, '\\');
                        aabCheckCommand.textContent = `dir "${winPath}\\build\\app\\outputs\\bundle\\release\\"`;
                    } else {
                        aabCheckCommand.textContent = `ls -lah "${projectPath}/build/app/outputs/bundle/release/"`;
                    }
                }
            }
            break;
        case 4:
            // Step 4: Play Console 앱 생성
            // Application ID에서 앱 이름 추출하여 표시
            if (state.applicationId) {
                const appName = state.applicationId.split('.').pop() || state.applicationId;
                // camelCase/snake_case를 읽기 좋게 변환 (suh_devops_template -> SuhDevopsTemplate)
                const formattedName = appName
                    .split(/[_-]/)
                    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
                    .join('');
                const appNameDisplay = document.getElementById('appNameDisplay');
                if (appNameDisplay) {
                    appNameDisplay.textContent = formattedName;
                }
            }
            break;
        case 5:
            // Step 5: AAB 수동 업로드
            // AAB 파일 경로 표시
            if (state.projectPath) {
                const aabUploadPath = document.getElementById('aabUploadPath');
                const projectPath = state.projectPath;
                if (aabUploadPath) {
                    const os = state.detectedOS || 'mac';
                    if (os === 'windows') {
                        const winPath = projectPath.replace(/\//g, '\\');
                        aabUploadPath.textContent = `${winPath}\\build\\app\\outputs\\bundle\\release\\app-release.aab`;
                    } else {
                        aabUploadPath.textContent = `${projectPath}/build/app/outputs/bundle/release/app-release.aab`;
                    }
                }
            }
            break;
        case 6:
            // Step 6: Service Account
            restoreInputValues();
            break;
        case 7:
            // Step 7: 완료
            generateFinalResult();
            break;
    }
}

function restoreInputValues() {
    const inputs = {
        'projectPath': state.projectPath,
        'keyAlias': state.keyAlias,
        'storePassword': state.storePassword,
        'keyPassword': state.keyPassword,
        'certCN': state.certCN,
        'certO': state.certO,
        'certL': state.certL,
        'certC': state.certC,
        'envFileContent': state.envFileContent
    };

    Object.entries(inputs).forEach(([id, value]) => {
        const el = document.getElementById(id);
        if (el && value) el.value = value;
    });
    
    // 유효기간 복원
    if (state.validityDays) {
        const validitySelect = document.getElementById('validityDays');
        const validityCustom = document.getElementById('validityDaysCustom');
        if (validitySelect) {
            // 저장된 값이 옵션에 있는지 확인
            const optionExists = Array.from(validitySelect.options).some(opt => opt.value === state.validityDays);
            if (optionExists) {
                validitySelect.value = state.validityDays;
                if (validityCustom) {
                    validityCustom.classList.add('hidden');
                }
            } else {
                // 사용자 지정 값인 경우
                validitySelect.value = 'custom';
                if (validityCustom) {
                    validityCustom.classList.remove('hidden');
                    validityCustom.value = state.validityDays;
                }
            }
        }
    }
}

function nextStep() {
    saveCurrentStepData();

    // Step 1에서 Step 2로 진행 시 Application ID 검증
    if (state.currentStep === 1) {
        const applicationId = state.applicationId;
        if (!applicationId || applicationId.trim() === '') {
            showToast('⚠️ Application ID를 먼저 감지하세요!\n\n1. 프로젝트 경로 입력\n2. 생성된 명령어를 터미널에서 실행\n3. 결과를 붙여넣고 "적용" 클릭');
            return;
        }

        // 프로젝트 경로 검증
        const projectPath = state.projectPath;
        if (!projectPath || projectPath.trim() === '') {
            showToast('⚠️ 프로젝트 경로를 먼저 입력하세요.');
            return;
        }
    }

    if (state.currentStep < state.totalSteps) {
        state.currentStep++;
        // 최대 도달 단계 갱신
        if (state.currentStep > state.maxReachedStep) {
            state.maxReachedStep = state.currentStep;
        }
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

function goToStep(stepNumber) {
    // 현재 단계와 같으면 무시
    if (stepNumber === state.currentStep) return;

    // 유효 범위 체크
    if (stepNumber >= 1 && stepNumber <= state.totalSteps) {
        saveCurrentStepData();
        state.currentStep = stepNumber;
        showStep(state.currentStep);
        updateProgress();
        saveState();
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

function resetWizard() {
    if (confirm('모든 데이터를 초기화하시겠습니까?\n\n모든 입력값과 localStorage가 완전히 삭제됩니다.')) {
        // State 초기화
        Object.keys(state).forEach(key => {
            if (key === 'currentStep') state[key] = 1;
            else if (key === 'maxReachedStep') state[key] = 1;
            else if (key === 'totalSteps') state[key] = 7;
            else if (key === 'certC') state[key] = 'KR';
            else if (key === 'gradleType') state[key] = 'kts';
            else if (key === 'validityDays') state[key] = '99999'; // 무제한 기본값
            else if (key === 'detectedOS') state[key] = detectOS(); // OS는 다시 감지
            else state[key] = '';
        });

        // localStorage 완전 삭제
        try {
            localStorage.removeItem(STORAGE_KEY);
            localStorage.removeItem(STORAGE_WARNING_KEY);
            // 모든 관련 키 삭제 (혹시 모를 경우 대비)
            Object.keys(localStorage).forEach(key => {
                if (key.startsWith('flutter_playstore_wizard')) {
                    localStorage.removeItem(key);
                }
            });
        } catch (e) {
            console.warn('localStorage 삭제 실패:', e);
        }

        // UI 초기화
        const inputs = ['projectPath', 'applicationId', 'keyAlias', 'storePassword', 'keyPassword', 'certCN', 'certO', 'certL', 'certC', 'envFileContent', 'scriptOutput'];
        inputs.forEach(id => {
            const input = document.getElementById(id);
            if (input) {
                if (id === 'certC') {
                    input.value = 'KR';
                } else {
                    input.value = '';
                }
            }
        });
        
        // Application ID 입력 필드 placeholder 복원
        const applicationIdInput = document.getElementById('applicationId');
        if (applicationIdInput) {
            applicationIdInput.placeholder = '예: com.example.app 또는 kr.suhsaechan.suh_devops_template';
        }
        
        // 유효기간 초기화
        const validitySelect = document.getElementById('validityDays');
        const validityCustom = document.getElementById('validityDaysCustom');
        if (validitySelect) {
            validitySelect.value = '99999'; // 무제한 기본값
        }
        if (validityCustom) {
            validityCustom.classList.add('hidden');
            validityCustom.value = '';
        }

        // 체크박스 초기화
        document.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
            checkbox.checked = false;
        });

        // 파일 업로드 상태 초기화
        document.querySelectorAll('.file-upload').forEach(el => {
            el.classList.remove('has-file');
            const p = el.querySelector('p');
            if (p && p.textContent.includes('✅')) {
                p.textContent = '클릭하거나 파일을 드래그하세요';
            }
        });

        // 결과 영역 숨기기
        document.querySelectorAll('[id$="Result"]').forEach(el => {
            el.classList.add('hidden');
        });
        
        // 감지된 정보 숨기기
        const detectedInfo = document.getElementById('detectedInfo');
        if (detectedInfo) {
            detectedInfo.classList.add('hidden');
        }

        // OS 배지 업데이트
        updateOSBadge();
        updateCommandsForOS();

        showStep(1);
        updateProgress();
        showToast('모든 설정이 초기화되었습니다.');
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

// ============================================
// Data Management Functions
// ============================================

function saveCurrentStepData() {
    switch (state.currentStep) {
        case 1:
            const path = getInputValue('projectPath');
            const validation = validateProjectPath(path);
            if (validation.valid) {
                state.projectPath = path;
            } else {
                state.projectPath = '';
            }
            // Application ID 저장 (감지된 값 또는 수동 입력 값)
            const detectedAppId = document.getElementById('detectedAppIdValue')?.textContent?.trim();
            const manualAppId = getInputValue('applicationId');
            if (detectedAppId) {
                state.applicationId = detectedAppId;
            } else if (manualAppId && manualAppId.trim() !== '') {
                state.applicationId = manualAppId.trim();
            }
            break;
        case 2:
            state.keyAlias = getInputValue('keyAlias');
            state.storePassword = getInputValue('storePassword');
            state.keyPassword = getInputValue('keyPassword');
            state.certCN = getInputValue('certCN');
            state.certO = getInputValue('certO');
            state.certL = getInputValue('certL');
            state.certC = getInputValue('certC') || 'KR';
            // 유효기간 저장
            const validitySelect = document.getElementById('validityDays');
            if (validitySelect) {
                const validityValue = validitySelect.value;
                if (validityValue === 'custom') {
                    const customValue = getInputValue('validityDaysCustom');
                    state.validityDays = customValue || '99999';
                } else {
                    state.validityDays = validityValue;
                }
            }
            break;
        case 5:
            state.envFileContent = getInputValue('envFileContent');
            break;
    }

    saveState();
}

// ============================================
// Command Generation Functions
// ============================================

function generateSetupCommand() {
    const projectPath = state.projectPath || '/path/to/project';
    const applicationId = state.applicationId || 'com.example.app';
    const keyAlias = state.keyAlias || 'release-key';
    const storePassword = state.storePassword || 'changeit';
    const keyPassword = state.keyPassword || storePassword;
    const validityDays = state.validityDays || '99999';
    const certCN = state.certCN || 'Unknown';
    const certO = state.certO || 'Unknown';
    const certL = state.certL || 'Unknown';
    const certC = state.certC || 'KR';

    const os = state.detectedOS;
    let cmd = '';

    if (os === 'windows') {
        // Windows PowerShell 명령어
        let winPath = projectPath;
        // Unix 경로를 Windows 경로로 변환
        if (!winPath.includes('\\') && !/^[A-Za-z]:/.test(winPath)) {
            winPath = winPath.replace(/\//g, '\\');
            if (winPath.startsWith('\\')) {
                winPath = 'C:' + winPath;
            }
        } else {
            winPath = winPath.replace(/\//g, '\\');
        }
        
        // PowerShell에서 특수문자 이스케이프 처리
        const escapePowerShell = (str) => {
            return str.replace(/"/g, '`"').replace(/\$/g, '`$');
        };
        
        cmd = `cd "${winPath}"; powershell -ExecutionPolicy Bypass -File .github\\util\\flutter\\playstore-wizard\\playstore-wizard-setup.ps1 "${escapePowerShell(winPath)}" "${escapePowerShell(applicationId)}" "${escapePowerShell(keyAlias)}" "${escapePowerShell(storePassword)}" "${escapePowerShell(keyPassword)}" "${validityDays}" "${escapePowerShell(certCN)}" "${escapePowerShell(certO)}" "${escapePowerShell(certL)}" "${certC}"`;
    } else {
        // Mac/Linux Bash 명령어
        // 특수문자 이스케이프 처리
        const escapeBash = (str) => {
            return str.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\$/g, '\\$');
        };
        
        cmd = `cd "${projectPath}" && bash .github/util/flutter/playstore-wizard/playstore-wizard-setup.sh "${escapeBash(projectPath)}" "${escapeBash(applicationId)}" "${escapeBash(keyAlias)}" "${escapeBash(storePassword)}" "${escapeBash(keyPassword)}" "${validityDays}" "${escapeBash(certCN)}" "${escapeBash(certO)}" "${escapeBash(certL)}" "${certC}"`;
    }

    const setupCmdEl = document.getElementById('setupCmd');
    if (setupCmdEl) {
        setupCmdEl.textContent = cmd;
    }
}

// ============================================
// Step 1: Application ID 자동 감지 (프로젝트 경로 입력 시 자동 실행)
// ============================================

function autoDetectApplicationIdOnPathInput() {
    const projectPath = getInputValue('projectPath');
    
    if (!projectPath || projectPath.trim() === '') {
        // 경로가 비어있으면 명령어 영역 숨기기
        const commandContainer = document.getElementById('detectAppIdCommandContainer');
        if (commandContainer) {
            const cmdEl = document.getElementById('detectAppIdCommand');
            if (cmdEl) {
                cmdEl.textContent = '프로젝트 경로를 입력하면 명령어가 여기에 표시됩니다...';
            }
        }
        return;
    }
    
    // 경로 검증
    const validation = validateProjectPath(projectPath);
    if (!validation.valid) {
        return;
    }
    
    // 자동으로 명령어 생성 및 표시
    generateApplicationIdDetectionCommand(projectPath);
}

function generateApplicationIdDetectionCommand(projectPath) {
    // OS 감지
    const os = state.detectedOS || detectOS();
    const isWindows = os === 'windows';
    
    // 명령어 생성
    let cmd = '';
    if (isWindows) {
        const winPath = projectPath.replace(/\//g, '\\');
        const escapePowerShell = (str) => {
            return str.replace(/"/g, '`"').replace(/\$/g, '`$');
        };
        cmd = `cd "${winPath}"; powershell -ExecutionPolicy Bypass -File .github\\util\\flutter\\playstore-wizard\\detect-application-id.ps1 "${escapePowerShell(winPath)}"`;
    } else {
        const escapeBash = (str) => {
            return str.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\$/g, '\\$');
        };
        cmd = `cd "${projectPath}" && bash .github/util/flutter/playstore-wizard/detect-application-id.sh "${escapeBash(projectPath)}"`;
    }
    
    // 명령어 표시
    const commandDisplay = document.getElementById('detectAppIdCommand');
    if (commandDisplay) {
        commandDisplay.textContent = cmd;
    }
    
    // 명령어 컨테이너 표시
    const commandContainer = document.getElementById('detectAppIdCommandContainer');
    if (commandContainer) {
        commandContainer.classList.remove('hidden');
    }
}

// 레거시 함수 (호환성 유지)
function detectApplicationId() {
    const projectPath = state.projectPath || getInputValue('projectPath');
    
    if (!projectPath || projectPath.trim() === '') {
        showToast('⚠️ 프로젝트 경로를 먼저 입력하세요.');
        return;
    }
    
    // 경로 검증
    const validation = validateProjectPath(projectPath);
    if (!validation.valid) {
        showToast('⚠️ 올바른 프로젝트 경로를 입력하세요.');
        return;
    }
    
    // 명령어 생성 및 표시
    generateApplicationIdDetectionCommand(projectPath);
    showToast('📋 아래 명령어를 복사하여 터미널에서 실행하세요. 결과를 붙여넣으면 자동으로 채워집니다.');
}

function parseDetectedApplicationId() {
    const resultText = getInputValue('detectAppIdResult');
    
    if (!resultText || resultText.trim() === '') {
        showToast('⚠️ 명령어 실행 결과를 붙여넣으세요.');
        return;
    }
    
    try {
        // JSON 파싱 시도
        let jsonData;
        try {
            jsonData = JSON.parse(resultText.trim());
        } catch (e) {
            // JSON이 아닌 경우, applicationId만 추출 시도
            const match = resultText.match(/["']?applicationId["']?\s*:\s*["']([^"']+)["']/i);
            if (match) {
                jsonData = { applicationId: match[1] };
            } else {
                throw new Error('JSON 형식이 아닙니다.');
            }
        }
        
        if (jsonData.applicationId) {
            // 상태에 저장
            state.applicationId = jsonData.applicationId;
            saveCurrentStepData();
            
            // 감지된 Application ID 표시
            const detectedContainer = document.getElementById('detectedApplicationIdContainer');
            const detectedValue = document.getElementById('detectedAppIdValue');
            if (detectedContainer && detectedValue) {
                detectedValue.textContent = jsonData.applicationId;
                detectedContainer.classList.remove('hidden');
            }
            
            // 수동 입력 필드에도 채우기 (있는 경우)
            const applicationIdInput = document.getElementById('applicationId');
            if (applicationIdInput) {
                applicationIdInput.value = jsonData.applicationId;
            }
            
            // 결과 입력 영역 초기화
            const resultArea = document.getElementById('detectAppIdResult');
            if (resultArea) {
                resultArea.value = '';
            }
            
            showToast('✅ Application ID가 자동으로 감지되었습니다: ' + jsonData.applicationId);
        } else {
            showToast('⚠️ applicationId를 찾을 수 없습니다.');
            // 수동 입력 옵션 표시
            const manualContainer = document.getElementById('manualApplicationIdContainer');
            if (manualContainer) {
                manualContainer.classList.remove('hidden');
            }
        }
    } catch (e) {
        showToast('⚠️ 결과 파싱 실패. JSON 형식을 확인하세요.');
        console.error('Parse error:', e);
        // 수동 입력 옵션 표시
        const manualContainer = document.getElementById('manualApplicationIdContainer');
        if (manualContainer) {
            manualContainer.classList.remove('hidden');
        }
    }
}

// ============================================
// Step 1: Parse Project Info (레거시 - 호환성 유지)
// ============================================

function parseProjectInfo() {
    const output = getInputValue('scriptOutput');

    if (!output) {
        // Manual entry fallback
        state.applicationId = 'com.example.app';
        state.versionName = '1.0.0';
        state.versionCode = '1';
        state.gradleType = 'kts';
    } else {
        try {
            const info = JSON.parse(output);
            state.applicationId = info.applicationId || 'com.example.app';
            state.versionName = info.versionName || '1.0.0';
            state.versionCode = info.versionCode?.toString() || '1';
            state.gradleType = info.gradleType || 'kts';
        } catch (e) {
            showToast('JSON 파싱 실패. 형식을 확인해주세요.');
            return;
        }
    }

    setElementText('detectedAppId', state.applicationId);
    setElementText('detectedVersion', state.versionName);
    setElementText('detectedVersionCode', state.versionCode);
    setElementText('detectedGradleType', state.gradleType);
    document.getElementById('detectedInfo').classList.remove('hidden');

    // Auto-generate key alias
    if (state.applicationId) {
        const suggestedAlias = state.applicationId.split('.').pop() + '-release-key';
        const aliasInput = document.getElementById('keyAlias');
        if (aliasInput && !aliasInput.value) {
            aliasInput.value = suggestedAlias;
            state.keyAlias = suggestedAlias;
        }
    }

    saveState();
    showToast('✅ 프로젝트 정보 파싱 완료');
}

// ============================================
// Step 2: Keystore 생성 명령어 생성 (완전 자동화)
// ============================================

function generateKeystoreCreationCommand() {
    const projectPath = state.projectPath || getInputValue('projectPath');
    const applicationId = state.applicationId || getInputValue('applicationId');
    const commandTextEl = document.getElementById('keystoreCreationCommandText');

    // 프로젝트 경로나 Application ID가 없으면 placeholder 표시
    if (!projectPath || projectPath.trim() === '') {
        if (commandTextEl) {
            commandTextEl.textContent = '⚠️ Step 1에서 프로젝트 경로를 먼저 입력하세요.';
        }
        return;
    }

    if (!applicationId || applicationId.trim() === '') {
        if (commandTextEl) {
            commandTextEl.textContent = '⚠️ Step 1에서 Application ID를 먼저 감지하세요.';
        }
        return;
    }
    
    // Keystore 정보 가져오기
    let keyAlias = getInputValue('keyAlias') || applicationId.split('.').pop() + '-release-key';
    let storePassword = getInputValue('storePassword') || 'changeit';
    let keyPassword = getInputValue('keyPassword') || storePassword;
    let validityDays = getInputValue('validityDays') || '99999';
    
    // 유효기간 커스텀 처리
    if (validityDays === 'custom') {
        const customValidity = getInputValue('validityDaysCustom');
        if (customValidity && parseInt(customValidity) > 0) {
            validityDays = customValidity;
        } else {
            validityDays = '99999';
        }
    }
    
    const certCN = getInputValue('certCN') || 'Unknown';
    const certO = getInputValue('certO') || 'Unknown';
    const certL = getInputValue('certL') || 'Unknown';
    const certC = getInputValue('certC') || 'KR';
    
    // OS 감지
    const os = state.detectedOS || detectOS();
    const isWindows = os === 'windows';
    
    // 명령어 생성
    let cmd = '';
    if (isWindows) {
        let winPath = projectPath.replace(/\//g, '\\');
        if (!winPath.match(/^[A-Z]:/)) {
            winPath = 'C:' + winPath;
        }
        
        const escapePowerShell = (str) => {
            return str.replace(/"/g, '`"').replace(/\$/g, '`$');
        };
        
        cmd = `cd "${winPath}"; powershell -ExecutionPolicy Bypass -File .github\\util\\flutter\\playstore-wizard\\playstore-wizard-setup.ps1 "${escapePowerShell(winPath)}" "${escapePowerShell(applicationId)}" "${escapePowerShell(keyAlias)}" "${escapePowerShell(storePassword)}" "${escapePowerShell(keyPassword)}" "${validityDays}" "${escapePowerShell(certCN)}" "${escapePowerShell(certO)}" "${escapePowerShell(certL)}" "${certC}"`;
    } else {
        const escapeBash = (str) => {
            return str.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\$/g, '\\$');
        };
        
        cmd = `cd "${projectPath}" && bash .github/util/flutter/playstore-wizard/playstore-wizard-setup.sh "${escapeBash(projectPath)}" "${escapeBash(applicationId)}" "${escapeBash(keyAlias)}" "${escapeBash(storePassword)}" "${escapeBash(keyPassword)}" "${validityDays}" "${escapeBash(certCN)}" "${escapeBash(certO)}" "${escapeBash(certL)}" "${certC}"`;
    }
    
    // 명령어 표시 (항상 보이므로 hidden 처리 불필요)
    if (commandTextEl) {
        commandTextEl.textContent = cmd;
    }
    
    // Key Alias 자동 채우기
    const keyAliasInput = document.getElementById('keyAlias');
    if (keyAliasInput && !keyAliasInput.value) {
        keyAliasInput.value = keyAlias;
        state.keyAlias = keyAlias;
    }
    
    // 입력값 저장
    state.storePassword = storePassword;
    state.keyPassword = keyPassword;
    state.validityDays = validityDays;
    state.certCN = certCN;
    state.certO = certO;
    state.certL = certL;
    state.certC = certC;
    saveCurrentStepData();
    
    // 토스트 없이 명령어만 표시
}

// ============================================
// Step 2: Keytool Command Generation (레거시 - 호환성 유지)
// ============================================

function generateKeytoolCommand() {
    // 레거시 함수 - 더 이상 사용하지 않지만 호환성을 위해 유지
    // 실제로는 generateKeystoreCreationCommand()를 사용
    showToast('💡 "Keystore 생성 명령어 생성" 버튼을 사용하세요.');
    generateKeystoreCreationCommand();
    return;
    
    // 아래 코드는 사용되지 않음 (호환성 유지)
    const alias = getInputValue('keyAlias') || 'release-key';
    const storePass = getInputValue('storePassword') || 'changeit';
    const keyPass = getInputValue('keyPassword') || storePass;
    
    // 유효기간 처리 (state에서 가져오거나 입력 필드에서 가져오기)
    let validity = state.validityDays || getInputValue('validityDays') || '99999';
    if (validity === 'custom') {
        // 사용자 지정 값 사용
        const customValidity = getInputValue('validityDaysCustom');
        if (customValidity && parseInt(customValidity) > 0) {
            validity = customValidity;
        } else {
            validity = '99999'; // 기본값으로 폴백
        }
    }

    const cn = getInputValue('certCN') || 'Unknown';
    const o = getInputValue('certO') || 'Unknown';
    const l = getInputValue('certL') || 'Unknown';
    const c = getInputValue('certC') || 'KR';

    state.keyAlias = alias;
    state.storePassword = storePass;
    state.keyPassword = keyPass;
    state.certCN = cn;
    state.certO = o;
    state.certL = l;
    state.certC = c;

    const dname = `CN=${cn}, O=${o}, L=${l}, C=${c}`;

    const command = `keytool -genkey -v \\
  -keystore release-key.jks \\
  -keyalg RSA \\
  -keysize 2048 \\
  -validity ${validity} \\
  -alias ${alias} \\
  -storepass "${storePass}" \\
  -keypass "${keyPass}" \\
  -dname "${dname}"`;

    setElementText('keytoolCommandText', command);
    document.getElementById('keytoolCommand').classList.remove('hidden');
    saveState();
}

// ============================================
// Step 4: Fastlane Content Generation
// ============================================

function generateFastfileContent() {
    const appId = state.applicationId || 'com.example.app';

    const fastfile = `# Play Store 내부 테스트 배포용 Fastfile
# 경로: android/fastlane/Fastfile.playstore

default_platform(:android)

platform :android do
  desc "Play Store 내부 테스트로 배포"
  lane :deploy_internal do
    # 환경 변수
    aab_path = ENV["AAB_PATH"] || "../build/app/outputs/bundle/release/app-release.aab"
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"

    puts "========================================="
    puts "Play Store 내부 테스트 배포 시작"
    puts "========================================="
    puts "AAB 경로: #{aab_path}"
    puts "Service Account: #{json_key}"

    # AAB 파일 확인
    unless File.exist?(aab_path)
      UI.user_error!("AAB 파일을 찾을 수 없습니다: #{aab_path}")
    end

    # Service Account 확인
    unless File.exist?(json_key)
      UI.user_error!("Service Account JSON을 찾을 수 없습니다: #{json_key}")
    end

    # Play Store 업로드
    upload_to_play_store(
      package_name: "${appId}",
      track: "internal",
      aab: aab_path,
      json_key: json_key,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      release_status: "completed"
    )

    puts ""
    puts "========================================="
    puts "내부 테스트 배포 성공!"
    puts "========================================="
  end

  desc "Service Account JSON 검증"
  lane :validate do
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"

    validate_play_store_json_key(
      json_key: json_key
    )

    puts "Service Account 검증 성공!"
  end
end`;

    setElementText('fastfileContent', fastfile);
}

// ============================================
// Step 7: 완료 및 GitHub Secrets 목록 생성
// ============================================

function generateFinalResult() {
    const secrets = [
        { key: 'RELEASE_KEYSTORE_BASE64', value: state.keystoreBase64, desc: 'Keystore 파일 (Base64)' },
        { key: 'RELEASE_KEYSTORE_PASSWORD', value: state.storePassword, desc: 'Keystore 비밀번호' },
        { key: 'RELEASE_KEY_ALIAS', value: state.keyAlias, desc: '키 별칭' },
        { key: 'RELEASE_KEY_PASSWORD', value: state.keyPassword, desc: '키 비밀번호' },
        { key: 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64', value: state.serviceAccountBase64, desc: 'Service Account (Base64)' },
        { key: 'GOOGLE_SERVICES_JSON', value: state.googleServicesJson, desc: 'Firebase 설정 (선택)' },
        { key: 'ENV_FILE', value: state.envFileContent, desc: '환경 변수 (선택)' }
    ];

    const tbody = document.getElementById('secretsTableBody');
    if (!tbody) return;

    tbody.innerHTML = secrets.map(s => {
        const hasValue = !!s.value;
        return `
            <tr>
                <td class="px-4 py-3">
                    <code class="text-blue-400">${s.key}</code>
                    <p class="text-xs text-slate-500 mt-1">${s.desc}</p>
                </td>
                <td class="px-4 py-3">
                    <span class="${hasValue ? 'text-green-400' : 'text-red-400'}">
                        ${hasValue ? '✓ 설정됨' : '✗ 미설정'}
                    </span>
                </td>
                <td class="px-4 py-3 text-right">
                    <button
                        class="px-3 py-1 ${hasValue ? 'bg-blue-600 hover:bg-blue-700' : 'bg-slate-700 cursor-not-allowed'} rounded text-xs transition"
                        onclick="copySecretValue('${s.key}')"
                        ${!hasValue ? 'disabled' : ''}>
                        복사
                    </button>
                </td>
            </tr>
        `;
    }).join('');

    // Generate .env file content
    generateEnvFileContent();
}

function generateEnvFileContent() {
    const envContent = `# ============================================
# Android Play Store 배포 설정
# ============================================

# Application ID
ANDROID_APPLICATION_ID=${state.applicationId || 'com.example.app'}

# Keystore 정보 (로컬 개발용)
ANDROID_KEY_ALIAS=${state.keyAlias || 'release-key'}
ANDROID_STORE_PASSWORD=${state.storePassword || 'YOUR_STORE_PASSWORD'}
ANDROID_KEY_PASSWORD=${state.keyPassword || 'YOUR_KEY_PASSWORD'}
ANDROID_KEYSTORE_PATH=android/app/keystore/key.jks

# 인증서 정보
ANDROID_CERT_CN=${state.certCN || 'Your Name'}
ANDROID_CERT_O=${state.certO || 'Your Organization'}
ANDROID_CERT_L=${state.certL || 'Your City'}
ANDROID_CERT_C=${state.certC || 'KR'}

# GitHub Secrets 정보 (참고용 - 실제로는 GitHub에 직접 등록)
# RELEASE_KEYSTORE_BASE64=<keystore file을 base64로 인코딩한 값>
# RELEASE_KEYSTORE_PASSWORD=${state.storePassword || 'YOUR_STORE_PASSWORD'}
# RELEASE_KEY_ALIAS=${state.keyAlias || 'release-key'}
# RELEASE_KEY_PASSWORD=${state.keyPassword || 'YOUR_KEY_PASSWORD'}
# GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64=<service account JSON을 base64로 인코딩한 값>
`;

    setElementText('envFileContent', envContent);
}

function copySecretValue(key) {
    const mapping = {
        'RELEASE_KEYSTORE_BASE64': state.keystoreBase64,
        'RELEASE_KEYSTORE_PASSWORD': state.storePassword,
        'RELEASE_KEY_ALIAS': state.keyAlias,
        'RELEASE_KEY_PASSWORD': state.keyPassword,
        'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64': state.serviceAccountBase64,
        'GOOGLE_SERVICES_JSON': state.googleServicesJson,
        'ENV_FILE': state.envFileContent
    };

    const value = mapping[key];
    if (!value) {
        showToast('⚠️ 값이 비어있습니다');
        return;
    }

    navigator.clipboard.writeText(value).then(() => {
        showToast(`✅ ${key} 복사 완료!`);
    });
}

// ============================================
// Copy All Secrets to Clipboard
// ============================================

function copyAllSecrets() {
    const secrets = [
        { key: 'RELEASE_KEYSTORE_BASE64', value: state.keystoreBase64 },
        { key: 'RELEASE_KEYSTORE_PASSWORD', value: state.storePassword },
        { key: 'RELEASE_KEY_ALIAS', value: state.keyAlias },
        { key: 'RELEASE_KEY_PASSWORD', value: state.keyPassword },
        { key: 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64', value: state.serviceAccountBase64 },
        { key: 'GOOGLE_SERVICES_JSON', value: state.googleServicesJson },
        { key: 'ENV_FILE', value: state.envFileContent }
    ];

    // 설정된 값만 필터링
    const configuredSecrets = secrets.filter(s => s.value);

    if (configuredSecrets.length === 0) {
        showToast('⚠️ 복사할 설정값이 없습니다');
        return;
    }

    const lines = [
        '===== GitHub Secrets for Play Store =====',
        `생성일: ${new Date().toLocaleString('ko-KR')}`,
        `Application ID: ${state.applicationId || '(미설정)'}`,
        '',
        ...configuredSecrets.map(s => `${s.key}=${s.value}`),
        '',
        '========================================='
    ];

    const text = lines.join('\n');

    navigator.clipboard.writeText(text).then(() => {
        showToast(`✅ ${configuredSecrets.length}개 Secret 전체 복사 완료!`);
    }).catch(() => {
        showToast('❌ 클립보드 복사 실패');
    });
}

// ============================================
// Download Functions
// ============================================

function downloadAsJson() {
    const secrets = {
        RELEASE_KEYSTORE_BASE64: state.keystoreBase64,
        RELEASE_KEYSTORE_PASSWORD: state.storePassword,
        RELEASE_KEY_ALIAS: state.keyAlias,
        RELEASE_KEY_PASSWORD: state.keyPassword,
        GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64: state.serviceAccountBase64,
        GOOGLE_SERVICES_JSON: state.googleServicesJson,
        ENV_FILE: state.envFileContent
    };

    const jsonStr = JSON.stringify(secrets, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-secrets-playstore.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ JSON 파일 다운로드 완료!');
}

function downloadAsTxt() {
    const lines = [
        '# GitHub Secrets for Play Store Deployment',
        '# 생성일: ' + new Date().toLocaleString('ko-KR'),
        '',
        '===== GitHub Repository Secrets =====',
        '',
        'RELEASE_KEYSTORE_BASE64:',
        state.keystoreBase64 || '(미입력)',
        '',
        'RELEASE_KEYSTORE_PASSWORD:',
        state.storePassword || '(미입력)',
        '',
        'RELEASE_KEY_ALIAS:',
        state.keyAlias || '(미입력)',
        '',
        'RELEASE_KEY_PASSWORD:',
        state.keyPassword || '(미입력)',
        '',
        'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64:',
        state.serviceAccountBase64 || '(미입력)',
        '',
        'GOOGLE_SERVICES_JSON:',
        state.googleServicesJson ? '[설정됨]' : '(미입력)',
        '',
        'ENV_FILE:',
        state.envFileContent || '(미입력)',
        '',
        '====================================='
    ];

    const txtStr = lines.join('\n');
    const blob = new Blob([txtStr], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'github-secrets-playstore.txt';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ TXT 파일 다운로드 완료!');
}

function downloadConfig() {
    const config = {
        projectInfo: {
            applicationId: state.applicationId,
            versionName: state.versionName,
            versionCode: state.versionCode,
            gradleType: state.gradleType
        },
        generatedAt: new Date().toISOString(),
        secrets: {
            RELEASE_KEYSTORE_BASE64: state.keystoreBase64 ? '[설정됨]' : null,
            RELEASE_KEYSTORE_PASSWORD: state.storePassword ? '[설정됨]' : null,
            RELEASE_KEY_ALIAS: state.keyAlias || null,
            RELEASE_KEY_PASSWORD: state.keyPassword ? '[설정됨]' : null,
            GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64: state.serviceAccountBase64 ? '[설정됨]' : null
        }
    };

    const blob = new Blob([JSON.stringify(config, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'playstore-cicd-config.json';
    a.click();
    URL.revokeObjectURL(url);
    showToast('✅ 설정 JSON 다운로드 완료!');
}

// ============================================
// ZIP Export Functions
// ============================================

function getDateString() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

function generateReadme() {
    return `# Play Store 배포 설정 백업

생성일: ${new Date().toLocaleString('ko-KR')}
Application ID: ${state.applicationId || '(미설정)'}

## 📁 파일 구조

\`\`\`
├── release-key.jks          # Android 서명 키스토어 (Base64 디코딩됨)
├── service-account.json     # Google Play Service Account (Base64 디코딩됨)
├── github-secrets/          # GitHub Secrets용 값들
│   ├── RELEASE_KEYSTORE_BASE64.txt
│   ├── RELEASE_KEYSTORE_PASSWORD.txt
│   ├── RELEASE_KEY_ALIAS.txt
│   ├── RELEASE_KEY_PASSWORD.txt
│   └── GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64.txt
└── README.md
\`\`\`

## 🔐 GitHub Secrets 등록 방법

1. GitHub 저장소 → Settings → Secrets and variables → Actions
2. \`github-secrets/\` 폴더 내 각 파일의 내용을 Secret으로 등록
3. Secret 이름은 파일명에서 .txt를 제외한 이름 사용

## ⚠️ 주의사항

- 이 파일들에는 민감한 정보가 포함되어 있습니다
- 안전한 장소에 보관하고, Git에 커밋하지 마세요
- 필요한 경우 암호화하여 보관하세요
`;
}

async function downloadAsZip() {
    // JSZip 로드 확인
    if (typeof JSZip === 'undefined') {
        showToast('❌ ZIP 라이브러리 로드 실패. 페이지를 새로고침해주세요.');
        return;
    }

    const zip = new JSZip();

    // 1. 실제 파일들 (Base64 디코딩)
    if (state.keystoreBase64) {
        try {
            const binaryString = atob(state.keystoreBase64);
            const bytes = new Uint8Array(binaryString.length);
            for (let i = 0; i < binaryString.length; i++) {
                bytes[i] = binaryString.charCodeAt(i);
            }
            zip.file("release-key.jks", bytes);
        } catch (e) {
            console.error('Keystore 디코딩 실패:', e);
        }
    }

    if (state.serviceAccountBase64) {
        try {
            const jsonContent = atob(state.serviceAccountBase64);
            zip.file("service-account.json", jsonContent);
        } catch (e) {
            console.error('Service Account 디코딩 실패:', e);
        }
    }

    // 2. 개별 Secret TXT 파일들 (github-secrets 폴더에)
    const secrets = [
        { name: 'RELEASE_KEYSTORE_BASE64.txt', value: state.keystoreBase64 },
        { name: 'RELEASE_KEYSTORE_PASSWORD.txt', value: state.storePassword },
        { name: 'RELEASE_KEY_ALIAS.txt', value: state.keyAlias },
        { name: 'RELEASE_KEY_PASSWORD.txt', value: state.keyPassword },
        { name: 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64.txt', value: state.serviceAccountBase64 },
        { name: 'GOOGLE_SERVICES_JSON.txt', value: state.googleServicesJson },
        { name: 'ENV_FILE.txt', value: state.envFileContent }
    ];

    const secretsFolder = zip.folder("github-secrets");
    let fileCount = 0;
    secrets.forEach(s => {
        if (s.value) {
            secretsFolder.file(s.name, s.value);
            fileCount++;
        }
    });

    // 파일이 하나도 없으면 경고
    if (fileCount === 0) {
        showToast('⚠️ 내보낼 설정값이 없습니다');
        return;
    }

    // 3. README.md 생성
    const readme = generateReadme();
    zip.file("README.md", readme);

    // 4. ZIP 다운로드
    try {
        const content = await zip.generateAsync({ type: "blob" });
        const url = URL.createObjectURL(content);
        const a = document.createElement('a');
        a.href = url;
        const appId = state.applicationId ? state.applicationId.replace(/\./g, '-') : 'app';
        a.download = `playstore-secrets-${appId}-${getDateString()}.zip`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        showToast(`✅ ZIP 파일 다운로드 완료! (${fileCount}개 설정 포함)`);
    } catch (e) {
        console.error('ZIP 생성 실패:', e);
        showToast('❌ ZIP 파일 생성 실패');
    }
}

// ============================================
// Import from JSON
// ============================================

function importFromJson(event) {
    const file = event.target.files[0];
    if (!file) return;

    // 파일 확장자 확인
    if (!file.name.endsWith('.json')) {
        showToast('❌ JSON 파일만 업로드 가능합니다');
        event.target.value = '';
        return;
    }

    const reader = new FileReader();

    reader.onload = function(e) {
        try {
            const data = JSON.parse(e.target.result);

            // 유효성 검사 - 적어도 하나의 알려진 키가 있어야 함
            const knownKeys = [
                'RELEASE_KEYSTORE_BASE64',
                'RELEASE_KEYSTORE_PASSWORD',
                'RELEASE_KEY_ALIAS',
                'RELEASE_KEY_PASSWORD',
                'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64',
                'GOOGLE_SERVICES_JSON',
                'ENV_FILE'
            ];

            const hasValidKey = knownKeys.some(key => key in data);
            if (!hasValidKey) {
                showToast('❌ 올바른 PlayStore Secrets JSON 파일이 아닙니다');
                event.target.value = '';
                return;
            }

            // State에 값 매핑
            let importedCount = 0;

            if (data.RELEASE_KEYSTORE_BASE64) {
                state.keystoreBase64 = data.RELEASE_KEYSTORE_BASE64;
                importedCount++;
            }
            if (data.RELEASE_KEYSTORE_PASSWORD) {
                state.storePassword = data.RELEASE_KEYSTORE_PASSWORD;
                importedCount++;
            }
            if (data.RELEASE_KEY_ALIAS) {
                state.keyAlias = data.RELEASE_KEY_ALIAS;
                importedCount++;
            }
            if (data.RELEASE_KEY_PASSWORD) {
                state.keyPassword = data.RELEASE_KEY_PASSWORD;
                importedCount++;
            }
            if (data.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64) {
                state.serviceAccountBase64 = data.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64;
                importedCount++;
            }
            if (data.GOOGLE_SERVICES_JSON) {
                state.googleServicesJson = data.GOOGLE_SERVICES_JSON;
                importedCount++;
            }
            if (data.ENV_FILE) {
                state.envFileContent = data.ENV_FILE;
                importedCount++;
            }

            // LocalStorage에 저장
            saveState();

            // 테이블 갱신
            generateFinalResult();

            showToast(`✅ ${importedCount}개 설정값 가져오기 완료!`);

        } catch (error) {
            console.error('JSON 파싱 오류:', error);
            showToast('❌ JSON 파일 읽기 실패: 형식이 올바르지 않습니다');
        }

        // 파일 입력 초기화 (같은 파일 다시 선택 가능하도록)
        event.target.value = '';
    };

    reader.onerror = function() {
        showToast('❌ 파일 읽기 오류');
        event.target.value = '';
    };

    reader.readAsText(file);
}

// ============================================
// Changelog Modal Functions
// ============================================

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

    // Build changelog HTML
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

// ============================================
// Input Event Handlers
// ============================================

function setupInputHandlers() {
    // ESC 키로 모달 닫기
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeChangelogModal();
        }
    });

    // 입력 필드 변경 시 저장
    const inputIds = ['projectPath', 'keyAlias', 'storePassword', 'keyPassword', 'certCN', 'certO', 'certL', 'certC', 'envFileContent', 'scriptOutput'];
    inputIds.forEach(id => {
        const input = document.getElementById(id);
        if (input) {
            input.addEventListener('change', saveCurrentStepData);
            input.addEventListener('blur', saveCurrentStepData);
        }
    });
    
    // 유효기간 드롭다운 처리
    const validitySelect = document.getElementById('validityDays');
    const validityCustom = document.getElementById('validityDaysCustom');
    if (validitySelect && validityCustom) {
        validitySelect.addEventListener('change', function() {
            if (this.value === 'custom') {
                validityCustom.classList.remove('hidden');
                validityCustom.focus();
            } else {
                validityCustom.classList.add('hidden');
            }
            saveCurrentStepData();
        });
        
        validityCustom.addEventListener('input', saveCurrentStepData);
        validityCustom.addEventListener('blur', saveCurrentStepData);
    }

    // projectPath 입력 시 실시간 검증 및 Application ID 감지 명령어 자동 생성
    const projectPathInput = document.getElementById('projectPath');
    if (projectPathInput) {
        projectPathInput.addEventListener('input', function() {
            const path = this.value.trim();
            updateProjectCommands(path);
            // Application ID 자동 감지 명령어 생성
            autoDetectApplicationIdOnPathInput();
            saveCurrentStepData();
        });

        projectPathInput.addEventListener('blur', function() {
            const path = this.value.trim();
            updateProjectCommands(path);
            // Application ID 자동 감지 명령어 생성
            autoDetectApplicationIdOnPathInput();
            saveCurrentStepData();
        });

        projectPathInput.addEventListener('paste', function(e) {
            // 붙여넣기 후 검증
            setTimeout(() => {
                const path = this.value.trim();
                updateProjectCommands(path);
                // Application ID 자동 감지 명령어 생성
                autoDetectApplicationIdOnPathInput();
                saveCurrentStepData();
            }, 10);
        });
    }
    
    // applicationId 입력 시 저장 및 자동 감지 명령어 업데이트
    const applicationIdInput = document.getElementById('applicationId');
    if (applicationIdInput) {
        applicationIdInput.addEventListener('input', () => {
            saveCurrentStepData();
            // 자동 감지 명령어 컨테이너가 보이면 명령어 업데이트
            const detectContainer = document.getElementById('detectAppIdCommandContainer');
            if (detectContainer && !detectContainer.classList.contains('hidden')) {
                detectApplicationId();
            }
        });
        applicationIdInput.addEventListener('blur', saveCurrentStepData);
    }
    
    // Step 2: Keystore 정보 입력 시 자동으로 명령어 생성
    const keystoreInputs = ['keyAlias', 'storePassword', 'keyPassword', 'validityDays', 'certCN', 'certO', 'certL', 'certC'];
    keystoreInputs.forEach(inputId => {
        const input = document.getElementById(inputId);
        if (input) {
            input.addEventListener('input', () => {
                saveCurrentStepData();
                // Step 2에 있을 때 명령어 자동 업데이트
                if (state.currentStep === 2) {
                    generateKeystoreCreationCommand();
                }
            });
            input.addEventListener('change', () => {
                saveCurrentStepData();
                if (state.currentStep === 2) {
                    generateKeystoreCreationCommand();
                }
            });
        }
    });
    
    // 유효기간 커스텀 입력 필드
    const validityCustomInput = document.getElementById('validityDaysCustom');
    if (validityCustomInput) {
        validityCustomInput.addEventListener('input', () => {
            saveCurrentStepData();
            if (state.currentStep === 2) {
                generateKeystoreCreationCommand();
            }
        });
    }
}

// ============================================
// Initialization
// ============================================

function initialize() {
    // OS 감지
    state.detectedOS = detectOS();
    
    // 저장된 상태 로드
    const hasState = loadState();
    
    // OS는 항상 최신 값 사용
    state.detectedOS = detectOS();

    if (hasState) {
        showStep(state.currentStep);
        updateProgress();
        showToast('이전 진행 상태를 복원했습니다');
    } else {
        showStep(1);
        updateProgress();
    }

    // OS 배지 및 명령어 업데이트
    updateOSBadge();
    updateCommandsForOS();
    
    // 저장된 경로가 있으면 검증 UI 업데이트
    if (state.projectPath) {
        updatePathValidation(state.projectPath);
    }

    setupInputHandlers();
    setupDragAndDrop();
    showSecurityWarning();

    // 버전 배지 업데이트
    const data = getVersionData();
    if (data && data.version) {
        const versionBadge = document.getElementById('versionBadge');
        if (versionBadge) {
            versionBadge.textContent = `v${data.version}`;
        }
    }
}

// DOM 로드 완료 시 초기화
document.addEventListener('DOMContentLoaded', initialize);

// 페이지 언로드 시 경고 (데이터 손실 방지)
window.addEventListener('beforeunload', (e) => {
    if (state.currentStep > 1 || state.keystoreBase64 || state.serviceAccountBase64) {
        e.preventDefault();
        e.returnValue = '입력한 데이터가 사라질 수 있습니다. 정말 나가시겠습니까?';
    }
});
