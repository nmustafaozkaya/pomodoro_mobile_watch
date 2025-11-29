# Pomodoro API Yönetim Komutları

## Mevcut Durum
PM2 listesinde `pomodoro-api` servisi **stopped** durumunda. API çalışmıyor.

## API'yi Başlatma

```bash
# Pomodoro API'yi başlat
pm2 start pomodoro-api

# Veya ID ile başlat
pm2 start 0

# Başlat ve otomatik başlatmayı etkinleştir
pm2 start pomodoro-api --name pomodoro-api
pm2 save
pm2 startup
```

## API Durumunu Kontrol

```bash
# PM2 listesi
pm2 list

# Pomodoro API logları
pm2 logs pomodoro-api

# Son 50 satır log
pm2 logs pomodoro-api --lines 50

# Canlı log takibi
pm2 logs pomodoro-api --lines 0

# Detaylı bilgi
pm2 show pomodoro-api
pm2 info pomodoro-api
```

## API Testi (Sunucu İçinden)

```bash
# API'nin hangi portta çalıştığını öğrenmek için
pm2 show pomodoro-api | grep script

# Veya loglardan port bilgisini görebilirsiniz
pm2 logs pomodoro-api --lines 20

# Genellikle port 3000, 8000, 5000 gibi olabilir
# Test için:
curl http://localhost:3000/api/stats?userId=mustafa
# veya
curl http://localhost:8000/api/stats?userId=mustafa
# veya
curl http://localhost:5000/api/stats?userId=mustafa
```

## API Yönetimi

```bash
# Yeniden başlat
pm2 restart pomodoro-api

# Durdur
pm2 stop pomodoro-api

# Sil (PM2 listesinden kaldır)
pm2 delete pomodoro-api

# Tüm servisleri yeniden başlat
pm2 restart all
```

## Otomatik Başlatma Ayarları

```bash
# Sistem açılışında otomatik başlatma için
pm2 save
pm2 startup

# (Çıkan komutu root olarak çalıştırın)
```

## Hata Ayıklama

```bash
# Hata loglarını kontrol
pm2 logs pomodoro-api --err

# Son hataları göster
pm2 logs pomodoro-api --err --lines 100

# Process durumunu kontrol
ps aux | grep pomodoro
ps aux | grep node
```

## Port Kontrolü

```bash
# Hangi portlar dinleniyor?
sudo netstat -tulpn | grep LISTEN
# veya
sudo ss -tulpn | grep LISTEN

# Node.js process'lerinin dinlediği portlar
sudo lsof -i -P -n | grep node
```

## Nginx/Apache Reverse Proxy Kontrolü

```bash
# Nginx durumu
sudo systemctl status nginx

# Nginx config kontrolü
sudo nginx -t

# Nginx logları
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Nginx config dosyasını kontrol et
sudo cat /etc/nginx/sites-available/default
# veya
sudo cat /etc/nginx/sites-enabled/default
```

