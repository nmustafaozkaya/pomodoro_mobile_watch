import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:vibration/vibration.dart';
import 'api_client.dart';
import 'user_id_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WearApp extends StatefulWidget {
  const WearApp({super.key});

  @override
  State<WearApp> createState() => WearAppState();
}

class WearAppState extends State<WearApp> {
  static const platform = MethodChannel('com.pomodoro.wear/data');
  static const String _apiBaseUrl = 'http://52.59.192.113:4001/api';
  ApiClient? _apiClient;
  String? _userId;

  int _secondsRemaining = 1500; // 25 minutes default
  int _originalTime = 1500;
  int _selectedMinutes = 25; // Seçilen dakika
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  int _totalWorkMinutes = 0; // local stats for watch UI

  // Paging (Timer <-> Statistics <-> Settings)
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  // Scroll controller for settings page
  final ScrollController _settingsScrollController = ScrollController();

  // Store pending data to send to phone
  Map<String, dynamic>? _pendingData;

  // Dil kontrolü - Cihaz diline göre (Türkçe ise TR, değilse EN)
  bool get _isTurkish {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode == 'tr';
  }

  // Çeviri metodları
  String _t(String en, String tr) => _isTurkish ? tr : en;

  @override
  void initState() {
    super.initState();
    _initializeUserId();
    // Delay the platform call to avoid startup issues
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadInitialFromPhone();
    });

    // Try to send pending data periodically (only if not disposed)
    // Her 5 dakikada bir cloud sync - maliyeti düşürmek için
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _trySendPendingData();
        _refreshCloudTotals();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _initializeUserId() async {
    // Önce telefonun user ID'sini almaya çalış
    try {
      final String result = await platform.invokeMethod('getUserId');
      if (result.isNotEmpty) {
        _userId = result;
        // Saat tarafında da kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _userId!);
      } else {
        // Telefon bağlı değilse, kendi ID'sini oluştur veya kayıtlı olanı kullan
        _userId = await getOrCreateUserId();
      }
    } catch (_) {
      // Platform channel hatası, kendi ID'sini oluştur
      _userId = await getOrCreateUserId();
    }

    _apiClient = ApiClient(baseUrl: _apiBaseUrl, userId: _userId!);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settingsScrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isPaused) {
      // Devam et
      setState(() {
        _isPaused = false;
        _isRunning = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            _isPaused = false;

            // Timer bitince alarm ve titreşim
            _playAlarmAndVibrate();

            _sendDataToPhone();
          }
        });
      });
    } else if (_isRunning) {
      // Duraklat
      _timer?.cancel();
      setState(() {
        _isPaused = true;
        _isRunning = false;
      });
      // Don't send data on pause, only store local state
    } else {
      // Başlat
      setState(() {
        _isRunning = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            _isPaused = false;
            _sendDataToPhone();
          }
        });
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    // Capture worked minutes BEFORE resetting (round up)
    final workedBeforeReset = ((_originalTime - _secondsRemaining) + 59) ~/ 60;

    // Update local stats so statistics page reflects immediately
    if (workedBeforeReset > 0) {
      setState(() {
        _totalWorkMinutes += workedBeforeReset;
      });
    }

    // Send to phone with reset flag and actual worked minutes
    _pendingData = {
      'totalWorkMinutes': workedBeforeReset,
      'isCompleted': false,
      'isReset': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _trySendPendingData();

    // Also post to cloud (fire-and-forget)
    if (workedBeforeReset > 0 && _apiClient != null) {
      // ignore: discarded_futures
      _apiClient!.postSession(
        source: 'watch',
        minutes: workedBeforeReset,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
    }

    // Finally reset timer state
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _secondsRemaining = _originalTime;
    });
  }

  Future<void> _loadInitialFromPhone() async {
    // Önce SharedPreferences'tan kayıtlı dakikayı oku
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMinutes = prefs.getInt('selected_minutes') ?? 25;
      final durationSeconds = savedMinutes * 60;

      setState(() {
        _selectedMinutes = savedMinutes;
        _originalTime = durationSeconds;
        _secondsRemaining = durationSeconds;
      });
      return;
    } catch (_) {
      // SharedPreferences okuma hatası, platform channel'ı dene
    }

    // Fallback: Platform channel'dan oku (eski yöntem)
    try {
      // Expect JSON string from phone, e.g. {"durationSeconds":1500,"language":"tr"}
      final String result = await platform.invokeMethod('getInitialSettings');
      if (result.isNotEmpty) {
        final Map<String, dynamic> data = _tryParseJson(result);
        final int durationSeconds = (data['durationSeconds'] is int)
            ? data['durationSeconds'] as int
            : 1500;

        setState(() {
          _selectedMinutes = durationSeconds ~/ 60;
          _originalTime = durationSeconds;
          _secondsRemaining = durationSeconds;
        });
        return;
      }
    } catch (_) {
      // Ignore and use fallback
    }

    // Fallback defaults
    setState(() {
      _selectedMinutes = 25;
      _originalTime = 1500;
      _secondsRemaining = 1500;
    });
  }

  Map<String, dynamic> _tryParseJson(String value) {
    try {
      return Map<String, dynamic>.from(jsonDecode(value));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  // Timer bitince alarm çal ve titre (Wear OS için)
  Future<void> _playAlarmAndVibrate() async {
    try {
      // Titreşim desteği var mı kontrol et
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        // Wear OS için titreşim (3 saniye - 3 kez kısa)
        await Vibration.vibrate(duration: 400);
        await Future.delayed(const Duration(milliseconds: 300));
        await Vibration.vibrate(duration: 400);
        await Future.delayed(const Duration(milliseconds: 300));
        await Vibration.vibrate(duration: 400);
      }
    } catch (_) {
      // Sessizce devam et
    }
  }

  void _sendDataToPhone() {
    // Only store data when timer is completed or reset (not on pause)
    if (_secondsRemaining == 0 || (!_isRunning && !_isPaused)) {
      final workedSeconds = _originalTime - _secondsRemaining;
      final workedMinutes =
          (workedSeconds + 59) ~/ 60; // round up to next minute
      _pendingData = {
        'totalWorkMinutes': workedMinutes,
        'isCompleted': _secondsRemaining == 0,
        'isReset':
            (!_isRunning && !_isPaused && _secondsRemaining == _originalTime),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Update local statistics immediately for watch UI
      if (workedMinutes > 0 && _secondsRemaining == 0) {
        setState(() {
          _totalWorkMinutes += workedMinutes;
        });
      }

      // Try to send immediately, but don't wait for result
      _trySendPendingData();

      // Also post to cloud (fire-and-forget)
      if (workedMinutes > 0 && _secondsRemaining == 0 && _apiClient != null) {
        // ignore: discarded_futures
        _apiClient!.postSession(
          source: 'watch',
          minutes: workedMinutes,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<void> _refreshCloudTotals() async {
    if (_apiClient == null) return;
    try {
      final total = await _apiClient!.fetchTotalMinutes();
      if (mounted) {
        setState(() {
          _totalWorkMinutes = total;
        });
      }
    } catch (_) {
      // ignore errors silently
    }
  }

  Future<void> _trySendPendingData() async {
    if (_pendingData == null) return;

    try {
      await platform.invokeMethod('sendWorkData', _pendingData);
      // Success - clear pending data
      _pendingData = null;
    } on PlatformException {
      // Keep data pending for next attempt
      // This is normal when phone is not connected
    } catch (e) {
      // Handle any other exceptions silently
      // Keep data pending for next attempt
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PopScope(
        canPop: _currentPage == 0,
        onPopInvokedWithResult: (didPop, result) {
          // If we're on the stats page, prevent dismiss and go back to timer
          if (!didPop && _currentPage != 0) {
            _currentPage = 0;
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Listener(
            onPointerSignal: (signal) {
              // Handle rotary/bezel scroll to switch pages
              if (signal is PointerScrollEvent) {
                if (signal.scrollDelta.dy > 0 && _currentPage < 2) {
                  _currentPage++;
                  _pageController.animateToPage(
                    _currentPage,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                } else if (signal.scrollDelta.dy < 0 && _currentPage > 0) {
                  _currentPage--;
                  _pageController.animateToPage(
                    _currentPage,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              }
            },
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildTimerPage(),
                _buildStatisticsPage(),
                _buildSettingsPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerPage() {
    final double progress = _originalTime > 0
        ? (_originalTime - _secondsRemaining) / _originalTime
        : 0.0;

    return Stack(
      children: [
        // Süre yazısı - EN ÜSTTE
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              _formatTime(_secondsRemaining),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Saat çerçevesi - ORTADA YUKARDA
        Positioned(
          top: 4,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: CustomPaint(
                painter: _WearClockFramePainter(progress: progress),
              ),
            ),
          ),
        ),

        // Başlat/Duraklat butonu ve yazı - ALTTA
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: _isPaused
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _startTimer,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t('Resume', 'Devam'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _resetTimer,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                            child: const Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t('Reset', 'Sıfırla'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  children: [
                    GestureDetector(
                      onTap: _startTimer,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRunning ? Colors.orange : Colors.green,
                        ),
                        child: Icon(
                          _isRunning ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRunning
                          ? _t('Pause', 'Duraklat')
                          : _t('Start', 'Başlat'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
        ),

        // Süre seçmek için bilgi yazısı - EN ALTTA
        Positioned(
          top: 50,
          bottom: 0,
          left: 0,
          right: 0,
          child: Text(
            _t("Swipe right for duration", "Süre için sağa kaydır"),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.white60),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsPage() {
    return Stack(
      children: [
        // Merkez içerik - İstatistikler
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                _t('Statistics', 'İstatistikler'),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Text(
                _formatMinutesShort(_totalWorkMinutes),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _t('Total work time', 'Toplam çalışma'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Sol taraf - Pomodoro'ya dön (Sola ok)
        Positioned(
          left: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back,
                      color: Colors.white70,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t('Pomodoro', 'Pomodoro'),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Sağ taraf - Süre Seç'e git (Sağa ok)
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  2,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white70,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t('Duration', 'Süre Seç'),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatMinutesShort(int minutes) {
    if (_isTurkish) {
      // Türkçe format
      if (minutes < 60) return '${minutes}dk';
      final hours = minutes ~/ 60;
      final rest = minutes % 60;
      return rest == 0 ? '${hours}sa' : '${hours}sa ${rest}dk';
    } else {
      // İngilizce format
      if (minutes < 60) return '${minutes}m';
      final hours = minutes ~/ 60;
      final rest = minutes % 60;
      return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
    }
  }

  // Süre ayarlama sayfası
  Widget _buildSettingsPage() {
    final List<int> availableMinutes = [15, 20, 25, 30, 45, 60];

    return Listener(
      onPointerSignal: (signal) {
        // Ayarlar sayfasında döner çerçeve ile scroll
        if (signal is PointerScrollEvent) {
          if (_settingsScrollController.hasClients) {
            _settingsScrollController.jumpTo(
              _settingsScrollController.offset + signal.scrollDelta.dy,
            );
          }
        }
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              _t('Select Duration', 'Süre Seç'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                controller: _settingsScrollController,
                scrollDirection: Axis.vertical,
                itemCount: availableMinutes.length,
                itemBuilder: (context, index) {
                  final minutes = availableMinutes[index];
                  final isSelected = minutes == _selectedMinutes;

                  return GestureDetector(
                    onTap: () async {
                      setState(() {
                        _selectedMinutes = minutes;
                        _originalTime = minutes * 60;
                        if (!_isRunning && !_isPaused) {
                          _secondsRemaining = minutes * 60;
                        }
                      });

                      // SharedPreferences'a kaydet
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('selected_minutes', minutes);
                      } catch (_) {
                        // Ignore save errors
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.deepPurple
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _isTurkish ? '${minutes}dk' : '${minutes}m',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Saat çerçevesi çizen CustomPainter (Wear OS için büyük boyut)
class _WearClockFramePainter extends CustomPainter {
  final double progress;

  _WearClockFramePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Arka plan çember
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress çizgisi
    final progressPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    const startAngle = -90 * 3.14159 / 180; // Saat 12'den başla
    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // 12 SAAT ÇİZGİSİ (her 30 derece) - TAM dış çembere oturuyor
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * 3.14159 / 180;

      // Ana saat çizgileri (12, 3, 6, 9) daha kalın
      final isMainHour = i % 3 == 0;

      final hourMarkPaint = Paint()
        ..color = Colors.white.withValues(alpha: isMainHour ? 0.7 : 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMainHour ? 4.0 : 2.5
        ..strokeCap = StrokeCap.round;

      final markLength = isMainHour ? 15.0 : 10.0;
      // Çizgiler TAM radius'a denk geliyor (boşluksuz)
      final x1 = center.dx + (radius - markLength) * cos(angle);
      final y1 = center.dy + (radius - markLength) * sin(angle);
      final x2 = center.dx + radius * cos(angle);
      final y2 = center.dy + radius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), hourMarkPaint);
    }
  }

  @override
  bool shouldRepaint(_WearClockFramePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
