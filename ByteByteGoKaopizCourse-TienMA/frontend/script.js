// Global variables
let requestStats = {
    total: 0,
    successful: 0,
    failed: 0,
    responseTimes: []
};

let serverEndpoints = [
    'http://localhost:8090/health',
    'http://localhost:8090/api/',
    'http://localhost:8090/api/users'
];

// Initialize the dashboard
document.addEventListener('DOMContentLoaded', function() {
    console.log('Dashboard initialized');
    addLogEntry('info', 'Dashboard initialized successfully');
    checkServerStatus();
    updateStats();
});

// Show/hide loading overlay
function showLoading() {
    document.getElementById('loadingOverlay').classList.add('show');
}

function hideLoading() {
    document.getElementById('loadingOverlay').classList.remove('show');
}

// Add entry to activity log
function addLogEntry(level, message, details = null) {
    const logContainer = document.getElementById('logContainer');
    const timestamp = new Date().toLocaleTimeString();
    
    // Remove placeholder if it exists
    const placeholder = logContainer.querySelector('.log-placeholder');
    if (placeholder) {
        placeholder.remove();
    }
    
    const logEntry = document.createElement('div');
    logEntry.className = 'log-entry fade-in';
    
    let detailsHtml = '';
    if (details) {
        detailsHtml = `<div style="margin-top: 5px; padding-left: 20px; color: #bdc3c7;">${JSON.stringify(details, null, 2)}</div>`;
    }
    
    logEntry.innerHTML = `
        <span class="log-timestamp">[${timestamp}]</span>
        <span class="log-level ${level}">${level.toUpperCase()}</span>
        ${message}
        ${detailsHtml}
    `;
    
    logContainer.insertBefore(logEntry, logContainer.firstChild);
    
    // Limit log entries to prevent memory issues
    const entries = logContainer.querySelectorAll('.log-entry');
    if (entries.length > 50) {
        entries[entries.length - 1].remove();
    }
}

// Clear activity log
function clearLog() {
    const logContainer = document.getElementById('logContainer');
    logContainer.innerHTML = '<div class="log-placeholder">Activity will appear here...</div>';
    addLogEntry('info', 'Activity log cleared');
}

// Update request statistics
function updateStats() {
    document.getElementById('totalRequests').textContent = requestStats.total;
    document.getElementById('successfulRequests').textContent = requestStats.successful;
    document.getElementById('failedRequests').textContent = requestStats.failed;
    
    const avgTime = requestStats.responseTimes.length > 0 
        ? Math.round(requestStats.responseTimes.reduce((a, b) => a + b, 0) / requestStats.responseTimes.length)
        : 0;
    document.getElementById('avgResponseTime').textContent = `${avgTime}ms`;
}

// Make API request with error handling and timing
async function makeApiRequest(url, options = {}) {
    const startTime = performance.now();
    requestStats.total++;
    
    try {
        addLogEntry('info', `Making request to: ${url}`);
        
        const response = await fetch(url, {
            ...options,
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            }
        });
        
        const endTime = performance.now();
        const responseTime = Math.round(endTime - startTime);
        requestStats.responseTimes.push(responseTime);
        
        if (response.ok) {
            requestStats.successful++;
            const data = await response.json();
            addLogEntry('success', `Request successful (${responseTime}ms)`, {
                status: response.status,
                url: url,
                responseTime: `${responseTime}ms`,
                serverInfo: data.server_id || data.served_by || 'unknown'
            });
            updateStats();
            return { success: true, data, responseTime };
        } else {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
    } catch (error) {
        const endTime = performance.now();
        const responseTime = Math.round(endTime - startTime);
        requestStats.failed++;
        addLogEntry('error', `Request failed (${responseTime}ms)`, {
            url: url,
            error: error.message,
            responseTime: `${responseTime}ms`
        });
        updateStats();
        return { success: false, error: error.message, responseTime };
    }
}

