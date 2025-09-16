# Load Balancer (Nginx)

## 📋 Tổng quan

Load Balancer sử dụng Nginx để phân phối requests giữa 3 backend servers và cung cấp các API endpoints cho health checks và monitoring.

## 🏗️ Kiến trúc

```
Client Requests
      │
      ▼
┌─────────────────┐
│  Load Balancer  │
│   (Port 8080)   │
└─────────────────┘
      │
      ▼
┌─────┬─────┬─────┐
│ B1  │ B2  │ B3  │
│3001 │3002 │3003 │
└─────┴─────┴─────┘
```

## 🚀 Cài đặt

### 1. Docker
```bash
# Build image
docker build -t loadbalancer .

# Run container
docker run -p 8080:8080 loadbalancer
```

### 2. Docker Compose
```bash
# Start với toàn bộ hệ thống
docker compose up -d
```

## ⚙️ Cấu hình

### Nginx Configuration
```nginx
# Load balancer upstream
upstream backend_servers {
    server backend1:3000;
    server backend2:3000;
    server backend3:3000;
}

# Health check upstreams
upstream backend1 { server backend1:3000; }
upstream backend2 { server backend2:3000; }
upstream backend3 { server backend3:3000; }
```

### Port Configuration
```nginx
server {
    listen 8080;
    server_name localhost;
    
    # API endpoints
    location /api/ {
        proxy_pass http://backend_servers;
        # ... proxy settings
    }
    
    # Health checks
    location ~ ^/health/backend([1-3])$ {
        proxy_pass http://backend$1:3000/health;
        # ... proxy settings
    }
}
```

## 📡 API Endpoints

### Health Checks
```http
GET /health/backend1
GET /health/backend2
GET /health/backend3
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

### API Proxying
```http
GET /api/server-info
GET /api/stats
POST /api/requests
GET /api/requests
GET /api/replication-status
POST /api/test-replication
```

**Load Balancing:**
- Round-robin distribution
- Health check integration
- Failover support

## 🔧 Cấu hình chi tiết

### Upstream Configuration
```nginx
upstream backend_servers {
    # Backend servers
    server backend1:3000 weight=1 max_fails=3 fail_timeout=30s;
    server backend2:3000 weight=1 max_fails=3 fail_timeout=30s;
    server backend3:3000 weight=1 max_fails=3 fail_timeout=30s;
    
    # Load balancing method
    # least_conn;  # Least connections
    # ip_hash;     # IP hash
    # round_robin; # Round robin (default)
}
```

### Proxy Settings
```nginx
location /api/ {
    proxy_pass http://backend_servers;
    
    # Headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Timeouts
    proxy_connect_timeout 5s;
    proxy_send_timeout 10s;
    proxy_read_timeout 10s;
    
    # Buffering
    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    
    # CORS
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range";
}
```

### Health Check Configuration
```nginx
location ~ ^/health/backend([1-3])$ {
    proxy_pass http://backend$1:3000/health;
    
    # Headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Timeouts
    proxy_connect_timeout 5s;
    proxy_send_timeout 10s;
    proxy_read_timeout 10s;
    
    # Error handling
    proxy_intercept_errors on;
    error_page 502 503 504 = @backend_error;
    
    # CORS
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods "GET, OPTIONS";
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range";
}
```

### Error Handling
```nginx
# Error handling for backend failures
location @backend_error {
    return 503 '{"error": "Backend service unavailable", "status": "unhealthy"}';
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
}
```

## 🏥 Health Monitoring

### Health Check Features
- **Individual Server Checks**: `/health/backend{1,2,3}`
- **Error Handling**: Graceful degradation
- **CORS Support**: Cross-origin requests
- **JSON Responses**: Structured error messages

### Monitoring Integration
```bash
# Check load balancer status
curl http://localhost:8080/health/backend1

# Check all backends
for i in {1..3}; do
  echo "Backend $i:"
  curl -s http://localhost:8080/health/backend$i | jq .
