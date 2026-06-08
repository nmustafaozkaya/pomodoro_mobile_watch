import 'package:shared_preferences/shared_preferences.dart';

class StatisticsModel {
  static const String _dailyKey = 'daily_stats';
  static const String _monthlyKey = 'monthly_stats';
  static const String _yearlyKey = 'yearly_stats';
  /// Saatten (Data Layer) gelen dakikalar — istatistik ekranında "Saat" kartı için.
  static const String _watchDailyKey = 'watch_daily_stats';
  static const String _watchMonthlyKey = 'watch_monthly_stats';
  static const String _watchYearlyKey = 'watch_yearly_stats';

  Map<String, int> _dailyStats = {};
  Map<String, int> _monthlyStats = {};
  Map<String, int> _yearlyStats = {};
  Map<String, int> _watchDailyStats = {};
  Map<String, int> _watchMonthlyStats = {};
  Map<String, int> _watchYearlyStats = {};

  // Load all statistics from SharedPreferences
  Future<void> loadStatistics() async {
    final prefs = await SharedPreferences.getInstance();

    // Load daily stats
    final dailyString = prefs.getString(_dailyKey) ?? '{}';
    _dailyStats = _parseStats(dailyString);

    // Load monthly stats
    final monthlyString = prefs.getString(_monthlyKey) ?? '{}';
    _monthlyStats = _parseStats(monthlyString);

    // Load yearly stats
    final yearlyString = prefs.getString(_yearlyKey) ?? '{}';
    _yearlyStats = _parseStats(yearlyString);

    _watchDailyStats = _parseStats(prefs.getString(_watchDailyKey) ?? '{}');
    _watchMonthlyStats = _parseStats(prefs.getString(_watchMonthlyKey) ?? '{}');
    _watchYearlyStats = _parseStats(prefs.getString(_watchYearlyKey) ?? '{}');
  }

