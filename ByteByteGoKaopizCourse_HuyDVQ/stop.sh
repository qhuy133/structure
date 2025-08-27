#!/bin/bash

echo "Stopping Load Balancer Demo..."

# Stop all services
sudo docker compose down

echo ""
echo "All services stopped!"
echo "To start again, run: ./start.sh"
