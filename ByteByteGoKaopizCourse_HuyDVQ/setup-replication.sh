#!/bin/bash

echo "=== Setting up MySQL Master-Slave Replication ==="

# Step 1: Start MySQL services
echo "1. Starting MySQL Master and Slaves..."
sudo docker compose up -d mysql-master mysql-slave1 mysql-slave2

echo "Waiting for MySQL services to be ready..."
sleep 60

# Step 2: Setup replication on master
echo "2. Setting up replication on master..."
sudo docker exec mysql_master mysql -u root -prootpassword -e "
CREATE USER 'replicator'@'%' IDENTIFIED BY 'replicator_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
SHOW MASTER STATUS;
"

# Step 3: Setup replication on slave1
echo "3. Setting up replication on slave1..."
sudo docker exec mysql_slave1 mysql -u root -prootpassword -e "
CHANGE MASTER TO
  MASTER_HOST='mysql-master',
  MASTER_USER='replicator',
  MASTER_PASSWORD='replicator_password',
  MASTER_AUTO_POSITION=1;
START SLAVE;
SHOW SLAVE STATUS\G;
"

# Step 4: Setup replication on slave2
echo "4. Setting up replication on slave2..."
sudo docker exec mysql_slave2 mysql -u root -prootpassword -e "
CHANGE MASTER TO
  MASTER_HOST='mysql-master',
  MASTER_USER='replicator',
  MASTER_PASSWORD='replicator_password',
  MASTER_AUTO_POSITION=1;
START SLAVE;
SHOW SLAVE STATUS\G;
"

# Step 5: Verify replication
echo "5. Verifying replication..."
sleep 10

echo "Checking slave1 status:"
sudo docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

echo "Checking slave2 status:"
sudo docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

# Step 6: Test replication
echo "6. Testing replication..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "
INSERT INTO requests (server_id, client_ip, user_agent) VALUES ('replication_test', '127.0.0.1', 'Replication Test');
"

sleep 5

echo "Checking if data replicated to slave1..."
sudo docker exec mysql_slave1 mysql -u user -ppassword loadbalancer_db -e "
SELECT * FROM requests WHERE server_id = 'replication_test';
"

echo "Checking if data replicated to slave2..."
sudo docker exec mysql_slave2 mysql -u user -ppassword loadbalancer_db -e "
SELECT * FROM requests WHERE server_id = 'replication_test';
"

echo ""
echo "=== Replication Setup Complete ==="
echo "Master: localhost:3306"
echo "Slave1: localhost:3307"
echo "Slave2: localhost:3308"
echo "Frontend: http://localhost:80"
echo "Load Balancer: http://localhost:8080"
echo ""
echo "You can now start the backend services and frontend!"
