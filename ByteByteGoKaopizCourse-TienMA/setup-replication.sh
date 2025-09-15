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
DROP USER IF EXISTS 'replicator'@'%';
CREATE USER 'replicator'@'%' IDENTIFIED WITH mysql_native_password BY 'replicator_password';
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

# Setup Slave1 with proper GTID handling
echo "Setting up Slave1..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "
STOP SLAVE;
RESET SLAVE ALL;
RESET MASTER;
"

# Get Master's current GTID position
MASTER_GTID=$(docker exec mysql_master mysql -u root -prootpassword -e "SELECT @@GLOBAL.GTID_EXECUTED;" 2>/dev/null | tail -n 1)
echo "Master GTID_EXECUTED: $MASTER_GTID"

# Set slave to skip already executed transactions
docker exec mysql_slave1 mysql -u root -prootpassword -e "
SET GLOBAL GTID_PURGED='$MASTER_GTID';
CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1,
    GET_MASTER_PUBLIC_KEY=1;
START SLAVE;
" 2>/dev/null

echo "✓ Slave1 configured"

# Setup Slave2 with proper GTID handling
echo "Setting up Slave2..."
docker exec mysql_slave2 mysql -u root -prootpassword -e "
STOP SLAVE;
RESET SLAVE ALL;
RESET MASTER;
SET GLOBAL GTID_PURGED='$MASTER_GTID';
CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1,
    GET_MASTER_PUBLIC_KEY=1;
START SLAVE;
" 2>/dev/null

echo "✓ Slave2 configured"

# Wait a moment for replication to initialize
echo "Waiting for replication to initialize..."
sleep 5

# Function to check and fix slave replication
check_and_fix_replication() {
    local slave_name=$1
    local container_name=$2
    
    # Check if SQL thread is running
    SQL_RUNNING=$(docker exec $container_name mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep "Slave_SQL_Running:" | awk '{print $2}')
    IO_RUNNING=$(docker exec $container_name mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep "Slave_IO_Running:" | awk '{print $2}')
    
    if [ "$SQL_RUNNING" != "Yes" ] || [ "$IO_RUNNING" != "Yes" ]; then
        echo "⚠️  $slave_name replication issues detected. Attempting to fix..."
        
        # Get current GTID_EXECUTED from master
        MASTER_GTID=$(docker exec mysql_master mysql -u root -prootpassword -e "SELECT @@GLOBAL.GTID_EXECUTED;" 2>/dev/null | tail -n 1)
        echo "Master GTID_EXECUTED: $MASTER_GTID"
        
        # Reset slave and skip problematic transactions
        docker exec $container_name mysql -u root -prootpassword -e "
        STOP SLAVE;
        RESET SLAVE ALL;
        RESET MASTER;
        SET GLOBAL GTID_PURGED='$MASTER_GTID';
        CHANGE MASTER TO
            MASTER_HOST='mysql-master',
            MASTER_USER='replicator',
            MASTER_PASSWORD='replicator_password',
            MASTER_AUTO_POSITION=1,
            GET_MASTER_PUBLIC_KEY=1;
        START SLAVE;
        " 2>/dev/null
        
        # Wait and check again
        sleep 5
        SQL_RUNNING=$(docker exec $container_name mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep "Slave_SQL_Running:" | awk '{print $2}')
        IO_RUNNING=$(docker exec $container_name mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep "Slave_IO_Running:" | awk '{print $2}')
        
        if [ "$SQL_RUNNING" = "Yes" ] && [ "$IO_RUNNING" = "Yes" ]; then
            echo "✓ $slave_name replication fixed successfully"
        else
            echo "❌ $slave_name replication still has issues"
            # Get detailed error for debugging
            docker exec $container_name mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Last_Error|Last_SQL_Error" | head -2
        fi
    else
        echo "✓ $slave_name replication is working correctly"
    fi
}

# Check and fix replication for both slaves
check_and_fix_replication "Slave1" "mysql_slave1"
check_and_fix_replication "Slave2" "mysql_slave2"

# Check replication status
echo "===== Checking Replication Status ====="
echo ""
echo "Slave1 Status:"
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host|Slave_SQL_Running_State"

# Check for specific errors on Slave1
SLAVE1_ERRORS=$(docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Last_Error:|Last_IO_Error:|Last_SQL_Error:" | grep -v ": $")
if [ ! -z "$SLAVE1_ERRORS" ]; then
    echo "❌ Slave1 Errors:"
    echo "$SLAVE1_ERRORS"
fi

echo ""
echo "Slave2 Status:"
docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host|Slave_SQL_Running_State"

# Check for specific errors on Slave2
SLAVE2_ERRORS=$(docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Last_Error:|Last_IO_Error:|Last_SQL_Error:" | grep -v ": $")
if [ ! -z "$SLAVE2_ERRORS" ]; then
    echo "❌ Slave2 Errors:"
    echo "$SLAVE2_ERRORS"
fi

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

# Insert sample data on master (will be replicated to slaves)
echo ""
echo "===== Inserting Sample Data on Master ====="
if [ -f "insert-sample-data.sql" ]; then
    echo "Loading sample data into master..."
    docker exec mysql_master mysql -u root -prootpassword loadbalancer_db < insert-sample-data.sql 2>/dev/null
    echo "✓ Sample data inserted on master"
    
    # Wait for replication to sync the data
    echo "Waiting for data replication to slaves..."
    sleep 5
    
    # Verify data replication
    MASTER_COUNT=$(docker exec mysql_master mysql -u root -prootpassword -D loadbalancer_db -e "SELECT COUNT(*) FROM users;" 2>/dev/null | tail -n 1)
    SLAVE1_COUNT=$(docker exec mysql_slave1 mysql -u root -prootpassword -D loadbalancer_db -e "SELECT COUNT(*) FROM users;" 2>/dev/null | tail -n 1)
    SLAVE2_COUNT=$(docker exec mysql_slave2 mysql -u root -prootpassword -D loadbalancer_db -e "SELECT COUNT(*) FROM users;" 2>/dev/null | tail -n 1)
    
    echo "Data verification - Master: $MASTER_COUNT, Slave1: $SLAVE1_COUNT, Slave2: $SLAVE2_COUNT"
    
    if [ "$SLAVE1_COUNT" = "$MASTER_COUNT" ] && [ "$SLAVE2_COUNT" = "$MASTER_COUNT" ]; then
        echo "✅ Data successfully replicated to all slaves"
    else
        echo "⚠️  Data replication may need more time"
    fi
else
    echo "⚠️  insert-sample-data.sql not found, skipping sample data insertion"
fi

echo ""
echo "===== Replication Setup Completed! ====="
echo "✓ Master: mysql-master:3306"
echo "✓ Slave1: mysql-slave1:3307" 
echo "✓ Slave2: mysql-slave2:3308"
echo ""
echo "To test replication, run: ./test-replication.sh"
