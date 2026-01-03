# Google Play Console - Wear OS Yükleme Adımları

## ⚠️ ÖNEMLİ: Wear OS Sekmesi Görünmüyorsa

Wear OS sekmesi otomatik olarak görünmeyebilir. Aşağıdaki adımları takip edin:

---

## 1️⃣ ADIM: Device Compatibility Ayarları

1. Google Play Console'a giriş yapın: https://play.google.com/console
2. Uygulamanızı seçin
3. Sol menüden **"App content"** → **"Device compatibility"** bölümüne gidin
4. Sayfayı aşağı kaydırın
5. **"Device types"** veya **"Supported devices"** bölümünü bulun
6. **"Wear OS"** seçeneğini işaretleyin (checkbox'ı aktif edin)
7. **"Save"** veya **"Save changes"** butonuna tıklayın
8. Sayfanın kaydedildiğini onaylayın

---

## 2️⃣ ADIM: Release Bölümüne Git

1. Sol menüden **"Release"** → **"Production"** (veya hangi track kullanıyorsanız) bölümüne gidin
2. Sayfayı yenileyin (F5 veya sayfayı yeniden yükleyin)

---

## 3️⃣ ADIM: Wear OS Sekmesini Bul

Production sayfasında şunlardan birini görmelisiniz:

### Seçenek A: Üstte Sekmeler Varsa
- Sayfanın **üst kısmında** yan yana sekmeler göreceksiniz:
  - **"App bundles"** veya **"Phone/Tablet"**
  - **"Wear OS"** ← Bu sekmeye tıklayın

### Seçenek B: Dropdown Menü Varsa
- **"Create new release"** butonunun yanında bir **dropdown menü** (▼) olabilir
- Dropdown'a tıklayın
- **"Wear OS app bundle"** seçeneğini seçin

### Seçenek C: Ayrı Bölüm Varsa
- Sayfada **"Wear OS"** başlıklı ayrı bir bölüm olabilir
- O bölümün altında **"Create new release"** butonunu bulun

---

## 4️⃣ ADIM: Hala Görünmüyorsa

### Çözüm 1: İlk Yükleme Yapın
1. Önce telefon için bir release yükleyin (Production → App bundles → Create new release)
2. Telefon release'ini kaydedin (publish etmek zorunda değilsiniz, sadece kaydedin)
3. Sayfayı yenileyin
4. Artık Wear OS sekmesi görünmeli

### Çözüm 2: Uygulama Bilgilerini Kontrol Edin
1. **"Policy"** → **"App content"** → **"Target audience and content"** bölümüne gidin
2. Uygulamanın **"Everyone"** veya uygun yaş grubunda olduğundan emin olun
3. Kaydedin ve geri dönün

### Çözüm 3: AndroidManifest Kontrolü (Teknik)
Eğer hala görünmüyorsa, AndroidManifest.xml'de Wear OS desteği olmayabilir. Ancak bizim durumumuzda kod runtime'da tespit ediyor, bu yüzden normalde sorun olmamalı.

---

## 5️⃣ ADIM: Wear OS Release Oluşturma

Wear OS sekmesini bulduktan sonra:

1. **"Create new release"** butonuna tıklayın
2. **"Upload"** butonuna tıklayın
3. Aynı AAB dosyasını seçin: `build\app\outputs\bundle\release\app-release.aab`
4. Yükleme tamamlanana kadar bekleyin

### Version Bilgileri:
- **Version code:** Telefon versiyonuyla **AYNI** olmalı (ör. 2)
- **Version name:** Telefon versiyonuyla **AYNI** olmalı (ör. 1.0.1)
- ⚠️ **ÖNEMLİ:** Version code ve version name telefonla aynı olmalı!

### Release Notes:
Türkçe ve İngilizce release notes ekleyin (RELEASE_NOTES.md dosyasından kopyalayın)

5. **"Save"** butonuna tıklayın
6. **"Review release"** ile kontrol edin
7. Hata yoksa **"Start rollout to Production"** ile yayınlayın

---

## 📸 Görsel İpuçları (Tahmini Menü Yerleşimi)

```
Google Play Console
│
├── App content
│   └── Device compatibility  ← BURADA Wear OS'i aktif edin
│
└── Release
    └── Production
        │
        ├── [App bundles]  ← Telefon için
        │   └── Create new release
        │
        └── [Wear OS]  ← SAAT İÇİN (burayı bulun)
            └── Create new release
```

---

## ✅ Kontrol Listesi

- [ ] Device compatibility'de Wear OS aktif
- [ ] Release → Production sayfasında Wear OS sekmesi görünüyor
- [ ] Wear OS sekmesine tıklandı
- [ ] Create new release butonuna tıklandı
- [ ] AAB dosyası yüklendi
- [ ] Version code telefonla aynı
- [ ] Version name telefonla aynı
- [ ] Release notes eklendi
- [ ] Save yapıldı
- [ ] Review release kontrol edildi
- [ ] Yayınlandı

---

## 🆘 Hala Bulamıyorsanız

1. **Google Play Console'un en son sürümünü kullandığınızdan emin olun**
2. **Farklı bir tarayıcı deneyin** (Chrome, Firefox, Edge)
3. **Sayfayı hard refresh yapın:** Ctrl + F5 (Windows) veya Cmd + Shift + R (Mac)
4. **Google Play Console'un yeni arayüzünde olup olmadığınızı kontrol edin**
5. **Uygulamanızın "Draft" durumunda olmadığından emin olun** - Eğer ilk yükleme ise, önce telefon release'ini kaydedin

---

## 📝 Notlar

- Wear OS sekmesi bazen sadece ilk release'ten sonra görünür
- Eğer uygulama henüz hiç yayınlanmadıysa, önce telefon release'ini kaydedin
- Aynı AAB dosyasını hem telefon hem Wear OS kanalına yükleyebilirsiniz
- Version code ve version name mutlaka aynı olmalı

---

## 🔗 Resmi Dokümantasyon

- [Google Play Console Wear OS Dökümanları](https://support.google.com/googleplay/android-developer/answer/9888179)
- [Wear OS App Bundles](https://developer.android.com/training/wearables/apps/packaging)

