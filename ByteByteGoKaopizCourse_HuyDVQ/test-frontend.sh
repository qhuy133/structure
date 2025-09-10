#!/bin/bash

echo "=== Frontend Master-Slave Test Demo ==="
echo ""

echo "🌐 Frontend URL: http://localhost"
echo "📊 Load Balancer: http://localhost:8080"
echo ""

echo "🧪 Available Test Functions:"
echo "1. Test Write (Master) - Tests write operations to Master DB"
echo "2. Test Read (Slave) - Tests read operations from Slave DBs"
echo "3. Test Replication - Tests MySQL Master-Slave replication"
echo "4. Test Load Balancing - Tests Round Robin load balancing"
echo "5. Run All Tests - Runs complete test suite"
echo ""

echo "🔍 Quick API Tests:"
echo ""

echo "Testing Write Operation (Master DB):"
curl -s http://localhost/api/server-info | jq '.server_id, .master_db_status, .timestamp'

echo ""
echo "Testing Read Operation (Slave DB):"
curl -s http://localhost/api/stats | jq '.server_id, .total_requests, .read_from'

echo ""
echo "Testing Load Balancing (5 requests):"
for i in {1..5}; do
  echo -n "Request $i: "
  curl -s http://localhost/api/server-info | jq -r '.server_id'
done

echo ""
echo "Testing Health Checks:"
for i in {1..3}; do
  echo -n "Backend $i: "
  curl -s http://localhost/health/backend$i | jq -r '.master_db, .slave1_db, .slave2_db' 2>/dev/null || echo "Failed"
done

echo ""
echo "✅ Frontend is ready for testing!"
echo "Open http://localhost in your browser to use the test interface."