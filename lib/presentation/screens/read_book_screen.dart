import 'dart:async';
import 'dart:convert';
import 'package:demo/data/models/reading_history.dart';
import 'package:demo/data/repositories/pi_repository.dart';
import 'package:demo/data/repositories/reading_history_repository.dart';
import 'package:demo/logic/book/book_cubit.dart';
import 'package:demo/logic/book/book_state.dart';
import 'package:demo/logic/tts/tts_cubit.dart';
import 'package:demo/presentation/screens/add_book_screen.dart';
import 'package:demo/presentation/screens/reading_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mjpeg_stream/mjpeg_stream.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadBookScreen extends StatelessWidget {
  final String title;
  final String author;

  const ReadBookScreen({super.key, required this.title, required this.author});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => PiRepository(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => TtsCubit(),
          ),
          BlocProvider(
            create: (context) => BookCubit(context.read<PiRepository>()),
          )
        ],
        child: ReadBookPage(title: title, author: author),
      ),
    );
  }
}

class ReadBookPage extends StatefulWidget {
  final String title;
  final String author;

  const ReadBookPage({super.key, required this.title, required this.author});

  @override
  State<ReadBookPage> createState() => _ReadBookPageState();
}

class _ReadBookPageState extends State<ReadBookPage> {
  bool _autoRead = true;
  bool _isPlaying = false;
  String _lastReadText = "";
  String _streamUrl = ""; // Initialize with empty string
  final ReadingHistoryRepository _historyRepository = ReadingHistoryRepository();
  StreamSubscription? _readingStream;
  String _currentPageText = "";
  int _currentPage = 0;
  Timer? _readingTimer;
  bool _isContinuousReading = false;
  DateTime? _currentPageStartTime;
  double? _estimatedPageReadingTime;

  // Quản lý một lần đọc (session)
  String _sessionText = "";
  bool _sessionActive = false;
  bool _sessionSaved = false;

  // Quản lý vị trí dừng trong đoạn đang đọc
  String? _pausedText; // Text đang đọc khi bị dừng
  int? _pausedPosition; // Vị trí ký tự đã đọc được khi bị dừng

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _saveLastReadBook(); // Lưu sách vừa đọc khi mở màn hình

    _initCameraStream();
    
