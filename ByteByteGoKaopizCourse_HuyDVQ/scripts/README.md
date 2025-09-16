# Scripts

## 📋 Tổng quan

Thư mục chứa các scripts để setup, migration, và maintenance hệ thống Load Balancer với MySQL Master-Slave replication.

## 📁 Danh sách Scripts

### 1. setup-replication.sh
**Mục đích**: Setup MySQL Master-Slave replication tự động

**Sử dụng**:
```bash
chmod +x setup-replication.sh
./setup-replication.sh
```

**Chức năng**:
- Start MySQL services
- Tạo replication user trên master
- Cấu hình replication cho slave1 và slave2
- Verify replication status
- Test replication với sample data

### 2. migrate-db.sh
**Mục đích**: Migration database schema từ INT sang VARCHAR cho server_id

**Sử dụng**:
```bash
chmod +x migrate-db.sh
./migrate-db.sh
```

**Chức năng**:
- Backup existing data
- Update server_id column type
- Update slave databases
- Verify schema changes
- Test với sample data

### 3. fix-replication.sh
**Mục đích**: Fix replication issues và restart replication

**Sử dụng**:
```bash
chmod +x fix-replication.sh
./fix-replication.sh
```

**Chức năng**:
- Stop replication trên slaves
- Disable read-only mode
- Create tables trên slaves
- Reset và restart replication
- Re-enable read-only mode
- Verify replication

## 🚀 Quick Start

### Setup toàn bộ hệ thống
```bash
# 1. Start containers
sudo docker compose up -d

# 2. Setup replication
./setup-replication.sh

# 3. Test hệ thống
curl http://localhost:8080/api/server-info
```

### Migration database
```bash
# Nếu cần migration schema
./migrate-db.sh

# Fix replication nếu có vấn đề
./fix-replication.sh
```

## 🔧 Script Details

### setup-replication.sh
```bash
#!/bin/bash

echo "=== Setting up MySQL Master-Slave Replication ==="

# Step 1: Start MySQL services
echo "1. Starting MySQL Master and Slaves..."
sudo docker compose up -d mysql-master mysql-slave1 mysql-slave2

# Step 2: Setup replication on master
echo "2. Setting up replication on master..."
sudo docker exec mysql_master mysql -u root -prootpassword -e "
CREATE USER 'replicator'@'%' IDENTIFIED BY 'replicator_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
SHOW MASTER STATUS;
"

# Step 3: Setup replication on slaves
# ... (chi tiết trong file)
```

### migrate-db.sh
```bash
#!/bin/bash

echo "=== Database Migration Script ==="
echo "Updating server_id column from INT to VARCHAR(50)"

# Step 1: Check current schema
echo "1. Checking current database schema..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "DESCRIBE requests;"

# Step 2: Backup data
echo "2. Backing up existing data..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "
CREATE TABLE IF NOT EXISTS requests_backup AS SELECT * FROM requests;
"

# Step 3: Update schema
echo "3. Updating server_id column type..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "
ALTER TABLE requests MODIFY COLUMN server_id VARCHAR(50) NOT NULL;
"
```

### fix-replication.sh
```bash
#!/bin/bash

echo "=== Fixing MySQL Replication ==="

# Step 1: Stop replication
echo "1. Stopping replication on slaves..."
sudo docker exec mysql_slave1 mysql -u root -prootpassword -e "STOP SLAVE;"
sudo docker exec mysql_slave2 mysql -u root -prootpassword -e "STOP SLAVE;"

# Step 2: Disable read-only mode
echo "2. Disabling read-only mode on slaves..."
sudo docker exec mysql_slave1 mysql -u root -prootpassword -e "SET GLOBAL read_only = 0;"
sudo docker exec mysql_slave2 mysql -u root -prootpassword -e "SET GLOBAL read_only = 0;"

# Step 3: Create tables on slaves
echo "3. Creating tables on slaves..."
# ... (chi tiết trong file)
```

## 🧪 Testing Scripts

### Test Replication
```bash
# Test write to master
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "
INSERT INTO requests (server_id, client_ip, user_agent) 
VALUES ('test_script', '127.0.0.1', 'Script Test');
"

# Check replication
sleep 5
sudo docker exec mysql_slave1 mysql -u user -ppassword loadbalancer_db -e "
SELECT * FROM requests WHERE server_id = 'test_script';
"
```

### Test Load Balancing
```bash
# Test API endpoints
curl http://localhost:8080/api/server-info
curl http://localhost:8080/api/stats
curl -X POST http://localhost:8080/api/test-replication
```

### Test Health Checks
```bash
# Test health endpoints
curl http://localhost:8080/health/backend1
curl http://localhost:8080/health/backend2
curl http://localhost:8080/health/backend3
```

## 🔍 Monitoring Scripts

