# Backend API Services

## 📋 Tổng quan

Backend API services được xây dựng với Node.js/Express, hỗ trợ MySQL Master-Slave replication với 3 backend servers chạy song song.

## 🏗️ Kiến trúc

```
Backend Server 1 (Port 3001) ──┐
Backend Server 2 (Port 3002) ──┼──► Load Balancer (Port 8080)
Backend Server 3 (Port 3003) ──┘
                                      │
                              ┌───────┼───────┐
                              │       │       │
                        Master DB  Slave1   Slave2
                        (WRITE)   (READ)   (READ)
```

## 🚀 Cài đặt

### 1. Dependencies
```bash
npm install
```

### 2. Environment Variables
```bash
NODE_ENV=production
DB_MASTER_HOST=mysql-master
DB_SLAVE1_HOST=mysql-slave1
DB_SLAVE2_HOST=mysql-slave2
DB_USER=user
DB_PASSWORD=password
DB_NAME=loadbalancer_db
SERVER_ID=1|2|3
```

### 3. Chạy với Docker
```bash
# Build image
docker build -t backend .

# Run container
docker run -p 3000:3000 \
  -e DB_MASTER_HOST=mysql-master \
  -e DB_SLAVE1_HOST=mysql-slave1 \
  -e DB_SLAVE2_HOST=mysql-slave2 \
  -e DB_USER=user \
  -e DB_PASSWORD=password \
  -e DB_NAME=loadbalancer_db \
  -e SERVER_ID=1 \
  backend
```

## 📡 API Endpoints

### Health Check
```http
GET /health
```
**Response:**
```json
{
  "status": "healthy",
  "server_id": "1",
  "master_db": "connected",
  "slave1_db": "connected",
  "slave2_db": "connected",
  "timestamp": "2025-09-16T07:30:55.559Z"
}
```

### Server Info (WRITE to Master)
```http
GET /api/server-info
```
**Response:**
```json
{
  "server_id": "1",
  "timestamp": "2025-09-16T07:30:55.559Z",
  "message": "Request handled by Server 1",
  "client_ip": "::ffff:172.18.0.8",
  "master_db_status": "connected",
  "slave1_db_status": "connected",
  "slave2_db_status": "connected"
}
```

### Statistics (READ from Slaves)
```http
GET /api/stats
```
**Response:**
```json
{
  "server_id": "1",
  "statistics": [
    {"server_id": "1", "request_count": 10},
    {"server_id": "2", "request_count": 8},
    {"server_id": "3", "request_count": 12}
  ],
  "total_requests": 30,
  "read_from": "slave1"
}
```

### Create Request (WRITE to Master)
```http
POST /api/requests
Content-Type: application/json

{
  "client_ip": "127.0.0.1",
  "user_agent": "Test Client"
}
```
**Response:**
```json
{
  "success": true,
  "data": {"id": 123},
  "server_id": "1",
  "written_to": "master"
}
```

### Get Requests (READ from Slaves)
```http
GET /api/requests
```
**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 123,
      "server_id": "1",
      "timestamp": "2025-09-16T07:30:55.000Z",
      "client_ip": "127.0.0.1",
      "user_agent": "Test Client"
    }
  ],
  "server_id": "1",
  "read_from": "slave2"
}
```

### Replication Status
```http
GET /api/replication-status
```
**Response:**
```json
{
  "server_id": "1",
  "master_status": "connected",
  "slaves": [
    {
      "name": "slave1",
      "status": "connected",
      "slave_io_running": "Yes",
      "slave_sql_running": "Yes",
      "seconds_behind_master": "0"
    },
    {
      "name": "slave2",
      "status": "connected",
      "slave_io_running": "Yes",
      "slave_sql_running": "Yes",
      "seconds_behind_master": "0"
    }
  ]
}
```

### Test Replication
```http
POST /api/test-replication
```
**Response:**
```json
{
  "server_id": "1",
  "test_id": "test_1758007951313",
  "write_result": "success",
  "read_results": [
    {
      "slave": "slave1",
      "status": "success",
      "found": true,
      "data": {
        "id": 123,
        "server_id": "test_1758007951313",
        "timestamp": "2025-09-16T07:30:55.000Z",
        "client_ip": "127.0.0.1",
        "user_agent": "Replication Test"
      }
    },
    {
      "slave": "slave2",
      "status": "success",
      "found": true,
      "data": {
        "id": 123,
        "server_id": "test_1758007951313",
        "timestamp": "2025-09-16T07:30:55.000Z",
        "client_ip": "127.0.0.1",
        "user_agent": "Replication Test"
      }
    }
  ]
}
```

## 🔧 Cấu hình Database

### Connection Pool
```javascript
// Master connection (WRITE operations)
masterConnection = await mysql.createConnection({
  host: process.env.DB_MASTER_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  connectTimeout: 10000,
  acquireTimeout: 10000,
  timeout: 10000,
});

