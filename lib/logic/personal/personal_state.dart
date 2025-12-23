part of 'personal_cubit.dart';

abstract class PersonalState extends Equatable {
  const PersonalState();

  @override
  List<Object> get props => [];
}

class PersonalInitial extends PersonalState {}

class PersonalLoading extends PersonalState {}

class PersonalLoaded extends PersonalState {
  final bool autoRead;
  final String readLanguage;

  const PersonalLoaded({required this.autoRead, required this.readLanguage});

  @override
  List<Object> get props => [autoRead, readLanguage];
}

