#!/bin/bash

echo "🚀 Starting Load Balancer System with MySQL Replication & Celery Worker"
echo "====================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is running${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "\n${BLUE}Checking prerequisites...${NC}"
    
    # Check if docker compose is available
    if ! command -v docker > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not installed or not in PATH.${NC}"
        exit 1
    fi
    
    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}❌ docker-compose.yml not found in current directory.${NC}"
        echo -e "${YELLOW}Please run this script from the project root directory.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Function to stop existing containers
stop_existing() {
    echo -e "\n${BLUE}Stopping existing containers...${NC}"
    if docker compose down -v 2>/dev/null; then
        echo -e "${GREEN}✅ Cleanup completed${NC}"
    else
        echo -e "${YELLOW}⚠️  Cleanup had some issues, but continuing...${NC}"
    fi
    
    # Additional cleanup for MySQL data consistency
    echo -e "${BLUE}Ensuring clean MySQL state...${NC}"
    docker volume prune -f 2>/dev/null || true
    sleep 2
}

# Function to start services
start_services() {
    echo -e "\n${BLUE}Starting all services...${NC}"
    if docker compose up -d --build; then
        echo -e "${GREEN}✅ Services started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start services${NC}"
        echo -e "${YELLOW}Checking for common issues...${NC}"
        docker compose logs | tail -20
        exit 1
    fi
}

# Function to wait for services to be ready
wait_for_services() {
    echo -e "\n${BLUE}Waiting for services to start...${NC}"
    sleep 10
    
    # Wait for MySQL master
    echo -e "\n${BLUE}Waiting for MySQL Master...${NC}"
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker exec mysql_master mysqladmin ping -h localhost --silent 2>/dev/null; then
            echo -e "${GREEN}✅ MySQL Master is ready${NC}"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        echo -e "${RED}❌ MySQL Master failed to start${NC}"
        exit 1
    fi
    
    # Wait for Redis
    echo -e "\n${BLUE}Waiting for Redis...${NC}"
    timeout=30
    while [ $timeout -gt 0 ]; do
        if docker exec redis_broker redis-cli ping > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Redis is ready${NC}"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        echo -e "${RED}❌ Redis failed to start${NC}"
        exit 1
    fi
    
    # Setup MySQL replication
    echo -e "\n${BLUE}Setting up MySQL replication...${NC}"
    chmod +x setup-replication.sh
    if ./setup-replication.sh; then
        echo -e "${GREEN}✅ MySQL replication setup completed${NC}"
    else
        echo -e "${RED}❌ MySQL replication setup failed${NC}"
        exit 1
    fi
}

# Function to check service status
check_service_status() {
    echo -e "\n${BLUE}Checking service status...${NC}"
    
    # Check if containers are running
    RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(fastapi|nginx|mysql|redis|celery)")
    echo -e "${BLUE}Running containers:${NC}"
    echo "$RUNNING_CONTAINERS"
    
    # Wait for services with timeout
    echo -e "\n${BLUE}Waiting for services to be accessible...${NC}"
    timeout=60
    counter=0
    while [ $counter -lt $timeout ]; do
        if curl -s "http://localhost:8090/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Services are ready${NC}"
            break
        fi
        echo -e "${YELLOW}Waiting for services... ($((counter + 1))/$timeout seconds)${NC}"
        sleep 1
        counter=$((counter + 1))
    done
    
    if [ $counter -eq $timeout ]; then
        echo -e "${RED}❌ Services did not become ready within $timeout seconds${NC}"
        echo -e "${YELLOW}Checking container logs for errors...${NC}"
        docker logs fastapi_server_1 --tail 10 2>/dev/null || echo "Cannot get fastapi_server_1 logs"
        docker logs nginx --tail 10 2>/dev/null || echo "Cannot get nginx logs"
        exit 1
    fi
}

