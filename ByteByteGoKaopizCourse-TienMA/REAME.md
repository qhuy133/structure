# Hướng dẫn xây dựng Load Balancer với Nginx và FastAPI

## Tổng quan

Load Balancer là một thành phần quan trọng trong kiến trúc hệ thống giúp phân phối tải đều đặn cho các server backend. Trong hướng dẫn này, chúng ta sẽ sử dụng Nginx làm load balancer và FastAPI để tạo các API server.

## Kiến trúc hệ thống

```
Client Browser
      ↓
  Nginx Load Balancer (Port 8090)
      ↓
┌─────────────────────────────┐
│ Frontend Dashboard (Static) │
│ API Endpoints (/api/*)      │
└─────────────────────────────┘
      ↓
┌─────────────────────────────┐
│ FastAPI Server 1 (Internal) │
│ FastAPI Server 2 (Internal) │
│ FastAPI Server 3 (Internal) │
└─────────────────────────────┘
```

## Cấu trúc thư mục dự án

```
load-balancer-demo/
├── app/
│   ├── main.py              # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   └── Dockerfile          # Docker cho FastAPI
├── frontend/
│   ├── index.html          # Frontend Dashboard
│   ├── styles.css          # CSS styling
│   └── script.js           # JavaScript functionality
├── nginx/
│   ├── nginx.conf          # Cấu hình Nginx
│   └── Dockerfile          # Docker cho Nginx
├── docker-compose.yml      # Orchestration
├── test_load_balancer.py   # Script test
├── start_with_frontend.sh  # Script khởi động với frontend
└── README.md              # Hướng dẫn này
```

## Bước 1: Tạo FastAPI Application

### 1.1 Tạo ứng dụng FastAPI cơ bản

```python
# app/main.py
from fastapi import FastAPI
import os
import socket
import time
from datetime import datetime

app = FastAPI(title="Load Balancer Demo API")

# Lấy thông tin server
SERVER_ID = os.getenv("SERVER_ID", "unknown")
HOSTNAME = socket.gethostname()

@app.get("/")
async def root():
    return {
        "message": "Hello from Load Balancer Demo!",
        "server_id": SERVER_ID,
        "hostname": HOSTNAME,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "server_id": SERVER_ID,
        "hostname": HOSTNAME
    }

@app.get("/api/users")
async def get_users():
    # Giả lập data users
    users = [
        {"id": 1, "name": "John Doe", "email": "john@example.com"},
        {"id": 2, "name": "Jane Smith", "email": "jane@example.com"},
        {"id": 3, "name": "Bob Johnson", "email": "bob@example.com"}
    ]
    return {
        "users": users,
        "served_by": SERVER_ID,
        "hostname": HOSTNAME
    }

@app.get("/api/slow")
async def slow_endpoint():
    # Endpoint chậm để test load balancing
    import asyncio
    await asyncio.sleep(2)
    return {
        "message": "This is a slow endpoint",
        "served_by": SERVER_ID,
        "processing_time": "2 seconds"
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
```

### 1.2 Requirements cho Python

```txt
# app/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
```

## Bước 2: Cấu hình Nginx Load Balancer

### 2.1 Tạo file cấu hình Nginx

```nginx
# nginx/nginx.conf
events {
    worker_connections 1024;
}

http {
    # Định nghĩa upstream backend servers
    upstream fastapi_backend {
        # Các thuật toán load balancing có thể sử dụng:
        # - round_robin (mặc định)
        # - least_conn
        # - ip_hash
        # - weighted round_robin
        
        least_conn;  # Sử dụng thuật toán least connections
        
        server fastapi_server_1:8000 weight=1 max_fails=3 fail_timeout=30s;
        server fastapi_server_2:8000 weight=1 max_fails=3 fail_timeout=30s;
        server fastapi_server_3:8000 weight=1 max_fails=3 fail_timeout=30s;
    }

    # Cấu hình server
    server {
        listen 80;
        server_name localhost;

        # Logging
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        # Health check endpoint cho Nginx
        location /nginx-health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Proxy tất cả requests đến backend
        location / {
            proxy_pass http://fastapi_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeout settings
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
            
            # Retry logic
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
            proxy_next_upstream_tries 3;
            proxy_next_upstream_timeout 10s;
        }

        # Status page để monitor
        location /nginx-status {
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            allow 172.0.0.0/8;  # Docker networks
            deny all;
        }
    }
}
```

## Bước 3: Docker Configuration

### 3.1 Dockerfile cho FastAPI

