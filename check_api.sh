#!/bin/bash

# API Base URL
API_URL="https://nmustafaozkaya.com.tr/api"
USER_ID="mustafa"

echo "=== API Durum Kontrolü ==="
echo ""

# 1. GET /api/stats endpoint testi
echo "1. GET /api/stats testi:"
curl -v "$API_URL/stats?userId=$USER_ID"
echo -e "\n"

# 2. POST /api/session endpoint testi
echo "2. POST /api/session testi:"
TIMESTAMP=$(date +%s)000
curl -v -X POST "$API_URL/session" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":\"$USER_ID\",\"source\":\"test\",\"minutes\":1,\"ts\":$TIMESTAMP}"
echo -e "\n"

# 3. Basit bağlantı testi
echo "3. Basit bağlantı testi:"
curl -I "$API_URL/stats?userId=$USER_ID" 2>&1 | head -n 1

