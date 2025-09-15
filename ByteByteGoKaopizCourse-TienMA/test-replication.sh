#!/bin/bash

echo "===== Testing MySQL Master-Slave Replication ====="

# Test 1: Insert data into master
echo "Test 1: Inserting test data into Master..."
docker exec mysql_master mysql -u user -ppassword -D loadbalancer_db -e "
INSERT INTO users (name, email) VALUES 
('Test User 1', 'test1@replication.com'),
('Test User 2', 'test2@replication.com');
"
echo "✓ Test data inserted into Master"

# Wait for replication
echo "Waiting 3 seconds for replication..."
sleep 3

# Test 2: Check data on slaves
echo ""
echo "Test 2: Checking data on Slave1..."
SLAVE1_COUNT=$(docker exec mysql_slave1 mysql -u user -ppassword -D loadbalancer_db -e "SELECT COUNT(*) as count FROM users WHERE email LIKE '%@replication.com';" | tail -n 1)
echo "Slave1 test users count: $SLAVE1_COUNT"

echo ""
echo "Test 3: Checking data on Slave2..."
SLAVE2_COUNT=$(docker exec mysql_slave2 mysql -u user -ppassword -D loadbalancer_db -e "SELECT COUNT(*) as count FROM users WHERE email LIKE '%@replication.com';" | tail -n 1)
echo "Slave2 test users count: $SLAVE2_COUNT"

# Test 3: Check replication lag
echo ""
echo "Test 4: Checking replication lag..."
echo "Slave1 lag:"
docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep "Seconds_Behind_Master"

echo "Slave2 lag:"
docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" | grep "Seconds_Behind_Master"

# Test 4: Test read-only on slaves (should fail)
echo ""
echo "Test 5: Testing read-only mode on slaves (should fail)..."
echo "Trying to insert into Slave1 (should fail):"
docker exec mysql_slave1 mysql -u user -ppassword -D loadbalancer_db -e "INSERT INTO users (name, email) VALUES ('Should Fail', 'fail@test.com');" 2>&1 | head -n 1

echo "Trying to insert into Slave2 (should fail):"
docker exec mysql_slave2 mysql -u user -ppassword -D loadbalancer_db -e "INSERT INTO users (name, email) VALUES ('Should Fail', 'fail@test.com');" 2>&1 | head -n 1

# Test 5: Show current data distribution
echo ""
echo "Test 6: Current data count on all nodes..."
MASTER_TOTAL=$(docker exec mysql_master mysql -u user -ppassword -D loadbalancer_db -e "SELECT COUNT(*) as count FROM users;" | tail -n 1)
SLAVE1_TOTAL=$(docker exec mysql_slave1 mysql -u user -ppassword -D loadbalancer_db -e "SELECT COUNT(*) as count FROM users;" | tail -n 1)
SLAVE2_TOTAL=$(docker exec mysql_slave2 mysql -u user -ppassword -D loadbalancer_db -e "SELECT COUNT(*) as count FROM users;" | tail -n 1)

echo "Master total users: $MASTER_TOTAL"
echo "Slave1 total users: $SLAVE1_TOTAL"
echo "Slave2 total users: $SLAVE2_TOTAL"

# Summary
echo ""
echo "===== Test Summary ====="
if [ "$MASTER_TOTAL" = "$SLAVE1_TOTAL" ] && [ "$MASTER_TOTAL" = "$SLAVE2_TOTAL" ]; then
    echo "✓ Replication is working correctly!"
    echo "  All databases have the same number of records: $MASTER_TOTAL"
else
    echo "✗ Replication issue detected!"
    echo "  Record counts don't match across master and slaves"
fi

echo ""
echo "To clean up test data, run:"
echo "docker exec mysql_master mysql -u user -ppassword -D loadbalancer_db -e \"DELETE FROM users WHERE email LIKE '%@replication.com';\""
