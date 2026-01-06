import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'phone_app.dart';
import 'wear_app.dart';

void main() {
  // Global error handler - crash önleme
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Platform hatalarını yakala
  PlatformDispatcher.instance.onError = (error, stack) {
    // Hataları logla ama uygulamayı çökertme
    return true;
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isWearOS(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }
        // Hata durumunda varsayılan olarak PhoneApp aç (güvenli varsayım)
        // Sadece kesin olarak Wear OS ise WearApp aç
        final isWear = snap.hasData && snap.data == true;
        if (isWear) {
          return const WearApp();
        } else {
          return const PhoneApp();
        }
      },
    );
  }
}

Future<bool> _isWearOS() async {
  try {
    if (!Platform.isAndroid) return false;
    final info = await DeviceInfoPlugin().androidInfo;

    // SADECE systemFeatures kontrolü - en güvenilir yöntem
    // Model/brand/device kontrolleri yanlış pozitif verebilir
    final systemFeatures = info.systemFeatures;
    final isWatch = systemFeatures.contains('android.hardware.type.watch');

    // Debug için log (production'da kaldırılabilir)
    if (kDebugMode) {
      print(
        'Device Info: model=${info.model}, brand=${info.brand}, device=${info.device}',
      );
      print('System Features: $systemFeatures');
      print('Is Wear OS: $isWatch');
    }

    return isWatch;
  } catch (e) {
    // Hata durumunda false döndür - telefon varsayımı (güvenli)
    if (kDebugMode) {
      print('Wear OS detection error: $e');
    }
    return false;
  }
}
