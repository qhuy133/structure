#!/bin/bash

echo "=== Testing Load Balancer Demo Connectivity ==="
echo

# Test if containers are running
echo "1. Checking if containers are running..."
if command -v docker &> /dev/null; then
    if sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(frontend|loadbalancer|backend|mysql)" | head -10; then
        echo "✓ Some containers are running"
    else
        echo "✗ No containers found. Please start the services first:"
        echo "  sudo docker compose up -d"
        exit 1
    fi
else
    echo "✗ Docker not found. Please install Docker first."
    exit 1
fi

echo

# Test frontend health
echo "2. Testing frontend health endpoint..."
if curl -s http://localhost/health 2>/dev/null; then
    echo "✓ Frontend is accessible"
else
    echo "✗ Frontend is not accessible on port 80"
fi

echo

# Test load balancer health
echo "3. Testing load balancer health endpoint..."
if curl -s http://localhost:8080/health 2>/dev/null; then
    echo "✓ Load balancer is accessible"
else
    echo "✗ Load balancer is not accessible on port 8080"
fi

echo

# Test API endpoints through frontend
echo "4. Testing API endpoints through frontend..."
echo "   Testing /api/stats..."
if curl -s -w "HTTP Status: %{http_code}, Content-Type: %{content_type}\n" http://localhost/api/stats 2>/dev/null | head -1; then
    echo "✓ API endpoint /api/stats is accessible"
else
    echo "✗ API endpoint /api/stats is not accessible"
fi

echo

# Test direct backend access
echo "5. Testing direct backend access..."
for port in 3001 3002 3003; do
    if curl -s http://localhost:$port/health 2>/dev/null | grep -q "healthy"; then
        echo "✓ Backend on port $port is healthy"
    else
        echo "✗ Backend on port $port is not accessible or unhealthy"
    fi
done

echo

# Test database connectivity
echo "6. Testing database connectivity..."
if curl -s http://localhost:3306 2>/dev/null | head -1; then
    echo "✓ MySQL is accessible on port 3306"
else
    echo "✗ MySQL is not accessible on port 3306"
fi

echo
echo "=== Connectivity Test Complete ==="
echo
echo "If you see errors above, try:"
echo "1. Start services: sudo docker compose up -d"
echo "2. Check logs: sudo docker compose logs"
echo "3. Restart services: sudo docker compose restart" 