### Check System Status
```bash
#!/bin/bash
echo "=== System Status Check ==="

# Check containers
echo "1. Container Status:"
sudo docker compose ps

# Check database connections
echo "2. Database Connections:"
sudo docker exec mysql_master mysql -u user -ppassword -e "SELECT 1" 2>/dev/null && echo "Master: OK" || echo "Master: FAIL"
sudo docker exec mysql_slave1 mysql -u user -ppassword -e "SELECT 1" 2>/dev/null && echo "Slave1: OK" || echo "Slave1: FAIL"
sudo docker exec mysql_slave2 mysql -u user -ppassword -e "SELECT 1" 2>/dev/null && echo "Slave2: OK" || echo "Slave2: FAIL"

# Check replication status
echo "3. Replication Status:"
sudo docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
```

### Check API Health
```bash
#!/bin/bash
echo "=== API Health Check ==="

# Test load balancer
echo "1. Load Balancer:"
curl -s http://localhost:8080/api/server-info | jq .server_id

# Test health checks
echo "2. Health Checks:"
for i in {1..3}; do
  echo "Backend $i:"
  curl -s http://localhost:8080/health/backend$i | jq .status
done

# Test replication
echo "3. Replication Test:"
curl -s -X POST http://localhost:8080/api/test-replication | jq .write_result
```

## 🛠️ Maintenance Scripts

### Clean Up
```bash
#!/bin/bash
echo "=== System Cleanup ==="

# Stop containers
echo "1. Stopping containers..."
sudo docker compose down

# Remove volumes
echo "2. Removing volumes..."
sudo docker volume prune -f

# Remove images
echo "3. Removing images..."
sudo docker image prune -f

# Clean up
echo "4. Cleanup complete!"
```

### Backup System
```bash
#!/bin/bash
echo "=== System Backup ==="

# Create backup directory
mkdir -p backups/$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"

# Backup master database
echo "1. Backing up master database..."
sudo docker exec mysql_master mysqldump -u root -prootpassword loadbalancer_db > $BACKUP_DIR/master_backup.sql

# Backup slave databases
echo "2. Backing up slave databases..."
sudo docker exec mysql_slave1 mysqldump -u root -prootpassword loadbalancer_db > $BACKUP_DIR/slave1_backup.sql
sudo docker exec mysql_slave2 mysqldump -u root -prootpassword loadbalancer_db > $BACKUP_DIR/slave2_backup.sql

# Backup configurations
echo "3. Backing up configurations..."
cp -r mysql/ $BACKUP_DIR/
cp docker-compose.yml $BACKUP_DIR/
cp init.sql $BACKUP_DIR/

echo "4. Backup complete: $BACKUP_DIR"
```

## 🔧 Troubleshooting Scripts

### Debug Database Issues
```bash
#!/bin/bash
echo "=== Database Debug ==="

# Check container logs
echo "1. Container Logs:"
echo "Master logs:"
sudo docker logs mysql_master --tail 10

echo "Slave1 logs:"
sudo docker logs mysql_slave1 --tail 10

echo "Slave2 logs:"
sudo docker logs mysql_slave2 --tail 10

# Check replication status
echo "2. Replication Status:"
sudo docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Last_Error"
sudo docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Last_Error"
```

### Debug API Issues
```bash
#!/bin/bash
echo "=== API Debug ==="

# Check backend logs
echo "1. Backend Logs:"
for i in {1..3}; do
  echo "Backend $i logs:"
  sudo docker logs backend_$i --tail 5
done

# Check load balancer logs
echo "2. Load Balancer Logs:"
sudo docker logs nginx_lb --tail 10

# Test API endpoints
echo "3. API Tests:"
curl -v http://localhost:8080/api/server-info
curl -v http://localhost:8080/health/backend1
```

## 📊 Performance Scripts

### Load Test
```bash
#!/bin/bash
echo "=== Load Test ==="

# Test API load
echo "1. Testing API load..."
for i in {1..100}; do
  curl -s http://localhost:8080/api/server-info > /dev/null &
done
wait

# Test replication load
echo "2. Testing replication load..."
for i in {1..50}; do
  curl -s -X POST http://localhost:8080/api/test-replication > /dev/null &
done
wait

echo "3. Load test complete!"
```

### Performance Monitor
```bash
#!/bin/bash
echo "=== Performance Monitor ==="

# Monitor database performance
echo "1. Database Performance:"
sudo docker exec mysql_master mysql -u root -prootpassword -e "
SHOW GLOBAL STATUS LIKE 'Queries';
SHOW GLOBAL STATUS LIKE 'Uptime';
SHOW GLOBAL STATUS LIKE 'Threads_connected';
"

# Monitor replication lag
echo "2. Replication Lag:"
sudo docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master
sudo docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master
```

## 📝 Changelog

### v1.0.0
- Initial release
- setup-replication.sh
- migrate-db.sh
- fix-replication.sh
- Monitoring scripts
- Maintenance scripts
- Troubleshooting scripts

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add new scripts
4. Test thoroughly
5. Submit pull request

## 📄 License

MIT License
