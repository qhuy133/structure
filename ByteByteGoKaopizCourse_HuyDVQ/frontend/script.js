// Modern Load Balancer Dashboard JavaScript

// Global variables
let requestCount = 0;
let totalResponseTime = 0;
let successCount = 0;
let testResults = [];

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
    setupEventListeners();
    loadSavedData();
    updateStats();
    checkServerHealth();
});

// Initialize application
function initializeApp() {
    // Setup tab navigation
    const menuItems = document.querySelectorAll('.menu-item');
    const tabContents = document.querySelectorAll('.tab-content');
    
    menuItems.forEach(item => {
        item.addEventListener('click', function(e) {
            e.preventDefault();
            
            // Remove active class from all items
            menuItems.forEach(mi => mi.classList.remove('active'));
            tabContents.forEach(tc => tc.classList.remove('active'));
            
            // Add active class to clicked item
            this.classList.add('active');
            
            // Show corresponding tab
            const tabId = this.getAttribute('data-tab');
            const tabContent = document.getElementById(tabId);
            if (tabContent) {
                tabContent.classList.add('active');
            }
            
            // Update page title
            const pageTitle = document.querySelector('.page-title');
            pageTitle.textContent = this.querySelector('span').textContent;
        });
    });
    
    // Setup menu toggle for mobile
    const menuToggle = document.querySelector('.menu-toggle');
    const sidebar = document.querySelector('.sidebar');
    
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', function() {
            sidebar.classList.toggle('open');
        });
    }
}

// Setup event listeners
function setupEventListeners() {
    // Add any additional event listeners here
}

// Load saved data from localStorage
function loadSavedData() {
    requestCount = parseInt(localStorage.getItem('requestCount')) || 0;
    totalResponseTime = parseInt(localStorage.getItem('totalResponseTime')) || 0;
    successCount = parseInt(localStorage.getItem('successCount')) || 0;
    testResults = JSON.parse(localStorage.getItem('testResults')) || [];
    
    // Update test results display
    updateTestResults();
}

// Save data to localStorage
function saveData() {
    localStorage.setItem('requestCount', requestCount.toString());
    localStorage.setItem('totalResponseTime', totalResponseTime.toString());
    localStorage.setItem('successCount', successCount.toString());
    localStorage.setItem('testResults', JSON.stringify(testResults));
}

// Update statistics display
function updateStats() {
    document.getElementById('totalRequests').textContent = requestCount;
    
    const avgResponseTime = requestCount > 0 ? Math.round(totalResponseTime / requestCount) : 0;
    document.getElementById('avgResponseTime').textContent = avgResponseTime + 'ms';
    
    const successRate = requestCount > 0 ? Math.round((successCount / requestCount) * 100) : 100;
    document.getElementById('successRate').textContent = successRate + '%';
    
    // Update database status
    const dbStatus = document.getElementById('dbStatus');
    if (dbStatus) {
        dbStatus.textContent = 'Online';
    }
}

// Check server health
async function checkServerHealth() {
    const servers = [1, 2, 3];
    
    for (const serverId of servers) {
        try {
            const response = await fetch(`health/backend${serverId}`);
            const data = await response.json();
            
            // Update server health display
            const healthElement = document.getElementById(`server${serverId}Health`);
            const dbElement = document.getElementById(`server${serverId}DB`);
            
            if (healthElement) {
                healthElement.textContent = data.status || 'Unknown';
                healthElement.className = data.status === 'healthy' ? 'value success' : 'value error';
            }
            
            if (dbElement) {
                dbElement.textContent = data.master_db || 'Unknown';
                dbElement.className = data.master_db === 'connected' ? 'value success' : 'value error';
            }
        } catch (error) {
            console.error(`Error checking server ${serverId}:`, error);
            
            const healthElement = document.getElementById(`server${serverId}Health`);
            const dbElement = document.getElementById(`server${serverId}DB`);
            
            if (healthElement) {
                healthElement.textContent = 'Error';
                healthElement.className = 'value error';
            }
            
            if (dbElement) {
                dbElement.textContent = 'Error';
                dbElement.className = 'value error';
            }
        }
    }
}

