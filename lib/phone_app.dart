import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'statistics_page.dart';
import 'settings_page.dart';
import 'settings_model.dart';
import 'statistics_model.dart';
import 'dart:math' as math;
import 'api_client.dart';
import 'user_id_helper.dart';

class PhoneApp extends StatelessWidget {
  const PhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Google Fonts yükleme hatası durumunda varsayılan font kullan
    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.robotoTextTheme();
    } catch (e) {
      // Font yüklenemezse varsayılan font kullan
      textTheme = ThemeData.light().textTheme;
    }
    
    return MaterialApp(
      title: 'Pomodoro Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: textTheme,
        scaffoldBackgroundColor: Colors.white, // Splash ile uyumlu
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
  static const String _apiBaseUrl = 'http://52.59.192.113:4001/api';
  ApiClient? _apiClient;
  String? _userId;
  int _cloudTotalMinutes = 0;
  bool _isWallpaperLoaded = false; // Wallpaper yükleme durumu
  bool _isTimerRunning = false; // Timer çalışıyor mu?

  // Wear data storage (populated from cloud sync)
  Map<String, dynamic>? _wearData;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _settings = SettingsModel();
    _statistics = StatisticsModel();
    _initializeUserId();
    _loadSettings();
    // Context hazır olduktan sonra wallpaper'ı yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _preloadWallpaper();
      }
    });
  }

  Future<void> _initializeUserId() async {
    _userId = await getOrCreateUserId();
    _apiClient = ApiClient(baseUrl: _apiBaseUrl, userId: _userId!);
    if (mounted) {
      setState(() {});
      _startWearDataSync();
    }
  }

  Future<void> _loadSettings() async {
    try {
      await _settings.loadSettings();
      await _statistics.loadStatistics();

      final newWallpaper = _settings.currentWallpaper;
      if (newWallpaper != _currentWallpaper) {
        // Wallpaper değişmiş, yeniden yükle
        if (mounted) {
          setState(() {
            _currentWallpaper = newWallpaper;
          });
        }
        await _preloadWallpaper();
      }
    } catch (e) {
      // Hata durumunda varsayılan değerlerle devam et
      if (mounted) {
        setState(() {
          _currentWallpaper = 'wallpaper1.jpg';
        });
      }
      await _preloadWallpaper();
    }
  }

  // Wallpaper'ı önceden yükle (görsel olmadan ekran gösterme)
  Future<void> _preloadWallpaper() async {
    if (!mounted) return;
    try {
      // Mevcut wallpaper'ı yükle
      final image = AssetImage('assets/wallpaper/$_currentWallpaper');
      final context = this.context;
      if (context.mounted) {
        await precacheImage(image, context);
      }

      if (mounted) {
        setState(() {
          _isWallpaperLoaded = true;
        });
      }
    } catch (e) {
      // Hata durumunda yine de devam et (wallpaper yüklenemese bile uygulama çalışsın)
      if (mounted) {
        setState(() {
          _isWallpaperLoaded = true;
        });
      }
    }
  }

  void _onWallpaperChanged(String wallpaper) async {
    if (mounted) {
      setState(() {
        _currentWallpaper = wallpaper;
        _isWallpaperLoaded = false; // Yeni wallpaper yüklenecek
      });

      // Yeni wallpaper'ı yükle
      await _preloadWallpaper();
    }
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        if (_apiClient == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _TimerPage(
          key: const ValueKey('timer_page'), // Timer state'ini korumak için key
          settings: _settings,
          wallpaper: _currentWallpaper,
          statistics: _statistics,
          apiClient: _apiClient!,
          onTimerStateChanged: (isRunning) {
            setState(() {
              _isTimerRunning = isRunning;
            });
          },
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
          key: const ValueKey('settings_page'), // State'i korumak için key
          settings: _settings, // Aynı SettingsModel'i paylaş
          wallpaper: _currentWallpaper, // Mevcut duvar kağıdı ile aç
          onWallpaperChanged: _onWallpaperChanged,
          onLanguageChanged: _onLanguageChanged,
        );
      default:
        if (_apiClient == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _TimerPage(
          key: const ValueKey('timer_page'), // Timer state'ini korumak için key
          settings: _settings,
          wallpaper: _currentWallpaper,
          statistics: _statistics,
          apiClient: _apiClient!,
          onTimerStateChanged: (isRunning) {
            setState(() {
              _isTimerRunning = isRunning;
            });
          },
        );
    }
  }

  void _onLanguageChanged(String language) async {
    try {
      // Reload settings to get updated language
      await _settings.loadSettings();
      if (mounted) {
        setState(() {
          // This will trigger a rebuild with the new language
        });
      }
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  void _startWearDataSync() {
    // İlk senkronizasyonu hemen yap
    _syncCloudStats();

    // Her 3 dakikada bir cloud sync - maliyeti düşürmek için
    _syncTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Wear data sync disabled for emulator - only use cloud data
      _syncCloudStats();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncCloudStats() async {
    if (!mounted || _apiClient == null) return;
    try {
      final stats = await _apiClient!.fetchStats();
      if (mounted) {
        setState(() {
          _cloudTotalMinutes = stats['totalMinutes'] ?? 0;
          // Update _wearData with cloud data for statistics
          _wearData = {
            'totalWorkMinutes': stats['totalMinutes'] ?? 0,
            'recent': stats['recent'] ?? [],
          };
        });
      }
    } catch (_) {
      // ignore errors
    }
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        // Fallback background color - splash ile uyumlu beyaz
        Container(color: Colors.white),
        // Wallpaper image with error handling
        Image.asset(
          'assets/wallpaper/$_currentWallpaper',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Asset yükleme hatası durumunda boş widget döndür
            // (arka plandaki renk görünecek)
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // İlk build'de wallpaper yüklenene kadar loading göster
    // Ama context hazır değilse direkt içeriği göster (crash önleme)
    if (!_isWallpaperLoaded && _currentWallpaper.isNotEmpty) {
      // Context hazır olduğunda wallpaper'ı yükle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isWallpaperLoaded) {
          _preloadWallpaper();
        }
      });
      // Loading göster ama çok kısa süre (max 500ms)
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white, // Splash ile uyumlu
      extendBodyBehindAppBar: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // Arka plan resmi tüm ekranı kaplasın
            _buildBackground(),
            // Sayfa içeriği
            _buildCurrentPage(),
            // Navbar en üstte (timer çalışıyorsa gizle)
            if (!_isTimerRunning)
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
      ),
    );
  }
}

