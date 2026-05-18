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

// HTML escape for innerHTML interpolation (text content)
function escapeHtml(s) {
    return String(s == null ? '' : s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// Escape for use inside JS string in inline onclick="fn('...')"
function escapeJsString(s) {
    return String(s == null ? '' : s)
        .replace(/\\/g, '\\\\')
        .replace(/'/g, "\\'")
        .replace(/"/g, '\\"')
        .replace(/</g, '\\x3C')
        .replace(/>/g, '\\x3E')
        .replace(/&/g, '\\x26')
        .replace(/\r?\n/g, '\\n');
}

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
// Custom Secrets
// ============================================
const TEXT_EXTS = ['.txt', '.env', '.json', '.yaml', '.yml', '.md', '.properties', '.xml', '.ini', '.conf', '.cfg'];

function detectSecretType(filename) {
    const lower = (filename || '').toLowerCase();
    return TEXT_EXTS.some(ext => lower.endsWith(ext)) ? 'text' : 'binary';
}

function suggestSecretKey(filename, type) {
    const base = (filename || '').replace(/\.[^.]+$/, '').toUpperCase().replace(/[^A-Z0-9]/g, '_');
    return type === 'binary' ? `${base}_BASE64` : base;
}

function addCustomSecret() {
    state.customSecrets.push({ key: '', value: '', fileName: '', type: 'text' });
    saveState();
    renderCustomSecrets();
}

function removeCustomSecret(index) {
    state.customSecrets.splice(index, 1);
    saveState();
    renderCustomSecrets();
}

function updateCustomSecretKey(index, value) {
    state.customSecrets[index].key = value;
    saveState();
}

function updateCustomSecretValue(index, value) {
    state.customSecrets[index].value = value;
    state.customSecrets[index].type = 'text';
    state.customSecrets[index].fileName = '';
    saveState();
}

async function handleCustomSecretFile(index, event) {
    const file = event.target.files[0];
    if (!file) return;
    const type = detectSecretType(file.name);
    let value;
    if (type === 'text') {
        value = await fileToText(file);
    } else {
        value = await fileToBase64(file);
    }
    state.customSecrets[index].value = value;
    state.customSecrets[index].fileName = file.name;
    state.customSecrets[index].type = type;
    if (!state.customSecrets[index].key) {
        state.customSecrets[index].key = suggestSecretKey(file.name, type);
    }
    saveState();
    renderCustomSecrets();
    showToast(`✅ ${file.name} (${type})`);
}

function renderCustomSecrets() {
    const container = document.getElementById('customSecretsContent');
    if (!container) return;
    if (state.customSecrets.length === 0) {
        container.innerHTML = '<p class="text-xs text-slate-500 italic">추가된 항목이 없습니다.</p>';
        return;
    }
    container.innerHTML = state.customSecrets.map((s, i) => {
        const safeKey = escapeHtml(s.key || '');
        const safeType = escapeHtml(s.type || 'text');
        const safeFileName = escapeHtml(s.fileName || '');
        const safeValuePreview = s.fileName ? '' : escapeHtml((s.value || '').substring(0, 100));
        const typeBadgeClass = s.type === 'binary' ? 'bg-purple-600/30 text-purple-300' : 'bg-blue-600/30 text-blue-300';
        return `
        <div class="bg-slate-900 border border-slate-700 rounded-lg p-3 mb-3">
            <div class="flex items-center gap-2 mb-2">
                <input type="text" placeholder="SECRET_KEY_NAME" value="${safeKey}"
                    class="flex-1 bg-slate-950 border border-slate-700 rounded px-3 py-1.5 text-xs font-mono"
                    oninput="updateCustomSecretKey(${i}, this.value)">
                <span class="text-xs px-2 py-1 rounded ${typeBadgeClass}">${safeType}</span>
                <button class="text-red-400 hover:text-red-300 text-sm" onclick="removeCustomSecret(${i})">✕</button>
            </div>
            <div class="flex gap-2">
                <input type="file" id="csFile${i}" class="hidden" onchange="handleCustomSecretFile(${i}, event)">
                <button class="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 rounded text-xs" onclick="document.getElementById('csFile${i}').click()">
                    ${safeFileName ? `📎 ${safeFileName}` : '📁 파일 선택'}
                </button>
                <span class="text-xs text-slate-500 self-center">또는</span>
                <input type="text" placeholder="값 직접 입력" value="${safeValuePreview}"
                    class="flex-1 bg-slate-950 border border-slate-700 rounded px-3 py-1.5 text-xs font-mono"
                    oninput="updateCustomSecretValue(${i}, this.value)">
            </div>
        </div>
        `;
    }).join('');
}

// Step 4 진입 시 custom secrets도 렌더 (Task 10 wrap)
const _showStepCustom = showStep;
showStep = function (step) {
    _showStepCustom(step);
    if (step === 4) {
        renderCustomSecrets();
    }
};

// ============================================
// Step 5: Secrets table + Export
// ============================================
function getDateString() {
    const d = new Date();
    return `${d.getFullYear()}${String(d.getMonth()+1).padStart(2,'0')}${String(d.getDate()).padStart(2,'0')}`;
}

function buildSecretsArray() {
    const list = [];
    if (state.serviceAccountBase64) {
        list.push({ key: 'FIREBASE_SERVICE_ACCOUNT_JSON_BASE64', value: state.serviceAccountBase64, source: 'Service Account JSON', type: 'binary' });
    }
    if (state.googleServicesJson) {
        list.push({ key: 'GOOGLE_SERVICES_JSON', value: state.googleServicesJson, source: 'google-services.json', type: 'text' });
    }
    state.customSecrets.forEach(s => {
        if (s.key && s.value) {
            list.push({ key: s.key, value: s.value, source: s.fileName || '직접 입력', type: s.type });
        }
    });
    return list;
}

function renderSecretsTable() {
    const tbody = document.getElementById('secretsTableBody');
    if (!tbody) return;
    const list = buildSecretsArray();
    if (list.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" class="py-3 text-center text-slate-500 italic">등록할 Secret이 없습니다. Step 4를 먼저 완료해주세요.</td></tr>';
        return;
    }
    tbody.innerHTML = list.map(s => {
        const safeKey = escapeHtml(s.key);
        const safeSource = escapeHtml(s.source);
        const safeJsKey = escapeJsString(s.key);
        return `
        <tr class="border-b border-slate-700/50 hover:bg-slate-700/30">
            <td class="py-2 px-2 font-mono text-yellow-400">${safeKey}</td>
            <td class="py-2 px-2 text-slate-400">${safeSource}</td>
            <td class="py-2 px-2 text-slate-400">${(s.value.length / 1024).toFixed(1)} KB</td>
            <td class="py-2 px-2 text-right">
                <button class="px-3 py-1 bg-firebase-primary text-slate-900 rounded text-xs hover:opacity-90" onclick="copySecretValue('${safeJsKey}')">복사</button>
            </td>
        </tr>
        `;
    }).join('');
}

function copySecretValue(key) {
    const list = buildSecretsArray();
    const item = list.find(x => x.key === key);
    if (!item) { showToast('⚠️ 항목을 찾을 수 없습니다'); return; }
    copyToClipboard(item.value);
    showToast(`✅ ${key} 복사됨`);
}

function onRepoOwnerChange(v) {
    state.repoOwner = v.trim();
    saveState();
    updateSecretsPageLink();
}

function onRepoNameChange(v) {
    state.repoName = v.trim();
    saveState();
    updateSecretsPageLink();
}

function updateSecretsPageLink() {
    const link = document.getElementById('secretsPageLink');
    if (!link) return;
    if (state.repoOwner && state.repoName) {
        link.href = `https://github.com/${state.repoOwner}/${state.repoName}/settings/secrets/actions`;
    } else {
        link.href = 'https://github.com';
    }
}

function exportJson() {
    const list = buildSecretsArray();
    if (list.length === 0) { showToast('⚠️ 등록할 Secret이 없습니다'); return; }
    const out = {};
    list.forEach(s => { out[s.key] = s.value; });
    const blob = new Blob([JSON.stringify(out, null, 2)], { type: 'application/json' });
    triggerDownload(blob, `firebase-secrets-${(state.firebaseAppId || 'app').slice(0,12)}-${getDateString()}.json`);
    showToast('✅ JSON 다운로드');
}

function exportTxt() {
    const list = buildSecretsArray();
    if (list.length === 0) { showToast('⚠️ 등록할 Secret이 없습니다'); return; }
    const lines = list.map(s => `=== ${s.key} ===\n${s.value}\n`);
    const blob = new Blob([lines.join('\n')], { type: 'text/plain' });
    triggerDownload(blob, `firebase-secrets-${(state.firebaseAppId || 'app').slice(0,12)}-${getDateString()}.txt`);
    showToast('✅ TXT 다운로드');
}

async function exportZip() {
    const list = buildSecretsArray();
    if (list.length === 0) { showToast('⚠️ 등록할 Secret이 없습니다'); return; }
    if (typeof JSZip === 'undefined') { showToast('❌ JSZip 라이브러리 로드 실패'); return; }

    const zip = new JSZip();
    const folder = zip.folder('github-secrets');
    list.forEach(s => folder.file(`${s.key}.txt`, s.value));

    // setup 스크립트 — GitHub raw에서 fetch 시도, 실패 시 README 안내만
    const wizardBaseUrl = 'https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/.github/util/flutter/firebase-wizard';
    try {
        const [shResp, ps1Resp] = await Promise.all([
            fetch(`${wizardBaseUrl}/firebase-wizard-setup.sh`).then(r => r.ok ? r.text() : null).catch(() => null),
            fetch(`${wizardBaseUrl}/firebase-wizard-setup.ps1`).then(r => r.ok ? r.text() : null).catch(() => null)
        ]);
        if (shResp) zip.file('firebase-wizard-setup.sh', shResp);
        if (ps1Resp) zip.file('firebase-wizard-setup.ps1', ps1Resp);
    } catch (e) {
        console.warn('setup 스크립트 fetch 실패:', e);
    }

    const readme = `# Firebase App Distribution Secrets 패키지

생성 시각: ${new Date().toISOString()}
앱 ID: ${state.firebaseAppId || '(미입력)'}
테스터 그룹: ${state.firebaseTesterGroup || '(미입력)'}

## 폴더 구조

- github-secrets/         GitHub Repository Secrets에 등록할 값 파일들
- firebase-wizard-setup.sh   워크플로우 placeholder 안전 치환 (bash)
- firebase-wizard-setup.ps1  동일 동작 (PowerShell)

## 등록 절차

1. https://github.com/<owner>/<repo>/settings/secrets/actions 접속
2. github-secrets/ 폴더의 각 파일명을 Secret 이름으로 사용
3. 파일 내용을 Secret 값으로 붙여넣기

## setup 스크립트 실행 (워크플로우 placeholder 치환)

### macOS / Linux
\`\`\`bash
chmod +x firebase-wizard-setup.sh
./firebase-wizard-setup.sh \\
  --project-path /path/to/project \\
  --app-id "${state.firebaseAppId}" \\
  --tester-group "${state.firebaseTesterGroup}"
\`\`\`

### Windows (PowerShell)
\`\`\`powershell
.\\firebase-wizard-setup.ps1 \`
  -ProjectPath C:\\path\\to\\project \`
  -AppId "${state.firebaseAppId}" \`
  -TesterGroup "${state.firebaseTesterGroup}"
\`\`\`

## 옵션

- --dry-run / -DryRun           실제 변경 없이 미리보기
- --non-interactive / -NonInteractive  충돌 시 자동 SKIP
- --no-backup / -NoBackup       백업 파일 생성 비활성화
`;
    zip.file('README.md', readme);

    const blob = await zip.generateAsync({ type: 'blob' });
    triggerDownload(blob, `firebase-setup-${(state.firebaseAppId || 'app').slice(0,12)}-${getDateString()}.zip`);
    showToast('✅ ZIP 다운로드');
}

function triggerDownload(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

// Step 5 진입 시 렌더 (Task 11 wrap)
const _showStepStep5 = showStep;
showStep = function (step) {
    _showStepStep5(step);
    if (step === 5) {
        const r1 = document.getElementById('repoOwnerInput'); if (r1) r1.value = state.repoOwner || '';
        const r2 = document.getElementById('repoNameInput'); if (r2) r2.value = state.repoName || '';
        renderSecretsTable();
        updateSecretsPageLink();
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