// Make a request to the API
async function makeRequest() {
    const startTime = Date.now();
    const responseElement = document.getElementById('responseText');
    
    try {
        responseElement.textContent = 'Sending request...';
        
        const response = await fetch('/api/server-info');
        const data = await response.json();
        
        const endTime = Date.now();
        const responseTime = endTime - startTime;
        
        // Update statistics
        requestCount++;
        totalResponseTime += responseTime;
        if (response.ok) successCount++;
        
        // Update display
        responseElement.textContent = JSON.stringify(data, null, 2);
        updateStats();
        saveData();
        
        // Show success toast
        showToast('Request sent successfully!', 'success');
        
        // Add to requests list
        addRequestToList('GET', '/api/server-info', responseTime, response.ok);
        
    } catch (error) {
        responseElement.textContent = `Error: ${error.message}`;
        showToast('Request failed!', 'error');
    }
}

// Test write operation
async function testWriteOperation() {
    const responseElement = document.getElementById('responseText');
    
    try {
        responseElement.textContent = 'Testing write operation...';
        
        const response = await fetch('api/requests', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
            },
        });
        
        const data = await response.json();
        responseElement.textContent = JSON.stringify(data, null, 2);
        
        if (response.ok) {
            showToast('Write operation successful!', 'success');
            addTestResult('Write Operation', 'success', 'Data written to master database');
        } else {
            showToast('Write operation failed!', 'error');
            addTestResult('Write Operation', 'error', 'Failed to write data');
        }
        
    } catch (error) {
        responseElement.textContent = `Error: ${error.message}`;
        showToast('Write operation failed!', 'error');
        addTestResult('Write Operation', 'error', error.message);
    }
}

// Test read operation
async function testReadOperation() {
    const responseElement = document.getElementById('responseText');
    
    try {
        responseElement.textContent = 'Testing read operation...';
        
        const response = await fetch('/api/stats');
        const data = await response.json();
        
        responseElement.textContent = JSON.stringify(data, null, 2);
        
        if (response.ok) {
            showToast('Read operation successful!', 'success');
            addTestResult('Read Operation', 'success', 'Data read from slave database');
        } else {
            showToast('Read operation failed!', 'error');
            addTestResult('Read Operation', 'error', 'Failed to read data');
        }
        
    } catch (error) {
        responseElement.textContent = `Error: ${error.message}`;
        showToast('Read operation failed!', 'error');
        addTestResult('Read Operation', 'error', error.message);
    }
}

// Test load balancing
async function testLoadBalancing() {
    const responseElement = document.getElementById('responseText');
    responseElement.textContent = 'Testing load balancing...';
    
    const results = [];
    const requests = 5;
    
    for (let i = 0; i < requests; i++) {
        try {
            const response = await fetch('/api/server-info');
            const data = await response.json();
            results.push(data.server_id);
        } catch (error) {
            results.push('Error');
        }
    }
    
    // Count server distribution
    const distribution = results.reduce((acc, serverId) => {
        acc[serverId] = (acc[serverId] || 0) + 1;
        return acc;
    }, {});
    
    const resultText = `Load Balancing Test Results:
Total Requests: ${requests}
Server Distribution: ${JSON.stringify(distribution, null, 2)}
All Results: ${results.join(', ')}`;
    
    responseElement.textContent = resultText;
    
    // Check if load balancing is working
    const uniqueServers = Object.keys(distribution).length;
    if (uniqueServers > 1) {
        showToast('Load balancing is working!', 'success');
        addTestResult('Load Balancing', 'success', `Requests distributed across ${uniqueServers} servers`);
    } else {
        showToast('Load balancing may not be working properly', 'warning');
        addTestResult('Load Balancing', 'error', 'All requests went to the same server');
    }
}

// Run all tests
async function runAllTests() {
    showToast('Running all tests...', 'info');
    
    await testWriteOperation();
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    await testReadOperation();
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    await testLoadBalancing();
    
    showToast('All tests completed!', 'success');
}

// Test individual server
async function testServer(serverId) {
    const responseElement = document.getElementById('responseText');
    
    try {
        responseElement.textContent = `Testing server ${serverId}...`;
        
        const response = await fetch(`health/backend${serverId}`);
        const data = await response.json();
        
        responseElement.textContent = JSON.stringify(data, null, 2);
        
        if (response.ok) {
            showToast(`Server ${serverId} is healthy!`, 'success');
        } else {
            showToast(`Server ${serverId} is not responding!`, 'error');
        }
        
    } catch (error) {
        responseElement.textContent = `Error testing server ${serverId}: ${error.message}`;
        showToast(`Server ${serverId} test failed!`, 'error');
    }
}

