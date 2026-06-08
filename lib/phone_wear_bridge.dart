import 'dart:io';

import 'package:flutter/services.dart';

/// Telefon (Android) üzerinden Wear Data Layer ile saate veri gönderir; API gerekmez.
class PhoneWearBridge {
  static const _channel = MethodChannel('com.pomodoro.phone/wear');

  static Future<void> syncPhoneWorkSession(int minutes) async {
    if (!Platform.isAndroid || minutes <= 0) return;
    try {
      await _channel.invokeMethod<void>('syncPhoneWorkSession', {
        'minutes': minutes,
      });
    } catch (_) {}
  }

  static Future<void> pushTimerSettings({
    required int selectedMinutes,
    required int breakMinutes,
    required String language,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('pushTimerSettings', {
        'selectedMinutes': selectedMinutes,
        'breakMinutes': breakMinutes,
        'language': language,
      });
    } catch (_) {}
  }
}
