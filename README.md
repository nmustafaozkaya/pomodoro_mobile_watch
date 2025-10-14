# Pomodoro Timer - Phone & Smartwatch

Bu uygulama hem telefonda hem de akıllı saatte çalışır ve Bluetooth üzerinden veri senkronizasyonu yapar.

## Kurulum

### Telefon için:
1. `flutter run` komutu ile telefon uygulamasını çalıştırın
2. Uygulama otomatik olarak telefon modunda açılacak

### Akıllı Saat için:
1. Akıllı saati USB ile bilgisayara bağlayın
2. `flutter run -d <watch_device_id>` komutu ile saate yükleyin
3. Veya Android Studio'da "Wear OS" target'ını seçip çalıştırın

## Özellikler

### Telefon Uygulaması:
- Pomodoro timer
- İstatistikler (günlük/aylık)
- Dil ayarları (Türkçe/İngilizce)
- Duvar kağıdı değiştirme
- Akıllı saat verilerini görüntüleme

### Akıllı Saat Uygulaması:
- Kompakt timer arayüzü
- 15-60 dakika arası süre seçimi
- Toplam çalışma süresi takibi
- Bluetooth ile telefona veri gönderme

## Veri Senkronizasyonu

Uygulama her 5 saniyede bir akıllı saatten telefon uygulamasına çalışma verilerini senkronize eder. İstatistikler sayfasında yeşil saat ikonu ile bağlantı durumu gösterilir.

## Gereksinimler

- Flutter 3.9.2+
- Android 6.0+ (telefon)
- Wear OS 2.0+ (akıllı saat)
- Bluetooth bağlantısı