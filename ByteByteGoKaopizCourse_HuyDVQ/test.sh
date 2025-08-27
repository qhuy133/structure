#!/bin/bash

echo "Testing Load Balancer Demo APIs..."
echo ""

# Test frontend
echo "1. Testing Frontend (http://localhost)..."
if curl -s http://localhost > /dev/null; then
    echo "   ✓ Frontend is accessible"
else
    echo "   ✗ Frontend is not accessible"
fi

echo ""

# Test load balancer
echo "2. Testing Load Balancer (http://localhost:8080)..."
if curl -s http://localhost:8080/health > /dev/null; then
    echo "   ✓ Load Balancer is accessible"
else
    echo "   ✗ Load Balancer is not accessible"
fi

echo ""

# Test backend servers directly
echo "3. Testing Backend Servers directly..."
for port in 3001 3002 3003; do
    if curl -s http://localhost:$port/health > /dev/null; then
        echo "   ✓ Backend Server on port $port is accessible"
    else
        echo "   ✗ Backend Server on port $port is not accessible"
    fi
done

echo ""

# Test load balancing
echo "4. Testing Load Balancing (Round Robin)..."
echo "   Sending 6 requests to see Round Robin in action:"
for i in {1..6}; do
    response=$(curl -s http://localhost/api/server-info)
    server_id=$(echo $response | grep -o server_id:[^]*' | cut -d' -f4)
    echo "   Request $i: Server $server_id"
done

echo ""
echo "Test completed!"
