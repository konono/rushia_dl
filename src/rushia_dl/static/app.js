/**
 * Rushia DL - Frontend Application
 */

class RushiaDL {
    constructor() {
        this.form = document.getElementById('downloadForm');
        this.urlInput = document.getElementById('urlInput');
        this.downloadBtn = document.getElementById('downloadBtn');
        this.statusIndicator = document.getElementById('statusIndicator');
        
        this.progressSection = document.getElementById('progressSection');
        this.progressTitle = document.getElementById('progressTitle');
        this.progressPercent = document.getElementById('progressPercent');
        this.progressFill = document.getElementById('progressFill');
        this.progressStatusText = document.getElementById('progressStatusText');
        this.progressSpeed = document.getElementById('progressSpeed');
        this.progressEta = document.getElementById('progressEta');
        this.progressSize = document.getElementById('progressSize');
        
        this.completeSection = document.getElementById('completeSection');
        this.completeFilename = document.getElementById('completeFilename');
        this.saveBtn = document.getElementById('saveBtn');
        this.newDownloadBtn = document.getElementById('newDownloadBtn');
        
        this.errorSection = document.getElementById('errorSection');
        this.errorMessage = document.getElementById('errorMessage');
        this.backBtn = document.getElementById('backBtn');
        this.retryBtn = document.getElementById('retryBtn');
        
        // Cookie関連
        this.cookieFile = document.getElementById('cookieFile');
        this.cookieUploadBtn = document.getElementById('cookieUploadBtn');
        this.cookieClearBtn = document.getElementById('cookieClearBtn');
        this.cookieStatus = document.getElementById('cookieStatus');
        
        // 履歴タブ関連
        this.tabDownload = document.getElementById('tabDownload');
        this.tabHistory = document.getElementById('tabHistory');
        this.downloadCard = document.getElementById('downloadCard');
        this.historyCard = document.getElementById('historyCard');
        this.historyList = document.getElementById('historyList');
        this.historyEmpty = document.getElementById('historyEmpty');
        
        this.currentTaskId = null;
        this.pollInterval = null;
        this.historyPollInterval = null;
        this.lastDownloadParams = null;
        this.cookieId = null;
        
        // localStorage キー
        this.STORAGE_KEY = 'rushia_dl_task';
        this.HISTORY_KEY = 'rushia_dl_history';
        
        this.init();
    }
    
    init() {
        // イベントリスナーの設定
        this.form.addEventListener('submit', (e) => this.handleSubmit(e));
        this.newDownloadBtn.addEventListener('click', () => this.resetForm());
        this.backBtn.addEventListener('click', () => this.backToForm());
        this.retryBtn.addEventListener('click', () => this.retryDownload());
        
        // タブ切り替え
        this.tabDownload.addEventListener('click', () => this.switchTab('download'));
        this.tabHistory.addEventListener('click', () => this.switchTab('history'));
        
        // Cookieアップロード関連
        this.cookieUploadBtn.addEventListener('click', () => this.cookieFile.click());
        this.cookieFile.addEventListener('change', (e) => this.handleCookieUpload(e));
        this.cookieClearBtn.addEventListener('click', () => this.clearCookie());
        
        // Cookieガイドセクション
        this.guideSection = document.getElementById('guideSection');
        this.showGuideBtn = document.getElementById('showCookieGuide');
        this.guideBackBtn = document.getElementById('guideBackBtn');
        
        if (this.showGuideBtn) {
            this.showGuideBtn.addEventListener('click', (e) => {
                e.preventDefault();
                this.showGuide();
            });
        }
        
        if (this.guideBackBtn) {
            this.guideBackBtn.addEventListener('click', () => {
                this.hideGuide();
            });
        }
        
        // ページ読み込み時に未完了タスクを復元
        this.restorePendingTask();
        
        // 履歴のクリーンアップ
        this.cleanupExpiredHistory();
    }
    
    // ===== 履歴管理 =====
    
    // 履歴を取得
    getHistory() {
        try {
            const data = localStorage.getItem(this.HISTORY_KEY);
            if (!data) return [];
            return JSON.parse(data);
        } catch (e) {
            return [];
        }
    }
    
