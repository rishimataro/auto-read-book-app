import 'dart:convert';
import 'dart:io';
import 'package:demo/data/models/reading_history.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingHistoryRepository {
  static const String _historyKey = 'reading_history';
  
  Future<String> _getHistoryDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${directory.path}/reading_history');
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    return historyDir.path;
  }

  Future<void> saveHistory(ReadingHistory history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historiesJson = prefs.getStringList(_historyKey) ?? [];
      
      // Thêm lịch sử mới
      historiesJson.add(jsonEncode(history.toJson()));
      
      // Giới hạn số lượng lịch sử (giữ 100 bản ghi gần nhất)
      if (historiesJson.length > 100) {
        historiesJson.removeRange(0, historiesJson.length - 100);
      }
      
      await prefs.setStringList(_historyKey, historiesJson);
    } catch (e) {
      print('Error saving reading history: $e');
    }
  }

  Future<List<ReadingHistory>> getAllHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historiesJson = prefs.getStringList(_historyKey) ?? [];
      
      return historiesJson.map((jsonStr) {
        try {
          return ReadingHistory.fromJson(jsonDecode(jsonStr));
        } catch (e) {
          return null;
        }
      }).whereType<ReadingHistory>().toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Error loading reading history: $e');
      return [];
    }
  }

  Future<List<ReadingHistory>> getHistoryByBook(String bookTitle) async {
    final allHistory = await getAllHistory();
    return allHistory.where((h) => h.bookTitle == bookTitle).toList();
  }

  Future<void> deleteHistory(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historiesJson = prefs.getStringList(_historyKey) ?? [];
      
      historiesJson.removeWhere((jsonStr) {
        try {
          final history = ReadingHistory.fromJson(jsonDecode(jsonStr));
          if (history.id == id && history.audioPath != null) {
            // Xóa file audio nếu có
            final audioFile = File(history.audioPath!);
            if (audioFile.existsSync()) {
              audioFile.deleteSync();
            }
          }
          return history.id == id;
        } catch (e) {
          return false;
        }
      });
      
      await prefs.setStringList(_historyKey, historiesJson);
    } catch (e) {
      print('Error deleting reading history: $e');
    }
  }

  Future<void> deleteAllHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allHistory = await getAllHistory();
      
      // Xóa tất cả file audio
      for (final history in allHistory) {
        if (history.audioPath != null) {
          final audioFile = File(history.audioPath!);
          if (audioFile.existsSync()) {
            audioFile.deleteSync();
          }
        }
      }
      
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Error deleting all reading history: $e');
    }
  }

  Future<String?> saveAudioFile(String audioData, String bookTitle) async {
    try {
      final historyDir = await _getHistoryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${bookTitle.replaceAll(RegExp(r'[^\w\s-]'), '_')}_$timestamp.wav';
      final filePath = '$historyDir/$fileName';
      
      final file = File(filePath);
      // Nếu audioData là base64, decode nó
      if (audioData.startsWith('data:')) {
        // Xử lý data URI nếu cần
        final base64Data = audioData.split(',')[1];
        await file.writeAsBytes(base64Decode(base64Data));
      } else {
        // Giả sử là đường dẫn file
        final sourceFile = File(audioData);
        if (await sourceFile.exists()) {
          await sourceFile.copy(filePath);
        }
      }
      
      return filePath;
    } catch (e) {
      print('Error saving audio file: $e');
      return null;
    }
  }
}

