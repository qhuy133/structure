# Load Balancer Demo with MySQL Master-Slave Replication & Celery Worker

## 🚀 Quy trình triển khai đơn giản

### 1. **Khởi động hệ thống (One Command)**
```bash
# Khởi động toàn bộ hệ thống (Load Balancer + MySQL Replication + Celery Worker)
./start.sh
```

### 2. **Test hệ thống**
```bash
# Test Worker system
./test-worker.sh

# Test MySQL replication
./test-replication.sh
```

### 3. **Dừng hệ thống**
```bash
docker compose down -v
```

## 🏗️ Kiến trúc hệ thống

### Kiến trúc đầy đủ (Load Balancer + Database Replication + Celery Worker)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │  Load Balancer  │    │  FastAPI Apps   │
│   (Nginx)       │    │    (Nginx)      │    │   (3 servers)   │
│   Port: 8090    │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                ▲                      │
                                │                      ▼
                        ┌─────────────────────────────────────────┐
                        │           Database Layer                │
                        │                                         │
                        │  ┌─────────────┐   ┌─────────────────┐  │
                        │  │MySQL Master │   │  MySQL Slave1   │  │
                        │  │  (Write)    │──▶│   (Read)        │  │
                        │  │ Port: 3306  │   │  Port: 3307     │  │
                        │  └─────────────┘   └─────────────────┘  │
                        │          │                              │
                        │          │        ┌─────────────────┐  │
                        │          └───────▶│  MySQL Slave2   │  │
                        │                   │   (Read)        │  │
                        │                   │  Port: 3308     │  │
                        │                   └─────────────────┘  │
                        └─────────────────────────────────────────┘
                                        ▲
                                        │
                        ┌─────────────────────────────────────────┐
                        │           Worker System                │
                        │                                         │
                        │  ┌─────────────┐   ┌─────────────────┐  │
                        │  │    Redis    │   │ Celery Worker   │  │
                        │  │ (Message    │◀──│  (Background    │  │
                        │  │  Broker)    │   │   Tasks)        │  │
                        │  │ Port: 6379  │   │                 │  │
                        │  └─────────────┘   └─────────────────┘  │
                        └─────────────────────────────────────────┘
```

## 📜 Scripts Overview

| Script | Mô tả | Khi nào sử dụng |
|--------|-------|-----------------|
| `start.sh` | **Script chính** - Khởi động toàn bộ hệ thống (Load Balancer + MySQL Replication + Celery Worker) | **Luôn sử dụng** - Khởi động hệ thống đầy đủ |
| `test-worker.sh` | Test worker system và async tasks | Sau khi khởi động hệ thống |
| `test-replication.sh` | Test MySQL replication | Khi cần kiểm tra replication |
| `setup-replication.sh` | Setup MySQL replication (tự động chạy trong start script) | Chỉ chạy thủ công khi cần debug replication |

## 📁 Cấu trúc project

```
ByteByteGoKaopizCourse-TienMA/
├── 📁 app/                          # FastAPI application
│   ├── main.py                      # Main app với database integration
│   ├── celery_app.py                # Celery worker configuration
│   ├── requirements.txt             # Python dependencies
│   └── Dockerfile                   # Docker config cho app
├── 📁 frontend/                     # Frontend dashboard
│   ├── index.html                   # Dashboard UI
│   ├── script.js                    # Frontend logic
│   └── styles.css                   # Styling
├── 📁 nginx/                        # Load balancer config
│   ├── nginx.conf                   # Nginx configuration
│   └── Dockerfile                   # Docker config cho nginx
├── 📁 mysql/                        # Database configurations
│   ├── 📁 master/
│   │   └── my.cnf                   # Master MySQL config
│   ├── 📁 slave1/
│   │   └── my.cnf                   # Slave1 MySQL config
│   ├── 📁 slave2/
│   │   └── my.cnf                   # Slave2 MySQL config
│   └── README.md                    # Database documentation
├── 🐳 docker-compose.yml            # Orchestration file
├── 🗄️ init-schema.sql               # Database schema initialization
├── 🗄️ insert-sample-data.sql        # Sample data for testing
├── 🚀 start.sh                       # Main deployment script (ALL-IN-ONE)
├── ⚙️ setup-replication.sh          # MySQL replication setup
├── 🧪 test-worker.sh                # Worker system testing
├── 🧪 test-replication.sh           # Replication testing
└── 📖 README.md                     # This file
```

## 💡 Các lệnh hữu ích

### Development:
```bash
# Rebuild containers sau khi sửa code
docker compose up --build

# Xem logs
docker compose logs -f                    # Xem tất cả logs
docker compose logs fastapi_server_1      # Xem logs FastAPI
docker compose logs mysql-master          # Xem logs MySQL master
docker compose logs celery_worker         # Xem logs Celery worker

