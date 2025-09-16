# Load Balancer với MySQL Master-Slave Replication

## 📋 Tổng quan

Hệ thống Load Balancer với MySQL Master-Slave Replication demo, bao gồm:
- **1 Master Database** (mysql-master:3306) - Cho write operations
- **2 Slave Databases** (mysql-slave1:3307, mysql-slave2:3308) - Cho read operations  
- **3 Backend Servers** (backend1:3001, backend2:3002, backend3:3003) - Node.js/Express APIs
- **Load Balancer** (nginx:8080) - Phân phối requests
- **Frontend Dashboard** (nginx:80) - Giao diện quản lý và monitoring

## 🏗️ Kiến trúc hệ thống

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │  Load Balancer  │    │  Backend APIs   │
│   (Port 80)     │◄──►│   (Port 8080)   │◄──►│  (Port 3001-3)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌───────────────────────────────┼───────────────────────────────┐
                       │                               │                               │
                ┌─────────────┐                ┌─────────────┐                ┌─────────────┐
                │   Master    │                │   Slave1    │                │   Slave2    │
                │   (3306)    │◄──────────────►│   (3307)    │                │   (3308)    │
                │   WRITE     │   Replication  │   READ      │                │   READ      │
                └─────────────┘                └─────────────┘                └─────────────┘
```

## 🚀 Cài đặt và chạy

### 1. Khởi động hệ thống
```bash
# Start toàn bộ hệ thống
sudo docker compose up -d

# Kiểm tra trạng thái
sudo docker compose ps
```

### 2. Setup MySQL Replication
```bash
# Chạy script setup replication
./setup-replication.sh
```

### 3. Migration Database (nếu cần)
```bash
# Chạy migration để cập nhật schema
./migrate-db.sh
```

## 🌐 Truy cập hệ thống

- **Frontend Dashboard**: http://localhost:80
- **Load Balancer API**: http://localhost:8080
- **Master Database**: localhost:3306
- **Slave1 Database**: localhost:3307
- **Slave2 Database**: localhost:3308

## 📊 Tính năng chính

### Frontend Dashboard
- **Dashboard**: Thống kê tổng quan
- **Servers**: Monitor trạng thái backend servers
- **Replication**: Theo dõi trạng thái master-slave
- **Requests**: Lịch sử requests
- **Analytics**: Kết quả tests và phân tích

### Backend APIs
- `GET /api/server-info` - Thông tin server (WRITE to master)
- `GET /api/stats` - Thống kê requests (READ from slaves)
- `POST /api/requests` - Tạo request mới (WRITE to master)
- `GET /api/requests` - Lấy danh sách requests (READ from slaves)
- `GET /api/replication-status` - Trạng thái replication
- `POST /api/test-replication` - Test replication

### Load Balancing
- **Round-robin** cho backend servers
- **Read/Write separation** cho databases
- **Health checks** cho tất cả services

## 🧪 Testing

### 1. Test Write Operation
```bash
curl -X POST http://localhost:8080/api/requests \
  -H "Content-Type: application/json" \
  -d '{"client_ip": "127.0.0.1", "user_agent": "Test Client"}'
```

### 2. Test Read Operation
```bash
curl http://localhost:8080/api/stats
```

### 3. Test Replication
```bash
curl -X POST http://localhost:8080/api/test-replication
```

### 4. Test Load Balancing
```bash
# Gửi nhiều requests để test load balancing
for i in {1..10}; do
  curl http://localhost:8080/api/server-info
  echo ""
done
```

## 🔧 Cấu hình

### Environment Variables
```yaml
# Backend services
NODE_ENV: production
DB_MASTER_HOST: mysql-master
DB_SLAVE1_HOST: mysql-slave1
DB_SLAVE2_HOST: mysql-slave2
DB_USER: user
DB_PASSWORD: password
DB_NAME: loadbalancer_db
SERVER_ID: 1|2|3
```

### Database Configuration
- **Master**: server-id=1, binary logging, GTID enabled
- **Slave1**: server-id=2, read-only, relay logs
- **Slave2**: server-id=3, read-only, relay logs

## 📁 Cấu trúc thư mục

```
├── backend/                 # Backend API services
│   ├── server.js           # Main server file
│   ├── package.json        # Dependencies
│   └── Dockerfile          # Backend container
├── frontend/               # Frontend dashboard
│   ├── index.html          # Main HTML
│   ├── style.css           # CSS styles
│   ├── script.js           # JavaScript logic
│   ├── nginx.conf          # Frontend nginx config
│   └── Dockerfile          # Frontend container
├── loadbalancer/           # Load balancer
│   ├── nginx.conf          # Load balancer config
│   └── Dockerfile          # Load balancer container
├── mysql/                  # MySQL configurations
│   ├── master/             # Master DB config
│   ├── slave1/             # Slave1 DB config
│   └── slave2/             # Slave2 DB config
├── docker-compose.yml      # Docker orchestration
├── init.sql               # Database initialization
├── setup-replication.sh   # Replication setup script
├── migrate-db.sh          # Database migration script
└── README.md              # This file
```

## 🛠️ Troubleshooting

### 1. Database Connection Issues
```bash
# Kiểm tra trạng thái containers
sudo docker compose ps

# Kiểm tra logs
sudo docker logs mysql_master
sudo docker logs mysql_slave1
sudo docker logs mysql_slave2
```

### 2. Replication Issues
```bash
# Kiểm tra trạng thái replication
sudo docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G"
sudo docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G"
```

### 3. Backend Issues
```bash
# Kiểm tra logs backend
sudo docker logs backend_1
sudo docker logs backend_2
sudo docker logs backend_3

# Test health check
curl http://localhost:8080/health/backend1
```

### 4. Load Balancer Issues
```bash
# Kiểm tra logs load balancer
sudo docker logs nginx_lb

# Test load balancer
curl http://localhost:8080/api/server-info
```

## 🔄 Maintenance

### Restart Services
```bash
# Restart toàn bộ hệ thống
sudo docker compose restart

# Restart specific service
sudo docker compose restart backend1
```

### Clean Up
```bash
# Dừng và xóa containers
sudo docker compose down

# Dừng và xóa containers + volumes
sudo docker compose down -v
```

### Backup Database
```bash
# Backup master database
sudo docker exec mysql_master mysqldump -u root -prootpassword loadbalancer_db > backup.sql
```

## 📈 Monitoring

### Health Checks
- Backend health: `GET /health/backend{1,2,3}`
- Replication status: `GET /api/replication-status`
- Database connections: Hiển thị trong frontend dashboard

### Metrics
- Request count
- Response time
- Success rate
- Database status
- Replication lag
