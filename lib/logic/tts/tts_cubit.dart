import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'tts_state.dart';

class TtsCubit extends Cubit<TtsState> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isReading = false;
  List<Map<String, String>> _availableVoices = [];
  String? _currentVoiceName;
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
    final savedVoice = prefs.getString('tts_voice_name');
    _speechRate = prefs.getDouble('speech_rate') ?? 0.5;

    await _flutterTts.setLanguage(language);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Load available voices first
    await loadAvailableVoices();
    
    // Set saved voice if available, otherwise use first available voice
    if (savedVoice != null && savedVoice.isNotEmpty) {
      // Check if saved voice still exists in available voices
      final voiceExists = _availableVoices.any((v) => v['name'] == savedVoice);
      if (voiceExists) {
        await setVoice(savedVoice);
      } else if (_availableVoices.isNotEmpty) {
        // If saved voice doesn't exist, use first available voice
        await setVoice(_availableVoices.first['name'] ?? '');
      }
    } else if (_availableVoices.isNotEmpty) {
      // If no saved voice, use first available voice
      await setVoice(_availableVoices.first['name'] ?? '');
    }
  }

  Future<void> loadAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null) {
        _availableVoices = List<Map<String, String>>.from(voices);
        
        // Filter voices by current language
        final language = await _flutterTts.getLanguages ?? 'vi-VN';
        final filteredVoices = _availableVoices.where((voice) {
          final voiceLocale = voice['locale'] ?? '';
          return voiceLocale.startsWith(language.split('-')[0]);
        }).toList();
        
        if (filteredVoices.isNotEmpty) {
          _availableVoices = filteredVoices;
        }
        
        emit(TtsVoicesLoaded(voices: _availableVoices, currentVoice: _currentVoiceName));
      }
    } catch (e) {
      print('Error loading voices: $e');
      _availableVoices = [];
    }
  }

  Future<void> setVoice(String voiceName) async {
    try {
      // Find voice by name
      final voice = _availableVoices.firstWhere(
        (v) => v['name'] == voiceName,
        orElse: () => _availableVoices.isNotEmpty ? _availableVoices.first : {},
      );
      
      if (voice.isNotEmpty) {
        await _flutterTts.setVoice({
          'name': voice['name'] ?? '',
          'locale': voice['locale'] ?? '',
        });
        
        _currentVoiceName = voiceName;
        
        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tts_voice_name', voiceName);
        
        emit(TtsVoicesLoaded(voices: _availableVoices, currentVoice: _currentVoiceName));
      }
    } catch (e) {
      print('Error setting voice: $e');
      // If setting voice fails, try to use default voice
      if (_availableVoices.isNotEmpty) {
        final defaultVoice = _availableVoices.first;
        try {
          await _flutterTts.setVoice({
            'name': defaultVoice['name'] ?? '',
            'locale': defaultVoice['locale'] ?? '',
          });
          _currentVoiceName = defaultVoice['name'];
        } catch (e2) {
          print('Error setting default voice: $e2');
        }
      }
    }
  }

  String? get currentVoiceName => _currentVoiceName;
  List<Map<String, String>> get availableVoices => _availableVoices;

  Future<void> readText(String text, {Function()? onComplete}) async {
    if (text.isEmpty) return;

    // Lưu callback hoàn thành cho cả chuỗi đọc hiện tại
    if (onComplete != null) {
      _onReadingComplete = onComplete;
    }

    // Nếu đang đọc, thêm text mới vào queue để đọc nối tiếp
    if (_isReading) {
      _readingQueue.add(text);
      return;
    }

    _isReading = true;
    _currentReadingText = text;
    _readingStartTime = DateTime.now();
    emit(TtsReading(text));
    
    // Ensure voice is set before reading
    if (_currentVoiceName != null && _availableVoices.isNotEmpty) {
      try {
        final voice = _availableVoices.firstWhere(
          (v) => v['name'] == _currentVoiceName,
          orElse: () => _availableVoices.first,
        );
        await _flutterTts.setVoice({
          'name': voice['name'] ?? '',
          'locale': voice['locale'] ?? '',
        });
      } catch (e) {
        print('Error setting voice before reading: $e');
      }
    }
    
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

