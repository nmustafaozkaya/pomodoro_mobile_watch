# PM2 Servis Silme Komutları

## kpss-backend Servisini Silme

```bash
# İsim ile silme (önerilen)
pm2 delete kpss-backend

# Veya ID ile silme
pm2 delete 1

# Veya namespace ile birlikte
pm2 delete kpss-backend --namespace default
```

## Diğer PM2 Silme Komutları

```bash
# Tüm durmuş servisleri sil
pm2 delete stopped

# Tüm servisleri sil (dikkatli kullanın!)
pm2 delete all

# Belirli bir namespace'teki tüm servisleri sil
pm2 delete all --namespace default
```

## Silme Sonrası Kontrol

```bash
# Liste kontrolü
pm2 list

# PM2 durumunu kaydet (eğer otomatik başlatma kullanıyorsanız)
pm2 save
```

## Notlar

- Silme işlemi geri alınamaz
- Servis dosyaları silinmez, sadece PM2 listesinden kaldırılır
- Eğer servisi tekrar eklemek isterseniz, `pm2 start` komutuyla yeniden ekleyebilirsiniz