```dockerfile
# app/Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 3.2 Dockerfile cho Nginx

```dockerfile
# nginx/Dockerfile
FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### 3.3 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  # Nginx Load Balancer
  nginx:
    build: ./nginx
    ports:
      - "80:80"
    depends_on:
      - fastapi_server_1
      - fastapi_server_2
      - fastapi_server_3
    networks:
      - load_balancer_network

  # FastAPI Server 1
  fastapi_server_1:
    build: ./app
    environment:
      - SERVER_ID=server-1
      - PORT=8000
    expose:
      - "8000"
    networks:
      - load_balancer_network

  # FastAPI Server 2
  fastapi_server_2:
    build: ./app
    environment:
      - SERVER_ID=server-2
      - PORT=8000
    expose:
      - "8000"
    networks:
      - load_balancer_network

  # FastAPI Server 3
  fastapi_server_3:
    build: ./app
    environment:
      - SERVER_ID=server-3
      - PORT=8000
    expose:
      - "8000"
    networks:
      - load_balancer_network

networks:
  load_balancer_network:
    driver: bridge
```

## Bước 4: Testing và Monitoring

### 4.1 Script test load balancer

```python
# test_load_balancer.py
import requests
import time
import asyncio
import aiohttp
from collections import Counter
import concurrent.futures

def test_basic_load_balancing():
    """Test cơ bản để kiểm tra load balancing"""
    print("=== Testing Basic Load Balancing ===")
    
    servers_hit = []
    
    for i in range(15):
        try:
            response = requests.get("http://localhost/", timeout=5)
            if response.status_code == 200:
                data = response.json()
                server_id = data.get("server_id", "unknown")
                servers_hit.append(server_id)
                print(f"Request {i+1}: {server_id}")
            time.sleep(0.1)
        except Exception as e:
            print(f"Request {i+1} failed: {e}")
    
    # Thống kê phân phối requests
    counter = Counter(servers_hit)
    print(f"\nDistribution: {dict(counter)}")
    
    return counter

def test_concurrent_requests():
    """Test với nhiều requests đồng thời"""
    print("\n=== Testing Concurrent Requests ===")
    
    def make_request():
        try:
            response = requests.get("http://localhost/api/users", timeout=10)
            if response.status_code == 200:
                return response.json().get("served_by", "unknown")
        except:
            return "failed"
    
    # Gửi 50 requests đồng thời
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(make_request) for _ in range(50)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    
    counter = Counter(results)
    print(f"Concurrent requests distribution: {dict(counter)}")
    
    return counter

def test_server_failure_simulation():
    """Test khi một server fail"""
    print("\n=== Testing Server Failure Handling ===")
    print("Manually stop one container with: docker compose stop fastapi_server_1")
    print("Then run this test again to see failover behavior")
    
    test_basic_load_balancing()

def test_health_checks():
    """Test health check endpoints"""
    print("\n=== Testing Health Checks ===")
    
    try:
        # Test Nginx health
        response = requests.get("http://localhost/nginx-health")
        print(f"Nginx health: {response.status_code} - {response.text.strip()}")
        
        # Test application health
        response = requests.get("http://localhost/health")
        if response.status_code == 200:
            data = response.json()
            print(f"App health: {data}")
    except Exception as e:
        print(f"Health check failed: {e}")

if __name__ == "__main__":
    print("Load Balancer Testing Script")
    print("=" * 40)
    
    # Chờ hệ thống khởi động
    print("Waiting for services to start...")
    time.sleep(5)
    
    test_health_checks()
    test_basic_load_balancing()
    test_concurrent_requests()
    test_server_failure_simulation()
```

## Bước 5: Các thuật toán Load Balancing

### 5.1 Round Robin (Mặc định)
```nginx
upstream fastapi_backend {
    server fastapi_server_1:8000;
    server fastapi_server_2:8000;
    server fastapi_server_3:8000;
}
```

### 5.2 Least Connections
```nginx
upstream fastapi_backend {
    least_conn;
    server fastapi_server_1:8000;
    server fastapi_server_2:8000;
    server fastapi_server_3:8000;
}
```

### 5.3 IP Hash (Session Persistence)
```nginx
upstream fastapi_backend {
    ip_hash;
    server fastapi_server_1:8000;
    server fastapi_server_2:8000;
    server fastapi_server_3:8000;
}
```

### 5.4 Weighted Round Robin
```nginx
upstream fastapi_backend {
    server fastapi_server_1:8000 weight=3;
    server fastapi_server_2:8000 weight=2;
    server fastapi_server_3:8000 weight=1;
}
```

## Bước 6: Chạy hệ thống

### 6.1 Khởi động tất cả services
```bash
# Tạo thư mục dự án
mkdir load-balancer-demo
cd load-balancer-demo

# Tạo cấu trúc thư mục
mkdir app nginx

# Copy các files đã tạo vào đúng vị trí

# Build và chạy
docker compose up --build
```

### 6.2 Test hệ thống
```bash
# Test cơ bản
curl http://localhost/

