import 'package:flutter/material.dart';
import 'settings_model.dart';
import 'statistics_model.dart';

class StatisticsPage extends StatefulWidget {
  final SettingsModel settings;
  final StatisticsModel statistics;
  final Map<String, dynamic>? wearData;

  const StatisticsPage({
    super.key,
    required this.settings,
    required this.statistics,
    this.wearData,
  });

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _selectedTab = 0; // 0: Günlük, 1: Aylık, 2: Yıllık

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    await widget.statistics.loadStatistics();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            'assets/wallpaper/${widget.settings.currentWallpaper}',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            8.0,
            8.0,
            8.0,
            80.0,
          ), // More bottom padding for navbar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.analytics, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    widget.settings.getText('statistics'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Selector
              _buildTabSelector(),
              const SizedBox(height: 6),

              // Total at top
              _buildTotalCard(),
              const SizedBox(height: 6),

              // Statistics Content
              Expanded(child: _buildStatisticsContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _buildTabButton(0, widget.settings.getText('daily')),
          _buildTabButton(1, widget.settings.getText('monthly')),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDailyStats();
      case 1:
        return _buildMonthlyStats();
      default:
        return _buildDailyStats();
    }
  }

  Widget _buildDailyStats() {
    final todayMinutes = widget.statistics.getTodayMinutes();
    final recentDays = widget.statistics.getRecentDays();

    return Column(
      children: [
        // Today's stats
        _buildStatsCard(
          widget.settings.getText('today'),
          widget.statistics.formatMinutes(
            todayMinutes,
            language: widget.settings.currentLanguage,
          ),
          Icons.today,
        ),
        const SizedBox(height: 4),

        // Recent 7 days - Fixed height, no scroll
        Container(
          height: 340, // Even larger
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_view_week,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.settings.getText('last_7_days'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: recentDays
                        .map(
                          (day) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            child: _buildDayItem(day.key, day.value),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyStats() {
    final thisMonthMinutes = widget.statistics.getThisMonthMinutes();
    final monthlyStats = widget.statistics.getMonthlyStats();

    return Column(
      children: [
        // This month's stats
        _buildStatsCard(
          widget.settings.getText('this_month'),
          widget.statistics.formatMinutes(
            thisMonthMinutes,
            language: widget.settings.currentLanguage,
          ),
          Icons.calendar_month,
        ),
        const SizedBox(height: 4),

        // Monthly chart - Fixed height, no scroll
        Container(
          height: 470, // Even larger
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      widget.settings.getText('monthly_graph'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: monthlyStats
                        .map(
                          (month) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            child: _buildMonthItem(month.key, month.value),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayItem(String dateKey, int minutes) {
    final date = widget.statistics.formatDateForDisplay(dateKey);
    final today = DateTime.now();
    final itemDate = DateTime.parse(dateKey);
    final isToday =
        itemDate.year == today.year &&
        itemDate.month == today.month &&
        itemDate.day == today.day;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isToday
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isToday
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Text(
            isToday ? widget.settings.getText('today') : date,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              fontSize: 20,
            ),
          ),
          const Spacer(),
          Text(
            widget.statistics.formatMinutes(
              minutes,
              language: widget.settings.currentLanguage,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthItem(String monthKey, int minutes) {
    final month = widget.statistics.formatMonthForDisplay(monthKey);
    final thisMonth = DateTime.now();
    final itemMonth = DateTime.parse('$monthKey-01');
    final isThisMonth =
        itemMonth.year == thisMonth.year && itemMonth.month == thisMonth.month;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isThisMonth
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isThisMonth
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Text(
            isThisMonth ? widget.settings.getText('this_month') : month,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isThisMonth ? FontWeight.bold : FontWeight.normal,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          Text(
            widget.statistics.formatMinutes(
              minutes,
              language: widget.settings.currentLanguage,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    final totalMinutes = widget.statistics.getTotalMinutes();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.all_inclusive, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.settings.getText('total_work_time'),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.statistics.formatMinutes(
                      totalMinutes,
                      language: widget.settings.currentLanguage,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
