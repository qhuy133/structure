# MySQL Master-Slave Replication Architecture

## 📖 Tổng quan về MySQL Replication

MySQL Replication là một kỹ thuật cho phép sao chép dữ liệu từ một MySQL server (Master) sang một hoặc nhiều MySQL servers khác (Slaves). Trong hệ thống này, chúng ta triển khai **1 Master + 2 Slaves** architecture với **GTID-based replication**.

## 🏗️ Kiến trúc triển khai

```
┌─────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   FastAPI App   │  │   FastAPI App   │  │   FastAPI App   │  │
│  │   (Server 1)    │  │   (Server 2)    │  │   (Server 3)    │  │
│  └─────────┬───────┘  └─────────┬───────┘  └─────────┬───────┘  │
└───────────┼─────────────────────┼─────────────────────┼─────────┘
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                                  │
    ┌─────────────────────────────┼─────────────────────────────┐
    │              DATABASE LAYER │                             │
    │                            │                             │
    │  WRITES                    │                    READS    │
    │     ▼                      │                       ▲     │
    │ ┌─────────────────┐        │        ┌─────────────────┐  │
    │ │  MySQL Master   │        │        │  MySQL Slave1   │  │
    │ │                 │────────┼────────┤                 │  │
    │ │ Port: 3306      │        │        │ Port: 3307      │  │
    │ │ Server ID: 1    │        │        │ Server ID: 2    │  │
    │ │ Read-Write      │        │        │ Read-Only       │  │
    │ └─────────────────┘        │        └─────────────────┘  │
    │         │                  │                   ▲         │
    │         │ Replication      │                   │         │
    │         ▼                  │                   │         │
    │ ┌─────────────────┐        │        ┌─────────────────┐  │
    │ │   Binary Log    │        │        │  MySQL Slave2   │  │
    │ │   + GTID        │        │        │                 │  │
    │ │                 │────────┼────────┤ Port: 3308      │  │
    │ └─────────────────┘        │        │ Server ID: 3    │  │
    │                            │        │ Read-Only       │  │
    │                            │        └─────────────────┘  │
    └────────────────────────────────────────────────────────────┘
```

## 🔧 Cấu hình Master Database

### Thông số kỹ thuật:
- **Server ID**: 1
- **Port**: 3306 (external)
- **Mode**: Read-Write
- **Binary Logging**: Enabled với ROW format
- **GTID**: Enabled

### File cấu hình: `master/my.cnf`

```ini
[mysqld]
# Server identification
server-id = 1

# Binary logging configuration
log-bin = mysql-bin                    # Enable binary logging
binlog-format = ROW                    # Row-based replication
expire_logs_days = 7                   # Auto-cleanup old logs
max_binlog_size = 100M                 # Max size per binlog file

# GTID (Global Transaction Identifier) 
gtid-mode = ON                         # Enable GTID
enforce-gtid-consistency = ON          # Strict GTID rules

# Replication performance settings
sync_binlog = 1                        # Sync binlog for durability
innodb_flush_log_at_trx_commit = 1     # Flush log on commit

# Performance tuning
innodb_buffer_pool_size = 256M         # InnoDB buffer pool
innodb_log_file_size = 64M             # InnoDB log file size
innodb_log_buffer_size = 16M           # Log buffer size

# Network settings
bind-address = 0.0.0.0                 # Listen on all interfaces
port = 3306

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Ignore system databases in replication
replicate-ignore-db = mysql
replicate-ignore-db = information_schema
replicate-ignore-db = performance_schema
replicate-ignore-db = sys
```

### Vai trò của Master:
1. **Xử lý Write Operations**: Tất cả INSERT, UPDATE, DELETE
2. **Generate Binary Logs**: Ghi lại mọi thay đổi dữ liệu
3. **GTID Management**: Tạo unique transaction identifiers
4. **Serve Replication Requests**: Gửi binary logs đến slaves

## 🔧 Cấu hình Slave Databases

### Slave 1 Specifications:
- **Server ID**: 2
- **Port**: 3307 (external)
- **Mode**: Read-Only
- **Role**: Read operations + Replication target

