import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'phone_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AdMob SDK'sını başlat
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    if (kDebugMode) {
      print('AdMob initialization error: $e');
    }
  }

  // Global error handler - crash önleme
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Platform hatalarını yakala
  PlatformDispatcher.instance.onError = (error, stack) {
    // Hataları logla ama uygulamayı çökertme
    return true;
  };

  // Alarm sesinin iOS/Mac ve Android simülatörlerde sessiz modda dahi çalabilmesi için yapılandırma
  try {
    AudioPlayer.global.setAudioContext(
      AudioContextConfig(
        respectSilence:
            false, // Sessiz anahtarı (Silent Switch) açık olsa bile sesi çalar
        stayAwake: true,
      ).build(),
    );
  } catch (_) {}

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhoneApp();
  }
}
