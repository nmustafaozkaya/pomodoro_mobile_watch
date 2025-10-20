import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'dart:async';
import 'api_client.dart';

class WearApp extends StatefulWidget {
  const WearApp({super.key});

  @override
  State<WearApp> createState() => WearAppState();
}

class WearAppState extends State<WearApp> {
  static const platform = MethodChannel('com.pomodoro.wear/data');
  static const String _apiBaseUrl = 'https://nmustafaozkaya.com.tr/api';
  static const String _userId = 'mustafa';
  late final ApiClient _apiClient = ApiClient(
    baseUrl: _apiBaseUrl,
    userId: _userId,
  );

  int _secondsRemaining = 1500; // 25 minutes default
  int _originalTime = 1500;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  int _totalWorkMinutes = 0; // local stats for watch UI

  // Paging (Timer <-> Statistics)
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  // Store pending data to send to phone
  Map<String, dynamic>? _pendingData;

  @override
  void initState() {
    super.initState();
    // Delay the platform call to avoid startup issues
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadInitialFromPhone();
    });

    // Try to send pending data periodically (only if not disposed)
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _trySendPendingData();
        _refreshCloudTotals();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    if (workedBeforeReset > 0) {
      // ignore: discarded_futures
      _apiClient.postSession(
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
    try {
      // Expect JSON string from phone, e.g. {"durationSeconds":1500,"language":"tr"}
      final String result = await platform.invokeMethod('getInitialSettings');
      if (result.isNotEmpty) {
        final Map<String, dynamic> data = _tryParseJson(result);
        final int durationSeconds = (data['durationSeconds'] is int)
            ? data['durationSeconds'] as int
            : 1500;
        // Keep for future localization usage
        // final String language = (data['language'] is String)
        //     ? data['language'] as String
        //     : 'tr';

        setState(() {
          _originalTime = durationSeconds;
          _secondsRemaining = durationSeconds;
          // If you later show language-dependent text, store language
          // _language = language; // optional for future UI changes
        });
        return;
      }
    } catch (_) {
      // Ignore and use fallback
    }

    // Fallback defaults
    setState(() {
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
      if (workedMinutes > 0 && _secondsRemaining == 0) {
        // ignore: discarded_futures
        _apiClient.postSession(
          source: 'watch',
          minutes: workedMinutes,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<void> _refreshCloudTotals() async {
    try {
      final total = await _apiClient.fetchTotalMinutes();
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
                if (signal.scrollDelta.dy > 0 && _currentPage < 1) {
                  _currentPage = 1;
                  _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                } else if (signal.scrollDelta.dy < 0 && _currentPage > 0) {
                  _currentPage = 0;
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              }
            },
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [_buildTimerPage(), _buildStatisticsPage()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatTime(_secondsRemaining),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          if (_isPaused)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: _startTimer,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _resetTimer,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: const Icon(
                      Icons.stop,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: _startTimer,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRunning ? Colors.orange : Colors.green,
                ),
                child: Icon(
                  _isRunning ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          const Text(
            'İstatistikler',
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
          const Text(
            'Toplam çalışma',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatMinutesShort(int minutes) {
    if (minutes < 60) return '${minutes}dk';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}sa' : '${hours}sa ${rest}dk';
  }
}
