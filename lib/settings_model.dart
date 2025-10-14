import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel {
  static const String _languageKey = 'language';
  static const String _wallpaperKey = 'wallpaper';

  static const String turkish = 'tr';
  static const String english = 'en';

  static const String wallpaper1 = 'wallpaper1.jpg';
  static const String wallpaper2 = 'walpaper2.jpg';
  static const String wallpaper3 = 'walpaper3.jpg';
  static const String wallpaper4 = 'walpaper4.jpg';

  String _currentLanguage = turkish;
  String _currentWallpaper = wallpaper1;

  String get currentLanguage => _currentLanguage;
  String get currentWallpaper => _currentWallpaper;

  // Language getters
  String get languageName {
    return _currentLanguage == turkish ? 'Türkçe' : 'English';
  }

  String get otherLanguageName {
    return _currentLanguage == turkish ? 'English' : 'Türkçe';
  }

  // Wallpaper getters

  List<String> get availableWallpapers => [
    wallpaper1,
    wallpaper2,
    wallpaper3,
    wallpaper4,
  ];

  // Load settings from SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? turkish;
    _currentWallpaper = prefs.getString(_wallpaperKey) ?? wallpaper1;
  }

  // Save language setting
  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    _currentLanguage = language;
  }

  // Save wallpaper setting
  Future<void> setWallpaper(String wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wallpaperKey, wallpaper);
    _currentWallpaper = wallpaper;
  }

  // Toggle language
  Future<void> toggleLanguage() async {
    final newLanguage = _currentLanguage == turkish ? english : turkish;
    await setLanguage(newLanguage);
  }

  // Get localized text
  String getText(String key) {
    if (_currentLanguage == turkish) {
      return _turkishTexts[key] ?? key;
    } else {
      return _englishTexts[key] ?? key;
    }
  }

  // Turkish texts
  static const Map<String, String> _turkishTexts = {
    'settings': 'Ayarlar',
    'language': 'Dil',
    'wallpaper': 'Duvar Kağıdı',
    'timer': 'Zamanlayıcı',
    'statistics': 'İstatistikler',
    'start': 'Başlat',
    'pause': 'Duraklat',
    'continue': 'Devam Et',
    'reset': 'Sıfırla',
    'paused': 'Duraklatıldı',
    'select_time': 'Süre Seç',
    'wallpaper_1': 'Duvar Kağıdı 1',
    'wallpaper_2': 'Duvar Kağıdı 2',
    'wallpaper_3': 'Duvar Kağıdı 3',
    'wallpaper_4': 'Duvar Kağıdı 4',
    'today': 'Bugün',
    'this_month': 'Bu Ay',
    'this_year': 'Bu Yıl',
    'last_7_days': 'Son 7 Gün',
    'monthly_graph': 'Aylık Grafik',
    'total_work_time': 'Toplam Çalışma Süresi',
    'daily': 'Günlük',
    'monthly': 'Aylık',
  };

  // English texts
  static const Map<String, String> _englishTexts = {
    'settings': 'Settings',
    'language': 'Language',
    'wallpaper': 'Wallpaper',
    'timer': 'Timer',
    'statistics': 'Statistics',
    'start': 'Start',
    'pause': 'Pause',
    'continue': 'Continue',
    'reset': 'Reset',
    'paused': 'Paused',
    'select_time': 'Select Time',
    'wallpaper_1': 'Wallpaper 1',
    'wallpaper_2': 'Wallpaper 2',
    'wallpaper_3': 'Wallpaper 3',
    'wallpaper_4': 'Wallpaper 4',
    'today': 'Today',
    'this_month': 'This Month',
    'this_year': 'This Year',
    'last_7_days': 'Last 7 Days',
    'monthly_graph': 'Monthly Graph',
    'total_work_time': 'Total Work Time',
    'daily': 'Daily',
    'monthly': 'Monthly',
  };
}