    _isPlaying = false;
    _lastReadText = "";
    _currentPageText = "";
    _currentPage = 0;
  }

  /// Lưu thông tin sách vừa đọc vào SharedPreferences
  Future<void> _saveLastReadBook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastReadBook = {
        'title': widget.title,
        'author': widget.author,
      };
      
      // Load đầy đủ thông tin sách từ SharedPreferences
      final booksJson = prefs.getStringList('read_books') ?? [];
      Map<String, dynamic>? fullBookData;
      
      for (var bookString in booksJson) {
        try {
          final book = json.decode(bookString) as Map<String, dynamic>;
          if (book['title'] == widget.title && book['author'] == widget.author) {
            fullBookData = book;
            break;
          }
        } catch (e) {
          // Ignore errors
        }
      }
      
      // Lưu sách vừa đọc (dùng dữ liệu đầy đủ nếu có)
      if (fullBookData != null) {
        await prefs.setString('last_read_book', json.encode(fullBookData));
      } else {
        await prefs.setString('last_read_book', json.encode(lastReadBook));
      }
    } catch (e) {
      print('Error saving last read book: $e');
    }
  }

  Future<void> _initCameraStream() async {
    final repository = context.read<PiRepository>();
    
    if (repository.piCameraIp == null) {
      await repository.findPiCamera();
    }
    
    final piCameraUrl = repository.piCameraUrl;
    if (mounted) {
      setState(() {
        _streamUrl = piCameraUrl != null ? "$piCameraUrl/video_feed" : "";
      });
    }
    
    if (_streamUrl.isEmpty) {
      print("Warning: Không tìm thấy Pi Camera, stream sẽ không hoạt động");
    } else {
      print("Pi Camera stream URL: $_streamUrl");
    }
  }

  @override
  void dispose() {
    // Dừng stream và timer khi dispose widget
    _readingStream?.cancel();
    _readingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoRead = prefs.getBool('auto_read') ?? true;
        _isPlaying = _autoRead;
      });
    }
  }

  void _handleBookStateChange(BuildContext context, BookState state) {
    if (state is BookLoaded && _autoRead && _isPlaying) {
      final newText = state.text;
      _currentPageText = newText;

      // Nếu đây là lần đầu nhận text trong phiên, đánh dấu bắt đầu session
      if (!_sessionActive && newText.isNotEmpty) {
        _sessionActive = true;
        _sessionSaved = false;
        _sessionText = "";
        _currentPage = 0;
      }

      if (newText.isNotEmpty && newText != _lastReadText) {
        // Lấy CHÍNH XÁC phần text mới được append thêm so với lần trước
        String textToRead = "";
        if (_lastReadText.isEmpty) {
          // Lần đầu tiên: đọc toàn bộ
          textToRead = newText;
        } else if (newText.length > _lastReadText.length) {
          // Những lần sau: chỉ đọc phần được thêm mới
          textToRead = newText.substring(_lastReadText.length).trim();
        }

        print("[ReadBookPage] newTextLen=${newText.length}, "
            "lastReadTextLen=${_lastReadText.length}, "
            "textToReadLen=${textToRead.length}");

        if (textToRead.isNotEmpty) {
          _lastReadText = newText;

          // Gộp text vào session thay vì lưu từng trang
          if (_sessionActive) {
            if (_sessionText.isEmpty) {
              _sessionText = textToRead;
            } else {
              _sessionText = '$_sessionText\n\n$textToRead';
            }
          }

          final ttsCubit = context.read<TtsCubit>();
          _estimatedPageReadingTime = ttsCubit.estimateReadingTime(textToRead);
          _currentPageStartTime = DateTime.now();

          ttsCubit.readText(textToRead, onComplete: () {
            _onPageReadingComplete(context);
          });

          _startReadingTimer(context);
        } else {
          print("Warning: textToRead rỗng, không đọc");
        }
      }
    }

    // Nếu backend báo đã đọc xong, lưu toàn bộ nội dung của phiên đọc
    if (state is BookLoaded) {
      final msg = state.statusMessage ?? '';
      if (_sessionActive && !_sessionSaved && msg.contains('Đã đọc xong')) {
        _finalizeReadingSession();
      }
    }
  }

  Future<void> _finalizeReadingSession() async {
    if (!_sessionActive || _sessionSaved) return;
    final text = _sessionText.trim();
    if (text.isEmpty) return;

    try {
      await _saveReadingHistory(text);
      _sessionSaved = true;
      _sessionActive = false;
      print("[ReadBookPage] Đã lưu lịch sử đọc cho 1 lần đọc, length=${text.length}");
    } catch (e) {
      print("[ReadBookPage] Lỗi khi lưu lịch sử phiên đọc: $e");
    }
  }

  /// Dừng hoàn toàn việc đọc sách: TTS, backend, stream, timer và lưu lịch sử
  Future<void> _finishReading(BuildContext context) async {
    print("[ReadBookPage] Bắt đầu dừng đọc sách và lưu lịch sử...");
    
    // 1. Dừng TTS ngay lập tức
    final ttsCubit = context.read<TtsCubit>();
    ttsCubit.stopReading();
    print("[ReadBookPage] Đã dừng TTS");
    
    // 2. Dừng backend (chụp ảnh và xử lý)
    final bookCubit = context.read<BookCubit>();
    await bookCubit.stopReading();
    print("[ReadBookPage] Đã dừng backend");
    
    // 3. Hủy timer nếu có
    _readingTimer?.cancel();
    _readingTimer = null;
    print("[ReadBookPage] Đã hủy timer");
    
    // 4. Reset các flags để không chạy ngầm nữa
    setState(() {
      _isPlaying = false;
      _isContinuousReading = false;
    });
    print("[ReadBookPage] Đã reset flags");
    
    // 5. Lưu lịch sử đọc (nếu chưa lưu)
    await _finalizeReadingSession();
    print("[ReadBookPage] Đã lưu lịch sử");
    
    // 6. Pop về màn hình trước
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _startReadingTimer(BuildContext context) {
    _readingTimer?.cancel();

    if (!_isContinuousReading || _estimatedPageReadingTime == null) return;

    final flipTime = _estimatedPageReadingTime! * 0.8;

    _readingTimer = Timer(Duration(milliseconds: (flipTime * 1000).toInt()), () {
      if (mounted && _isPlaying && _isContinuousReading) {
        _flipPageForNextReading(context);
      }
    });
  }

  void _onPageReadingComplete(BuildContext context) {
    _readingTimer?.cancel();

    if (_isContinuousReading && _isPlaying) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isPlaying && _isContinuousReading) {
          _flipPageForNextReading(context);
        }
      });
    }
  }

  void _flipPageForNextReading(BuildContext context) {
    // Lật trang tiếp theo trong quy trình đọc liên tục
    // Backend sẽ tự động chụp và xử lý trang tiếp theo
    print("Tự động lật trang tiếp theo...");
    // Không cần gọi flipPage() vì backend đã tự động lật trong start_reading
  }

  Future<void> _saveReadingHistory(String text) async {
    if (text.trim().isEmpty) return;
    
    try {
      String? audioPath;
      
      final history = ReadingHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bookTitle: widget.title,
        bookAuthor: widget.author,
        text: text,
        audioPath: audioPath,
        createdAt: DateTime.now(),
        pageNumber: _currentPage,
      );
      await _historyRepository.saveHistory(history);
    } catch (e) {
      print('Error saving reading history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookCubit, BookState>(
      listener: _handleBookStateChange,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: const Color(0xFF426A80),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Chỉnh sửa thông tin sách',
              onPressed: () async {
                // Load đầy đủ thông tin sách từ SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                final booksJson = prefs.getStringList('read_books') ?? [];
                Map<String, dynamic>? fullBookData;
                
                for (var bookString in booksJson) {
                  try {
                    final book = json.decode(bookString) as Map<String, dynamic>;
                    if (book['title'] == widget.title && book['author'] == widget.author) {
                      fullBookData = book;
                      break;
                    }
                  } catch (e) {
                    // Ignore errors
                  }
                }
                
                // Nếu không tìm thấy, dùng dữ liệu cơ bản
                final bookToEdit = fullBookData ?? {
                  'title': widget.title,
                  'author': widget.author,
                };
                
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddBookScreen(
                      bookToEdit: bookToEdit,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  // Refresh if book was updated
                  Navigator.pop(context, true);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              tooltip: 'Lịch sử đọc',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReadingHistoryScreen(bookTitle: widget.title),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              tooltip: 'Dừng đọc',
              onPressed: () async {
                final ttsCubit = context.read<TtsCubit>();
                final bookCubit = context.read<BookCubit>();

                // Lưu lại text đang đọc và vị trí đã đọc được để có thể resume
                _pausedText = ttsCubit.getCurrentReadingText();
                _pausedPosition = ttsCubit.getReadingPosition();

                // Dừng backend + TTS
                await bookCubit.stopReading();
                ttsCubit.stopReading();

                // Lưu toàn bộ nội dung đã đọc trong phiên (nếu chưa lưu)
                await _finalizeReadingSession();

                setState(() {
                  _isPlaying = false;
                  _isContinuousReading = false;
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  MJPEGStreamScreen(streamUrl: _streamUrl, showLiveIcon: true),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: BlocBuilder<BookCubit, BookState>(
                      buildWhen: (previous, current) {
                        return current is BookLoaded || previous != current;
                      },
                      builder: (context, state) {
                        if (state is BookLoaded && state.text.isNotEmpty) {
                          final parts = state.text.split('---');
                          String displayText = '';
                          if (parts.length > 1) {
                            final lastPart = parts.last.trim();
                            final lines = lastPart.split('\n');
                            if (lines.length > 1) {
                              displayText = lines.sublist(1).join('\n').trim();
                            } else {
                              displayText = lastPart;
                            }
                          } else {
                            final lines = state.text.split('\n');
                            if (lines.length > 3) {
                              displayText = lines.sublist(lines.length - 3).join('\n').trim();
                            } else {
                              displayText = state.text.trim();
                            }
                          }
                          
                          if (displayText.isNotEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.85),
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.volume_up,
                                        size: 14,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Đang đọc:',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    displayText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.grey[50],
                ),
                child: BlocBuilder<BookCubit, BookState>(
                  builder: (context, state) {
                    if (state is BookLoading) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            Text(state.message, style: const TextStyle(color: Colors.blueGrey)),
                          ],
                        ),
                      );
                    } else if (state is BookLoaded) {
                      final status = state.statusMessage ?? '';
                      final text = state.text;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              reverse: true, // Auto-scrolls to bottom
                              child: text.isEmpty 
                                ? const Center(
                                    child: Text(
                                      "Nhấn nút Play để bắt đầu...",
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  )
                                : SelectableText(
                                    text,
                                    style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87),
                                  ),
                            ),
                          ),
                          if (status.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(top: 8),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.black12)),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blue),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      );
                    } else if (state is BookError) {
                      return Center(child: Text("Lỗi: ${state.message}", style: const TextStyle(color: Colors.red)));
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.book, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text("Sẵn sàng đọc sách", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isPlaying = true;
                              });
                              context.read<BookCubit>().startContinuousReading();
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Bắt đầu đọc'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF426A80),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () async {
                  if (!_isPlaying) {
                    // Resume/Bắt đầu đọc
                    setState(() {
                      _isPlaying = true;
                    });
                    final bookState = context.read<BookCubit>().state;
                    final ttsCubit = context.read<TtsCubit>();

                    // Kiểm tra xem có text đã dừng trước đó không
                    if (_pausedText != null && _pausedText!.isNotEmpty && _pausedPosition != null) {
                      // Resume từ vị trí đã dừng
                      String textToRead = _pausedText!;
                      int resumePosition = _pausedPosition!.clamp(0, textToRead.length);

                      // Tìm vị trí bắt đầu từ từ tiếp theo (tránh cắt giữa từ)
                      if (resumePosition < textToRead.length) {
                        // Tìm đến khoảng trắng hoặc dấu câu tiếp theo
                        int searchStart = resumePosition;
                        while (searchStart < textToRead.length && 
                               !RegExp(r'[\s.,;:!?]').hasMatch(textToRead[searchStart])) {
                          searchStart++;
                        }
                        // Nếu tìm thấy khoảng trắng/dấu câu, bắt đầu từ sau đó
                        if (searchStart < textToRead.length) {
                          resumePosition = searchStart + 1;
                        }
                        // Nếu không tìm thấy, giữ nguyên vị trí
                      }

                      // Cắt phần đã đọc và lấy phần còn lại
                      if (resumePosition < textToRead.length) {
                        textToRead = textToRead.substring(resumePosition).trim();
                      } else {
                        // Đã đọc hết text này, xóa thông tin pause
                        _pausedText = null;
                        _pausedPosition = null;
                        textToRead = "";
                      }

                      if (textToRead.isNotEmpty) {
                        // Đọc phần còn lại
                        _pausedText = null;
                        _pausedPosition = null;
                        ttsCubit.readText(textToRead, onComplete: () {
                          _onPageReadingComplete(context);
                        });
                      } else {
                        // Không còn gì để đọc, bắt đầu luồng mới
                        _pausedText = null;
                        _pausedPosition = null;
                        setState(() {
                          _isContinuousReading = true;
                        });
                        await context.read<BookCubit>().startContinuousReading();
                      }
                    } else if (bookState is BookLoaded && bookState.text.isNotEmpty) {
                      // Không có text đã dừng, nhưng có text trong state: đọc từ đầu
                      setState(() {
                        _isContinuousReading = true;
                      });
                      await context.read<BookCubit>().startContinuousReading();
                    } else {
                      // Bắt đầu quy trình đọc sách mới (đọc liên tục)
                      setState(() {
                        _isContinuousReading = true;
                      });
                      await context.read<BookCubit>().startContinuousReading();
                    }
                  } else {
                    // Dừng đọc hoàn toàn: TTS + backend + timer
                    setState(() {
                      _isPlaying = false;
                      _isContinuousReading = false;
                    });
                    _readingTimer?.cancel();

                    final ttsCubit = context.read<TtsCubit>();
                    final bookCubit = context.read<BookCubit>();

                    // Lưu lại text đang đọc và vị trí đã đọc được để có thể resume
                    _pausedText = ttsCubit.getCurrentReadingText();
                    _pausedPosition = ttsCubit.getReadingPosition();

                    // Dừng đọc TTS ngay lập tức
                    ttsCubit.stopReading();
                    // Dừng lấy ảnh & xử lý chữ ở backend để tránh quá tải
                    await bookCubit.stopReading();
                  }
                },
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 50,
                  color: const Color(0xFF426A80),
                ),
              ),
              IconButton(
                onPressed: () => context.read<BookCubit>().flipPage(),
                icon: const Icon(Icons.skip_next, size: 30, color: Colors.black54),
                tooltip: 'Lật trang',
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              // Khi người dùng bấm "Đã đọc xong", dừng hoàn toàn và lưu lịch sử
              await _finishReading(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C7350),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Đã đọc xong', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

}