done
```

## 🔄 Load Balancing

### Round-robin Algorithm
```nginx
upstream backend_servers {
    server backend1:3000;
    server backend2:3000;
    server backend3:3000;
    # Default: round_robin
}
```

### Weighted Round-robin
```nginx
upstream backend_servers {
    server backend1:3000 weight=3;
    server backend2:3000 weight=2;
    server backend3:3000 weight=1;
}
```

### Least Connections
```nginx
upstream backend_servers {
    least_conn;
    server backend1:3000;
    server backend2:3000;
    server backend3:3000;
}
```

### IP Hash
```nginx
upstream backend_servers {
    ip_hash;
    server backend1:3000;
    server backend2:3000;
    server backend3:3000;
}
```

## 🛠️ Development

### Local Development
```bash
# Install Nginx
sudo apt-get install nginx

# Copy configuration
sudo cp nginx.conf /etc/nginx/sites-available/loadbalancer
sudo ln -s /etc/nginx/sites-available/loadbalancer /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### Docker Development
```bash
# Build image
docker build -t loadbalancer .

# Run with custom config
docker run -p 8080:8080 \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf \
  loadbalancer

# Debug mode
docker run -p 8080:8080 \
  --name nginx-debug \
  loadbalancer nginx -g "daemon off;"
```

## 🧪 Testing

### Load Balancer Tests
```bash
# Test API proxying
curl http://localhost:8080/api/server-info

# Test health checks
curl http://localhost:8080/health/backend1

# Test load balancing
for i in {1..10}; do
  curl -s http://localhost:8080/api/server-info | jq .server_id
done
```

### Load Testing
```bash
# Using Apache Bench
ab -n 1000 -c 10 http://localhost:8080/api/server-info

# Using curl in loop
for i in {1..100}; do
  curl -s http://localhost:8080/api/server-info > /dev/null &
done
wait
```

### Health Check Testing
```bash
# Test individual backends
curl -I http://localhost:8080/health/backend1
curl -I http://localhost:8080/health/backend2
curl -I http://localhost:8080/health/backend3

# Test error handling
curl http://localhost:8080/health/backend999
```

## 📊 Monitoring

### Nginx Status
```nginx
# Enable status module
location /nginx_status {
    stub_status on;
    access_log off;
    allow 127.0.0.1;
    deny all;
}
```

### Access Logs
```nginx
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for" '
                'rt=$request_time uct="$upstream_connect_time" '
                'uht="$upstream_header_time" urt="$upstream_response_time"';

access_log /var/log/nginx/access.log main;
```

### Error Logs
```nginx
error_log /var/log/nginx/error.log warn;
```

## 🔧 Troubleshooting

### Common Issues

1. **502 Bad Gateway**
   ```bash
   # Check backend services
   docker ps | grep backend
   
   # Check Nginx logs
   docker logs nginx_lb
   
   # Test backend directly
   curl http://backend1:3000/health
   ```

2. **CORS Issues**
   ```bash
   # Check CORS headers
   curl -H "Origin: http://localhost" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: X-Requested-With" \
        -X OPTIONS \
        http://localhost:8080/api/server-info
   ```

3. **Health Check Failures**
   ```bash
   # Check regex pattern
   echo "test" | grep -E "^/health/backend([1-3])$"
   
   # Test individual health checks
   curl http://localhost:8080/health/backend1
   ```

### Debug Commands
```bash
# Check Nginx configuration
docker exec nginx_lb nginx -t

# Check upstream status
docker exec nginx_lb nginx -T | grep upstream

# Monitor logs
docker logs -f nginx_lb

# Check connections
docker exec nginx_lb netstat -tulpn
```

## 📈 Performance

### Optimization Settings
```nginx
# Worker processes
worker_processes auto;

# Worker connections
events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

# Gzip compression
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript;

# Caching
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### Connection Pooling
```nginx
upstream backend_servers {
    server backend1:3000 max_conns=100;
    server backend2:3000 max_conns=100;
    server backend3:3000 max_conns=100;
    
    keepalive 32;
    keepalive_requests 100;
    keepalive_timeout 60s;
}
```

## 🔒 Security

### Security Headers
```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
```

### Rate Limiting
```nginx
# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

location /api/ {
    limit_req zone=api burst=20 nodelay;
    proxy_pass http://backend_servers;
}
```

### Access Control
```nginx
# IP whitelist
location /admin {
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    deny all;
    proxy_pass http://backend_servers;
}
```

## 📝 Changelog

### v1.0.0
- Initial release
- Round-robin load balancing
- Health check endpoints
- CORS support
- Error handling
- Docker support

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test configuration
5. Submit pull request

## 📄 License

MIT License