class _TimerPage extends StatefulWidget {
  final SettingsModel settings;
  final String wallpaper;
  final StatisticsModel statistics;
  final ApiClient apiClient;
  final Function(bool) onTimerStateChanged; // Timer durumu callback

  const _TimerPage({
    super.key,
    required this.settings,
    required this.wallpaper,
    required this.statistics,
    required this.apiClient,
    required this.onTimerStateChanged,
  });

  @override
  State<_TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<_TimerPage>
    with AutomaticKeepAliveClientMixin {
  Timer? _timer;
  int _secondsRemaining = 25 * 60; // 25 dakika
  int _selectedMinutes = 25; // Seçilen dakika
  int _breakMinutes = 5; // Ara süresi (dakika)
  int _breakSecondsRemaining = 300; // 5 dakika = 300 saniye
  bool _isBreakTime = false; // Pomodoro mu ara mı?
  bool _isRunning = false;
  bool _isPaused = false;
  bool _showTimeSelector = false;
  late ScrollController _scrollController;
  Timer? _autoSelectTimer;
  int _sessionStartSeconds = 0; // Timer başladığında kaydedilen toplam saniye
  final AudioPlayer _audioPlayer = AudioPlayer(); // Alarm sesi için

  @override
  bool get wantKeepAlive => true; // Widget state'ini koru

  @override
  void initState() {
    super.initState();
    // Kaydedilmiş timer dakikasını yükle
    _selectedMinutes = widget.settings.selectedMinutes;
    _secondsRemaining = _selectedMinutes * 60;
    _breakMinutes = widget.settings.breakMinutes;
    _breakSecondsRemaining = _breakMinutes * 60;
    // Scroll controller'ı daha yüksek initial offset ile başlat
    _scrollController = ScrollController(
      initialScrollOffset: 0.0, // En üstten başla
    );
    // Timer seçiciyi başlangıçta kapalı
    _showTimeSelector = false;
    // Başlangıç pozisyonunu seçili dakikaya ayarla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
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
  void didUpdateWidget(_TimerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget güncellendiğinde (sekmeler arası geçişte) kaydedilmiş değeri kontrol et
    final savedMinutes = widget.settings.selectedMinutes;
    final savedBreakMinutes = widget.settings.breakMinutes;
    if ((savedMinutes != _selectedMinutes ||
            savedBreakMinutes != _breakMinutes) &&
        !_isRunning &&
        !_isPaused) {
      // Timer çalışmıyorsa kaydedilmiş değere güncelle
      setState(() {
        _selectedMinutes = savedMinutes;
        _secondsRemaining = savedMinutes * 60;
        _breakMinutes = savedBreakMinutes;
        _breakSecondsRemaining = savedBreakMinutes * 60;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoSelectTimer?.cancel();
    _scrollController.dispose();
    _audioPlayer.dispose(); // AudioPlayer'ı temizle
    super.dispose();
  }

  // Timer bitince alarm çal ve titre
  Future<void> _playAlarmAndVibrate() async {
    try {
      // Kullanıcının seçtiği alarm sesini çal
      final soundPath = widget.settings.getAlarmSoundPath();

      if (soundPath != null) {
        // Alarm sesini 1 kez çal (loop yok) ve 5 saniye sonra durdur
        await _audioPlayer.stop(); // Önce durdur (eğer çalıyorsa)
        await _audioPlayer.play(
          AssetSource(soundPath),
          mode: PlayerMode.mediaPlayer, // Loop yok
        );

        // 5 saniye sonra alarm sesini durdur
        Future.delayed(const Duration(seconds: 5), () {
          _audioPlayer.stop();
        });
      }

      // Titreşim (her zaman çalışır, ses olsa da olmasa da)
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        // 3 kez kısa titreşim (~3 saniye toplam)
        await Vibration.vibrate(duration: 400);
        await Future.delayed(const Duration(milliseconds: 300));
        await Vibration.vibrate(duration: 400);
        await Future.delayed(const Duration(milliseconds: 300));
        await Vibration.vibrate(duration: 400);
      }
    } catch (e) {
      // Ses dosyası yoksa veya hata varsa sadece titreşim yap
      try {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator) {
          // Uzun titreşim (1 saniye)
          await Vibration.vibrate(duration: 1000);
        }
      } catch (_) {
        // Hiçbir şey yapma, sessizce devam et
      }
    }
  }

  void _startTimer() {
    if (_isPaused) {
      // Pause'dan devam ediyor, yeni session başlatma
      _isPaused = false;
      _isRunning = true;
    } else {
      // Yeni session başlatılıyor
      _isRunning = true;
      _sessionStartSeconds = _secondsRemaining; // Başlangıç saniyesini kaydet
    }

    // Parent'a timer başladığını bildir
    widget.onTimerStateChanged(true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_isBreakTime) {
          // Ara zamanı
          if (_breakSecondsRemaining > 0) {
            _breakSecondsRemaining--;
          } else {
            // Ara bitti - kullanıcıya seçenek sun
            _timer?.cancel();
            _isRunning = false;
            _isPaused = false;
            _playAlarmAndVibrate();
            // Pomodoro'ya geç ama başlatma
            _isBreakTime = false;
            _secondsRemaining = _selectedMinutes * 60;
            _sessionStartSeconds = 0;
          }
        } else {
          // Pomodoro zamanı
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            _isPaused = false;

            // Timer tamamlandığında alarm çal ve titre
            _playAlarmAndVibrate();

            // İstatistikleri kaydet
            _recordCompletedSession();

            _sessionStartSeconds = 0; // Session bitti, sıfırla

            // Ara'ya geç ama başlatma - kullanıcıya seçenek sun
            _isBreakTime = true;
            _breakSecondsRemaining = _breakMinutes * 60;
          }
        }
      });
    });
  }

  void _skipToNext() {
    // Bir sonraki aşamaya geç (pomodoro <-> ara) ama timer başlatma
    setState(() {
      if (_isBreakTime) {
        // Ara'dan Pomodoro'ya geç
        _isBreakTime = false;
        _secondsRemaining = _selectedMinutes * 60;
        _sessionStartSeconds = _secondsRemaining;
      } else {
        // Pomodoro'dan Ara'ya geç
        _isBreakTime = true;
        _breakSecondsRemaining = _breakMinutes * 60;
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _isPaused = true;
      });
      // Parent'a timer durduğunu bildir (pause)
      widget.onTimerStateChanged(false);
    }
  }

  void _resetTimer() {
    _timer?.cancel();

    // Eğer timer çalışıyorsa ve sıfırlanıyorsa, mevcut çalışılan süreyi kaydet
    if (_sessionStartSeconds > 0) {
      // Çalışılan saniyeyi hesapla
      final workedSeconds = _sessionStartSeconds - _secondsRemaining;
      // Sadece tam dakikaları kaydet (60 saniye = 1 dakika)
      // En az 60 saniye çalışılmışsa kaydet
      if (workedSeconds >= 60) {
        final workedMinutes = workedSeconds ~/ 60; // Tam dakikaları al
        _recordPartialSession(workedMinutes);
      }
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
        _isPaused = false;
        _isBreakTime = false;
        _secondsRemaining = _selectedMinutes * 60;
        _breakSecondsRemaining = _breakMinutes * 60;
        _sessionStartSeconds = 0; // Session sıfırlandı
      });
      // Parent'a timer durduğunu bildir (reset)
      widget.onTimerStateChanged(false);
    }
  }

  // Timer tamamlandığında çalışan session kaydet
  Future<void> _recordCompletedSession() async {
    if (_sessionStartSeconds > 0) {
      // Tamamlanan session'da başlangıç dakikasını hesapla
      final sessionMinutes = _sessionStartSeconds ~/ 60;
      if (sessionMinutes > 0) {
        // 1. Önce lokal'e kaydet (offline çalışma için)
        await widget.statistics.recordSession(sessionMinutes);

        // 2. Sonra cloud'a gönder (senkronizasyon için)
        // ignore: discarded_futures
        widget.apiClient.postSession(
          source: 'phone',
          minutes: sessionMinutes,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
      _sessionStartSeconds = 0;
    }
  }

  // Timer sıfırlandığında kısmi session kaydet
  Future<void> _recordPartialSession(int workedMinutes) async {
    // 1. Önce lokal'e kaydet (offline çalışma için)
    await widget.statistics.recordSession(workedMinutes);

    // 2. Sonra cloud'a gönder (senkronizasyon için)
    // ignore: discarded_futures
    widget.apiClient.postSession(
      source: 'phone',
      minutes: workedMinutes,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _toggleTimeSelector() {
    if (!_isRunning && mounted) {
      // Timer seçiciyi direkt aç
      setState(() {
        _showTimeSelector = true;
      });

      // Timer seçici açıldığında seçili dakikaya scroll et
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
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
    if (!mounted) return;
    // Şu an ortada olan dakikayı seç ve timer seçiciyi kapat
    setState(() {
      _showTimeSelector = false;
    });
    _autoSelectTimer?.cancel();

    // Seçilen dakikayı kaydet (timer seçici kapanırken)
    widget.settings.setSelectedMinutes(_selectedMinutes);

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
    if (!mounted) return;
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

      // Seçilen dakikayı kaydet
      widget.settings.setSelectedMinutes(minutes);

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
    if (_isBreakTime) {
      final totalBreakSeconds = _breakMinutes * 60;
      return 1.0 - (_breakSecondsRemaining / totalBreakSeconds);
    } else {
      return 1.0 - (_secondsRemaining / (_selectedMinutes * 60));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli

    // Build sırasında kaydedilmiş değeri kontrol et (timer çalışmıyorsa)
    if (!_isRunning && !_isPaused) {
      final savedMinutes = widget.settings.selectedMinutes;
      final savedBreakMinutes = widget.settings.breakMinutes;
      if ((savedMinutes != _selectedMinutes ||
              savedBreakMinutes != _breakMinutes) &&
          !_isRunning &&
          !_isPaused) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedMinutes = savedMinutes;
              _secondsRemaining = savedMinutes * 60;
              _breakMinutes = savedBreakMinutes;
              _breakSecondsRemaining = savedBreakMinutes * 60;
            });
          }
        });
      }
    }

    // Timer durumu hesaplamaları
    final currentSeconds = _isBreakTime
        ? _breakSecondsRemaining
        : _secondsRemaining;
    final isTimerFinished = currentSeconds == 0 && !_isRunning && !_isPaused;

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
                                      _isBreakTime
                                          ? widget.settings.getText('break')
                                          : widget.settings.getText('pomodoro'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(
                                        _isBreakTime
                                            ? _breakSecondsRemaining
                                            : _secondsRemaining,
                                      ),
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
                ] else if (isTimerFinished) ...[
                  // Two buttons when timer finished
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Start button
                      ElevatedButton.icon(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(widget.settings.getText('start')),
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
                      // Skip button
                      ElevatedButton.icon(
                        onPressed: _skipToNext,
                        icon: const Icon(Icons.skip_next),
                        label: Text(widget.settings.getText('skip')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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
