#!/bin/bash

echo "=== Testing MySQL Master-Slave Replication ==="

# Test health endpoints
echo "1. Testing Health Endpoints:"
echo "Backend1 (Master):"
curl -s http://localhost:3001/health | jq .

echo -e "\nBackend2 (Slave1):"
curl -s http://localhost:3002/health | jq .

echo -e "\nBackend3 (Slave2):"
curl -s http://localhost:3003/health | jq .

# Test load balancer
echo -e "\n2. Testing Load Balancer:"
for i in {1..5}; do
    echo "Request $i:"
    curl -s http://localhost:8080/api/server-info | jq .
    echo ""
done

# Test write operations (all backends can write to Master DB)
echo -e "\n3. Testing Write Operations:"
echo "Creating request via Backend1:"
curl -s -X POST http://localhost:3001/api/requests \
  -H "Content-Type: application/json" \
  -d '{"client_ip": "192.168.1.100", "user_agent": "Test Client"}' | jq .

echo -e "\nCreating request via Backend2:"
curl -s -X POST http://localhost:3002/api/requests \
  -H "Content-Type: application/json" \
  -d '{"client_ip": "192.168.1.101", "user_agent": "Test Client"}' | jq .

echo -e "\nCreating request via Backend3:"
curl -s -X POST http://localhost:3003/api/requests \
  -H "Content-Type: application/json" \
  -d '{"client_ip": "192.168.1.102", "user_agent": "Test Client"}' | jq .

# Test read operations (all backends read from Slave DBs with round-robin)
echo -e "\n4. Testing Read Operations:"
echo "Getting requests from Backend1 (reads from Slave DB):"
curl -s http://localhost:3001/api/requests | jq .

echo -e "\nGetting requests from Backend2 (reads from Slave DB):"
curl -s http://localhost:3002/api/requests | jq .

echo -e "\nGetting requests from Backend3 (reads from Slave DB):"
curl -s http://localhost:3003/api/requests | jq .

# Test statistics (all backends read from Slave DBs)
echo -e "\n5. Testing Statistics:"
echo "Stats from Backend1 (reads from Slave DB):"
curl -s http://localhost:3001/api/stats | jq .

echo -e "\nStats from Backend2 (reads from Slave DB):"
curl -s http://localhost:3002/api/stats | jq .

echo -e "\nStats from Backend3 (reads from Slave DB):"
curl -s http://localhost:3003/api/stats | jq .

echo -e "\n=== Test completed ==="