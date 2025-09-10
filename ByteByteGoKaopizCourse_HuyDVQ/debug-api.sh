#!/bin/bash

echo "=== Debug API Responses ==="

# Test 1: Frontend health
echo "1. Testing frontend health..."
echo "Response:"
curl -v http://localhost/health 2>&1
echo ""

# Test 2: Load balancer health
echo "2. Testing load balancer health..."
echo "Response:"
curl -v http://localhost:8080/health 2>&1
echo ""

# Test 3: API stats
echo "3. Testing /api/stats..."
echo "Response:"
curl -v http://localhost/api/stats 2>&1
echo ""

# Test 4: Direct backend
echo "4. Testing direct backend..."
echo "Response:"
curl -v http://localhost:3001/health 2>&1
echo ""

# Test 5: Check Docker services
echo "5. Checking Docker services..."
docker-compose ps
echo ""

# Test 6: Check if services are running
echo "6. Checking if services are running..."
docker-compose logs --tail=10 frontend
echo "---"
docker-compose logs --tail=10 loadbalancer
echo "---"
docker-compose logs --tail=10 backend1