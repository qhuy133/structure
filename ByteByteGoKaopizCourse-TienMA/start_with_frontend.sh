#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Load Balancer Demo with Frontend${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is running${NC}"
}

# Function to check if ports are available
check_ports() {
    local ports=(8090)
    for port in "${ports[@]}"; do
        if lsof -i :$port > /dev/null 2>&1; then
            echo -e "${RED}❌ Port $port is already in use${NC}"
            echo -e "${YELLOW}Please stop the service using port $port and try again${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}✅ Required ports are available${NC}"
}

# Function to build and start services
start_services() {
    echo -e "${YELLOW}🔨 Building and starting services...${NC}"
    
    # Build and start containers
    if docker-compose up --build -d; then
        echo -e "${GREEN}✅ Services started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start services${NC}"
        exit 1
    fi
}

# Function to wait for services to be ready
wait_for_services() {
    echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
    
    # Wait for nginx to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:8090/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Services are ready!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Attempt $attempt/$max_attempts - waiting for services...${NC}"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ Services did not start within expected time${NC}"
    echo -e "${YELLOW}Checking service status...${NC}"
    docker-compose logs --tail=20
    return 1
}

# Function to display service information
show_info() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Service Information${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}🌐 Frontend Dashboard: ${BLUE}http://localhost:8090${NC}"
    echo -e "${GREEN}🔗 API Health Check: ${BLUE}http://localhost:8090/health${NC}"
    echo -e "${GREEN}📊 API Users Endpoint: ${BLUE}http://localhost:8090/api/users${NC}"
    echo -e "${GREEN}🐌 API Slow Endpoint: ${BLUE}http://localhost:8090/api/slow${NC}"
    echo -e "${GREEN}📈 Nginx Status: ${BLUE}http://localhost:8090/nginx-status${NC}"
    echo ""
    echo -e "${YELLOW}💡 Tips:${NC}"
    echo -e "   • Open ${BLUE}http://localhost:8090${NC} in your browser to access the dashboard"
    echo -e "   • Use the dashboard buttons to test load balancing"
    echo -e "   • Monitor server status and request distribution"
    echo -e "   • Use keyboard shortcuts: Ctrl+R (refresh), Ctrl+U (load users), Ctrl+L (clear log)"
    echo ""
    echo -e "${BLUE}🐳 Docker Services:${NC}"
    docker-compose ps
    echo ""
    echo -e "${YELLOW}📝 To stop services: ${BLUE}docker-compose down${NC}"
    echo -e "${YELLOW}📋 To view logs: ${BLUE}docker-compose logs -f${NC}"
}

# Function to test the setup
test_setup() {
    echo -e "${YELLOW}🧪 Testing the setup...${NC}"
    
    # Test frontend
    if curl -f http://localhost:8090 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Frontend is accessible${NC}"
    else
        echo -e "${RED}❌ Frontend is not accessible${NC}"
        return 1
    fi
    
    # Test health endpoint
    if curl -f http://localhost:8090/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Health endpoint is working${NC}"
    else
        echo -e "${RED}❌ Health endpoint is not working${NC}"
        return 1
    fi
    
    # Test users API
    if curl -f http://localhost:8090/api/users > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Users API is working${NC}"
    else
        echo -e "${RED}❌ Users API is not working${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 All tests passed!${NC}"
}

# Main execution
main() {
    check_docker
    check_ports
    start_services
    
    if wait_for_services; then
        test_setup
        show_info
        echo -e "${GREEN}🚀 Load Balancer Demo with Frontend is ready!${NC}"
    else
        echo -e "${RED}❌ Failed to start services properly${NC}"
        exit 1
    fi
}

# Run main function
main

echo -e "${BLUE}========================================${NC}"
