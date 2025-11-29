# AWS Ubuntu Sunucusunda API Kontrol Komutları

## 1. Sunucuya SSH ile Bağlanma
```bash
ssh -i your-key.pem ubuntu@your-server-ip
# veya
ssh ubuntu@nmustafaozkaya.com.tr
```

## 2. API Servisinin Çalışıp Çalışmadığını Kontrol

### Node.js/Express API ise:
```bash
# PM2 ile çalışıyorsa
pm2 list
pm2 logs
pm2 status

# systemd service ise
sudo systemctl status your-api-service
sudo systemctl status node-api
sudo systemctl status pomodoro-api

# Process kontrolü
ps aux | grep node
ps aux | grep api
```

### Python/Flask/FastAPI ise:
```bash
# systemd service kontrolü
sudo systemctl status your-api-service
sudo systemctl status gunicorn
sudo systemctl status uwsgi

# Process kontrolü
ps aux | grep python
ps aux | grep gunicorn
```

### Nginx/Apache reverse proxy kontrolü:
```bash
# Nginx durumu
sudo systemctl status nginx
sudo nginx -t

# Apache durumu
sudo systemctl status apache2

# Nginx logları
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 3. Port Dinleme Durumu
```bash
# Hangi portlar dinleniyor?
sudo netstat -tulpn | grep LISTEN
# veya
sudo ss -tulpn | grep LISTEN

# Belirli bir port kontrolü (örn: 3000, 8000, 5000)
sudo lsof -i :3000
sudo lsof -i :8000
```

## 4. API Loglarını Kontrol
```bash
# Genel loglar
sudo journalctl -u your-api-service -f
sudo journalctl -u your-api-service --since "1 hour ago"

# Uygulama logları (genellikle)
tail -f /var/log/your-api/app.log
tail -f /home/ubuntu/api/logs/app.log
tail -f ~/api/logs/error.log
```

## 5. Sunucu İçinden API Testi
```bash
# GET endpoint testi
curl http://localhost:PORT/api/stats?userId=mustafa
# veya
curl http://127.0.0.1:PORT/api/stats?userId=mustafa

# POST endpoint testi
curl -X POST http://localhost:PORT/api/session \
  -H "Content-Type: application/json" \
  -d '{"userId":"mustafa","source":"test","minutes":1,"ts":1234567890}'
```

## 6. Firewall Kontrolü
```bash
# UFW (Ubuntu Firewall)
sudo ufw status
sudo ufw status verbose

# iptables
sudo iptables -L -n -v
```

## 7. DNS ve Domain Kontrolü
```bash
# Domain çözümleme
nslookup nmustafaozkaya.com.tr
dig nmustafaozkaya.com.tr

# SSL sertifikası kontrolü
curl -vI https://nmustafaozkaya.com.tr/api/stats?userId=mustafa
```

## 8. Disk ve Kaynak Kullanımı
```bash
# Disk kullanımı
df -h

# Memory kullanımı
free -h

# CPU kullanımı
top
# veya
htop
```

## 9. Servisi Yeniden Başlatma (Gerekirse)
```bash
# PM2 ile
pm2 restart all
pm2 restart your-api-name

# systemd ile
sudo systemctl restart your-api-service
sudo systemctl restart nginx

# Manuel process kill ve restart
# (Önce process ID'yi bulun)
ps aux | grep node
kill -9 PID
# Sonra servisi yeniden başlatın
```

## 10. Hızlı Test Scripti (Sunucuda)
```bash
# Sunucuda çalıştırılacak test scripti
cat > /tmp/test_api.sh << 'EOF'
#!/bin/bash
API_URL="http://localhost:YOUR_PORT/api"  # PORT'u değiştirin
USER_ID="mustafa"

echo "Testing GET /api/stats..."
curl -s "$API_URL/stats?userId=$USER_ID" | jq .

echo -e "\nTesting POST /api/session..."
TIMESTAMP=$(date +%s)000
curl -s -X POST "$API_URL/session" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":\"$USER_ID\",\"source\":\"test\",\"minutes\":1,\"ts\":$TIMESTAMP}"
EOF

chmod +x /tmp/test_api.sh
/tmp/test_api.sh
```