    // 履歴を保存
    saveHistory(history) {
        localStorage.setItem(this.HISTORY_KEY, JSON.stringify(history));
    }
    
    // タスクを履歴に追加
    addToHistory(taskId, url, format) {
        const history = this.getHistory();
        
        // 既存のタスクがあれば削除（重複防止）
        const filtered = history.filter(h => h.taskId !== taskId);
        
        // 新しいタスクを先頭に追加
        filtered.unshift({
            taskId: taskId,
            url: url,
            format: format,
            timestamp: Date.now(),
            status: 'pending',
            title: null,
            filename: null
        });
        
        this.saveHistory(filtered);
        this.updateHistoryBadge();
    }
    
    // 履歴のタスク情報を更新
    updateHistoryTask(taskId, updates) {
        const history = this.getHistory();
        const index = history.findIndex(h => h.taskId === taskId);
        
        if (index !== -1) {
            history[index] = { ...history[index], ...updates };
            this.saveHistory(history);
        }
    }
    
    // 期限切れの履歴を削除
    cleanupExpiredHistory() {
        const history = this.getHistory();
        const maxAge = 6 * 60 * 60 * 1000; // 6時間
        const now = Date.now();
        
        const filtered = history.filter(h => (now - h.timestamp) < maxAge);
        
        if (filtered.length !== history.length) {
            this.saveHistory(filtered);
        }
        
        this.updateHistoryBadge();
    }
    
    // 履歴バッジを更新
    updateHistoryBadge() {
        const history = this.getHistory();
        const activeCount = history.filter(h => 
            h.status === 'pending' || h.status === 'downloading' || h.status === 'processing'
        ).length;
        
        const badge = document.getElementById('historyBadge');
        if (badge) {
            if (activeCount > 0) {
                badge.textContent = activeCount;
                badge.style.display = 'flex';
            } else {
                badge.style.display = 'none';
            }
        }
    }
    
    // タブ切り替え
    switchTab(tab) {
        if (tab === 'download') {
            this.tabDownload.classList.add('active');
            this.tabHistory.classList.remove('active');
            this.downloadCard.style.display = 'block';
            this.historyCard.style.display = 'none';
            this.stopHistoryPolling();
        } else {
            this.tabDownload.classList.remove('active');
            this.tabHistory.classList.add('active');
            this.downloadCard.style.display = 'none';
            this.historyCard.style.display = 'block';
            this.renderHistory();
            this.startHistoryPolling();
        }
    }
    
    // 履歴のポーリング開始
    startHistoryPolling() {
        this.updateHistoryStatuses();
        this.historyPollInterval = setInterval(() => this.updateHistoryStatuses(), 2000);
    }
    
    // 履歴のポーリング停止
    stopHistoryPolling() {
        if (this.historyPollInterval) {
            clearInterval(this.historyPollInterval);
            this.historyPollInterval = null;
        }
    }
    
    // 履歴の各タスクのステータスを更新
    async updateHistoryStatuses() {
        const history = this.getHistory();
        let updated = false;
        
        for (const item of history) {
            // 完了・エラー以外のタスクのみ更新
            if (item.status !== 'completed' && item.status !== 'error') {
                try {
                    const response = await fetch(`/api/status/${item.taskId}`);
                    if (response.ok) {
                        const data = await response.json();
                        if (data.status !== item.status || data.title !== item.title || data.filename !== item.filename) {
                            this.updateHistoryTask(item.taskId, {
                                status: data.status,
                                title: data.title || item.title,
                                filename: data.filename || item.filename,
                                progress: data.progress
                            });
                            updated = true;
                        }
                    } else {
                        // タスクが存在しない場合はエラーとしてマーク
                        this.updateHistoryTask(item.taskId, { status: 'error' });
                        updated = true;
                    }
                } catch (e) {
                    console.error('Failed to update history status:', e);
                }
            }
        }
        
        if (updated) {
            this.renderHistory();
            this.updateHistoryBadge();
        }
    }
    
