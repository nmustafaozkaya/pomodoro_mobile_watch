import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel {
  static const String _languageKey = 'language';
  static const String _wallpaperKey = 'wallpaper';
  static const String _selectedMinutesKey = 'selected_minutes';
  static const String _breakMinutesKey = 'break_minutes';
  static const String _alarmSoundKey = 'alarm_sound';
  static const String _unlockedWallpapersKey = 'unlocked_wallpapers';
  static const String _unlockedAlarmsKey = 'unlocked_alarms';

  static const String turkish = 'tr';
  static const String english = 'en';

  static const String wallpaper1 = 'wallpaper1.jpg';
  static const String wallpaper2 = 'walpaper2.jpg';
  static const String wallpaper3 = 'walpaper3.jpg';
  static const String wallpaper4 = 'walpaper4.jpg';
  static const String wallpaper5 = 'walpaper5.jpeg';
  static const String wallpaper6 = 'walpaper6.jpeg';
  static const String wallpaper7 = 'walpaper7.jpeg';
  static const String wallpaper8 = 'walpaper8.jpeg';

  // Alarm sesleri (kullanıcının eklediği dosyalar)
  static const String alarm1 = 'alarm1.mp3';
  static const String alarm2 = 'alarm2.mp3';
  static const String alarm3 = 'alarm3.mp3';
  static const String alarm4 = 'alarm4.mp3';
  static const String alarm5 = 'alarm5.mp3';
  static const String alarmNone = 'none'; // Sessiz

  String _currentLanguage = english; // Varsayılan dil İngilizce
  String _currentWallpaper = wallpaper1;
  int _selectedMinutes = 25; // Varsayılan 25 dakika
  int _breakMinutes = 5; // Varsayılan 5 dakika ara
  String _currentAlarmSound = alarm1; // Varsayılan ses

  List<String> _unlockedWallpapers = [wallpaper1, wallpaper2];
  List<String> _unlockedAlarms = [alarm1, alarmNone];

  String get currentLanguage => _currentLanguage;
  String get currentWallpaper => _currentWallpaper;
  int get selectedMinutes => _selectedMinutes;
  int get breakMinutes => _breakMinutes;
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
    wallpaper5,
    wallpaper6,
    wallpaper7,
    wallpaper8,
  ];

  List<Map<String, String>> get availableAlarmSounds => [
    {'id': alarm1, 'name': getText('alarm_1')},
    {'id': alarm3, 'name': getText('alarm_3')},
    {'id': alarm2, 'name': getText('alarm_2')},
    {'id': alarm4, 'name': getText('alarm_4')},
    {'id': alarm5, 'name': getText('alarm_5')},
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
    _breakMinutes = prefs.getInt(_breakMinutesKey) ?? 5;
    _currentAlarmSound = prefs.getString(_alarmSoundKey) ?? alarm1;

    _unlockedWallpapers = prefs.getStringList(_unlockedWallpapersKey) ?? [wallpaper1, wallpaper2];
    _unlockedAlarms = prefs.getStringList(_unlockedAlarmsKey) ?? [alarm1, alarmNone];

    // Güvenlik amaçlı varsayılanların listede olmasını garanti et
    if (!_unlockedWallpapers.contains(wallpaper1)) _unlockedWallpapers.add(wallpaper1);
    if (!_unlockedWallpapers.contains(wallpaper2)) _unlockedWallpapers.add(wallpaper2);
    if (!_unlockedAlarms.contains(alarm1)) _unlockedAlarms.add(alarm1);
    if (!_unlockedAlarms.contains(alarmNone)) _unlockedAlarms.add(alarmNone);
  }

  bool isWallpaperUnlocked(String filename) {
    return _unlockedWallpapers.contains(filename);
  }

  Future<void> unlockWallpaper(String filename) async {
    if (!_unlockedWallpapers.contains(filename)) {
      _unlockedWallpapers.add(filename);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_unlockedWallpapersKey, _unlockedWallpapers);
    }
  }

  bool isAlarmUnlocked(String soundId) {
    return _unlockedAlarms.contains(soundId);
  }

  Future<void> unlockAlarm(String soundId) async {
    if (!_unlockedAlarms.contains(soundId)) {
      _unlockedAlarms.add(soundId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_unlockedAlarmsKey, _unlockedAlarms);
    }
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

  // Save break minutes
  Future<void> setBreakMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_breakMinutesKey, minutes);
    _breakMinutes = minutes;
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
    'finish': 'Bitir',
    'reset': 'Sıfırla',
    'paused': 'Duraklatıldı',
    'select_time': 'Süre Seç',
    'wallpaper_1': 'Duvar Kağıdı 1',
    'wallpaper_2': 'Duvar Kağıdı 2',
    'wallpaper_3': 'Duvar Kağıdı 3',
    'wallpaper_4': 'Duvar Kağıdı 4',
    'wallpaper_5': 'Duvar Kağıdı 5',
    'wallpaper_6': 'Duvar Kağıdı 6',
    'wallpaper_7': 'Duvar Kağıdı 7',
    'wallpaper_8': 'Duvar Kağıdı 8',
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
    'alarm_2': '🎵 Alarm 3',
    'alarm_3': '🎶 Alarm 2',
    'alarm_4': '🎸 Alarm 4',
    'alarm_5': '🎺 Alarm 5',
    'alarm_none': '🔇 Sessiz (Sadece Titreşim)',
    'pomodoro': 'Pomodoro',
    'break': 'Ara',
    'break_time': 'Ara Süresi',
    'skip': 'Atla',
    'stats_phone': 'Telefon',
    'stats_watch': 'Saat',
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
    'finish': 'Finish',
    'reset': 'Reset',
    'paused': 'Paused',
    'select_time': 'Select Time',
    'wallpaper_1': 'Wallpaper 1',
    'wallpaper_2': 'Wallpaper 2',
    'wallpaper_3': 'Wallpaper 3',
    'wallpaper_4': 'Wallpaper 4',
    'wallpaper_5': 'Wallpaper 5',
    'wallpaper_6': 'Wallpaper 6',
    'wallpaper_7': 'Wallpaper 7',
    'wallpaper_8': 'Wallpaper 8',
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
    'alarm_2': '🎵 Alarm 3',
    'alarm_3': '🎶 Alarm 2',
    'alarm_4': '🎸 Alarm 4',
    'alarm_5': '🎺 Alarm 5',
    'alarm_none': '🔇 Silent (Vibration Only)',
    'pomodoro': 'Pomodoro',
    'break': 'Break',
    'break_time': 'Break Time',
    'skip': 'Skip',
    'stats_phone': 'Phone',
    'stats_watch': 'Watch',
  };
}
