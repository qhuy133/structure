#!/bin/bash

echo "===== Setting up MySQL Master-Slave Replication ====="

# Wait for MySQL Master to be ready
echo "Waiting for MySQL Master to be ready..."
until docker exec mysql_master mysqladmin ping -h localhost --silent; do
    echo "Waiting for MySQL Master..."
    sleep 2
done
echo "✓ MySQL Master is ready"

# Create replication user on Master
echo "Creating replication user on Master..."
docker exec mysql_master mysql -u root -prootpassword -e "
CREATE USER IF NOT EXISTS 'replicator'@'%' IDENTIFIED BY 'replicator_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
"
echo "✓ Replication user created"

# Get Master status
echo "Getting Master status..."
MASTER_STATUS=$(docker exec mysql_master mysql -u root -prootpassword -e "SHOW MASTER STATUS\G")
echo "Master Status: $MASTER_STATUS"

# Wait for Slaves to be ready
echo "Waiting for MySQL Slaves to be ready..."
until docker exec mysql_slave1 mysqladmin ping -h localhost --silent; do
    echo "Waiting for MySQL Slave1..."
    sleep 2
done
echo "✓ MySQL Slave1 is ready"

until docker exec mysql_slave2 mysqladmin ping -h localhost --silent; do
    echo "Waiting for MySQL Slave2..."
    sleep 2
done
echo "✓ MySQL Slave2 is ready"

# Setup Slave1
echo "Setting up Slave1..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "
STOP SLAVE;
RESET SLAVE;
CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1;
START SLAVE;
"
echo "✓ Slave1 configured"

# Setup Slave2
echo "Setting up Slave2..."
docker exec mysql_slave2 mysql -u root -prootpassword -e "
STOP SLAVE;
RESET SLAVE;
CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1;
START SLAVE;
"
echo "✓ Slave2 configured"

# Wait a moment for replication to initialize
echo "Waiting for replication to initialize..."
sleep 5

# Check replication status
echo "===== Checking Replication Status ====="
echo ""
echo "Slave1 Status:"
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host"

echo ""
echo "Slave2 Status:"
docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host"

# Initial data sync from master to slaves
echo ""
echo "===== Syncing Initial Data to Slaves ====="

# Wait a moment for replication to stabilize
sleep 5

# Check if slaves have synced data
MASTER_COUNT=$(docker exec mysql_master mysql -u user -ppassword -D loadbalancer_db -e "SELECT COUNT(*) FROM users;" 2>/dev/null | tail -n 1)
SLAVE1_COUNT=$(docker exec mysql_slave1 mysql -u user -ppassword -D loadbalancer_db -e "SELECT COUNT(*) FROM users;" 2>/dev/null | tail -n 1)
SLAVE2_COUNT=$(docker exec mysql_slave2 mysql -u user -ppassword -D loadbalancer_db -e "SELECT COUNT(*) FROM users;" 2>/dev/null | tail -n 1)

echo "Data counts - Master: $MASTER_COUNT, Slave1: $SLAVE1_COUNT, Slave2: $SLAVE2_COUNT"

# If slaves don't have data, sync manually
if [ "$SLAVE1_COUNT" != "$MASTER_COUNT" ] || [ "$SLAVE2_COUNT" != "$MASTER_COUNT" ]; then
    echo "⚠️  Data not fully synced, performing manual initial sync..."
    
    # Dump data from master
    docker exec mysql_master mysqldump -u root -prootpassword --single-transaction --routines --triggers loadbalancer_db > /tmp/master_data.sql 2>/dev/null
    
    # Restore to slaves
    echo "Syncing data to Slave1..."
    docker exec mysql_slave1 mysql -u root -prootpassword -e "SET GLOBAL read_only = 0;"
    docker exec mysql_slave1 mysql -u root -prootpassword loadbalancer_db < /tmp/master_data.sql 2>/dev/null
    docker exec mysql_slave1 mysql -u root -prootpassword -e "SET GLOBAL read_only = 1;"
    
    echo "Syncing data to Slave2..."
    docker exec mysql_slave2 mysql -u root -prootpassword -e "SET GLOBAL read_only = 0;"
    docker exec mysql_slave2 mysql -u root -prootpassword loadbalancer_db < /tmp/master_data.sql 2>/dev/null
    docker exec mysql_slave2 mysql -u root -prootpassword -e "SET GLOBAL read_only = 1;"
    
    # Cleanup
    rm -f /tmp/master_data.sql
    
    echo "✓ Initial data sync completed"
fi

echo ""
echo "===== Replication Setup Completed! ====="
echo "✓ Master: mysql-master:3306"
echo "✓ Slave1: mysql-slave1:3307" 
echo "✓ Slave2: mysql-slave2:3308"
echo ""
echo "To test replication, run: ./test-replication.sh"
