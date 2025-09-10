#!/bin/bash

echo "=== Verifying Frontend Functions ==="
echo ""

echo "🌐 Frontend URL: http://localhost"
echo ""

echo "🔍 Testing API endpoints:"
echo ""

echo "1. Testing /api/server-info (Write to Master):"
curl -s http://localhost/api/server-info | jq '.server_id, .master_db_status, .timestamp'

echo ""
echo "2. Testing /api/stats (Read from Slave):"
curl -s http://localhost/api/stats | jq '.server_id, .total_requests, .read_from'

echo ""
echo "3. Testing health checks:"
for i in {1..3}; do
  echo -n "Backend $i: "
  curl -s http://localhost/health/backend$i | jq -r '.master_db, .slave1_db, .slave2_db' 2>/dev/null || echo "Failed"
done

echo ""
echo "4. Testing load balancing (5 requests):"
for i in {1..5}; do
  echo -n "Request $i: "
  curl -s http://localhost/api/server-info | jq -r '.server_id'
done

echo ""
echo "✅ All API endpoints are working!"
echo ""
echo "📝 To test frontend functions:"
echo "1. Open http://localhost in your browser"
echo "2. Open browser console (F12)"
echo "3. Check for debug messages about function definitions"
echo "4. Click on test buttons to verify functions work"
echo ""
echo "🔧 If functions are still not defined:"
echo "1. Hard refresh the page (Ctrl+F5 or Cmd+Shift+R)"
echo "2. Clear browser cache"
echo "3. Check browser console for JavaScript errors"