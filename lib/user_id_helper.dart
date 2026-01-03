import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı ID'sini oluşturur veya mevcut olanı döndürür
/// Uygulama silinmediği sürece aynı userId kullanılır
Future<String> getOrCreateUserId() async {
  final prefs = await SharedPreferences.getInstance();
  
  String? userId = prefs.getString('user_id');
  
  if (userId == null || userId.isEmpty) {
    // Yeni UUID oluştur
    userId = const Uuid().v4();
    await prefs.setString('user_id', userId);
  }
  
  return userId;
}

