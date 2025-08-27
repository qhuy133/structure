#!/bin/bash

echo "Starting Load Balancer Demo..."
echo "Building and starting all services..."

# Build and start all services
sudo docker compose up --build -d

echo ""
echo "Waiting for services to start..."
sleep 10

echo ""
echo "Checking service status..."
sudo docker compose ps

echo ""
echo "Checking logs..."
sudo docker compose logs --tail=20

echo ""
echo "Load Balancer Demo is now running!"
echo "Frontend: http://localhost"
echo "Load Balancer: http://localhost:8080"
echo "Backend Servers:"
echo "  - Server 1: http://localhost:3001"
echo "  - Server 2: http://localhost:3002"
echo "  - Server 3: http://localhost:3003"
echo ""
echo "Open http://localhost in your browser to test the load balancer!"
echo ""
echo "To stop all services, run: sudo docker compose down"
echo "To view logs, run: sudo docker compose logs -f"
