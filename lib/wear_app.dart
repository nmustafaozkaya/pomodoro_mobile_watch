import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class WearApp extends StatefulWidget {
  const WearApp({super.key});

  @override
  State<WearApp> createState() => WearAppState();
}

class WearAppState extends State<WearApp> {
  static const platform = MethodChannel('com.pomodoro.wear/data');

  int _secondsRemaining = 1500; // 25 minutes default
  int _originalTime = 1500;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;

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
      _isPaused = false;
      _isRunning = true;
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
      setState(() {
        _isRunning = true;
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _secondsRemaining = _originalTime;
    });
    _sendDataToPhone();
  }

  Future<void> _loadInitialFromPhone() async {
    // Skip platform call for now to prevent crashes
    // Use default values
    setState(() {
      _originalTime = 1500; // 25 minutes default
      _secondsRemaining = 1500;
    });
  }

  void _sendDataToPhone() {
    // Only store data when timer is completed or reset (not on pause)
    if (_secondsRemaining == 0 || (!_isRunning && !_isPaused)) {
      _pendingData = {
        'totalWorkMinutes': (_originalTime - _secondsRemaining) ~/ 60,
        'isCompleted': _secondsRemaining == 0,
        'isReset':
            (!_isRunning && !_isPaused && _secondsRemaining == _originalTime),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Try to send immediately, but don't wait for result
      _trySendPendingData();
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
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
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
                // Show Continue and Reset buttons when paused
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Continue button
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
                    // Reset button
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
                // Show single button when running or stopped
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
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