### Slave 2 Specifications:
- **Server ID**: 3  
- **Port**: 3308 (external)
- **Mode**: Read-Only
- **Role**: Read operations + Replication target

### File cấu hình: `slave1/my.cnf` & `slave2/my.cnf`

```ini
[mysqld]
# Server identification (2 for slave1, 3 for slave2)
server-id = 2                          # Unique server ID

# Relay logging for replication
relay-log = mysql-relay-bin            # Relay log file prefix
log-slave-updates = 1                  # Log slave updates

# Read-only mode (except for replication)
read-only = 1                          # Prevent writes from applications

# GTID settings (must match master)
gtid-mode = ON
enforce-gtid-consistency = ON

# Performance settings
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_log_buffer_size = 16M

# Network settings
bind-address = 0.0.0.0
port = 3306                            # Internal port (mapped externally)

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Replication error handling
slave-skip-errors = 1062,1032          # Skip duplicate key & record not found
slave-net-timeout = 60                 # Network timeout
slave-sql-verify-checksum = 1          # Verify checksums
```

### Vai trò của Slaves:
1. **Handle Read Operations**: SELECT queries từ applications
2. **Replication Target**: Nhận và apply changes từ master
3. **Load Balancing**: Phân tán read load
4. **High Availability**: Backup cho master data

## 🔄 Quy trình Replication

### 1. **Binary Logging trên Master:**
```sql
-- Khi có write operation trên master:
INSERT INTO users (name, email) VALUES ('John', 'john@example.com');

-- Master tự động:
-- 1. Execute query
-- 2. Generate GTID (Global Transaction ID)
-- 3. Write to binary log with GTID
-- 4. Return success to application
```

### 2. **Replication Process:**

```
┌─────────────────┐  ①Binary Log   ┌─────────────────┐
│   MYSQL MASTER  │ ──────────────→│   IO Thread     │ (on Slave)
│                 │                │ Downloads binlog │
└─────────────────┘                └─────────┬───────┘
                                             │
                                             ▼
                                   ┌─────────────────┐
                                   │   Relay Log     │ (on Slave)
                                   │ Stores changes  │
                                   └─────────┬───────┘
                                             │
                                             ▼
                                   ┌─────────────────┐
                                   │   SQL Thread    │ (on Slave)
                                   │ Applies changes │
                                   └─────────────────┘
```

### 3. **GTID-based Positioning:**
```sql
-- Master generates GTID for each transaction:
-- Format: source_id:transaction_number
-- Example: 3E11FA47-71CA-11E1-9E33-C80AA9429562:1

-- Slaves track executed GTIDs:
SHOW SLAVE STATUS\G
-- Retrieved_Gtid_Set: All GTIDs received from master
-- Executed_Gtid_Set: All GTIDs applied to slave
```

## 🔐 Security & User Management

### Replication User Setup:
```sql
-- Trên Master, tạo user chuyên dụng cho replication:
CREATE USER 'replicator'@'%' IDENTIFIED BY 'replicator_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
```

### Application Users:
```sql
-- Database user cho applications:
-- Username: user
-- Password: password
-- Database: loadbalancer_db
-- Permissions: SELECT, INSERT, UPDATE, DELETE
```

## 📊 Monitoring & Health Checks

### 1. **Replication Status Commands:**

```sql
-- Trên Master:
SHOW MASTER STATUS;
-- Shows: Binary log file, position, GTID set

SHOW SLAVE HOSTS;
-- Shows: Connected slaves information

-- Trên Slaves:
SHOW SLAVE STATUS\G
-- Key metrics:
-- Slave_IO_Running: YES/NO
-- Slave_SQL_Running: YES/NO
-- Seconds_Behind_Master: Replication lag
-- Master_Host: Master server
-- Retrieved_Gtid_Set: Received GTIDs
-- Executed_Gtid_Set: Applied GTIDs
```

### 2. **Health Check Script:**
```bash
#!/bin/bash
# Check replication health

# Test slave connectivity
docker exec mysql_slave1 mysqladmin ping

# Check replication status
docker exec mysql_slave1 mysql -u root -prootpassword \
  -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running"

# Check replication lag
docker exec mysql_slave1 mysql -u root -prootpassword \
  -e "SHOW SLAVE STATUS\G" | grep "Seconds_Behind_Master"
```

