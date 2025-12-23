part of 'tts_cubit.dart';

abstract class TtsState extends Equatable {
  const TtsState();

  @override
  List<Object> get props => [];
}

class TtsInitial extends TtsState {}

class TtsIdle extends TtsState {}

class TtsReading extends TtsState {
  final String text;
  const TtsReading(this.text);
  
  @override
  List<Object> get props => [text];
}

class TtsPaused extends TtsState {}

class TtsVoicesLoaded extends TtsState {
  final List<Map<String, String>> voices;
  final String? currentVoice;
  
  const TtsVoicesLoaded({required this.voices, this.currentVoice});
  
  @override
  List<Object> get props => [voices, currentVoice ?? ''];
}

