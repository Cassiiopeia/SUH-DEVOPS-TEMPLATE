/**
 * Firebase App Distribution Wizard
 * 정적 HTML/JS 마법사 - GitHub API 호출 안 함
 */

// ============================================
// OS Detection
// ============================================
let detectedOS = 'mac';
function detectOS() {
    const ua = navigator.userAgent || navigator.appVersion || navigator.platform;
    if (/Win/i.test(ua)) return 'windows';
    if (/Mac/i.test(ua)) return 'mac';
    if (/Linux/i.test(ua)) return 'linux';
    return 'mac';
}

// ============================================
// State
// ============================================
const state = {
    currentStep: 1,
    maxReachedStep: 1,
    totalSteps: 5,
    detectedOS: 'mac',
    // Step 3
    firebaseAppId: '',
    firebaseTesterGroup: '',
    projectPath: '.',
    // Step 4
    serviceAccountBase64: '',
    serviceAccountFileName: '',
    googleServicesJson: '',
    googleServicesFileName: '',
    // Step 5
    repoOwner: '',
    repoName: '',
    // Custom Secrets
    customSecrets: []
};

const STORAGE_KEY = 'firebase_wizard_state';

function saveState() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }
    catch (e) { console.warn('localStorage save failed:', e); }
}

function loadState() {
    try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
            const s = JSON.parse(saved);
            const total = state.totalSteps;
            Object.assign(state, s);
            state.totalSteps = total;
            state.detectedOS = detectOS();
            if (state.currentStep > state.totalSteps) state.currentStep = state.totalSteps;
            if (!state.maxReachedStep || state.maxReachedStep < state.currentStep) state.maxReachedStep = state.currentStep;
            if (state.maxReachedStep > state.totalSteps) state.maxReachedStep = state.totalSteps;
            return true;
        }
    } catch (e) { console.warn('localStorage load failed:', e); }
    return false;
}

function clearState() {
    try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
}

// ============================================
// Helpers
// ============================================
function $(sel) { return document.querySelector(sel); }
function $$(sel) { return document.querySelectorAll(sel); }
function getInputValue(id) { const el = document.getElementById(id); return el ? el.value : ''; }

function fileToBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
            const r = reader.result;
            const b64 = r.includes(',') ? r.split(',')[1] : r;
            resolve(b64);
        };
        reader.onerror = (e) => reject(e);
        reader.readAsDataURL(file);
    });
}

async function fileToText(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = (e) => reject(e);
        reader.readAsText(file, 'utf-8');
    });
}

// ============================================
// Toast / Copy
// ============================================
function showToast(message) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 2500);
}

async function copyToClipboard(text) {
    try {
        await navigator.clipboard.writeText(text);
        showToast('✅ 복사되었습니다');
    } catch (e) {
        const ta = document.createElement('textarea');
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        showToast('✅ 복사되었습니다');
    }
}

function copyCode(button) {
    const target = button.previousElementSibling;
    const text = target ? target.textContent : '';
    if (!text) { showToast('⚠️ 복사할 내용이 없습니다'); return; }
    copyToClipboard(text);
}

function copySecret(name) {
    const map = {
        'FIREBASE_SERVICE_ACCOUNT_JSON_BASE64': state.serviceAccountBase64,
        'GOOGLE_SERVICES_JSON': state.googleServicesJson
    };
    const value = map[name] || '';
    if (!value) { showToast(`⚠️ ${name} 값이 비어있습니다`); return; }
    copyToClipboard(value);
}

// ============================================
// Navigation
// ============================================
function updateStepIndicator() {
    const dots = $$('.step-dot');
    dots.forEach(dot => {
        const step = parseInt(dot.dataset.step);
        dot.classList.remove('active', 'completed', 'pending');
        if (step === state.currentStep) dot.classList.add('active');
        else if (step < state.currentStep) dot.classList.add('completed');
        else dot.classList.add('pending');
    });
    const lines = $$('.step-line');
    lines.forEach((line, i) => {
        if (i + 1 < state.currentStep) line.classList.add('completed');
        else line.classList.remove('completed');
    });
}