// Check server status
async function checkServerStatus() {
    showLoading();
    addLogEntry('info', 'Checking server status...');
    
    const serverGrid = document.getElementById('serverGrid');
    serverGrid.innerHTML = '';
    
    // Test main endpoints
    const endpoints = [
        { name: 'Health Check', url: '/health', icon: 'fas fa-heartbeat' },
        { name: 'Main API', url: '/api/', icon: 'fas fa-home' },
        { name: 'Users API', url: '/api/users', icon: 'fas fa-users' }
    ];
    
    for (let i = 0; i < endpoints.length; i++) {
        const endpoint = endpoints[i];
        const result = await makeApiRequest(`http://localhost:8090${endpoint.url}`);
        
        const serverCard = document.createElement('div');
        serverCard.className = `server-card ${result.success ? 'healthy' : 'unhealthy'} fade-in`;
        
        const statusIcon = result.success ? 'fas fa-check-circle' : 'fas fa-times-circle';
        const statusText = result.success ? 'Online' : 'Offline';
        
        let serverInfo = '';
        if (result.success && result.data) {
            serverInfo = `
                <div class="server-info">
                    <div class="server-detail">
                        <strong>Server ID:</strong><br>
                        ${result.data.server_id || result.data.served_by || 'N/A'}
                    </div>
                    <div class="server-detail">
                        <strong>Hostname:</strong><br>
                        ${result.data.hostname || 'N/A'}
                    </div>
                    <div class="server-detail">
                        <strong>Response Time:</strong><br>
                        ${result.responseTime}ms
                    </div>
                    <div class="server-detail">
                        <strong>Status:</strong><br>
                        ${result.data.status || 'Running'}
                    </div>
                </div>
            `;
        } else {
            serverInfo = `
                <div class="server-info">
                    <div class="server-detail">
                        <strong>Error:</strong><br>
                        ${result.error || 'Unknown error'}
                    </div>
                    <div class="server-detail">
                        <strong>Response Time:</strong><br>
                        ${result.responseTime}ms
                    </div>
                </div>
            `;
        }
        
        serverCard.innerHTML = `
            <h3>
                <i class="${endpoint.icon}"></i>
                ${endpoint.name}
                <span class="status-indicator ${result.success ? 'online' : 'offline'} pulse"></span>
            </h3>
            <div style="display: flex; align-items: center; gap: 10px; margin: 10px 0;">
                <i class="${statusIcon}"></i>
                <strong>${statusText}</strong>
            </div>
            ${serverInfo}
        `;
        
        serverGrid.appendChild(serverCard);
        
        // Add small delay for visual effect
        await new Promise(resolve => setTimeout(resolve, 200));
    }
    
    hideLoading();
    addLogEntry('info', 'Server status check completed');
}

// Load users data
async function loadUsers() {
    showLoading();
    addLogEntry('info', 'Loading users data...');
    
    const result = await makeApiRequest('http://localhost:8090/api/users');
    const dataDisplay = document.getElementById('dataDisplay');
    
    if (result.success) {
        dataDisplay.className = 'data-display has-content';
        dataDisplay.innerHTML = `
            <div class="data-content fade-in">
                <h3>👥 Users Data</h3>
                <hr style="margin: 10px 0;">
                <strong>Served by:</strong> ${result.data.served_by}<br>
                <strong>Hostname:</strong> ${result.data.hostname}<br>
                <strong>Response Time:</strong> ${result.responseTime}ms<br><br>
                <strong>Users:</strong><br>
                ${JSON.stringify(result.data.users, null, 2)}
            </div>
        `;
        addLogEntry('success', 'Users data loaded successfully');
    } else {
        dataDisplay.className = 'data-display';
        dataDisplay.innerHTML = `
            <div class="placeholder">
                <i class="fas fa-exclamation-triangle" style="color: #e74c3c;"></i>
                <p style="color: #e74c3c;">Failed to load users data</p>
                <small>${result.error}</small>
            </div>
        `;
        addLogEntry('error', 'Failed to load users data');
    }
    
    hideLoading();
}

