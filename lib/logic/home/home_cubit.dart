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
      final readBooksJson = prefs.getStringList('read_books') ?? [];
      Map<String, dynamic>? lastReadBook;
      if (readBooksJson.isNotEmpty) {
        lastReadBook = json.decode(readBooksJson.last) as Map<String, dynamic>;
      }
      emit(HomeLoaded(lastReadBook: lastReadBook, isConnected: isConnected));
    } catch (e) {
      emit(HomeLoaded(isConnected: isConnected)); // Vẫn load dù có lỗi sách
    }
  }
}

