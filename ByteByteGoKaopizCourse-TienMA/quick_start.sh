#!/bin/bash

echo "🚀 Load Balancer Demo Quick Start"
echo "================================="

# Kiểm tra Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker chưa được cài đặt. Vui lòng cài Docker trước."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose chưa được cài đặt. Vui lòng cài Docker Compose trước."
    exit 1
fi

echo "✅ Docker và Docker Compose đã sẵn sàng"

# Dọn dẹp containers cũ nếu có
echo "🧹 Dọn dẹp containers cũ..."
docker compose down --remove-orphans 2>/dev/null || true

# Build và khởi động services
echo "🔨 Build và khởi động services..."
docker compose up --build -d

# Chờ services khởi động
echo "⏳ Chờ services khởi động (30 giây)..."
sleep 30

# Kiểm tra health
echo "🏥 Kiểm tra health của services..."
curl -s http://localhost/nginx-health > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Nginx Load Balancer: OK"
else
    echo "❌ Nginx Load Balancer: FAILED"
fi

curl -s http://localhost/health > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ FastAPI Servers: OK"
else
    echo "❌ FastAPI Servers: FAILED"
fi

echo ""
echo "🎉 Hệ thống đã sẵn sàng!"
echo ""
echo "📋 URLs để test:"
echo "   - Home: http://localhost/"
echo "   - API Users: http://localhost/api/users"
echo "   - Health Check: http://localhost/health"
echo "   - Nginx Status: http://localhost/nginx-status"
echo ""
echo "🔧 Commands hữu ích:"
echo "   - Xem logs: docker compose logs -f"
echo "   - Stop services: docker compose down"
echo "   - Test load balancer: python test_load_balancer.py"
echo ""
echo "📊 Test load balancing ngay:"

# Test nhanh
for i in {1..5}; do
    response=$(curl -s http://localhost/ | grep -o '"server_id":"[^"]*"' | cut -d'"' -f4)
    echo "  Request $i: $response"
    sleep 0.5
done 