## 🚀 Setup và Initialization

### 1. **Automatic Setup Process:**
```bash
# 1. Start containers
docker compose up -d

# 2. Wait for MySQL services
# 3. Create replication user on master
# 4. Configure slaves to connect to master
# 5. Start replication
# 6. Verify replication status
```

### 2. **Manual Replication Setup:**
```sql
-- Trên Slaves:
STOP SLAVE;
RESET SLAVE;

CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator', 
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1;  -- Use GTID auto-positioning

START SLAVE;
```

## 🔧 Troubleshooting

### Common Issues và Solutions:

#### 1. **Replication Lag:**
```sql
-- Monitor lag:
SHOW SLAVE STATUS\G | grep Seconds_Behind_Master

-- Solutions:
-- - Optimize queries
-- - Increase slave resources
-- - Check network latency
```

#### 2. **Replication Errors:**
```sql
-- Check errors:
SHOW SLAVE STATUS\G | grep Last_Error

-- Common fixes:
STOP SLAVE;
-- Fix data inconsistency manually
START SLAVE;
```

#### 3. **Connection Issues:**
```sql
-- Test master connectivity from slave:
mysql -h mysql-master -u replicator -preplicator_password

-- Check firewall/network settings
-- Verify user permissions
```

#### 4. **GTID Consistency Issues:**
```sql
-- Reset GTID state (dangerous - use carefully):
STOP SLAVE;
RESET MASTER;
RESET SLAVE;
-- Reconfigure replication
```

## ⚡ Performance Tuning

### 1. **Master Optimizations:**
```ini
# Binary log performance
sync_binlog = 1                    # For durability
binlog_cache_size = 1M            # Cache size for transactions
max_binlog_cache_size = 2G        # Max cache size

# InnoDB settings
innodb_flush_log_at_trx_commit = 1 # Durability
innodb_buffer_pool_size = 70%      # Of available RAM
```

### 2. **Slave Optimizations:**
```ini
# Relay log settings
relay_log_recovery = ON            # Auto-recovery
relay_log_space_limit = 4G         # Limit relay log space

# Parallel replication (MySQL 5.7+)
slave_parallel_workers = 4         # Parallel SQL threads
slave_parallel_type = LOGICAL_CLOCK # Parallelization method
```

### 3. **Network Optimizations:**
```ini
# Connection settings
slave_net_timeout = 60             # Network timeout
slave_compressed_protocol = 1      # Compress replication traffic
```

## 📈 Scaling Considerations

### 1. **Read Scaling:**
- Thêm nhiều read replicas
- Implement read routing logic
- Consider read-only query caching

### 2. **Write Scaling:**
- Master-Master replication (advanced)
- Sharding strategies
- Application-level partitioning

### 3. **High Availability:**
- Auto-failover mechanisms
- Master promotion procedures
- Data consistency checks

## 🔒 Best Practices

### 1. **Security:**
- Dedicated replication users
- Strong passwords
- Network encryption (SSL)
- Firewall rules

### 2. **Monitoring:**
- Replication lag alerts
- Error log monitoring  
- Performance metrics
- Automated health checks

### 3. **Backup Strategy:**
- Regular master backups
- Point-in-time recovery
- Cross-region replicas
- Backup verification

### 4. **Maintenance:**
- Regular log cleanup
- Performance analysis
- Security updates
- Capacity planning

---

## 📚 Tài liệu tham khảo

- [MySQL 8.0 Replication Documentation](https://dev.mysql.com/doc/refman/8.0/en/replication.html)
- [GTID-based Replication](https://dev.mysql.com/doc/refman/8.0/en/replication-gtids.html)
- [Binary Logging](https://dev.mysql.com/doc/refman/8.0/en/binary-log.html)
- [Replication Performance](https://dev.mysql.com/doc/refman/8.0/en/replication-features-performance.html)

---

*Lưu ý: Configuration này được tối ưu cho development/testing. Production environments cần thêm security hardening, monitoring, và backup strategies.*