    // 履歴をレンダリング
    renderHistory() {
        const history = this.getHistory();
        
        if (history.length === 0) {
            this.historyList.style.display = 'none';
            this.historyEmpty.style.display = 'block';
            return;
        }
        
        this.historyList.style.display = 'block';
        this.historyEmpty.style.display = 'none';
        
        this.historyList.innerHTML = history.map(item => this.renderHistoryItem(item)).join('');
        
        // ダウンロードボタンのイベントリスナーを設定
        this.historyList.querySelectorAll('.history-download-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const filename = e.currentTarget.dataset.filename;
                if (filename) {
                    window.location.href = `/api/download/${encodeURIComponent(filename)}`;
                }
            });
        });
    }
    
    // 履歴アイテムのHTML生成
    renderHistoryItem(item) {
        const statusInfo = this.getStatusInfo(item.status);
        const timeAgo = this.formatTimeAgo(item.timestamp);
        const title = item.title || this.extractVideoId(item.url) || '取得中...';
        
        let actionHtml = '';
        if (item.status === 'completed' && item.filename) {
            actionHtml = `
                <button class="history-download-btn" data-filename="${item.filename}">
                    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        <polyline points="7 10 12 15 17 10" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        <line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                </button>
            `;
        } else if (item.status === 'downloading' || item.status === 'processing') {
            const progress = item.progress || 0;
            actionHtml = `<span class="history-progress">${Math.round(progress)}%</span>`;
        }
        
        return `
            <div class="history-item ${item.status}">
                <div class="history-format ${item.format}">${item.format.toUpperCase()}</div>
                <div class="history-info">
                    <div class="history-title">${this.escapeHtml(title)}</div>
                    <div class="history-meta">
                        <span class="history-status ${item.status}">${statusInfo.icon} ${statusInfo.text}</span>
                        <span class="history-time">${timeAgo}</span>
                    </div>
                </div>
                <div class="history-action">
                    ${actionHtml}
                </div>
            </div>
        `;
    }
    
    // ステータス情報を取得
    getStatusInfo(status) {
        const statuses = {
            'pending': { icon: '⏳', text: '待機中' },
            'downloading': { icon: '⬇️', text: 'ダウンロード中' },
            'processing': { icon: '⚙️', text: 'エンコード中' },
            'completed': { icon: '✅', text: '完了' },
            'error': { icon: '❌', text: 'エラー' }
        };
        return statuses[status] || { icon: '❓', text: status };
    }
    
    // 経過時間をフォーマット
    formatTimeAgo(timestamp) {
        const seconds = Math.floor((Date.now() - timestamp) / 1000);
        
        if (seconds < 60) return '数秒前';
        if (seconds < 3600) return `${Math.floor(seconds / 60)}分前`;
        if (seconds < 86400) return `${Math.floor(seconds / 3600)}時間前`;
        return `${Math.floor(seconds / 86400)}日前`;
    }
    
    // URLからビデオIDを抽出
    extractVideoId(url) {
        try {
            const urlObj = new URL(url);
            const params = new URLSearchParams(urlObj.search);
            return params.get('v');
        } catch (e) {
            return null;
        }
    }
    
    // HTMLエスケープ
    escapeHtml(str) {
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }
    
    // ===== 既存の機能（現在のダウンロード用） =====
    
    // タスク情報をlocalStorageに保存
    saveTask(taskId) {
        const taskData = {
            taskId: taskId,
            timestamp: Date.now()
        };
        localStorage.setItem(this.STORAGE_KEY, JSON.stringify(taskData));
        console.log('[Storage] Task saved:', taskId);
    }
    
    // タスク情報をlocalStorageから削除
    clearSavedTask() {
        localStorage.removeItem(this.STORAGE_KEY);
        console.log('[Storage] Task cleared');
    }
    
    // 保存されたタスク情報を取得
    getSavedTask() {
        const data = localStorage.getItem(this.STORAGE_KEY);
        if (!data) return null;
        
        try {
            const taskData = JSON.parse(data);
            // 6時間以上経過したタスクは無視（最長のdownloadingタイムアウトに合わせる）
            const elapsed = Date.now() - taskData.timestamp;
            if (elapsed > 6 * 60 * 60 * 1000) {
                this.clearSavedTask();
                return null;
            }
            return taskData;
        } catch (e) {
            this.clearSavedTask();
            return null;
        }
    }
    
    // 未完了タスクを復元
    async restorePendingTask() {
        const savedTask = this.getSavedTask();
        if (!savedTask) return;
        
        console.log('[Storage] Restoring task:', savedTask.taskId);
        
        try {
            // サーバーからタスク状態を確認
            const response = await fetch(`/api/status/${savedTask.taskId}`);
            if (!response.ok) {
                // タスクが存在しない場合はクリア
                this.clearSavedTask();
                return;
            }
            
            const data = await response.json();
            console.log('[Storage] Task status:', data.status);
            
            // タスクの状態に応じて処理
            if (data.status === 'completed') {
                // 完了済み - 完了画面を表示
                this.currentTaskId = savedTask.taskId;
                this.showComplete(data.filename, data.title);
            } else if (data.status === 'error') {
                // エラー - エラー画面を表示
                this.showError(data.error || 'ダウンロードに失敗しました');
                this.clearSavedTask();
            } else if (data.status === 'downloading' || data.status === 'processing' || data.status === 'pending') {
                // ダウンロード中 - 進捗画面を表示してポーリング再開
                this.currentTaskId = savedTask.taskId;
                this.showProgress();
                this.setStatus('active', 'ダウンロード再開中');
                this.startPolling();
            } else {
                // 不明な状態
                this.clearSavedTask();
            }
        } catch (e) {
            console.error('[Storage] Failed to restore task:', e);
            this.clearSavedTask();
        }
    }
    
    showGuide() {
        if (this.form && this.guideSection) {
            this.form.style.display = 'none';
            this.guideSection.style.display = 'block';
        }
    }
    
    hideGuide() {
        if (this.form && this.guideSection) {
            this.guideSection.style.display = 'none';
            this.form.style.display = 'block';
        }
    }
    
    async handleCookieUpload(e) {
        const file = e.target.files[0];
        if (!file) return;
        
        // ファイル名の検証
        if (!file.name.endsWith('.txt')) {
            alert('Cookie.txtファイルを選択してください');
            return;
        }
        
        const formData = new FormData();
        formData.append('file', file);
        
        try {
            const response = await fetch('/api/upload-cookie', {
                method: 'POST',
                body: formData,
            });
            
            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.detail || 'Cookieのアップロードに失敗しました');
            }
            
            const data = await response.json();
            this.cookieId = data.cookie_id;
            
            // UIを更新
            this.cookieUploadBtn.classList.add('uploaded');
            this.cookieUploadBtn.querySelector('span').textContent = 'Cookie.txt アップロード済み';
            this.cookieClearBtn.style.display = 'flex';
            this.cookieStatus.textContent = '✓ 有効';
            this.cookieStatus.className = 'cookie-status uploaded';
            
        } catch (error) {
            alert(error.message);
        }
        
        // ファイル入力をリセット
        this.cookieFile.value = '';
    }
    
    async clearCookie() {
        if (this.cookieId) {
            try {
                await fetch(`/api/cookie/${this.cookieId}`, { method: 'DELETE' });
            } catch (e) {
                // エラーは無視
            }
        }
        
        this.cookieId = null;
        this.cookieUploadBtn.classList.remove('uploaded');
        this.cookieUploadBtn.querySelector('span').textContent = 'Cookie.txtをアップロード';
        this.cookieClearBtn.style.display = 'none';
        this.cookieStatus.textContent = '';
        this.cookieStatus.className = 'cookie-status';
    }
    
    async handleSubmit(e) {
        e.preventDefault();
        
        const url = this.urlInput.value.trim();
        const format = document.querySelector('input[name="format"]:checked').value;
        
        if (!url) {
            this.showError('URLを入力してください');
            return;
        }
        
        // 再試行用にパラメータを保存
        this.lastDownloadParams = { url, format, cookieId: this.cookieId };
        
        await this.startDownload(url, format, this.cookieId);
    }
    
    async startDownload(url, format, cookieId) {
        // UIを更新
        this.showProgress();
        this.setStatus('active', 'ダウンロード中');
        this.downloadBtn.disabled = true;
        
        try {
            // ダウンロードリクエストを送信
            const response = await fetch('/api/download', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    url: url,
                    format: format,
                    cookie_id: cookieId,
                }),
            });
            
            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.detail || 'ダウンロードの開始に失敗しました');
            }
            
            const data = await response.json();
            this.currentTaskId = data.task_id;
            
            // タスクIDをlocalStorageに保存（セッション復元用）
            this.saveTask(this.currentTaskId);
            
            // 履歴に追加
            this.addToHistory(this.currentTaskId, url, format);
            
            // 進捗のポーリングを開始
            this.startPolling();
            
        } catch (error) {
            this.showError(error.message);
            this.downloadBtn.disabled = false;
        }
    }
    
    startPolling() {
        this.pollInterval = setInterval(() => this.checkStatus(), 1000);
    }
    
    stopPolling() {
        if (this.pollInterval) {
            clearInterval(this.pollInterval);
            this.pollInterval = null;
        }
    }
    
    async checkStatus() {
        if (!this.currentTaskId) return;
        
        try {
            const response = await fetch(`/api/status/${this.currentTaskId}`);
            
            if (!response.ok) {
                throw new Error('ステータスの取得に失敗しました');
            }
            
            const data = await response.json();
            
            // 進捗を更新
            this.updateProgress(data);
            
            // 履歴も更新
            this.updateHistoryTask(this.currentTaskId, {
                status: data.status,
                title: data.title,
                filename: data.filename,
                progress: data.progress
            });
            this.updateHistoryBadge();
            
            if (data.status === 'completed') {
                this.stopPolling();
                // 完了時は保存ボタンクリック後にクリアするため、ここではクリアしない
                this.showComplete(data.filename, data.title);
            } else if (data.status === 'error') {
                this.stopPolling();
                this.clearSavedTask(); // エラー時はクリア
                this.showError(data.error || 'ダウンロード中にエラーが発生しました');
            }
            
        } catch (error) {
            console.error('Status check failed:', error);
        }
    }
    
    updateProgress(data) {
        const percent = Math.round(data.progress);
        this.progressPercent.textContent = `${percent}%`;
        this.progressFill.style.width = `${percent}%`;
        
        // ステータスの更新
        let statusText = '準備中...';
        let statusClass = '';
        
        switch (data.status) {
            case 'downloading':
                statusText = 'ダウンロード中';
                statusClass = 'status-downloading';
                break;
            case 'processing':
                statusText = 'エンコード中';
                statusClass = 'status-processing';
                break;
            case 'pending':
                statusText = '準備中...';
                break;
        }
        
        this.progressStatusText.textContent = statusText;
        this.progressStatusText.className = `progress-value ${statusClass}`;
        
        // 速度の表示
        if (data.speed && data.speed > 0) {
            this.progressSpeed.textContent = this.formatSpeed(data.speed);
        } else if (data.status === 'downloading') {
            this.progressSpeed.textContent = '計測中...';
        } else if (data.status === 'processing') {
            this.progressSpeed.textContent = '-- (エンコード中)';
        } else {
            this.progressSpeed.textContent = '--';
        }
        
        // ETAの表示
        if (data.eta && data.eta > 0) {
            this.progressEta.textContent = this.formatEta(data.eta);
        } else if (data.status === 'downloading') {
            this.progressEta.textContent = '計算中...';
        } else if (data.status === 'processing') {
            this.progressEta.textContent = '-- (エンコード中)';
        } else {
            this.progressEta.textContent = '--';
        }
        
        // サイズの表示
        if (data.downloaded_bytes && data.total_bytes) {
            this.progressSize.textContent = `${this.formatSize(data.downloaded_bytes)} / ${this.formatSize(data.total_bytes)}`;
        } else if (data.downloaded_bytes) {
            this.progressSize.textContent = `${this.formatSize(data.downloaded_bytes)} / 不明`;
        } else {
            this.progressSize.textContent = '-- / --';
        }
    }
    
    formatSpeed(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec <= 0) return '-- MB/s';
        
        if (bytesPerSec >= 1024 * 1024) {
            return `${(bytesPerSec / (1024 * 1024)).toFixed(2)} MB/s`;
        } else if (bytesPerSec >= 1024) {
            return `${(bytesPerSec / 1024).toFixed(2)} KB/s`;
        } else {
            return `${bytesPerSec.toFixed(0)} B/s`;
        }
    }
    
    formatEta(seconds) {
        if (!seconds || seconds <= 0) return '--:--';
        
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        
        if (hours > 0) {
            return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        } else {
            return `${minutes}:${String(secs).padStart(2, '0')}`;
        }
    }
    
    formatSize(bytes) {
        if (!bytes || bytes <= 0) return '--';
        
        if (bytes >= 1024 * 1024 * 1024) {
            return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
        } else if (bytes >= 1024 * 1024) {
            return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
        } else if (bytes >= 1024) {
            return `${(bytes / 1024).toFixed(2)} KB`;
        } else {
            return `${bytes} B`;
        }
    }
    
    showProgress() {
        this.form.style.display = 'flex';
        this.progressSection.style.display = 'block';
        this.completeSection.style.display = 'none';
        this.errorSection.style.display = 'none';
        
        this.progressPercent.textContent = '0%';
        this.progressFill.style.width = '0%';
        this.progressStatusText.textContent = '準備中...';
        this.progressStatusText.className = 'progress-value';
        this.progressSpeed.textContent = '--';
        this.progressEta.textContent = '--';
        this.progressSize.textContent = '-- / --';
    }
    
    showComplete(filename, title) {
        this.form.style.display = 'none';
        this.progressSection.style.display = 'none';
        this.completeSection.style.display = 'block';
        this.errorSection.style.display = 'none';
        
        this.completeFilename.textContent = title || filename;
        this.saveBtn.href = `/api/download/${encodeURIComponent(filename)}`;
        this.saveBtn.download = filename;
        
        // ファイル保存ボタンクリック時にタスクをクリア
        this.saveBtn.onclick = () => {
            this.clearSavedTask();
        };
        
        this.setStatus('idle', '完了');
        this.downloadBtn.disabled = false;
    }
    
    showError(message) {
        this.form.style.display = 'none';
        this.progressSection.style.display = 'none';
        this.completeSection.style.display = 'none';
        this.errorSection.style.display = 'block';
        
        this.errorMessage.textContent = message;
        
        this.setStatus('error', 'エラー');
        this.downloadBtn.disabled = false;
    }
    
    resetForm() {
        this.form.style.display = 'flex';
        this.progressSection.style.display = 'none';
        this.completeSection.style.display = 'none';
        this.errorSection.style.display = 'none';
        
        this.urlInput.value = '';
        this.currentTaskId = null;
        this.lastDownloadParams = null;
        this.clearSavedTask(); // 現在のタスクをクリア（履歴は残る）
        
        this.setStatus('idle', '待機中');
    }
    
    backToForm() {
        // フォームに戻る（URLをクリアして新しいURLを入力可能に）
        this.form.style.display = 'flex';
        this.progressSection.style.display = 'none';
        this.completeSection.style.display = 'none';
        this.errorSection.style.display = 'none';
        
        this.urlInput.value = '';
        this.currentTaskId = null;
        this.clearSavedTask(); // 現在のタスクをクリア（履歴は残る）
        
        this.setStatus('idle', '待機中');
    }
    
    async retryDownload() {
        // 同じパラメータで再試行
        if (this.lastDownloadParams) {
            const { url, format, cookieId } = this.lastDownloadParams;
            
            // フォームの値を復元
            this.urlInput.value = url;
            document.querySelector(`input[name="format"][value="${format}"]`).checked = true;
            
            // 再度ダウンロードを開始
            await this.startDownload(url, format, cookieId);
        } else {
            // パラメータがない場合はフォームに戻る
            this.backToForm();
        }
    }
    
    setStatus(state, text) {
        const indicator = this.statusIndicator;
        indicator.className = 'status-indicator';
        
        if (state === 'active') {
            indicator.classList.add('active');
        } else if (state === 'error') {
            indicator.classList.add('error');
        }
        
        indicator.querySelector('.status-text').textContent = text;
    }
}

// アプリケーションの初期化
document.addEventListener('DOMContentLoaded', () => {
    window.rushiaDL = new RushiaDL();
});