# Test API endpoint
curl http://localhost/api/users

# Test health check
curl http://localhost/health

# Chạy script test
python test_load_balancer.py
```

### 6.3 Monitor hệ thống
```bash
# Xem logs
docker compose logs -f nginx
docker compose logs -f fastapi_server_1

# Check Nginx status
curl http://localhost/nginx-status

# Monitor container resources
docker stats
```

## Bước 7: Tối ưu hóa và Best Practices

### 7.1 Health Checks nâng cao
```nginx
# Trong nginx.conf, thêm health check cho upstream
upstream fastapi_backend {
    least_conn;
    server fastapi_server_1:8000 max_fails=3 fail_timeout=30s;
    server fastapi_server_2:8000 max_fails=3 fail_timeout=30s;
    server fastapi_server_3:8000 max_fails=3 fail_timeout=30s;
    
    # Backup server
    server fastapi_server_backup:8000 backup;
}
```

### 7.2 SSL/TLS Termination
```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://fastapi_backend;
        # ... other proxy settings
    }
}
```

### 7.3 Rate Limiting
```nginx
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    server {
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://fastapi_backend;
        }
    }
}
```

### 7.4 Caching
```nginx
http {
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=10g inactive=60m;
    
    server {
        location /api/users {
            proxy_cache api_cache;
            proxy_cache_valid 200 5m;
            proxy_pass http://fastapi_backend;
        }
    }
}
```

## Troubleshooting

### Các lỗi thường gặp:

1. **502 Bad Gateway**: Backend servers không available
   - Check xem các FastAPI containers có chạy không
   - Verify network connectivity

2. **Connection refused**: Port conflicts
   - Check port 80 có bị chiếm không
   - Sử dụng `docker compose ps` để check status

3. **Uneven load distribution**: 
   - Check thuật toán load balancing
   - Verify server weights

### Debug commands:
```bash
# Check containers
docker compose ps

# View logs
docker compose logs [service_name]

# Test connectivity
docker compose exec nginx ping fastapi_server_1

# Check Nginx config
docker compose exec nginx nginx -t
```

## Frontend Dashboard

Dự án bao gồm một giao diện web hiện đại để monitor và test hệ thống load balancer.

### Tính năng Frontend

1. **Server Status Monitor**
   - Hiển thị trạng thái real-time của các backend servers
   - Thông tin chi tiết về server ID, hostname, response time
   - Status indicators với màu sắc trực quan

2. **Data Loading Interface**
   - Button load dữ liệu users từ API
   - Test slow endpoint để kiểm tra performance
   - Multiple requests test để kiểm tra load balancing

3. **Request Statistics**
   - Tracking tổng số requests
   - Tỷ lệ successful/failed requests
   - Average response time

4. **Activity Log**
   - Real-time logging của tất cả hoạt động
   - Thông tin chi tiết về requests và responses
   - Timestamp và log levels

### Cách sử dụng Frontend

1. **Khởi động với Frontend**
```bash
# Sử dụng script khởi động mới
./start_with_frontend.sh

# Hoặc sử dụng docker-compose trực tiếp
docker-compose up --build
```

2. **Truy cập Dashboard**
```
Mở browser và truy cập: http://localhost:8090
```

3. **Keyboard Shortcuts**
- `Ctrl + R`: Refresh server status
- `Ctrl + U`: Load users data
- `Ctrl + L`: Clear activity log

### Endpoints

- **Frontend Dashboard**: `http://localhost:8090`
- **API Health Check**: `http://localhost:8090/health`
- **Users API**: `http://localhost:8090/api/users`
- **Slow Endpoint**: `http://localhost:8090/api/slow`
- **Nginx Status**: `http://localhost:8090/nginx-status`

### Features Highlights

1. **Responsive Design**: Giao diện tự động điều chỉnh cho mobile và desktop
2. **Real-time Updates**: Auto-refresh server status mỗi 30 giây
3. **Modern UI**: Sử dụng gradients, animations, và glassmorphism design
4. **CORS Support**: Full CORS configuration cho cross-origin requests
5. **Error Handling**: Comprehensive error handling và user feedback

## Kết luận

Hướng dẫn này đã cung cấp một hệ thống load balancer hoàn chỉnh với:
- **Frontend Dashboard** hiện đại để monitoring và testing
- Nginx làm reverse proxy và load balancer
- Multiple FastAPI servers làm backend
- Docker containerization
- Health checks và monitoring
- Testing scripts
- Các thuật toán load balancing khác nhau
- **CORS support** cho frontend integration

Hệ thống này có thể được mở rộng và tùy chỉnh theo nhu cầu cụ thể của dự án. Frontend dashboard cung cấp một cách trực quan và dễ sử dụng để monitor và test load balancer performance.
