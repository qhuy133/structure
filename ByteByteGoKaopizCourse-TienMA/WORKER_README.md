# Celery Worker System Documentation

## Tổng quan

Hệ thống đã được mở rộng với Celery Worker để xử lý các tác vụ bất đồng bộ. Worker sử dụng Redis làm message broker và có thể tạo sản phẩm tự động dựa trên tên user.

## Kiến trúc

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FastAPI App   │───▶│   Redis Queue   │───▶│  Celery Worker  │
│   (3 instances) │    │   (Message      │    │   (Background   │
│                 │    │    Broker)      │    │    Tasks)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                                               │
         ▼                                               ▼
┌─────────────────┐                            ┌─────────────────┐
│   MySQL Master  │                            │   MySQL Master  │
│   (Write Ops)   │                            │   (Write Ops)   │
└─────────────────┘                            └─────────────────┘
         │                                               │
         ▼                                               ▼
┌─────────────────┐                            ┌─────────────────┐
│  MySQL Slaves   │                            │  MySQL Slaves   │
│  (Read Ops)     │                            │  (Read Ops)     │
└─────────────────┘                            └─────────────────┘
```

## Các thành phần mới

### 1. Redis Service
- **Container**: `redis_broker`
- **Port**: 6379
- **Chức năng**: Message broker cho Celery

### 2. Celery Worker
- **Container**: `celery_worker`
- **Chức năng**: Xử lý các task bất đồng bộ
- **Tasks**: 
  - `create_product_from_user`: Tạo sản phẩm dựa trên tên user
  - `test_worker_connection`: Test kết nối worker

### 3. API Endpoints mới

#### Worker Management
- `POST /api/worker/test` - Test worker connection
- `GET /api/worker/status` - Kiểm tra trạng thái worker
- `GET /api/tasks/{task_id}` - Kiểm tra trạng thái task

#### Product Creation
- `POST /api/users/{user_id}/create-product` - Gửi task tạo sản phẩm cho user

## Cách sử dụng

### 1. Khởi động hệ thống

```bash
# Khởi động tất cả services
docker compose up -d

# Kiểm tra trạng thái
docker compose ps
```

### 2. Test qua Web Interface

Truy cập: http://localhost:8090

Các button mới trong dashboard:
- **Test Worker**: Kiểm tra kết nối worker
- **Worker Status**: Xem trạng thái worker và Redis
- **Create Product for User**: Tạo sản phẩm cho user đã chọn

### 3. Test qua API

```bash
# Test worker connection
curl -X POST http://localhost:8090/api/worker/test

# Check worker status
curl http://localhost:8090/api/worker/status

# Create product for user (thay {user_id} bằng ID thực)
curl -X POST http://localhost:8090/api/users/1/create-product

# Check task status (thay {task_id} bằng ID thực)
curl http://localhost:8090/api/tasks/{task_id}
```

### 4. Test tự động

```bash
# Chạy script test tự động
./test-worker.sh
```

## Luồng hoạt động

### Tạo sản phẩm cho user

1. **User gửi request** → FastAPI endpoint `/api/users/{user_id}/create-product`
2. **FastAPI lấy thông tin user** từ database (read từ slave)
3. **FastAPI gửi task** vào Redis queue
4. **Celery Worker nhận task** từ queue
5. **Worker tạo sản phẩm** với thông tin:
   - Tên: "Product for {user_name}"
   - Mô tả: Thông tin user và timestamp
   - Giá: Ngẫu nhiên từ 10.00 đến 1000.00
   - Số lượng: Ngẫu nhiên từ 1 đến 100
   - Danh mục: Ngẫu nhiên từ danh sách có sẵn
6. **Worker lưu sản phẩm** vào database (write vào master)
7. **Worker log task** vào bảng requests
8. **Client có thể check** trạng thái task qua API

## Monitoring và Debugging

### 1. Xem logs

```bash
# Xem logs của tất cả services
docker compose logs -f

# Xem logs của worker
docker compose logs -f celery_worker

# Xem logs của Redis
docker compose logs -f redis
```

### 2. Kiểm tra Redis

```bash
# Kết nối vào Redis container
docker exec -it redis_broker redis-cli

# Xem các key trong Redis
KEYS *

# Xem queue của Celery
LLEN celery

# Xem task trong queue
LRANGE celery 0 -1
```

### 3. Kiểm tra database

```bash
# Kết nối vào MySQL master
docker exec -it mysql_master mysql -u user -p loadbalancer_db

# Xem sản phẩm đã tạo
SELECT * FROM products ORDER BY created_at DESC LIMIT 10;

# Xem log requests từ worker
SELECT * FROM requests WHERE server_id = 'celery-worker' ORDER BY timestamp DESC LIMIT 10;
```

## Cấu hình

### Environment Variables

```yaml
# Redis connection
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0

# Database connection (cho worker)
DB_MASTER_HOST=mysql-master
DB_SLAVE1_HOST=mysql-slave1
DB_SLAVE2_HOST=mysql-slave2
DB_USER=user
DB_PASSWORD=password
DB_NAME=loadbalancer_db
```

### Celery Configuration

File `celery_app.py` chứa cấu hình:
- Broker: Redis
- Backend: Redis
- Task serialization: JSON
- Time limits: 30 minutes
- Retry policy: 3 lần với delay 60 giây

## Troubleshooting

### 1. Worker không hoạt động

```bash
# Kiểm tra worker có chạy không
docker compose ps celery_worker

# Restart worker
docker compose restart celery_worker

# Xem logs chi tiết
docker compose logs celery_worker
```

### 2. Redis connection failed

```bash
# Kiểm tra Redis
docker compose ps redis

# Test Redis connection
docker exec -it redis_broker redis-cli ping
```

### 3. Task không được xử lý

```bash
# Kiểm tra queue
docker exec -it redis_broker redis-cli LLEN celery

# Xem task trong queue
docker exec -it redis_broker redis-cli LRANGE celery 0 -1
```

### 4. Database connection issues

```bash
# Test database connection từ worker
docker exec -it celery_worker python -c "
import pymysql
conn = pymysql.connect(host='mysql-master', user='user', password='password', database='loadbalancer_db')
print('Database connection successful')
conn.close()
"
```

## Mở rộng

### Thêm task mới

1. Thêm task vào `celery_app.py`:

```python
@celery_app.task
def new_task(param1, param2):
    # Task logic here
    return {"status": "success", "result": "..."}
```

2. Thêm endpoint vào `main.py`:

```python
@app.post("/api/new-endpoint")
async def new_endpoint(data: dict):
    task = new_task.delay(data["param1"], data["param2"])
    return {"task_id": task.id, "status": "queued"}
```

3. Restart services:

```bash
docker compose restart
```

### Scale Worker

Để tăng số lượng worker:

```yaml
# Trong docker-compose.yml
celery_worker_2:
  build: ./app
  command: celery -A celery_app worker --loglevel=info
  # ... same environment as celery_worker
```

## Performance

- **Redis**: Có thể xử lý hàng nghìn message/giây
- **Celery Worker**: Có thể xử lý nhiều task đồng thời
- **Database**: Worker sử dụng connection pooling
- **Monitoring**: Tất cả task được log vào database

## Security

- Redis không expose ra ngoài (chỉ internal network)
- Worker chạy trong container riêng biệt
- Database credentials được quản lý qua environment variables
- Task có timeout và retry limits
