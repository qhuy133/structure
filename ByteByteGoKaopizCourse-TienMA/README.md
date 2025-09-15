# Load Balancer Demo with MySQL Master-Slave Replication

## 🚀 Quy trình triển khai đơn giản

### 1. **Khởi động hệ thống (One Command)**
```bash
./start-with-database.sh
```

### 2. **Test hệ thống**
```bash
./test.sh
```

### 3. **Dừng hệ thống**
```bash
docker compose down -v
```

## 🏗️ Kiến trúc hệ thống

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
```

## 📊 Các endpoints API

| Endpoint | Method | Mô tả | Database |
|----------|---------|-------|----------|
| `/health` | GET | Health check | Both |
| `/api/` | GET | Root endpoint | Master |
| `/api/users` | GET | Lấy danh sách users | **Slave** |
| `/api/users` | POST | Tạo user mới | **Master** |
| `/api/products` | GET | Lấy danh sách products | **Slave** |
| `/api/requests-log` | GET | Log các API requests | **Slave** |
| `/api/slow` | GET | Endpoint chậm (test) | Master |

## 🔄 Read/Write Splitting

- **📖 Read Operations**: Tự động route đến MySQL slaves (load balanced)
- **✍️ Write Operations**: Tự động route đến MySQL master
- **⚡ Automatic Failover**: Nếu slave down, fallback sang slave khác

## 📁 Cấu trúc project (đã tối ưu)

```
ByteByteGoKaopizCourse-TienMA/
├── 📁 app/                          # FastAPI application
│   ├── main.py                      # Main app với database integration
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
├── 🗄️ init.sql                      # Master database initialization
├── 🗄️ init-slave.sql                # Slave database initialization
├── 🚀 start-with-database.sh        # Main deployment script
├── ⚙️ setup-replication.sh          # MySQL replication setup
├── 🧪 test.sh                       # Simple testing script
├── 🧪 test-replication.sh           # Replication testing
└── 📖 README.md                     # This file
```

## 💡 Các lệnh hữu ích

### Development:
```bash
# Rebuild containers sau khi sửa code
docker compose up --build

# Xem logs
docker compose logs fastapi_server_1
docker compose logs mysql-master

# Restart service cụ thể
docker compose restart fastapi_server_1
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

# Kiểm tra containers
docker compose ps

# Clean restart
docker compose down -v
./start-with-database.sh
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

### ✅ **Monitoring**
- Real-time dashboard
- Request logging
- Server health monitoring
- Database status tracking

### ✅ **Easy Deployment**
- One-command setup
- Automated replication setup
- Self-healing data sync
- Clean restart capability

## 🔧 Configuration

### Database Credentials:
```
Root Password: rootpassword
Database: loadbalancer_db
User: user / password
Replication User: replicator / replicator_password
```

### Ports:
```
Frontend: http://localhost:8090
MySQL Master: localhost:3306
MySQL Slave1: localhost:3307
MySQL Slave2: localhost:3308
```

## 🚨 Troubleshooting

### Lỗi 502 Bad Gateway:
```bash
# Kiểm tra container status
docker compose ps

# Restart hệ thống
docker compose down -v
./start-with-database.sh
```

### Database Connection Issues:
```bash
# Test kết nối database
docker exec mysql_master mysql -u user -ppassword -e "SELECT 1"

# Rerun replication setup
./setup-replication.sh
```

### Frontend không load:
```bash
# Kiểm tra nginx logs
docker compose logs nginx

# Test direct API
curl http://localhost:8090/api/
```

---

## 🎯 Quick Start Checklist

- [ ] Clone repository
- [ ] Run `./start-with-database.sh`
- [ ] Wait 30-60 seconds for setup completion
- [ ] Run `./test.sh` to verify
- [ ] Open http://localhost:8090 in browser
- [ ] Test các features trên dashboard

**🎉 Enjoy your Load Balancer with MySQL Replication!**
