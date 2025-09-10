#!/bin/bash

echo "=== Fixing MySQL Master-Slave Replication ==="

# Stop replication on slaves
echo "Stopping replication on slaves..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "STOP REPLICA;"
docker exec mysql_slave2 mysql -u root -prootpassword -e "STOP REPLICA;"

# Reset replication on slaves
echo "Resetting replication on slaves..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "RESET REPLICA ALL;"
docker exec mysql_slave2 mysql -u root -prootpassword -e "RESET REPLICA ALL;"

# Recreate replication user on Master
echo "Recreating replication user on Master..."
docker exec mysql_master mysql -u root -prootpassword -e "
DROP USER IF EXISTS 'replicator'@'%';
CREATE USER 'replicator'@'%' IDENTIFIED BY 'replicator_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
"

# Get Master status
echo "Getting Master status..."
MASTER_STATUS=$(docker exec mysql_master mysql -u root -prootpassword -e "SHOW MASTER STATUS\G")
echo "Master Status: $MASTER_STATUS"

# Setup Slave1
echo "Setting up Slave1..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "
CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1;
START SLAVE;
"

# Setup Slave2
echo "Setting up Slave2..."
docker exec mysql_slave2 mysql -u root -prootpassword -e "
CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1;
START SLAVE;
"

# Wait a bit for replication to start
echo "Waiting for replication to start..."
sleep 10

# Check replication status
echo "Checking replication status..."
echo "Slave1 Status:"
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

echo "Slave2 Status:"
docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

echo "Replication fix completed!"