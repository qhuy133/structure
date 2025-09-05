#!/bin/bash

echo "=== MySQL Master-Slave Replication Status ==="

# Check Master status
echo "Master Status:"
docker exec mysql_master mysql -u root -prootpassword -e "SHOW MASTER STATUS\G"

echo -e "\nSlave1 Status:"
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host|Master_User"

echo -e "\nSlave2 Status:"
docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host|Master_User"

# Test replication
echo -e "\n=== Testing Replication ==="
echo "Inserting test data on Master..."
docker exec mysql_master mysql -u root -prootpassword -e "
USE loadbalancer_db;
INSERT INTO requests (server_id, client_ip, user_agent) VALUES (1, '192.168.1.100', 'Replication Test');
"

echo "Checking data on Slave1..."
docker exec mysql_slave1 mysql -u root -prootpassword -e "
USE loadbalancer_db;
SELECT * FROM requests ORDER BY id DESC LIMIT 3;
"

echo "Checking data on Slave2..."
docker exec mysql_slave2 mysql -u root -prootpassword -e "
USE loadbalancer_db;
SELECT * FROM requests ORDER BY id DESC LIMIT 3;
"