// Test slow endpoint
async function testSlowEndpoint() {
    showLoading();
    addLogEntry('info', 'Testing slow endpoint...');
    
    const result = await makeApiRequest('http://localhost:8090/api/slow');
    const dataDisplay = document.getElementById('dataDisplay');
    
    if (result.success) {
        dataDisplay.className = 'data-display has-content';
        dataDisplay.innerHTML = `
            <div class="data-content fade-in">
                <h3>🐌 Slow Endpoint Response</h3>
                <hr style="margin: 10px 0;">
                <strong>Served by:</strong> ${result.data.served_by}<br>
                <strong>Response Time:</strong> ${result.responseTime}ms<br>
                <strong>Processing Time:</strong> ${result.data.processing_time}<br><br>
                <strong>Message:</strong><br>
                ${result.data.message}
            </div>
        `;
        addLogEntry('success', 'Slow endpoint test completed');
    } else {
        dataDisplay.className = 'data-display';
        dataDisplay.innerHTML = `
            <div class="placeholder">
                <i class="fas fa-exclamation-triangle" style="color: #e74c3c;"></i>
                <p style="color: #e74c3c;">Slow endpoint test failed</p>
                <small>${result.error}</small>
            </div>
        `;
        addLogEntry('error', 'Slow endpoint test failed');
    }
    
    hideLoading();
}

// Load multiple requests to test load balancing
async function loadMultipleRequests() {
    showLoading();
    addLogEntry('info', 'Starting multiple requests test...');
    
    const requests = [];
    const results = [];
    
    // Make 10 concurrent requests
    for (let i = 0; i < 10; i++) {
        requests.push(makeApiRequest('http://localhost:8090/api/'));
    }
    
    try {
        const responses = await Promise.all(requests);
        const dataDisplay = document.getElementById('dataDisplay');
        
        // Count requests per server
        const serverCounts = {};
        responses.forEach(response => {
            if (response.success && response.data.server_id) {
                serverCounts[response.data.server_id] = (serverCounts[response.data.server_id] || 0) + 1;
            }
        });
        
        const successCount = responses.filter(r => r.success).length;
        const avgResponseTime = responses
            .filter(r => r.success)
            .reduce((sum, r) => sum + r.responseTime, 0) / successCount;
        
        dataDisplay.className = 'data-display has-content';
        dataDisplay.innerHTML = `
            <div class="data-content fade-in">
                <h3>⚡ Multiple Requests Test Results</h3>
                <hr style="margin: 10px 0;">
                <strong>Total Requests:</strong> 10<br>
                <strong>Successful:</strong> ${successCount}<br>
                <strong>Failed:</strong> ${10 - successCount}<br>
                <strong>Average Response Time:</strong> ${Math.round(avgResponseTime)}ms<br><br>
                <strong>Load Distribution:</strong><br>
                ${Object.entries(serverCounts)
                    .map(([server, count]) => `${server}: ${count} requests`)
                    .join('<br>')}
            </div>
        `;
        
        addLogEntry('success', 'Multiple requests test completed', {
            totalRequests: 10,
            successful: successCount,
            averageResponseTime: `${Math.round(avgResponseTime)}ms`,
            loadDistribution: serverCounts
        });
    } catch (error) {
        addLogEntry('error', 'Multiple requests test failed', { error: error.message });
    }
    
    hideLoading();
}

// Auto-refresh server status every 30 seconds
setInterval(() => {
    addLogEntry('info', 'Auto-refreshing server status...');
    checkServerStatus();
}, 30000);

// Add keyboard shortcuts
document.addEventListener('keydown', function(e) {
    if (e.ctrlKey || e.metaKey) {
        switch(e.key) {
            case 'r':
                e.preventDefault();
                checkServerStatus();
                break;
            case 'u':
                e.preventDefault();
                loadUsers();
                break;
            case 'l':
                e.preventDefault();
                clearLog();
                break;
        }
    }
});

// Add tooltips for keyboard shortcuts
document.addEventListener('DOMContentLoaded', function() {
    const refreshBtn = document.querySelector('button[onclick="checkServerStatus()"]');
    const usersBtn = document.querySelector('button[onclick="loadUsers()"]');
    const clearBtn = document.querySelector('button[onclick="clearLog()"]');
    
    if (refreshBtn) refreshBtn.title = 'Refresh Status (Ctrl+R)';
    if (usersBtn) usersBtn.title = 'Load Users (Ctrl+U)';
    if (clearBtn) clearBtn.title = 'Clear Log (Ctrl+L)';
});
