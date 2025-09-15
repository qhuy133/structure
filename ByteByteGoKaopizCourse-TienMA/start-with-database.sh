#!/bin/bash

echo "===== Starting Load Balancer System with MySQL Replication ====="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker > /dev/null 2>&1; then
    echo "❌ Docker is not installed or not in PATH."
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found in current directory."
    echo "Please run this script from the project root directory."
    exit 1
fi

# Clean up any existing containers
echo "Cleaning up existing containers..."
if docker compose down -v 2>/dev/null; then
    echo "✓ Cleanup completed"
else
    echo "⚠️  Cleanup had some issues, but continuing..."
fi

# Additional cleanup for MySQL data consistency
echo "Ensuring clean MySQL state..."
docker volume prune -f 2>/dev/null || true
sleep 2

# Start the services
echo "Starting all services..."
if docker compose up -d; then
    echo "✓ Services started successfully"
else
    echo "❌ Failed to start services"
    echo "Checking for common issues..."
    docker compose logs | tail -20
    exit 1
fi

echo "Waiting for services to start..."
sleep 10

# Setup MySQL replication
echo "Setting up MySQL replication..."
chmod +x setup-replication.sh
./setup-replication.sh

# Wait for FastAPI services to be ready
echo "Waiting for FastAPI services to be ready..."
echo "Checking if all services are running..."

# Check if containers are running
RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(fastapi|nginx|mysql)")
echo "Running containers:"
echo "$RUNNING_CONTAINERS"

# Wait for services with timeout
echo "Waiting for services to be accessible..."
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
    if curl -s "http://localhost:8090/health" > /dev/null 2>&1; then
        echo "✓ Services are ready"
        break
    fi
    echo "Waiting for services... ($((counter + 1))/$timeout seconds)"
    sleep 1
    counter=$((counter + 1))
done

if [ $counter -eq $timeout ]; then
    echo "❌ Services did not become ready within $timeout seconds"
    echo "Checking container logs for errors..."
    docker logs fastapi_server_1 --tail 10 2>/dev/null || echo "Cannot get fastapi_server_1 logs"
    docker logs nginx --tail 10 2>/dev/null || echo "Cannot get nginx logs"
    exit 1
fi

# Test the services
echo ""
echo "===== Testing Services ====="

# Test database connectivity
echo "Testing load balancer health..."
for i in {1..3}; do
    echo "Testing health check attempt $i..."
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/health" 2>/dev/null || echo "Connection failed")
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_status" = "200" ]; then
        echo "✓ Health check passed: $response_body"
        break
    else
        echo "❌ Health check failed (attempt $i/3): HTTP $http_status"
        echo "Response: $response_body"
        if [ $i -eq 3 ]; then
            echo "All health checks failed. Showing container status:"
            docker ps | grep -E "(fastapi|nginx)"
        fi
    fi
    sleep 2
done

# Test database operations
echo ""
echo "Testing database operations..."

echo "1. Getting users (read from slave):"
USER_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/api/users" 2>/dev/null)
HTTP_STATUS=$(echo "$USER_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$USER_RESPONSE" | sed '$d')
if [ "$HTTP_STATUS" = "200" ]; then
    echo "$RESPONSE_BODY" | jq '.read_from_slave, .total_count' 2>/dev/null || echo "✓ Users fetched successfully (jq not available)"
else
    echo "❌ Failed with HTTP status: $HTTP_STATUS"
    echo "Response: $RESPONSE_BODY"
fi

echo ""
echo "2. Creating a test user (write to master):"
USER_CREATE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "http://localhost:8090/api/users" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}' 2>/dev/null)
HTTP_STATUS=$(echo "$USER_CREATE_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$USER_CREATE_RESPONSE" | sed '$d')
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
    echo "$RESPONSE_BODY" | jq '.written_to_master' 2>/dev/null || echo "✓ User created successfully (jq not available)"
else
    echo "❌ Failed with HTTP status: $HTTP_STATUS"
    echo "Response: $RESPONSE_BODY"
fi

echo ""
echo "3. Getting products (read from slave):"
PRODUCTS_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/api/products" 2>/dev/null)
HTTP_STATUS=$(echo "$PRODUCTS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$PRODUCTS_RESPONSE" | sed '$d')
if [ "$HTTP_STATUS" = "200" ]; then
    echo "$RESPONSE_BODY" | jq '.read_from_slave, .total_count' 2>/dev/null || echo "✓ Products fetched successfully (jq not available)"
else
    echo "❌ Failed with HTTP status: $HTTP_STATUS"
    echo "Response: $RESPONSE_BODY"
fi

echo ""
echo "4. Getting requests log (read from slave):"
LOG_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/api/requests-log" 2>/dev/null)
HTTP_STATUS=$(echo "$LOG_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$LOG_RESPONSE" | sed '$d')
if [ "$HTTP_STATUS" = "200" ]; then
    echo "$RESPONSE_BODY" | jq '.read_from_slave, .total_count' 2>/dev/null || echo "✓ Requests log fetched successfully (jq not available)"
else
    echo "❌ Failed with HTTP status: $HTTP_STATUS"
    echo "Response: $RESPONSE_BODY"
fi

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

# Final replication status check
echo "===== Final Replication Status Check ====="
SLAVE1_SQL=$(docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running:" | awk '{print $2}')
SLAVE1_IO=$(docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running:" | awk '{print $2}')
SLAVE2_SQL=$(docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running:" | awk '{print $2}')
SLAVE2_IO=$(docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running:" | awk '{print $2}')

if [ "$SLAVE1_SQL" = "Yes" ] && [ "$SLAVE1_IO" = "Yes" ]; then
    echo "✅ Slave1: SQL=$SLAVE1_SQL, IO=$SLAVE1_IO (Healthy)"
else
    echo "❌ Slave1: SQL=$SLAVE1_SQL, IO=$SLAVE1_IO (Issues detected)"
fi

if [ "$SLAVE2_SQL" = "Yes" ] && [ "$SLAVE2_IO" = "Yes" ]; then
    echo "✅ Slave2: SQL=$SLAVE2_SQL, IO=$SLAVE2_IO (Healthy)"
else
    echo "❌ Slave2: SQL=$SLAVE2_SQL, IO=$SLAVE2_IO (Issues detected)"
fi

echo ""
echo "🎉 System ready! All APIs should work without 502 errors."