function showStep(step) {
    state.currentStep = step;
    if (step > state.maxReachedStep) state.maxReachedStep = step;
    $$('.step-content').forEach(el => {
        el.classList.toggle('hidden', parseInt(el.dataset.step) !== step);
        el.classList.add('fade-in');
    });
    updateStepIndicator();
    saveState();
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function nextStep() {
    if (state.currentStep < state.totalSteps) showStep(state.currentStep + 1);
}

function prevStep() {
    if (state.currentStep > 1) showStep(state.currentStep - 1);
}

function goToStep(step) {
    if (step <= state.maxReachedStep) showStep(step);
    else showToast('⚠️ 이전 단계를 먼저 완료해주세요');
}

function resetWizard() {
    if (!confirm('모든 입력 정보를 초기화할까요?')) return;
    clearState();
    Object.assign(state, {
        currentStep: 1, maxReachedStep: 1, totalSteps: 5, detectedOS: detectOS(),
        firebaseAppId: '', firebaseTesterGroup: '', projectPath: '.',
        serviceAccountBase64: '', serviceAccountFileName: '',
        googleServicesJson: '', googleServicesFileName: '',
        repoOwner: '', repoName: '', customSecrets: []
    });
    showStep(1);
    showToast('🔄 초기화되었습니다');
}

// ============================================
// Step 3: APP_ID / TESTER_GROUP / OS Tab
// ============================================
function shellEscape(s) {
    return (s || '').replace(/"/g, '\\"');
}

function updateSetupCommands() {
    const path = state.projectPath || '.';
    const appId = shellEscape(state.firebaseAppId);
    const tester = shellEscape(state.firebaseTesterGroup);

    const bashCmd = `./firebase-wizard-setup.sh --project-path ${path} --app-id "${appId}" --tester-group "${tester}"`;
    const psPath = (path === '.') ? '.' : path.replace(/\//g, '\\');
    const psCmd = `.\\firebase-wizard-setup.ps1 -ProjectPath ${psPath} -AppId "${appId}" -TesterGroup "${tester}"`;

    const bashEl = document.getElementById('cmdBashCode');
    const psEl = document.getElementById('cmdPsCode');
    if (bashEl) bashEl.textContent = bashCmd;
    if (psEl) psEl.textContent = psCmd;
}

function selectOsTab(which) {
    const bash = document.getElementById('osCmdBash');
    const ps = document.getElementById('osCmdPs');
    const tabBash = document.getElementById('osTabBash');
    const tabPs = document.getElementById('osTabPs');
    if (which === 'bash') {
        bash.classList.remove('hidden');
        ps.classList.add('hidden');
        tabBash.classList.add('bg-firebase-primary', 'text-slate-900');
        tabPs.classList.remove('bg-firebase-primary', 'text-slate-900');
    } else {
        ps.classList.remove('hidden');
        bash.classList.add('hidden');
        tabPs.classList.add('bg-firebase-primary', 'text-slate-900');
        tabBash.classList.remove('bg-firebase-primary', 'text-slate-900');
    }
}

function onFirebaseAppIdChange(v) { state.firebaseAppId = v.trim(); updateSetupCommands(); saveState(); }
function onFirebaseTesterGroupChange(v) { state.firebaseTesterGroup = v.trim(); updateSetupCommands(); saveState(); }
function onProjectPathChange(v) { state.projectPath = v.trim() || '.'; updateSetupCommands(); saveState(); }

function onStep3Next() {
    if (!state.firebaseAppId) { showToast('⚠️ FIREBASE_APP_ID를 입력해주세요'); return; }
    if (!state.firebaseTesterGroup) { showToast('⚠️ FIREBASE_TESTER_GROUP을 입력해주세요'); return; }
    nextStep();
}

// Step 진입 시 초기화 — showStep 함수 wrap
const _origShowStep = showStep;
showStep = function (step) {
    _origShowStep(step);
    if (step === 3) {
        const inputs = {
            firebaseAppIdInput: state.firebaseAppId,
            firebaseTesterGroupInput: state.firebaseTesterGroup,
            projectPathInput: state.projectPath || '.'
        };
        Object.keys(inputs).forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = inputs[id];
        });
        updateSetupCommands();
        selectOsTab(state.detectedOS === 'windows' ? 'ps' : 'bash');
    }
};

// ============================================
// Step 4: File uploads
// ============================================
async function handleServiceAccountUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (!file.name.endsWith('.json')) {
        showToast('⚠️ .json 파일만 업로드 가능합니다');
        return;
    }
    try {
        const text = await fileToText(file);
        const parsed = JSON.parse(text);
        if (!parsed.client_email || !parsed.private_key) {
            showToast('⚠️ Service Account JSON 형식이 아닐 수 있습니다 (client_email/private_key 누락)');
        }
        const b64 = btoa(unescape(encodeURIComponent(text)));
        state.serviceAccountBase64 = b64;
        state.serviceAccountFileName = file.name;

        document.getElementById('saUploadText').textContent = `✅ ${file.name} (${(file.size/1024).toFixed(1)}KB)`;
        const info = document.getElementById('saInfo');
        info.style.display = 'block';
        info.textContent = `client_email: ${parsed.client_email || '(누락)'}`;
        const preview = document.getElementById('saPreview');
        preview.classList.remove('hidden');
        document.getElementById('saPreviewText').textContent = b64.substring(0, 100) + '...';
        saveState();
        showToast('✅ Service Account 업로드 완료');
    } catch (e) {
        showToast('❌ JSON 파싱 실패: ' + e.message);
    }
}

