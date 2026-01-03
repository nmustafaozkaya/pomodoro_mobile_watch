#!/bin/bash
# Sunucuda API'yi test etmek için

echo "=== Pomodoro API Test ==="
echo ""

# 1. Health check
echo "1. Health Check:"
curl -s http://localhost:4001/health | jq .
echo ""

# 2. GET Stats
echo "2. GET /api/stats:"
curl -s "http://localhost:4001/api/stats?userId=mustafa" | jq .
echo ""

# 3. POST Session
echo "3. POST /api/session:"
TIMESTAMP=$(date +%s)000
curl -s -X POST "http://localhost:4001/api/session" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":\"mustafa\",\"source\":\"test\",\"minutes\":5,\"ts\":$TIMESTAMP}" | jq .
echo ""

# 4. Tekrar Stats (değişikliği görmek için)
echo "4. GET /api/stats (after POST):"
curl -s "http://localhost:4001/api/stats?userId=mustafa" | jq .
echo ""

echo "Test tamamlandı!"

