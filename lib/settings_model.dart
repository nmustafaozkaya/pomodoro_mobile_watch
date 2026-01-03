import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel {
  static const String _languageKey = 'language';
  static const String _wallpaperKey = 'wallpaper';
  static const String _selectedMinutesKey = 'selected_minutes';
  static const String _alarmSoundKey = 'alarm_sound';

  static const String turkish = 'tr';
  static const String english = 'en';

  static const String wallpaper1 = 'wallpaper1.jpg';
  static const String wallpaper2 = 'walpaper2.jpg';
  static const String wallpaper3 = 'walpaper3.jpg';
  static const String wallpaper4 = 'walpaper4.jpg';

  // Alarm sesleri (kullanıcının eklediği dosyalar)
  static const String alarm1 = 'alarm1.mp3';
  static const String alarm2 = 'alarm2.mp3';
  static const String alarmNone = 'none'; // Sessiz

  String _currentLanguage = english; // Varsayılan dil İngilizce
  String _currentWallpaper = wallpaper1;
  int _selectedMinutes = 25; // Varsayılan 25 dakika
  String _currentAlarmSound = alarm1; // Varsayılan ses

  String get currentLanguage => _currentLanguage;
  String get currentWallpaper => _currentWallpaper;
  int get selectedMinutes => _selectedMinutes;
  String get currentAlarmSound => _currentAlarmSound;

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

  // Mevcut alarm sesleri
  List<Map<String, String>> get availableAlarmSounds => [
    {'id': alarm1, 'name': getText('alarm_1')},
    {'id': alarm2, 'name': getText('alarm_2')},
    {'id': alarmNone, 'name': getText('alarm_none')},
  ];

  // Ses dosyası adını al (none hariç)
  String? getAlarmSoundPath() {
    if (_currentAlarmSound == alarmNone) return null;
    return 'sounds/$_currentAlarmSound';
  }

  // Load settings from SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage =
        prefs.getString(_languageKey) ?? english; // Varsayılan İngilizce
    _currentWallpaper = prefs.getString(_wallpaperKey) ?? wallpaper1;
    _selectedMinutes = prefs.getInt(_selectedMinutesKey) ?? 25;
    _currentAlarmSound = prefs.getString(_alarmSoundKey) ?? alarm1;
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

  // Save selected timer minutes
  Future<void> setSelectedMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedMinutesKey, minutes);
    _selectedMinutes = minutes;
  }

  // Save alarm sound setting
  Future<void> setAlarmSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alarmSoundKey, soundId);
    _currentAlarmSound = soundId;
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
    'wallpaper': 'Duvar Kağıtları',
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
    'alarm_sound': 'Alarm Sesi',
    'alarm_1': '🔔 Alarm 1',
    'alarm_2': '🎵 Alarm 2',
    'alarm_none': '🔇 Sessiz (Sadece Titreşim)',
  };

  // English texts
  static const Map<String, String> _englishTexts = {
    'settings': 'Settings',
    'language': 'Language',
    'wallpaper': 'Wallpapers',
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
    'alarm_sound': 'Alarm Sound',
    'alarm_1': '🔔 Alarm 1',
    'alarm_2': '🎵 Alarm 2',
    'alarm_none': '🔇 Silent (Vibration Only)',
  };
}
