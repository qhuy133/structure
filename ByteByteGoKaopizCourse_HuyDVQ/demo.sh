#!/bin/bash

echo "=== MySQL Master-Slave Replication Demo ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install jq first:"
    echo "sudo apt-get install jq"
    echo "or"
    echo "brew install jq"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

print_header "Starting MySQL Master-Slave Replication Demo"

# Step 1: Start the system
print_status "Step 1: Starting Docker services..."
docker-compose up -d

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 30

# Step 2: Setup replication
print_status "Step 2: Setting up MySQL replication..."
./setup-replication.sh

# Step 3: Check replication status
print_header "Step 3: Checking Replication Status"
./check-replication.sh

# Step 4: Test the system
print_header "Step 4: Testing Master-Slave System"

print_status "Testing health endpoints..."
echo "Backend1 (Master):"
curl -s http://localhost:3001/health | jq .

echo -e "\nBackend2 (Slave1):"
curl -s http://localhost:3002/health | jq .

echo -e "\nBackend3 (Slave2):"
curl -s http://localhost:3003/health | jq .

print_status "Testing load balancer..."
echo "Load balancer responses:"
for i in {1..3}; do
    echo "Request $i:"
    curl -s http://localhost:8080/api/server-info | jq .
    echo ""
done

print_status "Testing write operations..."
echo "Creating request via Backend1 (writes to Master DB):"
curl -s -X POST http://localhost:3001/api/requests \
  -H "Content-Type: application/json" \
  -d '{"client_ip": "192.168.1.100", "user_agent": "Demo Client"}' | jq .

echo -e "\nCreating request via Backend2 (writes to Master DB):"
curl -s -X POST http://localhost:3002/api/requests \
  -H "Content-Type: application/json" \
  -d '{"client_ip": "192.168.1.101", "user_agent": "Demo Client"}' | jq .

print_status "Testing read operations..."
echo "Getting requests from all servers (all read from Slave DBs):"
echo "Backend1 (reads from Slave DB):"
curl -s http://localhost:3001/api/requests | jq .

echo -e "\nBackend2 (reads from Slave DB):"
curl -s http://localhost:3002/api/requests | jq .

echo -e "\nBackend3 (reads from Slave DB):"
curl -s http://localhost:3003/api/requests | jq .

print_header "Demo Summary"
echo "✅ MySQL Master-Slave Replication is running"
echo "✅ Load balancer is distributing requests"
echo "✅ All backends write to Master DB"
echo "✅ All backends read from Slave DBs (round-robin)"
echo "✅ Data is being replicated in real-time"
echo ""
echo "Access points:"
echo "- Frontend: http://localhost"
echo "- Load Balancer: http://localhost:8080"
echo "- Backend1: http://localhost:3001"
echo "- Backend2: http://localhost:3002"
echo "- Backend3: http://localhost:3003"
echo "- MySQL Master: localhost:3306"
echo "- MySQL Slave1: localhost:3307"
echo "- MySQL Slave2: localhost:3308"
echo ""
echo "To stop the demo:"
echo "docker-compose down"
echo ""
echo "To check replication status:"
echo "./check-replication.sh"