# Function to test services
test_services() {
    echo -e "\n${YELLOW}===== Testing Services =====${NC}"
    
    # Test database connectivity
    echo -e "\n${BLUE}Testing load balancer health...${NC}"
    for i in {1..3}; do
        echo -e "${BLUE}Testing health check attempt $i...${NC}"
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/health" 2>/dev/null || echo "Connection failed")
        http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
        response_body=$(echo "$response" | head -n -1)
        
        if [ "$http_status" = "200" ]; then
            echo -e "${GREEN}✅ Health check passed: $response_body${NC}"
            break
        else
            echo -e "${RED}❌ Health check failed (attempt $i/3): HTTP $http_status${NC}"
            echo "Response: $response_body"
            if [ $i -eq 3 ]; then
                echo -e "${YELLOW}All health checks failed. Showing container status:${NC}"
                docker ps | grep -E "(fastapi|nginx)"
            fi
        fi
        sleep 2
    done
    
    # Test worker status
    echo -e "\n${BLUE}Testing worker status...${NC}"
    WORKER_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/api/worker/status" 2>/dev/null)
    HTTP_STATUS=$(echo "$WORKER_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$WORKER_RESPONSE" | sed '$d')
    
    if [ "$HTTP_STATUS" = "200" ]; then
        echo -e "${GREEN}✅ Worker status check passed${NC}"
        echo "$RESPONSE_BODY" | jq '.status, .redis_connected, .worker_available' 2>/dev/null || echo "Worker status: Available"
    else
        echo -e "${YELLOW}⚠️  Worker status check failed (HTTP $HTTP_STATUS) - Worker may not be available${NC}"
    fi
}

# Function to test database operations
test_database_operations() {
    echo -e "\n${BLUE}Testing database operations...${NC}"
    
    echo -e "\n${BLUE}1. Getting users (read from slave):${NC}"
    USER_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/api/users" 2>/dev/null)
    HTTP_STATUS=$(echo "$USER_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$USER_RESPONSE" | sed '$d')
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "$RESPONSE_BODY" | jq '.read_from_slave, .total_count' 2>/dev/null || echo -e "${GREEN}✅ Users fetched successfully (jq not available)${NC}"
    else
        echo -e "${RED}❌ Failed with HTTP status: $HTTP_STATUS${NC}"
        echo "Response: $RESPONSE_BODY"
    fi
    
    echo -e "\n${BLUE}2. Creating a test user (write to master):${NC}"
    USER_CREATE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "http://localhost:8090/api/users" \
      -H "Content-Type: application/json" \
      -d '{"name": "Test User", "email": "test@example.com"}' 2>/dev/null)
    HTTP_STATUS=$(echo "$USER_CREATE_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$USER_CREATE_RESPONSE" | sed '$d')
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
        echo "$RESPONSE_BODY" | jq '.written_to_master' 2>/dev/null || echo -e "${GREEN}✅ User created successfully (jq not available)${NC}"
    else
        echo -e "${RED}❌ Failed with HTTP status: $HTTP_STATUS${NC}"
        echo "Response: $RESPONSE_BODY"
    fi
    
    echo -e "\n${BLUE}3. Getting products (read from slave):${NC}"
    PRODUCTS_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/api/products" 2>/dev/null)
    HTTP_STATUS=$(echo "$PRODUCTS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$PRODUCTS_RESPONSE" | sed '$d')
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "$RESPONSE_BODY" | jq '.read_from_slave, .total_count' 2>/dev/null || echo -e "${GREEN}✅ Products fetched successfully (jq not available)${NC}"
    else
        echo -e "${RED}❌ Failed with HTTP status: $HTTP_STATUS${NC}"
        echo "Response: $RESPONSE_BODY"
    fi
    
    echo -e "\n${BLUE}4. Getting requests log (read from slave):${NC}"
    LOG_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "http://localhost:8090/api/requests-log" 2>/dev/null)
    HTTP_STATUS=$(echo "$LOG_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$LOG_RESPONSE" | sed '$d')
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "$RESPONSE_BODY" | jq '.read_from_slave, .total_count' 2>/dev/null || echo -e "${GREEN}✅ Requests log fetched successfully (jq not available)${NC}"
    else
        echo -e "${RED}❌ Failed with HTTP status: $HTTP_STATUS${NC}"
        echo "Response: $RESPONSE_BODY"
    fi
}

