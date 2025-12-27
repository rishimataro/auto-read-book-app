import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'tts_state.dart';

class TtsCubit extends Cubit<TtsState> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isReading = false;
  double _speechRate = 0.5;
  DateTime? _readingStartTime;
  String? _currentReadingText;
  Function()? _onReadingComplete;
  final List<String> _readingQueue = [];

  TtsCubit() : super(TtsInitial()) {
    _loadSettingsAndInitTts();
    _setupTtsCallbacks();
  }

  void _setupTtsCallbacks() {
    _flutterTts.setCompletionHandler(() {
      if (_readingQueue.isNotEmpty) {
        final nextText = _readingQueue.removeAt(0);
        _currentReadingText = nextText;
        _readingStartTime = DateTime.now();
        emit(TtsReading(nextText));
        _flutterTts.speak(nextText);
      } else {
        _isReading = false;
        _readingStartTime = null;
        _currentReadingText = null;
        emit(TtsIdle());
        if (_onReadingComplete != null) {
          _onReadingComplete!();
          _onReadingComplete = null;
        }
      }
    });
  }

  Future<void> _loadSettingsAndInitTts() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('read_language') ?? 'vi-VN';
    _speechRate = prefs.getDouble('speech_rate') ?? 0.5;

    await _flutterTts.setLanguage(language);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> readText(String text, {Function()? onComplete}) async {
    if (text.isEmpty) return;
 
    if (onComplete != null) {
      _onReadingComplete = onComplete;
    }

    if (_isReading) {
      _readingQueue.add(text);
      return;
    }

    _isReading = true;
    _currentReadingText = text;
    _readingStartTime = DateTime.now();
    emit(TtsReading(text));
    await _flutterTts.speak(text);
  }

  /// Ước tính thời gian đọc (giây) dựa trên độ dài text và tốc độ đọc
  /// Giả sử: ~150 từ/phút với speechRate = 1.0
  /// Mỗi từ tiếng Việt trung bình ~5 ký tự
  double estimateReadingTime(String text) {
    if (text.isEmpty) return 0;
    
    // Đếm số từ (chia theo khoảng trắng)
    final words = text.trim().split(RegExp(r'\s+'));
    final wordCount = words.length;
    
    // Tốc độ đọc cơ bản: 150 từ/phút với rate = 1.0
    // Với rate = 0.5 thì tốc độ = 75 từ/phút
    final wordsPerMinute = 150 * _speechRate;
    final minutes = wordCount / wordsPerMinute;
    
    return minutes * 60; // Trả về giây
  }

  /// Lấy thời gian đọc đã trôi qua (giây)
  double? getElapsedReadingTime() {
    if (_readingStartTime == null) return null;
    return DateTime.now().difference(_readingStartTime!).inMilliseconds / 1000.0;
  }

  /// Lấy thời gian đọc còn lại ước tính (giây)
  double? getRemainingReadingTime() {
    if (_currentReadingText == null || _readingStartTime == null) return null;
    final totalTime = estimateReadingTime(_currentReadingText!);
    final elapsed = getElapsedReadingTime() ?? 0;
    return (totalTime - elapsed).clamp(0, double.infinity);
  }

  /// Kiểm tra xem đã đọc được bao nhiêu phần trăm
  double? getReadingProgress() {
    if (_currentReadingText == null || _readingStartTime == null) return null;
    final totalTime = estimateReadingTime(_currentReadingText!);
    if (totalTime == 0) return 1.0;
    final elapsed = getElapsedReadingTime() ?? 0;
    return (elapsed / totalTime).clamp(0.0, 1.0);
  }

  /// Lấy text đang đọc hiện tại
  String? getCurrentReadingText() {
    return _currentReadingText;
  }

  /// Tính vị trí ký tự đã đọc được dựa trên thời gian đã trôi qua
  /// Trả về số ký tự đã đọc được (ước tính)
  int? getReadingPosition() {
    if (_currentReadingText == null || _readingStartTime == null) return null;
    
    final totalTime = estimateReadingTime(_currentReadingText!);
    if (totalTime == 0) return _currentReadingText!.length;
    
    final elapsed = getElapsedReadingTime() ?? 0;
    final progress = (elapsed / totalTime).clamp(0.0, 1.0);
    
    // Tính số ký tự đã đọc dựa trên progress
    final position = (progress * _currentReadingText!.length).round();
    return position.clamp(0, _currentReadingText!.length);
  }

  void stopReading() {
    _flutterTts.stop();
    _isReading = false;
    _readingQueue.clear();
    emit(TtsIdle());
  }

  void pauseReading() {
    _flutterTts.pause();
    emit(TtsPaused());
  }

  Future<void> setRate(double rate) async {
    _speechRate = rate;
    await _flutterTts.setSpeechRate(rate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speech_rate', rate);
  }
}

