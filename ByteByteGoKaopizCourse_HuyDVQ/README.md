# Load Balancer Demo với Docker

## Mô tả
Đây là một demo về Load Balancer sử dụng Nginx với thuật toán Round Robin để phân phối tải cho 3 backend servers Node.js. Hệ thống bao gồm:

- **Frontend**: HTML/CSS/JS với Nginx server
- **Backend**: 3 Node.js servers với Express
- **Database**: MySQL để lưu trữ thông tin requests
- **Load Balancer**: Nginx với Round Robin algorithm

## Kiến trúc hệ thống

```
Client → Frontend Nginx (Port 80) → Load Balancer Nginx (Port 8080) → Backend Servers (Port 3001, 3002, 3003)
                                                                    ↓
                                                              MySQL Database
```

## Cách sử dụng

### 1. Khởi chạy hệ thống
```bash
docker compose up --build
```

### 2. Truy cập ứng dụng
- **Frontend**: http://localhost:80
- **Load Balancer**: http://localhost:8080
- **Backend Servers**: 
  - Server 1: http://localhost:3001
  - Server 2: http://localhost:3002
  - Server 3: http://localhost:3003

### 3. Test Load Balancing
1. Mở trình duyệt và truy cập http://localhost
2. Click nút "Send Request" để gửi request
3. Quan sát response để thấy server nào đang xử lý request
4. Gửi nhiều request để thấy Round Robin hoạt động

## Các tính năng

### Frontend
- Giao diện đẹp với CSS modern
- Button để gửi request
- Hiển thị thông tin server đang xử lý
- Thống kê số lượng request cho mỗi server
- Health check cho từng backend server

### Backend
- 3 servers Node.js độc lập
- API endpoints:
  - `/health`: Kiểm tra trạng thái server
  - `/api/server-info`: Thông tin server và log request
  - `/api/stats`: Thống kê requests

### Load Balancer
- Nginx với Round Robin algorithm
- Health check và failover
- Timeout và retry logic

### Database
- MySQL để lưu trữ request logs
- Tự động khởi tạo schema

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
- ít nhất 2GB RAM
- Ports 80, 8080, 3001, 3002, 3003, 3306 phải available

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