// Slave connections (READ operations)
slave1Connection = await mysql.createConnection({...});
slave2Connection = await mysql.createConnection({...});
```

### Round-robin Load Balancing
```javascript
function getNextSlaveConnection() {
  const slaves = [slave1Connection, slave2Connection].filter(conn => conn);
  const selectedSlave = slaves[currentSlaveIndex % slaves.length];
  currentSlaveIndex++;
  return selectedSlave;
}
```

## 🛠️ Development

### Local Development
```bash
# Install dependencies
npm install

# Set environment variables
export DB_MASTER_HOST=localhost
export DB_SLAVE1_HOST=localhost
export DB_SLAVE2_HOST=localhost
export DB_USER=user
export DB_PASSWORD=password
export DB_NAME=loadbalancer_db
export SERVER_ID=1

# Run server
npm start
```

### Testing
```bash
# Test health check
curl http://localhost:3000/health

# Test server info
curl http://localhost:3000/api/server-info

# Test stats
curl http://localhost:3000/api/stats

# Test replication
curl -X POST http://localhost:3000/api/test-replication
```

## 📊 Monitoring

### Health Checks
- Database connections status
- Server health status
- Replication status

### Logging
```javascript
console.log(`Server ${SERVER_ID}: Master DB connected successfully`);
console.log(`Server ${SERVER_ID}: Slave 1 DB connected successfully`);
console.log(`Server ${SERVER_ID}: Slave 2 DB connected successfully`);
```

### Error Handling
```javascript
try {
  // Database operation
} catch (error) {
  console.error(`Server ${SERVER_ID}: Error:`, error);
  res.status(500).json({
    error: "Internal server error",
    server_id: SERVER_ID,
  });
}
```

## 🔄 Graceful Shutdown

```javascript
process.on("SIGTERM", async () => {
  console.log(`Server ${SERVER_ID}: Shutting down gracefully`);
  if (masterConnection) await masterConnection.end();
  if (slave1Connection) await slave1Connection.end();
  if (slave2Connection) await slave2Connection.end();
  process.exit(0);
});
```

## 🐛 Troubleshooting

### Common Issues

1. **Database Connection Failed**
   ```bash
   # Check database status
   docker logs mysql_master
   docker logs mysql_slave1
   docker logs mysql_slave2
   ```

2. **Replication Not Working**
   ```bash
   # Check replication status
   docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G"
   ```

3. **Port Already in Use**
   ```bash
   # Check port usage
   netstat -tulpn | grep :3000
   ```

### Debug Mode
```bash
# Enable debug logging
DEBUG=* npm start
```

## 📈 Performance

### Connection Pooling
- Master: 1 connection (WRITE)
- Slaves: 1 connection each (READ)
- Round-robin distribution

### Timeout Settings
- Connect timeout: 10s
- Acquire timeout: 10s
- Query timeout: 10s

### Retry Logic
- Max retries: 10
- Retry delay: 3s
- Exponential backoff

## 🔒 Security

### Database Security
- Connection encryption
- User authentication
- Read-only slaves

### API Security
- CORS enabled
- Input validation
- Error handling
