import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'personal_state.dart';

class PersonalCubit extends Cubit<PersonalState> {
  PersonalCubit() : super(PersonalInitial());

  static const String _autoReadKey = 'auto_read';
  static const String _readLanguageKey = 'read_language';

  Future<void> loadSettings() async {
    emit(PersonalLoading());
    final prefs = await SharedPreferences.getInstance();
    final autoRead = prefs.getBool(_autoReadKey) ?? true; // Default to true
    final readLanguage = prefs.getString(_readLanguageKey) ?? 'vi-VN'; // Default to Vietnamese
    emit(PersonalLoaded(autoRead: autoRead, readLanguage: readLanguage));
  }

  Future<void> setAutoRead(bool value) async {
    if (state is PersonalLoaded) {
      final currentState = state as PersonalLoaded;
      emit(PersonalLoading());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoReadKey, value);
      emit(PersonalLoaded(autoRead: value, readLanguage: currentState.readLanguage));
    }
  }

  Future<void> setReadLanguage(String languageCode) async {
    if (state is PersonalLoaded) {
      final currentState = state as PersonalLoaded;
      emit(PersonalLoading());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_readLanguageKey, languageCode);
      emit(PersonalLoaded(autoRead: currentState.autoRead, readLanguage: languageCode));
    }
  }
}

