import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WearApp extends StatefulWidget {
  const WearApp({super.key});

  @override
  State<WearApp> createState() => WearAppState();
}

class WearAppState extends State<WearApp> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.pomodoro.wear/data');
  static const statsChannel = EventChannel('com.pomodoro.wear/stats');
  static const settingsChannel = EventChannel('com.pomodoro.wear/settings');
  /// Wear OS taç / rotary encoder — native `dispatchGenericMotionEvent` ile beslenir.
  static const rotaryChannel = EventChannel('com.pomodoro.wear/rotary');

  int _secondsRemaining = 1500; // 25 minutes default
  int _originalTime = 1500;
  int _selectedMinutes = 25; // Seçilen dakika
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  /// İstatistik ekranında gösterilen toplam (telefon + bu saatte biten oturumlar).
  int _totalWorkMinutes = 0;
  /// Telefonun Data Layer ile bildirdiği toplam (gecikmeli / 0 olabilir).
  int _lastPhoneReportedTotal = 0;
  /// Bu saatte tamamlanan (Bitir veya süre dolunca) dakikalar — telefon yokken de gösterilir.
  int _watchDeviceWorkTotal = 0;

  static const String _prefsWatchDeviceWork = 'wear_device_work_minutes_total';
  // Paging (Timer <-> Statistics <-> Settings)
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  // Scroll controller for settings page
  final ScrollController _settingsScrollController = ScrollController();

  StreamSubscription<dynamic>? _statsSubscription;
  StreamSubscription<dynamic>? _settingsSubscription;
  StreamSubscription<dynamic>? _rotarySubscription;

  /// Taç hareketlerini sayfa değişimine birleştirmek için (küçük axis değerleri).
  double _rotaryPageAccum = 0;

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
    WidgetsBinding.instance.addObserver(this);
    _startListeningToPhoneSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWatchDeviceWorkFromPrefs();
    });
    _rotarySubscription = rotaryChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final axis = (event as num?)?.toDouble() ?? 0;
        if (axis == 0 || !mounted) return;
        _handleRotaryAxis(axis);
      },
      onError: (_) {},
    );
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _loadWatchDeviceWorkFromPrefs();
      _loadInitialFromPhone();
      await _requestTotalFromPhone();
    });
    _startListeningToPhoneStats();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (!mounted) return;
        _loadInitialFromPhone();
        await _loadWatchDeviceWorkFromPrefs();
        await _requestTotalFromPhone();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _settingsScrollController.dispose();
    _statsSubscription?.cancel();
    _settingsSubscription?.cancel();
    _rotarySubscription?.cancel();
    super.dispose();
  }

  void _recomputeStatsDisplay() {
    if (!mounted) return;
    final merged = math.max(_lastPhoneReportedTotal, _watchDeviceWorkTotal);
    setState(() {
      _totalWorkMinutes = merged;
    });
  }

  Future<void> _loadWatchDeviceWorkFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_prefsWatchDeviceWork) ?? 0;
      if (!mounted) return;
      _watchDeviceWorkTotal = v;
      _recomputeStatsDisplay();
    } catch (_) {}
  }

  /// Bu saatte biten pomodoro dakikası — istatistik ekranı anında güncellenir; telefona da gönderilir.
  Future<void> _addWatchDeviceWorkMinutes(int minutes) async {
    if (minutes <= 0 || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(_prefsWatchDeviceWork) ?? 0) + minutes;
      await prefs.setInt(_prefsWatchDeviceWork, next);
      if (!mounted) return;
      _watchDeviceWorkTotal = next;
      _recomputeStatsDisplay();
    } catch (_) {}
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

            _sendWorkSessionToPhone();
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
            _playAlarmAndVibrate();
            _sendWorkSessionToPhone();
          }
        });
      });
    }
  }

  /// Duraklat sonrası: çalışılan dakikayı telefona gönder, süreyi başa al.
  Future<void> _finishWorkEarly() async {
    if (!_isPaused) return;
    _timer?.cancel();
    await _sendWorkSessionToPhone();
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _secondsRemaining = _originalTime;
    });
  }

  Future<void> _sendWorkSessionToPhone() async {
    if (!mounted) return;
    final workedSeconds = _originalTime - _secondsRemaining;
    if (workedSeconds <= 0) return;
    final workedMinutes = (workedSeconds + 59) ~/ 60;
    if (workedMinutes <= 0) return;

    await _addWatchDeviceWorkMinutes(workedMinutes);

    final sessionData = {
      'minutes': workedMinutes,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await platform.invokeMethod('sendSession', sessionData);
      await _requestTotalFromPhone();
    } catch (_) {}
  }

  Future<void> _loadInitialFromPhone() async {
    try {
      final String raw =
          await platform.invokeMethod<String>('getSettingsFromDataLayer') ??
              '{}';
      final Map<String, dynamic> data = _tryParseJson(raw);
      final dynamic sm = data['selectedMinutes'];
      final int? fromPhone = sm is int
          ? sm
          : (sm is num ? sm.toInt() : int.tryParse('$sm'));
      if (fromPhone != null && fromPhone > 0) {
        await _applyPhoneSelectedMinutes(fromPhone);
        return;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMinutes = prefs.getInt('selected_minutes') ?? 25;
      final durationSeconds = savedMinutes * 60;
      if (!mounted) return;
      setState(() {
        _selectedMinutes = savedMinutes;
        _originalTime = durationSeconds;
        _secondsRemaining = durationSeconds;
      });
      return;
    } catch (_) {}

    if (!mounted) return;
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

  // Telefondaki toplam istatistiği dinle
  void _startListeningToPhoneStats() {
    _statsSubscription = statsChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (!mounted) return;
        final phoneT = event as int? ?? 0;
        _lastPhoneReportedTotal = phoneT;
        _recomputeStatsDisplay();
      },
      onError: (error) {
        // Hataları sessizce yok say
      },
    );
  }

  /// Telefondan Data Layer ile gelen pomodoro süresi (dakika) güncellemeleri.
  void _startListeningToPhoneSettings() {
    _settingsSubscription =
        settingsChannel.receiveBroadcastStream().listen((dynamic event) async {
      if (!mounted || event is! Map) return;
      final minutes = (event['selectedMinutes'] as num?)?.toInt();
      if (minutes == null || minutes <= 0) return;
      if (_isRunning || _isPaused) return;
      await _applyPhoneSelectedMinutes(minutes);
    }, onError: (_) {});
  }

  Future<void> _applyPhoneSelectedMinutes(int minutes) async {
    final durationSeconds = minutes * 60;
    if (!mounted) return;
    setState(() {
      _selectedMinutes = minutes;
      _originalTime = durationSeconds;
      _secondsRemaining = durationSeconds;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_minutes', minutes);
    } catch (_) {}
  }

  // Telefona "toplam ne kadar?" diye sor
  Future<void> _requestTotalFromPhone() async {
    try {
      final int total = await platform.invokeMethod('getTotalMinutes');
      if (!mounted) return;
      _lastPhoneReportedTotal = total;
      _recomputeStatsDisplay();
    } catch (_) {
      // Telefon bağlı değil — sadece saat yerel toplamı _recomputeStatsDisplay ile kalır
      if (mounted) _recomputeStatsDisplay();
    }
  }

  // İstatistik sayfasında refresh butonu için
  Future<void> _refreshStats(BuildContext context) async {
    await _requestTotalFromPhone();
    if (mounted && context.mounted) {
      // Küçük ve ortada mesaj göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Refreshed', 'Yenilendi'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Daire gibi yuvarlak
          ),
        ),
      );
    }
  }

  /// Süre listesi: dokunmatik tekerlek veya taç ile dikey kaydırma.
  void _scrollSettingsByVerticalDelta(double dy) {
    if (!_settingsScrollController.hasClients || dy == 0) return;
    final c = _settingsScrollController;
    final next = (c.offset + dy).clamp(0.0, c.position.maxScrollExtent);
    if (next != c.offset) c.jumpTo(next);
  }

  void _stepWearPage(int direction) {
    if (direction > 0 && _currentPage < 2) {
      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (direction < 0 && _currentPage > 0) {
      _currentPage--;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _handlePointerScroll(double dy) {
    if (dy == 0) return;
    if (_currentPage == 2) {
      _scrollSettingsByVerticalDelta(dy);
      return;
    }
    if (dy > 0) {
      _stepWearPage(1);
    } else if (dy < 0) {
      _stepWearPage(-1);
    }
  }

  /// Native rotary encoder (Galaxy / Pixel taç vb.); küçük adımları biriktirip sayfa veya liste kaydırır.
  void _handleRotaryAxis(double axis) {
    if (_currentPage == 2) {
      _scrollSettingsByVerticalDelta(axis * 56);
      return;
    }
    _rotaryPageAccum += axis;
    const step = 0.24;
    while (_rotaryPageAccum >= step) {
      _rotaryPageAccum -= step;
      _stepWearPage(1);
    }
    while (_rotaryPageAccum <= -step) {
      _rotaryPageAccum += step;
      _stepWearPage(-1);
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
              if (signal is PointerScrollEvent) {
                _handlePointerScroll(signal.scrollDelta.dy);
              }
            },
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                  _rotaryPageAccum = 0;
                });
                // İstatistikler sayfasına gelince refresh yap
                if (index == 1) {
                  _requestTotalFromPhone();
                }
              },
              children: [
                _buildTimerPage(),
                Builder(builder: (context) => _buildStatisticsPage(context)),
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
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Çember (altta): Impeller + küçük ekranda güvenilir boyut; dokunuşları yutmaz
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Yuvarlak yüzeyin çevresini kapla (kenara yakın; güvenli pay ~%3)
              final shortest = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final side = math.max(140.0, shortest * 0.995);
              return Center(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: CustomPaint(
                        painter: _WearClockFramePainter(progress: progress),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Positioned(
          top: 38,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Text(
                _t("Swipe right for duration", "Süre için sağa kaydır"),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.white60),
              ),
            ),
          ),
        ),

        Center(
          child: LayoutBuilder(
            builder: (context, c) {
              return Padding(
                padding: EdgeInsets.only(bottom: c.maxHeight * 0.06),
                child: Text(
                  _formatTime(_secondsRemaining),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),

        Positioned(
          bottom: 22,
          left: 0,
          right: 0,
          child: Center(
            child: _isPaused
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _startTimer();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _t('Resume', 'Devam'),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 22),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _finishWorkEarly();
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.deepPurple,
                                ),
                                child: const Icon(
                                  Icons.flag,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _t('Finish', 'Bitir'),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _startTimer();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRunning ? Colors.orange : Colors.green,
                          ),
                          child: Icon(
                            _isRunning ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isRunning
                            ? _t('Pause', 'Duraklat')
                            : _t('Start', 'Başlat'),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsPage(BuildContext context) {
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

              // Refresh butonu
              GestureDetector(
                onTap: () => _refreshStats(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _t('Refresh', 'Yenile'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

    return Center(
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
    );
  }
}

// Saat çerçevesi çizen CustomPainter (Wear OS için büyük boyut)
class _WearClockFramePainter extends CustomPainter {
  final double progress;

  _WearClockFramePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);

    // Dış çember (bezel): inset az = yüz kenarına daha yakın, görsel olarak daha büyük halka
    const double edgeInset = 1.0;
    const double trackStroke = 7.5;
    final double rimOuter = shortest / 2 - edgeInset;
    final double ringRadius = (rimOuter - trackStroke / 2).clamp(8.0, rimOuter);

    // Arka plan çemberi
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStroke;
    canvas.drawCircle(center, ringRadius, bgPaint);

    // İlerleme yayı — aynı hatta
    final progressPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStroke
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Saat çizgileri: uçları dış rim’e dayalı, yüzeye doğru (bezel görünümü)
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final isMainHour = i % 3 == 0;

      final hourMarkPaint = Paint()
        ..color = Colors.white.withValues(alpha: isMainHour ? 0.85 : 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMainHour ? 3.5 : 2.2
        ..strokeCap = StrokeCap.round;

      final markLength = isMainHour ? 14.0 : 9.0;
      final outerR = rimOuter - 1.0;
      final innerR = math.min(outerR - 2.0, math.max(6.0, outerR - markLength));

      final x1 = center.dx + innerR * math.cos(angle);
      final y1 = center.dy + innerR * math.sin(angle);
      final x2 = center.dx + outerR * math.cos(angle);
      final y2 = center.dy + outerR * math.sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), hourMarkPaint);
    }
  }

  @override
  bool shouldRepaint(_WearClockFramePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
