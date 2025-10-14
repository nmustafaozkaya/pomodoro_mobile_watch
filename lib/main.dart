import 'package:flutter/material.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'phone_app.dart';
import 'wear_app.dart';

void main() {
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
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final isWear = snap.data == true;
        return isWear ? WearApp() : PhoneApp();
      },
    );
  }
}

Future<bool> _isWearOS() async {
  if (!Platform.isAndroid) return false;
  final info = await DeviceInfoPlugin().androidInfo;
  final features = info.systemFeatures;
  return features.contains('android.hardware.type.watch');
}
