// ============================================
// GitHub Secrets Converter
// 파일을 업로드하면 자동으로 최적의 형식으로 변환
// ============================================

// 상태 관리
const STORAGE_KEY = 'secrets-converter-state';
let state = {
    files: []
    // [{
    //   key: 'SECRET_NAME',
    //   value: '...',
    //   fileName: 'original.p12',
    //   type: 'text' | 'binary',
    //   hint: '사용법'
    // }]
};

// ============================================
// 파일 타입 감지 및 처리
// ============================================

// 텍스트 파일 확장자 (원본 그대로 저장)
const TEXT_EXTENSIONS = [
    '.json', '.yml', '.yaml', '.env', '.txt', '.xml',
    '.plist', '.properties', '.toml', '.ini', '.cfg', '.conf'
];

// 바이너리 파일 확장자 (Base64 인코딩)
const BINARY_EXTENSIONS = [
    '.jks', '.keystore', '.p12', '.mobileprovision', '.p8',
    '.cer', '.pfx', '.pem', '.der', '.key', '.crt'
];

function getFileType(fileName) {
    const lowerName = fileName.toLowerCase();
    // .env로 시작하는 파일은 텍스트로 처리 (.env.production, .env.local 등)
    if (lowerName === '.env' || lowerName.startsWith('.env.')) return 'text';

    const ext = '.' + fileName.split('.').pop().toLowerCase();
    if (TEXT_EXTENSIONS.includes(ext)) return 'text';
    if (BINARY_EXTENSIONS.includes(ext)) return 'binary';
    // 알 수 없는 확장자는 바이너리로 처리 (안전)
    return 'binary';
}

function generateKeyName(fileName, fileType) {
    // 파일명에서 확장자 제거 후 대문자+언더스코어로 변환
    const baseName = fileName
        .replace(/\.[^/.]+$/, '')  // 확장자 제거
        .toUpperCase()
        .replace(/[^A-Z0-9]/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_|_$/g, '');  // 시작/끝 언더스코어 제거

    // 바이너리 파일만 _BASE64 접미사 추가
    if (fileType === 'binary') {
        return baseName + '_BASE64';
    }
    return baseName;
}

async function processFile(file) {
    const fileType = getFileType(file.name);

    if (fileType === 'text') {
        // 텍스트 파일: 원본 내용 그대로
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve({
                value: reader.result,
                type: 'text',
                hint: 'cat <<EOF 로 파일 생성'
            });
            reader.onerror = reject;
            reader.readAsText(file);
        });
    } else {
        // 바이너리 파일: Base64 인코딩
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve({
                value: reader.result.split(',')[1],  // data URL에서 base64만 추출
                type: 'binary',
                hint: 'echo $SECRET | base64 -d > file'
            });
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }
}

// ============================================
// UI 렌더링
// ============================================

