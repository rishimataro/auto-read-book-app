import 'package:equatable/equatable.dart';

abstract class BookState extends Equatable {
  const BookState();
}

class BookInitial extends BookState {
  const BookInitial();

  @override
  List<Object?> get props => const [];
}

class BookLoading extends BookState {
  final String message;

  const BookLoading(this.message);

  @override
  List<Object?> get props => [message];
}

class BookLoaded extends BookState {
  final String text;
  final String? statusMessage;

  const BookLoaded(this.text, {this.statusMessage});

  @override
  List<Object?> get props => [text, statusMessage];
}

class BookError extends BookState {
  final String message;

  const BookError(this.message);

  @override
  List<Object?> get props => [message];
}