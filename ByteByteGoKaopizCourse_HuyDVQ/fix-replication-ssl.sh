#!/bin/bash

echo "=== Fixing MySQL Replication SSL Issue ==="

# Fix replication user to use mysql_native_password
echo "Updating replication user authentication..."
docker exec mysql_master mysql -u root -prootpassword -e "
ALTER USER 'replicator'@'%' IDENTIFIED WITH mysql_native_password BY 'replicator_password';
FLUSH PRIVILEGES;
"

# Stop replication on slaves
echo "Stopping replication on slaves..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "STOP REPLICA;"
docker exec mysql_slave2 mysql -u root -prootpassword -e "STOP REPLICA;"

# Reset replication on slaves
echo "Resetting replication on slaves..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "RESET REPLICA ALL;"
docker exec mysql_slave2 mysql -u root -prootpassword -e "RESET REPLICA ALL;"

# Setup Slave1 with SSL disabled
echo "Setting up Slave1..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "
CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1,
    MASTER_SSL=0;
START SLAVE;
"

# Setup Slave2 with SSL disabled
echo "Setting up Slave2..."
docker exec mysql_slave2 mysql -u root -prootpassword -e "
CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='replicator',
    MASTER_PASSWORD='replicator_password',
    MASTER_AUTO_POSITION=1,
    MASTER_SSL=0;
START SLAVE;
"

# Wait a bit for replication to start
echo "Waiting for replication to start..."
sleep 15

# Check replication status
echo "Checking replication status..."
echo "Slave1 Status:"
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

echo "Slave2 Status:"
docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

echo "Replication SSL fix completed!"