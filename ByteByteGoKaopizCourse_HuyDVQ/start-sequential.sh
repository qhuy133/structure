#!/bin/bash

echo "=== Starting MySQL Master-Slave Replication System ==="

# Step 1: Start MySQL databases
echo "Step 1: Starting MySQL databases..."
docker compose up -d mysql-master mysql-slave1 mysql-slave2

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
sleep 30

# Step 2: Setup replication
echo "Step 2: Setting up replication..."
./setup-replication.sh

# Step 3: Start backend servers
echo "Step 3: Starting backend servers..."
docker compose up -d backend1 backend2 backend3

# Wait for backends to connect to databases
echo "Waiting for backends to connect to databases..."
sleep 20

# Step 4: Start load balancer
echo "Step 4: Starting load balancer..."
docker compose up -d loadbalancer

# Wait for load balancer
sleep 10

# Step 5: Start frontend
echo "Step 5: Starting frontend..."
docker compose up -d frontend

# Wait for frontend
sleep 10

# Step 6: Test the system
echo "Step 6: Testing the system..."

echo "Testing backend health..."
curl -s http://localhost:3001/health | jq .

echo "Testing API..."
curl -s http://localhost/api/stats | jq .

echo ""
echo "=== System Started Successfully ==="
echo "Frontend: http://localhost"
echo "Load Balancer: http://localhost:8080"
echo "Backend1: http://localhost:3001"
echo "Backend2: http://localhost:3002"
echo "Backend3: http://localhost:3003"