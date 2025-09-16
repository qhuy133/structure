# Load Balancer Demo với MySQL Master-Slave Replication

## Mô tả

Đây là một demo về Load Balancer sử dụng Nginx với thuật toán Round Robin kết hợp MySQL Master-Slave Replication. Hệ thống bao gồm:

- **Frontend**: HTML/CSS/JS với Nginx server
- **Backend**: 3 Node.js servers với Express (1 Master, 2 Slaves)
- **Database**: MySQL Master-Slave Replication (1 Master, 2 Slaves)
- **Load Balancer**: Nginx với Round Robin algorithm

## Kiến trúc hệ thống

```
Client → Frontend Nginx (Port 80) → Load Balancer Nginx (Port 8080) → Backend Servers
                                                                    ├── Backend1 (Master) → MySQL Master (Port 3306)
                                                                    ├── Backend2 (Slave1) → MySQL Slave1 (Port 3307)
                                                                    └── Backend3 (Slave2) → MySQL Slave2 (Port 3308)

MySQL Master ←→ MySQL Slave1 (Replication)
MySQL Master ←→ MySQL Slave2 (Replication)
```

## Tính năng Master-Slave Replication

### Database Architecture

- **MySQL Master**: Xử lý tất cả WRITE operations (INSERT, UPDATE, DELETE)
- **MySQL Slave1 & Slave2**: Xử lý READ operations (SELECT)
- **GTID Replication**: Đảm bảo consistency và automatic failover
- **Read-Only Slaves**: Bảo vệ dữ liệu khỏi accidental writes

### Backend Server Roles

- **Tất cả 3 Backend Servers**: Kết nối đến cả MySQL Master và 2 MySQL Slaves
- **WRITE Operations**: Tất cả backends đều ghi vào MySQL Master
- **READ Operations**: Tất cả backends đều đọc từ MySQL Slaves (round-robin)
- **Load Balancing**: Nginx phân phối requests đến các backends theo Round Robin

## Cách sử dụng

### 1. Khởi chạy hệ thống với Master-Slave Replication

```bash
# Khởi động toàn bộ hệ thống với replication
./start-with-replication.sh

# Hoặc khởi động thủ công
docker compose up -d
./setup-replication.sh
```

### 2. Truy cập ứng dụng

- **Frontend**: http://localhost:80
- **Load Balancer**: http://localhost:8080
- **Backend Servers**:
  - Backend1: http://localhost:3001
  - Backend2: http://localhost:3002
  - Backend3: http://localhost:3003
- **MySQL Databases**:
  - Master: localhost:3306
  - Slave1: localhost:3307
  - Slave2: localhost:3308

### 3. Test Master-Slave Replication

```bash
# Test toàn bộ hệ thống
./test-master-slave.sh

# Kiểm tra replication status
./check-replication.sh
```

### 4. Test Load Balancing

1. Mở trình duyệt và truy cập http://localhost
2. Click nút "Send Request" để gửi request
3. Quan sát response để thấy server nào đang xử lý request
4. Gửi nhiều request để thấy Round Robin hoạt động
5. Kiểm tra database để thấy dữ liệu được replicate

## Các tính năng

### Frontend

- Giao diện đẹp với CSS modern
- Button để gửi request
- Hiển thị thông tin server đang xử lý
- Thống kê số lượng request cho mỗi server
- Health check cho từng backend server

### Backend

- 3 servers Node.js với dual database connections
- **Tất cả Backends**: Kết nối đến cả MySQL Master và Slaves
- **WRITE Operations**: Tất cả backends ghi vào MySQL Master
- **READ Operations**: Tất cả backends đọc từ MySQL Slaves (round-robin)
- API endpoints:
  - `/health`: Kiểm tra trạng thái server và database connections
  - `/api/server-info`: Thông tin server và log request (ghi vào Master DB)
  - `/api/stats`: Thống kê requests (đọc từ Slave DBs)
  - `/api/requests`: Lấy danh sách requests (đọc từ Slave DBs)
  - `POST /api/requests`: Tạo request mới (ghi vào Master DB)

### Load Balancer

- Nginx với Round Robin algorithm
- Health check và failover
- Timeout và retry logic

### Database

- **MySQL Master-Slave Replication** với GTID
- **Master**: Xử lý WRITE operations, binary logging
- **Slaves**: READ-only, tự động sync từ Master
- **Replication**: Real-time data synchronization
- **High Availability**: Automatic failover capability
- Tự động khởi tạo schema và setup replication

## Monitoring

### Health Check

- Frontend tự động kiểm tra trạng thái các backend servers
- Cập nhật trạng thái real-time

### Statistics

- Đếm số request cho mỗi server
- Tính phần trăm phân phối tải
- Auto-refresh mỗi 5 giây

## Troubleshooting

### Kiểm tra logs

```bash
# Xem logs của tất cả services
docker compose logs

# Xem logs của service cụ thể
docker compose logs backend1
docker compose logs loadbalancer
```

### Restart services

```bash
# Restart toàn bộ hệ thống
docker compose restart

# Restart service cụ thể
docker compose restart backend1
```

### Clean up

```bash
# Dừng và xóa containers
docker compose down

# Dừng, xóa containers và volumes
docker compose down -v
```

## Cấu trúc thư mục

```
loadbalancer-demo/
├── docker compose.yml
├── init.sql
├── start-with-replication.sh
├── setup-replication.sh
├── check-replication.sh
├── test-master-slave.sh
├── mysql/
│   ├── master/
│   │   └── my.cnf
│   ├── slave1/
│   │   └── my.cnf
│   └── slave2/
│       └── my.cnf
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── index.html
│   ├── style.css
│   └── script.js
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
└── loadbalancer/
    ├── Dockerfile
    └── nginx.conf
```

## Yêu cầu hệ thống

- Docker
- Docker Compose
- ít nhất 4GB RAM (cho MySQL replication)
- Ports 80, 8080, 3001, 3002, 3003, 3306, 3307, 3308 phải available
- jq (cho test scripts)

## Tùy chỉnh

### Thay đổi số lượng backend servers

1. Sửa `docker compose.yml` - thêm/bớt backend services
2. Sửa `loadbalancer/nginx.conf` - cập nhật upstream
3. Sửa `frontend/script.js` - cập nhật server checking logic

### Thay đổi load balancing algorithm

Trong `loadbalancer/nginx.conf`, thay đổi upstream block:

```nginx
upstream backend_servers {
    # Least Connections
    least_conn;
    server backend1:3000;
    server backend2:3000;
    server backend3:3000;
}
```

### Thay đổi database

Sửa environment variables trong `docker compose.yml` và connection string trong `backend/server.js`

