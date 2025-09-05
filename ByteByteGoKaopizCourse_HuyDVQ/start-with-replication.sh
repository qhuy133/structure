#!/bin/bash

echo "Starting MySQL Master-Slave Replication setup..."

# Create necessary directories
mkdir -p mysql/master mysql/slave1 mysql/slave2

# Start services
echo "Starting Docker services..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 30

# Setup replication
echo "Setting up replication..."
./setup-replication.sh

# Check replication status
echo "Checking replication status..."
./check-replication.sh

echo "Setup completed! Services are running:"
echo "- Frontend: http://localhost"
echo "- Load Balancer: http://localhost:8080"
echo "- Backend1 (Master): http://localhost:3001"
echo "- Backend2 (Slave1): http://localhost:3002"
echo "- Backend3 (Slave2): http://localhost:3003"
echo "- MySQL Master: localhost:3306"
echo "- MySQL Slave1: localhost:3307"
echo "- MySQL Slave2: localhost:3308"