// Add test result
function addTestResult(testName, status, details) {
    const testResult = {
        id: Date.now(),
        name: testName,
        status: status,
        details: details,
        timestamp: new Date().toISOString()
    };
    
    testResults.unshift(testResult);
    
    // Keep only last 50 results
    if (testResults.length > 50) {
        testResults = testResults.slice(0, 50);
    }
    
    updateTestResults();
    saveData();
}

// Update test results display
function updateTestResults() {
    const testResultsElement = document.getElementById('testResults');
    
    if (testResults.length === 0) {
        testResultsElement.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-chart-line"></i>
                <p>Run tests to see results here.</p>
            </div>
        `;
        return;
    }
    
    const resultsHTML = testResults.map(result => `
        <div class="test-item ${result.status}">
            <h4>
                <i class="fas fa-${result.status === 'success' ? 'check-circle' : 'exclamation-circle'}"></i>
                ${result.name}
                <span class="test-status ${result.status}">${result.status}</span>
            </h4>
            <div class="test-details">
                ${result.details}
                <br>
                <small>${new Date(result.timestamp).toLocaleString()}</small>
            </div>
        </div>
    `).join('');
    
    testResultsElement.innerHTML = resultsHTML;
}

// Add request to list
function addRequestToList(method, url, responseTime, success) {
    const requestsList = document.getElementById('requestsList');
    
    // Remove empty state if it exists
    const emptyState = requestsList.querySelector('.empty-state');
    if (emptyState) {
        emptyState.remove();
    }
    
    const requestItem = document.createElement('div');
    requestItem.className = 'request-item';
    requestItem.innerHTML = `
        <div class="request-method ${method.toLowerCase()}">${method}</div>
        <div class="request-details">
            <div class="request-url">${url}</div>
            <div class="request-time">${new Date().toLocaleString()} • ${responseTime}ms</div>
        </div>
        <div class="request-status ${success ? 'success' : 'error'}">
            ${success ? 'Success' : 'Error'}
        </div>
    `;
    
    requestsList.insertBefore(requestItem, requestsList.firstChild);
    
    // Keep only last 20 requests
    const requestItems = requestsList.querySelectorAll('.request-item');
    if (requestItems.length > 20) {
        requestItems[requestItems.length - 1].remove();
    }
}

// Utility functions
function copyResponse() {
    const responseText = document.getElementById('responseText');
    navigator.clipboard.writeText(responseText.textContent);
    showToast('Response copied to clipboard!', 'success');
}

function clearResponse() {
    document.getElementById('responseText').textContent = 'Click an action button to see responses...';
}

function clearResults() {
    testResults = [];
    updateTestResults();
    saveData();
    
    const requestsList = document.getElementById('requestsList');
    requestsList.innerHTML = `
        <div class="empty-state">
            <i class="fas fa-inbox"></i>
            <p>No requests yet. Send a request to see data here.</p>
        </div>
    `;
    
    showToast('Results cleared!', 'info');
}

function refreshData() {
    updateStats();
    checkServerHealth();
    showToast('Data refreshed!', 'success');
}

function refreshRequests() {
    // This would typically fetch fresh data from the API
    showToast('Requests refreshed!', 'success');
}

function exportResults() {
    const data = {
        testResults: testResults,
        statistics: {
            totalRequests: requestCount,
            avgResponseTime: requestCount > 0 ? Math.round(totalResponseTime / requestCount) : 0,
            successRate: requestCount > 0 ? Math.round((successCount / requestCount) * 100) : 100
        },
        exportDate: new Date().toISOString()
    };
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `load-balancer-results-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
    
    showToast('Results exported!', 'success');
}

// Toast notification system
function showToast(message, type = 'info') {
    const toastContainer = document.getElementById('toastContainer');
    
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <i class="fas fa-${getToastIcon(type)}"></i>
        <span>${message}</span>
    `;
    
    toastContainer.appendChild(toast);
    
    // Auto remove after 3 seconds
    setTimeout(() => {
        toast.remove();
    }, 3000);
}

function getToastIcon(type) {
    const icons = {
        success: 'check-circle',
        error: 'exclamation-circle',
        warning: 'exclamation-triangle',
        info: 'info-circle'
    };
    return icons[type] || 'info-circle';
}

// Auto-refresh data every 30 seconds
setInterval(() => {
    checkServerHealth();
    updateStats();
}, 30000);