function renderFileList() {
    const container = document.getElementById('fileList');
    if (!container) return;

    if (state.files.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">📁</div>
                <p>파일을 추가하여 GitHub Secrets 값을 생성하세요</p>
                <p class="hint">바이너리 파일은 Base64로, 텍스트 파일은 원본 그대로 변환됩니다</p>
            </div>
        `;
        return;
    }

    container.innerHTML = state.files.map((file, index) => {
        const typeIcon = file.type === 'text' ? '📄' : '🔐';
        const typeBadge = file.type === 'text' ? 'Raw Text' : 'Base64';
        const typeClass = file.type === 'text' ? 'text' : 'binary';
        const valuePreview = file.value ?
            (file.value.length > 100 ? file.value.substring(0, 100) + '...' : file.value) :
            '';

        return `
            <div class="file-slot" data-index="${index}">
                <div class="slot-header">
                    <span class="type-badge ${typeClass}">${typeIcon} ${typeBadge}</span>
                    <button class="remove-btn" onclick="removeFile(${index})" title="삭제">×</button>
                </div>
                <div class="key-input-wrapper">
                    <label>Secret 키 이름</label>
                    <input type="text"
                           class="key-input"
                           value="${file.key || ''}"
                           onchange="updateKey(${index}, this.value)"
                           placeholder="SECRET_NAME">
                </div>
                <div class="file-info">
                    <span class="file-name">${file.fileName || '(파일 없음)'}</span>
                    ${file.value ? `<span class="file-size">(${formatSize(file.value.length)})</span>` : ''}
                </div>
                ${file.hint ? `<div class="usage-hint">💡 ${file.hint}</div>` : ''}
                ${file.value ? `
                    <div class="value-preview">
                        <code>${escapeHtml(valuePreview)}</code>
                    </div>
                    <button class="copy-btn" onclick="copyValue(${index})">📋 값 복사</button>
                ` : ''}
            </div>
        `;
    }).join('');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatSize(length) {
    if (length < 1024) return `${length}B`;
    if (length < 1024 * 1024) return `${(length / 1024).toFixed(1)}KB`;
    return `${(length / (1024 * 1024)).toFixed(1)}MB`;
}

// ============================================
// 파일 슬롯 관리
// ============================================

function addFileSlot() {
    state.files.push({
        key: '',
        value: '',
        fileName: '',
        type: 'binary',
        hint: ''
    });
    renderFileList();
    saveState();

    // 새로 추가된 슬롯의 파일 선택 다이얼로그 열기
    setTimeout(() => {
        const slots = document.querySelectorAll('.file-slot');
        const lastSlot = slots[slots.length - 1];
        if (lastSlot) {
            const input = document.createElement('input');
            input.type = 'file';
            input.onchange = (e) => handleFileSelect(state.files.length - 1, e.target.files[0]);
            input.click();
        }
    }, 100);
}

function removeFile(index) {
    state.files.splice(index, 1);
    renderFileList();
    saveState();
    showToast('파일이 삭제되었습니다');
}

function updateKey(index, newKey) {
    if (state.files[index]) {
        state.files[index].key = newKey.toUpperCase().replace(/[^A-Z0-9_]/g, '_');
        saveState();
    }
}

async function handleFileSelect(index, file) {
    if (!file) return;

    try {
        const result = await processFile(file);
        const suggestedKey = generateKeyName(file.name, result.type);

        state.files[index] = {
            key: suggestedKey,
            value: result.value,
            fileName: file.name,
            type: result.type,
            hint: result.hint
        };

        renderFileList();
        saveState();
        showToast(`✅ ${file.name} 처리 완료 (${result.type === 'text' ? '텍스트' : 'Base64'})`);
    } catch (error) {
        console.error('파일 처리 실패:', error);
        showToast('❌ 파일 처리 실패');
    }
}

// ============================================
// Drag & Drop
// ============================================

function setupDragAndDrop() {
    const dropZone = document.getElementById('dropZone');
    if (!dropZone) return;

    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, preventDefaults, false);
    });

    function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    ['dragenter', 'dragover'].forEach(eventName => {
        dropZone.addEventListener(eventName, () => {
            dropZone.classList.add('drag-over');
        });
    });

    ['dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, () => {
            dropZone.classList.remove('drag-over');
        });
    });

    dropZone.addEventListener('drop', async (e) => {
        const files = e.dataTransfer.files;
        for (const file of files) {
            try {
                const result = await processFile(file);
                const suggestedKey = generateKeyName(file.name, result.type);

                state.files.push({
                    key: suggestedKey,
                    value: result.value,
                    fileName: file.name,
                    type: result.type,
                    hint: result.hint
                });
            } catch (error) {
                console.error('파일 처리 실패:', file.name, error);
            }
        }
        renderFileList();
        saveState();
        showToast(`✅ ${files.length}개 파일 처리 완료`);
    });
}

// ============================================
// 복사 및 내보내기
// ============================================

function copyValue(index) {
    const file = state.files[index];
    if (!file || !file.value) {
        showToast('❌ 복사할 값이 없습니다');
        return;
    }

    navigator.clipboard.writeText(file.value).then(() => {
        showToast(`✅ ${file.key} 값 복사 완료!`);
    }).catch(() => {
        showToast('❌ 클립보드 복사 실패');
    });
}

function copyAllAsJson() {
    const validFiles = state.files.filter(f => f.key && f.value);
    if (validFiles.length === 0) {
        showToast('⚠️ 복사할 데이터가 없습니다');
        return;
    }

    const result = {};
    validFiles.forEach(f => {
        result[f.key] = f.value;
    });

    navigator.clipboard.writeText(JSON.stringify(result, null, 2)).then(() => {
        showToast(`✅ ${validFiles.length}개 Secret JSON 복사 완료!`);
    }).catch(() => {
        showToast('❌ 클립보드 복사 실패');
    });
}

function downloadAsJson() {
    const validFiles = state.files.filter(f => f.key && f.value);
    if (validFiles.length === 0) {
        showToast('⚠️ 내보낼 데이터가 없습니다');
        return;
    }

    const result = {};
    validFiles.forEach(f => {
        result[f.key] = f.value;
    });

    const jsonStr = JSON.stringify(result, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `github-secrets-${getDateString()}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ JSON 파일 다운로드 완료!');
}

function downloadAsTxt() {
    const validFiles = state.files.filter(f => f.key && f.value);
    if (validFiles.length === 0) {
        showToast('⚠️ 내보낼 데이터가 없습니다');
        return;
    }

    const lines = [
        '# GitHub Secrets',
        '# 생성일: ' + new Date().toLocaleString('ko-KR'),
        ''
    ];

    validFiles.forEach(f => {
        const typeLabel = f.type === 'text' ? '[텍스트]' : '[Base64]';
        lines.push(`===== ${f.key} ${typeLabel} =====`);
        lines.push(`# 원본 파일: ${f.fileName}`);
        lines.push(`# 사용법: ${f.hint}`);
        lines.push('');
        lines.push(f.value);
        lines.push('');
    });

    const txtStr = lines.join('\n');
    const blob = new Blob([txtStr], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `github-secrets-${getDateString()}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('✅ TXT 파일 다운로드 완료!');
}

function getDateString() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

// ============================================
// 상태 저장/복원
// ============================================

function saveState() {
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
        console.error('상태 저장 실패:', e);
    }
}

function loadState() {
    try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
            state = JSON.parse(saved);
        }
    } catch (e) {
        console.error('상태 복원 실패:', e);
        state = { files: [] };
    }
}

function clearAll() {
    if (confirm('모든 데이터를 삭제하시겠습니까?')) {
        state = { files: [] };
        saveState();
        renderFileList();
        showToast('모든 데이터가 삭제되었습니다');
    }
}

// ============================================
// 토스트 메시지
// ============================================

function showToast(message) {
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
    }, 2500);
}

// ============================================
// 초기화
// ============================================

document.addEventListener('DOMContentLoaded', () => {
    loadState();
    renderFileList();
    setupDragAndDrop();
});
