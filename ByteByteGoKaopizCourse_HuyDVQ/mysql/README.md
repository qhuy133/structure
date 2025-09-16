# MySQL Master-Slave Replication

## 📋 Tổng quan

Hệ thống MySQL Master-Slave replication với 1 master database cho write operations và 2 slave databases cho read operations, sử dụng GTID (Global Transaction Identifier) để đảm bảo consistency.

## 🏗️ Kiến trúc

```
                    ┌─────────────────┐
                    │   Master DB     │
                    │   (Port 3306)   │
                    │     WRITE       │
                    └─────────────────┘
                           │
                    ┌──────┼──────┐
                    │      │      │
            ┌─────────────┐ ┌─────────────┐
            │  Slave1 DB  │ │  Slave2 DB  │
            │  (Port 3307)│ │  (Port 3308)│
            │    READ     │ │    READ     │
            └─────────────┘ └─────────────┘
```

## 🚀 Cài đặt

### 1. Docker Compose
```bash
# Start MySQL services
docker compose up -d mysql-master mysql-slave1 mysql-slave2

# Check status
docker compose ps
```

### 2. Manual Setup
```bash
# Start master
docker run -d --name mysql_master \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=loadbalancer_db \
  -e MYSQL_USER=user \
  -e MYSQL_PASSWORD=password \
  -e MYSQL_REPLICATION_USER=replicator \
  -e MYSQL_REPLICATION_PASSWORD=replicator_password \
  -p 3306:3306 \
  mysql:8.0

# Start slave1
docker run -d --name mysql_slave1 \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=loadbalancer_db \
  -e MYSQL_USER=user \
  -e MYSQL_PASSWORD=password \
  -e MYSQL_MASTER_HOST=mysql-master \
  -e MYSQL_MASTER_USER=replicator \
  -e MYSQL_MASTER_PASSWORD=replicator_password \
  -p 3307:3306 \
  mysql:8.0

# Start slave2
docker run -d --name mysql_slave2 \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=loadbalancer_db \
  -e MYSQL_USER=user \
  -e MYSQL_PASSWORD=password \
  -e MYSQL_MASTER_HOST=mysql-master \
  -e MYSQL_MASTER_USER=replicator \
  -e MYSQL_MASTER_PASSWORD=replicator_password \
  -p 3308:3306 \
  mysql:8.0
```

## ⚙️ Cấu hình

### Master Database (mysql-master)
```ini
[mysqld]
server-id = 1
log-bin = mysql-bin
binlog-format = ROW
gtid-mode = ON
enforce-gtid-consistency = ON

# Performance optimizations
innodb_flush_log_at_trx_commit = 1
sync_binlog = 1
innodb_buffer_pool_size = 256M
max_connections = 200

# Replication settings
expire_logs_days = 7
max_binlog_size = 100M
```

### Slave1 Database (mysql-slave1)
```ini
[mysqld]
server-id = 2
relay-log = mysql-relay-bin
log-slave-updates = 1
read-only = 1
gtid-mode = ON
enforce-gtid-consistency = ON
log-bin = mysql-bin
binlog-format = ROW

# Performance optimizations
innodb_flush_log_at_trx_commit = 2
sync_binlog = 0
innodb_buffer_pool_size = 128M
max_connections = 200

# Replication settings
slave_net_timeout = 60
slave_skip_errors = 1062,1032
```

### Slave2 Database (mysql-slave2)
```ini
[mysqld]
server-id = 3
relay-log = mysql-relay-bin
log-slave-updates = 1
read-only = 1
gtid-mode = ON
enforce-gtid-consistency = ON
log-bin = mysql-bin
binlog-format = ROW

# Performance optimizations
innodb_flush_log_at_trx_commit = 2
sync_binlog = 0
innodb_buffer_pool_size = 128M
max_connections = 200

# Replication settings
slave_net_timeout = 60
slave_skip_errors = 1062,1032
```

## 🔧 Setup Replication

### 1. Automatic Setup
```bash
# Run setup script
./setup-replication.sh
```

