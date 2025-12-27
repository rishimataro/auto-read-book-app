import 'dart:async';
import 'dart:convert';

import 'package:demo/data/repositories/pi_repository.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import 'book_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BookCubit extends Cubit<BookState> {
  final PiRepository _repository;
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<String>? _textSubscription;
  StreamSubscription<String>? _readingStreamSubscription;

  String _currentText = "";

  BookCubit(this._repository) : super(BookInitial()) {
    _initTts();
    _listenToTextStream();
  }

  void _listenToTextStream() {
    _textSubscription = _repository.textStream.listen(
      (text) {
        if (text.isNotEmpty) {
          try {
            final data = jsonDecode(text);
            if (data is Map<String, dynamic>) {
              final cleanText = data['clean_text'] ?? data['text'] ?? '';
              if (cleanText.isNotEmpty) {
                updateText(cleanText);
              }
            }
          } catch (e) {
            // If not JSON, treat as plain text
            if (text.isNotEmpty) {
              updateText(text);
            }
          }
        }
      },
      onError: (error) {
        emit(BookError("Lỗi nhận dữ liệu: $error"));
      },
    );
  }

  void _initTts() async {
    await _tts.setLanguage("vi-VN");
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
  }

  // Future<void> scanAndRead() async {
  //   emit(BookLoading("Đang chụp và Phân tích..."));
  //   try {
  //     final result = await _repository.scanPage();
  //     emit(BookLoaded(result.cleanText));
  //     await _tts.speak(result.cleanText);
  //   } catch (e) {
  //     emit(BookError("Lỗi: ${e.toString()}"));
  //   }
  // }

  Future<void> scanAndReadStream() async {
    _currentText = "";

    emit(BookLoading("Đang kết nối AI Server..."));

    try {
      final baseUrl = await _repository.findAiServer();
      if(baseUrl == null) {
        emit(BookError("Không tìm thấy AI Server (Laptop)"));
        return;
      }

      final request = http.Request('GET', Uri.parse('http://$baseUrl:5000/scan_stream'));
      final client = http.Client();

      final response = await client.send(request);

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) async {

        if (line.startsWith("data: ")) {
          final jsonStr = line.substring(6);
          try {
            final data = jsonDecode(jsonStr);
            _handleStreamEvent(data);
          } catch (e) {
            print("Lỗi parse JSON stream: $e");
          }
        }
      }, onError: (error) {
        emit(BookError("Lỗi kết nối: $error"));
      }, onDone: () {
        client.close();
      });

    } catch (e) {
      emit(BookError("Không thể kết nối Server: $e"));
    }
  }

  Future<void> startContinuousReading() async {
    // Hủy subscription cũ nếu có
    await _readingStreamSubscription?.cancel();
    _currentText = "";

    emit(BookLoading("Đang bắt đầu quy trình đọc sách..."));

    try {
      final baseUrl = await _repository.findAiServer();
      if(baseUrl == null) {
        emit(BookError("Không tìm thấy AI Server (Laptop)"));
        return;
      }

      final request = http.Request('POST', Uri.parse('http://$baseUrl:5000/reading'));
      final client = http.Client();

      final response = await client.send(request);

      _readingStreamSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith("data: ")) {
          final jsonStr = line.substring(6);
          try {
            final data = jsonDecode(jsonStr);
            _handleStreamEvent(data);
          } catch (e) {
            print("Lỗi parse JSON stream: $e");
            print("Line gây lỗi: $line");
          }
        } else if (line.trim().isNotEmpty) {
          // Debug: in ra các dòng không phải data:
          print("Received non-data line: $line");
        }
      }, onError: (error) {
        print("Stream error: $error");
        emit(BookError("Lỗi kết nối: $error"));
      }, onDone: () {
        print("Stream done");
        client.close();
      }, cancelOnError: false);

    } catch (e) {
      print("Error starting continuous reading: $e");
      emit(BookError("Không thể kết nối Server: $e"));
    }
  }

  // Hàm xử lý từng sự kiện từ Server
  void _handleStreamEvent(Map<String, dynamic> data) {
    final status = data['status'];
    final sideRaw = data['side'];
    final text = data['text'];

    // Log chi tiết mọi event từ backend để debug
    print("[BookCubit] Event nhận được - status: $status, side: $sideRaw, "
        "text_len: ${text is String ? text.length : 'null'}, raw: $data");

    if (status == 'processing' || status == 'capturing' || status == 'flipping') {
      // Giữ lại text hiện tại khi đang loading
      final currentState = state;
      if (currentState is BookLoaded) {
        emit(BookLoaded(currentState.text, statusMessage: data['message'] ?? 'Đang xử lý...'));
      } else {
        emit(BookLoading(data['message'] ?? 'Đang xử lý...'));
      }

    } else if (status == 'page_done') {
      final text = data['text'] ?? '';
      final side = data['side'] == 'left' ? "Trái" : "Phải";
      final page = data['page'] ?? 0;

      // Kiểm tra text có hợp lệ không
      if (text.isEmpty || text.trim().isEmpty) {
        print("Warning: Nhận được text rỗng từ trang $side");
        return;
      }

      print("Nhận được text từ trang $side: ${text.length} ký tự");

      // Cập nhật _currentText - thêm text mới vào
      if (_currentText.isEmpty) {
        _currentText = "--- Trang $side (Trang $page) ---\n$text";
      } else {
        _currentText = "$_currentText\n\n--- Trang $side (Trang $page) ---\n$text";
      }

      // Emit ngay lập tức để UI cập nhật real-time
      emit(BookLoaded(_currentText, statusMessage: "Đã nhận được text trang $side"));
      print("Đã emit BookLoaded với ${_currentText.length} ký tự");

    } else if (status == 'finished') {
      emit(BookLoaded(_currentText, statusMessage: data['message'] ?? 'Đã đọc xong!'));
    } else if (status == 'error') {
      emit(BookError(data['message'] ?? 'Có lỗi xảy ra'));
    }
  }

  Future<void> flipPage() async {
    emit(BookLoading("Đang lật trang..."));
    try {
      await _repository.flipPage();
      emit(BookInitial());
    } catch (e) {
      emit(BookError("Lỗi lật trang: ${e.toString()}"));
    }
  }

  Future<void> stopReading() async {
    // Hủy stream subscription
    await _readingStreamSubscription?.cancel();
    _readingStreamSubscription = null;
    
    // Dừng TTS
    await _tts.stop();
    
    // Gọi endpoint để dừng backend processing
    try {
      await _repository.stopReading();
    } catch (e) {
      print('Error stopping reading on backend: $e');
      // Không emit error để không làm gián đoạn UI
    }
  }

  void updateText(String text) {
    if (state is BookLoaded) {
      final currentText = (state as BookLoaded).text;
      emit(BookLoaded("$currentText\n$text"));
    } else {
      emit(BookLoaded(text));
    }
  }

  @override
  Future<void> close() {
    _textSubscription?.cancel();
    _readingStreamSubscription?.cancel();
    _tts.stop();
    return super.close();
  }
}