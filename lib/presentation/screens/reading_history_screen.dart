import 'package:demo/data/models/reading_history.dart';
import 'package:demo/data/repositories/reading_history_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';

class ReadingHistoryScreen extends StatefulWidget {
  final String? bookTitle;

  const ReadingHistoryScreen({super.key, this.bookTitle});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  final ReadingHistoryRepository _repository = ReadingHistoryRepository();
  final FlutterTts _tts = FlutterTts();
  List<ReadingHistory> _histories = [];
  bool _isLoading = true;
  String? _playingHistoryId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("vi-VN");
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final histories = widget.bookTitle != null
        ? await _repository.getHistoryByBook(widget.bookTitle!)
        : await _repository.getAllHistory();
    setState(() {
      _histories = histories;
      _isLoading = false;
    });
  }

  Future<void> _playHistory(ReadingHistory history) async {
    if (_playingHistoryId == history.id) {
      await _tts.stop();
      setState(() => _playingHistoryId = null);
      return;
    }

    setState(() => _playingHistoryId = history.id);

    try {
      // Nếu trong tương lai có file audio đã được generate,
      // có thể tích hợp audio player tại đây.
      if (history.audioPath != null && File(history.audioPath!).existsSync()) {
        // Tạm thời chỉ log lại đường dẫn, vẫn dùng TTS để đọc nội dung.
        print('Phát lịch sử bằng TTS, file audio (nếu có): ${history.audioPath}');
      }

      // Phát text bằng TTS (đảm bảo widget luôn có chức năng)
      await _tts.speak(history.text);
    } catch (e) {
      print('Lỗi khi phát lịch sử: $e');
    } finally {
      if (mounted) {
        setState(() => _playingHistoryId = null);
      }
    }
  }

  Future<void> _deleteHistory(ReadingHistory history) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch sử?'),
        content: const Text('Bạn có chắc chắn muốn xóa lịch sử này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteHistory(history.id);
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle ?? 'Lịch sử đọc sách'),
        backgroundColor: const Color(0xFF426A80),
        foregroundColor: Colors.white,
        actions: [
          if (_histories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xóa tất cả?'),
                    content: const Text('Bạn có chắc chắn muốn xóa tất cả lịch sử không?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Xóa tất cả'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _repository.deleteAllHistory();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _histories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có lịch sử đọc sách',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _histories.length,
                    itemBuilder: (context, index) {
                      final history = _histories[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: Icon(
                            Icons.book,
                            color: const Color(0xFF426A80),
                          ),
                          title: Text(
                            history.bookTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(history.bookAuthor),
                              const SizedBox(height: 4),
                              Text(
                                '${history.createdAt.day}/${history.createdAt.month}/${history.createdAt.year} ${history.createdAt.hour}:${history.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _playingHistoryId == history.id
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                  color: const Color(0xFF426A80),
                                ),
                                onPressed: () => _playHistory(history),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteHistory(history),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (history.pageNumber > 0)
                                    Text(
                                      'Trang ${history.pageNumber}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    history.text,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (history.audioPath != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.audiotrack, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Có file âm thanh',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}

