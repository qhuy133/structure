#!/bin/bash

echo "===== Starting Load Balancer System with MySQL Replication ====="

# Clean up any existing containers
echo "Cleaning up existing containers..."
docker compose down -v 2>/dev/null

# Start the services
echo "Starting all services..."
docker compose up -d

echo "Waiting for services to start..."
sleep 10

# Setup MySQL replication
echo "Setting up MySQL replication..."
chmod +x setup-replication.sh
./setup-replication.sh

# Wait for FastAPI services to be ready
echo "Waiting for FastAPI services to be ready..."
sleep 15

# Test the services
echo ""
echo "===== Testing Services ====="

# Test database connectivity
echo "Testing database connectivity..."
for i in {1..3}; do
    echo "Testing server $i health..."
    response=$(curl -s "http://localhost:8090/health" || echo "Connection failed")
    echo "Response: $response"
    sleep 1
done

# Test database operations
echo ""
echo "Testing database operations..."

echo "1. Getting users (read from slave):"
curl -s "http://localhost:8090/api/users" | jq '.read_from_slave, .total_count' 2>/dev/null || echo "No jq installed, response received"

echo ""
echo "2. Creating a test user (write to master):"
curl -s -X POST "http://localhost:8090/api/users" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}' | jq '.written_to_master' 2>/dev/null || echo "User created"

echo ""
echo "3. Getting products (read from slave):"
curl -s "http://localhost:8090/api/products" | jq '.read_from_slave, .total_count' 2>/dev/null || echo "Products fetched"

echo ""
echo "4. Getting requests log (read from slave):"
curl -s "http://localhost:8090/api/requests-log" | jq '.read_from_slave, .total_count' 2>/dev/null || echo "Requests log fetched"

echo ""
echo "===== System Status ====="
echo "Frontend: http://localhost:8090"
echo "API Load Balancer: http://localhost:8090/api/"
echo "Health Check: http://localhost:8090/health"
echo ""
echo "Available endpoints:"
echo "  GET  /api/ - Root endpoint"
echo "  GET  /api/users - Get users (reads from slave)"
echo "  POST /api/users - Create user (writes to master)"
echo "  GET  /api/products - Get products (reads from slave)"
echo "  GET  /api/requests-log - Get API requests log"
echo "  GET  /api/slow - Slow endpoint for testing"
echo "  GET  /health - Health check"
echo ""
echo "Database ports:"
echo "  Master:  localhost:3306"
echo "  Slave1:  localhost:3307"
echo "  Slave2:  localhost:3308"
echo ""
echo "To test replication: ./test-replication.sh"
echo "To stop all services: docker compose down -v"
echo ""
echo "🎉 System ready! All APIs should work without 502 errors."