async function handleGoogleServicesUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (!file.name.endsWith('.json')) {
        showToast('⚠️ .json 파일만 업로드 가능합니다');
        return;
    }
    try {
        const text = await fileToText(file);
        JSON.parse(text); // 형식 검증
        state.googleServicesJson = text;
        state.googleServicesFileName = file.name;
        document.getElementById('gsUploadText').textContent = `✅ ${file.name} (${(file.size/1024).toFixed(1)}KB)`;
        const info = document.getElementById('gsInfo');
        info.style.display = 'block';
        info.textContent = `${file.size} bytes`;
        saveState();
        showToast('✅ google-services.json 업로드 완료');
    } catch (e) {
        showToast('❌ JSON 파싱 실패: ' + e.message);
    }
}

function setupDragAndDrop() {
    const targets = [
        { drop: 'saUpload', input: 'saInput', handler: handleServiceAccountUpload },
        { drop: 'gsUpload', input: 'gsInput', handler: handleGoogleServicesUpload }
    ];
    targets.forEach(({ drop, input, handler }) => {
        const el = document.getElementById(drop);
        if (!el) return;
        ['dragenter', 'dragover'].forEach(evt => el.addEventListener(evt, e => { e.preventDefault(); el.classList.add('dragover'); }));
        ['dragleave', 'drop'].forEach(evt => el.addEventListener(evt, e => { e.preventDefault(); el.classList.remove('dragover'); }));
        el.addEventListener('drop', e => {
            const file = e.dataTransfer.files[0];
            if (file) {
                const inp = document.getElementById(input);
                const dt = new DataTransfer();
                dt.items.add(file);
                inp.files = dt.files;
                handler({ target: inp });
            }
        });
    });
}

function onStep4Next() {
    if (!state.serviceAccountBase64) {
        showToast('⚠️ Service Account JSON을 업로드해주세요');
        return;
    }
    nextStep();
}

// Step 4 진입 시 setup — showStep 함수 wrap (Step 3 wrap 위에 다시 wrap)
const _showStepStep4 = showStep;
showStep = function (step) {
    _showStepStep4(step);
    if (step === 4) {
        if (state.serviceAccountFileName) {
            const t = document.getElementById('saUploadText');
            if (t) t.textContent = `✅ ${state.serviceAccountFileName} (복원됨)`;
            const preview = document.getElementById('saPreview');
            if (preview && state.serviceAccountBase64) {
                preview.classList.remove('hidden');
                document.getElementById('saPreviewText').textContent = state.serviceAccountBase64.substring(0, 100) + '...';
            }
        }
        if (state.googleServicesFileName) {
            const t = document.getElementById('gsUploadText');
            if (t) t.textContent = `✅ ${state.googleServicesFileName} (복원됨)`;
        }
        setupDragAndDrop();
    }
};

// ============================================
// Init
// ============================================
window.addEventListener('DOMContentLoaded', () => {
    state.detectedOS = detectOS();
    detectedOS = state.detectedOS;
    loadState();
    showStep(state.currentStep);
});