### 2. Manual Setup

#### Step 1: Create Replication User on Master
```sql
-- Connect to master
mysql -h localhost -P 3306 -u root -prootpassword

-- Create replication user
CREATE USER 'replicator'@'%' IDENTIFIED BY 'replicator_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;

-- Show master status
SHOW MASTER STATUS;
```

#### Step 2: Setup Slave1
```sql
-- Connect to slave1
mysql -h localhost -P 3307 -u root -prootpassword

-- Configure replication
CHANGE MASTER TO
  MASTER_HOST='mysql-master',
  MASTER_USER='replicator',
  MASTER_PASSWORD='replicator_password',
  MASTER_AUTO_POSITION=1;

-- Start replication
START SLAVE;

-- Check status
SHOW SLAVE STATUS\G;
```

#### Step 3: Setup Slave2
```sql
-- Connect to slave2
mysql -h localhost -P 3308 -u root -prootpassword

-- Configure replication
CHANGE MASTER TO
  MASTER_HOST='mysql-master',
  MASTER_USER='replicator',
  MASTER_PASSWORD='replicator_password',
  MASTER_AUTO_POSITION=1;

-- Start replication
START SLAVE;

-- Check status
SHOW SLAVE STATUS\G;
```

## 📊 Database Schema

### Initialization Script (init.sql)
```sql
-- Initialize database
USE loadbalancer_db;

-- Create table to track requests
CREATE TABLE IF NOT EXISTS requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    server_id VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_ip VARCHAR(45),
    user_agent TEXT
);

-- Insert sample data
INSERT INTO requests (server_id, client_ip, user_agent) VALUES 
("1", "127.0.0.1", "Sample Request"),
("2", "127.0.0.1", "Sample Request"),
("3", "127.0.0.1", "Sample Request");
```

## 🔍 Monitoring

### Check Replication Status
```sql
-- Check master status
SHOW MASTER STATUS;

-- Check slave status
SHOW SLAVE STATUS\G;

-- Check GTID status
SELECT @@gtid_mode;
SELECT @@gtid_executed;
```

### Health Checks
```bash
# Check master
mysql -h localhost -P 3306 -u user -ppassword -e "SELECT 1"

# Check slave1
mysql -h localhost -P 3307 -u user -ppassword -e "SELECT 1"

# Check slave2
mysql -h localhost -P 3308 -u user -ppassword -e "SELECT 1"
```

### Replication Lag
```sql
-- Check replication lag
SELECT 
    SUBSTRING_INDEX(HOST, ':', 1) AS slave_host,
    PORT,
    USER,
    SECONDS_BEHIND_MASTER,
    SLAVE_IO_RUNNING,
    SLAVE_SQL_RUNNING
FROM information_schema.PROCESSLIST 
WHERE COMMAND = 'Binlog Dump';
```

## 🧪 Testing

### Test Write to Master
```sql
-- Connect to master
mysql -h localhost -P 3306 -u user -ppassword loadbalancer_db

-- Insert test data
INSERT INTO requests (server_id, client_ip, user_agent) 
VALUES ('test_master', '127.0.0.1', 'Master Test');
```

### Test Read from Slaves
```sql
-- Check slave1
mysql -h localhost -P 3307 -u user -ppassword loadbalancer_db
SELECT * FROM requests WHERE server_id = 'test_master';

-- Check slave2
mysql -h localhost -P 3308 -u user -ppassword loadbalancer_db
SELECT * FROM requests WHERE server_id = 'test_master';
```

### Test Replication
```bash
# Write to master
mysql -h localhost -P 3306 -u user -ppassword loadbalancer_db -e "
INSERT INTO requests (server_id, client_ip, user_agent) 
VALUES ('replication_test', '127.0.0.1', 'Replication Test');
"

# Wait for replication
sleep 5

# Check slaves
mysql -h localhost -P 3307 -u user -ppassword loadbalancer_db -e "
SELECT * FROM requests WHERE server_id = 'replication_test';
"

mysql -h localhost -P 3308 -u user -ppassword loadbalancer_db -e "
SELECT * FROM requests WHERE server_id = 'replication_test';
"
```

