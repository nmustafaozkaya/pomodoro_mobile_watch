import 'package:flutter/material.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isWearOS(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(home: SizedBox.shrink());
        }
        final isWear = snap.data == true;
        return MaterialApp(
          title: 'Pomodoro',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          home: isWear ? const WearHome() : const PhoneHome(),
        );
      },
    );
  }
}

Future<bool> _isWearOS() async {
  if (!Platform.isAndroid) return false;
  final info = await DeviceInfoPlugin().androidInfo;
  final features = info.systemFeatures ?? <String>[];
  return features.contains('android.hardware.type.watch');
}

class WearHome extends StatelessWidget {
  const WearHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Pomodoro', style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text('Wear OS', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class PhoneHome extends StatelessWidget {
  const PhoneHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Phone Home')));
  }
}
