part of 'home_cubit.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final Map<String, dynamic>? lastReadBook;
  final bool isConnected;

  const HomeLoaded({this.lastReadBook, required this.isConnected});

  @override
  List<Object?> get props => [lastReadBook, isConnected];
}

