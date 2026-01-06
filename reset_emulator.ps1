# Emülatör Sıfırlama Scripti
# Bu script emülatörü cold boot (tüm verileri temizleyerek) başlatır

$ANDROID_HOME = "C:\Users\Mustafa-Slayer\AppData\Local\Android\Sdk"
$EMULATOR_PATH = "$ANDROID_HOME\emulator\emulator.exe"
$AVDMANAGER_PATH = "$ANDROID_HOME\cmdline-tools\latest\bin\avdmanager.bat"

Write-Host "Emülatör sıfırlama başlatılıyor..." -ForegroundColor Cyan

# 1. Çalışan emülatör process'lerini durdur
Write-Host "`nÇalışan emülatörler kontrol ediliyor..." -ForegroundColor Yellow
$emulatorProcesses = Get-Process | Where-Object {$_.ProcessName -like "*emulator*" -or $_.ProcessName -like "*qemu*"}
if ($emulatorProcesses) {
    Write-Host "Çalışan emülatör process'leri bulundu, durduruluyor..." -ForegroundColor Yellow
    $emulatorProcesses | Stop-Process -Force
    Start-Sleep -Seconds 2
} else {
    Write-Host "Çalışan emülatör yok." -ForegroundColor Green
}

# 2. Mevcut emülatörleri listele
Write-Host "`nMevcut emülatörler:" -ForegroundColor Cyan
flutter emulators

Write-Host "`nEmülatörü cold boot (tüm verileri temizleyerek) başlatmak için:" -ForegroundColor Yellow
Write-Host "1. Android Studio'yu açın" -ForegroundColor White
Write-Host "2. Tools > Device Manager'a gidin" -ForegroundColor White
Write-Host "3. Emülatörün yanındaki dropdown menüden 'Cold Boot Now' seçin" -ForegroundColor White
Write-Host "`nVEYA" -ForegroundColor Yellow
Write-Host "Aşağıdaki komutu kullanın (emülatör adını değiştirin):" -ForegroundColor White
Write-Host "& `"$EMULATOR_PATH`" -avd Medium_Phone_API_36.1 -wipe-data" -ForegroundColor Green
Write-Host "`nVEYA" -ForegroundColor Yellow
Write-Host "Emülatörü normal şekilde başlatıp, ayarlardan 'Wipe Data' yapın" -ForegroundColor White

Write-Host "`nScript tamamlandı!" -ForegroundColor Green

