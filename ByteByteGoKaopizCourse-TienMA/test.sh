#!/bin/bash

echo "===== Testing Load Balancer System ====="

# Test all endpoints
echo "1. Testing Health Check..."
curl -s http://localhost:8090/health | python3 -m json.tool | head -5

echo -e "\n2. Testing Main API..."
curl -s http://localhost:8090/api/ | python3 -m json.tool | head -5

echo -e "\n3. Testing Users API..."
curl -s http://localhost:8090/api/users | python3 -m json.tool | head -10

echo -e "\n4. Testing Products API..."  
curl -s http://localhost:8090/api/products | python3 -m json.tool | head -10

echo -e "\n5. Testing Requests Log..."
curl -s http://localhost:8090/api/requests-log | python3 -m json.tool | head -5

echo -e "\n6. Testing Slow Endpoint..."
curl -s http://localhost:8090/api/slow | python3 -m json.tool | head -5

echo -e "\n===== Test Complete ====="
echo "Frontend: http://localhost:8090"
echo "All endpoints should return 200 OK"
