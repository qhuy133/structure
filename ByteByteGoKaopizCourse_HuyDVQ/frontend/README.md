# Frontend Dashboard

## 📋 Tổng quan

Frontend Dashboard là giao diện web hiện đại để quản lý và monitor hệ thống Load Balancer với MySQL Master-Slave replication. Được xây dựng với HTML5, CSS3, và JavaScript vanilla.

## 🎨 Tính năng chính

### Dashboard Tabs
- **Dashboard**: Thống kê tổng quan và quick actions
- **Servers**: Monitor trạng thái backend servers
- **Replication**: Theo dõi trạng thái master-slave databases
- **Requests**: Lịch sử requests và logs
- **Analytics**: Kết quả tests và phân tích hiệu suất

### Real-time Monitoring
- Auto-refresh mỗi 30 giây
- Health checks cho tất cả services
- Database connection status
- Replication status monitoring

### Interactive Testing
- Send Request - Test API calls
- Test Write Operation - Test master database writes
- Test Read Operation - Test slave database reads
- Test Load Balancing - Test request distribution
- Test Replication - Test master-slave replication
- Run All Tests - Chạy tất cả tests

## 🏗️ Cấu trúc

```
frontend/
├── index.html          # Main HTML structure
├── style.css           # CSS styles và responsive design
├── script.js           # JavaScript logic và API calls
├── nginx.conf          # Nginx configuration
├── Dockerfile          # Frontend container
└── README.md           # This file
```

## 🚀 Cài đặt

### 1. Local Development
```bash
# Mở file index.html trong browser
open index.html

# Hoặc sử dụng local server
python -m http.server 8000
# Truy cập: http://localhost:8000
```

### 2. Docker
```bash
# Build image
docker build -t frontend .

# Run container
docker run -p 80:80 frontend
```

### 3. Docker Compose
```bash
# Start với toàn bộ hệ thống
docker compose up -d
# Truy cập: http://localhost:80
```

## 🎯 Sử dụng

### Dashboard Tab
- **Stats Cards**: Hiển thị tổng quan về requests, response time, success rate, database status
- **Quick Actions**: Các nút test nhanh các tính năng
- **Response Panel**: Hiển thị kết quả của các API calls

### Servers Tab
- **Server Cards**: Thông tin chi tiết về từng backend server
- **Health Status**: Trạng thái kết nối database (master, slave1, slave2)
- **Test Buttons**: Test individual servers

### Replication Tab
- **Master Database**: Thông tin master database
- **Slave Databases**: Thông tin slave1 và slave2
- **Replication Status**: IO Running, SQL Running, Seconds Behind Master
- **Test Results**: Kết quả replication tests

### Requests Tab
- **Request History**: Lịch sử các requests đã gửi
- **Request Details**: Method, URL, timestamp, response time, status

### Analytics Tab
- **Test Results**: Kết quả của tất cả tests
- **Export Function**: Xuất kết quả ra file JSON

## 🔧 Cấu hình

### API Endpoints
```javascript
// Cấu hình API endpoints
const API_BASE_URL = ''; // Sử dụng relative URLs

// Health checks
const healthEndpoints = [
  '/health/backend1',
  '/health/backend2', 
  '/health/backend3'
];

// API endpoints
const apiEndpoints = {
  serverInfo: '/api/server-info',
  stats: '/api/stats',
  requests: '/api/requests',
  replicationStatus: '/api/replication-status',
  testReplication: '/api/test-replication'
};
```

### Auto-refresh Settings
```javascript
// Auto-refresh mỗi 30 giây
setInterval(() => {
  checkServerHealth();
  checkReplicationStatus();
  updateStats();
}, 30000);
```

## 🎨 UI Components

### Stats Cards
```html
<div class="stat-card">
  <div class="stat-icon">
    <i class="fas fa-server"></i>
  </div>
  <div class="stat-content">
    <h3 id="totalRequests">0</h3>
    <p>Total Requests</p>
    <span class="stat-change positive">+12%</span>
  </div>
</div>
```

### Action Buttons
```html
<button class="action-btn" onclick="makeRequest()">
  <i class="fas fa-paper-plane"></i>
  <span>Send Request</span>
</button>
```

### Server Cards
```html
<div class="server-card">
  <div class="server-header">
    <h3>Backend Server 1</h3>
    <div class="server-status online">Online</div>
  </div>
  <div class="server-info">
    <div class="info-item">
      <span class="label">Port:</span>
      <span class="value">3001</span>
    </div>
    <!-- More info items -->
  </div>
  <button class="btn btn-sm" onclick="testServer(1)">Test</button>
</div>
```

## 📱 Responsive Design

### Breakpoints
```css
/* Desktop */
@media (min-width: 1024px) {
  .stats-grid {
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  }
}

/* Tablet */
@media (max-width: 1024px) {
  .sidebar {
    transform: translateX(-100%);
  }
  .sidebar.open {
    transform: translateX(0);
  }
}

/* Mobile */
@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: 1fr;
  }
  .action-grid {
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  }
}
```

## 🔄 JavaScript Functions

### Core Functions
```javascript
// Initialize application
function initializeApp()

// Setup event listeners
function setupEventListeners()

// Load/save data from localStorage
function loadSavedData()
function saveData()

// Update statistics display
function updateStats()
```

