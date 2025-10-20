import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'statistics_page.dart';
import 'settings_page.dart';
import 'settings_model.dart';
import 'statistics_model.dart';
import 'dart:math' as math;
import 'api_client.dart';

class PhoneApp extends StatelessWidget {
  const PhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomodoro - Phone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(),
      ),
      home: const PhoneHome(),
    );
  }
}

class PhoneHome extends StatefulWidget {
  const PhoneHome({super.key});

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> {
  int _selectedIndex = 0;
  late SettingsModel _settings;
  late StatisticsModel _statistics;
  String _currentWallpaper = 'wallpaper1.jpg';
  static const String _apiBaseUrl = 'https://nmustafaozkaya.com.tr/api';
  static const String _userId = 'mustafa';
  late final ApiClient _apiClient = ApiClient(
    baseUrl: _apiBaseUrl,
    userId: _userId,
  );
  int _cloudTotalMinutes = 0;

  // Bluetooth/Wear OS communication
  static const platform = MethodChannel('com.pomodoro.phone/wear');
  Map<String, dynamic>? _wearData;

  @override
  void initState() {
    super.initState();
    _settings = SettingsModel();
    _statistics = StatisticsModel();
    _loadSettings();
    _startWearDataSync();
  }

  Future<void> _loadSettings() async {
    await _settings.loadSettings();
    await _statistics.loadStatistics();
    setState(() {
      _currentWallpaper = _settings.currentWallpaper;
    });
  }

  void _onWallpaperChanged(String wallpaper) {
    setState(() {
      _currentWallpaper = wallpaper;
    });
    // Refresh all pages with new wallpaper
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _TimerPage(
          settings: _settings,
          wallpaper: _currentWallpaper,
          statistics: _statistics,
          apiClient: _apiClient,
        );
      case 1:
        return StatisticsPage(
          key: ValueKey(_currentWallpaper),
          settings: _settings,
          statistics: _statistics,
          wallpaper: _currentWallpaper,
          wearData: {...?_wearData, 'cloudTotalMinutes': _cloudTotalMinutes},
        );
      case 2:
        return SettingsPage(
          onWallpaperChanged: _onWallpaperChanged,
          onLanguageChanged: _onLanguageChanged,
        );
      default:
        return _TimerPage(
          settings: _settings,
          wallpaper: _currentWallpaper,
          statistics: _statistics,
          apiClient: _apiClient,
        );
    }
  }

  void _onLanguageChanged(String language) async {
    // Reload settings to get updated language
    await _settings.loadSettings();
    setState(() {
      // This will trigger a rebuild with the new language
    });
  }