  // Parse statistics from JSON-like string
  Map<String, int> _parseStats(String statsString) {
    if (statsString.isEmpty || statsString == '{}') return {};

    final Map<String, int> stats = {};
    final entries = statsString.split(',');

    for (final entry in entries) {
      if (entry.contains(':')) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = int.tryParse(parts[1].trim()) ?? 0;
          stats[key] = value;
        }
      }
    }

    return stats;
  }

  // Convert stats to string for storage
  String _statsToString(Map<String, int> stats) {
    if (stats.isEmpty) return '{}';
    return stats.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  // Save statistics to SharedPreferences
  Future<void> _saveStats(String key, Map<String, int> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, _statsToString(stats));
  }

  // Record a completed Pomodoro session
  Future<void> recordSession(int durationMinutes) async {
    await loadStatistics(); // Ensure we have latest data

    final now = DateTime.now();
    final dateKey = _formatDate(now);
    final monthKey = _formatMonth(now);
    final yearKey = _formatYear(now);

    // Update daily stats
    _dailyStats[dateKey] = (_dailyStats[dateKey] ?? 0) + durationMinutes;

    // Update monthly stats
    _monthlyStats[monthKey] = (_monthlyStats[monthKey] ?? 0) + durationMinutes;

    // Update yearly stats
    _yearlyStats[yearKey] = (_yearlyStats[yearKey] ?? 0) + durationMinutes;

    // Save to storage
    await _saveStats(_dailyKey, _dailyStats);
    await _saveStats(_monthlyKey, _monthlyStats);
    await _saveStats(_yearlyKey, _yearlyStats);
  }

  /// Saatten gelen oturum: toplam istatistiklere + ayrı saat haritasına yazar.
  Future<void> recordWatchSession(int durationMinutes) async {
    if (durationMinutes <= 0) return;
    await loadStatistics();

    final now = DateTime.now();
    final dateKey = _formatDate(now);
    final monthKey = _formatMonth(now);
    final yearKey = _formatYear(now);

    _dailyStats[dateKey] = (_dailyStats[dateKey] ?? 0) + durationMinutes;
    _monthlyStats[monthKey] = (_monthlyStats[monthKey] ?? 0) + durationMinutes;
    _yearlyStats[yearKey] = (_yearlyStats[yearKey] ?? 0) + durationMinutes;

    _watchDailyStats[dateKey] = (_watchDailyStats[dateKey] ?? 0) + durationMinutes;
    _watchMonthlyStats[monthKey] = (_watchMonthlyStats[monthKey] ?? 0) + durationMinutes;
    _watchYearlyStats[yearKey] = (_watchYearlyStats[yearKey] ?? 0) + durationMinutes;

    await _saveStats(_dailyKey, _dailyStats);
    await _saveStats(_monthlyKey, _monthlyStats);
    await _saveStats(_yearlyKey, _yearlyStats);
    await _saveStats(_watchDailyKey, _watchDailyStats);
    await _saveStats(_watchMonthlyKey, _watchMonthlyStats);
    await _saveStats(_watchYearlyKey, _watchYearlyStats);
  }

  int getWatchTodayMinutes() {
    final today = _formatDate(DateTime.now());
    return _watchDailyStats[today] ?? 0;
  }

  /// Telefonda tamamlanan dakikalar (toplam − saatten kayıtlı).
  int getPhoneTodayMinutes() {
    final combined = getTodayMinutes();
    final watch = getWatchTodayMinutes();
    final phone = combined - watch;
    return phone < 0 ? 0 : phone;
  }

  int getWatchThisMonthMinutes() {
    final thisMonth = _formatMonth(DateTime.now());
    return _watchMonthlyStats[thisMonth] ?? 0;
  }

  int getPhoneThisMonthMinutes() {
    final combined = getThisMonthMinutes();
    final watch = getWatchThisMonthMinutes();
    final phone = combined - watch;
    return phone < 0 ? 0 : phone;
  }

  // Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Format month as YYYY-MM
  String _formatMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  // Format year as YYYY
  String _formatYear(DateTime date) {
    return date.year.toString();
  }

  // Get today's minutes
  int getTodayMinutes() {
    final today = _formatDate(DateTime.now());
    return _dailyStats[today] ?? 0;
  }

  // Get this month's minutes
  int getThisMonthMinutes() {
    final thisMonth = _formatMonth(DateTime.now());
    return _monthlyStats[thisMonth] ?? 0;
  }

  // Get this year's minutes
  int getThisYearMinutes() {
    final thisYear = _formatYear(DateTime.now());
    return _yearlyStats[thisYear] ?? 0;
  }

  // Get total minutes across all time
  int getTotalMinutes() {
    return _dailyStats.values.fold(0, (sum, minutes) => sum + minutes);
  }

  // Get recent daily stats (last 7 days)
  List<MapEntry<String, int>> getRecentDays() {
    final now = DateTime.now();
    final List<MapEntry<String, int>> recentDays = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = _formatDate(date);
      final minutes = _dailyStats[dateKey] ?? 0;
      recentDays.add(MapEntry(dateKey, minutes));
    }

    return recentDays;
  }

  // Get monthly stats for current year
  List<MapEntry<String, int>> getMonthlyStats() {
    final now = DateTime.now();
    final List<MapEntry<String, int>> monthlyStats = [];

    for (int month = 1; month <= 12; month++) {
      final monthKey = '${now.year}-${month.toString().padLeft(2, '0')}';
      final minutes = _monthlyStats[monthKey] ?? 0;
      monthlyStats.add(MapEntry(monthKey, minutes));
    }

    return monthlyStats;
  }

  // Format minutes to human readable string
  String formatMinutes(int minutes, {String language = 'tr'}) {
    if (minutes < 60) {
      return language == 'tr' ? '${minutes}dk' : '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return language == 'tr' ? '${hours}sa' : '${hours}h';
      } else {
        return language == 'tr'
            ? '${hours}sa ${remainingMinutes}dk'
            : '${hours}h ${remainingMinutes}m';
      }
    }
  }

  // Format date for display
  String formatDateForDisplay(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}';
    }
    return dateKey;
  }

  // Format month for display (TR / EN month names)
  String formatMonthForDisplay(String monthKey, {String language = 'tr'}) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final month = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return monthKey;

    const trNames = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    const enNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final names = language == 'tr' ? trNames : enNames;
    return '${names[month]} ${parts[0]}';
  }

  // Format year for display
  String formatYearForDisplay(String yearKey) {
    return yearKey;
  }

  // Clear all statistics
  Future<void> clearAllStatistics() async {
    _dailyStats.clear();
    _monthlyStats.clear();
    _yearlyStats.clear();
    _watchDailyStats.clear();
    _watchMonthlyStats.clear();
    _watchYearlyStats.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dailyKey);
    await prefs.remove(_monthlyKey);
    await prefs.remove(_yearlyKey);
    await prefs.remove(_watchDailyKey);
    await prefs.remove(_watchMonthlyKey);
    await prefs.remove(_watchYearlyKey);
  }
}