# Function to show system status
show_system_status() {
    echo -e "\n${YELLOW}===== System Status =====${NC}"
    echo -e "${BLUE}Frontend:${NC} http://localhost:8090"
    echo -e "${BLUE}API Load Balancer:${NC} http://localhost:8090/api/"
    echo -e "${BLUE}Health Check:${NC} http://localhost:8090/health"
    echo ""
    echo -e "${BLUE}Available endpoints:${NC}"
    echo "  GET  /api/ - Root endpoint"
    echo "  GET  /api/users - Get users (reads from slave)"
    echo "  POST /api/users - Create user (writes to master)"
    echo "  GET  /api/products - Get products (reads from slave)"
    echo "  GET  /api/requests-log - Get API requests log"
    echo "  GET  /api/slow - Slow endpoint for testing"
    echo "  GET  /health - Health check"
    echo ""
    echo -e "${BLUE}Worker endpoints:${NC}"
    echo "  GET  /api/worker/status - Check worker status"
    echo "  POST /api/worker/test - Test worker connection"
    echo "  POST /api/users/{id}/create-product - Create product for user (async)"
    echo "  GET  /api/tasks/{task_id} - Check task status"
    echo ""
    echo -e "${BLUE}Database ports:${NC}"
    echo "  Master:  localhost:3306"
    echo "  Slave1:  localhost:3307"
    echo "  Slave2:  localhost:3308"
    echo "  Redis:   localhost:6379"
    echo ""
    echo -e "${BLUE}Testing Commands:${NC}"
    echo "  🧪 Test Worker: ${GREEN}./test-worker.sh${NC}"
    echo "  🧪 Test Replication: ${GREEN}./test-replication.sh${NC}"
    echo "  🛑 Stop System: ${GREEN}docker compose down -v${NC}"
    echo ""
}

# Function to check final replication status
check_replication_status() {
    echo -e "\n${YELLOW}===== Final Replication Status Check =====${NC}"
    SLAVE1_SQL=$(docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running:" | awk '{print $2}')
    SLAVE1_IO=$(docker exec mysql_slave1 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running:" | awk '{print $2}')
    SLAVE2_SQL=$(docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running:" | awk '{print $2}')
    SLAVE2_IO=$(docker exec mysql_slave2 mysql -u root -prootpassword -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running:" | awk '{print $2}')
    
    if [ "$SLAVE1_SQL" = "Yes" ] && [ "$SLAVE1_IO" = "Yes" ]; then
        echo -e "${GREEN}✅ Slave1: SQL=$SLAVE1_SQL, IO=$SLAVE1_IO (Healthy)${NC}"
    else
        echo -e "${RED}❌ Slave1: SQL=$SLAVE1_SQL, IO=$SLAVE1_IO (Issues detected)${NC}"
    fi
    
    if [ "$SLAVE2_SQL" = "Yes" ] && [ "$SLAVE2_IO" = "Yes" ]; then
        echo -e "${GREEN}✅ Slave2: SQL=$SLAVE2_SQL, IO=$SLAVE2_IO (Healthy)${NC}"
    else
        echo -e "${RED}❌ Slave2: SQL=$SLAVE2_SQL, IO=$SLAVE2_IO (Issues detected)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 System ready! Load Balancer, MySQL Replication, and Celery Worker are all running.${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting system initialization...${NC}"
    
    # Check prerequisites
    check_docker
    check_prerequisites
    
    # Stop existing containers
    stop_existing
    
    # Start services
    start_services
    
    # Wait for services and setup replication
    wait_for_services
    
    # Check service status
    check_service_status
    
    # Test services
    test_services
    test_database_operations
    
    # Show system status
    show_system_status
    
    # Check replication status
    check_replication_status
}

# Run main function
main "$@"