  void _startWearDataSync() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      // _syncWearData(); // Disabled for emulator - only use cloud data
      _syncCloudStats();
    });
  }

  Future<void> _syncWearData() async {
    try {
      final String result = await platform.invokeMethod('getWearData');
      if (result.isNotEmpty) {
        final data = json.decode(result);
        setState(() {
          _wearData = data;
        });

        // Sync work data to statistics
        if (data['totalWorkMinutes'] != null) {
          await _statistics.recordSession(data['totalWorkMinutes']);
        }
      }
    } on PlatformException catch (e) {
      // Failed to sync wear data - continue without sync
      print('Wear data sync failed: ${e.message}');
    }
  }

  Future<void> _syncCloudStats() async {
    try {
      final stats = await _apiClient.fetchStats();
      setState(() {
        _cloudTotalMinutes = stats['totalMinutes'] ?? 0;
        // Update _wearData with cloud data for statistics
        _wearData = {
          'totalWorkMinutes': stats['totalMinutes'] ?? 0,
          'recent': stats['recent'] ?? [],
        };
      });
    } catch (_) {
      // ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan resmi tüm ekranı kaplasın
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/wallpaper/$_currentWallpaper'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Sayfa içeriği
          _buildCurrentPage(),
          // Navbar en üstte
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (index) async {
                if (index == 1) {
                  // Refresh stats when navigating to Statistics tab
                  await _statistics.loadStatistics();
                  await _syncCloudStats();
                }
                setState(() => _selectedIndex = index);
              },
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.timer),
                  label: _settings.getText('timer'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics),
                  label: _settings.getText('statistics'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: _settings.getText('settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerPage extends StatefulWidget {
  final SettingsModel settings;
  final String wallpaper;
  final StatisticsModel statistics;
  final ApiClient apiClient;

  const _TimerPage({
    required this.settings,
    required this.wallpaper,
    required this.statistics,
    required this.apiClient,
  });

  @override
  State<_TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<_TimerPage> {
  Timer? _timer;
  int _secondsRemaining = 25 * 60; // 25 dakika
  int _selectedMinutes = 25; // Seçilen dakika
  bool _isRunning = false;
  bool _isPaused = false;
  bool _showTimeSelector = false;
  late ScrollController _scrollController;
  Timer? _autoSelectTimer;
  int _sessionStartMinutes = 0; // Timer başladığında kaydedilen dakika

  @override
  void initState() {
    super.initState();
    // Scroll controller'ı daha yüksek initial offset ile başlat
    _scrollController = ScrollController(
      initialScrollOffset: 0.0, // En üstten başla
    );
    // Timer seçiciyi başlangıçta kapalı
    _showTimeSelector = false;
    // Başlangıç pozisyonunu seçili dakikaya ayarla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        int index = _selectedMinutes - 1; // 0-based index
        double itemHeight = 45.0;
        // Basit hesaplama - index * itemHeight
        double targetOffset = index * itemHeight;
        _scrollController.jumpTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );

        // 800ms sonra otomatik seçim
        _autoSelectTimer?.cancel();
        _autoSelectTimer = Timer(const Duration(milliseconds: 800), () {
          if (_showTimeSelector && mounted) {
            _selectCurrentCenterTime();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoSelectTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isPaused) {
      _isPaused = false;
      _isRunning = true;
    } else {
      _isRunning = true;
      _sessionStartMinutes = _selectedMinutes; // Timer başladığında kaydet
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _isPaused = false;

          // Timer tamamlandığında istatistikleri kaydet
          _recordCompletedSession();

          _secondsRemaining =
              _selectedMinutes * 60; // Reset to selected minutes
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _resetTimer() {
    _timer?.cancel();

    // Eğer timer çalışıyorsa ve sıfırlanıyorsa, mevcut çalışılan süreyi kaydet
    if (_sessionStartMinutes > 0) {
      final workedMinutes = _sessionStartMinutes - (_secondsRemaining ~/ 60);
      if (workedMinutes > 0) {
        _recordPartialSession(workedMinutes);
      }
    }

    setState(() {
      _isRunning = false;
      _isPaused = false;
      _secondsRemaining = _selectedMinutes * 60;
      _sessionStartMinutes = 0;
    });
  }

  // Timer tamamlandığında çalışan session kaydet
  Future<void> _recordCompletedSession() async {
    if (_sessionStartMinutes > 0) {
      await widget.statistics.recordSession(_sessionStartMinutes);
      // Cloud'a da yaz (fire-and-forget)
      // ignore: discarded_futures
      widget.apiClient.postSession(
        source: 'phone',
        minutes: _sessionStartMinutes,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      _sessionStartMinutes = 0;
    }
  }

  // Timer sıfırlandığında kısmi session kaydet
  Future<void> _recordPartialSession(int workedMinutes) async {
    await widget.statistics.recordSession(workedMinutes);
    // Cloud'a da yaz (fire-and-forget)
    // ignore: discarded_futures
    widget.apiClient.postSession(
      source: 'phone',
      minutes: workedMinutes,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _toggleTimeSelector() {
    if (!_isRunning) {
      // Timer seçiciyi direkt aç
      setState(() {
        _showTimeSelector = true;
      });

      // Timer seçici açıldığında seçili dakikaya scroll et
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          int index = _selectedMinutes - 1; // 1, 2, 3... için index hesapla
          double itemHeight = 45.0;
          // Seçili sayıyı ortaya getir
          double targetOffset = index * itemHeight;
          _scrollController.jumpTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );

          // 800ms sonra otomatik seçim
          _autoSelectTimer?.cancel();
          _autoSelectTimer = Timer(const Duration(milliseconds: 800), () {
            if (_showTimeSelector && mounted) {
              _selectCurrentCenterTime();
            }
          });
        }
      });
    }
  }

  void _selectCurrentCenterTime() {
    // Şu an ortada olan dakikayı seç ve timer seçiciyi kapat
    setState(() {
      _showTimeSelector = false;
    });
    _autoSelectTimer?.cancel();

    // Scroll pozisyonunu koru
    if (_scrollController.hasClients) {
      double currentOffset = _scrollController.offset;
      _scrollController.jumpTo(currentOffset);
    }
  }

  Widget _buildScrollableTimePicker() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          _onScrollEnd(notification.metrics);
        } else if (notification is ScrollUpdateNotification) {
          // Scroll sırasında da seçim yap
          _onScrollUpdate(notification.metrics);
        }
        return true;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: 200, // 1'den 200'e kadar
        padding: const EdgeInsets.only(top: 80.0), // Üst padding azaltıldı
        itemBuilder: (context, index) {
          int minutes = index + 1; // 1, 2, 3, ..., 200

          // Ortadaki item'ı belirle (scroll pozisyonuna göre)
          double itemHeight = 45.0;

          // Scroll pozisyonuna göre ortadaki index'i hesapla
          double scrollOffset = _scrollController.hasClients
              ? _scrollController.offset
              : 0;
          int centerIndex = (scrollOffset / itemHeight).round();
          bool isCenter = index == centerIndex;

          return SizedBox(
            height: 45,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isCenter ? Colors.deepPurple : Colors.grey[400],
                  fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
                  fontSize: isCenter ? 38 : 18,
                ),
                child: Text('$minutes:00'),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onScrollUpdate(ScrollMetrics metrics) {
    // Scroll sırasında ortadaki dakikayı seç
    double itemHeight = 45.0;

    // Scroll pozisyonuna göre ortadaki index'i hesapla
    double scrollOffset = metrics.pixels;
    int centerIndex = (scrollOffset / itemHeight).round();

    // Index'i dakikaya çevir (0-based -> 1-based)
    int minutes = centerIndex + 1;

    // Sınırları kontrol et
    minutes = minutes.clamp(1, 200);

    if (minutes != _selectedMinutes) {
      setState(() {
        _selectedMinutes = minutes;
        _secondsRemaining = minutes * 60;
      });

      // Scroll yapıldığında 800ms timer'ı yeniden başlat
      _autoSelectTimer?.cancel();
      _autoSelectTimer = Timer(const Duration(milliseconds: 800), () {
        if (_showTimeSelector && mounted) {
          _selectCurrentCenterTime();
        }
      });
    }
  }

  void _onScrollEnd(ScrollMetrics metrics) {
    // Scroll bittiğinde ortadaki dakikayı seç
    _onScrollUpdate(metrics);
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    return 1.0 - (_secondsRemaining / (_selectedMinutes * 60));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/wallpaper/${widget.wallpaper}'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Timer with Hour Marks
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Hour marks around the circle
                    SizedBox(
                      width: 350,
                      height: 350,
                      child: CustomPaint(painter: HourMarksPainter()),
                    ),
                    // Progress indicator (red line from right to left)
                    if (_isRunning)
                      SizedBox(
                        width: 350,
                        height: 350,
                        child: CustomPaint(
                          painter: ProgressLinePainter(_getProgress()),
                        ),
                      ),
                    // Timer Text - Scrollable Time Picker
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: _showTimeSelector && !_isRunning
                          ? Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: _buildScrollableTimePicker(),
                            )
                          : GestureDetector(
                              onTap: _toggleTimeSelector,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatTime(_secondsRemaining),
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isPaused
                                          ? widget.settings.getText('paused')
                                          : '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Control Buttons
                if (_isPaused) ...[
                  // Two buttons when paused
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Continue button
                      ElevatedButton.icon(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(widget.settings.getText('continue')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Reset button
                      ElevatedButton.icon(
                        onPressed: _resetTimer,
                        icon: const Icon(Icons.refresh),
                        label: Text(widget.settings.getText('reset')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Single button when running or stopped
                  ElevatedButton.icon(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      _isRunning
                          ? widget.settings.getText('pause')
                          : widget.settings.getText('start'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning
                          ? Colors.orange
                          : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HourMarksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20; // 20px padding from edge

    // Draw 60 minute marks (like a clock)
    for (int i = 0; i < 60; i++) {
      final angle = (i * 6) * math.pi / 180; // 6 degrees per minute

      // Calculate mark length (longer for every 5th minute)
      final isLongMark = i % 5 == 0;
      final markLength = isLongMark ? 15.0 : 8.0;

      // Calculate start and end points
      final startRadius = radius - markLength;
      final endRadius = radius;

      final startX = center.dx + startRadius * math.cos(angle - math.pi / 2);
      final startY = center.dy + startRadius * math.sin(angle - math.pi / 2);
      final endX = center.dx + endRadius * math.cos(angle - math.pi / 2);
      final endY = center.dy + endRadius * math.sin(angle - math.pi / 2);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProgressLinePainter extends CustomPainter {
  final double progress;

  ProgressLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 25; // 25px padding from edge

    // Draw progress line from right to left (clockwise)
    // Start from 3 o'clock position (right side)
    final startAngle = -math.pi / 2; // 3 o'clock position
    final sweepAngle = 2 * math.pi * progress; // Progress in radians

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is ProgressLinePainter && oldDelegate.progress != progress;
}
