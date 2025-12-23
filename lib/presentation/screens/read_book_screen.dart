import 'dart:async';
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
  late String _streamUrl; // Calculate once
  final ReadingHistoryRepository _historyRepository = ReadingHistoryRepository();
  StreamSubscription? _readingStream;
  String _currentPageText = "";
  int _currentPage = 0;
  bool _isChangingVoice = false;
  Timer? _readingTimer;
  bool _isContinuousReading = false;
  DateTime? _currentPageStartTime;
  double? _estimatedPageReadingTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _initCameraStream();
    
    _isPlaying = false;
    _lastReadText = "";
    _currentPageText = "";
    _currentPage = 0;
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
    if (state is BookLoaded && _autoRead && _isPlaying && !_isChangingVoice) {
      final newText = state.text;
      _currentPageText = newText;

      if (newText.isNotEmpty && newText != _lastReadText) {
        String textToRead = "";

        if (_lastReadText.isEmpty) {
          textToRead = newText;
        } else if (newText.length > _lastReadText.length) {
          final lastMarker = _lastReadText.lastIndexOf("---");
          if (lastMarker != -1) {
            final afterLastMarker = _lastReadText.substring(lastMarker);
            final newMarker = newText.lastIndexOf("---");
            if (newMarker != -1 && newMarker > lastMarker) {
              final afterNewMarker = newText.substring(newMarker);
              final lines = afterNewMarker.split('\n');
              if (lines.length > 1) {
                textToRead = lines.sublist(1).join('\n').trim();
              }
            }
          }
          
          if (textToRead.isEmpty) {
            final diff = newText.length - _lastReadText.length;
            if (diff > 0) {
              textToRead = newText.substring(_lastReadText.length).trim();
            }
          }
        }

        if (textToRead.isNotEmpty) {
          _lastReadText = newText;
          
          _saveReadingHistory(textToRead);
          
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
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddBookScreen(
                      bookToEdit: {
                        'title': widget.title,
                        'author': widget.author,
                      },
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
              onPressed: () {
                context.read<BookCubit>().stopReading();
                context.read<TtsCubit>().stopReading();
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
                onPressed: () => _showVoiceSelectionDialog(context),
                icon: const Icon(Icons.record_voice_over, size: 30),
                tooltip: 'Đổi giọng đọc',
              ),
              IconButton(
                onPressed: () async {
                  if (!_isPlaying) {
                    // Bắt đầu đọc
                    setState(() {
                      _isPlaying = true;
                    });
                    final bookState = context.read<BookCubit>().state;
                    if (bookState is BookLoaded && bookState.text.isNotEmpty) {
                      // Tiếp tục đọc từ vị trí hiện tại
                      final parts = bookState.text.split('---');
                      String textToRead = parts.length > 1 ? parts.last.trim() : bookState.text;
                      if (textToRead.isNotEmpty) {
                        context.read<TtsCubit>().readText(textToRead, onComplete: () {
                          _onPageReadingComplete(context);
                        });
                      }
                    } else {
                      // Bắt đầu quy trình đọc sách mới
                      setState(() {
                        _isContinuousReading = true;
                      });
                      context.read<BookCubit>().startContinuousReading();
                    }
                  } else {
                    // Dừng đọc
                    setState(() {
                      _isPlaying = false;
                      _isContinuousReading = false;
                    });
                    _readingTimer?.cancel();
                    context.read<TtsCubit>().stopReading();
                    // Không dừng backend để có thể tiếp tục sau
                    // context.read<BookCubit>().stopReading();
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
            onPressed: () => Navigator.pop(context, true),
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

  Future<void> _showVoiceSelectionDialog(BuildContext context) async {
    final ttsCubit = context.read<TtsCubit>();
    final bookCubit = context.read<BookCubit>();
    
    // Dừng đọc trước khi đổi giọng
    setState(() {
      _isChangingVoice = true;
    });
    
    // Dừng TTS và backend processing
    ttsCubit.stopReading();
    
    // Đợi một chút để đảm bảo TTS đã dừng hoàn toàn
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Tạm dừng backend (không dừng hoàn toàn để có thể tiếp tục)
    // await bookCubit.stopReading(); // Comment out để không dừng backend
    
    await ttsCubit.loadAvailableVoices();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return BlocBuilder<TtsCubit, TtsState>(
          bloc: ttsCubit,
          builder: (context, state) {
            List<Map<String, String>> voices = [];
            String? currentVoice;
            if (state is TtsVoicesLoaded) {
              voices = state.voices;
              currentVoice = state.currentVoice;
            } else {
              voices = ttsCubit.availableVoices;
              currentVoice = ttsCubit.currentVoiceName;
            }
            return AlertDialog(
              title: const Text('Chọn giọng đọc', style: TextStyle(fontWeight: FontWeight.bold)),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SizedBox(
                  width: double.maxFinite,
                  child: voices.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: voices.length,
                    itemBuilder: (context, index) {
                      final voice = voices[index];
                      final voiceName = voice['name'] ?? 'Unknown';
                      final isSelected = voiceName == currentVoice;
                      return RadioListTile<String>(
                        title: Text(voiceName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        value: voiceName,
                        groupValue: currentVoice,
                        activeColor: const Color(0xFF426A80),
                        onChanged: (value) async {
                          if (value != null) {
                            await ttsCubit.setVoice(value);
                            Navigator.of(dialogContext).pop();
                            
                            // Đợi một chút để đảm bảo voice đã được set
                            await Future.delayed(const Duration(milliseconds: 200));
                            
                            // Tiếp tục đọc sau khi đổi giọng
                            setState(() {
                              _isChangingVoice = false;
                            });
                            
                            // Lấy text hiện tại và đọc lại
                            final bookState = context.read<BookCubit>().state;
                            if (_isPlaying && bookState is BookLoaded && bookState.text.isNotEmpty) {
                              // Lấy phần text mới nhất để đọc lại
                              final parts = bookState.text.split('---');
                              String textToRead = '';
                              if (parts.length > 1) {
                                textToRead = parts.last.trim();
                              } else {
                                textToRead = bookState.text;
                              }
                              
                              if (textToRead.isNotEmpty) {
                                _currentPageText = textToRead;
                                ttsCubit.readText(textToRead, onComplete: () {
                                  _onPageReadingComplete(context);
                                });
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _isChangingVoice = false;
                    });
                    if (_isPlaying) {
                      final bookState = context.read<BookCubit>().state;
                      if (bookState is BookLoaded && bookState.text.isNotEmpty) {
                        final parts = bookState.text.split('---');
                        String textToRead = parts.length > 1 ? parts.last.trim() : bookState.text;
                        if (textToRead.isNotEmpty) {
                          ttsCubit.readText(textToRead);
                        }
                      }
                    }
                  },
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}