#!/bin/bash

# Test script for Celery Worker functionality
# This script tests the worker queue system

echo "🚀 Testing Celery Worker System"
echo "================================"

BASE_URL="http://localhost:8090"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to make API requests
make_request() {
    local method=$1
    local url=$2
    local data=$3
    
    if [ "$method" = "GET" ]; then
        curl -s -w "\n%{http_code}" "$url"
    else
        curl -s -w "\n%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" "$url"
    fi
}

# Function to check if service is running
check_service() {
    local service_name=$1
    local url=$2
    
    echo -e "${BLUE}Checking $service_name...${NC}"
    response=$(make_request "GET" "$url")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ $service_name is running${NC}"
        return 0
    else
        echo -e "${RED}❌ $service_name is not responding (HTTP $http_code)${NC}"
        return 1
    fi
}

# Function to test worker
test_worker() {
    echo -e "\n${YELLOW}Testing Worker Functionality${NC}"
    echo "=========================="
    
    # Test 1: Check worker status
    echo -e "\n${BLUE}1. Checking worker status...${NC}"
    response=$(make_request "GET" "$BASE_URL/api/worker/status")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Worker status endpoint working${NC}"
        echo "Response: $body"
    else
        echo -e "${RED}❌ Worker status endpoint failed (HTTP $http_code)${NC}"
        return 1
    fi
    
    # Test 2: Test worker connection
    echo -e "\n${BLUE}2. Testing worker connection...${NC}"
    response=$(make_request "POST" "$BASE_URL/api/worker/test" "{}")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Worker test task queued${NC}"
        task_id=$(echo "$body" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)
        echo "Task ID: $task_id"
        
        # Wait and check task status
        echo -e "\n${BLUE}3. Checking task status...${NC}"
        sleep 3
        response=$(make_request "GET" "$BASE_URL/api/tasks/$task_id")
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n -1)
        
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✅ Task status retrieved${NC}"
            echo "Task Status: $body"
        else
            echo -e "${RED}❌ Failed to get task status (HTTP $http_code)${NC}"
        fi
    else
        echo -e "${RED}❌ Worker test failed (HTTP $http_code)${NC}"
        return 1
    fi
}

# Function to test product creation
test_product_creation() {
    echo -e "\n${YELLOW}Testing Product Creation${NC}"
    echo "======================="
    
    # First, create a test user
    echo -e "\n${BLUE}1. Creating test user...${NC}"
    user_data='{"name":"Test User Worker","email":"testworker@example.com"}'
    response=$(make_request "POST" "$BASE_URL/api/users" "$user_data")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Test user created${NC}"
        user_id=$(echo "$body" | grep -o '"user_id":[0-9]*' | cut -d':' -f2)
        echo "User ID: $user_id"
        
        # Now test product creation for this user
        echo -e "\n${BLUE}2. Creating product for user...${NC}"
        response=$(make_request "POST" "$BASE_URL/api/users/$user_id/create-product" "{}")
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n -1)
        
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✅ Product creation task queued${NC}"
            task_id=$(echo "$body" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4)
            echo "Task ID: $task_id"
            
            # Wait and check task status
            echo -e "\n${BLUE}3. Checking product creation task status...${NC}"
            sleep 5
            response=$(make_request "GET" "$BASE_URL/api/tasks/$task_id")
            http_code=$(echo "$response" | tail -n1)
            body=$(echo "$response" | head -n -1)
            
            if [ "$http_code" = "200" ]; then
                echo -e "${GREEN}✅ Product creation task status retrieved${NC}"
                echo "Task Status: $body"
                
                # Check if product was created
                echo -e "\n${BLUE}4. Checking if product was created...${NC}"
                response=$(make_request "GET" "$BASE_URL/api/products")
                http_code=$(echo "$response" | tail -n1)
                body=$(echo "$response" | head -n -1)
                
                if [ "$http_code" = "200" ]; then
                    echo -e "${GREEN}✅ Products retrieved${NC}"
                    if echo "$body" | grep -q "Product for Test User Worker"; then
                        echo -e "${GREEN}✅ Product was successfully created by worker!${NC}"
                    else
                        echo -e "${YELLOW}⚠️  Product creation may still be in progress${NC}"
                    fi
                else
                    echo -e "${RED}❌ Failed to retrieve products (HTTP $http_code)${NC}"
                fi
            else
                echo -e "${RED}❌ Failed to get product creation task status (HTTP $http_code)${NC}"
            fi
        else
            echo -e "${RED}❌ Product creation task failed (HTTP $http_code)${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to create test user (HTTP $http_code)${NC}"
    fi
}

# Main test execution
echo -e "${BLUE}Starting comprehensive worker tests...${NC}"

# Check if services are running
echo -e "\n${YELLOW}Service Health Checks${NC}"
echo "===================="

check_service "Main API" "$BASE_URL/health" || exit 1
check_service "Worker Status" "$BASE_URL/api/worker/status" || exit 1

# Test worker functionality
test_worker

# Test product creation
test_product_creation

echo -e "\n${GREEN}🎉 Worker testing completed!${NC}"
echo -e "${BLUE}You can also test the system through the web interface at: $BASE_URL${NC}"
echo -e "${BLUE}Use the new worker buttons in the dashboard to interact with the system.${NC}"