# Restart service cụ thể
docker compose restart fastapi_server_1
docker compose restart celery_worker
```

### Database Management:
```bash
# Kết nối vào MySQL master
docker exec -it mysql_master mysql -u user -ppassword loadbalancer_db

# Kết nối vào MySQL slave
docker exec -it mysql_slave1 mysql -u user -ppassword loadbalancer_db

# Kiểm tra replication status
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G"
```

### Troubleshooting:
```bash
# Test từng endpoint
curl http://localhost:8090/health
curl http://localhost:8090/api/users
curl http://localhost:8090/api/products
curl http://localhost:8090/api/worker/status

# Kiểm tra containers
docker compose ps

# Test worker system
./test-worker.sh

# Test replication
./test-replication.sh

# Clean restart
docker compose down -v
./start.sh
```

## 🎯 Features chính

### ✅ **Load Balancing**
- 3 FastAPI servers với Nginx load balancer
- Round-robin distribution
- Health checks

### ✅ **Database Replication**
- Master-Slave architecture (1:2)
- Automatic read/write splitting
- GTID-based replication
- Data consistency

### ✅ **Celery Worker System**
- Asynchronous task processing
- Redis message broker
- Background product creation
- Task status tracking

### ✅ **Frontend Dashboard**
- Real-time system monitoring
- Interactive API testing
- Worker system controls
- Request logging

## 🔧 API Endpoints

### Core APIs:
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/api/` | Root endpoint |
| GET | `/api/users` | Get users (reads from slave) |
| POST | `/api/users` | Create user (writes to master) |
| GET | `/api/products` | Get products (reads from slave) |
| GET | `/api/requests-log` | Get API requests log |
| GET | `/api/slow` | Slow endpoint for testing |

### Worker APIs:
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/worker/status` | Check worker status |
| POST | `/api/worker/test` | Test worker connection |
| POST | `/api/users/{id}/create-product` | Create product for user (async) |
| GET | `/api/tasks/{task_id}` | Check task status |

## ⚙️ Celery Worker System

### Features:
- **Asynchronous Processing**: Background task execution
- **Redis Integration**: Reliable message broker
- **Product Creation**: Auto-generate products for users
- **Task Tracking**: Monitor task status and results
- **Error Handling**: Retry mechanism with exponential backoff

### Flow:
1. User creates account via API
2. System queues product creation task
3. Celery worker processes task asynchronously
4. Product is created with user-specific details
5. Task status can be tracked via API

### Usage:
```bash
# Test worker system
./test-worker.sh

# Check worker status via API
curl http://localhost:8090/api/worker/status

# Create user and trigger product creation
curl -X POST http://localhost:8090/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# Then create product for user (replace {user_id})
curl -X POST http://localhost:8090/api/users/1/create-product
```

## 🌐 Access Points

```
Frontend: http://localhost:8090
MySQL Master: localhost:3306
MySQL Slave1: localhost:3307
MySQL Slave2: localhost:3308
Redis: localhost:6379
```

## 🚨 Troubleshooting

### Lỗi 502 Bad Gateway:
```bash
# Kiểm tra container status
docker compose ps

# Restart hệ thống
docker compose down -v
./start.sh
```

### Database Connection Issues:
```bash
# Test kết nối database
docker exec mysql_master mysql -u user -ppassword -e "SELECT 1"

# Rerun replication setup
./setup-replication.sh
```

### Worker System Issues:
```bash
# Kiểm tra worker status
curl http://localhost:8090/api/worker/status

# Test worker
./test-worker.sh

# Restart worker
docker compose restart celery_worker
```

### Frontend không load:
```bash
# Kiểm tra nginx logs
docker compose logs nginx

# Restart nginx
docker compose restart nginx
```

## 🎉 Quick Start Guide

1. **Clone và setup:**
   ```bash
   git clone <repository>
   cd ByteByteGoKaopizCourse-TienMA
   ```

2. **Khởi động hệ thống:**
   ```bash
   ./start.sh
   ```

3. **Mở browser:**
   ```
   http://localhost:8090
   ```

4. **Test features:**
   - Click "Test Worker" để test worker system
   - Click "Create User" để tạo user mới
   - Click "Create Product for User" để test async product creation
   - Click "Worker Status" để kiểm tra worker health

5. **Dừng hệ thống:**
   ```bash
   docker compose down -v
   ```

## 📚 Additional Resources

- [WORKER_README.md](./WORKER_README.md) - Chi tiết về Celery Worker System
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Hướng dẫn deployment
- [mysql/README.md](./mysql/README.md) - Database configuration details

---

**🎯 Mục tiêu:** Demo Load Balancer với MySQL Master-Slave Replication và Celery Worker System cho việc xử lý background tasks.