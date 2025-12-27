import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(HomeInitial());

  Future<void> loadHomeData(bool isConnected) async {
    emit(HomeLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic>? lastReadBook;
      
      // Ưu tiên lấy từ last_read_book (sách vừa đọc)
      final lastReadBookJson = prefs.getString('last_read_book');
      if (lastReadBookJson != null && lastReadBookJson.isNotEmpty) {
        try {
          lastReadBook = json.decode(lastReadBookJson) as Map<String, dynamic>;
        } catch (e) {
          print('Error decoding last_read_book: $e');
        }
      }
      
      // Nếu không có last_read_book, thử lấy từ reading history (sách có lịch sử đọc mới nhất)
      if (lastReadBook == null) {
        try {
          final historiesJson = prefs.getStringList('reading_history') ?? [];
          if (historiesJson.isNotEmpty) {
            // Lấy lịch sử mới nhất
            final latestHistoryJson = historiesJson.last;
            final latestHistory = json.decode(latestHistoryJson) as Map<String, dynamic>;
            final bookTitle = latestHistory['bookTitle'] as String?;
            final bookAuthor = latestHistory['bookAuthor'] as String?;
            
            if (bookTitle != null && bookAuthor != null) {
              // Tìm sách trong danh sách read_books
              final readBooksJson = prefs.getStringList('read_books') ?? [];
              for (var bookString in readBooksJson) {
                try {
                  final book = json.decode(bookString) as Map<String, dynamic>;
                  if (book['title'] == bookTitle && book['author'] == bookAuthor) {
                    lastReadBook = book;
                    break;
                  }
                } catch (e) {
                  // Ignore errors
                }
              }
            }
          }
        } catch (e) {
          print('Error loading from reading history: $e');
        }
      }
      
      // Nếu vẫn không có, lấy sách cuối cùng trong danh sách (fallback)
      if (lastReadBook == null) {
        final readBooksJson = prefs.getStringList('read_books') ?? [];
        if (readBooksJson.isNotEmpty) {
          try {
            lastReadBook = json.decode(readBooksJson.last) as Map<String, dynamic>;
          } catch (e) {
            print('Error decoding last book: $e');
          }
        }
      }
      
      emit(HomeLoaded(lastReadBook: lastReadBook, isConnected: isConnected));
    } catch (e) {
      emit(HomeLoaded(isConnected: isConnected)); // Vẫn load dù có lỗi sách
    }
  }
}

