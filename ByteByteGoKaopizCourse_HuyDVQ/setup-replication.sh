#!/bin/bash

echo "Setting up MySQL Master-Slave Replication..."

# Wait for MySQL Master to be ready
echo "Waiting for MySQL Master to be ready..."
until docker exec mysql_master mysqladmin ping -h localhost --silent; do
    echo "Waiting for MySQL Master..."
    sleep 2
done

# Create replication user on Master
echo "Creating replication user on Master..."
docker exec mysql_master mysql -u root -prootpassword -e "
CREATE USER IF NOT EXISTS 'replicator'@'%' IDENTIFIED BY 'replicator_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
"

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

until docker exec mysql_slave2 mysqladmin ping -h localhost --silent; do
    echo "Waiting for MySQL Slave2..."
    sleep 2
done

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

# Check replication status
echo "Checking replication status..."
echo "Slave1 Status:"
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

echo "Slave2 Status:"
docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

echo "Replication setup completed!"