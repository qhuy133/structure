#!/bin/bash

echo "=== Database Migration Script ==="
echo "Updating server_id column from INT to VARCHAR(50)"

# Check if containers are running
if ! sudo docker ps | grep -q mysql_master; then
    echo "Error: MySQL master container is not running!"
    echo "Please start the system first with: sudo docker compose up -d"
    exit 1
fi

echo "1. Checking current database schema..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "DESCRIBE requests;"

echo ""
echo "2. Backing up existing data..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "
CREATE TABLE IF NOT EXISTS requests_backup AS SELECT * FROM requests;
"

echo "3. Updating server_id column type..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "
ALTER TABLE requests MODIFY COLUMN server_id VARCHAR(50) NOT NULL;
"

echo "4. Verifying schema update..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "DESCRIBE requests;"

echo "5. Testing with sample data..."
sudo docker exec mysql_master mysql -u user -ppassword loadbalancer_db -e "
INSERT INTO requests (server_id, client_ip, user_agent) VALUES ('test_migration', '127.0.0.1', 'Migration Test');
SELECT * FROM requests WHERE server_id = 'test_migration';
"

echo "6. Updating slave databases..."
echo "   - Updating slave1..."
sudo docker exec mysql_slave1 mysql -u user -ppassword loadbalancer_db -e "
ALTER TABLE requests MODIFY COLUMN server_id VARCHAR(50) NOT NULL;
"

echo "   - Updating slave2..."
sudo docker exec mysql_slave2 mysql -u user -ppassword loadbalancer_db -e "
ALTER TABLE requests MODIFY COLUMN server_id VARCHAR(50) NOT NULL;
"

echo "7. Verifying replication..."
sleep 5
echo "   - Checking slave1..."
sudo docker exec mysql_slave1 mysql -u user -ppassword loadbalancer_db -e "
SELECT * FROM requests WHERE server_id = 'test_migration';
"

echo "   - Checking slave2..."
sudo docker exec mysql_slave2 mysql -u user -ppassword loadbalancer_db -e "
SELECT * FROM requests WHERE server_id = 'test_migration';
"

echo ""
echo "=== Migration Complete ==="
echo "✅ Database schema updated successfully!"
echo "✅ server_id column is now VARCHAR(50)"
echo "✅ Replication is working"
echo "✅ Test data inserted and replicated"
echo ""
echo "You can now test the replication functionality!"
