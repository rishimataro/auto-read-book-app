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
