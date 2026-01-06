# Hem telefon hem de saat emülatörlerini başlat ve uygulamaları çalıştır

Write-Host "Emülatörleri kontrol ediliyor..." -ForegroundColor Cyan

# Mevcut emülatörleri listele
flutter emulators

Write-Host "`nBağlı cihazlar:" -ForegroundColor Cyan
flutter devices

Write-Host "`n=== TEST KOMUTLARI ===" -ForegroundColor Yellow
Write-Host "`n1. Saat uygulamasını çalıştırmak için:" -ForegroundColor Green
Write-Host "   flutter run --flavor wear -d emulator-5554" -ForegroundColor White

Write-Host "`n2. Telefon uygulamasını çalıştırmak için:" -ForegroundColor Green
Write-Host "   flutter run --flavor phone -d emulator-5556" -ForegroundColor White

Write-Host "`n3. Her ikisini de çalıştırmak için (2 farklı terminal):" -ForegroundColor Green
Write-Host "   Terminal 1: flutter run --flavor wear -d emulator-5554" -ForegroundColor White
Write-Host "   Terminal 2: flutter run --flavor phone -d emulator-5556" -ForegroundColor White

Write-Host "`n=== TEST ADIMLARI ===" -ForegroundColor Yellow
Write-Host "1. Saat uygulamasında bir pomodoro tamamla" -ForegroundColor White
Write-Host "2. Telefon uygulamasında İstatistikler sekmesine git" -ForegroundColor White
Write-Host "3. Birkaç saniye bekle (senkronizasyon için)" -ForegroundColor White
Write-Host "4. 'Saat' kartında verilerin göründüğünü kontrol et" -ForegroundColor White