### API Functions
```javascript
// Check server health
async function checkServerHealth()

// Check replication status
async function checkReplicationStatus()

// Test replication
async function testReplication()

// Make API requests
async function makeRequest()
async function testWriteOperation()
async function testReadOperation()
async function testLoadBalancing()
```

### UI Functions
```javascript
// Tab navigation
function switchTab(tabId)

// Toast notifications
function showToast(message, type)

// Copy/clear response
function copyResponse()
function clearResponse()

// Export results
function exportResults()
```

## 🎨 CSS Features

### Modern Design
- **CSS Variables**: Sử dụng CSS custom properties
- **Flexbox/Grid**: Layout responsive
- **Animations**: Smooth transitions và hover effects
- **Shadows**: Box shadows cho depth
- **Gradients**: Background gradients

### Color Scheme
```css
:root {
  --primary: #6366f1;
  --secondary: #8b5cf6;
  --success: #10b981;
  --warning: #f59e0b;
  --danger: #ef4444;
  --info: #06b6d4;
}
```

### Typography
```css
body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  line-height: 1.6;
}
```

## 📊 Data Management

### LocalStorage
```javascript
// Save data
localStorage.setItem('requestCount', requestCount.toString());
localStorage.setItem('totalResponseTime', totalResponseTime.toString());
localStorage.setItem('successCount', successCount.toString());
localStorage.setItem('testResults', JSON.stringify(testResults));

// Load data
requestCount = parseInt(localStorage.getItem('requestCount')) || 0;
totalResponseTime = parseInt(localStorage.getItem('totalResponseTime')) || 0;
successCount = parseInt(localStorage.getItem('successCount')) || 0;
testResults = JSON.parse(localStorage.getItem('testResults')) || [];
```

### Statistics Tracking
```javascript
// Update statistics
function updateStats() {
  document.getElementById('totalRequests').textContent = requestCount;
  
  const avgResponseTime = requestCount > 0 ? Math.round(totalResponseTime / requestCount) : 0;
  document.getElementById('avgResponseTime').textContent = avgResponseTime + 'ms';
  
  const successRate = requestCount > 0 ? Math.round((successCount / requestCount) * 100) : 100;
  document.getElementById('successRate').textContent = successRate + '%';
}
```

## 🧪 Testing Features

### Test Functions
```javascript
// Test individual server
async function testServer(serverId)

// Test write operation
async function testWriteOperation()

// Test read operation
async function testReadOperation()

// Test load balancing
async function testLoadBalancing()

// Test replication
async function testReplication()

// Run all tests
async function runAllTests()
```

### Test Results Display
```javascript
// Add test result
function addTestResult(testName, status, details)

// Update test results display
function updateTestResults()

// Export results
function exportResults()
```

## 🔔 Notifications

### Toast System
```javascript
function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <i class="fas fa-${getToastIcon(type)}"></i>
    <span>${message}</span>
  `;
  // Auto remove after 3 seconds
  setTimeout(() => toast.remove(), 3000);
}
```

### Status Indicators
```javascript
// Update status indicators
function updateStatusIndicator(status) {
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');
  
  if (status === 'connected') {
    statusDot.className = 'status-dot';
    statusText.textContent = 'Connected';
  } else {
    statusDot.className = 'status-dot offline';
    statusText.textContent = 'Disconnected';
  }
}
```

## 🛠️ Development

### Local Development
```bash
# Clone repository
git clone <repository-url>

# Navigate to frontend directory
cd frontend

# Open in browser
open index.html

# Or use local server
python -m http.server 8000
```

### Debugging
```javascript
// Enable debug logging
console.log('Debug info:', data);

// Check API responses
console.log('API Response:', response);

// Monitor errors
console.error('Error:', error);
```

## 🐛 Troubleshooting

### Common Issues

1. **API Calls Failing**
   ```javascript
   // Check network connectivity
   console.log('API URL:', url);
   
   // Check response status
   if (!response.ok) {
     throw new Error(`HTTP error! status: ${response.status}`);
   }
   ```

2. **Data Not Persisting**
   ```javascript
   // Check localStorage
   console.log('Saved data:', localStorage.getItem('testResults'));
   
   // Clear and reset
   localStorage.clear();
   loadSavedData();
   ```

3. **UI Not Updating**
   ```javascript
   // Force update
   updateStats();
   checkServerHealth();
   checkReplicationStatus();
   ```

### Browser Compatibility
- Chrome 80+
- Firefox 75+
- Safari 13+
- Edge 80+

## 📈 Performance

### Optimization
- **Lazy Loading**: Load data only when needed
- **Debouncing**: Prevent excessive API calls
- **Caching**: Store data in localStorage
- **Efficient DOM**: Minimal DOM manipulation

### Memory Management
```javascript
// Clean up intervals
const intervalId = setInterval(updateStats, 30000);
// Clear when needed
clearInterval(intervalId);

// Remove event listeners
element.removeEventListener('click', handler);
```

## 🔒 Security

### Input Validation
```javascript
// Validate input data
function validateInput(data) {
  if (!data || typeof data !== 'object') {
    throw new Error('Invalid input data');
  }
  return data;
}
```

### XSS Prevention
```javascript
// Sanitize HTML content
function sanitizeHTML(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
```

## 📝 Changelog

### v1.0.0
- Initial release
- Dashboard with 5 tabs
- Real-time monitoring
- Interactive testing
- Responsive design
- LocalStorage persistence

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## 📄 License

MIT License
