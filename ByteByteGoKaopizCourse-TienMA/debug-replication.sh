#!/bin/bash

echo "===== MySQL Replication Debug Tool ====="

# Function to show detailed replication status
show_replication_status() {
    local container_name=$1
    local slave_name=$2
    
    echo ""
    echo "===== $slave_name Detailed Status ====="
    echo "Container: $container_name"
    
    # Basic replication status
    echo "--- Basic Status ---"
    docker exec $container_name mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host|Master_Port"
    
    # Error information
    echo "--- Error Information ---"
    docker exec $container_name mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Last_Error|Last_IO_Error|Last_SQL_Error" | grep -v ": $"
    
    # GTID Information
    echo "--- GTID Information ---"
    docker exec $container_name mysql -u root -prootpassword -e "SELECT @@GLOBAL.GTID_EXECUTED;" 2>/dev/null | tail -n 1 | sed "s/^/$slave_name GTID_EXECUTED: /"
    docker exec $container_name mysql -u root -prootpassword -e "SELECT @@GLOBAL.GTID_PURGED;" 2>/dev/null | tail -n 1 | sed "s/^/$slave_name GTID_PURGED: /"
    
    # Worker errors
    echo "--- Worker Errors ---"
    WORKER_ERRORS=$(docker exec $container_name mysql -u root -prootpassword -e "SELECT WORKER_ID, LAST_ERROR_MESSAGE FROM performance_schema.replication_applier_status_by_worker WHERE LAST_ERROR_MESSAGE != '';" 2>/dev/null | tail -n +2)
    if [ ! -z "$WORKER_ERRORS" ]; then
        echo "$WORKER_ERRORS"
    else
        echo "No worker errors found"
    fi
}

# Function to fix replication issues
fix_replication() {
    local container_name=$1
    local slave_name=$2
    
    echo ""
    echo "===== Fixing $slave_name Replication ====="
    
    # Get Master GTID
    MASTER_GTID=$(docker exec mysql_master mysql -u root -prootpassword -e "SELECT @@GLOBAL.GTID_EXECUTED;" 2>/dev/null | tail -n 1)
    echo "Master GTID_EXECUTED: $MASTER_GTID"
    
    # Reset and reconfigure slave
    echo "Resetting $slave_name..."
    docker exec $container_name mysql -u root -prootpassword -e "
    STOP SLAVE;
    RESET SLAVE ALL;
    RESET MASTER;
    " 2>/dev/null
    
    # Skip conflicting transactions
    if [ ! -z "$MASTER_GTID" ] && [ "$MASTER_GTID" != "" ]; then
        echo "Setting GTID_PURGED to skip conflicting transactions..."
        docker exec $container_name mysql -u root -prootpassword -e "SET GLOBAL GTID_PURGED='$MASTER_GTID';" 2>/dev/null
    fi
    
    # Reconfigure replication
    echo "Reconfiguring replication..."
    docker exec $container_name mysql -u root -prootpassword -e "
    CHANGE MASTER TO
        MASTER_HOST='mysql-master',
        MASTER_USER='replicator',
        MASTER_PASSWORD='replicator_password',
        MASTER_AUTO_POSITION=1,
        GET_MASTER_PUBLIC_KEY=1;
    START SLAVE;
    " 2>/dev/null
    
    echo "✓ $slave_name reconfiguration completed"
}

# Main execution
echo "Checking containers..."
if ! docker ps | grep -q mysql_master; then
    echo "❌ mysql_master container not running"
    exit 1
fi

echo "Master GTID_EXECUTED:"
docker exec mysql_master mysql -u root -prootpassword -e "SELECT @@GLOBAL.GTID_EXECUTED;" 2>/dev/null | tail -n 1

# Show status for all slaves
for slave in "mysql_slave1:Slave1" "mysql_slave2:Slave2"; do
    container=$(echo $slave | cut -d: -f1)
    name=$(echo $slave | cut -d: -f2)
    
    if docker ps | grep -q $container; then
        show_replication_status $container $name
    else
        echo "❌ $container not running"
    fi
done

# Ask user if they want to fix issues
echo ""
read -p "Do you want to attempt to fix replication issues? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for slave in "mysql_slave1:Slave1" "mysql_slave2:Slave2"; do
        container=$(echo $slave | cut -d: -f1)
        name=$(echo $slave | cut -d: -f2)
        
        if docker ps | grep -q $container; then
            fix_replication $container $name
            sleep 3
            show_replication_status $container $name
        fi
    done
fi

echo ""
echo "===== Debug Complete ====="