## 🔧 Troubleshooting

### Common Issues

1. **Replication Not Starting**
   ```sql
   -- Check slave status
   SHOW SLAVE STATUS\G;
   
   -- Check for errors
   SELECT * FROM performance_schema.replication_applier_status_by_worker;
   ```

2. **Slave Lagging Behind**
   ```sql
   -- Check lag
   SHOW SLAVE STATUS\G;
   
   -- Check processlist
   SHOW PROCESSLIST;
   ```

3. **GTID Errors**
   ```sql
   -- Reset GTID
   RESET MASTER;
   RESET SLAVE;
   
   -- Reconfigure replication
   CHANGE MASTER TO MASTER_AUTO_POSITION=1;
   START SLAVE;
   ```

### Debug Commands
```bash
# Check container logs
docker logs mysql_master
docker logs mysql_slave1
docker logs mysql_slave2

# Check replication status
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G"

# Check GTID status
docker exec mysql_master mysql -u root -prootpassword -e "SELECT @@gtid_mode, @@gtid_executed"
```

## 📈 Performance

### Master Database
- **Write Performance**: Optimized for write operations
- **Binary Logging**: ROW format for consistency
- **GTID**: Global Transaction Identifier for reliability
- **Buffer Pool**: 256MB for better performance

### Slave Databases
- **Read Performance**: Optimized for read operations
- **Read-only**: Prevents accidental writes
- **Relay Logs**: Efficient replication processing
- **Buffer Pool**: 128MB each for read operations

### Optimization Settings
```sql
-- Master optimizations
SET GLOBAL innodb_flush_log_at_trx_commit = 1;
SET GLOBAL sync_binlog = 1;
SET GLOBAL innodb_buffer_pool_size = 256*1024*1024;

-- Slave optimizations
SET GLOBAL innodb_flush_log_at_trx_commit = 2;
SET GLOBAL sync_binlog = 0;
SET GLOBAL innodb_buffer_pool_size = 128*1024*1024;
```

## 🔒 Security

### User Management
```sql
-- Create application user
CREATE USER 'user'@'%' IDENTIFIED BY 'password';
GRANT SELECT, INSERT, UPDATE, DELETE ON loadbalancer_db.* TO 'user'@'%';

-- Create replication user
CREATE USER 'replicator'@'%' IDENTIFIED BY 'replicator_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';

-- Flush privileges
FLUSH PRIVILEGES;
```

### Network Security
- **Port Access**: Only necessary ports exposed
- **User Authentication**: Strong passwords
- **Privilege Separation**: Minimal required privileges

## 📊 Backup & Recovery

### Backup Master
```bash
# Full backup
mysqldump -h localhost -P 3306 -u root -prootpassword \
  --single-transaction --routines --triggers \
  loadbalancer_db > master_backup.sql

# Binary log backup
mysqlbinlog --start-datetime="2025-09-16 00:00:00" \
  /var/lib/mysql/mysql-bin.000001 > binlog_backup.sql
```

### Backup Slaves
```bash
# Slave1 backup
mysqldump -h localhost -P 3307 -u root -prootpassword \
  --single-transaction --routines --triggers \
  loadbalancer_db > slave1_backup.sql

# Slave2 backup
mysqldump -h localhost -P 3308 -u root -prootpassword \
  --single-transaction --routines --triggers \
  loadbalancer_db > slave2_backup.sql
```

### Recovery
```bash
# Restore master
mysql -h localhost -P 3306 -u root -prootpassword loadbalancer_db < master_backup.sql

# Restore slave
mysql -h localhost -P 3307 -u root -prootpassword loadbalancer_db < slave1_backup.sql
```

## 📝 Changelog

### v1.0.0
- Initial release
- Master-Slave replication
- GTID support
- Read-only slaves
- Performance optimizations
- Docker support

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test replication
5. Submit pull request

## 📄 License

MIT License
